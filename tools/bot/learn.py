"""Bot knowledge (tools/bot/bot_knowledge.gd, docs/BOT.md): merges what the workers of a batch learned, or learns it
from the TSV of a batch (offline: no new run needed).
    python tools/bot/learn.py build/bot/b1                      # knowledge_*.json of the batch -> tools/bot/knowledge.json
    python tools/bot/learn.py --from-tsv build/bot/b2000        # the batch's stages / units / runs TSV -> the same file
    options: --into <file> (default tools/bot/knowledge.json), --decay 0.9 (old knowledge counts less), --reset
Every entry is [n, sum]; merging adds them.
"""
import glob
import io
import json
import os
import sys

import pandas as pd

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
KINDS = ["stage", "syn", "pair", "unit", "share", "item", "plan", "econ"]


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def merge(into, extra, decay=1.0):
    for kind in KINDS:
        table = into.setdefault(kind, {})
        for name in list(table):
            table[name] = [table[name][0] * decay, table[name][1] * decay]
        for name, (n, s) in extra.get(kind, {}).items():
            old = table.get(name, [0.0, 0.0])
            table[name] = [old[0] + n, old[1] + s]


def from_tsv(folder):
    """The knowledge a batch's TSV gives (same rules as BotKnowledge.observe, the baseline from the whole batch)."""
    load = lambda k: pd.concat([pd.read_csv(f, sep="\t", na_filter=False, low_memory=False)
                                for f in sorted(glob.glob(os.path.join(folder, "%s_*.tsv" % k)))], ignore_index=True)
    stages, units, runs = load("stages"), load("units"), load("runs")
    out = {k: {} for k in KINDS}
    add = lambda kind, name, n, s: out[kind].__setitem__(name, [out[kind].get(name, [0, 0])[0] + n, out[kind].get(name, [0, 0])[1] + s])
    stages["win"] = (stages["res"] == "W").astype(float)
    base = stages.groupby("stage")["win"].mean()
    stages["adj"] = stages["win"] - stages["stage"].map(base)
    for st, g in stages.groupby("stage"):
        add("stage", str(st), len(g), float(g["win"].sum()))
    pair_rows, syn_rows = [], []
    for r in stages[["syn", "adj"]].itertuples(index=False):
        active = []
        for part in str(r.syn).split("|") if r.syn else []:
            t, c, tier = part.split(":")
            syn_rows.append(("%s:%s" % (t, tier), r.adj))
            active.append(t)
        active.sort()
        for i in range(len(active)):
            for j in range(i + 1, len(active)):
                pair_rows.append((active[i] + "+" + active[j], r.adj))
    for kind, rows in [("syn", syn_rows), ("pair", pair_rows)]:
        df = pd.DataFrame(rows, columns=["name", "adj"])
        for name, g in df.groupby("name"):
            add(kind, name, len(g), float(g["adj"].sum()))
    u = units[units.team == "B"].merge(stages[["run", "stage", "adj"]], on=["run", "stage"], how="left")
    u["team_dealt"] = u.groupby(["run", "stage"])["dealt"].transform("sum").clip(lower=1)
    u["share"] = u["dealt"] / u["team_dealt"]
    for pkm, g in u.groupby("pkm"):
        add("unit", pkm, len(g), float(g["adj"].sum()))
        add("share", pkm, len(g), float(g["share"].sum()))
    held = u[u["items"] != ""].assign(item=lambda d: d["items"].str.split("+")).explode("item")
    for (item, role), g in held.groupby(["item", "role"]):
        add("item", "%s@%s" % (item, role), len(g), float(g["adj"].sum()))
    # strategies: only the runs of the pro bots (a weak bot's result says little about a plan played well)
    runs = runs[(runs["aims"] != "") & runs["bot"].str.startswith(("pro", "design"))]
    for aims, g in runs.groupby("aims"):
        parts = sorted(a for a in aims.split(",") if a)
        if len(parts) >= 2:
            add("plan", "+".join(parts[:2]), len(g), float(g["stage"].sum()))
    return out


def main():
    into_path = arg("--into", os.path.join(ROOT, "tools", "bot", "knowledge.json"))
    decay = float(arg("--decay", "1.0"))
    known = {} if "--reset" in sys.argv or not os.path.exists(into_path) else json.load(io.open(into_path, encoding="utf-8"))
    if "--from-tsv" in sys.argv:
        merge(known, from_tsv(arg("--from-tsv")), decay)
    else:
        folder = [a for a in sys.argv[1:] if not a.startswith("--") and a not in (into_path, str(decay))][0]
        for f in sorted(glob.glob(os.path.join(folder, "knowledge_*.json"))):
            merge(known, json.load(io.open(f, encoding="utf-8")), decay)
            decay = 1.0 # decay the old knowledge once
    io.open(into_path, "w", encoding="utf-8").write(json.dumps(known, separators=(",", ":")))
    print("knowledge: %s (%s)" % (into_path, ", ".join("%s %d" % (k, len(known.get(k, {}))) for k in KINDS)))


if __name__ == "__main__":
    main()
