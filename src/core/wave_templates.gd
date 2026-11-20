class_name WaveTemplates
extends RefCounted

## Hand-made waves of the Endless mode (not in the web game): data/wave_templates.json,
## edited with tools/wave_editor (tools\wave_editor.bat). See docs/DIFFICULTY.md.
##
## A template replaces the wild pack (or, with `replaceBoss`, the boss) of the stages it
## matches. When several match, one is drawn by `weight` against the wild pack
## (`wildWeight` of the file); a template marked `always` wins over the draw.
## Its Pokémon come from `slots`: each slot is `count` Pokémon, either a given one
## (`pkm`) or a random one of the shop having one of `types` and one of `rarity`, at
## `stars` (0 = the stage rule), holding `items` plus `randomItems` of `itemPool`.

const PATH := "res://data/wave_templates.json"

const TEMPLATE_DEFAULTS := {
	"id": "", "name": "", "enabled": true,
	"stages": [1, 0],          # [first, last]; last 0 = no end
	"every": 0,                # > 0: only every N stages from the first one
	"weight": 10, "always": false, "replaceBoss": false,
	"levels": [],              # difficulty levels using it ([] = all)
	"slots": [],
	"stageItems": false,       # also gives the items a wild wave of the stage holds
	"statBoosts": {}, "statScale": {},
	"synergies": "auto",       # "auto" (the difficulty decides) | "on" | "off"
	"bonusSynergies": {},
	"reward": "default",       # default | none | component | full | choice_component | choice_full
}
const SLOT_DEFAULTS := {
	"count": 1,
	"pkm": "",                 # a given Pokémon; "" = random
	"types": [],               # random: has one of these types ([] = any)
	"rarity": [],              # random: of one of these rarities ([] = the stage odds)
	"stars": 0,                # 1-3, 0 = the stage rule
	"items": [],               # held by each Pokémon of the slot
	"randomItems": 0, "itemPool": "auto",  # auto (the stage rule) | component | full
	"row": 0,                  # 3 front, 2 middle, 1 back, 0 = by attack range
}
const SPECIAL_RARITIES: Array[String] = ["UNIQUE", "LEGENDARY"]

static var _data: Dictionary = {}


## The whole file ({wildWeight, templates}).
static func data() -> Dictionary:
	if _data.is_empty():
		load_data()
	return _data


## Reads the file again, or takes `new_data` (the editor previews unsaved changes).
static func load_data(new_data: Variant = null) -> void:
	if new_data is Dictionary:
		_data = new_data
	else:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if parsed is Dictionary else {}
	if not _data.get("templates") is Array:
		_data["templates"] = []
	if not _data.has("wildWeight"):
		_data["wildWeight"] = 10
	EndlessWaves.clear_cache()


static func templates() -> Array:
	return data().templates


## A template / slot with every key (the file only needs the ones it changes).
static func with_defaults(template: Dictionary) -> Dictionary:
	var out := TEMPLATE_DEFAULTS.duplicate(true)
	out.merge(template, true)
	return out


static func slot_with_defaults(slot: Dictionary) -> Dictionary:
	var out := SLOT_DEFAULTS.duplicate(true)
	out.merge(slot, true)
	return out


## The template can be used at this stage with the current difficulty level.
static func matches(template: Dictionary, stage: int) -> bool:
	var t := with_defaults(template)
	if not t.enabled or t.slots.is_empty():
		return false
	var stages: Array = t.stages
	var first := int(stages[0]) if stages.size() > 0 else 1
	var last := int(stages[1]) if stages.size() > 1 else 0
	if stage < first or (last > 0 and stage > last):
		return false
	if int(t.every) > 0 and (stage - first) % int(t.every) != 0:
		return false
	if not _unlocked(t):
		return false
	return t.levels.is_empty() or t.levels.has(Difficulty.level)


## Battle Pass: a template waits until every slot can be filled: one of the types a random slot asks
## for is unlocked, a given Pokémon is one the pass lets appear.
static func _unlocked(template: Dictionary) -> bool:
	if GameData.all_unlocked:
		return true
	for raw in template.slots:
		if not raw is Dictionary:
			continue
		var s := slot_with_defaults(raw)
		var pkm := String(s.pkm)
		if pkm != "" and GameData.pokemon.has(pkm):
			if not GameData.pokemon_unlocked(pkm):
				return false
		elif not s.types.is_empty() and not s.types.any(func(type: String) -> bool: return GameData.synergy_unlocked(type)):
			return false
	return true


## The template of a stage, {} for the usual wave. `boss`: the stage has a boss, which
## only a `replaceBoss` template takes the place of.
static func pick(stage: int, run_seed: int, boss: bool) -> Dictionary:
	var list: Array = []
	for t in templates():
		if t is Dictionary and matches(t, stage) and (not boss or t.get("replaceBoss", false)):
			list.append(t)
	if list.is_empty():
		return {}
	var always := list.filter(func(t: Dictionary) -> bool: return t.get("always", false))
	var total := 0.0 if boss else maxf(float(data().get("wildWeight", 10)), 0.0)
	if not always.is_empty():
		list = always
		total = 0.0
	for t in list:
		total += _weight(t)
	if total <= 0.0:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, stage, "template"])
	var roll := rng.randf() * total
	for t in list:
		roll -= _weight(t)
		if roll < 0.0:
			return t
	return {}


static func _weight(template: Dictionary) -> float:
	return maxf(float(template.get("weight", TEMPLATE_DEFAULTS.weight)), 0.0)


## First forms a random slot can roll at a stage (its types and rarities).
static func candidates(slot: Dictionary, stage: int) -> Array[String]:
	var s := slot_with_defaults(slot)
	var rarities: Array = s.rarity if not s.rarity.is_empty() else EndlessWaves.allowed_rarities(stage)
	var out: Array[String] = []
	for rarity in rarities:
		for pkm in _rarity_pool(String(rarity)):
			if _has_type(pkm, s.types) and not out.has(pkm):
				out.append(pkm)
	return out


static func _rarity_pool(rarity: String) -> Array:
	match rarity:
		"UNIQUE": return GameData.unique
		"LEGENDARY": return GameData.legendary
	return GameData.wild_tier1_by_rarity.get(rarity, [])


static func _has_type(pkm: String, types: Array) -> bool:
	if types.is_empty():
		return true
	for t in GameData.get_pokemon(pkm).get("types", []):
		if types.has(t):
			return true
	return false


## Builds the wave of a template at a stage ({} when no slot gives a Pokémon); the
## format is the one of EndlessWaves.get_stage().
static func build(template: Dictionary, stage: int, rng: RandomNumberGenerator) -> Dictionary:
	var t := with_defaults(template)
	var board: Array = []
	var held: Array = []
	var used := {}
	var families := {}
	for raw in t.slots:
		if not raw is Dictionary:
			continue
		var s := slot_with_defaults(raw)
		for _i in int(s.count):
			if board.size() >= EndlessWaves.MAX_UNITS:
				break
			var pkm := String(s.pkm)
			if pkm == "" or not GameData.pokemon.has(pkm):
				pkm = _roll_pokemon(s, stage, families, rng)
			if pkm == "":
				continue
			families[GameData.get_pokemon(pkm).get("family", pkm)] = true
			var stars := int(s.stars) if int(s.stars) > 0 else EndlessWaves.roll_stars(stage, rng)
			var rows: Array = []
			if int(s.row) >= 1 and int(s.row) <= 3:
				rows = [int(s.row)]
				for y in [3, 2, 1, 0]:
					if not rows.has(y):
						rows.append(y)
			if not EndlessWaves.place(board, used, GameData.evolve_to(pkm, stars, rng), rows):
				break
			held.append(_slot_items(s, stage, rng))
	if board.is_empty():
		return {}
	if t.stageItems:
		EndlessWaves.add_stage_items(stage, board, held, rng)
	var scale := {}
	for stat in t.statScale:
		if not is_equal_approx(float(t.statScale[stat]), 1.0):
			scale[stat] = float(t.statScale[stat])
	var bonus := {}
	for type in t.bonusSynergies:
		if int(t.bonusSynergies[type]) > 0:
			bonus[type] = int(t.bonusSynergies[type])
	return {
		"name": "template",
		"template": String(t.id),
		"title": String(t.name),
		"leader": GameData.get_pokemon(board[0][0]).get("family", board[0][0]),
		"avatar": board[0][0],
		"board": board,
		"statBoosts": EndlessWaves._add_boosts(EndlessWaves.scaling_boosts(stage), t.statBoosts),
		"statScale": scale,
		"items": held,
		"reward": _reward(String(t.reward), stage),
		"synergyMode": String(t.synergies),
		"bonusSynergies": bonus,
	}


## A random Pokémon of the slot: a rarity drawn with the stage odds when the slot names
## none, a family not in the wave yet when possible.
static func _roll_pokemon(slot: Dictionary, stage: int, families: Dictionary, rng: RandomNumberGenerator) -> String:
	var all := candidates(slot, stage)
	if all.is_empty():
		return ""
	var pool: Array = all
	if slot.rarity.is_empty():
		var rarity := EndlessWaves.roll_rarity(stage, rng)
		var of_rarity := all.filter(func(pkm: String) -> bool: return GameData.get_pokemon(pkm).rarity == rarity)
		if not of_rarity.is_empty():
			pool = of_rarity
	var fresh := pool.filter(func(pkm: String) -> bool: return not families.has(GameData.get_pokemon(pkm).get("family", pkm)))
	if fresh.is_empty():
		fresh = all.filter(func(pkm: String) -> bool: return not families.has(GameData.get_pokemon(pkm).get("family", pkm)))
	if not fresh.is_empty():
		pool = fresh
	return pool[rng.randi() % pool.size()]


static func _slot_items(slot: Dictionary, stage: int, rng: RandomNumberGenerator) -> Array:
	var items: Array = []
	for item in slot.items:
		if GameData.items.has(item) and items.size() < BattleUnit.MAX_ITEMS:
			items.append(item)
	var kind := String(slot.itemPool)
	var pool := EndlessWaves.item_pool(kind if kind in ["component", "full"] else EndlessWaves.stage_item_kind(stage))
	for _i in int(slot.randomItems):
		EndlessWaves.add_random_item(items, pool, rng)
	return items


## What is wrong in the templates (unknown Pokémon / item / type, duplicate id, a slot
## no Pokémon fits...), one text each; [] when all is fine. Used by the editor and sim_test.
static func problems() -> Array[String]:
	var out: Array[String] = []
	var ids := {}
	var types: Dictionary = GameData.config.get("synergyThresholds", {})
	for raw in templates():
		if not raw is Dictionary:
			out.append("a template is not an object")
			continue
		var t := with_defaults(raw)
		var id := String(t.id)
		if id == "" or ids.has(id):
			out.append("%s: empty or duplicate id" % id)
		ids[id] = true
		if t.slots.is_empty():
			out.append("%s: no slot" % id)
		for level in t.levels:
			if not Difficulty.levels().has(level):
				out.append("%s: unknown difficulty level %s" % [id, level])
		for type in t.bonusSynergies:
			if not types.has(type):
				out.append("%s: unknown synergy %s" % [id, type])
		if not String(t.synergies) in ["auto", "on", "off"]:
			out.append("%s: synergies must be auto, on or off" % id)
		for i in t.slots.size():
			if not t.slots[i] is Dictionary:
				out.append("%s slot %d: not an object" % [id, i + 1])
				continue
			var s := slot_with_defaults(t.slots[i])
			if String(s.pkm) != "" and not GameData.is_available(String(s.pkm)):
				out.append("%s slot %d: unknown Pokémon %s" % [id, i + 1, s.pkm])
			for type in s.types:
				if not types.has(type):
					out.append("%s slot %d: unknown type %s" % [id, i + 1, type])
			for rarity in s.rarity:
				if not GameData.SHOP_RARITIES.has(rarity) and not SPECIAL_RARITIES.has(rarity):
					out.append("%s slot %d: unknown rarity %s" % [id, i + 1, rarity])
			for item in s.items:
				if not GameData.items.has(item):
					out.append("%s slot %d: unknown item %s" % [id, i + 1, item])
			if String(s.pkm) == "" and not s.rarity.is_empty() and candidates(s, 1).is_empty():
				out.append("%s slot %d: no Pokémon has these types and rarities" % [id, i + 1])
	return out


static func _reward(kind: String, stage: int) -> Variant:
	match kind:
		"none": return null
		"component", "full": return {"pool": kind, "choice": false}
		"choice_component": return {"pool": "component", "choice": true}
		"choice_full": return {"pool": "full", "choice": true}
	return EndlessWaves.stage_reward(stage)
