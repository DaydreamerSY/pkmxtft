"""Adds a batch of code-written abilities.

  python tools/port/add_batch.py <path>/batchN

reads <path>/batchN.gd (static funcs, GDScript, tabs) and <path>/batchN.json
({"SKILL": {"name", "desc", ...flags}}; "script" defaults to skill.lower()), then:
  - appends the functions to src/core/ability_scripts.gd in "#region abilities (batchN)"
  - appends the entries to data/abilities.json (skills already there are skipped)
Write the .gd / .json with a file editor (not a bash heredoc: backslash-newlines get eaten).
Flags: "no_target", "focus", "inimitable", "approx" (see docs/ABILITIES.md).
"""
import json
import sys
from pathlib import Path

GD = Path(__file__).resolve().parents[2]
src = Path(sys.argv[1])
name = src.name
code = src.with_suffix(".gd").read_text(encoding="utf8").strip("\n")
entries = json.loads(src.with_suffix(".json").read_text(encoding="utf8"))

p = GD / "data/abilities.json"
s = p.read_text(encoding="utf8")
data = json.loads(s)
lines = []
for k, v in entries.items():
    if k in data:
        print("skip (exists)", k)
        continue
    v = dict(v)
    v.setdefault("script", k.lower())
    lines.append(" %s: %s" % (json.dumps(k), json.dumps(v, ensure_ascii=False)))
if lines:
    i = s.rstrip().rfind("}")
    s = s[:i].rstrip() + ",\n\n" + ",\n".join(lines) + "\n}\n"
    json.loads(s)
    p.write_text(s, encoding="utf8", newline="\n")

p = GD / "src/core/ability_scripts.gd"
s = p.read_text(encoding="utf8").rstrip()
marker = "#region abilities (%s)" % name
if marker in s:
    print("region exists, code not appended")
else:
    s += "\n\n\n" + marker + "\n" + code + "\n#endregion\n"
    p.write_text(s, encoding="utf8", newline="\n")
print("added", len(lines), "abilities")
