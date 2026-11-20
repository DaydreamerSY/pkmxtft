"""The pro bot's win model (tools/bot/bot_model.gd, docs/BOT.md): logistic regression of "the board wins this fight",
trained on the stages TSV of bot batches. Features (names shared with BotModel):
  st:<stage, 60 max>  lv:<level>  wv:<wave code>  sy:<TYPE>:<k> for every tier k reached (cumulative)
  pr:<A>+<B> active pair (A < B)  u:<form> count on the board  it:<item> count held on the board
  pw: power of the board (sum of rarity cost x 3^(stars-1), / 10)  n3: 3-star Pokémon  ni: items held / 3
  (pw / n3 / ni generalize to forms seen rarely; a form's own weight is then how much better or worse it is than
  its cost - a balance number)
    python tools/bot/train_model.py build/bot/b2000 build/bot/pro1 [--out tools/bot/model.json] [--min 5] [--l2 0.0005]
    python tools/bot/train_model.py --all          (every batch folder of build/bot)
Prints the holdout log loss / accuracy / AUC against a stage-only baseline. tools/bot/autobalance.py uses the same
functions (load_stages, matrix, fit).
"""
import glob
import io
import json
import os
import sys

import numpy as np
import pandas as pd

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
POKEMON = json.load(io.open(os.path.join(ROOT, "data", "pac", "pokemon.json"), encoding="utf-8"))
COST = json.load(io.open(os.path.join(ROOT, "data", "pac", "config.json"), encoding="utf-8")).get("rarityCost", {})


def arg(name, default):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def folders_of(argv):
    """The batch folders named on the command line (every one of build/bot with --all)."""
    if "--all" in argv:
        return sorted(set(os.path.dirname(f) for f in glob.glob(os.path.join(ROOT, "build", "bot", "*", "stages_*.tsv"))))
    values = set(argv[i + 1] for i, a in enumerate(argv[:-1]) if a.startswith("--"))
    return [a for a in argv[1:] if not a.startswith("--") and a not in values]


def load_stages(folders):
    frames = [pd.read_csv(f, sep="\t", na_filter=False, low_memory=False)
              for d in folders for f in sorted(glob.glob(os.path.join(d, "stages_*.tsv"))) if os.path.getsize(f) > 0]
    return pd.concat(frames, ignore_index=True)


def features(r, synergies=True, item_forms=False):
    """synergies=False: no sy: / pr: terms - a form's weight then holds what its synergies bring too (autobalance).
    item_forms: ui:<form> = items held by that form (autobalance: u:<form> is then its worth without items, ui:<form>
    what each item adds on it)."""
    f = {"st:%d" % min(int(r.stage), 60): 1.0, "lv:%d" % int(r.level): 1.0, "wv:" + r.wave: 1.0}
    active = []
    for part in r.syn.split("|") if r.syn and synergies else []:
        t, _count, tier = part.split(":")
        for k in range(1, int(tier) + 1):
            f["sy:%s:%d" % (t, k)] = 1.0
        active.append(t)
    active.sort()
    for i in range(len(active)):
        for j in range(i + 1, len(active)):
            f["pr:%s+%s" % (active[i], active[j])] = 1.0
    power, threes, held = 0.0, 0.0, 0.0
    for unit in r.board.split("|") if r.board else []:
        pkm = unit.split("*")[0]
        f["u:" + pkm] = f.get("u:" + pkm, 0.0) + 1.0
        stars = int(unit.split("*")[1].split("[")[0]) if "*" in unit else 1
        power += max(int(COST.get(POKEMON.get(pkm, {}).get("rarity", "COMMON"), 1)), 1) * 3 ** (stars - 1)
        threes += 1.0 if stars >= 3 else 0.0
        items = unit[unit.index("[") + 1:unit.index("]")] if "[" in unit else ""
        for it in items.split("+") if items else []:
            f["it:" + it] = f.get("it:" + it, 0.0) + 1.0
            held += 1.0
            if item_forms:
                f["ui:" + pkm] = f.get("ui:" + pkm, 0.0) + 1.0
    f["pw"], f["n3"], f["ni"] = power / 10.0, threes, held / 3.0
    return f


def matrix(stages, least, synergies=True, item_forms=False):
    """Sparse design matrix of the stages: (names, seen, row_of, col, val, y); features seen fewer than `least` rows
    are dropped. seen: rows with the feature (before the cut)."""
    y = (stages["res"] == "W").astype(np.float64).to_numpy()
    rows = [features(r, synergies, item_forms)
            for r in stages[["stage", "level", "wave", "syn", "board"]].itertuples(index=False)]
    seen = {}
    for f in rows:
        for name in f:
            seen[name] = seen.get(name, 0) + 1
    names = sorted(n for n, c in seen.items() if c >= least)
    index = {n: i for i, n in enumerate(names)}
    row_of, col, val = [], [], []
    for i, f in enumerate(rows):
        for name, v in f.items():
            j = index.get(name)
            if j is not None:
                row_of.append(i)
                col.append(j)
                val.append(v)
    return names, seen, np.array(row_of), np.array(col), np.array(val), y


def fit(data, mask, l2=0.0005, iters=400, lr=0.05):
    """Logistic regression (Adam, full batch) on the rows of `mask`: (weights, bias)."""
    names, _seen, row_of, col, val, y = data
    n, m = len(y), len(names)
    w, b = np.zeros(m), 0.0
    mw, vw, mb, vb = np.zeros(m), np.zeros(m), 0.0, 0.0
    sel = mask[row_of]
    r_, c_, v_ = row_of[sel], col[sel], val[sel]
    k = mask.sum()
    for t in range(1, iters + 1):
        z = np.bincount(r_, weights=w[c_] * v_, minlength=n) + b
        p = 1.0 / (1.0 + np.exp(-z))
        err = np.where(mask, p - y, 0.0)
        gw = np.bincount(c_, weights=err[r_] * v_, minlength=m) / k + l2 * w
        gb = err.sum() / k
        mw, vw = 0.9 * mw + 0.1 * gw, 0.999 * vw + 0.001 * gw * gw
        mb, vb = 0.9 * mb + 0.1 * gb, 0.999 * vb + 0.001 * gb * gb
        w -= lr * (mw / (1 - 0.9 ** t)) / (np.sqrt(vw / (1 - 0.999 ** t)) + 1e-8)
        b -= lr * (mb / (1 - 0.9 ** t)) / (np.sqrt(vb / (1 - 0.999 ** t)) + 1e-8)
    return w, b


def predict(data, w, b):
    _names, _seen, row_of, col, val, y = data
    return 1.0 / (1.0 + np.exp(-(np.bincount(row_of, weights=w[col] * val, minlength=len(y)) + b)))


def auc(y, p):
    order = np.argsort(p)
    ranks = np.empty(len(p))
    ranks[order] = np.arange(1, len(p) + 1)
    pos = y == 1
    n1, n0 = pos.sum(), (~pos).sum()
    return (ranks[pos].sum() - n1 * (n1 + 1) / 2) / max(n1 * n0, 1)


def main():
    folders = folders_of(sys.argv)
    out_path = arg("--out", os.path.join(ROOT, "tools", "bot", "model.json"))
    least, l2 = int(arg("--min", "5")), float(arg("--l2", "0.0005"))
    stages = load_stages(folders)
    data = matrix(stages, least)
    names, y = data[0], data[5]
    n = len(y)
    test = np.random.default_rng(7).random(n) < 0.1
    w, b = fit(data, ~test, l2)
    p = predict(data, w, b)
    base = stages.loc[~test].groupby("stage")["res"].apply(lambda s: (s == "W").mean())
    pb = stages["stage"].map(base).fillna(0.5).clip(0.01, 0.99).to_numpy()
    ll = lambda q: float(-np.mean(y[test] * np.log(np.clip(q[test], 1e-6, 1)) + (1 - y[test]) * np.log(np.clip(1 - q[test], 1e-6, 1))))
    acc = lambda q: float(np.mean((q[test] > 0.5) == (y[test] == 1)))
    print("rows %d, features %d (seen >= %d), holdout %d" % (n, len(names), least, test.sum()))
    print("holdout  model: logloss %.4f acc %.3f auc %.3f | stage-only: logloss %.4f acc %.3f auc %.3f" % (
        ll(p), acc(p), auc(y[test], p[test]), ll(pb), acc(pb), auc(y[test], pb[test])))
    w, b = fit(data, np.ones(n, dtype=bool), l2) # the model shipped: every row
    model = {"bias": round(float(b), 4), "w": {names[j]: round(float(w[j]), 4) for j in range(len(names)) if abs(w[j]) >= 0.002},
             "meta": {"rows": n, "features": len(names), "folders": [os.path.relpath(d, ROOT) for d in folders]}}
    io.open(out_path, "w", encoding="utf-8").write(json.dumps(model, separators=(",", ":")))
    top = sorted(((v, k) for k, v in model["w"].items() if k.startswith("pr:") or k.startswith("sy:")), reverse=True)
    print("model -> %s (%d weights); strongest synergy / pair terms: %s" % (out_path, len(model["w"]),
          ", ".join("%s %+.2f" % (k, v) for v, k in top[:8])))


if __name__ == "__main__":
    main()
