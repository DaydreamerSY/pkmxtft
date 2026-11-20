class_name AbilityRunner
extends RefCounted

## Runs the data-driven abilities of data/abilities.json (schema: docs/ABILITIES.md).
##
## The same `step_cells()` computes the cells of an ability for the simulation,
## for the flash on the board when it is cast and for the preview in the unit
## info panel, so the cells shown are always the cells really affected.

const AREA_LABELS := {
	"self": "itself",
	"single": "the target cell",
	"adjacent": "the 6 cells around %s",
	"adjacent_center": "%s and the 6 cells around",
	"radius": "every cell within %d of %s",
	"square": "every cell in its attack range",
	"cone": "a cone of depth %d in front of it",
	"ray": "a straight line of %d cells toward the target",
	"ray_edge": "a straight line toward the target, to the board edge",
	"line": "a line through the target to the board edge",
	"between": "the cells between it and %s",
	"path": "the cells on its dash path",
	"board": "the whole board",
	"row": "the whole row of the target",
	"closest": "the %d closest enemies",
	"backline": "the %d back-most enemies",
	"random": "%d random hits",
}


#region cast
## castAbility: spends the PP and runs the ability (`ability_id` = another one than its own,
## Pursuit chasing its target).
static func cast(sim: BattleSim, caster: BattleUnit, target: BattleUnit, ability_id := "") -> void:
	if ability_id == "":
		ability_id = caster.ability_id
	var ab := GameData.get_ability(ability_id)
	caster.pp = maxf(caster.pp - caster.max_pp, 0.0)
	caster.cast_count += 1
	sim.abilities_cast[caster.team].append(ability_id)
	var ctx := {
		"sim": sim, "caster": caster, "ability": ab,
		"focus": resolve_focus(sim, caster, target, ab.get("focus", "target")),
		"start_cell": caster.cell,
	}
	_dash(ctx, ab.get("dash", ""))
	ctx.dash_end = caster.cell
	var focus: BattleUnit = ctx.focus
	if focus != null and focus.cell != caster.cell:
		caster.facing = BattleBoard.orientation(caster.cell, focus.cell)
	sim.emit({"type": "cast", "unit": caster, "ability": ability_id, "focus": focus})

	var steps: Array = ab.get("steps", [])
	if ab.get("cycle", false) and not steps.is_empty():
		steps = [steps[(caster.cast_count - 1) % steps.size()]]
	var outer := sim.ability_source # its damage / heal / shield (and what it schedules) are the ability's
	var outer_hooks := sim.damage_hooks # cast from what follows a damage: its own ability is scaled all the same
	sim.ability_source = caster
	sim.damage_hooks = 0
	for step in steps:
		_schedule_step(ctx, step)
	AbilityScripts.run(ctx) # "script": code of the ability (ability_scripts.gd)
	if ab.get("special", "") == "transe":
		PassiveEffects.transe(sim, caster)
	sim.ability_source = outer
	sim.damage_hooks = outer_hooks
	ItemEffects.on_cast(sim, caster)
	SynergyEffects.on_cast(sim, caster)
	PassiveEffects.on_cast(sim, caster)


static func resolve_focus(sim: BattleSim, caster: BattleUnit, target: BattleUnit, kind: String) -> BattleUnit:
	match kind:
		"farthest":
			return sim.farthest_enemy(caster)
		"self":
			return caster
		"lowest_ally":
			var best: BattleUnit = null
			for a in sim.allies_of(caster):
				if best == null or a.hp_ratio() < best.hp_ratio():
					best = a
			return best
	if target != null and target.alive:
		return target
	return sim.nearest_enemy_manhattan(caster)


static func _schedule_step(ctx: Dictionary, step: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var caster: BattleUnit = ctx.caster
	var area: String = step.get("area", "single")
	var delay := float(step.get("delay", 0))
	var interval := float(step.get("interval", 0))

	# one hit per pick: random bombardments, projectiles cycling on the closest enemies
	if area == "random" or (area == "closest" and step.get("cycle_targets", false)):
		var picks := int(_size(ctx, step))
		if area == "random" and step.get("ap_picks", false):
			picks = roundi(picks * (1.0 + caster.ap / 100.0))
		var ordered := _closest_enemies(sim, caster, 99)
		for i in picks:
			var index := i
			sim.schedule(delay + i * maxf(interval, 100.0 if area == "closest" else interval), caster,
				func() -> void: _run_pick(ctx, step, ordered, index))
		return

	if delay >= 500.0:
		# telegraph: show now where it will land
		sim.emit({"type": "area", "unit": caster, "cells": step_cells(ctx, step),
			"affects": step.get("affects", "enemies"), "telegraph": true, "duration": delay})
	for i in _repeat(ctx, step):
		sim.schedule(delay + i * interval, caster, func() -> void: _run_step(ctx, step))


static func _run_step(ctx: Dictionary, step: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var cells := step_cells(ctx, step)
	var targets := _targets_in(ctx, step, cells)
	sim.emit({"type": "area", "unit": ctx.caster, "cells": cells,
		"affects": step.get("affects", "enemies")})
	_apply_effects(ctx, step, targets)


static func _run_pick(ctx: Dictionary, step: Dictionary, ordered: Array[BattleUnit], index: int) -> void:
	var sim: BattleSim = ctx.sim
	var caster: BattleUnit = ctx.caster
	var cell: Variant = null
	if step.get("area") == "closest":
		var alive: Array[BattleUnit] = []
		for e in ordered:
			if e.alive:
				alive.append(e)
		if alive.is_empty():
			return
		cell = alive[index % alive.size()].cell
	else:
		var enemies := sim.enemies_of(caster)
		if enemies.is_empty():
			return
		var enemy := enemies[sim.rng.randi() % enemies.size()]
		cell = enemy.cell
		if step.get("scatter", false):
			var around := BattleBoard.adjacent_cells(enemy.cell, true)
			cell = around[sim.rng.randi() % around.size()]
	var cells: Array[Vector2i] = [cell]
	sim.emit({"type": "area", "unit": caster, "cells": cells, "affects": "enemies"})
	_apply_effects(ctx, step, _targets_in(ctx, step, cells))
#endregion


#region cells
## Cells of one ability step. Only positions are read, so it also works on the
## preview board of the info panel.
static func step_cells(ctx: Dictionary, step: Dictionary) -> Array[Vector2i]:
	var caster: BattleUnit = ctx.caster
	var focus: BattleUnit = ctx.get("focus")
	var sim: BattleSim = ctx.sim
	var area: String = step.get("area", "single")
	var center: bool = step.get("center", false)
	var origin := caster.cell
	if step.get("origin", "caster") == "focus" and focus != null:
		origin = focus.cell
	var focus_cell := focus.cell if focus != null else BattleBoard.step(caster.cell, caster.facing)
	var out: Array[Vector2i] = []
	match area:
		"self":
			out = [caster.cell]
		"single":
			if focus != null:
				out = [focus.cell]
		"adjacent":
			out = BattleBoard.adjacent_cells(origin, center)
		"radius":
			out = BattleBoard.cells_in_radius(origin, int(_size(ctx, step)), center)
		"square":
			out = BattleBoard.cells_in_range(origin, int(_size(ctx, step)), center)
		"cone":
			out = BattleBoard.cells_in_front(caster.cell, focus_cell, int(_size(ctx, step)))
		"ray":
			var ray_length := int(_size(ctx, step)) if step.has("size") else 0
			out = BattleBoard.ray_cells(caster.cell, focus_cell, ray_length)
		"line":
			out = BattleBoard.line_cells(caster.cell, focus_cell)
			out.erase(caster.cell)
		"between":
			out = BattleBoard.cells_between(ctx.start_cell, focus_cell)
			out.erase(ctx.start_cell)
		"path":
			out = BattleBoard.cells_between(ctx.start_cell, ctx.get("dash_end", caster.cell))
			out.erase(ctx.start_cell)
		"board":
			out = BattleBoard.all_cells()
		"row":
			out = BattleBoard.cells_in_row(focus_cell.y)
		"closest":
			for e in _closest_enemies(sim, caster, int(_size(ctx, step))):
				out.append(e.cell)
		"backline":
			for e in _backline_enemies(sim, caster, int(_size(ctx, step))):
				out.append(e.cell)
		"random":
			for e in sim.enemies_of(caster):
				var around: Array[Vector2i] = [e.cell]
				if step.get("scatter", false):
					around = BattleBoard.adjacent_cells(e.cell, true)
				for c in around:
					if not out.has(c):
						out.append(c)
	return out


static func _targets_in(ctx: Dictionary, step: Dictionary, cells: Array[Vector2i]) -> Array[BattleUnit]:
	var sim: BattleSim = ctx.sim
	var caster: BattleUnit = ctx.caster
	var focus: BattleUnit = ctx.get("focus")
	var affects: String = step.get("affects", "enemies")
	var out: Array[BattleUnit] = []
	if step.get("area") == "self":
		out.append(caster)
		return out
	for c in cells:
		var u := sim.board.get_unit(c)
		if u != null and u.alive and _matches(affects, caster, u) and not out.has(u):
			out.append(u)
			if step.get("first_only", false) and affects == "enemies":
				break
	var guarantee: bool = step.get("guarantee_focus", false) or step.get("area") == "ray"
	if out.is_empty() and guarantee and focus != null and focus.alive and _matches(affects, caster, focus):
		out.append(focus)
	return out


static func _matches(affects: String, caster: BattleUnit, u: BattleUnit) -> bool:
	match affects:
		"allies": return u.team == caster.team
		"allies_others": return u.team == caster.team and u != caster
		"all": return true
	return u.team != caster.team


static func _closest_enemies(sim: BattleSim, caster: BattleUnit, count: int) -> Array[BattleUnit]:
	var enemies := sim.enemies_of(caster)
	enemies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return BattleBoard.distance_m(a.cell, caster.cell) < BattleBoard.distance_m(b.cell, caster.cell))
	return enemies.slice(0, count)


## Enemies farthest from the caster's side first (Sing, Icicle Missile).
static func _backline_enemies(sim: BattleSim, caster: BattleUnit, count: int) -> Array[BattleUnit]:
	var enemies := sim.enemies_of(caster)
	var blue := caster.team == BattleUnit.Team.BLUE
	enemies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return a.cell.y > b.cell.y if blue else a.cell.y < b.cell.y)
	return enemies.slice(0, count)
#endregion


#region dashes
static func _dash(ctx: Dictionary, kind: String) -> void:
	if kind == "":
		return
	var sim: BattleSim = ctx.sim
	var caster: BattleUnit = ctx.caster
	var focus: BattleUnit = ctx.focus
	var dest: Variant = null
	match kind:
		"farthest_spot":
			var spot := sim.farthest_spot(caster)
			if not spot.is_empty():
				dest = spot.cell
				ctx.focus = spot.target
				caster.target = spot.target
		"behind_focus":
			if focus != null:
				dest = sim.board.closest_free_cell(BattleBoard.step(focus.cell, BattleBoard.offset(caster.cell, focus.cell)))
		"toward_focus":
			if focus != null:
				dest = sim.board.closest_free_cell(BattleBoard.step(caster.cell, BattleBoard.orientation(caster.cell, focus.cell)))
		"fly_away":
			dest = fly_away_cell(sim, caster)
		"most_surrounded":
			dest = most_surrounded_cell(sim, 1 - caster.team)
		"far_row":
			var blue := caster.team == BattleUnit.Team.BLUE
			var row := (0 if caster.cell.y >= BattleBoard.HEIGHT - 2 else BattleBoard.HEIGHT - 1) if blue \
				else (BattleBoard.HEIGHT - 1 if caster.cell.y <= 1 else 0)
			dest = sim.board.closest_free_cell(Vector2i(caster.cell.x, row))
		"swap_farthest":
			var far := sim.farthest_enemy(caster)
			if far != null and not far.has_item("HEAVY_DUTY_BOOTS"):
				sim.swap_cells(caster.cell, far.cell)
			return
	if dest != null and dest != caster.cell:
		sim.move_unit(caster, dest, 250.0, "dash")


## board.getFlyAwayCell: a free cell beyond its own attack range from here with a targetable
## enemy in range from there, as few enemies as possible able to reach it, then as far as
## possible (Manhattan), at random among the ties. Without one: getSafePlaceAwayFrom its
## target within its range. Returns the cell or null (fly_away_spot: with the target).
static func fly_away_cell(sim: BattleSim, caster: BattleUnit) -> Variant:
	var spot := fly_away_spot(sim, caster)
	return spot.cell if not spot.is_empty() else null


## {cell, target} of getFlyAwayCell, {} when there is no enemy left.
static func fly_away_spot(sim: BattleSim, caster: BattleUnit) -> Dictionary:
	var enemies := sim.enemies_of(caster)
	if enemies.is_empty():
		return {}
	var candidates: Array = []
	for c in sim.board.free_cells():
		if BattleBoard.distance_c(c, caster.cell) <= caster.attack_range:
			continue
		var target: BattleUnit = null
		for e in enemies:
			if e.is_untargetable() or BattleBoard.distance_c(c, e.cell) > caster.attack_range:
				continue
			if target == null or e.hp_ratio() < target.hp_ratio():
				target = e
		if target == null:
			continue
		var threats := 0
		for e in enemies:
			if BattleBoard.distance_c(c, e.cell) <= e.attack_range:
				threats += 1
		candidates.append({"cell": c, "target": target, "threats": threats,
			"distance": BattleBoard.distance_m(c, caster.cell)})
	if candidates.is_empty():
		var origin := caster.target.cell if caster.target != null and caster.target.alive else caster.cell
		var safe: Variant = sim.safe_place_away(origin, -1, caster.attack_range)
		if safe == null:
			return {}
		var closest: BattleUnit = null
		for e in enemies:
			if closest == null or BattleBoard.distance_m(safe, e.cell) < BattleBoard.distance_m(safe, closest.cell):
				closest = e
		return {"cell": safe, "target": closest}
	var fewest: int = candidates.map(func(x: Dictionary) -> int: return x.threats).min()
	candidates = candidates.filter(func(x: Dictionary) -> bool: return x.threats == fewest)
	var farthest: int = candidates.map(func(x: Dictionary) -> int: return x.distance).max()
	candidates = candidates.filter(func(x: Dictionary) -> bool: return x.distance == farthest)
	var pick: Dictionary = candidates[sim.rng.randi() % candidates.size()]
	return {"cell": pick.cell, "target": pick.target}


## getMostSurroundedCoordinateAvailablePlace: the free cell with the most units of `team`
## around it (the first one of the board on a tie, even with none around).
static func most_surrounded_cell(sim: BattleSim, team: int) -> Variant:
	var best: Variant = null
	var best_count := -1
	for c in sim.board.free_cells():
		var count := 0
		for n in BattleBoard.adjacent_cells(c):
			var u := sim.board.get_unit(n)
			if u != null and u.alive and u.team == team:
				count += 1
		if count > best_count:
			best_count = count
			best = c
	return best
#endregion


#region effects
static func _apply_effects(ctx: Dictionary, step: Dictionary, targets: Array[BattleUnit]) -> void:
	var sim: BattleSim = ctx.sim
	var caster: BattleUnit = ctx.caster
	var effects: Array = step.get("effects", [])
	for t in targets:
		var dealt := 0.0
		for eff in effects:
			if eff.get("to", "") == "self":
				continue
			if eff.type == "damage":
				dealt += _damage(ctx, eff, t)
			elif eff.type == "drain":
				sim.heal(caster, dealt * float(eff.get("ratio", 1.0)))
			else:
				_apply_effect(ctx, eff, t)
	for eff in effects:
		if eff.get("to", "") == "self":
			_apply_effect(ctx, eff, caster)


static func _apply_effect(ctx: Dictionary, eff: Dictionary, t: BattleUnit) -> void:
	var sim: BattleSim = ctx.sim
	var caster: BattleUnit = ctx.caster
	if not t.alive:
		return
	if eff.has("if") and eff.type != "damage" and not _check(eff["if"], t):
		return
	var ap_factor := 1.0 if eff.get("no_ap", false) else 1.0 + caster.ap / 100.0
	match eff.type:
		"damage":
			_damage(ctx, eff, t)
		"heal":
			var amount := _value(eff, "values", caster.stars)
			if eff.has("stat"):
				amount *= caster.stat(eff.stat)
			if eff.has("target_stat"):
				amount *= t.stat(eff.target_stat)
			sim.heal(t, amount * ap_factor, caster)
		"shield":
			var amount := _value(eff, "values", caster.stars)
			if eff.has("stat"):
				amount *= caster.stat(eff.stat)
			sim.add_shield(t, roundf(amount * ap_factor), caster)
		"status":
			if sim.rng.randf() >= float(eff.get("chance", 1.0)):
				return
			var status: String = eff.get("status", "")
			var duration := float(eff.get("duration", 0))
			if eff.has("durations"):
				duration = _value(eff, "durations", caster.stars)
			if eff.has("options"):
				var option: Array = eff.options[sim.rng.randi() % eff.options.size()]
				status = option[0]
				duration = float(option[1])
			if eff.get("ap_scale", false):
				duration *= 1.0 + caster.ap / 100.0
			sim.add_status(t, status, duration, caster)
		"buff":
			var amount := _value(eff, "values", caster.stars)
			if eff.has("scale_stat"):
				amount *= caster.stat(eff.scale_stat)
			amount = adjust_buff(caster, t, amount * ap_factor)
			t.add_stat(eff.stat, roundf(amount * 10.0) / 10.0)
			sim.emit({"type": "buff", "unit": t, "stat": eff.stat, "amount": amount})
		"cleanse":
			t.cleanse()
		"knockback":
			if t.has_item("HEAVY_DUTY_BOOTS"):
				return
			var dir := BattleBoard.orientation(caster.cell, t.cell)
			if dir == Vector2i.ZERO:
				dir = caster.facing
			var distance := int(eff.get("distance", 1))
			if eff.has("distances"):
				distance = int(_value(eff, "distances", caster.stars))
			var dest := t.cell
			for _i in distance:
				if not sim.board.is_free(BattleBoard.step(dest, dir)):
					break
				dest = BattleBoard.step(dest, dir)
			if dest != t.cell:
				sim.move_unit(t, dest, 250.0, "knockback")


static func _damage(ctx: Dictionary, eff: Dictionary, t: BattleUnit) -> float:
	var sim: BattleSim = ctx.sim
	var caster: BattleUnit = ctx.caster
	if not t.alive:
		return 0.0
	var stars := caster.stars
	var amount := _value(eff, "values", stars)
	if eff.has("stat"):
		amount *= caster.stat(eff.stat)
	if eff.has("plus_stat"):
		amount += _value(eff, "plus_values", stars) * caster.stat(eff.plus_stat)
	if eff.has("per_fallen"):
		amount *= 1.0 + sim.fallen[caster.team] * _value(eff, "per_fallen", stars)
	if eff.has("target_hp_bonus"):
		amount += _value(eff, "target_hp_bonus", stars) * t.hp_ratio()
	if eff.has("if") and _check(eff["if"], t):
		amount *= float(eff.get("if_mult", 1.0))
	if eff.has("falloff"):
		amount *= maxf(0.0, 1.0 - float(eff.falloff) * BattleBoard.distance_c(caster.cell, t.cell))
	if eff.get("stored_power", false):
		amount *= 1.0 + _stored_power(caster)
	if not eff.get("no_ap", false):
		amount *= 1.0 + caster.ap / 100.0
	if caster.effects.get("double_damage", false): # Helping Hand
		amount *= 2.0
		caster.effects.erase("double_damage")
	amount *= sim.strange_steam_factor(caster, t)
	var kind := BattleUnit.DamageKind.SPECIAL
	match eff.get("kind", "special"):
		"physical": kind = BattleUnit.DamageKind.PHYSICAL
		"true": kind = BattleUnit.DamageKind.TRUE
	if eff.has("execute_below") and t.hp_ratio() < float(eff.execute_below):
		amount = 9999.0
		kind = BattleUnit.DamageKind.TRUE
	var crit: bool = eff.get("always_crit", false)
	if not crit and eff.has("crit_bonus"):
		crit = sim.chance((caster.crit_chance + _value(eff, "crit_bonus", stars)) / 100.0, caster)
	elif not crit and caster.effects.get("ability_crit", false):
		crit = sim.chance(caster.crit_chance / 100.0, caster) # Reaper Cloth
	if crit:
		amount *= sim.crit_multiplier(caster, t, kind)
	if eff.has("execute_chance"):
		var bonus := maxf(0.0, (caster.atk - t.atk) / maxf(t.atk, 1.0))
		if sim.rng.randf() < float(eff.execute_chance) * (1.0 + bonus):
			amount = 9999.0
	var result := sim.deal_damage(t, amount, kind, caster, crit)
	if result.death and eff.has("on_kill_pp"):
		caster.add_pp(caster.max_pp * float(eff.on_kill_pp), true)
	if eff.has("splash"):
		var splash_cells := BattleBoard.adjacent_cells(t.cell)
		sim.emit({"type": "area", "unit": caster, "cells": splash_cells, "affects": "enemies"})
		for c in splash_cells:
			var e := sim.board.get_unit(c)
			if e != null and e.team != caster.team:
				sim.deal_damage(e, amount * float(eff.splash), kind, caster)
	return result.taken


## Stored Power: every stat boost of the caster (ATK, DEF, SPE_DEF, SPEED over its
## base, AP over 100) adds to the damage multiplier.
static func _stored_power(u: BattleUnit) -> float:
	var base_speed := float(u.data.get("speed", 50))
	return maxf(0.0, u.speed / maxf(base_speed, 1.0) - 1.0) \
		+ maxf(0.0, u.atk / maxf(u.base_atk, 1.0) - 1.0) \
		+ maxf(0.0, u.def / maxf(u.base_def, 1.0) - 1.0) \
		+ maxf(0.0, u.spe_def / maxf(u.base_spe_def, 1.0) - 1.0) \
		+ maxf(0.0, u.ap / 100.0 - 1.0)


static func _check(cond: Dictionary, t: BattleUnit) -> bool:
	if cond.has("target_type") and not t.types.has(cond.target_type):
		return false
	if cond.has("target_types_any"):
		var any := false
		for type in cond.target_types_any:
			any = any or t.types.has(type)
		if not any:
			return false
	if cond.has("target_status") and not t.has_status(cond.target_status):
		return false
	if cond.get("target_negative", false) and not t.has_negative_status():
		return false
	if cond.get("target_shield", false) and t.shield <= 0.0:
		return false
	return true
#endregion


## Twist Band: enemy debuffs become buffs; Big Eater Belt: buffs x1.25 (rounded down).
static func adjust_buff(source: BattleUnit, t: BattleUnit, amount: float) -> float:
	var enemy := source != null and source.team != t.team
	if amount < 0.0 and t.has_item("TWIST_BAND") and (source == null or enemy):
		amount = -amount
	if t.has_item("BIG_EATER_BELT") and (amount > 0.0 or not enemy):
		amount = floorf(amount * 1.25)
	return amount


#region values
static func _value(dict: Dictionary, key: String, stars: int) -> float:
	var v = dict.get(key, 0)
	if v is Array:
		return float(v[clampi(stars - 1, 0, v.size() - 1)]) if not v.is_empty() else 0.0
	return float(v)


static func _size(ctx: Dictionary, step: Dictionary) -> float:
	var caster: BattleUnit = ctx.caster
	var s = step.get("size", 1)
	if s is String:
		match s:
			"range": return caster.attack_range
			"range+1": return caster.attack_range + 1
		return 1
	if s is Array:
		return _value(step, "size", caster.stars)
	return float(s)


static func _repeat(ctx: Dictionary, step: Dictionary) -> int:
	var caster: BattleUnit = ctx.caster
	var sim: BattleSim = ctx.sim
	var r = step.get("repeat", 1)
	if r is String:
		match r:
			"fallen+1": return sim.fallen[caster.team] + 1
			"speed3": return roundi(3.0 * (1.0 + 0.01 * caster.speed))
		return 1
	return maxi(int(r), 1)
#endregion


#region preview (unit info panel, docs)
## Shows where an ability lands on a typical board: the caster on its front row
## facing a standard enemy formation. Uses the real step_cells().
## Returns {caster_start, caster, focus, allies, enemies, steps: [{cells, affects, delay}]}.
static func preview(pkm: String) -> Dictionary:
	var sim := BattleSim.new()
	sim.rng.seed = 7
	var caster := BattleUnit.create(pkm, BattleUnit.Team.BLUE)
	# melee in the front row, ranged one row back: the front enemy is in range
	sim.add_unit(caster, Vector2i(3, 3 if caster.attack_range <= 1 else 2))
	var allies: Array[Vector2i] = [Vector2i(1, 2), Vector2i(5, 1)]
	for c in allies:
		sim.add_unit(BattleUnit.create(pkm, BattleUnit.Team.BLUE), c)
	var enemies: Array[Vector2i] = [Vector2i(3, 4), Vector2i(5, 4), Vector2i(2, 5), Vector2i(6, 5), Vector2i(1, 6), Vector2i(4, 6)]
	for c in enemies:
		sim.add_unit(BattleUnit.create(pkm, BattleUnit.Team.RED), c)
	# a target in attack range if any, like during the fight
	var target: BattleUnit = null
	for e in sim.enemies_of(caster):
		if BattleBoard.distance_c(e.cell, caster.cell) <= caster.attack_range:
			if target == null or BattleBoard.distance_m(e.cell, caster.cell) < BattleBoard.distance_m(target.cell, caster.cell):
				target = e
	var ab := caster.ability()
	var ctx := {
		"sim": sim, "caster": caster, "ability": ab,
		"focus": resolve_focus(sim, caster, target, ab.get("focus", "target")),
		"start_cell": caster.cell,
	}
	_dash(ctx, ab.get("dash", ""))
	ctx.dash_end = caster.cell
	sim.drain_events()
	var steps: Array = []
	var ability_steps: Array = ab.get("steps", [])
	for step in ability_steps:
		var cells := step_cells(ctx, step)
		if step.get("area") == "self" or step.get("effects", []).all(func(e: Dictionary) -> bool: return e.get("to", "") == "self"):
			cells = [caster.cell]
		steps.append({"cells": cells, "affects": step.get("affects", "enemies") if step.get("area") != "self" else "self",
			"delay": float(step.get("delay", 0))})
	var focus: BattleUnit = ctx.focus
	var result := {
		"caster_start": ctx.start_cell, "caster": caster.cell,
		"focus": focus.cell if focus != null else null,
		"allies": allies, "enemies": enemies, "steps": steps, "cycle": ab.get("cycle", false),
	}
	ctx.clear()
	sim.dispose()
	return result


## Plain-language area of each step, e.g. "the target and the 6 cells around".
static func describe_areas(ability: Dictionary, attack_range: int, stars: int) -> String:
	var parts: Array[String] = []
	for step in ability.get("steps", []):
		var area: String = step.get("area", "single")
		var who := "the target" if step.get("origin", "caster") == "focus" else "itself"
		var size = step.get("size", 1)
		var n := 1
		if size is Array:
			n = int(size[clampi(stars - 1, 0, size.size() - 1)])
		elif size is String:
			n = attack_range + (1 if size == "range+1" else 0)
		else:
			n = int(size)
		var text := ""
		match area:
			"adjacent":
				if step.get("center", false):
					var subject := L.t(who)
					text = L.t(AREA_LABELS.adjacent_center) % (subject.left(1).to_upper() + subject.substr(1))
				else:
					text = L.t(AREA_LABELS.adjacent) % L.t(who)
			"radius":
				text = L.t(AREA_LABELS.radius) % [n, L.t(who)]
			"cone", "closest", "backline", "random":
				text = L.t(AREA_LABELS[area]) % n
			"ray":
				text = (L.t(AREA_LABELS.ray) % n) if n > 0 else L.t(AREA_LABELS.ray_edge)
			"between":
				text = L.t(AREA_LABELS.between) % L.t("the farthest enemy" if ability.get("focus") == "farthest" else "the target")
			_:
				text = L.t(AREA_LABELS.get(area, area))
		if step.get("delay", 0) >= 500:
			text += " " + L.t("(after %.1fs)") % (float(step.delay) / 1000.0)
		if not parts.has(text):
			parts.append(text)
	return L.t(", then ").join(parts) if not ability.get("cycle", false) else " / ".join(parts)
#endregion
