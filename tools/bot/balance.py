"""Balance questions on a bot batch (docs/BOT.md) - compact TSV blocks for Claude, not people:
  #pkm_vs_cost   Pokémon too strong / weak for their cost (same rarity and stars compared)
  #syn_ease      synergies: how easily an aimed synergy reaches its tiers vs how much it wins
  #skill_pp      abilities: output per cast and how often they come, vs PP (same rarity / stars / role compared)
  #items         items: units holding it vs the same Pokémon with as many items, without it
  #roles / #role_fit   do the roles do their job (damage share, damage taken, survival, heal + shield)
Every "adj" number is stage-adjusted: win - the win rate of that stage, so a late stage does not look weak.
    python tools/bot/balance.py build/bot/b2000 [--min 30]
"""
import glob
import io
import json
import os
import sys

import numpy as np
import pandas as pd

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


def load(folder, kind):
    files = sorted(glob.glob(os.path.join(folder, "%s_*.tsv" % kind)))
    frames = [pd.read_csv(f, sep="\t", na_filter=False, low_memory=False) for f in files if os.path.getsize(f) > 0]
    return pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()


def block(out, name, df):
    out.write("#%s\n" % name)
    df.to_csv(out, sep="\t", index=False, float_format="%.3g", lineterminator="\n")


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else "build/bot/latest"
    least = int(sys.argv[sys.argv.index("--min") + 1]) if "--min" in sys.argv else 30
    stages, units = load(folder, "stages"), load(folder, "units")
    cfg = json.load(io.open(os.path.join(ROOT, "data/pac/config.json"), encoding="utf-8"))
    cost = cfg.get("rarityCost", {})
    thresholds = cfg.get("synergyThresholds", {})
    out = io.StringIO()

    stages["win"] = (stages["res"] == "W").astype(float)
    stages["base"] = stages.groupby("stage")["win"].transform("mean")
    stages["adj"] = stages["win"] - stages["base"]
    stages["band"] = (stages["stage"] // 10) * 10
    out.write("#meta stages=%d units=%d runs=%d\n" % (len(stages), len(units), stages["run"].nunique()))

    u = units.merge(stages[["run", "stage", "win", "adj", "fight_s"]], on=["run", "stage"], how="left")
    u["fight_s"] = pd.to_numeric(u["fight_s"], errors="coerce").clip(lower=0.1)
    key = ["run", "stage", "team"]
    for col, tot in [("dealt", "team_dealt"), ("taken", "team_taken")]:
        u[tot] = u.groupby(key)[col].transform("sum").clip(lower=1)
    u["share"] = u["dealt"] / u["team_dealt"]
    u["tshare"] = u["taken"] / u["team_taken"]
    u["support"] = u["heal"] + u["shield"]
    u["life_s"] = np.where(u["t_dead"] >= 0, u["t_dead"], u["fight_s"])
    u["skill_out"] = (u["dealt"] - u["adealt"]).clip(lower=0) + u["support"]
    u["nitems"] = u["items"].apply(lambda s: 0 if s == "" else len(s.split("+")))
    u["cost"] = u["rarity"].map(lambda r: int(cost.get(r, 1))) * (3 ** (u["stars"] - 1))
    u["band"] = (u["stage"] // 10) * 10
    me = u[u["team"] == "B"].copy()

    # 1. Pokémon vs cost: impact (stage-adjusted win with it on the board) and damage / tank share, against the
    # Pokémon of the same rarity and stars
    pk = me.groupby("pkm").agg(n=("adj", "size"), rarity=("rarity", "first"), stars=("stars", "first"), role=("role", "first"),
                               adj=("adj", "mean"), share=("share", "mean"), tshare=("tshare", "mean"),
                               surv=("alive", "mean"), support=("support", "mean")).reset_index()
    pk = pk[pk.n >= least]
    grp = pk.groupby(["rarity", "stars"])
    pk["adj_vs"] = pk["adj"] - grp["adj"].transform("mean")
    pk["share_vs"] = pk["share"] - grp["share"].transform("mean")
    cols = ["pkm", "rarity", "stars", "role", "n", "adj", "adj_vs", "share", "share_vs", "tshare", "surv", "support"]
    block(out, "pkm_vs_cost strong (adj_vs = adj - mean of same rarity+stars, n >= %d)" % least,
          pk.sort_values("adj_vs", ascending=False)[cols].head(25))
    block(out, "pkm_vs_cost weak", pk.sort_values("adj_vs")[cols].head(25))
    block(out, "rarity_stars (mean of the group)", grp.agg(n=("n", "sum"), adj=("adj", "mean"), share=("share", "mean"))
          .reset_index())

    # 2. synergies: ease (stages aiming it -> share reaching tier 1 / 2 / its top) vs strength (adj when active)
    rows = []
    for r in stages[["syn", "aims", "adj", "band"]].itertuples(index=False):
        active = {}
        for part in str(r.syn).split("|") if r.syn else []:
            t, c, tier = part.split(":")
            active[t] = int(tier)
        aims = [a for a in str(r.aims).split(",") if a]
        for t in set(active) | set(aims):
            rows.append((t, active.get(t, 0), t in aims, r.adj, r.band))
    sy = pd.DataFrame(rows, columns=["type", "tier", "aimed", "adj", "band"])
    ease = sy[sy.aimed & (sy.band >= 10)].groupby("type").agg(aimed=("tier", "size"), r1=("tier", lambda s: (s >= 1).mean()),
                                                               r2=("tier", lambda s: (s >= 2).mean())).reset_index()
    act = sy[sy.tier >= 1]
    power = act.groupby("type").agg(n=("adj", "size"), adj=("adj", "mean"), tier=("tier", "mean"),
                                    adj2=("adj", lambda s: s[act.loc[s.index, "tier"] >= 2].mean())).reset_index()
    syn = power.merge(ease, on="type", how="left")
    syn["tiers"] = syn["type"].map(lambda t: "/".join(str(int(x)) for x in thresholds.get(t, [])))
    med = syn["r2"].median()
    syn["verdict"] = np.select([(syn.r2 >= med) & (syn.adj > 0.03), (syn.r2 < med) & (syn.adj < -0.03)],
                               ["easy+strong", "hard+weak"], "")
    block(out, "syn_ease (r1/r2: aimed at stage >= 10 -> tier 1 / 2 reached; adj / adj2: active / tier >= 2)",
          syn.sort_values("adj", ascending=False))

    # 3. abilities vs PP: casts, first cast, output per cast, against the same rarity / stars / role
    sk = me.groupby("pkm").agg(n=("casts", "size"), rarity=("rarity", "first"), stars=("stars", "first"),
                               role=("role", "first"), maxpp=("maxpp", "median"), casts=("casts", "mean"),
                               zero=("casts", lambda s: (s == 0).mean()),
                               first=("first_cast", lambda s: s[s >= 0].mean()),
                               rate=("casts", "sum"), alive_s=("life_s", "sum"), out=("skill_out", "sum"),
                               adeal=("adealt", "sum"), dealt=("dealt", "sum")).reset_index()
    sk = sk[sk.n >= least].copy()
    sk["rate10"] = 10 * sk["rate"] / sk["alive_s"].clip(lower=1)
    sk["per_cast"] = sk["out"] / sk["rate"].clip(lower=1)
    sk["skill_part"] = 1 - sk["adeal"] / sk["dealt"].clip(lower=1)
    g = sk.groupby(["rarity", "stars", "role"])
    sk["per_cast_vs"] = sk["per_cast"] / g["per_cast"].transform("median").clip(lower=1)
    cols = ["pkm", "rarity", "stars", "role", "n", "maxpp", "casts", "zero", "first", "rate10", "per_cast", "per_cast_vs",
            "skill_part"]
    block(out, "skill_pp strong (per_cast_vs = output per cast / median of same rarity+stars+role)",
          sk.sort_values("per_cast_vs", ascending=False)[cols].head(25))
    block(out, "skill_pp weak", sk[sk.casts > 0.3].sort_values("per_cast_vs")[cols].head(25))
    block(out, "skill_pp rarely cast (zero = share of fights without a cast)", sk.sort_values("zero", ascending=False)[cols].head(20))

    # 4. items: holding it vs the same Pokémon with as many items in the same stage band, without it
    held = me[me.nitems > 0].assign(item=me.loc[me.nitems > 0, "items"].str.split("+")).explode("item")
    base = me.groupby(["pkm", "band", "nitems"]).agg(b_adj=("adj", "mean"), b_share=("share", "mean"), b_surv=("alive", "mean"),
                                                     b_n=("adj", "size")).reset_index()
    with_ = held.groupby(["item", "pkm", "band", "nitems"]).agg(adj=("adj", "mean"), share=("share", "mean"),
                                                               surv=("alive", "mean"), n=("adj", "size")).reset_index()
    pair = with_.merge(base, on=["pkm", "band", "nitems"])
    pair = pair[pair.b_n > pair.n] # some of the same Pokémon without it
    for m in ["adj", "share", "surv"]:
        pair["d_" + m] = (pair[m] - pair["b_" + m]) * pair["n"]
    it = pair.groupby("item").agg(n=("n", "sum"), d_adj=("d_adj", "sum"), d_share=("d_share", "sum"),
                                  d_surv=("d_surv", "sum")).reset_index()
    for m in ["d_adj", "d_share", "d_surv"]:
        it[m] = it[m] / it["n"]
    block(out, "items (d_* = holder - same Pokémon / band / item count without it; n >= %d)" % least,
          it[it.n >= least].sort_values("d_adj", ascending=False))

    # 5. roles: what each role does, then the Pokémon furthest from their role's job
    ro = me.groupby("role").agg(n=("adj", "size"), share=("share", "mean"), tshare=("tshare", "mean"), surv=("alive", "mean"),
                                life_s=("life_s", "mean"), support=("support", "mean"), casts=("casts", "mean"),
                                front=("y", lambda s: (s == 3).mean())).reset_index()
    block(out, "roles (front = share placed in the front row)", ro)
    job = {"tank": "tshare", "fighter": "share", "assassin": "share", "caster": "share", "marksman": "share",
           "support": "support"}
    fit = me.groupby(["pkm", "role"]).agg(n=("adj", "size"), share=("share", "mean"), tshare=("tshare", "mean"),
                                          surv=("alive", "mean"), support=("support", "mean")).reset_index()
    fit = fit[fit.n >= least].copy()
    fit["job"] = fit["role"].map(job)
    fit["value"] = fit.apply(lambda r: r[r["job"]], axis=1)
    fit["fit"] = fit["value"] / fit.groupby("role")["value"].transform("median").replace(0, np.nan)
    block(out, "role_fit worst (fit = its job metric / median of the role; job: tank tshare, support heal+shield, else share)",
          fit.sort_values("fit").head(25))
    block(out, "role_fit best", fit.sort_values("fit", ascending=False).head(15))

    text = out.getvalue()
    io.open(os.path.join(folder, "balance.tsv"), "w", encoding="utf-8").write(text)
    sys.stdout.write(text)


if __name__ == "__main__":
    main()
