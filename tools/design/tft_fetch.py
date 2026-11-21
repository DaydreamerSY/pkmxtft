"""Download the TFT game data of every set (Community Dragon, versioned) and keep, per set, the champions (cost, traits,
ability text with its numbers) and the traits (text, breakpoints): a design reference (inspiration for skills / synergies).

usage: python -I tft_fetch.py <raw dir> <out dir>
"""
import html
import json
import os
import re
import sys
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
RAW, OUT = sys.argv[1], sys.argv[2]
os.makedirs(RAW, exist_ok=True)
os.makedirs(OUT, exist_ok=True)

# label: (patch, set number, mutator hint) — the patch is one where that set was live
SETS = {
    "1": ("9.21", "1", ""),
    "2": ("10.5", "2", ""),
    "3": ("10.11", "3", ""),
    "3.5": ("latest", "3", "TFTSet3"),
    "4": ("10.25", "4", ""),
    "4.5": ("11.8", "4", "TFTSet4_Act2"),
    "5": ("11.14", "5", ""),
    "5.5": ("11.21", "5", "TFT_Set5_Stage2"),
    "6": ("12.3", "6", "TFTTURBOSet6"),
    "6.5": ("12.10", "6", "Stage2"),
    "7": ("latest", "7", "TFTSet7"),
    "7.5": ("latest", "7", "TFTSet7_Stage2"),
    "8": ("13.5", "8", ""),
    "8.5": ("13.11", "8", "Stage2"),
    "9": ("13.18", "9", ""),
    "9.5": ("13.23", "9", "Stage2"),
    "10": ("14.6", "10", ""),
    "11": ("14.14", "11", ""),
    "12": ("14.22", "12", ""),
    "13": ("latest", "13", "TFTSet13"),
    "14": ("latest", "14", "TFTSet14"),
    "15": ("latest", "15", "TFTSet15"),
    "16": ("latest", "16", "TFTSet16"),
    "17": ("latest", "17", "TFTSet17"),
    "18": ("latest", "18", "TFTSet18"),

}
UA = {"User-Agent": "Mozilla/5.0 (data fetch for a private game design reference)"}


def fetch(patch):
    for lang in ("vi_vn", "en_us"):
        path = os.path.join(RAW, f"cd_{patch}_{lang}.json")
        if os.path.exists(path) and os.path.getsize(path) > 1000:
            return json.load(open(path, encoding="utf-8")), lang
        url = f"https://raw.communitydragon.org/{patch}/cdragon/tft/{lang}.json"
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r:
                data = r.read()
        except Exception as e:  # noqa: BLE001
            print(f"  {url}: {e}")
            continue
        open(path, "wb").write(data)
        return json.loads(data.decode("utf-8")), lang
    return None, None


def pick(d, number, hint):
    """The champions / traits of the set: setData entry matching the mutator hint, else sets[number]."""
    if hint and isinstance(d.get("setData"), list):
        exact = [s for s in d["setData"] if s.get("mutator") == hint]
        loose = [s for s in d["setData"] if hint in str(s.get("mutator", "")) and str(s.get("number")) == number]
        for cand in (exact, loose):
            if cand:
                return cand[0]
    if isinstance(d.get("sets"), dict) and number in d["sets"]:
        return d["sets"][number]
    if isinstance(d.get("setData"), list):
        same = [s for s in d["setData"] if str(s.get("number")) == number]
        if same:
            plain = [s for s in same if re.fullmatch(r"TFTSet\d+", str(s.get("mutator", "")))]
            return (plain or same)[0]
    if "champions" in d:
        return d
    return None


TAG = re.compile(r"<[^>]+>")


def clean(text):
    text = text.replace("<br>", "\n").replace("<br/>", "\n").replace("<br />", "\n")
    text = re.sub(r"%i:[A-Za-z]+%", "", text)
    text = TAG.sub("", text)
    text = html.unescape(text).replace(" ", " ")
    return re.sub(r"[ \t]+", " ", text).strip()


def fmt(v):
    if isinstance(v, (int, float)):
        return str(int(round(v))) if abs(v - round(v)) < 1e-6 else f"{v:.2f}".rstrip("0").rstrip(".")
    return str(v)


def subst(text, values):
    """@Name@ / @Name*100@ -> value(s) from `values` {name_lower: value or [values]}; unknown -> ?."""
    def rep(m):
        expr = m.group(1)
        mul = 1.0
        mm = re.match(r"([A-Za-z0-9_]+)\*([0-9.]+)$", expr)
        name = expr
        if mm:
            name, mul = mm.group(1), float(mm.group(2))
        v = values.get(name.lower())
        if v is None:
            return "?"
        if isinstance(v, list):
            return "/".join(fmt(x * mul) for x in v)
        return fmt(v * mul) if isinstance(v, (int, float)) else str(v)
    return re.sub(r"@([^@]+)@", rep, text)


def champion(c):
    ab = c.get("ability") or {}
    values = {}
    for var in ab.get("variables", []) or []:
        val = var.get("value") or var.get("values") or []
        if isinstance(val, list) and len(val) >= 4:
            stars = val[1:4]
            values[str(var.get("name", "")).lower()] = stars if len(set(stars)) > 1 else stars[0]
    stats = c.get("stats") or {}
    return {"name": c.get("name"), "cost": c.get("cost"), "traits": c.get("traits", []),
            "role": c.get("role"), "range": stats.get("range"), "mana": stats.get("mana"),
            "initialMana": stats.get("initialMana"), "ability": ab.get("name"),
            "desc": subst(clean(ab.get("desc") or ""), values)}


def trait(t):
    desc = clean(t.get("desc") or "")
    tiers = []
    for e in t.get("effects", []) or []:
        values = {k.lower(): v for k, v in (e.get("variables") or {}).items()}
        values["minunits"] = e.get("minUnits")
        tiers.append({"units": e.get("minUnits"), "values": {k: fmt(v) for k, v in (e.get("variables") or {}).items()}})
    # the rows of the text: one per breakpoint when it has <row> / (@MinUnits@) markers, else the text once
    rendered = desc
    if tiers and "@MinUnits@" in (t.get("desc") or ""):
        head, _, rows = desc.partition("(@MinUnits@")
        lines = [head.strip()] if head.strip() else []
        raw_rows = re.findall(r"\(@MinUnits@\)([^\n]*)", desc)
        for e in t.get("effects", []) or []:
            values = {k.lower(): v for k, v in (e.get("variables") or {}).items()}
            for r in raw_rows:
                lines.append(f"({e.get('minUnits')}) " + subst(r.strip(), values))
        rendered = "\n".join(dict.fromkeys(lines))
    elif tiers:
        values = {}
        for e in t.get("effects", []):
            for k, v in (e.get("variables") or {}).items():
                values.setdefault(k.lower(), []).append(v)
        values = {k: (v if len(set(map(str, v))) > 1 else v[0]) for k, v in values.items()}
        rendered = subst(desc, values)
    return {"name": t.get("name"), "units": [x["units"] for x in tiers], "desc": rendered}


index = {}
for label, (patch, number, hint) in SETS.items():
    print(f"set {label}: patch {patch}")
    d, lang = fetch(patch)
    if d is None:
        continue
    s = pick(d, number, hint)
    if s is None:
        print("  set not found")
        continue
    champs = [champion(c) for c in s.get("champions", []) if c.get("traits") and (c.get("ability") or {}).get("name")]
    traits = [trait(t) for t in s.get("traits", []) if t.get("name")]
    name = s.get("name") or s.get("mutator") or label
    json.dump({"set": label, "name": name, "lang": lang, "patch": patch, "champions": champs, "traits": traits},
              open(os.path.join(OUT, f"set_{label}.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    index[label] = {"name": name, "lang": lang, "champions": len(champs), "traits": len(traits)}
    print(f"  {name} ({lang}): {len(champs)} champions, {len(traits)} traits")
json.dump(index, open(os.path.join(OUT, "index.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
