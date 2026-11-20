"""Replaces (or adds) entries of data/abilities.json, keeping the hand formatting of the others.

  python tools/port/replace_abilities.py <entries.json> [<code.gd> <region name>]

<entries.json>: {"SKILL": {...full new entry...}}; an entry already in the file is replaced by
a one-line version (its old lines are dropped), a new one is appended at the end.
With <code.gd>: its functions are appended to src/core/ability_scripts.gd in
"#region abilities (<region name>)" (skipped when the region is already there).
"""
import json
import re
import sys
from pathlib import Path

GD = Path(__file__).resolve().parents[2]
entries = json.loads(Path(sys.argv[1]).read_text(encoding="utf8"))

p = GD / "data/abilities.json"
s = p.read_text(encoding="utf8")
data = json.loads(s)
key_re = re.compile(r'^ "([A-Z0-9_]+)": ', re.M)
for key, value in entries.items():
    line = " %s: %s" % (json.dumps(key), json.dumps(value, ensure_ascii=False))
    if key in data:
        starts = [(m.start(), m.group(1)) for m in key_re.finditer(s)]
        i = next(k for k, (_, name) in enumerate(starts) if name == key)
        start = starts[i][0]
        end = starts[i + 1][0] if i + 1 < len(starts) else s.rstrip().rfind("}")
        old = s[start:end]
        # keep what follows the entry (",\n", ",\n\n" or "\n")
        body = old.rstrip()
        tail = old[len(body):]
        if body.endswith(","):
            body, tail = body[:-1], "," + tail
        s = s[:start] + line + tail + s[end:]
        print("replaced", key)
    else:
        i = s.rstrip().rfind("}")
        s = s[:i].rstrip() + ",\n" + line + "\n}\n"
        print("added", key)
json.loads(s)
p.write_text(s, encoding="utf8", newline="\n")

if len(sys.argv) > 3:
    code = Path(sys.argv[2]).read_text(encoding="utf8").strip("\n")
    p = GD / "src/core/ability_scripts.gd"
    s = p.read_text(encoding="utf8").rstrip()
    marker = "#region abilities (%s)" % sys.argv[3]
    if marker in s:
        print("region exists, code not appended")
    else:
        s += "\n\n\n" + marker + "\n" + code + "\n#endregion\n"
        p.write_text(s, encoding="utf8", newline="\n")
        print("code appended")
