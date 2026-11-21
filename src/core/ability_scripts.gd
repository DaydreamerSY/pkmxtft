class_name AbilityScripts
extends RefCounted

## Abilities written as code (data/abilities.json "script": "<name>" -> <name>(ctx)),
## for the web strategies (app/core/abilities/<name>.ts) that do not fit the data
## steps of AbilityRunner. ctx = {sim, caster, ability, focus, start_cell, dash_end}.
## Helpers mirror the web API: hit() = handleSpecialDamage (AP boost, ability crit).


## Runs the script of `ability` if it has one; false if none.
static func run(ctx: Dictionary) -> bool:
	var name := String(ctx.ability.get("script", ""))
	if name == "":
		return false
	var script: GDScript = load("res://src/core/ability_scripts.gd")
	if not script.has_method(name):
		push_warning("AbilityScripts: no script " + name)
		return true
	script.call(name, ctx)
	return true


#region helpers
## handleSpecialDamage: `amount` x (1 + AP/100) unless `ap` is false, ability crit
## (Reaper Cloth...) or `crit`. Returns {taken, death}.
static func hit(ctx: Dictionary, t: BattleUnit, amount: float, kind := BattleUnit.DamageKind.SPECIAL,
		ap := true, crit := false) -> Dictionary:
	var sim: BattleSim = ctx.sim
	var caster: BattleUnit = ctx.caster
	if t == null or not t.alive:
		return {"taken": 0.0, "death": false}
	if ap:
		amount *= 1.0 + caster.ap / 100.0
	if caster.effects.get("double_damage", false): # Helping Hand
		amount *= 2.0
		caster.effects.erase("double_damage")
	amount *= sim.strange_steam_factor(caster, t)
	if not crit and caster.effects.get("ability_crit", false):
		crit = sim.chance(caster.crit_chance / 100.0, caster)
	if crit:
		amount *= sim.crit_multiplier(caster, t, kind)
	return sim.deal_damage(t, roundf(amount), kind, caster, crit)


## Value by stars ([1★, 2★, 3★, 4]).
static func by_stars(caster: BattleUnit, values: Array) -> float:
	return float(values[clampi(caster.stars - 1, 0, values.size() - 1)])


## Status with the ability AP boost on its duration (web apBoost = true).
static func status(ctx: Dictionary, t: BattleUnit, name: String, ms: float, ap_boost := false) -> void:
	var caster: BattleUnit = ctx.caster
	if ap_boost:
		ms *= 1.0 + caster.ap / 100.0
	ctx.sim.add_status(t, name, ms, caster)


## Shows cells as hit (board flash / VFX "cells" specs).
static func show(ctx: Dictionary, cells: Array, affects := "enemies") -> void:
	var list: Array[Vector2i] = []
	list.assign(cells)
	ctx.sim.emit({"type": "area", "unit": ctx.caster, "cells": list, "affects": affects})


static func pick_random(sim: BattleSim, list: Array, n: int) -> Array:
	var copy := list.duplicate()
	var out := []
	while not copy.is_empty() and out.size() < n:
		out.append(copy.pop_at(sim.rng.randi() % copy.size()))
	return out
#endregion


#region abilities
## attract.ts: charms 1 / 2 / 3 / 5 random enemies for 1 s (AP boosted).
static func attract(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var caster: BattleUnit = ctx.caster
	var targets := pick_random(sim, sim.enemies_of(caster), int(by_stars(caster, [1, 2, 3, 5])))
	show(ctx, targets.map(func(t: BattleUnit) -> Vector2i: return t.cell))
	for t in targets:
		status(ctx, t, "charm", 1000.0, true)


## octazooka.ts: 300% ATK as SPECIAL on the target (600% at 4★) and BLINDED 4 s.
static func octazooka(ctx: Dictionary) -> void:
	var caster: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, ceilf(caster.atk * by_stars(caster, [3, 3, 3, 6])))
	status(ctx, t, "blinded", 4000.0)


## schooling.ts: 15% (30% at 4★) of its max HP as SPECIAL to the adjacent enemies;
## the Wishiwashi of the player's bench join the school (+50 max HP for good each).
static func schooling(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var caster: BattleUnit = ctx.caster
	var damage := by_stars(caster, [0.15, 0.15, 0.15, 0.3]) * caster.max_hp
	var cells := BattleBoard.adjacent_cells(caster.cell)
	show(ctx, cells)
	for c in cells:
		var e := sim.board.get_unit(c)
		if e != null and e.alive and e.team != caster.team:
			hit(ctx, e, damage)
	if caster.owned != null and sim.player_bench_absorb.is_valid():
		var absorbed: int = sim.player_bench_absorb.call("WISHIWASHI")
		if absorbed > 0:
			caster.add_stat("maxHP", 50.0 * absorbed)
			caster.owned.mods.maxHP = float(caster.owned.mods.get("maxHP", 0.0)) + 50.0 * absorbed


## rage.ts: RAGE 3 s, +10% (20% at 4★) BASE ATK per 10% of max HP missing (AP boosted).
static func rage(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	status(ctx, c, "enraged", 3000.0)
	var missing := c.max_hp - c.hp
	var boost := c.base_atk * by_stars(c, [10, 10, 10, 20]) / 100.0 * floorf(missing / (c.max_hp / 10.0))
	c.add_stat("atk", boost * (1.0 + c.ap / 100.0))
	c.cooldown = 1000.0


## return.ts: 20 / 40 / 80 SPECIAL; +2 AP for good.
static func return_(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	if ctx.focus != null:
		show(ctx, [ctx.focus.cell])
		hit(ctx, ctx.focus, by_stars(c, [20, 40, 80, 160]))
	c.add_stat("ap", 2.0)
	if c.owned != null:
		c.owned.mods.ap = float(c.owned.mods.get("ap", 0.0)) + 2.0


## counter.ts: its missing HP x 0.5 (x1 at 4★) as SPECIAL to the adjacent enemies.
static func counter(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var damage := maxf(1.0, roundf((c.max_hp - c.hp) * by_stars(c, [0.5, 0.5, 0.5, 1.0])))
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for cell in cells:
		var e := sim.board.get_unit(cell)
		if e != null and e.alive and e.team != c.team:
			hit(ctx, e, damage)


## disable.ts: the target and the 6 cells around: SILENCE 2 / 3 / 4 s and 12 / 25 / 50 SPECIAL.
static func disable(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if ctx.focus == null:
		return
	var cells := BattleBoard.adjacent_cells(ctx.focus.cell, true)
	show(ctx, cells)
	for cell in cells:
		var e := sim.board.get_unit(cell)
		if e != null and e.alive and e.team != c.team:
			status(ctx, e, "silence", by_stars(c, [2000, 3000, 4000, 8000]))
			hit(ctx, e, by_stars(c, [12, 25, 50, 100]))


## bulk-up.ts: +50% (100% at 4★) BASE ATK and BASE DEF (AP boosted).
static func bulk_up(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var k := by_stars(c, [0.5, 0.5, 0.5, 1.0]) * (1.0 + c.ap / 100.0)
	c.add_stat("atk", ceilf(k * c.base_atk))
	c.add_stat("def", ceilf(k * c.base_def))
	c.cooldown = 300.0


## charge.ts: from now on its attacks add bonus SPECIAL (BattleSim attack_hit, effect "charge").
static func charge(ctx: Dictionary) -> void:
	ctx.caster.effects.charge = true


## payday.ts: 15 / 30 / 60 x (2 + AP/100) SPECIAL (no other AP boost); a kill gives gold = stars.
static func payday(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var r := hit(ctx, t, floorf(by_stars(c, [15, 30, 60, 120]) * (2.0 + c.ap / 100.0)), BattleUnit.DamageKind.SPECIAL, false)
	if r.death and c.team == BattleUnit.Team.BLUE and c.owned != null:
		sim.rewards.gold += c.stars


## hyper-beam.ts: charges 1 s, then a beam through the target to the board edge (65 / 130 /
## 250 SPECIAL) and FATIGUE 5 s on itself.
static func hyper_beam(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	c.cooldown = 1000.0
	var target_cell := t.cell
	sim.schedule(1000.0, c, func() -> void:
		var cells := BattleBoard.line_cells(c.cell, target_cell)
		cells.erase(c.cell)
		show(ctx, cells)
		for cell in cells:
			var e := sim.board.get_unit(cell)
			if e != null and e.alive and e.team != c.team:
				hit(ctx, e, by_stars(c, [65, 130, 250, 500]))
		status(ctx, c, "fatigue", 5000.0))


## focus-punch.ts: after 0.9 s, ejects the target from the board (sure KO) if nothing stands
## behind it on its line, else 500% ATK (1000% at 4★) as SPECIAL and pushes it as far as
## possible, the caster taking its place. A target already KO: PP refilled.
static func focus_punch(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	c.cooldown = 1000.0
	sim.schedule(900.0, c, func() -> void:
		if not t.alive:
			c.pp = c.max_pp
			return
		var dir := BattleBoard.orientation(c.cell, t.cell)
		if dir == Vector2i.ZERO:
			dir = c.facing
		var farthest: Variant = null
		var blocked := false
		var cell := BattleBoard.step(c.cell, dir)
		while BattleBoard.in_bounds(cell):
			var u := sim.board.get_unit(cell)
			if u != null and u != t:
				blocked = true
			elif u == null:
				farthest = cell
			cell = BattleBoard.step(cell, dir)
		show(ctx, [t.cell])
		var movable: bool = farthest != null and not t.has_item("HEAVY_DUTY_BOOTS")
		if movable and not blocked and not t.effects.get("resurrection", false) and not t.has_status("magic_bounce") \
				and not t.has_status("protect"):
			t.cooldown = 9999.0
			var r := hit(ctx, t, 9999.0, BattleUnit.DamageKind.TRUE, false)
			if not r.death and t.alive:
				sim.deal_damage(t, t.hp + t.shield + 1.0, BattleUnit.DamageKind.TRUE, c)
			return
		hit(ctx, t, by_stars(c, [5, 5, 5, 10]) * c.atk)
		if movable and t.alive:
			var from := t.cell
			sim.move_unit(t, farthest, 250.0, "knockback")
			sim.move_unit(c, from, 250.0, "dash"))


## substitute.ts: jumps to the closest free cell and leaves a Substitute doll where it was,
## with 25% (50% at 4★) of its max HP more (AP boosted); its attackers switch to the doll.
static func substitute(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if not GameData.pokemon.has("SUBSTITUTE"):
		return
	var dest: Variant = sim.closest_free_cell_near(c.cell, c.team)
	if dest == null:
		return
	var old := c.cell
	sim.move_unit(c, dest, 250.0, "dash")
	var doll := BattleUnit.create("SUBSTITUTE", c.team)
	doll.add_stat("maxHP", roundf(by_stars(c, [0.25, 0.25, 0.25, 0.5]) * c.max_hp * (1.0 + c.ap / 100.0)))
	doll.hp = doll.max_hp
	sim.add_unit(doll, old)
	for e in sim.enemies_of(c):
		if e.target == c:
			e.target = doll


## Skill Swap (abilities.ts SkillSwapStrategy): takes the ability of the target for the rest
## of the fight and casts it at once.
static func skill_swap(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null or t.ability_id == "SKILL_SWAP" or GameData.get_ability(t.ability_id).get("inimitable", false):
		return
	c.ability_id = t.ability_id
	c.max_pp = t.max_pp
	AbilityRunner.cast(sim, c, t)


## surf.ts: rides to the free cell next to the farthest enemy; enemies on the way take
## 20 / 40 / 80 SPECIAL and are pushed one cell sideways.
static func surf(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var spot := sim.farthest_spot(c)
	if spot.is_empty():
		return
	var damage := by_stars(c, [20, 40, 80, 160])
	var cells := BattleBoard.cells_between(c.cell, spot.cell)
	show(ctx, cells)
	var hit_any := false
	for cell in cells:
		var e := sim.board.get_unit(cell)
		if e == null or not e.alive or e.team == c.team:
			continue
		hit_any = true
		hit(ctx, e, damage)
		if e.alive and not e.has_item("HEAVY_DUTY_BOOTS"):
			var side := Vector2i(1 if e.cell.x >= c.cell.x else -1, 0)
			if sim.board.is_free(e.cell + side):
				sim.move_unit(e, e.cell + side, 250.0, "knockback")
				e.cooldown = 500.0
	sim.move_unit(c, spot.cell, 300.0, "dash")
	if not hit_any and spot.target.alive:
		hit(ctx, spot.target, damage)
#endregion


#region helpers 2

## effectInOrientation: cells from the caster going `dir` (a BattleBoard.DIRECTIONS one) to the board edge.
static func ray_from(from: Vector2i, dir: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if dir == Vector2i.ZERO:
		return out
	var c := BattleBoard.step(from, dir)
	while BattleBoard.in_bounds(c):
		out.append(c)
		c = BattleBoard.step(c, dir)
	return out


## getKnockBackPlace: a free cell next to `t` going `dir` (or 60° aside; web: 45°); moves it there.
static func knock_back(sim: BattleSim, t: BattleUnit, dir: Vector2i) -> void:
	if t == null or not t.alive or t.has_item("HEAVY_DUTY_BOOTS") or dir == Vector2i.ZERO:
		return
	for d in BattleBoard.fan(dir):
		var cell := BattleBoard.step(t.cell, d)
		if sim.board.is_free(cell):
			sim.move_unit(t, cell, 250.0, "knockback")
			t.cooldown = 500.0
			return


## Enemies of the caster on `cells`.
static func enemies_on(ctx: Dictionary, cells: Array) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for cell in cells:
		var e: BattleUnit = ctx.sim.board.get_unit(cell)
		if e != null and e.alive and e.team != ctx.caster.team and not out.has(e):
			out.append(e)
	return out
#endregion


#region abilities (hatch)

## dragon-darts.ts: 3 x 10 / 20 / 40 SPECIAL on the target; +40 PP (80 at 4★) if it faints.
static func dragon_darts(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	for _i in 3:
		hit(ctx, t, by_stars(c, [10, 20, 40, 80]))
	if not t.alive:
		c.add_pp(by_stars(c, [40, 40, 40, 80]))


## fake-tears.ts: every enemy: ARMOR_BREAK 3 s (6 s at 4★) and 5 / 10 / 15 SPECIAL.
static func fake_tears(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var foes: Array[BattleUnit] = ctx.sim.enemies_of(c)
	show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	for e in foes:
		status(ctx, e, "armor_reduction", by_stars(c, [3000, 3000, 3000, 6000]))
		hit(ctx, e, by_stars(c, [5, 10, 15, 30]))


## foul-play.ts: the ATK of the target x 2 / 4 / 6 as SPECIAL.
static func foul_play(ctx: Dictionary) -> void:
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(ctx.caster, [2, 4, 6, 12]) * t.atk)


## heat-crash.ts: 40 / 60 / 80 SPECIAL + 2 x (its ATK - target ATK), knocks the target back.
static func heat_crash(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [40, 60, 80, 160]) + 2.0 * (c.atk - t.atk))
	knock_back(ctx.sim, t, BattleBoard.orientation(c.cell, t.cell))


## outrage.ts: CONFUSION 2 s on itself; 300% ATK (600% at 4★) as SPECIAL to the target and
## the allies of the target next to the caster.
static func outrage(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	status(ctx, c, "confusion", 2000.0)
	if t == null:
		return
	var damage := roundf(c.atk * by_stars(c, [3, 3, 3, 6]))
	var victims: Array[BattleUnit] = [t]
	for cell in BattleBoard.adjacent_cells(c.cell):
		var e := sim.board.get_unit(cell)
		if e != null and e.alive and e.team == t.team and e != t:
			victims.append(e)
	show(ctx, victims.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	for e in victims:
		hit(ctx, e, damage)


## powder.ts: toward the fastest enemy in range: enemies on the way take 10 / 20 / 30
## SPECIAL and lose 10 / 20 / 30 SPEED (AP boosted) for 5 s.
static func powder(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var fastest: BattleUnit = ctx.focus
	for e in sim.enemies_of(c):
		if BattleBoard.distance_c(e.cell, c.cell) <= c.attack_range and (fastest == null or e.speed > fastest.speed):
			fastest = e
	if fastest == null:
		return
	var cells := BattleBoard.cells_between(c.cell, fastest.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [10, 20, 30, 50]))
		var nerf := minf(e.speed, by_stars(c, [10, 20, 30, 50]) * (1.0 + c.ap / 100.0))
		e.add_stat("speed", -nerf)
		sim.schedule(5000.0, e, func() -> void: e.add_stat("speed", nerf))


## pyro-ball.ts: toward the farthest enemy: enemies on the way BURN 2 s and 10 / 20 / 40 SPECIAL.
static func pyro_ball(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var far: BattleUnit = sim.farthest_enemy(c)
	if far == null:
		far = ctx.focus
	if far == null:
		return
	var cells := BattleBoard.cells_between(c.cell, far.cell)
	show(ctx, cells)
	var victims := enemies_on(ctx, cells)
	if victims.is_empty() and ctx.focus != null:
		victims.append(ctx.focus)
	for e in victims:
		status(ctx, e, "burn", 2000.0)
		hit(ctx, e, by_stars(c, [10, 20, 40, 80]))


## sludge-wave.ts: the target and the 6 cells around: POISON 2 / 3 / 4 s (AP boosted) and 10 / 20 / 40 SPECIAL.
static func sludge_wave(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.adjacent_cells(t.cell, true)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		status(ctx, e, "poison", by_stars(c, [2000, 3000, 4000, 8000]), true)
		hit(ctx, e, by_stars(c, [10, 20, 40, 80]))


## sparkling-aria.ts: 15 / 25 / 50 SPECIAL to the target and the enemies around it; the
## burning allies around it are cured (and immune 3 s).
static func sparkling_aria(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var damage := by_stars(c, [15, 25, 50, 100])
	show(ctx, BattleBoard.adjacent_cells(t.cell, true))
	hit(ctx, t, damage)
	for cell in BattleBoard.adjacent_cells(t.cell):
		var u := sim.board.get_unit(cell)
		if u == null or not u.alive:
			continue
		if u.team != c.team:
			hit(ctx, u, damage)
		elif u.has_status("burn"):
			u.statuses.erase("burn")
			u.effects.immune_burn = true
			sim.schedule(3000.0, u, func() -> void: u.effects.erase("immune_burn"))


## spirit-shackle.ts: a line through the target to the board edge: 25 / 50 / 75 SPECIAL and WOUND 4 s.
static func spirit_shackle(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.line_cells(c.cell, t.cell)
	cells.erase(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [25, 50, 75, 150]))
		status(ctx, e, "wound", 4000.0)


## water-shuriken.ts: 3 shurikens toward the target and 60° on each side (web: 45°), to the board
## edge: 20 / 40 / 60 SPECIAL to every enemy on them.
static func water_shuriken(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var dir := BattleBoard.orientation(c.cell, t.cell)
	if dir == Vector2i.ZERO:
		dir = BattleBoard.DIRECTIONS[0]
	var cells: Array[Vector2i] = []
	for d in BattleBoard.fan(dir):
		cells.append_array(ray_from(c.cell, d))
	show(ctx, cells)
	for cell in cells:
		var e: BattleUnit = ctx.sim.board.get_unit(cell)
		if e != null and e.alive and e.team != c.team:
			hit(ctx, e, by_stars(c, [20, 40, 60, 120]))


## zap-cannon.ts: ARMOR_BREAK and PARALYSIS 1 / 2 / 4 s, then 25 / 50 / 100 SPECIAL.
static func zap_cannon(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var ms := by_stars(c, [1000, 2000, 4000, 8000])
	status(ctx, t, "armor_reduction", ms)
	status(ctx, t, "paralysis", ms)
	hit(ctx, t, by_stars(c, [25, 50, 100, 200]))
#endregion


#region abilities (flower pots)
## acrobatics.ts: 20 / 40 / 80 SPECIAL, then leaps to a free cell in range of the target,
## as close as possible to 4 - (items held) cells away.
static func acrobatics(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [20, 40, 80, 160]))
	var travel := 4 - c.items.size()
	var best: Variant = null
	var best_gap := 99
	for cell in BattleBoard.cells_in_radius(t.cell, c.attack_range, false):
		if not sim.board.is_free(cell):
			continue
		var gap := absi(travel - BattleBoard.distance_m(cell, c.cell))
		if gap < best_gap:
			best_gap = gap
			best = cell
	if best != null:
		sim.move_unit(c, best, 250.0, "dash")


## ingrain.ts: itself and the 6 cells around: allies heal 15 / 30 / 60 (AP), enemies LOCKED
## 4 s and 15 / 30 / 60 SPECIAL.
static func ingrain(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var amount := by_stars(c, [15, 30, 60, 120])
	var cells := BattleBoard.adjacent_cells(c.cell, true)
	show(ctx, cells, "all")
	for cell in cells:
		var u := sim.board.get_unit(cell)
		if u == null or not u.alive:
			continue
		if u.team == c.team:
			sim.heal(u, amount * (1.0 + c.ap / 100.0), c)
		else:
			status(ctx, u, "locked", 4000.0)
			hit(ctx, u, amount)


## sweet-scent.ts: enemies within 3 cells: 30% CHARM 1 s, lose 4 / 6 / 8 SPE_DEF and 10 / 12 / 15
## SPEED (AP boosted) and all their dodge.
static func sweet_scent(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.cells_in_radius(c.cell, 3, false)
	show(ctx, cells)
	var k := 1.0 + c.ap / 100.0
	for e in enemies_on(ctx, cells):
		if sim.chance(0.3, c):
			status(ctx, e, "charm", 1000.0)
		e.add_stat("speDef", AbilityRunner.adjust_buff(c, e, -by_stars(c, [4, 6, 8, 10]) * k))
		e.add_stat("speed", AbilityRunner.adjust_buff(c, e, -by_stars(c, [10, 12, 15, 20]) * k))
		e.add_stat("dodge", -e.dodge)


## stun-spore.ts: the target and the 6 cells around: PARALYSIS 5 s and 15 / 30 / 60 SPECIAL.
static func stun_spore(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.adjacent_cells(t.cell, true)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		status(ctx, e, "paralysis", 5000.0)
		hit(ctx, e, by_stars(c, [15, 30, 60, 120]))


## petal-blizzard.ts: 10 / 20 / 30 SPECIAL to the adjacent enemies, +10 AP.
static func petal_blizzard(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [10, 20, 30, 50]))
	c.add_stat("ap", 10.0)
#endregion


#region Unowns: Hidden Power (hidden-power.ts)
## Every Hidden Power: the Unown is used up (gone from the player's team, +1 reminiscence
## for the next shop) and faints, then its letter does something.
static func _hidden_power(ctx: Dictionary) -> BattleUnit:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if c.owned != null and sim.player != null and not c.is_spawn:
		var p = sim.player
		p.unown_reminiscences += 1
		var loc: Dictionary = p.find(c.owned)
		if not loc.is_empty():
			p._set_at(loc, null)
	sim.deal_damage(c, c.hp + c.shield + 1.0, BattleUnit.DamageKind.TRUE, null)
	return c


## Adds a Pokémon to the fight at `cell` (or the closest free cell to it).
static func _summon(sim: BattleSim, pkm: String, team: int, cell: Vector2i) -> BattleUnit:
	if not GameData.pokemon.has(pkm):
		return null
	var at: Variant = cell if sim.board.is_free(cell) else sim.closest_free_cell_near(cell, team)
	if at == null:
		return null
	var u := BattleUnit.create(pkm, team)
	sim.add_unit(u, at)
	return u


static func _corners() -> Array[Vector2i]:
	return [Vector2i(0, 0), Vector2i(BattleBoard.WIDTH - 1, 0), Vector2i(0, BattleBoard.HEIGHT - 1),
		Vector2i(BattleBoard.WIDTH - 1, BattleBoard.HEIGHT - 1)]


static func _team(sim: BattleSim, c: BattleUnit, allies: bool) -> Array[BattleUnit]:
	return sim.alive_units(c.team) if allies else sim.enemies_of(c)


## A: 4 Abra, one at each corner.
static func hidden_power_a(ctx: Dictionary) -> void:
	var c := _hidden_power(ctx)
	for corner in _corners():
		_summon(ctx.sim, "ABRA", c.team, corner)


## B: every enemy burns 30 s.
static func hidden_power_b(ctx: Dictionary) -> void:
	var c := _hidden_power(ctx)
	for e in _team(ctx.sim, c, false):
		status(ctx, e, "burn", 30000.0)


## C: every ally holds an Amulet Coin.
static func hidden_power_c(ctx: Dictionary) -> void:
	var c := _hidden_power(ctx)
	for a in _team(ctx.sim, c, true):
		if a.items.size() < BattleUnit.MAX_ITEMS:
			a.equip(["AMULET_COIN"])


## D: a copy of the strongest Pokémon of the team.
static func hidden_power_d(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c := _hidden_power(ctx)
	var best: BattleUnit = null
	for a in sim.alive_units(c.team):
		if best == null or a.unit_score() > best.unit_score():
			best = a
	if best != null:
		_summon(sim, best.pkm, c.team, c.cell)


## E: an egg on the bench, about to hatch.
static func hidden_power_e(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	_hidden_power(ctx)
	var p = sim.player
	if p == null or p.first_free_bench_slot() < 0:
		return
	var egg: PlayerState.OwnedUnit = SynergyItems.make_egg(p)
	egg.hatch_stacks = int(GameData.config.get("eggHatch", 5)) - 1
	p.bench[p.first_free_bench_slot()] = egg


## F: 2 fishes (Super Rod) on the bench.
static func hidden_power_f(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	_hidden_power(ctx)
	var p = sim.player
	if p == null:
		return
	for _i in 2:
		var slot: int = p.first_free_bench_slot()
		var fish: String = SynergyItems.pick_fish(p, "SUPER_ROD")
		if slot >= 0 and GameData.pokemon.has(fish):
			p.bench[slot] = PlayerState.OwnedUnit.new(fish)


## G: +5 gold.
static func hidden_power_g(ctx: Dictionary) -> void:
	_hidden_power(ctx)
	if ctx.sim.player != null:
		ctx.sim.rewards.gold += 5


## H: every ally healed to full.
static func hidden_power_h(ctx: Dictionary) -> void:
	var c := _hidden_power(ctx)
	for a in _team(ctx.sim, c, true):
		ctx.sim.heal(a, a.max_hp - a.hp, c)


## I: a random component.
static func hidden_power_i(ctx: Dictionary) -> void:
	_hidden_power(ctx)
	if ctx.sim.player != null:
		var parts := EndlessWaves.item_pool("component")
		ctx.sim.rewards.items.append(parts[ctx.sim.rng.randi() % parts.size()])


## J: 2 Sharpedo holding a Razor Claw.
static func hidden_power_j(ctx: Dictionary) -> void:
	var c := _hidden_power(ctx)
	for _i in 2:
		var shark := _summon(ctx.sim, "SHARPEDO", c.team, c.cell)
		if shark != null:
			shark.equip(["RAZOR_CLAW"])


## K: Hitmonlee holding a Red Orb, about to cast.
static func hidden_power_k(ctx: Dictionary) -> void:
	var c := _hidden_power(ctx)
	var lee := _summon(ctx.sim, "HITMONLEE", c.team, c.cell)
	if lee != null:
		lee.equip(["RED_ORB"])
		lee.pp = lee.max_pp - 1.0


## L: every enemy LOCKED 5 s.
static func hidden_power_l(ctx: Dictionary) -> void:
	var c := _hidden_power(ctx)
	for e in _team(ctx.sim, c, false):
		status(ctx, e, "locked", 5000.0)


## M: +50 PP to every ally.
static func hidden_power_m(ctx: Dictionary) -> void:
	var c := _hidden_power(ctx)
	for a in _team(ctx.sim, c, true):
		a.add_pp(50.0)


## N: every ally gains 50 SHIELD and explodes: 50 SPECIAL to its adjacent enemies and itself.
static func hidden_power_n(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c := _hidden_power(ctx)
	for a in _team(sim, c, true):
		sim.add_shield(a, 50.0 * (1.0 + c.ap / 100.0), c)
		for cell in BattleBoard.adjacent_cells(a.cell):
			var e := sim.board.get_unit(cell)
			if e != null and e.alive and e.team != a.team:
				sim.deal_damage(e, 50.0, BattleUnit.DamageKind.SPECIAL, a)
		if not a.has_item("PROTECTIVE_PADS"):
			sim.deal_damage(a, 50.0, BattleUnit.DamageKind.SPECIAL, a)


## O: every Pokémon of the player that can eat gets a random dish.
static func hidden_power_o(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	_hidden_power(ctx)
	var p = sim.player
	if p == null:
		return
	var dishes := GameData.items_in("Dishes").filter(func(d: String) -> bool: return d != "HERBA_MYSTICA")
	for u in p.bench + p.board.values():
		if u == null or not SynergyItems.can_eat(u):
			continue
		var dish: String = dishes[sim.rng.randi() % dishes.size()]
		if dish == "SWEETS":
			var sweets := GameData.items_in("Sweets")
			dish = sweets[sim.rng.randi() % sweets.size()]
		elif dish == "MUSHROOMS":
			dish = SynergyItems._weighted(sim.rng, SynergyItems.MUSHROOM_WEIGHTS)
		u.dishes.assign([dish])


## P: 5 Bug Pokémon, rarer with the stages.
static func hidden_power_p(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c := _hidden_power(ctx)
	var stage := float(sim.team_info[BattleUnit.Team.BLUE].get("stage", 1))
	var weights := {"COMMON": maxf(0.0, 2.0 - stage / 10.0), "UNCOMMON": maxf(0.0, 2.0 - stage / 20.0), "RARE": 1.0,
		"EPIC": stage / 10.0, "ULTRA": stage / 20.0}
	var bugs: Dictionary = {}
	for pkm in GameData.pool + GameData.additional:
		var d := GameData.get_pokemon(pkm)
		if d.types.has("BUG") and int(d.stars) == 1:
			bugs[pkm] = int(roundf(100.0 * float(weights.get(d.rarity, 0.0))))
	for _i in 5:
		var bug := SynergyItems._weighted(sim.rng, bugs) if not bugs.is_empty() else "WEEDLE"
		_summon(sim, bug, c.team, c.cell)


## Q: the fight ends: both teams leave the board.
static func hidden_power_q(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	_hidden_power(ctx)
	for u in sim.units:
		if u.alive:
			u.alive = false
			sim.board.clear(u.cell)
			sim.emit({"type": "death", "unit": u})


## R: 6 free shop refreshes.
static func hidden_power_r(ctx: Dictionary) -> void:
	_hidden_power(ctx)
	if ctx.sim.player != null:
		ctx.sim.rewards.free_rolls += 6


## S: a tidal wave (level 2) for its team.
static func hidden_power_s(ctx: Dictionary) -> void:
	var c := _hidden_power(ctx)
	SynergyEffects.tidal_wave(ctx.sim, c.team, 2)


## T: 3 random berries.
static func hidden_power_t(ctx: Dictionary) -> void:
	_hidden_power(ctx)
	if ctx.sim.player != null:
		var berries := GameData.items_in("Berries")
		for b in pick_random(ctx.sim, berries, 3):
			ctx.sim.rewards.items.append(b)


## U: Uxie holding an Aqua Egg, about to cast.
static func hidden_power_u(ctx: Dictionary) -> void:
	var c := _hidden_power(ctx)
	var uxie := _summon(ctx.sim, "UXIE", c.team, c.cell)
	if uxie != null:
		uxie.equip(["AQUA_EGG"])
		uxie.pp = uxie.max_pp - 1.0


## V: 30 SPECIAL to every enemy.
static func hidden_power_v(ctx: Dictionary) -> void:
	var c := _hidden_power(ctx)
	var foes := _team(ctx.sim, c, false)
	show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	for e in foes:
		ctx.sim.deal_damage(e, roundf(30.0 * (1.0 + c.ap / 100.0)), BattleUnit.DamageKind.SPECIAL, c)


## W: a Pokémon of one of the 2 top synergies of the player on the bench (rarer with the stages).
static func hidden_power_w(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	_hidden_power(ctx)
	var p = sim.player
	if p == null or p.first_free_bench_slot() < 0:
		return
	var top: Array = Synergies.sort(p.synergy_counts()).slice(0, 2)
	if top.is_empty():
		return
	var synergy: String = top[sim.rng.randi() % top.size()]
	var stage := float(p.stage)
	var weights := {"RARE": clampf(1.5 - stage / 10.0, 0.0, 1.0),
		"EPIC": clampf(stage / 10.0 if stage < 10 else 1.5 - stage / 20.0, 0.0, 1.0), "ULTRA": maxf(0.0, -1.0 + stage / 10.0)}
	var candidates: Dictionary = {}
	for pkm in GameData.pool + GameData.additional:
		var d := GameData.get_pokemon(pkm)
		if d.types.has(synergy) and int(d.stars) == 1 and weights.has(d.rarity):
			candidates[pkm] = int(roundf(100.0 * float(weights[d.rarity])))
	var total := 0
	for k in candidates:
		total += int(candidates[k])
	if total <= 0:
		return
	p.bench[p.first_free_bench_slot()] = PlayerState.OwnedUnit.new(SynergyItems._weighted(sim.rng, candidates))


## X: every ally gets X-Ray Vision.
static func hidden_power_x(ctx: Dictionary) -> void:
	var c := _hidden_power(ctx)
	for a in _team(ctx.sim, c, true):
		if a.items.size() < BattleUnit.MAX_ITEMS:
			a.equip(["XRAY_VISION"])


## Y: every ally gains 100% of its BASE ATK (AP boosted).
static func hidden_power_y(ctx: Dictionary) -> void:
	var c := _hidden_power(ctx)
	for a in _team(ctx.sim, c, true):
		a.add_stat("atk", a.base_atk * (1.0 + c.ap / 100.0))


## Z: every enemy FREEZE 2 s.
static func hidden_power_z(ctx: Dictionary) -> void:
	var c := _hidden_power(ctx)
	for e in _team(ctx.sim, c, false):
		status(ctx, e, "freeze", 2000.0)


## ?: 4 Unowns on the bench.
static func hidden_power_qm(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	_hidden_power(ctx)
	var p = sim.player
	if p == null:
		return
	var unowns: Array = p.unowns_for_stage().filter(func(u: String) -> bool: return u != "UNOWN_QUESTION")
	for _i in 4:
		var slot: int = p.first_free_bench_slot()
		if slot < 0 or unowns.is_empty():
			break
		p.bench[slot] = PlayerState.OwnedUnit.new(unowns[sim.rng.randi() % unowns.size()])


## !: 4 Unowns join the fight, one at each corner.
static func hidden_power_em(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c := _hidden_power(ctx)
	var stages: Array = GameData.config.get("unownStages", [[]])
	var stage := int(sim.team_info[BattleUnit.Team.BLUE].get("stage", 1))
	var list: Array = stages[0 if stage < 10 else (1 if stage < 20 else 2)]
	list = list.filter(func(u: String) -> bool: return u != "UNOWN_EXCLAMATION" and GameData.pokemon.has(u))
	for corner in _corners():
		if not list.is_empty():
			_summon(sim, list[sim.rng.randi() % list.size()], c.team, corner)
#endregion


#region abilities (batch1)
## horn-leech.ts: 200% ATK (300 / 500% at 3★ / 4★) as SPECIAL; heals 50% of the damage
## taken, half of the overheal as SHIELD.
static func horn_leech(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var r := hit(ctx, t, by_stars(c, [2, 2, 3, 5]) * c.atk)
	var heal := roundf(float(r.taken) * 0.5)
	var overheal := maxf(0.0, heal - (c.max_hp - c.hp))
	sim.heal(c, heal, c)
	if overheal > 0.0:
		sim.add_shield(c, roundf(overheal * 0.5), c)


## explosion.ts: 50 / 100 / 200 SPECIAL to the adjacent enemies and to itself.
static func explosion(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var damage := by_stars(c, [50, 100, 200, 400])
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, damage)
	if not c.has_item("PROTECTIVE_PADS"):
		hit(ctx, c, damage)


## leech-seed.ts: heals 20 / 40 / 80 (AP) and POISON the target 3 / 6 / 12 s.
static func leech_seed(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	ctx.sim.heal(c, by_stars(c, [20, 40, 80, 160]) * (1.0 + c.ap / 100.0), c)
	if ctx.focus != null:
		show(ctx, [ctx.focus.cell])
		status(ctx, ctx.focus, "poison", by_stars(c, [3000, 6000, 12000, 24000]))


## aerial-ace.ts: 25 / 50 / 100 TRUE.
static func aerial_ace(ctx: Dictionary) -> void:
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(ctx.caster, [25, 50, 100, 200]), BattleUnit.DamageKind.TRUE)


## Free cell with the most allies around (getMostSurroundedCoordinateAvailablePlace).
static func most_allied_cell(sim: BattleSim, c: BattleUnit) -> Variant:
	var best: Variant = null
	var best_count := -1
	for cell in sim.board.free_cells():
		var n := 0
		for a in BattleBoard.adjacent_cells(cell):
			var u := sim.board.get_unit(a)
			if u != null and u.alive and u.team == c.team:
				n += 1
		if n > best_count:
			best_count = n
			best = cell
	return best


## aqua-ring.ts: moves where allies are the most packed; itself and the allies around are
## cleansed and heal 20 / 40 / 80 (AP).
static func aqua_ring(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var dest: Variant = most_allied_cell(sim, c)
	if dest == null:
		return
	sim.move_unit(c, dest, 250.0, "dash")
	var cells := BattleBoard.adjacent_cells(c.cell, true)
	show(ctx, cells, "allies")
	for cell in cells:
		var a := sim.board.get_unit(cell)
		if a != null and a.alive and a.team == c.team:
			a.cleanse()
			sim.heal(a, by_stars(c, [20, 40, 80, 160]) * (1.0 + c.ap / 100.0), c)


## iron-defense.ts: every ally on its row gains 20 / 40 / 80 SHIELD (AP).
static func iron_defense(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.cells_in_row(c.cell.y)
	show(ctx, cells, "allies")
	for a in sim.alive_units(c.team):
		if a.cell.y == c.cell.y:
			sim.add_shield(a, by_stars(c, [20, 40, 80, 160]) * (1.0 + c.ap / 100.0), c)


## slashing-claw.ts: 15 / 30 / 60 SPECIAL (x1.3 on a wounded target), WOUND 5 s.
static func slashing_claw(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var damage := by_stars(c, [15, 30, 60, 120])
	if t.has_status("wound"):
		damage = ceilf(damage * 1.3)
	hit(ctx, t, damage)
	status(ctx, t, "wound", 5000.0)


## wonder-guard.ts: the adjacent enemies: PARALYSIS 3 s and 30 / 60 / 120 SPECIAL.
static func wonder_guard(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		status(ctx, e, "paralysis", 3000.0)
		hit(ctx, e, by_stars(c, [30, 60, 120, 240]))


## absorb.ts: 30 / 60 / 120 SPECIAL; itself and the allies around heal 10% of it (AP).
static func absorb(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var damage := by_stars(c, [30, 60, 120, 240])
	show(ctx, [t.cell])
	hit(ctx, t, damage)
	for cell in BattleBoard.adjacent_cells(c.cell, true):
		var a := sim.board.get_unit(cell)
		if a != null and a.alive and a.team == c.team:
			sim.heal(a, damage * 0.1 * (1.0 + c.ap / 100.0), c)


## arm-thrust.ts: 2 to 5 hits (Luck) of 100% ATK (200 / 400% at 3★ / 4★) as PHYSICAL, each
## with its own crit chance.
static func arm_thrust(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var hits := clampi(int(floorf(2.0 + sim.rng.randf() * 4.0 * (1.0 + c.luck / 100.0))), 2, 5)
	for _i in hits:
		hit(ctx, t, c.atk * by_stars(c, [1, 1, 2, 4]), BattleUnit.DamageKind.PHYSICAL, true,
			sim.chance(c.crit_chance / 100.0, c))
#endregion


#region abilities (batch2)
## Line through the target to the board edge (effectInLine), the caster excluded.
static func line_through(c: BattleUnit, t: BattleUnit) -> Array[Vector2i]:
	var cells := BattleBoard.line_cells(c.cell, t.cell)
	cells.erase(c.cell)
	return cells


## aromatherapy.ts: the adjacent allies are cleansed and heal 20 / 40 / 80 (AP).
static func aromatherapy(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells, "allies")
	for cell in cells:
		var a := sim.board.get_unit(cell)
		if a != null and a.alive and a.team == c.team:
			a.cleanse()
			sim.heal(a, by_stars(c, [20, 40, 80, 160]) * (1.0 + c.ap / 100.0), c)


## assurance.ts: 25 / 50 / 100 SPECIAL, doubled when itself is under 50% HP.
static func assurance(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var damage := by_stars(c, [25, 50, 100, 200])
	hit(ctx, t, damage * 2.0 if c.hp_ratio() < 0.5 else damage)


## aura-sphere.ts: a line through the target: 25 / 50 / 100 SPECIAL and SILENCE 3 s.
static func aurasphere(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := line_through(c, t)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [25, 50, 100, 200]))
		status(ctx, e, "silence", 3000.0)


## aurora-beam.ts: a line through the target: 25 / 50 / 100 SPECIAL, 50% FREEZE 2 s.
static func aurora_beam(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := line_through(c, t)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [25, 50, 100, 200]))
		if sim.chance(0.5, c):
			status(ctx, e, "freeze", 2000.0)


## axe-kick.ts: leaps next to the enemy with the most PP: 25 / 50 / 100 SPECIAL, it loses 15 PP
## (AP), 30% CONFUSION 3 s.
static func axe_kick(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var foes := sim.enemies_of(c)
	foes.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.pp > b.pp)
	for e in foes:
		var spot: Variant = sim.closest_free_cell_near(e.cell, c.team)
		if spot == null:
			continue
		sim.move_unit(c, spot, 250.0, "dash")
		show(ctx, [e.cell])
		hit(ctx, e, by_stars(c, [25, 50, 100, 100]))
		e.drain_pp(15.0 * (1.0 + c.ap / 100.0))
		if sim.chance(0.3, c):
			status(ctx, e, "confusion", 3000.0)
		return


## baneful-bunker.ts: PROTECT 2 s; meanwhile melee attackers take 10 / 20 / 30 SPECIAL and
## POISON 3 s (ItemEffects.on_attack_received); the adjacent enemies are taunted.
static func baneful_bunker(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	status(ctx, c, "protect", 2000.0)
	c.effects.bunker_until = sim.time_ms + 2000.0
	c.effects.bunker_damage = by_stars(c, [10, 20, 30, 50])
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		e.target = c


## beat-up.ts: 1 / 2 / 3 Houndour join the fight, their max HP scaled by AP.
static func beat_up(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	for _i in int(by_stars(c, [1, 2, 3, 5])):
		var dog := _summon(sim, "HOUNDOUR", c.team, c.cell)
		if dog != null:
			dog.max_hp = maxf(1.0, roundf(dog.max_hp * (1.0 + c.ap / 100.0)))
			dog.hp = dog.max_hp


## body-slam.ts: 30% (50 / 80% at 3★ / 4★) of its max HP x (1 + AP/100) as SPECIAL.
static func body_slam(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, roundf(by_stars(c, [0.3, 0.3, 0.5, 0.8]) * c.max_hp * (1.0 + c.ap / 100.0)),
		BattleUnit.DamageKind.SPECIAL, false)


## bonemerang.ts: a line through the target, twice (again 1 s later): 15 / 30 / 60 SPECIAL.
static func bonemerang(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := line_through(c, t)
	var throw := func() -> void:
		show(ctx, cells)
		for e in enemies_on(ctx, cells):
			hit(ctx, e, by_stars(c, [15, 30, 60, 120]))
	throw.call()
	sim.schedule(1000.0, c, throw)


## bone-armor.ts: jumps next to the enemy with the lowest HP%: 20 / 40 / 80 SPECIAL, heals the
## damage taken; a kill gives +4 / 8 / 12 DEF and SPE_DEF.
static func bone_armor(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var low: BattleUnit = null
	for e in sim.enemies_of(c):
		if low == null or e.hp_ratio() < low.hp_ratio():
			low = e
	if low == null:
		return
	var spot: Variant = sim.closest_free_cell_near(low.cell, c.team)
	if spot != null:
		sim.move_unit(c, spot, 250.0, "dash")
	show(ctx, [low.cell])
	var r := hit(ctx, low, by_stars(c, [20, 40, 80, 160]))
	if float(r.taken) > 0.0:
		sim.heal(c, float(r.taken), c)
	if r.death:
		var buff := by_stars(c, [4, 8, 12, 24])
		c.add_stat("def", buff)
		c.add_stat("speDef", buff)
#endregion


#region abilities (batch3)
## city-shuttle.ts: carries the closest ally: dashes next to the farthest enemy, enemies on
## the way take 10 / 20 / 40 SPECIAL + the ATK of the passenger; both gain 20 / 40 / 80 SHIELD.
static func city_shuttle(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var passenger: BattleUnit = null
	for a in sim.alive_units(c.team):
		if a != c and (passenger == null or BattleBoard.distance_m(a.cell, c.cell) < BattleBoard.distance_m(passenger.cell, c.cell)):
			passenger = a
	var spot := sim.farthest_spot(c)
	var extra := passenger.atk if passenger != null else 0.0
	if not spot.is_empty():
		var cells := BattleBoard.cells_between(c.cell, spot.cell)
		show(ctx, cells)
		sim.move_unit(c, spot.cell, 300.0, "dash")
		if passenger != null:
			var drop: Variant = sim.closest_free_cell_near(spot.cell, c.team)
			if drop != null:
				sim.move_unit(passenger, drop, 300.0, "dash")
		for e in enemies_on(ctx, cells):
			hit(ctx, e, by_stars(c, [10, 20, 40, 80]) + extra)
	var shield := by_stars(c, [20, 40, 80, 160]) * (1.0 + c.ap / 100.0)
	sim.add_shield(c, shield, c)
	if passenger != null:
		sim.add_shield(passenger, shield, c)


## coil.ts: LOCKED and PARALYSIS 3 s on the target; +3 / 5 / 10 ATK and DEF (AP).
static func coil(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t != null:
		show(ctx, [t.cell])
		status(ctx, t, "locked", 3000.0)
		status(ctx, t, "paralysis", 3000.0)
	var buff := by_stars(c, [3, 5, 10, 20]) * (1.0 + c.ap / 100.0)
	c.add_stat("atk", buff)
	c.add_stat("def", buff)


## confusion.ts: a confused target takes 75 / 150 / 300 SPECIAL; else SILENCE and CONFUSION 3 / 5 / 7 s.
static func confusion(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	if t.has_status("confusion"):
		hit(ctx, t, by_stars(c, [75, 150, 300, 500]))
	else:
		var ms := by_stars(c, [3000, 5000, 7000, 10000])
		status(ctx, t, "silence", ms)
		status(ctx, t, "confusion", ms)


## cotton-spore.ts: the 3 closest enemies lose 10 / 20 / 30 SPEED (AP) and a COTTON_BALL is left
## under each of them.
static func cotton_spore(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var foes := sim.enemies_of(c)
	foes.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return BattleBoard.distance_c(a.cell, c.cell) < BattleBoard.distance_c(b.cell, c.cell))
	foes = foes.slice(0, 3)
	show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	for e in foes:
		e.add_stat("speed", AbilityRunner.adjust_buff(c, e, -by_stars(c, [10, 20, 30, 50]) * (1.0 + c.ap / 100.0)))
		board_effect(sim, [e.cell], "COTTON_BALL")


## cross-poison.ts: the target and the 6 cells around: 30 / 60 / 120 SPECIAL and POISON 2 s.
static func cross_poison(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.adjacent_cells(t.cell, true)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [30, 60, 120, 240]))
		status(ctx, e, "poison", 2000.0)


## defense-curl.ts: +5 / 10 / 20 DEF and SPE_DEF (AP).
static func defense_curl(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var buff := by_stars(c, [5, 10, 20, 40]) * (1.0 + c.ap / 100.0)
	c.add_stat("def", buff)
	c.add_stat("speDef", buff)
	c.cooldown = 250.0


## detect.ts: the adjacent allies get PROTECT 0.5 / 0.6 / 0.8 s per enemy within 2 cells (AP).
static func detect(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var near := 0
	for e in sim.enemies_of(c):
		if BattleBoard.distance_c(e.cell, c.cell) <= 2:
			near += 1
	var ms := roundf(by_stars(c, [500, 600, 800, 1000]) * near * (1.0 + c.ap / 100.0))
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells, "allies")
	for cell in cells:
		var a := sim.board.get_unit(cell)
		if a != null and a.alive and a.team == c.team and ms > 0.0:
			sim.add_status(a, "protect", ms)


## diamond-storm.ts: its DEF x1 (1.5 at 3★) as SPECIAL to the adjacent enemies.
static func diamond_storm(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, c.def * by_stars(c, [1, 1, 1.5, 3]))


## dig.ts: digs to the free cell next to the farthest enemy: 10 / 20 / 40 SPECIAL to the enemies on the way.
static func dig(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var spot := sim.farthest_spot(c)
	var victims: Array[BattleUnit] = []
	if not spot.is_empty():
		var cells := BattleBoard.cells_between(c.cell, spot.cell)
		show(ctx, cells)
		victims = enemies_on(ctx, cells)
		sim.move_unit(c, spot.cell, 300.0, "dash")
	if victims.is_empty() and ctx.focus != null:
		victims.append(ctx.focus)
	for e in victims:
		hit(ctx, e, by_stars(c, [10, 20, 40, 80]))


## disarming-voice.ts: enemies within 1 / 2 / 3 cells are charmed 1 s (AP).
static func disarming_voice(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.cells_in_radius(c.cell, int(by_stars(c, [1, 2, 3, 4])), false)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		status(ctx, e, "charm", by_stars(c, [1000, 1000, 1000, 2000]), true)
#endregion


#region abilities (batch4)
## Runs another ability as `c` (Encore, Metronome...): its steps and script, no PP spent.
static func run_other(ctx: Dictionary, ability_id: String, target: BattleUnit) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var ab := GameData.get_ability(ability_id)
	var other := {"sim": sim, "caster": c, "ability": ab, "start_cell": c.cell,
		"focus": AbilityRunner.resolve_focus(sim, c, target, ab.get("focus", "target"))}
	other.dash_end = c.cell
	for step in ab.get("steps", []):
		AbilityRunner._schedule_step(other, step)
	run(other)


## drill-run.ts: 15 / 30 / 60 TRUE (can crit), takes the place of the target; an enemy right
## behind it becomes the next target, PP refilled.
static func drill_run(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var dir := BattleBoard.orientation(c.cell, t.cell)
	var behind := BattleBoard.step(t.cell, dir)
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [15, 30, 60, 120]), BattleUnit.DamageKind.TRUE, true,
		sim.chance(c.crit_chance / 100.0, c))
	if not t.alive:
		sim.move_unit(c, t.cell if sim.board.is_free(t.cell) else c.cell, 250.0, "dash")
	var next := sim.board.get_unit(behind) if BattleBoard.in_bounds(behind) else null
	if next != null and next.alive and next.team != c.team:
		c.target = next
		c.pp = c.max_pp


## ear-dig.ts: 30 / 60 / 120 SPECIAL + 5 / 10 / 20 per depth of the hole under the target;
## a target on the player's side without a hole gets one.
static func ear_dig(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var holes: Dictionary = sim.team_info[BattleUnit.Team.BLUE].get("holes", {})
	var depth := int(holes.get(t.cell, 0))
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [30, 60, 120, 240]) + depth * by_stars(c, [5, 10, 20, 40]))
	if depth == 0 and sim.player != null and PlayerState.is_player_cell(t.cell):
		sim.player.ground_holes[t.cell] = 1


## electrify.ts: the strongest ally not ELECTRIC gets ELECTRIC_FIELD, the Electric synergy of
## the team and 15 / 30 / 60 SHIELD (AP); itself if none.
static func electrify(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var best: BattleUnit = null
	for a in sim.alive_units(c.team):
		if a != c and not a.types.has("ELECTRIC") and not a.has_status("electric_field"):
			if best == null or a.unit_score() > best.unit_score():
				best = a
	if best == null:
		best = c
	show(ctx, [best.cell], "allies")
	sim.add_status(best, "electric_field", 1e9)
	sim.add_shield(best, by_stars(c, [15, 30, 60, 120]) * (1.0 + c.ap / 100.0), c)
	if not best.types.has("ELECTRIC") and GameData.synergy_unlocked("ELECTRIC"):
		best.types.append("ELECTRIC")
		var tier := int(sim.team_tiers[c.team].get("ELECTRIC", 0))
		if tier > 0:
			best.synergy["ELECTRIC"] = tier
		if sim.player != null and c.team == BattleUnit.Team.BLUE:
			best.add_stat("speed", 2.0 * sim.player.items.count("CELL_BATTERY"))


## electro-ball.ts: bounces from enemy to enemy (the closest not hit yet), 10 / 20 / 40 SPECIAL
## each, as long as its SPEED allows (-30 per bounce).
static func electro_ball(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var state := {"speed": c.speed, "hit": []}
	var step_ms := roundf(200.0 * (50.0 / maxf(c.speed, 1.0)))
	var bounce := func(self_ref: Callable, current: BattleUnit) -> void:
		if not current.alive:
			return
		show(ctx, [current.cell])
		hit(ctx, current, by_stars(c, [10, 20, 40, 80]))
		state.hit.append(current)
		var next: BattleUnit = null
		for e in sim.enemies_of(c):
			if not state.hit.has(e) and (next == null or BattleBoard.distance_m(e.cell, current.cell) < BattleBoard.distance_m(next.cell, current.cell)):
				next = e
		state.speed -= 30.0
		if next != null and state.speed > 0.0:
			sim.schedule(step_ms * BattleBoard.distance_m(next.cell, current.cell), c,
				func() -> void: self_ref.call(self_ref, next))
	bounce.call(bounce, t)


## encore.ts: casts again the last ability its team used (not an inimitable one).
static func encore(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var history: Array = sim.abilities_cast[c.team]
	for i in range(history.size() - 1, -1, -1):
		var id: String = history[i]
		if not GameData.get_ability(id).get("inimitable", false) and GameData.is_ability_ported(id):
			run_other(ctx, id, ctx.focus)
			return


## fake-out.ts: FLINCH 3 s (if AP not negative) and 40 / 80 / 150 SPECIAL; loses 30 AP.
static func fake_out(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	if c.ap >= 0.0:
		status(ctx, t, "flinch", 3000.0)
	hit(ctx, t, by_stars(c, [40, 80, 150, 300]))
	c.add_stat("ap", -30.0)


## fire-fang.ts: 30 / 60 / 120 SPECIAL and BURN 2 s.
static func fire_fang(ctx: Dictionary) -> void:
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(ctx.caster, [30, 60, 120, 240]))
	status(ctx, t, "burn", 2000.0)


## harden.ts: +4 / 8 / 12 DEF (AP).
static func harden(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	c.add_stat("def", by_stars(c, [4, 8, 12, 24]) * (1.0 + c.ap / 100.0))


## head-smash.ts: 40 / 80 / 150 SPECIAL (a sleeping / frozen target is KO); 10 / 20 / 40 recoil.
static func head_smash(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	if t.has_status("sleep") or t.has_status("freeze"):
		hit(ctx, t, 9999.0, BattleUnit.DamageKind.TRUE, false)
	else:
		hit(ctx, t, by_stars(c, [40, 80, 150, 300]))
	if not c.has_item("PROTECTIVE_PADS"):
		ctx.sim.deal_damage(c, by_stars(c, [10, 20, 40, 80]), BattleUnit.DamageKind.PHYSICAL, c)
#endregion


#region abilities (batch5)
## Free cell with the most units of `team` around.
static func most_surrounded_by(sim: BattleSim, team: int) -> Variant:
	var best: Variant = null
	var best_count := 0
	for cell in sim.board.free_cells():
		var n := 0
		for a in BattleBoard.adjacent_cells(cell):
			var u := sim.board.get_unit(a)
			if u != null and u.alive and u.team == team:
				n += 1
		if n > best_count:
			best_count = n
			best = cell
	return best


## cavernous-chomp.ts: 40 / 80 / 160 SPECIAL; a kill makes it RAGE 1 / 2 / 3 s.
static func cavernous_chomp(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var r := hit(ctx, t, by_stars(c, [40, 80, 160, 320]))
	if r.death:
		status(ctx, c, "enraged", by_stars(c, [1000, 2000, 3000, 3000]))


## dive.ts: 15 / 30 / 60 SHIELD, dives where the enemies are the most packed: 10 / 20 / 40
## SPECIAL to the adjacent enemies.
static func dive(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	sim.add_shield(c, by_stars(c, [15, 30, 60, 120]), c)
	var foe_team := BattleUnit.Team.RED if c.team == BattleUnit.Team.BLUE else BattleUnit.Team.BLUE
	var dest: Variant = most_surrounded_by(sim, foe_team)
	if dest == null:
		return
	sim.move_unit(c, dest, 250.0, "dash")
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [10, 20, 40, 80]))


## drain-punch.ts: 200% ATK (300 / 400% at 3★ / 4★) as SPECIAL, heals twice the damage taken.
static func drain_punch(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var r := hit(ctx, t, c.atk * by_stars(c, [2, 2, 3, 4]))
	ctx.sim.heal(c, float(r.taken) * 2.0, c)


## dynamic-punch.ts: CONFUSION 2 / 4 / 6 s and 40 / 80 / 160 SPECIAL.
static func dynamic_punch(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	status(ctx, t, "confusion", by_stars(c, [2000, 4000, 6000, 8000]))
	hit(ctx, t, by_stars(c, [40, 80, 160, 320]))


## egg-bomb.ts: the target and its allies around: 25 / 50 / 100 SPECIAL and ARMOR_BREAK 4 s;
## a KO has 25% to give an egg about to hatch.
static func egg_bomb(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.adjacent_cells(t.cell, true)
	show(ctx, cells)
	for cell in cells:
		var v := sim.board.get_unit(cell)
		if v == null or not v.alive or v.team != t.team:
			continue
		var r := hit(ctx, v, by_stars(c, [25, 50, 100, 200]))
		if r.death and sim.player != null and c.owned != null and sim.chance(0.25, c):
			var p = sim.player
			if p.first_free_bench_slot() >= 0:
				var egg: PlayerState.OwnedUnit = SynergyItems.make_egg(p)
				egg.hatch_stacks = int(GameData.config.get("eggHatch", 5)) - 1
				p.bench[p.first_free_bench_slot()] = egg
		if v.alive:
			status(ctx, v, "armor_reduction", 4000.0)


## electro-web.ts: the adjacent enemies: 15 / 30 / 60 SPECIAL and it steals 15 / 30 / 60 SPEED (AP).
static func electro_web(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	var steal := by_stars(c, [15, 30, 60, 120]) * (1.0 + c.ap / 100.0)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [15, 30, 60, 120]))
		if not e.has_item("TWIST_BAND"):
			e.add_stat("speed", -steal)
			c.add_stat("speed", steal)


## heal-block.ts: the adjacent enemies: 20 / 40 / 80 SPECIAL and WOUND 5 s.
static func heal_block(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [20, 40, 80, 160]))
		status(ctx, e, "wound", 5000.0)


## hypnosis.ts: the farthest enemy SLEEP 1 / 1.75 / 3 s x (2 + AP/100).
static func hypnosis(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var far: BattleUnit = sim.farthest_enemy(c)
	if far == null:
		far = ctx.focus
	if far == null:
		return
	show(ctx, [far.cell])
	status(ctx, far, "sleep", roundf(by_stars(c, [1000, 1750, 3000, 6000]) * (2.0 + c.ap / 100.0)))


## ice-hammer.ts: FREEZE 3 s on the target, PARALYSIS 3 s on itself, 50 / 100 / 200 SPECIAL.
static func ice_hammer(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	status(ctx, t, "freeze", 3000.0)
	status(ctx, c, "paralysis", 3000.0)
	hit(ctx, t, by_stars(c, [50, 100, 200, 400]))
#endregion


#region abilities (batch6)
## feather-dance.ts: flies next to the farthest enemy (else to safety), 8 / 10 / 12 feathers
## fall on the cells of its path: 1 s later each unit hit gets (ally) or loses (enemy) HP 20,
## ATK 4, DEF 4, AP 10, SPE_DEF 4, SPEED 10 or LUCK 10 (random feather, AP boosted).
static func feather_dance(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var spot := sim.farthest_spot(c)
	var dest: Variant = spot.cell if not spot.is_empty() else AbilityRunner.fly_away_cell(sim, c)
	if dest == null:
		return
	var path := BattleBoard.cells_between(c.cell, dest)
	sim.move_unit(c, dest, 300.0, "dash")
	show(ctx, path, "all")
	var k := 1.0 + c.ap / 100.0
	for _i in int(by_stars(c, [8, 10, 12, 24])):
		var u := sim.board.get_unit(path[sim.rng.randi() % path.size()])
		if u == null or not u.alive:
			continue
		var feather := sim.rng.randi() % 7
		sim.schedule(1000.0, c, func() -> void: _feather(ctx, u, feather, k))


static func _feather(ctx: Dictionary, u: BattleUnit, feather: int, k: float) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if not u.alive:
		return
	var sign := 1.0 if u.team == c.team else -1.0
	var stats := ["", "atk", "def", "ap", "speDef", "speed", "luck"]
	var amounts := [20.0, 4.0, 4.0, 10.0, 4.0, 10.0, 10.0]
	if feather == 0:
		if sign > 0.0:
			sim.heal(u, 20.0 * k, c)
		else:
			hit(ctx, u, 20.0)
	else:
		u.add_stat(stats[feather], AbilityRunner.adjust_buff(c, u, sign * amounts[feather] * k))


## fire-lash.ts: ARMOR_BREAK 4 s and 30 / 60 / 120 SPECIAL.
static func fire_lash(ctx: Dictionary) -> void:
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	status(ctx, t, "armor_reduction", 4000.0)
	hit(ctx, t, by_stars(ctx.caster, [30, 60, 120, 240]))


## fire-spin.ts: the target and the 6 cells around: 25 / 50 / 100 SPECIAL and BURN 3 s.
static func fire_spin(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.adjacent_cells(t.cell, true)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [25, 50, 100, 200]))
		status(ctx, e, "burn", 3000.0)


## first-impression.ts: 45 / 90 / 180 SPECIAL and FLINCH 5 s; on its first cast it jumps to
## safety and a Bug (common / uncommon / rare by stars) appears where it stood.
static func first_impression(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [45, 90, 180, 360]))
	status(ctx, t, "flinch", 5000.0)
	if c.cast_count != 1:
		return
	var dest: Variant = AbilityRunner.fly_away_cell(sim, c)
	if dest == null:
		return
	var old := c.cell
	sim.move_unit(c, dest, 250.0, "dash")
	var rarity: String = ["COMMON", "UNCOMMON", "RARE"][clampi(c.stars - 1, 0, 2)]
	var bugs := GameData.pool.filter(func(pkm: String) -> bool:
		var d := GameData.get_pokemon(pkm)
		return d.types.has("BUG") and int(d.stars) == 1 and d.rarity == rarity)
	if not bugs.is_empty() and sim.board.is_free(old):
		_summon(sim, bugs[sim.rng.randi() % bugs.size()], c.team, old)


## fissure.ts: 2 / 3 / 4 rifts on random cells: the cell and the 6 around take 25 / 50 / 75 SPECIAL.
static func fissure(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	for _i in int(by_stars(c, [2, 3, 4, 6])):
		var center := Vector2i(sim.rng.randi() % BattleBoard.WIDTH, sim.rng.randi() % BattleBoard.HEIGHT)
		var cells := BattleBoard.adjacent_cells(center, true)
		show(ctx, cells)
		for e in enemies_on(ctx, cells):
			hit(ctx, e, by_stars(c, [25, 50, 75, 100]))


## frost-breath.ts: a cone of 4 cells in front of it toward the target: 35 / 70 / 140 SPECIAL
## (can crit), 50% FREEZE 2 s.
static func frost_breath(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var dir := BattleBoard.orientation(c.cell, t.cell)
	if dir == Vector2i.ZERO:
		dir = BattleBoard.DIRECTIONS[0]
	var front := BattleBoard.step(c.cell, dir)
	var cells: Array[Vector2i] = [front]
	for d in BattleBoard.fan(dir):
		if BattleBoard.in_bounds(BattleBoard.step(front, d)):
			cells.append(BattleBoard.step(front, d))
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [35, 70, 140, 280]), BattleUnit.DamageKind.SPECIAL, true,
			sim.chance(c.crit_chance / 100.0, c))
		if sim.chance(0.5, c):
			status(ctx, e, "freeze", 2000.0)


## gunk-shot.ts: 50 / 100 / 200 SPECIAL and POISON 2 / 4 / 8 s (AP).
static func gunk_shot(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [50, 100, 200, 400]))
	status(ctx, t, "poison", by_stars(c, [2000, 4000, 8000, 16000]), true)


## helping-hand.ts: the 2 closest allies: 30 / 60 / 100 SHIELD (AP), their next ability damage doubled.
static func helping_hand(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies := sim.allies_of(c)
	allies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return BattleBoard.distance_m(a.cell, c.cell) < BattleBoard.distance_m(b.cell, c.cell))
	allies = allies.slice(0, 2)
	show(ctx, allies.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
	for a in allies:
		a.effects.double_damage = true
		sim.add_shield(a, by_stars(c, [30, 60, 100, 200]) * (1.0 + c.ap / 100.0), c)


## high-horsepower.ts: charges behind the target, then 0.3 s later 15 / 30 / 60 SPECIAL to
## every adjacent enemy (doubled when there is only one).
static func high_horsepower(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var dir := BattleBoard.orientation(c.cell, t.cell)
	var behind := BattleBoard.step(t.cell, dir)
	if BattleBoard.in_bounds(behind) and sim.board.is_free(behind):
		sim.move_unit(c, behind, 250.0, "dash")
	sim.schedule(300.0, c, func() -> void:
		var cells := BattleBoard.adjacent_cells(c.cell)
		show(ctx, cells)
		var foes := enemies_on(ctx, cells)
		var damage := by_stars(c, [15, 30, 60, 120])
		for e in foes:
			hit(ctx, e, damage * 2.0 if foes.size() == 1 else damage))


## hyper-voice.ts: every enemy on the row of the target: 25 / 50 / 100 SPECIAL, 30% CONFUSION 1 / 2 / 3 s.
static func hyper_voice(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.cells_in_row(t.cell.y)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [25, 50, 100, 200]))
		if sim.chance(0.3, c):
			status(ctx, e, "confusion", by_stars(c, [1000, 2000, 3000, 6000]))
#endregion


#region abilities (batch7)
## Board effect (EMBER...) on cells (board.addBoardEffect: the unit standing there gets it
## again, a new cotton ball can put it back to sleep).
static func board_effect(sim: BattleSim, cells: Array, effect: String) -> void:
	var list: Array[Vector2i] = []
	for cell in cells:
		if not BattleBoard.in_bounds(cell):
			continue
		if not sim.board_effects.has(cell):
			sim.board_effects[cell] = {}
		sim.board_effects[cell][effect] = true
		list.append(cell)
		var u := sim.board.get_unit(cell)
		if effect == "COTTON_BALL" and u != null:
			u.effects.erase("cotton_spent")
	sim.emit({"type": "board_effect", "cells": list, "effect": effect})


## iron-tail.ts: the cells in front of it: its DEF x1 (2 at 3★) as SPECIAL, knocked back.
static func iron_tail(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.cells_in_front(c.cell, t.cell, 1)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		knock_back(sim, e, BattleBoard.orientation(c.cell, e.cell))
		hit(ctx, e, roundf(by_stars(c, [1, 1, 2, 4]) * c.def))


## jaw-lock.ts: LOCKED 3 s and 125% ATK + 10 / 15 / 20 SPECIAL; biting it again heals 25 / 50 / 100 (AP).
static func jaw_lock(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var bitten: bool = t.effects.get("jaw_lock", false)
	status(ctx, t, "locked", 3000.0)
	t.effects.jaw_lock = true
	hit(ctx, t, roundf(c.atk * 1.25) + by_stars(c, [10, 15, 20, 40]))
	if bitten:
		ctx.sim.heal(c, by_stars(c, [25, 50, 100, 200]) * (1.0 + c.ap / 100.0), c)


## last-respects.ts: 30 / 60 / 90 SPECIAL to an adjacent enemy not cursed (else the target),
## cursed: KO in 10 / 8 / 6 s (shorter with AP).
static func last_respects(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var candidates: Array = []
	for cell in BattleBoard.adjacent_cells(c.cell):
		var e := sim.board.get_unit(cell)
		if e != null and e.alive and e.team == t.team and not e.has_status("curse"):
			candidates.append(e)
	var cursed: BattleUnit = candidates[sim.rng.randi() % candidates.size()] if not candidates.is_empty() else null
	var victim: BattleUnit = cursed if cursed != null else t
	show(ctx, [victim.cell])
	hit(ctx, victim, by_stars(c, [30, 60, 90, 180]))
	if cursed != null and cursed.alive:
		var delay := maxf(0.0, by_stars(c, [10000, 8000, 6000, 4000]) * (1.0 - 0.2 * c.ap / 100.0))
		sim.add_status(cursed, "curse", delay, c)


## lava-plume.ts: the cells in front of it: 20 / 40 / 80 SPECIAL and EMBER on them.
static func lava_plume(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.cells_in_front(c.cell, t.cell, 1)
	show(ctx, cells)
	board_effect(sim, cells, "EMBER")
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [20, 40, 80, 160]))


## lingering-aroma.ts: for 5 s, melee attackers take 10 / 20 / 30 SPECIAL and lose 5 PP
## (ItemEffects.on_attack_received).
static func lingering_aroma(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	c.effects.aroma_until = ctx.sim.time_ms + 5000.0
	c.effects.aroma_damage = by_stars(c, [10, 20, 30, 60]) * (1.0 + c.ap / 100.0)
	show(ctx, [c.cell], "allies")


## lovely-kiss.ts: a sleeping target takes 50 / 100 / 150 SPECIAL; else SLEEP 2 / 4 / 6 s (AP).
static func lovely_kiss(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	if t.has_status("sleep"):
		hit(ctx, t, by_stars(c, [50, 100, 150, 300]))
	else:
		status(ctx, t, "sleep", by_stars(c, [2000, 4000, 6000, 12000]), true)


## mach-punch.ts: 25 / 50 / 100 SPECIAL, acts again right away.
static func mach_punch(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [25, 50, 100, 200]))
	c.cooldown = 100.0


## magic-bounce.ts: MAGIC_BOUNCE and SILENCE 4 s on itself.
static func magic_bounce(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	status(ctx, c, "magic_bounce", 4000.0)
	status(ctx, c, "silence", 4000.0)


## magnet-rise.ts: itself and its 2 / 4 / 6 lowest-HP adjacent allies: PROTECT 2 s and +10% dodge (AP).
static func magnet_rise(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies: Array[BattleUnit] = []
	for cell in BattleBoard.adjacent_cells(c.cell):
		var a := sim.board.get_unit(cell)
		if a != null and a.alive and a.team == c.team:
			allies.append(a)
	allies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.hp < b.hp)
	allies = allies.slice(0, int(by_stars(c, [2, 4, 6, 8])))
	allies.append(c)
	show(ctx, allies.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
	for a in allies:
		sim.add_status(a, "protect", 2000.0)
		a.add_stat("dodge", by_stars(c, [0.1, 0.1, 0.1, 0.2]) * (1.0 + c.ap / 100.0))


## meditate.ts: +100% BASE ATK (AP).
static func meditate(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	c.add_stat("atk", c.base_atk * (1.0 + c.ap / 100.0))
#endregion


#region abilities (batch8)
## mimic.ts: casts the ability of its target (unless inimitable).
static func mimic(ctx: Dictionary) -> void:
	var t: BattleUnit = ctx.focus
	if t == null or t.ability_id == "MIMIC" or t.ability_id == "":
		return
	var ab := GameData.get_ability(t.ability_id)
	if ab.get("inimitable", false) or not GameData.is_ability_ported(t.ability_id):
		return
	run_other(ctx, t.ability_id, t)


## moon-dream.ts: SLEEP 3 / 6 / 9 s on the target, the 3 allies closest to the target gain
## 10 / 20 / 30 SHIELD (AP).
static func moon_dream(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var allies := sim.allies_of(c)
	allies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return BattleBoard.distance_m(a.cell, t.cell) < BattleBoard.distance_m(b.cell, t.cell))
	allies = allies.slice(0, 3)
	show(ctx, allies.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
	for a in allies:
		sim.add_shield(a, by_stars(c, [10, 20, 30, 60]) * (1.0 + c.ap / 100.0), c)
	show(ctx, [t.cell])
	status(ctx, t, "sleep", by_stars(c, [3000, 6000, 9000, 18000]))


## mortal-spin.ts: adjacent enemies targeting it take 20 / 40 / 80 SPECIAL, POISON 4 / 4 / 8 s,
## and are pushed back one cell.
static func mortal_spin(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		if e.target != c:
			continue
		hit(ctx, e, by_stars(c, [20, 40, 80, 160]))
		status(ctx, e, "poison", by_stars(c, [4000, 4000, 8000, 16000]))
		if e.alive:
			knock_back(sim, e, BattleBoard.orientation(c.cell, e.cell))
			e.cooldown = maxf(e.cooldown, 500.0)


## mountain-gale.ts: 1 / 3 / 5 icicles, every 0.2 s, on a random adjacent enemy (or the
## target): 40 SPECIAL and FLINCH 3 s. First cast: one more per Bergmite on its back.
static func mountain_gale(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var targets: Array = enemies_on(ctx, BattleBoard.adjacent_cells(c.cell))
	if not targets.has(t):
		targets.append(t)
	var bergmites := int(c.counters.get("bergmites", 0)) if c.cast_count == 1 else 0
	for i in int(by_stars(c, [1, 3, 5, 10])) + bergmites:
		var e: BattleUnit = targets[sim.rng.randi() % targets.size()]
		sim.schedule(200.0 * i, c, func() -> void:
			if not e.alive:
				return
			show(ctx, [e.cell])
			status(ctx, e, "flinch", 3000.0)
			hit(ctx, e, 40.0))


## mud-shot.ts: 25 / 50 / 100 SPECIAL and -10 / 20 / 30 SPEED (AP).
static func mud_shot(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [25, 50, 100, 200]))
	t.add_stat("speed", AbilityRunner.adjust_buff(c, t, -by_stars(c, [10, 20, 30, 40]) * (1.0 + c.ap / 100.0)))


## night-daze.ts: 25 / 50 / 100 SPECIAL and BLINDED 3 s.
static func night_daze(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [25, 50, 100, 200]))
	status(ctx, t, "blinded", 3000.0, true)


## night-shade.ts: 12.5 / 16.5 / 25% of the target max HP x (2 + AP/100) as TRUE.
static func night_shade(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var damage := ceilf(by_stars(c, [0.125, 0.165, 0.25, 0.35]) * t.max_hp * (2.0 + c.ap / 100.0))
	hit(ctx, t, damage, BattleUnit.DamageKind.TRUE, false)


## octolock.ts: 30 / 60 / 90 SPECIAL, LOCKED and ARMOR_BREAK 3 / 3 / 6 s.
static func octolock(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [30, 60, 90, 180]))
	var ms := by_stars(c, [3000, 3000, 6000, 10000])
	status(ctx, t, "locked", ms)
	status(ctx, t, "armor_reduction", ms)


## parabolic-charge.ts: heals 25 / 50 / 75, then 25 / 50 / 100 SPECIAL + the overheal.
static func parabolic_charge(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	var amount := by_stars(c, [25, 50, 75, 100])
	var over := maxf(0.0, amount + c.hp - c.max_hp)
	sim.heal(c, amount, c)
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [25, 50, 100, 200]) + over)


## poison-gas.ts: the 6 cells around: POISON_GAS on them, enemies take 15 / 30 / 60 SPECIAL
## and POISON 3 s.
static func poison_gas(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	board_effect(sim, cells, "POISON_GAS")
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [15, 30, 60, 120]))
		status(ctx, e, "poison", 3000.0)
#endregion


#region abilities (batch9)
## board.swapCells + moveTo: two units trade places (one may be null), shown as dashes.
static func swap_units(sim: BattleSim, a: Vector2i, b: Vector2i, kind := "dash") -> void:
	sim.swap_cells(a, b, kind)


## poison-jab.ts: 30 / 60 / 120 SPECIAL, POISON 3 s on the target and on itself, trades places.
static func poison_jab(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [30, 60, 120, 240]))
	status(ctx, t, "poison", 3000.0)
	sim.add_status(c, "poison", 3000.0, c)
	if t.alive and not t.has_item("HEAVY_DUTY_BOOTS"):
		swap_units(sim, c.cell, t.cell)
		c.cooldown = 100.0


## poison-sting.ts: 2 / 3 / 4 POISON stacks (4 s); every stack over the cap deals
## 25 / 50 / 100 SPECIAL.
static func poison_sting(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var tier := c.synergy_tier("POISON")
	var max_stacks := 5 if tier >= 3 else (4 if tier == 2 else 3)
	var stacks := int(by_stars(c, [2, 3, 4, 5]))
	var current := t.poison_stacks if t.has_status("poison") else 0
	var extra := maxi(0, current + stacks - max_stacks) * by_stars(c, [25, 50, 100, 150])
	for _i in stacks:
		sim.add_status(t, "poison", 4000.0, c)
	if extra > 0.0:
		hit(ctx, t, extra)


## poltergeist.ts: 30 / 60 / 120 SPECIAL, +20 per item of the target (+40 per tool).
static func poltergeist(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var damage := by_stars(c, [30, 60, 120, 240])
	for item in t.items:
		damage += 40.0 if GameData.item_in(item, "Tools") else 20.0
	hit(ctx, t, damage)


## powder-snow.ts: enemies on the line to the target: 20 / 40 / 80 SPECIAL, 15 / 30 / 50% FREEZE 2 s.
static func powder_snow(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := line_through(c, t)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [20, 40, 80, 160]))
		if sim.chance(by_stars(c, [0.15, 0.3, 0.5, 1.0]), c):
			status(ctx, e, "freeze", 2000.0)


## power-hug.ts: LOCKED and PARALYSIS 3 / 3 / 6 s, 40 / 80 / 160 SPECIAL.
static func power_hug(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var ms := by_stars(c, [3000, 3000, 6000, 10000])
	status(ctx, t, "locked", ms)
	status(ctx, t, "paralysis", ms)
	hit(ctx, t, by_stars(c, [40, 80, 160, 320]))


## protect.ts: PROTECT for 0.5 / 1.5 / 2.5 s x (2 + AP/100).
static func protect(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	show(ctx, [c.cell], "allies")
	ctx.sim.add_status(c, "protect", roundf(by_stars(c, [500, 1500, 2500, 4000]) * (2.0 + c.ap / 100.0)))


## psybeam.ts: enemies on the line to the target: 25 / 50 / 100 SPECIAL, 50% CONFUSION 2 / 3 / 4 s.
static func psybeam(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := line_through(c, t)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [25, 50, 100, 200]))
		if sim.chance(0.5, c):
			status(ctx, e, "confusion", by_stars(c, [2000, 3000, 4000, 5000]))


## psy-shock.ts: burns 20 / 40 / 80 PP (AP) of the target, gains as much SHIELD; the PP it
## did not have is dealt as SPECIAL damage.
static func psyshock(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var burn := by_stars(c, [20, 40, 80, 160]) * (1.0 + c.ap / 100.0)
	var stolen := t.drain_pp(burn)
	sim.add_shield(c, burn, c)
	if burn - stolen > 0.0:
		hit(ctx, t, burn - stolen, BattleUnit.DamageKind.SPECIAL, false)


## razor-wind.ts: 20 / 40 / 80 SPECIAL, can crit.
static func razor_wind(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [20, 40, 80, 160]), BattleUnit.DamageKind.SPECIAL, true,
		sim.chance(c.crit_chance / 100.0, c))


## roar.ts: 20 / 40 / 80 SPECIAL; the target is blown to the far end of the line, swapping
## places with (and hitting the enemies) on the way.
static func roar(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var damage := by_stars(c, [20, 40, 80, 160])
	show(ctx, [t.cell])
	hit(ctx, t, damage)
	if not t.alive or t.has_item("HEAVY_DUTY_BOOTS"):
		return
	var far: Variant = null
	for cell in ray_from(c.cell, BattleBoard.orientation(c.cell, t.cell)):
		var u := sim.board.get_unit(cell)
		if u == null:
			far = cell
		elif u != t:
			if u.team != c.team:
				hit(ctx, u, damage)
			if t.alive and u.alive:
				swap_units(sim, t.cell, u.cell, "knockback")
	if far != null and t.alive and sim.board.is_free(far):
		sim.move_unit(t, far, 250.0, "knockback")
	t.cooldown = maxf(t.cooldown, 500.0)
#endregion


#region abilities (batch10)
## pokemon.removeItem: drops an item mid-fight and takes back its flat stats.
static func take_item(u: BattleUnit, item: String) -> void:
	if not u.items.has(item):
		return
	u.items.erase(item)
	var stats: Dictionary = GameData.item_stats(item)
	for stat in stats:
		var v := float(stats[stat])
		if stat == "HP":
			u.max_hp = maxf(1.0, u.max_hp - v)
			u.hp = minf(u.hp, u.max_hp)
		elif stat != "SHIELD" and stat != "PP":
			u._add_item_stat(stat, -v)


## rock-head.ts: 120 / 120 / 150% of (ATK + DEF) as SPECIAL.
static func rock_head(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, roundf(by_stars(c, [1.2, 1.2, 1.5, 3.0]) * (c.atk + c.def)))


## rock-smash.ts: 25 / 50 / 100 SPECIAL and ARMOR_BREAK 3 / 6 / 9 s.
static func rock_smash(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [25, 50, 100, 200]))
	status(ctx, t, "armor_reduction", by_stars(c, [3000, 6000, 9000, 18000]))


## rock-tomb.ts: 30 / 60 / 120 SPECIAL and -10 / 20 / 40 SPEED.
static func rock_tomb(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [30, 60, 120, 240]))
	t.add_stat("speed", AbilityRunner.adjust_buff(c, t, -by_stars(c, [10, 20, 40, 80])))


## rock-wrecker.ts: FLINCH 2 s, 80 / 160 / 320 SPECIAL, then FATIGUE 4 s on itself.
static func rock_wrecker(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	status(ctx, t, "flinch", 2000.0)
	hit(ctx, t, by_stars(c, [80, 160, 320, 640]))
	ctx.sim.add_status(c, "fatigue", 4000.0, c)


## rollout.ts: +2 / 5 / 10 DEF (AP), then 200% DEF as SPECIAL.
static func rollout(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	c.add_stat("def", by_stars(c, [2, 5, 10, 20]) * (1.0 + c.ap / 100.0))
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, 2.0 * c.def)


## sand-spit.ts: the cells in front of it: 30 / 60 / 120 SPECIAL and BLINDED 2 s.
static func sand_spit(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.cells_in_front(c.cell, t.cell, 1)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [30, 60, 120, 240]))
		status(ctx, e, "blinded", 2000.0)


## sand-tomb.ts: PARALYSIS and SILENCE 3 / 5 / 8 s, 10 / 20 / 40 SPECIAL.
static func sand_tomb(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var ms := by_stars(c, [3000, 5000, 8000, 16000])
	status(ctx, t, "paralysis", ms)
	status(ctx, t, "silence", ms)
	hit(ctx, t, by_stars(c, [10, 20, 40, 80]))


## screech.ts: enemies within 2 cells: -2 / 4 / 8 DEF (AP).
static func screech(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.cells_in_radius(c.cell, 2)
	var foes := enemies_on(ctx, cells)
	show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	for e in foes:
		e.add_stat("def", AbilityRunner.adjust_buff(c, e, -by_stars(c, [2, 4, 8, 16]) * (1.0 + c.ap / 100.0)))


## shadow-clone.ts: a copy of itself appears on the closest free cell with 50 / 50 / 90% of its
## max HP (AP) and holding an item stolen from the target.
static func shadow_clone(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	var stolen := ""
	if t != null:
		var takeable: Array = t.items.filter(func(i: String) -> bool:
			return not GameData.item_in(i, "AbsorbedItems"))
		if not takeable.is_empty():
			stolen = takeable[sim.rng.randi() % takeable.size()]
			take_item(t, stolen)
	var clone := _summon(sim, c.pkm, c.team, c.cell)
	if clone == null:
		return
	clone.max_hp = maxf(1.0, ceilf(by_stars(c, [0.5, 0.5, 0.9, 1.0]) * c.max_hp * (1.0 + c.ap / 100.0)))
	clone.hp = clone.max_hp
	if stolen != "":
		clone.equip([stolen])
	show(ctx, [clone.cell], "allies")


## shadow-punch.ts: teleports next to the enemy with the lowest HP %, its next attack deals
## 30 / 60 / 120 more SPECIAL (AP).
static func shadow_punch(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var foes := sim.enemies_of(c)
	if foes.is_empty():
		return
	foes.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.hp_ratio() < b.hp_ratio())
	var weakest: BattleUnit = foes[0]
	var dest: Variant = sim.closest_free_cell_near(weakest.cell, weakest.team)
	if dest != null:
		sim.move_unit(c, dest, 200.0, "dash")
		c.target = weakest
	c.effects.next_attack_special = ceilf(by_stars(c, [30, 60, 120, 240]) * (1.0 + c.ap / 100.0))
	show(ctx, [weakest.cell])
#endregion


#region abilities (batch11)
## shell-smash.ts: adjacent enemies take 15 / 30 / 60 SPECIAL; itself +20 AP, +2 ATK, +20 SPEED,
## -2 DEF, -2 SPE_DEF.
static func shell_smash(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [15, 30, 60, 120]))
	c.add_stat("ap", 20.0)
	c.add_stat("atk", 2.0)
	c.add_stat("speed", 20.0)
	c.add_stat("def", -2.0)
	c.add_stat("speDef", -2.0)


## shore-up.ts: heals 20 / 25 / 40% of its max HP (+10% in SANDSTORM, AP).
static func shore_up(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var factor := by_stars(c, [0.2, 0.25, 0.4, 0.8])
	if sim.weather == "SANDSTORM":
		factor += 0.1
	show(ctx, [c.cell], "allies")
	sim.heal(c, factor * c.max_hp * (1.0 + c.ap / 100.0), c)


## silk-trap.ts: PROTECT 1.5 s; melee attackers meanwhile lose 5 / 10 / 15 SPEED (AP) and get
## PARALYSIS 1.5 s (ItemEffects.on_attack_received).
static func silk_trap(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	show(ctx, [c.cell], "allies")
	sim.add_status(c, "protect", 1500.0)
	c.effects.silk_until = sim.time_ms + 1500.0
	c.effects.silk_speed = by_stars(c, [5, 10, 15, 30]) * (1.0 + c.ap / 100.0)


## sludge.ts: enemies in front of it get 2 / 3 / 4 POISON stacks for 3 s (AP).
static func sludge(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.cells_in_front(c.cell, t.cell, 1)
	show(ctx, cells)
	var ms := roundf(by_stars(c, [3000, 3000, 3000, 10000]) * (1.0 + c.ap / 100.0))
	for e in enemies_on(ctx, cells):
		for _i in int(by_stars(c, [2, 3, 4, 8])):
			sim.add_status(e, "poison", ms, c)


## smog.ts: SMOKE on the cells in front of it, enemies there take 10 / 20 / 40 SPECIAL.
static func smog(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.cells_in_front(c.cell, t.cell, 1)
	show(ctx, cells)
	board_effect(sim, cells, "SMOKE")
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [10, 20, 40, 80]))


## solar-beam.ts: enemies on the line to the target: BURN 3 s and 25 / 50 / 100 SPECIAL
## (x1.3 and +20 PP in ZENITH or on the light cell).
static func solar_beam(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var damage := by_stars(c, [25, 50, 100, 200])
	if sim.weather == "ZENITH" or c.effects.get("spotlight", false):
		damage *= 1.3
		c.add_pp(20.0)
	var cells := line_through(c, t)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		status(ctx, e, "burn", 3000.0)
		hit(ctx, e, damage)


## solar-blade.ts: charges 2 s (none on the light cell), then the cells in front of it take
## 30 / 60 / 120 TRUE damage.
static func solar_blade(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var lit: bool = c.effects.get("spotlight", false)
	var strike := func() -> void:
		if not c.alive:
			return
		var aim := t.cell if t.alive else BattleBoard.step(c.cell, c.facing)
		var cells := BattleBoard.cells_in_front(c.cell, aim, 1)
		show(ctx, cells)
		for e in enemies_on(ctx, cells):
			hit(ctx, e, by_stars(c, [30, 60, 120, 240]), BattleUnit.DamageKind.TRUE)
	if lit:
		strike.call()
	else:
		c.cooldown = 2000.0
		show(ctx, [c.cell], "allies")
		sim.schedule(2000.0, c, strike)


## spark.ts: 30 / 60 / 90 SPECIAL, then bounces every 0.25 s to an adjacent unit of the
## target's team not hit yet, halving the damage each time (10 bounces max).
static func spark(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var damage := by_stars(c, [30, 60, 90, 180])
	var hit_ids := {}
	show(ctx, [t.cell])
	hit(ctx, t, damage)
	var propagate := func(self_ref: Callable, from: BattleUnit, bounce: int) -> void:
		var next: BattleUnit = null
		for cell in BattleBoard.adjacent_cells(from.cell):
			var u := sim.board.get_unit(cell)
			if u != null and u.alive and u.team == t.team and not hit_ids.has(u.id):
				next = u
				break
		if next == null:
			return
		hit_ids[next.id] = true
		sim.schedule(250.0, c, func() -> void:
			if not next.alive:
				return
			show(ctx, [next.cell])
			hit(ctx, next, ceilf(damage / pow(2.0, bounce)))
			if bounce < 10:
				self_ref.call(self_ref, next, bounce + 1))
	propagate.call(propagate, t, 1)


## spicy-extract.ts: its 1 / 2 / 3 closest allies get RAGE for 2 s (AP).
static func spicy_extract(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies := sim.allies_of(c)
	allies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		var here := BattleBoard.center(c.cell)
		return BattleBoard.center(a.cell).distance_to(here) < BattleBoard.center(b.cell).distance_to(here))
	allies = allies.slice(0, int(by_stars(c, [1, 2, 3, 6])))
	show(ctx, allies.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
	for a in allies:
		sim.add_status(a, "enraged", 2000.0 * (1.0 + c.ap / 100.0), c)


## spikes.ts: 6 (AP) random cells up to 3 in front of it get SPIKES; enemies there take
## 25 / 50 / 100 SPECIAL.
static func spikes(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells: Array = pick_random(sim, BattleBoard.cells_in_front(c.cell, t.cell, 3),
		int(roundf(6.0 * (1.0 + c.ap / 100.0))))
	show(ctx, cells)
	board_effect(sim, cells, "SPIKES")
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [25, 50, 100, 200]))
#endregion


#region abilities (batch12)
## spite.ts: drains 20 / 40 / 60 PP (AP) from the target, shared among its adjacent allies.
static func spite(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var k := 1.0 + c.ap / 100.0
	var drain := by_stars(c, [20, 40, 60, 100])
	show(ctx, [t.cell])
	t.drain_pp(drain * k)
	var allies: Array[BattleUnit] = []
	for cell in BattleBoard.adjacent_cells(c.cell):
		var a := sim.board.get_unit(cell)
		if a != null and a.alive and a.team == c.team:
			allies.append(a)
	show(ctx, allies.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
	for a in allies:
		a.add_pp(drain / allies.size() * k)


## sticky-web.ts: 20 / 35 / 70 SPECIAL, STICKY_WEB on the cells in front of it.
static func sticky_web(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.cells_in_front(c.cell, t.cell, 1)
	show(ctx, cells)
	hit(ctx, t, by_stars(c, [20, 35, 70, 140]))
	board_effect(sim, cells, "STICKY_WEB")


## stone-edge.ts: for 5 / 8 / 10 s: SILENCE on itself, +20% crit chance (AP) and +2 range.
static func stone_edge(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if c.effects.get("stone_edge", false):
		return
	var ms := by_stars(c, [5000, 8000, 10000, 10000])
	var crit := 20.0 * (1.0 + c.ap / 100.0)
	show(ctx, [c.cell], "allies")
	sim.add_status(c, "silence", ms, c)
	c.effects.stone_edge = true
	c.add_stat("critChance", crit)
	c.attack_range += 2
	sim.schedule(ms, c, func() -> void:
		c.add_stat("critChance", -crit)
		c.attack_range = maxi(c.base_range, c.attack_range - 2)
		c.effects.erase("stone_edge"))


## stuff-cheeks.ts: eats a held berry, its heals become SHIELD; else forages a random berry
## (kept after the fight).
static func stuff_cheeks(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var held: Array = c.items.filter(func(i: String) -> bool: return GameData.item_in(i, "Berries"))
	show(ctx, [c.cell], "allies")
	if not held.is_empty():
		SynergyItems.eat_berry(sim, c, held[sim.rng.randi() % held.size()], true)
		return
	var berries := GameData.items_in("NonSpecialBerries")
	if berries.is_empty() or c.items.size() >= BattleUnit.MAX_ITEMS:
		return
	var berry: String = berries[sim.rng.randi() % berries.size()]
	c.equip([berry])
	if c.owned != null and c.owned.items.size() < BattleUnit.MAX_ITEMS:
		c.owned.items.append(berry)
	sim.emit({"type": "item", "unit": c, "item": berry, "text": GameData.item_name(berry)})


## supercell-slam.ts: 10 / 20 / 40 SHIELD (AP), rushes to the free cell with the most enemies
## around, which take 10 / 20 / 40 SPECIAL.
static func supercell_slam(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	sim.add_shield(c, by_stars(c, [10, 20, 40, 80]) * (1.0 + c.ap / 100.0), c)
	var dest: Variant = null
	var best := 0
	for cell in sim.board.free_cells():
		var n := enemies_on(ctx, BattleBoard.adjacent_cells(cell)).size()
		if n > best:
			best = n
			dest = cell
	if dest == null:
		return
	sim.move_unit(c, dest, 250.0, "dash")
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [10, 20, 40, 80]))


## super-fang.ts: 10 / 15 / 25% of the target max HP x (2 + AP/100) as TRUE.
static func super_fang(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var damage := ceilf(by_stars(c, [0.1, 0.15, 0.25, 0.35]) * t.max_hp * (2.0 + c.ap / 100.0))
	hit(ctx, t, damage, BattleUnit.DamageKind.TRUE, false)


## swagger.ts: CONFUSION and RAGE 1.5 / 2 / 3 s (AP) on the target.
static func swagger(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var ms := roundf(by_stars(c, [1500, 2000, 3000, 5000]) * (1.0 + c.ap / 100.0))
	status(ctx, t, "confusion", ms)
	status(ctx, t, "enraged", ms)


## swallow.ts: stockpiles (+3 DEF and SPE_DEF); under 25% HP swallows (heals 20 / 40% max HP
## per stack, AP); at 3 stacks spits up: 40 / 80 / 150 SPECIAL in front of it.
static func swallow(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	var stacks := c.cast_count - int(c.effects.get("swallow_reset", 0))
	if c.hp < c.max_hp * 0.25 and stacks > 0:
		show(ctx, [c.cell], "allies")
		sim.heal(c, [0.0, 20.0, 40.0, 60.0][mini(stacks, 3)] * c.max_hp / 100.0 * (1.0 + c.ap / 100.0), c)
		c.effects.swallow_reset = c.cast_count
	elif stacks >= 3:
		c.effects.swallow_reset = c.cast_count
		if t == null:
			return
		var cells := BattleBoard.cells_in_front(c.cell, t.cell, 1)
		show(ctx, cells)
		for e in enemies_on(ctx, cells):
			hit(ctx, e, by_stars(c, [40, 80, 150, 300]))
	else:
		c.add_stat("def", 3.0)
		c.add_stat("speDef", 3.0)


## tailwind.ts: every ally +5 / 10 / 15 SPEED (AP).
static func tailwind(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies := sim.alive_units(c.team)
	show(ctx, allies.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
	for a in allies:
		a.add_stat("speed", by_stars(c, [5, 10, 15, 30]) * (1.0 + c.ap / 100.0))


## tea-time.ts: every ally heals 15 / 30 / 60 (AP) and eats its first berry.
static func tea_time(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies := sim.alive_units(c.team)
	show(ctx, allies.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
	for a in allies:
		sim.heal(a, by_stars(c, [15, 30, 60, 120]) * (1.0 + c.ap / 100.0), c)
		for item in a.items:
			if GameData.item_in(item, "Berries"):
				SynergyItems.eat_berry(sim, a, item)
				break
#endregion


#region abilities (batch13)
## thief.ts: steals every item of the target (as many as it can hold), then 15 / 30 / 60 SPECIAL.
static func thief(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	for item in t.items.duplicate():
		if c.items.size() >= BattleUnit.MAX_ITEMS or GameData.item_in(item, "AbsorbedItems"):
			break
		take_item(t, item)
		c.equip([item])
	hit(ctx, t, by_stars(c, [15, 30, 60, 120]))


## thrash.ts: +100 / 100 / 120% BASE ATK (AP), CONFUSION 3 s on itself.
static func thrash(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	show(ctx, [c.cell], "allies")
	c.add_stat("atk", floorf(by_stars(c, [1.0, 1.0, 1.2, 1.5]) * c.base_atk) * (1.0 + c.ap / 100.0))
	ctx.sim.add_status(c, "confusion", 3000.0, c)


## thunder-fang.ts: PARALYSIS 3 s and 30 / 60 / 120 SPECIAL.
static func thunder_fang(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	status(ctx, t, "paralysis", 3000.0)
	hit(ctx, t, by_stars(c, [30, 60, 120, 240]))


## topsy-turvy.ts: 0.5 s later, 40 / 80 / 160 SPECIAL and the target's ATK, AP, DEF and
## SPE_DEF changes are turned upside down.
static func topsy_turvy(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	sim.schedule(500.0, c, func() -> void:
		if not t.alive:
			return
		hit(ctx, t, by_stars(c, [40, 80, 160, 320]))
		t.add_stat("atk", -2.0 * (t.atk - t.base_atk))
		t.add_stat("ap", -2.0 * t.ap)
		t.add_stat("def", -2.0 * (t.def - t.base_def))
		t.add_stat("speDef", -2.0 * (t.spe_def - t.base_spe_def)))


## toxic.ts: its 1 / 2 / 3 closest enemies are POISONED for 1.5 / 3 / 4.5 s x (2 + AP/100).
static func toxic(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var foes := sim.enemies_of(c)
	foes.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return BattleBoard.distance_m(a.cell, c.cell) < BattleBoard.distance_m(b.cell, c.cell))
	foes = foes.slice(0, int(by_stars(c, [1, 2, 3, 4])))
	show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	var ms := roundf(by_stars(c, [1500, 3000, 4500, 9000]) * (2.0 + c.ap / 100.0))
	for e in foes:
		sim.add_status(e, "poison", ms, c)


## trick-or-treat.ts: steals a random item of the target; if it has none, the target turns
## into a Magikarp (SPLASH, ATK / DEF / SPE_DEF 1) for 3 / 3 / 10 s (AP).
static func trick_or_treat(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	if not t.items.is_empty():
		var item: String = t.items[sim.rng.randi() % t.items.size()]
		take_item(t, item)
		if c.items.size() < BattleUnit.MAX_ITEMS:
			c.equip([item])
		return
	if t.effects.get("trick_or_treat", false):
		return
	var saved := {"ability": t.ability_id, "atk": t.atk, "def": t.def, "spe_def": t.spe_def, "pkm": t.pkm}
	t.effects.trick_or_treat = true
	t.ability_id = "SPLASH"
	t.atk = 1.0
	t.def = 1.0
	t.spe_def = 1.0
	if GameData.pokemon.has("MAGIKARP"):
		t.pkm = "MAGIKARP"
		sim.emit({"type": "transform", "unit": t})
	sim.schedule(roundf(by_stars(c, [3000, 3000, 10000, 30000]) * (1.0 + c.ap / 100.0)), t, func() -> void:
		t.ability_id = saved.ability
		t.atk = saved.atk
		t.def = saved.def
		t.spe_def = saved.spe_def
		t.effects.erase("trick_or_treat")
		if t.pkm != saved.pkm:
			t.pkm = saved.pkm
			sim.emit({"type": "transform", "unit": t}))


## triple-dive.ts: dives, every 0.4 s, next to each of the 3 enemies with the lowest HP:
## 15 / 30 / 60 SPECIAL.
static func triple_dive(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var foes := sim.enemies_of(c)
	foes.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.hp < b.hp)
	foes = foes.slice(0, 3)
	for i in foes.size():
		var e: BattleUnit = foes[i]
		sim.schedule(400.0 * i, c, func() -> void:
			if not e.alive:
				return
			var dest: Variant = sim.closest_free_cell_near(e.cell, e.team)
			if dest != null:
				sim.move_unit(c, dest, 200.0, "dash")
			show(ctx, [e.cell])
			hit(ctx, e, by_stars(c, [15, 30, 60, 120])))


## twineedle.ts: 25 / 50 / 80 SPECIAL twice (the first can crit), the second 0.5 s later with
## 50% POISON 4 s.
static func twineedle(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var damage := by_stars(c, [25, 50, 80, 160])
	show(ctx, [t.cell])
	hit(ctx, t, damage, BattleUnit.DamageKind.SPECIAL, true, sim.chance(c.crit_chance / 100.0, c))
	sim.schedule(500.0, c, func() -> void:
		if not t.alive:
			return
		hit(ctx, t, damage)
		if sim.chance(0.5, c):
			status(ctx, t, "poison", 4000.0))


## twin-beam.ts: two beams toward the farthest enemy and the enemy farthest from that one:
## 30 / 60 / 100 SPECIAL to the enemies on each line.
static func twin_beam(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var first := sim.farthest_enemy(c)
	if first == null:
		return
	var second: BattleUnit = null
	var best := -1
	for e in sim.enemies_of(c):
		var d := BattleBoard.distance_m(first.cell, e.cell)
		if e != first and d > best:
			best = d
			second = e
	var damage := by_stars(c, [30, 60, 100, 200])
	for aim in [first, second]:
		if aim == null:
			continue
		var cells := line_through(c, aim)
		show(ctx, cells)
		for e in enemies_on(ctx, cells):
			hit(ctx, e, damage)


## vine-whip.ts: PARALYSIS 3 s on the target and the units of its team around it,
## 30 / 60 / 100 SPECIAL to the target.
static func vine_whip(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var victims: Array[BattleUnit] = [t]
	for cell in BattleBoard.adjacent_cells(t.cell):
		var u := sim.board.get_unit(cell)
		if u != null and u.alive and u.team == t.team:
			victims.append(u)
	show(ctx, victims.map(func(u: BattleUnit) -> Vector2i: return u.cell))
	for u in victims:
		status(ctx, u, "paralysis", 3000.0)
	hit(ctx, t, by_stars(c, [30, 60, 100, 200]))
#endregion


#region abilities (batch14)
## vise-grip.ts: LOCKED 4 s on both, 30 / 60 / 100 SPECIAL; for 4 s it gains the DEF and
## SPE_DEF of the target (AP).
static func vise_grip(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	status(ctx, t, "locked", 4000.0)
	sim.add_status(c, "locked", 4000.0, c)
	hit(ctx, t, by_stars(c, [30, 60, 100, 200]))
	var k := 1.0 + c.ap / 100.0
	var def_gain := t.def * k
	var spe_gain := t.spe_def * k
	c.add_stat("def", def_gain)
	c.add_stat("speDef", spe_gain)
	sim.schedule(4000.0, c, func() -> void:
		c.add_stat("def", -def_gain)
		c.add_stat("speDef", -spe_gain))


## waterfall.ts: 50 / 100 / 150 SHIELD (AP), cleanses its negative statuses and the board
## effects of its cell.
static func waterfall(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	show(ctx, [c.cell], "allies")
	sim.add_shield(c, by_stars(c, [50, 100, 150, 300]) * (1.0 + c.ap / 100.0), c)
	c.cleanse()
	if sim.board_effects.has(c.cell):
		sim.board_effects.erase(c.cell)
		sim.emit({"type": "board_effect", "cells": [] as Array[Vector2i], "effect": ""})


## water-pulse.ts: the target and the units of its team around: 70 / 140 / 280 SPECIAL,
## 30% CONFUSION 2 s.
static func water_pulse(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.adjacent_cells(t.cell, true)
	show(ctx, cells)
	for cell in cells:
		var u := sim.board.get_unit(cell)
		if u == null or not u.alive or u.team != t.team:
			continue
		if sim.chance(0.3, c):
			status(ctx, u, "confusion", 2000.0)
		hit(ctx, u, by_stars(c, [70, 140, 280, 500]))


## whirlwind.ts: blows the target away to a far cell, then 40 / 80 / 120 SPECIAL.
static func whirlwind(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	if not t.has_item("HEAVY_DUTY_BOOTS"):
		var dest: Variant = AbilityRunner.fly_away_cell(sim, t)
		if dest != null:
			sim.move_unit(t, dest, 300.0, "knockback")
	hit(ctx, t, by_stars(c, [40, 80, 120, 240]))


## wonder-room.ts: for 5 s, enemies around the target swap DEF and SPE_DEF and the attacks
## they receive become SPECIAL (BattleSim.attack_hit / deal_damage).
static func wonder_room(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.adjacent_cells(t.cell, true)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		e.effects.wonder_room_until = sim.time_ms + 5000.0


## wood-hammer.ts: 0.5 s later 400 / 400 / 800% ATK as SPECIAL, and its ATK as recoil
## (none with Protective Pads).
static func wood_hammer(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var damage := by_stars(c, [4, 4, 8, 16]) * c.atk
	var recoil := c.atk
	show(ctx, [t.cell])
	sim.schedule(500.0, c, func() -> void:
		if t.alive:
			hit(ctx, t, damage)
		if c.alive and not c.has_item("PROTECTIVE_PADS"):
			sim.deal_damage(c, recoil, BattleUnit.DamageKind.PHYSICAL, c, false, false, false))


## wise-yawn.ts: the ally with the lowest HP gains 15 / 30 / 60 SHIELD (AP); the enemies
## targeting it get FATIGUE 3 s and -20 AP.
static func wise_yawn(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies := sim.alive_units(c.team)
	if allies.is_empty():
		return
	allies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.hp < b.hp)
	var weakest: BattleUnit = allies[0]
	_yawn(ctx, weakest)


## yawn.ts: the enemies targeting it get FATIGUE 3 s and -20 AP; it gains 15 / 30 / 60 SHIELD
## (AP) and acts again 1 s later.
static func yawn(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	_yawn(ctx, c)
	c.cooldown = 1000.0


static func _yawn(ctx: Dictionary, protected: BattleUnit) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	show(ctx, [protected.cell], "allies")
	for e in sim.enemies_of(c):
		if e.target == protected:
			sim.add_status(e, "fatigue", 3000.0, c)
			e.add_stat("ap", AbilityRunner.adjust_buff(c, e, -20.0))
	sim.add_shield(protected, by_stars(c, [15, 30, 60, 120]) * (1.0 + c.ap / 100.0), c)
#endregion


#region abilities (batch15)
## getNearestAllies + getStrongestUnit: the strongest of the closest allies (random tie).
static func strongest_nearest_ally(sim: BattleSim, c: BattleUnit) -> BattleUnit:
	var nearest: Array[BattleUnit] = []
	var best := 999
	for a in sim.allies_of(c):
		var d := BattleBoard.distance_c(c.cell, a.cell)
		if d < best:
			nearest = [a]
			best = d
		elif d == best:
			nearest.append(a)
	if nearest.is_empty():
		return null
	var top := -INF
	for a in nearest:
		top = maxf(top, a.unit_score())
	var tied := nearest.filter(func(a: BattleUnit) -> bool: return a.unit_score() == top)
	return tied[sim.rng.randi() % tied.size()]


## after-you.ts: the strongest closest ally gains 5 / 10 / 15 PP and 5 / 10 / 15 SPEED (AP).
static func after_you(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var a := strongest_nearest_ally(ctx.sim, c)
	if a == null:
		return
	var k := 1.0 + c.ap / 100.0
	show(ctx, [a.cell], "allies")
	a.add_pp(by_stars(c, [5, 10, 15, 30]) * k)
	a.add_stat("speed", by_stars(c, [5, 10, 15, 20]) * k)


## anchor-shot.ts: drags the farthest enemy to a free cell next to it: 20 / 40 / 80 SPECIAL.
static func anchor_shot(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var far := sim.farthest_enemy(c)
	if far == null:
		return
	var free: Array = BattleBoard.adjacent_cells(c.cell).filter(func(cell: Vector2i) -> bool:
		return sim.board.is_free(cell))
	if free.is_empty():
		return
	show(ctx, [far.cell])
	if not far.has_item("HEAVY_DUTY_BOOTS"):
		sim.move_unit(far, free[sim.rng.randi() % free.size()], 300.0, "knockback")
	hit(ctx, far, by_stars(c, [20, 40, 80, 160]))
	far.cooldown = minf(far.cooldown, 750.0)


## apple-acid.ts: enemies in front of it take 15 / 30 / 50 SPECIAL (doubled if SPE_DEF is 0).
static func apple_acid(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.cells_in_front(c.cell, t.cell, 1)
	show(ctx, cells)
	var damage := by_stars(c, [15, 30, 50, 100])
	for e in enemies_on(ctx, cells):
		hit(ctx, e, damage * 2.0 if e.spe_def <= 0.0 else damage)


## armor-cannon.ts: 0.3 s later 15 / 30 / 50 SPECIAL to the target, the shot bounces to the
## 2 enemies closest to it (15 / 30 / 50 each) and back to the target (6 / 12 / 25 each).
static func armor_cannon(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	sim.schedule(300.0, c, func() -> void:
		if not t.alive:
			return
		hit(ctx, t, by_stars(c, [15, 30, 50, 100]))
		var others: Array = sim.enemies_of(c).filter(func(e: BattleUnit) -> bool: return e != t)
		others.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
			return BattleBoard.distance_m(a.cell, c.cell) < BattleBoard.distance_m(b.cell, c.cell))
		for tg in others.slice(0, 2):
			sim.schedule(300.0, c, func() -> void:
				if tg.alive:
					show(ctx, [tg.cell])
					hit(ctx, tg, by_stars(c, [15, 30, 50, 100]))
				sim.schedule(300.0, c, func() -> void:
					if t.alive:
						hit(ctx, t, by_stars(c, [6, 12, 25, 50])))))


## aura-wheel.ts: Morpeko switches mode (Full Belly / Hangry), +10 SPEED, 20 / 40 / 60 SPECIAL,
## acts again 0.5 s later.
static func aura_wheel(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	var other := "MORPEKO_HANGRY" if c.pkm == "MORPEKO" else ("MORPEKO" if c.pkm == "MORPEKO_HANGRY" else "")
	if other != "" and GameData.pokemon.has(other):
		c.pkm = other
		sim.emit({"type": "transform", "unit": c})
	c.add_stat("speed", 10.0)
	if t != null:
		show(ctx, [t.cell])
		hit(ctx, t, by_stars(c, [20, 40, 60, 120]))
	c.cooldown = 500.0


## bared-fangs.ts: 120 / 140 / 160% ATK as SPECIAL, steals 10 SPEED (AP) unless Twist Band.
static func bared_fangs(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, roundf(c.atk * by_stars(c, [1.2, 1.4, 1.6, 3.2])))
	if not t.has_item("TWIST_BAND"):
		var steal := 10.0 * (1.0 + c.ap / 100.0)
		t.add_stat("speed", -steal)
		c.add_stat("speed", steal)


## bide.ts: for 3 s it gains no PP and stores the damage received; then adjacent enemies take
## 100 / 150 / 200% of it as SPECIAL.
static func bide(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if c.effects.has("bide_damage"):
		return
	show(ctx, [c.cell], "allies")
	c.effects.bide_damage = 0.0
	c.effects.no_pp_gain = true
	sim.schedule(3000.0, c, func() -> void:
		var stored: float = c.effects.get("bide_damage", 0.0)
		c.effects.erase("bide_damage")
		c.effects.erase("no_pp_gain")
		if not c.alive:
			return
		var cells := BattleBoard.adjacent_cells(c.cell)
		show(ctx, cells)
		for e in enemies_on(ctx, cells):
			hit(ctx, e, by_stars(c, [1.0, 1.5, 2.0, 4.0]) * stored))


## bitter-blade.ts: adjacent enemies take 50 / 60 / 70 SPECIAL, heals 10% max HP per enemy hit.
static func bitter_blade(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	var foes := enemies_on(ctx, cells)
	for e in foes:
		hit(ctx, e, by_stars(c, [50, 60, 70, 140]))
	if not foes.is_empty():
		sim.heal(c, c.max_hp * 0.1 * foes.size(), c)


## bolt-beak.ts: 0.25 s later 20 / 40 / 80 SPECIAL (doubled if the target has over 40 PP).
static func bolt_beak(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	sim.schedule(250.0, c, func() -> void:
		if t.alive:
			var damage := by_stars(c, [20, 40, 80, 160])
			hit(ctx, t, damage * 2.0 if t.pp > t.web_pp(40.0) else damage))


## boomburst.ts: every adjacent unit (allies too) takes 60 SPECIAL and FLINCH 4 s.
static func boomburst(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells, "all")
	for cell in cells:
		var u := sim.board.get_unit(cell)
		if u != null and u.alive:
			hit(ctx, u, by_stars(c, [60, 60, 60, 120]))
			status(ctx, u, "flinch", 4000.0)
#endregion


#region abilities (batch16)
## Closest enemy of `team`'s foes to a cell (board.getClosestEnemy), random among ties.
static func closest_unit_of(sim: BattleSim, cell: Vector2i, team: int) -> BattleUnit:
	var best: Array[BattleUnit] = []
	var best_d := 999
	for u in sim.alive_units(team):
		var d := BattleBoard.distance_c(cell, u.cell)
		if d < best_d:
			best_d = d
			best = [u]
		elif d == best_d:
			best.append(u)
	return best[sim.rng.randi() % best.size()] if not best.is_empty() else null


## bounce.ts: 1 / 2 / 3 bounces, every 0.5 s, next to the farthest enemy: adjacent enemies take
## 15 / 20 / 25 SPECIAL.
static func bounce(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	for i in int(by_stars(c, [1, 2, 3, 4])):
		sim.schedule(500.0 * i, c, func() -> void:
			var spot := sim.farthest_spot(c)
			if spot.is_empty():
				return
			sim.move_unit(c, spot.cell, 300.0, "dash")
			var cells := BattleBoard.adjacent_cells(spot.cell)
			show(ctx, cells)
			for e in enemies_on(ctx, cells):
				hit(ctx, e, by_stars(c, [15, 20, 25, 30])))


## camouflage.ts: heals 15 / 25 / 35 x (2 + AP/100) and copies the look of the target, the
## best of their ATK / DEF / SPE_DEF and its range.
static func camouflage(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	sim.heal(c, by_stars(c, [15, 25, 35, 70]) * (2.0 + c.ap / 100.0), c)
	if t == null or t.inanimate:
		return
	show(ctx, [t.cell])
	sim.emit({"type": "transform", "unit": c, "pkm": t.pkm})
	c.atk = maxf(c.atk, t.atk)
	c.def = maxf(c.def, t.def)
	c.spe_def = maxf(c.spe_def, t.spe_def)
	c.attack_range = t.attack_range


## charm.ts: -2 / 3 / 4 ATK (AP) and CHARM 3 s on the target.
static func charm(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	t.add_stat("atk", AbilityRunner.adjust_buff(c, t, -by_stars(c, [2, 3, 4, 8]) * (1.0 + c.ap / 100.0)))
	status(ctx, t, "charm", 3000.0)


## chatter.ts: enemies within 3 cells take 10 / 20 / 30 SPECIAL, 50% CONFUSION 1 s.
static func chatter(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.cells_in_radius(c.cell, 3)
	var foes := enemies_on(ctx, cells)
	show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	for e in foes:
		hit(ctx, e, by_stars(c, [10, 20, 30, 60]))
		if sim.chance(0.5, c):
			status(ctx, e, "confusion", 1000.0)


## close-combat.ts: -2 DEF and SPE_DEF on itself, 30 / 65 / 130 SPECIAL.
static func close_combat(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	c.add_stat("def", -2.0)
	c.add_stat("speDef", -2.0)
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [30, 65, 130, 260]))


## cosmic-power-moon.ts: every other ally +25 AP (AP).
static func cosmic_power_moon(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies := sim.allies_of(c)
	show(ctx, allies.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
	for a in allies:
		a.add_stat("ap", by_stars(c, [25, 25, 25, 50]) * (1.0 + c.ap / 100.0))


## cosmic-power-sun.ts: every other ally +25% BASE ATK (AP).
static func cosmic_power_sun(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies := sim.allies_of(c)
	show(ctx, allies.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
	for a in allies:
		a.add_stat("atk", by_stars(c, [0.25, 0.25, 0.25, 0.5]) * a.base_atk * (1.0 + c.ap / 100.0))


## cotton-guard.ts: 15 / 30 / 60 SHIELD and +3 DEF (AP); COTTON_BALL in front of it, enemies
## there SLEEP 1 s.
static func cotton_guard(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	var k := 1.0 + c.ap / 100.0
	sim.add_shield(c, by_stars(c, [15, 30, 60, 120]) * k, c)
	c.add_stat("def", 3.0 * k)
	if t == null:
		return
	var cells := BattleBoard.cells_in_front(c.cell, t.cell, 1)
	show(ctx, cells)
	board_effect(sim, cells, "COTTON_BALL")
	for e in enemies_on(ctx, cells):
		status(ctx, e, "sleep", 1000.0)


## decorate.ts: the strongest closest ally +1 / 2 / 3 ATK and +10 / 20 / 30 AP (AP), plus the
## bonus of the Alcremie flavor.
static func decorate(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var a := strongest_nearest_ally(sim, c)
	if a == null:
		return
	var k := 1.0 + c.ap / 100.0
	show(ctx, [a.cell], "allies")
	a.add_stat("atk", by_stars(c, [1, 2, 3, 6]) * k)
	a.add_stat("ap", by_stars(c, [10, 20, 30, 60]) * k)
	match c.pkm:
		"ALCREMIE_VANILLA": sim.add_shield(a, 80.0 * k, c)
		"ALCREMIE_RUBY": a.add_stat("speed", 30.0 * k)
		"ALCREMIE_MATCHA": a.add_stat("maxHP", 60.0 * k)
		"ALCREMIE_MINT":
			sim.heal(a, 40.0 * k, c)
			a.add_stat("speDef", 15.0 * k)
		"ALCREMIE_LEMON": a.add_stat("critChance", 40.0 * k)
		"ALCREMIE_SALTED":
			sim.heal(a, 40.0 * k, c)
			a.add_stat("def", 15.0 * k)
		"ALCREMIE_RUBY_SWIRL": a.add_stat("atk", 10.0 * k)
		"ALCREMIE_CARAMEL_SWIRL": a.add_stat("critPower", 0.8 * k)
		"ALCREMIE_RAINBOW_SWIRL": a.add_pp(50.0 * k)


## deep-freeze.ts: 5 / 7 / 9 ice bolts, every 0.33 s: 10 SPECIAL and -1 SPE_DEF; when the
## target faints, the bolts chain to the enemy closest to it.
static func deep_freeze(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var state := {"target": t, "left": int(by_stars(c, [5, 7, 9, 20]))}
	var fire := func(self_ref: Callable) -> void:
		var cur: BattleUnit = state.target
		if cur == null or not cur.alive or state.left <= 0 or not c.alive:
			return
		show(ctx, [cur.cell])
		cur.add_stat("speDef", -1.0)
		var r := hit(ctx, cur, 10.0)
		state.left -= 1
		if r.death:
			state.target = closest_unit_of(sim, cur.cell, cur.team)
		if state.left > 0 and state.target != null:
			sim.schedule(333.0, c, func() -> void: self_ref.call(self_ref))
	fire.call(fire)
#endregion


#region abilities (batch17)
## dizzy-punch.ts: 20 / 40 / 80 SPECIAL (doubled on a shielded target), CONFUSION 3 s.
static func dizzy_punch(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var damage := by_stars(c, [20, 40, 80, 160])
	hit(ctx, t, damage * 2.0 if t.shield > 0.0 else damage)
	status(ctx, t, "confusion", 3000.0)


## dragon-pulse.ts: 0.4 s later 10 / 15 / 20 SPECIAL to the target, spreading to the enemies
## around it, then 0.4 s later around each of those; +5 AP per hit.
static func dragon_pulse(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var damage := by_stars(c, [10, 15, 20, 40])
	sim.schedule(400.0, c, func() -> void:
		if not t.alive:
			return
		show(ctx, [t.cell])
		hit(ctx, t, damage)
		c.add_stat("ap", 5.0)
		for e in enemies_on(ctx, BattleBoard.adjacent_cells(t.cell)):
			show(ctx, [e.cell])
			hit(ctx, e, damage)
			c.add_stat("ap", 5.0)
			sim.schedule(400.0, c, func() -> void:
				if not e.alive:
					return
				for f in enemies_on(ctx, BattleBoard.adjacent_cells(e.cell)):
					show(ctx, [f.cell])
					hit(ctx, f, damage)
					c.add_stat("ap", 5.0)))


## echo.ts: enemies within 2 + casts cells take casts x 3 / 6 / 9 SPECIAL.
static func echo(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.cells_in_radius(c.cell, 2 + c.cast_count)
	var foes := enemies_on(ctx, cells)
	show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	for e in foes:
		hit(ctx, e, c.cast_count * by_stars(c, [3, 6, 9, 12]))


## electro-shot.ts: charges 2 s (none in STORM), then +40 AP and 80 / 100 / 120 SPECIAL to the
## enemies on the line to the target (cancelled if silenced meanwhile).
static func electro_shot(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var storm := sim.weather == "STORM"
	var aim := t.cell
	var shot := func() -> void:
		if not c.alive or c.has_status("silence"):
			return
		c.add_stat("ap", 40.0)
		var cells := BattleBoard.cells_between(c.cell, t.cell if t.alive else aim)
		cells = line_through(c, t) if t.alive else cells
		show(ctx, cells)
		for e in enemies_on(ctx, cells):
			hit(ctx, e, by_stars(c, [80, 100, 120, 240]))
	if storm:
		shot.call()
	else:
		c.cooldown = 2000.0
		show(ctx, [c.cell], "allies")
		sim.schedule(2000.0, c, shot)


## entrainment.ts: +10 PP (AP); the target's ability becomes Entrainment (else the closest
## enemy that does not have it yet).
static func entrainment(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	c.add_pp(by_stars(c, [10, 10, 10, 30]) * (1.0 + c.ap / 100.0))
	if t == null:
		return
	var victim: BattleUnit = t if t.ability_id != "ENTRAINMENT" else null
	if victim == null:
		var others: Array = sim.enemies_of(c).filter(func(e: BattleUnit) -> bool:
			return e.ability_id != "ENTRAINMENT")
		others.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
			return BattleBoard.distance_c(a.cell, c.cell) < BattleBoard.distance_c(b.cell, c.cell))
		victim = others[0] if not others.is_empty() else null
	if victim != null:
		show(ctx, [victim.cell])
		victim.ability_id = "ENTRAINMENT"


## facade.ts: 20 / 40 / 80 SPECIAL, doubled when it has a negative status.
static func facade(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var damage := by_stars(c, [20, 40, 80, 160])
	hit(ctx, t, damage * 2.0 if c.has_negative_status() else damage)


## fairy-lock.ts: LOCKED 5 s; 50 / 70 / 90 SPECIAL split among the target and the enemies around.
static func fairy_lock(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	status(ctx, t, "locked", 5000.0)
	var foes := enemies_on(ctx, BattleBoard.adjacent_cells(t.cell, true))
	show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	for e in foes:
		hit(ctx, e, roundf(by_stars(c, [50, 70, 90, 180]) / foes.size()))


## fell-stinger.ts: 400% BASE ATK as SPECIAL; a KO gives +30% BASE ATK.
static func fell_stinger(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var r := hit(ctx, t, by_stars(c, [4, 4, 4, 8]) * c.base_atk)
	if r.death and not c.is_spawn:
		c.add_stat("atk", 0.3 * c.base_atk)


## fickle-beam.ts: 5 coin flips, one beam per head at the fastest enemies: PARALYSIS 2 s and
## 20 / 30 / 40 SPECIAL.
static func fickle_beam(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var foes := sim.enemies_of(c)
	if foes.is_empty():
		return
	foes.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.speed > b.speed)
	var beams := 0
	for _i in 5:
		if sim.chance(0.5, c):
			beams += 1
	for i in beams:
		var e: BattleUnit = foes[i % foes.size()]
		if not e.alive:
			continue
		show(ctx, [e.cell])
		status(ctx, e, "paralysis", 2000.0)
		hit(ctx, e, by_stars(c, [20, 30, 40, 50]))


## fillet-away.ts: loses 30% max HP, +5 / 8 / 10 ATK and +10 / 15 / 20 SPEED (AP), PROTECT 1 s,
## goes to a back corner.
static func fillet_away(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var k := 1.0 + c.ap / 100.0
	c.add_stat("maxHP", -floorf(c.max_hp * 0.3))
	c.add_stat("atk", by_stars(c, [5, 8, 10, 20]) * k)
	c.add_stat("speed", by_stars(c, [10, 15, 20, 40]) * k)
	sim.add_status(c, "protect", 1000.0)
	show(ctx, [c.cell], "allies")
	var dest: Variant = sim.teleport_cell(c.cell, c.team)
	if dest != null:
		sim.move_unit(c, dest, 250.0, "dash")
#endregion


#region abilities (batch18)
## fishious-rend.ts: 20 / 40 / 80 SPECIAL, doubled if it is faster than the target.
static func fishious_rend(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [20, 40, 80, 160]) * (2.0 if c.speed > t.speed else 1.0))


## fling.ts: holding the Ball, the enemies on the way to the farthest FIELD ally (else the
## farthest enemy) take 30% SPEED as SPECIAL; without it, jumps to a corner and gets a Ball.
static func fling(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if c.has_item("BALL"):
		var receiver: BattleUnit = null
		var best := 0
		for a in sim.allies_of(c):
			var d := BattleBoard.distance_m(a.cell, c.cell)
			if a.types.has("FIELD") and a.items.size() < BattleUnit.MAX_ITEMS and not a.has_item("BALL") and d > best:
				receiver = a
				best = d
		if receiver == null:
			receiver = sim.farthest_enemy(c)
		if receiver == null:
			return
		var cells := line_through(c, receiver)
		show(ctx, cells)
		for e in enemies_on(ctx, cells):
			hit(ctx, e, roundf(by_stars(c, [0.3, 0.3, 0.3, 1.0]) * c.speed))
		return
	var dest: Variant = sim.teleport_cell(c.cell, c.team)
	if dest == null:
		return
	sim.move_unit(c, dest, 250.0, "dash")
	sim.schedule(100.0, c, func() -> void:
		if c.items.size() < BattleUnit.MAX_ITEMS and not c.has_item("BALL"):
			c.equip(["BALL"])
			sim.emit({"type": "item", "unit": c, "item": "BALL", "text": GameData.item_name("BALL")}))


## floral-healing.ts: heals as much HP as its max PP.
static func floral_healing(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	show(ctx, [c.cell], "allies")
	ctx.sim.heal(c, c.max_pp, c)


## flying-press.ts: skydives next to the farthest enemy, 1 s later 50% of its max HP as SPECIAL.
static func flying_press(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var spot := sim.farthest_spot(c)
	if spot.is_empty():
		return
	var target: BattleUnit = spot.target
	sim.move_unit(c, spot.cell, 500.0, "dash")
	sim.schedule(1000.0, c, func() -> void:
		if target.alive:
			show(ctx, [target.cell])
			hit(ctx, target, by_stars(c, [0.5, 0.5, 0.5, 1.0]) * c.max_hp))


## follow-me.ts: jumps to a safe cell, 10 / 20 / 40 SHIELD (AP); the enemies that were
## targeting it are CHARMED 1 / 2 / 3 s.
static func follow_me(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var dest: Variant = AbilityRunner.fly_away_cell(sim, c)
	if dest == null:
		return
	for e in sim.enemies_of(c):
		if e.target == c:
			status(ctx, e, "charm", by_stars(c, [1000, 2000, 3000, 5000]))
	sim.move_unit(c, dest, 250.0, "dash")
	show(ctx, [c.cell], "allies")
	sim.add_shield(c, by_stars(c, [10, 20, 40, 80]) * (1.0 + c.ap / 100.0), c)


## force-palm.ts: 15 / 30 / 60 + 10% target max HP SPECIAL; a paralysed target takes
## 10 / 20 / 40 more and is pushed to the far end of the line, else PARALYSIS 6 s.
static func force_palm(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var paralysed := t.has_status("paralysis")
	var damage := roundf(by_stars(c, [15, 30, 60, 120]) + t.max_hp * 0.1
		+ (by_stars(c, [10, 20, 40, 80]) if paralysed else 0.0))
	if paralysed:
		if not t.has_item("HEAVY_DUTY_BOOTS"):
			var far: Variant = null
			for cell in ray_from(c.cell, BattleBoard.orientation(c.cell, t.cell)):
				if sim.board.is_free(cell):
					far = cell
			if far != null:
				sim.move_unit(t, far, 250.0, "knockback")
	else:
		status(ctx, t, "paralysis", 6000.0)
	hit(ctx, t, damage)


## forecast.ts: every ally 10 SHIELD (AP) + the Castform form bonus: Sun +4 ATK, Rain +8 PP,
## Hail +2 DEF / SPE_DEF.
static func forecast(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var k := 1.0 + c.ap / 100.0
	var allies := sim.alive_units(c.team)
	show(ctx, allies.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
	for a in allies:
		sim.add_shield(a, by_stars(c, [10, 10, 10, 20]) * k, c)
		match c.pkm:
			"CASTFORM_SUN": a.add_stat("atk", by_stars(c, [4, 4, 4, 8]) * k)
			"CASTFORM_RAIN": a.add_pp(by_stars(c, [8, 8, 8, 16]) * k)
			"CASTFORM_HAIL":
				a.add_stat("def", by_stars(c, [2, 2, 2, 4]) * k)
				a.add_stat("speDef", by_stars(c, [2, 2, 2, 4]) * k)


## freeze-dry.ts: 0.25 s later (30 / 50 / 70) x AP + SPE_DEF as SPECIAL; on a KO the enemies
## around take (10 / 20 / 30) x AP + 50% SPE_DEF.
static func freeze_dry(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	sim.schedule(250.0, c, func() -> void:
		if not t.alive:
			return
		var k := 1.0 + c.ap / 100.0
		var cell := t.cell
		var r := hit(ctx, t, by_stars(c, [30, 50, 70, 140]) * k + c.spe_def, BattleUnit.DamageKind.SPECIAL, false)
		if r.death:
			var cells := BattleBoard.adjacent_cells(cell)
			show(ctx, cells)
			for e in enemies_on(ctx, cells):
				hit(ctx, e, by_stars(c, [10, 20, 30, 60]) * k + c.spe_def * 0.5, BattleUnit.DamageKind.SPECIAL, false))


## gold-rush.ts: 20 SPECIAL + 1 per gold of the player; the player earns 2 gold.
static func gold_rush(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	var gold := 0.0
	if sim.player != null and c.team == BattleUnit.Team.BLUE:
		gold = float(sim.player.gold + sim.rewards.gold)
		sim.rewards.gold += 2
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [20, 20, 20, 50]) + gold * by_stars(c, [1, 1, 1, 3]))


## gravity.ts: every enemy LOCKED 2 s (AP).
static func gravity(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var foes := sim.enemies_of(c)
	show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	for e in foes:
		status(ctx, e, "locked", roundf(by_stars(c, [2000, 2000, 2000, 5000]) * (1.0 + c.ap / 100.0)))
#endregion


#region abilities (batch19)
## grav-apple.ts: 20 / 40 / 80 PHYSICAL (AP, doubled if DEF is 0).
static func grav_apple(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var damage := by_stars(c, [20, 40, 80, 160])
	hit(ctx, t, damage * 2.0 if t.def <= 0.0 else damage, BattleUnit.DamageKind.PHYSICAL)


## growth.ts: +3 / 5 / 7 ATK and +10 / 20 / 40 max HP (AP, doubled in ZENITH), acts again soon.
static func growth(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var k := (1.0 + c.ap / 100.0) * (2.0 if sim.weather == "ZENITH" else 1.0)
	show(ctx, [c.cell], "allies")
	c.add_stat("atk", by_stars(c, [3, 5, 7, 14]) * k)
	c.add_stat("maxHP", by_stars(c, [10, 20, 40, 80]) * k)
	c.cooldown = 250.0


## grudge-dive.ts: 30 / 60 / 90 SPECIAL + 5 / 10 / 15 per fallen ally; 10% max HP recoil.
static func grudge_dive(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [30, 60, 90, 120]) + sim.fallen[c.team] * by_stars(c, [5, 10, 15, 20]))
	if not c.has_item("PROTECTIVE_PADS"):
		sim.deal_damage(c, roundf(c.max_hp * 0.1 * (1.0 + c.ap / 100.0)), BattleUnit.DamageKind.PHYSICAL, c, false, false, false)


## gulp-missile.ts: an Arrokuda (20%: a Pikachu) is shot next to the target with full PP;
## the target takes 25 / 40 / 55 SPECIAL.
static func gulp_missile(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var missile := "PIKACHU" if sim.chance(0.2, c) else "ARROKUDA"
	show(ctx, [t.cell])
	var delay := maxf(0.0, BattleBoard.distance_m(c.cell, t.cell) * 150.0 - 30.0)
	sim.schedule(delay, c, func() -> void:
		if not t.alive:
			return
		var u := _summon(sim, missile, c.team, t.cell)
		if u == null:
			return
		u.is_spawn = true
		u.pp = u.max_pp
		hit(ctx, t, by_stars(c, [25, 40, 55, 110])))


## headlong-rush.ts: rushes next to the farthest enemy; enemies on the way are pushed aside
## (it loses 1 DEF / SPE_DEF each) and take 10 / 20 / 30 SPECIAL, the farthest one 20 / 40 / 80.
static func headlong_rush(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var spot := sim.farthest_spot(c)
	var main: BattleUnit = spot.target if not spot.is_empty() else ctx.focus
	if main == null:
		return
	var hit_list: Array[BattleUnit] = [main]
	if not spot.is_empty():
		var path := BattleBoard.cells_between(c.cell, spot.cell)
		show(ctx, path)
		for e in enemies_on(ctx, path):
			if not hit_list.has(e):
				hit_list.append(e)
			c.add_stat("def", -1.0)
			c.add_stat("speDef", -1.0)
			var side := Vector2i(1 if e.cell.x >= c.cell.x else -1, 0)
			if not e.has_item("HEAVY_DUTY_BOOTS") and sim.board.is_free(e.cell + side):
				sim.move_unit(e, e.cell + side, 250.0, "knockback")
				e.cooldown = 500.0
		sim.move_unit(c, spot.cell, 300.0, "dash")
	for e in hit_list:
		hit(ctx, e, by_stars(c, [20, 40, 80, 160]) if e == main else by_stars(c, [10, 20, 30, 60]))


## hyperspace-fury.ts: 1 / 2 / 3 hits (AP): -1 DEF and SPE_DEF, then 15 SPECIAL each.
static func hyperspace_fury(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	for _i in int(roundf(by_stars(c, [1, 2, 3, 4]) * (1.0 + c.ap / 100.0))):
		if not t.alive:
			break
		t.add_stat("def", -1.0)
		t.add_stat("speDef", -1.0)
		hit(ctx, t, 15.0, BattleUnit.DamageKind.SPECIAL, false)


## hyper-drill.ts: 10 / 20 / 40 TRUE through PROTECT; digs the hole under the target one level
## deeper (on the player's side), doubled on a hole already 5 deep.
static func hyper_drill(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var double := false
	if sim.player != null and PlayerState.is_player_cell(t.cell):
		var depth := int(sim.player.ground_holes.get(t.cell, 0))
		if depth >= PlayerState.MAX_HOLE_DEPTH:
			double = true
		else:
			sim.player.ground_holes[t.cell] = depth + 1
	t.statuses.erase("protect")
	hit(ctx, t, by_stars(c, [10, 20, 40, 50]) * (2.0 if double else 1.0), BattleUnit.DamageKind.TRUE)


## ice-fang.ts: 30 / 60 / 120 SPECIAL and FREEZE 1 / 1.5 / 2 s.
static func ice_fang(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [30, 60, 120, 240]))
	status(ctx, t, "freeze", by_stars(c, [1000, 1500, 2000, 2500]))


## infestation.ts: 10 SPECIAL per Bug ally; on its first cast, the strongest Bug of the bench
## joins the fight.
static func infestation(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t != null:
		var bugs := sim.alive_units(c.team).filter(func(a: BattleUnit) -> bool: return a.types.has("BUG")).size()
		show(ctx, [t.cell])
		hit(ctx, t, bugs * by_stars(c, [10, 10, 10, 20]))
	if c.cast_count != 1 or sim.player == null or c.team != BattleUnit.Team.BLUE:
		return
	var best: PlayerState.OwnedUnit = null
	var best_score := -1.0
	for o in sim.player.bench:
		if o == null or not GameData.get_pokemon(o.pkm).get("types", []).has("BUG"):
			continue
		var score := SynergyItems.unit_score(o)
		if score > best_score:
			best = o
			best_score = score
	if best == null:
		return
	var o: PlayerState.OwnedUnit = best
	sim.schedule(400.0, c, func() -> void:
		var u := _summon(sim, o.pkm, c.team, c.cell)
		if u == null:
			return
		u.is_spawn = true
		for stat in o.mods:
			u.add_stat(stat, float(o.mods[stat]))
		u.equip(o.items, sim.rng))


## jet-punch.ts: 100% SPEED as SPECIAL.
static func jet_punch(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [1, 1, 1, 1.5]) * c.speed)
#endregion


#region abilities (batch20)
## knock-off.ts: 30 / 60 / 90 SPECIAL + 15 / 20 / 30 per item of the target, which loses them
## for this fight.
static func knock_off(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var damage := by_stars(c, [30, 60, 90, 100]) + t.items.size() * by_stars(c, [15, 20, 30, 35])
	for item in t.items.duplicate():
		take_item(t, item)
	hit(ctx, t, damage)


## knowledge-thief.ts: casts the ability of its target (unless inimitable); the player gains 1 XP.
static func knowledge_thief(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t != null and t.ability_id != "KNOWLEDGE_THIEF" and GameData.is_ability_ported(t.ability_id) \
			and not GameData.get_ability(t.ability_id).get("inimitable", false):
		run_other(ctx, t.ability_id, t)
	if sim.player != null and c.team == BattleUnit.Team.BLUE and not c.is_spawn:
		sim.rewards.exp = int(sim.rewards.get("exp", 0)) + int(by_stars(c, [1, 1, 1, 2]))


## link-cable.ts: rushes next to the farthest enemy; 0.3 s later, linked to its partner (the
## other Link Cable ally): 40 SPECIAL to the enemies on the link and around both, else
## 20 SPECIAL around itself.
static func link_cable(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var spot := sim.farthest_spot(c)
	if not spot.is_empty():
		sim.move_unit(c, spot.cell, 250.0, "dash")
		c.target = spot.target
	sim.schedule(300.0, c, func() -> void:
		if not c.alive:
			return
		var partner: BattleUnit = null
		for a in sim.allies_of(c):
			if a.ability_id == "LINK_CABLE":
				partner = a
				break
		if partner == null:
			var cells := BattleBoard.adjacent_cells(c.cell)
			show(ctx, cells)
			for e in enemies_on(ctx, cells):
				hit(ctx, e, by_stars(c, [20, 20, 20, 40]))
			return
		var hit_set: Array[BattleUnit] = []
		var cells: Array = line_through(c, partner) + BattleBoard.adjacent_cells(c.cell) \
			+ BattleBoard.adjacent_cells(partner.cell)
		show(ctx, cells)
		for e in enemies_on(ctx, cells):
			if not hit_set.has(e):
				hit_set.append(e)
		for e in hit_set:
			hit(ctx, e, by_stars(c, [40, 40, 40, 80])))


## luster-purge.ts / mist-ball.ts: the enemies on the line to the target (up to 4 cells) take
## 10 / 20 / 30 SPECIAL and lose `stat`; the ball comes back 1 s later (whole line).
static func _returning_ball(ctx: Dictionary, stat: String, amount: float) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var damage := by_stars(c, [10, 20, 30, 60])
	var cells := line_through(c, t)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		if BattleBoard.distance_c(c.cell, e.cell) <= 4:
			hit(ctx, e, damage)
			e.add_stat(stat, -amount)
	sim.schedule(1000.0, c, func() -> void:
		var back := line_through(c, t) if t.alive else cells
		show(ctx, back)
		for e in enemies_on(ctx, back):
			hit(ctx, e, damage)
			e.add_stat(stat, -amount))


static func luster_purge(ctx: Dictionary) -> void:
	_returning_ball(ctx, "speDef", by_stars(ctx.caster, [5, 5, 5, 10]))


static func mist_ball(ctx: Dictionary) -> void:
	_returning_ball(ctx, "ap", by_stars(ctx.caster, [30, 30, 30, 60]))


## make-it-rain.ts: 25 / 50 / 100 SPECIAL + 1 per gold of the player.
static func make_it_rain(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var gold := 0.0
	if sim.player != null and c.team == BattleUnit.Team.BLUE:
		gold = float(sim.player.gold + sim.rewards.gold)
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [25, 50, 100, 200]) + floorf(gold * by_stars(c, [1, 1, 1, 3])))


## mawashi-geri.ts: 20 / 40 / 60 SPECIAL (doubled if its ATK is higher), the target is kicked
## to the far end of the line.
static func mawashi_geri(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var damage := by_stars(c, [20, 40, 60, 120])
	hit(ctx, t, damage * 2.0 if c.atk > t.atk else damage)
	if t.alive and not t.has_item("HEAVY_DUTY_BOOTS"):
		var far: Variant = null
		for cell in ray_from(c.cell, BattleBoard.orientation(c.cell, t.cell)):
			if sim.board.is_free(cell):
				far = cell
		if far != null:
			sim.move_unit(t, far, 250.0, "knockback")


## mega-punch.ts: 20 / 40 / 60 SPECIAL, doubled if its DEF is higher.
static func mega_punch(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var damage := by_stars(c, [20, 40, 60, 120])
	hit(ctx, t, damage * 2.0 if c.def > t.def else damage)


## moonblast.ts: 6 moons, every 0.2 s: 10 / 14 / 18 SPECIAL; a KO moves on to the closest
## enemy with one more moon.
static func moonblast(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var state := {"target": t, "left": 6, "sent": 0}
	var send := func(self_ref: Callable) -> void:
		var cur: BattleUnit = state.target
		if cur == null or not cur.alive or not c.alive:
			return
		state.sent += 1
		show(ctx, [cur.cell])
		var r := hit(ctx, cur, by_stars(c, [10, 14, 18, 26]))
		state.left -= 1
		if r.death:
			state.target = closest_unit_of(sim, cur.cell, cur.team)
			if state.target != null:
				state.left += 1
		if state.left > 0 and state.target != null and state.sent < 20:
			sim.schedule(200.0, c, func() -> void: self_ref.call(self_ref))
	send.call(send)


## nasty-plot.ts: +4 / 7 / 10 ATK (AP), acts again soon.
static func nasty_plot(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	show(ctx, [c.cell], "allies")
	c.add_stat("atk", by_stars(c, [4, 7, 10, 20]) * (1.0 + c.ap / 100.0))
	c.cooldown = 250.0
#endregion


#region abilities (batch21)
## night-slash.ts: 15 / 30 / 60 SPECIAL, can crit.
static func night_slash(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [15, 30, 60, 120]), BattleUnit.DamageKind.SPECIAL, true,
		sim.chance(c.crit_chance / 100.0, c))


## no-retreat.ts: per Falinks trooper in formation (PassiveEffects FALINKS: effects.falinks):
## +1 ATK / DEF / SPE_DEF, +5 SPEED and a 20 SPECIAL tackle.
static func no_retreat(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	var n := int(c.effects.get("falinks", 0))
	if n <= 0:
		return
	c.add_stat("atk", n)
	c.add_stat("def", n)
	c.add_stat("speDef", n)
	c.add_stat("speed", 5.0 * n)
	if t == null:
		return
	for i in n:
		sim.schedule(100.0 * i, c, func() -> void:
			if t.alive:
				show(ctx, [t.cell])
				hit(ctx, t, by_stars(c, [20, 20, 20, 40])))


## nutrients.ts: the ally with the lowest HP % heals 20 / 30 / 40 and gains 1 / 2 / 3 DEF and
## SPE_DEF (AP).
static func nutrients(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies := sim.alive_units(c.team)
	if allies.is_empty():
		return
	allies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.hp_ratio() < b.hp_ratio())
	var a: BattleUnit = allies[0]
	var k := 1.0 + c.ap / 100.0
	show(ctx, [a.cell], "allies")
	sim.heal(a, by_stars(c, [20, 30, 40, 80]) * k, c)
	a.add_stat("def", by_stars(c, [1, 2, 3, 6]) * k)
	a.add_stat("speDef", by_stars(c, [1, 2, 3, 6]) * k)


## order-up.ts: 30 / 60 / 100 SPECIAL; with a Tatsugiri item, itself and the allies that ate
## Rice gain 80 max HP and 8 ATK / 8 DEF / 25 SPEED; else a Tatsugiri comes to the bench.
static func order_up(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t != null:
		show(ctx, [t.cell])
		hit(ctx, t, by_stars(c, [30, 60, 100, 200]))
	var eaters: Array[BattleUnit] = [c]
	for a in sim.allies_of(c):
		if a.effects.get("rice", false):
			eaters.append(a)
	var bonus := ""
	for item in ["TATSUGIRI_CURLY", "TATSUGIRI_DROOPY", "TATSUGIRI_STRETCHY"]:
		if c.has_item(item):
			bonus = item
	if bonus != "":
		for p in eaters:
			p.add_stat("maxHP", 80.0)
			match bonus:
				"TATSUGIRI_CURLY": p.add_stat("atk", 8.0)
				"TATSUGIRI_DROOPY": p.add_stat("def", 8.0)
				"TATSUGIRI_STRETCHY": p.add_stat("speed", 25.0)
		return
	if sim.player == null or c.team != BattleUnit.Team.BLUE or sim.rewards.has("tatsugiri"):
		return
	for cell in sim.player.board:
		if String(sim.player.board[cell].pkm).begins_with("TATSUGIRI"):
			return
	sim.rewards.tatsugiri = true
	var form: String = ["TATSUGIRI_CURLY", "TATSUGIRI_DROOPY", "TATSUGIRI_STRETCHY"][sim.player.stage % 3]
	if not sim.rewards.has("pokemon"):
		sim.rewards.pokemon = []
	sim.rewards.pokemon.append(form)


## plasma-fist.ts: 60 / 90 / 120 SPECIAL, heals 30% of the damage dealt.
static func plasma_fist(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var r := hit(ctx, t, by_stars(c, [60, 90, 120, 240]))
	if r.taken > 0.0:
		ctx.sim.heal(c, roundf(r.taken * 0.3), c)


## plasma-flash.ts: 4 + casts flashes, every 0.1 s: 5 / 10 / 20 SPECIAL.
static func plasma_flash(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	for i in 4 + c.cast_count:
		sim.schedule(100.0 * i, c, func() -> void:
			if t.alive:
				show(ctx, [t.cell])
				hit(ctx, t, by_stars(c, [5, 10, 20, 40])))


## plasma-tempest.ts: flies away, 0.5 s later 3 beams through its 3 closest enemies to the
## board edge: 20 / 30 / 40 SPECIAL, -10% per enemy already hit by the beam.
static func plasma_tempest(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var dest: Variant = AbilityRunner.fly_away_cell(sim, c)
	if dest != null:
		sim.move_unit(c, dest, 300.0, "dash")
	sim.schedule(500.0, c, func() -> void:
		if not c.alive:
			return
		var foes := sim.enemies_of(c)
		foes.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
			return BattleBoard.distance_c(a.cell, c.cell) < BattleBoard.distance_c(b.cell, c.cell))
		for e in foes.slice(0, 3):
			var cells := line_through(c, e)
			show(ctx, cells)
			var damage := by_stars(c, [20, 30, 40, 80])
			for u in enemies_on(ctx, cells):
				hit(ctx, u, damage)
				damage = maxf(1.0, roundf(damage * 0.9)))


## population-bomb.ts: 4 / 8 / 12 hits (AP) of 10 SPECIAL.
static func population_bomb(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	for _i in int(roundf(by_stars(c, [4, 8, 12, 16]) * (1.0 + c.ap / 100.0))):
		if not t.alive:
			break
		hit(ctx, t, 10.0, BattleUnit.DamageKind.SPECIAL, false)


## power-wash.ts: water drops sweep the row with the most enemy HP from both sides:
## 80 / 120 / 160 SPECIAL shared among the enemies of the row (per drop: half the share).
static func power_wash(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var best_row := -1
	var best_hp := 0.0
	var count := 0
	for y in BattleBoard.HEIGHT:
		var hp := 0.0
		var n := 0
		for e in enemies_on(ctx, BattleBoard.cells_in_row(y)):
			hp += e.hp
			n += 1
		if n > 0 and hp > best_hp:
			best_hp = hp
			best_row = y
			count = n
	if best_row < 0:
		return
	var drop := ceilf(by_stars(c, [80, 120, 160, 320]) / count) / 2.0
	for x in BattleBoard.WIDTH:
		for cell in [Vector2i(x, best_row), Vector2i(BattleBoard.WIDTH - 1 - x, best_row)]:
			sim.schedule(100.0 * x, c, func() -> void:
				show(ctx, [cell])
				var e := sim.board.get_unit(cell)
				if e != null and e.alive and e.team != c.team:
					hit(ctx, e, drop))


## power-whip.ts: 15 / 30 / 60 + 30% of its HP as SPECIAL.
static func power_whip(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [15, 30, 60, 120]) + 0.3 * c.hp)
#endregion


#region abilities (batch22)
## present.ts: a random gift (luck helps): 10% heals the target 50, 40% 20 / 40 / 80, 30%
## 50 / 100 / 150, 20% 100 / 200 / 300 SPECIAL.
static func present(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var roll := pow(sim.rng.randf(), maxf(0.01, 1.0 - c.luck / 100.0))
	if roll < 0.1:
		sim.heal(t, 50.0, c)
	elif roll < 0.5:
		hit(ctx, t, by_stars(c, [20, 40, 80, 160]))
	elif roll < 0.8:
		hit(ctx, t, by_stars(c, [50, 100, 150, 300]))
	else:
		hit(ctx, t, by_stars(c, [100, 200, 300, 600]))


## psychic-fangs.ts: the target's ATK, DEF and SPE_DEF drop back to base, 20 / 40 / 80 SPECIAL.
static func psychic_fangs(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	t.atk = minf(t.atk, t.base_atk)
	t.def = minf(t.def, t.base_def)
	t.spe_def = minf(t.spe_def, t.base_spe_def)
	hit(ctx, t, by_stars(c, [20, 40, 80, 160]))


## psycho-shift.ts: the farthest enemy trades places with the target, both take 20 / 40 / 60 SPECIAL.
static func psycho_shift(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var far := sim.farthest_enemy(c)
	var damage := by_stars(c, [20, 40, 60, 120])
	show(ctx, [t.cell])
	if far != null and far != t:
		if not far.has_item("HEAVY_DUTY_BOOTS") and not t.has_item("HEAVY_DUTY_BOOTS"):
			swap_units(sim, far.cell, t.cell, "knockback")
		hit(ctx, far, damage)
	hit(ctx, t, damage)


## psyshield-bash.ts: charges next to the farthest enemy with PROTECT 1 s: the enemies on the
## way take 30 / 40 / 50 SPECIAL (at least the target).
static func psyshield_bash(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var hit_list: Array[BattleUnit] = []
	var spot := sim.farthest_spot(c)
	if not spot.is_empty():
		var path := BattleBoard.cells_between(c.cell, spot.cell)
		show(ctx, path)
		hit_list = enemies_on(ctx, path)
		sim.move_unit(c, spot.cell, 300.0, "dash")
	sim.add_status(c, "protect", 1000.0)
	if hit_list.is_empty() and ctx.focus != null:
		hit_list.append(ctx.focus)
	for e in hit_list:
		hit(ctx, e, by_stars(c, [30, 40, 50, 60]))


## pummeling-payback.ts: 20 / 40 / 60 + 125% ATK as SPECIAL, heals 20 / 30 / 40 (AP).
static func pummeling_payback(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t != null:
		show(ctx, [t.cell])
		hit(ctx, t, by_stars(c, [20, 40, 60, 120]) + 1.25 * c.atk)
	ctx.sim.heal(c, by_stars(c, [20, 30, 40, 80]) * (1.0 + c.ap / 100.0), c)


## purify.ts: cleanses itself and the adjacent allies, heals 15 / 30 / 60 (AP).
static func purify(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.adjacent_cells(c.cell, true)
	show(ctx, cells, "allies")
	for cell in cells:
		var a := sim.board.get_unit(cell)
		if a != null and a.alive and a.team == c.team:
			a.cleanse()
	sim.heal(c, by_stars(c, [15, 30, 60, 120]) * (1.0 + c.ap / 100.0), c)


## raging-bull.ts: breaks PROTECT, REFLECT and MAGIC_BOUNCE, ARMOR_BREAK 3 s, 20 / 40 / 80 SPECIAL.
static func raging_bull(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	for s in ["protect", "reflect", "magic_bounce"]:
		t.statuses.erase(s)
	status(ctx, t, "armor_reduction", 3000.0)
	hit(ctx, t, by_stars(c, [20, 40, 80, 160]))


## shadow-sneak.ts: 25 / 40 / 50 SPECIAL, TRUE on a silenced target.
static func shadow_sneak(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [25, 40, 50, 100]),
		BattleUnit.DamageKind.TRUE if t.has_status("silence") else BattleUnit.DamageKind.SPECIAL)


## shed-tail.ts: the ally with the lowest HP % gains 40 / 60 / 80 SHIELD (AP); it runs next to
## it and leaves a Substitute where it stood (its attackers now target the Substitute).
static func shed_tail(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies := sim.alive_units(c.team)
	if allies.is_empty():
		return
	allies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.hp_ratio() < b.hp_ratio())
	var weakest: BattleUnit = allies[0]
	show(ctx, [weakest.cell], "allies")
	sim.add_shield(weakest, by_stars(c, [40, 60, 80, 160]) * (1.0 + c.ap / 100.0), c)
	var dest: Variant = sim.closest_free_cell_near(weakest.cell, weakest.team)
	if dest == null:
		return
	var old := c.cell
	sim.move_unit(c, dest, 250.0, "dash")
	var sub := _summon(sim, "SUBSTITUTE", c.team, old)
	if sub == null:
		return
	sub.is_spawn = true
	for e in sim.enemies_of(c):
		if e.target == c:
			e.target = sub


## shell-trap.ts: with a shield, the enemies around take 50 SPECIAL + its shield, which bursts;
## else gains 25 / 50 / 75 SHIELD (AP).
static func shell_trap(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if c.shield > 0.0:
		var damage := by_stars(c, [50, 50, 50, 100]) + c.shield
		var cells := BattleBoard.adjacent_cells(c.cell, true)
		show(ctx, cells)
		for e in enemies_on(ctx, cells):
			hit(ctx, e, damage)
		c.shield = 0.0
		if c.has_item("EXPLOSIVE_BAND"):
			ItemEffects.explosive_band(sim, c)
	else:
		show(ctx, [c.cell], "allies")
		sim.add_shield(c, by_stars(c, [25, 50, 75, 150]) * (1.0 + c.ap / 100.0), c)
#endregion


#region abilities (batch23)
## shields-down.ts / shields-up.ts: Minior drops its shell (a random Kernel color, ability
## Shields Up) or puts it back on (Minior, Shields Down); acts again right away.
static func shields_down(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var kernels: Array = ["MINIOR_KERNEL_BLUE", "MINIOR_KERNEL_GREEN", "MINIOR_KERNEL_ORANGE", "MINIOR_KERNEL_RED"]
	_minior(ctx, kernels[sim.rng.randi() % kernels.size()], "SHIELDS_UP")


static func shields_up(ctx: Dictionary) -> void:
	_minior(ctx, "MINIOR", "SHIELDS_DOWN")


static func _minior(ctx: Dictionary, pkm: String, ability: String) -> void:
	var c: BattleUnit = ctx.caster
	show(ctx, [c.cell], "allies")
	if GameData.pokemon.has(pkm):
		c.pkm = pkm
		ctx.sim.emit({"type": "transform", "unit": c})
	c.ability_id = ability
	c.cooldown = 0.0


## sketch.ts: nothing (Smeargle's Sketch is its passive).
static func sketch(_ctx: Dictionary) -> void:
	pass


## skitter-smack.ts: skitters behind the target, 0.3 s later 15 / 30 / 60 SPECIAL and -20 AP.
static func skitter_smack(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var behind: Variant = sim.board.closest_free_cell(BattleBoard.step(t.cell, BattleBoard.orientation(c.cell, t.cell)))
	if behind != null:
		sim.move_unit(c, behind, 250.0, "dash")
	sim.schedule(300.0, c, func() -> void:
		if t.alive:
			show(ctx, [t.cell])
			hit(ctx, t, by_stars(c, [15, 30, 60, 120]))
			t.add_stat("ap", AbilityRunner.adjust_buff(c, t, -20.0)))


## smoke-screen.ts: jumps where enemies are the most packed: 10 / 20 / 40 SPECIAL around, and
## SMOKE on 3 cells of the deepest enemy row it touches.
static func smoke_screen(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var dest: Variant = null
	var best := 0
	for cell in sim.board.free_cells():
		var n := enemies_on(ctx, BattleBoard.adjacent_cells(cell)).size()
		if n > best:
			best = n
			dest = cell
	if dest == null:
		return
	sim.move_unit(c, dest, 250.0, "dash")
	# the side it lands on: the front row of that side, else the deepest row of it an enemy hit stands on
	var low: bool = dest.y < BattleBoard.SIDE_ROWS
	var row := BattleBoard.SIDE_ROWS - 1 if low else BattleBoard.SIDE_ROWS
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [10, 20, 40, 80]))
		if (e.cell.y < row) if low else (e.cell.y > row):
			row = e.cell.y
	var smoke: Array[Vector2i] = []
	for dx in [-1, 0, 1]:
		var cell := Vector2i(c.cell.x + dx, row)
		if BattleBoard.in_bounds(cell) and cell != c.cell:
			smoke.append(cell)
	board_effect(sim, smoke, "SMOKE")


## snore.ts: enemies in front of it: FLINCH 3 s and 20 / 40 / 60 SPECIAL.
static func snore(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.cells_in_front(c.cell, t.cell, 1)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		status(ctx, e, "flinch", 3000.0)
		hit(ctx, e, by_stars(c, [20, 40, 60, 120]))


## song-of-desire.ts: the 1 / 1 / 2 backmost enemies are CHARMED 3 s and lose 3 ATK (AP).
static func song_of_desire(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var foes := sim.enemies_of(c)
	foes.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return a.cell.y < b.cell.y if a.team == BattleUnit.Team.BLUE else a.cell.y > b.cell.y)
	foes = foes.slice(0, int(by_stars(c, [1, 1, 2, 3])))
	show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	for e in foes:
		status(ctx, e, "charm", 3000.0)
		e.add_stat("atk", AbilityRunner.adjust_buff(c, e, -3.0 * (1.0 + c.ap / 100.0)))


## soul-trap.ts: 25 / 50 / 108 SHIELD; enemies within 2 cells lose 10 PP (AP) and get FATIGUE
## 2 s (AP).
static func soul_trap(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var k := 1.0 + c.ap / 100.0
	sim.add_shield(c, by_stars(c, [25, 50, 108, 108]), c)
	var foes := enemies_on(ctx, BattleBoard.cells_in_radius(c.cell, 2))
	show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	for e in foes:
		e.drain_pp(by_stars(c, [10, 10, 10, 50]) * k)
		sim.add_status(e, "fatigue", roundf(by_stars(c, [2000, 2000, 2000, 5000]) * k), c)


## static-shock.ts: 30 / 50 / 70 SPECIAL; heals 10 / 20 / 30 per adjacent Fairy and gains
## 10 / 20 / 30 SHIELD per adjacent Electric (AP).
static func static_shock(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t != null:
		show(ctx, [t.cell])
		hit(ctx, t, by_stars(c, [30, 50, 70, 100]))
	var fairies := 0
	var electrics := 0
	for cell in BattleBoard.adjacent_cells(c.cell):
		var u := sim.board.get_unit(cell)
		if u != null and u.alive:
			fairies += 1 if u.types.has("FAIRY") else 0
			electrics += 1 if u.types.has("ELECTRIC") else 0
	var k := 1.0 + c.ap / 100.0
	if fairies > 0:
		sim.heal(c, by_stars(c, [10, 20, 30, 60]) * fairies * k, c)
	if electrics > 0:
		sim.add_shield(c, by_stars(c, [10, 20, 30, 60]) * electrics * k, c)


## stockpile.ts: +30 / 40 / 50 max HP (AP) and -10 SPEED; every 4th cast spits up: 50% max HP
## as SPECIAL, jumps to the backline, back to base max HP and +30 SPEED.
static func stockpile(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if c.cast_count % 4 != 0:
		show(ctx, [c.cell], "allies")
		c.add_stat("maxHP", by_stars(c, [30, 40, 50, 100]) * (1.0 + c.ap / 100.0))
		c.add_stat("speed", -10.0)
		return
	if t != null:
		show(ctx, [t.cell])
		hit(ctx, t, ceilf(by_stars(c, [0.5, 0.5, 0.5, 1.0]) * c.max_hp))
	var dest: Variant = sim.teleport_cell(c.cell, c.team)
	if dest != null:
		sim.move_unit(c, dest, 300.0, "dash")
	c.max_hp = c.base_hp
	c.hp = minf(c.hp, c.max_hp)
	c.add_stat("speed", 30.0)
#endregion


#region abilities (batch24)
## struggle-bug.ts: adjacent enemies lose 30 AP and take 10 / 20 / 30 SPECIAL.
static func struggle_bug(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		e.add_stat("ap", AbilityRunner.adjust_buff(c, e, -30.0))
		hit(ctx, e, by_stars(c, [10, 20, 30, 60]))


## super-heat.ts: 9 bursts, every 0.33 s, in a cone 2 cells deep: 4 / 7 / 10 SPECIAL and
## ARMOR_BREAK 1 s (stops while frozen or asleep).
static func super_heat(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var aim := t.cell
	for i in 9:
		sim.schedule(333.0 * i, c, func() -> void:
			if not c.alive or c.has_status("freeze") or c.has_status("sleep"):
				return
			var cells := BattleBoard.cells_in_front(c.cell, t.cell if t.alive else aim, 2)
			show(ctx, cells)
			for e in enemies_on(ctx, cells):
				hit(ctx, e, by_stars(c, [4, 7, 10, 20]))
				status(ctx, e, "armor_reduction", 1000.0))


## syrup-bomb.ts: the fastest enemy loses 30 SPEED (AP) and takes 30 / 40 / 50 SPECIAL.
static func syrup_bomb(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var foes := sim.enemies_of(c)
	if foes.is_empty():
		return
	foes.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.speed > b.speed)
	var e: BattleUnit = foes[0]
	show(ctx, [e.cell])
	e.add_stat("speed", AbilityRunner.adjust_buff(c, e, -30.0 * (1.0 + c.ap / 100.0)))
	hit(ctx, e, by_stars(c, [30, 40, 50, 100]))


## tail-glow.ts: +30 AP, adjacent enemies take 10 / 20 / 30 SPECIAL.
static func tail_glow(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	c.add_stat("ap", 30.0)
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [10, 20, 30, 60]))


## teeter-dance.ts: +20 SPEED (AP); every unit on the board (allies too) gets CONFUSION 3 s.
static func teeter_dance(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	c.add_stat("speed", 20.0 * (1.0 + c.ap / 100.0))
	var all: Array[BattleUnit] = sim.alive_units(BattleUnit.Team.BLUE) + sim.alive_units(BattleUnit.Team.RED)
	show(ctx, all.map(func(u: BattleUnit) -> Vector2i: return u.cell), "all")
	for u in all:
		sim.add_status(u, "confusion", by_stars(c, [3000, 3000, 3000, 6000]), c)


## trimming-mower.ts: dashes (2 cells max) where the most enemies are adjacent, heals
## 30 / 45 / 60 (AP, overheal as SHIELD), 0.3 s later 20 / 30 / 40 SPECIAL around.
static func trimming_mower(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var dest := c.cell
	var best := 0
	for cell in sim.board.free_cells():
		if maxi(absi(cell.x - c.cell.x), absi(cell.y - c.cell.y)) > 2:
			continue
		var n := enemies_on(ctx, BattleBoard.adjacent_cells(cell)).size()
		if n > best:
			best = n
			dest = cell
	if dest != c.cell:
		sim.move_unit(c, dest, 250.0, "dash")
	var over := sim.heal(c, by_stars(c, [30, 45, 60, 120]) * (1.0 + c.ap / 100.0), c)
	if over > 0.0:
		sim.add_shield(c, over, c)
	sim.schedule(300.0, c, func() -> void:
		if not c.alive:
			return
		var cells := BattleBoard.adjacent_cells(c.cell)
		show(ctx, cells)
		for e in enemies_on(ctx, cells):
			hit(ctx, e, by_stars(c, [20, 30, 40, 80])))


## triple-kick.ts: up to 3 adjacent enemies take 20 / 40 / 60 SPECIAL.
static func triple_kick(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var foes := enemies_on(ctx, BattleBoard.adjacent_cells(c.cell)).slice(0, 3)
	show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	for e in foes:
		hit(ctx, e, by_stars(c, [20, 40, 60, 120]))


## unbound.ts: Hoopa unleashes its true form: Hoopa Unbound, one more star, +10 ATK,
## +100 max HP, ability Hyperspace Fury.
static func unbound(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	show(ctx, [c.cell], "allies")
	if GameData.pokemon.has("HOOPA_UNBOUND"):
		c.pkm = "HOOPA_UNBOUND"
		sim.emit({"type": "transform", "unit": c})
	c.stars += 1
	c.ability_id = "HYPERSPACE_FURY"
	c.add_stat("atk", 10.0)
	c.add_stat("maxHP", 100.0)


## venoshock.ts: 30 / 60 / 120 SPECIAL, doubled when it is poisoned itself.
static func venoshock(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var damage := by_stars(c, [30, 60, 120, 240])
	hit(ctx, t, damage * 2.0 if c.has_status("poison") else damage)


## Vespiquen's orders come from its passive: the ability itself does nothing.
static func vespiquen_orders(_ctx: Dictionary) -> void:
	pass


## volt-surge.ts: +10 / 20 / 30 max HP (AP), +20 SPEED, ELECTRIC_FIELD; after the first cast,
## every 3rd attack bounces lightning (ItemEffects.on_attack); later casts act again at once.
static func volt_surge(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	show(ctx, [c.cell], "allies")
	c.add_stat("maxHP", by_stars(c, [10, 20, 30, 60]) * (1.0 + c.ap / 100.0))
	c.add_stat("speed", 20.0)
	if not c.has_status("electric_field"):
		sim.add_status(c, "electric_field", 1e9)
	if c.cast_count == 1:
		c.effects.volt_surge = true
	else:
		c.cooldown = 0.0


## x-scissor.ts: 10 / 20 / 40 TRUE twice.
static func x_scissor(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	for _i in 2:
		hit(ctx, t, by_stars(c, [10, 20, 40, 60]), BattleUnit.DamageKind.TRUE)


## zing-zap.ts: 30 / 60 / 90 SPECIAL and FLINCH 3 s (+10 / 20 / 40 SHIELD if the target is
## paralysed), then bounces behind the target.
static func zing_zap(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [30, 60, 90, 180]))
	status(ctx, t, "flinch", 3000.0)
	if t.has_status("paralysis"):
		sim.add_shield(c, by_stars(c, [10, 20, 40, 80]) * (1.0 + c.ap / 100.0), c)
	var dir := BattleBoard.orientation(c.cell, t.cell)
	for d in BattleBoard.fan(dir):
		if sim.board.is_free(BattleBoard.step(t.cell, d)):
			sim.move_unit(c, BattleBoard.step(t.cell, d), 250.0, "dash")
			break
#endregion


#region abilities (batch25)
## bug-bite.ts: 20 / 40 / 80 SPECIAL; steals and eats the berry of the target.
static func bug_bite(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [20, 40, 80, 160]))
	var berry := ""
	for item in t.items:
		if GameData.item_in(item, "Berries"):
			berry = item
			break
	if berry == "":
		return
	t.items.erase(berry)
	if t.owned != null:
		t.owned.items.erase(berry)
	var owned: Variant = c.owned
	c.owned = null # the berry is not one of its own items
	c.items.append(berry)
	SynergyItems.eat_berry(sim, c, berry)
	c.owned = owned


## happy-hour.ts: every ally +2 / 4 / 7 ATK (AP).
static func happy_hour(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies := sim.alive_units(c.team)
	show(ctx, allies.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
	for a in allies:
		a.add_stat("atk", by_stars(c, [2, 4, 7, 10]) * (1.0 + c.ap / 100.0))


## magnet-pull.ts: attracts a Steel Pokémon of the shop (PlayerState.magnet_pull_pick: AP and LUCK
## make rarer ones likelier, else Meltan); it watches the fight beside the board, click it to
## catch it (Wanderers).
static func magnet_pull(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if sim.player == null or c.team != BattleUnit.Team.BLUE:
		return
	var pkm: String = sim.player.magnet_pull_pick(c.ap, c.luck)
	if not GameData.is_available(pkm):
		return
	show(ctx, [c.cell], "allies")
	sim.player.wanderers.append({"pkm": pkm, "kind": "catchable", "behavior": "spectate", "delay": 0.0})


## swarm.ts: a Bug of the team (cheaper ones first, one more per cast) hatches from the Bug Nest.
static func swarm(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if sim.player == null:
		return
	var nest: BattleUnit = null
	for a in sim.alive_units(c.team):
		if a.pkm == "BUG_NEST":
			nest = a
	if nest == null:
		return
	var bugs: Array = []
	for cell in sim.player.board:
		var o: PlayerState.OwnedUnit = sim.player.board[cell]
		if GameData.get_pokemon(o.pkm).get("types", []).has("BUG"):
			bugs.append(o.pkm)
	if bugs.is_empty():
		return
	bugs.sort_custom(func(a: String, b: String) -> bool:
		return GameData.rarity_cost(String(GameData.get_pokemon(a).rarity)) \
			< GameData.rarity_cost(String(GameData.get_pokemon(b).rarity)))
	var pkm: String = bugs[mini(maxi(c.cast_count - 1, 0), bugs.size() - 1)]
	var u := _summon(sim, pkm, c.team, nest.cell)
	if u != null:
		u.is_spawn = true
		u.cooldown = 1000.0
		show(ctx, [u.cell], "allies")


## tackle.ts: 20 / 40 / 60 SPECIAL.
static func tackle(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [20, 40, 60, 120]))


## take-heart.ts: +4 / 6 / 8 ATK and SPE_DEF (AP), cleanses itself, acts again soon.
static func take_heart(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var k := 1.0 + c.ap / 100.0
	show(ctx, [c.cell], "allies")
	c.add_stat("atk", by_stars(c, [4, 6, 8, 12]) * k)
	c.add_stat("speDef", by_stars(c, [4, 6, 8, 12]) * k)
	c.cleanse()
	c.cooldown = 100.0


## thunderclap-press.ts: the target is pushed to the far end of the line; it and the units on
## the way get PARALYSIS 4 s and 20 / 40 / 80 SPECIAL.
static func thunderclap_press(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var hit_list: Array[BattleUnit] = [t]
	var far: Variant = null
	for cell in ray_from(c.cell, BattleBoard.orientation(c.cell, t.cell)):
		var u := sim.board.get_unit(cell)
		if u == null:
			far = cell
		elif not hit_list.has(u) and u.team != c.team:
			hit_list.append(u)
	if far != null and not t.has_item("HEAVY_DUTY_BOOTS"):
		sim.move_unit(t, far, 250.0, "knockback")
	show(ctx, hit_list.map(func(u: BattleUnit) -> Vector2i: return u.cell))
	for u in hit_list:
		status(ctx, u, "paralysis", 4000.0)
		hit(ctx, u, by_stars(c, [20, 40, 80, 160]))


## transform.ts: becomes a copy of the target: look, stars, ability, passive and stats.
static func transform(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null or t.inanimate:
		return
	show(ctx, [t.cell])
	sim.emit({"type": "transform", "unit": c, "pkm": t.pkm})
	c.stars = t.stars
	c.ability_id = t.ability_id
	c.max_pp = t.max_pp
	c.passive = t.passive
	c.base_atk = t.atk
	c.base_def = t.def
	c.base_spe_def = t.spe_def
	c.base_range = t.base_range
	c.atk = t.atk
	c.def = t.def
	c.spe_def = t.spe_def
	c.speed = t.speed
	c.ap = t.ap
	c.crit_chance = t.crit_chance
	c.crit_power = t.crit_power
	c.attack_range = t.attack_range
	c.dodge = t.dodge
#endregion


#region abilities (batch26)
## acid-spray.ts: 5 sprays chaining through adjacent enemies (each once): -5 SPE_DEF and
## 11 / 22 / 33 SPECIAL.
static func acid_spray(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var tg: BattleUnit = ctx.focus
	var done: Array[BattleUnit] = []
	for _i in 5:
		if tg == null:
			break
		show(ctx, [tg.cell])
		tg.add_stat("speDef", -5.0)
		hit(ctx, tg, by_stars(c, [11, 22, 33, 66]))
		done.append(tg)
		var next: BattleUnit = null
		for cell in BattleBoard.adjacent_cells(tg.cell):
			var u := sim.board.get_unit(cell)
			if u != null and u.alive and u.team != c.team and not done.has(u):
				next = u
				break
		tg = next


## astral-barrage.ts: jumps to a back corner and sends 3 / 5 / 7 ghosts (AP) at random
## enemies: 20 SPECIAL each.
static func astral_barrage(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var dest: Variant = sim.teleport_cell(c.cell, c.team)
	if dest != null:
		sim.move_unit(c, dest, 250.0, "dash")
	var foes := sim.enemies_of(c)
	if foes.is_empty():
		return
	var ghosts := int(by_stars(c, [3, 5, 7, 13]) * (1.0 + c.ap / 100.0))
	var delay := 500.0 / (1.0 + c.speed / 100.0) / (ghosts + 1)
	for i in ghosts:
		var e: BattleUnit = foes[sim.rng.randi() % foes.size()]
		sim.schedule(delay * (i + 1), c, func() -> void:
			if e.alive:
				show(ctx, [e.cell])
				hit(ctx, e, 20.0, BattleUnit.DamageKind.SPECIAL, false))


## behemoth-blade.ts: 30 / 60 / 90 + ATK as SPECIAL, then bounces behind the target.
static func behemoth_blade(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [30, 60, 90, 120]) + c.atk)
	_jump_behind(sim, c, t)


## getKnockBackPlace from the target: the caster lands behind it (or 60° aside; web: 45°).
static func _jump_behind(sim: BattleSim, c: BattleUnit, t: BattleUnit) -> void:
	var dir := BattleBoard.orientation(c.cell, t.cell)
	if dir == Vector2i.ZERO:
		dir = BattleBoard.DIRECTIONS[0]
	for d in BattleBoard.fan(dir):
		if sim.board.is_free(BattleBoard.step(t.cell, d)):
			sim.move_unit(c, BattleBoard.step(t.cell, d), 250.0, "dash")
			return


## bleakwind-storm.ts: enemies on the line to the target: 45 / 60 / 75 SPECIAL and FREEZE 2 s.
static func bleakwind_storm(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := line_through(c, t)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [45, 60, 75, 150]))
		status(ctx, e, "freeze", 2000.0)


## blue-flare.ts: 0.25 s later the target and the enemies around take 12 / 25 / 50 SPECIAL
## + 10 per Fire Pokémon of the team (synergy count).
static func blue_flare(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var fire := int(sim.team_info[c.team].get("counts", {}).get("FIRE", 0))
	var damage := by_stars(c, [12, 25, 50, 100]) + fire * by_stars(c, [10, 10, 10, 20])
	var aim := t.cell
	sim.schedule(250.0, c, func() -> void:
		var cells := BattleBoard.adjacent_cells(t.cell if t.alive else aim, true)
		show(ctx, cells)
		for e in enemies_on(ctx, cells):
			hit(ctx, e, damage))


## burning-jealousy.ts: the target and the enemies around take 30 / 50 / 70 SPECIAL; those
## with ATK buffs lose them and BURN 5 s.
static func burning_jealousy(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.adjacent_cells(t.cell, true)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [30, 50, 70, 140]))
		if e.alive and e.atk > e.base_atk:
			e.atk = e.base_atk
			status(ctx, e, "burn", 5000.0)


## chain-crazed.ts: poisons itself 3 s, +10 / 15 / 20 SPEED, +5 / 10 / 15 ATK and
## +3 / 6 / 10 DEF (AP).
static func chain_crazed(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var k := 1.0 + c.ap / 100.0
	show(ctx, [c.cell], "allies")
	sim.add_status(c, "poison", 3000.0, c)
	c.add_stat("speed", by_stars(c, [10, 15, 20, 25]))
	c.add_stat("atk", by_stars(c, [5, 10, 15, 20]) * k)
	c.add_stat("def", by_stars(c, [3, 6, 10, 15]) * k)


## charge-beam.ts: a beam chaining through 3 units of the target's team: 15 / 30 / 60 SPECIAL each.
static func charge_beam(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var chain: Array[BattleUnit] = [t]
	var at := t.cell
	for _n in 2:
		for cell in BattleBoard.adjacent_cells(at):
			var u := sim.board.get_unit(cell)
			if u != null and u.alive and u.team == t.team and not chain.has(u):
				chain.append(u)
				at = cell
				break
	show(ctx, chain.map(func(u: BattleUnit) -> Vector2i: return u.cell))
	for u in chain:
		hit(ctx, u, by_stars(c, [15, 30, 60, 120]))
#endregion


#region abilities (batch27)
## core-enforcer.ts: a Z around the target (rows above and below, the target itself):
## SILENCE 3 s and 20 / 40 / 60 SPECIAL.
static func core_enforcer(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells: Array = BattleBoard.adjacent_cells(t.cell, true).filter(func(cell: Vector2i) -> bool:
		return cell.y != t.cell.y or cell.x == t.cell.x)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		status(ctx, e, "silence", 3000.0)
		hit(ctx, e, by_stars(c, [20, 40, 60, 80]))


## crunch.ts: 40 / 80 / 160 SPECIAL; a KO heals 50% of the target max HP.
static func crunch(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var r := hit(ctx, t, by_stars(c, [40, 80, 160, 320]))
	if r.death:
		ctx.sim.heal(c, ceilf(0.5 * t.max_hp), c)


## dark-void.ts: enemies within 4 cells of the target take 10 / 20 / 30 SPECIAL, 80% SLEEP 2 s.
static func dark_void(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var foes := enemies_on(ctx, BattleBoard.cells_in_radius(t.cell, 4, true))
	show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	for e in foes:
		hit(ctx, e, by_stars(c, [10, 20, 30, 60]))
		if sim.chance(0.8, c):
			status(ctx, e, "sleep", 2000.0)


## doom-desire.ts: 2 s later 100 / 125 / 150 SPECIAL to the target (PP refilled if it is gone).
static func doom_desire(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	sim.schedule(2000.0, c, func() -> void:
		if t.alive:
			show(ctx, [t.cell])
			hit(ctx, t, by_stars(c, [100, 125, 150, 300]))
		else:
			c.pp = c.max_pp)
	c.cooldown = 200.0


## double-iron-bash.ts: 150% ATK as PHYSICAL twice, FLINCH 3 s.
static func double_iron_bash(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var damage := roundf(c.atk * by_stars(c, [1.5, 1.5, 1.5, 3.0]))
	for _i in 2:
		hit(ctx, t, damage, BattleUnit.DamageKind.PHYSICAL)
	status(ctx, t, "flinch", 3000.0)


## dynamax-cannon.ts: enemies on the line to the target take 30 / 40 / 50% of their max HP.
static func dynamax_cannon(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := line_through(c, t)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, ceilf(e.max_hp * by_stars(c, [0.3, 0.4, 0.5, 0.7])))


## extreme-speed.ts: dashes next to the farthest enemy: the enemies on the way take
## 20 / 30 / 40 SPECIAL (at least the target).
static func extreme_speed(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var hit_list: Array[BattleUnit] = []
	var spot := sim.farthest_spot(c)
	if not spot.is_empty():
		var path := BattleBoard.cells_between(c.cell, spot.cell)
		show(ctx, path)
		hit_list = enemies_on(ctx, path)
		sim.move_unit(c, spot.cell, 200.0, "dash")
	if hit_list.is_empty() and ctx.focus != null:
		hit_list.append(ctx.focus)
	for e in hit_list:
		hit(ctx, e, by_stars(c, [20, 30, 40, 80]))


## fleur-cannon.ts: enemies on the line to the target take 50 / 75 / 100 SPECIAL; -20 AP.
static func fleur_cannon(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t != null:
		var cells := line_through(c, t)
		show(ctx, cells)
		for e in enemies_on(ctx, cells):
			hit(ctx, e, by_stars(c, [50, 75, 100, 200]))
	c.add_stat("ap", -20.0)


## fusion-bolt.ts: 0.25 s later the target and the enemies around take 30 / 40 / 50 SPECIAL
## + 10 per Electric Pokémon of the team.
static func fusion_bolt(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var electric := int(sim.team_info[c.team].get("counts", {}).get("ELECTRIC", 0))
	var damage := by_stars(c, [30, 40, 50, 100]) + electric * by_stars(c, [10, 10, 10, 20])
	var aim := t.cell
	sim.schedule(250.0, c, func() -> void:
		var cells := BattleBoard.adjacent_cells(t.cell if t.alive else aim, true)
		show(ctx, cells)
		for e in enemies_on(ctx, cells):
			hit(ctx, e, damage))
#endregion


#region abilities (batch28)
## geomancy.ts: +15 ATK and +10 SPE_DEF (AP), +15 SPEED.
static func geomancy(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var k := 1.0 + c.ap / 100.0
	show(ctx, [c.cell], "allies")
	c.add_stat("atk", by_stars(c, [15, 15, 15, 30]) * k)
	c.add_stat("speDef", by_stars(c, [10, 10, 10, 20]) * k)
	c.add_stat("speed", 15.0)


## glacial-lance.ts: goes to a back corner, then throws a lance at the first enemy on the way
## to the farthest one: 300% ATK as SPECIAL, half to the enemies around it.
static func glacial_lance(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var dest: Variant = sim.teleport_cell(c.cell, c.team)
	if dest != null:
		sim.move_unit(c, dest, 250.0, "dash")
	var delay := roundf(500.0 / (1.0 + c.speed / 100.0)) if dest != null else 0.0
	sim.schedule(delay, c, func() -> void:
		if not c.alive:
			return
		var far: BattleUnit = sim.farthest_enemy(c)
		if far == null:
			far = ctx.focus
		if far == null or not far.alive:
			return
		var victim: BattleUnit = far
		for cell in BattleBoard.cells_between(c.cell, far.cell):
			var u := sim.board.get_unit(cell)
			if u != null and u.alive and u.team != c.team:
				victim = u
				break
		var damage := by_stars(c, [3, 3, 3, 6]) * c.atk
		show(ctx, [victim.cell])
		sim.schedule(500.0, c, func() -> void:
			if not victim.alive:
				return
			hit(ctx, victim, damage)
			for e in enemies_on(ctx, BattleBoard.adjacent_cells(victim.cell)):
				hit(ctx, e, damage * 0.5)))


## glaciate.ts: 0.3 s later the target and the enemies around take 30 / 40 / 50 SPECIAL + 10
## per Ice Pokémon of the team.
static func glaciate(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var ice := int(sim.team_info[c.team].get("counts", {}).get("ICE", 0))
	var damage := by_stars(c, [30, 40, 50, 100]) + ice * by_stars(c, [10, 10, 10, 20])
	var aim := t.cell
	sim.schedule(300.0, c, func() -> void:
		var cells := BattleBoard.adjacent_cells(t.cell if t.alive else aim, true)
		show(ctx, cells)
		for e in enemies_on(ctx, cells):
			hit(ctx, e, damage))


## heart-swap.ts: 60 / 80 / 100 SPECIAL; steals the target's SPE_DEF buffs and AP (unless
## Twist Band) and hands over its own negative statuses.
static func heart_swap(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var spe_boost := t.spe_def - t.base_spe_def
	var ap_boost := t.ap
	hit(ctx, t, by_stars(c, [60, 80, 100, 200]))
	if not t.has_item("TWIST_BAND"):
		t.add_stat("speDef", -spe_boost)
		t.add_stat("ap", -ap_boost)
		c.add_stat("speDef", maxf(0.0, spe_boost))
		c.add_stat("ap", ap_boost)
	for s in BattleUnit.NEGATIVE_STATUSES:
		if c.has_status(s) and s != "curse":
			sim.add_status(t, s, float(c.statuses[s]), c)
	c.cleanse()


## lands-wrath.ts: the target and the enemies around take 20 / 30 / 40 + 100% ATK (x AP) SPECIAL
## and lose 5 DEF and SPE_DEF (AP).
static func lands_wrath(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var k := 1.0 + c.ap / 100.0
	var damage := by_stars(c, [20, 30, 40, 80]) + roundf(c.atk * by_stars(c, [1, 1, 1, 2]) * k)
	var cells := BattleBoard.adjacent_cells(t.cell, true)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, damage, BattleUnit.DamageKind.SPECIAL, false)
		e.add_stat("def", AbilityRunner.adjust_buff(c, e, -by_stars(c, [5, 5, 5, 10]) * k))
		e.add_stat("speDef", AbilityRunner.adjust_buff(c, e, -by_stars(c, [5, 5, 5, 10]) * k))


## laser-blade.ts: odd casts spin behind the target (25 SHIELD, AP) hitting the enemies around
## both for 25 SPECIAL; even casts slash the target twice for 25 + ATK SPECIAL.
static func laser_blade(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	if c.cast_count % 2 == 1:
		var foes: Array[BattleUnit] = []
		for e in enemies_on(ctx, BattleBoard.adjacent_cells(c.cell) + BattleBoard.adjacent_cells(t.cell)):
			if not foes.has(e):
				foes.append(e)
		if not t.has_item("HEAVY_DUTY_BOOTS"):
			swap_units(sim, c.cell, t.cell)
		sim.add_shield(c, by_stars(c, [25, 25, 25, 50]) * (1.0 + c.ap / 100.0), c)
		show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
		for e in foes:
			hit(ctx, e, by_stars(c, [25, 25, 25, 50]))
	else:
		var damage := by_stars(c, [25, 25, 25, 50]) + c.atk
		show(ctx, [t.cell])
		hit(ctx, t, damage)
		sim.schedule(300.0, c, func() -> void:
			if t.alive:
				hit(ctx, t, damage))


## lock-on.ts: its next attack cannot be dodged and deals 200% (AP) extra as TRUE damage.
static func lock_on(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t != null:
		show(ctx, [t.cell])
	c.effects.lock_on = true


## lunar-blessing.ts: every wounded ally heals 25% max HP (AP) and is cleansed.
static func lunar_blessing(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies: Array = sim.alive_units(c.team).filter(func(a: BattleUnit) -> bool: return a.hp < a.max_hp)
	show(ctx, allies.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
	for a in allies:
		sim.heal(a, by_stars(c, [0.25, 0.25, 0.25, 0.5]) * a.max_hp * (1.0 + c.ap / 100.0), c)
		a.cleanse()


## lunge.ts: jumps next to the enemy with the most ATK: -3 / 4 / 5 ATK (AP) and 30 / 40 / 50 SPECIAL.
static func lunge(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var foes := sim.enemies_of(c)
	foes.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.atk > b.atk)
	for e in foes:
		var free: Array = BattleBoard.adjacent_cells(e.cell).filter(func(cell: Vector2i) -> bool:
			return sim.board.is_free(cell))
		if free.is_empty():
			continue
		sim.move_unit(c, free[0], 250.0, "dash")
		show(ctx, [e.cell])
		e.add_stat("atk", AbilityRunner.adjust_buff(c, e, -by_stars(c, [3, 4, 5, 10]) * (1.0 + c.ap / 100.0)))
		hit(ctx, e, by_stars(c, [30, 40, 50, 100]))
		return
#endregion


#region abilities (batch29)
## magma-storm.ts: a fire storm hops every 0.25 s to adjacent units of the target's team not hit
## yet: 50 / 75 / 100 SPECIAL, 20% weaker at each hit (5 hits at most).
static func magma_storm(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var state := {"power": 1.0, "hit": {}}
	var base := by_stars(c, [50, 75, 100, 200])
	var propagate := func(self_ref: Callable, cur: BattleUnit, depth: int) -> void:
		if depth >= 20 or state.power <= 0.001 or sim.finished:
			return
		state.hit[cur.id] = true
		show(ctx, [cur.cell])
		hit(ctx, cur, base * state.power)
		state.power -= 0.2
		if state.power <= 0.001:
			return
		sim.schedule(250.0, c, func() -> void:
			for cell in BattleBoard.adjacent_cells(cur.cell):
				var u := sim.board.get_unit(cell)
				if u != null and u.alive and u.team == cur.team and not state.hit.has(u.id):
					self_ref.call(self_ref, u, depth + 1))
	propagate.call(propagate, t, 0)


## malignant-chain.ts: POSSESSED and 3 POISON stacks for 3 s (AP).
static func malignant_chain(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var ms := roundf(by_stars(c, [3000, 3000, 3000, 6000]) * (1.0 + c.ap / 100.0))
	sim.add_status(t, "possessed", ms, c)
	for _i in int(by_stars(c, [3, 3, 3, 6])):
		sim.add_status(t, "poison", ms, c)


## mind-bend.ts: POSSESSED 2 s (AP); 100 SPECIAL instead on a protected or possessed target.
static func mind_bend(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	if t.has_status("safeguard") or t.has_status("possessed"):
		hit(ctx, t, by_stars(c, [100, 100, 100, 200]))
	else:
		sim.add_status(t, "possessed", roundf(by_stars(c, [2000, 2000, 2000, 4000]) * (1.0 + c.ap / 100.0)), c)


## mind-blown.ts: loses 50% max HP (TRUE); 3 / 4 / 5 fireworks burst over the target then random
## enemies (radius 2), by color: pink 20 PHYSICAL + BURN 5 s, blue 20 SPECIAL + FATIGUE 5 s,
## yellow 20 TRUE, white 20 SHIELD + cleanse for allies.
static func mind_blown(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	for i in int(by_stars(c, [3, 4, 5, 8])):
		var color := sim.rng.randi() % 4
		var foes := sim.enemies_of(c)
		var center: Vector2i = t.cell if i == 0 or foes.is_empty() else foes[sim.rng.randi() % foes.size()].cell
		sim.schedule(1000.0 + 250.0 * i, null, func() -> void:
			if sim.finished:
				return
			var cells := BattleBoard.cells_in_radius(center, 2, true)
			show(ctx, cells, "allies" if color == 3 else "enemies")
			for cell in cells:
				var u := sim.board.get_unit(cell)
				if u == null or not u.alive:
					continue
				if color == 3:
					if u.team == c.team:
						sim.add_shield(u, 20.0, c)
						u.cleanse()
				elif u.team != c.team:
					_firework(ctx, u, color))
	sim.deal_damage(c, c.max_hp / 2.0, BattleUnit.DamageKind.TRUE, c, false, false, false)


## One Mind Blown firework on an enemy: 0 pink, 1 blue, 2 yellow (no match inside lambdas).
static func _firework(ctx: Dictionary, u: BattleUnit, color: int) -> void:
	match color:
		0:
			hit(ctx, u, 20.0, BattleUnit.DamageKind.PHYSICAL, false)
			status(ctx, u, "burn", 5000.0)
		1:
			hit(ctx, u, 20.0, BattleUnit.DamageKind.SPECIAL, false)
			status(ctx, u, "fatigue", 5000.0)
		2:
			hit(ctx, u, 20.0, BattleUnit.DamageKind.TRUE, false)


## moongeist-beam.ts: on the line to the target, enemies get PARALYSIS 3 s and 60 / 80 / 100
## SPECIAL, allies gain as much SHIELD (AP).
static func moongeist_beam(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var amount := by_stars(c, [60, 80, 100, 200])
	var cells := line_through(c, t)
	show(ctx, cells, "all")
	for cell in cells:
		var u := sim.board.get_unit(cell)
		if u == null or not u.alive or u == c:
			continue
		if u.team != c.team:
			status(ctx, u, "paralysis", 3000.0)
			hit(ctx, u, amount)
		else:
			sim.add_shield(u, amount * (1.0 + c.ap / 100.0), c)


## multi-attack.ts: adjacent enemies take 7 / 10 / 13 SPECIAL per synergy level of its types.
static func multi_attack(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var counts: Dictionary = sim.team_info[c.team].get("counts", {})
	var levels := 0
	for type in c.types:
		levels += int(counts.get(type, 0))
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [7, 10, 13, 20]) * levels)


## oblivion-wing.ts: 90 / 120 / 150 SPECIAL, heals 75% of the damage dealt.
static func oblivion_wing(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var r := hit(ctx, t, by_stars(c, [90, 120, 150, 300]))
	if r.taken > 0.0:
		ctx.sim.heal(c, roundf(0.75 * r.taken), c)


## prismatic-laser.ts: a 3-column laser sweeps the board through the target, from the far side:
## 30 / 40 / 50 SPECIAL to the enemies, pushed one cell along.
static func prismatic_laser(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var flip := c.team == BattleUnit.Team.RED
	var step := -1 if flip else 1
	var cells: Array[Vector2i] = []
	for dx in [-1, 0, 1]:
		var x: int = t.cell.x + dx
		if x < 0 or x >= BattleBoard.WIDTH:
			continue
		var ys: Array = range(BattleBoard.HEIGHT) if flip else range(BattleBoard.HEIGHT - 1, -1, -1)
		for y in ys:
			cells.append(Vector2i(x, y))
			var e := sim.board.get_unit(Vector2i(x, y))
			if e == null or not e.alive or e.team == c.team:
				continue
			hit(ctx, e, by_stars(c, [30, 40, 50, 60]))
			var next := Vector2i(x, y + step)
			if e.alive and BattleBoard.in_bounds(next) and sim.board.is_free(next) and not e.has_item("HEAVY_DUTY_BOOTS"):
				sim.move_unit(e, next, 200.0, "knockback")
	show(ctx, cells)


## psycho-boost.ts: the target and its 2 row neighbours take 90 / 120 / 150 SPECIAL; -10 AP per hit.
static func psycho_boost(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	for dx in [-1, 0, 1]:
		var e := sim.board.get_unit(t.cell + Vector2i(dx, 0))
		if e != null and e.alive and e.team != c.team:
			show(ctx, [e.cell])
			hit(ctx, e, by_stars(c, [90, 120, 150, 300]))
			c.add_stat("ap", -10.0)
#endregion


#region abilities (batch30)
## relic-song.ts: every 3rd cast, every enemy SLEEPS 1 s x (2 + AP/100); otherwise every ally
## gains 10 SHIELD (AP).
static func relic_song(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if c.cast_count % 3 == 0:
		var foes := sim.enemies_of(c)
		show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
		for e in foes:
			sim.add_status(e, "sleep", roundf(by_stars(c, [1000, 1000, 1000, 2500]) * (2.0 + c.ap / 100.0)), c)
	else:
		var allies := sim.alive_units(c.team)
		show(ctx, allies.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
		for a in allies:
			sim.add_shield(a, by_stars(c, [10, 10, 10, 25]) * (1.0 + c.ap / 100.0), c)


## sacred-sword-cavern.ts: 40 / 60 / 80 TRUE + 20 per enemy on its side of the board.
static func sacred_sword_cavern(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var n := sim.enemies_of(c).filter(func(e: BattleUnit) -> bool:
		return e.cell.y < BattleBoard.SIDE_ROWS if c.team == BattleUnit.Team.BLUE else e.cell.y >= BattleBoard.SIDE_ROWS).size()
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [40, 60, 80, 160]) + by_stars(c, [20, 20, 20, 40]) * n, BattleUnit.DamageKind.TRUE)


## sacred-sword-grass.ts: 40 / 60 / 80 TRUE + 10 per ally still standing.
static func sacred_sword_grass(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [40, 60, 80, 160]) + by_stars(c, [10, 10, 10, 20]) * sim.alive_units(c.team).size(),
		BattleUnit.DamageKind.TRUE)


## sacred-sword-iron.ts: 40 / 60 / 80 TRUE + 15 per fallen ally.
static func sacred_sword_iron(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [40, 60, 80, 160]) + by_stars(c, [15, 15, 15, 30]) * sim.fallen[c.team],
		BattleUnit.DamageKind.TRUE)


## sandsear-storm.ts: enemies on the line to the target: 45 / 60 / 75 SPECIAL and BURN 2 s.
static func sandsear_storm(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := line_through(c, t)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [45, 60, 75, 150]))
		status(ctx, e, "burn", by_stars(c, [2000, 2000, 2000, 5000]))


## scale-shot.ts: ARMOR_BREAK 2 s on itself; 8 scales around it (adjacent enemies: ARMOR_BREAK
## 2 s and 40 SPECIAL), then 2 s later each flies at the farthest enemy: 10 / 15 / 20 to it,
## 10 to the enemies on the way.
static func scale_shot(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	sim.add_status(c, "armor_reduction", 2000.0, c)
	var around := BattleBoard.adjacent_cells(c.cell)
	show(ctx, around)
	for e in enemies_on(ctx, around):
		status(ctx, e, "armor_reduction", 2000.0)
		hit(ctx, e, by_stars(c, [40, 40, 40, 80]))
	for i in around.size():
		var from: Vector2i = around[i]
		sim.schedule(2000.0 + 100.0 * i, c, func() -> void:
			if c.has_status("freeze") or c.has_status("sleep"):
				return
			var far := sim.farthest_enemy(c)
			if far == null:
				return
			var path := BattleBoard.cells_between(from, far.cell)
			show(ctx, path)
			for e in enemies_on(ctx, path):
				hit(ctx, e, by_stars(c, [10, 15, 20, 40]) if e == far else by_stars(c, [10, 10, 10, 20])))


## searing-shot.ts: enemies within 2 cells take 30 / 40 / 50 SPECIAL and BURN 3 s.
static func searing_shot(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var foes := enemies_on(ctx, BattleBoard.cells_in_radius(c.cell, 2))
	show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	for e in foes:
		hit(ctx, e, by_stars(c, [30, 40, 50, 100]))
		status(ctx, e, "burn", by_stars(c, [3000, 3000, 3000, 6000]))


## secret-sword.ts: 50 / 100 / 150 SPECIAL, TRUE once it has blocked 20 hits (Fighting).
static func secret_sword(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var true_dmg := int(c.counters.get("fighting_blocks", 0)) >= 20
	hit(ctx, t, by_stars(c, [50, 100, 150, 300]),
		BattleUnit.DamageKind.TRUE if true_dmg else BattleUnit.DamageKind.SPECIAL)


## seed-flare.ts: enemies within 5 cells lose 3 SPE_DEF and take 20 / 25 / 30 SPECIAL.
static func seed_flare(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var foes := enemies_on(ctx, BattleBoard.cells_in_radius(c.cell, 5))
	show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	for e in foes:
		e.add_stat("speDef", -by_stars(c, [3, 3, 3, 3]))
		hit(ctx, e, by_stars(c, [20, 25, 30, 35]))
#endregion


#region abilities (batch31)
## shadow-claw.ts: enemies in front of it take 20 / 40 / 60 SPECIAL (60 / 100 / 140 when only
## one), heals 25% of the damage dealt.
static func shadow_claw(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.cells_in_front(c.cell, t.cell, 1)
	show(ctx, cells)
	var foes := enemies_on(ctx, cells)
	var damage := by_stars(c, [60, 100, 140, 280]) if foes.size() == 1 else by_stars(c, [20, 40, 60, 120])
	var done := 0.0
	for e in foes:
		done += float(hit(ctx, e, damage).taken)
	if done > 0.0:
		ctx.sim.heal(c, done * 0.25, c)


## spectral-thief.ts: 30 / 40 / 50 SPECIAL, rushes behind the farthest enemy and steals every
## stat buff of the target (unless Twist Band).
static func spectral_thief(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var spot := sim.farthest_spot(c)
	if spot.is_empty():
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [30, 40, 50, 100]))
	sim.move_unit(c, spot.cell, 250.0, "dash")
	if not t.alive or t.has_item("TWIST_BAND"):
		return
	var base := GameData.get_pokemon(t.pkm)
	var boosts := {
		"atk": maxf(0.0, t.atk - t.base_atk),
		"speed": maxf(0.0, t.speed - float(base.get("speed", t.speed))),
		"def": maxf(0.0, t.def - t.base_def),
		"speDef": maxf(0.0, t.spe_def - t.base_spe_def),
		"ap": t.ap,
		"maxHP": maxf(0.0, t.max_hp - float(base.get("hp", t.max_hp))),
		"critChance": maxf(0.0, t.crit_chance - 10.0),
		"critPower": maxf(0.0, t.crit_power - 2.0),
		"luck": maxf(0.0, t.luck),
	}
	for stat in boosts:
		t.add_stat(stat, -boosts[stat])
		c.add_stat(stat, boosts[stat])


## springtide-storm.ts: enemies on the line to the target: 45 / 60 / 75 SPECIAL and CHARM 2 s.
static func springtide_storm(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := line_through(c, t)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [45, 60, 75, 150]))
		status(ctx, e, "charm", 2000.0)


## steam-eruption.ts: the target and the enemies around take 20 / 40 / 80 SPECIAL and BURN 3 s.
static func steam_eruption(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.adjacent_cells(t.cell, true)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [20, 40, 80, 160]))
		status(ctx, e, "burn", 3000.0)


## sunsteel-strike.ts: skydives where the enemies are the most packed, 1 s later the enemies
## around take 40 / 60 / 80 SPECIAL.
static func sunsteel_strike(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var dest: Variant = null
	var best := 0
	for cell in sim.board.free_cells():
		var n := enemies_on(ctx, BattleBoard.adjacent_cells(cell)).size()
		if n > best:
			best = n
			dest = cell
	if dest == null:
		return
	sim.move_unit(c, dest, 500.0, "dash")
	sim.schedule(1000.0, c, func() -> void:
		var cells := BattleBoard.adjacent_cells(c.cell)
		show(ctx, cells)
		for e in enemies_on(ctx, cells):
			hit(ctx, e, by_stars(c, [40, 60, 80, 150])))


## surging-strikes.ts: 3 strikes, every 0.2 s: 100% ATK as SPECIAL, always critical.
static func surging_strikes(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var damage := c.atk * by_stars(c, [1, 1, 1, 2])
	for i in 3:
		sim.schedule(200.0 * i, c, func() -> void:
			if t.alive:
				show(ctx, [t.cell])
				hit(ctx, t, damage, BattleUnit.DamageKind.SPECIAL, true, true))
	c.cooldown += 600.0


## thousand-arrows.ts: 33 arrows on random cells, every 0.1 s: enemies hit are LOCKED 1 s and
## take 40 / 50 / 60 SPECIAL.
static func thousand_arrows(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	for i in 33:
		sim.schedule(100.0 * i, c, func() -> void:
			var cell := Vector2i(sim.rng.randi() % BattleBoard.WIDTH, sim.rng.randi() % BattleBoard.HEIGHT)
			show(ctx, [cell])
			var e := sim.board.get_unit(cell)
			if e != null and e.alive and e.team != c.team:
				status(ctx, e, "locked", 1000.0)
				hit(ctx, e, by_stars(c, [40, 50, 60, 100])))
#endregion


#region abilities (batch32)
## time-travel.ts: every ally heals 25 (AP) and is cleansed; Celebi also gives the player 1 life.
static func time_travel(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies := sim.alive_units(c.team)
	show(ctx, allies.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
	for a in allies:
		sim.heal(a, by_stars(c, [25, 25, 25, 50]) * (1.0 + c.ap / 100.0), c)
		a.cleanse()
	if sim.player != null and c.team == BattleUnit.Team.BLUE and c.passive == "CELEBI" \
			and sim.player.life + int(sim.rewards.get("life", 0)) < 100:
		sim.rewards.life = int(sim.rewards.get("life", 0)) + 1


## ultra-thrusters.ts: adjacent enemies take 20 / 40 / 80 SPECIAL and BURN 2 s, then it
## blasts off to a back corner.
static func ultra_thrusters(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [20, 40, 80, 160]))
		status(ctx, e, "burn", 2000.0)
	var dest: Variant = sim.teleport_cell(c.cell, c.team)
	if dest != null:
		sim.move_unit(c, dest, 300.0, "dash")
		c.cooldown = 600.0


## u-turn.ts: trades places with the target, 15 / 30 / 50 SHIELD (AP), CHARM 1 s on the target.
static func u_turn(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	if not t.has_item("HEAVY_DUTY_BOOTS"):
		swap_units(sim, c.cell, t.cell)
	sim.add_shield(c, by_stars(c, [15, 30, 50, 100]) * (1.0 + c.ap / 100.0), c)
	status(ctx, t, "charm", 1000.0)


## wicked-blow.ts: 30 / 45 / 60 TRUE, always critical.
static func wicked_blow(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [30, 45, 60, 120]), BattleUnit.DamageKind.TRUE, true, true)


## wildbolt-storm.ts: enemies on the line to the target: PARALYSIS 4 s and 45 / 60 / 75 SPECIAL.
static func wildbolt_storm(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := line_through(c, t)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		status(ctx, e, "paralysis", 4000.0)
		hit(ctx, e, by_stars(c, [45, 60, 75, 150]))
#endregion


#region abilities (batch33)
## brave-bird.ts: flies to a safe cell, pulls the target to a free cell next to it and
## deals 30 / 60 / 90 SPECIAL.
static func brave_bird(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var dest: Variant = AbilityRunner.fly_away_cell(sim, c)
	if dest == null:
		return
	sim.move_unit(c, dest, 250.0, "dash")
	for cell in BattleBoard.adjacent_cells(dest):
		if sim.board.is_free(cell):
			if not t.has_item("HEAVY_DUTY_BOOTS") and not t.inanimate:
				sim.move_unit(t, cell, 250.0, "knockback")
			show(ctx, [t.cell])
			hit(ctx, t, by_stars(c, [30, 60, 90, 180]))
			return


## discharge.ts: the adjacent enemies: PARALYSIS 5 s and 25 / 50 / 100 SPECIAL.
static func discharge(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		status(ctx, e, "paralysis", 5000.0)
		hit(ctx, e, by_stars(c, [25, 50, 100, 200]))


## expanding-force.ts: gets a PSYCHIC FIELD, or gives one to the closest ally without it;
## every ally in a Psychic Field deals 10 / 20 / 40 SPECIAL to the enemies next to it.
static func expanding_force(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if not c.has_status("psychic_field"):
		sim.add_status(c, "psychic_field", 1e9, c)
	else:
		var others := sim.allies_of(c).filter(func(a: BattleUnit) -> bool:
			return a != c and not a.has_status("psychic_field"))
		others.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
			return BattleBoard.distance_m(a.cell, c.cell) < BattleBoard.distance_m(b.cell, c.cell))
		if not others.is_empty():
			sim.add_status(others[0], "psychic_field", 1e9, c)
	var damage := by_stars(c, [10, 20, 40, 80])
	for a in sim.allies_of(c):
		if not a.has_status("psychic_field"):
			continue
		var cells := BattleBoard.adjacent_cells(a.cell)
		show(ctx, cells)
		for e in enemies_on(ctx, cells):
			hit(ctx, e, damage)


## hurricane.ts: the line through the target: PARALYSIS 3 s and 25 / 50 / 100 SPECIAL.
static func hurricane(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	if ctx.focus == null:
		return
	var cells := line_through(c, ctx.focus)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		status(ctx, e, "paralysis", 3000.0)
		hit(ctx, e, by_stars(c, [25, 50, 100, 200]))


## mud-bubble.ts: heals 10 / 20 / 40 (AP), acts again sooner.
static func mud_bubble(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	ctx.sim.heal(c, by_stars(c, [10, 20, 40, 80]) * (1.0 + c.ap / 100.0), c)
	c.cooldown = 250.0


## razor-leaf.ts: 20 / 40 / 80 SPECIAL to the enemies from it toward the target to the
## board edge; can crit.
static func razor_leaf(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if ctx.focus == null:
		return
	var crit := sim.chance(c.crit_chance / 100.0, c)
	var cells := ray_from(c.cell, BattleBoard.orientation(c.cell, ctx.focus.cell))
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [20, 40, 80, 160]), BattleUnit.DamageKind.SPECIAL, true, crit)


## roost.ts: flies to a safe cell, SLEEP 1 s, 20 / 40 / 80 SHIELD (AP).
static func roost(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var dest: Variant = AbilityRunner.fly_away_cell(sim, c)
	if dest != null:
		sim.move_unit(c, dest, 250.0, "dash")
	sim.add_status(c, "sleep", 1000.0, c)
	sim.add_shield(c, by_stars(c, [20, 40, 80, 160]) * (1.0 + c.ap / 100.0), c)


## shelter.ts: +3 / 6 / 12 DEF (AP) and SMOKE on the target's cell.
static func shelter(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	c.add_stat("def", by_stars(c, [3, 6, 12, 24]) * (1.0 + c.ap / 100.0))
	if ctx.focus != null:
		board_effect(ctx.sim, [ctx.focus.cell], "SMOKE")


## tail-whip.ts: the target loses 20 / 30 / 40% of its DEF (AP).
static func tail_whip(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	t.add_stat("def", AbilityRunner.adjust_buff(c, t, -by_stars(c, [0.2, 0.3, 0.4, 0.5]) * t.def * (1.0 + c.ap / 100.0)))


## torment.ts: +20 / 35 / 50 SPEED (AP), acts again sooner.
static func torment(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	c.add_stat("speed", by_stars(c, [20, 35, 50, 65]) * (1.0 + c.ap / 100.0))
	c.cooldown = 500.0
#endregion


#region abilities (batch34)
## bitter-malice.ts: 25 / 50 / 100 SPECIAL and FATIGUE 3 s (AP) to the target; while
## disguised (Illusion), also to the enemies around the target, and the disguise breaks.
static func bitter_malice(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var targets: Array[BattleUnit] = [t]
	if c.effects.has("disguise"):
		c.effects.erase("disguise")
		sim.emit({"type": "transform", "unit": c, "pkm": c.pkm})
		var cells := BattleBoard.adjacent_cells(t.cell, true)
		show(ctx, cells)
		targets = enemies_on(ctx, cells)
	else:
		show(ctx, [t.cell])
	for e in targets:
		hit(ctx, e, by_stars(c, [25, 50, 100, 200]))
		status(ctx, e, "fatigue", 3000.0, true)


## burn-up.ts: 50 / 100 / 200 SPECIAL to the target, BURN 3 s on itself.
static func burn_up(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	if ctx.focus != null:
		show(ctx, [ctx.focus.cell])
		hit(ctx, ctx.focus, by_stars(c, [50, 100, 200, 400]))
	ctx.sim.add_status(c, "burn", 3000.0, c)


## chloroblast.ts: 50 / 100 / 200 SPECIAL to the adjacent enemies, half of its max HP
## as TRUE to itself (AP boosted like the web; not with Protective Pads).
static func chloroblast(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [50, 100, 200, 400]))
	if not c.has_item("PROTECTIVE_PADS"):
		hit(ctx, c, 0.5 * c.max_hp, BattleUnit.DamageKind.TRUE)


## crush-claw.ts: the target loses 5 / 10 / 15 DEF, then takes 2 hits of 100% ATK
## (200% / 400% at 3★ / 4★) as PHYSICAL.
static func crush_claw(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	t.add_stat("def", AbilityRunner.adjust_buff(c, t, -by_stars(c, [5, 10, 15, 20])))
	for _i in 2:
		hit(ctx, t, c.atk * by_stars(c, [1, 1, 2, 4]), BattleUnit.DamageKind.PHYSICAL)


## double-edge.ts: 55 / 110 / 220 PHYSICAL to the target, 20 / 40 / 60 PHYSICAL to itself
## (not with Protective Pads).
static func double_edge(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	if ctx.focus != null:
		show(ctx, [ctx.focus.cell])
		hit(ctx, ctx.focus, by_stars(c, [55, 110, 220, 440]), BattleUnit.DamageKind.PHYSICAL)
	if not c.has_item("PROTECTIVE_PADS"):
		hit(ctx, c, by_stars(c, [20, 40, 60, 80]), BattleUnit.DamageKind.PHYSICAL)


## dragon-claw.ts: the adjacent enemy with the lowest max HP (else the target) takes
## 30 / 60 / 120 SPECIAL and WOUND 4 s, and becomes the target.
static func dragon_claw(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = null
	for e in enemies_on(ctx, BattleBoard.adjacent_cells(c.cell)):
		if t == null or e.max_hp < t.max_hp:
			t = e
	if t == null:
		t = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [30, 60, 120, 240]))
	status(ctx, t, "wound", 4000.0)
	c.target = t


## Bounces of Eerie Spell / Shell Side Arm: the target, then 3 more units not hit yet
## (both teams), the lowest (`lowest`) or highest HP first; `effect` is called on each.
static func _bounce(ctx: Dictionary, first: BattleUnit, lowest: bool, effect: Callable) -> void:
	var sim: BattleSim = ctx.sim
	var visited := {}
	var current := first
	for i in 4:
		if current != null:
			visited[current] = true
			show(ctx, [current.cell], "all")
			effect.call(current)
		var rest := sim.units.filter(func(u: BattleUnit) -> bool:
			return u.alive and not u.inanimate and not visited.has(u))
		rest.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
			return a.hp < b.hp if lowest else a.hp > b.hp)
		current = rest[0] if not rest.is_empty() else null


## eerie-spell.ts: bounces 4 times, lowest HP first: allies heal 15 / 30 / 45 (AP),
## enemies take 10 / 20 / 40 SPECIAL.
static func eerie_spell(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if ctx.focus == null:
		return
	_bounce(ctx, ctx.focus, true, func(u: BattleUnit) -> void:
		if u.team == c.team:
			sim.heal(u, by_stars(c, [15, 30, 45, 90]) * (1.0 + c.ap / 100.0), c)
		else:
			hit(ctx, u, by_stars(c, [10, 20, 40, 80])))


## ice-spinner.ts: spins over its cell and the 6 around (one every 0.1 s): clears their
## board effects; enemies there take 15 / 30 / 60 SPECIAL and are knocked back.
static func ice_spinner(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var damage := by_stars(c, [15, 30, 60, 120])
	var delay := 0.0
	for cell in BattleBoard.adjacent_cells(c.cell, true):
		sim.schedule(delay, c, func() -> void:
			show(ctx, [cell])
			if sim.board_effects.has(cell):
				sim.board_effects.erase(cell)
				sim.emit({"type": "board_effect", "cells": [] as Array[Vector2i], "effect": ""})
			var e := sim.board.get_unit(cell)
			if e != null and e.alive and e.team != c.team:
				hit(ctx, e, damage)
				knock_back(sim, e, BattleBoard.orientation(c.cell, e.cell)))
		delay += 100.0


## infernal-parade.ts: the enemies between it and the farthest enemy (else the target):
## 50% BURN 3 s, 30 SPECIAL now and 30 SPECIAL 0.5 s later (60 at 4★).
static func infernal_parade(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var far := sim.farthest_enemy(c)
	if far == null:
		far = ctx.focus
	if far == null:
		return
	var cells := BattleBoard.cells_between(c.cell, far.cell)
	show(ctx, cells)
	var targets := enemies_on(ctx, cells)
	if targets.is_empty() and ctx.focus != null:
		targets.append(ctx.focus)
	var damage := by_stars(c, [30, 30, 30, 60])
	for e in targets:
		if sim.chance(0.5, c):
			status(ctx, e, "burn", 3000.0)
		hit(ctx, e, damage)
		sim.schedule(500.0, e, func() -> void: hit(ctx, e, damage))


static var _metronome_skills := {} ## rarity -> ported abilities of its Pokémon


## metronome.ts: casts the ability of a random Pokémon of a random rarity (luck helps
## reaching the rarest ones); inimitable abilities excluded.
static func metronome(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var threshold := pow(sim.rng.randf(), 1.0 + c.luck / 100.0)
	var rarities := ["ULTRA", "LEGENDARY", "EPIC", "UNIQUE", "RARE", "SPECIAL", "UNCOMMON", "COMMON"]
	var rarity: String = rarities[clampi(int(threshold * 8.0), 0, 7)]
	if not _metronome_skills.has(rarity):
		var skills: Array[String] = []
		for pkm in GameData.pokemon:
			var d: Dictionary = GameData.pokemon[pkm]
			var s := String(d.get("skill", ""))
			if (d.rarity == rarity or (rarity == "SPECIAL" and d.rarity == "HATCH")) and not skills.has(s) \
					and GameData.is_ability_ported(s) and not GameData.get_ability(s).get("inimitable", false):
				skills.append(s)
		_metronome_skills[rarity] = skills
	var options: Array = _metronome_skills[rarity]
	if not options.is_empty():
		run_other(ctx, options[sim.rng.randi() % options.size()], ctx.focus)


## shell-side-arm.ts: bounces 4 times, highest HP first: allies gain 10 / 20 / 30 AP,
## enemies get POISON 2 / 3 / 4 s (AP).
static func shell_side_arm(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if ctx.focus == null:
		return
	var ms := by_stars(c, [2000, 3000, 4000, 6000]) * (1.0 + c.ap / 100.0)
	_bounce(ctx, ctx.focus, false, func(u: BattleUnit) -> void:
		if u.team == c.team:
			u.add_stat("ap", AbilityRunner.adjust_buff(c, u, by_stars(c, [10, 20, 30, 50])))
		else:
			sim.add_status(u, "poison", ms, c))


## spin-out.ts: 25 / 50 / 100% of its SPEED as SPECIAL and BLINDED 1 s to the target,
## then drives back to its backline; its Acceleration stacks are spent.
static func spin_out(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, roundf(by_stars(c, [0.25, 0.5, 1, 2]) * c.speed))
	status(ctx, t, "blinded", 1000.0)
	var corner: Variant = sim.teleport_cell(c.cell, c.team)
	if corner != null:
		sim.schedule(100.0, c, func() -> void: sim.move_unit(c, corner, 300.0, "dash"))
	var stacks := int(c.counters.get("acceleration", 0))
	if stacks > 0:
		c.add_stat("speed", -15.0 * stacks)
		c.counters.acceleration = 0


## spirit-break.ts: 20 / 40 / 80 SPECIAL and -20 AP (AP) to the target.
static func spirit_break(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [20, 40, 80, 160]))
	t.add_stat("ap", AbilityRunner.adjust_buff(c, t, -20.0 * (1.0 + c.ap / 100.0)))


## strange-steam.ts: STRANGE_STEAM on the cells within (casts) of it: enemies there 30%
## (100% at 3★) CONFUSION 3 s (AP), allies get a FAIRY FIELD.
static func strange_steam(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.cells_in_radius(c.cell, maxi(c.cast_count, 1), true)
	board_effect(sim, cells, "STRANGE_STEAM")
	for cell in cells:
		var u := sim.board.get_unit(cell)
		if u == null or not u.alive:
			continue
		if u.team != c.team:
			if sim.chance(by_stars(c, [0.3, 0.3, 1.0, 1.0]), c):
				status(ctx, u, "confusion", 3000.0, true)
		else:
			sim.add_status(u, "fairy_field", 1e9, c)


## suction-heal.ts: 15 / 30 / 60 SPECIAL to the enemies up to 2 cells in front of it;
## heals half of the damage done.
static func suction_heal(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if ctx.focus == null:
		return
	var cells := BattleBoard.cells_in_front(c.cell, ctx.focus.cell, 2)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		var r := hit(ctx, e, by_stars(c, [15, 30, 60, 120]))
		sim.heal(c, float(r.taken) * 0.5, c)


## victory-dance.ts: +3 ATK, +3 DEF and +10 SPEED (AP).
static func victory_dance(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var k := 1.0 + c.ap / 100.0
	c.add_stat("atk", 3.0 * k)
	c.add_stat("def", 3.0 * k)
	c.add_stat("speed", 10.0 * k)
#endregion


#region abilities (batch35)
## aurora-veil.ts: every ally gains 5 / 10 / 20 SHIELD (AP) and RUNE PROTECT 1 s.
static func aurora_veil(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies := sim.allies_of(c)
	show(ctx, allies.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
	for a in allies:
		sim.add_shield(a, by_stars(c, [5, 10, 20, 50]) * (1.0 + c.ap / 100.0), c)
		sim.add_status(a, "safeguard", 1000.0, c)


## grudge.ts: SILENCE 3 s on the target, then every silenced enemy takes 18 / 36 / 52 SPECIAL.
static func grudge(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if ctx.focus == null:
		return
	status(ctx, ctx.focus, "silence", 3000.0)
	var silenced := sim.enemies_of(c).filter(func(e: BattleUnit) -> bool: return e.has_status("silence"))
	show(ctx, silenced.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	for e in silenced:
		hit(ctx, e, by_stars(c, [18, 36, 52, 104]))


## high-jump-kick.ts: steals up to 40 PP of the target (not with Twist Band), then
## 15 / 30 / 60 SPECIAL.
static func high_jump_kick(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	if not t.has_item("TWIST_BAND"):
		c.add_pp(t.drain_pp(40.0))
	hit(ctx, t, by_stars(c, [15, 30, 60, 120]))


## metal-claw.ts: 10 / 20 / 40 TRUE to the target, +2 / 4 / 6 ATK (AP).
static func metal_claw(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	if ctx.focus != null:
		show(ctx, [ctx.focus.cell])
		hit(ctx, ctx.focus, by_stars(c, [10, 20, 40, 80]), BattleUnit.DamageKind.TRUE)
	c.add_stat("atk", by_stars(c, [2, 4, 6, 12]) * (1.0 + c.ap / 100.0))


## obstruct.ts: PROTECT 0.5 / 0.75 / 1 s x (2 + AP/100); meanwhile its attackers lose 2 DEF.
static func obstruct(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var ms := roundf(by_stars(c, [500, 750, 1000, 2000]) * (2.0 + c.ap / 100.0))
	show(ctx, [c.cell], "allies")
	sim.add_status(c, "protect", ms, c)
	c.effects.obstruct = true
	sim.schedule(ms, null, func() -> void: c.effects.erase("obstruct"))


## overdrive.ts: enemies within 3 cells of the target (not the target itself): 120% ATK
## (150 / 300% at 3★ / 4★) as SPECIAL, 20% less per cell away from the caster.
static func overdrive(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	if ctx.focus == null:
		return
	var cells := BattleBoard.cells_in_radius(ctx.focus.cell, 3)
	show(ctx, cells)
	var base := by_stars(c, [1.2, 1.2, 1.5, 3])
	for e in enemies_on(ctx, cells):
		var distance := BattleBoard.distance_c(e.cell, c.cell)
		hit(ctx, e, c.atk * (base - 0.2 * (distance - 1)))


## pickup.ts: takes the first item of the target if it can hold one more (the web also
## steals gold from the target's player, none in the wild), then 30 / 60 / 120 SPECIAL.
static func pickup(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	if not t.items.is_empty() and c.items.size() < BattleUnit.MAX_ITEMS:
		var item := t.items[0]
		if not GameData.item_in(item, "AbsorbedItems"):
			take_item(t, item)
			c.equip([item])
	hit(ctx, t, by_stars(c, [30, 60, 120, 240]))


## pollen-puff.ts: the ally with the lowest HP heals 30 / 60 / 120 (AP).
static func pollen_puff(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies := sim.allies_of(c)
	allies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.hp < b.hp)
	if allies.is_empty():
		return
	show(ctx, [allies[0].cell], "allies")
	sim.heal(allies[0], by_stars(c, [30, 60, 120, 240]) * (1.0 + c.ap / 100.0), c)


## quiver-dance.ts: +3 / 4 / 5 ATK and SPE_DEF, +10 SPEED (AP), +20 AP.
static func quiver_dance(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var k := 1.0 + c.ap / 100.0
	c.add_stat("atk", by_stars(c, [3, 4, 5, 10]) * k)
	c.add_stat("speDef", by_stars(c, [3, 4, 5, 10]) * k)
	c.add_stat("speed", by_stars(c, [10, 10, 10, 15]) * k)
	c.add_stat("ap", 20.0)


## recover.ts: heals 25% of its max HP (50 / 100% at 3★ / 4★), AP boosted.
static func recover(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	ctx.sim.heal(c, by_stars(c, [0.25, 0.25, 0.5, 1.0]) * c.max_hp * (1.0 + c.ap / 100.0), c)


## steel-wing.ts: flies next to the farthest enemy; the enemies on the way (else the
## target) take 10 / 20 / 40 + 200% DEF as SPECIAL and give it 1 DEF each (Twist Band: no).
static func steel_wing(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var damage := by_stars(c, [10, 20, 40, 80]) + 2.0 * c.def
	var targets: Array[BattleUnit] = []
	var spot := sim.farthest_spot(c)
	if not spot.is_empty():
		var cells := BattleBoard.cells_between(c.cell, spot.cell)
		show(ctx, cells)
		targets = enemies_on(ctx, cells)
		sim.move_unit(c, spot.cell, 300.0, "dash")
	if targets.is_empty() and ctx.focus != null:
		targets.append(ctx.focus)
	for e in targets:
		if not e.has_item("TWIST_BAND"):
			c.add_stat("def", 1.0)
			e.add_stat("def", -1.0)
		hit(ctx, e, damage)
#endregion


#region abilities (batch36)
## ancient-power.ts: 40 / 80 / 120 SPECIAL to the target, +25 AP.
static func ancient_power(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	if ctx.focus != null:
		show(ctx, [ctx.focus.cell])
		hit(ctx, ctx.focus, by_stars(c, [40, 80, 120, 200]))
	c.add_stat("ap", 25.0)


## ceaseless-edge.ts: SPIKES on the cells in front of it; enemies there take 20 / 40 / 80
## SPECIAL. Can crit.
static func ceaseless_edge(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if ctx.focus == null:
		return
	var crit := sim.chance(c.crit_chance / 100.0, c)
	var cells := BattleBoard.cells_in_front(c.cell, ctx.focus.cell, 1)
	board_effect(sim, cells, "SPIKES")
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [20, 40, 80, 160]), BattleUnit.DamageKind.SPECIAL, true, crit)


## clangorous-soul.ts: itself and the adjacent allies gain 2 / 4 / 8 ATK, DEF and SPE_DEF (AP).
static func clangorous_soul(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var buff := by_stars(c, [2, 4, 8, 16]) * (1.0 + c.ap / 100.0)
	var cells := BattleBoard.adjacent_cells(c.cell, true)
	show(ctx, cells, "allies")
	for cell in cells:
		var a := sim.board.get_unit(cell)
		if a != null and a.alive and a.team == c.team:
			for stat in ["atk", "def", "speDef"]:
				a.add_stat(stat, AbilityRunner.adjust_buff(c, a, buff))


## curse.ts: a random enemy among the highest max HP ones is CURSED: KO in 8 / 5 / 3 s
## (shorter with AP).
static func curse(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var enemies := sim.enemies_of(c)
	if enemies.is_empty():
		return
	var highest := 0.0
	for e in enemies:
		highest = maxf(highest, e.max_hp)
	var top := enemies.filter(func(e: BattleUnit) -> bool: return e.max_hp == highest)
	var cursed: BattleUnit = top[sim.rng.randi() % top.size()]
	show(ctx, [cursed.cell])
	var delay := maxf(0.0, by_stars(c, [8000, 5000, 3000, 1000]) * (1.0 - 0.2 * c.ap / 100.0))
	sim.add_status(cursed, "curse", delay, c)


## dire-claw.ts: POISON, SLEEP or PARALYSIS (random) 3 s, then 15 / 30 / 60 SPECIAL.
static func dire_claw(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	status(ctx, t, ["poison", "sleep", "paralysis"][sim.rng.randi() % 3], 3000.0)
	hit(ctx, t, by_stars(c, [15, 30, 60, 120]))


## dream-eater.ts: a sleeping enemy: moves next to it, 45 / 90 / 150 SPECIAL, heals the
## damage done. Else puts an enemy that can sleep to SLEEP 3 / 4 / 5 s (AP) and refills
## its PP (the web sleeps the target even when only another enemy can).
static func dream_eater(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var enemies: Array[BattleUnit] = []
	for u in sim.board.units(): # board order, like board.find
		if u.alive and u.team != c.team:
			enemies.append(u)
	var sleeping: BattleUnit = null
	for e in enemies:
		if e.has_status("sleep"):
			sleeping = e
			break
	if sleeping != null:
		show(ctx, [sleeping.cell])
		var free: Variant = sim.nearest_free_cell(sleeping.cell, 1)
		if free != null:
			sim.move_unit(c, free, 250.0, "dash")
		var r := hit(ctx, sleeping, by_stars(c, [45, 90, 150, 250]))
		sim.heal(c, float(r.taken), c)
		return
	# web: if any enemy could fall asleep, the TARGET is put to sleep (even if it cannot) and the
	# PP is refilled
	var t: BattleUnit = ctx.focus
	var candidates: Array = [t] if t != null else []
	candidates.append_array(enemies)
	for e in candidates:
		if e.alive and not e.is_immune_to("sleep") and not e.has_status("skydiving"):
			if t != null:
				show(ctx, [t.cell])
				status(ctx, t, "sleep", roundf(by_stars(c, [3000, 4000, 5000, 6000]) * (1.0 + c.ap / 100.0)))
			c.pp = c.max_pp
			return


## drill-peck.ts: 30 / 60 / 120 SPECIAL to the target and trades places with it; a unit of
## its team right behind it becomes the next target, PP refilled.
static func drill_peck(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var dir := BattleBoard.orientation(c.cell, t.cell)
	var behind := BattleBoard.step(t.cell, dir)
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [30, 60, 120, 240]))
	if t.alive:
		swap_units(sim, c.cell, t.cell)
	elif sim.board.is_free(t.cell):
		sim.move_unit(c, t.cell, 250.0, "dash")
	var next := sim.board.get_unit(behind) if BattleBoard.in_bounds(behind) else null
	if next != null and next.alive and next.team == t.team:
		c.target = next
		c.pp = c.max_pp


## eruption.ts: 20 / 30 / 45 rocks fall on random cells (one every 0.1 s); enemies hit take
## 30 / 50 / 70 SPECIAL and BURN 5 s.
static func eruption(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var damage := by_stars(c, [30, 50, 70, 90])
	for i in int(by_stars(c, [20, 30, 45, 60])):
		sim.schedule(i * 100.0, c, func() -> void:
			var cell := Vector2i(sim.rng.randi_range(0, BattleBoard.WIDTH - 1), sim.rng.randi_range(0, BattleBoard.HEIGHT - 1))
			show(ctx, [cell])
			var e := sim.board.get_unit(cell)
			if e != null and e.alive and e.team != c.team:
				hit(ctx, e, damage)
				status(ctx, e, "burn", 5000.0))


## fiery-dance.ts: +30 AP, then 25 / 50 / 100 SPECIAL to the target.
static func fiery_dance(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	c.add_stat("ap", 30.0)
	if ctx.focus != null:
		show(ctx, [ctx.focus.cell])
		hit(ctx, ctx.focus, by_stars(c, [25, 50, 100, 200]))


## muddy-water.ts: enemies in front of it: 40 / 80 / 160 SPECIAL, ARMOR_REDUCTION and WOUND 4 s.
static func muddy_water(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	if ctx.focus == null:
		return
	var cells := BattleBoard.cells_in_front(c.cell, ctx.focus.cell, 1)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [40, 80, 160, 320]))
		status(ctx, e, "armor_reduction", 4000.0)
		status(ctx, e, "wound", 4000.0)


## natural-gift.ts: the ally with the lowest HP ratio heals 30 / 60 / 90 (AP) and gets
## RUNE PROTECT 1 / 2 / 3 s.
static func natural_gift(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies := sim.allies_of(c)
	if allies.is_empty():
		return
	allies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.hp_ratio() < b.hp_ratio())
	var a: BattleUnit = allies[0]
	show(ctx, [a.cell], "allies")
	sim.heal(a, by_stars(c, [30, 60, 90, 150]) * (1.0 + c.ap / 100.0), c)
	sim.add_status(a, "safeguard", by_stars(c, [1000, 2000, 3000, 6000]), c)


## pastel-veil.ts: dashes next to the farthest ally; allies on the way (else itself) are
## cleansed and gain 20 / 40 / 80 SHIELD (AP).
static func pastel_veil(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var shielded: Array[BattleUnit] = []
	var far: BattleUnit = null
	for a in sim.allies_of(c):
		if a != c and (far == null or BattleBoard.distance_m(a.cell, c.cell) > BattleBoard.distance_m(far.cell, c.cell)):
			far = a
	if far != null:
		var dest: Variant = null
		for cell in BattleBoard.adjacent_cells(far.cell):
			if sim.board.is_free(cell) and (dest == null or BattleBoard.distance_m(cell, c.cell) > BattleBoard.distance_m(dest, c.cell)):
				dest = cell
		if dest != null:
			var cells := BattleBoard.cells_between(c.cell, dest)
			show(ctx, cells, "allies")
			for cell in cells:
				var a := sim.board.get_unit(cell)
				if a != null and a.alive and a.team == c.team and not shielded.has(a):
					shielded.append(a)
			sim.move_unit(c, dest, 300.0, "dash")
	if shielded.is_empty():
		shielded.append(c)
	for a in shielded:
		a.cleanse()
		sim.add_shield(a, by_stars(c, [20, 40, 80, 160]) * (1.0 + c.ap / 100.0), c)


## shadow-bone.ts: enemies in the line through the target: 30 / 60 / 120 SPECIAL, 50% chance
## to lose 6 DEF (AP).
static func shadow_bone(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if ctx.focus == null:
		return
	var cells := line_through(c, ctx.focus)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [30, 60, 120, 240]))
		if sim.chance(0.5, c):
			e.add_stat("def", AbilityRunner.adjust_buff(c, e, -6.0 * (1.0 + c.ap / 100.0)))


## sheer-cold.ts: 50 / 100 / 200 SPECIAL to the target; 10 / 20 / 30% chance (more when it
## has more HP than the target) to KO it instead; sure on a frozen target, never on ICE.
static func sheer_cold(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var execute := by_stars(c, [0.1, 0.2, 0.3, 0.6]) * (1.0 + maxf(0.0, (c.hp - t.hp) / maxf(t.hp, 1.0)))
	if t.types.has("ICE"):
		execute = 0.0
	elif t.has_status("freeze"):
		execute = 1.0
	show(ctx, [t.cell])
	hit(ctx, t, 9999.0 if sim.chance(execute, c) else by_stars(c, [50, 100, 200, 400]))


## slack-off.ts: cleansed, heals 30% of its max HP (60% at 4★, AP), then SLEEP 3 s.
static func slack_off(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	c.cleanse()
	sim.heal(c, c.max_hp * by_stars(c, [0.3, 0.3, 0.3, 0.6]) * (1.0 + c.ap / 100.0), c)
	sim.add_status(c, "sleep", 3000.0, c)
#endregion


#region abilities (batch37)
## fiery-wrath.ts: enemies within 4 cells: 30 / 40 / 50 SPECIAL, 50% FLINCH 4 s.
static func fiery_wrath(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.cells_in_radius(c.cell, 4)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		if sim.chance(0.5, c):
			status(ctx, e, "flinch", 4000.0)
		hit(ctx, e, by_stars(c, [30, 40, 50, 80]))


## freezing-glare.ts: enemies in the line through the target: 20 / 40 / 80 SPECIAL,
## 50% FREEZE 3 s.
static func freezing_glare(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if ctx.focus == null:
		return
	var cells := line_through(c, ctx.focus)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [20, 40, 80, 160]))
		if sim.chance(0.5, c):
			status(ctx, e, "freeze", by_stars(c, [3000, 3000, 3000, 6000]))


## hydro-steam.ts: the cell in front of it and the 3 cells beyond (straight and 60° aside; web: 45°):
## 30 / 60 / 100 SPECIAL and BURN 4 s.
static func hydro_steam(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	if ctx.focus == null:
		return
	var dir := BattleBoard.orientation(c.cell, ctx.focus.cell)
	if dir == Vector2i.ZERO:
		return
	var front := BattleBoard.step(c.cell, dir)
	var cells: Array[Vector2i] = [front]
	for d in BattleBoard.fan(dir):
		var cell := BattleBoard.step(front, d)
		if BattleBoard.in_bounds(cell):
			cells.append(cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [30, 60, 100, 200]))
		status(ctx, e, "burn", 4000.0)


## ivy-cudgel.ts: 50 / 75 / 100 SPECIAL to the target, then by Ogerpon's mask: Teal +6 ATK
## per adjacent enemy (AP); Wellspring: adjacent allies +25 PP and heal 50 (AP);
## Hearthflame: adjacent enemies 30 SPECIAL and BURN 5 s; Cornerstone: adjacent enemies
## FLINCH 5 s, PROTECT 1 s x (2 + AP/100).
static func ivy_cudgel(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var k := 1.0 + c.ap / 100.0
	if ctx.focus != null:
		show(ctx, [ctx.focus.cell])
		hit(ctx, ctx.focus, by_stars(c, [50, 75, 100, 200]))
	var cells := BattleBoard.adjacent_cells(c.cell)
	var enemies := enemies_on(ctx, cells)
	match c.passive:
		"OGERPON_TEAL":
			c.add_stat("atk", 6.0 * enemies.size() * k)
		"OGERPON_WELLSPRING":
			show(ctx, cells, "allies")
			for cell in cells:
				var a := sim.board.get_unit(cell)
				if a != null and a.alive and a.team == c.team:
					a.add_pp(25.0 * k)
					sim.heal(a, 50.0 * k, c)
		"OGERPON_HEARTHFLAME":
			show(ctx, cells)
			for e in enemies:
				hit(ctx, e, 30.0)
				status(ctx, e, "burn", 5000.0)
		"OGERPON_CORNERSTONE":
			show(ctx, cells)
			for e in enemies:
				status(ctx, e, "flinch", 5000.0)
			sim.add_status(c, "protect", roundf(1000.0 * (2.0 + c.ap / 100.0)), c)


## sky-attack-shadow.ts: soars out of reach, lands next to the farthest enemy and strikes
## it 1 s later for 30 / 60 / 120 SPECIAL. Can crit.
static func sky_attack_shadow(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var spot := sim.farthest_spot(c)
	if spot.is_empty():
		return
	var crit := sim.chance(c.crit_chance / 100.0, c)
	var t: BattleUnit = spot.target
	sim.move_unit(c, spot.cell, 500.0, "dash")
	sim.add_status(c, "skydiving", 1000.0, c)
	c.cooldown = 1000.0
	sim.schedule(1000.0, c, func() -> void:
		if t.alive:
			show(ctx, [t.cell])
			hit(ctx, t, by_stars(c, [30, 60, 120, 240]), BattleUnit.DamageKind.SPECIAL, true, crit))


## thunderous-kick.ts: kicks the target back along its line as far as it goes, pushing the
## enemies on the way aside (left, else right; blocked otherwise); every enemy hit gets
## FLINCH 4 s, -10 DEF (AP) and 20 / 40 / 60 PHYSICAL.
static func thunderous_kick(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var movable := func(u: BattleUnit) -> bool: return not u.has_item("HEAVY_DUTY_BOOTS") and not u.inanimate
	var blocked: bool = not movable.call(t)
	var farthest := t.cell
	var hits: Array[BattleUnit] = [t]
	var cells := ray_from(c.cell, BattleBoard.orientation(c.cell, t.cell))
	show(ctx, cells)
	for cell in cells:
		if blocked:
			break
		var u := sim.board.get_unit(cell)
		if u != null and u.alive and u.team != c.team and u != t:
			hits.append(u)
			var left := cell + Vector2i(-1, 0)
			var right := cell + Vector2i(1, 0)
			if sim.board.is_free(left) and movable.call(u):
				sim.move_unit(u, left, 250.0, "knockback")
				u.cooldown = 500.0
			elif sim.board.is_free(right) and movable.call(u):
				sim.move_unit(u, right, 250.0, "knockback")
				u.cooldown = 500.0
			else:
				blocked = true
		if not blocked:
			farthest = cell
	if farthest != t.cell:
		swap_units(sim, t.cell, farthest, "knockback")
	for e in hits:
		status(ctx, e, "flinch", 4000.0)
		e.add_stat("def", AbilityRunner.adjust_buff(c, e, -10.0 * (1.0 + c.ap / 100.0)))
		hit(ctx, e, by_stars(c, [20, 40, 60, 120]), BattleUnit.DamageKind.PHYSICAL)


## barb-barrage.ts: jumps where the enemies are the most packed, then the target and its
## adjacent teammates get POISON 3 s and 15 / 30 / 45 SPECIAL (only the target when it
## cannot jump).
static func barb_barrage(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var damage := by_stars(c, [15, 30, 45, 60, 120])
	var foe_team := BattleUnit.Team.RED if c.team == BattleUnit.Team.BLUE else BattleUnit.Team.BLUE
	var dest: Variant = most_surrounded_by(sim, foe_team)
	if dest == null:
		show(ctx, [t.cell])
		hit(ctx, t, damage)
		return
	sim.move_unit(c, dest, 250.0, "dash")
	var targets: Array[BattleUnit] = []
	for cell in BattleBoard.adjacent_cells(t.cell):
		var u := sim.board.get_unit(cell)
		if u != null and u.alive and u.team == t.team:
			targets.append(u)
	targets.append(t)
	show(ctx, targets.map(func(u: BattleUnit) -> Vector2i: return u.cell))
	for u in targets:
		status(ctx, u, "poison", 3000.0)
		hit(ctx, u, damage)


## bullet-punch.ts: 20 / 30 / 40 TRUE to the target, +20 / 30 / 40 SPEED (AP) for 2 s,
## acts again sooner.
static func bullet_punch(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if ctx.focus != null:
		show(ctx, [ctx.focus.cell])
		hit(ctx, ctx.focus, by_stars(c, [20, 30, 40, 80]), BattleUnit.DamageKind.TRUE)
	var buff := by_stars(c, [20, 30, 40, 80]) * (1.0 + c.ap / 100.0)
	c.add_stat("speed", buff)
	sim.schedule(2000.0, c, func() -> void: c.add_stat("speed", -buff))
	c.cooldown = 250.0


## Surges of the Tapus: every other ally of `type` gets `apply`.
static func _surge(ctx: Dictionary, type: String, apply: Callable) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies := sim.allies_of(c).filter(func(a: BattleUnit) -> bool: return a != c and a.types.has(type))
	show(ctx, allies.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
	for a in allies:
		apply.call(a)


## electric-surge.ts: the other ELECTRIC allies gain 10 SPEED (20 at 4★, AP).
static func electric_surge(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var buff := by_stars(c, [10, 10, 10, 20]) * (1.0 + c.ap / 100.0)
	_surge(ctx, "ELECTRIC", func(a: BattleUnit) -> void: a.add_stat("speed", AbilityRunner.adjust_buff(c, a, buff)))


## grassy-surge.ts: the other GRASS allies gain 5 ATK (10 at 4★, AP).
static func grassy_surge(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var buff := by_stars(c, [5, 5, 5, 10]) * (1.0 + c.ap / 100.0)
	_surge(ctx, "GRASS", func(a: BattleUnit) -> void: a.add_stat("atk", AbilityRunner.adjust_buff(c, a, buff)))


## misty-surge.ts: the other FAIRY allies gain 25 PP and heal 25 (50 at 4★, AP).
static func misty_surge(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var amount := by_stars(c, [25, 25, 25, 50]) * (1.0 + c.ap / 100.0)
	_surge(ctx, "FAIRY", func(a: BattleUnit) -> void:
		a.add_pp(amount)
		sim.heal(a, amount, c))


## psychic-surge.ts: the other PSYCHIC allies gain 20 / 25 / 30 SHIELD (AP).
static func psychic_surge(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var shield := by_stars(c, [20, 25, 30, 60]) * (1.0 + c.ap / 100.0)
	_surge(ctx, "PSYCHIC", func(a: BattleUnit) -> void: sim.add_shield(a, shield, c))


## Enemies on the supercover line a -> b (the unit at `skip` excluded), closest first.
static func _enemies_between(ctx: Dictionary, a: Vector2i, b: Vector2i, skip: BattleUnit = null) -> Array[BattleUnit]:
	var out := enemies_on(ctx, BattleBoard.cells_between(a, b))
	out.erase(skip)
	out.sort_custom(func(x: BattleUnit, y: BattleUnit) -> bool:
		return BattleBoard.distance_c(a, x.cell) < BattleBoard.distance_c(a, y.cell))
	return out


## plasma-fission.ts: a beam hits the first enemy toward the target (20 / 40 / 60 SPECIAL,
## 0.4 s later), then splits in two beams perpendicular to it (at the real angle) up to the board edges: the
## enemies there take the damage, halved after each one.
static func plasma_fission(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if ctx.focus == null:
		return
	var on_path := _enemies_between(ctx, c.cell, ctx.focus.cell)
	var primary: BattleUnit = on_path[0] if not on_path.is_empty() else ctx.focus
	var damage := by_stars(c, [20, 40, 60, 120])
	var from := c.cell
	sim.schedule(400.0, c, func() -> void:
		if not primary.alive:
			return
		show(ctx, [primary.cell])
		hit(ctx, primary, damage)
		var v := BattleBoard.center(primary.cell) - BattleBoard.center(from)
		if v.is_zero_approx():
			return
		for p in [Vector2(-v.y, v.x), Vector2(v.y, -v.x)]:
			var dest := BattleBoard.cell_at(BattleBoard.center(primary.cell) + p.normalized() * 12.0)
			var beam := BattleBoard.cells_between(primary.cell, dest)
			if beam.size() < 2:
				continue
			show(ctx, beam)
			var residual := damage
			for e in _enemies_between(ctx, primary.cell, dest, primary):
				hit(ctx, e, residual)
				residual = maxf(1.0, roundf(residual / 2.0)))


## revelation-dance.ts: feathers on the adjacent cells: enemies take 15 / 30 / 50 SPECIAL,
## allies gain by Oricorio's style: Baile 3 / 6 / 10 SPEED, Pom-Pom 2 / 4 / 6 ATK,
## Pa'u 2 / 4 / 6 SPE_DEF, Sensu 15 / 30 / 50 SHIELD (AP).
static func revelation_dance(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var k := 1.0 + c.ap / 100.0
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells, "all")
	for cell in cells:
		var u := sim.board.get_unit(cell)
		if u == null or not u.alive:
			continue
		if u.team != c.team:
			hit(ctx, u, by_stars(c, [15, 30, 50, 80]))
			continue
		match c.pkm:
			"ORICORIO_BAILE":
				u.add_stat("speed", AbilityRunner.adjust_buff(c, u, by_stars(c, [3, 6, 10, 15]) * k))
			"ORICORIO_PA_U":
				u.add_stat("speDef", AbilityRunner.adjust_buff(c, u, by_stars(c, [2, 4, 6, 10]) * k))
			"ORICORIO_POMPOM":
				u.add_stat("atk", AbilityRunner.adjust_buff(c, u, by_stars(c, [2, 4, 6, 10]) * k))
			"ORICORIO_SENSU":
				sim.add_shield(u, by_stars(c, [15, 30, 50, 80]) * k, c)


## stone-axe.ts: 30 / 40 / 50 TRUE to the target, STEALTH_ROCKS on the cells around it.
static func stone_axe(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var cells := BattleBoard.adjacent_cells(t.cell)
	hit(ctx, t, by_stars(c, [30, 40, 50, 100]), BattleUnit.DamageKind.TRUE)
	board_effect(ctx.sim, cells, "STEALTH_ROCKS")
#endregion


#region abilities (faithful rewrites of the approx ones)
## Fields a Pokémon can stand in, in the order terrain-pulse.ts looks for them.
const FIELD_ORDER := ["fairy_field", "electric_field", "grass_field", "psychic_field"]


static func _field_of(u: BattleUnit) -> String:
	for f in FIELD_ORDER:
		if u.has_status(f):
			return f
	return ""


## heavy-slam.ts: the adjacent enemies take 15 / 30 / 60 SPECIAL, x (1 + 0.5 x (its max HP -
## the target's) / the target's max HP) when it has more max HP than its target.
static func heavy_slam(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	var damage := by_stars(c, [15, 30, 60, 120])
	if t != null and c.max_hp > t.max_hp:
		damage = roundf(damage * (1.0 + 0.5 * (c.max_hp - t.max_hp) / t.max_hp))
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, damage)


## terrain-pulse.ts: without a field it gets a Grassy one; the fields of its team spread to the
## adjacent allies without one (a random one of the fields around them), then every ally with
## a field: Grass heals 5 / 7 / 10% max HP, Electric +10 / 12 / 15 SPEED, Psychic +10 / 12 / 15 PP,
## Fairy 5 / 7 / 10% max HP as shield (all AP).
static func terrain_pulse(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if _field_of(c) == "":
		sim.add_status(c, "grass_field", 1e9, c)
	var spread := {} # ally without a field -> fields around it
	var fields := {} # ally -> its field
	for u in sim.board.units():
		if not u.alive or u.team != c.team or _field_of(u) == "":
			continue
		var f := _field_of(u)
		fields[u] = f
		for cell in BattleBoard.adjacent_cells(u.cell):
			var a := sim.board.get_unit(cell)
			if a != null and a.alive and a.team == u.team and _field_of(a) == "":
				if not spread.has(a):
					spread[a] = []
				if not spread[a].has(f):
					spread[a].append(f)
	for a in spread:
		var options: Array = spread[a]
		sim.add_status(a, options[sim.rng.randi() % options.size()], 1e9, c)
		fields[a] = _field_of(a)
	var ap := 1.0 + c.ap / 100.0
	var cells: Array = []
	for a in fields:
		cells.append(a.cell)
		match String(fields[a]):
			"grass_field":
				sim.heal(a, by_stars(c, [0.05, 0.07, 0.1, 0.15]) * a.max_hp * ap, c)
			"electric_field":
				a.add_stat("speed", AbilityRunner.adjust_buff(c, a, by_stars(c, [10, 12, 15, 20]) * ap))
			"psychic_field":
				a.add_pp(by_stars(c, [10, 12, 15, 20]) * ap)
			"fairy_field":
				sim.add_shield(a, by_stars(c, [0.05, 0.07, 0.1, 0.15]) * a.max_hp * ap, c)
	show(ctx, cells, "allies")


## magnet-bomb.ts: 20 / 40 / 80 SPECIAL to the target, 10 / 20 / 40 to the enemies around it, all
## LOCKED 1.5 s; an enemy 2 cells away from the target on each side is pulled next to it and
## LOCKED too.
static func magnet_bomb(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var center := t.cell
	var team := t.team
	show(ctx, BattleBoard.adjacent_cells(center, true))
	hit(ctx, t, by_stars(c, [20, 40, 80, 160]))
	sim.add_status(t, "locked", 1500.0, t)
	for e in enemies_on(ctx, BattleBoard.adjacent_cells(center)):
		hit(ctx, e, by_stars(c, [10, 20, 40, 80]))
		sim.add_status(e, "locked", 1500.0, e)
	# each of the 6 cells around takes one of the 2 cells beyond it (straight on and the next one
	# counter-clockwise: the ring 2 cells away, once each)
	for d in BattleBoard.DIRECTIONS:
		var dest := BattleBoard.step(center, d)
		if not sim.board.is_free(dest):
			continue
		var attracted: Array = []
		for from in [BattleBoard.step(center, d, 2), BattleBoard.step(dest, BattleBoard.turn(d, 1))]:
			var e := sim.board.get_unit(from)
			if e != null and e.alive and e.team == team:
				attracted.append(e)
		if attracted.is_empty():
			continue
		var pulled: BattleUnit = attracted[sim.rng.randi() % attracted.size()]
		if sim.force_move(pulled, dest, 250.0, "knockback"):
			sim.add_status(pulled, "locked", 1500.0, pulled)


## teleport.ts: teleports to a safe cell (getFlyAwayCell); its next attack deals 15 / 30 / 60
## more SPECIAL (BattleSim.attack_hit) and it cannot cast until then.
static func teleport(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var cell: Variant = AbilityRunner.fly_away_cell(sim, c)
	if cell == null:
		return
	sim.move_unit(c, cell, 250.0, "dash")
	c.effects.teleport_next_attack = true
	show(ctx, [c.cell], "allies")


## pursuit.ts: 35 / 70 / 140 SPECIAL and marks the target: when it jumps (more than one cell),
## the caster lands next to it and casts Pursuit again (BattleSim._pursue).
static func pursuit(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [35, 70, 140, 280]))
	var pursuers: Array = t.effects.get("pursuers", [])
	if not pursuers.has(c.id):
		pursuers.append(c.id)
	t.effects.pursuers = pursuers


## nightmare.ts: every enemy is FATIGUED 2 / 4 / 6 s; the ones under a Ghost curse also take
## 25 / 50 / 100 SPECIAL.
static func nightmare(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var duration := by_stars(c, [2000, 4000, 6000, 10000])
	var foes := sim.enemies_of(c)
	show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	for e in foes:
		if not e.curses.is_empty() or e.has_status("curse"):
			hit(ctx, e, by_stars(c, [25, 50, 100, 200]))
		status(ctx, e, "fatigue", duration)


## column-crush.ts: without a pillar of its team on the board, builds one (wood / iron / concrete
## by its stars) on the closest free cell. With one, jumps on its cell (the pillar breaks) and
## throws it at the nearest enemy: 50 / 100 / 150 + the HP the pillar had left, as SPECIAL.
static func column_crush(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var pillar: BattleUnit = null
	for u in sim.board.units():
		if u.alive and u.team == c.team and PlayerState.PILLARS.has(u.pkm):
			pillar = u
			break
	if pillar == null:
		var free: Variant = sim.closest_free_cell_near(c.cell, c.team)
		if free != null:
			_summon(sim, PlayerState.PILLARS[clampi(c.stars - 1, 0, 2)], c.team, free)
		return
	var from := pillar.cell
	var remaining := pillar.hp
	pillar.shield = 0.0
	sim.deal_damage(pillar, 9999.0, BattleUnit.DamageKind.TRUE, null)
	if pillar.alive:
		return
	sim.move_unit(c, from, 250.0, "dash")
	c.cooldown = 800.0
	sim.schedule(500.0, c, func() -> void:
		var enemy := sim.nearest_enemy_manhattan(c)
		if enemy == null:
			return
		c.target = enemy
		var landing := enemy.cell
		var travel := Vector2(from - landing).length() * 160.0
		sim.emit({"type": "area", "unit": c, "cells": [landing] as Array[Vector2i], "affects": "enemies",
			"telegraph": true, "duration": travel})
		sim.schedule(travel, c, func() -> void:
			show(ctx, [landing])
			if enemy.alive:
				hit(ctx, enemy, by_stars(c, [50, 100, 150, 300]) + remaining)))


## dragon-rage.ts: +15 / 30 / 45 shield (AP); each second for 6 s: +5 / 10 / 15 shield (AP) and
## 5 / 10 / 15 SPECIAL to the adjacent enemies; then the shield it gave turns into a heal of 40%
## of it. Cast again meanwhile: converts the shield given so far and restarts the 6 s.
static func dragon_rage(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if c.effects.has("dragon_rage"):
		var state: Dictionary = c.effects.dragon_rage
		_dragon_rage_consume(sim, c, state)
		state.ticks = 6
		return
	var crit: bool = c.effects.get("ability_crit", false) and sim.chance(c.crit_chance / 100.0, c)
	var initial := by_stars(c, [15, 30, 45, 60])
	sim.add_shield(c, initial * (1.0 + c.ap / 100.0) * (c.crit_power if crit else 1.0), c)
	c.effects.dragon_rage = {"ticks": 6, "given": initial, "crit": crit}
	show(ctx, [c.cell], "allies")
	sim.schedule(1000.0, c, func() -> void: _dragon_rage_tick(ctx))


static func _dragon_rage_tick(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if not c.effects.has("dragon_rage"):
		return
	var state: Dictionary = c.effects.dragon_rage
	state.ticks = int(state.ticks) - 1
	if state.ticks < 0:
		c.effects.erase("dragon_rage")
		_dragon_rage_consume(sim, c, state)
		return
	var amount := by_stars(c, [5, 10, 15, 20])
	sim.add_shield(c, amount * (1.0 + c.ap / 100.0) * (c.crit_power if state.crit else 1.0), c)
	state.given = float(state.given) + amount
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, amount, BattleUnit.DamageKind.SPECIAL, true, state.crit)
	sim.schedule(1000.0, c, func() -> void: _dragon_rage_tick(ctx))


## DragonRageEffect.consumeShield: the shield it still has from the rage becomes 40% heal.
static func _dragon_rage_consume(sim: BattleSim, c: BattleUnit, state: Dictionary) -> void:
	var converted := minf(c.shield, float(state.given))
	c.shield -= converted
	if converted > 0.0:
		sim.heal(c, roundf(converted * 0.4), c)
	state.given = 0.0


## psystrike.ts: a wave toward the farthest enemy: 20 / 40 / 80 SPECIAL to the enemies on its path
## (the farthest one at least), each one teleported to the back of its side.
static func psystrike(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var far := sim.farthest_enemy(c)
	if far == null:
		far = ctx.focus
	if far == null:
		return
	var cells := BattleBoard.cells_between(c.cell, far.cell)
	show(ctx, cells)
	var targets := enemies_on(ctx, cells)
	if targets.is_empty():
		targets = [far]
	for e in targets:
		hit(ctx, e, by_stars(c, [20, 40, 80, 160]))
		if e.alive:
			var dest: Variant = sim.teleport_cell(e.cell, e.team)
			if dest != null:
				sim.force_move(e, dest, 250.0, "dash")


## sky-attack.ts: soars out of reach, lands next to the farthest enemy and strikes it 1 s later
## for 30 / 60 / 120 SPECIAL.
static func sky_attack(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var spot := sim.farthest_spot(c)
	if spot.is_empty():
		return
	var t: BattleUnit = spot.target
	sim.move_unit(c, spot.cell, 500.0, "dash")
	sim.add_status(c, "skydiving", 1000.0, c)
	c.cooldown = 1000.0
	sim.schedule(1000.0, c, func() -> void:
		if t.alive:
			show(ctx, [t.cell])
			hit(ctx, t, by_stars(c, [30, 60, 120, 240])))


## fire-blast.ts: a star on the target (the web: 6 squares; here the target and the 6 cells around):
## 30 / 60 / 110 SPECIAL to the enemies there.
static func fire_blast(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.adjacent_cells(t.cell, true)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [30, 60, 110, 220]))


## thunder.ts: lightning on 3 random enemies, 0.5 s apart: 25 / 50 / 100 SPECIAL, 30% chance
## (luck) of PARALYSIS 3 s.
static func thunder(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var targets := pick_random(sim, sim.enemies_of(c), 3)
	for i in targets.size():
		var tg: BattleUnit = targets[i]
		sim.schedule(i * 500.0, tg, func() -> void:
			if sim.chance(0.3, c):
				sim.add_status(tg, "paralysis", 3000.0, c)
			show(ctx, [tg.cell])
			hit(ctx, tg, by_stars(c, [25, 50, 100, 200])))


## origin-pulse.ts: a wave along the row of the target: 50 / 75 / 100 SPECIAL to every enemy on it.
static func origin_pulse(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.cells_in_row(t.cell.y)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [50, 75, 100, 120, 150]))


## draco-meteor.ts: 1 s later a meteor falls where the target was: 30 / 60 / 120 SPECIAL to the
## enemies on that cell and around it; then it loses 20 AP.
static func draco_meteor(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.adjacent_cells(t.cell, true)
	sim.emit({"type": "area", "unit": c, "cells": cells, "affects": "enemies", "telegraph": true, "duration": 1000.0})
	sim.schedule(1000.0, c, func() -> void:
		show(ctx, cells)
		for e in enemies_on(ctx, cells):
			hit(ctx, e, by_stars(c, [30, 60, 120, 150, 300]))
		c.add_stat("ap", -20.0))


## precipice-blades.ts: 25 / 50 / 100 SPECIAL to every enemy on its row or its column.
static func precipice_blades(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var cells: Array[Vector2i] = []
	for e in sim.board.units():
		if e.alive and e.team != c.team and (e.cell.x == c.cell.x or e.cell.y == c.cell.y):
			cells.append(e.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [25, 50, 100, 120, 200]))


## stealth-rocks.ts: STEALTH_ROCKS in a cone of 1 / 2 / 3 cells toward the target; the enemies in
## it take 30 / 40 / 50 SPECIAL.
static func stealth_rocks(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.cells_in_front(c.cell, t.cell, c.stars)
	board_effect(sim, cells, "STEALTH_ROCKS")
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [30, 40, 50, 80]))


## iron-head.ts: +5 / 10 / 15 DEF and SPE_DEF (AP), then its DEF + SPE_DEF as SPECIAL to the target.
static func iron_head(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var buff := AbilityRunner.adjust_buff(c, c, by_stars(c, [5, 10, 15, 30]) * (1.0 + c.ap / 100.0))
	c.add_stat("def", buff)
	c.add_stat("speDef", buff)
	show(ctx, [t.cell])
	hit(ctx, t, c.def + c.spe_def)


## dragon-energy.ts: its current HP (x1.5 at 4★) as SPECIAL to the target.
static func dragon_energy(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	hit(ctx, t, c.hp * by_stars(c, [1, 1, 1, 1.5]))


## roar-of-time.ts: the strongest ally without one gets a RESURRECTION and +10 / 15 / 20 SPEED (AP).
static func roar_of_time(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var best := -INF
	var picks: Array[BattleUnit] = []
	for u in sim.alive_units(c.team):
		if u.effects.get("resurrection", false):
			continue
		var score := u.unit_score()
		if score > best:
			best = score
			picks = [u]
		elif score == best:
			picks.append(u)
	if picks.is_empty():
		return
	var s: BattleUnit = picks[sim.rng.randi() % picks.size()]
	s.effects.resurrection = true
	var speed := AbilityRunner.adjust_buff(c, s, by_stars(c, [10, 15, 20, 40]) * (1.0 + c.ap / 100.0))
	s.add_stat("speed", speed)
	sim.emit({"type": "buff", "unit": s, "stat": "speed", "amount": speed})
	show(ctx, [s.cell], "allies")


## shadow-force.ts: takes its Origin form (its ability becomes Shadow Claw), teleports into the
## largest group of enemies and deals 30 / 45 / 60 SPECIAL to the adjacent ones, breaking their
## Protect, Reflect and Magic Bounce.
static func shadow_force(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if GameData.pokemon.has("ORIGIN_GIRATINA"):
		c.effects.disguise = "ORIGIN_GIRATINA"
		sim.emit({"type": "transform", "unit": c, "pkm": "ORIGIN_GIRATINA"})
	if GameData.abilities.has("SHADOW_CLAW"):
		c.ability_id = "SHADOW_CLAW"
	var dest: Variant = AbilityRunner.most_surrounded_cell(sim, 1 - c.team)
	if dest != null:
		sim.move_unit(c, dest, 250.0, "dash")
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		for barrier in ["protect", "reflect", "magic_bounce"]:
			e.statuses.erase(barrier)
		hit(ctx, e, by_stars(c, [30, 45, 60, 120]))


## spacial-rend.ts: the enemies that can be moved swap places in reverse board order, then every
## enemy on the row of the target takes 20 / 60 / 100 SPECIAL.
static func spacial_rend(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var row := t.cell.y
	var foes: Array[BattleUnit] = []
	for u in sim.board.units():
		if u.alive and u.team != c.team and u.can_be_moved():
			foes.append(u)
	var n := foes.size()
	for i in n / 2:
		sim.swap_cells(foes[i].cell, foes[n - 1 - i].cell, "dash")
	var cells := BattleBoard.cells_in_row(row)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [20, 60, 100, 200]))


## judgement.ts: 10 SPECIAL (20 at 4★) x the synergy levels of its team for its own types
## (a wild wave has none, like the web game).
static func judgement(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var counts: Dictionary = sim.team_info[c.team].get("counts", {})
	var levels := 0
	for type in c.types:
		levels += int(counts.get(type, 0))
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [10, 10, 10, 20]) * levels)
#endregion


#region abilities (Vespiquen orders)
## attack-order.ts: a Combee joins next to it, every Combee ally is ENRAGED 3 s; its next attack deals
## 20 / 40 / 60 + 10 / 20 / 30 per Combee ally more SPECIAL (BattleSim.attack_hit).
static func attack_order(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	_combee(sim, c)
	c.effects.attack_order_next_attack = true
	var cells: Array = []
	for a in sim.alive_units(c.team):
		if a.pkm == "COMBEE":
			sim.add_status(a, "enraged", 3000.0, a)
			cells.append(a.cell)
	show(ctx, cells, "allies")


## heal-order.ts: a Combee joins next to it, then it and every Combee heal their adjacent allies
## 10 / 20 / 30 (AP) and clear their negative statuses.
static func heal_order(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	_combee(sim, c)
	var heal := by_stars(c, [10, 20, 30, 60]) * (1.0 + c.ap / 100.0)
	for healer in sim.alive_units(c.team):
		if healer != c and healer.pkm != "COMBEE":
			continue
		var cells := BattleBoard.adjacent_cells(healer.cell)
		show(ctx, cells, "allies")
		for cell in cells:
			var a := sim.board.get_unit(cell)
			if a != null and a.alive and a.team == c.team:
				sim.heal(a, heal, c)
				a.cleanse()


## defend-order.ts: a Combee joins next to it, every Combee gets 10 / 20 / 30 shield (AP) and it
## gets as much plus as much again per Combee ally.
static func defend_order(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	_combee(sim, c)
	var shield := by_stars(c, [10, 20, 30, 50]) * (1.0 + c.ap / 100.0)
	var combees := 0
	var cells: Array = [c.cell]
	for a in sim.alive_units(c.team):
		if a.pkm == "COMBEE":
			sim.add_shield(a, shield, c)
			combees += 1
			cells.append(a.cell)
	sim.add_shield(c, shield * (1 + combees), c)
	show(ctx, cells, "allies")


## The Combee joining Vespiquen: on the free cell closest to it.
static func _combee(sim: BattleSim, c: BattleUnit) -> void:
	var cell: Variant = sim.nearest_free_cell(c.cell)
	if cell != null:
		_summon(sim, "COMBEE", c.team, cell)
#endregion


#region abilities (hail)
## hail.ts: 8 / 15 / 30 hailstones on random cells of the target's side: an enemy there takes 50
## SPECIAL (80 at 4★) and FREEZE 1 s; every cell hit keeps HAIL (10 SPECIAL and FREEZE 1 s to whoever
## steps on it, BattleSim._each_second).
static func hail(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var enemy_side := t.cell.y >= BattleBoard.SIDE_ROWS
	var cells: Array[Vector2i] = []
	for _i in int(by_stars(c, [8, 15, 30, 45])):
		var cell := Vector2i(sim.rng.randi_range(0, BattleBoard.WIDTH - 1),
			sim.rng.randi_range(BattleBoard.SIDE_ROWS, BattleBoard.HEIGHT - 1) if enemy_side
			else sim.rng.randi_range(0, BattleBoard.SIDE_ROWS - 1))
		cells.append(cell)
		var e := sim.board.get_unit(cell)
		if e != null and e.alive and e.team != c.team:
			hit(ctx, e, by_stars(c, [50, 50, 50, 80]))
			status(ctx, e, "freeze", 1000.0)
	show(ctx, cells)
	board_effect(sim, cells, "HAIL")
#endregion


#region abilities (season1a)
## Season skills (not in the web game; docs/DESIGN_S1.md, data/season_skills.json): lasting parts in SeasonSkillEffects.

## -`amount` SPEED for `ms`, then back.
static func _slow_for(sim: BattleSim, e: BattleUnit, amount: float, ms: float) -> void:
	e.add_stat("speed", -amount)
	sim.schedule(ms, null, func() -> void:
		if e.alive:
			e.add_stat("speed", amount))


## Season 1 (Azurill): 3 / 4 / 5 bubbles fanned toward the target, each popping on the first enemy on its way:
## 15 / 30 / 60 SPECIAL and -10 SPEED for 3 s.
static func bubble(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var dir := BattleBoard.orientation(c.cell, t.cell)
	var dirs: Array[Vector2i] = [dir, BattleBoard.turn(dir, 1), BattleBoard.turn(dir, -1), BattleBoard.turn(dir, 2),
		BattleBoard.turn(dir, -2)]
	for i in mini(int(by_stars(c, [3, 4, 5])), dirs.size()):
		for cell in ray_from(c.cell, dirs[i]):
			var e := sim.board.get_unit(cell)
			if e != null and e.alive and e.team != c.team:
				show(ctx, [cell])
				hit(ctx, e, by_stars(c, [15, 30, 60]))
				_slow_for(sim, e, 10.0, 3000.0)
				break


## Season 1 (Fennekin): a wisp on the target for 5 s: BURN, and it takes 15 / 20 / 30% more damage from everything.
static func will_o_wisp(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	status(ctx, t, "burn", 5000.0)
	t.counters.wisp_until = sim.time_ms + 5000.0
	t.counters.wisp_amp = by_stars(c, [0.15, 0.2, 0.3])


## Season 1 (Goomy): heals back 40 / 60 / 90% of the damage taken in the last 3 s, then slime on the ADJACENT enemies:
## 15 / 30 / 60 SPECIAL and -20% SPEED for 3 s.
static func life_dew(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var lost := 0.0
	for entry in c.counters.get("dew_log", []):
		if float(entry[0]) >= sim.time_ms - 3000.0:
			lost += float(entry[1])
	c.counters.dew_log = []
	if lost > 0.0:
		sim.heal(c, lost * by_stars(c, [0.4, 0.6, 0.9]) * (1.0 + c.ap / 100.0), c)
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [15, 30, 60]))
		_slow_for(sim, e, roundf(e.speed * 0.2), 3000.0)


## Season 1 (Klink): its next 3 / 4 / 5 attacks come twice as fast, each firing a gear at the enemy nearest its
## target too (50% ATK as SPECIAL): SeasonSkillEffects.on_attack_hit.
static func shift_gear(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	if int(c.counters.get("shift_gears", 0)) <= 0:
		var boost := roundf(c.speed)
		c.add_stat("speed", boost)
		c.counters.shift_gear_speed = boost
	c.counters.shift_gears = int(by_stars(c, [3, 4, 5]))
	ctx.sim.emit({"type": "buff", "unit": c, "stat": "speed", "amount": c.counters.shift_gear_speed})


## Season 1 (Mareep): a wire to the ally with the most ATK for 6 s: +15 / 25 / 40 SPEED, and each of its attacks
## adds 10 / 20 / 40 SPECIAL (SeasonSkillEffects.on_attack_hit).
static func electro_link(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var best: BattleUnit = null
	for a in sim.allies_of(c):
		if a != c and not a.inanimate and (best == null or a.atk > best.atk):
			best = a
	if best == null:
		best = c
	show(ctx, [best.cell], "allies")
	var speed := by_stars(c, [15, 25, 40])
	if not _active_link(sim, best):
		best.add_stat("speed", speed)
		sim.schedule(6000.0, null, func() -> void:
			if best.alive:
				best.add_stat("speed", -speed))
	best.counters.charged_until = sim.time_ms + 6000.0
	best.counters.charged_dmg = roundf(by_stars(c, [10, 20, 40]) * (1.0 + c.ap / 100.0))
	sim.emit({"type": "buff", "unit": best, "stat": "speed", "amount": speed})


static func _active_link(sim: BattleSim, u: BattleUnit) -> bool:
	return sim.time_ms < float(u.counters.get("charged_until", -1.0))


## Season 1 (Rattata): if the target has more HP, it is brought down to Rattata's HP (at most 80 / 160 / 320 TRUE);
## else 20 / 40 / 80 SPECIAL.
static func endeavor(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	if t.hp > c.hp:
		hit(ctx, t, minf(t.hp - c.hp, by_stars(c, [80, 160, 320]) * (1.0 + c.ap / 100.0)), BattleUnit.DamageKind.TRUE, false)
	else:
		hit(ctx, t, by_stars(c, [20, 40, 80]))


## Season 1 (Cyndaquil): a sea of fire on the target's row for 4 s: every second the enemies there BURN and take
## 10 / 20 / 40 SPECIAL.
static func fire_pledge(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.cells_in_row(t.cell.y)
	var damage := by_stars(c, [10, 20, 40])
	for i in 4:
		sim.schedule(1000.0 * i, null, _pledge_tick.bind(ctx, cells, damage))


static func _pledge_tick(ctx: Dictionary, cells: Array, damage: float) -> void:
	if ctx.sim.finished:
		return
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		status(ctx, e, "burn", 1500.0)
		hit(ctx, e, damage)


## Season 1 (Growlithe): for 4 s, 30 / 40 / 50% of the damage its ADJACENT allies take goes to it instead
## (SeasonSkillEffects.redirect); it gains 20 / 40 / 80 SHIELD.
static func guard_dog(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	show(ctx, BattleBoard.adjacent_cells(c.cell), "allies")
	c.counters.guard_until = sim.time_ms + 4000.0
	c.counters.guard_pct = by_stars(c, [0.3, 0.4, 0.5])
	sim.add_shield(c, by_stars(c, [20, 40, 80]) * (1.0 + c.ap / 100.0), c)


## Season 1 (Nidoran M): 2 / 3 / 4 toxic spikes on free cells of its own front row; an enemy stepping on one takes
## 30 / 60 / 120 SPECIAL and 2 POISON stacks (each spike once; SeasonSkillEffects.each_second).
static func toxic_spikes(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var row := 3 if c.team == BattleUnit.Team.BLUE else 4
	var free: Array = []
	for cell in BattleBoard.cells_in_row(row):
		if sim.board.is_free(cell):
			free.append(cell)
	if free.is_empty():
		for cell in BattleBoard.cells_in_row(row):
			free.append(cell)
	var cells := pick_random(sim, free, int(by_stars(c, [2, 3, 4])))
	SeasonSkillEffects.set_traps(sim, c, cells, roundf(by_stars(c, [30, 60, 120]) * (1.0 + c.ap / 100.0)))
	show(ctx, cells)


## Season 1 (Omanyte): wraps the target for 3 / 3 / 4 s: LOCKED, 10 / 20 / 40 SPECIAL every second, and it needs 30%
## more PP to cast while wrapped.
static func constrict(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var ms := by_stars(c, [3000, 3000, 4000])
	show(ctx, [t.cell])
	status(ctx, t, "locked", ms)
	if not t.counters.has("constricted"):
		var extra := roundf(t.max_pp * 0.3)
		t.counters.constricted = true
		t.max_pp += extra
		sim.schedule(ms, null, func() -> void:
			t.max_pp -= extra
			t.counters.erase("constricted"))
	for i in int(ms / 1000.0):
		sim.schedule(1000.0 * (i + 1), c, func() -> void:
			if t.alive:
				hit(ctx, t, by_stars(c, [10, 20, 40])))


## Season 1 (Piplup): mist over the 2 allies standing right behind it: 25 / 50 / 100 SHIELD and SAFEGUARD 3 s each.
static func mist(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var dy := -1 if c.team == BattleUnit.Team.BLUE else 1
	var behind: Array[BattleUnit] = []
	for cell in BattleBoard.adjacent_cells(c.cell):
		var a := sim.board.get_unit(cell)
		if cell.y == c.cell.y + dy and a != null and a.alive and a.team == c.team and not a.inanimate:
			behind.append(a)
	if behind.is_empty(): # nobody behind: itself
		behind.append(c)
	show(ctx, behind.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
	for a in behind.slice(0, 2):
		sim.add_shield(a, by_stars(c, [25, 50, 100]) * (1.0 + c.ap / 100.0), c)
		sim.add_status(a, "safeguard", 3000.0, c)


## Season 1 (Sewaddle): an X through the target (it and its 4 neighbours off its row): 20 / 40 / 80 PHYSICAL; the
## enemies hit under 12 / 15 / 18% HP fall.
static func cross_cut(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells: Array[Vector2i] = [t.cell]
	for cell in BattleBoard.adjacent_cells(t.cell):
		if cell.y != t.cell.y:
			cells.append(cell)
	show(ctx, cells)
	var below := by_stars(c, [0.12, 0.15, 0.18])
	for e in enemies_on(ctx, cells):
		var r := hit(ctx, e, by_stars(c, [20, 40, 80]), BattleUnit.DamageKind.PHYSICAL)
		if e.alive and not r.death and e.hp < e.max_hp * below:
			hit(ctx, e, e.hp + e.shield + 1.0, BattleUnit.DamageKind.TRUE, false)


## Season 1 (Spinarak): ties the 2 enemies nearest it together for 5 s: whatever one of them loses, the other loses
## 30 / 40 / 50% of it as TRUE (SeasonSkillEffects.after_damage); both -15 SPEED for that time.
static func spider_web(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var foes := sim.enemies_of(c)
	foes.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return BattleBoard.distance(a.cell, c.cell) < BattleBoard.distance(b.cell, c.cell))
	if foes.size() < 2:
		if not foes.is_empty():
			hit(ctx, foes[0], by_stars(c, [20, 40, 80]))
		return
	var a: BattleUnit = foes[0]
	var b: BattleUnit = foes[1]
	show(ctx, [a.cell, b.cell])
	for pair in [[a, b], [b, a]]:
		var u: BattleUnit = pair[0]
		u.counters.web_with = pair[1].id
		u.counters.web_until = sim.time_ms + 5000.0
		u.counters.web_pct = by_stars(c, [0.3, 0.4, 0.5])
		_slow_for(sim, u, 15.0, 5000.0)


## Season 1 (Bulbasaur): vines into the 3 enemies nearest it for 4 s: every second 8 / 15 / 30 SPECIAL each, and it
## heals what they lose.
static func giga_drain(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var foes := sim.enemies_of(c)
	foes.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return BattleBoard.distance(a.cell, c.cell) < BattleBoard.distance(b.cell, c.cell))
	var tied := foes.slice(0, 3)
	for i in 4:
		sim.schedule(1000.0 * i, c, _drain_tick.bind(ctx, tied))


static func _drain_tick(ctx: Dictionary, tied: Array) -> void:
	var c: BattleUnit = ctx.caster
	var total := 0.0
	var cells: Array[Vector2i] = []
	for e in tied:
		if e.alive:
			cells.append(e.cell)
			total += float(hit(ctx, e, by_stars(c, [8, 15, 30])).taken)
	show(ctx, cells)
	if total > 0.0:
		ctx.sim.heal(c, total, c)
#endregion


#region abilities (season1b)
## Nearest free cell ADJACENT to `cell` from `toward` (null: none).
static func _free_adjacent_toward(sim: BattleSim, cell: Vector2i, toward: Vector2i) -> Variant:
	var best: Variant = null
	for c in BattleBoard.adjacent_cells(cell):
		if sim.board.is_free(c) and (best == null or BattleBoard.distance(c, toward) < BattleBoard.distance(best, toward)):
			best = c
	return best


## Season 1 (Pancham): grabs the target and slams it onto a free cell behind itself (into its own side):
## 30 / 60 / 120 SPECIAL and FLINCH 2 s.
static func circle_throw(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	if t.can_be_moved():
		var back := BattleBoard.step(c.cell, BattleBoard.orientation(t.cell, c.cell))
		var to: Variant = back if BattleBoard.in_bounds(back) and sim.board.is_free(back) \
			else _free_adjacent_toward(sim, c.cell, back)
		if to != null:
			sim.force_move(t, to, 300.0, "knockback")
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [30, 60, 120]))
	status(ctx, t, "flinch", 2000.0)


## Season 1 (Pawmi): the first time in a fight an ally has fallen, the nearest fallen one comes back with
## 20 / 30 / 50% HP; else (or later) a punch: 30 / 60 / 120 SPECIAL and PARALYSIS 1 s.
static func revival_blessing(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if not c.counters.has("revived"):
		var fallen: BattleUnit = null
		for u in sim.units:
			if not u.alive and u.team == c.team and not u.inanimate and not u.is_spawn and \
					(fallen == null or BattleBoard.distance(u.cell, c.cell) < BattleBoard.distance(fallen.cell, c.cell)):
				fallen = u
		if fallen != null:
			c.counters.revived = true
			var back := _summon(sim, fallen.pkm, c.team, fallen.cell)
			if back != null:
				back.hp = maxf(roundf(back.max_hp * by_stars(c, [0.2, 0.3, 0.5])), 1.0)
				show(ctx, [back.cell], "allies")
				sim.emit({"type": "resurrect", "unit": back})
				return
	var t: BattleUnit = ctx.focus
	if t != null:
		show(ctx, [t.cell])
		hit(ctx, t, by_stars(c, [30, 60, 120]))
		status(ctx, t, "paralysis", 1000.0)


## Season 1 (Trapinch): pulls the nearest enemy within 3 cells next to itself: LOCKED 2 / 3 / 4 s and
## 30 / 60 / 120 SPECIAL.
static func sand_pit(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var near: BattleUnit = null
	for e in sim.enemies_of(c):
		if BattleBoard.distance(e.cell, c.cell) <= 3 and not e.is_untargetable() and \
				(near == null or BattleBoard.distance(e.cell, c.cell) < BattleBoard.distance(near.cell, c.cell)):
			near = e
	if near == null:
		near = ctx.focus
	if near == null:
		return
	if BattleBoard.distance(near.cell, c.cell) > 1 and near.can_be_moved():
		var to: Variant = _free_adjacent_toward(sim, c.cell, near.cell)
		if to != null:
			sim.force_move(near, to, 300.0, "knockback")
	show(ctx, [near.cell])
	status(ctx, near, "locked", by_stars(c, [2000, 3000, 4000]))
	hit(ctx, near, by_stars(c, [30, 60, 120]))


## Season 1 (Vanillite): for 3 s, 50 / 75 / 100% of the special damage it takes goes back to its source
## (SeasonSkillEffects.after_damage); 15 / 30 / 60 SHIELD.
static func mirror_coat(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	show(ctx, [c.cell], "allies")
	c.counters.mirror_until = sim.time_ms + 3000.0
	c.counters.mirror_pct = by_stars(c, [0.5, 0.75, 1.0])
	sim.add_shield(c, by_stars(c, [15, 30, 60]) * (1.0 + c.ap / 100.0), c)


## Season 1 (Vulpix): a fox flame on each of the 3 / 3 / 4 nearest enemies (up to 3 each); an enemy with 3 flames
## blows up: 60 / 120 / 240 SPECIAL and BURN 3 s.
static func fox_fire(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var foes := sim.enemies_of(c)
	foes.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return BattleBoard.distance(a.cell, c.cell) < BattleBoard.distance(b.cell, c.cell))
	var cells: Array[Vector2i] = []
	for e in foes.slice(0, int(by_stars(c, [3, 3, 4]))):
		cells.append(e.cell)
		var flames := int(e.counters.get("fox_fire", 0)) + 1
		if flames >= 3:
			e.counters.erase("fox_fire")
			hit(ctx, e, by_stars(c, [60, 120, 240]))
			status(ctx, e, "burn", 3000.0)
		else:
			e.counters.fox_fire = flames
	show(ctx, cells)


## Season 1 (Corsola): the target loses 3 / 5 / 8 ATK; Corsola heals 300% of the target's ATK.
static func strength_sap(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	var sap := t.atk * 3.0
	t.add_stat("atk", AbilityRunner.adjust_buff(c, t, -by_stars(c, [3, 5, 8])))
	sim.heal(c, sap * (1.0 + c.ap / 100.0), c)


## Season 1 (Dratini): flies to the ally with the lowest % HP and takes its place: that ally gets
## 30 / 60 / 120 SHIELD, the enemies ADJACENT to Dratini's new cell FLINCH 2 s.
static func ally_switch(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var low: BattleUnit = null
	for a in sim.allies_of(c):
		if a != c and not a.inanimate and (low == null or a.hp_ratio() < low.hp_ratio()):
			low = a
	if low == null:
		return
	if low.can_be_moved() and c.can_be_moved():
		sim.swap_cells(c.cell, low.cell, "dash", 300.0)
	sim.add_shield(low, by_stars(c, [30, 60, 120]) * (1.0 + c.ap / 100.0), c)
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		status(ctx, e, "flinch", 2000.0)


## Season 1 (Dwebble): throws its rock onto the cell of the enemy back row with the most enemies around:
## 30 / 60 / 120 SPECIAL there and ADJACENT, LOCKED 1 s.
static func smack_down(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var row := BattleBoard.HEIGHT - 1 if c.team == BattleUnit.Team.BLUE else 0
	var best := Vector2i(-1, -1)
	var most := -1
	for cell in BattleBoard.cells_in_row(row):
		var n := enemies_on(ctx, BattleBoard.adjacent_cells(cell, true)).size()
		if n > most:
			most = n
			best = cell
	if most <= 0 and ctx.focus != null:
		best = ctx.focus.cell
	var cells := BattleBoard.adjacent_cells(best, true)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		hit(ctx, e, by_stars(c, [30, 60, 120]))
		status(ctx, e, "locked", 1000.0)


## Season 1 (Gible): a quake spreading in 3 rings around it (1, 2, 3 cells), 0.4 s apart: 20 / 40 / 80 SPECIAL to
## the enemies of each ring (not FLYING).
static func earthquake(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var center := c.cell
	for r in range(1, 4):
		sim.schedule(400.0 * (r - 1), c, _quake_ring.bind(ctx, center, r))


static func _quake_ring(ctx: Dictionary, center: Vector2i, r: int) -> void:
	var c: BattleUnit = ctx.caster
	var ring: Array[Vector2i] = []
	for cell in BattleBoard.cells_in_range(center, r):
		if BattleBoard.distance(cell, center) == r:
			ring.append(cell)
	show(ctx, ring)
	for e in enemies_on(ctx, ring):
		if not e.types.has("FLYING"):
			hit(ctx, e, by_stars(c, [20, 40, 80]))


## Season 1 (Rockruff): hides in the rocks for 1.5 s (untargetable); its first attack after that is a sure critical
## hit dealing 150 / 200 / 250% ATK (SeasonSkillEffects.on_attack_hit).
static func rock_ambush(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	show(ctx, [c.cell], "allies")
	c.add_status("untargetable", 1500.0)
	c.counters.ambush = by_stars(c, [1.5, 2.0, 2.5])
	for e in sim.units:
		if e.target == c:
			e.target = null


## Season 1 (Snorunt): ties its fate to the target for 5 s: if Snorunt faints meanwhile, the target faints too
## (SeasonSkillEffects.on_death); else, when it ends, 40 / 80 / 160 SPECIAL and FREEZE 1 s on the target.
static func destiny_bond(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	c.counters.bond_until = sim.time_ms + 5000.0
	c.counters.bond_with = t.id
	sim.schedule(5000.0, c, func() -> void:
		if t.alive and int(c.counters.get("bond_with", -1)) == t.id:
			c.counters.erase("bond_until")
			show(ctx, [t.cell])
			hit(ctx, t, by_stars(c, [40, 80, 160]))
			status(ctx, t, "freeze", 1000.0))


## Season 1 (Pawniard): every enemy under 12 / 16 / 22% HP falls; each one gives it 3 / 5 / 8 ATK. None: 100% ATK as
## TRUE on the target.
static func supreme_overlord(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var below := by_stars(c, [0.12, 0.16, 0.22])
	var cells: Array[Vector2i] = []
	for e in sim.enemies_of(c):
		if e.hp < e.max_hp * below and not e.inanimate:
			cells.append(e.cell)
			var r := hit(ctx, e, e.hp + e.shield + 1.0, BattleUnit.DamageKind.TRUE, false)
			if r.death:
				c.add_stat("atk", by_stars(c, [3, 5, 8]))
	if not cells.is_empty():
		show(ctx, cells)
		return
	var t: BattleUnit = ctx.focus
	if t != null:
		show(ctx, [t.cell])
		hit(ctx, t, c.atk, BattleUnit.DamageKind.TRUE)


## Season 1 (Venipede): +10 / 20 / 40 SPEED and +4 / 8 / 15 ATK for 5 s; then (or when it faints) it hands them to
## the ADJACENT ally with the most ATK for the rest of the fight (SeasonSkillEffects.pass_baton).
static func baton_pass(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	if c.counters.has("baton"):
		SeasonSkillEffects.pass_baton(sim, c)
	var boost := {"speed": by_stars(c, [10, 20, 40]), "atk": by_stars(c, [4, 8, 15])}
	c.add_stat("speed", boost.speed)
	c.add_stat("atk", boost.atk)
	c.counters.baton = boost
	show(ctx, [c.cell], "allies")
	var stamp := sim.time_ms
	c.counters.baton_stamp = stamp
	sim.schedule(5000.0, c, func() -> void:
		if float(c.counters.get("baton_stamp", -1.0)) == stamp:
			SeasonSkillEffects.pass_baton(sim, c))
#endregion


#region abilities (season1c)
## Season 1 (Arctovish): 4 s of primal cold: every second the enemies within 2 cells lose 20% more SPEED and take 20
## SPECIAL; one slowed by 80% FREEZES 1.5 s. Their SPEED comes back after.
static func primal_chill(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var center := c.cell
	var slowed: Dictionary = {} # unit -> [SPEED taken, stacks]
	for i in 4:
		sim.schedule(1000.0 * i, null, func() -> void:
			if sim.finished:
				return
			var cells := BattleBoard.cells_in_range(center, 2)
			show(ctx, cells)
			for e in enemies_on(ctx, cells):
				var st: Array = slowed.get(e, [0.0, 0])
				var loss := roundf(e.speed * 0.2)
				e.add_stat("speed", -loss)
				st[0] = float(st[0]) + loss
				st[1] = int(st[1]) + 1
				slowed[e] = st
				hit(ctx, e, 20.0)
				if int(st[1]) == 4:
					status(ctx, e, "freeze", 1500.0))
	sim.schedule(4000.0, null, func() -> void:
		for e in slowed:
			if e.alive:
				e.add_stat("speed", float(slowed[e][0])))


## Season 1 (Armarouge): 250 SPECIAL shared evenly by every enemy on the board.
static func armor_salvo(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var foes := sim.enemies_of(c)
	if foes.is_empty():
		return
	var each := 250.0 * (1.0 + c.ap / 100.0) / foes.size()
	show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	for e in foes:
		hit(ctx, e, each, BattleUnit.DamageKind.SPECIAL, false)


## Season 1 (Eiscue): pulls every enemy 2 cells away into the cells around it; those pulled FREEZE 1 s and take 40
## SPECIAL.
static func snow_huddle(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var pulled: Array[BattleUnit] = []
	for e in sim.enemies_of(c):
		if BattleBoard.distance(e.cell, c.cell) == 2 and e.can_be_moved():
			var to: Variant = _free_adjacent_toward(sim, c.cell, e.cell)
			if to != null:
				sim.force_move(e, to, 300.0, "knockback")
				pulled.append(e)
	show(ctx, BattleBoard.cells_in_range(c.cell, 2))
	for e in pulled:
		status(ctx, e, "freeze", 1000.0)
		hit(ctx, e, 40.0)


## Season 1 (Emolga): 3 afterimages: each one makes a basic attack at it miss (SeasonSkillEffects.blocks_attack);
## +20 SPEED while one is left.
static func double_team(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	show(ctx, [c.cell], "allies")
	if int(c.counters.get("decoys", 0)) <= 0:
		c.add_stat("speed", 20.0)
		c.counters.decoy_speed = 20.0
	c.counters.decoys = 3


## Season 1 (Galarian Farfetch'd): guard stance for 3 s: the first 3 basic attacks at it are parried (no damage) and
## answered with 120% ATK as PHYSICAL (SeasonSkillEffects.blocks_attack).
static func parry(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	show(ctx, [c.cell], "allies")
	c.counters.parry_until = sim.time_ms + 3000.0
	c.counters.parry = 3
	c.counters.parry_ratio = 1.2


## Season 1 (Hawlucha): carries the target up for 1.5 s (both out of reach, the target frozen in the air), then slams it
## down: 150 PHYSICAL, 60 to the enemies ADJACENT.
static func sky_drop(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	show(ctx, [t.cell])
	c.add_status("skydiving", 1500.0)
	t.add_status("stasis", 1500.0) # out of reach and held in the air (BattleUnit.can_act / is_untargetable)
	for e in sim.units:
		if e.target == t or e.target == c:
			e.target = null
	sim.schedule(1500.0, c, func() -> void:
		if not t.alive:
			return
		var cells := BattleBoard.adjacent_cells(t.cell, true)
		show(ctx, cells)
		hit(ctx, t, 150.0, BattleUnit.DamageKind.PHYSICAL)
		for e in enemies_on(ctx, BattleBoard.adjacent_cells(t.cell)):
			hit(ctx, e, 60.0, BattleUnit.DamageKind.PHYSICAL))


## Season 1 (Heatmor): fire over the target and the enemies ADJACENT to it: their SHIELD burns away, each takes
## 30 + the SHIELD lost as SPECIAL and BURNS 3 s.
static func incinerate(ctx: Dictionary) -> void:
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.adjacent_cells(t.cell, true)
	show(ctx, cells)
	for e in enemies_on(ctx, cells):
		var burnt := e.shield
		e.shield = 0.0
		hit(ctx, e, 30.0 + burnt)
		status(ctx, e, "burn", 3000.0)


## Season 1 (Latios): links its mind with the strongest ally for 6 s: the damage either takes is halved and half goes
## to the other (SeasonSkillEffects.redirect); both +40 AP meanwhile.
static func mind_link(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var best: BattleUnit = null
	for a in sim.allies_of(c):
		if a != c and not a.inanimate and (best == null or a.unit_score() > best.unit_score()):
			best = a
	if best == null:
		return
	show(ctx, [best.cell, c.cell], "allies")
	for pair in [[c, best], [best, c]]:
		var u: BattleUnit = pair[0]
		u.counters.link_with = pair[1].id
		u.counters.link_until = sim.time_ms + 6000.0
		u.add_stat("ap", 40.0)
		sim.schedule(6000.0, null, func() -> void:
			u.add_stat("ap", -40.0))


## Season 1 (Maractus): a dance floor of radius 2 around it for 5 s: the allies there +25% SPEED for that time, and
## every second the allies on it heal 3% of their max HP.
static func maraca_dance(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var center := c.cell
	var cells := BattleBoard.cells_in_range(center, 2, true)
	show(ctx, cells, "allies")
	for cell in cells:
		var a := sim.board.get_unit(cell)
		if a != null and a.alive and a.team == c.team and not a.inanimate:
			var boost := roundf(a.speed * 0.25)
			a.add_stat("speed", boost)
			sim.schedule(5000.0, null, func() -> void:
				if a.alive:
					a.add_stat("speed", -boost))
	for i in range(1, 6):
		sim.schedule(1000.0 * i, null, func() -> void:
			for cell in cells:
				var a := sim.board.get_unit(cell)
				if a != null and a.alive and a.team == c.team and not a.inanimate:
					sim.heal(a, a.max_hp * 0.03, c))


## Season 1 (Mesprit): the enemy with the most AP loses 40 AP (Mesprit gets it) and is SILENCED 2.5 s.
static func emotion_drain(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var best: BattleUnit = null
	for e in sim.enemies_of(c):
		if not e.inanimate and (best == null or e.ap > best.ap):
			best = e
	if best == null:
		return
	show(ctx, [best.cell])
	best.add_stat("ap", -40.0)
	c.add_stat("ap", 40.0)
	status(ctx, best, "silence", 2500.0)


## Season 1 (Mimikyu): patches a Pikachu disguise on itself and the 2 allies with the lowest % HP: the next hit each
## takes is stopped and its attacker takes 40 SPECIAL (SeasonSkillEffects.redirect).
static func disguise_patch(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies := sim.allies_of(c).filter(func(a: BattleUnit) -> bool: return a != c and not a.inanimate)
	allies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.hp_ratio() < b.hp_ratio())
	var wearers: Array = [c] + allies.slice(0, 2)
	show(ctx, wearers.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
	for a in wearers:
		a.counters.disguise = 1
		a.counters.disguise_dmg = roundf(40.0 * (1.0 + c.ap / 100.0))


## Season 1 (Orthworm): quicksand on the cells around the target (radius 1) for 4 s: every second the enemies there
## are slowed by half and take 30 SPECIAL; Orthworm heals what they lose.
static func earth_eater(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var cells := BattleBoard.adjacent_cells(t.cell, true)
	for i in 4:
		sim.schedule(1000.0 * i, null, func() -> void:
			if sim.finished:
				return
			show(ctx, cells)
			var total := 0.0
			for e in enemies_on(ctx, cells):
				_slow_for(sim, e, roundf(e.speed * 0.5), 1000.0)
				total += float(hit(ctx, e, 30.0).taken)
			if total > 0.0 and c.alive:
				sim.heal(c, total, c))


## Season 1 (Scream Tail): everyone else within 2 cells hears the song: 4 s later the enemies lose 25% and the allies
## 10% of their max HP as TRUE.
static func perish_song(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.cells_in_range(c.cell, 2)
	show(ctx, cells, "all")
	var listeners: Array[BattleUnit] = []
	for cell in cells:
		var u := sim.board.get_unit(cell)
		if u != null and u.alive and u != c and not u.inanimate:
			listeners.append(u)
	sim.schedule(4000.0, null, func() -> void:
		for u in listeners:
			if u.alive:
				var share := 0.25 if u.team != c.team else 0.1
				sim.deal_damage(u, roundf(u.max_hp * share), BattleUnit.DamageKind.TRUE, c if c.alive else null,
					false, true, false))
#endregion


#region abilities (season1d)
## Season 1 (Stonjourner): the ancient stones power up the ADJACENT allies for 6 s: +40 AP and 30 SHIELD.
static func power_spot(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var cells := BattleBoard.adjacent_cells(c.cell)
	show(ctx, cells, "allies")
	for cell in cells:
		var a := sim.board.get_unit(cell)
		if a != null and a.alive and a.team == c.team and not a.inanimate:
			a.add_stat("ap", 40.0)
			sim.add_shield(a, 30.0 * (1.0 + c.ap / 100.0), c)
			sim.emit({"type": "buff", "unit": a, "stat": "ap", "amount": 40.0})
			sim.schedule(6000.0, null, func() -> void:
				a.add_stat("ap", -40.0))


## Season 1 (Tropius): throws a fruit through the 4 allies with the lowest % HP: 80 HP for the first, 20% less for each
## next one; the last one also +10 SPEED.
static func fruit_toss(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies := sim.allies_of(c).filter(func(a: BattleUnit) -> bool: return not a.inanimate)
	allies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.hp_ratio() < b.hp_ratio())
	var heal := 80.0 * (1.0 + c.ap / 100.0)
	var chain := allies.slice(0, 4)
	for i in chain.size():
		var a: BattleUnit = chain[i]
		sim.schedule(200.0 * i, null, func() -> void:
			if a.alive:
				show(ctx, [a.cell], "allies")
				sim.heal(a, heal * pow(0.8, i), c)
				if i == chain.size() - 1:
					a.add_stat("speed", 10.0))


## Season 1 (Zeraora): dashes in turn to 3 enemies standing near each other, a punch each: 40 + 60% ATK as SPECIAL;
## every punch +10 SPEED for the rest of the fight.
static func plasma_blitz(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var chain: Array[BattleUnit] = [t]
	while chain.size() < 3:
		var last: BattleUnit = chain[chain.size() - 1]
		var next: BattleUnit = null
		for e in sim.enemies_of(c):
			if not chain.has(e) and not e.is_untargetable() and \
					(next == null or BattleBoard.distance(e.cell, last.cell) < BattleBoard.distance(next.cell, last.cell)):
				next = e
		if next == null:
			break
		chain.append(next)
	for i in chain.size():
		var e: BattleUnit = chain[i]
		sim.schedule(250.0 * i, c, func() -> void:
			if not e.alive:
				return
			var to: Variant = _free_adjacent_toward(sim, e.cell, c.cell)
			if to != null and c.can_be_moved():
				sim.move_unit(c, to, 150.0, "dash")
			show(ctx, [e.cell])
			hit(ctx, e, 40.0 + 0.6 * c.atk)
			c.add_stat("speed", 10.0))


## Season 1 (Celebi): every ally goes back to the HP it had 3 s ago when that was more (SeasonSkillEffects HP history),
## and is cleansed.
static func time_rewind(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var cells: Array[Vector2i] = []
	for a in sim.allies_of(c):
		if a.inanimate:
			continue
		cells.append(a.cell)
		a.cleanse()
		var hist: Array = a.counters.get("hp_hist", [])
		if not hist.is_empty():
			var before := float(hist[0])
			if before > a.hp:
				sim.heal(a, before - a.hp, c)
	show(ctx, cells, "allies")


## Season 1 (Enamorus): the 2 enemies nearest it fall for each other for 3 s: each is CHARMED toward the other and
## takes 30% more damage (SeasonSkillEffects.damage_factor).
static func love_tangle(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var foes := sim.enemies_of(c)
	foes.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return BattleBoard.distance(a.cell, c.cell) < BattleBoard.distance(b.cell, c.cell))
	if foes.size() < 2:
		if not foes.is_empty():
			status(ctx, foes[0], "charm", 2000.0)
		return
	var a: BattleUnit = foes[0]
	var b: BattleUnit = foes[1]
	show(ctx, [a.cell, b.cell])
	sim.add_status(a, "charm", 3000.0, b)
	sim.add_status(b, "charm", 3000.0, a)
	a.counters.love_until = sim.time_ms + 3000.0
	b.counters.love_until = sim.time_ms + 3000.0


## Season 1 (Melmetal): lifts the target and slams it onto the cell next to it with the most enemies around:
## 120% ATK to the target, 80% ATK to the enemies around that cell, as PHYSICAL; FLINCH 2 s.
static func iron_slam(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var spot := t.cell
	var most := -1
	for cell in BattleBoard.adjacent_cells(t.cell):
		var n := enemies_on(ctx, BattleBoard.adjacent_cells(cell)).size()
		if n > most:
			most = n
			spot = cell
	if spot != t.cell and sim.board.is_free(spot) and t.can_be_moved():
		sim.force_move(t, spot, 300.0, "knockback")
	var cells := BattleBoard.adjacent_cells(spot, true)
	show(ctx, cells)
	hit(ctx, t, 1.2 * c.atk, BattleUnit.DamageKind.PHYSICAL)
	status(ctx, t, "flinch", 2000.0)
	for e in enemies_on(ctx, BattleBoard.adjacent_cells(spot)):
		if e != t:
			hit(ctx, e, 0.8 * c.atk, BattleUnit.DamageKind.PHYSICAL)
			status(ctx, e, "flinch", 2000.0)


## Season 1 (Okidogi): toxic chains on the 3 enemies nearest it: each is dragged 1 cell closer and gets 2 POISON
## stacks; +5 DEF and +5 SPE_DEF to Okidogi per enemy chained.
static func chain_drag(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var foes := sim.enemies_of(c)
	foes.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return BattleBoard.distance(a.cell, c.cell) < BattleBoard.distance(b.cell, c.cell))
	var chained := foes.slice(0, 3)
	show(ctx, chained.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	for e in chained:
		if BattleBoard.distance(e.cell, c.cell) > 1 and e.can_be_moved():
			var closer := BattleBoard.step(e.cell, BattleBoard.orientation(e.cell, c.cell))
			if BattleBoard.in_bounds(closer) and sim.board.is_free(closer):
				sim.force_move(e, closer, 250.0, "knockback")
		status(ctx, e, "poison", 3000.0)
		status(ctx, e, "poison", 3000.0)
		c.add_stat("def", 5.0)
		c.add_stat("speDef", 5.0)


## Season 1 (Registeel): locks on the enemy with the most ATK; 1.5 s later a sure hit: 150 SPECIAL and PARALYSIS 2 s;
## while it is paralysed, attacks at it get +30% crit chance (SeasonSkillEffects.crit_bonus).
static func zap_lock(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var best: BattleUnit = null
	for e in sim.enemies_of(c):
		if not e.inanimate and (best == null or e.atk > best.atk):
			best = e
	if best == null:
		return
	show(ctx, [best.cell])
	sim.schedule(1500.0, c, func() -> void:
		if not best.alive:
			return
		show(ctx, [best.cell])
		hit(ctx, best, 150.0)
		status(ctx, best, "paralysis", 2000.0)
		best.counters.zap_until = sim.time_ms + 2000.0)


## Season 1 (Suicune): a wave over the board: every enemy is pushed 1 cell back, takes 30 + 8% of its max HP as
## SPECIAL and loses its PROTECT, REFLECT, SAFEGUARD and MAGIC_BOUNCE.
static func tidal_push(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var foes := sim.enemies_of(c)
	show(ctx, foes.map(func(e: BattleUnit) -> Vector2i: return e.cell))
	var back := Vector2i(0, 1) if c.team == BattleUnit.Team.BLUE else Vector2i(0, -1)
	for e in foes:
		for good in ["protect", "reflect", "safeguard", "magic_bounce"]:
			e.statuses.erase(good)
		if e.can_be_moved():
			knock_back(sim, e, BattleBoard.orientation(e.cell, e.cell + back))
		hit(ctx, e, 30.0 + 0.08 * e.max_hp)


## Season 1 (Axew): each basic attack that lands stores 1 fury (up to 20, SeasonSkillEffects.on_attack_hit); the
## ability spends it all: 30 / 60 / 120 SPECIAL on the target, +6% per fury.
static func dragon_fury(ctx: Dictionary) -> void:
	var c: BattleUnit = ctx.caster
	var t: BattleUnit = ctx.focus
	if t == null:
		return
	var fury := int(c.counters.get("fury", 0))
	c.counters.fury = 0
	show(ctx, [t.cell])
	hit(ctx, t, by_stars(c, [30, 60, 120]) * (1.0 + 0.06 * fury))


## Season 1 (Popplio): the 2 allies with the lowest % HP float in a bubble for 2 s (out of the fight a moment:
## status "stasis"), healing 10 / 20 / 40 HP every 0.5 s.
static func bubble_stasis(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies := sim.allies_of(c).filter(func(a: BattleUnit) -> bool: return not a.inanimate)
	allies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.hp_ratio() < b.hp_ratio())
	var held := allies.slice(0, 2)
	show(ctx, held.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
	var heal := by_stars(c, [10, 20, 40]) * (1.0 + c.ap / 100.0)
	for a in held:
		a.add_status("stasis", 2000.0)
		for e in sim.units:
			if e.target == a:
				e.target = null
		for i in range(1, 5):
			sim.schedule(500.0 * i, null, func() -> void:
				if a.alive:
					sim.heal(a, heal, c))


## Season 1 (Sandile): for 4 s every heal and SHIELD the enemies get goes to Sandile instead
## (SeasonSkillEffects.snatcher); it also bites the target: 20 / 40 / 80 SPECIAL.
static func snatch(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	c.counters.snatch_until = sim.time_ms + 4000.0
	var t: BattleUnit = ctx.focus
	if t != null:
		show(ctx, [t.cell])
		hit(ctx, t, by_stars(c, [20, 40, 80]))


## Season 1 (Scatterbug): scale powder on the 3 allies nearest it: each gets one of +20 / 40 / 80 SHIELD,
## +10 / 20 / 40 AP or +10 / 15 / 25 SPEED, at random.
static func wing_powder(ctx: Dictionary) -> void:
	var sim: BattleSim = ctx.sim
	var c: BattleUnit = ctx.caster
	var allies := sim.allies_of(c).filter(func(a: BattleUnit) -> bool: return a != c and not a.inanimate)
	allies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return BattleBoard.distance(a.cell, c.cell) < BattleBoard.distance(b.cell, c.cell))
	var dusted := allies.slice(0, 3)
	if dusted.is_empty():
		dusted = [c]
	show(ctx, dusted.map(func(a: BattleUnit) -> Vector2i: return a.cell), "allies")
	for a in dusted:
		match sim.rng.randi() % 3:
			0:
				sim.add_shield(a, by_stars(c, [20, 40, 80]) * (1.0 + c.ap / 100.0), c)
			1:
				a.add_stat("ap", by_stars(c, [10, 20, 40]))
				sim.emit({"type": "buff", "unit": a, "stat": "ap", "amount": by_stars(c, [10, 20, 40])})
			_:
				a.add_stat("speed", by_stars(c, [10, 15, 25]))
				sim.emit({"type": "buff", "unit": a, "stat": "speed", "amount": by_stars(c, [10, 15, 25])})
#endregion
