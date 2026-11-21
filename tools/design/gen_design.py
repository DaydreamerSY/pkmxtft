"""Season design review (not in the web game): merges tools/design/<season>_*.json into docs/DESIGN_<SEASON>.md and checks it.

  python tools/design/gen_design.py [s1]

Checks: every family of the season has one skill decision (keep / borrow / new), the mechanic keys (vùng.cơ chế) are
unique in the season, the synergy mechanics are unique, new skill ids do not clash with data/abilities.json.
"""
import io
import json
import os
import sys
from collections import Counter

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "tools", "roles"))
import skill_list as sl  # noqa: E402  (vi texts of the game)

SEASON = sys.argv[1] if len(sys.argv) > 1 else "s1"
RARITY_VI = {"COMMON": "Thường", "UNCOMMON": "Ít gặp", "RARE": "Hiếm", "EPIC": "Sử thi", "ULTRA": "Tối thượng",
             "UNIQUE": "Độc nhất", "LEGENDARY": "Huyền thoại", "HATCH": "Trứng"}
# design entries that name a branch form instead of a family: form -> family
FORM_FAMILY = {"URSHIFU": "KUBFU", "ARMAROUGE": "CHARCADET", "HISUI_SAMUROTT": "OSHAWOTT", "CURSOLA": "CORSOLA",
               "GALLADE": "RALTS", "CERULEDGE": "CHARCADET"}


def load(name):
    path = os.path.join(HERE, f"{SEASON}_{name}.json")
    return json.load(io.open(path, encoding="utf-8")) if os.path.exists(path) else {}


def md(text):
    return str(text).replace("|", "\\|").replace("\n", " ")


pk = json.load(io.open(os.path.join(ROOT, "data", "pac", "pokemon.json"), encoding="utf-8"))
abilities = json.load(io.open(os.path.join(ROOT, "data", "abilities.json"), encoding="utf-8"))
season = next(s for s in json.load(io.open(os.path.join(ROOT, "data", "seasons.json"), encoding="utf-8"))["seasons"]
              if s["id"] == SEASON)
types = load("types").get("types", {})
skills = load("skills")
borrow = load("borrow")
new = {}
for part in ("new_1", "new_2", "new_3"):
    new.update(load(part).get("new", {}))

# families of the season (the Flabébé colours are one family)
fams = []
for rarity, lst in season["shop"].items():
    for f in lst:
        if f.startswith("FLABEBE_"):
            continue
        fams.append((f, rarity))
for k in ("unique", "legendary", "hatch"):
    fams += [(f, k.upper()) for f in season.get(k, [])]

rows = []  # (family, rarity, status, form, skill, name, key, text, note)
problems = []
keep = skills.get("keep", {})
keep.update({f: v[:2] for f, v in borrow.get("keep_after_review", {}).items()})
for f, (sk, key) in keep.items():
    rows.append((f, "", "Giữ", "", sk, sl.ability_name(sk), key, sl.ability_desc(sk), ""))
for f, forms in skills.get("keep_forms", {}).items():
    for form, (sk, key) in forms.items():
        rows.append((f, "", "Giữ", form, sk, sl.ability_name(sk), key, sl.ability_desc(sk), "dạng rẽ nhánh"))
for f, (sk, key, owner, why) in borrow.get("borrow", {}).items():
    fam = FORM_FAMILY.get(f, f)
    rows.append((fam, "", "Mượn", f if fam != f else "", sk, sl.ability_name(sk), key, sl.ability_desc(sk),
                 f"của {owner}: {why}"))
    if sk not in abilities:
        problems.append(f"borrowed {sk} ({f}) is not in data/abilities.json")
for f, d in new.items():
    fam = FORM_FAMILY.get(f, f)
    rows.append((fam, "", "Mới", f if fam != f else "", d["id"], d["vi"], d["key"], d["text"],
                 f"PP {d.get('pp', '')}; cảm hứng: {d.get('tft', '')}"))
    web_users = [p for p, x in pk.items() if x.get("skill") == d["id"]]
    if web_users:
        problems.append(f"new id {d['id']} ({f}) is a skill of the web game ({web_users[0]}): rename it")
    elif d["id"] not in abilities:
        notes = d.setdefault("_status", "chưa code")

# coverage: every family once at family level (branch forms may add rows)
rarity_of = dict(fams)
covered = Counter(r[0] for r in rows if r[3] == "" or r[0] == "CORSOLA")
for f, _ in fams:
    if covered[f] == 0:
        problems.append(f"{f}: no skill decision")
for f in covered:
    if f not in rarity_of:
        problems.append(f"{f}: not a family of {SEASON}")
# unique keys / mechanics
for key, n in Counter(r[6] for r in rows).items():
    if n > 1:
        problems.append(f"key {key} used {n} times: " + ", ".join(r[0] + (f"/{r[3]}" if r[3] else "") for r in rows if r[6] == key))
for mech, n in Counter(t["mechanic"] for t in types.values()).items():
    if n > 1:
        problems.append(f"synergy mechanic {mech} used {n} times")
missing_types = set(GameTypes := []) if False else set()
order = {f: i for i, (f, _) in enumerate(fams)}
rows.sort(key=lambda r: (order.get(r[0], 999), r[3]))

count = Counter(r[2] for r in rows)
out = [f"# Thiết kế {season['name']}", "",
       f"*Sinh bằng `python tools/design/gen_design.py {SEASON}` từ `tools/design/{SEASON}_*.json`; đừng sửa tay. "
       "Người dùng đã duyệt (2026-11-20: mượn skill được, item giữa stage của hệ giữ nguyên, số liệu để tự cân bằng "
       "chỉnh); trong game: `data/season_skills.json` (`--write`), `data/season_synergies.json`, `docs/HANDOFF.md` mục 14.*",
       "",
       "## Luật đã chốt (người dùng, 2026-11-20)", "",
       "- **Hệ**: mỗi mùa mỗi hệ một hiệu ứng mới, không lặp ở hệ / mùa nào (hiệu ứng web chỉ còn khi chơi *Không mùa*). "
       "Giữ chủ đề của hệ, đổi cơ chế. Item giữa các stage của hệ (cần câu, quả mọng, đũa, mũ đầu bếp...) giữ nguyên.",
       "- **Skill**: trong một mùa mỗi họ Pokémon một cơ chế riêng = *vùng trúng + cách hoạt động* (cột **Khoá**). "
       "Chỉ đổi số liệu, đổi trạng thái (BURN↔POISON) hay đổi chỉ số bị giảm vẫn tính là trùng.",
       "- Họ có ở nhiều mùa: mỗi mùa một skill khác (mùa 1 giữ skill web nếu không trùng; mùa 2 / 3 sẽ đổi).",
       "- Làm từng mùa: duyệt bảng này → code + test → chơi thử → mùa 2, mùa 3.", "",
       "## Số liệu", "",
       f"- {len(fams)} họ (5 màu Flabébé tính 1). Skill: **{count['Giữ']} giữ**, **{count['Mượn']} mượn** "
       f"(skill đã có của Pokémon không thuộc mùa này), **{count['Mới']} mới** (phải code).",
       f"- {len(types)} hệ, mỗi hệ một cơ chế mới.",
       "- Kiểm tra: " + ("**không lỗi** (mỗi họ một skill, khoá không trùng, id mới không đụng skill có sẵn)."
                         if not problems else f"**{len(problems)} lỗi** (cuối file)."), ""]
out += ["## 1. Hiệu ứng hệ", "",
        "| Hệ | Tên | Mốc | Hiệu ứng | Cơ chế (khoá) | Vì sao hợp mùa này | Cảm hứng TFT |", "|---|---|---|---|---|---|---|"]
for t, d in types.items():
    out.append(f"| {t} | **{md(d['name'])}** | {'/'.join(str(x) for x in d['thresholds'])} | {md(d['text'])} | "
               f"`{d['mechanic']}` | {md(d['why'])} | {md(d['tft'])} |")
for status, title in (("Mới", "2. Skill mới (phải code)"), ("Mượn", "3. Skill mượn (đã có trong game)"),
                      ("Giữ", "4. Skill giữ nguyên (web)")):
    out += ["", f"## {title}", "", "| Họ | Độ hiếm | Dạng | Skill | Khoá | Mô tả | Ghi chú |", "|---|---|---|---|---|---|---|"]
    for r in rows:
        if r[2] != status:
            continue
        name = sl.pkm_name(r[0])
        out.append(f"| {name} | {RARITY_VI.get(rarity_of.get(r[0], ''), '')} | {sl.pkm_name(r[3]) if r[3] else ''} | "
                   f"**{md(r[5])}** `{r[4]}` | `{r[6]}` | {md(r[7])} | {md(r[8])} |")
out += ["", "## 5. Người dùng đã trả lời (2026-11-20)", "",
        "1. Skill **mượn**: được (một skill có thể ở hai mùa trên hai Pokémon khác nhau).",
        "2. Item giữa stage của hệ giữ nguyên (bản sao Bug đầu trận của web là hiệu ứng trong trận nên mùa 1 không có).",
        "3. Số liệu là bản đầu; tự cân bằng chỉnh sau khi chơi thử.", ""]
if problems:
    out += ["## Lỗi kiểm tra", ""] + [f"- {p}" for p in problems]
# --write: the skill rules of the season into data/season_skills.json (GameData.season_skill_rule)
# design entry naming a form -> (family, web skills it replaces)
FORM_RULES = {"HISUI_SAMUROTT": ("OSHAWOTT", ["CEASELESS_EDGE"]), "CHARCADET": ("CHARCADET", ["FLAME_CHARGE"]),
              "ARMAROUGE": ("CHARCADET", ["ARMOR_CANNON"]), "URSHIFU": ("KUBFU", ["WICKED_BLOW", "SURGING_STRIKES"]),
              "CORSOLA": ("CORSOLA", ["RECOVER"])}
if "--write" in sys.argv and not problems:
    def owner_pp(skill):
        """The web PP of the first form using `skill` (the PP it was made for), or None."""
        for p, d in sorted(pk.items()):
            if d.get("skill") == skill and float(d.get("maxPP", 0)) > 0:
                return int(d["maxPP"])
        return None

    rules = {}

    def add(entry, rule):
        family, replaces = FORM_RULES.get(entry, (entry, None))
        if replaces:
            rule["replaces"] = replaces
        rules.setdefault(family, []).append(rule)

    for f, (sk, key, owner, why) in borrow.get("borrow", {}).items():
        rule = {"skill": sk}
        pp = owner_pp(sk)
        if pp:
            rule["pp"] = pp
        add(f, rule)
    for f, d in new.items():
        add(f, {"skill": d["id"], "pp": int(d.get("pp", 100))})
    rules = {f: (r[0] if len(r) == 1 else r) for f, r in sorted(rules.items())}
    data_path = os.path.join(ROOT, "data", "season_skills.json")
    current = json.load(io.open(data_path, encoding="utf-8")) if os.path.exists(data_path) else {}
    current.setdefault("_doc", [
        "Skill theo mùa (không có ở bản web): mỗi họ một cơ chế riêng trong mùa. Sinh bằng",
        "python tools/design/gen_design.py <mùa> --write từ tools/design/<mùa>_*.json (docs/DESIGN_<MÙA>.md); đừng sửa tay.",
        "seasons.<mùa>.<HỌ> = rule hoặc [rules]: skill, pp (PP để cast), forms (chỉ các dạng này), replaces (chỉ dạng có skill web này).",
        "Đọc ở GameData.season_skill_rule / _apply_season_skills."])
    current.setdefault("seasons", {})[SEASON] = rules
    lines = ["{", '  "_doc": ' + json.dumps(current["_doc"], ensure_ascii=False) + ",", '  "seasons": {']
    seasons_out = []
    for sid in sorted(current["seasons"]):
        body = ",\n".join(f'      "{f}": ' + json.dumps(r, ensure_ascii=False) for f, r in current["seasons"][sid].items())
        seasons_out.append(f'    "{sid}": {{\n{body}\n    }}')
    lines.append(",\n".join(seasons_out))
    lines += ["  }", "}"]
    io.open(data_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print(f"{data_path}: {len(rules)} families of {SEASON}")

path = os.path.join(ROOT, "docs", f"DESIGN_{SEASON.upper()}.md")
io.open(path, "w", encoding="utf-8").write("\n".join(out) + "\n")
print(f"{path}: {len(rows)} rows ({dict(count)}), {len(problems)} problems")
for p in problems:
    print("  -", p)
