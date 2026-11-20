class_name PlayerState
extends RefCounted

## The player during an Endless run: gold, level, life, bench, board and shop.
## Rules from app/config/game (shop odds, costs, xp table) and game-commands.ts,
## plus what synergies and passives do between stages (player.ts, synergies.ts,
## passives.ts): Light cell, Ground holes and buried items, Fairy wands, Bug nest
## spawns, Fighting training, Fur Coat, Timburr pillars, divergent evolutions and
## weather forms.
##
## Board cells use the battle board coordinates of the player's side
## (x 0..7, y 0..2, y = 2 front row), so a fight starts from the same cells.

signal changed

const BENCH_SIZE := 8 ## web; the run uses `bench_slots` (difficulty benchSize)
const MAX_BENCH := 24 ## 3 rows of 8 on the arena
const MAX_STACK := 3 ## copies a bench slot may hold at most (difficulty benchStack)
const START_GOLD := 5
const START_LEVEL := 2
const START_LIFE := 100
const REROLL_COST := 1
const XP_COST := 4
const XP_PER_BUY := 4
const XP_PER_ROUND := 2
const BASE_INCOME := 5
const MAX_INTEREST := 5
## Rows of the player's side of the board (y 0..3, 3 = the front row).
const PLAYER_ROWS := BattleBoard.SIDE_ROWS
## Columns from the middle out, for the automatic placements.
const CENTER_OUT := [3, 2, 4, 1, 5, 0, 6]
const REPEAT_BALL_UNIQUE_CAP := 80
const REPEAT_BALL_LEGENDARY_CAP := 120
const REPEAT_BALL_INTERVAL := 10
const INCENSE_CHANCE := 0.05 ## INCENSE_CHANCE = HONEY_CHANCE (config/game/shop.ts)
const MAX_HOLE_DEPTH := 5
const FUR_COAT_STACKS := 10
const PILLARS := ["PILLAR_WOOD", "PILLAR_IRON", "PILLAR_CONCRETE"]
const FLABEBE_FORMS := ["FLABEBE", "FLABEBE_YELLOW", "FLABEBE_ORANGE", "FLABEBE_BLUE", "FLABEBE_WHITE"]
## Rotom Catalog (items.ts): the appliances Rotom can possess.
const ROTOM_FORMS := ["ROTOM", "ROTOM_HEAT", "ROTOM_WASH", "ROTOM_FROST", "ROTOM_FAN", "ROTOM_MOW", "ROTOM_DRONE"]
## Meteorite (items.ts): the formes Deoxys can take.
const DEOXYS_FORMS := ["DEOXYS", "DEOXYS_ATTACK", "DEOXYS_DEFENSE", "DEOXYS_SPEED"]
## Oricorio's nectars -> its style; the nectar of each flower pot (pink, yellow, white, blue).
const NECTAR_FORMS := {"RED_NECTAR": "ORICORIO_BAILE", "YELLOW_NECTAR": "ORICORIO_POMPOM",
	"PINK_NECTAR": "ORICORIO_PA_U", "PURPLE_NECTAR": "ORICORIO_SENSU"}
const POT_NECTARS := ["RED_NECTAR", "YELLOW_NECTAR", "PINK_NECTAR", "PURPLE_NECTAR"]
const TRAINING_ATK := 4.0
const TRAINING_HP_RATIO := 0.1
## Additional pick stages (5, 8, 11): the additional families of this rarity join the shop.
const ADDITIONAL_RARITIES := ["UNCOMMON", "RARE", "EPIC"]
## Port-only tool of the item bench (strip_items), drawn with the web Toolbox icon.
const ITEM_REMOVER := "ITEM_REMOVER"
## Shop specials (config/game/shop.ts): Ditto 0.5% + 0.01% per refresh since the last one, from
## stage 6 (Meltan instead with a Mystery Box); a Falinks Trooper 4% per slot with Falinks Brass.
const DITTO_BASE_RATE := 0.005
const DITTO_RATE_PER_REROLL := 0.0001
const MIN_STAGE_FOR_DITTO := 6
const FALINKS_TROOPER_RATE := 0.04
const MAX_FALINKS_TROOPERS := 6
## getBuyPrice / getSellPrice special prices (SellPrices, BuyPrices).
const BUY_PRICES := {"DITTO": 5, "FALINKS_TROOPER": 3, "MELTAN": 0}
const SELL_PRICES := {"EGG": 2, "DITTO": 5, "FALINKS_TROOPER": 3, "MELTAN": 0, "MAGIKARP": 0, "GYARADOS": 10,
	"FEEBAS": 1, "MILOTIC": 10, "WISHIWASHI": 3, "WISHIWASHI_SCHOOL": 10, "REMORAID": 2, "OCTILLERY": 7,
	"PIKACHU_LIBRE": 3, "PIKACHU_SURFER": 3}
## Rare Candy evolved fishes sell as their first form.
const CANDY_SELL_AS := {"OCTILLERY": "REMORAID", "GYARADOS": "MAGIKARP", "MILOTIC": "FEEBAS",
	"WISHIWASHI_SCHOOL": "WISHIWASHI"}
const HATCH_SELL := [3, 4, 5]
const UNIQUE_SELL := 10
const LEGENDARY_SELL := 20
const UNIQUE_DUO_SELL := 6
const LEGENDARY_DUO_SELL := 10
## Items rotting at each stage start (game-commands.ts rottingItems, in this order).
const ROTTING_ITEMS := [["SIRUPY_APPLE", "LEFTOVERS"], ["SWEET_APPLE", "SIRUPY_APPLE"], ["TART_APPLE", "SWEET_APPLE"]]
## Milcery's flavors by the synergy most present around it (SynergyFlavors).
const SYNERGY_FLAVORS := {"NORMAL": "VANILLA_FLAVOR", "GRASS": "MATCHA_FLAVOR", "FIRE": "RUBY_SWIRL_FLAVOR",
	"WATER": "MINT_FLAVOR", "ELECTRIC": "LEMON_FLAVOR", "FIGHTING": "RUBY_FLAVOR", "PSYCHIC": "RAINBOW_SWIRL_FLAVOR",
	"DARK": "CARAMEL_SWIRL_FLAVOR", "STEEL": "RUBY_FLAVOR", "GROUND": "SALTED_FLAVOR", "POISON": "MATCHA_FLAVOR",
	"DRAGON": "CARAMEL_SWIRL_FLAVOR", "FIELD": "RUBY_SWIRL_FLAVOR", "MONSTER": "CARAMEL_SWIRL_FLAVOR",
	"HUMAN": "RUBY_FLAVOR", "AQUATIC": "MINT_FLAVOR", "BUG": "LEMON_FLAVOR", "FLYING": "VANILLA_FLAVOR",
	"FLORA": "MATCHA_FLAVOR", "ROCK": "SALTED_FLAVOR", "GHOST": "MATCHA_FLAVOR", "FAIRY": "LEMON_FLAVOR",
	"ICE": "MINT_FLAVOR", "FOSSIL": "SALTED_FLAVOR", "SOUND": "LEMON_FLAVOR", "ARTIFICIAL": "VANILLA_FLAVOR",
	"LIGHT": "RAINBOW_SWIRL_FLAVOR", "WILD": "RUBY_SWIRL_FLAVOR", "BABY": "RAINBOW_SWIRL_FLAVOR",
	"AMORPHOUS": "RAINBOW_SWIRL_FLAVOR", "GOURMET": "VANILLA_FLAVOR"}
## VivillonFormPerSynergy (config/game/pokemons.ts).
const VIVILLON_FORMS := {"SOUND": "VIVILLON", "NORMAL": "VIVILLON_ICY_SNOW", "GHOST": "VIVILLON_POLAR",
	"ICE": "VIVILLON_TUNDRA", "FOSSIL": "VIVILLON_CONTINENTAL", "GRASS": "VIVILLON_GARDEN",
	"PSYCHIC": "VIVILLON_ELEGANT", "FIELD": "VIVILLON_MODERN", "WATER": "VIVILLON_MARINE",
	"FIGHTING": "VIVILLON_ARCHIPELAGO", "HUMAN": "VIVILLON_HIGH_PLAINS", "ROCK": "VIVILLON_SANDSTORM",
	"AQUATIC": "VIVILLON_RIVER", "STEEL": "VIVILLON_MONSOON", "ELECTRIC": "VIVILLON_SAVANNA",
	"FIRE": "VIVILLON_SUN", "LIGHT": "VIVILLON_OCEAN", "POISON": "VIVILLON_JUNGLE", "FAIRY": "VIVILLON_FANCY",
	"ARTIFICIAL": "VIVILLON_POKE_BALL"}


class OwnedUnit:
	extends RefCounted
	static var _next_id := 1
	var id: int
	var pkm: String
	var items: Array[String] = [] ## held items, 3 at most
	## Permanent stat changes (Fighting training): {"atk": 4, "maxHP": 12}.
	var mods: Dictionary = {}
	var stacks := 0 ## Fur Coat stages on the board
	## Gourmet: dishes eaten, their effect applies at the next fight on the board.
	var dishes: Array[String] = []
	## Baby: stages spent growing (eggs and HATCH lines), what an egg hatches into, golden egg.
	var hatch_stacks := 0
	var hatch_into := ""
	var golden := false
	## Electric: Cell Battery used on it: supercharged at its next fight.
	var supercharged := false
	## Human: ability taught by a TM ("" = its own), TM item given back when it leaves.
	var tm := ""
	## KO it did / KO it suffered in fights (Basculin White), the region it was found in (Stantler).
	var kill_count := 0
	var death_count := 0
	var original_map := ""
	## Illusion (Zorua line): the Pokémon it looks like ("" = itself), the slot it was last seen on.
	var look := ""
	var last_slot: Dictionary = {}

	## Ability used in fights: the TM one, else its own.
	func skill() -> String:
		return tm if tm != "" else String(data().get("skill", ""))

	func _init(p: String) -> void:
		id = _next_id
		_next_id += 1
		pkm = p
		if passive() == "PASSIMIAN": # comes with a Ball (pokemon.ts)
			items.append("BALL")

	func data() -> Dictionary:
		return GameData.get_pokemon(pkm)

	func stars() -> int:
		return int(data().get("stars", 1))

	func family() -> String:
		return String(data().get("family", pkm))

	func passive() -> String:
		return String(data().get("passive", "NONE"))

	## Pillars: cannot be sold, hold items or fight, and do not count in the team size.
	func is_inanimate() -> bool:
		return passive() == "INANIMATE"

	## Types of the Pokémon plus the ones its items give (evolution stones, gems...);
	## a DRAGON given by an item comes first (addSynergiesGivenByItems).
	func types() -> Array:
		var out: Array = data().get("types", []).duplicate()
		for item in items:
			var given := GameData.item_synergy(item)
			if given != "" and not out.has(given):
				if given == "DRAGON":
					out.push_front(given)
				else:
					out.append(given)
		return out


var gold := START_GOLD
var level := START_LEVEL
var experience := 0
var life := START_LIFE
var stage := 0
## OwnedUnit or null: `bench_stack` places per bench slot, `bench_size` places (see "bench slots").
var bench: Array = []
## Bench slots (difficulty benchSize) and the copies of the same Pokémon a slot holds (difficulty
## benchStack; 1 = the web game, a Pokémon per slot).
var bench_slots := BENCH_SIZE
var bench_stack := 1
## Bench slots of this run (Difficulty benchSize, web 8).
var bench_size := BENCH_SIZE
var board: Dictionary = {} ## Vector2i -> OwnedUnit
var shop: Array[String] = []
var shop_locked := false
var items: Array[String] = [] ## item bench (rewards, items of sold Pokémon)
var pool_counts: Dictionary = {}
var rng := RandomNumberGenerator.new()
## False during a fight: units fighting on the board must not merge away.
var merge_board := true

## Synergy points found in the ground (buried gems): {type: count}.
var bonus_synergies: Dictionary = {}
## Light: the Pokémon on this cell when a fight starts is in the spotlight.
var light_cell := Vector2i.ZERO
## Ground: depth of the hole of each board cell (0..5) and the item buried under it.
var ground_holes: Dictionary = {}
var buried_items: Dictionary = {}
## Fairy: 3 wands offered per synergy level, and the wands picked so far.
var wand_options: Array = []
var fairy_wands: Array[String] = []
## Flabébé color of this run (only this one is found in the shop).
var flower_color := "FLABEBE"
## First forms of additional families that joined the shop.
var unlocked_additional: Dictionary = {}
## What joined the shop and when, for the pool list behind the "!" button of the shop:
## [{stage, rarity, pokemons: Array[String], pick}] (`pick`: chosen in town, not a stage unlock).
var pool_news: Array[Dictionary] = []
## Something joined the pool since the list was last opened ("!" glows).
var pool_news_unread := false
## Fighting 4: bench units training during the current fight (OwnedUnit ids).
var training_ids: Array[int] = []
## Town: the region the last portal led to (its music), the current encounter (Marowak
## stays until the next town), encounters already met, the Treasure Box reward of the run.
var map := "town"
## Regions (updateRegionalPool): copies of the Pokémon found only in the current region
## (web regional pool), and the regional forms of the region (web regionalPokemons: a
## variant replaces its base form in the shop, Vulpix -> Alolan Vulpix).
var regional_counts: Dictionary = {}
var regional_pokemons: Array[String] = []
## Synergies the regions of this run unlocked until it ends (GameData.run_unlocked, not in the web
## game), and the ones not told yet (the Game banner takes them).
var run_unlocks: Array[String] = []
var run_unlocks_unread: Array[String] = []
var town_encounter := ""
var encounters_seen: Dictionary = {}
var treasure_reward := ""
var outlaw_stage := -1 ## Magnezone: the stage the outlaw shows up (Wanted Notice)
var gold_earned := 0 ## gold earned during the run (Gold mission order)
## Pokémon training in the Dojo: [{unit, sub (its Substitute), level, return_stage}]
var dojo: Array = []
## Grass: berry of each of the 3 trees and its growth (ripe at 3).
var berry_tree_types: Array[String] = []
var berry_tree_stages: Array[int] = [1, 1, 1]
## Free shop refreshes (Golden Razz Berry...).
var free_rolls := 0
## Normal: scarves crafted from the Silk Scarves of the synergy (in order), Silk
## Scarves got another way (Fur Coat), Normal tier the scarves were last given for.
var scarves_items: Array[String] = []
var extra_scarves := 0
var scarves_tier := 0
## Artificial: the 3 tools of this run (one per tier, in order), tier last given for.
var artificial_items: Array[String] = []
var artificial_tier := 0
## Human: the bronze / silver / gold TM of this run, tier they were last given for.
var tms: Array[String] = []
var tms_tier := 0
## Electric 3: charge of the Cell Battery (a battery every 100%).
var cell_battery := 0
## Baby: egg chance stacked by lost fights (Hatcher), HATCH Pokémon already given by eggs.
var egg_chance := 0.0
var eggs_given: Array[String] = []
## Psychic: shop refreshes done, shops since the last Unown shop, Unowns used (their
## reminiscence counts toward Psychic 3 for the next shop).
var reroll_count := 0
var shops_since_unown := 0
var unown_reminiscences := 0
## Flora: the Pokémon of each pot (pink, yellow, white, blue, orange), the order the pots
## blossom in fights, the mulch collected toward the next Rich Mulch and its cap.
var flower_pots: Array[String] = ["HOPPIP", "BELLSPROUT", "CHIKORITA", "ODDISH", "BELLOSSOM"]
var flower_order: Array[int] = [0, 1, 2, 3, 4]
var mulch := 0
var mulch_cap := 5
## Shop refreshes since the last Ditto (gameStats.rerollCountSinceLastDitto).
var rerolls_since_ditto := 0
## The wild Pokémon of this stage are shiny (Celebi met in the town, or the stage's shinyChance):
## their colors, the rewards of some bosses (GameState.shinyEncounter).
var shiny_encounter := false
## Components given by the random rewards of the first stages (randomComponentsGiven).
var random_components_given: Array[String] = []
## Wandering Pokémon to show (spawnWanderingPokemon): {pkm, kind: catchable | outlaw | dialog,
## behavior: run | spectate, delay (s)}; the game takes them (Wanderers).
var wanderers: Array[Dictionary] = []


func _init() -> void:
	rng.randomize()
	bench_slots = clampi(int(Difficulty.value("benchSize", BENCH_SIZE)), 1, MAX_BENCH)
	bench_stack = clampi(int(Difficulty.value("benchStack", 1)), 1, MAX_STACK)
	bench_size = bench_slots * bench_stack
	bench.resize(bench_size)
	for rarity in GameData.SHOP_RARITIES:
		for pkm in GameData.tier1_by_rarity[rarity] + GameData.additional_tier1_by_rarity[rarity]:
			pool_counts[pkm] = GameData.pool_size(pkm)
	var shop_size := int(GameData.config.get("shopSize", 6))
	shop.resize(shop_size)
	shop.fill("")
	light_cell = Vector2i(rng.randi_range(0, BattleBoard.WIDTH - 1), rng.randi_range(0, PLAYER_ROWS - 1))
	_bury_items()
	for level_wands in GameData.config.get("fairyWands", []):
		var options: Array = level_wands.duplicate()
		_shuffle(options)
		wand_options.append(options.slice(0, 3))
	flower_color = FLABEBE_FORMS[rng.randi() % FLABEBE_FORMS.size()]
	treasure_reward = Town.treasure_reward(rng)
	var berries := GameData.items_in("NonSpecialBerries")
	_shuffle(berries)
	berry_tree_types.assign(berries.slice(0, 3))
	var tools := GameData.items_in("ArtificialItems")
	_shuffle(tools)
	artificial_items.assign(tools.slice(0, 3))
	_shuffle(flower_order)
	for tier in ["TMsBronze", "TMsSilver", "TMsGold"]:
		tms.append(_pick(GameData.items_in(tier)))


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp


## initBuriedItems: 3 synergy gems, 4 trash / coins, 1 precious item (tool or treasure),
## hidden under 8 of the 24 cells of the player's side.
func _bury_items() -> void:
	var buried: Array = []
	for _i in 3:
		buried.append(_pick(GameData.items_in("SynergyGemsBuried")))
	for _i in 4:
		buried.append(_pick(GameData.items_in("BuriedTrash")))
	buried.append(_pick(GameData.items_in("ToolsBuried")) if rng.randf() < 0.5 else _pick(["TREASURE_BOX", "BIG_NUGGET"]))
	var cells: Array = []
	for y in PLAYER_ROWS:
		for x in BattleBoard.WIDTH:
			cells.append(Vector2i(x, y))
	_shuffle(cells)
	for i in buried.size():
		if buried[i] != "":
			buried_items[cells[i]] = buried[i]


func _pick(list: Array) -> String:
	return String(list[rng.randi() % list.size()]) if not list.is_empty() else ""


#region shop
## assignShop: Psychic 3 makes some shops all Unowns (the stage one, or every 10th refresh;
## +1 free refresh); Psychic 1 / 2: the last slot is an Unown every 5 / 3 shops.
func roll_shop(manual := false) -> void:
	var odds := GameData.shop_odds(level)
	var wild := Synergies.wild_chance(self)
	var counts := synergy_counts()
	var psychic := int(counts.get("PSYCHIC", 0)) + unown_reminiscences
	unown_reminiscences = 0
	var tiers: Array = Synergies.thresholds("PSYCHIC")
	var intervals: Array = GameData.config.get("unownIntervals", [5, 3, 10])
	var transcendence := tiers.size() >= 3 and psychic >= int(tiers[2])
	if transcendence:
		shops_since_unown += 1
	_release_shop()
	if transcendence and ((not manual and not shop_locked) or (manual and shops_since_unown >= int(intervals[2]))):
		free_rolls += 1
		shops_since_unown = 0
		var unowns := unowns_for_stage()
		_shuffle(unowns)
		for i in shop.size():
			shop[i] = unowns[i % unowns.size()]
		changed.emit()
		return
	var psy_tier := Synergies.tier("PSYCHIC", psychic)
	for i in shop.size():
		var special := _special_pick()
		set_shop_slot(i, special if special != "" else _roll_one(odds, wild))
	# Repeat Ball (shop.ts): after many rerolls, one slot per holder offers a Unique
	# (80+) or a Legendary (120+) every 10 rerolls
	var total := reroll_count + stage
	if total % REPEAT_BALL_INTERVAL == 0 and total >= REPEAT_BALL_UNIQUE_CAP:
		var special: Array = GameData.legendary if total >= REPEAT_BALL_LEGENDARY_CAP else GameData.unique
		special = special.filter(func(p: String) -> bool: return GameData.get_pokemon(p).family == p)
		for i in mini(_repeat_balls(), shop.size()):
			if not special.is_empty():
				set_shop_slot(i, special[rng.randi() % special.size()])
	if psy_tier > 0 and not shop.is_empty():
		var every := int(intervals[1]) if psy_tier >= 2 else int(intervals[0])
		if (reroll_count + stage) % every == 0:
			var unowns := unowns_for_stage()
			set_shop_slot(shop.size() - 1, unowns[rng.randi() % unowns.size()])
	changed.emit()


## getUnownsPoolPerStage: the Unowns found before stage 10, before 20, then.
func unowns_for_stage() -> Array:
	var stages: Array = GameData.config.get("unownStages", [[]])
	var i := 0 if stage < 10 else (1 if stage < 20 else 2)
	var list: Array = stages[mini(i, stages.size() - 1)]
	return list.filter(func(p: String) -> bool: return GameData.pokemon.has(p))


## First forms of a rarity found in the shared pool: the pool, the additional families
## unlocked, only the Flabébé color of this run.
func shop_candidates(rarity: String) -> Array:
	var out: Array = []
	for pkm in GameData.tier1_by_rarity[rarity] + GameData.additional_tier1_by_rarity[rarity]:
		if GameData.additional.has(pkm) and not unlocked_additional.has(pkm):
			continue
		if FLABEBE_FORMS.has(pkm) and pkm != flower_color:
			continue
		out.append(pkm)
	return out


## getRandomPokemonFromPool: the pool entries of a rarity (shared pool + regional pool)
## with what the shop shows for each ({entry: shown}): a regional variant of this region
## replaces its base form.
func pool_entries(rarity: String) -> Dictionary:
	var out := {}
	for pkm in shop_candidates(rarity):
		out[pkm] = regional_form(pkm)
	for pkm in regional_counts:
		if GameData.get_pokemon(pkm).get("rarity", "") == rarity:
			out[pkm] = pkm
	return out


## shop.ts pickPokemon / assignShop: a Pokémon shown in the shop has left its pool (the next slots
## and rolls see one copy less); it comes back when the shop is refreshed without buying it.
func set_shop_slot(slot: int, pkm: String) -> void:
	_release_slot(slot)
	shop[slot] = pkm
	if pkm != "":
		take_copy(pkm)


func _release_slot(slot: int) -> void:
	var pkm := shop[slot]
	if pkm != "":
		return_copies(String(GameData.get_pokemon(pkm).get("family", pkm)), 1)
	shop[slot] = ""


func _release_shop() -> void:
	for i in shop.size():
		_release_slot(i)


## Copies of a pool entry left (shared pool or regional pool).
func copies_left(pkm: String) -> int:
	return int(pool_counts.get(pkm, regional_counts.get(pkm, 0)))


## A copy leaves the pools (bought, fished, given): a regional variant takes one of the
## form it replaces.
func take_copy(pkm: String) -> void:
	var key: String = GameData.regional_base.get(pkm, pkm)
	if pool_counts.has(key):
		pool_counts[key] = maxi(int(pool_counts[key]) - 1, 0)
	elif regional_counts.has(key):
		regional_counts[key] = maxi(int(regional_counts[key]) - 1, 0)


## releasePokemon: copies of a sold family go back to their pool; a regional Pokémon
## sold out of its region is lost.
func return_copies(family: String, n: int) -> void:
	if GameData.get_pokemon(family).get("regional", false) and not GameData.in_region(family, map, unlocked_additional):
		return
	var key: String = GameData.regional_base.get(family, family)
	if pool_counts.has(key):
		pool_counts[key] += n
	elif regional_counts.has(key):
		regional_counts[key] += n


## pickPokemon specials: Ditto (Meltan with a Mystery Box) from stage 6, a Falinks Trooper while
## Falinks Brass is owned and fewer than 6 troopers are. "" when none.
func _special_pick(no_special := false) -> String:
	if no_special:
		return ""
	var ditto_rate := DITTO_BASE_RATE + DITTO_RATE_PER_REROLL * rerolls_since_ditto
	if stage >= MIN_STAGE_FOR_DITTO and rng.randf() < ditto_rate:
		var pkm := "MELTAN" if items.has("MYSTERY_BOX") else "DITTO"
		if GameData.is_available(pkm):
			rerolls_since_ditto = 0
			return pkm
	var owned := bench + board.values()
	var brass := owned.any(func(u) -> bool: return u != null and u.pkm == "FALINKS_BRASS")
	var troopers := owned.filter(func(u) -> bool: return u != null and u.pkm == "FALINKS_TROOPER").size()
	if brass and troopers < MAX_FALINKS_TROOPERS and GameData.is_available("FALINKS_TROOPER") \
			and rng.randf() < FALINKS_TROOPER_RATE:
		return "FALINKS_TROOPER"
	return ""


## getFinalizedLines: the first forms of the lines the player finished (a form without COUNT
## evolution owned, Corsola and Avalugg excepted): the shop stops offering them.
func finalized_lines() -> Dictionary:
	var out := {}
	var owned: Array = bench + board.values()
	for entry in dojo:
		owned.append(entry.unit)
	for u in owned:
		if u == null or u.passive() == "CORSOLA" or u.passive() == "AVALUGG":
			continue
		var data: Dictionary = u.data()
		var has_evolution: bool = String(data.get("evolution", "")) != "" or not data.get("evolutions", []).is_empty()
		if not has_evolution or String(data.get("evolutionRule", "count")) != "count":
			out[GameData.regional_base.get(u.family(), u.family())] = true
	if out.has("BURMY_PLANT"):
		out["BURMY_TRASH"] = true
		out["BURMY_SANDY"] = true
	return out


## One shop slot: a rarity from the level odds, then WILD Pokémon only with the wild
## chance (Synergies.wild_chance), the others otherwise; weighted by the copies left.
func _roll_one(odds: Array, wild_chance := 0.0, forced_types: Array = []) -> String:
	var roll := rng.randf()
	var rarity: String = GameData.SHOP_RARITIES[0]
	for i in GameData.SHOP_RARITIES.size():
		roll -= float(odds[i])
		if roll < 0.0:
			rarity = GameData.SHOP_RARITIES[i]
			break
	var shown := pool_entries(rarity)
	var finals := finalized_lines()
	var all: Array = shown.keys().filter(func(pkm: String) -> bool: return not finals.has(pkm))
	var attracted: Array = forced_types.duplicate() # Soothe Bell, then Incense / Honey (5% each)
	for u in (board.values() if attracted.is_empty() else []):
		if (u.items.has("INCENSE") and rng.randf() < INCENSE_CHANCE) \
				or (u.dishes.has("HONEY") and rng.randf() < INCENSE_CHANCE):
			attracted = u.types()
	var want_wild := attracted.is_empty() and wild_chance > 0.0 and rng.randf() < wild_chance
	if attracted.is_empty() and not want_wild:
		for treasure in Town.SEVEN_TREASURES: # Ludicolo's instruments: 5% each for their type
			if items.has(treasure) and rng.randf() < INCENSE_CHANCE:
				attracted = [Town.SEVEN_TREASURES[treasure]]
				break
	var candidates := all.filter(func(pkm: String) -> bool:
		var types: Array = GameData.get_pokemon(shown[pkm]).types
		if not attracted.is_empty():
			return types.any(func(t: String) -> bool: return attracted.has(t))
		return types.has("WILD") == want_wild)
	var total := 0
	for pkm in candidates:
		total += copies_left(pkm)
	if total <= 0:
		candidates = all
		for pkm in candidates:
			total += copies_left(pkm)
	if total <= 0:
		return ""
	var pick := rng.randi() % total
	for pkm in candidates:
		pick -= copies_left(pkm)
		if pick < 0:
			return shown[pkm]
	return ""


## Spewpa's Vivillon (getAltFormForPlayer): the pattern of the first synergy of the player (by
## tier, then count) that has one, else Icy Snow.
func vivillon_form() -> String:
	var counts := synergy_counts()
	for t in Synergies.sort(counts):
		if int(counts[t]) <= 0:
			continue
		if VIVILLON_FORMS.has(t) and GameData.is_available(VIVILLON_FORMS[t]):
			return VIVILLON_FORMS[t]
	return "VIVILLON_ICY_SNOW" if GameData.is_available("VIVILLON_ICY_SNOW") else "VIVILLON"


## The regional variant replacing `pkm` in this region (Vulpix -> Alolan Vulpix), else `pkm`.
func regional_form(pkm: String) -> String:
	var variants: Array = GameData.regional_variants.get(pkm, []).filter(func(v: String) -> bool:
		return regional_pokemons.has(v))
	return variants[rng.randi() % variants.size()] if not variants.is_empty() else pkm


## Goes to another region (portal, Lapras Passport): its synergies still locked are unlocked for the
## run (not in the web game), new berry trees, new regional Pokémon.
func change_map(new_map: String) -> void:
	if new_map == map or new_map == "":
		return
	map = new_map
	_unlock_region_synergies()
	SynergyItems.reset_berry_trees(self)
	update_regional_pool(true)


## The region reached unlocks the synergies the Battle Pass has not for the rest of the run
## (GameData.unlock_for_run; not in the web game): their families join the shop now (copies in the
## pool, the "!" list), their items the item pools; `run_unlocks` keeps them for the banner and the HUD.
func _unlock_region_synergies() -> void:
	var fresh := GameData.unlock_for_run(map)
	if fresh.is_empty():
		return
	run_unlocks.append_array(fresh)
	run_unlocks_unread.append_array(fresh)
	for rarity in GameData.SHOP_RARITIES:
		var joined: Array[String] = []
		for pkm in GameData.tier1_by_rarity[rarity] + GameData.additional_tier1_by_rarity[rarity]:
			if pool_counts.has(pkm):
				continue
			pool_counts[pkm] = GameData.pool_size(pkm)
			if not GameData.additional.has(pkm) or unlocked_additional.has(pkm):
				joined.append(pkm)
		if not joined.is_empty():
			record_pool_news(joined, rarity)


## updateRegionalPool (player.ts). In a new region the regional pool is emptied, then gets
## the copies of the first forms found only there (not the variants); the regional forms
## are listed again (also when additional families join the shop: their variants).
func update_regional_pool(map_changed: bool) -> void:
	if map == "town":
		regional_pokemons.clear()
		return
	var found := GameData.regional_in(map, unlocked_additional)
	if map_changed:
		regional_counts.clear()
		for pkm in found:
			var data := GameData.get_pokemon(pkm)
			if int(data.stars) == 1 and not GameData.regional_base.has(pkm) \
					and GameData.SHOP_RARITIES.has(data.rarity):
				regional_counts[pkm] = GameData.pool_size(pkm)
		_burmy_cloak()
	# one form per family, its first one; no Unique / Legendary, no plain evolution, no
	# variant of an additional form that has not joined the shop
	regional_pokemons.clear()
	var families := {}
	for pkm in found:
		var family := String(GameData.get_pokemon(pkm).get("family", pkm))
		if families.has(family):
			continue
		families[family] = true
		var base := GameData.get_pokemon(family)
		var evolution := String(base.get("evolution", ""))
		if ["UNIQUE", "LEGENDARY"].has(base.get("rarity", "")) or evolution == pkm \
				or (evolution != "" and GameData.get_pokemon(evolution).get("evolution", "") == pkm):
			continue
		var original := String(GameData.regional_base.get(pkm, ""))
		if original != "" and GameData.get_pokemon(original).get("additional", false) \
				and not unlocked_additional.has(original):
			continue
		regional_pokemons.append(pkm)


## Burmy: from stage 20, going to a region without the type of a Burmy's cloak makes the
## first Burmy of the board evolve into Mothim.
func _burmy_cloak() -> void:
	if stage < 20 or not GameData.pokemon.has("MOTHIM"):
		return
	var cloaks := {"BURMY_PLANT": "GRASS", "BURMY_SANDY": "GROUND", "BURMY_TRASH": "ARTIFICIAL"}
	var burmys: Array = board.values().filter(func(u: OwnedUnit) -> bool: return cloaks.has(u.pkm))
	if burmys.is_empty():
		return
	var region_types: Array = GameData.config.get("maps", {}).get(map, {}).get("synergies", [])
	if burmys.any(func(u: OwnedUnit) -> bool: return not region_types.has(cloaks[u.pkm])):
		burmys[0].pkm = "MOTHIM"


func reroll() -> bool:
	if free_rolls > 0:
		free_rolls -= 1
		reroll_count += 1
		roll_shop(true)
		return true
	if gold < REROLL_COST:
		return false
	gold -= REROLL_COST
	reroll_count += 1
	rerolls_since_ditto += 1
	free_rolls += _repeat_balls() # Repeat Ball: a paid reroll gives a free one per holder
	roll_shop(true)
	return true


func _repeat_balls() -> int:
	return board.values().filter(func(u: OwnedUnit) -> bool: return u.items.has("REPEAT_BALL")).size()


func toggle_lock() -> void:
	shop_locked = not shop_locked
	changed.emit()


## getBuyPrice: Ditto 5, Falinks Trooper 3, Meltan 0, else the rarity cost.
static func buy_price(pkm: String) -> int:
	if BUY_PRICES.has(pkm):
		return int(BUY_PRICES[pkm])
	return GameData.rarity_cost(String(GameData.get_pokemon(pkm).get("rarity", "COMMON")))


func can_buy(slot: int) -> bool:
	var pkm := shop[slot]
	if pkm == "" or gold < buy_price(pkm):
		return false
	return has_bench_room(pkm) or _completes_merge(pkm)


## Buys a shop card onto the bench (with a copy it stacks with, else the first free slot). Returns the
## merges done.
func buy(slot: int) -> Array[Dictionary]:
	var merges: Array[Dictionary] = []
	if not can_buy(slot):
		return merges
	var pkm := shop[slot]
	gold -= buy_price(pkm)
	shop[slot] = "" # its copy left the pool when the shop showed it (set_shop_slot)
	var unit := OwnedUnit.new(pkm)
	var free := bench_index_for(unit)
	if free >= 0:
		bench[free] = unit
	else:
		# bench full: the new copy merges right away
		bench.append(unit)
	merges = check_merges()
	_compact_overflow()
	_board_changed()
	return merges


## getSellPrice (shop.ts): eggs, Ditto, troopers, fishes, Unowns, HATCH, Unique / Legendary
## (duos less), Eevee, duos of the shop half price; a Rare Candy counts one star less.
func sell_price(unit: OwnedUnit) -> int:
	if unit.is_inanimate():
		return 0
	var pkm := unit.pkm
	var data := unit.data()
	var rarity := String(data.get("rarity", "COMMON"))
	var candy := unit.items.has("RARE_CANDY")
	var stars := maxi(1, unit.stars() - (1 if candy else 0))
	var duo := GameData.duo_of(pkm) != ""
	if pkm == "EGG":
		return 10 if unit.golden else int(SELL_PRICES.EGG)
	if candy and CANDY_SELL_AS.has(pkm):
		return int(SELL_PRICES[CANDY_SELL_AS[pkm]])
	if SELL_PRICES.has(pkm):
		return int(SELL_PRICES[pkm])
	if pkm.begins_with("UNOWN"):
		return 1
	match rarity:
		"HATCH":
			return int(HATCH_SELL[clampi(stars - 1, 0, HATCH_SELL.size() - 1)])
		"UNIQUE":
			return UNIQUE_DUO_SELL if duo else UNIQUE_SELL
		"LEGENDARY":
			return LEGENDARY_DUO_SELL if duo else LEGENDARY_SELL
	if unit.family() == "EEVEE":
		return 1
	if duo:
		return ceili(GameData.rarity_cost(rarity) * stars / 2.0)
	if pkm == "MOTHIM":
		return GameData.rarity_cost(rarity)
	return GameData.rarity_cost(rarity) * stars


func sell(unit: OwnedUnit) -> void:
	var loc := find(unit)
	if loc.is_empty() or unit.is_inanimate():
		return
	gold += sell_price(unit)
	if unit.passive() == "CHARCADET": # afterSell: the armors go away
		items.erase("AUSPICIOUS_ARMOR")
		items.erase("MALICIOUS_ARMOR")
	# releasePokemon: 1 / 3 / 9 copies by stars (9 at most), half of them for a duo
	var copies := mini(int(pow(3, unit.stars() - 1)), 9)
	if GameData.duo_of(unit.pkm) != "":
		copies = ceili(copies / 2.0)
	return_copies(unit.data().get("family", unit.pkm), copies)
	items.append_array(unit.items) # held items go back to the item bench
	unit.items.clear()
	if unit.tm != "":
		items.append(SynergyItems.tm_item(unit.tm))
		unit.tm = ""
	_remove_at(loc)
	_board_changed()


func buy_xp() -> bool:
	if gold < XP_COST or level >= int(GameData.config.maxLevel):
		return false
	gold -= XP_COST
	add_experience(XP_PER_BUY)
	return true


func add_experience(amount: int) -> void:
	var max_level := int(GameData.config.maxLevel)
	experience += amount
	while level < max_level and experience >= GameData.exp_to_next_level(level):
		experience -= GameData.exp_to_next_level(level)
		level += 1
	if level >= max_level:
		experience = 0
	check_missions() # level 9
	changed.emit()


## Max interest: 5, +1 per Gimmighoul Coin kept.
## computeIncome: +1 per Gimmighoul Coin, -1 per Amulet Coin (item bench and held).
func max_interest() -> int:
	var amulets := items.count("AMULET_COIN")
	for u in board.values():
		amulets += u.items.count("AMULET_COIN")
	return maxi(0, MAX_INTEREST + items.count("GIMMIGHOUL_COIN") - amulets)


## End of a round: 5 gold + 1 per 10 gold held (max 5), +2 xp.
func collect_income() -> int:
	var income := int(Difficulty.value("goldPerWave", BASE_INCOME)) + mini(gold / 10, max_interest())
	income += 5 * items.count("RED_SCALE") # Red Scale: +5 gold a round
	gold += income
	gold_earned += income
	add_experience(XP_PER_ROUND)
	return income
#endregion


#region units
func max_team_size() -> int:
	return level


## Pokémon on the board counting in the team size (pillars do not).
func team_count() -> int:
	var n := 0
	for u in board.values():
		if not u.is_inanimate() and not u.items.has("GOLD_BOW"): # Gold Bow: free slot
			n += 1
	return n


func board_units() -> Array:
	return board.values()


#region bench slots
## Not in the web game, where a bench slot holds one Pokémon: here a slot holds up to `bench_stack` copies
## of the same Pokémon (difficulty benchStack), so that a bench of 8 slots keeps two copies of each line
## waiting for the third. `bench` keeps one place per copy - place index = slot * bench_stack + layer, the
## front copy (layer 0) first - so that every list of the units owned (bench + board) sees them all.
## Locations: {"bench": slot, "layer": layer}. The game shows the front copy of a slot with the count;
## the copies behind it hold nothing (stackable()).

## Place index of the front of the first empty bench slot, -1 when every slot holds something.
func first_free_bench_slot() -> int:
	for s in bench_slots:
		if slot_units(s).is_empty():
			return s * bench_stack
	return -1


## {"bench": slot, "layer": layer} of a place of `bench`.
func bench_loc(index: int) -> Dictionary:
	return {"bench": index / bench_stack, "layer": index % bench_stack}


func _bench_index(loc: Dictionary) -> int:
	return int(loc.bench) * bench_stack + int(loc.get("layer", 0))


## The copies in bench slot `slot`, the front one first.
func slot_units(slot: int) -> Array:
	var out: Array = []
	if slot < 0:
		return out
	for layer in bench_stack:
		var i := slot * bench_stack + layer
		if i < bench.size() and bench[i] != null:
			out.append(bench[i])
	return out


## `back` may stand behind `front` in a bench slot: the same Pokémon (not an egg nor a pillar), `back`
## holding nothing (only the items of the front copy are shown).
static func stackable(front: OwnedUnit, back: OwnedUnit) -> bool:
	return front != null and back != null and front != back and front.pkm == back.pkm and front.pkm != "EGG" \
		and not front.is_inanimate() and back.items.is_empty() and back.tm == ""


## `units` sharing a slot, front first (the one holding items in front); [] when they cannot.
static func stack_order(units: Array) -> Array:
	if units.size() <= 1:
		return units.duplicate()
	var front: OwnedUnit = null
	for u in units:
		if not u.items.is_empty() or u.tm != "":
			if front != null:
				return []
			front = u
	if front == null:
		front = units[0]
	var out: Array = [front]
	for u in units:
		if u != front:
			if not stackable(front, u):
				return []
			out.append(u)
	return out


## Where `unit` joins the bench (bought, given, fished...): with the copies it stacks with, else in the
## first empty slot. A place index, -1 when there is no room.
func bench_index_for(unit: OwnedUnit) -> int:
	if bench_stack > 1:
		for s in bench_slots:
			var units := slot_units(s)
			if units.is_empty() or units.size() >= bench_stack or stack_order(units + [unit]).is_empty():
				continue
			for layer in bench_stack:
				if bench[s * bench_stack + layer] == null:
					return s * bench_stack + layer
	return first_free_bench_slot()


## A new copy of `pkm` has a place on the bench: an empty slot, or copies it stacks with.
func has_bench_room(pkm: String) -> bool:
	if first_free_bench_slot() >= 0:
		return true
	if bench_stack <= 1 or pkm == "EGG":
		return false
	for s in bench_slots:
		var units := slot_units(s)
		if not units.is_empty() and units.size() < bench_stack and units[0].pkm == pkm and not units[0].is_inanimate():
			return true
	return false


## Puts `unit` on the bench (bench_index_for); false when there is no room.
func put_on_bench(unit: OwnedUnit) -> bool:
	var i := bench_index_for(unit)
	if i < 0:
		return false
	bench[i] = unit
	_normalize_bench()
	return true


## Every slot keeps its copies front first, without a gap. Copies that cannot share their slot (put there
## by a power, or the tests) move to another slot, or stay behind their front copy when there is none.
func _normalize_bench() -> void:
	if bench_stack <= 1:
		return
	var leftovers: Array = [] # [unit, its slot]
	for s in bench_slots:
		var units := slot_units(s)
		var order := stack_order(units)
		if order.is_empty() and not units.is_empty(): # they cannot share it: the front one stays
			order = [units[0]]
			for u in units.slice(1):
				leftovers.append([u, s])
		for layer in bench_stack:
			bench[s * bench_stack + layer] = order[layer] if layer < order.size() else null
	for entry in leftovers:
		var i := bench_index_for(entry[0])
		if i < 0:
			for layer in range(1, bench_stack):
				if bench[int(entry[1]) * bench_stack + layer] == null:
					i = int(entry[1]) * bench_stack + layer
					break
		if i >= 0:
			bench[i] = entry[0]


## What dropping `unit` on `to` ({"board": cell} or {"bench": slot}) does: {"moves": [[unit, location],
## ...]}, every unit changing place, or {} when it cannot go there. A board cell holds one Pokémon, a bench
## slot copies of the same Pokémon; the units there swap with it, going where it came from when they fit
## there, else to an empty bench slot.
func _plan_move(unit: OwnedUnit, to: Dictionary) -> Dictionary:
	var from := find(unit)
	if from.is_empty() or to.is_empty():
		return {}
	if to.has("board"):
		var cell: Vector2i = to.board
		var other: OwnedUnit = board.get(cell)
		if not is_player_cell(cell) or unit.pkm == "EGG" or other == unit:
			return {}
		var needs_room := not from.has("board") and not unit.is_inanimate() and (other == null or other.is_inanimate())
		if needs_room and team_count() >= max_team_size():
			return {}
		if other == null:
			return {"moves": [[unit, {"board": cell}]]}
		if from.has("board"):
			return {"moves": [[unit, {"board": cell}], [other, from]]}
		var home := _rehome([other], int(from.bench), unit)
		return {} if home.is_empty() else {"moves": [[unit, {"board": cell}]] + home}
	var s := int(to.bench)
	if s < 0 or s >= bench_slots or (from.has("bench") and int(from.bench) == s):
		return {}
	var there := slot_units(s)
	if there.is_empty():
		return {"moves": [[unit, {"bench": s, "layer": 0}]]}
	if there.size() < bench_stack:
		var order := stack_order(there + [unit])
		if not order.is_empty():
			return {"moves": _slot_moves(s, order)}
	if from.has("board"): # what is there goes to the cell it leaves: one Pokémon, not an egg
		if there.size() != 1 or there[0].pkm == "EGG":
			return {}
		return {"moves": [[unit, {"bench": s, "layer": 0}], [there[0], from]]}
	var home := _rehome(there, int(from.bench), unit, s)
	return {} if home.is_empty() else {"moves": [[unit, {"bench": s, "layer": 0}]] + home}


## Where `units` go when `leaving` takes their place coming from bench slot `f`: into `f` (with the copies
## left there, when they stack), else into an empty slot other than `exclude`. Moves, [] when nowhere.
func _rehome(units: Array, f: int, leaving: OwnedUnit, exclude := -1) -> Array:
	var rest := slot_units(f).filter(func(u) -> bool: return u != leaving)
	var order := stack_order(rest + units)
	if not order.is_empty() and order.size() <= bench_stack:
		return _slot_moves(f, order)
	order = stack_order(units)
	for s in bench_slots:
		if s != f and s != exclude and slot_units(s).is_empty() and not order.is_empty():
			return _slot_moves(s, order)
	return []


static func _slot_moves(slot: int, units: Array) -> Array:
	var out: Array = []
	for i in units.size():
		out.append([units[i], {"bench": slot, "layer": i}])
	return out
#endregion


## {"bench": slot, "layer": layer} or {"board": cell}, {} if not owned.
func find(unit: OwnedUnit) -> Dictionary:
	for i in bench.size():
		if bench[i] == unit:
			return bench_loc(i)
	for cell in board:
		if board[cell] == unit:
			return {"board": cell}
	return {}


## The unit at a location; {"bench": slot} without a layer: the front copy of the slot.
func unit_at(loc: Dictionary) -> OwnedUnit:
	if loc.has("bench"):
		var i := _bench_index(loc)
		return bench[i] if i >= 0 and i < bench.size() else null
	if loc.has("board"):
		return board.get(loc.board)
	return null


static func is_player_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BattleBoard.WIDTH and cell.y >= 0 and cell.y < PLAYER_ROWS


## Whether `unit` may be dropped on `slot` ({"board": cell} or {"bench": slot}, see _plan_move): the team
## size (a unit coming from the bench onto an empty cell needs room; pillars never count), one Pokémon a
## cell, copies of the same Pokémon in a bench slot. Dropped where it is: yes (nothing happens).
func can_place(unit: OwnedUnit, slot: Dictionary) -> bool:
	if unit == null or slot.is_empty():
		return false
	var from := find(unit)
	if from.has("bench") and slot.has("bench") and int(from.bench) == int(slot.bench):
		return true
	if from.has("board") and slot.has("board") and from.board == slot.board:
		return true
	return not _plan_move(unit, slot).is_empty()


## Drag & drop: moves a unit to a bench slot or a board cell, swapping with the
## unit there. Fails if the board would exceed the team size.
func move_unit(unit: OwnedUnit, to: Dictionary) -> bool:
	var from := find(unit)
	if from.is_empty() or to.is_empty() or from == to:
		return false
	if from.has("bench") and to.has("bench") and int(from.bench) == int(to.bench):
		return false # back on its own slot
	var target := unit_at(to)
	if unit.pkm == "DITTO" and from.has("bench") and target != null and not target.is_inanimate():
		return ditto_copy(unit, target)
	if unit.pkm == "MELTAN" and target != null and target.pkm == "MELMETAL": # Meltan joins Melmetal: +50 max HP
		target.mods.maxHP = float(target.mods.get("maxHP", 0.0)) + 50.0
		items.append_array(unit.items)
		_remove_at(from)
		_board_changed()
		return true
	var plan := _plan_move(unit, to)
	if plan.is_empty():
		return false
	var origins: Array = []
	for m in plan.moves:
		origins.append(find(m[0]))
	for m in plan.moves:
		_remove_at(find(m[0]))
	for m in plan.moves:
		_set_at(m[1], m[0])
	for i in plan.moves.size(): # back from the board to the bench: the removable items go back
		if origins[i].has("board") and plan.moves[i][1].has("bench"):
			_unequip_on_bench(plan.moves[i][0])
	_board_changed()
	return true


## Ditto dropped from the bench on a Pokémon (OnDragDropPokemonCommand): it becomes the first form of
## that Pokémon (the player's alternative form) in the first free bench slot; its items go back to
## the item bench.
func ditto_copy(ditto: OwnedUnit, model: OwnedUnit) -> bool:
	var base: String = model.family()
	if base.begins_with("FLABEBE"):
		base = flower_color
	if not GameData.pokemon.has(base) or not GameData.is_available(base):
		return false
	var loc := find(ditto)
	items.append_array(ditto.items)
	_remove_at(loc)
	var copy := OwnedUnit.new(base)
	var free := bench_index_for(copy)
	if free >= 0:
		bench[free] = copy
	else:
		_set_at(loc, copy)
	EvolutionRules.on_acquired(self, copy)
	check_merges()
	_board_changed()
	return true


## OnDragDrop to the bench: Chef Hat, Trash, tools, scarves and the TM go back to the item bench.
func _unequip_on_bench(unit: OwnedUnit) -> void:
	var rks := unit.passive() == "RKS_SYSTEM" # Silvally: its memories (synergy items) too
	for item in unit.items.duplicate():
		if GameData.item_in(item, "RemovableItems") or (rks and GameData.item_in(item, "SynergyItems")):
			unit.items.erase(item)
			items.append(item)
	if unit.tm != "":
		items.append(SynergyItems.tm_item(unit.tm))
		unit.tm = ""


func _set_at(loc: Dictionary, unit: OwnedUnit) -> void:
	if loc.has("bench"):
		bench[_bench_index(loc)] = unit
	elif loc.has("board"):
		if unit == null:
			board.erase(loc.board)
		else:
			board[loc.board] = unit


func _remove_at(loc: Dictionary) -> void:
	_set_at(loc, null)


func _completes_merge(pkm: String) -> bool:
	var count := 0
	for u in bench + (board.values() if merge_board else []):
		if u != null and u.pkm == pkm:
			count += 1
	return count >= merge_count(pkm) - 1 and not GameData.evolutions_of(pkm).is_empty()


## Copies merging into the evolution (COUNT rule: 3; Magikarp 8, Feebas 6), 0 = none.
static func merge_count(pkm: String) -> int:
	var evolutions := GameData.evolutions_of(pkm)
	if evolutions.is_empty() or evolutions.has(pkm):
		return 0 # Wishiwashi School evolves into itself
	return int(GameData.get_pokemon(pkm).get("evolutionCount", 3))


## 3 copies of the same Pokémon evolve into one (kept where the first board copy
## was, else in the first bench slot). Repeats for 3 x 2★ -> 3★.
func check_merges() -> Array[Dictionary]:
	var merges: Array[Dictionary] = []
	var merged := true
	while merged:
		merged = false
		var groups := {}
		for u in (board.values() if merge_board else []) + bench:
			if u != null and not u.is_inanimate() and not u.items.has("EVIOLITE"): # Eviolite: stays as is
				if not groups.has(u.pkm):
					groups[u.pkm] = []
				groups[u.pkm].append(u)
		for pkm in groups:
			var copies: Array = groups[pkm]
			var needed := merge_count(pkm)
			if needed <= 0 or copies.size() < needed:
				continue
			var evolution := evolution_for(pkm, copies.slice(0, needed))
			var keep_loc := find(copies[0])
			var carried: Array[String] = []
			for i in needed:
				carried.append_array(copies[i].items)
				_remove_at(find(copies[i]))
			var evolved := OwnedUnit.new(evolution)
			_carry_items(evolved, carried)
			evolved.stacks = copies[0].stacks # stacks are not linked to the count rule
			for i in needed:
				for stat in copies[i].mods: # carryOverPermanentStats: the permanent buffs add up
					evolved.mods[stat] = float(evolved.mods.get(stat, 0.0)) + float(copies[i].mods[stat])
				evolved.supercharged = evolved.supercharged or copies[i].supercharged
				if copies[i].tm != "":
					if evolved.tm == "":
						evolved.tm = copies[i].tm
					else:
						items.append(SynergyItems.tm_item(copies[i].tm))
				for dish in copies[i].dishes:
					if not evolved.dishes.has(dish):
						evolved.dishes.append(dish)
			if keep_loc.has("bench") and int(keep_loc.bench) >= bench_slots: # the copy bought on a full bench
				var free := first_free_bench_slot()
				if free >= 0:
					keep_loc = bench_loc(free)
			_set_at(keep_loc, evolved)
			EvolutionRules.on_acquired(self, evolved)
			EvolutionRules.after_evolve(self, evolved, pkm)
			merges.append({"from": pkm, "to": evolution, "unit": evolved})
			merged = true
			break
	if not merges.is_empty():
		_normalize_bench()
		update_pillars()
	return merges


## Evolution of 3 copies: the divergent ones follow their web rule (divergentEvolution).
##   Poliwhirl (TADPOLE): Poliwrath if a copy stands on the front row, else Politoed
##   Espurr: Meowstic Male if PSYCHIC dominates FIELD, else Female
##   Kirlia: Gallade if FIGHTING dominates FAIRY, else Gardevoir
##   Galarian Slowpoke: Galarian Slowking if PSYCHIC dominates POISON, else Galarian Slowbro
##   Wurmple: Cascoon with POISON active, else Silcoon
##   Flabébé / Floette: keep their color
## A branch that is not ported falls back to one that is.
func evolution_for(pkm: String, copies: Array) -> String:
	var options := GameData.evolutions_of(pkm)
	if options.size() <= 1:
		return options[0] if not options.is_empty() else ""
	var wanted := ""
	var counts := Synergies.count_player(self)
	match GameData.get_pokemon(pkm).get("passive", ""):
		"TADPOLE":
			var front := false
			for c in copies:
				var loc := find(c)
				front = front or (loc.has("board") and loc.board.y == PLAYER_ROWS - 1)
			wanted = "POLIWRATH" if front else "POLITOED"
		"ESPURR":
			wanted = "MEOWSTIC_MALE" if Synergies.dominant(counts, ["PSYCHIC", "FIELD"]) == "PSYCHIC" else "MEOWSTIC_FEMALE"
		"KIRLIA":
			wanted = "GALLADE" if Synergies.dominant(counts, ["FIGHTING", "FAIRY"]) == "FIGHTING" else "GARDEVOIR"
		"GALARIAN_SLOWPOKE":
			wanted = "GALARIAN_SLOWKING" if Synergies.dominant(counts, ["PSYCHIC", "POISON"]) == "PSYCHIC" else "GALARIAN_SLOWBRO"
		"WURMPLE":
			wanted = "CASCOON" if Synergies.tier("POISON", counts.get("POISON", 0)) > 0 else "SILCOON"
		"SLOWPOKE":
			wanted = "SLOWKING" if Synergies.dominant(counts, ["PSYCHIC", "WATER"]) == "PSYCHIC" else "SLOWBRO"
		"BIVALVE":
			wanted = "HUNTAIL" if Synergies.dominant(counts, ["PSYCHIC", "DARK"]) == "DARK" else "GOREBYSS"
		"FLABEBE_COLOR":
			var color := pkm.trim_prefix("FLABEBE").trim_prefix("FLOETTE")
			var next := "FLOETTE" if pkm.begins_with("FLABEBE") else "FLORGES"
			wanted = next + color
	if wanted == "":
		if pkm == "CHERUBI": # Cherrim Sunlight on the light cell of an active LIGHT
			var lit := false
			for c in copies:
				var loc := find(c)
				lit = lit or (loc.has("board") and loc.board == light_cell)
			wanted = "CHERRIM_SUNLIGHT" if lit and Synergies.tier("LIGHT", counts.get("LIGHT", 0)) > 0 else "CHERRIM"
		else: # Dewott, Cubone, Pikachu...: the regional form of the region, else the usual one
			for o in options:
				if regional_pokemons.has(o):
					wanted = o
			if wanted == "":
				for o in options:
					if not GameData.regional_base.has(o):
						wanted = o
						break
	return wanted if options.has(wanted) else options[0]


## Items of the 3 merged copies (count-evolution-handler.ts): full items first, one
## component at most, 3 items at most; the others go to the item bench.
func _carry_items(evolved: OwnedUnit, carried: Array[String]) -> void:
	var fulls := carried.filter(func(i: String) -> bool: return not GameData.is_component(i))
	var components := carried.filter(func(i: String) -> bool: return GameData.is_component(i))
	for item in fulls:
		if evolved.items.has(item) or evolved.items.size() >= BattleUnit.MAX_ITEMS:
			items.append(item)
		else:
			evolved.items.append(item)
	for item in components:
		var has_component := evolved.items.any(func(i: String) -> bool: return GameData.is_component(i))
		if has_component or evolved.items.size() >= BattleUnit.MAX_ITEMS:
			items.append(item)
		else:
			evolved.items.append(item)


## A bought unit may sit in an extra bench slot until it merges.
func _compact_overflow() -> void:
	while bench.size() > bench_size:
		var extra = bench.pop_back()
		if extra != null:
			var free := bench_index_for(extra)
			if free >= 0:
				bench[free] = extra


## Fills the board from the bench up to the team size (like TFT when the
## planning timer ends): melee in front, long range in the back.
func auto_place() -> int:
	var placed := 0
	while team_count() < max_team_size():
		var slot := -1
		for i in bench_size:
			if bench[i] != null and not bench[i].is_inanimate():
				slot = i
				break
		if slot < 0:
			break
		var unit: OwnedUnit = bench[slot]
		var r := int(unit.data().get("range", 1))
		var rows: Array = [3, 2, 1, 0] if r <= 1 else ([2, 3, 1, 0] if r == 2 else [0, 1, 2, 3])
		var target: Variant = null
		for y in rows:
			for x in CENTER_OUT:
				if target == null and not board.has(Vector2i(x, y)):
					target = Vector2i(x, y)
		if target == null:
			break
		bench[slot] = null
		board[target] = unit
		placed += 1
	if placed > 0:
		_board_changed()
	return placed


## A Pokémon obtained from a choice (starter, Unique, additional pick): to the bench,
## merging right away if it completes 3 copies; sold when there is no room.
## Returns "bench", "merged" or "sold".
func give_pokemon(pkm: String) -> String:
	var unit := OwnedUnit.new(pkm)
	var free := bench_index_for(unit)
	if free >= 0:
		bench[free] = unit
	elif _completes_merge(pkm):
		bench.append(unit)
	else:
		gold += GameData.rarity_cost(unit.data().rarity) * unit.stars()
		changed.emit()
		return "sold"
	var merged := not check_merges().is_empty()
	_compact_overflow()
	_board_changed()
	return "merged" if merged else "bench"


## A random common first form on the board (tests; the game starts with the starter portal).
func give_starter() -> void:
	var commons := shop_candidates("COMMON").filter(func(pkm: String) -> bool:
		return not GameData.get_pokemon(pkm).types.has("WILD"))
	if commons.is_empty():
		return
	var pkm: String = commons[rng.randi() % commons.size()]
	take_copy(pkm)
	board[Vector2i(3, PLAYER_ROWS - 1)] = OwnedUnit.new(pkm)
	_board_changed()


## After any change of the board: pillars follow the Timburr line, then listeners.
func _board_changed() -> void:
	_normalize_bench()
	update_pillars()
	_update_position_forms()
	_sync_form_items()
	EvolutionRules.check_board(self, ["placement", "money"])
	SynergyItems.update_all(self)
	check_missions() # 3-star team, 8 synergies
	changed.emit()


## onAcquired / afterSell of Rotom and Ogerpon, giveNectarsAlreadyUnlocked of Oricorio: the
## items changing their form sit in the item bench while they are owned (Rotom Catalog, the
## masks Ogerpon does not wear, the nectars of the fully grown flower pots).
func _sync_form_items() -> void:
	var owned: Array = (bench + board.values()).filter(func(u) -> bool: return u != null)
	var passives: Array = owned.map(func(u: OwnedUnit) -> String: return u.passive())
	_keep_item("ROTOM_CATALOG", passives.has("ROTOM"))
	_keep_item("METEORITE", passives.has("ALIEN_DNA")) # Deoxys: choose its forme
	_keep_item("ZYGARDE_CUBE", passives.has("ZYGARDE")) # Zygarde: 10% <-> 50%
	_keep_item("MYSTERY_BOX", owned.any(func(u: OwnedUnit) -> bool: return u.pkm == "MELMETAL")) # Meltan in the shop
	var ogerpons := owned.filter(func(u: OwnedUnit) -> bool: return u.passive().begins_with("OGERPON_"))
	for mask in PassiveEffects.OGERPON_MASKS:
		var worn := ogerpons.any(func(u: OwnedUnit) -> bool: return u.items.has(mask))
		_keep_item(mask, not ogerpons.is_empty() and not worn)
	if passives.has("NECTAR"):
		for i in POT_NECTARS.size():
			if GameData.evolutions_of(flower_pots[i]).is_empty():
				_keep_item(POT_NECTARS[i], true)


func _keep_item(item: String, keep: bool) -> void:
	if keep and not items.has(item):
		items.append(item)
	while not keep and items.has(item):
		items.erase(item)


## OnChangePositionEffect / OnSpotlightChangeEffect of the board: Meloetta dances (Pirouette) on
## the front row, Necrozma / Cherrim take their light form in the spotlight (or with a Shiny Stone).
func _update_position_forms() -> void:
	# Illusion: moved, it takes the looks of the Pokémon on its left (if any; else keeps its disguise)
	for s in bench_slots:
		var left_units := slot_units(s - 1)
		for u in slot_units(s):
			_illusion(u, {"bench": s}, left_units[0] if not left_units.is_empty() else null)
	for cell in board:
		_illusion(board[cell], {"board": cell}, board.get(cell + Vector2i(-1, 0)))
	var light := synergy_tier("LIGHT") > 0
	for cell in board:
		var u: OwnedUnit = board[cell]
		var form := ""
		match u.passive():
			"MELOETTA":
				form = "PIROUETTE_MELOETTA" if cell.y == PLAYER_ROWS - 1 else "MELOETTA"
			"PRISM":
				var lit: bool = light and (cell == light_cell or u.items.has("SHINY_STONE"))
				form = "ULTRA_NECROZMA" if lit else "NECROZMA"
			"BLOSSOM":
				var lit: bool = light and (cell == light_cell or u.items.has("SHINY_STONE"))
				form = "CHERRIM_SUNLIGHT" if lit else "CHERRIM"
		if form != "" and form != u.pkm and GameData.is_available(form):
			u.pkm = form


func _illusion(u: OwnedUnit, slot: Dictionary, left: OwnedUnit) -> void:
	if u == null or u.passive() != "ILLUSION" or u.last_slot == slot:
		return
	u.last_slot = slot
	if left != null:
		u.look = left.look if left.look != "" else left.pkm


## Rotom Catalog choice: Rotom possesses another appliance.
func change_form(unit_id: int, pkm: String) -> void:
	for u in bench + board.values():
		if u != null and u.id == unit_id and GameData.is_available(pkm):
			u.pkm = pkm
			_board_changed()
			return


## Timburr (PILLAR): builds 1 / 1 / 2 pillars (wood / iron / concrete by its stars)
## on the front rows; they are removed when their builder leaves the board.
func update_pillars() -> void:
	var expected := [0, 0, 0]
	for u in board.values():
		if GameData.get_pokemon(u.family()).get("passive", "") == "PILLAR" or u.passive() == "PILLAR":
			expected[clampi(u.stars() - 1, 0, 2)] += 2 if u.pkm == "CONKELDURR" else 1
	for rank in 3:
		if not GameData.pokemon.has(PILLARS[rank]):
			continue
		var current: Array = []
		for u in bench + board.values():
			if u != null and u.pkm == PILLARS[rank]:
				current.append(u)
		while current.size() > expected[rank]:
			_remove_at(find(current.pop_back()))
		for _i in expected[rank] - current.size():
			var cell: Variant = _first_free_cell([3, 2, 1, 0])
			if cell == null:
				break
			board[cell] = OwnedUnit.new(PILLARS[rank])


func _first_free_cell(rows: Array) -> Variant:
	for y in rows:
		for x in BattleBoard.WIDTH:
			if not board.has(Vector2i(x, y)):
				return Vector2i(x, y)
	return null
#endregion


#region synergies between stages
func synergy_counts() -> Dictionary:
	return Synergies.count_player(self)


func synergy_tier(type: String) -> int:
	return Synergies.tier(type, synergy_counts().get(type, 0))


## Fairy: one wand per level reached, among the ones picked (in order).
func active_wands() -> Array[String]:
	var out: Array[String] = []
	out.assign(fairy_wands.slice(0, synergy_tier("FAIRY")))
	return out


## Wands to choose from when a new Fairy level is reached, [] if none pending.
func pending_wand_choice() -> Array:
	var n := fairy_wands.size()
	if n < synergy_tier("FAIRY") and n < wand_options.size():
		return wand_options[n]
	return []


func choose_wand(wand: String) -> void:
	if pending_wand_choice().has(wand):
		fairy_wands.append(wand)
		changed.emit()


## Web board context of a fight for the player's team (BattleSim.team_info).
func fight_info() -> Dictionary:
	var counts := synergy_counts()
	var dragon_stars := 0
	for u in board.values():
		if u.types().has("DRAGON"):
			dragon_stars += u.stars()
	return {
		"counts": counts,
		"active": Synergies.active_count(counts),
		"dragon_stars": dragon_stars,
		"light": light_cell if Synergies.tier("LIGHT", counts.get("LIGHT", 0)) > 0 else null,
		"holes": ground_holes.duplicate(),
		"wands": active_wands(),
		"stage": stage,
	}


## Before a fight (beforeSimulationStart): Lycanroc and Ursaluna change form with
## the weather; Fighting 4 marks the bench Fighting units training this fight.
func before_fight(weather: String) -> void:
	for cell in board:
		var u: OwnedUnit = board[cell]
		var form := ""
		match u.passive():
			"LYCANROC_DAY", "LYCANROC_NIGHT", "LYCANROC_DUSK":
				match weather:
					"NIGHT", "BLOODMOON": form = "LYCANROC_NIGHT"
					"ZENITH": form = "LYCANROC_DAY"
					"DROUGHT": form = "LYCANROC_DUSK"
			"BLOODMOON":
				if weather == "BLOODMOON":
					form = "URSALUNA_BLOODMOON"
		if form != "" and form != u.pkm and GameData.pokemon.has(form):
			u.pkm = form
	training_ids.clear()
	if synergy_tier("FIGHTING") >= 4:
		for s in bench_slots: # the first slot, and the ones right of a pillar
			var left_units := slot_units(s - 1)
			if s > 0 and (left_units.is_empty() or not PILLARS.has(left_units[0].pkm)):
				continue
			for u in slot_units(s):
				if u.types().has("FIGHTING"):
					training_ids.append(u.id)
	changed.emit()


## After a fight: the training Fighting units gain 4 ATK and 10% BASE max HP for good.
func after_fight() -> void:
	_normalize_bench() # copies absorbed from the bench during the fight leave gaps in their slots
	for u in bench + board.values():
		if u != null and training_ids.has(u.id):
			u.mods.atk = float(u.mods.get("atk", 0.0)) + TRAINING_ATK
			u.mods.maxHP = float(u.mods.get("maxHP", 0.0)) + ceilf(TRAINING_HP_RATIO * float(u.data().get("hp", 0)))
	training_ids.clear()


## Remembers Pokémon that joined the shop pool (`pick`: picked in town) for the "!" list.
func record_pool_news(pokemons: Array[String], rarity: String, pick := false) -> void:
	pool_news.append({"stage": stage, "rarity": rarity, "pokemons": pokemons, "pick": pick})
	pool_news_unread = true


## A town pick (additional pick): the family joins the shop now. In a season nothing joins: the
## Pokémon picked was in the shop already.
func unlock_additional(pkm: String) -> void:
	if GameData.season_active:
		return
	var base: String = GameData.regional_base.get(pkm, pkm)
	if not unlocked_additional.has(base):
		record_pool_news([pkm], String(GameData.get_pokemon(pkm).get("rarity", "")), true)
	unlocked_additional[base] = true
	update_regional_pool(false)


## Stage start (updatePlayerBetweenStages): additional families join the shop,
## Ground Pokémon dig, Bug 4 spawns a Bug, Fur Coat grows or gets groomed.
## Returns messages for the UI ("Found Big Nugget"...).
func start_stage() -> Array[String]:
	var messages: Array[String] = []
	if items.has("TREASURE_BOX") and life <= int(GameData.config.get("treasureBoxLifeThreshold", 40)):
		items.erase("TREASURE_BOX")
		messages.append(L.t("Treasure Box: %s") % Town.open_treasure_box(self, rng))
	var pick_stages: Array = GameData.config.get("additionalPickStages", [])
	var pick := pick_stages.find(float(stage))
	if pick < 0:
		pick = pick_stages.find(stage)
	if pick >= 0 and pick < ADDITIONAL_RARITIES.size():
		var joined: Array[String] = []
		for pkm in GameData.additional_tier1_by_rarity[ADDITIONAL_RARITIES[pick]]:
			unlocked_additional[pkm] = true
			joined.append(pkm)
		update_regional_pool(false) # their regional variants can now replace them
		if not joined.is_empty(): # one short line: the list is behind the "!" button of the shop
			record_pool_news(joined, ADDITIONAL_RARITIES[pick])
			messages.append(L.t("%d %s Pokémon joined the shop (see the ! button)") % [joined.size(),
				GameData.rarity_name(ADDITIONAL_RARITIES[pick])])
	var counts := synergy_counts()
	if Synergies.tier("GROUND", counts.get("GROUND", 0)) > 0:
		messages.append_array(_dig())
	if Synergies.tier("GRASS", counts.get("GRASS", 0)) > 0:
		SynergyItems.grow_berry_trees(self)
	if Synergies.tier("FIRE", counts.get("FIRE", 0)) >= 4 and not items.has("FIRE_SHARD") and life > 2:
		items.append("FIRE_SHARD")
	var fish := SynergyItems.fish(self)
	if fish != "":
		messages.append(L.t("Fished %s") % GameData.display_name(fish))
	messages.append_array(SynergyItems.cook(self))
	if Synergies.tier("BUG", counts.get("BUG", 0)) >= 4:
		var spawned := _bug_nest_spawn()
		if spawned != "":
			messages.append(L.t("%s hatched from the nest") % GameData.display_name(spawned))
	messages.append_array(_town_items_stage())
	for u in bench + board.values():
		if u == null or u.passive() != "FUR_COAT":
			continue
		if find(u).has("bench"):
			if u.stacks >= FUR_COAT_STACKS: # groomed: its fur makes a Silk Scarf
				items.append("SILK_SCARF")
				extra_scarves += 1
			u.stacks = 0
		else:
			u.stacks = mini(u.stacks + 1, FUR_COAT_STACKS)
	for pair in ROTTING_ITEMS: # apples rot a bit more every stage
		while items.has(pair[0]):
			items.erase(pair[0])
			items.append(pair[1])
	for u in bench + board.values():
		if u == null:
			continue
		match u.passive():
			"CREAM": # Milcery: the flavor of the synergy most present around it
				_milcery_flavor(u)
			"PACHIRISU": # 30% chance to dig up a Sitrus Berry
				if rng.randf() < 0.3:
					items.append("SITRUS_BERRY")
					messages.append(L.t("%s found %s") % [GameData.display_name(u.pkm), GameData.item_name("SITRUS_BERRY")])
	messages.append_array(EvolutionRules.check_board(self, ["state", "stack"]))
	changed.emit()
	return messages


## MilceryFlavorEffect: the flavor of the synergy of the most adjacent allies on the board (Normal
## by default) replaces the flavor in the item bench.
func _milcery_flavor(u: OwnedUnit) -> void:
	var loc := find(u)
	var around := {}
	if loc.has("board"):
		for cell in board:
			if board[cell] != u and maxi(absi(cell.x - loc.board.x), absi(cell.y - loc.board.y)) == 1:
				for t in board[cell].types():
					around[t] = int(around.get(t, 0)) + 1
	var best := "NORMAL"
	for t in GameData.config.get("synergyThresholds", {}): # SynergyArray order: the first one wins a tie
		if int(around.get(t, 0)) > int(around.get(best, 0)):
			best = t
	for flavor in GameData.items_in("Flavors"):
		items.erase(flavor)
	items.append(SYNERGY_FLAVORS.get(best, "VANILLA_FLAVOR"))


## Stage start of the town items: Dojo trainees come back, the outlaw shows up, the
## mission orders done pay 30 gold.
func _town_items_stage() -> Array[String]:
	var messages: Array[String] = []
	for entry in dojo.duplicate():
		if int(entry.return_stage) > stage:
			continue
		dojo.erase(entry)
		var unit: OwnedUnit = entry.unit
		var sub: OwnedUnit = entry.sub
		var loc := find(sub)
		if loc.is_empty():
			var free := first_free_bench_slot()
			if free < 0:
				continue
			loc = bench_loc(free)
		else:
			unit.items.assign(sub.items)
		var level := clampi(int(entry.level), 1, 3) - 1
		unit.mods.maxHP = float(unit.mods.get("maxHP", 0.0)) + [50.0, 100.0, 150.0][level]
		unit.mods.atk = float(unit.mods.get("atk", 0.0)) + [5.0, 10.0, 15.0][level]
		unit.mods.ap = float(unit.mods.get("ap", 0.0)) + [15.0, 30.0, 45.0][level]
		if unit.pkm == "PIKACHU" and GameData.pokemon.has("PIKACHU_LIBRE"):
			unit.pkm = "PIKACHU_LIBRE"
		if not loc.is_empty() and unit_at(loc) == sub:
			_remove_at(loc)
		_set_at(loc, unit)
		messages.append(L.t("%s is back from the Dojo") % GameData.display_name(unit.pkm))
		check_merges()
	# spawnWanderingPokemons: the outlaw of the Wanted Notice runs across the screen at its stage
	# (click it to catch it); before that, Magnemite (or Magnezone) look for it
	if outlaw_stage >= 0 and items.has("WANTED_NOTICE"):
		if stage == outlaw_stage:
			wanderers.append({"pkm": "DROWZEE", "kind": "outlaw", "behavior": "run", "delay": rng.randf_range(5.0, 20.0)})
		elif stage < outlaw_stage:
			if rng.randf() < stage * 0.04:
				wanderers.append({"pkm": "MAGNEZONE", "kind": "dialog", "behavior": "run", "delay": rng.randf_range(5.0, 20.0)})
			else:
				for _i in rng.randi_range(1, 3):
					wanderers.append({"pkm": "MAGNEMITE", "kind": "dialog", "behavior": "run", "delay": rng.randf_range(5.0, 20.0)})
	messages.append_array(check_missions())
	return messages


## A wanderer clicked (OnWandererClickedCommand): the catchable one joins the bench if there is
## room (false otherwise: it stays), the outlaw gives 10 gold for the Wanted Notice.
func catch_wanderer(data: Dictionary) -> bool:
	match String(data.get("kind", "")):
		"catchable":
			var pkm := String(data.pkm)
			if not has_bench_room(pkm) and not _completes_merge(pkm):
				return false
			give_pokemon(pkm)
		"outlaw":
			gold += Town.OUTLAW_GOLD
			gold_earned += Town.OUTLAW_GOLD
			items.erase("WANTED_NOTICE")
			EvolutionRules.check_board(self, ["money"])
	changed.emit()
	return true


## shop.magnetPull: a Steel Pokémon of the shop pool (its copy leaves the pool) of a rarity drawn
## with the shop odds of the level and 35 for Meltan, AP and LUCK favoring the end of the list
## (rarer ones, Meltan).
func magnet_pull_pick(ap: float, luck: float) -> String:
	var odds := GameData.shop_odds(level)
	var weights: Array = []
	for i in GameData.SHOP_RARITIES.size():
		weights.append(float(odds[i]) if i < odds.size() else 0.0)
	var roll := rng.randf() * 1.35 * (1.0 + ap * 0.5 / 100.0) * (1.0 + luck / 100.0)
	var rarity := "SPECIAL"
	for i in weights.size():
		roll -= float(weights[i])
		if roll < 0.0:
			rarity = GameData.SHOP_RARITIES[i]
			break
	if rarity != "SPECIAL":
		var shown := pool_entries(rarity)
		var finals := finalized_lines()
		var candidates: Array = shown.keys().filter(func(pkm: String) -> bool:
			return not finals.has(pkm) and copies_left(pkm) > 0 \
				and GameData.get_pokemon(shown[pkm]).get("types", []).has("STEEL"))
		var total := 0
		for pkm in candidates:
			total += copies_left(pkm)
		if total > 0:
			var pick := rng.randi() % total
			for pkm in candidates:
				pick -= copies_left(pkm)
				if pick < 0:
					take_copy(pkm)
					return shown[pkm]
	return "MELTAN"


## Wigglytuff's mission orders held in the item bench: done = +30 gold.
func check_missions() -> Array[String]:
	var messages: Array[String] = []
	for order in Town.MISSION_ORDERS:
		if not items.has(order):
			continue
		var done := false
		match order:
			"MISSION_ORDER_PINK":
				done = board.values().filter(func(u: OwnedUnit) -> bool: return u.stars() >= 3).size() >= 4
			"MISSION_ORDER_BLUE":
				done = level >= 9
			"MISSION_ORDER_GREEN":
				done = Synergies.tiers(synergy_counts()).size() >= 8
			"MISSION_ORDER_GOLD":
				done = gold_earned >= 200
		if done:
			items.erase(order)
			gold += Town.MISSION_GOLD
			messages.append(L.t("Mission complete: +%d gold") % Town.MISSION_GOLD)
	return messages


## Ground: every Ground Pokémon on the board digs its cell one level deeper; at the
## max depth it finds what is buried there.
func _dig() -> Array[String]:
	var messages: Array[String] = []
	var gourmet := synergy_tier("GOURMET") > 0
	for cell in board:
		var u: OwnedUnit = board[cell]
		if not u.types().has("GROUND") or (u.items.has(SynergyItems.CHEF_HAT) and gourmet):
			continue
		var depth := int(ground_holes.get(cell, 0))
		if depth >= MAX_HOLE_DEPTH:
			continue
		ground_holes[cell] = depth + 1
		match u.passive(): # OnGroundDiggingEffect
			"DUNSPARCE":
				u.stacks += 1
			"ORTHWORM":
				u.mods.maxHP = float(u.mods.get("maxHP", 0.0)) + 5.0
		if depth + 1 == MAX_HOLE_DEPTH and not buried_items.has(cell) and u.items.has("EXPLORER_KIT"):
			# Explorer Kit: something is found even where nothing was buried
			var roll := rng.randf()
			buried_items[cell] = "BIG_NUGGET" if roll < 0.1 else ("NUGGET" if roll < 0.55 else "COIN")
		if depth + 1 == MAX_HOLE_DEPTH and buried_items.has(cell):
			var found: String = buried_items[cell]
			buried_items.erase(cell)
			messages.append(L.t("Found %s") % _collect_buried(found))
	return messages


## What a buried item gives: gold (Coin 1, Nugget 3, Big Nugget 10), 2 components
## (Treasure Box), +1 synergy (gems), nothing (Trash); the items not ported yet
## (Metal Coat...) become a random component.
func _collect_buried(item: String) -> String:
	var name := GameData.item_name(item)
	match item:
		"COIN":
			gold += 1
		"NUGGET":
			gold += 3
		"BIG_NUGGET":
			gold += 10
		"TREASURE_BOX":
			for _i in 2:
				add_item(_pick(EndlessWaves.item_pool("component")))
		"TRASH":
			pass
		"FOSSIL_STONE", "LEFTOVERS": # a component (evolution stones) and a dish
			add_item(item)
		_:
			var gem_type := GameData.item_synergy(item)
			if GameData.item_in(item, "SynergyGems") and gem_type != "":
				add_gem(item)
				name += " (+1 %s)" % GameData.synergy_name(gem_type)
			elif GameData.item_in(item, "Tools"):
				add_item(item)
			else:
				var component := _pick(EndlessWaves.item_pool("component"))
				add_item(component)
				name += " -> " + GameData.item_name(component)
	return name


## Stoutland: barks when standing on a cell hiding an item.
func has_buried_item(cell: Vector2i) -> bool:
	return buried_items.has(cell) and int(ground_holes.get(cell, 0)) < MAX_HOLE_DEPTH


## Bug 4: a copy of the lowest rarity Bug not fully evolved hatches on the bench.
func _bug_nest_spawn() -> String:
	var best: OwnedUnit = null
	for u in bench + board.values():
		if u == null or not u.types().has("BUG") or GameData.evolutions_of(u.pkm).is_empty():
			continue
		if best == null or GameData.rarity_cost(u.data().rarity) < GameData.rarity_cost(best.data().rarity):
			best = u
	if best == null:
		return ""
	var base := best.family()
	if not GameData.pokemon.has(base) or not put_on_bench(OwnedUnit.new(base)):
		return ""
	check_merges()
	return base
#endregion


#region items
## What the fight gave (BattleSim.rewards: golden berries...).
func collect_fight_rewards(rewards: Dictionary) -> void:
	gold += int(rewards.get("gold", 0))
	EvolutionRules.check_board(self, ["money"])
	gold_earned += int(rewards.get("gold", 0))
	free_rolls += int(rewards.get("free_rolls", 0))
	cell_battery += int(rewards.get("cell_battery", 0))
	if int(rewards.get("life", 0)) > 0: # Time Travel (Celebi)
		life = mini(100, life + int(rewards.life))
	if int(rewards.get("exp", 0)) > 0: # Knowledge Thief
		add_experience(int(rewards.exp))
	SynergyItems.collect_mulch(self, int(rewards.get("mulch", 0)))
	while cell_battery >= 100:
		cell_battery -= 100
		items.append("CELL_BATTERY")
	for item in rewards.get("items", []):
		items.append(item)
	for pkm in rewards.get("pokemon", []): # spawned on the bench (Order Up...)
		if GameData.pokemon.has(pkm) and put_on_bench(OwnedUnit.new(pkm)):
			check_merges()
	changed.emit()


func add_item(item: String) -> void:
	items.append(item)
	changed.emit()


## A synergy gem (buried, Sableye): +1 to its synergy for the rest of the run.
func add_gem(gem: String) -> void:
	var type := GameData.item_synergy(gem)
	if type != "":
		bonus_synergies[type] = int(bonus_synergies.get(type, 0)) + 1
	add_item(gem)


## An item picked in the town: Gimmighoul Coins also give 5 gold, gems a synergy.
func take_town_item(item: String) -> void:
	if GameData.item_in(item, "SynergyGems"):
		add_gem(item)
		return
	if item == "EGG_FOR_SELL": # Chansey: a random egg on the bench
		var slot := first_free_bench_slot()
		if slot >= 0:
			bench[slot] = SynergyItems.make_egg(self)
			changed.emit()
		return
	if item == "GIMMIGHOUL_COIN":
		gold += Town.GIMMIGHOUL_GOLD
	if item == "SILK_SCARF": # Cinccino: counts for the Normal scarves
		extra_scarves += 1
	add_item(item)


## What dropping item bench slot `index` on `unit` would do (game-commands.ts
## OnDragDropItemCommand): {ok, result, combine?, reason}. Two components make the
## full item of their recipe; a Pokémon holds 3 items at most, never twice the same full item.
func equip_preview(index: int, unit: OwnedUnit) -> Dictionary:
	if unit == null or index < 0 or index >= items.size():
		return {"ok": false, "reason": ""}
	if unit.is_inanimate():
		return {"ok": false, "reason": "Cannot hold items"}
	var item := items[index]
	if GameData.item_in(item, "Dishes"):
		# game-commands.ts: a dish dropped on a Pokémon is eaten
		if SynergyItems.can_eat(unit) and not unit.dishes.has(item):
			return {"ok": true, "result": item, "eat": true}
		return {"ok": false, "reason": "Belly full" if not unit.dishes.is_empty() else "Not hungry"}
	if item == "FIRE_SHARD":
		if not unit.types().has("FIRE"):
			return {"ok": false, "reason": "Only Fire Pokémon can use it"}
		if life <= 3:
			return {"ok": false, "reason": "Not enough life"}
		return {"ok": true, "result": item, "use": true}
	if item == "CELL_BATTERY":
		if not unit.types().has("ELECTRIC") or unit.supercharged:
			return {"ok": false, "reason": "Only an Electric Pokémon not supercharged yet"}
		return {"ok": true, "result": item, "use": true}
	match item:
		"SOOTHE_BELL": # Chimecho: the shop is rolled again with the types of this Pokémon
			return {"ok": true, "result": item, "use": true}
		"PICNIC_SET": # Munchlax: a Sandwich for it and every hungry neighbour
			if not SynergyItems.can_eat(unit):
				return {"ok": false, "reason": "Not hungry"}
			return {"ok": true, "result": item, "use": true}
		"RECYCLE_TICKET": # Wobbuffet: its full items fall apart into components
			if not unit.items.any(func(i: String) -> bool: return not GameData.recipe_of(i).is_empty()):
				return {"ok": false, "reason": "No item to recycle"}
			return {"ok": true, "result": item, "use": true}
		"EXCHANGE_TICKET":
			return {"ok": false, "reason": "Drop it on an item of the item bench"}
		"LAPRAS_PASSPORT": # Lapras: a ride to the region sharing the most synergies with it
			return {"ok": true, "result": item, "use": true}
		"BRONZE_DOJO_TICKET", "SILVER_DOJO_TICKET", "GOLD_DOJO_TICKET":
			if unit.pkm == "SUBSTITUTE" or find(unit).is_empty():
				return {"ok": false, "reason": "Cannot go to the Dojo"}
			return {"ok": true, "result": item, "use": true}
	if Town.SEVEN_TREASURES.has(item):
		return {"ok": false, "reason": "Keep it in the item bench"}
	match item:
		"METEORITE": # Deoxys: choose its forme; the meteorite stays
			if unit.passive() != "ALIEN_DNA":
				return {"ok": false, "reason": "Only Deoxys can use it"}
			return {"ok": true, "result": item, "use": true, "keep": true}
		"ZYGARDE_CUBE": # Zygarde: 10% <-> 50%; the cube stays
			if unit.passive() != "ZYGARDE" or not ["ZYGARDE_10", "ZYGARDE_50"].has(unit.pkm):
				return {"ok": false, "reason": "Only Zygarde can use it"}
			return {"ok": true, "result": item, "use": true, "keep": true}
		"AUSPICIOUS_ARMOR", "MALICIOUS_ARMOR": # Charcadet evolves with it
			if unit.passive() != "CHARCADET":
				return {"ok": false, "reason": "Only Charcadet can wear it"}
			return {"ok": true, "result": item, "special": true}
		"SCROLL_OF_WATERS", "SCROLL_OF_DARKNESS": # Kubfu evolves with it
			if unit.passive() != "KUBFU":
				return {"ok": false, "reason": "Only Kubfu can read it"}
			return {"ok": true, "result": item, "special": true}
	if GameData.item_in(item, "Flavors"): # Milcery evolves with it
		if unit.skill() != "DECORATE":
			return {"ok": false, "reason": "Only Milcery can use it"}
		return {"ok": true, "result": item, "special": true}
	if GameData.item_in(item, "MemoryDiscs") and unit.family() != "TYPE_NULL":
		return {"ok": false, "reason": "Only Type: Null and Silvally can hold it"}
	if GameData.item_in(item, "SynergyStones") and unit.types().has(GameData.item_synergy(item)):
		return {"ok": false, "reason": "Already of this type"}
	if item == "ROTOM_CATALOG": # Rotom: choose the appliance it possesses; the catalog stays
		if unit.passive() != "ROTOM":
			return {"ok": false, "reason": "Only Rotom can use it"}
		return {"ok": true, "result": item, "use": true, "keep": true}
	if NECTAR_FORMS.has(item): # Oricorio: changes its style; the nectar stays
		if unit.passive() != "NECTAR" or unit.pkm == NECTAR_FORMS[item]:
			return {"ok": false, "reason": "Only Oricorio of another style"}
		return {"ok": true, "result": item, "use": true, "keep": true}
	if PassiveEffects.OGERPON_MASKS.has(item): # Ogerpon wears it (instead of its mask)
		if not unit.passive().begins_with("OGERPON_"):
			return {"ok": false, "reason": "Only Ogerpon can wear it"}
		var masked := unit.items.any(func(i: String) -> bool: return PassiveEffects.OGERPON_MASKS.has(i))
		if not masked and unit.items.size() >= BattleUnit.MAX_ITEMS:
			return {"ok": false, "reason": "Already holds 3 items"}
		return {"ok": true, "result": item, "mask": true}
	if GameData.item_in(item, "TMs"):
		if not unit.types().has("HUMAN"):
			return {"ok": false, "reason": "Only Human Pokémon can learn it"}
		return {"ok": true, "result": item, "teach": SynergyItems.tm_ability(item)}
	if GameData.item_in(item, "UnholdableItems"):
		return {"ok": false, "reason": "Cannot be held"}
	if item == SynergyItems.CHEF_HAT and not unit.types().has("GOURMET"):
		return {"ok": false, "reason": "Only Gourmet Pokémon can wear it"}
	if item == "EVIOLITE" or item == "RARE_CANDY":
		if _next_form(unit) == "":
			return {"ok": false, "reason": "Cannot evolve"}
		if item == "RARE_CANDY" and unit.items.has("EVIOLITE"):
			return {"ok": false, "reason": "Holds an Eviolite"}
	var is_component := GameData.is_component(item)
	var held_component := ""
	for held in unit.items:
		if GameData.is_component(held):
			held_component = held
	if is_component and held_component != "":
		var result := GameData.combine(held_component, item)
		if result == "":
			return {"ok": false, "reason": "No recipe"}
		return {"ok": true, "result": result, "combine": held_component}
	if unit.items.size() >= BattleUnit.MAX_ITEMS:
		return {"ok": false, "reason": "Already holds 3 items"}
	if not is_component and unit.items.has(item):
		return {"ok": false, "reason": "Already held"}
	return {"ok": true, "result": item}


func equip(index: int, unit: OwnedUnit) -> Dictionary:
	var preview := equip_preview(index, unit)
	if not preview.ok:
		return preview
	var item := items[index]
	if not preview.get("keep", false):
		items.remove_at(index)
	if preview.get("eat", false):
		unit.dishes.append(item)
		# game-commands.ts: the dish is held just in time for the item evolution (Applin + an apple,
		# Dipplin + a Sirupy Apple); the form acquired eats it (EvolutionRules.on_acquired)
		unit.items.append(item)
		var eaten_into := _item_evolution(unit)
		unit.items.erase(item)
		if eaten_into != "":
			preview.evolved = eaten_into
			EvolutionRules.on_acquired(self, unit)
			check_merges()
			_board_changed()
		changed.emit()
		return preview
	if preview.get("mask", false): # ogerponMaskEffect: the mask worn sets the form
		for mask in PassiveEffects.OGERPON_MASKS:
			unit.items.erase(mask)
		unit.items.append(item)
		unit.pkm = PassiveEffects.OGERPON_MASKS[item] + "_MASK"
		preview.evolved = unit.pkm
		_board_changed() # the other masks come back to the item bench
		return preview
	if preview.get("special", false): # held, then the item evolution takes it (Charcadet, Kubfu, Milcery)
		unit.items.append(item)
		var into := _item_evolution(unit)
		if into != "":
			preview.evolved = into
			EvolutionRules.on_acquired(self, unit)
			check_merges()
		_board_changed()
		return preview
	if preview.get("use", false):
		if item == "ROTOM_CATALOG":
			var forms := ROTOM_FORMS.filter(func(p: String) -> bool: return p != unit.pkm and GameData.is_available(p))
			preview.choice = {"kind": "pokemon", "category": "form", "pokemons": forms, "items": [], "unit": unit.id}
		elif item == "METEORITE":
			var forms := DEOXYS_FORMS.filter(func(p: String) -> bool: return p != unit.pkm and GameData.is_available(p))
			preview.choice = {"kind": "pokemon", "category": "form", "pokemons": forms, "items": [], "unit": unit.id}
		elif item == "ZYGARDE_CUBE":
			var other := "ZYGARDE_50" if unit.pkm == "ZYGARDE_10" else "ZYGARDE_10"
			if GameData.is_available(other):
				unit.pkm = other
				preview.evolved = other
				_board_changed()
		elif NECTAR_FORMS.has(item):
			unit.pkm = NECTAR_FORMS[item]
			preview.evolved = unit.pkm
			_board_changed() # its types change with its style
		elif item == "FIRE_SHARD": # +3 ATK and +3 SPEED for good, for 3 life
			unit.mods.atk = float(unit.mods.get("atk", 0.0)) + 3.0
			unit.mods.speed = float(unit.mods.get("speed", 0.0)) + 3.0
			life = maxi(life - 3, 1)
		elif item == "CELL_BATTERY":
			unit.supercharged = true
		elif item == "LAPRAS_PASSPORT":
			var types := unit.types()
			var best := -1
			var maps: Array = []
			for m in GameData.config.get("maps", {}):
				if m == map or m == "town":
					continue
				var common: int = GameData.config.maps[m].get("synergies", []).filter(
					func(s: String) -> bool: return types.has(s)).size()
				if common > best:
					best = common
					maps = [m]
				elif common == best:
					maps.append(m)
			if not maps.is_empty():
				change_map(maps[rng.randi() % maps.size()])
				preview.map = map
		elif item.ends_with("_DOJO_TICKET"):
			var loc := find(unit)
			var sub := OwnedUnit.new("SUBSTITUTE")
			sub.items.assign(unit.items)
			unit.items.clear()
			_remove_at(loc)
			_set_at(loc, sub)
			dojo.append({"unit": unit, "sub": sub, "return_stage": stage + 3,
				"level": {"BRONZE_DOJO_TICKET": 1, "SILVER_DOJO_TICKET": 2, "GOLD_DOJO_TICKET": 3}[item]})
			SynergyItems.update_all(self)
		elif item == "SOOTHE_BELL":
			var odds := GameData.shop_odds(level)
			_release_shop()
			for i in shop.size():
				set_shop_slot(i, _roll_one(odds, 0.0, unit.types()))
		elif item == "PICNIC_SET":
			var here := find(unit)
			for cell in board:
				var o: OwnedUnit = board[cell]
				var near: bool = o == unit or (here.has("board") \
					and maxi(absi(cell.x - here.board.x), absi(cell.y - here.board.y)) <= 1)
				if near and SynergyItems.can_eat(o) and not o.dishes.has("SANDWICH"):
					o.dishes.append("SANDWICH")
		elif item == "RECYCLE_TICKET":
			for held in unit.items.duplicate():
				var recipe := GameData.recipe_of(held)
				if not recipe.is_empty():
					unit.items.erase(held)
					items.append_array(recipe)
				elif GameData.is_component(held):
					unit.items.erase(held)
					items.append(held)
			SynergyItems.update_all(self)
		changed.emit()
		return preview
	if preview.has("teach"):
		if unit.tm != "":
			items.append(SynergyItems.tm_item(unit.tm)) # the previous TM comes back
		unit.tm = preview.teach
		changed.emit()
		return preview
	if preview.has("combine"):
		if preview.combine == "SILK_SCARF" or item == "SILK_SCARF":
			SynergyItems.scarf_crafted(self, preview.result)
		unit.items.erase(preview.combine)
		if unit.items.has(preview.result):
			items.append(preview.result) # already held: the new one pops to the item bench
		else:
			unit.items.append(preview.result)
	else:
		unit.items.append(item)
	if item == "RARE_CANDY": # evolves right away, keeps the candy
		unit.pkm = _next_form(unit)
		preview.evolved = unit.pkm
	elif item == "SURFBOARD" and unit.pkm == "PIKACHU" and GameData.is_available("PIKACHU_SURFER"):
		unit.pkm = "PIKACHU_SURFER"
		preview.evolved = unit.pkm
	elif item == "SHINY_STONE":
		var passive := String(unit.data().get("passive", ""))
		var form := "ULTRA_NECROZMA" if passive == "PRISM" else ("CHERRIM_SUNLIGHT" if passive == "BLOSSOM" else "")
		if form != "" and form != unit.pkm and GameData.pokemon.has(form):
			unit.pkm = form
			preview.evolved = form
	var evolved := _item_evolution(unit)
	if evolved != "":
		preview.evolved = evolved
		EvolutionRules.on_acquired(self, unit)
	if preview.has("evolved"):
		check_merges()
	SynergyItems.update_all(self) # an item may give a synergy (stones)
	changed.emit()
	return preview


## Exchange / Recycle Ticket dropped on another item of the item bench (game-commands.ts
## OnDragDropCombineCommand): exchange = a random item of the same kind, recycle = its 2
## components. {ok, result?, reason?}.
func use_ticket(ticket_index: int, item_index: int) -> Dictionary:
	if ticket_index == item_index or ticket_index < 0 or item_index < 0 \
			or ticket_index >= items.size() or item_index >= items.size():
		return {"ok": false}
	var ticket := items[ticket_index]
	var item := items[item_index]
	if not ["EXCHANGE_TICKET", "RECYCLE_TICKET"].has(ticket):
		return {"ok": false}
	var result: Array[String] = []
	if ticket == "EXCHANGE_TICKET":
		var pool: Array = []
		if GameData.is_component(item) and item != "SILK_SCARF":
			pool = EndlessWaves.item_pool("component")
		elif GameData.item_in(item, "SynergyStones"):
			pool = GameData.items_in("SynergyStones")
		elif GameData.full_items.has(item) and not GameData.item_in(item, "Scarves"):
			pool = EndlessWaves.item_pool("full")
		pool = pool.filter(func(i: String) -> bool: return i != item)
		if pool.is_empty():
			return {"ok": false, "reason": "Cannot be exchanged"}
		result.append(pool[rng.randi() % pool.size()])
	else:
		var recipe := GameData.recipe_of(item)
		if recipe.is_empty():
			return {"ok": false, "reason": "No item to recycle"}
		result.assign(recipe)
	for i in [maxi(ticket_index, item_index), mini(ticket_index, item_index)]:
		items.remove_at(i)
	items.append_array(result)
	changed.emit()
	return {"ok": true, "result": result}


## Item Remover (port only, not in `items`: a permanent tool of the item bench, unlimited
## uses): every item `unit` holds goes back to the item bench, so items can be moved
## without selling the Pokémon. {ok, count} or {ok: false, reason}.
func strip_preview(unit: OwnedUnit) -> Dictionary:
	if unit == null:
		return {"ok": false, "reason": ""}
	var count := _removable_items(unit).size()
	if count == 0:
		return {"ok": false, "reason": "No item to remove"}
	return {"ok": true, "count": count}


## Removes the held items of `unit` (see strip_preview) and returns them.
func strip_items(unit: OwnedUnit) -> Array[String]:
	var removed := _removable_items(unit)
	for item in removed:
		unit.items.erase(item)
		items.append(item)
	if not removed.is_empty():
		SynergyItems.update_all(self)
		changed.emit()
	return removed


## Held items that can be taken off: all but the one that made an item evolution
## (Primal Kyogre keeps its Blue Orb, else it would stay Primal without it).
func _removable_items(unit: OwnedUnit) -> Array[String]:
	var out: Array[String] = []
	out.assign(unit.items)
	var pre := GameData.get_pokemon(GameData.prevolution(unit.pkm))
	if String(pre.get("evolutionRule", "")) == "item":
		for trigger in pre.get("evolutionItems", []):
			if out.has(trigger):
				out.erase(trigger)
				break
	return out


## The form a Rare Candy gives (EvolutionManager.getEvolution): the next form of the line.
func _next_form(unit: OwnedUnit) -> String:
	var data := unit.data()
	var next := String(data.get("evolution", ""))
	if next == "":
		var options: Array = data.get("evolutions", [])
		if not options.is_empty():
			next = evolution_for(unit.pkm, [unit])
	return next if GameData.pokemon.has(next) else ""


## ITEM evolutions (item-evolution-handler.ts): Kyogre + Blue Orb -> Primal Kyogre,
## Groudon + Red Orb, Rayquaza + Green Orb. Returns the new form or "".
func _item_evolution(unit: OwnedUnit) -> String:
	var data := unit.data()
	if String(data.get("evolutionRule", "")) != "item" or unit.items.has("EVIOLITE"): # item-evolution-handler.ts canEvolve
		return ""
	var by_item: Dictionary = data.get("evolutionByItem", {})
	for item in unit.items:
		if by_item.has(item) and GameData.pokemon.has(by_item[item]):
			unit.pkm = by_item[item] # Eevee + Water Stone -> Vaporeon...
			return unit.pkm
	if String(data.get("evolution", "")) == "":
		return ""
	var triggers: Array = data.get("evolutionItems", [])
	if not unit.items.any(func(i: String) -> bool: return triggers.has(i)):
		return ""
	if not GameData.pokemon.has(data.evolution):
		return ""
	unit.pkm = data.evolution
	return unit.pkm
#endregion
