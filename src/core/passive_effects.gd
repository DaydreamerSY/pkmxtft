class_name PassiveEffects
extends RefCounted

## Passives of the Pokémon during a fight: port of app/core/effects/passives.ts and
## the passive checks of pokemon-entity.ts, status.ts, moving-state.ts and some
## abilities (King Shield, Transe). Passives acting between stages (Fur Coat, Pillar,
## divergent evolutions, weather forms, Milcery's flavors...) are in PlayerState /
## EvolutionRules, weather passives in Weather.
##   GEARS        allies gain 1 SPEED every 3 / 2 / 1 s while it stands
##   PICKUP       starts the fight with a random item when holding none
##   SLOW_START   -30 SPEED; +30 SPEED and +10 ATK after its first cast
##   AEGISLASH    King's Shield swaps Shield / Blade forme (+10 ATK, -5 DEF / SPE_DEF)
##   DARMANITAN   under 30% HP, jumps to safety and turns into Zen mode (Transe turns it back)
##   DARMANITAN_ZEN  attacks deal SPECIAL and heal for the damage dealt
##   MITOSIS      splits into 2 copies of its previous stage when KO'd
##   SYNCHRO      every 3 s, sends its BURN / POISONED / WOUND / SILENCE back to their author
##   WELL_BAKED   no BURN damage, +20 DEF while burning
##   GALE_WINGS   leaves EMBER on the cells it flies over
##   DRUMMER      with allies and no enemy in range, drums: +2 / 3 / 5 PP to adjacent allies
##   BEAST_BOOST_ATK / _AP, SOUL_HEART, GRIM_NEIGH, CHILLING_NEIGH  stats on every KO
##   ILLUSION     looks like the ally on its left (Bitter Malice breaks the disguise)
##   ACCELERATION +15 SPEED on every move (Spin Out spends the stacks)
##   trees        STONJOURNER, WOBBUFFET, SUDOWOODO (+1 / 2 ATK a second) stand still until
##                their PP is full (BattleSim._update_unit)
##   on spawn     COMATOSE (always asleep but acts, immune to BURN / POISON / FREEZE / PARALYSIS),
##                EMERGENCY_EXIT (full PP), SPOT_PANDA (no CONFUSION), AQUA_VEIL (RAIN: Rune Protect
##                60 s), SPECIAL_ATTACK, WATER_BUBBLE (no BURN), DRY_SKIN (weather), FALINKS (troopers
##                of the bench), MEGA_SABLEYE, GHOLDENGO (Rune Protect)
##   fight start  COMFEY (becomes the item of an ally), MANAPHY (Aqua Egg: Phione), STONJOURNER (+50
##                AP around it), SKARMORY (10 spikes), BAD_LUCK, TADBULB, FINIZEN, EISCUE_NOICE,
##                WALL_OF_STONE, LUVDISC, GOOD_LUCK (Jirachi), VICTINI, CONVERSION (copies the
##                opponents' best synergy: none against a wild wave)
##   on attack    DURANT (TRUE per Bug ally), METEOR (Minior kernels splash)
##   on hit       BEADS_OF_RUIN, BERRY_EATER, PSYDUCK (target), MINIOR, DREAM_CATCHER
##   on damage    QWILFISH, MIMIKYU, GLIMMORA, TADBULB, PINCURCHIN, STAMINA, DARMANITAN...
##   on KO        KUBFU, GUZZLORD, POIPOLE / NAGANADEL, BASCULIN_WHITE, MOXIE (any ally's KO),
##                PYUKUMUKU, PRIMEAPE, LAST_RESPECTS, FINIZEN (allies KO)
##   on cast      WATER_SPRING, CHINGLING, DUNSPARCE, HISUIAN_QWILFISH, BASCULIN_RED_BLUE
##   statuses     GUTS, TOXIC_BOOST, PSYDUCK, EISCUE_NOICE, GLISCOR (BattleSim), WONDER_GUARD
##                (BattleSim), MELMETAL (BattleUnit: SPEED buffs give half as ATK)
##   regional lines: WATER_SPRING (+5 PP when an enemy casts), SURGE_SURFER (+30 SPEED in an
##     Electric / Psychic field), VIGOROTH (no SLEEP), SLAKING (RAGE 3 s on waking up),
##     STEELY_SPIRIT, HISUIAN_TYPHLOSION (+20% damage to BURN / SILENCE targets, BattleSim),
##     GALARIAN_DARMANITAN (Zen: a burning tree), CORSOLA / HISUIAN_QWILFISH (evolve by KO /
##     casts), Tapus' terrains (GRASSY / MISTY / ELECTRIC / PSYCHIC_TERRAIN)
## PROTEAN (Arceus) is in Synergies, PRIMAL (Kyogre / Groudon / Rayquaza + orb) in PlayerState.

const GEARS_INTERVAL := [3000.0, 2000.0, 1000.0]
const SYNCHRO_MS := 3000.0
const DRUM_PP := [2.0, 3.0, 5.0]
const ZEN_HP_RATIO := 0.3
const MAX_BERGMITES := 4 ## MaxTroopersPerPkm (Avalugg, Hisuian Avalugg)
## Ogerpon's masks -> the unmasked form of their type (the masked one adds "_MASK")
const OGERPON_MASKS := {"TEAL_MASK": "OGERPON_TEAL", "WELLSPRING_MASK": "OGERPON_WELLSPRING",
	"HEARTHFLAME_MASK": "OGERPON_HEARTHFLAME", "CORNERSTONE_MASK": "OGERPON_CORNERSTONE"}
## Tapus' terrains: passive -> [type of the allies, field given]
const TERRAINS := {"GRASSY_TERRAIN": ["GRASS", "grass_field"], "MISTY_TERRAIN": ["FAIRY", "fairy_field"],
	"ELECTRIC_TERRAIN": ["ELECTRIC", "electric_field"], "PSYCHIC_TERRAIN": ["PSYCHIC", "psychic_field"]}
## treeEffect: they stand still until their PP is full.
const TREES := ["STONJOURNER", "WOBBUFFET", "SUDOWOODO", "GALARIAN_DARMANITAN_ZEN"]
## OnKillEffect stat gains: passive -> [[stat, value]...]
const KILL_BUFFS := {"BEAST_BOOST_ATK": [["atk", 5.0]], "BEAST_BOOST_AP": [["ap", 10.0]],
	"SOUL_HEART": [["pp", 10.0], ["ap", 10.0]], "GRIM_NEIGH": [["ap", 30.0]], "CHILLING_NEIGH": [["atk", 5.0]]}
const MINIOR_KERNELS := ["MINIOR_KERNEL_BLUE", "MINIOR_KERNEL_RED", "MINIOR_KERNEL_ORANGE", "MINIOR_KERNEL_GREEN"]
const KUBFU_SPEED := 3.0 ## per physical KO (KubfuOnKillEffect)
const KUBFU_AP := 5.0 ## per other KO
const KUBFU_MAX := 10 ## buffs of each kind; the 10th gives a scroll
const KUBFU_BASE_SPEED := 50.0
const ZYGARDE_MAX_CELLS := 95
const ZYGARDE_DELAY := 1800.0
const FINIZEN_KO := 5
const TADBULB_COOLDOWN := 3000.0
const STAMINA_HITS := 10
const STAMINA_SHIELD := 20.0
const SKARMORY_SPIKES := 10
const WALL_OF_STONE_SHIELD := 50.0


static func on_spawn(sim: BattleSim, u: BattleUnit) -> void:
	if TREES.has(u.passive):
		u.effects.tree = true
	match u.passive:
		"SLOW_START":
			u.add_stat("speed", -30.0)
		"PICKUP":
			if u.items.is_empty():
				var options := GameData.full_items.filter(func(i: String) -> bool: return i != "WONDER_BOX")
				if not options.is_empty():
					u.equip([options[sim.rng.randi() % options.size()]])
		"VIGOROTH":
			u.statuses.erase("sleep")
			u.effects.immune_sleep = true
		"COMATOSE": # asleep for good, but acts (BattleUnit.can_act)
			for s in ["burn", "poison", "freeze", "paralysis"]:
				u.statuses.erase(s)
				u.effects["immune_" + s] = true
			u.poison_stacks = 0
			u.statuses.sleep = 1e9
		"EMERGENCY_EXIT":
			u.add_pp(u.max_pp, true)
		"SPOT_PANDA":
			u.statuses.erase("confusion")
			u.effects.immune_confusion = true
		"AQUA_VEIL":
			if sim.weather == "RAIN":
				sim.add_status(u, "safeguard", 60000.0, u)
		"SPECIAL_ATTACK":
			u.effects.special_attacks = true
		"WATER_BUBBLE":
			u.effects.immune_burn = true
		"DRY_SKIN":
			match sim.weather:
				"RAIN", "DROUGHT":
					u.effects.dry_skin = true
				"SANDSTORM":
					u.add_stat("dodge", 0.25)
				"ZENITH":
					u.add_stat("ap", 50.0)
		"FALINKS":
			_falinks_formation(sim, u)
		"MEGA_SABLEYE":
			sim.add_status(u, "safeguard", 60000.0, u)
		"GHOLDENGO":
			if sim.player != null and u.owned != null and sim.player.gold >= sim.player.max_interest() * 10:
				sim.add_status(u, "safeguard", 60000.0, u)


## FalinksFormationEffect: each Falinks trooper of the bench (not training) gives the brass its
## ATK, its DEF and its max HP as shield; No Retreat counts them.
static func _falinks_formation(sim: BattleSim, u: BattleUnit) -> void:
	if u.owned == null or sim.player == null:
		return
	var n := 0
	for b in sim.player.bench:
		if b == null or b.pkm != "FALINKS_TROOPER" or b == u.owned or sim.player.training_ids.has(b.id):
			continue
		var data: Dictionary = b.data()
		u.add_stat("atk", float(data.get("atk", 1)) + float(b.mods.get("atk", 0.0)))
		u.add_stat("def", float(data.get("def", 1)) + float(b.mods.get("def", 0.0)))
		u.shield += float(data.get("hp", 30)) + float(b.mods.get("maxHP", 0.0))
		n += 1
	u.effects.falinks = n


## Gears: every ally on the board when the fight starts spins with it.
## Illusion (Zorua): keeps the looks it took on the board; Bitter Malice breaks the disguise.
## Terrains (Tapus, simulation.ts): the allies of their type get the matching field.
## Steely Spirit (Perrserker): it and its row neighbours add 10% ATK as TRUE to attacks.
## Then the other OnSimulationStartEffects of passives.ts (see the list at the top).
static func on_fight_start(sim: BattleSim) -> void:
	for u in sim.units:
		if not u.alive:
			continue
		if u.passive == "ILLUSION" and u.owned != null and u.owned.look != "" and u.owned.look != u.pkm:
			u.effects.disguise = u.owned.look # the looks it took on the board (PlayerState._illusion)
			sim.emit({"type": "transform", "unit": u, "pkm": u.owned.look})
		if TERRAINS.has(u.passive):
			var terrain: Array = TERRAINS[u.passive]
			for ally in sim.allies_of(u):
				if ally.types.has(terrain[0]):
					sim.add_status(ally, terrain[1], 1e9, u)
		if u.passive == "AVALUGG" and u.owned != null and sim.player != null: # Bergmites of the bench
			var n: int = sim.player.bench.filter(func(b) -> bool: return b != null and b.pkm == "BERGMITE").size()
			u.counters.bergmites = mini(n, MAX_BERGMITES)
		if u.passive == "STEELY_SPIRIT":
			for dx in [-1, 0, 1]:
				var ally := sim.board.get_unit(u.cell + Vector2i(dx, 0))
				if ally != null and ally.team == u.team:
					ally.effects.steely_spirit = true
	for gear in sim.units:
		if not gear.alive or gear.passive != "GEARS":
			continue
		var interval: float = GEARS_INTERVAL[clampi(gear.stars - 1, 0, 2)]
		for ally in sim.allies_of(gear):
			if not ally.counters.has("gears"):
				ally.counters.gears = []
			ally.counters.gears.append({"gear": gear, "interval": interval, "time": 0.0})
	for u in sim.units.duplicate():
		if not u.alive:
			continue
		match u.passive:
			"CHINGLING": # the units of its team at the start count for its stacks
				if u.owned != null:
					u.effects.chingling_team = sim.alive_units(u.team).map(func(a: BattleUnit) -> int: return a.id)
			"COMFEY":
				_comfey_equip(sim, u)
			"COMMANDER":
				_commander(sim, u)
			"CONVERSION":
				_conversion(sim, u)
			"MANAPHY":
				if u.has_item("AQUA_EGG"):
					AbilityScripts.take_item(u, "AQUA_EGG")
					var cell: Variant = sim.closest_free_cell_near(u.cell, u.team)
					if cell != null:
						AbilityScripts._summon(sim, "PHIONE", u.team, cell)
			"STONJOURNER": # Power Spot: +50 AP to the adjacent allies (100 in the spotlight)
				var bonus := 100.0 if in_spotlight(sim, u) and u.synergy_tier("LIGHT") > 0 else 50.0
				for cell in BattleBoard.adjacent_cells(u.cell):
					var ally := sim.board.get_unit(cell)
					if ally != null and ally.alive and ally.team == u.team:
						ally.add_stat("ap", bonus)
			"SKARMORY":
				sim.schedule(300.0, u, func() -> void: _skarmory_spikes(sim, u))
			"BAD_LUCK":
				for e in sim.enemies_of(u):
					e.add_stat("luck", -20.0)
			"TADBULB":
				if in_spotlight(sim, u):
					_supercharge(sim, u)
			"FINIZEN":
				_finizen_setup(sim, u)
			"EISCUE_NOICE":
				if sim.weather == "SNOW":
					_ice_face(sim, u, true)
			"WALL_OF_STONE":
				for ally in sim.alive_units(u.team):
					if ally.cell.y == u.cell.y and ally.types.has("ROCK"):
						sim.add_shield(ally, WALL_OF_STONE_SHIELD, u)
						sim.add_status(ally, "locked", 60000.0, ally)
						ally.effects.wall_of_stone = true
			"LUVDISC": # the allies on its left and right share their best ATK, DEF, SPE_DEF, AP
				var left := sim.board.get_unit(u.cell + Vector2i(-1, 0))
				var right := sim.board.get_unit(u.cell + Vector2i(1, 0))
				if left != null and right != null:
					for stat in ["atk", "def", "speDef", "ap"]:
						var best := maxf(left.stat(stat), right.stat(stat))
						for lover in [left, right]:
							lover.add_stat(stat, best - lover.stat(stat))
			"GOOD_LUCK": # Jirachi: +20 LUCK to its team
				for ally in sim.alive_units(u.team):
					ally.add_stat("luck", 20.0)
			"VICTINI": # its opponents cannot dodge
				for e in sim.enemies_of(u):
					e.add_stat("dodge", -1.0)


## Is it in the spotlight of its team (Light cell, Shiny Stone; Porygon converted to LIGHT)?
static func in_spotlight(sim: BattleSim, u: BattleUnit) -> bool:
	if u.effects.get("spotlight", false) or u.has_item("SHINY_STONE"):
		return true
	var light: Variant = sim.team_info[u.team].get("light")
	return light != null and u.cell == light and not u.is_spawn


## comfeyEquipOnSimulationStartEffect: Comfey leaves the board and becomes the item of the
## strongest of the nearest allies with a free item slot.
static func _comfey_equip(sim: BattleSim, u: BattleUnit) -> void:
	var holders := sim.alive_units(u.team).filter(func(a: BattleUnit) -> bool:
		return a != u and a.pkm != "COMFEY" and a.items.size() < BattleUnit.MAX_ITEMS and not a.inanimate)
	if holders.is_empty():
		return
	var nearest := 99
	for a in holders:
		nearest = mini(nearest, BattleBoard.distance_c(a.cell, u.cell))
	holders = holders.filter(func(a: BattleUnit) -> bool: return BattleBoard.distance_c(a.cell, u.cell) == nearest)
	var holder: BattleUnit = _strongest(sim, holders)
	sim.remove_unit(u)
	give_comfey(sim, holder)


## The COMFEY item: Comfey's max HP, ATK, DEF and SPE_DEF; its holder also casts Floral Healing.
static func give_comfey(sim: BattleSim, holder: BattleUnit) -> void:
	var data := GameData.get_pokemon("COMFEY")
	holder.items.append("COMFEY")
	holder.add_stat("maxHP", float(data.get("hp", 0)))
	holder.add_stat("atk", float(data.get("atk", 0)))
	holder.add_stat("def", float(data.get("def", 0)))
	holder.add_stat("speDef", float(data.get("speDef", 0)))
	sim.emit({"type": "item", "unit": holder, "item": "COMFEY", "text": GameData.item_name("COMFEY")})


## dropComfey (Comfey item holder KO or resurrecting): Comfey jumps back on one of the closest
## free cells, 2 cells away at most.
static func drop_comfey(sim: BattleSim, holder: BattleUnit) -> void:
	if not holder.has_item("COMFEY"):
		return
	var cell: Variant = sim.nearest_free_cell(holder.cell, 2)
	if cell == null:
		return
	var data := GameData.get_pokemon("COMFEY")
	holder.use_up("COMFEY")
	holder.add_stat("maxHP", -float(data.get("hp", 0)))
	holder.add_stat("atk", -float(data.get("atk", 0)))
	holder.add_stat("def", -float(data.get("def", 0)))
	holder.add_stat("speDef", -float(data.get("speDef", 0)))
	var comfey := BattleUnit.create("COMFEY", holder.team)
	sim.add_unit(comfey, cell)


## commanderPassive: Tatsugiri next to a Dondozo without one jumps into its mouth (an item).
static func _commander(sim: BattleSim, u: BattleUnit) -> void:
	var items := ["TATSUGIRI_CURLY", "TATSUGIRI_DROOPY", "TATSUGIRI_STRETCHY"]
	var item: String = items[0] if u.pkm == "TATSUGIRI_CURLY" else (items[1] if u.pkm == "TATSUGIRI_DROOPY" else items[2])
	for cell in BattleBoard.adjacent_cells(u.cell):
		var d := sim.board.get_unit(cell)
		if d == null or not d.alive or d.pkm != "DONDOZO" or d.team != u.team:
			continue
		if items.any(func(i: String) -> bool: return d.has_item(i)):
			continue
		sim.remove_unit(u)
		d.equip([item])
		sim.emit({"type": "item", "unit": d, "item": item, "text": GameData.item_name(item)})
		return


## conversionEffect (Porygon): gets the best synergy of the opposing team and its effect.
## A wild wave has no synergy in the web game (nothing happens); a wave with active synergies
## (difficulty) gives one.
static func _conversion(sim: BattleSim, u: BattleUnit) -> void:
	if u.is_spawn or u.team != BattleUnit.Team.BLUE:
		return
	var counts: Dictionary = sim.team_info[1 - u.team].get("counts", {})
	var tiers: Dictionary = sim.team_tiers[1 - u.team]
	var best := ""
	for type in counts:
		if best == "" or int(counts[type]) > int(counts[best]):
			best = type
	if best == "" or u.types.has(best):
		return
	u.types.append(best)
	u.synergy[best] = maxi(int(tiers.get(best, 1)), 1)
	sim.emit({"type": "effect", "unit": u, "text": GameData.synergy_name(best), "color": Color(0.6, 0.85, 1.0)})


## skarmorySpikesOnSimulationStartEffect: 10 SPIKES on random cells of the opposing side.
static func _skarmory_spikes(sim: BattleSim, u: BattleUnit) -> void:
	var rows := range(BattleBoard.SIDE_ROWS, BattleBoard.HEIGHT) if u.cell.y < BattleBoard.SIDE_ROWS else range(BattleBoard.SIDE_ROWS)
	var cells: Array = []
	for y in rows:
		for x in BattleBoard.WIDTH:
			cells.append(Vector2i(x, y))
	var picked := AbilityScripts.pick_random(sim, cells, SKARMORY_SPIKES)
	AbilityScripts.board_effect(sim, picked, "SPIKES")
	AbilityScripts.show({"sim": sim, "caster": u}, picked)


## superchargeTadbulb: Electric Field (+20 SPEED, 30 shield) if it had none, then knocks the
## adjacent enemies back for 10 SPECIAL; at most once every 3 s.
static func _supercharge(sim: BattleSim, u: BattleUnit) -> void:
	var last := float(u.counters.get("supercharge_at", -1e9))
	if sim.time_ms - last < TADBULB_COOLDOWN:
		return
	u.counters.supercharge_at = sim.time_ms
	if not u.has_status("electric_field"):
		sim.add_status(u, "electric_field", 1e9, u)
		u.add_stat("speed", 20.0)
		sim.add_shield(u, 30.0, u)
	for cell in BattleBoard.adjacent_cells(u.cell):
		var e := sim.board.get_unit(cell)
		if e == null or not e.alive or e.team == u.team:
			continue
		AbilityScripts.knock_back(sim, e, BattleBoard.orientation(u.cell, e.cell))
		sim.deal_damage(e, 10.0, BattleUnit.DamageKind.SPECIAL, u, false, true)
	sim.emit({"type": "effect", "unit": u, "text": "Supercharge!", "color": Color(1.0, 0.9, 0.3)})


## Finizen: when 5 allies (or all of them) are KO, it becomes Palafin Hero (+18 ATK, +16 SPEED,
## +5 DEF / SPE_DEF, full HP); the Finizen of the board becomes a Palafin for good.
static func _finizen_setup(sim: BattleSim, u: BattleUnit) -> void:
	if u.pkm == "PALAFIN_HERO":
		return
	var allies: Array = []
	for a in sim.alive_units(u.team):
		if a != u:
			allies.append(a.id)
	u.effects.finizen = {"allies": allies, "ko": 0, "hero": false}
	if allies.is_empty():
		_palafin_hero(sim, u, true)


static func _palafin_hero(sim: BattleSim, u: BattleUnit, evolve_owned: bool) -> void:
	var state: Dictionary = u.effects.get("finizen", {})
	state.hero = true
	u.effects.finizen = state
	if GameData.pokemon.has("PALAFIN_HERO"):
		u.effects.disguise = "PALAFIN_HERO"
		sim.emit({"type": "transform", "unit": u, "pkm": "PALAFIN_HERO"})
	u.add_stat("atk", 18.0)
	u.add_stat("speed", 16.0)
	u.add_stat("def", 5.0)
	u.add_stat("speDef", 5.0)
	u.hp = u.max_hp
	if evolve_owned and u.owned != null and u.owned.pkm == "FINIZEN" and GameData.is_available("PALAFIN"):
		u.owned.pkm = "PALAFIN"


## Eiscue: Ice Face (+100 shield at the start in SNOW, +50 when it freezes or is frozen); the
## shield broken, Noice Face again.
static func _ice_face(sim: BattleSim, u: BattleUnit, battle_start: bool) -> void:
	if GameData.pokemon.has("EISCUE"):
		u.effects.disguise = "EISCUE"
		sim.emit({"type": "transform", "unit": u, "pkm": "EISCUE"})
	u.passive = "EISCUE_ICE_FACE"
	sim.add_shield(u, 100.0 if battle_start else 50.0, u)


## Acceleration (Varoom): +15 SPEED on every move (a stack; Spin Out spends them).
static func on_move(u: BattleUnit) -> void:
	if u.passive == "ACCELERATION":
		u.add_stat("speed", 15.0)
		u.counters.acceleration = int(u.counters.get("acceleration", 0)) + 1


static func on_tick(sim: BattleSim, u: BattleUnit, dt: float) -> void:
	for g in u.counters.get("gears", []):
		g.time += dt
		while g.time >= g.interval:
			g.time -= g.interval
			if g.gear.alive:
				u.add_stat("speed", 1.0)
	if u.passive == "SYNCHRO":
		u.counters.synchro_ms = u.counters.get("synchro_ms", 0.0) + dt
		if u.counters.synchro_ms >= SYNCHRO_MS:
			u.counters.synchro_ms -= SYNCHRO_MS
			for status in ["burn", "poison", "wound", "silence"]:
				var origin: BattleUnit = u.status_origin.get(status)
				if u.has_status(status) and origin != null and origin.alive:
					sim.add_status(origin, status, 3000.0, u)
	if u.counters.get("well_baked", false) and not u.has_status("burn"):
		u.counters.erase("well_baked")
		u.add_stat("def", -20.0)
	# Guts (Heracross) / Toxic Boost (Zangoose): the ATK lasts while burning / poisoned
	if u.counters.get("guts", false) and not u.has_status("burn") and not u.has_status("poison"):
		u.counters.erase("guts")
		u.add_stat("atk", -5.0)
	if u.counters.get("toxic_boost", false) and not u.has_status("poison"):
		u.counters.erase("toxic_boost")
		u.add_stat("atk", -10.0)
	if u.passive == "COMATOSE" and not u.has_status("sleep"):
		u.statuses.sleep = 1e9
	if u.passive == "SLAKING": # wakes up in a RAGE for 3 s
		if u.has_status("sleep"):
			u.counters.slaking_asleep = true
		elif u.counters.get("slaking_asleep", false):
			u.counters.erase("slaking_asleep")
			sim.add_status(u, "enraged", 3000.0, u)
	if u.passive == "GALARIAN_DARMANITAN_ZEN" and u.pkm == "GALARIAN_DARMANITAN_ZEN":
		u.counters.zen_ms = float(u.counters.get("zen_ms", 0.0)) + dt
		if u.counters.zen_ms >= 1000.0:
			u.counters.zen_ms -= 1000.0
			_galarian_zen_burn(sim, u)
	# PeriodicEffects of 1 s
	var periodic: bool = u.passive in ["CLEAR_WING", "SUDOWOODO", "ZYGARDE"] or u.effects.get("dry_skin", false)
	if not periodic:
		return
	u.counters.passive_ms = float(u.counters.get("passive_ms", 0.0)) + dt
	if u.counters.passive_ms < 1000.0:
		return
	u.counters.passive_ms -= 1000.0
	match u.passive:
		"CLEAR_WING": # Yanma line: +1 SPEED a second
			u.add_stat("speed", 1.0)
		"SUDOWOODO": # +1 (2 from 2★) ATK a second while still a tree
			if u.effects.get("tree", false):
				u.add_stat("atk", 1.0 if u.stars == 1 else 2.0)
		"ZYGARDE":
			_zygarde_cells(sim, u)
	if u.effects.get("dry_skin", false):
		if sim.weather == "RAIN":
			sim.heal(u, 8.0, u)
		elif sim.weather == "DROUGHT":
			sim.deal_damage(u, 8.0, BattleUnit.DamageKind.TRUE, u, false, false, true, true)


## ZygardeCellsEffect: every second, a cell comes from each fully dug hole of the player's board
## (+1 max HP each, 95 at most); at 95 cells it heals 20% max HP and becomes Zygarde 100%.
static func _zygarde_cells(sim: BattleSim, u: BattleUnit) -> void:
	if sim.player == null or u.owned == null or u.pkm == "ZYGARDE_100":
		return
	var count := int(u.counters.get("zygarde_cells", 0))
	if count >= ZYGARDE_MAX_CELLS:
		return
	var spawned := 0
	for cell in sim.player.ground_holes:
		if int(sim.player.ground_holes[cell]) >= PlayerState.MAX_HOLE_DEPTH and count < ZYGARDE_MAX_CELLS:
			count += 1
			spawned += 1
	u.counters.zygarde_cells = count
	if spawned == 0:
		return
	var complete := count >= ZYGARDE_MAX_CELLS
	sim.schedule(ZYGARDE_DELAY, u, func() -> void:
		if u.pkm == "ZYGARDE_100":
			return
		u.add_stat("maxHP", float(spawned))
		if not complete:
			return
		sim.heal(u, 0.2 * u.max_hp, u)
		if u.pkm == "ZYGARDE_10":
			u.add_stat("def", 2.0)
			u.add_stat("speDef", 2.0)
			u.add_stat("maxHP", 5.0)
			u.add_stat("speed", -12.0)
			u.attack_range = maxi(1, u.attack_range + 1)
		elif u.pkm == "ZYGARDE_50":
			u.add_stat("atk", 5.0)
			u.add_stat("def", 5.0)
			u.add_stat("speDef", 5.0)
			u.add_stat("maxHP", 35.0)
			u.add_stat("speed", -5.0)
			u.attack_range = maxi(1, u.attack_range - 1)
		if GameData.pokemon.has("ZYGARDE_100"):
			u.pkm = "ZYGARDE_100"
			u.data = GameData.get_pokemon("ZYGARDE_100")
			u.passive = "NONE"
			u.ability_id = "CORE_ENFORCER"
			sim.emit({"type": "transform", "unit": u}))


## Galarian Darmanitan Zen, every second: heals 10 (AP), 25% ATK as SPECIAL and BURN 2 s
## to the adjacent enemies.
static func _galarian_zen_burn(sim: BattleSim, u: BattleUnit) -> void:
	sim.heal(u, 10.0 * (1.0 + u.ap / 100.0), u)
	var cells := BattleBoard.adjacent_cells(u.cell)
	sim.emit({"type": "area", "unit": u, "cells": cells, "affects": "enemies"})
	for c in cells:
		var e := sim.board.get_unit(c)
		if e != null and e.alive and e.team != u.team:
			sim.deal_damage(e, roundf(0.25 * u.atk * (1.0 + u.ap / 100.0)), BattleUnit.DamageKind.SPECIAL, u)
			sim.add_status(e, "burn", 2000.0, u)


static func on_status(sim: BattleSim, t: BattleUnit, status: String, fresh: bool, origin: BattleUnit = null) -> void:
	# Surge Surfer (Alolan Raichu): +30 SPEED in an Electric or Psychic field
	if fresh and t.passive == "SURGE_SURFER" and (status == "electric_field" or status == "psychic_field"):
		t.add_stat("speed", 30.0)
	if status == "burn" and fresh and t.passive == "WELL_BAKED" and not t.counters.get("well_baked", false):
		t.counters.well_baked = true
		t.add_stat("def", 20.0)
	# Magmarizer: +30 SPEED when it starts burning (the burn deals no damage)
	if status == "burn" and fresh and t.has_item("MAGMARIZER") and not t.counters.get("magmarizer", false):
		t.counters.magmarizer = true
		t.add_stat("speed", 30.0)
	# Guts: +5 ATK while burning or poisoned; Toxic Boost: +10 ATK while poisoned
	if (status == "burn" or status == "poison") and t.passive == "GUTS" and not t.counters.get("guts", false):
		t.counters.guts = true
		t.add_stat("atk", 5.0)
	if status == "poison" and t.passive == "TOXIC_BOOST" and not t.counters.get("toxic_boost", false):
		t.counters.toxic_boost = true
		t.add_stat("atk", 10.0)
	# Psyduck: confused, +100 AP
	if status == "confusion" and fresh and t.passive == "PSYDUCK":
		t.add_stat("ap", 100.0)
	# Eiscue: freezing or being frozen brings its Ice Face back
	if status == "freeze":
		if t.passive == "EISCUE_NOICE":
			_ice_face(sim, t, false)
		if origin != null and origin.alive and origin.passive == "EISCUE_NOICE":
			_ice_face(sim, origin, false)


static func on_cast(sim: BattleSim, u: BattleUnit) -> void:
	# the COMFEY item: its holder also casts Floral Healing
	if u.has_item("COMFEY"):
		AbilityScripts.run_other({"sim": sim, "caster": u}, "FLORAL_HEALING", u.target)
	# Water Spring (Mudkip line): +5 PP whenever an enemy casts
	for e in sim.enemies_of(u):
		if e.passive == "WATER_SPRING":
			e.add_pp(5.0)
	# Chingling: a stack for each cast of its team (it evolves at 30)
	for a in sim.units:
		if a.team == u.team and a.passive == "CHINGLING" and a.owned != null and a.effects.get("chingling_team", []).has(u.id):
			EvolutionRules.add_stack(sim, a)
	match u.passive:
		"HISUIAN_QWILFISH": # evolves into Overqwil after 20 casts (StackEvolutionRule)
			EvolutionRules.add_stack(sim, u)
		"DUNSPARCE": # a stack for every Dunsparce of its family on the board
			var family := String(u.data.get("family", u.pkm))
			var members: Array = sim.alive_units(u.team).filter(func(a: BattleUnit) -> bool:
				return String(a.data.get("family", a.pkm)) == family)
			for m in members:
				EvolutionRules.add_stack(sim, m)
			if members.all(func(a: BattleUnit) -> bool: return a.owned == null) and sim.player != null:
				EvolutionRules.add_stack_to_owned(sim.player, "DUNSPARCE")
		"BASCULIN_RED_BLUE": # catches up with the best ATK of its Basculin allies
			var best := u.atk
			for a in sim.alive_units(u.team):
				if a.passive == "BASCULIN_RED_BLUE":
					best = maxf(best, a.atk)
			if best > u.atk:
				u.add_stat("atk", best - u.atk)
		"SLOW_START":
			if u.cast_count == 1:
				u.add_stat("speed", 30.0)
				u.add_stat("atk", 10.0)
		"AEGISLASH":
			var to_blade := u.pkm == "AEGISLASH"
			sim.schedule(1500.0, u, func() -> void:
				if to_blade and u.pkm == "AEGISLASH":
					u.add_stat("atk", 10.0)
					u.add_stat("def", -5.0)
					u.add_stat("speDef", -5.0)
					_transform(sim, u, "AEGISLASH_BLADE")
				elif not to_blade and u.pkm == "AEGISLASH_BLADE":
					u.add_stat("atk", -10.0)
					u.add_stat("def", 5.0)
					u.add_stat("speDef", 5.0)
					_transform(sim, u, "AEGISLASH"))


## Every second (pokemon-state.ts update): Illumise and Volbeat gain 5 PP per other one on the board.
static func on_second(sim: BattleSim, u: BattleUnit) -> void:
	if u.passive == "ILLUMISE_VOLBEAT":
		for other in sim.units:
			if other != u and other.alive and other.passive == "ILLUMISE_VOLBEAT":
				u.add_pp(5.0)


## A basic attack done (OnAttackEffect): Durant, Minior's kernels, Shared Vision (Latios / Latias).
static func on_attack(sim: BattleSim, u: BattleUnit, hit: Dictionary) -> void:
	var t: BattleUnit = hit.get("target")
	if t == null:
		return
	if u.passive == "SHARED_VISION": # the allies with Shared Vision attack its target too
		for a in sim.alive_units(u.team):
			if a.passive == "SHARED_VISION" and a.target != u:
				a.target = t
	if u.passive == "DURANT": # +1 TRUE per Bug ally
		var bugs := sim.alive_units(u.team).filter(func(a: BattleUnit) -> bool: return a != u and a.types.has("BUG")).size()
		if bugs > 0 and t.alive:
			sim.deal_damage(t, float(bugs), BattleUnit.DamageKind.TRUE, u)
	if MINIOR_KERNELS.has(u.pkm): # MiniorKernelOnAttackEffect
		var physical := float(hit.get("physical", 0.0))
		var mult := 2.0 if u.stars >= 4 else 1.0
		var ap := 1.0 + u.ap / 100.0
		var around := BattleBoard.adjacent_cells(t.cell)
		var targets: Array[BattleUnit] = []
		for c in around:
			var e := sim.board.get_unit(c)
			if e != null and e.alive and e.team != u.team:
				targets.append(e)
		if t.alive:
			targets.append(t)
		sim.emit({"type": "area", "unit": u, "cells": around, "affects": "enemies"})
		for e in targets:
			match u.pkm:
				"MINIOR_KERNEL_BLUE":
					sim.deal_damage(e, ceilf(physical * ap * mult), BattleUnit.DamageKind.SPECIAL, u, false, false, false)
				"MINIOR_KERNEL_RED":
					sim.deal_damage(e, ceilf(physical * 1.5 * ap * mult), BattleUnit.DamageKind.PHYSICAL, u, false, false, false)
				"MINIOR_KERNEL_ORANGE":
					sim.deal_damage(e, ceilf(physical * 0.5 * ap * mult), BattleUnit.DamageKind.TRUE, u, false, false, false)
		if u.pkm == "MINIOR_KERNEL_GREEN":
			for c in around:
				var a := sim.board.get_unit(c)
				if a != null and a.alive and a.team == u.team:
					sim.heal(a, physical * mult * ap, u)


static func on_damage_received(sim: BattleSim, t: BattleUnit, attacker: BattleUnit = null,
		kind := BattleUnit.DamageKind.SPECIAL, before := 0.0, retaliation := false) -> void:
	t.counters.damage_received = int(t.counters.get("damage_received", 0)) + 1
	if t.passive == "DARMANITAN" and t.alive and t.hp < ZEN_HP_RATIO * t.max_hp and GameData.pokemon.has("DARMANITAN_ZEN"):
		var dest: Variant = sim.teleport_cell(t.cell, t.team)
		if dest != null:
			sim.move_unit(t, dest, 300.0, "dash")
		_darmanitan_zen(sim, t)
	# Galarian Darmanitan: turns Zen, neither moves nor attacks, out of reach 1.5 s
	if t.passive == "GALARIAN_DARMANITAN" and t.alive and t.hp < ZEN_HP_RATIO * t.max_hp \
			and GameData.pokemon.has("GALARIAN_DARMANITAN_ZEN"):
		_galarian_zen(sim, t)
	match t.passive:
		"QWILFISH": # Poison Point: melee physical attackers take 5 TRUE, 30% POISON 3 s
			if kind == BattleUnit.DamageKind.PHYSICAL and not retaliation and attacker != null and attacker.alive \
					and not attacker.has_item("PROTECTIVE_PADS") and BattleBoard.distance_c(t.cell, attacker.cell) == 1:
				sim.deal_damage(attacker, 5.0, BattleUnit.DamageKind.TRUE, t)
				if sim.chance(0.3, t):
					sim.add_status(attacker, "poison", 3000.0, t)
		"MIMIKYU": # under 50% HP its disguise breaks: Busted form (+8 ATK), Protect 1.5 s
			if t.hp < 0.5 * t.max_hp:
				_mimikyu_busted(sim, t)
				sim.add_status(t, "protect", 1500.0, t)
		"GLIMMORA": # under 50% HP, once: TOXIC_SPIKES on the 6 cells in front, 20 SPECIAL there
			if t.hp < 0.5 * t.max_hp:
				t.passive = "NONE"
				_toxic_spikes(sim, t)
		"TADBULB":
			if before >= 50.0 and not retaliation:
				_supercharge(sim, t)
		"PINCURCHIN": # SPECIAL damage gives it an Electric Field, then melee attackers are paralysed 2 s
			if kind == BattleUnit.DamageKind.SPECIAL and not t.has_status("electric_field"):
				sim.add_status(t, "electric_field", 1e9, t)
			if t.has_status("electric_field") and attacker != null and attacker.alive \
					and BattleBoard.distance_c(t.cell, attacker.cell) <= 1:
				sim.add_status(attacker, "paralysis", 2000.0, t)
		"STAMINA": # every 10th hit taken: +20 shield (AP)
			if int(t.counters.damage_received) % STAMINA_HITS == 0:
				sim.add_shield(t, STAMINA_SHIELD * (1.0 + t.ap / 100.0), t)


static func _darmanitan_zen(sim: BattleSim, t: BattleUnit) -> void:
	_transform(sim, t, "DARMANITAN_ZEN")
	t.pp = 0.0
	t.add_stat("atk", -10.0)
	t.add_stat("speed", -20.0)
	t.add_stat("def", 6.0)
	t.add_stat("speDef", 6.0)
	t.attack_range += 4
	t.effects.special_attacks = true
	t.target = null


static func _galarian_zen(sim: BattleSim, t: BattleUnit) -> void:
	_transform(sim, t, "GALARIAN_DARMANITAN_ZEN")
	t.pp = 0.0
	t.effects.tree = true
	sim.add_status(t, "untargetable", 1500.0, t)
	t.add_stat("atk", 6.0)
	t.add_stat("speed", -60.0)
	t.counters.zen_ms = 0.0
	for e in sim.enemies_of(t):
		if e.target == t:
			e.target = null


static func _mimikyu_busted(sim: BattleSim, t: BattleUnit) -> void:
	if GameData.pokemon.has("MIMIKYU_BUSTED"):
		t.pkm = "MIMIKYU_BUSTED"
		t.data = GameData.get_pokemon("MIMIKYU_BUSTED")
		sim.emit({"type": "transform", "unit": t})
	t.passive = "MIMIKYU_BUSTED"
	t.add_stat("atk", 8.0)


## ToxicSpikesEffect (Glimmora): the cells of the 2 rows in front of it at most one cell aside (the web:
## 3 x 2 squares; on hexagons 2 + 3 cells) get TOXIC_SPIKES; the enemies there take 20 SPECIAL.
static func _toxic_spikes(sim: BattleSim, t: BattleUnit) -> void:
	var rows := [1, 2] if t.team == BattleUnit.Team.BLUE else [-2, -1]
	var cells: Array[Vector2i] = []
	for dy in rows:
		for c in BattleBoard.cells_in_row(t.cell.y + dy):
			if absf(BattleBoard.center(c).x - BattleBoard.center(t.cell).x) <= 1.01:
				cells.append(c)
	AbilityScripts.board_effect(sim, cells, "TOXIC_SPIKES")
	sim.emit({"type": "area", "unit": t, "cells": cells, "affects": "enemies"})
	for c in cells:
		var e := sim.board.get_unit(c)
		if e != null and e.alive and e.team != t.team:
			sim.deal_damage(e, 20.0 * (1.0 + t.ap / 100.0), BattleUnit.DamageKind.SPECIAL, t)


## Transe (Darmanitan Zen's ability): back to Standard mode, healing 30% max HP.
static func transe(sim: BattleSim, u: BattleUnit) -> void:
	if u.pkm == "GALARIAN_DARMANITAN_ZEN":
		_transform(sim, u, "GALARIAN_DARMANITAN")
		u.effects.erase("tree")
		u.statuses.erase("untargetable")
		u.add_stat("atk", -6.0)
		u.add_stat("speed", 60.0)
		sim.heal(u, roundf(0.3 * u.max_hp))
		u.cooldown = 0.0
		return
	if u.pkm != "DARMANITAN_ZEN":
		return
	_transform(sim, u, "DARMANITAN")
	u.add_stat("atk", 10.0)
	u.add_stat("speed", 20.0)
	u.add_stat("def", -6.0)
	u.add_stat("speDef", -6.0)
	u.attack_range = maxi(u.attack_range - 4, 1)
	u.effects.erase("special_attacks")
	sim.heal(u, roundf(0.3 * u.max_hp))
	u.cooldown = 0.0


## A KO (OnKillEffect; `kind`: the damage that did it): stat gains of Beast Boost and co, Kubfu,
## Guzzlord, Poipole, Basculin, and Moxie for every ally.
static func on_kill(sim: BattleSim, attacker: BattleUnit, target: BattleUnit, kind := BattleUnit.DamageKind.SPECIAL) -> void:
	if attacker.owned != null:
		attacker.owned.kill_count += 1
	for buff in KILL_BUFFS.get(attacker.passive, []):
		attacker.add_stat(buff[0], buff[1])
	match attacker.passive:
		"KUBFU":
			_kubfu_kill(sim, attacker, kind)
		"GUZZLORD": # with a Chef Hat: +5 AP and +10 max HP for good (x2 with Gourmet 2)
			if attacker.has_item("CHEF_HAT"):
				var doubled: bool = int(sim.team_tiers[attacker.team].get("GOURMET", 0)) >= 2
				var ap := 10.0 if doubled else 5.0
				var hp := 20.0 if doubled else 10.0
				attacker.add_stat("ap", ap)
				attacker.add_stat("maxHP", hp)
				if attacker.owned != null:
					attacker.owned.mods.ap = float(attacker.owned.mods.get("ap", 0.0)) + ap
					attacker.owned.mods.maxHP = float(attacker.owned.mods.get("maxHP", 0.0)) + hp
					attacker.owned.stacks += 2 if doubled else 1
		"POIPOLE", "NAGANADEL": # a stack for the family on the board, +1 ATK for good every 2
			var family := String(attacker.data.get("family", attacker.pkm))
			var members: Array = sim.alive_units(attacker.team).filter(func(a: BattleUnit) -> bool:
				return String(a.data.get("family", a.pkm)) == family)
			for m in members:
				EvolutionRules.add_stack(sim, m)
				if m.owned != null and m.owned.stacks % 2 == 0:
					m.add_stat("atk", 1.0)
					m.owned.mods.atk = float(m.owned.mods.get("atk", 0.0)) + 1.0
			if members.all(func(a: BattleUnit) -> bool: return a.owned == null) and sim.player != null:
				EvolutionRules.add_stack_to_owned(sim.player, "POIPOLE", true)
		"BASCULIN_WHITE":
			if attacker.owned != null:
				EvolutionRules.basculin_count(sim, attacker.owned)
	# Moxie (Scraggy line): every KO of its team gives it the stars of the victim as ATK
	for m in sim.alive_units(attacker.team):
		if m.passive == "MOXIE":
			m.add_stat("atk", float(target.stars))
	# a shiny Magikarp of the first stage gives 10 gold
	if target.pkm == "MAGIKARP" and target.effects.get("shiny", false) and sim.player != null \
			and sim.player.stage == 1 and attacker.team == BattleUnit.Team.BLUE:
		sim.rewards.gold += 10


## KubfuOnKillEffect: a physical KO gives +3 SPEED for good, another one +5 AP for good (10 of
## each at most); the 10th of a kind gives the player its scroll (Waters / Darkness).
static func _kubfu_kill(sim: BattleSim, u: BattleUnit, kind: int) -> void:
	if u.owned == null:
		return
	var mods: Dictionary = u.owned.mods
	var speed_buffs := int(floorf(float(mods.get("speed", 0.0)) / KUBFU_SPEED))
	var ap_buffs := int(floorf(float(mods.get("ap", 0.0)) / KUBFU_AP))
	if kind == BattleUnit.DamageKind.PHYSICAL:
		if speed_buffs < KUBFU_MAX:
			u.add_stat("speed", KUBFU_SPEED)
			mods.speed = float(mods.get("speed", 0.0)) + KUBFU_SPEED
			speed_buffs += 1
		if speed_buffs >= KUBFU_MAX and u.pkm == "KUBFU" and sim.player != null \
				and not sim.player.items.has("SCROLL_OF_WATERS"):
			sim.rewards.items.append("SCROLL_OF_WATERS")
	else:
		if ap_buffs < KUBFU_MAX:
			u.add_stat("ap", KUBFU_AP)
			mods.ap = float(mods.get("ap", 0.0)) + KUBFU_AP
			ap_buffs += 1
		if ap_buffs >= KUBFU_MAX and u.pkm == "KUBFU" and sim.player != null \
				and not sim.player.items.has("SCROLL_OF_DARKNESS"):
			sim.rewards.items.append("SCROLL_OF_DARKNESS")
	u.owned.stacks = mini(maxi(speed_buffs, ap_buffs), KUBFU_MAX)


## A basic attack landed (OnHitEffect and pokemon-entity.ts onHit).
static func on_hit(sim: BattleSim, u: BattleUnit, t: BattleUnit, taken: float) -> void:
	if u.passive == "DARMANITAN_ZEN" and taken > 0.0:
		sim.heal(u, taken)
	if u.passive == "BERRY_EATER": # eats the berries of its target
		for item in t.items.duplicate():
			if GameData.item_in(item, "Berries"):
				t.use_up(item)
				u.items.append(item)
				SynergyItems.eat_berry(sim, u, item)
	if t.passive == "PSYDUCK" and sim.chance(0.1, u):
		sim.add_status(t, "confusion", 3000.0, t)
	if u.pkm == "MINIOR":
		u.add_stat("speed", 5.0 * (1.0 + u.ap / 100.0))
	if u.passive == "DREAM_CATCHER" and t.has_status("sleep"): # the 2 allies closest to the target: 10 shield
		var allies := sim.alive_units(u.team).filter(func(a: BattleUnit) -> bool: return a != u)
		allies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
			return BattleBoard.distance_m(a.cell, t.cell) < BattleBoard.distance_m(b.cell, t.cell))
		for a in allies.slice(0, 2):
			sim.add_shield(a, 10.0 * (1.0 + u.ap / 100.0), u)
	if u.passive == "BEADS_OF_RUIN" and t.alive:
		t.add_stat("speDef", AbilityRunner.adjust_buff(u, t, -1.0))


## Ogerpon (ogerponMaskDropEffect): its shield broken, the mask falls for this fight
## (its stats lost), back to the unmasked form. Eiscue loses its Ice Face, the Rock allies
## of Stakataka's wall are unlocked.
static func on_shield_depleted(sim: BattleSim, t: BattleUnit) -> void:
	if t.passive == "EISCUE_ICE_FACE":
		t.passive = "EISCUE_NOICE"
		t.shield = 0.0
		t.effects.erase("disguise")
		sim.emit({"type": "transform", "unit": t, "pkm": t.pkm})
	if t.effects.get("wall_of_stone", false):
		t.effects.erase("wall_of_stone")
		t.statuses.erase("locked")
	if not t.passive.begins_with("OGERPON_") or not t.pkm.ends_with("_MASK"):
		return
	for mask in OGERPON_MASKS:
		if t.has_item(mask) and OGERPON_MASKS[mask] + "_MASK" == t.pkm:
			AbilityScripts.take_item(t, mask)
			_transform(sim, t, OGERPON_MASKS[mask])
			return


## Mitosis: 2 copies of the previous stage, with half its PP.
## Corsola: once KO, evolves into Galarian Corsola (StateEvolutionRule).
## Terrains: the field of a Tapu leaves its team with it.
## Pyukumuku explodes, Primeape and Basculin count, Last Respects and Finizen react to the KO.
static func on_death(sim: BattleSim, u: BattleUnit) -> void:
	if u.owned != null:
		u.owned.death_count += 1
	if u.passive == "CORSOLA" and u.owned != null and u.owned.pkm == "CORSOLA" \
			and GameData.is_available("GALAR_CORSOLA"):
		u.owned.pkm = "GALAR_CORSOLA"
	if TERRAINS.has(u.passive):
		var field: String = TERRAINS[u.passive][1]
		for ally in sim.allies_of(u):
			if ally.has_status(field):
				ally.statuses.erase(field)
				if ally.passive == "SURGE_SURFER" and (field == "electric_field" or field == "psychic_field"):
					ally.add_stat("speed", -30.0)
	match u.passive:
		"PYUKUMUKU": # 50% of its max HP as SPECIAL to the adjacent enemies
			var cells := BattleBoard.adjacent_cells(u.cell)
			sim.emit({"type": "area", "unit": u, "cells": cells, "affects": "enemies"})
			for c in cells:
				var e := sim.board.get_unit(c)
				if e != null and e.alive and e.team != u.team:
					sim.deal_damage(e, roundf(0.5 * u.max_hp), BattleUnit.DamageKind.SPECIAL, u)
		"PRIMEAPE":
			_primeape_stack(sim, u)
		"BASCULIN_WHITE":
			if u.owned != null:
				EvolutionRules.basculin_count(sim, u.owned)
	# Last Respects (Greavard line): an ally KO next to it fills its PP
	for c in BattleBoard.adjacent_cells(u.cell):
		var a := sim.board.get_unit(c)
		if a != null and a.alive and a.team == u.team and a.passive == "LAST_RESPECTS":
			a.add_pp(a.max_pp - a.pp, true)
	# Finizen counts the KO of the allies it had at the start
	for f in sim.alive_units(u.team):
		var state: Dictionary = f.effects.get("finizen", {})
		if state.is_empty() or state.hero or not state.allies.has(u.id):
			continue
		state.ko = int(state.ko) + 1
		if int(state.ko) >= FINIZEN_KO or int(state.ko) >= state.allies.size():
			_palafin_hero(sim, f, true)
	if u.has_item("COMFEY"):
		drop_comfey(sim, u)
	if u.passive != "MITOSIS":
		return
	var prevolution := GameData.prevolution(u.pkm)
	if prevolution == "":
		return
	for _i in 2:
		var cell: Variant = sim.closest_free_cell_near(u.cell, u.team)
		if cell == null:
			return
		var copy := BattleUnit.create(prevolution, u.team)
		copy.pp = floorf(u.pp / 2.0)
		sim.add_unit(copy, cell)


## Primeape: +1 ATK for good and a stack on each KO (or resurrection); evolves at 10.
static func _primeape_stack(sim: BattleSim, u: BattleUnit) -> void:
	u.add_stat("atk", 1.0)
	if u.owned != null:
		u.owned.mods.atk = float(u.owned.mods.get("atk", 0.0)) + 1.0
	EvolutionRules.add_stack(sim, u)


## KO with a resurrection (OnResurrectingEffect): Primeape counts it, Comfey jumps off.
static func on_resurrecting(sim: BattleSim, u: BattleUnit) -> void:
	if u.passive == "PRIMEAPE":
		_primeape_stack(sim, u)
	if u.has_item("COMFEY"):
		drop_comfey(sim, u)


## Back from a KO (OnResurrectionEffect): the forms and their stats come back.
static func on_resurrect(sim: BattleSim, u: BattleUnit) -> void:
	match u.passive:
		"MIMIKYU", "MIMIKYU_BUSTED":
			if u.pkm == "MIMIKYU_BUSTED":
				u.add_stat("atk", 8.0)
		"DARMANITAN_ZEN":
			if u.pkm == "DARMANITAN_ZEN":
				_darmanitan_zen(sim, u)
		"GALARIAN_DARMANITAN_ZEN":
			if u.pkm == "GALARIAN_DARMANITAN_ZEN":
				_galarian_zen(sim, u)
		"AEGISLASH":
			if u.pkm == "AEGISLASH_BLADE": # keeps the blade forme stats
				u.add_stat("atk", 10.0)
				u.add_stat("def", -5.0)
				u.add_stat("speDef", -5.0)
	var state: Dictionary = u.effects.get("finizen", {})
	if not state.is_empty() and state.hero:
		_palafin_hero(sim, u, false)


## Gale Wings: EMBER on the cells between where it was and where it flies.
static func on_fly_away(sim: BattleSim, u: BattleUnit, from: Vector2i, to: Vector2i) -> void:
	if u.passive != "GALE_WINGS":
		return
	var cells: Array[Vector2i] = []
	for c in BattleBoard.cells_between(from, to):
		if not sim.board_effects.has(c):
			sim.board_effects[c] = {}
		sim.board_effects[c]["EMBER"] = true
		cells.append(c)
	sim.emit({"type": "board_effect", "cells": cells, "effect": "EMBER"})


## Drummer (moving-state.ts): instead of walking when no enemy is in range and it has
## allies, casts if its PP is full, else beats its drum (counts as an attack).
## Returns true when it drummed.
static func drum_beat(sim: BattleSim, u: BattleUnit) -> bool:
	if u.passive != "DRUMMER":
		return false
	var has_allies := sim.allies_of(u).any(func(a: BattleUnit) -> bool:
		return a != u and a.passive != "DRUMMER" and not a.inanimate)
	if not has_allies:
		return false
	u.cooldown = u.attack_cooldown()
	if u.pp >= u.max_pp and u.can_cast():
		var target := sim.nearest_enemy_manhattan(u)
		if target != null:
			AbilityRunner.cast(sim, u, target)
		return true
	u.counters.attacks = int(u.counters.get("attacks", 0)) + 1
	sim.emit({"type": "attack", "unit": u, "target": null, "hit_delay": 0.0})
	drum_pp(sim, u)
	SynergyEffects.on_attack(sim, u, {"target": null, "triple": false})
	if sim.season_effects_on:
		SeasonSynergies.on_attack(sim, u)
	return true


## One drum beat: PP to the adjacent allies (other drummers excepted).
static func drum_pp(sim: BattleSim, u: BattleUnit) -> void:
	var gain: float = DRUM_PP[clampi(u.stars - 1, 0, 2)]
	var cells: Array[Vector2i] = []
	for c in BattleBoard.adjacent_cells(u.cell):
		var ally := sim.board.get_unit(c)
		if ally != null and ally.alive and ally.team == u.team and ally.passive != "DRUMMER":
			ally.add_pp(gain)
			cells.append(c)
	if not cells.is_empty():
		sim.emit({"type": "area", "unit": u, "cells": cells, "affects": "allies"})


## Parting Shot (Pancham line, passives.ts partingShot): the enemy it jumps next to loses 20 AP
## and 20% of its BASE ATK, once.
static func parting_shot(sim: BattleSim, u: BattleUnit, t: BattleUnit) -> void:
	t.add_stat("ap", AbilityRunner.adjust_buff(u, t, -20.0))
	t.add_stat("atk", AbilityRunner.adjust_buff(u, t, -0.2 * t.base_atk))
	t.effects.parting_shot = true
	sim.emit({"type": "area", "unit": u, "cells": [t.cell] as Array[Vector2i], "affects": "enemies"})


## getStrongestUnit: most items, then stars, then rarity (random among the ties).
static func _strongest(sim: BattleSim, list: Array) -> BattleUnit:
	var best := -INF
	var picks: Array = []
	for u in list:
		var s: float = u.unit_score()
		if s > best:
			best = s
			picks = [u]
		elif s == best:
			picks.append(u)
	return picks[sim.rng.randi() % picks.size()] if not picks.is_empty() else null


static func _transform(sim: BattleSim, u: BattleUnit, pkm: String) -> void:
	if not GameData.pokemon.has(pkm):
		return
	u.transform(pkm)
	sim.emit({"type": "transform", "unit": u})
