"""Generates VFX specs (data/ability_vfx.json) from the web abilities-animations.ts.

  python tools/port/gen_vfx.py            dry run: what would be added, what needs a hand-written spec
  python tools/port/gen_vfx.py --write    appends the generated specs (existing ones are kept)
  python tools/port/gen_vfx.py SKILL...   web entry + generated spec of these abilities

Only the entries built from the web makers are translated (onCaster / onTarget / projectile /
skyfall / shakeCamera / poppingIcon and lists of them); entries written as code (args => ...)
are listed as "manual". An ability whose web strategy skips the default animation
(super.process(..., true)) and broadcasts its own positions gets its still animations on
the cells it shows (at: cells) instead of the caster / target.
Run tools\\export_pac.bat --no-music afterwards: the exporter packs the sheets of the specs.
"""
import json
import math
import os
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
GD = Path(__file__).resolve().parents[2]
PAC = Path(os.environ.get("PAC_DIR", r"D:/Python/PKM Autobattle/pokemonAutoChess"))
ANIMS = PAC / "app/public/src/game/components/abilities-animations.ts"
STRATEGIES = PAC / "app/core/abilities"
ATLAS = json.loads((PAC / "app/public/src/assets/atlas.json").read_text(encoding="utf8"))["packs"]

ab = json.loads((GD / "data/abilities.json").read_text(encoding="utf8"))
vfx_path = GD / "data/ability_vfx.json"
vfx = json.loads(vfx_path.read_text(encoding="utf8"))


# ---- web entries: "ABILITY" -> source text of its animation ----
def web_entries():
    src = ANIMS.read_text(encoding="utf8")
    body = src[src.index("export const AbilitiesAnimations"):src.index("export function displayAbility")]
    pat = re.compile(r'^  (?:\[Ability\.(\w+)\]|\["(\w+)"\]|(\w+)):', re.M)
    marks = [(m.start(), m.group(1) or m.group(2) or m.group(3), m.end()) for m in pat.finditer(body)]
    out = {}
    for i, (_pos, name, end) in enumerate(marks):
        nxt = marks[i + 1][0] if i + 1 < len(marks) else len(body)
        out[name] = body[end:nxt].strip().rstrip(",").strip()
    return out


ENTRIES = web_entries()
# enum AttackSprite { PSYCHIC_RANGE = "PSYCHIC/range", ... } (types/Animation.ts)
ATTACK_SPRITES = dict(re.findall(r'^\s*(\w+) = "([\w/]+)"', (PAC / "app/types/Animation.ts").read_text(encoding="utf8"), re.M))


# ---- parsing an entry made of maker calls ----
class Unsupported(Exception):
    pass


def _maker(name):
    return lambda options=None: (name, options or {})


ENV = {name: _maker(name) for name in ["onCaster", "onTarget", "projectile", "skyfall", "shakeCamera", "poppingIcon"]}
for who in ["Caster", "Target"]:
    for n in [1, 2, 3, 4]:
        ENV["on%sScale%d" % (who, n)] = ("on" + who, {"scale": n})
ENV.update({"True": True, "False": False, "None": None, "__builtins__": {}})


def parse(text):
    if "=>" in text or "function" in text or "..." in text:
        raise Unsupported("code")
    t = re.sub(r"//[^\n]*", "", text)
    t = re.sub(r"Ability\.(\w+)", r'"\1"', t)
    t = re.sub(r"AttackSprite\.(\w+)", lambda m: json.dumps(ATTACK_SPRITES.get(m.group(1), m.group(1))), t)
    t = re.sub(r"(DEPTH|Orientation|PokemonTint|Stat)\.(\w+)", r'"\1.\2"', t)
    t = re.sub(r"Phaser(\.\w+)+", '"ease"', t)
    t = t.replace("Math.PI", repr(math.pi))
    t = re.sub(r"\btrue\b", "True", t)
    t = re.sub(r"\bfalse\b", "False", t)
    t = re.sub(r"\b(undefined|null)\b", "None", t)
    t = re.sub(r"([{,]\s*)([A-Za-z_]\w*)\s*:", r'\1"\2":', t)
    try:
        return eval(t, ENV)  # maker calls, literals and arithmetic only (see ENV)
    except Exception as e:
        raise Unsupported("parse: %s" % e)


# ---- translation to the specs of the port ----
def _common(o, spec, ability):
    anim = o.get("ability")
    if anim and anim != ability:
        spec["anim"] = anim
    pack = o.get("textureKey", "abilities")
    if pack != "abilities":
        if pack not in ("attacks", "status"):
            raise Unsupported("textureKey " + str(pack))
        spec["pack"] = pack
    key = spec.get("anim", ability)
    if key not in ATLAS[pack]["anims"]:
        raise Unsupported("no animation %s/%s" % (pack, key))
    scale = o.get("scale", 2)
    if scale != 2:
        spec["scale"] = scale
    if "origin" in o:
        origin = o["origin"] if isinstance(o["origin"], list) else [o["origin"], o["origin"]]
        if origin != [0.5, 0.5]:
            spec["origin"] = origin
    if o.get("oriented"):
        spec["oriented"] = True
    rotation = o.get("rotation")
    if rotation is None and "angle" in o:
        rotation = math.radians(o["angle"])
    if rotation:
        spec["rotation"] = round(rotation, 4)
    if isinstance(o.get("tint"), int):
        spec["tint"] = "#%06x" % o["tint"]
    if "alpha" in o:
        spec["alpha"] = o["alpha"]
    if o.get("delay"):
        spec["delay"] = o["delay"]
    depth = str(o.get("depth", ""))
    if "BELOW" in depth or "GROUND" in depth:
        spec["below"] = True
    anim_options = o.get("animOptions") or {}
    if "repeat" in anim_options:
        spec["repeat"] = anim_options["repeat"]
    if "frameRate" in anim_options:
        spec["fps"] = anim_options["frameRate"]


def _tween(o, spec):
    if o.get("duration") and o["duration"] != 500:
        spec["duration"] = round(o["duration"])
    props = o.get("tweenProps") or {}
    if isinstance(props.get("scale"), (int, float)):
        spec["grow"] = props["scale"]
    if isinstance(props.get("alpha"), (int, float)):
        spec["alpha_to"] = props["alpha"]
    if props.get("yoyo") or o.get("yoyo"):
        spec["yoyo"] = True


def translate(ability, parsed, custom):
    """parsed: (maker, options) or a list of them -> list of specs."""
    if isinstance(parsed, list):
        out = []
        for p in parsed:
            out.extend(translate(ability, p, custom))
        return out
    if not isinstance(parsed, tuple):
        raise Unsupported("not a maker")
    maker, o = parsed
    if maker == "shakeCamera":
        return [{"at": "shake"}]
    spec = {}
    extra = []
    if maker in ("onCaster", "onTarget"):
        spec["at"] = maker[2:].lower()
        if custom:
            # own broadcast: on the caster / target when it keeps their position, else on
            # the cells it gives (the cells the port shows)
            m = re.search(("positionX" if maker == "onCaster" else "targetX") + r"\s*:\s*([\w.]+)", custom)
            if m and not m.group(1).startswith(("pokemon.", "target.")):
                spec["at"] = "cells"
        _common(o, spec, ability)
        if "positionOffset" in o:
            spec["offset"] = o["positionOffset"]
    elif maker == "poppingIcon":
        spec["at"] = "target" if o.get("startCoords") == "target" else "caster"
        o = dict(o, scale=o.get("scale", 0.25))
        _common(o, spec, ability)
        spec["grow"] = o.get("maxScale", 3)
        _tween(dict(o, tweenProps={}), spec)
    elif maker in ("projectile", "skyfall"):
        spec["at"] = maker
        if "orientation" in o:
            raise Unsupported("orientation")
        _common(o, spec, ability)
        start, end = o.get("startCoords", "caster"), o.get("endCoords", "target")
        if maker == "projectile":
            if not isinstance(start, str) or not isinstance(end, str):
                raise Unsupported("coordinates")
            if start == "target":
                spec["from"] = "target"
            if end == "caster":
                spec["to"] = "caster"
            if "distance" in o:
                spec["distance"] = o["distance"]
        if "startPositionOffset" in o:
            spec["offset"] = o["startPositionOffset"]
        if "endPositionOffset" in o:
            spec["to_offset"] = o["endPositionOffset"]
        _tween(o, spec)
        hit = o.get("hitAnim")
        if isinstance(hit, tuple) and hit[0] == "shakeCamera":
            extra.append({"at": "shake", "delay": o.get("duration", 500)})
        elif isinstance(hit, tuple) and hit[0] in ("onCaster", "onTarget"):
            h = {}
            _common(hit[1], h, ability)
            h.setdefault("anim", ability)
            spec["hit"] = h
        elif hit is not None:
            raise Unsupported("hitAnim")
    else:
        raise Unsupported(maker)
    return [spec] + extra


# ---- web strategies: default animation skipped? own broadcasts? ----
def strategy(skill):
    cls = "".join(w.capitalize() for w in skill.lower().split("_")) + "Strategy"
    p = STRATEGIES / (skill.lower().replace("_", "-") + ".ts")
    text = p.read_text(encoding="utf8") if p.exists() else ""
    if ("class " + cls) not in text:
        text = ""
        for f in STRATEGIES.iterdir():
            t = f.read_text(encoding="utf8")
            if ("class " + cls + " ") in t:
                text = t
                break
    i = text.find("class " + cls)
    if i < 0:
        return ""
    body = text[i:]
    j = body.find("\nexport class", 5)
    return body[:j] if j > 0 else body


def plan(skill):
    """(entry name, custom) of the animation of a skill. entry None = no animation in the web
    game; custom = "" for the default animation (on cast, caster -> target), else the
    arguments of its own broadcastAbility call."""
    body = re.sub(r"\s+", " ", strategy(skill))
    call = re.search(r"super\.process\(([^()]*)\)", body)
    call_args = [a.strip() for a in call.group(1).split(",")] if call else []
    if not (len(call_args) >= 5 and call_args[4] == "true"):  # preventDefaultAnim
        return skill, ""
    calls = re.findall(r"broadcastAbility\(\s*\{([^}]*)\}", body)
    if not calls:
        return None, "-"
    for call_text in calls:
        m = re.search(r'skill:\s*(?:Ability\.(\w+)|"(\w+)")', call_text)
        if m:
            return m.group(1) or m.group(2), call_text
    return skill, calls[0]


def generate(skill):
    entry, custom = plan(skill)
    if entry is None:
        return None, "no animation (default skipped, no broadcast)"
    if entry not in ENTRIES:
        return None, "no web entry" + (" for " + entry if entry != skill else "")
    try:
        specs = translate(entry, parse(ENTRIES[entry]), custom)
    except Unsupported as e:
        return None, "manual (%s)" % e
    if entry != skill:
        for s in specs:
            if s.get("at") != "shake":
                s.setdefault("anim", entry)
    return specs, "cells" if custom else "auto"


if "--check" in sys.argv:
    # the generator against the hand-written specs (how far it can be trusted)
    same, differ = 0, []
    for skill, hand in vfx.items():
        if skill.startswith("_"):
            continue
        specs, why = generate(skill)
        if specs == hand:
            same += 1
        elif specs:
            differ.append((skill, why, hand, specs))
    print("same: %d, different: %d" % (same, len(differ)))
    for skill, why, hand, specs in differ:
        print(skill, "(%s)\n  hand: %s\n  auto: %s" % (why, json.dumps(hand), json.dumps(specs)))
    sys.exit(0)

args = [a for a in sys.argv[1:] if not a.startswith("--")]
if args:
    for skill in args:
        print("=====", skill, plan(skill))
        print(ENTRIES.get(plan(skill)[0] or skill, "(no entry)"))
        print("->", generate(skill))
    sys.exit(0)

missing = [k for k in ab if not k.startswith("_") and k not in vfx]
done, reasons = {}, {}
for skill in missing:
    specs, why = generate(skill)
    if specs:
        done[skill] = specs
    reasons.setdefault(why if not specs else "generated (%s)" % why, []).append(skill)
for why, skills in sorted(reasons.items(), key=lambda kv: -len(kv[1])):
    print("%4d  %s%s" % (len(skills), why, "" if why.startswith("generated") else ": " + " ".join(skills)))
if "--write" in sys.argv and done:
    s = vfx_path.read_text(encoding="utf8").rstrip()
    lines = [" %s: %s" % (json.dumps(k), json.dumps(v)) for k, v in done.items()]
    s = s[:s.rfind("}")].rstrip() + ",\n" + ",\n".join(lines) + "\n}\n"
    json.loads(s)
    vfx_path.write_text(s, encoding="utf8", newline="\n")
    print("written:", len(done), "abilities")
