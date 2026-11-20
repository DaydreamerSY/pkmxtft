"""Missing Vietnamese texts.

  python tools/port/check_texts.py

- UI strings: L.t("...") and "reason": "..." of src/ missing from data/i18n/ui.json (vi)
- abilities without a vi name (data/i18n/vi.json "ability", or the web translation)
- abilities without a vi description (vi.json "ability_port", or the web translation)
"""
import json
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
GD = Path(__file__).resolve().parents[2]

ui = json.loads((GD / "data/i18n/ui.json").read_text(encoding="utf8"))
found = {}
pats = [re.compile(r'L\.t\("((?:[^"\\]|\\.)*)"\)'), re.compile(r'"reason":\s*"((?:[^"\\]|\\.)*)"')]
for f in (GD / "src").rglob("*.gd"):
    s = f.read_text(encoding="utf8")
    for pat in pats:
        for m in pat.finditer(s):
            found.setdefault(m.group(1), f.relative_to(GD).as_posix())
missing_ui = [k for k in found if k and not ui.get(k, {}).get("vi")]
print("UI: %d strings, %d without vi" % (len(found), len(missing_ui)))
for k in missing_ui:
    print("  %r  (%s)" % (k, found[k]))

ab = json.loads((GD / "data/abilities.json").read_text(encoding="utf8"))
web = json.loads((GD / "data/pac/lang/vi.json").read_text(encoding="utf8"))
port = json.loads((GD / "data/i18n/vi.json").read_text(encoding="utf8"))
names = {**web.get("ability", {}), **port.get("ability", {})}
descs = {**web.get("ability_description", {}), **port.get("ability_port", {})}
skills = [k for k in ab if not k.startswith("_")]
no_name = [k for k in skills if k not in names]
no_desc = [k for k in skills if k not in descs]
print("abilities: %d, %d without vi name, %d without vi description" % (len(skills), len(no_name), len(no_desc)))
for k in no_name + no_desc:
    print("  %s | %s | %s" % (k, ab[k].get("name", ""), ab[k].get("desc", "")))
