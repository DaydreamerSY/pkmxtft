class_name Difficulty
extends RefCounted

## Difficulty of the Endless mode (not in the web game), read from data/difficulty.json:
## hand-edited, or with tools/wave_editor. See docs/DIFFICULTY.md.
##
## A level is `base` overridden by `levels.<id>` (nested dictionaries merge key by key):
##   endless                 overrides of GameData.config.endless (wave size, stars, items, scaling)
##   enemySynergies...       the waves activate their synergies (FightSetup gives them to the red team)
##   bossItems               the original bosses hold their `marowakItems`
##   statScale...            multipliers of the enemies' base stats, growing with the stage
##   statBoosts              flat stats added to every enemy
##   startLife, startGold, lifeLossScale   the player's side
##   mana                    PP rules of every Pokémon in the fight (see `mana()`)
## The level is picked in the main menu (Settings.difficulty); `revision` changes with
## it so that EndlessWaves rebuilds its waves.

const PATH := "res://data/difficulty.json"
const SCALED_STATS: Array[String] = ["HP", "ATK", "DEF", "SPE_DEF", "SPEED"]
## The mana rules of the web game (updateEachSecond, ON_ATTACK_MANA, handleDamage): used for the
## keys a level does not set.
const WEB_MANA := {"perSecond": 10.0, "perAttack": 5.0, "perHit": 0.0, "perDamage": 10.0}

static var level := ""
static var revision := 0
static var _data: Dictionary = {}
static var _params: Dictionary = {}
static var _endless: Dictionary = {}
static var _mana: Dictionary = {}


## The whole file ({active, base, levels}).
static func data() -> Dictionary:
	if _data.is_empty():
		load_data()
	return _data


## Reads the file again, or takes `new_data` (the editor previews unsaved changes).
static func load_data(new_data: Variant = null) -> void:
	if new_data is Dictionary:
		_data = new_data
	else:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	if _data.is_empty():
		push_error("Difficulty: cannot read " + PATH)
		_data = {"active": "normal", "base": {}, "levels": {"normal": {"label": "Normal"}}}
	if not _data.get("levels", {}).has(level):
		level = default_level()
	_invalidate()


static func default_level() -> String:
	var ids := levels()
	var active := String(_data.get("active", ""))
	return active if ids.has(active) else (ids[0] if not ids.is_empty() else "")


static func levels() -> Array[String]:
	var out: Array[String] = []
	out.assign(data().get("levels", {}).keys())
	return out


## Name of a level in the UI language ("Classic", "Normal", "Hard" are in ui.json).
static func label(id: String) -> String:
	return L.t(String(data().get("levels", {}).get(id, {}).get("label", id.capitalize())))


static func description(id: String) -> String:
	return L.t(String(data().get("levels", {}).get(id, {}).get("desc", "")))


static func set_level(id: String) -> void:
	if not levels().has(id):
		id = default_level()
	if id != level:
		level = id
		_invalidate()


## Parameters of the current level: `base` overridden by the level.
static func params() -> Dictionary:
	if _params.is_empty():
		data()
		_params = merged(_data.get("base", {}), _data.get("levels", {}).get(level, {}))
	return _params


static func value(key: String, default: Variant = null) -> Variant:
	return params().get(key, default)


## config.endless of the web game overridden by the level's `endless`.
static func endless() -> Dictionary:
	if _endless.is_empty():
		_endless = merged(GameData.config.get("endless", {}), params().get("endless", {}))
	return _endless


## Basic PP (mana) rules of every Pokémon, both teams (items, synergies, passives and the
## weather keep their own PP):
##   perSecond   passive PP each second (web: 10; RAIN / DROUGHT still add / remove 3)
##   perAttack   PP per basic attack that lands (not dodged nor blocked; web: 5 per attack)
##   perHit      flat PP each time a basic attack lands on it and is not blocked — the damage of an
##               ability gives none (web: 0)
##   perDamage   1 PP per N damage that went through the shield, any source (web: 10; 0 = off)
##   roles       {role: the keys above} for the role of the Pokémon (UnitRoles: tank, fighter,
##               assassin, caster, marksman, support), over the keys above — see role_mana()
## The PP to cast is not a rule: every form has its own maxPP (the web data with the auto balance of
## data/balance.json, in tens) — max_pp_of().
static func mana() -> Dictionary:
	if _mana.is_empty():
		_mana = merged(WEB_MANA, params().get("mana", {}))
	return _mana


## The PP rules of one role: `rules` (default: mana()) overridden by `rules.roles.<role>`, without `roles`.
static func role_mana(role: String, rules: Dictionary = {}) -> Dictionary:
	if rules.is_empty():
		rules = mana()
	var out := rules.duplicate()
	out.erase("roles")
	var roles = rules.get("roles")
	if roles is Dictionary and roles.get(role) is Dictionary:
		out.merge(roles[role], true)
	return out


## PP a Pokémon needs to cast: `own`, its maxPP in GameData (the web data with the auto balance; 100 for
## a TM ability, as on the web) — no longer by role. 0 (Substitute, Egg, pillars: no ability) -> 100.
static func max_pp_of(own: float) -> float:
	return own if own > 0.0 else 100.0


## Multipliers of the enemies' base stats at a stage: {stat: factor} (1 = unchanged).
static func enemy_scale(stage: int) -> Dictionary:
	var p := params()
	var base: Dictionary = p.get("statScale", {})
	var growth: Dictionary = p.get("statScalePerStage", {})
	var n := maxi(stage - int(p.get("statScaleStartStage", 1)), 0)
	var out := {}
	for stat in SCALED_STATS:
		var factor := float(base.get(stat, 1.0)) + float(growth.get(stat, 0.0)) * n
		if not is_equal_approx(factor, 1.0):
			out[stat] = maxf(factor, 0.05)
	return out


## The waves activate their synergies at this stage (`boss`: an original PvE stage).
static func enemy_synergies(stage: int, boss: bool) -> bool:
	var p := params()
	if not p.get("enemySynergies", false) or stage < int(p.get("enemySynergiesFromStage", 1)):
		return false
	return not boss or bool(p.get("bossSynergies", true))


## `base` with the keys of `over`; dictionaries present in both are merged key by key.
static func merged(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key in over:
		if over[key] is Dictionary and out.get(key) is Dictionary:
			out[key].merge(over[key], true)
		else:
			out[key] = over[key]
	return out


static func _invalidate() -> void:
	_params = {}
	_endless = {}
	_mana = {}
	revision += 1
