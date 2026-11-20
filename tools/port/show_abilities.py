"""Web ability code, compact, to port it into src/core/ability_scripts.gd.

  python tools/port/show_abilities.py SKILL [SKILL...]   code of the web strategies (app/core/abilities)
  python tools/port/show_abilities.py --next N           the N missing skills blocking the most shop families
  python tools/port/show_abilities.py --rest             every missing skill, grouped by rarity (/regional)

The web project is found through PAC_DIR (default D:/Python/PKM Autobattle/pokemonAutoChess).
"""
import json
import os
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
GD = Path(__file__).resolve().parents[2]
PAC = Path(os.environ.get("PAC_DIR", r"D:/Python/PKM Autobattle/pokemonAutoChess"))
WEB = PAC / "app/core/abilities"
ab = json.load(open(GD / "data/abilities.json", encoding="utf8"))
pk = json.load(open(GD / "data/pac/pokemon.json", encoding="utf8"))
ported = set(k for k in ab if not k.startswith("_"))


def file_of(skill):
    p = WEB / (skill.lower().replace("_", "-") + ".ts")
    if p.exists():
        return p
    cls = "".join(w.capitalize() for w in skill.lower().split("_")) + "Strategy"
    for f in WEB.iterdir():
        if ("class " + cls + " ") in f.read_text(encoding="utf8"):
            return f
    return None


def compact(skill):
    p = file_of(skill)
    if p is None:
        return "  (no file: look for it in abilities.ts)"
    t = p.read_text(encoding="utf8")
    cls = "".join(w.capitalize() for w in skill.lower().split("_")) + "Strategy"
    i = t.find("class " + cls)
    if i < 0:
        i = t.find("export class")
    body = t[i:]
    j = body.find("\nexport class", 5)
    if j > 0:
        body = body[:j]
    out = []
    for line in body.split("\n"):
        s = line.rstrip()
        if not s.strip():
            continue
        if re.match(r"^\s*(pokemon: PokemonEntity,|board: Board,|target: PokemonEntity,|target: null,|crit: boolean,?|\) \{|process\()\s*$", s):
            continue
        out.append(s.replace("    ", "  "))
    return "\n".join(out)


args = sys.argv[1:]
if args and args[0] == "--next":
    n = int(args[1]) if len(args) > 1 else 10
    shop = {"COMMON", "UNCOMMON", "RARE", "EPIC", "ULTRA"}
    fam = {}
    for name, p in pk.items():
        if p["rarity"] in shop and not p.get("regional"):
            fam.setdefault(p.get("family", name), set()).add(name)
    blocking = {}
    for f, members in fam.items():
        miss = {pk[m]["skill"] for m in members if pk[m]["skill"] not in ported and pk[m]["skill"] != "DEFAULT"}
        for s in miss:
            blocking.setdefault(s, []).append((f, len(miss)))
    order = sorted(blocking.items(), key=lambda kv: (-sum(1 for f, k in kv[1] if k == 1), -len(kv[1]), kv[0]))
    for s, fs in order[:n]:
        print(s, [f for f, k in fs])
elif args and args[0] == "--rest":
    by = {}
    for name, p in pk.items():
        s = p["skill"]
        if s in ported or s == "DEFAULT":
            continue
        key = p["rarity"] + ("/regional" if p.get("regional") else "")
        by.setdefault(key, {}).setdefault(s, []).append(name)
    for k, v in sorted(by.items()):
        print(k, len(v), ":", " ".join(sorted(v)))
else:
    for skill in args:
        print("=====", skill)
        print(compact(skill))
