class_name EndlessWaves
extends RefCounted

## Endless mode waves, port of app/models/endless-stages.ts.
## A wave only depends on the run seed and the stage, like the web version:
##   - the original PvE stages (Magikarp, Gyarados, Mewtwo, legendaries...) are kept
##   - after the last one, a boss comes back every `bossInterval` stages
##   - other stages: a pack of wild Pokémon sharing a type with a random leader
## Boards use enemy coordinates (x 0..6, y 0..3, y = 3 front row; the web: x 0..7, y 1..3);
## to_sim_cell() converts them to the red side of the battle board.
##
## Not in the web game (see docs/DIFFICULTY.md): the numbers come from Difficulty.endless()
## (data/difficulty.json over config.endless), a stage can be built from a wave template
## (WaveTemplates, data/wave_templates.json), and the difficulty adds to every wave its
## stat multipliers, the items of the bosses and whether its synergies are active.

## Rows of a wave board: 3 = front, 2 = middle, 1 = back (the web game's 3 rows), 0 = the 4th row of the
## hex board behind them (only when the other 3 are full).
const ROWS_BY_RANGE := [[3, 2, 1, 0], [3, 2, 1, 0], [2, 3, 1, 0], [1, 2, 3, 0]]
const COLUMNS := [3, 2, 4, 1, 5, 0, 6]
const MAX_UNITS := BattleBoard.WIDTH * BattleBoard.SIDE_ROWS ## cells of the enemy side

static var _cache: Dictionary = {}
static var _cache_revision := -1


## {name, avatar, board: [[pkm, x, y]], statBoosts: {}, items: [[item...] per board entry],
##  reward: {pool: "component" | "full", choice: bool} or null} or {} at stage 0.
## The reward is given after a win: a random item of the pool, or a choice of 3.
## Added by the difficulty: stage, kind ("boss" | "wild" | "template"), statScale
## {stat: factor}, synergies (bool: the wave's synergies are active), synergyBonus,
## bonusSynergies {type: points}; a template wave also has title, template (its id), leader.
static func get_stage(stage: int, run_seed: int) -> Dictionary:
	if stage <= 0:
		return {}
	if _cache_revision != Difficulty.revision:
		_cache.clear()
		_cache_revision = Difficulty.revision
	var key := "%d:%d" % [run_seed, stage]
	if not _cache.has(key):
		_cache[key] = _create_stage(stage, run_seed)
	return _cache[key]


## Forgets the built waves (the templates or the difficulty changed).
static func clear_cache() -> void:
	_cache.clear()


## Name shown for a wave, in the current language: "pkm.GYARADOS" (web key) -> the
## Pokémon name, wild waves -> "Wild <leader> pack", tower_duo... -> text.stage_name,
## template waves -> their own name.
static func display_name(wave: Dictionary) -> String:
	var name := String(wave.get("name", ""))
	if String(wave.get("title", "")) != "":
		return L.t(String(wave.title)) # translated when data/i18n/ui.json knows it
	if name == "wild" or name == "template":
		return L.t("Wild %s pack") % GameData.display_name(String(wave.get("leader", "")))
	if name.begins_with("pkm."):
		return GameData.display_name(name.substr(4))
	var own = GameData.text.get("stage_name", {}).get(name)
	return String(own) if own is String else name.replace("_", " ").capitalize()


## Wave coordinates (x 0..6, y 3 = front .. 0 = the 4th row; web: y 1..3) -> battle board cell on the
## red side (y 4..7). The web boards of the bosses are fitted to 7 columns when loaded
## (GameData.fit_wave_board).
static func to_sim_cell(x: int, y: int) -> Vector2i:
	return Vector2i(x, BattleBoard.HEIGHT - 1 - y)


## An original PvE stage, or one of the bosses coming back after the last of them.
static func is_boss_stage(stage: int) -> bool:
	if GameData.pve_stages.has(stage):
		return true
	var after := stage - _last_original()
	return after > 0 and after % int(Difficulty.endless().bossInterval) == 0


static func _last_original() -> int:
	var originals: Array = GameData.pve_stages.keys()
	originals.sort()
	return int(originals.back())


static func _create_stage(stage: int, run_seed: int) -> Dictionary:
	var endless := Difficulty.endless()
	var boss := is_boss_stage(stage)
	var template := WaveTemplates.pick(stage, run_seed, boss)
	if not template.is_empty():
		var template_rng := RandomNumberGenerator.new()
		template_rng.seed = hash([run_seed, stage, String(template.get("id", ""))])
		var built := WaveTemplates.build(template, stage, template_rng)
		if not built.is_empty():
			return _apply_difficulty(built, stage, "template")
	if GameData.pve_stages.has(stage):
		return _apply_difficulty(_boss_stage(GameData.pve_stages[stage]), stage, "boss")
	if boss:
		var originals: Array = GameData.pve_stages.keys()
		originals.sort()
		var recurring := originals.filter(func(s: int) -> bool: return s >= 19)
		var cycle := (stage - _last_original()) / int(endless.bossInterval) - 1
		var wave := _boss_stage(GameData.pve_stages[recurring[cycle % recurring.size()]])
		wave.statBoosts = _add_boosts(wave.get("statBoosts", {}), scaling_boosts(stage))
		return _apply_difficulty(wave, stage, "boss")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, stage])
	return _apply_difficulty(_wild_wave(stage, rng), stage, "wild")


## An original PvE stage: its bosses hold no item, unless the player met Marowak in
## the town (`marowakItems`, see held_items()) or the difficulty gives them (`bossItems`).
static func _boss_stage(def: Dictionary) -> Dictionary:
	var boss := def.duplicate(true)
	var empty: Array = []
	for _entry in boss.get("board", []):
		empty.append([])
	boss.items = empty
	return boss


## What the difficulty level adds to a wave (see get_stage).
static func _apply_difficulty(wave: Dictionary, stage: int, kind: String) -> Dictionary:
	wave.stage = stage
	wave.kind = kind
	wave.statBoosts = _add_boosts(wave.get("statBoosts", {}), Difficulty.value("statBoosts", {}))
	var scale := Difficulty.enemy_scale(stage)
	var own_scale: Dictionary = wave.get("statScale", {})
	for stat in own_scale:
		scale[stat] = float(scale.get(stat, 1.0)) * float(own_scale[stat])
	wave.statScale = scale
	match String(wave.get("synergyMode", "auto")):
		"on": wave.synergies = true
		"off": wave.synergies = false
		_: wave.synergies = Difficulty.enemy_synergies(stage, kind == "boss")
	wave.synergyBonus = int(Difficulty.value("synergyBonus", 0))
	if kind == "boss" and Difficulty.value("bossItems", false) and wave.has("marowakItems"):
		wave.items = wave.marowakItems.duplicate(true)
	var max_items := clampi(int(Difficulty.value("itemsPerUnit", BattleUnit.MAX_ITEMS)), 0, BattleUnit.MAX_ITEMS)
	for list in wave.get("items", []):
		if list.size() > max_items:
			list.resize(max_items)
	return wave


## Items held by the wave: Marowak makes the bosses hold their items (pokemon-factory.ts).
static func held_items(wave: Dictionary, town_encounter: String) -> Array:
	if town_encounter == "MAROWAK" and wave.has("marowakItems"):
		return wave.marowakItems
	return wave.get("items", [])


#region synergies of a wave
## The wave's Pokémon as Synergies.count() wants them, one per board entry:
## {family, types, passive, stars}; the types include the ones given by held items.
static func team_units(wave: Dictionary, town_encounter := "") -> Array:
	var held := held_items(wave, town_encounter)
	var out: Array = []
	var board: Array = wave.get("board", [])
	for i in board.size():
		var data := GameData.get_pokemon(board[i][0])
		var types: Array = data.get("types", []).duplicate()
		for item in (held[i] if i < held.size() else []):
			var given := GameData.item_synergy(item)
			if given != "" and not types.has(given):
				if given == "DRAGON":
					types.push_front(given)
				else:
					types.append(given)
		out.append({"family": data.get("family", board[i][0]), "types": types,
			"passive": String(data.get("passive", "NONE")), "stars": int(data.get("stars", 1))})
	return out


## {type: points} of the wave when its synergies are active ({} otherwise): one per
## family like the player's, plus the template's `bonusSynergies` and the difficulty's
## `synergyBonus` on every type the wave has. `units` = team_units() (Protean types are
## written there).
static func synergy_counts(wave: Dictionary, town_encounter := "", units: Variant = null) -> Dictionary:
	if not wave.get("synergies", false):
		return {}
	var counts := Synergies.count(units if units is Array else team_units(wave, town_encounter), wave.get("bonusSynergies", {}))
	var bonus := int(wave.get("synergyBonus", 0))
	if bonus != 0:
		for type in counts:
			counts[type] = maxi(int(counts[type]) + bonus, 0)
	return counts


## Fairy wands of a wave: one per FAIRY tier, fixed by the stage (the player picks its own).
static func wands(wave: Dictionary, fairy_tier: int) -> Array:
	var out: Array = []
	var by_tier: Array = GameData.config.get("fairyWands", [])
	for i in mini(fairy_tier, by_tier.size()):
		var options: Array = by_tier[i]
		if not options.is_empty():
			out.append(options[(int(wave.get("stage", 0)) + i) % options.size()])
	return out
#endregion


#region wild waves
## Pokémon in a wild pack at a stage.
static func stage_units(stage: int) -> int:
	var endless := Difficulty.endless()
	return clampi(roundi(float(endless.get("unitsBase", 2)) + stage * float(endless.unitsPerStage)),
		int(endless.minUnits), int(endless.maxUnits))


## Shop odds used by the wild waves of a stage (one per GameData.SHOP_RARITIES).
static func stage_odds(stage: int) -> Array:
	return GameData.shop_odds(10 if stage >= 30 else stage_units(stage))


## Rarities a wild wave of a stage can roll.
static func allowed_rarities(stage: int) -> Array[String]:
	var odds := stage_odds(stage)
	var rarities := GameData.SHOP_RARITIES
	var allowed: Array[String] = []
	for i in rarities.size():
		if float(odds[i]) > 0.0 and not GameData.wild_tier1_by_rarity[rarities[i]].is_empty():
			allowed.append(rarities[i])
	return allowed


static func roll_rarity(stage: int, rng: RandomNumberGenerator) -> String:
	var odds := stage_odds(stage)
	var rarities := GameData.SHOP_RARITIES
	var allowed := allowed_rarities(stage)
	var roll := rng.randf()
	for i in rarities.size():
		roll -= float(odds[i])
		if roll < 0.0 and allowed.has(rarities[i]):
			return rarities[i]
	return allowed.back()


## Star level of a wild Pokémon: 2★ then 3★ come in gradually (twoStarsStages, threeStarsStages).
static func roll_stars(stage: int, rng: RandomNumberGenerator) -> int:
	var endless := Difficulty.endless()
	var three := _progress(stage, endless.threeStarsStages)
	var two := _progress(stage, endless.twoStarsStages)
	return 3 if rng.randf() < three else (2 if rng.randf() < two else 1)


## Puts `unit` on the first free cell of its rows (`rows`: preferred rows, front = 3;
## default: by attack range). Returns false when the side is full.
static func place(board: Array, used: Dictionary, unit: String, rows: Array = []) -> bool:
	if rows.is_empty():
		rows = ROWS_BY_RANGE[mini(int(GameData.get_pokemon(unit).range), 3)]
	for y in rows:
		for x in COLUMNS:
			if not used.has(Vector2i(x, y)):
				used[Vector2i(x, y)] = true
				board.append([unit, x, y])
				return true
	return false


static func _wild_wave(stage: int, rng: RandomNumberGenerator) -> Dictionary:
	var nb_units := stage_units(stage)
	var allowed := allowed_rarities(stage)
	var leader_pool: Array = GameData.wild_tier1_by_rarity[roll_rarity(stage, rng)]
	var leader: String = leader_pool[rng.randi() % leader_pool.size()]
	var leader_types: Array = GameData.get_pokemon(leader).types
	var families := {GameData.get_pokemon(leader).family: true}
	var pack: Array[String] = [leader]
	while pack.size() < nb_units:
		var fits := func(pkm: String) -> bool:
			var data := GameData.get_pokemon(pkm)
			if families.has(data.family):
				return false
			for t in data.types:
				if leader_types.has(t):
					return true
			return false
		var candidates: Array = GameData.wild_tier1_by_rarity[roll_rarity(stage, rng)].filter(fits)
		if candidates.is_empty():
			for r in allowed:
				candidates.append_array(GameData.wild_tier1_by_rarity[r].filter(fits))
		var member: String = candidates[rng.randi() % candidates.size()] if not candidates.is_empty() else leader
		families[GameData.get_pokemon(member).family] = true
		pack.append(member)

	var used := {}
	var board: Array = []
	for pkm in pack:
		place(board, used, GameData.evolve_to(pkm, roll_stars(stage, rng), rng))
	var held: Array = []
	for _entry in board:
		held.append([])
	return {
		"name": "wild",
		"leader": leader,
		"avatar": board[0][0],
		"board": board,
		"statBoosts": scaling_boosts(stage),
		"items": add_stage_items(stage, board, held, rng),
		"reward": stage_reward(stage),
	}


## Reward of a wild wave: an item every `rewardInterval` stages (null otherwise).
static func stage_reward(stage: int) -> Variant:
	var endless := Difficulty.endless()
	if stage % maxi(int(endless.rewardInterval), 1) != 0:
		return null
	return {"pool": "full" if stage >= int(endless.fullItemRewardsStage) else "component", "choice": false}


## Held items of a wild wave, added to `held` (one list per board entry): components from
## `firstItemStage`, full items from `fullItemsStage`, one more every `stagesPerItem`
## stages, most evolved Pokémon first.
static func add_stage_items(stage: int, board: Array, held: Array, rng: RandomNumberGenerator) -> Array:
	var endless := Difficulty.endless()
	if stage < int(endless.firstItemStage) or board.is_empty():
		return held
	var count := mini(board.size() * BattleUnit.MAX_ITEMS,
		1 + (stage - int(endless.firstItemStage)) / maxi(int(endless.stagesPerItem), 1))
	var pool: Array[String] = item_pool("full" if stage >= int(endless.fullItemsStage) else "component")
	var holders: Array = range(board.size())
	holders.sort_custom(func(a: int, b: int) -> bool:
		var sa := int(GameData.get_pokemon(board[a][0]).stars)
		var sb := int(GameData.get_pokemon(board[b][0]).stars)
		return sa > sb or (sa == sb and a < b))
	for i in count:
		add_random_item(held[holders[i % holders.size()]], pool, rng)
	return held


## Adds to `items` a random item of `pool` it does not hold yet (at most 3 items).
static func add_random_item(items: Array, pool: Array, rng: RandomNumberGenerator) -> void:
	var options := pool.filter(func(item: String) -> bool: return not items.has(item))
	if items.size() < BattleUnit.MAX_ITEMS and not options.is_empty():
		items.append(options[rng.randi() % options.size()])


## Items a wave can hold or give: the 8 components, or the full items (no Wonder
## Box: it needs a player to open it).
static func item_pool(kind: String) -> Array[String]:
	var endless := Difficulty.endless()
	var out: Array[String] = []
	out.assign(endless.get("componentPool" if kind == "component" else "fullItemPool", []))
	return out


## "full" once the wild waves hold full items, else "component".
static func stage_item_kind(stage: int) -> String:
	return "full" if stage >= int(Difficulty.endless().fullItemsStage) else "component"
#endregion


static func _progress(stage: int, range_def: Array) -> float:
	var start := float(range_def[0])
	var full := float(range_def[1])
	if full <= start:
		return 1.0 if stage >= start else 0.0
	return clampf((stage - start) / (full - start), 0.0, 1.0)


## Flat stats every wave gains per stage after `scalingStartStage`.
static func scaling_boosts(stage: int) -> Dictionary:
	var endless := Difficulty.endless()
	var n := stage - int(endless.scalingStartStage)
	var out := {}
	if n <= 0:
		return out
	for stat in endless.statBoostsPerStage:
		out[stat] = floorf(float(endless.statBoostsPerStage[stat]) * n)
	return out


static func _add_boosts(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for stat in b:
		if float(b[stat]) != 0.0:
			out[stat] = float(out.get(stat, 0)) + float(b[stat])
	return out
