class_name FightSetup
extends RefCounted

## Builds the fight of a stage (GameRoom initializeFightingPhase + the Simulation
## constructor): the weather of both boards, the forms changed by it, the player's
## synergies and board context, then the units of both teams with their items.
## Not in the web game: the wave gets its own synergies, stat multipliers and items
## from the difficulty level (Difficulty, EndlessWaves).


## Weather of the coming fight: the player's board (bench excluded) and the wave.
static func weather_for(player: PlayerState, wave: Dictionary) -> String:
	var blue: Array = []
	for u in player.board.values():
		blue.append(Weather.voter(u.types(), u.passive()))
	var red: Array = []
	for entry in wave.get("board", []):
		var data := GameData.get_pokemon(entry[0])
		red.append(Weather.voter(data.get("types", []), String(data.get("passive", "NONE"))))
	return Weather.compute([blue, red])


## Board context of a wave with active synergies (BattleSim.team_info, like
## PlayerState.fight_info): the spotlight is on its first Pokémon, its Ground Pokémon
## stand in holes getting deeper with the stage, its Fairy wands are fixed by the stage.
static func enemy_info(wave: Dictionary, units: Array, counts: Dictionary, tiers: Dictionary) -> Dictionary:
	if tiers.is_empty():
		return {}
	var dragon_stars := 0
	for u in units:
		if u.types.has("DRAGON"):
			dragon_stars += int(u.stars)
	var stage := int(wave.get("stage", 0))
	var holes := {}
	if tiers.has("GROUND"):
		var depth := clampi(1 + stage / 6, 1, PlayerState.MAX_HOLE_DEPTH)
		for entry in wave.get("board", []):
			holes[EndlessWaves.to_sim_cell(int(entry[1]), int(entry[2]))] = depth
	var light: Variant = null
	var board: Array = wave.get("board", [])
	if tiers.has("LIGHT") and not board.is_empty():
		light = EndlessWaves.to_sim_cell(int(board[0][1]), int(board[0][2]))
	return {
		"counts": counts,
		"active": Synergies.active_count(counts),
		"dragon_stars": dragon_stars,
		"light": light,
		"holes": holes,
		"wands": EndlessWaves.wands(wave, int(tiers.get("FAIRY", 0))),
		"stage": stage,
	}


## Returns {sim, owned: {OwnedUnit id: BattleUnit}, enemies: [BattleUnit or null per wave entry]}.
static func create(player: PlayerState, wave: Dictionary) -> Dictionary:
	var sim := BattleSim.new()
	sim.weather = weather_for(player, wave)
	player.before_fight(sim.weather)
	var info := player.fight_info()
	# the wave: its synergies when the difficulty (or its template) turns them on
	var red_units := EndlessWaves.team_units(wave, player.town_encounter)
	var red_counts := EndlessWaves.synergy_counts(wave, player.town_encounter, red_units)
	var red_tiers := Synergies.tiers(red_counts)
	sim.setup_teams(Synergies.tiers(info.counts), info, red_tiers, enemy_info(wave, red_units, red_counts, red_tiers))
	var owned := {}
	sim.player = player
	for pot in SynergyItems.pots_unlocked(player):
		sim.flower_pots.append(player.flower_pots[pot])
	sim.player_bench_absorb = func(pkm: String) -> int:
		var n := 0
		for i in player.bench_size:
			var b = player.bench[i]
			if b != null and b.pkm == pkm:
				player.bench[i] = null
				n += 1
		return n
	var protean := Synergies.dynamic_types(player)
	for cell in player.board:
		var o: PlayerState.OwnedUnit = player.board[cell]
		var u := BattleUnit.create(o.pkm, BattleUnit.Team.BLUE)
		u.owned_id = o.id
		u.owned = o
		if o.tm != "": # a TM ability (web: maxPP 100)
			u.ability_id = o.tm
			u.max_pp = Difficulty.max_pp_of(100.0)
		if u.passive == "VESPIQUEN": # its row gives its order (OnChangePositionEffect): front row Defend (range 1),
			# the next one Heal (2), farther back Attack (web: range 3; here the range of its role, marksman)
			var order: Array = [["DEFEND_ORDER", 1], ["HEAL_ORDER", 2], ["ATTACK_ORDER", maxi(3, u.attack_range)]][
				clampi(BattleBoard.SIDE_ROWS - 1 - cell.y, 0, 2)]
			u.ability_id = order[0]
			u.attack_range = order[1]
			u.base_range = order[1]
		if protean.has(o.id):
			u.types = protean[o.id].duplicate()
		for stat in o.mods:
			u.add_stat(stat, float(o.mods[stat]))
			if stat == "maxHP":
				u.hp = u.max_hp
		if o.stacks > 0: # Fur Coat
			u.add_stat("def", 2.0 * o.stacks)
			u.add_stat("speed", -5.0 * o.stacks)
		u.equip(o.items, sim.rng)
		if u.has_item("REPEAT_BALL"): # rerolls and stages of the run
			var v := floorf((player.reroll_count + player.stage) / 2.0)
			u.shield += 2.0 * v
			u.add_stat("speed", v)
		if u.has_item("GOLD_BOTTLE_CAP"): # +1% crit power per gold
			u.add_stat("critPower", player.gold / 100.0)
		# Electric: +2 SPEED per Cell Battery in the item bench; a supercharged one gets its bonus
		if u.types.has("ELECTRIC"):
			u.add_stat("speed", 2.0 * player.items.count("CELL_BATTERY"))
		sim.add_unit(u, cell)
		owned[o.id] = u
		# dishes eaten since the last fight: their effect, then consumed (simulation.ts start)
		if o.supercharged:
			o.supercharged = false
			sim.add_status(u, "electric_field", 1e9)
			u.add_stat("speed", 20.0)
			sim.add_shield(u, 30.0)
		for dish in o.dishes:
			DishEffects.apply(sim, u, o, dish)
		o.dishes.clear()
	var enemies: Array = []
	var boosts: Dictionary = wave.get("statBoosts", {})
	var board: Array = wave.get("board", [])
	var held: Array = EndlessWaves.held_items(wave, player.town_encounter)
	for i in board.size():
		var entry: Array = board[i]
		var cell := EndlessWaves.to_sim_cell(int(entry[1]), int(entry[2]))
		if not sim.board.is_free(cell):
			enemies.append(null)
			continue
		var u := BattleUnit.create(entry[0], BattleUnit.Team.RED)
		if not red_tiers.is_empty() and u.passive.begins_with("PROTEAN"):
			u.types = red_units[i].types.duplicate()
		u.apply_stat_scale(wave.get("statScale", {}))
		u.apply_stat_boosts(boosts)
		var items: Array = (held[i] if i < held.size() else []).duplicate()
		if u.passive == "PASSIMIAN" and not items.has("BALL"): # comes with a Ball (pokemon.ts)
			items.append("BALL")
		u.equip(items, sim.rng)
		if player.shiny_encounter:
			u.effects.shiny = true
		sim.add_unit(u, cell)
		enemies.append(u)
	return {"sim": sim, "owned": owned, "enemies": enemies}
