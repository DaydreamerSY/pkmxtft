class_name SynergyEffects
extends RefCounted

## Synergy effects during a fight: port of Simulation.applyEffect / applyPostEffects /
## applyCurse / tidal waves, app/core/effects/synergies.ts and the synergy checks of
## pokemon-state.ts, pokemon-entity.ts and status.ts.
##
## BattleSim.team_tiers[team] = {type: tier} of the active synergies; in the web game a
## PvE wave has none, here the difficulty level can give the wave its own (FightSetup). on_spawn() gives each unit its stat buffs and the tiers
## it benefits from (BattleUnit.synergy: mostly units of that type, whole team for
## STEEL DEF, ICE SPE_DEF, AQUATIC, AMORPHOUS). The other hooks are called by BattleSim:
##   before_start     Bug clones
##   on_fight_start   Ghost curses, Normal shields
##   update           Aquatic tidal waves
##   on_second        Water / Light PP
##   on_tick          Grass heal, curses kept on their target
##   on_attack        Fire ATK, Electric triple attacks
##   on_attack_received  Pounce Wand splash (Fairy)
##   on_hit           Ice freeze, Fire burn, Monster flinch, Ghost silence, Poison, Wild wound
##   on_damage_dealt  Human lifesteal
##   on_damage_received  Flying fly away, Fighting throw, Wild berserk
##   on_kill          Monster growth
##   on_death         Field heal, curse passed on
##   on_cast          Sound cry
## plus blocked_damage (Fighting), fossil_awaken (Fossil), crit_reduction (Rock),
## steel_true_part (Steel), apply_wands (Fairy), status_duration_factor (Aquatic).

const DARK_CRIT := [30.0, 40.0, 50.0]
const DARK_CRIT_POWER := [0.4, 0.6, 1.0]
const PSYCHIC_AP := [50.0, 100.0, 150.0]
const ROCK_DEF := [10.0, 25.0, 50.0]
const ROCK_CRIT_REDUCTION := [0.3, 0.5, 0.7]
const ICE_SPE_DEF := [4.0, 12.0, 25.0, 50.0]
const STEEL_TEAM_DEF := 3.0
const STEEL_TRUE_PART := [0.33, 0.66, 1.0, 1.25]
const NORMAL_SHIELD := [15.0, 20.0, 25.0, 30.0]
const GRASS_HEAL := [5.0, 15.0, 25.0, 25.0]
const GRASS_HEAL_MS := 2000.0
const WATER_PP := [4.0, 8.0, 12.0]
const FIGHTING_BLOCK := [3.0, 6.0, 9.0, 12.0]
const FIGHTING_THROW_EVERY := 10
const HUMAN_LIFESTEAL := [0.25, 0.35, 0.5]
const AQUATIC_REDUCTION := [0.7, 0.5, 0.3, 0.3]
const TIDAL_WAVE_MS := 7000.0
const FOSSIL_FACTOR := [0.4, 0.7, 1.0]
const FOSSIL_HP_RATIO := 0.3
const ARTIFICIAL_FACTOR := [0.0, 0.05, 0.1]
const ARTIFICIAL_AP := [0.0, 5.0, 10.0]
const WILD_SPEED := [20.0, 40.0, 40.0, 40.0]
const WILD_ATK_RATIO := 0.4
const WILD_BERSERK_SHIELD := 30.0
const GHOST_DODGE := 0.15
const LIGHT_PP := 8.0
const FLY_AWAY_PROTECT_MS := 2000.0
const CURSE_OF_FATE_MS := 8000.0
const CURSE_STATUS_MS := 30000.0
const CURSES := ["vulnerability", "weakness", "torment", "fate"]


static func _value(key: String, tier: int) -> float:
	var list: Array = GameData.config.get("synergyValues", {}).get(key, [])
	return float(list[tier]) if tier >= 0 and tier < list.size() else 0.0


static func _at(list: Array, tier: int) -> float:
	return float(list[clampi(tier - 1, 0, list.size() - 1)])


static func setup(sim: BattleSim) -> void:
	sim.synergy_state = {"tidal_timer": 0.0, "tidal_count": 0}
	for tiers in sim.team_tiers:
		if tiers.has("AQUATIC"):
			sim.synergy_state.tidal_timer = TIDAL_WAVE_MS


#region spawn: stat buffs (Simulation.applyEffect)
static func on_spawn(sim: BattleSim, u: BattleUnit) -> void:
	var tiers: Dictionary = sim.team_tiers[u.team]
	if tiers.is_empty() or u.inanimate:
		return
	var info: Dictionary = sim.team_info[u.team]
	for type in tiers:
		var t: int = tiers[type]
		# effects given to the whole team
		match type:
			"STEEL":
				u.add_stat("def", STEEL_TEAM_DEF)
			"ICE":
				u.add_stat("speDef", _at(ICE_SPE_DEF, t))
				u.synergy[type] = t # Sheer Cold works for everyone, the freeze only for ICE
			"AQUATIC":
				u.synergy[type] = t
			"AMORPHOUS":
				var active := int(info.get("active", 0))
				u.add_stat("speed", _value("amorphousSpeed", t) * active)
				u.add_stat("maxHP", _value("amorphousHp", t) * active)
			"LIGHT":
				_spotlight(sim, u, t)
		if not u.types.has(type) or type in ["ICE", "AQUATIC", "AMORPHOUS", "LIGHT"]:
			continue
		# effects of the Pokémon of that type
		u.synergy[type] = t
		match type:
			"DARK":
				u.add_stat("critChance", _at(DARK_CRIT, t))
				u.add_stat("critPower", _at(DARK_CRIT_POWER, t))
			"PSYCHIC":
				u.add_stat("ap", _at(PSYCHIC_AP, t))
			"ROCK":
				u.add_stat("def", _at(ROCK_DEF, t))
			"GHOST":
				u.add_stat("dodge", GHOST_DODGE)
			"FLYING":
				u.counters.flying_protection = 2 if t >= 3 else 1
			"FAIRY":
				if _wands(sim, u).has("LONG_WAND") and u.attack_range > 1:
					u.attack_range += 1
				if t >= 4:
					u.add_stat("luck", 5.0)
			"DRAGON":
				var dragon_stars := float(info.get("dragon_stars", 0))
				if t >= 2:
					u.shield += dragon_stars * 5.0
				if t >= 3:
					u.add_stat("ap", dragon_stars)
					u.add_stat("speed", dragon_stars)
			"WILD":
				u.add_stat("speed", _at(WILD_SPEED, t))
				if t >= 3:
					u.add_stat("atk", ceilf(WILD_ATK_RATIO * u.base_atk))
			"ARTIFICIAL":
				var n := mini(u.items.size(), BattleUnit.MAX_ITEMS)
				if t >= 2 and n > 0:
					u.add_stat("atk", _at(ARTIFICIAL_FACTOR, t) * u.base_atk * n)
					u.add_stat("ap", _at(ARTIFICIAL_AP, t) * n)
					u.shield += roundf(_at(ARTIFICIAL_FACTOR, t) * u.max_hp * n)
			"GROUND":
				_ground_hole(sim, u, t)


## The Pokémon standing on the player's light cell when the fight starts (not a spawn).
static func _spotlight(sim: BattleSim, u: BattleUnit, t: int) -> void:
	var light: Variant = sim.team_info[u.team].get("light")
	if light == null or u.is_spawn or (u.team == BattleUnit.Team.BLUE and u.owned_id < 0) or u.cell != light:
		return
	u.synergy["LIGHT"] = t
	u.effects.spotlight = true
	u.add_stat("atk", ceilf(u.atk * 0.2))
	u.add_stat("ap", 20.0)
	if t >= 3:
		u.add_status("safeguard", 8000.0)
		u.add_stat("def", 0.5 * u.base_def)
		u.add_stat("speDef", 0.5 * u.base_spe_def)
	if t >= 4:
		u.shield += 100.0
		u.effects.resurrection = true


## GroundHoleEffect: DEF / SPE_DEF from the depth of the hole it starts in, ATK at max depth.
static func _ground_hole(sim: BattleSim, u: BattleUnit, t: int) -> void:
	var holes: Dictionary = sim.team_info[u.team].get("holes", {})
	var depth := int(holes.get(u.cell, 0))
	var def_buff := depth * _value("groundDef", t)
	var atk_buff := _value("groundAtk", t) if depth >= 5 else 0.0
	if t >= 4:
		var full_rows := 0
		for y in PlayerState.PLAYER_ROWS:
			var full := true
			for x in BattleBoard.WIDTH:
				full = full and int(holes.get(Vector2i(x, y), 0)) >= 5
			if full:
				full_rows += 1
		def_buff += full_rows * 5.0
		if full_rows == PlayerState.PLAYER_ROWS:
			atk_buff += 8.0
	u.add_stat("atk", atk_buff)
	u.add_stat("def", def_buff)
	u.add_stat("speDef", def_buff)
#endregion


#region fight start
## Bug: copies of the strongest Bug Pokémon on the board (1 to 4).
static func before_start(sim: BattleSim) -> void:
	for team in [BattleUnit.Team.BLUE, BattleUnit.Team.RED]:
		var t := int(sim.team_tiers[team].get("BUG", 0))
		if t <= 0:
			continue
		var bugs: Array = sim.alive_units(team).filter(func(u: BattleUnit) -> bool:
			return u.types.has("BUG") and not u.is_spawn and not u.inanimate)
		bugs.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.unit_score() > b.unit_score())
		for i in mini(t, bugs.size()):
			# Vespiquen calls 2 Combee instead of a copy of itself
			var vespiquen: bool = bugs[i].passive == "VESPIQUEN" and GameData.pokemon.has("COMBEE")
			for _n in (2 if vespiquen else 1):
				var cell: Variant = sim.closest_free_cell_near(bugs[i].cell, team)
				if cell == null:
					continue
				var clone := BattleUnit.create("COMBEE" if vespiquen else bugs[i].pkm, team)
				sim.add_unit(clone, cell)
				if bugs[i].has_item("SHED_SHELL"): # the copy and the original share the HP
					bugs[i].add_stat("maxHP", -0.5 * bugs[i].max_hp)
					clone.add_stat("maxHP", -0.5 * clone.max_hp)
				sim.emit({"type": "effect", "unit": clone, "text": "Swarm!", "color": Color(0.75, 0.85, 0.3)})


## Ghost curses on the enemy team, then the Normal shields (OnSimulationStart).
static func on_fight_start(sim: BattleSim) -> void:
	for team in [BattleUnit.Team.BLUE, BattleUnit.Team.RED]:
		var t := int(sim.team_tiers[team].get("GHOST", 0))
		for i in mini(t, CURSES.size()):
			apply_curse(sim, CURSES[i], 1 - team)
	for u in sim.units:
		var t := u.synergy_tier("NORMAL")
		if t <= 0 or not u.alive:
			continue
		var amount := _at(NORMAL_SHIELD, t)
		sim.add_shield(u, amount)
		for c in BattleBoard.adjacent_cells(u.cell):
			var ally := sim.board.get_unit(c)
			if ally != null and ally.alive and ally.team == u.team:
				sim.add_shield(ally, amount)


## Simulation.applyCurse: curses the matching enemy of `cursed_team` (needs a Ghost
## on the other team). Vulnerability: highest DEF + SPE_DEF, -5 each, FLINCH. Weakness:
## highest ATK, -20%, PARALYSIS. Torment: highest AP, -30, FATIGUE. Fate: strongest, KO in 8 s.
static func apply_curse(sim: BattleSim, kind: String, cursed_team: int) -> void:
	if not sim.alive_units(1 - cursed_team).any(func(u: BattleUnit) -> bool: return u.types.has("GHOST")):
		return
	var candidates: Array[BattleUnit] = sim.alive_units(cursed_team)
	if candidates.is_empty():
		return
	var score := func(u: BattleUnit) -> float:
		match kind:
			"vulnerability": return u.def + u.spe_def
			"weakness": return u.atk
			"torment": return u.ap
		return u.unit_score()
	var best := -INF
	var picks: Array[BattleUnit] = []
	for u in candidates:
		var s: float = score.call(u)
		if s > best:
			best = s
			picks = [u]
		elif s == best:
			picks.append(u)
	var cursed: BattleUnit = picks[sim.rng.randi() % picks.size()]
	cursed.curses[kind] = true
	match kind:
		"vulnerability":
			cursed.add_stat("def", -5.0)
			cursed.add_stat("speDef", -5.0)
			sim.add_status(cursed, "flinch", CURSE_STATUS_MS)
		"weakness":
			cursed.add_stat("atk", -roundf(0.2 * cursed.atk))
			sim.add_status(cursed, "paralysis", CURSE_STATUS_MS)
		"torment":
			cursed.add_stat("ap", -30.0)
			sim.add_status(cursed, "fatigue", CURSE_STATUS_MS)
		"fate":
			sim.add_status(cursed, "curse", CURSE_OF_FATE_MS)
	sim.emit({"type": "effect", "unit": cursed, "text": "Curse of " + kind.capitalize(), "color": Color(0.6, 0.35, 0.9)})
#endregion


#region timers
## Aquatic: a tidal wave after 7 s (and 14 s at tier 3, every 7 s at tier 4).
static func update(sim: BattleSim, dt: float) -> void:
	var st: Dictionary = sim.synergy_state
	if st.get("tidal_timer", 0.0) <= 0.0:
		return
	st.tidal_timer -= dt
	if st.tidal_timer > 0.0:
		return
	st.tidal_count += 1
	var surfer := false
	for team in [BattleUnit.Team.BLUE, BattleUnit.Team.RED]:
		var t := int(sim.team_tiers[team].get("AQUATIC", 0))
		surfer = surfer or t >= 4
		var level := 3 if t >= 3 else t
		if (level > 0 and st.tidal_count == 1) or (level == 3 and st.tidal_count == 2) or t >= 4:
			tidal_wave(sim, team, level)
			if t >= 4 and st.tidal_count == 1:
				_add_pikachu_surfer(sim, team)
	if surfer or st.tidal_count < 2:
		st.tidal_timer = TIDAL_WAVE_MS


## triggerTidalWave: clears the board effects, cleanses the team, heals its Aquatic
## Pokémon (10% max HP per level) and hits enemies (5% max HP per level as TRUE),
## pushing them back toward their side.
static func tidal_wave(sim: BattleSim, team: int, level: int) -> void:
	var cells: Array[Vector2i] = BattleBoard.all_cells()
	sim.emit({"type": "area", "unit": null, "cells": cells, "affects": "allies" if team == BattleUnit.Team.BLUE else "enemies"})
	sim.emit({"type": "effect", "unit": null, "text": "Tidal Wave!", "color": Color(0.4, 0.75, 1.0), "team": team})
	sim.board_effects.clear()
	var rows := range(BattleBoard.HEIGHT - 1, -1, -1) if team == BattleUnit.Team.BLUE else range(BattleBoard.HEIGHT)
	var push := 1 if team == BattleUnit.Team.BLUE else -1
	for y in rows:
		for x in BattleBoard.WIDTH:
			var u := sim.board.get_unit(Vector2i(x, y))
			if u == null or not u.alive:
				continue
			if u.team == team:
				u.cleanse()
				if u.passive == "PIKACHU_SURFER":
					u.add_pp(u.max_pp, true) # rides the wave
				if u.types.has("AQUATIC"):
					sim.heal(u, level * 0.1 * u.max_hp)
				continue
			sim.deal_damage(u, level * 0.05 * u.max_hp, BattleUnit.DamageKind.TRUE, null, false, false, false)
			if not u.alive or u.has_item("HEAVY_DUTY_BOOTS"):
				continue
			var dest := u.cell
			while sim.board.is_free(dest + Vector2i(0, push)):
				dest += Vector2i(0, push)
			if dest != u.cell:
				sim.move_unit(u, dest, 300.0, "knockback")
				u.cooldown = 500.0


## Aquatic 4: a surfing Pikachu joins the team with the first wave.
static func _add_pikachu_surfer(sim: BattleSim, team: int) -> void:
	if not GameData.pokemon.has("PIKACHU_SURFER"):
		return
	for y in (range(BattleBoard.HEIGHT) if team == BattleUnit.Team.BLUE else range(BattleBoard.HEIGHT - 1, -1, -1)):
		for x in BattleBoard.WIDTH:
			if sim.board.is_free(Vector2i(x, y)):
				sim.add_unit(BattleUnit.create("PIKACHU_SURFER", team), Vector2i(x, y))
				return


## Water: +4 / 8 / 12 PP per second. Light 2+: +8 PP per second in the spotlight.
static func on_second(_sim: BattleSim, u: BattleUnit) -> void:
	var water := u.synergy_tier("WATER")
	if water > 0:
		u.add_pp(_at(WATER_PP, water))
	if u.synergy_tier("LIGHT") >= 2 and u.effects.get("spotlight", false):
		u.add_pp(LIGHT_PP)


## Grass heals every 2 s; Ghost curses stay on their target (re-applied when cleansed).
static func on_tick(sim: BattleSim, u: BattleUnit, dt: float) -> void:
	var grass := u.synergy_tier("GRASS")
	if grass > 0:
		u.counters.grass_ms = u.counters.get("grass_ms", GRASS_HEAL_MS) - dt
		if u.counters.grass_ms <= 0.0:
			u.counters.grass_ms = GRASS_HEAL_MS
			sim.heal(u, _at(GRASS_HEAL, grass))
	if u.curses.is_empty():
		return
	if u.curses.has("vulnerability") and not u.has_status("flinch"):
		sim.add_status(u, "flinch", CURSE_STATUS_MS)
	if u.curses.has("weakness") and not u.has_status("paralysis"):
		sim.add_status(u, "paralysis", CURSE_STATUS_MS)
	if u.curses.has("torment") and not u.has_status("fatigue"):
		sim.add_status(u, "fatigue", CURSE_STATUS_MS)
	if u.curses.has("fate") and not u.has_status("curse"):
		sim.add_status(u, "curse", CURSE_OF_FATE_MS + 100.0)
#endregion


#region attacks
## After a basic attack. Fire: +ATK per attack (tiers 2-4). Electric: every 4th
## (tier 1) / 3rd attack hits twice more; tier 3 also burns 10 PP of the target.
static func on_attack(sim: BattleSim, u: BattleUnit, hit: Dictionary) -> void:
	var fire := u.synergy_tier("FIRE")
	if fire > 0:
		u.add_stat("atk", _value("fireAtk", fire))
	var electric := u.synergy_tier("ELECTRIC")
	if electric <= 0 or hit.get("triple", false):
		return
	var attacks := int(u.counters.get("attacks", 0))
	if attacks <= 0 or attacks % (4 if electric == 1 else 3) != 0:
		return
	var t: BattleUnit = hit.get("target")
	sim.emit({"type": "effect", "unit": u, "text": "Triple attack!", "color": Color(1.0, 0.95, 0.4)})
	if t != null and t.alive: # Hunger Switch: Morpeko paralyses 2 s, Hangry Morpeko wounds 4 s
		if u.pkm == "MORPEKO":
			sim.add_status(t, "paralysis", 2000.0, u)
		elif u.pkm == "MORPEKO_HANGRY":
			sim.add_status(t, "wound", 4000.0, u)
	for _i in 2:
		if u.passive == "DRUMMER":
			PassiveEffects.drum_pp(sim, u)
		elif t != null and t.alive:
			sim.attack_hit(u, t, true)
	if electric >= 3 and t != null and t.alive:
		t.drain_pp(10.0)
		if u.owned != null:
			sim.rewards.cell_battery = int(sim.rewards.get("cell_battery", 0)) + 5 # chargeCellBattery


## Statuses inflicted by an attack that landed (pokemon-entity.ts onHit).
static func on_hit(sim: BattleSim, u: BattleUnit, t: BattleUnit) -> void:
	if not t.alive:
		return
	if u.synergy_tier("ICE") > 0 and u.types.has("ICE") and sim.chance(0.2, u):
		sim.add_status(t, "freeze", 2000.0, u)
	if u.synergy_tier("FIRE") > 0 and sim.chance(0.3, u):
		sim.add_status(t, "burn", 3000.0, u)
	if u.synergy_tier("MONSTER") > 0 and sim.chance(0.3, u):
		sim.add_status(t, "flinch", 3000.0, u)
	if u.synergy_tier("GHOST") > 0 and sim.chance(0.15, u):
		sim.add_status(t, "silence", 2000.0, u)
	var poison := u.synergy_tier("POISON")
	if poison > 0 and sim.chance([0.3, 0.6, 1.0][mini(poison, 3) - 1], u):
		sim.add_status(t, "poison", 4000.0, u)
	if u.synergy_tier("WILD") > 0 and sim.chance(0.25, u):
		sim.add_status(t, "wound", 3000.0, u)


## Pounce Wand: a Fairy Pokémon hit in melee (crit or 10%) deals 30% of the hit as
## SPECIAL to the enemies around it (250 ms cooldown).
static func on_attack_received(sim: BattleSim, t: BattleUnit, attacker: BattleUnit, hit: Dictionary) -> void:
	if t.synergy_tier("FAIRY") <= 0 or not _wands(sim, t).has("POUNCE_WAND") or not t.alive:
		return
	if sim.time_ms < float(t.counters.get("pounce_ready", 0.0)):
		return
	if not (hit.get("crit", false) or sim.chance(0.1, t)):
		return
	t.counters.pounce_ready = sim.time_ms + 250.0
	if BattleBoard.distance_c(t.cell, attacker.cell) > 1:
		return
	var damage := maxf(roundf(0.3 * float(hit.get("total", 0.0))), 1.0)
	for c in BattleBoard.adjacent_cells(t.cell):
		var e := sim.board.get_unit(c)
		if e != null and e.alive and e.team != t.team and not e.has_item("PROTECTIVE_PADS"):
			sim.deal_damage(e, damage, BattleUnit.DamageKind.SPECIAL, t, false, true)


## Crit chance added to an attack: Long Wand, +1% per cell for ranged Fairy.
static func crit_chance_bonus(sim: BattleSim, u: BattleUnit, t: BattleUnit) -> float:
	if u.types.has("FAIRY") and u.attack_range > 1 and _wands(sim, u).has("LONG_WAND"):
		return 0.01 * BattleBoard.distance_m(u.cell, t.cell)
	return 0.0


## Share of a crit bonus that goes through: Rocky Helmet 0, Rock -30 / 50 / 70%.
static func crit_reduction(t: BattleUnit) -> float:
	if t.has_item("ROCKY_HELMET"):
		return 0.0
	var rock := t.synergy_tier("ROCK")
	return maxf(0.0, 1.0 - _at(ROCK_CRIT_REDUCTION, rock)) if rock > 0 else 1.0


## Steel: part of the attack dealt as TRUE.
static func steel_true_part(u: BattleUnit) -> float:
	var steel := u.synergy_tier("STEEL")
	return _at(STEEL_TRUE_PART, steel) if steel > 0 else 0.0
#endregion


#region damage
## Fighting: flat damage blocked on every non-TRUE hit (counts toward the throw).
static func blocked_damage(t: BattleUnit) -> float:
	var fighting := t.synergy_tier("FIGHTING")
	if fighting <= 0:
		return 0.0
	t.counters.fighting_blocks = int(t.counters.get("fighting_blocks", 0)) + 1
	return _at(FIGHTING_BLOCK, fighting)


## Fossil: the first time it would fall to 30% HP, gains 40 / 70 / 100% max HP as
## shield (which takes at most half of this hit) and as much of its BASE ATK.
## Returns {residual, taken} for the rest of the hit.
static func fossil_awaken(sim: BattleSim, t: BattleUnit, residual: float) -> Dictionary:
	var fossil := t.synergy_tier("FOSSIL")
	if fossil <= 0 or t.hp - residual > FOSSIL_HP_RATIO * t.max_hp:
		return {"residual": residual, "taken": 0.0}
	t.synergy.erase("FOSSIL")
	var factor := _at(FOSSIL_FACTOR, fossil)
	sim.add_shield(t, roundf(t.max_hp * factor))
	var on_shield := minf(0.5 * t.shield, residual)
	t.shield -= on_shield
	t.add_stat("atk", t.base_atk * factor)
	t.cooldown = roundf(500.0 / (0.4 + t.speed * 0.007))
	sim.emit({"type": "effect", "unit": t, "text": "Awakened!", "color": Color(0.85, 0.8, 0.45)})
	return {"residual": 0.0, "taken": on_shield}


## Human: heals 25 / 35 / 50% of the damage dealt (not from retaliation, nor on itself).
static func on_damage_dealt(sim: BattleSim, u: BattleUnit, t: BattleUnit, taken: float, retaliation: bool) -> void:
	var human := u.synergy_tier("HUMAN")
	if human <= 0 or retaliation or t == u:
		return
	sim.heal(u, ceilf(_at(HUMAN_LIFESTEAL, human) * taken))


static func on_damage_received(sim: BattleSim, t: BattleUnit, attacker: BattleUnit, _taken: float, retaliation: bool) -> void:
	if not t.alive:
		return
	_flying_protection(sim, t)
	_fighting_throw(sim, t, retaliation)
	if t.synergy_tier("WILD") >= 4 and not t.counters.get("berserk", false) and t.hp < 0.3 * t.max_hp:
		t.counters.berserk = true
		var atk_bonus := ceilf(WILD_ATK_RATIO * t.base_atk)
		t.add_stat("speed", 40.0)
		t.add_stat("atk", atk_bonus)
		sim.add_shield(t, WILD_BERSERK_SHIELD)
		sim.emit({"type": "effect", "unit": t, "text": "Berserk!", "color": Color(0.9, 0.3, 0.25)})
		sim.schedule(3000.0, t, func() -> void:
			t.add_stat("speed", -40.0)
			t.add_stat("atk", -atk_bonus))


## Flying: flies away under 20% HP (tier 3+: under 50% and again under 20%), with
## 2 s of PROTECT from tier 2; tier 4 skydives on an enemy (150% ATK as PHYSICAL).
static func _flying_protection(sim: BattleSim, t: BattleUnit) -> void:
	var flying := t.synergy_tier("FLYING")
	var left := int(t.counters.get("flying_protection", 0))
	if flying <= 0 or left <= 0 or not t.can_move() or t.has_status("paralysis"):
		return
	var ratio := t.hp_ratio()
	if not ((left == 1 and ratio < 0.2) or (flying >= 3 and left == 2 and ratio < 0.5)):
		return
	t.counters.flying_protection = left - 1
	fly_away(sim, t, flying >= 2, flying >= 4)


static func fly_away(sim: BattleSim, t: BattleUnit, protect: bool, skydive: bool) -> void:
	var from := t.cell
	var dest: Variant = AbilityRunner.fly_away_cell(sim, t)
	if protect:
		sim.add_status(t, "protect", FLY_AWAY_PROTECT_MS)
	if dest == null:
		return
	PassiveEffects.on_fly_away(sim, t, from, dest)
	sim.move_unit(t, dest, 400.0, "dash")
	for e in sim.units:
		if e.alive and e.target == t:
			e.target = null
	if not skydive:
		return
	var target := sim.nearest_enemy_manhattan(t)
	if target == null:
		return
	t.add_status("skydiving", 1000.0)
	t.cooldown = 1500.0
	t.target = target
	sim.schedule(1000.0, t, func() -> void:
		if target.alive:
			var crit := sim.chance(t.crit_chance / 100.0, t)
			var damage := 1.5 * t.atk * (1.0 + t.ap / 100.0) * (sim.crit_multiplier(t, target) if crit else 1.0)
			var cells: Array[Vector2i] = [target.cell]
			sim.emit({"type": "area", "unit": t, "cells": cells, "affects": "enemies"})
			sim.deal_damage(target, damage, BattleUnit.DamageKind.PHYSICAL, t, crit))


## Fighting: every 10 blocked hits, throws its melee target far away, removing its
## shield and dealing its ATK as PHYSICAL.
static func _fighting_throw(sim: BattleSim, t: BattleUnit, retaliation: bool) -> void:
	var blocks := int(t.counters.get("fighting_blocks", 0))
	if retaliation or blocks <= 0 or blocks % FIGHTING_THROW_EVERY != 0 or t.counters.get("thrown_at", -1) == blocks:
		return
	var foe := t.target
	if foe == null or not foe.alive or foe.attack_range > 1 or BattleBoard.distance_c(t.cell, foe.cell) != 1:
		return
	t.counters.thrown_at = blocks
	var dest: Variant = sim.safe_place_away(foe.cell, foe.team)
	if dest == null or foe.has_item("PROTECTIVE_PADS") or foe.has_item("HEAVY_DUTY_BOOTS"):
		return
	foe.shield = 0.0
	sim.deal_damage(foe, t.atk, BattleUnit.DamageKind.PHYSICAL, t, false, true)
	if foe.alive:
		sim.move_unit(foe, dest, 300.0, "knockback")
		sim.emit({"type": "effect", "unit": t, "text": "Throw!", "color": Color(1.0, 0.55, 0.3)})


## Aquatic: negative statuses last 30 / 50 / 70% shorter (whole team).
static func status_duration_factor(t: BattleUnit) -> float:
	var aquatic := t.synergy_tier("AQUATIC")
	return _at(AQUATIC_REDUCTION, aquatic) if aquatic > 0 else 1.0


## Aquatic: BURN and POISONED damage reduced the same way.
static func status_damage_factor(t: BattleUnit) -> float:
	return status_duration_factor(t)
#endregion


#region kills, deaths, casts
## Monster: grows on every KO (ATK, AP and part of the victim's max HP).
static func on_kill(sim: BattleSim, attacker: BattleUnit, target: BattleUnit) -> void:
	var monster := attacker.synergy_tier("MONSTER")
	if monster <= 0:
		return
	attacker.add_stat("atk", _value("monsterAtk", monster))
	attacker.add_stat("ap", _value("monsterAp", monster))
	attacker.add_stat("maxHP", _value("monsterHpFactor", monster) * target.max_hp)
	sim.emit({"type": "effect", "unit": attacker, "text": "Grow!", "color": Color(0.35, 0.8, 0.45)})
	if attacker.has_item("BERSERK_GENE"):
		sim.add_status(attacker, "confusion", 1000.0, attacker)


## Field: when a Field Pokémon faints, the other Field allies heal and gain SPEED.
## A cursed Pokémon passes its curse to another one of its team.
static func on_death(sim: BattleSim, u: BattleUnit) -> void:
	var field := u.synergy_tier("FIELD")
	if field > 0:
		for ally in sim.allies_of(u):
			if ally.types.has("FIELD"):
				sim.heal(ally, _value("fieldHeal", field))
				ally.add_stat("speed", _value("fieldSpeed", field))
	for kind in u.curses:
		apply_curse(sim, kind, u.team)


## Sound: every cast of a Sound Pokémon wakes up its allies; with the synergy they
## also gain ATK / SPEED / PP.
## A Chimecho next to the caster gets 3 PP; Mega Launcher (Clauncher line) triples the buffs;
## a Comatose ally does not wake up but gains 5 AP.
static func on_cast(sim: BattleSim, u: BattleUnit) -> void:
	if not u.types.has("SOUND"):
		return
	var sound := u.synergy_tier("SOUND")
	var scale := 3.0 if u.passive == "MEGA_LAUNCHER" else 1.0
	var atk := _value("soundAtk", sound) * scale
	var speed := _value("soundSpeed", sound) * scale
	var pp := _value("soundPp", sound) * scale
	for cell in BattleBoard.adjacent_cells(u.cell):
		var chimecho := sim.board.get_unit(cell)
		if chimecho != null and chimecho.alive and chimecho.passive == "CHIMECHO":
			chimecho.add_pp(3.0)
			break
	for ally in sim.allies_of(u):
		if ally.passive == "COMATOSE" and ally.has_status("sleep"):
			ally.add_stat("ap", 5.0)
		else:
			ally.statuses.erase("sleep")
		if atk > 0.0:
			ally.add_stat("atk", atk)
		if speed > 0.0:
			ally.add_stat("speed", speed)
		if pp > 0.0:
			ally.add_pp(pp)
	if sound > 0:
		sim.emit({"type": "effect", "unit": u, "text": "Echo!", "color": Color(1.0, 0.55, 0.7)})
#endregion


#region fairy wands
## Wands of the unit's team (PlayerState.active_wands()).
static func _wands(sim: BattleSim, u: BattleUnit) -> Array:
	return sim.team_info[u.team].get("wands", [])


## applyWandEffects: each wand adds 20% ATK as SPECIAL to a Fairy attack that landed,
## plus its own effect. Returns {taken, death}.
static func apply_wands(sim: BattleSim, u: BattleUnit, target: BattleUnit, crit: bool) -> Dictionary:
	var wands := _wands(sim, u)
	if wands.is_empty():
		return {"taken": 0.0, "death": false}
	var factor := 0.0
	for wand in wands:
		factor += 0.2
		match wand:
			"CONFUSE_WAND":
				if sim.chance(0.05, u):
					sim.add_status(target, "confusion", 2000.0, u)
					target.add_stat("speDef", -3.0)
			"PETRIFY_WAND":
				if sim.chance(0.05, u):
					sim.add_status(target, "locked", 2000.0, u)
					target.add_stat("def", -3.0)
			"SLOW_WAND":
				if sim.chance(0.05, u):
					sim.add_status(target, "paralysis", 2000.0, u)
					target.add_stat("speed", -10.0)
			"SLUMBER_WAND":
				if sim.chance(0.05, u):
					sim.add_status(target, "sleep", 2000.0, u)
					target.add_stat("atk", -3.0)
			"BLAST_WAND":
				if crit:
					factor += 0.3
			"SPIRIT_WAND":
				factor += u.cast_count * 0.05
				if sim.chance(0.2, u):
					u.add_pp(5.0)
			"GUIDING_WAND":
				if sim.chance(0.5, u):
					for c in BattleBoard.adjacent_cells(target.cell):
						var e := sim.board.get_unit(c)
						if e != null and e.alive and e.team != u.team and e.hp_ratio() < target.hp_ratio():
							target = e
			"SURROUND_WAND":
				factor += 0.05 * _adjacent_enemies(sim, u).size()
			"TWO_EDGED_WAND":
				factor += 0.3
	var special := factor * u.atk
	var result := sim.deal_damage(target, special, BattleUnit.DamageKind.SPECIAL, u)
	var taken: float = result.taken
	var death: bool = result.death
	for wand in wands:
		match wand:
			"HP_SWAP_WAND":
				if sim.chance(0.2, u) and taken >= 1.0:
					target.add_stat("maxHP", -floorf(taken))
					u.add_stat("maxHP", floorf(taken))
			"SURROUND_WAND":
				if sim.chance(0.1, u):
					for e in _adjacent_enemies(sim, u):
						if e != target:
							var r := sim.deal_damage(e, special, BattleUnit.DamageKind.SPECIAL, u)
							taken += r.taken
							death = death or r.death
			"TWO_EDGED_WAND":
				if not sim.chance(0.8, u) and not u.has_item("PROTECTIVE_PADS"):
					sim.deal_damage(u, special, BattleUnit.DamageKind.SPECIAL, u)
			"WARP_WAND":
				if sim.chance(0.05, u) and target.alive and not target.has_item("HEAVY_DUTY_BOOTS"):
					var dest: Variant = sim.teleport_cell(target.cell, target.team)
					if dest != null:
						sim.move_unit(target, dest, 250.0, "dash")
			"SWITCHER_WAND":
				if sim.chance(0.05, u) and target.alive and not target.has_item("HEAVY_DUTY_BOOTS"):
					var far := sim.farthest_enemy(u)
					if far != null and far != target and not far.has_item("HEAVY_DUTY_BOOTS"):
						sim.swap_cells(target.cell, far.cell)
			"WHIRLWIND_WAND":
				if sim.chance(0.05, u):
					for c in BattleBoard.line_cells(u.cell, target.cell):
						var e := sim.board.get_unit(c)
						if e != null and e.alive and e.team != u.team and not e.has_item("HEAVY_DUTY_BOOTS"):
							var dest: Variant = sim.safe_place_away(e.cell, e.team, 2)
							if dest != null:
								sim.move_unit(e, dest, 300.0, "knockback")
			"TUNNEL_WAND":
				if sim.chance(0.05, u):
					for c in BattleBoard.line_cells(u.cell, target.cell):
						var e := sim.board.get_unit(c)
						if e != null and e.alive and e.team != u.team and e != target:
							var r := sim.deal_damage(e, special, BattleUnit.DamageKind.SPECIAL, u)
							taken += r.taken
							death = death or r.death
	return {"taken": taken, "death": death}


static func _adjacent_enemies(sim: BattleSim, u: BattleUnit) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for c in BattleBoard.adjacent_cells(u.cell):
		var e := sim.board.get_unit(c)
		if e != null and e.alive and e.team != u.team:
			out.append(e)
	return out
#endregion
