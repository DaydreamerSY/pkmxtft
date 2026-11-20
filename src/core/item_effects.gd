class_name ItemEffects
extends RefCounted

## Effects of the held items during a fight (port of app/core/effects/items.ts and
## the item checks of pokemon-state.ts / pokemon-entity.ts / simulation.ts).
## Stats come from BattleUnit.equip(); BattleSim calls these hooks:
##   on_fight_start   Kings Rock, Ability Shield, Gracidea Flower, Safety Goggles, Flame Orb
##   on_tick          Soul Dew (1 s), Green Orb (2 s), Flame Orb burn
##   on_attack        after a basic attack: Upgrade, Deep Sea Tooth, Scope Lens, Blue Orb, Loaded Dice
##   on_hit           attack that landed: Razor Fang
##   on_attack_received  Sticky Barb
##   on_damage_dealt  Shell Bell, Pokemonomicon
##   on_damage_received  Muscle Band, Smoke Ball
##   on_cast          Aqua Egg, Star Dust
## Tools (Artificial / buried): Exp Share, Terrain Extender, Pokerus Vial, Air Balloon (start),
## Electirizer, Metronome (attack), Max Elixir (cast), Spell Tag (death), Running Shoes (move),
## Magmarizer / Cooking Pot (burn), Shed Shell (Bug clone).
## Scarves (Normal): Lucky Ribbon, Efficient Bandanna (start), Mach Ribbon (tick), Black Belt
## (attack), Explosive Band (shield depleted), Cover Band / Nullify Bandanna / Twist Band /
## Big Eater Belt (BattleSim, BattleUnit, AbilityRunner).
## Poke Doll, Protective Pads, Shiny Charm, Power Lens, Rocky Helmet, Red Orb, Punching Glove,
## X-Ray Vision, Max Revive and Assault Vest are checked inside BattleSim / BattleUnit.

const GREEN_ORB_MS := 2000.0
const SOUL_DEW_MS := 1000.0


static func on_fight_start(sim: BattleSim) -> void:
	for u in sim.units.duplicate():
		if u.alive and u.has_item("GOLD_MASK"):
			_gold_mask(sim, u)
	for u in sim.units:
		if not u.alive:
			continue
		if u.has_item("KINGS_ROCK"):
			sim.add_shield(u, roundf(0.2 * u.max_hp))
		if u.has_item("SAFETY_GOGGLES"):
			sim.add_status(u, "safeguard", 60000.0)
		if u.has_item("ABILITY_SHIELD"):
			for ally in _row_neighbours(sim, u, true):
				sim.add_shield(ally, ceilf(0.2 * ally.max_hp), u)
				sim.add_status(ally, "safeguard", 5000.0)
		if u.has_item("GRACIDEA_FLOWER"):
			for ally in _row_neighbours(sim, u, true):
				ally.add_stat("speed", 20.0)
				sim.emit({"type": "buff", "unit": ally, "stat": "speed", "amount": 20.0})
		if u.has_item("FLAME_ORB"):
			sim.add_status(u, "burn", 300000.0)
		if u.has_item("LUCKY_RIBBON"):
			u.add_stat("dodge", 0.15)
		if u.has_item("AIR_BALLOON"):
			u.add_stat("dodge", 0.1)
		if u.has_item("POKERUS_VIAL") and not u.inanimate:
			sim.add_status(u, "pokerus", 1e9)
		if u.has_item("TERRAIN_EXTENDER"):
			for type in u.types:
				var field: String = {"ELECTRIC": "electric_field", "GRASS": "grass_field", "PSYCHIC": "psychic_field",
					"FAIRY": "fairy_field"}.get(type, "")
				if field != "":
					sim.add_status(u, field, 1e9)
					break
	# Exp Share: the best ATK / DEF / SPE_DEF / AP of its row neighbours (after the others)
	for u in sim.units:
		if u.alive and u.has_item("EXP_SHARE"):
			for dx in [-1, 1]:
				var n := sim.board.get_unit(u.cell + Vector2i(dx, 0))
				if n != null and n.alive:
					u.atk = maxf(u.atk, n.atk)
					u.def = maxf(u.def, n.def)
					u.spe_def = maxf(u.spe_def, n.spe_def)
					u.ap = maxf(u.ap, n.ap)
		if u.has_item("EFFICIENT_BANDANNA"):
			for ally in _row_neighbours(sim, u, true):
				ally.max_pp = roundf(0.85 * ally.max_pp)


## The unit and its left / right neighbours of the same team (ADJACENT_IN_THE_SAME_ROW).
static func _row_neighbours(sim: BattleSim, u: BattleUnit, include_self: bool) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for dx in [-1, 0, 1]:
		if dx == 0 and not include_self:
			continue
		var other := sim.board.get_unit(u.cell + Vector2i(dx, 0))
		if other != null and other.alive and other.team == u.team:
			out.append(other)
	return out


static func on_tick(sim: BattleSim, u: BattleUnit, dt: float) -> void:
	if u.has_status("pokerus"):
		pokerus_tick(sim, u, dt)
	if u.has_item("SOUL_DEW"):
		u.counters.soul_dew_ms = u.counters.get("soul_dew_ms", 0.0) + dt
		while u.counters.soul_dew_ms >= SOUL_DEW_MS:
			u.counters.soul_dew_ms -= SOUL_DEW_MS
			u.ap += 5.0
			u.add_pp(5.0)
	if u.has_item("GREEN_ORB"):
		u.counters.green_orb_ms = u.counters.get("green_orb_ms", 0.0) + dt
		if u.counters.green_orb_ms >= GREEN_ORB_MS:
			u.counters.green_orb_ms -= GREEN_ORB_MS
			var cells := BattleBoard.adjacent_cells(u.cell, true)
			sim.emit({"type": "area", "unit": u, "cells": cells, "affects": "allies"})
			for c in cells:
				var ally := sim.board.get_unit(c)
				if ally != null and ally.alive and ally.team == u.team:
					var overheal := sim.heal(ally, 0.05 * ally.max_hp, u)
					if overheal > 0.0:
						ally.add_pp(0.3 * overheal)
	if u.has_item("MACH_RIBBON"):
		u.counters.mach_ms = u.counters.get("mach_ms", 0.0) + dt
		while u.counters.mach_ms >= 3000.0:
			u.counters.mach_ms -= 3000.0
			u.add_stat("speed", 20.0)
	if u.has_item("FLAME_ORB") and not u.has_status("burn"):
		sim.add_status(u, "burn", 60000.0)


## After a basic attack. `hit` = {target, physical, special, true_damage, total, killed, crit}.
static func on_attack(sim: BattleSim, u: BattleUnit, hit: Dictionary) -> void:
	var target: BattleUnit = hit.target
	# Volt Surge (ability): every 3rd attack, lightning bounces through the 4 closest enemies
	if u.effects.get("volt_surge", false) and int(u.counters.get("attacks", 0)) % 3 == 0:
		var foes := sim.enemies_of(u)
		foes.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
			return BattleBoard.distance_c(a.cell, u.cell) < BattleBoard.distance_c(b.cell, u.cell))
		var damage: float = [10.0, 20.0, 30.0, 60.0][clampi(u.stars - 1, 0, 3)] * (1.0 + u.ap / 100.0)
		var cells: Array[Vector2i] = []
		for e in foes.slice(0, 4):
			cells.append(e.cell)
			sim.deal_damage(e, roundf(damage), BattleUnit.DamageKind.SPECIAL, u)
		sim.emit({"type": "area", "unit": u, "cells": cells, "affects": "enemies"})
	if u.has_item("UPGRADE"):
		u.add_stat("speed", 5.0)
		u.counters.upgrade = u.counters.get("upgrade", 0) + 1
	if u.has_item("DEEP_SEA_TOOTH"):
		u.add_pp(5.0 + (15.0 if hit.killed else 0.0))
	if u.has_item("SCOPE_LENS") and hit.crit and target != null:
		u.add_pp(target.drain_pp(10.0))
	if u.has_item("BLUE_ORB"):
		u.counters.blue_orb = u.counters.get("blue_orb", 0) + 1
		if u.counters.blue_orb >= 3:
			u.counters.blue_orb = 0
			_chain_lightning(sim, u)
	if u.has_item("LOADED_DICE") and hit.total > 0 and target != null and sim.chance(0.5, u):
		_loaded_dice(sim, u, hit)
	if u.has_item("ELECTIRIZER") and target != null and target.alive and int(u.counters.get("attacks", 0)) % 3 == 0:
		sim.add_status(target, "paralysis", 2000.0, u)
	if u.has_item("METRONOME"):
		u.add_pp(5.0)
	if u.has_item("BLACK_BELT") and hit.crit:
		sim.add_shield(u, ceilf(0.33 * float(hit.taken)))


## Blue Orb: bounces to the 2 enemies closest to the holder, 10 special damage and -15 PP each.
static func _chain_lightning(sim: BattleSim, u: BattleUnit) -> void:
	var enemies := sim.enemies_of(u)
	enemies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return BattleBoard.distance_m(a.cell, u.cell) < BattleBoard.distance_m(b.cell, u.cell))
	var cells: Array[Vector2i] = []
	for e in enemies.slice(0, 2):
		cells.append(e.cell)
		sim.deal_damage(e, 10.0, BattleUnit.DamageKind.SPECIAL, u)
		e.drain_pp(15.0)
	if not cells.is_empty():
		sim.emit({"type": "area", "unit": u, "cells": cells, "affects": "enemies"})


## Loaded Dice: the lowest-HP enemy next to the target takes 75 % of the hit (on-hit effects too).
static func _loaded_dice(sim: BattleSim, u: BattleUnit, hit: Dictionary) -> void:
	var target: BattleUnit = hit.target
	var second: BattleUnit = null
	for c in BattleBoard.adjacent_cells(target.cell):
		var e := sim.board.get_unit(c)
		if e != null and e.alive and e.team != u.team and (second == null or e.hp < second.hp):
			second = e
	if second == null:
		return
	var cells: Array[Vector2i] = [second.cell]
	sim.emit({"type": "area", "unit": u, "cells": cells, "affects": "enemies"})
	if hit.physical > 0:
		sim.deal_damage(second, roundf(hit.physical * 0.75), BattleUnit.DamageKind.PHYSICAL, u)
	if hit.special > 0:
		sim.deal_damage(second, roundf(hit.special * 0.75), BattleUnit.DamageKind.SPECIAL, u)
	if hit.true_damage > 0:
		sim.deal_damage(second, roundf(hit.true_damage * 0.75), BattleUnit.DamageKind.TRUE, u)
	on_hit(sim, u, second)


## An attack that landed on `target`.
static func on_hit(sim: BattleSim, u: BattleUnit, target: BattleUnit) -> void:
	if u.has_item("RAZOR_FANG") and target.alive:
		sim.add_status(target, "armor_reduction", 2000.0)


## Sticky Barb: melee attackers take 3 + 15 % DEF true damage and Wound 3 s.
static func on_attack_received(sim: BattleSim, t: BattleUnit, attacker: BattleUnit) -> void:
	# Lingering Aroma (ability): melee attackers take damage and lose 5 PP
	if attacker != null and attacker.alive and float(t.effects.get("aroma_until", 0.0)) > sim.time_ms \
			and BattleBoard.distance_c(t.cell, attacker.cell) == 1:
		sim.deal_damage(attacker, float(t.effects.get("aroma_damage", 10.0)), BattleUnit.DamageKind.SPECIAL, t, false, true)
		attacker.drain_pp(5.0)
	# Silk Trap (ability): melee attackers lose SPEED and get PARALYSIS 1.5 s
	if attacker != null and attacker.alive and float(t.effects.get("silk_until", 0.0)) > sim.time_ms \
			and BattleBoard.distance_c(t.cell, attacker.cell) == 1:
		attacker.add_stat("speed", AbilityRunner.adjust_buff(t, attacker, -float(t.effects.get("silk_speed", 5.0))))
		sim.add_status(attacker, "paralysis", 1500.0, t)
	# Baneful Bunker (ability): melee attackers are poisoned while it lasts
	if attacker != null and attacker.alive and float(t.effects.get("bunker_until", 0.0)) > sim.time_ms \
			and BattleBoard.distance_c(t.cell, attacker.cell) == 1:
		sim.deal_damage(attacker, float(t.effects.get("bunker_damage", 10.0)), BattleUnit.DamageKind.SPECIAL, t, false, true)
		sim.add_status(attacker, "poison", 3000.0, t)
	if not t.has_item("STICKY_BARB") or attacker == null or not attacker.alive:
		return
	if attacker.has_item("PROTECTIVE_PADS") or BattleBoard.distance_c(t.cell, attacker.cell) != 1:
		return
	sim.deal_damage(attacker, roundf(3.0 + 0.15 * t.def), BattleUnit.DamageKind.TRUE, t, false, true)
	sim.add_status(attacker, "wound", 3000.0)


static func on_damage_dealt(sim: BattleSim, attacker: BattleUnit, t: BattleUnit, taken: float, kind: int) -> void:
	if attacker == t:
		return
	if attacker.has_item("SHELL_BELL") and taken > 0.0:
		sim.heal(attacker, ceilf(0.33 * taken))
	if attacker.has_item("POKEMONOMICON") and kind == BattleUnit.DamageKind.SPECIAL and t.alive:
		sim.add_status(t, "burn", 3000.0)
		t.add_stat("speDef", -1.0)


static func on_damage_received(sim: BattleSim, t: BattleUnit, taken: float) -> void:
	if t.has_item("ABSORB_BULB") and t.alive and t.hp < 0.5 * t.max_hp:
		# Absorb Bulb: the damage its defenses stopped bursts on the adjacent enemies
		var burst := roundf(float(t.counters.get("reduced", 0.0)))
		t.use_up("ABSORB_BULB")
		var cells := BattleBoard.adjacent_cells(t.cell)
		sim.emit({"type": "area", "unit": t, "cells": cells, "affects": "enemies"})
		for c in cells:
			var e := sim.board.get_unit(c)
			if e != null and e.alive and e.team != t.team and burst > 0.0:
				sim.deal_damage(e, burst, BattleUnit.DamageKind.SPECIAL, t)
	if t.has_item("MUSCLE_BAND") and taken > 0.0 and t.counters.get("muscle_band", 0) < 20:
		t.counters.muscle_band = t.counters.get("muscle_band", 0) + 1
		if t.counters.muscle_band % 2 == 0:
			t.add_stat("atk", 1.0)
			t.add_stat("def", 2.0)
			t.add_stat("speed", 5.0)
	if t.has_item("SMOKE_BALL") and t.alive and t.hp < 0.4 * t.max_hp:
		smoke_ball(sim, t)


## The holder fainted: Spell Tag curses its killer for 10 s.
static func on_death(sim: BattleSim, t: BattleUnit, attacker: BattleUnit) -> void:
	# Amulet Coin: 1 gold per KO
	if attacker != null and attacker.has_item("AMULET_COIN") and attacker.team != t.team \
			and attacker.team == BattleUnit.Team.BLUE and sim.player != null:
		sim.rewards.gold += 1
	# Gold Bottle Cap: 1 gold per KO, the last enemy gives 1 more per KO of the fight
	if attacker != null and attacker.has_item("GOLD_BOTTLE_CAP") and attacker.team != t.team \
			and attacker.team == BattleUnit.Team.BLUE and sim.player != null:
		attacker.counters.bottle_caps = int(attacker.counters.get("bottle_caps", 0)) + 1
		var last := sim.alive_units(t.team).is_empty()
		sim.rewards.gold += attacker.counters.bottle_caps + 1 if last else 1
	if t.has_item("SPELL_TAG") and attacker != null and attacker.alive and attacker != t:
		sim.add_status(attacker, "curse", 10000.0, t)
	# Rusted Sword: the ally with the lowest ATK and a free slot picks it up (+50% of its BASE ATK)
	if t.has_item("RUSTED_SWORD"):
		t.use_up("RUSTED_SWORD")
		var receiver: BattleUnit = null
		for a in sim.alive_units(t.team):
			if a != t and a.items.size() < BattleUnit.MAX_ITEMS and not a.inanimate \
					and (receiver == null or a.atk < receiver.atk):
				receiver = a
		if receiver != null:
			receiver.items.append("RUSTED_SWORD")
			receiver.add_stat("atk", 0.5 * receiver.base_atk)
			sim.emit({"type": "item", "unit": receiver, "item": "RUSTED_SWORD", "text": GameData.item_name("RUSTED_SWORD")})


## Running Shoes: +5 SPEED each step.
static func on_move(u: BattleUnit) -> void:
	if u.has_item("RUNNING_SHOES"):
		u.add_stat("speed", 5.0)


## Pokerus (Pokerus Vial): every 3 s +1 ATK, +10 AP, then infects up to 2 adjacent allies.
static func pokerus_tick(sim: BattleSim, u: BattleUnit, dt: float) -> void:
	u.counters.pokerus_ms = float(u.counters.get("pokerus_ms", 3000.0)) - dt
	if u.counters.pokerus_ms > 0.0:
		return
	u.counters.pokerus_ms = 3000.0
	u.add_stat("atk", 1.0)
	u.add_stat("ap", 10.0)
	var infected := 0
	for c in BattleBoard.adjacent_cells(u.cell):
		var ally := sim.board.get_unit(c)
		if infected < 2 and ally != null and ally.alive and ally.team == u.team and not ally.has_status("pokerus") \
				and not ally.inanimate:
			sim.add_status(ally, "pokerus", 1e9)
			infected += 1


## Explosive Band: the first time the shield is gone, 50% of all the shield gained this
## fight hits the adjacent enemies as SPECIAL (no AP); the band is used up.
static func explosive_band(sim: BattleSim, t: BattleUnit) -> void:
	t.use_up("EXPLOSIVE_BAND")
	var damage := roundf(0.5 * float(t.counters.get("shield_gained", 0.0)))
	var cells := BattleBoard.adjacent_cells(t.cell)
	sim.emit({"type": "area", "unit": t, "cells": cells, "affects": "enemies"})
	for c in cells:
		var e := sim.board.get_unit(c)
		if e != null and e.alive and e.team != t.team and damage > 0.0:
			sim.deal_damage(e, damage, BattleUnit.DamageKind.SPECIAL, t)


## Smoke Ball: adjacent enemies Paralysis + Blinded 4 s; the holder gets 50 shield and jumps away.
static func smoke_ball(sim: BattleSim, t: BattleUnit) -> void:
	t.use_up("SMOKE_BALL")
	var cells := BattleBoard.adjacent_cells(t.cell)
	sim.emit({"type": "area", "unit": t, "cells": cells, "affects": "enemies"})
	for c in cells:
		var e := sim.board.get_unit(c)
		if e != null and e.alive and e.team != t.team:
			sim.add_status(e, "paralysis", 4000.0)
			sim.add_status(e, "blinded", 4000.0)
	if t.alive and t.hp > 0.0: # also dropped when fainting, without the shield and the jump
		sim.add_shield(t, 50.0)
		var dest: Variant = AbilityRunner.fly_away_cell(sim, t)
		if dest != null:
			sim.move_unit(t, dest, 250.0, "dash")


static func on_cast(sim: BattleSim, u: BattleUnit) -> void:
	if u.has_item("MAX_ELIXIR") and u.cast_count == 1:
		sim.schedule(1000.0, u, func() -> void:
			if u.alive and u.has_item("MAX_ELIXIR"):
				u.add_pp(u.max_pp, true)
				u.use_up("MAX_ELIXIR"))
	if u.has_item("AQUA_EGG"):
		# web: 20 % of the bar + 2 PP a cast so far, at most maxPP - 10: all of it in shares of the bar here (own maxPP)
		u.add_pp(minf(u.max_pp - u.web_pp(10.0), roundf(u.max_pp * (0.2 + 0.02 * u.cast_count))), true)
	if u.has_item("STAR_DUST"):
		sim.add_shield(u, roundf(0.5 * u.max_pp))
	if u.has_item("BALL"):
		_throw_ball(sim, u)


## Gold Mask (simulation.ts): 3 or 4 Pokémon sharing a type with its holder join the team,
## stronger as the run goes on.
const GOLD_MASK_SPAWNS := [
	[5, [["COMMON", 1], ["COMMON", 1], ["COMMON", 1]]],
	[10, [["COMMON", 1], ["COMMON", 1], ["UNCOMMON", 1]]],
	[15, [["UNCOMMON", 1], ["UNCOMMON", 1], ["RARE", 1]]],
	[20, [["UNCOMMON", 1], ["RARE", 1], ["EPIC", 1]]],
	[25, [["UNCOMMON", 2], ["RARE", 1], ["EPIC", 1]]],
	[30, [["RARE", 2], ["EPIC", 1], ["EPIC", 1]]],
	[35, [["RARE", 2], ["EPIC", 2], ["UNIQUE", 3]]],
	[9999, [["EPIC", 2], ["UNIQUE", 3], ["ULTRA", 2]]],
]


static func _gold_mask(sim: BattleSim, u: BattleUnit) -> void:
	var stage: int = sim.player.stage if sim.player != null else 1
	var picks: Array = GOLD_MASK_SPAWNS[-1][1]
	for row in GOLD_MASK_SPAWNS:
		if stage <= row[0]:
			picks = row[1]
			break
	for pick in picks:
		var candidates: Array = GameData.pokemon.keys().filter(func(pkm: String) -> bool:
			var d: Dictionary = GameData.pokemon[pkm]
			return d.rarity == pick[0] and int(d.stars) == pick[1] and GameData.is_ability_ported(d.skill) \
				and d.types.any(func(t: String) -> bool: return u.types.has(t)))
		if candidates.is_empty():
			continue
		var cell: Variant = sim.closest_free_cell_near(u.cell, u.team)
		if cell == null:
			return
		var spawn := BattleUnit.create(candidates[sim.rng.randi() % candidates.size()], u.team)
		spawn.is_spawn = true
		sim.add_unit(spawn, cell)


## Ball: thrown to the farthest FIELD ally with a free slot (it gets the Ball and 50 SHIELD),
## else at the farthest enemy (30% SPEED as PHYSICAL).
static func _throw_ball(sim: BattleSim, u: BattleUnit) -> void:
	var receiver: BattleUnit = null
	var best := 0
	for a in sim.allies_of(u):
		var d := BattleBoard.distance_m(a.cell, u.cell)
		if a.types.has("FIELD") and a.items.size() < BattleUnit.MAX_ITEMS and not a.has_item("BALL") and d > best:
			receiver = a
			best = d
	var ally := receiver != null
	if not ally:
		for e in sim.enemies_of(u):
			var d := BattleBoard.distance_m(e.cell, u.cell)
			if d > best:
				receiver = e
				best = d
	if receiver == null:
		return
	u.use_up("BALL")
	var travel := roundf(best * 1000.0 / (4.0 * (1.0 + u.speed / 100.0)))
	sim.emit({"type": "area", "unit": u, "cells": [receiver.cell] as Array[Vector2i],
		"affects": "allies" if ally else "enemies"})
	var damage := roundf(0.3 * u.speed)
	sim.schedule(500.0 if ally else travel, u, func() -> void:
		if not receiver.alive:
			return
		if ally:
			if receiver.items.size() < BattleUnit.MAX_ITEMS:
				receiver.equip(["BALL"])
			sim.add_shield(receiver, 50.0, u)
		else:
			sim.deal_damage(receiver, damage, BattleUnit.DamageKind.PHYSICAL, u))
