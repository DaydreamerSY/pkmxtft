"""Season tables from bot batches (docs/BOT.md "Mùa có skill / hệ riêng"): how the synergy effects and the skills a season
gives its families (data/season_synergies.json, data/season_skills.json) do - against the other seasons of the batches
and against the same forms with their web skill. Made for Claude to read (TSV blocks "#name", few rounded numbers).
    python tools/bot/season_report.py build/bot/design_s1_v9 [build/bot/bal_v9 ...] [--season s1] [--min 30]
Writes <first folder>/season_<id>.tsv (season_all.tsv without --season).
adj = win rate - the mean win rate of the same season and stage (the player's fights). D / T / S = damage dealt / taken,
heal + shield given, each against the even share of the unit's team in that fight (1 = an even share).
dmg0 / dmgi = damage against the same role (autobalance.expected_damage: the player's other units of the same role,
stars, items held and 5-stage band; x1 = like them), without items / with items; _web: the same forms with their web skill.
"""
import glob
import io
import json
import os
import sys

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import autobalance as ab  # noqa: E402 (season_forms, expected_damage: the same rules as the auto balance)

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def arg(name, default):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def folders():
    out, skip = [], False
    for a in sys.argv[1:]:
        if skip:
            skip = False
        elif a.startswith("--"):
            skip = True
        else:
            out.append(a)
    return out


def load(dirs, kind):
    frames = []
    for b, folder in enumerate(dirs):
        for f in sorted(glob.glob(os.path.join(folder, "%s_*.tsv" % kind))):
            if os.path.getsize(f) == 0:
                continue
            d = pd.read_csv(f, sep="\t", na_filter=False, low_memory=False, on_bad_lines="skip")
            d["batch"] = b
            frames.append(d)
    return pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()


def block(out, name, df):
    out.write("#%s\n" % name)
    df.to_csv(out, sep="\t", index=False, float_format="%.3g", lineterminator="\n")


def read_json(rel):
    with io.open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return json.load(f)


def parse_syn(text):
    """'TYPE:count:tier|...' -> [(type, tier)]"""
    out = []
    for part in str(text).split("|"):
        bits = part.split(":")
        if len(bits) >= 3 and bits[0]:
            out.append((bits[0], int(float(bits[2]))))
    return out


def mechanic(season_syn, season, t):
    entry = season_syn.get(season, {}).get(t)
    if not isinstance(entry, dict):
        return "web"
    names = [str(e.get("type", "?")) for e in entry.get("effects", []) if isinstance(e, dict)]
    return ("" if entry.get("mode", "replace") == "replace" else "web+") + "+".join(names)


def errors(dirs):
    total, lines = 0, {}
    for folder in dirs:
        for f in glob.glob(os.path.join(folder, "meta_*.tsv")):
            for line in io.open(f, encoding="utf-8", errors="replace"):
                if line.startswith("errors\t"):
                    total += int(line.split("\t")[1])
        for f in glob.glob(os.path.join(folder, "err_*.txt")):
            for line in io.open(f, encoding="utf-8", errors="replace"):
                line = line.strip()
                if "ERROR" in line:
                    lines[line[:160]] = lines.get(line[:160], 0) + 1
    return total, sorted(lines.items(), key=lambda kv: -kv[1])


def main():
    dirs = folders() or ["build/bot/latest"]
    least = int(arg("--min", "30"))
    runs, stages, units = load(dirs, "runs"), load(dirs, "stages"), load(dirs, "units")
    if runs.empty:
        sys.exit("no runs in %s" % ", ".join(dirs))
    pokemon = read_json("data/pac/pokemon.json")
    maps = ab.season_forms()
    season_syn = read_json("data/season_synergies.json").get("seasons", {})
    web_users = {}
    for pkm, d in pokemon.items():
        web_users.setdefault(d.get("skill", ""), []).append(pkm)
    custom = sorted(s for s in set(runs.season) if maps.get(s) or season_syn.get(s))
    shown = [arg("--season", "")] if "--season" in sys.argv else custom
    out = io.StringIO()
    out.write("#meta folders=%s runs=%d stages=%d units=%d custom_seasons=%s\n"
              % (",".join(dirs), len(runs), len(stages), len(units), ",".join(custom)))
    total, lines = errors(dirs)
    out.write("#errors runs_stopped=%d distinct_error_lines=%d\n" % (total, len(lines)))
    for text, n in lines[:12]:
        out.write("%d\t%s\n" % (n, text))

    runs["style"] = runs["bot"].str.split(":").str[0]
    runs["ms_stage"] = runs["real_ms"] / runs["stage"].clip(lower=1)
    stages = stages.merge(runs[["batch", "run", "season", "style"]], on=["batch", "run"], how="left")
    stages["win"] = (stages["res"] == "W").astype(float)
    stages["draw"] = (stages["res"] == "D").astype(float)
    stages["adj"] = stages["win"] - stages.groupby(["season", "stage"])["win"].transform("mean")

    # 1. the seasons side by side (same machine load inside one batch: ms_stage compares the cost of the code)
    per_run = runs.groupby(["batch", "season"]).agg(runs=("stage", "size"), stage=("stage", "mean"),
                                                   med=("stage", "median"), p90=("stage", lambda s: s.quantile(0.9)),
                                                   ms_stage=("ms_stage", "mean"))
    per_fight = stages.groupby(["batch", "season"]).agg(fights=("win", "size"), win=("win", "mean"),
                                                       draw=("draw", "mean"), fight_s=("fight_s", "mean"))
    block(out, "seasons (per batch; ms_stage = real time per stage of a worker)", per_run.join(per_fight).reset_index())
    by_style = runs.groupby(["season", "style"]).agg(runs=("stage", "size"), stage=("stage", "mean")).reset_index()
    block(out, "seasons_by_style", by_style)

    # 2. synergies: the player's fights with it active (B) / the enemy wave having it (R)
    rows = []
    for r in stages[["season", "syn", "wsyn", "adj"]].itertuples(index=False):
        for t, tier in parse_syn(r.syn):
            rows.append((r.season, "B", t, tier, r.adj))
        for t, tier in parse_syn(r.wsyn):
            rows.append((r.season, "R", t, tier, r.adj))
    syn = pd.DataFrame(rows, columns=["season", "side", "type", "tier", "adj"])
    mine = syn[syn.side == "B"]
    tab = mine.groupby(["season", "type"]).agg(n=("adj", "size"), adj=("adj", "mean")).reset_index()
    two = mine[mine.tier >= 2].groupby(["season", "type"]).agg(n2=("adj", "size"), adj2=("adj", "mean")).reset_index()
    foe = syn[syn.side == "R"].groupby(["season", "type"]).agg(n_foe=("adj", "size"), adj_foe=("adj", "mean")).reset_index()
    tab = tab.merge(two, on=["season", "type"], how="left").merge(foe, on=["season", "type"], how="left")
    tab["mechanic"] = [mechanic(season_syn, s, t) for s, t in zip(tab.season, tab.type)]
    ok = tab[tab.n >= least]
    spread = ok.groupby("season").agg(types=("adj", "size"), sd_adj=("adj", "std"), min_adj=("adj", "min"),
                                      max_adj=("adj", "max")).reset_index()
    spread["custom"] = spread["season"].isin(custom)
    block(out, "synergy_spread (sd of adj over the synergies with >= --min fights, per season)", spread)
    for season in shown:
        t = tab[(tab.season == season) & (tab.n >= least)].sort_values("adj", ascending=False)
        block(out, "synergies %s (B: the player's fights with it; adj_foe: the player's adj when the wave has it)" % season,
              t.drop(columns=["season"]))

    if units.empty:
        io.open(os.path.join(dirs[0], "season_%s.tsv" % (shown[0] if len(shown) == 1 else "all")), "w",
                encoding="utf-8").write(out.getvalue())
        print(out.getvalue())
        return
    # 3. units: the share of the team's damage / damage taken / heal + shield, casts, the skill each form had
    units = units.merge(stages[["batch", "run", "stage", "season", "adj"]], on=["batch", "run", "stage"], how="left")
    units["nitems"] = units["items"].map(lambda s: 0 if s == "" else str(s).count("+") + 1)
    units["sus"] = units["heal"] + units["shield"]
    key = ["batch", "run", "stage", "team"]
    for col, name in (("dealt", "D"), ("taken", "T"), ("sus", "S")):
        mean = units.groupby(key)[col].transform("mean")
        units[name] = np.where(mean > 0, units[col] / mean.where(mean > 0, 1), np.nan)
    units["seasonal"] = [p in maps.get(s, {}) for s, p in zip(units.season, units.pkm)]
    units["skill"] = [maps.get(s, {}).get(p) or pokemon.get(p, {}).get("skill", "") for s, p in zip(units.season, units.pkm)]
    units["out"] = units["sdealt"] + units["ssus"]
    units["other"] = units["dealt"] - units["adealt"] - units["sdealt"]
    # damage against the same role (the player's units; a form with a season skill is <form>@<season> there)
    entity = units.assign(pkm=np.where(units.seasonal, units.pkm + "@" + units.season.astype(str), units.pkm))
    dmg = ab.expected_damage(entity[entity.team == "B"])
    dmg = dmg.assign(skill=units.loc[dmg.index, "skill"], seasonal=units.loc[dmg.index, "seasonal"],
                     season=units.loc[dmg.index, "season"], form=units.loc[dmg.index, "pkm"])
    ratio = lambda r: r["dealt"].sum() / r["exp"].sum() if len(r) >= 20 else np.nan

    roles = units[units.nitems == 0].groupby(["season", "role"]).agg(n=("casts", "size"), casts=("casts", "mean"),
                                                                       zero=("casts", lambda s: (s == 0).mean()),
                                                                       D=("D", "mean"), T=("T", "mean"), S=("S", "mean"),
                                                                       alive=("alive", "mean")).reset_index()
    block(out, "roles (units without item, both teams)", roles)
    sea = units[units.seasonal].groupby("season").agg(n=("casts", "size"), D=("D", "mean"), T=("T", "mean"),
                                                      casts=("casts", "mean")).reset_index()
    block(out, "seasonal_units (units having a season skill)", sea)

    for season in shown:
        here = units[units.season == season]
        role_d = here.groupby("role")["D"].mean()
        role_casts = here[here.nitems == 0].groupby("role")["casts"].mean()
        rows = []
        for skill, g in here[here.seasonal].groupby("skill"):
            forms = sorted(set(g.pkm))
            web = units[(units.pkm.isin(forms)) & (~units.seasonal)]
            mine = dmg[(dmg.season == season) & dmg.seasonal & (dmg.skill == skill)]
            theirs = dmg[dmg.form.isin(forms) & ~dmg.seasonal]
            g0 = g[g.nitems == 0]
            casts = g["casts"].sum()
            role = g["role"].mode().iloc[0]
            rows.append(dict(
                skill=skill, kind="new" if skill not in web_users else "borrowed", role=role,
                forms=",".join(forms[:3]) + ("+%d" % (len(forms) - 3) if len(forms) > 3 else ""),
                n=len(g), nB=int((g.team == "B").sum()), pp=g["maxpp"].mean(), pp_web=web["maxpp"].mean(),
                dmg0=ratio(mine[mine.nitems == 0]), dmgi=ratio(mine[mine.nitems > 0]),
                dmg0_web=ratio(theirs[theirs.nitems == 0]), dmgi_web=ratio(theirs[theirs.nitems > 0]),
                casts0=g0["casts"].mean(), zero0=(g0["casts"] == 0).mean(),
                first=g.loc[g.casts > 0, "first_cast"].mean(), out_cast=g["out"].sum() / casts if casts else 0.0,
                skill_part=g["sdealt"].sum() / max(g["dealt"].sum(), 1), other_part=g["other"].sum() / max(g["dealt"].sum(), 1),
                D=g["D"].mean(), D_role=role_d.get(role, np.nan), T=g["T"].mean(), S=g["S"].mean(),
                alive=g["alive"].mean(), adj=g.loc[g.team == "B", "adj"].mean(),
                n_web=len(web), D_web=web["D"].mean(), casts0_web=web.loc[web.nitems == 0, "casts"].mean(),
                adj_web=web.loc[web.team == "B", "adj"].mean(), casts0_role=role_casts.get(role, np.nan)))
        if rows:
            t = pd.DataFrame(rows)
            t["dD"] = t["D"] - t["D_web"]
            t = t.sort_values("D", ascending=False)
            block(out, "skills %s (n >= --min: every season skill; D_web / casts0_web / adj_web = the same forms with "
                       "their web skill in the other seasons)" % season, t[t.n >= least])
            block(out, "skills %s few (n < --min)" % season, t[t.n < least][["skill", "kind", "role", "forms", "n"]])

    name = "season_%s.tsv" % (shown[0] if len(shown) == 1 else "all")
    io.open(os.path.join(dirs[0], name), "w", encoding="utf-8").write(out.getvalue())
    print(out.getvalue())


if __name__ == "__main__":
    main()
