"""Every Pokémon ability, to read and balance (docs/SKILLS.md + docs/skills.html, Vietnamese): its text as the game shows
it, the Pokémon using it (role now / suggested), how it lands (thrown at range or dropped where it stands, data steps +
what the role probe measured), its numbers, the PP to cast and the strength of the auto balance, where to edit it.
Needs build/roles/roles.tsv (tools\\role_audit.bat).
    python tools/roles/skill_list.py
"""
import base64
import io
import json
import os
import re
import sys

import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "bot"))
import role_audit as ra  # noqa: E402
import autobalance as ab  # noqa: E402

ROOT = ra.ROOT
ABILITIES = json.load(io.open(os.path.join(ROOT, "data", "abilities.json"), encoding="utf-8"))
TEXT = json.load(io.open(os.path.join(ROOT, "data", "pac", "text.json"), encoding="utf-8"))
WEB_VI = os.path.join(ROOT, "data", "pac", "lang", "vi.json")
PORT_VI = json.load(io.open(os.path.join(ROOT, "data", "i18n", "vi.json"), encoding="utf-8"))
ROLES_TSV = os.path.join(ROOT, "build", "roles", "roles.tsv")
MD = os.path.join(ROOT, "docs", "SKILLS.md")
HTML_OUT = os.path.join(ROOT, "docs", "skills.html")
SECTIONS = ["damage", "stat", "status", "technical_terms", "synergy", "item", "weather", "effect"]
RARITY_ORDER = ["COMMON", "UNCOMMON", "RARE", "EPIC", "ULTRA", "UNIQUE", "LEGENDARY", "HATCH", "SPECIAL"]
AREA = {"self": "bản thân", "single": "1 mục tiêu", "adjacent": "%s kề", "radius": "%s bán kính %s", "square": "%s vuông %s",
        "cone": "hình nón %s trước mặt", "ray": "tia thẳng", "line": "đường thẳng qua mục tiêu", "between": "đường tới mục tiêu",
        "path": "đường lao qua", "board": "toàn sàn", "row": "cả hàng của mục tiêu", "closest": "%s địch gần nhất",
        "backline": "%s địch tuyến sau", "random": "ngẫu nhiên"}
THROWN = {"single", "line", "ray", "between", "board", "row", "closest", "backline", "random"}


#region texts (GameData.set_language("vi") + ability_desc / GameText.format)
def merged_text():
    text = json.loads(json.dumps(TEXT))
    for extra in (json.load(io.open(WEB_VI, encoding="utf-8")) if os.path.exists(WEB_VI) else {}, PORT_VI):
        for section, values in extra.items():
            if isinstance(values, dict):
                text.setdefault(section, {})
                for k, v in values.items():
                    if isinstance(v, str) and v:
                        text[section][k] = v
    return text


VI = merged_text()


def plain(desc):
    """The game's text without its markup: [25,50,100,SP] -> 25/50/100, SPECIAL -> sát thương phép..."""
    def token(m):
        t = m.group(0)
        if t.startswith("["):
            nums = [p.strip() for p in t[1:-1].split(",") if re.fullmatch(r"-?\d+(\.\d+)?", p.strip())]
            return "/".join(nums) if nums else ""
        for section in SECTIONS:
            if t in VI.get(section, {}):
                return VI[section][t]
        return t
    desc = re.sub(r"\{\{[^}]*\}\}", "", desc)
    return re.sub(r"\[[^\]]*\]|\b[A-Z][A-Z0-9_]*[A-Z0-9]\b", token, desc).strip()


def ability_name(sid):
    return VI.get("ability", {}).get(sid) or ABILITIES.get(sid, {}).get("name") or sid


def ability_desc(sid):
    own = PORT_VI.get("ability_port", {}).get(sid)
    if isinstance(own, str) and own:
        return own
    return plain(VI.get("ability_description", {}).get(sid) or ABILITIES.get(sid, {}).get("desc", ""))


def pkm_name(pkm):
    return VI.get("pkm", {}).get(pkm) or pkm.replace("_", " ").title()
#endregion


#region how it lands
def data_shape(a):
    """Words for the data steps of an ability: where each step lands and what it does."""
    out = []
    for st in a.get("steps", []):
        area = st.get("area", "single")
        size = st.get("size", "")
        if isinstance(size, list):
            size = "/".join(str(v) for v in size)
        origin = "quanh mục tiêu:" if st.get("origin") == "focus" else "quanh mình:"
        words = AREA.get(area, area)
        if area in ("adjacent",):
            words = words % origin.rstrip(":")
        elif area in ("radius", "square"):
            words = words % (origin.rstrip(":"), size)
        elif area in ("cone", "closest", "backline"):
            words = words % size
        who = st.get("affects", "enemies")
        if who.startswith("allies"):
            words += " (đồng đội)"
        extra = []
        if st.get("delay"):
            extra.append("sau %g s" % (float(st["delay"]) / 1000))
        if st.get("repeat"):
            extra.append("%s lần" % st["repeat"])
        effects = []
        for e in st.get("effects", []):
            kind = e.get("type", "")
            vals = e.get("values") or e.get("durations") or ([e["duration"]] if "duration" in e else [])
            v = "/".join("%g" % float(x) for x in vals) if vals else ""
            label = {"damage": "sát thương", "heal": "hồi", "shield": "khiên", "status": e.get("status", "trạng thái"),
                     "buff": "%s %s" % ("buff" if not str(v).startswith("-") else "giảm", e.get("stat", "")), "drain": "hút",
                     "cleanse": "giải trạng thái", "pp": "PP"}.get(kind, kind)
            effects.append(("%s %s" % (label, v)).strip())
        out.append(words + (" (" + ", ".join(extra) + ")" if extra else "") + (": " + ", ".join(effects) if effects else ""))
    if a.get("dash"):
        out.insert(0, "lao (%s)" % a["dash"])
    return "; ".join(out)


def landing(a, x):
    """(how, throw): how it lands in a few words, and "tung" (thrown: works from the back row), "tại chỗ" (lands around
    itself: must stand close), "hỗ trợ", "—" (no damage). Data steps first, else what the probe measured (`x`, a row of
    roles.tsv)."""
    if x is not None and x.help_share >= ra.RULES["support"] and x.help > 0:
        return "hỗ trợ đồng đội", "hỗ trợ"
    out = float(x.per_cast) if x is not None else 0.0
    steps = [st for st in a.get("steps", []) if not str(st.get("affects", "enemies")).startswith("allies")
             and st.get("area") != "self" and any(e.get("type") in ("damage", "drain", "status") for e in st.get("effects", []))]
    if steps and not a.get("script"):
        near = [st for st in steps if st.get("area") in ("adjacent", "radius", "square", "cone") and st.get("origin", "caster") != "focus"]
        if a.get("dash") and steps and all(st.get("area") == "path" for st in steps):
            return "lao qua địch", "lao"
        if near and len(near) == len(steps):
            return "quanh mình", "tại chỗ"
        return "tung vào mục tiêu" if all(st.get("area") in THROWN or st.get("origin") == "focus" for st in steps) else "hỗn hợp", "tung"
    if x is None:
        return "—", "—"
    if out <= 0 and x.cc > 0:
        return "khống chế (không sát thương)", "tung" if x.reach >= ra.RULES["casterReach"] else "tại chỗ"
    if out <= 0:
        if x.spawn > 0:
            return "triệu hồi", "—"
        if x.self_buff > 0 or x.sustain > 0:
            return "buff / hồi bản thân", "—"
        return "không thấy tác động khi thử", "—"
    if x.engage >= ra.RULES["assassinEngage"]:
        return "lao vào địch", "lao"
    if x.reach < ra.RULES["casterReach"] or x.back_ratio < ra.RULES["backShare"]:
        return "quanh mình / phải đứng gần", "tại chỗ"
    return "tung vào mục tiêu", "tung"
#endregion


#region where to edit
def line_index():
    lines = {}
    for i, l in enumerate(io.open(os.path.join(ROOT, "data", "abilities.json"), encoding="utf-8")):
        m = re.match(r'\s*"([A-Z0-9_]+)": \{', l)
        if m:
            lines.setdefault(("data", m.group(1)), i + 1)
    for i, l in enumerate(io.open(os.path.join(ROOT, "src", "core", "ability_scripts.gd"), encoding="utf-8")):
        m = re.match(r"static func ([a-z0-9_]+)\(", l)
        if m:
            lines[("script", m.group(1))] = i + 1
    return lines
#endregion


def build():
    if not os.path.exists(ROLES_TSV):
        raise SystemExit("skill_list: no build/roles/roles.tsv (run tools\\role_audit.bat)")
    roles = pd.read_csv(ROLES_TSV, sep="\t", na_filter=False)
    for c in roles.columns:
        if c not in ("pkm", "family", "rarity", "types", "skill", "role", "form_role", "suggested", "why", "flag"):
            roles[c] = pd.to_numeric(roles[c], errors="coerce").fillna(0.0)
    roles = roles.set_index("pkm", drop=False)
    roles.index.name = None
    rost = ra.rosters()
    season_of = {}
    for sid, fams in rost.items():
        if sid == "all":
            continue
        for fam in fams:
            for f in ra.family_forms(fam):
                season_of.setdefault(f, []).append(sid)
    in_game = set(f for fams in rost.values() for fam in fams for f in ra.family_forms(fam))
    balance = ab.load_balance()["pokemon"]
    lines = line_index()
    skills = []
    users = {}
    for pkm, d in ra.POKEMON.items():
        if d.get("skill") in ABILITIES and pkm in roles.index:
            users.setdefault(d["skill"], []).append(pkm)
    for sid, forms in sorted(users.items()):
        a = ABILITIES[sid]
        forms = sorted(forms, key=lambda p: (p not in in_game, -int(ra.POKEMON[p].get("stars", 1)), p))
        main = forms[0]
        x = roles.loc[main]
        how, throw = landing(a, x)
        script = a.get("script", "")
        edit = ("src/core/ability_scripts.gd", lines.get(("script", script), 1)) if script else \
            ("data/abilities.json", lines.get(("data", sid), 1))
        rows = []
        for p in forms:
            y = roles.loc[p]
            e = ab.entry_of(balance.get(p, 1.0))
            now = ab.realized(p, e)
            rows.append({"pkm": p, "name": pkm_name(p), "idx": ra.POKEMON[p].get("index", ""), "stars": int(y.stars),
                         "rarity": y.rarity, "role": y.role, "suggested": y.suggested, "flag": y.flag,
                         "pp_web": int(y.maxPP), "pp": int(now["pp"]), "strength": round(100 * now["skill"]),
                         "front": int(round(y.front_out)), "back": int(round(y.back_out)), "front_hit": int(y.front_hit),
                         "back_hit": int(y.back_hit), "reach": int(y.reach), "share": round(100 * y.share),
                         "help": int(round(y.help)), "cc": int(y.cc), "dash": int(y.dash), "types": y.types.split(","),
                         "seasons": sorted(season_of.get(p, [])), "in_game": p in in_game})
        skills.append({
            "id": sid, "name": ability_name(sid), "en": a.get("name", sid), "desc": ability_desc(sid),
            "shape": data_shape(a) if not script else "", "script": script, "how": how, "throw": throw,
            "edit": "%s:%d" % edit, "role": x.role, "suggested": x.suggested, "rarity": x.rarity,
            "types": sorted(set(t for r in rows for t in r["types"] if t)),
            "seasons": sorted(set(s for r in rows for s in r["seasons"])), "in_game": any(r["in_game"] for r in rows),
            "forms": rows,
        })
    return skills


def md_cell(text):
    return str(text).replace("|", "\\|").replace("\n", " ")


def write_md(skills):
    L = []
    say = L.append
    game = [s for s in skills if s["in_game"]]
    say("# Danh sách skill Pokémon")
    say("")
    say("*Sinh bằng `python tools/roles/skill_list.py` (sau `tools\\role_audit.bat`); đừng sửa tay. Bản lọc / sắp xếp có ảnh: "
        "[`docs/skills.html`](skills.html) (mở bằng trình duyệt).*")
    say("")
    say("Mỗi skill một dòng, xếp theo vai trò hiện tại của Pokémon dùng nó (dạng có nhiều sao nhất trong game). **Kiểu**: skill "
        "rơi ở đâu (bước data của `data/abilities.json`; skill viết bằng code thì theo probe). **Tung / tại chỗ**: *tung* = "
        "dùng từ hàng cuối vẫn trúng (vào mục tiêu, đường thẳng, toàn sàn...), *tại chỗ* = chỉ trúng quanh mình / khi đứng gần "
        "(probe: tầm < %d ô hoặc từ hàng cuối còn < %d%% sát thương). **ST/lần**: sát thương một lần dùng lên 7 địch thử (không "
        "DEF, không item, chỉ số web), đứng hàng đầu / hàng cuối, số địch trúng trong ngoặc. **PP** web → hiện tại (tự cân "
        "bằng), **Sức mạnh** = × sát thương / hồi / khiên của skill (tự cân bằng). **Sửa ở**: dòng định nghĩa skill."
        % (ra.RULES["casterReach"], round(100 * ra.RULES["backShare"])))
    say("")
    say("%d skill (%d có Pokémon trong game)." % (len(skills), len(game)))
    say("")
    kinds = ["tung", "tại chỗ", "lao", "hỗ trợ", "—"]
    rows = []
    for role in ra.ORDER:
        sub = [s for s in game if s["role"] == role]
        rows.append([ra.vi_role(role), len(sub)] + [sum(s["throw"] == k for s in sub) for k in kinds])
    say(ra.md_table(["Vai trò hiện tại", "Skill", "Tung", "Tại chỗ", "Lao", "Hỗ trợ", "Không sát thương"], rows))
    say("")
    for role in ra.ORDER:
        sub = sorted([s for s in game if s["role"] == role], key=lambda s: (s["throw"] != "tại chỗ", s["name"]))
        if not sub:
            continue
        say("## %s (%d skill)" % (ra.vi_role(role), len(sub)))
        say("")
        rows = []
        for s in sub:
            f = s["forms"][0]
            who = ", ".join("%s %d★" % (r["name"], r["stars"]) for r in s["forms"] if r["in_game"])
            sug = "" if s["suggested"] == s["role"] else " → %s" % ra.vi_role(s["suggested"])
            kind = s["shape"] or ("code: " + s["how"])
            rows.append(["**%s** `%s`" % (s["name"], s["id"]), md_cell(who) + sug, md_cell(kind), s["throw"], md_cell(s["desc"]),
                         "%d→%d" % (f["pp_web"], f["pp"]), "%d%%" % f["strength"],
                         "%d (%d) / %d (%d)" % (f["front"], f["front_hit"], f["back"], f["back_hit"]),
                         "[%s](../%s)" % (s["edit"], s["edit"].replace(":", "#L"))])
        say(ra.md_table(["Skill", "Pokémon (→ vai trò gợi ý)", "Kiểu", "Tung / tại chỗ", "Mô tả", "PP", "Sức mạnh",
                         "ST/lần đầu / cuối (trúng)", "Sửa ở"], rows))
        say("")
    io.open(MD, "w", encoding="utf-8", newline="\n").write("\n".join(L) + "\n")


HTML = r"""<!DOCTYPE html>
<html lang="vi"><head><meta charset="utf-8"><title>Skill Pokémon — pkmxtft</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
:root{--bg:#14161c;--panel:#1d2029;--line:#2c303c;--text:#e6e6ea;--dim:#9aa0ad;--gold:#ffd24d;--accent:#7fd0ff;--bad:#ff8a7a}
*{box-sizing:border-box}body{margin:0;font:13px/1.45 system-ui,"Segoe UI",sans-serif;background:var(--bg);color:var(--text);display:flex;height:100vh}
#side{width:300px;flex:none;overflow:auto;border-right:1px solid var(--line);padding:12px;background:var(--panel)}
#main{flex:1;overflow:auto;padding:10px 14px}
h1{font-size:17px;margin:0 0 6px}h2{font-size:12px;text-transform:uppercase;color:var(--dim);margin:12px 0 4px;letter-spacing:.05em}
input[type=search],select{width:100%;padding:6px 8px;background:#11131a;color:var(--text);border:1px solid var(--line);border-radius:6px;margin:2px 0}
.small{color:var(--dim);font-size:12px}.chk{display:inline-flex;gap:3px;align-items:center;margin:0 8px 2px 0;font-size:12px;color:var(--dim)}
table{border-collapse:collapse;width:100%}th,td{border-bottom:1px solid var(--line);padding:4px 6px;vertical-align:top;text-align:left}
th{position:sticky;top:0;background:#191c24;cursor:pointer;white-space:nowrap;font-weight:600;color:var(--dim)}th:hover{color:var(--text)}
tr.s:hover{background:#1c2030}tr.s{cursor:pointer}td.n{text-align:right;font-variant-numeric:tabular-nums;white-space:nowrap}
img{width:32px;height:32px;image-rendering:pixelated;background:#0d0f14;border-radius:4px}
.name{font-weight:600}.id{color:var(--dim);font-size:11px}.desc{max-width:420px}.who{max-width:220px;font-size:12px}
.b{display:inline-block;font-size:11px;padding:0 6px;border-radius:9px;margin:1px 2px 0 0;background:#2a3142;color:var(--accent)}
.t-tung{color:#8fe08f}.t-tại{color:var(--bad);font-weight:600}.t-lao{color:#c7a0ff}.t-hỗ{color:#7fd0ff}
tr.d td{background:#171a22;font-size:12px}tr.d table td,tr.d table th{padding:2px 6px;position:static}
code{color:var(--gold)}
</style></head><body>
<div id="side">
<h1>Skill Pokémon</h1>
<div class="small">Bấm tiêu đề cột để sắp xếp, bấm một dòng để xem từng dạng. Sinh bởi tools/roles/skill_list.py.</div>
<h2>Tìm</h2><input type="search" id="q" placeholder="Tên skill / Pokémon / mô tả...">
<h2>Vai trò hiện tại</h2><div id="roles"></div>
<h2>Vai trò gợi ý</h2><select id="sug"></select>
<h2>Tung / tại chỗ</h2><div id="throws"></div>
<h2>Hệ / mùa / độ hiếm</h2><select id="type"></select><select id="season"></select><select id="rarity"></select>
<h2>Khác</h2><label class="chk"><input type="checkbox" id="game" checked>chỉ Pokémon có trong game</label>
<label class="chk"><input type="checkbox" id="code">chỉ skill viết bằng code</label>
<label class="chk"><input type="checkbox" id="changed">vai trò gợi ý khác hiện tại</label>
<div class="small" id="count"></div>
</div>
<div id="main"><table><thead><tr id="head"></tr></thead><tbody id="body"></tbody></table></div>
<script>
const DATA = __DATA__;
const $ = id => document.getElementById(id);
function h(tag, props, ...kids) { const e = document.createElement(tag); Object.assign(e, props || {}); for (const k of kids) if (k != null) e.append(k); return e; }
const ROLE = DATA.roles, THROWS = ["tung", "tại chỗ", "lao", "hỗ trợ", "—"];
for (const r of Object.keys(ROLE)) $('roles').append(h('label', {className: 'chk'}, h('input', {type: 'checkbox', checked: true, value: r, onchange: render}), ROLE[r]));
for (const t of THROWS) $('throws').append(h('label', {className: 'chk'}, h('input', {type: 'checkbox', checked: true, value: t, onchange: render}), t));
$('sug').append(h('option', {value: '', textContent: 'Mọi vai trò'}), ...Object.keys(ROLE).map(r => h('option', {value: r, textContent: ROLE[r]})));
const types = [...new Set(DATA.skills.flatMap(s => s.types))].sort();
$('type').append(h('option', {value: '', textContent: 'Mọi hệ'}), ...types.map(t => h('option', {value: t, textContent: DATA.syn[t] || t})));
$('season').append(h('option', {value: '', textContent: 'Mọi mùa'}), ...DATA.seasons.map(s => h('option', {value: s.id, textContent: s.name})));
$('rarity').append(h('option', {value: '', textContent: 'Mọi độ hiếm'}), ...DATA.rarities.map(r => h('option', {value: r, textContent: r})));
for (const id of ['q', 'sug', 'type', 'season', 'rarity', 'game', 'code', 'changed']) $(id).addEventListener('input', render);
for (const s of DATA.skills) s.search = [s.name, s.en, s.id, s.desc, s.shape, s.how, ...s.forms.map(f => f.name + ' ' + f.pkm)].join(' ').toLowerCase();
const COLS = [
  ['', s => '', null], ['Skill', s => s.name, (s, td) => td.append(h('div', {className: 'name', textContent: s.name}), h('div', {className: 'id', textContent: s.id + (s.script ? ' (code)' : '')}))],
  ['Pokémon', s => s.forms[0].name, (s, td) => { td.className = 'who'; for (const f of s.forms.filter(f => f.in_game || !$('game').checked)) td.append(h('div', {textContent: f.name + ' ' + f.stars + '★ · ' + ROLE[f.role] + (f.suggested !== f.role ? ' → ' + ROLE[f.suggested] : '')})); }],
  ['Tung / tại chỗ', s => s.throw, (s, td) => td.append(h('span', {className: 't-' + s.throw.split(' ')[0], textContent: s.throw}))],
  ['Kiểu', s => s.shape || s.how, (s, td) => { td.className = 'desc'; td.textContent = s.shape || ('(code) ' + s.how); }],
  ['Mô tả', s => s.desc, (s, td) => { td.className = 'desc'; td.textContent = s.desc; }],
  ['PP', s => s.forms[0].pp, (s, td) => { td.className = 'n'; td.textContent = s.forms[0].pp_web + '→' + s.forms[0].pp; }],
  ['Sức mạnh', s => s.forms[0].strength, (s, td) => { td.className = 'n'; td.textContent = s.forms[0].strength + '%'; }],
  ['ST đầu', s => s.forms[0].front, (s, td) => { td.className = 'n'; td.textContent = s.forms[0].front + ' (' + s.forms[0].front_hit + ')'; }],
  ['ST cuối', s => s.forms[0].back, (s, td) => { td.className = 'n'; td.textContent = s.forms[0].back + ' (' + s.forms[0].back_hit + ')'; }],
  ['Tầm', s => s.forms[0].reach, (s, td) => { td.className = 'n'; td.textContent = s.forms[0].reach; }],
  ['Skill %', s => s.forms[0].share, (s, td) => { td.className = 'n'; td.textContent = s.forms[0].share + '%'; }],
  ['Sửa ở', s => s.edit, (s, td) => td.append(h('code', {textContent: s.edit}))],
];
let sortKey = 3, sortDir = 1;
COLS.forEach(([label], i) => $('head').append(h('th', {textContent: label, onclick: () => { sortDir = sortKey === i ? -sortDir : 1; sortKey = i; render(); }})));
function details(s) {
  const t = h('table', {});
  t.append(h('tr', {}, ...['Dạng', 'Sao', 'Độ hiếm', 'Vai trò', 'Gợi ý', 'PP', 'Sức mạnh', 'ST đầu (trúng)', 'ST cuối (trúng)', 'Tầm', 'Skill %', 'Hỗ trợ', 'Khống chế', 'Lao', 'Mùa'].map(x => h('th', {textContent: x}))));
  for (const f of s.forms) t.append(h('tr', {}, ...[f.name + (f.in_game ? '' : ' (ngoài game)'), f.stars, f.rarity, ROLE[f.role], ROLE[f.suggested] + (f.flag === 'inplace' ? ' ⚠ tại chỗ' : ''), f.pp_web + '→' + f.pp,
    f.strength + '%', f.front + ' (' + f.front_hit + ')', f.back + ' (' + f.back_hit + ')', f.reach, f.share + '%', f.help, f.cc, f.dash, f.seasons.join(', ')].map(x => h('td', {textContent: x}))));
  const td = h('td', {colSpan: COLS.length}, t);
  if (s.shape) td.append(h('div', {className: 'small', textContent: 'Bước data: ' + s.shape}));
  td.append(h('div', {className: 'small', textContent: 'Tên tiếng Anh: ' + s.en + ' · sửa ở ' + s.edit}));
  return h('tr', {className: 'd'}, td);
}
const open = new Set();
function render() {
  const q = $('q').value.trim().toLowerCase(), sug = $('sug').value, type = $('type').value, season = $('season').value, rarity = $('rarity').value;
  const roles = [...$('roles').querySelectorAll('input')].filter(b => b.checked).map(b => b.value);
  const throws = [...$('throws').querySelectorAll('input')].filter(b => b.checked).map(b => b.value);
  const list = DATA.skills.filter(s => (!$('game').checked || s.in_game) && roles.includes(s.role) && throws.includes(s.throw)
    && (!sug || s.suggested === sug) && (!type || s.types.includes(type)) && (!season || s.seasons.includes(season))
    && (!rarity || s.forms.some(f => f.rarity === rarity)) && (!$('code').checked || s.script) && (!$('changed').checked || s.suggested !== s.role)
    && (!q || s.search.includes(q)));
  const key = COLS[sortKey][1];
  list.sort((a, b) => { const x = key(a), y = key(b); return (typeof x === 'number' ? x - y : String(x).localeCompare(String(y))) * sortDir; });
  $('count').textContent = list.length + ' skill';
  const body = $('body'); body.textContent = '';
  for (const s of list) {
    const tr = h('tr', {className: 's', onclick: () => { open.has(s.id) ? open.delete(s.id) : open.add(s.id); render(); }});
    for (const [label, , fill] of COLS) {
      const td = h('td', {});
      if (!label) { const f = s.forms[0]; if (DATA.pics[f.idx]) td.append(h('img', {src: 'data:image/png;base64,' + DATA.pics[f.idx], title: f.name})); }
      else fill(s, td);
      tr.append(td);
    }
    body.append(tr);
    if (open.has(s.id)) body.append(details(s));
  }
}
render();
</script></body></html>
"""


def write_html(skills):
    pics = {}
    for s in skills:
        idx = s["forms"][0]["idx"]
        for name in (idx, idx.split("-")[0]):
            png = os.path.join(ROOT, "assets", "portraits", name + ".png")
            if idx not in pics and os.path.exists(png):
                pics[idx] = base64.b64encode(io.open(png, "rb").read()).decode("ascii")
    data = {"skills": skills, "pics": pics, "roles": {r: ra.vi_role(r) for r in ra.ORDER},
            "syn": {k: ra.vi_syn(k) for k in ra.RULES["synergies"]},
            "seasons": [{"id": s["id"], "name": s.get("name", s["id"])} for s in ra.SEASONS.get("seasons", [])],
            "rarities": [r for r in RARITY_ORDER if any(f["rarity"] == r for s in skills for f in s["forms"])]}
    blob = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    io.open(HTML_OUT, "w", encoding="utf-8", newline="\n").write(HTML.replace("__DATA__", blob))


def main():
    skills = build()
    write_md(skills)
    write_html(skills)
    game = [s for s in skills if s["in_game"]]
    by = {}
    for s in game:
        by[s["throw"]] = by.get(s["throw"], 0) + 1
    casters = [s for s in game if s["role"] == "caster"]
    print("skill list: %d skills (%d in the game) -> %s, %s" % (len(skills), len(game), os.path.relpath(MD, ROOT),
                                                                os.path.relpath(HTML_OUT, ROOT)))
    print("in the game: " + ", ".join("%s %d" % kv for kv in sorted(by.items(), key=lambda kv: -kv[1])))
    print("casters now: %d skills, %d thrown, %d in place" % (len(casters), sum(s["throw"] == "tung" for s in casters),
                                                             sum(s["throw"] == "tại chỗ" for s in casters)))


if __name__ == "__main__":
    main()
