"""Auto balance (docs/BOT.md "Tự cân bằng"), method 4: one step of data/balance.json = every Pokémon's OWN stats (HP,
Attack, DEF, SPE_DEF, SPEED, skill power, PP to cast) learned from bot batches played with the balance in use, by the
criteria of tools/bot/balance_targets.json. No synergy lever: a strong synergy gets balanced through its Pokémon.
  power  the form's worth: its weights in the win model (train_model.py) fitted WITHOUT the synergy features (it holds
         what its synergies bring too) and with ui:<form> (items held by it): u:<form> its worth without items, ui:<form>
         what each item adds on it. Deviation = (without items) + itemWeight x (per item), against the use-weighted
         mean of its group (rarity, stars, family size); the groups of a star level ordered by rarity (a rarer form is
         stronger: at least rarityGap a rarity step, isotonic) - a group out of order moves whole.
         Noise: the model fitted again on each half of the runs, split-half reliability (Spearman-Brown) -> shrink.
         ln P -= rate dev / sens (sens: log-odds per ln m of an even multiplier: an earlier step of this method whose
         stats moved, else the evolutions, at least 0.6), shared between offence and bulk by the role (tank 30 %
         offence ... carries 70 %) and by what it does better / worse than its group.
  role   its profile (units TSV): damage dealt against damage taken, each against an even share of its team; a tank
         dealing like a carry or a carry taking like a tank (beyond roleDeadZone from its role) -> part of the offence
         moved to bulk or back, same power; a support dealing too much -> Attack to skill, too little heal + shield ->
         more skill.
  casts  abilities per fight without items -> its PP to cast: the PP it gains per fight (ppgain) solved for the casts
         of its role (webPP keeps part of the web's maxPP differences), with 2+ items at most castsWithItems; a cast
         replaces an attack (perAttack PP of its role lost). A form whose PP moves more than ppFreeze keeps its power
         and role this step (measured again once its casts changed).
  stats  bulk = HP, DEF, SPE_DEF (one multiplier; the armour weighs by the physical / special share of the damage it
         takes), offence = Attack + SPEED (2 : 1 of the attack part: attack rate 0.4 + 0.007 speed) and skill by the
         share of its output from attacks. skill is NO stat: the strength of its own ability (x the damage, heal and
         shield it deals, GameData "skillScale"; its AP stays 0), so a too strong ability gets a lower skill or more PP to
         cast, never a negative stat (every stat checked >= 0 before writing). At most +-step (10 %) per stat per step
         (PP: ppStep), HP and PP in tens in the game; forms on fewer than --min boards only follow the PP of their role.
    python tools/bot/autobalance.py build/bot/bal_v4 [more folders] [--min 60] [--step 0.1] [--rate 1] [--explore 0.03]
        [--sens S] [--dry]          (--rate: damping of the power steps, 1 = the full step; --explore: random +-x on
                                    each step's power, so that the next step can measure the lever)
    python tools/bot/autobalance.py --reset          back to the web stats
    python tools/bot/autobalance.py --restore 2      back to version 2 (build/bot/balance_v2.json)
Writes data/balance.json (unless --dry; the previous one kept as build/bot/balance_v<version>.json), build/bot/
balance_stats.tsv (every balanced form: web and balanced stats), <first folder>/balance_step.tsv (every form: the
criteria and the step), <first folder>/balance_report.txt (casts, roles, items, rarity, strategies) and a line of
build/bot/balance_history.tsv.
"""
import glob
import io
import json
import math
import os
import re
import shutil
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import train_model as tm  # noqa: E402

pd = tm.pd
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

PATH = os.path.join(tm.ROOT, "data", "balance.json")
TARGETS = os.path.join(tm.ROOT, "tools", "bot", "balance_targets.json")
DIFFICULTY = os.path.join(tm.ROOT, "data", "difficulty.json")
BACKUP = os.path.join(tm.ROOT, "build", "bot", "balance_v%d.json")
HISTORY = os.path.join(tm.ROOT, "build", "bot", "balance_history.tsv")
STATS = os.path.join(tm.ROOT, "build", "bot", "balance_stats.tsv")
L2 = 0.0005
ARMOR = 0.05 # BattleUnit.ARMOR_FACTOR: damage / (1 + 0.05 DEF)
KNOBS = ["hp", "atk", "def", "speDef", "speed", "skill", "pp"]
BOUNDS = {"hp": (0.5, 2.0), "atk": (0.5, 2.0), "def": (0.5, 2.0), "speDef": (0.5, 2.0), "speed": (0.6, 1.6),
          "skill": (0.3, 2.5), "pp": (0.2, 2.5)}
ROLE_OFFENCE = {"tank": 0.3, "fighter": 0.5, "support": 0.6, "marksman": 0.7, "caster": 0.7, "assassin": 0.7}
CARRIES = ("marksman", "caster", "assassin")
SHOP = ["COMMON", "UNCOMMON", "RARE", "EPIC", "ULTRA"]
DOC = ("Auto balance (tools/bot/autobalance.py, docs/BOT.md) - not in the web game: every form's own multipliers of its "
       "web stats. hp, atk, def, speDef, speed: x m (hp in tens); skill: the strength of its own ability, x m on the damage, "
       "heal and shield it deals (no stat: AP stays 0, no stat is ever negative); pp: the PP to cast x m (in tens). Missing = 1. version: the step that wrote it (bot batches record it). Remove an entry to undo it; python "
       "tools/bot/autobalance.py --reset for the web stats, --restore <version> for an earlier step.")


#region files
def load_balance(path=PATH):
    b = json.load(io.open(path, encoding="utf-8")) if os.path.exists(path) else {}
    b.setdefault("pokemon", {})
    b.setdefault("version", 0)
    return b


def entry_of(value):
    """A form's multipliers as a dict (the older format: one number for hp, atk and skill)."""
    if isinstance(value, dict):
        return {k: float(v) for k, v in value.items()}
    return {k: float(value) for k in ("hp", "atk", "skill")}


def save_balance(b):
    old = load_balance()
    os.makedirs(os.path.dirname(BACKUP), exist_ok=True)
    if os.path.exists(PATH):
        shutil.copyfile(PATH, BACKUP % old["version"])
    forms = {}
    for pkm in sorted(b["pokemon"]):
        e = {k: round(v, 3) for k, v in entry_of(b["pokemon"][pkm]).items() if abs(v - 1.0) >= 0.005}
        if e:
            forms[pkm] = e
    wrong = negative_stats(forms)
    if wrong:
        raise SystemExit("autobalance: a stat would go below 0, data/balance.json unchanged: %s" % wrong[:10])
    lines = ['\t\t"%s": %s' % (pkm, json.dumps(e, ensure_ascii=False)) for pkm, e in forms.items()]
    text = "{\n\t\"_doc\": %s,\n\t\"version\": %d,\n\t\"pokemon\": {\n%s\n\t}\n}\n" % (
        json.dumps(DOC, ensure_ascii=False), b["version"], ",\n".join(lines))
    json.loads(text) # one form per line, still JSON
    io.open(PATH, "w", encoding="utf-8", newline="\n").write(text)
    return forms


def batch_versions(folders):
    versions = set()
    for d in folders:
        for f in glob.glob(os.path.join(d, "meta_*.tsv")):
            lines = [l for l in io.open(f, encoding="utf-8") if l.startswith("balance\t")]
            versions.add(lines[0].split("\t")[1].strip() if lines else "0") # batches older than the balance: 0
    return versions


def load_batches(folders):
    """Stages and the units (both teams) of the batches; `batch` = index of the folder."""
    stages, units = [], []
    for i, d in enumerate(folders):
        read = lambda kind: [pd.read_csv(f, sep="\t", na_filter=False, low_memory=False)
                             for f in sorted(glob.glob(os.path.join(d, "%s_*.tsv" % kind))) if os.path.getsize(f) > 0]
        s = pd.concat(read("stages"), ignore_index=True)
        s["batch"] = i
        stages.append(s)
        u = read("units")
        if u:
            u = pd.concat(u, ignore_index=True)
            u["batch"] = i
            units.append(u)
    return pd.concat(stages, ignore_index=True), (pd.concat(units, ignore_index=True) if units else None)


def role_mana():
    """perAttack of each role (data/difficulty.json base mana; what a cast costs in attack PP)."""
    mana = json.load(io.open(DIFFICULTY, encoding="utf-8")).get("base", {}).get("mana", {})
    roles = mana.get("roles", {})
    return {r: float(roles.get(r, {}).get("perAttack", mana.get("perAttack", 5))) for r in ROLE_OFFENCE}


ABILITIES = json.load(io.open(os.path.join(tm.ROOT, "data", "abilities.json"), encoding="utf-8"))
SCRIPTS = {} # name -> body of every static func of src/core/ability_scripts.gd (the abilities written as code)
for _part in re.split(r"^static func ", io.open(os.path.join(tm.ROOT, "src", "core", "ability_scripts.gd"),
                                                  encoding="utf-8").read(), flags=re.M)[1:]:
    SCRIPTS[_part.split("(", 1)[0].strip()] = _part
_WHO = r"\b(?:c|caster|ctx\.caster)\."
SCALE_PATTERNS = {"ap": _WHO + r"ap\b|\bhit\(ctx", "atk": _WHO + r"(?:base_)?atk\b", "def": _WHO + r"(?:base_)?def\b",
                  "speDef": _WHO + r"(?:base_)?spe_def\b", "hp": _WHO + r"(?:max_hp|base_hp|hp)\b",
                  "speed": _WHO + r"speed\b"}
SCALE_NAMES = {"maxHP": "hp", "hp": "hp", "atk": "atk", "def": "def", "speDef": "speDef", "speed": "speed", "ap": "ap"}


def skill_scaling(pkm):
    """The caster stats the form's ability scales with: data/abilities.json effects (damage / heal / shield x AP
    unless no_ap, x `stat` / `plus_stat`, buffs x `scale_stat`) and the code of a script ability (hit() = AP, the caster's
    atk / def / spe_def / hp / speed read, with the helpers it calls)."""
    ab = ABILITIES.get(tm.POKEMON.get(pkm, {}).get("skill", ""), {})
    found = set()
    if not isinstance(ab, dict):
        return found
    for st in ab.get("steps", []):
        for e in st.get("effects", []):
            if e.get("type") in ("damage", "heal", "shield", "drain"):
                if not e.get("no_ap"):
                    found.add("ap")
                for key in ("stat", "plus_stat"):
                    if e.get(key) in SCALE_NAMES:
                        found.add(SCALE_NAMES[e[key]])
            if e.get("scale_stat") in SCALE_NAMES:
                found.add(SCALE_NAMES[e["scale_stat"]])
    body = SCRIPTS.get(ab.get("script", ""), "")
    for helper in set(re.findall(r"\b(_[a-z0-9_]+)\(", body)):
        body += SCRIPTS.get(helper, "")
    for stat, pattern in SCALE_PATTERNS.items():
        if body and re.search(pattern, body):
            found.add(stat)
    return found


def executes(pkm):
    """Its ability knocks out outright (execute: 9999 damage): its damage of an older batch (overkill counted) says
    nothing of its role."""
    ab = ABILITIES.get(tm.POKEMON.get(pkm, {}).get("skill", ""), {})
    if not isinstance(ab, dict):
        return False
    if any("execute_chance" in e or "execute_below" in e for st in ab.get("steps", []) for e in st.get("effects", [])):
        return True
    return "9999" in SCRIPTS.get(ab.get("script", ""), "")


def damage_effective(folders):
    """Every batch counted the damage without overkill (meta "damage effective")."""
    for d in folders:
        for f in glob.glob(os.path.join(d, "meta_*.tsv")):
            if not any(l.startswith("damage\teffective") for l in io.open(f, encoding="utf-8")):
                return False
    return True


_OUTPUT = re.compile(r"\b(?:hit|deal_damage|heal|add_shield)\(")


def skill_output(pkm):
    """Its ability deals damage, heals or shields (data effects damage / heal / shield / drain, a script calling hit /
    deal_damage / heal / add_shield, itself or through its helpers): what the skill lever scales."""
    ab = ABILITIES.get(tm.POKEMON.get(pkm, {}).get("skill", ""), {})
    if not isinstance(ab, dict):
        return False
    if any(e.get("type") in ("damage", "heal", "shield", "drain") for st in ab.get("steps", []) for e in st.get("effects", [])):
        return True
    body = SCRIPTS.get(ab.get("script", ""), "")
    for helper in set(re.findall(r"\b(_[a-z0-9_]+)\(", body)):
        body += SCRIPTS.get(helper, "")
    return bool(_OUTPUT.search(body))


def skill_levers(pkm):
    """What tunes the power of its ability: skill = its strength (x the damage, heal and shield it deals, whatever stat
    it scales with; GameData "skillScale", no stat) - [] when it deals, heals and shields nothing (its power comes from
    its casts only: the PP)."""
    return ["skill"] if skill_output(pkm) else []


def guess_role(pkm):
    """UnitRoles._guess (src/core/unit_roles.gd) on the web data: the role of a form no batch played."""
    d = tm.POKEMON.get(pkm, {})
    ab = ABILITIES.get(d.get("skill", ""), {})
    helps = hurts = shields_self = False
    for step in ab.get("steps", []) if isinstance(ab, dict) else []:
        affects = str(step.get("affects", "enemies"))
        for eff in step.get("effects", []):
            if eff.get("to", "") == "self" or step.get("area") == "self":
                shields_self = shields_self or eff.get("type") == "shield"
            elif affects.startswith("allies"):
                helps = helps or eff.get("type") in ("heal", "shield", "buff", "cleanse")
            elif eff.get("type") == "damage":
                hurts = True
    if helps and not hurts:
        return "support"
    if int(d.get("range", 1)) >= 2:
        return "caster" if hurts else "marksman"
    if "dash" in ab and hurts:
        return "assassin"
    base = tm.POKEMON.get(d.get("family", ""), d)
    bulk = float(base.get("def", 0)) + float(base.get("speDef", 0))
    return "tank" if bulk >= 10 or (float(base.get("hp", 0)) >= 80 and bulk >= 8) or shields_self else "fighter"
#endregion


#region stats
def roundi(x):
    """GDScript roundi: half away from zero."""
    return int(math.copysign(math.floor(abs(x) + 0.5), x))


def realized(pkm, e):
    """The stats the game gives a form with its multipliers (GameData.balance_form); skill = skillScale, the strength of
    its own ability (no stat: its AP stays 0)."""
    d = tm.POKEMON.get(pkm, {})
    snap = lambda x: math.floor(x * 10 + 0.5) / 10
    out = {"hp": max(roundi(float(d.get("hp", 10)) * e.get("hp", 1.0) / 10.0) * 10, 10),
           "atk": max(snap(float(d.get("atk", 1)) * e.get("atk", 1.0)), 1.0),
           "skill": max(math.floor(e.get("skill", 1.0) * 100 + 0.5) / 100, 0.1)}
    for stat in ("def", "speDef", "speed"):
        out[stat] = max(snap(float(d.get(stat, 0)) * e.get(stat, 1.0)), 0.0) if stat in e else float(d.get(stat, 0))
    pp = float(d.get("maxPP", 0))
    out["pp"] = max(roundi(pp * e.get("pp", 1.0) / 10.0) * 10, 10) if pp > 0 else 0
    return out


def negative_stats(forms):
    """(form, stat, value) of every multiplier <= 0 or stat below 0 the balance `forms` would give (must be empty)."""
    wrong = []
    for pkm, value in forms.items():
        e = entry_of(value)
        wrong += [(pkm, k, v) for k, v in e.items() if not v > 0]
        if pkm in tm.POKEMON:
            wrong += [(pkm, k, v) for k, v in realized(pkm, e).items() if v < 0]
    return wrong


def power_eq(pkm, e, prof):
    """The even multiplier worth the same power as the multipliers `e` (sqrt(offence x bulk)): bulk = HP x the armour
    against the physical / special share of the damage it takes, offence = attack share x (Attack x attack rate) + the
    rest x skill. The PP is not in it (its casts are measured)."""
    d = tm.POKEMON.get(pkm, {})
    ln = lambda k: math.log(max(e.get(k, 1.0), 1e-6))
    armour = lambda stat, phi: phi * math.log((1 + ARMOR * float(d.get(stat, 0)) * e.get(stat, 1.0))
                                              / (1 + ARMOR * float(d.get(stat, 0))))
    s = float(d.get("speed", 50))
    rate = math.log((0.4 + 0.007 * s * e.get("speed", 1.0)) / (0.4 + 0.007 * s))
    bulk = ln("hp") + armour("def", prof["phys"]) + armour("speDef", prof["spec"])
    off = prof["a"] * (ln("atk") + rate) + (1 - prof["a"]) * ln("skill")
    return math.exp(0.5 * (bulk + off))


def step_stats(pkm, old, d_off, d_bulk, prof, cap, extra=None, levers=("skill",), skill_shift=0.0):
    """New multipliers: bulk (ln) on HP, DEF, SPE_DEF; offence (ln) on the attack (Attack + attack rate, 2 : 1) and on
    the ability's levers (`levers`: skill = the strength of its ability; none: all on the attack) by the attack share;
    `skill_shift` (ln of the skill / attack output ratio, same offence) from the attack to the ability; `extra` {knob:
    ln} added (a support's Attack / skill shift); every change within +-cap, every multiplier within BOUNDS (> 0)."""
    d = tm.POKEMON.get(pkm, {})
    clip = lambda x: max(min(x, cap), -cap)
    elastic = lambda stat: ARMOR * float(d.get(stat, 0)) * old.get(stat, 1.0) / (1 + ARMOR * float(d.get(stat, 0)) * old.get(stat, 1.0))
    x = d_bulk / (1 + prof["phys"] * elastic("def") + prof["spec"] * elastic("speDef"))
    a = prof["a"] if levers else 1.0
    k = a * a + (1 - a) ** 2
    y, z = d_off * a / k, d_off * (1 - a) / k
    if "skill" in levers and skill_shift: # the ability's part up, the attack's down: a dy + (1 - a) dz = 0
        y -= skill_shift * (1 - a)
        z_skill = skill_shift * a
    else:
        z_skill = 0.0
    ln = {"hp": x, "def": x, "speDef": x, "atk": y * 2 / 3}
    for lever in levers:
        ln[lever] = ln.get(lever, 0.0) + z / len(levers)
    if z_skill:
        ln["skill"] = ln.get("skill", 0.0) + z_skill
    for knob, v in (extra or {}).items():
        ln[knob] = ln.get(knob, 0.0) + v
    new = dict(old)
    for knob, v in ln.items():
        new[knob] = old.get(knob, 1.0) * math.exp(clip(v))
    s = float(d.get("speed", 50)) * old.get("speed", 1.0)
    if s > 0:
        r = (0.4 + 0.007 * s) * math.exp(y / 3)
        new["speed"] = old.get("speed", 1.0) * math.exp(clip(math.log(max((r - 0.4) / 0.007, 1.0) / s)))
    for knob, (low, high) in BOUNDS.items():
        if knob in new:
            new[knob] = min(max(new[knob], low), high)
    return new
#endregion


#region worth
def family_size(pkm, depth=0):
    d = tm.POKEMON.get(pkm, {})
    nxt = d.get("evolution", "")
    if not nxt or nxt not in tm.POKEMON or depth > 4:
        return int(d.get("stars", 1))
    return family_size(nxt, depth + 1)


def form_groups(names):
    full = {}
    for name in names:
        pkm = name[2:]
        if name.startswith("u:") and pkm in tm.POKEMON and tm.POKEMON[pkm].get("passive") != "INANIMATE":
            d = tm.POKEMON[pkm]
            full.setdefault((d.get("rarity", "COMMON"), int(d.get("stars", 1)), family_size(pkm)), []).append(name)
    groups = {}
    for key, members in full.items():
        groups.setdefault(key if len(members) >= 4 else key[:2] + (0,), []).extend(members)
    return groups


def form_devs(groups, weight, seen):
    """u:<form> minus the use-weighted mean of its group (0 in a group of fewer than 3 forms)."""
    out = {}
    for members in groups.values():
        mean = sum(weight.get(m, 0.0) * seen[m] for m in members) / max(sum(seen[m] for m in members), 1)
        for m in members:
            out[m] = weight.get(m, 0.0) - mean if len(members) >= 3 else 0.0
    return out


def calibrate(full, half_a, half_b, se2, n):
    """Reliability of the deviations from the two halves: (tau2, c, r, rho)."""
    keys = [k for k in full if k in half_a and k in half_b]
    if len(keys) < 5:
        return 1e-4, 1.0, 0.0, 0.0
    wts = np.array([n[k] for k in keys], float)
    a, b, f = (np.array([d[k] for k in keys]) for d in (half_a, half_b, full))
    avg = lambda x: float(np.average(x, weights=wts))
    cov = avg((a - avg(a)) * (b - avg(b)))
    rho = cov / math.sqrt(max(avg((a - avg(a)) ** 2) * avg((b - avg(b)) ** 2), 1e-18))
    r = min(max(2 * rho / (1 + rho) if rho > 0 else 0.0, 0.02), 0.98) # Spearman-Brown: the full data
    var = avg((f - avg(f)) ** 2)
    c = (1 - r) * var / max(avg(np.array([se2[k] for k in keys])), 1e-12)
    return max(r * var, 1e-6), c, r, rho


def unit_power(pkm):
    d = tm.POKEMON.get(pkm, {})
    return max(int(tm.COST.get(d.get("rarity", "COMMON"), 1)), 1) * 3 ** (int(d.get("stars", 1)) - 1)


def pav(values, weights):
    """Weighted isotonic (non-decreasing) regression."""
    blocks = []
    for v, w in zip(values, weights):
        blocks.append([v, max(w, 1e-9), 1])
        while len(blocks) > 1 and blocks[-2][0] > blocks[-1][0]:
            b2 = blocks.pop()
            b1 = blocks.pop()
            wt = b1[1] + b2[1]
            blocks.append([(b1[0] * b1[1] + b2[0] * b2[1]) / wt, wt, b1[2] + b2[2]])
    out = []
    for v, _w, k in blocks:
        out += [v] * k
    return out


def rarity_targets(groups, total, seen, gap):
    """{(rarity, stars): (mean worth, target)}: per star level the shop rarities in order, at least `gap` a rarity step
    (worth = the form's total worth without items, weighted by use)."""
    pooled = {}
    for key, members in groups.items():
        for m in members:
            acc = pooled.setdefault(key[:2], [0.0, 0])
            acc[0] += total[m] * seen[m]
            acc[1] += seen[m]
    out = {key: (acc[0] / max(acc[1], 1), acc[0] / max(acc[1], 1)) for key, acc in pooled.items()} # unordered: as they are
    for stars in sorted(set(s for _r, s in pooled)):
        # groups on fewer than 300 boards: too noisy to order (their forms mostly stay anyway, --min)
        seq = [(r, pooled[(r, stars)][0] / max(pooled[(r, stars)][1], 1), pooled[(r, stars)][1])
               for r in SHOP if (r, stars) in pooled and pooled[(r, stars)][1] >= 300]
        if len(seq) < 2:
            for r, mean, _n in seq:
                out[(r, stars)] = (mean, mean)
            continue
        ranks = [SHOP.index(r) for r, _m, _n in seq]
        fitted = pav([m - gap * k for (_r, m, _n), k in zip(seq, ranks)], [n for _r, _m, n in seq])
        for (r, mean, _n), k, f in zip(seq, ranks, fitted):
            out[(r, stars)] = (mean, f + gap * k)
    return out


def lever_from_history(version, dev_form, now_m):
    """Sensitivity of the lever from the latest earlier step of this method (its TSV has pp_old) whose power moved and
    whose PP hardly did: deviation now = a x deviation then + s x ln(m now / m then) (m: power_eq), weighted least
    squares over the forms on 100+ boards both times. dev_form: name -> (deviation, n) now. -> (s or None, source)."""
    if not os.path.exists(HISTORY):
        return None, "no history"
    lines = [l.rstrip("\n").split("\t") for l in io.open(HISTORY, encoding="utf-8")][1:]
    for r in reversed([r for r in lines if r and r[0].isdigit() and int(r[0]) < version]):
        step = os.path.join(tm.ROOT, r[-1].split(",")[0], "balance_step.tsv")
        if not os.path.exists(step):
            continue
        then = pd.read_csv(step, sep="\t")
        if "pp_old" not in then.columns:
            continue # a step of an older method (another model): its deviations do not compare
        then = then[then.kind == "pokemon"].copy()
        for column in ("pp_old", "pp_new", "n", "dev", "old"):
            then[column] = pd.to_numeric(then[column], errors="coerce").fillna(0)
        mine = then[then.pp_old > 0]
        if len(mine) and float(np.median(np.abs(np.log(mine.pp_new.clip(lower=1) / mine.pp_old.clip(lower=1))))) > 0.05:
            continue # the PP moved too: its casts changed the worth as well
        xs, ys, ws = [], [], []
        for row in then[(then.kind == "pokemon") & (then.n >= 100)].itertuples(index=False):
            if row.name not in dev_form or dev_form[row.name][1] < 100:
                continue
            xs.append((row.dev, math.log(now_m.get(row.name, 1.0) / max(float(row.old), 1e-6))))
            ys.append(dev_form[row.name][0])
            ws.append(math.sqrt(min(row.n, dev_form[row.name][1])))
        if len(xs) < 50 or np.std([x[1] for x in xs]) < 0.02:
            continue # too few, or the stats hardly moved since: says nothing
        X = np.column_stack([np.array(xs), np.ones(len(xs))])
        wts = np.array(ws)
        s = float(np.linalg.lstsq(X * wts[:, None], np.array(ys) * wts, rcond=None)[0][1])
        if 0.1 <= s <= 3.0:
            return s, "version %s, %d forms" % (r[0], len(xs))
    return None, "no step of this method moved the power alone"
#endregion


#region casts
def cast_calibration(version, observed, fight_now):
    """{role: cast rate observed now / rate the previous step predicted} for the PP it set (its balance_step.tsv
    `casts_after` over the fight length of its batches, against the casts now over fight_now; the forms on 30+ fights
    without items now): the prediction misses what more casts change (fewer attacks...), so the PP solver aims at
    target / ratio (the shorter fights are in the targets already: refFight). observed: pkm -> mean casts without items."""
    if not os.path.exists(HISTORY):
        return {}, "no history"
    lines = [l.rstrip("\n").split("\t") for l in io.open(HISTORY, encoding="utf-8")][1:]
    for r in reversed([r for r in lines if r and r[0].isdigit() and int(r[0]) == version - 1]):
        step = os.path.join(tm.ROOT, r[-1].split(",")[0], "balance_step.tsv")
        if not os.path.exists(step):
            continue
        then = pd.read_csv(step, sep="\t")
        if "casts_after" not in then.columns:
            return {}, "step %s has no prediction" % r[0]
        then = then[then.kind == "pokemon"].copy()
        then["casts_after"] = pd.to_numeric(then["casts_after"], errors="coerce")
        then["now"] = then["name"].map(observed)
        then = then[(then.casts_after > 0.2) & then.now.notna()]
        lengths = [pd.read_csv(f, sep="\t", usecols=["fight_s"])["fight_s"] for d in r[-1].split(",")
                   for f in glob.glob(os.path.join(tm.ROOT, d, "stages_*.tsv")) if os.path.getsize(f) > 0]
        fight_then = float(pd.concat(lengths).mean()) if lengths else fight_now
        out = {}
        for role, g in then.groupby("role"):
            if len(g) >= 10:
                rate = float(np.median(g.now / g.casts_after)) * fight_then / max(fight_now, 1.0)
                out[role] = min(max(rate, 0.5), 1.5)
        return out, "step %s, %d forms, fights %.1f -> %.1f s" % (r[0], len(then), fight_then, fight_now)
    return {}, "no step before"


def predicted_casts(gain, casts, per_attack, pp):
    """Casts per fight at `pp`: the PP gained (a cast replaces an attack: its perAttack PP lost)."""
    return np.floor((gain + per_attack * casts) / (pp + per_attack))


def solve_pp(gain, casts, per_attack, target, quantile=None):
    """The PP whose mean predicted casts (or that quantile of them) is `target`."""
    lo, hi = 5.0, 600.0
    stat = (lambda x: x.mean()) if quantile is None else (lambda x: float(np.quantile(x, quantile)))
    for _ in range(40):
        mid = math.sqrt(lo * hi)
        if stat(predicted_casts(gain, casts, per_attack, mid)) > target:
            lo = mid
        else:
            hi = mid
    return math.sqrt(lo * hi)
#endregion


#region report
def strategies(stages, role_of):
    """Stage rows -> their strategy (core synergies, carry and its items), role structure and stage-adjusted result."""
    win = (stages["res"] == "W").astype(float)
    expected = win.groupby([stages["batch"], stages["stage"].clip(upper=60)]).transform("mean")
    core, carry, shape = [], [], []
    for syn, board in stages[["syn", "board"]].itertuples(index=False):
        tiers = sorted(((int(p.split(":")[2]), int(p.split(":")[1]), p.split(":")[0]) for p in syn.split("|")) if syn else [],
                       reverse=True)
        core.append("+".join(sorted(t for _k, _c, t in tiers[:2])) or "-")
        best, roles = None, {"T": 0, "F": 0, "C": 0, "S": 0}
        for unit in board.split("|") if board else []:
            pkm = unit.split("*")[0]
            items = unit[unit.index("[") + 1:unit.index("]")] if "[" in unit else ""
            held = [i for i in items.split("+") if i]
            score = (len(held), unit_power(pkm))
            if held and (best is None or score > best[0]):
                best = (score, "%s [%s]" % (pkm, "+".join(sorted(held))))
            role = role_of.get(pkm, "")
            roles["T" if role == "tank" else "F" if role == "fighter" else "S" if role == "support" else "C"] += 1 if role else 0
        carry.append(best[1] if best else "-")
        shape.append(roles)
    out = pd.DataFrame({"core": core, "carry": carry, "resid": win - expected, "stage": stages["stage"]})
    out["T"] = [r["T"] for r in shape]
    out["F"] = [r["F"] for r in shape]
    out["C"] = [r["C"] for r in shape]
    out["S"] = [r["S"] for r in shape]
    return out


def table(df, key, least, top=10):
    g = df.groupby(key)["resid"].agg(["size", "mean", "std"])
    g = g[g["size"] >= least]
    g["se"] = g["std"] / np.sqrt(g["size"])
    return g.sort_values("mean", ascending=False), g
#endregion


def main():
    least, limit = int(tm.arg("--min", "60")), float(tm.arg("--step", "0.1"))
    rate, explore = float(tm.arg("--rate", "1")), float(tm.arg("--explore", "0"))
    bal = load_balance()
    if "--reset" in sys.argv:
        save_balance({"version": bal["version"] + 1, "pokemon": {}})
        print("balance reset (version %d): the web stats" % (bal["version"] + 1))
        return
    if "--restore" in sys.argv:
        v = int(tm.arg("--restore", "0"))
        shutil.copyfile(BACKUP % v, PATH)
        print("balance restored to version %d (%d forms)" % (v, len(load_balance()["pokemon"])))
        return
    goal = json.load(io.open(TARGETS, encoding="utf-8"))
    folders = tm.folders_of(sys.argv)
    if not folders:
        sys.exit("no batch folder")
    versions = batch_versions(folders)
    if versions and versions != {str(bal["version"])}:
        print("WARNING: batches played with balance version(s) %s, data/balance.json is version %d"
              % (",".join(sorted(versions)), bal["version"]))
    stages, units = load_batches(folders)
    if units is None:
        sys.exit("the batches have no units_*.tsv (run them without -NoUnits)")
    tracked = "ppgain" in units.columns
    effective = damage_effective(folders) # damage without overkill (else the execute abilities' 9999 counted)
    forms = {pkm: entry_of(v) for pkm, v in bal["pokemon"].items()}
    out_dir = folders[0]
    report = []
    say = lambda line="": report.append(line)

    #region 1. worth with and without items
    data = tm.matrix(stages, 5, synergies=False, item_forms=True)
    names, seen, row_of, col, val, y = data
    w, b = tm.fit(data, np.ones(len(y), dtype=bool), L2)
    p = tm.predict(data, w, b)
    info = np.bincount(col, weights=(p * (1 - p))[row_of] * val ** 2, minlength=len(names)) + L2 * len(y)
    weight = dict(zip(names, w))
    se2 = dict(zip(names, 1.0 / info))
    half = stages["run"].to_numpy() % 2 == 0 # by run: the stages of a run stay together
    weight_a = dict(zip(names, tm.fit(data, half, L2)[0]))
    weight_b = dict(zip(names, tm.fit(data, ~half, L2)[0]))
    groups = form_groups(names)
    group_of = {m: key for key, members in groups.items() for m in members}
    w_pw, w_n3 = weight.get("pw", 0.0), weight.get("n3", 0.0)
    total = {m: weight[m] + w_pw * unit_power(m[2:]) / 10.0 + (w_n3 if int(tm.POKEMON[m[2:]].get("stars", 1)) >= 3 else 0.0)
             for members in groups.values() for m in members}
    dev_f = form_devs(groups, weight, seen)
    used = {m: d for m, d in dev_f.items() if seen[m] >= least}
    tau2, c, r_forms, rho_forms = calibrate(used, form_devs(groups, weight_a, seen), form_devs(groups, weight_b, seen), se2, seen)
    targets = rarity_targets(groups, total, seen, float(goal.get("rarityGap", 0.03)))
    # items: what each item adds on the form against its group (same split-half reliability)
    def item_devs(wt):
        out = {}
        for members in groups.values():
            have = [m for m in members if seen.get("ui:" + m[2:], 0) >= 30]
            if len(have) < 3:
                continue
            mean = sum(wt.get("ui:" + m[2:], 0.0) * seen["ui:" + m[2:]] for m in have) / sum(seen["ui:" + m[2:]] for m in have)
            for m in have:
                out[m] = wt.get("ui:" + m[2:], 0.0) - mean
        return out
    d_item = item_devs(weight)
    se2_item = {m: se2["ui:" + m[2:]] for m in d_item}
    tau2_i, c_i, r_items, rho_items = calibrate(d_item, item_devs(weight_a), item_devs(weight_b), se2_item,
                                                {m: seen["ui:" + m[2:]] for m in d_item})
    item_w = float(goal.get("itemWeight", 1.5))
    #endregion

    #region 2. what each form does: profile against its role (blue units), physical / special share of its damage taken
    blue = units[units.team == "B"].copy()
    key = ["batch", "run", "stage"]
    team = blue.groupby(key)
    n_team = team["pkm"].transform("size").clip(lower=1)
    blue["sus"] = blue["heal"] + blue["shield"]
    blue["ed"] = team["dealt"].transform("sum") / n_team
    blue["et"] = team["taken"].transform("sum") / n_team
    blue["es"] = blue.groupby(key)["sus"].transform("sum") / n_team
    blue["out"] = blue["dealt"] + blue["sus"]
    agg = {"n": ("dealt", "size"), "dealt": ("dealt", "sum"), "ed": ("ed", "sum"), "taken": ("taken", "sum"),
           "et": ("et", "sum"), "sus": ("sus", "sum"), "es": ("es", "sum"), "adealt": ("adealt", "sum"),
           "out": ("out", "sum"), "role": ("role", lambda s: s.mode().iat[0])}
    if "tphys" in blue.columns:
        agg.update({"tphys": ("tphys", "sum"), "tspec": ("tspec", "sum")})
    skill_tracked = "sdealt" in blue.columns # damage / heal + shield of the ability itself (BattleSim.ability_source)
    if skill_tracked:
        agg.update({"sdealt": ("sdealt", "sum"), "ssus": ("ssus", "sum"), "casts": ("casts", "sum")})
    prof = blue.groupby("pkm").agg(**agg)
    by_role = blue.groupby("role").agg(**{k: v for k, v in agg.items() if k != "role"})
    eps = 0.05
    for frame in (prof, by_role):
        frame["D"] = frame["dealt"] / frame["ed"].clip(lower=1)
        frame["T"] = frame["taken"] / frame["et"].clip(lower=1)
        frame["S"] = frame["sus"] / frame["es"].clip(lower=1)
        frame["q"] = np.log(frame["D"] + eps) - np.log(frame["T"] + eps)
        frame["qs"] = np.log(frame["S"] + eps) - np.log(frame["D"] + eps)
        if skill_tracked: # attack share of what attacks and ability do (items / synergies / statuses apart)
            frame["skill_out"] = frame["sdealt"] + frame["ssus"]
            both = (frame["adealt"] + frame["skill_out"]).clip(lower=1)
            frame["a"] = (frame["adealt"] / both).clip(0, 1)
            frame["per_cast"] = frame["skill_out"] / frame["casts"].clip(lower=1)
        else: # older batches: everything but the attacks counted as the ability's
            frame["a"] = (frame["adealt"] / frame["out"].clip(lower=1)).clip(0, 1)
        frame.loc[frame["out"] < 1, "a"] = 0.5
        if "tphys" in frame.columns:
            frame["phys"] = (frame["tphys"] / frame["taken"].clip(lower=1)).clip(0, 1)
            frame["spec"] = (frame["tspec"] / frame["taken"].clip(lower=1)).clip(0, 1)
        else:
            frame["phys"], frame["spec"] = 0.55, 0.4
    profile = prof.to_dict("index")
    role_norm = by_role.to_dict("index")
    rel = {} # output / taken against the group (where a nerf takes from, a buff gives to)
    for members in groups.values():
        pk = [m[2:] for m in members if m[2:] in profile]
        n = sum(profile[k]["n"] for k in pk)
        out_g = sum(profile[k]["out"] / profile[k]["n"] * profile[k]["n"] for k in pk) / max(n, 1)
        taken_g = sum(profile[k]["taken"] for k in pk) / max(n, 1)
        for k in pk:
            rel[k] = (math.log((profile[k]["out"] / profile[k]["n"] + 1) / (out_g + 1)),
                      math.log((profile[k]["taken"] / profile[k]["n"] + 1) / (taken_g + 1)))
    default_prof = {"role": "fighter", "a": 0.5, "phys": 0.55, "spec": 0.4, "n": 0}
    prof_of = lambda pkm: profile.get(pkm, default_prof)
    role_of = {pkm: pr["role"] for pkm, pr in profile.items()}
    if "role" in units.columns:
        for pkm, role in units.groupby("pkm")["role"].agg(lambda s: s.mode().iat[0]).items():
            role_of.setdefault(pkm, role)
    for pkm in tm.POKEMON:
        role_of.setdefault(pkm, guess_role(pkm))
    #endregion

    #region 3. casts -> PP (both teams: the same rules)
    per_attack = role_mana()
    cast_goal = goal.get("casts", {})
    beta, (c_low, c_high) = float(goal.get("webPP", 0.5)), goal.get("castRange", [1.0, 4.0])
    with_items_max, p99_max = float(goal.get("castsWithItems", 6.0)), float(goal.get("castsP99", 10.0))
    pp_cap, pp_freeze = float(goal.get("ppStep", 1.2)), float(goal.get("ppFreeze", 0.35))
    cast_rows = units[(units.maxpp > 0) & (units.pkm.map(lambda k: float(tm.POKEMON.get(k, {}).get("maxPP", 0)) > 0))].copy()
    cast_rows["nitems"] = cast_rows["items"].map(lambda s: len(s.split("+")) if s else 0)
    pp_plan = {} # pkm -> (old PP played, wanted PP, target casts, casts now, casts now with 2+ items, how)
    role_move = {} # role -> median ln PP change of its forms (for the forms without data)
    calib, calib_source = {}, "-"
    # the casts of a fight of refFight s: fights get shorter when everyone casts more, the target follows the time
    fight_s = float(stages["fight_s"].mean())
    time_scale = fight_s / float(goal.get("refFight", 16.0))
    if tracked:
        plain_casts = cast_rows[cast_rows.nitems == 0].groupby("pkm").casts.agg(["size", "mean"])
        calib, calib_source = cast_calibration(int(bal["version"]), plain_casts[plain_casts["size"] >= 30]["mean"], fight_s)
        for pkm, rows in cast_rows.groupby("pkm"):
            role = role_of.get(pkm, "fighter")
            web_pp = float(tm.POKEMON[pkm]["maxPP"])
            target = min(max(float(cast_goal.get(role, 2.0)) * (100.0 / web_pp) ** beta, c_low), c_high) * time_scale
            plain, loaded = rows[rows.nitems == 0], rows[rows.nitems >= 2]
            pa = per_attack.get(role, 10.0)
            old_pp = float(plain["maxpp"].median() if len(plain) else rows["maxpp"].median())
            if len(plain) < 30:
                pp_plan[pkm] = (old_pp, None, target, float(rows.casts.mean()), float(loaded.casts.mean()) if len(loaded) else -1, "role")
                continue
            # the solver's casts come out x calib of what the game then gives: aim at target / calib
            want = solve_pp(plain.ppgain.to_numpy(float), plain.casts.to_numpy(float), pa, target / calib.get(role, 1.0))
            how = "casts"
            if len(loaded) >= 30:
                cap_pp = solve_pp(loaded.ppgain.to_numpy(float), loaded.casts.to_numpy(float), pa, with_items_max)
                if cap_pp > want:
                    want, how = cap_pp, "items cap"
            if len(rows) >= 100: # the rare fights of endless casting (flat PP of items / synergies, refunds)
                top_pp = solve_pp(rows.ppgain.to_numpy(float), rows.casts.to_numpy(float), pa, p99_max, 0.99)
                if top_pp > want:
                    want, how = top_pp, "p99 cap"
            pp_plan[pkm] = (old_pp, want, target, float(plain.casts.mean()), float(loaded.casts.mean()) if len(loaded) else -1, how)
        # forms with too few fights without items, or none: the median PP change of their role (the same rule for all)
        moves = {}
        for pkm, (old_pp, want, *_rest) in pp_plan.items():
            if want is not None:
                moves.setdefault(role_of.get(pkm, "fighter"), []).append(math.log(want / max(old_pp, 1)))
        role_move = {r: float(np.median(v)) for r, v in moves.items()}
        for pkm, d in tm.POKEMON.items():
            if pkm not in pp_plan and float(d.get("maxPP", 0)) > 0 and d.get("passive") != "INANIMATE":
                pp_plan[pkm] = (realized(pkm, entry_of(forms.get(pkm, 1.0)))["pp"], None,
                                min(max(float(cast_goal.get(role_of.get(pkm, "fighter"), 2.0))
                                        * (100.0 / float(d["maxPP"])) ** beta, c_low), c_high), -1.0, -1.0, "role")
    plain_of = {pkm: g for pkm, g in cast_rows[cast_rows.nitems == 0].groupby("pkm")} if tracked else {}
    #endregion

    #region 4. the lever's sensitivity
    now_m = {pkm: power_eq(pkm, e, prof_of(pkm)) for pkm, e in forms.items() if pkm in tm.POKEMON}
    s_hist, source = lever_from_history(bal["version"], {m[2:]: (d, seen[m]) for m, d in dev_f.items()}, now_m)
    ratios = []
    power = lambda k: 0.5 * math.log(max(float(tm.POKEMON[k].get("hp", 1)), 1.0) * entry_of(forms.get(k, 1.0)).get("hp", 1.0)
                                     * max(float(tm.POKEMON[k].get("atk", 1)), 1.0) * entry_of(forms.get(k, 1.0)).get("atk", 1.0))
    for name in names:
        pkm = name[2:]
        nxt = tm.POKEMON.get(pkm, {}).get("evolution", "")
        if not name.startswith("u:") or "u:" + nxt not in total or name not in total or seen[name] < 100 \
                or seen["u:" + nxt] < 100:
            continue
        if tm.POKEMON[nxt].get("rarity") != tm.POKEMON[pkm].get("rarity"):
            continue
        dl = power(nxt) - power(pkm)
        if dl > 0.1:
            ratios.append((total["u:" + nxt] - total[name]) / dl)
    sens_evo = min(max(float(np.median(ratios)) if len(ratios) >= 5 else 0.5, 0.2), 3.0)
    sens = float(tm.arg("--sens", s_hist if s_hist is not None else max(sens_evo, 0.6)))
    #endregion

    #region 5. the steps
    rng = np.random.default_rng(1000 + int(bal["version"]))
    cap = math.log(1.0 + limit)
    r_strength, r_step = float(goal.get("roleStrength", 0.5)), float(goal.get("roleStep", 0.1))
    profile_goal, sustain_min = goal.get("roleProfile", {}), float(goal.get("supportSustain", 0.4))
    share_goal = goal.get("skillShare", {})
    rows, imbalance = [], [0.0, 0.0]
    all_forms = sorted(set(m[2:] for members in groups.values() for m in members) | set(pp_plan))
    for pkm in all_forms:
        if pkm not in tm.POKEMON:
            continue
        m = "u:" + pkm
        n = seen.get(m, 0)
        pr = prof_of(pkm)
        role = role_of.get(pkm, pr["role"])
        old = entry_of(forms.get(pkm, 1.0))
        new = dict(old)
        web_pp = float(tm.POKEMON[pkm].get("maxPP", 0))
        # PP
        old_pp, want, c_target, c_now, c_items, how = pp_plan.get(pkm, (realized(pkm, old)["pp"], None, 0.0, -1.0, -1.0, "-"))
        pp_step = 0.0
        if want is not None:
            pp_step = max(min(math.log(want / max(old_pp, 1.0)), pp_cap), -pp_cap)
        elif how == "role" and role in role_move:
            pp_step = max(min(role_move[role], pp_cap), -pp_cap)
        if web_pp > 0 and pp_step != 0.0:
            new["pp"] = min(max(old_pp * math.exp(pp_step) / web_pp, BOUNDS["pp"][0]), BOUNDS["pp"][1])
        # its PP in the game (tens) moves a lot: its power and role are measured again first
        frozen = web_pp > 0 and abs(math.log(max(realized(pkm, new)["pp"], 1) / max(old_pp, 1.0))) > pp_freeze
        # power: worth (without items + per item) against its group and the rarity order
        key = group_of.get(m)
        dev0 = sdev0 = dit = sdit = shift = dev = dp = sigma = 0.0
        if key is not None:
            dev0 = dev_f.get(m, 0.0)
            sdev0 = dev0 * tau2 / (tau2 + c * se2[m])
            if m in d_item:
                dit = d_item[m]
                sdit = dit * tau2_i / (tau2_i + c_i * se2_item[m])
            mean_rs, target_rs = targets.get(key[:2], (0.0, 0.0))
            shift = target_rs - mean_rs
            dev = sdev0 + item_w * sdit - shift
            imbalance[0] += abs(dev) * n
            imbalance[1] += n
        moved_power = key is not None and n >= least and not frozen
        extra = {}
        levers = skill_levers(pkm)
        skill_shift = 0.0
        if moved_power:
            dp = -rate * dev / sens + (float(rng.uniform(-explore, explore)) if explore > 0 else 0.0)
            # role: its profile q = ln(D / T) within the one of its role (roleProfile), else offence <-> bulk (same power)
            if pr["n"] >= least and (effective or not executes(pkm)): # an execute's overkill is no profile
                lo, hi = profile_goal.get(role) or [None, None]
                if hi is not None and pr["q"] > hi:
                    sigma = hi - pr["q"] # deals too much for what it takes: toward bulk
                elif lo is not None and pr["q"] < lo:
                    sigma = lo - pr["q"] # takes too much for what it deals: toward offence
                if role == "support" and pr["qs"] < sustain_min:
                    move = min(r_strength * (sustain_min - pr["qs"]), r_step)
                    # deals more than its share: Attack down; else heals / shields too little: a stronger ability
                    # (one that heals / shields nothing has only its PP for it)
                    extra = {"atk": -move} if pr["D"] > 1.0 else ({"skill": move} if "skill" in levers else {})
                    if extra:
                        shift_off = pr["a"] * extra.get("atk", 0.0) + (1 - pr["a"]) * extra.get("skill", 0.0)
                        extra["hp"] = extra["def"] = extra["speDef"] = -shift_off # same power
                sigma = max(min(r_strength * sigma, r_step), -r_step)
                # skill against attack output (skillShare of its role): between Attack / speed and the ability's
                # strength, same offence
                lo_s, hi_s = share_goal.get(role) or [None, None]
                s_share = min(max(1.0 - pr["a"], 0.02), 0.98)
                logit = lambda v: math.log(v / (1.0 - v))
                if "skill" in levers and lo_s is not None and s_share < lo_s:
                    skill_shift = min(r_strength * (logit(lo_s) - logit(s_share)), r_step)
                elif "skill" in levers and hi_s is not None and s_share > hi_s:
                    skill_shift = max(r_strength * (logit(hi_s) - logit(s_share)), -r_step)
        delta = 2.0 * dp
        prior = ROLE_OFFENCE.get(role, 0.5)
        off_r, def_r = rel.get(pkm, (0.0, 0.0))
        sign = 1.0 if delta < 0 else -1.0 # a nerf from where it outdoes its group, a buff to where it falls short
        w_off = prior * math.exp(max(min(sign * off_r, 1.5), -1.5))
        w_def = (1 - prior) * math.exp(max(min(sign * def_r, 1.5), -1.5))
        d_off = delta * w_off / (w_off + w_def) + sigma
        d_bulk = delta * w_def / (w_off + w_def) - sigma
        if moved_power or extra:
            new = step_stats(pkm, new, d_off, d_bulk, pr if pr["n"] else default_prof, cap, extra, levers, skill_shift)
        if new != old:
            forms[pkm] = new
        dq_row = pr["q"] - role_norm[role]["q"] if pr["n"] and role in role_norm else 0.0
        new_pp = realized(pkm, new)["pp"]
        pred = -1.0
        if pkm in plain_of and web_pp > 0:
            plain = plain_of[pkm]
            pred = float(predicted_casts(plain.ppgain.to_numpy(float), plain.casts.to_numpy(float),
                                         per_attack.get(role, 10.0), new_pp).mean())
        rows.append({"kind": "pokemon", "name": pkm, "group": "%s*%d/%d" % key if key else "-", "role": role, "n": n,
                     "units": int(pr["n"]), "worth": total.get(m, 0.0), "target": targets.get(key[:2], (0, 0))[1] if key else 0.0,
                     "weight": weight.get(m, 0.0), "se": math.sqrt(se2.get(m, 0.0)), "dev": dev0, "shrunk": sdev0,
                     "item": dit, "item_shrunk": sdit, "rarity_shift": shift, "dev_used": dev, "dp": dp, "sigma": sigma,
                     "a": pr["a"], "D": pr.get("D", 0.0), "T": pr.get("T", 0.0), "S": pr.get("S", 0.0),
                     "q": pr.get("q", 0.0), "dq": dq_row,
                     "phys": pr["phys"], "levers": "+".join(levers) or "-", "scales": "+".join(sorted(skill_scaling(pkm))) or "-",
                     "skill_shift": skill_shift, "per_cast": pr.get("per_cast", -1.0),
                     "casts": c_now, "casts_items": c_items, "cast_target": c_target,
                     "casts_after": pred, "pp_old": old_pp, "pp_new": new_pp, "pp_how": how,
                     "old": power_eq(pkm, old, pr if pr["n"] else default_prof),
                     "new": power_eq(pkm, new, pr if pr["n"] else default_prof),
                     **{"step_" + k: new.get(k, 1.0) / old.get(k, 1.0) for k in KNOBS}})
    #endregion

    #region 6. information: synergies and items of the full model (with the synergy features)
    full = tm.matrix(stages, 5)
    wf, _bf = tm.fit(full, np.ones(len(full[5]), dtype=bool), L2)
    wfull, seen_full = dict(zip(full[0], wf)), full[1]
    tiers = {}
    for name in full[0]:
        if name.startswith("sy:"):
            _p, t, k = name.split(":")
            tiers.setdefault(t, {})[int(k)] = name
    first = {t: ks[min(ks)] for t, ks in tiers.items()}
    cum = {t: sum(wfull[nm] for nm in ks.values()) for t, ks in tiers.items()}
    mean_cum = sum(cum[t] * seen_full[first[t]] for t in cum) / max(sum(seen_full[first[t]] for t in cum), 1)
    for t in sorted(cum):
        rows.append({"kind": "synergy", "name": t, "group": "tiers %d" % len(tiers[t]), "n": seen_full[first[t]],
                     "weight": cum[t], "dev": cum[t] - mean_cum})
    held = [(nm[3:], seen_full[nm]) for nm in full[0] if nm.startswith("it:") and seen_full[nm] >= least]
    item_mean = sum(wfull["it:" + i] * k for i, k in held) / max(sum(k for _i, k in held), 1)
    for item, k in held:
        rows.append({"kind": "item", "name": item, "n": k, "weight": wfull["it:" + item], "dev": wfull["it:" + item] - item_mean})
    #endregion

    dry = "--dry" in sys.argv
    suffix = ".dry" if dry else "" # a dry run does not overwrite the record of the step taken from these batches
    step = pd.DataFrame(rows)
    step.to_csv(os.path.join(out_dir, "balance_step%s.tsv" % suffix), sep="\t", index=False, float_format="%.3f")
    pk = step[step.kind == "pokemon"]
    moved = pk[(pk.new / pk.old - 1).abs() >= 0.005]
    pp_moved = pk[(pk.pp_new != pk.pp_old) & (pk.pp_old > 0)]

    #region 7. the report: casts, roles, items, rarity, strategies
    say("Balance step from %d stages of %s (balance version %d, method 4: tools/bot/balance_targets.json)"
        % (len(stages), ", ".join(os.path.relpath(d, tm.ROOT) for d in folders), bal["version"]))
    say("sensitivity %.2f log-odds per ln m (measured: %s; evolutions %.2f, %d pairs); reliability of the forms' worth %.2f"
        " (split-half %.2f)" % (sens, source, sens_evo, len(ratios), r_forms, rho_forms))
    say("imbalance %.3f (mean |deviation used| of the forms' worth, log-odds, weighted by use); power moved on %d forms,"
        " PP on %d" % (imbalance[0] / max(imbalance[1], 1), len(moved), len(pp_moved)))
    say()
    if tracked:
        say("== Casts per fight (both teams, forms with an ability): mean / share with none / per 10 s alive")
        st = stages[["batch", "run", "stage", "fight_s"]].drop_duplicates(["batch", "run", "stage"])
        cr = cast_rows.merge(st, on=["batch", "run", "stage"], how="left")
        cr["alive_s"] = np.where(cr["t_dead"] >= 0, cr["t_dead"], cr["fight_s"]).clip(1, None)
        say("fight length: mean %.1f s, median %.1f s; the targets are for a fight of %.0f s: x %.2f here" % (
            st.fight_s.mean(), st.fight_s.median(), float(goal.get("refFight", 16.0)), time_scale))
        say("%-9s %6s %22s %22s %22s %8s" % ("role", "n", "0 item", "1 item", "2+ items", "target"))
        for role in ["tank", "fighter", "assassin", "marksman", "caster", "support"]:
            r = cr[cr.role == role]
            cells = []
            for sel in (r[r.nitems == 0], r[r.nitems == 1], r[r.nitems >= 2]):
                cells.append("%.2f %3.0f%% %.2f/10s" % (sel.casts.mean(), 100 * (sel.casts == 0).mean(),
                                                         (sel.casts / sel.alive_s).mean() * 10) if len(sel) else "-")
            say("%-9s %6d %22s %22s %22s %8.1f" % (role, len(r), cells[0], cells[1], cells[2],
                                                    float(cast_goal.get(role, 2.0)) * time_scale))
        hi = cr.groupby("pkm").casts.quantile(0.99)
        say("99th percentile of casts in a fight: %s" % ", ".join("%s %.0f" % (k, v) for k, v in hi.sort_values().tail(6).items()))
        say("PP to cast: %d forms moved (%s); predicted casts without items after the step (mean of the forms): %.2f"
            % (len(pp_moved), ", ".join("%s %d" % (h, k) for h, k in pp_moved.pp_how.value_counts().items()),
               pk[pk.casts_after >= 0].casts_after.mean() if (pk.casts_after >= 0).any() else -1))
        say("  by role, PP before -> after (median): " + ", ".join(
            "%s %d -> %d" % (r, g.pp_old.median(), g.pp_new.median()) for r, g in pk[pk.pp_old > 0].groupby("role")))
        say("  casts now / predicted by the previous step (%s): %s" % (calib_source, ", ".join(
            "%s %.2f" % (r, v) for r, v in sorted(calib.items())) or "-"))
        say()
    say("== Roles: profile against an even share of the team (D dealt, T taken, S heal + shield; 1 = even), blue units;"
        " q = ln(D / T) and its range for the role (roleProfile)")
    for role, nr in sorted(role_norm.items()):
        mine = pk[(pk.role == role) & (pk.units >= least)]
        lo, hi = profile_goal.get(role) or [None, None]
        mask = pd.Series(False, index=mine.index)
        if hi is not None:
            mask |= mine.q > hi
        if lo is not None:
            mask |= mine.q < lo
        out = mine[mask]
        say("%-9s D %.2f T %.2f S %.2f q %+.2f (range %s..%s): %d / %d forms out | most offensive: %s | most defensive: %s" % (
            role, nr["D"], nr["T"], nr["S"], nr["q"], "-" if lo is None else "%+.2f" % lo, "-" if hi is None else "%+.2f" % hi,
            len(out), len(mine),
            ", ".join("%s (D %.2f T %.2f)" % (r.name, r.D, r.T) for r in mine.sort_values("q").tail(3).iloc[::-1].itertuples()),
            ", ".join("%s (D %.2f T %.2f)" % (r.name, r.D, r.T) for r in mine.sort_values("q").head(3).itertuples())))
    shaped = pk[pk.sigma.abs() > 0.001]
    say("offence <-> bulk moved on %d forms (tanks toward bulk %d, carries toward offence %d, fighters %d); supports"
        " Attack -> skill / more skill: %d" % (
        len(shaped), int(((shaped.role == "tank") & (shaped.sigma < 0)).sum()),
        int((shaped.role.isin(CARRIES) & (shaped.sigma > 0)).sum()), int((shaped.role == "fighter").sum()),
        int(((pk.role == "support") & ((pk.step_atk < 0.995) | (pk.step_skill > 1.005)) & (pk.sigma.abs() <= 0.001)).sum())))
    say()
    say("== Ability against attack: output of the ability (damage + heal + shield%s) / of the basic attacks; skillShare of"
        " the role" % ("" if skill_tracked else "; this batch has no sdealt: all but the attacks"))
    say("what scales the abilities (forms, levers of the balance): " + ", ".join(
        "%s %d" % (k, v) for k, v in pk.groupby("levers").size().sort_values(ascending=False).items()))
    for role, nr in sorted(role_norm.items()):
        lo_s, hi_s = share_goal.get(role) or [None, None]
        mine = pk[(pk.role == role) & (pk.units >= least)]
        share = 1.0 - mine.a
        out_s = int(((share < lo_s) if lo_s is not None else share < -1).sum() + ((share > hi_s) if hi_s is not None else share > 2).sum())
        line = "%-9s attacks %2.0f%% / ability %2.0f%% (range %s..%s, %d / %d forms out)" % (
            role, 100 * nr["a"], 100 * (1 - nr["a"]), "-" if lo_s is None else "%.0f%%" % (100 * lo_s),
            "-" if hi_s is None else "%.0f%%" % (100 * hi_s), out_s, len(mine))
        if skill_tracked:
            top = mine[mine.per_cast > 0].sort_values("per_cast").tail(3).iloc[::-1]
            line += "; per cast %.0f, biggest: %s" % (nr["per_cast"], ", ".join("%s %.0f" % (r.name, r.per_cast) for r in top.itertuples()))
        say(line)
    shifted = pk[pk.skill_shift.abs() > 0.001]
    say("attack <-> ability moved on %d forms (toward the ability %d, toward the attack %d)" % (
        len(shifted), int((shifted.skill_shift > 0).sum()), int((shifted.skill_shift < 0).sum())))
    say()
    say("== Items: what each item adds on the form, against its group (log-odds per item; reliability %.2f, split-half %.2f)"
        % (r_items, rho_items))
    it = pk[pk.item_shrunk.abs() > 0].sort_values("item_shrunk")
    say("best with items: " + ", ".join("%s %+.2f" % (r.name, r.item_shrunk) for r in it.tail(8).iloc[::-1].itertuples()))
    say("worst with items: " + ", ".join("%s %+.2f" % (r.name, r.item_shrunk) for r in it.head(8).itertuples()))
    ranked = pk[pk.n >= least].assign(bare=lambda f: f.shrunk - f.rarity_shift,
                                      full=lambda f: f.shrunk + 3 * f.item_shrunk - f.rarity_shift)
    say("stronger than their group without items: " + ", ".join(
        "%s %+.2f" % (r.name, r.bare) for r in ranked.sort_values("bare").tail(6).iloc[::-1].itertuples()))
    say("stronger than their group with 3 items:  " + ", ".join(
        "%s %+.2f" % (r.name, r.full) for r in ranked.sort_values("full").tail(6).iloc[::-1].itertuples()))
    say()
    say("== Rarity order (total worth without items of a form, use-weighted; target = ordered, +%.2f a rarity step)"
        % float(goal.get("rarityGap", 0.03)))
    for stars in sorted(set(s for _r, s in targets)):
        say("  %d*: " % stars + "  ".join("%s %.2f->%.2f" % (r[:3], targets[(r, stars)][0], targets[(r, stars)][1])
                                         for r in SHOP if (r, stars) in targets))
    say()
    strat = strategies(stages, role_of)
    best, _all = table(strat[strat.carry != "-"], ["core", "carry"], 30)
    say("== Strategies (2 main synergies + carry = the unit with the most items): win rate against the stage mean, 30+ fights")
    for (core, carry), r in best.head(12).iterrows():
        say("  %+.3f +-%.3f  n %5d  %s | %s" % (r["mean"], r["se"], r["size"], core, carry))
    if len(best) >= 10:
        say("  spread: sd %.3f over %d strategies; best %+.3f, 90th %+.3f, median %+.3f, worst %+.3f" % (
            best["mean"].std(), len(best), best["mean"].iloc[0], best["mean"].quantile(0.9), best["mean"].median(),
            best["mean"].iloc[-1]))
    cores, _c = table(strat, "core", 100)
    say("  2 main synergies, best: " + ", ".join("%s %+.3f" % (k, r["mean"]) for k, r in cores.head(6).iterrows())
        + " | worst: " + ", ".join("%s %+.3f" % (k, r["mean"]) for k, r in cores.tail(4).iterrows()))
    strat = strat.assign(cpkm=strat.carry.str.split(" ").str[0], main=strat.core.str.split("+").str[0])
    carries = table(strat[strat.cpkm != "-"], "cpkm", 60)[0]
    say("  carries, best: " + ", ".join("%s %+.3f" % (k, r["mean"]) for k, r in carries.head(8).iterrows()))
    if len(carries) >= 10:
        say("    spread of the carries: sd %.3f over %d; best %+.3f, 90th %+.3f, median %+.3f" % (
            carries["mean"].std(), len(carries), carries["mean"].iloc[0], carries["mean"].quantile(0.9), carries["mean"].median()))
    kits = table(strat[strat.cpkm != "-"], "carry", 30)[0]
    say("  carry + its items, best: " + ", ".join("%s %+.3f (n %d)" % (k, r["mean"], r["size"]) for k, r in kits.head(6).iterrows()))
    duo = table(strat[strat.cpkm != "-"], ["core", "cpkm"], 30)[0]
    say("  2 main synergies + carry, best: " + ", ".join("%s / %s %+.3f (n %d)" % (k[0], k[1], r["mean"], r["size"])
                                                        for k, r in duo.head(6).iterrows()))
    say("== Role structure of the board (T tank, F fighter, C carry, S support): win rate against the stage mean")
    late = strat[strat.stage >= 8]
    named = {"cân bằng (≥1 tank, ≥2 carry)": (late["T"] >= 1) & (late["C"] >= 2),
             "không tank / fighter": (late["T"] == 0) & (late["F"] == 0),
             "không carry": late["C"] == 0,
             "1 carry + ≥2 support": (late["C"] == 1) & (late["S"] >= 2),
             "≥3 support": late["S"] >= 3}
    for name, sel in named.items():
        if sel.sum() >= 30:
            say("  %-30s %+.3f  n %d" % (name, late.loc[sel, "resid"].mean(), int(sel.sum())))
    late = late.assign(shape=["T%d F%d C%d S%d" % t for t in zip(late["T"], late["F"], late["C"], late["S"])])
    shapes, _s = table(late, "shape", 150)
    say("  most common shapes: " + ", ".join("%s %+.3f (n %d)" % (k, r["mean"], r["size"])
                                           for k, r in shapes.sort_values("size", ascending=False).head(8).iterrows()))
    say()
    pct = lambda v: "%+.0f%%" % (100 * (v - 1))
    fmt = lambda r: "%s %s (hp %s atk %s def %s spd %s skill %s pp %s)" % (
        r.name, r.role, pct(r.step_hp), pct(r.step_atk), pct(r.step_def), pct(r.step_speed), pct(r.step_skill), pct(r.step_pp))
    say("strongest moved down: " + ", ".join(fmt(r) for r in moved.sort_values("dp").head(6).itertuples()))
    say("weakest moved up:     " + ", ".join(fmt(r) for r in moved.sort_values("dp").tail(6).iloc[::-1].itertuples()))
    syn = step[step.kind == "synergy"].sort_values("dev", ascending=False)
    say("synergies (full model, information): " + ", ".join("%s %+.2f" % (r.name, r.dev) for r in syn.head(5).itertuples())
        + " ... " + ", ".join("%s %+.2f" % (r.name, r.dev) for r in syn.tail(5).itertuples()))
    text = "\n".join(report) + "\n"
    io.open(os.path.join(out_dir, "balance_report%s.txt" % suffix), "w", encoding="utf-8", newline="\n").write(text)
    print(text)
    #endregion

    wrong = negative_stats(forms)
    if wrong: # BOUNDS keep every multiplier > 0: never a negative stat (a too strong ability: lower skill, more PP)
        raise SystemExit("autobalance: a stat would go below 0: %s" % wrong[:10])
    if dry:
        print("dry run: data/balance.json unchanged (no stat below 0)")
        return
    written = save_balance({"version": bal["version"] + 1, "pokemon": forms})
    with io.open(STATS, "w", encoding="utf-8", newline="\n") as f:
        cols = ["hp", "atk", "def", "speDef", "speed", "pp"]
        f.write("pkm\trarity\tstars\trole\t" + "\t".join("%s_web\t%s" % (c, c) for c in cols) + "\tskill\n")
        for pkm, e in written.items():
            d = tm.POKEMON.get(pkm, {})
            now = realized(pkm, e)
            web = {"hp": d.get("hp", 0), "atk": d.get("atk", 0), "def": d.get("def", 0), "speDef": d.get("speDef", 0),
                   "speed": d.get("speed", 0), "pp": d.get("maxPP", 0)}
            f.write("\t".join(str(x) for x in [pkm, d.get("rarity", ""), d.get("stars", ""), role_of.get(pkm, "")]
                              + sum(([web[c], now[c]] for c in cols), []) + [now["skill"]]) + "\n")
    print("data/balance.json -> version %d (%d forms with their own stats; table %s); version %d kept as %s"
          % (bal["version"] + 1, len(written), os.path.relpath(STATS, tm.ROOT), bal["version"], os.path.relpath(BACKUP % bal["version"], tm.ROOT)))
    new_file = not os.path.exists(HISTORY)
    with io.open(HISTORY, "a", encoding="utf-8", newline="\n") as f:
        if new_file:
            f.write("version\tstages\tsens\tr_pkm\tr_syn\timb_pkm\timb_syn\tchanges\tnerfs\tbuffs\tfolders\n")
        f.write("%d\t%d\t%.3f\t%.2f\t\t%.4f\t\t%d\t%d\t%d\t%s\n" % (bal["version"], len(stages), sens, r_forms,
                imbalance[0] / max(imbalance[1], 1), len(moved) + len(pp_moved), int((moved.new < moved.old).sum()),
                int((moved.new > moved.old).sum()), ",".join(os.path.relpath(d, tm.ROOT) for d in folders)))


if __name__ == "__main__":
    main()
