#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Seasons of the Godot port (data/seasons.json, docs/SEASONS.md) - not in the web game.

A season is a fixed roster for a run: the families of the shop, the Unique / Legendary Pokémon of
the portals and the lines hatching from eggs. See docs/SEASONS.md.

  python tools/port/gen_seasons.py              checks data/seasons.json and writes docs/SEASONS.md again
                                                (run it after editing the JSON by hand)
  python tools/port/gen_seasons.py --generate   computes the rosters again from the parameters below
                                                (overwrites data/seasons.json: hand edits are lost)

The rosters are found by simulated annealing (fixed seed: the same parameters give the same file).
"""
import collections
import json
import math
import os
import random
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT_JSON = os.path.join(ROOT, "data", "seasons.json")
OUT_DOC = os.path.join(ROOT, "docs", "SEASONS.md")

# ---------------------------------------------------------------------------------------------
# Parameters of --generate
# ---------------------------------------------------------------------------------------------
SEED = 20261115
RARITIES = ["COMMON", "UNCOMMON", "RARE", "EPIC", "ULTRA"]
## Families of the shop per rarity, in every season (the web shop starts with 22 / 23 / 18 / 17 / 14
## and ends with 22 / 31 / 26 / 25 / 14 once the additional picks are in).
QUOTA = {"COMMON": 19, "UNCOMMON": 24, "RARE": 22, "EPIC": 19, "ULTRA": 12}
## Families of a synergy in the shop of a season: the regular synergies, and the special ones (few
## Pokémon, thresholds of their own).
COMMON_RANGE = (8, 10)
SPECIAL_RANGE = (3, 5)
## The seasons. `featured`: the synergies that are regular in this season and special in the others.
## Every synergy never featured is regular everywhere.
SEASONS = [
    {
        "id": "s1",
        "name": "Season 1: Genesis",
        "description": "The classic line-up of the web game: the starters and the best-known lines.",
        "featured": ["WILD", "BABY", "FLORA", "DRAGON"],
        "prefer_base": 3.0,  # cost of each family that is not in the starting shop of the web game
    },
    {
        "id": "s2",
        "name": "Season 2: Ancient Ruins",
        "description": "Fossils wake up, ghosts roam the ruins and explorers teach their moves.",
        "featured": ["FOSSIL", "HUMAN", "SOUND", "GHOST"],
        "prefer_base": 0.0,
    },
    {
        "id": "s3",
        "name": "Season 3: Festival of Lights",
        "description": "Machines, lanterns and banquets: a festival where strange shapes dance.",
        "featured": ["ARTIFICIAL", "LIGHT", "GOURMET", "AMORPHOUS"],
        "prefer_base": 0.0,
    },
]
## Families left out of every season, with the reason.
EXCLUDED = {
    "DEERLING_SPRING": "its form follows today's date: not a fixed roster",
    "DEERLING_SUMMER": "its form follows today's date: not a fixed roster",
    "DEERLING_AUTUMN": "its form follows today's date: not a fixed roster",
    "DEERLING_WINTER": "its form follows today's date: not a fixed roster",
    "BURMY_SANDY": "its Mothim belongs to the Burmy (Plant) family",
    "BURMY_TRASH": "its Mothim belongs to the Burmy (Plant) family",
    "SHEDINJA": "not a line of the shop: it comes with Ninjask when Nincada evolves",
}
## Families that are one entry of a roster: listed together, counted once (one colour per run).
GROUPS = {"FLABEBE": ["FLABEBE", "FLABEBE_YELLOW", "FLABEBE_ORANGE", "FLABEBE_BLUE", "FLABEBE_WHITE"]}
## The synergies a new Battle Pass starts with (data/progression.json: the ones in no level) and the
## families it needs in every rarity of a season at level 1.
MIN_OPEN_AT_PASS_1 = 6
ITERATIONS = 400000
# ---------------------------------------------------------------------------------------------

COST = {"COMMON": 1, "UNCOMMON": 2, "RARE": 3, "EPIC": 4, "ULTRA": 5}
LETTER = {"COMMON": "C", "UNCOMMON": "U", "RARE": "R", "EPIC": "E", "ULTRA": "Ul"}


def load_json(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as f:
        return json.load(f)


class Game:
    """What the tool needs from data/pac: the families of every list, their types and rarities."""

    def __init__(self):
        self.pk = load_json("data", "pac", "pokemon.json")
        self.pool = load_json("data", "pac", "pool.json")
        self.cfg = load_json("data", "pac", "config.json")
        self.text = load_json("data", "pac", "text.json")
        self.thresholds = {t: [int(x) for x in v] for t, v in self.cfg["synergyThresholds"].items()}
        self.types = list(self.thresholds.keys())
        prog = load_json("data", "progression.json")
        later = set(t for lvl in prog.get("levels", []) for t in lvl.get("synergies", []))
        self.start_types = [t for t in self.types if t not in later]
        self.gates = list(prog.get("gatedBy", ["WILD"]))
        self.duos = self.pool.get("duos", {})
        # family -> its forms, per list
        self.lists = {}
        for name in ["pool", "additional", "regional", "unique", "legendary", "hatch"]:
            fams = collections.OrderedDict()
            for p in self.pool.get(name, []):
                d = self.pk.get(p)
                if d:
                    fams.setdefault(d.get("family", p), []).append(p)
            self.lists[name] = fams
        self.source = {}  # shop family -> pool / additional / regional
        for name in ["pool", "additional", "regional"]:
            for fam in self.lists[name]:
                self.source[fam] = name

    def forms(self, fam):
        for name in self.lists:
            if fam in self.lists[name]:
                return self.lists[name][fam]
        return [fam] if fam in self.pk else []

    def first(self, fam):
        forms = self.forms(fam)
        return self.pk[fam] if fam in self.pk and self.pk[fam]["stars"] == 1 else self.pk[forms[0]]

    def rarity(self, fam):
        return self.first(fam)["rarity"]

    def first_types(self, fam):
        return list(self.first(fam).get("types", []))

    def all_types(self, fam):
        """Types of any form of the family: what the synergy tooltip of the game lists."""
        out = []
        for f in self.forms(fam):
            for t in self.pk[f].get("types", []):
                if t not in out:
                    out.append(t)
        return out

    def index_group(self, fam):
        return self.first(fam)["index"].split("-")[0]

    def name(self, pkm):
        n = self.text.get("pkm", {}).get(pkm)
        return n if isinstance(n, str) and n else pkm.replace("_", " ").title()

    def type_name(self, t):
        return t.capitalize()

    def open_at_pass_1(self, fam):
        types = self.first_types(fam)
        if any(t in self.gates for t in types):
            return False
        return any(t in self.start_types for t in types)


def group_of(fam):
    for key, members in GROUPS.items():
        if fam in members:
            return key
    return fam


def fit_thresholds(orig, n):
    """Thresholds of a synergy that has `n` families in the shop of a season: the ones of the web game
    when the last one can be reached with those families, else as many tiers from 2 up to `n` (to
    tiers + 1 when there are fewer families than that: the last tiers then need a Unique, a
    Legendary or a synergy item)."""
    if not orig or orig[-1] <= n:
        return list(orig)
    k = len(orig)
    if k == 1:
        return [min(orig[0], max(n, 2))]
    top = max(n, k + 1)
    out = [2 + (i * (top - 2)) // (k - 1) for i in range(k)]
    for i in range(1, k):
        out[i] = max(out[i], out[i - 1] + 1)
    return out


# ---------------------------------------------------------------------------------------------
# --generate
# ---------------------------------------------------------------------------------------------
class Unit:
    """One entry of a shop roster: a family (or a group of families counted once)."""

    def __init__(self, game, key, members):
        self.key = key
        self.members = members
        self.rarity = game.rarity(members[0])
        self.types = game.all_types(members[0])
        self.index_group = game.index_group(members[0])
        self.base = game.source[members[0]] == "pool"
        self.open1 = game.open_at_pass_1(members[0])
        self.cost = COST[self.rarity]


def shop_units(game):
    units = collections.OrderedDict()
    for fam in game.source:
        if fam in EXCLUDED or game.rarity(fam) not in RARITIES:
            continue
        key = group_of(fam)
        if key in units:
            continue
        members = [m for m in GROUPS.get(key, [fam]) if m in game.source]
        units[key] = Unit(game, key, members)
    return units


class SeasonState:
    def __init__(self, game, spec, featured_anywhere):
        self.spec = spec
        self.chosen = {r: set() for r in RARITIES}
        self.cnt = {t: 0 for t in game.types}
        self.low = {t: 0 for t in game.types}
        self.high = {t: 0 for t in game.types}
        self.open1 = {r: 0 for r in RARITIES}
        self.non_base = 0
        self.groups = collections.Counter()
        self.range = {}
        self.common = {}
        for t in game.types:
            special = t in featured_anywhere and t not in spec["featured"]
            self.common[t] = not special
            if special:
                self.range[t] = SPECIAL_RANGE
            else:
                top = game.thresholds[t][-1]
                self.range[t] = (max(COMMON_RANGE[0], min(top, COMMON_RANGE[1])), COMMON_RANGE[1])

    def apply(self, unit, sign):
        for t in unit.types:
            self.cnt[t] += sign
            if unit.cost <= 2:
                self.low[t] += sign
            elif unit.cost >= 4:
                self.high[t] += sign
        if unit.open1:
            self.open1[unit.rarity] += sign
        if not unit.base:
            self.non_base += sign
        self.groups[unit.index_group] += sign
        if sign > 0:
            self.chosen[unit.rarity].add(unit.key)
        else:
            self.chosen[unit.rarity].discard(unit.key)

    def cost(self):
        c = 0.0
        for t, n in self.cnt.items():
            lo, hi = self.range[t]
            if n < lo:
                c += 10.0 * (lo - n) ** 2
            elif n > hi:
                c += 10.0 * (n - hi) ** 2
            if self.common[t]:
                if self.low[t] < 2:
                    c += 3.0 * (2 - self.low[t])
                if self.high[t] < 2:
                    c += 3.0 * (2 - self.high[t])
            elif self.low[t] + self.high[t] == 0 and n > 0:
                c += 1.0
        for r in RARITIES:
            if self.open1[r] < MIN_OPEN_AT_PASS_1:
                c += 8.0 * (MIN_OPEN_AT_PASS_1 - self.open1[r])
        c += self.spec.get("prefer_base", 0.0) * self.non_base
        return c


def generate(game):
    rng = random.Random(SEED)
    units = shop_units(game)
    by_rarity = {r: [u for u in units.values() if u.rarity == r] for r in RARITIES}
    featured_anywhere = set(t for s in SEASONS for t in s["featured"])
    states = [SeasonState(game, spec, featured_anywhere) for spec in SEASONS]
    uses = collections.Counter()
    # how much two seasons sharing a family costs: little where the game has few families to share
    share_cost = {}
    for r in RARITIES:
        need = QUOTA[r] * len(SEASONS)
        share_cost[r] = 2.5 if len(by_rarity[r]) >= need else 0.6
    # start: random rosters respecting the quotas and one family per Pokédex number
    for st in states:
        for r in RARITIES:
            order = by_rarity[r][:]
            rng.shuffle(order)
            order.sort(key=lambda u: uses[u.key])
            for u in order:
                if len(st.chosen[r]) >= QUOTA[r]:
                    break
                if st.groups[u.index_group] > 0:
                    continue
                st.apply(u, 1)
                uses[u.key] += 1
    def total():
        return sum(st.cost() for st in states) + sum(share_cost[units[k].rarity] * (n - 1) for k, n in uses.items() if n > 1)
    current = total()
    best = current
    best_sets = [{r: set(st.chosen[r]) for r in RARITIES} for st in states]
    t0, t1 = 6.0, 0.02
    for it in range(ITERATIONS):
        temp = t0 * (t1 / t0) ** (it / ITERATIONS)
        si = rng.randrange(len(states))
        st = states[si]
        r = RARITIES[rng.randrange(len(RARITIES))]
        if len(by_rarity[r]) <= QUOTA[r]:
            continue
        out_key = rng.choice(tuple(st.chosen[r]))
        cand = by_rarity[r][rng.randrange(len(by_rarity[r]))]
        if cand.key in st.chosen[r]:
            continue
        out = units[out_key]
        if st.groups[cand.index_group] - (1 if out.index_group == cand.index_group else 0) > 0:
            continue
        before = st.cost()
        st.apply(out, -1)
        st.apply(cand, 1)
        delta = st.cost() - before
        if uses[out_key] > 1:
            delta -= share_cost[r]
        if uses[cand.key] >= 1:
            delta += share_cost[r]
        if delta <= 0 or rng.random() < math.exp(-delta / temp):
            uses[out_key] -= 1
            uses[cand.key] += 1
            current += delta
            if current < best - 1e-9:
                best = current
                best_sets = [{rr: set(s.chosen[rr]) for rr in RARITIES} for s in states]
        else:
            st.apply(cand, -1)
            st.apply(out, 1)
    print("annealing: cost %.1f" % best)
    seasons = []
    for spec, sets in zip(SEASONS, best_sets):
        shop = collections.OrderedDict()
        for r in RARITIES:
            members = []
            for key in sorted(sets[r]):
                members.extend(units[key].members)
            shop[r] = members
        seasons.append({"spec": spec, "shop": shop})
    assign_special(game, seasons, rng, featured_anywhere)
    out = collections.OrderedDict()
    out["_doc"] = [
        "Seasons (not in the web game): a run is played with the fixed roster of one season. docs/SEASONS.md",
        "Generated by tools/port/gen_seasons.py --generate; edit by hand, then run the tool without argument (checks + doc).",
        "enabled: false = no season at all (the pools of the web game). default: the season picked the first time.",
        "allowFull: the menu also offers 'All Pokémon' (no season).",
        "A season: shop = families (first forms) per rarity, in the shop from the first stage; unique / legendary = offered",
        "by the portals of stage 10 / 20; hatch = lines of the Baby eggs; thresholds = the synergies with their own tiers",
        "(same number of tiers as the web game); featured / special = shown in the menu (information only).",
    ]
    out["enabled"] = True
    out["default"] = SEASONS[0]["id"]
    out["allowFull"] = True
    out["seasons"] = []
    for s in seasons:
        spec = s["spec"]
        entry = collections.OrderedDict()
        entry["id"] = spec["id"]
        entry["name"] = spec["name"]
        entry["description"] = spec["description"]
        entry["featured"] = spec["featured"]
        entry["special"] = [t for t in game.types if t in featured_anywhere and t not in spec["featured"]]
        entry["thresholds"] = {}
        entry["shop"] = s["shop"]
        entry["unique"] = s["unique"]
        entry["legendary"] = s["legendary"]
        entry["hatch"] = s["hatch"]
        counts = type_counts(game, entry)
        for t in game.types:
            fitted = fit_thresholds(game.thresholds[t], counts[t])
            if fitted != game.thresholds[t]:
                entry["thresholds"][t] = fitted
        out["seasons"].append(entry)
    return out


def assign_special(game, seasons, rng, featured_anywhere):
    """Unique, Legendary and hatch lines: each one in exactly one season. Unique / Legendary: every
    synergy of a season gets at least 2 Unique and 1 Legendary when the game has enough."""
    n = len(seasons)
    for list_name, want in [("unique", 2), ("legendary", 1)]:
        fams = list(game.lists[list_name].keys())
        # units: Pokémon of the same Pokédex number and duos stay together
        parent = {f: f for f in fams}
        def find(x):
            while parent[x] != x:
                parent[x] = parent[parent[x]]
                x = parent[x]
            return x
        by_index = {}
        for f in fams:
            g = game.index_group(f)
            if g in by_index:
                parent[find(f)] = find(by_index[g])
            else:
                by_index[g] = f
        for pair in game.duos.values():
            members = [game.pk[p]["family"] for p in pair if p in game.pk and game.pk[p]["family"] in parent]
            for m in members[1:]:
                parent[find(m)] = find(members[0])
        groups = collections.OrderedDict()
        for f in fams:
            groups.setdefault(find(f), []).append(f)
        keys = list(groups.keys())
        types = {k: sorted(set(t for f in groups[k] for t in game.all_types(f))) for k in keys}
        size = {k: len(groups[k]) for k in keys}
        where = {k: i % n for i, k in enumerate(rng.sample(keys, len(keys)))}
        total = sum(size.values())
        def cost():
            c = 0.0
            cnt = [collections.Counter() for _ in range(n)]
            sizes = [0] * n
            for k in keys:
                sizes[where[k]] += size[k]
                for t in types[k]:
                    cnt[where[k]][t] += 1
            for i in range(n):
                c += 0.5 * (sizes[i] - total / n) ** 2
                for t in game.types:
                    target = want + (1 if t in seasons[i]["spec"]["featured"] else 0)
                    if cnt[i][t] < target:
                        c += 4.0 * (target - cnt[i][t]) ** 2
            return c
        current = cost()
        steps = 60000
        for it in range(steps):
            temp = 3.0 * (0.01 / 3.0) ** (it / steps)
            k = keys[rng.randrange(len(keys))]
            old = where[k]
            new = rng.randrange(n)
            if new == old:
                continue
            k2 = None
            if rng.random() < 0.5:  # swap with one of the other season
                others = [x for x in keys if where[x] == new]
                if others:
                    k2 = others[rng.randrange(len(others))]
            where[k] = new
            if k2 is not None:
                where[k2] = old
            c = cost()
            if c <= current or rng.random() < math.exp(-(c - current) / temp):
                current = c
            else:
                where[k] = old
                if k2 is not None:
                    where[k2] = new
        print("%s: cost %.1f" % (list_name, current))
        for i, s in enumerate(seasons):
            s[list_name] = sorted(f for k in keys if where[k] == i for f in groups[k])
    hatch = list(game.lists["hatch"].keys())
    rng.shuffle(hatch)
    # the season featuring BABY gets the extra lines
    order = sorted(range(n), key=lambda i: 0 if "BABY" in seasons[i]["spec"]["featured"] else 1)
    for i in range(n):
        seasons[i]["hatch"] = []
    for j, f in enumerate(hatch):
        seasons[order[j % n]]["hatch"].append(f)
    for s in seasons:
        s["hatch"].sort()


# ---------------------------------------------------------------------------------------------
# checks and doc (from data/seasons.json)
# ---------------------------------------------------------------------------------------------
def shop_families(season):
    shop = season.get("shop", [])
    if isinstance(shop, dict):
        return [f for r in shop for f in shop[r]]
    return list(shop)


def type_counts(game, season):
    """Families of each synergy in the shop of a season (a group of GROUPS counts once)."""
    counts = {t: 0 for t in game.types}
    seen = set()
    for fam in shop_families(season):
        key = group_of(fam)
        if key in seen or fam not in game.source:
            continue
        seen.add(key)
        for t in game.all_types(fam):
            counts[t] += 1
    return counts


def season_thresholds(game, season, t):
    return [int(x) for x in season.get("thresholds", {}).get(t, game.thresholds[t])]


def problems(game, data):
    out = []
    ids = set()
    for season in data.get("seasons", []):
        sid = season.get("id", "?")
        if sid in ids or sid in ("", "all"):
            out.append("%s: id used twice or reserved" % sid)
        ids.add(sid)
        seen = set()
        shop = season.get("shop", {})
        for fam in shop_families(season):
            if fam in seen:
                out.append("%s: %s listed twice in the shop" % (sid, fam))
            seen.add(fam)
            if fam not in game.source or game.pk.get(fam, {}).get("stars") != 1 or game.rarity(fam) not in RARITIES:
                out.append("%s: %s is not a line of the shop (first form of pool / additional / regional)" % (sid, fam))
            elif isinstance(shop, dict):
                listed = [r for r in shop if fam in shop[r]][0]
                if game.rarity(fam) != listed:
                    out.append("%s: %s is %s, listed under %s" % (sid, fam, game.rarity(fam), listed))
        by_index = collections.defaultdict(set)
        for fam in seen:
            if fam in game.source:
                by_index[game.index_group(fam)].add(group_of(fam))
        for idx, fams in by_index.items():
            if len(fams) > 1:
                out.append("%s: %s are forms of the same Pokémon (pick one)" % (sid, ", ".join(sorted(fams))))
        for list_name in ["unique", "legendary", "hatch"]:
            for fam in season.get(list_name, []):
                if fam not in game.lists[list_name]:
                    out.append("%s: %s is not a %s family" % (sid, fam, list_name))
        fams_u = set(season.get("unique", []))
        for duo, pair in game.duos.items():
            members = [game.pk[p]["family"] for p in pair if p in game.pk]
            inside = [m for m in members if m in fams_u]
            if inside and len(inside) != len(members) and all(m in game.lists["unique"] for m in members):
                out.append("%s: duo %s is split" % (sid, duo))
        counts = type_counts(game, season)
        extra = collections.Counter()
        for list_name in ["unique", "legendary"]:
            for fam in season.get(list_name, []):
                if fam in game.lists[list_name]:
                    for t in game.all_types(fam):
                        extra[t] += 1
        for t in game.types:
            th = season_thresholds(game, season, t)
            if len(th) != len(game.thresholds[t]):
                out.append("%s: %s has %d tiers, the game has %d" % (sid, t, len(th), len(game.thresholds[t])))
            if any(b <= a for a, b in zip(th, th[1:])) or (th and th[0] < 1):
                out.append("%s: thresholds of %s are not increasing" % (sid, t))
            if counts[t] == 0:
                out.append("%s: no %s family in the shop" % (sid, t))
            elif th and counts[t] < th[0]:
                out.append("%s: %s has %d families, its first tier needs %d" % (sid, t, counts[t], th[0]))
            elif th and counts[t] + extra[t] < th[-1]:
                out.append("%s: the last tier of %s (%d) is out of reach (%d families + %d Unique / Legendary)"
                           % (sid, t, th[-1], counts[t], extra[t]))
        for r in RARITIES:
            fams = [f for f in seen if f in game.source and game.rarity(f) == r]
            keys = set(group_of(f) for f in fams)
            open1 = set(group_of(f) for f in fams if game.open_at_pass_1(f))
            if len(keys) < 8:
                out.append("%s: only %d %s families" % (sid, len(keys), r))
            if len(open1) < 5:
                out.append("%s: only %d %s families at Battle Pass level 1" % (sid, len(open1), r))
    return out


def dump_json(data):
    """JSON with one line per list of names (the file is made to be edited by hand)."""
    def scalar_list(v):
        return isinstance(v, list) and all(not isinstance(x, (dict, list)) for x in v)

    def write(v, indent):
        pad = "  " * indent
        if isinstance(v, dict):
            if not v:
                return "{}"
            if all(scalar_list(x) for x in v.values()) and all(len(x) <= 8 for x in v.values()) and indent >= 3:
                rows = ["%s  %s: %s" % (pad, json.dumps(k), json.dumps(x, ensure_ascii=False)) for k, x in v.items()]
                return "{\n" + ",\n".join(rows) + "\n" + pad + "}"
            rows = ["%s  %s: %s" % (pad, json.dumps(k), write(x, indent + 1)) for k, x in v.items()]
            return "{\n" + ",\n".join(rows) + "\n" + pad + "}"
        if isinstance(v, list):
            if scalar_list(v):
                if v and all(isinstance(x, str) for x in v) and sum(len(x) for x in v) > 100 and indent <= 1:
                    rows = ["%s  %s" % (pad, json.dumps(x, ensure_ascii=False)) for x in v]
                    return "[\n" + ",\n".join(rows) + "\n" + pad + "]"
                return json.dumps(v, ensure_ascii=False)
            rows = ["%s  %s" % (pad, write(x, indent + 1)) for x in v]
            return "[\n" + ",\n".join(rows) + "\n" + pad + "]"
        return json.dumps(v, ensure_ascii=False)

    return write(data, 0) + "\n"


def names(game, fams, with_rarity=False):
    out = []
    seen = set()
    for f in fams:
        key = group_of(f)
        if key in seen:
            continue
        seen.add(key)
        label = game.name(key)
        if with_rarity:
            label += " (%s)" % LETTER.get(game.rarity(f), "?")
        out.append(label)
    return out


def write_doc(game, data, issues):
    seasons = data.get("seasons", [])
    ui = load_json("data", "i18n", "ui.json")

    def vi(text):  # the Vietnamese name / description of a season when ui.json has it
        entry = ui.get(text)
        return entry.get("vi", text) if isinstance(entry, dict) else text

    L = []
    L.append("# Mùa — danh sách Pokémon cố định cho từng run (chỉ có ở bản Godot)")
    L.append("")
    L.append("> File này sinh bằng `python tools/port/gen_seasons.py` từ `data/seasons.json` — đừng sửa tay, sửa JSON rồi chạy lại.")
    L.append("")
    L.append("Không có mùa, mọi Pokémon của game nằm chung một pool: shop bắt đầu với 94 họ, tới stage 11 bản port đã cho cả")
    L.append("155 họ *additional* vào shop (bản web 8 người chơi chỉ thêm 24 họ mỗi ván), cộng Pokémon vùng — một hệ có tới")
    L.append("13–37 họ, rất khó nhắm đội hình. Bản Godot vì vậy chia nội dung thành các **mùa** như TFT: mỗi run chơi với")
    L.append("danh sách Pokémon **cố định** của một mùa, chọn ở menu chính trước khi bắt đầu.")
    L.append("")
    L.append("Dữ liệu: `data/seasons.json` • Code: `src/core/seasons.gd` (`Seasons`), `GameData.apply_progression()` •")
    L.append("Công cụ: `tools/port/gen_seasons.py`.")
    L.append("")
    L.append("## 1. Luật")
    L.append("")
    L.append("- **Shop của mùa** có sẵn toàn bộ từ stage đầu: không còn họ *additional* gia nhập ở stage 5 / 8 / 11, không còn")
    L.append("  Pokémon vùng theo từng vùng, không còn biến thể vùng thay dạng gốc. Họ nào không thuộc mùa thì không xuất hiện ở")
    L.append("  đâu cả (shop, đề xuất, trứng, bầy hoang dã của wave).")
    L.append("- **Hệ đại trà**: %d–%d họ trong shop (hệ có mốc cuối 9 thì ít nhất 9). **Hệ đặc biệt**: %d–%d họ, có **mốc kích"
             % (COMMON_RANGE[0], COMMON_RANGE[1], SPECIAL_RANGE[0], SPECIAL_RANGE[1]))
    L.append("  hoạt riêng** của mùa (ít Pokémon hơn nên mốc thấp hơn; mốc cuối có thể cần thêm Unique / Legendary / đá hệ).")
    L.append("- Mỗi mùa có **4 hệ đặc trưng**: các hệ này đủ %d–%d họ ở mùa đó và là hệ đặc biệt ở các mùa khác."
             % (COMMON_RANGE[0], COMMON_RANGE[1]))
    L.append("- **Additional pick** (stage 5 / 8 / 11) vẫn còn: chọn 1 trong 3 Pokémon *của mùa* (Uncommon / Rare / Epic) kèm mảnh ghép.")
    L.append("- **Unique / Legendary** của cổng stage 10 / 20 và **dòng nở từ trứng** cũng theo mùa; mỗi con chỉ thuộc một mùa.")
    L.append("- Wave địch (bầy hoang dã, template) lấy Pokémon từ chính danh sách của mùa.")
    L.append("- **Battle Pass** vẫn áp lên trên: hệ chưa mở bị ẩn như cũ, mùa chỉ quyết định họ nào có mặt.")
    L.append("- Kỷ lục lưu riêng cho từng cặp mùa + độ khó.")
    L.append("- Lựa chọn **Tất cả Pokémon** (`allowFull`) = không mùa: pool như bản web.")
    L.append("")
    L.append("## 2. Tổng quan các mùa")
    L.append("")
    L.append("| Mùa | Hệ đặc trưng | Họ trong shop (C / U / R / E / Ultra) | Unique | Legendary | Trứng |")
    L.append("|---|---|---|---|---|---|")
    for s in seasons:
        fams = shop_families(s)
        per = [len(set(group_of(f) for f in fams if f in game.source and game.rarity(f) == r)) for r in RARITIES]
        L.append("| **%s** (`%s`) | %s | %d (%s) | %d | %d | %d |" % (
            vi(s.get("name", "")), s.get("id", ""), ", ".join(game.type_name(t) for t in s.get("featured", [])),
            sum(per), " / ".join(str(x) for x in per), len(s.get("unique", [])), len(s.get("legendary", [])),
            len(s.get("hatch", []))))
    L.append("")
    # counts per type
    L.append("### Số họ của mỗi hệ trong shop")
    L.append("")
    L.append("Chữ **đậm** = hệ đặc trưng của mùa, *nghiêng* = hệ đặc biệt (mốc riêng trong ngoặc). Cột \"web\" = số họ shop +")
    L.append("additional + vùng mà bản web có cho hệ đó.")
    L.append("")
    L.append("| Hệ | Mốc gốc | web | " + " | ".join(s.get("id", "") for s in seasons) + " |")
    L.append("|---|---|---|" + "---|" * len(seasons))
    web = {t: 0 for t in game.types}
    seen_keys = set()
    for fam in game.source:
        key = group_of(fam)
        if key in seen_keys or fam in EXCLUDED:
            continue
        seen_keys.add(key)
        for t in game.all_types(fam):
            web[t] += 1
    all_counts = [type_counts(game, s) for s in seasons]
    for t in game.types:
        cells = []
        for s, counts in zip(seasons, all_counts):
            th = season_thresholds(game, s, t)
            cell = str(counts[t])
            if th != game.thresholds[t]:
                cell += " (%s)" % "/".join(str(x) for x in th)
            if t in s.get("featured", []):
                cell = "**%s**" % cell
            elif t in s.get("special", []):
                cell = "*%s*" % cell
            cells.append(cell)
        L.append("| %s | %s | %d | %s |" % (game.type_name(t), "/".join(str(x) for x in game.thresholds[t]), web[t], " | ".join(cells)))
    L.append("")
    # overlap
    L.append("### Trùng nhau giữa các mùa")
    L.append("")
    sets = [set(group_of(f) for f in shop_families(s)) for s in seasons]
    L.append("| | " + " | ".join(s.get("id", "") for s in seasons) + " |")
    L.append("|---|" + "---|" * len(seasons))
    for i, s in enumerate(seasons):
        L.append("| %s | %s |" % (s.get("id", ""), " | ".join(str(len(sets[i] & sets[j])) for j in range(len(seasons)))))
    L.append("")
    used = set().union(*sets) if sets else set()
    every = set(group_of(f) for f in game.source)
    unused = sorted(every - used)
    L.append("Số họ shop dùng trong ít nhất một mùa: **%d / %d**. Common và Ultra của game chỉ có %d và %d họ nên các mùa"
             % (len(used), len(every), len(set(group_of(f) for f in game.source if game.rarity(f) == "COMMON")),
                len(set(group_of(f) for f in game.source if game.rarity(f) == "ULTRA"))))
    L.append("buộc phải dùng chung phần lớn hai độ hiếm này.")
    L.append("")
    if unused:
        L.append("Chưa mùa nào dùng (%d): %s." % (len(unused), ", ".join(game.name(f) for f in unused)))
        L.append("")
    # each season
    for idx, s in enumerate(seasons):
        L.append("## %d. %s (`%s`)" % (idx + 3, vi(s.get("name", "")), s.get("id", "")))
        L.append("")
        L.append(vi(s.get("description", "")))
        L.append("")
        L.append("- **Hệ đặc trưng**: %s" % ", ".join(game.type_name(t) for t in s.get("featured", [])))
        special = []
        for t in s.get("special", []):
            special.append("%s (%s)" % (game.type_name(t), "/".join(str(x) for x in season_thresholds(game, s, t))))
        L.append("- **Hệ đặc biệt** (mốc của mùa): %s" % ", ".join(special))
        other = [t for t in s.get("thresholds", {}) if t not in s.get("special", [])]
        if other:
            L.append("- Hệ đại trà đổi mốc cho vừa số họ: %s" % ", ".join(
                "%s (%s)" % (game.type_name(t), "/".join(str(x) for x in season_thresholds(game, s, t))) for t in other))
        L.append("- **Trứng** nở ra: %s" % ", ".join(names(game, s.get("hatch", []))))
        L.append("")
        fams = [f for f in shop_families(s) if f in game.source]
        L.append("### Shop theo độ hiếm")
        L.append("")
        for r in RARITIES:
            row = names(game, [f for f in fams if game.rarity(f) == r])
            L.append("- **%s** (%d): %s" % (r.capitalize(), len(row), ", ".join(row)))
        L.append("")
        L.append("### Theo hệ")
        L.append("")
        L.append("| Hệ | Mốc | Shop | Unique | Legendary |")
        L.append("|---|---|---|---|---|")
        counts = all_counts[idx]
        for t in game.types:
            members = [f for f in fams if t in game.all_types(f)]
            members.sort(key=lambda f: (COST[game.rarity(f)], game.name(group_of(f))))
            uniq = [f for f in s.get("unique", []) if f in game.lists["unique"] and t in game.all_types(f)]
            leg = [f for f in s.get("legendary", []) if f in game.lists["legendary"] and t in game.all_types(f)]
            label = game.type_name(t)
            if t in s.get("featured", []):
                label = "**%s** ★" % label
            elif t in s.get("special", []):
                label = "*%s*" % label
            L.append("| %s | %s | **%d**: %s | %s | %s |" % (
                label, "/".join(str(x) for x in season_thresholds(game, s, t)), counts[t],
                ", ".join(names(game, members, True)), ", ".join(names(game, uniq)) or "—", ", ".join(names(game, leg)) or "—"))
        L.append("")
        L.append("Unique (%d): %s." % (len(s.get("unique", [])), ", ".join(names(game, s.get("unique", [])))))
        L.append("")
        L.append("Legendary (%d): %s." % (len(s.get("legendary", [])), ", ".join(names(game, s.get("legendary", [])))))
        L.append("")
    n = len(seasons) + 3
    L.append("## %d. Chỉnh sửa" % n)
    L.append("")
    L.append("| Khoá của `data/seasons.json` | Ý nghĩa |")
    L.append("|---|---|")
    L.append("| `enabled` | `false` = tắt hẳn mùa: pool như bản web, menu không hiện ô chọn mùa |")
    L.append("| `default` | mùa được chọn lần đầu (sau đó game nhớ lựa chọn của người chơi) |")
    L.append("| `allowFull` | menu có thêm lựa chọn *Tất cả Pokémon* (không mùa) |")
    L.append("| `seasons[i].id` | định danh, dùng trong file lưu kỷ lục và tham số test `season=<id>` |")
    L.append("| `seasons[i].name`, `description` | tiếng Anh; bản dịch thêm vào `data/i18n/ui.json` |")
    L.append("| `seasons[i].shop` | các **họ** (tên dạng đầu) theo độ hiếm; cũng nhận một mảng phẳng |")
    L.append("| `seasons[i].unique`, `legendary`, `hatch` | các họ Unique / Legendary được đề xuất, các dòng nở từ trứng |")
    L.append("| `seasons[i].thresholds` | mốc riêng của mùa cho một hệ — **phải cùng số mốc** với bản gốc |")
    L.append("| `seasons[i].featured`, `special` | chỉ để hiển thị ở menu và trong tài liệu này |")
    L.append("")
    L.append("- Thêm / bớt Pokémon: sửa các mảng trong JSON rồi chạy `python tools/port/gen_seasons.py` (kiểm + ghi lại tài liệu")
    L.append("  này) và `sim_test` (`_check_seasons`).")
    L.append("- Thêm mùa: thêm một mục vào `seasons` (hoặc thêm vào bảng `SEASONS` trong tool rồi `--generate`).")
    L.append("- Flabébé: liệt kê cả 5 màu, tính là một họ (mỗi run một màu). Deerling không vào mùa (dạng theo ngày thật).")
    L.append("- Hai dạng của cùng một Pokémon (Vulpix và Alolan Vulpix) không nên ở chung một mùa — tool sẽ báo.")
    L.append("- `--generate` tính lại toàn bộ danh sách bằng thuật toán (tham số ở đầu file tool: số họ mỗi độ hiếm, khoảng")
    L.append("  %d–%d / %d–%d, hệ đặc trưng từng mùa) — **ghi đè** mọi chỉnh tay." % (COMMON_RANGE + SPECIAL_RANGE))
    L.append("")
    L.append("## %d. Kiểm tra" % (n + 1))
    L.append("")
    if issues:
        L.append("Tool báo %d vấn đề:" % len(issues))
        L.append("")
        for p in issues:
            L.append("- %s" % p)
    else:
        L.append("Tool không báo vấn đề nào: mọi họ hợp lệ, mỗi hệ đủ họ cho mốc đầu, mốc cuối với tới được, mỗi độ hiếm còn")
        L.append("ít nhất 5 họ ở Battle Pass cấp 1.")
    L.append("")
    with open(OUT_DOC, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L))


def report(game, data):
    for s in data.get("seasons", []):
        counts = type_counts(game, s)
        fams = [f for f in shop_families(s) if f in game.source]
        per = [len(set(group_of(f) for f in fams if game.rarity(f) == r)) for r in RARITIES]
        print("%s  %s  shop %d %s  unique %d  legendary %d  hatch %d" % (
            s["id"], s["name"], sum(per), per, len(s.get("unique", [])), len(s.get("legendary", [])), len(s.get("hatch", []))))
        row = []
        for t in game.types:
            mark = "*" if t in s.get("featured", []) else ("." if t in s.get("special", []) else "")
            row.append("%s%s=%d" % (t[:4], mark, counts[t]))
        print("   " + " ".join(row))


def main():
    game = Game()
    if "--generate" in sys.argv:
        data = generate(game)
        with open(OUT_JSON, "w", encoding="utf-8", newline="\n") as f:
            f.write(dump_json(data))
        print("wrote", OUT_JSON)
    with open(OUT_JSON, encoding="utf-8") as f:
        data = json.load(f)
    issues = problems(game, data)
    report(game, data)
    write_doc(game, data, issues)
    print("wrote", OUT_DOC)
    if issues:
        print("%d problem(s):" % len(issues))
        for p in issues:
            print("  -", p)
    return 1 if issues else 0


if __name__ == "__main__":
    sys.exit(main())
