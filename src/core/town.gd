class_name Town
extends RefCounted

## The town phase between stages, played solo as choices (port of app/core/mini-game.ts,
## shop.ts assignUniquePropositions and the additional picks of game-commands.ts):
##   portal stages (0, 10, 20): pick one of 3 portals (synergy symbols + the region it
##     leads to), then a starter (3 commons, each with a component), a Unique (6) or a
##     Legendary (6) matching the symbols of the portal
##   item carousel stages (4, 12, 17, 22, 27, 34): pick 1 item (components, full items from 20)
##   additional pick stages (5, 8, 11): pick 1 additional Pokémon (with a component)
##   town encounters (TownEncountersByStage): every one of the web game; Celebi makes the wild
##     Pokémon of the next stages shiny (PlayerState.shiny_encounter), Kingambit gives the
##     Leader's Crest (only useful against players)
## A choice is a Dictionary queued by the game: {kind: "portal" | "pokemon" | "items", ...}.

const NB_PORTALS := 3 ## clamp(players + 1, 3, 9) with one player
const EEVEE_RATE := 1.0 / 20.0 ## shop.ts: an Eevee with a Fossil Stone among the first starters
const NB_SYMBOLS_PER_PLAYER := 4
const PORTED_ENCOUNTERS := ["REGIROCK", "XATU", "KANGASKHAN", "SABLEYE", "DUSKULL", "MAROWAK",
	"MEOWTH", "CINCCINO", "ELECTIVIRE", "KECLEON", "LUDICOLO", "CHANSEY", "WOBBUFFET", "CROAGUNK",
	"MUNCHLAX", "CHIMECHO", "SPINDA", "LAPRAS", "MAKUHITA", "MAGNEZONE", "WIGGLYTUFF", "CELEBI", "KINGAMBIT"]
const ENCOUNTER_PRICES := {"KANGASKHAN": 10, "KECLEON": 10, "ELECTIVIRE": 10, "CHANSEY": 7} ## TownEncounterSellPrice
## Items given to the player by an encounter (mini-game.ts onStageStart)
const ENCOUNTER_ITEMS := {"WOBBUFFET": "RECYCLE_TICKET", "CROAGUNK": "EXCHANGE_TICKET",
	"MUNCHLAX": "PICNIC_SET", "CHIMECHO": "SOOTHE_BELL", "LAPRAS": "LAPRAS_PASSPORT", "KINGAMBIT": "LEADERS_CREST"}
## Wigglytuff's mission orders (30 gold each); Red (damage to other players) cannot be done solo
const MISSION_ORDERS := ["MISSION_ORDER_PINK", "MISSION_ORDER_BLUE", "MISSION_ORDER_GREEN", "MISSION_ORDER_GOLD"]
const MISSION_GOLD := 30
const OUTLAW_GOLD := 10 ## OUTLAW_GOLD_REWARD
const SEVEN_TREASURES := {"AQUA_MONICA": "WATER", "FIERY_DRUM": "FIRE", "GRASS_CORNET": "GRASS",
	"ICY_FLUTE": "ICE", "ROCK_HORN": "ROCK", "SKY_MELODICA": "FLYING", "TERRA_CYMBAL": "GROUND"}
const REGIROCK_LIFE := 15
const GIMMIGHOUL_GOLD := 5
const ADDITIONAL_RARITIES := ["UNCOMMON", "RARE", "EPIC"]
const TREASURE_REWARDS := {"gold": 0.2, "mushrooms": 0.1, "sweets": 0.1, "itemComponents": 0.1,
	"componentsAndTickets": 0.1, "craftableItems": 0.15, "goldBow": 0.05}


static func _stages(key: String) -> Array:
	return GameData.config.get(key, []).map(func(s) -> int: return int(s))


static func is_portal_stage(stage: int) -> bool:
	return _stages("portalCarouselStages").has(stage)


static func is_carousel_stage(stage: int) -> bool:
	return _stages("itemCarouselStages").has(stage)


static func is_additional_stage(stage: int) -> bool:
	return _stages("additionalPickStages").has(stage)


## Everything the town brings at the start of `player.stage`: {messages, choices}.
## Encounters happen on carousel stages; Marowak stays until the next one.
static func begin_stage(player: PlayerState, rng: RandomNumberGenerator) -> Dictionary:
	var stage := player.stage
	var messages: Array[String] = []
	var choices: Array[Dictionary] = []
	if is_carousel_stage(stage) or is_portal_stage(stage):
		player.town_encounter = pick_encounter(stage, rng, player.encounters_seen)
		if player.town_encounter != "":
			messages.append(encounter_text(player.town_encounter))
			messages.append_array(_apply_encounter(player))
	if is_portal_stage(stage):
		choices.append({"kind": "portal", "portals": portals(player, stage, rng), "stage": stage})
	if is_carousel_stage(stage):
		choices.append(carousel(player, stage, player.town_encounter, rng))
	if player.town_encounter == "WIGGLYTUFF":
		var orders := MISSION_ORDERS.duplicate()
		_shuffle(orders, rng)
		choices.append({"kind": "items", "source": "mission", "items": orders.slice(0, 3),
			"title": encounter_text("WIGGLYTUFF")})
	if is_additional_stage(stage):
		var pick := additional_pick(stage, rng, player.map, player)
		if not pick.pokemons.is_empty():
			choices.append(pick)
	return {"messages": messages, "choices": choices}


#region encounters
## TownEncountersByStage: each encounter has its weight (1/20 mostly), none otherwise;
## never twice in a run.
static func pick_encounter(stage: int, rng: RandomNumberGenerator, seen: Dictionary) -> String:
	var table: Dictionary = GameData.config.get("townEncounters", {}).get(str(stage), {})
	var roll := rng.randf()
	var chosen := ""
	for encounter in table:
		roll -= float(table[encounter])
		if roll < 0.0:
			chosen = encounter
			break
	if chosen == "" or seen.has(chosen) or not PORTED_ENCOUNTERS.has(chosen):
		return ""
	seen[chosen] = true
	return chosen


static func encounter_text(encounter: String) -> String:
	var text := String(GameData.text.get("town_encounter_description", {}).get(encounter, encounter))
	return text.replace("{{cost}}", str(ENCOUNTER_PRICES.get(encounter, 0)))


static func _apply_encounter(player: PlayerState) -> Array[String]:
	var out: Array[String] = []
	match player.town_encounter:
		"REGIROCK":
			player.life += REGIROCK_LIFE
		"XATU":
			player.add_item("TREASURE_BOX")
		"MAKUHITA": # a Dojo ticket, better later in the run
			player.add_item("GOLD_DOJO_TICKET" if player.stage >= 15
				else ("SILVER_DOJO_TICKET" if player.stage >= 10 else "BRONZE_DOJO_TICKET"))
		"MAGNEZONE": # an outlaw shows up at a stage between 5 and 15
			player.outlaw_stage = player.rng.randi_range(5, 15)
			player.add_item("WANTED_NOTICE")
		_:
			if ENCOUNTER_ITEMS.has(player.town_encounter):
				player.add_item(ENCOUNTER_ITEMS[player.town_encounter])
	return out


## Treasure Box (Xatu): opens when the player falls to 40 life or less. The reward
## kind is drawn once per run (getTreasureBoxReward).
static func treasure_reward(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	for kind in TREASURE_REWARDS:
		roll -= TREASURE_REWARDS[kind]
		if roll < 0.0:
			return kind
	return "itemComponents"


static func open_treasure_box(player: PlayerState, rng: RandomNumberGenerator) -> String:
	var given: Array[String] = []
	match player.treasure_reward:
		"sweets": # 5 different sweets
			given.assign(_pick_n(GameData.items_in("Sweets"), 5, rng))
		"itemComponents": # 4 different components (Fossil Stone and Silk Scarf included)
			given.assign(_pick_n(GameData.items_in("ItemComponents"), 4, rng))
		"componentsAndTickets":
			given.assign(_pick_n(GameData.items_in("ItemComponents"), 2, rng))
			given.append_array(["RECYCLE_TICKET", "EXCHANGE_TICKET"])
		"craftableItems":
			given.assign(_pick_n(EndlessWaves.item_pool("full"), 2, rng))
		"mushrooms":
			given.assign(["TINY_MUSHROOM", "BIG_MUSHROOM", "BALM_MUSHROOM"])
		"goldBow":
			given.append("GOLD_BOW")
		_: # a Big Nugget: 10 gold
			player.gold += 10
			player.gold_earned += 10
			return "10 gold"
	for item in given:
		player.add_item(item)
	return ", ".join(given.map(func(i: String) -> String: return GameData.item_name(i)))
#endregion


#region portals and propositions
## 3 portals, each with synergy symbols and the region it leads to (pickRandomSynergySymbols).
## Stage 0: random symbols; later: symbols from the synergies of the player's board.
static func portals(player: PlayerState, stage: int, rng: RandomNumberGenerator) -> Array:
	var all_types: Array = GameData.synergies() # the ones the Battle Pass has unlocked
	var symbols: Array = []
	if stage == 0:
		var shuffled := all_types.duplicate()
		_shuffle(shuffled, rng)
		symbols = shuffled.slice(0, 3 * 2)
	else:
		symbols = _player_symbols(player, stage, all_types, rng)
	_shuffle(symbols, rng)
	var out: Array = []
	for i in NB_PORTALS:
		out.append({"synergies": [], "map": ""})
	for i in symbols.size():
		out[i % NB_PORTALS].synergies.append(symbols[i])
	var maps: Array = GameData.config.get("maps", {}).keys().filter(func(m: String) -> bool:
		return m != "town" and not m.begins_with("Test"))
	for portal in out:
		var best := -1
		var candidates: Array = []
		for m in maps:
			var shared: int = GameData.config.maps[m].synergies.filter(func(s: String) -> bool: return portal.synergies.has(s)).size()
			if shared > best:
				best = shared
				candidates = [m]
			elif shared == best:
				candidates.append(m)
		portal.map = candidates[rng.randi() % candidates.size()] if not candidates.is_empty() else ""
		maps.erase(portal.map)
		portal["unlocks"] = GameData.region_unlocks(portal.map) # reaching it unlocks these for the run
	return out


## The 4 symbols of a player: its synergies by tier (Light and Flora tiers lowered,
## no Baby legendaries), completed with incomplete ones then random ones.
static func _player_symbols(player: PlayerState, stage: int, all_types: Array, rng: RandomNumberGenerator) -> Array:
	var counts := player.synergy_counts()
	var usable := all_types.filter(func(t: String) -> bool: return not (t == "BABY" and stage == 20))
	var entries: Array = []
	for t in usable:
		var tier := Synergies.tier(t, counts.get(t, 0))
		if t == "LIGHT":
			tier = [0, 1, 1, 2, 3][tier]
		elif t == "FLORA":
			tier = [0, 1, 2, 3, 3][tier]
		elif t == "GOURMET" and stage == 20:
			tier = mini(tier, 2)
		entries.append([t, tier])
	entries.sort_custom(func(a: Array, b: Array) -> bool:
		if a[1] != b[1]:
			return a[1] > b[1]
		var ca := int(counts.get(a[0], 0))
		var cb := int(counts.get(b[0], 0))
		if ca != cb:
			return ca > cb
		return all_types.find(a[0]) > all_types.find(b[0]))
	var candidates: Array = []
	for e in entries:
		if not candidates.has(e[0]):
			for _i in e[1]:
				candidates.append(e[0])
	if candidates.size() < 4:
		var incomplete := entries.filter(func(e: Array) -> bool:
			return e[1] == 0 and counts.get(e[0], 0) > 0 and not candidates.has(e[0])).map(func(e: Array) -> String: return e[0])
		_shuffle(incomplete, rng)
		candidates.append_array(incomplete.slice(0, 4 - candidates.size()))
	while candidates.size() < 4:
		var free := usable.filter(func(t: String) -> bool: return not candidates.has(t))
		if free.is_empty(): # fewer than 4 synergies unlocked (Battle Pass)
			break
		candidates.append(free[rng.randi() % free.size()])
	candidates = candidates.slice(0, 7)
	_shuffle(candidates, rng)
	return candidates.slice(0, NB_SYMBOLS_PER_PLAYER)


## Pokémon offered after going through a portal: {kind: "pokemon", category, pokemons, items}.
## Each one has one of the portal synergies when possible, never two of a family;
## starters come with a component each.
static func propositions(player: PlayerState, stage: int, portal_synergies: Array, rng: RandomNumberGenerator) -> Dictionary:
	var category := "starter" if stage == 0 else ("unique" if stage == 10 else "legendary")
	var candidates: Array = []
	match category:
		"starter":
			candidates = player.shop_candidates("COMMON")
		"unique":
			candidates = GameData.unique.filter(func(p: String) -> bool:
				return GameData.get_pokemon(p).family == p and GameData.duo_of(p) == "")
			candidates.append_array(GameData.unique_duos.map(func(d: String) -> String: return "+".join(GameData.DUOS[d])))
		"legendary":
			candidates = GameData.legendary.filter(func(p: String) -> bool:
				return GameData.get_pokemon(p).family == p and GameData.duo_of(p) == "")
			candidates.append_array(GameData.legendary_duos.map(func(d: String) -> String: return "+".join(GameData.DUOS[d])))
	var n := int(GameData.config.get("nbStarters", 3)) if category == "starter" else int(GameData.config.get("nbUniquePropositions", 6))
	var wanted_list := portal_synergies.duplicate()
	_shuffle(wanted_list, rng)
	wanted_list = wanted_list.slice(0, n)
	var pokemons: Array[String] = []
	var items: Array[String] = []
	var components := EndlessWaves.item_pool("component")
	for i in n:
		var wanted: String = wanted_list[i] if i < wanted_list.size() else ""
		var options := candidates.filter(_fits_proposition.bind(wanted, pokemons, player.map))
		if options.is_empty():
			options = candidates.filter(_fits_proposition.bind("", pokemons, player.map))
		if options.is_empty():
			break
		var selected: String = options[rng.randi() % options.size()]
		candidates.erase(selected)
		if selected.contains("+"): # a duo: both are given
			pokemons.append(selected)
			continue
		var variants := GameData.variants_in_region(selected, player.map)
		if not variants.is_empty(): # the regional variant of the region (Vulpix -> Alolan Vulpix)
			selected = variants[rng.randi() % variants.size()]
		if category == "starter" and not pokemons.has("EEVEE") and GameData.pokemon.has("EEVEE") \
				and rng.randf() < EEVEE_RATE:
			pokemons.append("EEVEE") # evolves with a stone crafted from its Fossil Stone
			items.append("FOSSIL_STONE")
			continue
		pokemons.append(selected)
		if category == "starter":
			var free := components.filter(func(c: String) -> bool: return not items.has(c))
			items.append(free[rng.randi() % free.size()])
	return {"kind": "pokemon", "category": category, "pokemons": pokemons, "items": items}


## filterCandidates: the wanted synergy, a regional Pokémon only in its region, not two of a
## family (or regional variants of each other), not a form whose variant in this region
## would lose the wanted synergy.
static func _fits_proposition(pkm: String, wanted: String, proposed: Array, map: String) -> bool:
	pkm = pkm.get_slice("+", 0) # a duo: its first Pokémon
	var data := GameData.get_pokemon(pkm)
	if wanted != "" and not data.types.has(wanted):
		return false
	if data.get("regional", false) and not GameData.in_region(pkm, map):
		return false
	if proposed.any(func(p: String) -> bool:
			p = p.get_slice("+", 0)
			return GameData.get_pokemon(p).family == data.family or GameData.is_regional_variant(p, pkm)):
		return false
	return wanted == "" or not GameData.variants_in_region(pkm, map).any(func(v: String) -> bool:
		return not GameData.get_pokemon(v).types.has(wanted))
#endregion


#region carousel and additional picks
## Items of the carousel (pickRandomItems): 5 components (2 copies max), or 6 full
## items from stage 20; Kangaskhan sells full items, Duskull adds 4 Gimmighoul Coins,
## Sableye 4 synergy gems.
static func carousel(player: PlayerState, stage: int, encounter: String, rng: RandomNumberGenerator) -> Dictionary:
	var n := 5
	var max_copies := 2
	var pool: Array = EndlessWaves.item_pool("component")
	if stage >= 20:
		# CraftableItemsNoScarves: full items and synergy stones (items made with a Silk
		# Scarf are not ported)
		n += 1
		max_copies = 1
		pool = GameData.full_items.filter(func(i: String) -> bool: return not GameData.item_in(i, "Scarves"))
	var items: Array[String] = []
	match encounter:
		"KANGASKHAN":
			pool = EndlessWaves.item_pool("full")
			max_copies = 1
		"DUSKULL":
			for _i in 4:
				items.append("GIMMIGHOUL_COIN")
		"SABLEYE":
			var gems := GameData.items_in("SynergyGems")
			_shuffle(gems, rng)
			items.append_array(gems.slice(0, 4))
		"MEOWTH":
			for _i in 4:
				items.append("AMULET_COIN")
		"CINCCINO":
			for _i in 4:
				items.append("SILK_SCARF")
		"ELECTIVIRE":
			pool = GameData.items_in("Tools")
			max_copies = 2
		"KECLEON":
			# synergy items of the player's 3 best synergies (no Memory Disc, no Shiny Stone)
			var top := _top_synergies(player, 3)
			var fits := GameData.items_in("SynergyItems").filter(func(i: String) -> bool:
				return not GameData.item_in(i, "MemoryDiscs") and i != "SHINY_STONE" \
					and top.has(GameData.item_synergy(i)))
			if not fits.is_empty():
				pool = fits
			max_copies = 2
		"LUDICOLO":
			items.append_array(SEVEN_TREASURES.keys())
			n -= 1
		"CHANSEY":
			pool = ["EGG_FOR_SELL"]
			n = 1
			max_copies = 99
	for _i in n:
		var item := ""
		for _try in 10:
			item = pool[rng.randi() % pool.size()]
			if items.count(item) < max_copies:
				break
		items.append(item)
	_shuffle(items, rng)
	var title := L.t("Carousel: choose an item")
	if encounter != "":
		title = encounter_text(encounter)
	return {"kind": "items", "source": "carousel", "items": items, "cost": int(ENCOUNTER_PRICES.get(encounter, 0)), "title": title}


## The `n` synergies of the player with the most Pokémon (getTopSynergies).
static func _top_synergies(player: PlayerState, n: int) -> Array:
	var counts := player.synergy_counts()
	var types: Array = counts.keys().filter(func(t: String) -> bool: return int(counts[t]) > 0)
	types.sort_custom(func(a: String, b: String) -> bool: return int(counts[a]) > int(counts[b]))
	return types.slice(0, n)


## Additional pick (5 / 8 / 11): up to 3 additional Pokémon of the stage rarity, each with a
## component; the regional variant of the player's region is shown instead of its base form.
## In a season (Seasons) there is no additional family: the pick is among the Pokémon of that
## rarity in the shop of the season (the ones `player` can find: its Flabébé colour).
static func additional_pick(stage: int, rng: RandomNumberGenerator, map := "town", player: PlayerState = null) -> Dictionary:
	var index := _stages("additionalPickStages").find(stage)
	var rarity: String = ADDITIONAL_RARITIES[clampi(index, 0, 2)]
	var options: Array = GameData.additional_tier1_by_rarity[rarity].duplicate()
	if GameData.season_active:
		options = player.shop_candidates(rarity) if player != null else GameData.tier1_by_rarity[rarity].duplicate()
	_shuffle(options, rng)
	var pokemons: Array[String] = []
	for pkm in options.slice(0, 3):
		var variants := GameData.variants_in_region(pkm, "AmpPlains" if map == "town" else map)
		pokemons.append(variants[rng.randi() % variants.size()] if not variants.is_empty() else pkm)
	var components := EndlessWaves.item_pool("component")
	var items: Array[String] = []
	for _p in pokemons:
		items.append(components[rng.randi() % components.size()])
	return {"kind": "pokemon", "category": "addpick", "pokemons": pokemons, "items": items}
#endregion


## pickNRandomIn: `n` different entries of `list`.
static func _pick_n(list: Array, n: int, rng: RandomNumberGenerator) -> Array:
	var copy := list.duplicate()
	var unique: Array = []
	for x in copy:
		if not unique.has(x):
			unique.append(x)
	_shuffle(unique, rng)
	return unique.slice(0, n)


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp
