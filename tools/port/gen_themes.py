"""Điểm chung (theme) của các họ Pokémon trong game -> docs/THEMES.md + docs/themes.html.

Nguồn: tools/port/themes/themes.txt (danh sách điểm chung), tools/port/themes/pokemon_*.txt (tag + ghi chú của
từng họ), tools/port/themes/genus_en.txt (category Pokédex, PokéAPI), data/pac/pokemon.json + pool.json
(họ, dạng, hệ, độ hiếm) và data/seasons.json (họ thuộc mùa nào).

    python tools/port/gen_themes.py          # kiểm + ghi docs/THEMES.md và docs/themes.html

Dòng của một họ: `HỌ | tag tag? ... | ghi chú`; `HỌ*` = mọi họ bắt đầu bằng HỌ (biến thể màu / mùa...);
`tag?` = gần đúng (liệt kê riêng, viewer có ô "gần đúng"). Không phải dữ liệu game: không file nào của game đọc nó.
"""
import glob
import io
import json
import os
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SRC = os.path.join(ROOT, "tools", "port", "themes")
LISTS = ["pool", "additional", "regional", "unique", "legendary", "hatch"]
RARITIES = ["COMMON", "UNCOMMON", "RARE", "EPIC", "ULTRA", "UNIQUE", "LEGENDARY", "HATCH", "SPECIAL"]
SHORT = {"COMMON": "C", "UNCOMMON": "U", "RARE": "R", "EPIC": "E", "ULTRA": "UL", "UNIQUE": "Unq",
         "LEGENDARY": "Leg", "HATCH": "Trứng", "SPECIAL": "Sp"}
GROUPS = [("animal", "Tộc — con vật gốc"), ("role", "Hệ — vai trò / nghề"), ("lore", "Truyền thuyết & văn hoá"),
          ("world", "Đồ vật & thế giới")]


def read(path):
    return io.open(path, encoding="utf-8").read()


def rows(path):
    for line in read(path).splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            yield [part.strip() for part in line.split("|")]


def title(s):
    return s.replace("_", " ").title()


def load():
    pk = json.loads(read(os.path.join(ROOT, "data", "pac", "pokemon.json")))
    pool = json.loads(read(os.path.join(ROOT, "data", "pac", "pool.json")))
    seasons = json.loads(read(os.path.join(ROOT, "data", "seasons.json")))
    text = json.loads(read(os.path.join(ROOT, "data", "pac", "text.json")))
    names = text.get("pkm", {}) if isinstance(text.get("pkm"), dict) else {}
    genus = {}
    for line in read(os.path.join(SRC, "genus_en.txt")).splitlines():
        if line and not line.startswith("#"):
            for item in line.split("|"):
                num, _, g = item.partition(":")
                genus[int(num)] = g
    themes = []
    for r in rows(os.path.join(SRC, "themes.txt")):
        themes.append({"id": r[0], "vi": r[1], "en": r[2], "group": r[3], "desc": r[4] if len(r) > 4 else ""})
    entries = []
    for path in sorted(glob.glob(os.path.join(SRC, "pokemon_*.txt"))):
        for r in rows(path):
            r += [""] * (3 - len(r))
            entries.append({"key": r[0], "tags": r[1].split(), "note": r[2], "file": os.path.basename(path)})
    return pk, pool, seasons, names, genus, themes, entries


def build():
    pk, pool, seasons, names, genus, themes, entries = load()
    problems = []
    known = {t["id"] for t in themes}
    # families of the obtainable lists
    fams = {}
    for name, d in pk.items():
        fams.setdefault(d.get("family", name), []).append(name)
    lists_of = {}
    for key in LISTS:
        for n in pool.get(key, []):
            if n in pk:
                lists_of.setdefault(pk[n].get("family", n), set()).add(key)
    season_of = {}
    for s in seasons.get("seasons", []):
        members = [n for r in s.get("shop", {}).values() for n in r]
        members += s.get("unique", []) + s.get("legendary", []) + s.get("hatch", [])
        for n in members:
            season_of.setdefault(pk[n].get("family", n) if n in pk else n, set()).add(s["id"])
    families = []
    for fam in sorted(lists_of):
        forms = sorted(fams.get(fam, [fam]), key=lambda n: (pk[n].get("stars", 1), n))
        first = pk.get(fam, pk[forms[0]])
        types = []
        for n in forms:
            for t in pk[n].get("types", []):
                if t not in types:
                    types.append(t)
        by_star = {}
        for n in forms:
            by_star.setdefault(pk[n].get("stars", 1), []).append(names.get(n) or title(n))
        families.append({
            "id": fam, "name": names.get(fam) or title(fam), "rarity": first.get("rarity", ""), "types": types,
            "chain": " → ".join(" / ".join(v) for _, v in sorted(by_star.items())),
            "forms": [{"name": names.get(n) or title(n), "idx": pk[n].get("index", ""),
                       "genus": genus.get(int(pk[n]["index"][:4]), "") if pk[n].get("index", "")[:4].isdigit() else ""}
                      for n in forms],
            "lists": sorted(lists_of[fam]), "seasons": sorted(season_of.get(fam, [])),
            "tags": [], "near": [], "note": ""})
    # entries -> families (exact key first, then KEY* prefix)
    by_id = {f["id"]: f for f in families}
    used = set()
    for e in entries:
        for t in e["tags"]:
            if t.rstrip("?") not in known:
                problems.append("%s: %s: tag lạ '%s'" % (e["file"], e["key"], t))
        if e["key"].endswith("*"):
            targets = [f for f in families if f["id"].startswith(e["key"][:-1])]
        else:
            targets = [by_id[e["key"]]] if e["key"] in by_id else []
        if not targets:
            problems.append("%s: %s không phải họ nào trong game" % (e["file"], e["key"]))
        for f in targets:
            if f["id"] in used and not e["key"].endswith("*"):
                problems.append("%s: %s ghi hai lần" % (e["file"], e["key"]))
            if f["id"] in used:
                continue
            used.add(f["id"])
            f["tags"] = [t for t in e["tags"] if not t.endswith("?") and t in known]
            f["near"] = [t[:-1] for t in e["tags"] if t.endswith("?") and t[:-1] in known]
            f["note"] = e["note"]
    missing = [f["id"] for f in families if f["id"] not in used]
    if missing:
        problems.append("%d họ chưa có dòng: %s" % (len(missing), ", ".join(missing)))
    # theme statistics
    for t in themes:
        members = [f for f in families if t["id"] in f["tags"]]
        near = [f for f in families if t["id"] in f["near"]]
        t["count"], t["near_count"] = len(members), len(near)
        t["members"], t["near_members"] = [f["id"] for f in members], [f["id"] for f in near]
        t["by_rarity"] = {r: sum(1 for f in members if f["rarity"] == r) for r in RARITIES}
        types = {}
        for f in members:
            for ty in f["types"]:
                types[ty] = types.get(ty, 0) + 1
        t["types"] = sorted(types.items(), key=lambda kv: (-kv[1], kv[0]))[:3]
        with_ = {}
        for f in members:
            for o in f["tags"]:
                if o != t["id"]:
                    with_[o] = with_.get(o, 0) + 1
        t["with"] = sorted(with_.items(), key=lambda kv: (-kv[1], kv[0]))[:3]
        t["seasons"] = {s["id"]: sum(1 for f in members if s["id"] in f["seasons"]) for s in seasons.get("seasons", [])}
    return families, themes, problems, seasons


def fmt_count(t):
    return "%d" % t["count"] + (" (+%d?)" % t["near_count"] if t["near_count"] else "")


def write_md(families, themes, seasons, path):
    tid = {t["id"]: t for t in themes}
    fid = {f["id"]: f for f in families}
    order = sorted(themes, key=lambda t: (-t["count"], t["id"]))
    season_ids = [s["id"] for s in seasons.get("seasons", [])]
    out = []
    w = out.append
    w("# Điểm chung của Pokémon — nguyên liệu dựng hệ mới theo mùa")
    w("")
    w("> Sinh bằng `python tools/port/gen_themes.py` từ `tools/port/themes/` — **đừng sửa tay file này**. Bản xem có ảnh,")
    w("> lọc theo điểm chung / độ hiếm / mùa / hệ và nút chép danh sách: [`docs/themes.html`](themes.html) (mở bằng trình duyệt).")
    w("")
    w("Mục đích (yêu cầu 2026-11-16): thêm các hệ *khác đại trà* — kiểu Human, Gourmet — như Y tế, Vận chuyển, Trâu bò,")
    w("Ngựa…, rồi đưa vào từng mùa (`docs/SEASONS.md`). File này gom **điểm chung** của **%d họ** Pokémon đang có trong" % len(families))
    w("game (shop, Unique, Legendary, trứng): mỗi họ có thể có nhiều điểm chung; danh sách xếp theo số họ.")
    w("")
    w("**Nguồn:**")
    w("")
    w("- Cột *Pokédex*: category chính thức (tiếng Anh) từ dữ liệu PokéAPI (`pokemon_species_names.csv`), lưu ở")
    w("  `tools/port/themes/genus_en.txt` — vd Lapras là *Transport*, Miltank *Milk Cow*, Mudsdale *Draft Horse*.")
    w("- *Ghi chú* và *điểm chung*: Claude tóm tắt từ lore Pokédex / thiết kế của từng loài (viết lại, không chép nguyên")
    w("  văn; Bulbapedia chặn bot nên không đọc được từng trang). Tag có dấu `?` = **gần đúng** / tuỳ cách hiểu. Trước khi")
    w("  chốt một hệ, nên xem lại các họ trong đó (ảnh và ghi chú ở viewer).")
    w("- Sửa / thêm: chỉnh `tools/port/themes/themes.txt` (điểm chung) hoặc `pokemon_*.txt` (tag của họ) rồi chạy lại script.")
    w("")
    w("## 1. Tham khảo: cách TFT Set 19 xếp hệ (op.gg)")
    w("")
    w("Set 19 *Prismatic Tour* (chủ đề âm nhạc) có khoảng 94 tướng (tính cả biến thể), **14 Tộc (origin) + 15 Hệ (class)**.")
    w("Mỗi tướng thường có **1 Tộc + 1 Hệ** (vd Draven: Illbeats + Trickshot, Ashe: Beach Pop + Swiftstriker, Elise: Ionic")
    w("Spark + Frontman); nhiều tướng đắt có **hệ độc nhất** (1 tướng, cơ chế riêng). Các cỡ hệ hay gặp:")
    w("")
    w("| Loại | Số tướng | Mốc | Ví dụ |")
    w("|---|---|---|---|")
    w("| Hệ lớn (vai trò) | 7–10 | 2/4/6 | Arcanist, Bodyguard, Frontman, Juggernaut, Slayer |")
    w("| Tộc vừa (nhóm nhạc) | 6–8 | 3/5/7 | Beach Pop, Pentakill, Heartsteel, Rock |")
    w("| Hệ nhỏ | 3–6 | 2/3/4 (đến 5) | Jazz, Gu Feng, Manager, Prodigy, Renegade |")
    w("| Độc nhất | 1 | 1 | Country, Disco, Emo, Goth, Mariachi… (khoảng 15 hệ) |")
    w("| Siêu hệ | ~8 | nhiều mốc (3/5/7/10…) | K/DA, Ionic Spark |")
    w("")
    w("Áp vào game này: các hệ có sẵn (Fire, Water…) đóng vai **Tộc**; điểm chung ở đây hợp làm **Hệ theo chủ đề** — mỗi")
    w("mùa thêm vài hệ mới, Pokémon của mùa mang hệ gốc + một hệ mới. Luật mùa hiện tại (hệ đại trà 8–10 họ, hệ đặc biệt")
    w("3–5 họ + mốc riêng) khớp với *Hệ lớn* và *Hệ nhỏ*; điểm chung chỉ có 1–2 họ có thể làm **hệ độc nhất** cho một")
    w("Unique / Legendary. Lưu ý: game chưa có hệ nào trong số này — mỗi hệ mới cần hiệu ứng, icon, mốc, chữ 14 ngôn ngữ.")
    w("")
    w("## 2. Gợi ý ghép mùa (số = số họ khớp, `+n?` = thêm n họ gần đúng)")
    w("")
    ideas = [
        ("Nông trại & thảo nguyên", ["farm", "horse", "bovine", "goat", "pig", "transport"]),
        ("Thành phố & nghề nghiệp", ["medic", "transport", "worker", "guardian", "urban", "food"]),
        ("12 con giáp", ["rodent", "bovine", "tiger", "cat", "snake", "horse", "goat", "monkey", "fowl", "dog", "pig"]),
        ("Truyện cổ phương Đông", ["folklore", "myth", "ninja", "knight", "royal"]),
        ("Kho báu & cổ vật", ["treasure", "relic", "desert", "rogue", "miner"]),
        ("Vũ trụ & giấc mơ", ["space", "dream", "magic", "weather"]),
        ("Biển cả", ["sea_mammal", "crab", "waterbird", "octopus", "turtle", "transport"]),
        ("Rạp xiếc & sân đấu", ["artist", "sport", "magic", "food"]),
    ]
    for name, ids in ideas:
        w("- **%s**: %s." % (name, ", ".join("%s `%s` %s" % (tid[i]["vi"], i, fmt_count(tid[i])) for i in ids if i in tid)))
    w("")
    w("12 con giáp: Thìn (rồng) dùng hệ Dragon có sẵn; trâu bò và gà ít họ — gộp cả mười hai thành một hệ \"Con giáp\"")
    w("lớn, hoặc mỗi con một hệ nhỏ 2/3/4 và bỏ các con thiếu họ.")
    w("")
    w("## 3. Bảng tổng (xếp theo số họ)")
    w("")
    w("| Điểm chung | id | Nhóm | Số họ | Theo độ hiếm | Hệ có sẵn hay gặp | Hay đi cùng | Trong mùa %s |" % "/".join(season_ids))
    w("|---|---|---|---|---|---|---|---|")
    gname = dict(GROUPS)
    for t in order:
        rar = " ".join("%s%d" % (SHORT[r], n) for r, n in t["by_rarity"].items() if n)
        w("| %s | `%s` | %s | %s | %s | %s | %s | %s |" % (
            t["vi"], t["id"], gname.get(t["group"], t["group"]).split(" — ")[0], fmt_count(t), rar,
            ", ".join("%s %d" % (title(k), v) for k, v in t["types"]),
            ", ".join("%s %d" % (k, v) for k, v in t["with"]),
            "/".join(str(t["seasons"].get(s, 0)) for s in season_ids)))
    w("")
    w("## 4. Từng điểm chung")
    w("")
    for group, label in GROUPS:
        w("### %s" % label)
        w("")
        for t in sorted((t for t in themes if t["group"] == group), key=lambda t: (-t["count"], t["id"])):
            w("#### %s — `%s` (%s)" % (t["vi"], t["id"], fmt_count(t)))
            w("")
            w("*%s* — %s" % (t["en"], t["desc"]))
            w("")
            for r in RARITIES:
                members = [fid[i] for i in t["members"] if fid[i]["rarity"] == r]
                if members:
                    w("- %s: %s" % (title(r), ", ".join("%s (%s)" % (f["name"], "/".join(title(x) for x in f["types"])) for f in members)))
            if t["near_members"]:
                w("- *Gần đúng*: %s" % ", ".join(fid[i]["name"] for i in t["near_members"]))
            w("")
    w("## 5. Từng họ Pokémon (thông tin nền)")
    w("")
    w("Hệ = hệ trong game (gộp mọi dạng). Mùa = mùa có họ đó (`data/seasons.json`). Điểm chung in nghiêng là gần đúng.")
    w("")
    for r in RARITIES:
        members = [f for f in families if f["rarity"] == r]
        if not members:
            continue
        w("### %s (%d họ)" % (title(r), len(members)))
        w("")
        w("| Họ | Pokédex | Hệ | Mùa | Điểm chung | Ghi chú |")
        w("|---|---|---|---|---|---|")
        for f in members:
            gen = []
            for form in f["forms"]:
                if form["genus"] and form["genus"] not in gen:
                    gen.append(form["genus"])
            tags = ", ".join([tid[x]["vi"] for x in f["tags"]] + ["*%s*" % tid[x]["vi"] for x in f["near"]])
            w("| **%s** | %s | %s | %s | %s | %s |" % (f["chain"], " / ".join(gen), ", ".join(title(x) for x in f["types"]),
                                                    ", ".join(f["seasons"]), tags, f["note"].replace("|", "/")))
        w("")
    io.open(path, "w", encoding="utf-8", newline="\n").write("\n".join(out))


HTML = r"""<!DOCTYPE html>
<html lang="vi"><head><meta charset="utf-8"><title>Điểm chung Pokémon — pkmxtft</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
:root{--bg:#14161c;--panel:#1d2029;--line:#2c303c;--text:#e6e6ea;--dim:#9aa0ad;--gold:#ffd24d;--accent:#7fd0ff}
*{box-sizing:border-box}body{margin:0;font:14px/1.45 system-ui,"Segoe UI",sans-serif;background:var(--bg);color:var(--text);display:flex;height:100vh}
#side{width:330px;flex:none;overflow:auto;border-right:1px solid var(--line);padding:12px;background:var(--panel)}
#main{flex:1;overflow:auto;padding:12px 16px}
h1{font-size:17px;margin:0 0 6px}h2{font-size:12px;text-transform:uppercase;color:var(--dim);margin:14px 0 4px;letter-spacing:.05em}
input[type=search],select{width:100%;padding:6px 8px;background:#11131a;color:var(--text);border:1px solid var(--line);border-radius:6px}
.theme{display:flex;justify-content:space-between;gap:6px;padding:2px 8px;margin:1px 0;border-radius:6px;cursor:pointer;border:1px solid transparent}
.theme:hover{background:#262a35}.theme.on{border-color:var(--gold);background:#2b2a1f}.theme .n{color:var(--dim);font-variant-numeric:tabular-nums;white-space:nowrap}
.small{color:var(--dim);font-size:12px}.row{display:flex;gap:6px;flex-wrap:wrap;align-items:center;margin:6px 0}
.chk{display:inline-flex;gap:3px;align-items:center;margin-right:6px;font-size:12px;color:var(--dim)}
#info{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:8px 12px;margin-bottom:10px}
#grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:10px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:8px 10px}
.pics{display:flex;gap:2px;float:right;margin-left:6px}.pics img{width:40px;height:40px;image-rendering:pixelated;background:#0d0f14;border-radius:4px}
.name{font-weight:600}.r{font-size:11px;padding:0 6px;border-radius:9px;margin-left:4px;color:#111;font-weight:600}
.sub{color:var(--dim);font-size:12px}.note{margin-top:4px;clear:both}
.tag{display:inline-block;font-size:11px;padding:1px 6px;margin:3px 3px 0 0;border-radius:9px;background:#2a3142;color:var(--accent);cursor:pointer}
.tag.near{background:transparent;border:1px dashed #4a5670;color:var(--dim)}
button{background:#2a3142;color:var(--text);border:1px solid var(--line);border-radius:6px;padding:4px 10px;cursor:pointer}
</style></head><body>
<div id="side">
<h1>Điểm chung Pokémon</h1>
<div class="small">Bấm điểm chung để lọc (bấm nhiều = phải có hết, hoặc chọn "bất kỳ"). Sinh bởi tools/port/gen_themes.py.</div>
<div class="row"><input type="search" id="q" placeholder="Tìm tên, Pokédex, ghi chú..."></div>
<div class="row"><label class="chk"><input type="checkbox" id="near">tính cả gần đúng</label>
<label class="chk"><input type="radio" name="mode" value="and" checked>có hết</label>
<label class="chk"><input type="radio" name="mode" value="or">bất kỳ</label><button id="clear">Bỏ chọn</button></div>
<div class="row" id="rar"></div>
<div class="row"><select id="season"></select><select id="type"></select></div>
<div id="themes"></div>
</div>
<div id="main"><div id="info"></div><div id="grid"></div></div>
<script>
const DATA = __DATA__;
const RCOL = {COMMON:'#c9c9c9',UNCOMMON:'#6fd16f',RARE:'#5aa9ff',EPIC:'#c77dff',ULTRA:'#ff6b6b',UNIQUE:'#ffd24d',LEGENDARY:'#ff9f43',HATCH:'#f8a5c2',SPECIAL:'#9aa0ad'};
const T = Object.fromEntries(DATA.themes.map(t => [t.id, t]));
const sel = new Set();
const $ = id => document.getElementById(id);
function h(tag, props, ...kids) { const e = document.createElement(tag); Object.assign(e, props || {}); for (const k of kids) if (k != null) e.append(k); return e; }
for (const f of DATA.families) f.search = [f.name, f.chain, f.note, ...f.forms.map(x => x.genus), ...f.tags.map(t => T[t].vi), ...f.types].join(' ').toLowerCase();
for (const r of DATA.rarities) { const b = h('input', {type: 'checkbox', checked: true, value: r, onchange: render}); $('rar').append(h('label', {className: 'chk'}, b, r[0] + r.slice(1).toLowerCase())); }
$('season').append(h('option', {value: '', textContent: 'Mọi mùa'}), h('option', {value: 'none', textContent: 'Chưa thuộc mùa nào'}), ...DATA.seasons.map(s => h('option', {value: s.id, textContent: s.id + ' ' + s.name})));
const types = [...new Set(DATA.families.flatMap(f => f.types))].sort();
$('type').append(h('option', {value: '', textContent: 'Mọi hệ có sẵn'}), ...types.map(t => h('option', {value: t, textContent: t})));
for (const id of ['q', 'near', 'season', 'type']) $(id).addEventListener('input', render);
for (const r of document.querySelectorAll('input[name=mode]')) r.addEventListener('change', render);
$('clear').onclick = () => { sel.clear(); render(); };
function toggle(id) { sel.has(id) ? sel.delete(id) : sel.add(id); render(); }
function side() {
  const box = $('themes'); box.textContent = '';
  for (const [g, label] of DATA.groups) {
    box.append(h('h2', {textContent: label}));
    for (const t of DATA.themes.filter(t => t.group === g).sort((a, b) => b.count - a.count || a.id.localeCompare(b.id)))
      box.append(h('div', {className: 'theme' + (sel.has(t.id) ? ' on' : ''), title: t.en + ' — ' + t.desc, onclick: () => toggle(t.id)},
        h('span', {textContent: t.vi}), h('span', {className: 'n', textContent: t.count + (t.near_count ? ' +' + t.near_count + '?' : '')})));
  }
}
function copy(text) {
  if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).catch(() => fallback(text)); else fallback(text);
}
function fallback(text) { const a = h('textarea', {value: text}); document.body.append(a); a.select(); document.execCommand('copy'); a.remove(); }
function render() {
  side();
  const q = $('q').value.trim().toLowerCase(), near = $('near').checked, season = $('season').value, type = $('type').value;
  const mode = document.querySelector('input[name=mode]:checked').value;
  const rar = [...$('rar').querySelectorAll('input')].filter(b => b.checked).map(b => b.value);
  const list = DATA.families.filter(f => {
    if (!rar.includes(f.rarity)) return false;
    if (season === 'none' ? f.seasons.length > 0 : season && !f.seasons.includes(season)) return false;
    if (type && !f.types.includes(type)) return false;
    if (sel.size) { const has = t => f.tags.includes(t) || (near && f.near.includes(t)); if (!(mode === 'and' ? [...sel].every(has) : [...sel].some(has))) return false; }
    return !q || f.search.includes(q);
  });
  const info = $('info'); info.textContent = '';
  if (sel.size === 1) {
    const t = T[[...sel][0]];
    info.append(h('div', {className: 'name', textContent: t.vi + ' (' + t.en + ') — ' + t.count + ' họ' + (t.near_count ? ', ' + t.near_count + ' gần đúng' : '')}),
      h('div', {className: 'sub', textContent: t.desc}),
      h('div', {className: 'sub', textContent: 'Theo độ hiếm: ' + Object.entries(t.by_rarity).filter(e => e[1]).map(e => e[0] + ' ' + e[1]).join(', ') +
        '  •  Hay đi cùng: ' + (t.with.map(e => T[e[0]].vi + ' ' + e[1]).join(', ') || '—')}));
  }
  info.append(h('div', {className: 'row'}, h('span', {textContent: list.length + ' họ'}),
    h('button', {textContent: 'Chép danh sách (id họ)', onclick: () => copy(list.map(f => f.id).join(', '))}),
    h('button', {textContent: 'Chép bảng (tên, độ hiếm, hệ, điểm chung)', onclick: () => copy(list.map(f => [f.name, f.rarity, f.types.join('/'), f.tags.map(t => T[t].vi).join(', ')].join('\t')).join('\n'))})));
  const grid = $('grid'); grid.textContent = '';
  for (const f of list) {
    const pics = h('div', {className: 'pics'});
    const seen = new Set();
    for (const form of f.forms) { if (seen.has(form.idx) || seen.size >= 4) continue; seen.add(form.idx);
      if (DATA.pics[form.idx]) pics.append(h('img', {src: 'data:image/png;base64,' + DATA.pics[form.idx], title: form.name + (form.genus ? ' — ' + form.genus + ' Pokémon' : '')})); }
    const genus = [...new Set(f.forms.map(x => x.genus).filter(Boolean))].join(' / ');
    const tags = h('div', {});
    for (const t of f.tags) tags.append(h('span', {className: 'tag', textContent: T[t].vi, onclick: () => toggle(t)}));
    for (const t of f.near) tags.append(h('span', {className: 'tag near', textContent: T[t].vi + '?', onclick: () => toggle(t)}));
    grid.append(h('div', {className: 'card'}, pics,
      h('div', {}, h('span', {className: 'name', textContent: f.name}), h('span', {className: 'r', textContent: f.rarity.toLowerCase(), style: 'background:' + (RCOL[f.rarity] || '#999')})),
      h('div', {className: 'sub', textContent: f.chain}),
      h('div', {className: 'sub', textContent: (genus ? 'Pokédex: ' + genus + '  •  ' : '') + f.types.join(', ') + (f.seasons.length ? '  •  mùa ' + f.seasons.join(', ') : '')}),
      h('div', {className: 'note', textContent: f.note}), tags));
  }
}
render();
</script></body></html>
"""


def portraits(families, most=4):
    """The portraits the viewer shows (up to `most` forms a family), embedded as base64: the page works
    from anywhere (a copy, a preview pane, an artifact) without the assets folder."""
    import base64
    out = {}
    for f in families:
        shown = []
        for form in f["forms"]:
            if form["idx"] not in shown and len(shown) < most:
                shown.append(form["idx"])
        for idx in shown:
            png = os.path.join(ROOT, "assets", "portraits", idx + ".png")
            if idx not in out and os.path.exists(png):
                out[idx] = base64.b64encode(io.open(png, "rb").read()).decode("ascii")
    return out


def write_html(families, themes, seasons, path):
    data = {
        "pics": portraits(families),
        "groups": GROUPS, "rarities": [r for r in RARITIES if any(f["rarity"] == r for f in families)],
        "seasons": [{"id": s["id"], "name": s.get("name", "")} for s in seasons.get("seasons", [])],
        "themes": [{k: t[k] for k in ("id", "vi", "en", "group", "desc", "count", "near_count", "by_rarity", "with")} for t in themes],
        "families": [{k: f[k] for k in ("id", "name", "rarity", "types", "chain", "forms", "seasons", "tags", "near", "note")} for f in families],
    }
    blob = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    io.open(path, "w", encoding="utf-8", newline="\n").write(HTML.replace("__DATA__", blob))


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8") # the Windows console is cp1252
    families, themes, problems, seasons = build()
    for p in problems:
        print("PROBLEM:", p)
    write_md(families, themes, seasons, os.path.join(ROOT, "docs", "THEMES.md"))
    write_html(families, themes, seasons, os.path.join(ROOT, "docs", "themes.html"))
    top = sorted(themes, key=lambda t: -t["count"])
    print("%d họ, %d điểm chung; nhiều nhất: %s" % (len(families), len(themes), ", ".join("%s %d" % (t["id"], t["count"]) for t in top[:8])))
    print("ít nhất: %s" % ", ".join("%s %d" % (t["id"], t["count"]) for t in top[-6:]))
    print("họ không có điểm chung nào: %d" % sum(1 for f in families if not f["tags"] and not f["near"]))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
