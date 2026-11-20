class_name Seasons
extends RefCounted

## Seasons (not in the web game): a run is played with the fixed roster of one season instead of
## every Pokémon of the game. Read from data/seasons.json (generated and checked by
## tools/port/gen_seasons.py, then edited by hand). See docs/SEASONS.md.
##
## A season lists the families of its shop (all there from the first stage: no additional family
## joining later, no regional pool), the Unique / Legendary Pokémon of the portals, the lines
## hatching from eggs, and the synergies with thresholds of their own (the ones that have few
## Pokémon in that season). GameData.apply_progression() is the one place applying it.
## The season is picked in the main menu (Settings.season); FULL = none: the pools of the web game.

const PATH := "res://data/seasons.json"
## Id of "no season": every Pokémon of the game.
const FULL := "all"
## The lists of a season: the shop (every rarity), then the Pokémon of the portals and of the eggs.
const LISTS: Array[String] = ["shop", "unique", "legendary", "hatch"]

## Season of the next run / of the run being played (FULL: none). Set by Settings when the game
## starts; changing it needs GameData.apply_progression() (Settings.set_season does both).
static var current := FULL
static var _data: Dictionary = {}
static var _loaded := false


## The whole file ({enabled, default, allowFull, seasons}).
static func data() -> Dictionary:
	if not _loaded:
		load_data()
	return _data


## Reads the file again, or takes `new_data` (tests).
static func load_data(new_data: Variant = null) -> void:
	_loaded = true
	if new_data is Dictionary:
		_data = new_data
	else:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if parsed is Dictionary else {}
	if not ids().has(current):
		current = default_id()


## Seasons exist: the menu shows the picker.
static func enabled() -> bool:
	return bool(data().get("enabled", false)) and not data().get("seasons", []).is_empty()


## What the menu offers: the seasons, then FULL when the file allows it (FULL alone when seasons are off).
static func ids() -> Array[String]:
	var out: Array[String] = []
	if enabled():
		for s in _data.get("seasons", []):
			out.append(String(s.get("id", "")))
		if bool(_data.get("allowFull", true)):
			out.append(FULL)
	else:
		out.append(FULL)
	return out


static func default_id() -> String:
	var list := ids()
	var wanted := String(_data.get("default", ""))
	return wanted if list.has(wanted) else list[0]


static func set_current(id: String) -> void:
	current = id if ids().has(id) else default_id()


## Tests: the default season of the file instead of the one the player saved, unless "season=<id>"
## was given after "--" on the command line (Settings read it). GameData.apply_progression() still
## has to run (the menu and the game do it).
static func use_default_unless_asked() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("season="):
			return
	set_current(default_id())


## The season `id` ({} for FULL: no roster applies).
static func season(id: String = current) -> Dictionary:
	if id == FULL or not enabled():
		return {}
	for s in _data.get("seasons", []):
		if String(s.get("id", "")) == id:
			return s
	return {}


## A roster applies to the runs (not FULL).
static func active() -> bool:
	return not season().is_empty()


## Name of a season in the UI language (the names of the file are in ui.json).
static func label(id: String = current) -> String:
	var s := season(id)
	return L.t(String(s.get("name", id))) if not s.is_empty() else L.t("All Pokémon")


static func description(id: String = current) -> String:
	var s := season(id)
	if s.is_empty():
		return L.t("No season: every Pokémon of the game. The shop grows at stages 5 / 8 / 11 and changes with the region, as in the web game.")
	return L.t(String(s.get("description", "")))


## Families (first forms) of one list of a season: "shop" (every rarity), "unique", "legendary", "hatch".
static func families(list: String, id: String = current) -> Array[String]:
	var out: Array[String] = []
	var value = season(id).get(list, [])
	if value is Dictionary: # the shop, per rarity
		for key in value:
			for family in value[key]:
				out.append(String(family))
	elif value is Array:
		for family in value:
			out.append(String(family))
	return out


## synergy -> thresholds, for the synergies the season gives tiers of their own.
static func thresholds(id: String = current) -> Dictionary:
	var value = season(id).get("thresholds", {})
	return value if value is Dictionary else {}


## The synergies with a full roster in this season only (special in the other seasons).
static func featured(id: String = current) -> Array[String]:
	var out: Array[String] = []
	out.assign(season(id).get("featured", []))
	return out


## The synergies with few Pokémon and thresholds of their own in this season.
static func special(id: String = current) -> Array[String]:
	var out: Array[String] = []
	out.assign(season(id).get("special", []))
	return out


## "<season> • <difficulty>" of the runs being played (the difficulty alone when seasons are off).
static func run_label() -> String:
	var level := Difficulty.label(Difficulty.level)
	return "%s • %s" % [label(), level] if enabled() else level


## Key of the records (Records) of a difficulty level: one record per season and level; the runs
## without a season keep the key they always had.
static func record_key(level: String, id: String = current) -> String:
	return level if season(id).is_empty() else "%s@%s" % [level, id]


## What is wrong in the file ([] when fine): unknown families, a family in the wrong list or under the
## wrong rarity, thresholds without the tiers of the game. tools/port/gen_seasons.py checks more
## (families per synergy, tiers out of reach).
static func problems() -> Array[String]:
	var out: Array[String] = []
	var seen_ids := {}
	var all_thresholds: Dictionary = GameData.full_thresholds()
	var sources := {} # list -> its families (the first form of a Unique line is not always offered itself)
	for list in ["unique", "legendary", "hatch"]:
		var known := {}
		for pkm in GameData.full_list(list):
			known[String(GameData.get_pokemon(pkm).get("family", pkm))] = true
		sources[list] = known
	var shop_forms: Array = GameData.full_list("pool") + GameData.full_list("additional") + GameData.full_list("regional")
	for s in data().get("seasons", []):
		var id := String(s.get("id", ""))
		if id == "" or id == FULL or seen_ids.has(id):
			out.append("season '%s': id missing, reserved or used twice" % id)
		seen_ids[id] = true
		var seen := {}
		var shop = s.get("shop", [])
		for family in families("shop", id):
			if seen.has(family):
				out.append("%s: %s is listed twice in the shop" % [id, family])
			seen[family] = true
			var entry := GameData.get_pokemon(family)
			if entry.is_empty() or not shop_forms.has(family) or String(entry.get("family", "")) != family \
					or int(entry.get("stars", 0)) != 1 or not GameData.SHOP_RARITIES.has(String(entry.get("rarity", ""))):
				out.append("%s: %s is not a line of the shop" % [id, family])
			elif shop is Dictionary and not shop.get(String(entry.rarity), []).has(family):
				out.append("%s: %s is %s, listed under another rarity" % [id, family, entry.rarity])
		for list in sources:
			for family in families(list, id):
				if not sources[list].has(family):
					out.append("%s: %s is not a %s family" % [id, family, list])
		var own := thresholds(id)
		for type in own:
			var tiers = own[type]
			if not all_thresholds.has(type) or not tiers is Array or tiers.size() != all_thresholds[type].size():
				out.append("%s: thresholds of %s must have the %d tiers of the game" % [id, type,
					all_thresholds.get(type, []).size()])
				continue
			for i in range(1, tiers.size()):
				if float(tiers[i]) <= float(tiers[i - 1]):
					out.append("%s: thresholds of %s are not increasing" % [id, type])
					break
		for key in ["featured", "special"]:
			for type in s.get(key, []):
				if not all_thresholds.has(type):
					out.append("%s: unknown synergy %s in %s" % [id, type, key])
	return out
