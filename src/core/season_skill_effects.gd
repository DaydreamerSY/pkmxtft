class_name SeasonSkillEffects
extends RefCounted

## Lasting effects of the season skills (not in the web game; docs/DESIGN_S1.md) that need a hook of the fight. The
## skills (AbilityScripts, region "season 1") put timers / partners in u.counters; BattleSim calls the hooks below
## only when a unit of the fight casts one of SKILLS (season_skills_on, BattleSim.add_unit).

const SKILLS: Array[String] = ["WILL_O_WISP", "LIFE_DEW", "SHIFT_GEAR", "ELECTRO_LINK", "GUARD_DOG", "SPIDER_WEB",
	"MIRROR_COAT", "ROCK_AMBUSH", "DESTINY_BOND", "BATON_PASS", "DOUBLE_TEAM", "PARRY", "MIND_LINK", "DISGUISE_PATCH",
	"TIME_REWIND", "LOVE_TANGLE", "SNATCH", "DRAGON_FURY", "CONSTRICT", "ZAP_LOCK", "TOXIC_SPIKES"]
const HISTORY := 4 ## seconds of HP kept for Time Rewind


static func _flash(sim: BattleSim, u: BattleUnit, text: String, color := Color(0.95, 0.85, 0.45)) -> void:
	sim.emit({"type": "effect", "unit": u, "text": text, "color": color})


static func _active(sim: BattleSim, u: BattleUnit, key: String) -> bool:
	return sim.time_ms < float(u.counters.get(key, -1.0))


## x on a damage to `t` before DEF (BattleSim.deal_damage): Will-O-Wisp mark, Love Tangle, Zap Lock crits.
static func damage_factor(sim: BattleSim, _attacker: BattleUnit, t: BattleUnit) -> float:
	var f := 1.0
	if _active(sim, t, "wisp_until"):
		f *= 1.0 + float(t.counters.get("wisp_amp", 0.0))
	if _active(sim, t, "love_until"):
		f *= 1.3
	return f


## Before `t` takes `amount` (after DEF): Disguise stops it, a Guard Dog or a Mind Link partner takes a part.
static func redirect(sim: BattleSim, t: BattleUnit, amount: float, kind: int, attacker: BattleUnit,
		retaliation: bool) -> float:
	if retaliation or amount <= 0.0 or attacker == null or attacker.team == t.team:
		return amount
	if int(t.counters.get("disguise", 0)) > 0:
		t.counters.disguise = int(t.counters.disguise) - 1
		_flash(sim, t, "Disguise!")
		if attacker.alive:
			sim.deal_damage(attacker, float(t.counters.get("disguise_dmg", 0.0)), BattleUnit.DamageKind.SPECIAL, t,
				false, true)
		return 0.0
	for c in BattleBoard.adjacent_cells(t.cell):
		var g := sim.board.get_unit(c)
		if g != null and g.alive and g.team == t.team and _active(sim, g, "guard_until"):
			var part := roundf(amount * float(g.counters.get("guard_pct", 0.0)))
			if part >= 1.0:
				sim.deal_damage(g, part, kind, attacker, false, true, false)
				amount -= part
			break
	if _active(sim, t, "link_until"):
		var other := sim.unit_by_id(int(t.counters.get("link_with", -1)))
		if other != null and other.alive and other != t:
			var part := roundf(amount * 0.5)
			if part >= 1.0:
				sim.deal_damage(other, part, kind, attacker, false, true, false)
				amount -= part
	return amount


## `t` lost `taken` (shield + HP) and is still up or not (BattleSim.deal_damage): the Spider Web partner shares it,
## Mirror Coat sends special damage back, Life Dew remembers it.
static func after_damage(sim: BattleSim, t: BattleUnit, attacker: BattleUnit, taken: float, kind: int,
		retaliation: bool) -> void:
	if taken <= 0.0:
		return
	if t.ability_id == "LIFE_DEW":
		var dew: Array = t.counters.get("dew_log", [])
		dew.append([sim.time_ms, taken])
		while not dew.is_empty() and float(dew[0][0]) < sim.time_ms - 3000.0:
			dew.pop_front()
		t.counters.dew_log = dew
	if retaliation:
		return
	if _active(sim, t, "web_until"):
		var other := sim.unit_by_id(int(t.counters.get("web_with", -1)))
		if other != null and other.alive and other != t:
			sim.deal_damage(other, roundf(taken * float(t.counters.get("web_pct", 0.0))), BattleUnit.DamageKind.TRUE,
				attacker, false, true, false)
	if _active(sim, t, "mirror_until") and kind == BattleUnit.DamageKind.SPECIAL and attacker != null \
			and attacker.alive and attacker.team != t.team:
		sim.deal_damage(attacker, roundf(taken * float(t.counters.get("mirror_pct", 0.0))), BattleUnit.DamageKind.SPECIAL,
			t, false, true, false)


## A basic attack of `u` is about to land on `t` (BattleSim.attack_hit): true = it does not (Parry, Double Team).
static func blocks_attack(sim: BattleSim, u: BattleUnit, t: BattleUnit) -> bool:
	if _active(sim, t, "parry_until") and int(t.counters.get("parry", 0)) > 0:
		t.counters.parry = int(t.counters.parry) - 1
		_flash(sim, t, "Parry!")
		sim.deal_damage(u, roundf(t.atk * float(t.counters.get("parry_ratio", 1.2))), BattleUnit.DamageKind.PHYSICAL, t,
			false, true)
		return true
	if int(t.counters.get("decoys", 0)) > 0:
		t.counters.decoys = int(t.counters.decoys) - 1
		if int(t.counters.decoys) == 0:
			t.add_stat("speed", -float(t.counters.get("decoy_speed", 0.0)))
		sim.emit({"type": "miss", "unit": t})
		return true
	return false


## A basic attack of `u` hit `t` (BattleSim.attack_hit, after the damage): Shift Gear, Electro Link, Rock Ambush,
## Dragon Fury.
static func on_attack_hit(sim: BattleSim, u: BattleUnit, t: BattleUnit) -> void:
	if u.ability_id == "DRAGON_FURY":
		u.counters.fury = mini(int(u.counters.get("fury", 0)) + 1, 20)
	if int(u.counters.get("shift_gears", 0)) > 0:
		u.counters.shift_gears = int(u.counters.shift_gears) - 1
		if int(u.counters.shift_gears) == 0:
			u.add_stat("speed", -float(u.counters.get("shift_gear_speed", 0.0)))
		var near: BattleUnit = null
		for e in sim.enemies_of(u):
			if e != t and (near == null or BattleBoard.distance(e.cell, t.cell) < BattleBoard.distance(near.cell, t.cell)):
				near = e
		if near != null:
			sim.deal_damage(near, roundf(u.atk * 0.5 * (1.0 + u.ap / 100.0)), BattleUnit.DamageKind.SPECIAL, u, false, true)
	if _active(sim, u, "charged_until") and t.alive:
		sim.deal_damage(t, float(u.counters.get("charged_dmg", 0.0)), BattleUnit.DamageKind.SPECIAL, u, false, true)
	if u.counters.has("ambush") and t.alive:
		var bonus := roundf(u.atk * (float(u.counters.ambush) - 1.0) * u.crit_power)
		u.counters.erase("ambush")
		_flash(sim, u, "Ambush!")
		sim.deal_damage(t, bonus, BattleUnit.DamageKind.PHYSICAL, u, true, true)


## Crit chance added to the basic attacks at `t` (BattleSim.attack_hit): Zap Lock's paralysed target.
static func crit_bonus(sim: BattleSim, t: BattleUnit) -> float:
	return 0.3 if _active(sim, t, "zap_until") and t.has_status("paralysis") else 0.0


## Heals and shields for `t` (BattleSim.heal / add_shield): an enemy Snatching gets them instead.
static func snatcher(sim: BattleSim, t: BattleUnit) -> BattleUnit:
	for e in sim.enemies_of(t):
		if _active(sim, e, "snatch_until"):
			return e
	return t


## A unit fainted (BattleSim._faint): Destiny Bond takes its partner along, Baton Pass hands its boosts over.
static func on_death(sim: BattleSim, dead: BattleUnit) -> void:
	if _active(sim, dead, "bond_until"):
		var other := sim.unit_by_id(int(dead.counters.get("bond_with", -1)))
		dead.counters.erase("bond_until")
		if other != null and other.alive:
			_flash(sim, other, "Destiny Bond!", Color(0.6, 0.4, 0.9))
			sim.deal_damage(other, other.hp + other.shield + 1.0, BattleUnit.DamageKind.TRUE, null, false, true, false)
	if dead.counters.has("baton"):
		pass_baton(sim, dead)


## Baton Pass: the boosts it got go to the ADJACENT ally with the most ATK (once).
static func pass_baton(sim: BattleSim, u: BattleUnit) -> void:
	var boost: Dictionary = u.counters.get("baton", {})
	u.counters.erase("baton")
	if boost.is_empty():
		return
	if u.alive:
		u.add_stat("speed", -float(boost.speed))
		u.add_stat("atk", -float(boost.atk))
	var best: BattleUnit = null
	for c in BattleBoard.adjacent_cells(u.cell):
		var a := sim.board.get_unit(c)
		if a != null and a.alive and a.team == u.team and a != u and not a.inanimate and (best == null or a.atk > best.atk):
			best = a
	if best != null:
		best.add_stat("speed", float(boost.speed))
		best.add_stat("atk", float(boost.atk))
		sim.emit({"type": "buff", "unit": best, "stat": "atk", "amount": float(boost.atk)})


## Every second: the HP of the last seconds (Time Rewind), a trap under an enemy (Toxic Spikes).
static func each_second(sim: BattleSim, u: BattleUnit) -> void:
	var hist: Array = u.counters.get("hp_hist", [])
	hist.append(u.hp)
	if hist.size() > HISTORY:
		hist.pop_front()
	u.counters.hp_hist = hist
	var traps: Dictionary = _traps(sim)
	if traps.has(u.cell) and int(traps[u.cell].team) != u.team and not u.inanimate:
		var trap: Dictionary = traps[u.cell]
		traps.erase(u.cell)
		if sim.board_effects.has(u.cell):
			sim.board_effects[u.cell].erase("TRAP")
		sim.emit({"type": "board_effect", "cells": [u.cell], "effect": "TRAP"})
		var owner: BattleUnit = trap.owner if trap.owner != null and trap.owner.alive else null
		sim.deal_damage(u, float(trap.dmg), BattleUnit.DamageKind.SPECIAL, owner, false, true)
		for i in 2:
			sim.add_status(u, "poison", 3000.0, owner)


static func _traps(sim: BattleSim) -> Dictionary:
	if not sim.has_meta("season_traps"):
		sim.set_meta("season_traps", {})
	return sim.get_meta("season_traps")


## Toxic Spikes: traps of `owner`'s team on `cells` (an enemy entering one sets it off).
static func set_traps(sim: BattleSim, owner: BattleUnit, cells: Array, damage: float) -> void:
	var traps := _traps(sim)
	var shown: Array[Vector2i] = []
	for cell in cells:
		traps[cell] = {"team": owner.team, "dmg": damage, "owner": owner}
		if not sim.board_effects.has(cell):
			sim.board_effects[cell] = {}
		sim.board_effects[cell]["TRAP"] = true # tint only (Game BOARD_EFFECT_COLORS)
		shown.append(cell)
	sim.emit({"type": "board_effect", "cells": shown, "effect": "TRAP"})
