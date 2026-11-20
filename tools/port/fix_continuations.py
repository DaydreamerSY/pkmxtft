"""Restores GDScript line continuations collapsed to 'code \\t\\t\\tmore' (a backslash-newline
eaten by a bash heredoc). Run it after editing .gd files through the shell:

  python tools/port/fix_continuations.py
"""
import re
from pathlib import Path

GD = Path(__file__).resolve().parents[2]
pat = re.compile(r"^(\t*)(\S.*?\S) (\t{2,})(\S.*)$")
for f in list((GD / "src").rglob("*.gd")) + list((GD / "tests").glob("*.gd")):
    lines = f.read_text(encoding="utf8").split("\n")
    out = []
    changed = False
    for line in lines:
        m = pat.match(line)
        if m:
            out.append(m.group(1) + m.group(2) + " \\")
            out.append(m.group(3) + m.group(4))
            changed = True
        else:
            out.append(line)
    if changed:
        f.write_text("\n".join(out), encoding="utf8", newline="\n")
        print("fixed", f.relative_to(GD))
