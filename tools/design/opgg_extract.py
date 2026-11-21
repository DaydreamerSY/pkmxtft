"""Extract the champions (ability) and traits of an op.gg TFT set page (RSC payload) into JSON.

usage: python -I opgg_extract.py <set_N.html> <out.json> [--probe WORD]
"""
import json
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
src, out = sys.argv[1], sys.argv[2]
probe = sys.argv[sys.argv.index("--probe") + 1] if "--probe" in sys.argv else None
html = open(src, encoding="utf-8").read()

# RSC chunks: self.__next_f.push([1,"..."])
chunks = []
for m in re.finditer(r'self\.__next_f\.push\(\[1,("(?:[^"\\]|\\.)*")\]\)', html):
    try:
        chunks.append(json.loads(m.group(1)))
    except json.JSONDecodeError:
        pass
text = "".join(chunks)
print(f"{len(chunks)} chunks, {len(text)} chars")

if probe:
    for m in list(re.finditer(re.escape(probe), text))[:3]:
        print("----", m.start())
        print(text[max(0, m.start() - 1500): m.start() + 1500])
    sys.exit(0)


def balanced(s, i):
    """The JSON object starting at s[i] == '{' (string-aware bracket matching)."""
    depth, j, n, in_str = 0, i, len(s), False
    while j < n:
        c = s[j]
        if in_str:
            if c == "\\":
                j += 2
                continue
            if c == '"':
                in_str = False
        else:
            if c == '"':
                in_str = True
            elif c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    return s[i:j + 1]
        j += 1
    return None


champions, traits = {}, {}
for m in re.finditer(r'\{"key":"', text):
    obj = balanced(text, m.start())
    if not obj:
        continue
    try:
        d = json.loads(obj)
    except json.JSONDecodeError:
        continue
    if "ability" in d and "cost" in d:
        champions.setdefault(d["key"], d)
    elif any(k in d for k in ("effects", "styles", "description", "desc")) and "cost" not in d:
        if d.get("key") not in traits or len(json.dumps(d)) > len(json.dumps(traits[d["key"]])):
            traits[d["key"]] = d

print(f"champions {len(champions)}, trait-like objects {len(traits)}")
json.dump({"champions": list(champions.values()), "traits": list(traits.values())}, open(out, "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)
