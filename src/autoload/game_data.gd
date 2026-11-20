extends Node

## Autoload "GameData": static data of the game.
##
## data/pac/*.json is generated from the web project (pokemonAutoChess) by
## tools/export_pac.bat -> offline/godot-export.ts. Never edit those by hand.
## data/abilities.json holds the abilities ported to Godot (see docs/ABILITIES.md),
## data/item_effects.json the item numbers and tooltip templates (see docs/ITEMS.md).
## data/balance.json: the auto balance (tools/bot/autobalance.py, docs/BOT.md), multipliers on top of the web stats.
## The attack range of a caster / marksman is raised to the range of its role (UnitRoles.ROLES, _apply_role_ranges).

const SHOP_RARITIES: Array[String] = ["COMMON", "UNCOMMON", "RARE", "EPIC", "ULTRA"]
const BALANCED_STATS: Array[String] = ["hp", "atk", "def", "speDef", "speed", "maxPP"] # stats the auto balance may change

const RARITY_COLORS := {
	"COMMON": Color("#9e9e9e"),
	"UNCOMMON": Color("#4caf50"),
	"RARE": Color("#2196f3"),
	"EPIC": Color("#9c27b0"),
	"ULTRA": Color("#f44336"),
	"UNIQUE": Color("#ffeb3b"),
	"LEGENDARY": Color("#ffc107"),
}

const TYPE_COLORS := {
	"NORMAL": Color("#a8a878"), "GRASS": Color("#78c850"), "FIRE": Color("#f08030"),
	"WATER": Color("#6890f0"), "ELECTRIC": Color("#f8d030"), "FIGHTING": Color("#c03028"),
	"PSYCHIC": Color("#f85888"), "DARK": Color("#705848"), "STEEL": Color("#b8b8d0"),
	"GROUND": Color("#e0c068"), "POISON": Color("#a040a0"), "DRAGON": Color("#7038f8"),
	"FIELD": Color("#c69c6d"), "MONSTER": Color("#7a5c3c"), "HUMAN": Color("#e7a07a"),
	"AQUATIC": Color("#3cb4c8"), "BUG": Color("#a8b820"), "FLYING": Color("#a890f0"),
	"FLORA": Color("#f4a6c8"), "ROCK": Color("#b8a038"), "GHOST": Color("#705898"),
	"FAIRY": Color("#ee99ac"), "ICE": Color("#98d8d8"), "FOSSIL": Color("#a0826d"),
	"SOUND": Color("#e57fb2"), "ARTIFICIAL": Color("#8fa3b0"), "BABY": Color("#ffc0cb"),
	"LIGHT": Color("#fff59d"), "WILD": Color("#8d6e63"), "AMORPHOUS": Color("#b39ddb"),
	"GOURMET": Color("#ffb74d"),
}

## Fallback when a Pokémon uses an ability that is not ported yet.
const DEFAULT_ABILITY := {
	"name": "Strike",
	"desc": "Deals 30/60/120 special damage to the target (placeholder: ability not ported).",
	"approx": true,
	"steps": [{"area": "single", "effects": [{"type": "damage", "values": [30, 60, 120, 240]}]}],
}

var pokemon: Dictionary = {}          # name -> data (stats, types, evolution...)
var abilities: Dictionary = {}        # ability id -> definition
var pve_stages: Dictionary = {}       # stage (int) -> {name, avatar, board, statBoosts, items, reward}
var config: Dictionary = {}           # shop odds, costs, xp table, synergy numbers, endless tunables...
## Auto balance (data/balance.json, not in the web game): "pokemon": form -> its own multipliers {"hp", "atk", "skill"
## (base AP 100 (m - 1): its skill x m), "def", "speDef", "speed"} (a number = the same for hp, atk and skill).
var balance: Dictionary = {}
var balance_id := "0"                  # its "version" (the autobalance step that wrote it; bot batches record it)
var _web_stats: Dictionary = {}       # form -> its stats of the web data (BALANCED_STATS), for use_balance(false)
var _web_ranges: Dictionary = {}      # form -> its range of the web data, when its role gives more (_apply_role_ranges)
var delays: Dictionary = {}           # sprite index -> {d, t} attack hit timing
var pool: Array[String] = []          # Pokémon of the shop (and of the wild waves)
var additional: Array[String] = []    # additional-pick families: join the shop at their stage
var extras: Array[String] = []        # forms reached in a fight or by a passive (pillars, Zen mode...)
var unique: Array[String] = []        # Unique Pokémon offered by the portal of stage 10
var legendary: Array[String] = []     # Legendary Pokémon offered by the portal of stage 20
var unique_duos: Array[String] = []   # duos offered by the portal of stage 10 (DUOS keys)
var legendary_duos: Array[String] = []  # duos offered by the portal of stage 20
var hatch: Array[String] = []         # lines hatching from Baby eggs (1★ = what an egg gives)
var regional: Array[String] = []      # regional lines: in the shop of some regions only, regional variants
var regional_info: Dictionary = {}    # regional Pokémon -> {maps, requires} (isInRegion of each region)
var regional_variants: Dictionary = {}  # form -> its regional variants (Vulpix -> [Alolan Vulpix])
var regional_base: Dictionary = {}    # regional variant -> family of the form it replaces
var tier1_by_rarity: Dictionary = {}  # rarity -> Array[String] first forms of the shop
var additional_tier1_by_rarity: Dictionary = {}  # rarity -> first forms of the additional families
var wild_tier1_by_rarity: Dictionary = {}  # rarity -> first forms of the wild waves (both)
var items: Dictionary = {}            # item id -> {name, desc, stats, recipe, synergy, categories}
var item_categories: Dictionary = {}  # category of app/types/enum/Item.ts -> Array[String]
var item_components: Array[String] = []  # the 10 components (Fossil Stone and Silk Scarf included)
var full_items: Array[String] = []    # items made of two components
var item_effects: Dictionary = {}     # item id -> {params, desc, stats} (data/item_effects.json)
var text: Dictionary = {}             # names / descriptions in the current language (see set_language)
var language := "en"
var languages: Dictionary = {}        # code -> name of the language (data/pac/languages.json)

var _base_text: Dictionary = {}       # English texts (data/pac/text.json)
var _port_texts: Dictionary = {}      # hand-written texts of the current language (data/i18n/<code>.json)
var _bosses: Dictionary = {}          # PvE boss names
var _prevolutions: Dictionary = {}    # pkm -> the form it evolves from
var _recipes: Dictionary = {}         # "A+B" (sorted) -> full item
var _template_re: RegEx
var _textures: Dictionary = {}        # path -> Texture2D or null


func _ready() -> void:
	pokemon = _load_json("res://data/pac/pokemon.json")
	_apply_balance()
	abilities = _load_json("res://data/abilities.json")
	abilities.erase("_doc")
	_apply_role_ranges()
	config = _load_json("res://data/pac/config.json")
	delays = _load_json("res://data/pac/delays.json")
	_base_text = _load_json("res://data/pac/text.json")
	text = _base_text
	languages = _load_json("res://data/pac/languages.json")
	var stages := _load_json("res://data/pac/pve_stages.json")
	for key in stages:
		pve_stages[int(key)] = stages[key]
		if stages[key] is Dictionary and stages[key].get("board") is Array:
			stages[key].board = fit_wave_board(stages[key].board)
	var pool_data := _load_json("res://data/pac/pool.json")
	for pkm in pool_data.get("pool", []):
		if pokemon.has(pkm):
			pool.append(pkm)
	for pkm in pool_data.get("additional", []):
		if pokemon.has(pkm):
			additional.append(pkm)
	for pkm in pool_data.get("extras", []):
		if pokemon.has(pkm):
			extras.append(pkm)
	for pkm in pool_data.get("unique", []):
		if pokemon.has(pkm):
			unique.append(pkm)
	for pkm in pool_data.get("hatch", []):
		if pokemon.has(pkm):
			hatch.append(pkm)
	for pkm in pool_data.get("legendary", []):
		if pokemon.has(pkm):
			legendary.append(pkm)
	for pkm in pool_data.get("regional", []):
		if pokemon.has(pkm):
			regional.append(pkm)
	unique_duos.assign(pool_data.get("uniqueDuos", []))
	legendary_duos.assign(pool_data.get("legendaryDuos", []))
	# Deerling: only the form of the current season joins the shop (game-room.ts)
	var season := current_season()
	for form in ["DEERLING_SPRING", "DEERLING_SUMMER", "DEERLING_AUTUMN", "DEERLING_WINTER"]:
		if not form.ends_with(season.to_upper()):
			additional.erase(form)
	regional_info = config.get("regional", {})
	regional_variants = config.get("regionalVariants", {})
	for base in regional_variants:
		for variant in regional_variants[base]:
			regional_base[variant] = String(get_pokemon(base).get("family", base))
	_index_first_forms()
	for pkm in pool_data.get("bosses", []):
		_bosses[pkm] = true
	var item_data := _load_json("res://data/pac/items.json")
	items = item_data.get("items", {})
	item_categories = item_data.get("categories", {})
	item_components.assign(item_categories.get("ItemComponents", []))
	full_items.assign(item_categories.get("CraftableItems", []))
	for item in full_items:
		var recipe: Array = items[item].recipe
		_recipes[_recipe_key(recipe[0], recipe[1])] = item
	item_effects = _load_json("res://data/item_effects.json")
	item_effects.erase("_doc")
	# Battle Pass: what the export holds is kept aside, then the locked synergies are hidden
	for pkm in pokemon:
		pokemon[pkm]["all_types"] = pokemon[pkm].get("types", []).duplicate()
	for map in config.get("maps", {}):
		config.maps[map]["all_synergies"] = config.maps[map].get("synergies", []).duplicate()
	_full = {"pool": pool.duplicate(), "additional": additional.duplicate(), "unique": unique.duplicate(),
		"legendary": legendary.duplicate(), "hatch": hatch.duplicate(), "regional": regional.duplicate(),
		"unique_duos": unique_duos.duplicate(), "legendary_duos": legendary_duos.duplicate(),
		"full_items": full_items.duplicate(),
		# what a season replaces (Seasons): the thresholds of some synergies, the regional data
		"thresholds": config.get("synergyThresholds", {}).duplicate(true), "regional_info": regional_info,
		"regional_variants": regional_variants, "regional_base": regional_base}
	_infer_regional_links()
	apply_progression()


## First forms of the shop rarities: the shop's, the additional ones, and both for the wild waves.

## A web enemy board ([pkm, x, y] with x 0..7, y 1..3) on the 7 columns of the hex board: x * 6 / 7
## rounded, a taken cell moves to the closest free one of its row (EndlessWaves.to_sim_cell).
static func fit_wave_board(board: Array) -> Array:
	var used := {}
	var out: Array = []
	for entry in board:
		if not (entry is Array) or entry.size() < 3:
			out.append(entry)
			continue
		var y := int(entry[2])
		var want := clampi(roundi(float(entry[1]) * (BattleBoard.WIDTH - 1) / 7.0), 0, BattleBoard.WIDTH - 1)
		var x := want
		for d in BattleBoard.WIDTH:
			for cand in [want - d, want + d]:
				if cand >= 0 and cand < BattleBoard.WIDTH and not used.has(Vector2i(cand, y)):
					x = cand
					break
			if not used.has(Vector2i(x, y)):
				break
		used[Vector2i(x, y)] = true
		var fitted: Array = entry.duplicate()
		fitted[1] = x
		out.append(fitted)
	return out

func _index_first_forms() -> void:
	for rarity in SHOP_RARITIES:
		tier1_by_rarity[rarity] = [] as Array[String]
		additional_tier1_by_rarity[rarity] = [] as Array[String]
		wild_tier1_by_rarity[rarity] = [] as Array[String]
	for pkm in pool + additional:
		var data: Dictionary = pokemon[pkm]
		if int(data.stars) == 1 and tier1_by_rarity.has(data.rarity):
			(tier1_by_rarity if pool.has(pkm) else additional_tier1_by_rarity)[data.rarity].append(pkm)
			wild_tier1_by_rarity[data.rarity].append(pkm)


#region Battle Pass: the synergies still locked (Progression, data/progression.json)
## Every synergy is unlocked: nothing is hidden (the fast path of the checks below).
var all_unlocked := true
var _unlocked: Dictionary = {}        # synergy -> true
var _gates: Array = []                # locked synergies keeping their whole families out (gatedBy)
var _full: Dictionary = {}            # the lists as exported, before the locks: pool, additional...
var _regional_links: Dictionary = {}  # regional Pokémon -> the region synergies it lives by


## Synergies unlocked for this run only (not in the web game): reaching a region unlocks its synergies
## the Battle Pass has not until the run ends (PlayerState.change_map -> unlock_for_run). Cleared when a
## run starts and in the main menu (begin_run).
var run_unlocked: Array[String] = []


## A synergy the Battle Pass of the player has unlocked, or a region of this run.
func synergy_unlocked(type: String) -> bool:
	return all_unlocked or _unlocked.has(type)


## A run starts / the menu opens: no synergy unlocked by a region any more, the pass alone.
func begin_run() -> void:
	run_unlocked.clear()
	apply_progression()


## The synergies of `map` that reaching it would unlock for the run (locked by the pass, not unlocked
## by a region yet).
func region_unlocks(map: String) -> Array[String]:
	var out: Array[String] = []
	for s in config.get("maps", {}).get(map, {}).get("all_synergies", []):
		if not synergy_unlocked(s) and config.get("synergyThresholds", {}).has(s):
			out.append(s)
	return out


## Unlocks the synergies of `map` for the rest of the run (region_unlocks): the locks are applied
## again, so their Pokémon, items and region Pokémon come back; the waves already built stay as they
## are. Only adds: nothing is locked again before the run ends. Returns the synergies unlocked.
func unlock_for_run(map: String) -> Array[String]:
	var fresh := region_unlocks(map)
	if not fresh.is_empty():
		run_unlocked.append_array(fresh)
		apply_progression(true)
	return fresh


## The synergies of the game in the web order (Synergy enum) without the locked ones. Code listing
## "every synergy" for the player uses this, not config.synergyThresholds.
func synergies() -> Array[String]:
	var out: Array[String] = []
	for type in config.get("synergyThresholds", {}):
		if synergy_unlocked(type):
			out.append(type)
	return out


## A Pokémon the season and the pass let appear: its family is in the roster of the season, has an
## unlocked synergy (first form) and no locked gating one (WILD). For the pass, Pokémon without any
## type (Arceus, Kecleon, eggs, pillars) always do. The SPECIAL ones always do: they come from a
## mechanic and not from a pool (Ditto, Meltan, fished Magikarp / Remoraid, Falinks troopers, summons).
func pokemon_unlocked(pkm: String) -> bool:
	var data := get_pokemon(pkm)
	if String(data.get("rarity", "")) == "SPECIAL":
		return true
	if season_active and not _season_families.has(String(data.get("family", pkm))):
		return false # not in the roster of the season
	if all_unlocked:
		return true
	var first: Dictionary = pokemon.get(String(data.get("family", pkm)), data)
	var types: Array = first.get("all_types", [])
	if types.is_empty():
		return true
	var open := false
	for t in types:
		if _gates.has(t):
			return false
		open = open or _unlocked.has(t)
	return open


## An item giving a synergy still locked (stone, gem, tool, memory disc): left out of the random
## pools (items_in, full_items); held anyway, it gives its stats but no type (item_synergy).
func item_locked(item: String) -> bool:
	if all_unlocked:
		return false
	var given := String(items.get(item, {}).get("synergy", ""))
	return given != "" and not _unlocked.has(given)


## One of the lists as exported, whatever the pass hides: pool, additional, unique, legendary, hatch,
## regional (the ported content, for the menu and the tools).
func full_list(list_name: String) -> Array:
	return _full.get(list_name, [])


## The synergy thresholds as exported, whatever the season (a season replaces some: Seasons.thresholds).
func full_thresholds() -> Dictionary:
	return _full.get("thresholds", {})


#region season: the fixed roster of the run (Seasons, data/seasons.json)
## A season applies: the lists hold its roster only, the shop is whole from the first stage
## (`additional` and `regional` are empty) and no Pokémon depends on the region.
var season_active := false
var _season_families: Dictionary = {}  # family -> true: shop, Unique, Legendary and hatch lines of the season


## The roster and the thresholds of the season picked (Seasons.current), or the web game's again.
func _apply_season() -> void:
	season_active = Seasons.active()
	_season_families.clear()
	for list in Seasons.LISTS:
		for family in Seasons.families(list):
			_season_families[family] = true
	var own := Seasons.thresholds()
	var thresholds: Dictionary = config.get("synergyThresholds", {})
	for type in _full.thresholds:
		var tiers: Array = _full.thresholds[type]
		var replaced = own.get(type)
		thresholds[type] = replaced if replaced is Array and replaced.size() == tiers.size() else tiers
	# no regional pool and no regional variant in a season: every Pokémon of the roster is its own line
	regional_info = {} if season_active else _full.regional_info
	regional_variants = {} if season_active else _full.regional_variants
	regional_base = {} if season_active else _full.regional_base
#endregion


## Applies the season (Seasons), then the Battle Pass (Progression.unlocked_synergies).
## Season: only its roster stays in the lists; its shop families are all in `pool` (the additional
## and regional ones too), some synergies get thresholds of their own.
## Pass: the locked synergies leave the types of every Pokémon and region; the families left
## without any leave the pools (shop, additional picks, Unique / Legendary, eggs, regional, wild
## waves: is_available() is false for them); the items giving a locked synergy leave the item
## pools. Called when the game starts, by the main menu and at the start of a run (begin_run); during
## a run only by unlock_for_run (a region unlocks synergies: the Pokémon owned gain types, never
## lose one). `keep_waves`: the Endless waves already built are kept.
func apply_progression(keep_waves := false) -> void:
	_apply_season()
	_unlocked.clear()
	for type in Progression.unlocked_synergies() + run_unlocked:
		_unlocked[type] = true
	all_unlocked = config.get("synergyThresholds", {}).keys().all(func(t: String) -> bool: return _unlocked.has(t))
	_gates = [] if all_unlocked else Progression.gated_types().filter(func(t: String) -> bool: return not _unlocked.has(t))
	var open := func(t: String) -> bool: return all_unlocked or _unlocked.has(t)
	for pkm in pokemon:
		pokemon[pkm]["types"] = pokemon[pkm].all_types.filter(open)
	for map in config.get("maps", {}):
		config.maps[map]["synergies"] = config.maps[map].all_synergies.filter(open)
	if season_active:
		pool.assign((_full.pool + _full.additional + _full.regional).filter(pokemon_unlocked))
		additional.clear()
		regional.clear()
	else:
		pool.assign(_full.pool.filter(pokemon_unlocked))
		additional.assign(_full.additional.filter(pokemon_unlocked))
		regional.assign(_full.regional.filter(pokemon_unlocked))
	unique.assign(_full.unique.filter(pokemon_unlocked))
	legendary.assign(_full.legendary.filter(pokemon_unlocked))
	hatch.assign(_full.hatch.filter(pokemon_unlocked))
	var duo_open := func(duo: String) -> bool: return DUOS.get(duo, []).all(pokemon_unlocked)
	unique_duos.assign(_full.unique_duos.filter(duo_open))
	legendary_duos.assign(_full.legendary_duos.filter(duo_open))
	_index_first_forms()
	full_items.assign(_full.full_items.filter(func(i: String) -> bool: return not item_locked(i)))
	if not keep_waves:
		EndlessWaves.clear_cache()


## The region synergies each regional Pokémon lives by, read back from its exported regions (the web
## rule isInRegion is code: a type of the variant its base has not, or a list of its own): a synergy
## whose regions nearly all have the Pokémon. While all of them found in a region are locked, the
## Pokémon is not found there (in_region); a region none of them explains keeps it.
func _infer_regional_links() -> void:
	var maps_with := {}
	for map in config.get("maps", {}):
		for s in config.maps[map].all_synergies:
			if not maps_with.has(s):
				maps_with[s] = []
			maps_with[s].append(map)
	for pkm in regional_info:
		var maps: Array = regional_info[pkm].get("maps", [])
		var links: Array = []
		for s in maps_with:
			var shared: int = maps_with[s].filter(func(m: String) -> bool: return maps.has(m)).size()
			if shared >= 0.75 * maps_with[s].size():
				links.append(s)
		_regional_links[pkm] = links


## The synergies that bring `pkm` to `map` (_region_link_unlocked): the region's synergies among its links,
## or, in a region none of its links explains, among its own types (Shellos East Sea: found in the Aquatic
## regions by its type, its only link being Rock); [] = the region keeps it whatever is unlocked.
func region_reasons(pkm: String, map: String) -> Array:
	var region: Array = config.get("maps", {}).get(map, {}).get("all_synergies", [])
	var links: Array = _regional_links.get(pkm, [])
	var here: Array = region.filter(func(s: String) -> bool: return links.has(s))
	if here.is_empty():
		var own: Array = get_pokemon(pkm).get("all_types", get_pokemon(pkm).get("types", []))
		here = region.filter(func(s: String) -> bool: return own.has(s))
	return here


func _region_link_unlocked(pkm: String, map: String) -> bool:
	if all_unlocked:
		return true
	var here := region_reasons(pkm, map)
	return here.is_empty() or here.any(func(s: String) -> bool: return _unlocked.has(s))
#endregion


func get_pokemon(pkm: String) -> Dictionary:
	return pokemon.get(pkm, {})


## PkmDuos (types/enum/Pokemon.ts): pairs offered together by the portals, sold half price.
const DUOS := {"LATIOS_LATIAS": ["LATIOS", "LATIAS"], "PLUSLE_MINUN": ["PLUSLE", "MINUN"],
	"ILLUMISE_VOLBEAT": ["ILLUMISE", "VOLBEAT"], "NINJASK_SHEDINJA": ["NINJASK", "SHEDINJA"],
	"INDEEDEE": ["INDEEDEE_FEMALE", "INDEEDEE_MALE"], "BASCULIN_RED_BLUE": ["BASCULIN_RED", "BASCULIN_BLUE"]}


## Season of today's date (northern hemisphere, game-room.ts): spring from March 20, summer June 22,
## autumn September 23, winter December 21.
static func current_season() -> String:
	var d := Time.get_date_dict_from_system()
	var day := int(d.month) * 100 + int(d.day)
	if day >= 320 and day < 622:
		return "spring"
	if day >= 622 and day < 923:
		return "summer"
	if day >= 923 and day < 1221:
		return "autumn"
	return "winter"


## The duo `pkm` belongs to ("" if none).
func duo_of(pkm: String) -> String:
	for duo in DUOS:
		if DUOS[duo].has(pkm):
			return duo
	return ""


## A Pokémon the port can show (shop, additional, Unique, Legendary, extra form or boss).
func is_available(pkm: String) -> bool:
	for list in [pool, additional, regional, extras, unique, legendary, hatch]:
		if list.has(pkm):
			return true
	return _bosses.has(pkm)


#region regions
## isInRegion (pokemon.ts): a regional Pokémon is found in the regions sharing one of its
## types (its variant base's types excluded). With `unlocked` (the additional families
## that joined the shop), the ones replacing an additional form need that form unlocked.
func in_region(pkm: String, map: String, unlocked = null) -> bool:
	if season_active: # the roster of a season is found in every region
		return true
	var info: Dictionary = regional_info.get(pkm, {})
	if not info.get("maps", []).has(map) or not _region_link_unlocked(pkm, map):
		return false
	var requires := String(info.get("requires", ""))
	return unlocked == null or requires == "" or unlocked.has(requires)


## The ported regional Pokémon of a region, fewest stars first (PRECOMPUTED_REGIONAL_MONS).
func regional_in(map: String, unlocked = null) -> Array[String]:
	var out: Array[String] = []
	for pkm in regional_info:
		if is_available(pkm) and in_region(pkm, map, unlocked):
			out.append(pkm)
	return out


## The ported variants of `pkm` found in a region (Vulpix -> Alolan Vulpix in an Ice region).
func variants_in_region(pkm: String, map: String) -> Array:
	return regional_variants.get(pkm, []).filter(func(v: String) -> bool:
		return is_available(v) and in_region(v, map))


## isRegionalVariant: one form is a regional variant of the other.
func is_regional_variant(a: String, b: String) -> bool:
	return regional_variants.get(a, []).has(b) or regional_variants.get(b, []).has(a)
#endregion


## Next COUNT evolutions of a form: its evolution, or the ported branches of a
## divergent one (Poliwhirl -> Politoed / Poliwrath). Empty for a final form.
func evolutions_of(pkm: String) -> Array[String]:
	var data := get_pokemon(pkm)
	var out: Array[String] = []
	if String(data.get("evolutionRule", "count")) != "count":
		return out
	if data.get("evolution", "") != "":
		out.append(data.evolution)
		return out
	for e in data.get("evolutions", []):
		if is_available(e):
			out.append(e)
	return out


## The form `pkm` evolves from ("" for a first form). Mitosis spawns it.
func prevolution(pkm: String) -> String:
	if _prevolutions.is_empty():
		for p in pokemon:
			for e in [pokemon[p].get("evolution", "")] + Array(pokemon[p].get("evolutions", [])):
				if e != "":
					_prevolutions[e] = p
	return String(_prevolutions.get(pkm, ""))


func get_ability(ability_id: String) -> Dictionary:
	return abilities.get(ability_id, DEFAULT_ABILITY)


func is_ability_ported(ability_id: String) -> bool:
	return abilities.has(ability_id)


## Name shown in the UI: the web game name ("Farfetch'd"), else MEGA_RAYQUAZA -> "Mega Rayquaza".
func display_name(pkm: String) -> String:
	var name = text.get("pkm", {}).get(pkm)
	return String(name) if name is String and name != "" else pkm.replace("_", " ").capitalize()


#region languages
## Texts of a language: the web game translation (data/pac/lang/<code>.json) and the
## texts written for the port (data/i18n/<code>.json) over the English ones; what a
## translation lacks stays in English.
func set_language(code: String) -> void:
	language = code if languages.has(code) else "en"
	text = _base_text.duplicate(true)
	_port_texts = {}
	if language != "en":
		_merge_texts(_load_json_optional("res://data/pac/lang/%s.json" % language))
		_port_texts = _load_json_optional("res://data/i18n/%s.json" % language)
		_merge_texts(_port_texts)


func _merge_texts(extra: Dictionary) -> void:
	for section in extra:
		var values = extra[section]
		if not values is Dictionary:
			continue
		if not text.has(section) or not text[section] is Dictionary:
			text[section] = {}
		for key in values:
			var v = values[key]
			if v is Array and text[section].get(key) is Array:
				var merged: Array = text[section][key].duplicate()
				for i in mini(v.size(), merged.size()):
					if v[i] is String and v[i] != "":
						merged[i] = v[i]
				text[section][key] = merged
			elif v is String and v != "":
				text[section][key] = v


## Ability name / description: the port ones in English, else the translation.
func ability_name(ability_id: String) -> String:
	var ported := String(get_ability(ability_id).get("name", ability_id))
	if language == "en":
		return ported
	return String(text.get("ability", {}).get(ability_id, ported))


func ability_desc(ability_id: String) -> String:
	var ported := String(get_ability(ability_id).get("desc", ""))
	if language == "en":
		return ported
	var own = _port_texts.get("ability_port", {}).get(ability_id)
	if own is String:
		return own
	return String(text.get("ability_description", {}).get(ability_id, ported))
#endregion


func rarity_cost(rarity: String) -> int:
	return int(config.rarityCost.get(rarity, 1))


## Copies of each first form in the shared pool, by rarity and family size.
func pool_size(pkm: String) -> int:
	var data := get_pokemon(pkm)
	var sizes: Array = config.poolSize.get(data.rarity, [0, 0, 0])
	var stages := family_stages(pkm)
	return int(sizes[clampi(stages - 1, 0, sizes.size() - 1)])


func family_stages(pkm: String) -> int:
	var stages := 1
	var current := pkm
	while not evolutions_of(current).is_empty() and stages < 4:
		current = evolutions_of(current)[0]
		stages += 1
	return stages


## Walks the COUNT evolution line until the wanted star level (first branch of a
## divergent evolution, or a random one when `rng` is given).
func evolve_to(pkm: String, stars: int, rng: RandomNumberGenerator = null) -> String:
	var current := pkm
	while int(get_pokemon(current).get("stars", 1)) < stars:
		var nexts := evolutions_of(current)
		if nexts.is_empty() or not pokemon.has(nexts[0]):
			break
		if get_pokemon(current).get("passive", "") == "FLABEBE_COLOR":
			# Flabébé keeps its color
			var color := current.trim_prefix("FLABEBE").trim_prefix("FLOETTE")
			var same := nexts.filter(func(n: String) -> bool: return n.trim_prefix("FLOETTE").trim_prefix("FLORGES") == color)
			if not same.is_empty():
				current = same[0]
				continue
		current = nexts[rng.randi() % nexts.size()] if rng != null else nexts[0]
	return current


func exp_to_next_level(level: int) -> int:
	return int(config.expTable.get(str(level), 255))


func shop_odds(level: int) -> Array:
	return config.rarityProbabilityPerLevel.get(str(clampi(level, 1, 10)), [1, 0, 0, 0, 0])


func sprite_path(index: String) -> String:
	return "res://assets/pokemons/%s.json" % index


func portrait(pkm: String) -> Texture2D:
	var index := String(get_pokemon(pkm).get("index", "0000"))
	var texture := _texture("res://assets/portraits/%s.png" % index)
	if texture == null and index.contains("-"): # a form without a portrait of its own (Flabébé colours): its base form's
		texture = _texture("res://assets/portraits/%s.png" % index.get_slice("-", 0))
	return texture


#region items
func get_item(item: String) -> Dictionary:
	return items.get(item, {})


func item_name(item: String) -> String:
	if language != "en" and text.get("item", {}).has(item):
		return String(text.item[item])
	return String(items.get(item, {}).get("name", text.get("item", {}).get(item, item.capitalize())))


func is_component(item: String) -> bool:
	return item_components.has(item)


## The 2 components of a full item ([] for a component or an item without recipe).
func recipe_of(item: String) -> Array[String]:
	var out: Array[String] = []
	var recipe = items.get(item, {}).get("recipe")
	if recipe is Array:
		out.assign(recipe)
	return out


## Full item made of two components, "" if none.
func combine(a: String, b: String) -> String:
	return _recipes.get(_recipe_key(a, b), "")


## [[other component, result]] for every recipe using `component` (right click on an item).
func recipes_with(component: String) -> Array:
	var out := []
	for other in item_components:
		var result := combine(component, other)
		if result != "":
			out.append([other, result])
	return out


func item_icon(item: String) -> Texture2D:
	return _texture(item_icon_path(item))


## Items of the port without their own icon -> the web icon they use.
const ITEM_ICON_ALIASES := {"ITEM_REMOVER": "TOOLBOX"}


func item_icon_path(item: String) -> String:
	return "res://assets/items/%s.png" % ITEM_ICON_ALIASES.get(item, item)


## Synergy an item gives to its holder (evolution stones, gems...), "" if none or if the Battle Pass
## has not unlocked that synergy yet.
func item_synergy(item: String) -> String:
	var given := String(items.get(item, {}).get("synergy", ""))
	return given if given == "" or synergy_unlocked(given) else ""


func item_in(item: String, category: String) -> bool:
	return item_categories.get(category, []).has(item)


## Items of a category of app/types/enum/Item.ts (Berries, Tools, ShinyItems...), without the ones
## giving a synergy still locked (item_locked); item_in() still knows them.
func items_in(category: String) -> Array[String]:
	var out: Array[String] = []
	out.assign(item_categories.get(category, []) if all_unlocked
		else item_categories.get(category, []).filter(func(i: String) -> bool: return not item_locked(i)))
	return out


## Stats of an item: the web game ones, overridden by data/item_effects.json.
func item_stats(item: String) -> Dictionary:
	var stats: Dictionary = items.get(item, {}).get("stats", {})
	var override = item_effects.get(item, {}).get("stats")
	if override is Dictionary:
		stats = stats.duplicate()
		stats.merge(override, true)
	return stats


## Number used by the item code (data/item_effects.json "params").
func item_param(item: String, key: String, default: Variant = 0.0) -> Variant:
	return item_effects.get(item, {}).get("params", {}).get(key, default)


## Description shown in tooltips (English, with the web game keywords: ATK, BURN...):
## the template of data/item_effects.json filled with its params, else the web text.
func item_desc(item: String) -> String:
	var template = item_effects.get(item, {}).get("desc")
	if language != "en":
		# a template written for the port in this language, else the web translation
		var own = _port_texts.get("item_port", {}).get(item)
		if own is String:
			template = own
		elif text.get("item_description", {}).has(item):
			return String(text.item_description[item])
	if not template is String:
		return String(items.get(item, {}).get("desc", ""))
	if _template_re == null:
		_template_re = RegEx.create_from_string("\\{([A-Za-z0-9_.]+)(?:\\|([a-z%]+))?\\}")
	var out := ""
	var last := 0
	for m in _template_re.search_all(template):
		out += template.substr(last, m.get_start() - last)
		var key := m.get_string(1)
		var value: Variant = item_stats(item).get(key.substr(5), 0) if key.begins_with("stat.") \
			else item_param(item, key, "?")
		out += _format_param(value, m.get_string(2))
		last = m.get_end()
	return out + template.substr(last)


static func _format_param(value: Variant, filter: String) -> String:
	if value is Array:
		var parts: Array[String] = []
		for v in value:
			parts.append(_format_param(v, filter))
		return "/".join(parts)
	if not (value is float or value is int):
		return str(value)
	var v := float(value)
	match filter:
		"s": v /= 1000.0
		"%": v *= 100.0
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return String.num(v, 2).rstrip("0").rstrip(".")


static func _recipe_key(a: String, b: String) -> String:
	return a + "+" + b if a < b else b + "+" + a
#endregion


#region texts and icons
func type_icon(type: String) -> Texture2D:
	return _texture("res://assets/types/%s.svg" % type)


## Stat (ATK, AP, HP...) or UI glyph (money, star, lock-close...) icon.
func icon(icon_name: String) -> Texture2D:
	var path := "res://assets/icons/%s.png" % icon_name
	return _texture(path if ResourceLoader.exists(path) else "res://assets/icons/%s.svg" % icon_name)


func synergy_name(type: String) -> String:
	return String(text.get("synergy", {}).get(type, type.capitalize()))


## One text per tier of the synergy (thresholds in config.synergyThresholds).
func synergy_tier_texts(type: String) -> Array:
	return text.get("synergy_tiers", {}).get(type, [])


## Rarity (COMMON, UNCOMMON...) in the game language.
func rarity_name(rarity: String) -> String:
	return String(text.get("rarity", {}).get(rarity, rarity.capitalize()))


func stat_name(stat: String) -> String:
	return String(text.get("stat", {}).get(stat, stat.capitalize()))


## Passive description of the web game ("" for NONE / unknown).
func passive_desc(passive: String) -> String:
	if passive == "" or passive == "NONE":
		return ""
	return String(text.get("passive_description", {}).get(passive, ""))


## Status of the fight (burn, poison...) in the current language.
const STATUS_KEYS := {
	"burn": "BURN", "silence": "SILENCE", "fatigue": "FATIGUE", "poison": "POISONED", "freeze": "FREEZE",
	"protect": "PROTECT", "sleep": "SLEEP", "confusion": "CONFUSION", "wound": "WOUND", "enraged": "RAGE",
	"paralysis": "PARALYSIS", "locked": "LOCKED", "blinded": "BLINDED", "armor_reduction": "ARMOR_BREAK",
	"charm": "CHARM", "flinch": "FLINCH", "curse": "CURSE", "safeguard": "SAFEGUARD",
	"electric_field": "ELECTRIC_FIELD", "psychic_field": "PSYCHIC_FIELD", "grass_field": "GRASS_FIELD",
	"fairy_field": "FAIRY_FIELD",
}


func status_name(status: String) -> String:
	var key: String = STATUS_KEYS.get(status, "")
	if key != "" and text.get("status", {}).has(key):
		return String(text.status[key])
	return L.t(status.replace("_", " ").capitalize())


func weather_name(weather: String) -> String:
	return String(text.get("weather", {}).get(weather, weather.capitalize()))


func weather_desc(weather: String) -> String:
	return String(text.get("weather_description", {}).get(weather, ""))


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]
#endregion


## The auto balance of the forms (data/balance.json "pokemon") applied to their stats.
func _apply_balance() -> void:
	balance = _load_json_optional("res://data/balance.json")
	var forms: Dictionary = balance.get("pokemon", {})
	for pkm in forms:
		if not pokemon.has(pkm):
			continue
		if not _web_stats.has(pkm):
			var web := {}
			for stat in BALANCED_STATS:
				if pokemon[pkm].has(stat):
					web[stat] = pokemon[pkm][stat]
			_web_stats[pkm] = web
		balance_form(pokemon[pkm], forms[pkm])
	balance_id = str(int(balance.get("version", 0)))


## A stat of the web data, before the auto balance and the range of the roles (UnitRoles: neither may change a role).
func web_stat(pkm: String, stat: String, default: Variant = 0) -> Variant:
	if _web_stats.has(pkm) and _web_stats[pkm].has(stat):
		return _web_stats[pkm][stat]
	if stat == "range" and _web_ranges.has(pkm):
		return _web_ranges[pkm]
	return pokemon.get(pkm, {}).get(stat, default)


## Attack range of the roles (UnitRoles.ROLES "range": caster and marksman 5, not in the web game) on the data of the
## forms, so the fight, the panels, the waves and the bots read one range. Needs the abilities (they give the role).
func _apply_role_ranges() -> void:
	for pkm in pokemon:
		var web := int(pokemon[pkm].get("range", 1))
		var r := UnitRoles.attack_range(pkm, web)
		if r != web:
			_web_ranges[pkm] = web
			pokemon[pkm]["range"] = r


## The auto balance off (the web stats, as sim_test checks them) or on again (data/balance.json, read again).
func use_balance(on: bool) -> void:
	for pkm in _web_stats:
		for stat in _web_stats[pkm]:
			pokemon[pkm][stat] = _web_stats[pkm][stat]
		pokemon[pkm].erase("skillScale")
	balance = {}
	balance_id = "off"
	if on:
		_apply_balance()


## The stats of a form (`d`, its data) with its balance `entry`: {"hp", "atk", "skill", "def", "speDef", "speed", "pp"}
## -> multiplier (missing = 1; "pp" the PP to cast), or one number for hp, atk and skill. HP and PP in tens (at least 10;
## a form without PP keeps 0), the other stats to 0.1. No stat ever goes below 0: "skill" is no stat but the strength
## of its own ability, `skillScale` (x the damage, heal and shield it deals: BattleUnit.skill_scale, to 0.01, at least
## 0.1); its AP stays the web's 0.
static func balance_form(d: Dictionary, entry: Variant) -> void:
	var m := {}
	if entry is Dictionary:
		m = entry
	else:
		m = {"hp": float(entry), "atk": float(entry), "skill": float(entry)}
	d["hp"] = maxi(roundi(float(d.get("hp", 10)) * float(m.get("hp", 1.0)) / 10.0) * 10, 10)
	d["atk"] = maxf(snappedf(float(d.get("atk", 1)) * float(m.get("atk", 1.0)), 0.1), 1.0)
	for stat in ["def", "speDef", "speed"]:
		if m.has(stat):
			d[stat] = maxf(snappedf(float(d.get(stat, 0)) * float(m[stat]), 0.1), 0.0)
	if float(d.get("maxPP", 0)) > 0.0:
		d["maxPP"] = maxi(roundi(float(d.maxPP) * float(m.get("pp", 1.0)) / 10.0) * 10, 10)
	var scale := maxf(snappedf(float(m.get("skill", 1.0)), 0.01), 0.1)
	if is_equal_approx(scale, 1.0):
		d.erase("skillScale")
	else:
		d["skillScale"] = scale


func _load_json_optional(path: String) -> Dictionary:
	return _load_json(path) if FileAccess.file_exists(path) else {}


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("GameData: cannot read %s (run tools/export_pac.bat)" % path)
		return {}
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("GameData: invalid JSON in %s" % path)
	return {}
