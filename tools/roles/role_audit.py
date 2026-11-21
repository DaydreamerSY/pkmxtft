"""Role audit (docs/ROLES.md), step 2: reads build/roles/probe_*.tsv (tools/roles/role_probe.gd: what the ability of
every form really does on test boards) and the rules (tools/roles/role_rules.json), suggests a role for every form and
line of evolution, and checks every synergy's members against what its effect wants (per season); writes docs/ROLES.md
(the report, Vietnamese) and build/roles/roles.tsv (every form, every number).
    python tools/roles/role_audit.py [build/roles]
The roles of the game (UnitRoles) are not changed: the report says what to change.
"""
import glob
import io
import json
import os
import sys

import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RULES = json.load(io.open(os.path.join(ROOT, "tools", "roles", "role_rules.json"), encoding="utf-8"))
POKEMON = json.load(io.open(os.path.join(ROOT, "data", "pac", "pokemon.json"), encoding="utf-8"))
POOL = json.load(io.open(os.path.join(ROOT, "data", "pac", "pool.json"), encoding="utf-8"))
SEASONS = json.load(io.open(os.path.join(ROOT, "data", "seasons.json"), encoding="utf-8"))
VI = json.load(io.open(os.path.join(ROOT, "data", "i18n", "vi.json"), encoding="utf-8"))
REPORT = os.path.join(ROOT, "docs", "ROLES.md")
ORDER = [k for k in ["tank", "fighter", "assassin", "marksman", "caster", "battlemage", "support"]
         if k != "battlemage" or RULES.get("battlemage")]
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


#region data
def load_probe(folder):
    files = sorted(glob.glob(os.path.join(folder, "probe_*.tsv")))
    if not files:
        raise SystemExit("role_audit: no %s/probe_*.tsv (run tools\\role_audit.bat)" % folder)
    d = pd.concat([pd.read_csv(f, sep="\t", na_filter=False) for f in files], ignore_index=True)
    d = d.drop_duplicates("pkm").set_index("pkm", drop=False)
    d.index.name = None # (pkm stays a column too)
    return d


def finals_of(pkm, seen=None):
    """The last forms of its line(s) of evolution (several for a branching line: Eevee, Tyrogue...)."""
    seen = seen or set()
    if pkm in seen or pkm not in POKEMON:
        return []
    seen.add(pkm)
    d = POKEMON[pkm]
    nxt = [d["evolution"]] if d.get("evolution") else list(d.get("evolutions") or [])
    nxt = [n for n in nxt if n in POKEMON]
    if not nxt:
        return [pkm]
    return sorted(set(f for n in nxt for f in finals_of(n, seen)))


def family_forms(family):
    return sorted(p for p, d in POKEMON.items() if d.get("family", p) == family)


def strings_in(value):
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        return [s for v in value.values() for s in strings_in(v)]
    if isinstance(value, list):
        return [s for v in value for s in strings_in(v)]
    return []


def rosters():
    """name -> the families a run can get: every season of data/seasons.json and "all" (no season, pool.json)."""
    out = {}
    for s in SEASONS.get("seasons", []):
        fams = set(strings_in(s.get("shop", {})) + strings_in(s.get("unique", [])) + strings_in(s.get("legendary", []))
                   + strings_in(s.get("hatch", [])))
        out[s["id"]] = sorted(POKEMON[f].get("family", f) for f in fams if f in POKEMON)
    every = set()
    for key in ("pool", "additional", "regional", "unique", "legendary", "hatch"):
        every |= set(strings_in(POOL.get(key, [])))
    out["all"] = sorted(set(POKEMON[f].get("family", f) for f in every if f in POKEMON))
    return out
#endregion


#region roles
def features(d, r):
    """The numbers of the rules on the probe table `d` (one row per form)."""
    d = d.copy()
    num = ["hp", "atk", "def", "speDef", "speed", "maxPP", "reach", "front_dmg", "back_dmg", "front_dot", "back_dot",
           "front_hit", "back_hit", "ally_heal", "ally_shield", "ally_buff", "ally_status", "self_heal", "self_shield",
           "self_buff", "cc", "debuff", "spawn", "dash", "engage", "web_range", "stars"]
    for c in num:
        d[c] = pd.to_numeric(d[c], errors="coerce").fillna(0.0)
    rate = 0.4 + 0.007 * d.speed.clip(lower=0)
    swings = r["fight"] * rate
    d["casts"] = ((swings * r["ppPerAttack"] + r["hitPP"]) / d.maxPP.where(d.maxPP > 0)).fillna(0.0).clip(upper=swings)
    d["front_out"] = d.front_dmg + d.front_dot
    d["back_out"] = d.back_dmg + d.back_dot
    d["per_cast"] = d[["front_out", "back_out"]].max(axis=1)
    d["skill_dmg"] = d.casts * d.per_cast
    d["attack_dmg"] = d.atk * (swings - d.casts) * r["critFactor"]
    d["share"] = (d.skill_dmg / (d.skill_dmg + d.attack_dmg).where(lambda s: s > 0)).fillna(0.0)
    d["help"] = d.ally_heal + d.ally_shield + r["helpBuff"] * d.ally_buff + r["helpStatus"] * d.ally_status
    d["harm"] = d.per_cast + r["helpStatus"] * d.cc + r["debuff"] * d.debuff
    d["help_share"] = (d.help / (d.help + d.harm).where(lambda s: s > 0)).fillna(0.0)
    d["back_ratio"] = (d.back_out / d.front_out.where(d.front_out > 0)).fillna((d.back_out > 0).astype(float))
    d["sustain"] = (d.self_heal + d.self_shield) / d.hp.clip(lower=1)
    d["bulk"] = d.hp * (1 + 0.05 * (d["def"] + d.speDef) / 2)
    d["bulk_pct"] = d.groupby(["rarity", "stars"])["bulk"].rank(pct=True)
    return d


def classify(x, r):
    """(role, why, flag) of one form (a row of features()); flag "inplace": a caster whose ability lands around itself
    instead of being thrown (a design to fix in its ability, docs/ROLES.md)."""
    ranged = x.web_range >= 2
    if x.help > 0 and x.help_share >= r["support"]:
        return "support", "skill giúp đồng đội (hồi / khiên / buff) = %d%% giá trị skill" % round(100 * x.help_share), ""
    in_place = x.reach < r["casterReach"] or x.back_ratio < r["backShare"]
    where = "tầm %d ô, từ hàng cuối còn %d%%" % (x.reach, round(100 * x.back_ratio))
    skill = "skill = %d%% sát thương" % round(100 * x.share)
    if ranged and x.share >= r["carryShare"]:
        if r["battlemage"] and in_place:
            return "battlemage", skill + ", skill phải đứng gần: " + where, ""
        if r["battlemage"] and x.web_range <= r["battlemageRange"] and x.bulk_pct >= r["battlemageBulk"]:
            return "battlemage", skill + ", tầm web %d + trâu (bulk %d%% cùng nhóm)" % (x.web_range, round(100 * x.bulk_pct)), ""
        if in_place:
            return "caster", skill + ", nhưng skill TẠI CHỖ (" + where + "): nên sửa thành skill tung", "inplace"
        return "caster", skill + ", tung được từ hàng cuối (" + where + ")", ""
    if not ranged and r["battlemage"] and x.share >= r["battlemageShare"]:
        return "battlemage", skill + ", cận chiến (tầm web 1)", ""
    why = "đòn đánh = %d%% sát thương" % round(100 * (1 - x.share))
    if ranged:
        if x.bulk_pct >= r["marksmanBulk"]:
            return "fighter", why + ", tầm web %d nhưng rất trâu (bulk %d%%)" % (x.web_range, round(100 * x.bulk_pct)), ""
        return "marksman", why + ", tầm web %d" % x.web_range, ""
    if x.engage >= r["assassinEngage"]:
        return "assassin", why + ", skill lao vào địch %d ô" % x.engage, ""
    if x.bulk_pct >= r["tankBulk"]:
        return "tank", why + ", trâu (bulk %d%% cùng nhóm)" % round(100 * x.bulk_pct), ""
    if x.sustain >= r["selfSustain"]:
        return "tank", why + ", tự hồi / khiên %d%% HP mỗi lần cast" % round(100 * x.sustain), ""
    return "fighter", why + ", cận chiến", ""


def suggest(d, r):
    d = d.copy()
    picked = [classify(x, r) for x in d.itertuples()]
    d["form_role"] = [p[0] for p in picked]
    d["why"] = [p[1] for p in picked]
    d["flag"] = [p[2] for p in picked]
    # a line of evolution: the role of its final form(s) (the most common one; a form between branches keeps its own)
    line = []
    for x in d.itertuples():
        finals = [f for f in finals_of(x.pkm) if f in d.index]
        roles = [d.at[f, "form_role"] for f in finals]
        if r.get("familyRole", "final") == "final" and roles:
            best = max(set(roles), key=lambda k: (roles.count(k), k == x.form_role))
            line.append(best if roles.count(best) * 2 > len(roles) or len(roles) == 1 else x.form_role)
        else:
            line.append(x.form_role)
    d["suggested"] = line
    return d
#endregion


#region synergies
def synergy_table(d, r, roster_families):
    """Per synergy (focus != team): its families in the roster (by their final forms' types), their roles now and
    suggested, and the share whose role gets something out of the synergy's effect."""
    benefits = {role: set(v["focus"]) for role, v in r["roles"].items()}
    members = {}
    for fam in roster_families:
        finals = [f for f in finals_of(fam) if f in d.index] or [f for f in family_forms(fam) if f in d.index][-1:]
        for f in finals:
            for t in str(d.at[f, "types"]).split(","):
                if t:
                    members.setdefault(t, {})[f] = (d.at[f, "role"], d.at[f, "suggested"])
    rows = []
    for syn, spec in r["synergies"].items():
        focus = spec["focus"]
        got = members.get(syn, {})
        if focus == "team" or not got:
            continue
        now = [v[0] for v in got.values()]
        new = [v[1] for v in got.values()]
        fit = lambda roles: sum(focus in benefits.get(x, set()) for x in roles) / len(roles)
        rows.append({"synergy": syn, "focus": focus, "why": spec.get("why", ""), "n": len(got),
                     "now": now, "new": new, "fit_now": fit(now), "fit_new": fit(new),
                     "misfits": sorted(f for f, v in got.items() if focus not in benefits.get(v[1], set()))})
    return rows


def role_counts(roles):
    c = {k: roles.count(k) for k in ORDER if roles.count(k)}
    return ", ".join("%s %d" % (RULES["roles"].get(k, {}).get("vi", k), n) for k, n in c.items())
#endregion


#region report
def md_table(header, rows):
    out = ["| " + " | ".join(header) + " |", "|" + "---|" * len(header)]
    out += ["| " + " | ".join(str(c) for c in row) + " |" for row in rows]
    return "\n".join(out)


def vi_role(role):
    return RULES["roles"].get(role, {}).get("vi", role)


def vi_syn(syn):
    return VI.get("synergy", {}).get(syn, syn)


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "roles")
    if not os.path.isabs(folder):
        folder = os.path.join(ROOT, folder)
    r = RULES
    d = suggest(features(load_probe(folder), r), r)
    cols = ["pkm", "family", "rarity", "stars", "types", "skill", "scripted", "role", "form_role", "suggested", "flag", "why",
            "web_range", "hp", "atk", "def", "speDef", "speed", "maxPP", "reach", "front_out", "back_out", "front_hit",
            "back_hit", "back_ratio", "casts", "per_cast", "skill_dmg", "attack_dmg", "share", "help", "harm",
            "help_share", "sustain", "bulk", "bulk_pct", "cc", "debuff", "spawn", "dash", "engage", "front_dot", "back_dot",
            "ally_heal", "ally_shield", "ally_buff", "self_heal", "self_shield", "self_buff"]
    d[cols].to_csv(os.path.join(folder, "roles.tsv"), sep="\t", index=False, float_format="%.3f")
    rost = rosters()
    in_game = set(f for fams in rost.values() for fam in fams for f in family_forms(fam))
    g = d[d.pkm.isin(in_game)]
    changed = g[g.role != g.suggested]
    L = []
    say = L.append
    say("# Kiểm tra vai trò Pokémon")
    say("")
    say("*Sinh bằng `tools\\role_audit.bat` (probe: `tools/roles/role_probe.gd`, luật: `tools/roles/role_rules.json`, báo cáo: "
        "`tools/roles/role_audit.py`); đừng sửa tay. Bảng đủ số: `build/roles/roles.tsv`.*")
    say("")
    say("Probe đặt từng dạng lên một sàn thử (chỉ số web, không item / AP / hệ), cho nó dùng skill một lần rồi đo: tầm với "
        "thật (một địch đứng cách 1..7 ô), sát thương khi đứng hàng đầu / hàng cuối lên 7 địch, burn / poison nó gây, hồi / "
        "khiên / buff cho đồng đội và cho chính nó, trạng thái / debuff lên địch, lao tới / triệu hồi. Luật (sửa được ở "
        "`role_rules.json`) ước lượng một trận %d s: phần sát thương từ skill so với đòn đánh, rồi xếp vai trò. Vai trò hiện "
        "tại là `UnitRoles._guess` (chỉ đọc skill dạng data: %d dạng có skill viết bằng code bị coi như skill không gây sát "
        "thương)."
        % (r["fight"], int((g.scripted.astype(int) == 1).sum())))
    say("")
    say("## Tóm tắt")
    say("")
    say("%d dạng có trong game (shop / unique / legendary / trứng của mọi mùa), %d dạng đổi vai trò (%d họ)." % (
        len(g), len(changed), changed.family.nunique()))
    say("")
    rows = []
    for role in ORDER:
        rows.append([vi_role(role) + (" (mới)" if r["roles"].get(role, {}).get("new") else ""),
                     int((g.role == role).sum()), int((g.suggested == role).sum())])
    say(md_table(["Vai trò", "Hiện tại", "Gợi ý"], rows))
    say("")
    flips = changed.groupby(["role", "suggested"]).size().sort_values(ascending=False)
    say("Đổi nhiều nhất: " + ", ".join("%s → %s %d" % (vi_role(a), vi_role(b), n) for (a, b), n in flips.head(8).items()) + ".")
    say("")
    # synergies
    say("## Hệ và vai trò")
    say("")
    say("Mỗi hệ có một *focus* (hiệu ứng của nó có lợi cho ai: đòn đánh, skill, đứng trước, gây sát thương); vai trò hưởng: "
        + "; ".join("%s: %s" % (vi_role(k), ", ".join(v["focus"])) for k, v in r["roles"].items())
        + ". **Hợp** = phần thành viên (theo dạng cuối của họ) có vai trò hưởng hiệu ứng của hệ. Hệ dưới %d%% bị đánh dấu ⚠."
        % round(100 * r["synergyFit"]))
    say("")
    for name in [s["id"] for s in SEASONS.get("seasons", [])] + ["all"]:
        table = synergy_table(d, r, rost.get(name, []))
        title = next((s.get("name", name) for s in SEASONS.get("seasons", []) if s["id"] == name), "Không mùa (mọi Pokémon)")
        say("### %s" % title)
        say("")
        rows = []
        for t in sorted(table, key=lambda t: t["fit_new"]):
            flag = "⚠ " if t["fit_new"] < r["synergyFit"] else ("↑ " if t["fit_new"] > t["fit_now"] + 0.05 else "")
            rows.append([flag + vi_syn(t["synergy"]), t["focus"], t["n"], role_counts(t["now"]), "%d%%" % round(100 * t["fit_now"]),
                         role_counts(t["new"]), "%d%%" % round(100 * t["fit_new"]),
                         ", ".join(t["misfits"][:6]) + (" …" if len(t["misfits"]) > 6 else "")])
        say(md_table(["Hệ", "Focus", "Họ", "Vai trò hiện tại", "Hợp", "Vai trò gợi ý", "Hợp", "Không hưởng (gợi ý)"], rows))
        say("")
    # changes by family
    say("## Đổi vai trò (theo họ, dạng cuối)")
    say("")
    say("Số: skill = phần sát thương từ skill trong trận %d s ước lượng; tầm = ô xa nhất skill còn trúng; cuối = sát thương "
        "skill khi đứng hàng cuối so với hàng đầu; trúng = số địch trúng (hàng đầu / hàng cuối); bulk = xếp hạng độ trâu trong "
        "cùng độ hiếm × sao." % r["fight"])
    say("")
    rows = []
    finals = changed[changed.pkm.apply(lambda p: p in finals_of(p))]
    for x in finals.sort_values(["suggested", "rarity", "pkm"]).itertuples():
        rows.append(["%s (%s)" % (x.pkm, x.family) if x.family != x.pkm else x.pkm, x.rarity, vi_role(x.role),
                     "**%s**" % vi_role(x.suggested), "%d%%" % round(100 * x.share), int(x.reach), "%d%%" % round(100 * x.back_ratio),
                     "%d / %d" % (x.front_hit, x.back_hit), int(x.web_range), "%d%%" % round(100 * x.bulk_pct), x.why])
    say(md_table(["Dạng cuối (họ)", "Độ hiếm", "Hiện tại", "Gợi ý", "Skill", "Tầm", "Cuối", "Trúng", "Tầm web", "Bulk", "Lý do"], rows))
    say("")
    # casters whose ability lands where it stands (the user: a caster throws its ability)
    inplace = g[(g.flag == "inplace") & g.pkm.apply(lambda p: p in finals_of(p))]
    if len(inplace):
        say("## Pháp sư có skill tại chỗ (nên sửa skill)")
        say("")
        say("Pháp sư nên *tung* skill (vào mục tiêu / đường thẳng / ném xa) chứ không *thả skill tại chỗ* (quanh mình). Các dạng "
            "cuối dưới đây là carry skill tầm xa nhưng skill chỉ trúng khi đứng gần: tầm < %d ô hoặc từ hàng cuối còn < %d%% sát "
            "thương so với hàng đầu. Danh sách đủ skill để đọc / cân lại: `docs/SKILLS.md`, `docs/skills.html`."
            % (r["casterReach"], round(100 * r["backShare"])))
        say("")
        rows = []
        for x in inplace.sort_values(["rarity", "pkm"]).itertuples():
            rows.append([x.pkm, x.rarity, x.skill, vi_role(x.role), int(x.reach), "%d%%" % round(100 * x.back_ratio),
                         "%d / %d" % (x.front_hit, x.back_hit), "%d%%" % round(100 * x.share)])
        say(md_table(["Dạng cuối", "Độ hiếm", "Skill", "Vai trò hiện tại", "Tầm", "Cuối", "Trúng", "Skill"], rows))
        say("")
    # families whose forms do not agree
    split = []
    for fam, forms in g.groupby("family"):
        roles = sorted(set(forms.form_role))
        if len(roles) > 1:
            split.append([fam, ", ".join("%s %s" % (p, vi_role(fr)) for p, fr in zip(forms.pkm, forms.form_role))])
    if split:
        say("## Họ có dạng khác vai trò")
        say("")
        say("Từng dạng xếp riêng ra vai trò khác nhau (skill / chỉ số đổi theo sao); gợi ý lấy vai trò của dạng cuối "
            "(`familyRole`).")
        say("")
        say(md_table(["Họ", "Vai trò từng dạng"], split[:80]))
        say("")
    text = "\n".join(L) + "\n"
    io.open(REPORT, "w", encoding="utf-8", newline="\n").write(text)
    print("role audit: %d forms in the game, %d change (%d families) -> %s, %s" % (
        len(g), len(changed), changed.family.nunique(), os.path.relpath(REPORT, ROOT),
        os.path.relpath(os.path.join(folder, "roles.tsv"), ROOT)))
    print("now:       " + role_counts(list(g.role)))
    print("suggested: " + role_counts(list(g.suggested)))


if __name__ == "__main__":
    main()
