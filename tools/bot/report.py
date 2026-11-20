"""Compact balance tables from a bot batch (tools/bot_run.ps1, docs/BOT.md) - made for Claude to read, not people:
TSV blocks headed "#name", few rounded numbers. Also writes <dir>/boards.tsv (winning boards per stage band).
    python tools/bot/report.py build/bot/b1 [--min 20]     (--min: rows needed for a line of the per-name tables)
"""
import glob
import io
import os
import sys

import pandas as pd

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


def load(folder, kind):
    files = sorted(glob.glob(os.path.join(folder, "%s_*.tsv" % kind)))
    frames = [pd.read_csv(f, sep="\t", na_filter=False, low_memory=False) for f in files if os.path.getsize(f) > 0]
    return pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()


def block(out, name, df):
    out.write("#%s\n" % name)
    df.to_csv(out, sep="\t", index=False, float_format="%.3g", lineterminator="\n")


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else "build/bot/latest"
    least = int(sys.argv[sys.argv.index("--min") + 1]) if "--min" in sys.argv else 20
    runs, stages, units = load(folder, "runs"), load(folder, "stages"), load(folder, "units")
    if runs.empty:
        sys.exit("no runs in %s" % folder)
    out = io.StringIO()
    runs["style"] = runs["bot"].str.split(":").str[0]
    stages["win"] = (stages["res"] == "W").astype(int)
    out.write("#meta runs=%d stages=%d units=%d\n" % (len(runs), len(stages), len(units)))

    q = lambda p: (lambda s: s.quantile(p))
    agg = dict(n=("stage", "size"), stage=("stage", "mean"), med=("stage", "median"), p10=("stage", q(0.1)),
               p90=("stage", q(0.9)), lvl=("level", "mean"))
    block(out, "by_setup diff season pass", runs.groupby(["diff", "season", "pass"]).agg(**agg).reset_index())
    block(out, "by_style", runs.groupby("style").agg(**agg).reset_index())

    # the difficulty curve: per stage, of the runs that fought it
    curve = stages.groupby("stage").agg(reach=("run", "size"), win=("win", "mean"), life=("life", "mean"),
                                        lvl=("level", "mean"), team=("team", "mean"), gold=("gold", "mean"),
                                        rolls=("rolls", "mean")).reset_index()
    losses = stages[stages.res != "W"].groupby("stage")["loss"].mean().rename("loss_on_def")
    curve = curve.join(losses, on="stage")
    block(out, "curve (win = share of fights won; loss_on_def = life lost when not won)", curve[curve.reach >= 5])

    band = (runs["stage"] // 5) * 5
    death = runs.groupby(band).size().rename("n").reset_index().rename(columns={"stage": "end_from"})
    death["share"] = death["n"] / len(runs)
    block(out, "death (runs ending in stages end_from..end_from+4)", death)

    ends = runs.groupby("wave").size().rename("deaths")
    waves = stages.groupby("wave").agg(n=("run", "size"), win=("win", "mean"), loss=("loss", "mean"),
                                       stage=("stage", "mean")).join(ends).fillna({"deaths": 0}).reset_index()
    waves = waves[waves.n >= 5].sort_values(["deaths", "win"], ascending=[False, True])
    block(out, "waves (deaths = runs it ended)", waves.head(30))

    stages["band"] = (stages["stage"] // 10) * 10
    block(out, "wkind band x kind", stages.groupby(["band", "wkind"]).agg(n=("run", "size"), win=("win", "mean")).reset_index())

    # synergies active on the player's board
    syn_rows = []
    for row in stages[["syn", "win", "stage"]].itertuples(index=False):
        for part in str(row.syn).split("|") if row.syn else []:
            t, count, tier = part.split(":")
            syn_rows.append((t, int(tier), row.win, row.stage))
    if syn_rows:
        syn = pd.DataFrame(syn_rows, columns=["type", "tier", "win", "stage"])
        block(out, "syn (stages with the synergy active)", syn.groupby("type").agg(
            n=("win", "size"), win=("win", "mean"), tier=("tier", "mean"), stage=("stage", "mean")).reset_index()
            .sort_values("win", ascending=False))
        # balance at a glance (auto balance, docs/BOT.md): per bot style, the spread between the synergies of the
        # stage-adjusted win rate of boards with the synergy active - lower = more even
        styled = stages.merge(runs[["run", "style"]], on="run", how="left")
        styled["adj"] = styled["win"] - styled.groupby(["style", "stage"])["win"].transform("mean")
        spread = []
        for style, g in styled.groupby("style"):
            per = pd.DataFrame([(p.split(":")[0], a) for s, a in g[["syn", "adj"]].itertuples(index=False)
                                for p in (str(s).split("|") if s else [])], columns=["type", "adj"])
            per = per.groupby("type")["adj"].agg(["size", "mean"])
            per = per[per["size"] >= 100]
            if len(per) < 3:
                continue
            w = per["size"] / per["size"].sum()
            mu = (w * per["mean"]).sum()
            top = per["mean"].sort_values(ascending=False)
            spread.append((style, len(g), ((w * (per["mean"] - mu) ** 2).sum()) ** 0.5,
                           ",".join("%s%+.3f" % kv for kv in top.head(3).items()), ",".join("%s%+.3f" % kv for kv in top.tail(3).items())))
        if spread:
            block(out, "syn_spread (per style: sd between synergies of the stage-adjusted win rate; lower = more even)",
                  pd.DataFrame(spread, columns=["style", "stages", "spread", "top", "low"]))

    if not units.empty:
        units = units.merge(stages[["run", "stage", "win"]], on=["run", "stage"], how="left")
        units["team_dealt"] = units.groupby(["run", "stage", "team"])["dealt"].transform("sum").clip(lower=1)
        units["share"] = units["dealt"] / units["team_dealt"]
        mine = units[units.team == "B"]
        pk = mine.groupby("pkm").agg(n=("win", "size"), win=("win", "mean"), stars=("stars", "mean"), dealt=("dealt", "mean"),
                                     share=("share", "mean"), taken=("taken", "mean"), heal=("heal", "mean"),
                                     role=("role", "first")).reset_index()
        pk = pk[pk.n >= least].sort_values("win", ascending=False)
        block(out, "pkm best (player units, n >= %d)" % least, pk.head(25))
        block(out, "pkm worst", pk.tail(25))
        items = mine[mine["items"] != ""].assign(item=mine["items"].str.split("+")).explode("item")
        it = items.groupby("item").agg(n=("win", "size"), win=("win", "mean"), dealt=("dealt", "mean")).reset_index()
        block(out, "items (held by player units)", it[it.n >= least].sort_values("win", ascending=False))
        roles = mine.groupby("role").agg(n=("win", "size"), win=("win", "mean"), share=("share", "mean"),
                                         taken=("taken", "mean")).reset_index()
        block(out, "roles", roles)
        foe = units[units.team == "R"].groupby("pkm").agg(n=("dealt", "size"), dealt=("dealt", "mean"),
                                                         share=("share", "mean"), alive=("alive", "mean")).reset_index()
        block(out, "enemy carries (enemy units by damage share)", foe[foe.n >= least].sort_values("share", ascending=False).head(25))

    # design test: every combo of synergies played by the pro bot - the tier list of the combos
    design = runs[runs["style"] == "design"]
    if not design.empty:
        combos = design.groupby("aims").agg(n=("stage", "size"), stage=("stage", "mean"), med=("stage", "median"),
                                            p90=("stage", q(0.9)), wins=("wins", "sum"), fights=("stage", "sum")).reset_index()
        combos["win"] = combos["wins"] / combos["fights"].clip(lower=1)
        combos = combos.drop(columns=["wins", "fights"]).sort_values("stage", ascending=False)
        block(out, "combos (design test: every combo the pool has, played by the pro bot)", combos)
        rows = []
        for r in design[["aims", "stage"]].itertuples(index=False):
            for t in str(r.aims).split(","):
                rows.append((t, r.stage))
        per = pd.DataFrame(rows, columns=["type", "stage"]).groupby("type")["stage"].agg(["size", "mean", "std"]).reset_index()
        per["se"] = per["std"] / per["size"].clip(lower=1) ** 0.5
        per["vs_all"] = per["mean"] - design["stage"].mean()
        block(out, "combo_types (mean stage of the combos with the synergy; se = standard error, vs_all = against every combo)",
              per.drop(columns=["std"]).sort_values("mean", ascending=False))
    pro = runs[runs["style"] == "pro"]
    if not pro.empty:
        top = pro["aims"].value_counts(normalize=True)
        out.write(("#pro_variety distinct_plans=%d of %d runs, top plan %s %.3f" % (pro["aims"].nunique(), len(pro), top.index[0], top.iloc[0])) + chr(10))
    # winning boards with room to spare, per 5-stage band: material for Endless waves
    good = stages[(stages.res == "W") & (stages.alive_b >= 2)].copy()
    good["band"] = (good["stage"] // 5) * 5
    good = good.sort_values(["band", "alive_b", "life"], ascending=[True, False, False]).groupby("band").head(20)
    good[["band", "stage", "board", "syn", "alive_b", "life", "wave"]].to_csv(
        os.path.join(folder, "boards.tsv"), sep="\t", index=False)
    out.write("#boards %d rows -> %s\n" % (len(good), os.path.join(folder, "boards.tsv")))

    text = out.getvalue()
    io.open(os.path.join(folder, "report.tsv"), "w", encoding="utf-8").write(text)
    sys.stdout.write(text)


if __name__ == "__main__":
    main()
