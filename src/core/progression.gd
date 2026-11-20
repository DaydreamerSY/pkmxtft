class_name Progression
extends RefCounted

## Battle Pass: the unlock progression across runs (not in the web game), read from
## data/progression.json. See docs/PROGRESSION.md.
##
## Playing gives pass XP: `xp.perRun` for a run played to its end (Game Over; leaving by the menu gives
## none), and `perStage` / `perWin` for each stage fought (0 in the file now), scaled by the difficulty;
## the pass levels unlock synergies. A new player starts with three simple ones (Fire, Water, Grass); the
## next one comes after one run, then two every three runs:
##   level 1         every synergy no level unlocks
##   level N (>= 2)  `levels[N - 2]`: {xp: cost from the level before, synergies: [...]}
## A locked synergy does not exist in the game: GameData.apply_progression() removes it from the types
## of every Pokémon and region, and the families left without a synergy (or with a locked `gatedBy`
## one) from every pool. What a level unlocks is used from the next run on (never during a run).
##
## The pass is saved in user://progress.cfg ([pass] xp = total XP, seen / run = the level whose unlocks
## the pass screen / a run start showed). Tests and tools: `override_level` (or "pass=<level>" /
## "pass=all" after "--") forces a level and saves nothing; "pass_file=<file>" uses another save.

const PATH := "res://data/progression.json"
const SECTION := "pass"

static var path := _path_arg()
## >= 1: this level whatever the saved XP is, and nothing is saved; -1: the saved pass.
static var override_level := _level_arg()

static var _data: Dictionary = {}
static var _state: Dictionary = {} ## {xp, seen, run} of `_state_path` ({} = not read yet)
static var _state_path := ""


static func _path_arg() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("pass_file="):
			return arg.substr(10)
	return "user://progress.cfg"


static func _level_arg() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("pass="):
			var value := arg.substr(5)
			return 9999 if value == "all" else maxi(int(value), 1)
	return -1


#region the pass file (data/progression.json)
static func data() -> Dictionary:
	if _data.is_empty():
		load_data()
	return _data


## Reads the file again, or takes `new_data` (tests).
static func load_data(new_data: Variant = null) -> void:
	if new_data is Dictionary:
		_data = new_data
	else:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if parsed is Dictionary else {}
	if not _data.get("levels") is Array:
		_data["levels"] = []
	if not _data.get("xp") is Dictionary:
		_data["xp"] = {}
	if not _data.get("gatedBy") is Array:
		_data["gatedBy"] = []


static func _levels() -> Array:
	return data().levels


## The pass is on: `enabled` (default true) and at least one level to reach. Off: every synergy is
## unlocked, no XP, the menu and the Game Over screen do not show it.
static func enabled() -> bool:
	return bool(data().get("enabled", true)) and not _levels().is_empty()


## Last level of the pass (1 when the file has no level: everything is unlocked from the start).
static func max_level() -> int:
	return _levels().size() + 1


## XP to reach `level` from the level before (0 for level 1 and past the last one).
static func level_cost(level: int) -> int:
	if level < 2 or level > max_level():
		return 0
	var entry = _levels()[level - 2]
	return maxi(int(entry.get("xp", 0)) if entry is Dictionary else 0, 1)


## Total XP at which `level` is reached.
static func level_start_xp(level: int) -> int:
	var total := 0
	for l in range(2, mini(level, max_level()) + 1):
		total += level_cost(l)
	return total


static func level_at(total_xp: int) -> int:
	var reached := 1
	var left := total_xp
	while reached < max_level() and left >= level_cost(reached + 1):
		left -= level_cost(reached + 1)
		reached += 1
	return reached


## Synergies that keep their whole families out while they are locked (`gatedBy`).
static func gated_types() -> Array:
	return data().gatedBy


## The synergies `level` unlocks, in the web order for level 1 (every synergy no level gives).
static func rewards(level: int) -> Array[String]:
	var known: Array = GameData.config.get("synergyThresholds", {}).keys()
	var out: Array[String] = []
	if level <= 1:
		var later := {}
		for entry in _levels():
			if entry is Dictionary:
				for s in entry.get("synergies", []):
					later[s] = true
		for s in known:
			if not later.has(s):
				out.append(s)
		return out
	if level > max_level():
		return out
	var level_entry = _levels()[level - 2]
	for s in (level_entry.get("synergies", []) if level_entry is Dictionary else []):
		if known.has(s) and not out.has(s):
			out.append(s)
	return out


## Every synergy unlocked at `at_level` (default: the player's level).
static func unlocked_synergies(at_level := -1) -> Array[String]:
	var out: Array[String] = []
	for l in range(1, mini(level() if at_level < 1 else at_level, max_level()) + 1):
		for s in rewards(l):
			if not out.has(s):
				out.append(s)
	return out


## The level unlocking `synergy` (1 = from the start).
static func level_of(synergy: String) -> int:
	for l in range(2, max_level() + 1):
		if rewards(l).has(synergy):
			return l
	return 1


## What is wrong in the file, one text each ([] when all is fine): sim_test.
static func problems() -> Array[String]:
	var out: Array[String] = []
	var known: Array = GameData.config.get("synergyThresholds", {}).keys()
	var seen := {}
	var list := _levels()
	for i in list.size():
		if not list[i] is Dictionary:
			out.append("level %d: not an object" % (i + 2))
			continue
		if int(list[i].get("xp", 0)) <= 0:
			out.append("level %d: xp must be > 0" % (i + 2))
		for s in list[i].get("synergies", []):
			if not known.has(s):
				out.append("level %d: unknown synergy %s" % [i + 2, s])
			elif seen.has(s):
				out.append("level %d: %s is already unlocked by level %d" % [i + 2, s, seen[s]])
			seen[s] = i + 2
	for s in gated_types():
		if not known.has(s):
			out.append("gatedBy: unknown synergy %s" % s)
	for level_id in data().xp.get("difficulty", {}):
		if not Difficulty.levels().has(level_id):
			out.append("xp.difficulty: unknown difficulty level %s" % level_id)
	if rewards(1).is_empty():
		out.append("no starting synergy: every synergy is unlocked by a level")
	return out
#endregion


#region the player's pass (user://progress.cfg)
static func _read() -> Dictionary:
	if _state.is_empty() or _state_path != path:
		_state_path = path
		_state = {"xp": 0, "seen": 1, "run": 1}
		var cfg := ConfigFile.new()
		if cfg.load(path) == OK:
			for key in _state:
				_state[key] = maxi(int(cfg.get_value(SECTION, key, _state[key])), 0)
	return _state


static func _save() -> void:
	if override_level >= 1:
		return
	var cfg := ConfigFile.new()
	cfg.load(path) # keeps what else the file may hold
	for key in _state:
		cfg.set_value(SECTION, key, _state[key])
	cfg.save(path)


## Forgets what was read (tests changing `path` or the file behind it).
static func forget() -> void:
	_state = {}


## Total XP earned (with `override_level`: the XP at which that level starts).
static func xp() -> int:
	if override_level >= 1:
		return level_start_xp(level())
	return int(_read().xp)


static func level() -> int:
	if not enabled():
		return max_level()
	if override_level >= 1:
		return clampi(override_level, 1, max_level())
	return level_at(int(_read().xp))


## {level, max_level, into: XP earned in the level, need: XP of the level (0 at the last one)}.
static func progress() -> Dictionary:
	var lv := level()
	return {"level": lv, "max_level": max_level(), "into": xp() - level_start_xp(lv), "need": level_cost(lv + 1)}


## Pass XP of one stage fought: perStage (+ perWin), times the factor of the difficulty level.
static func stage_xp(won: bool) -> int:
	var cfg: Dictionary = data().xp
	var base := float(cfg.get("perStage", 0)) + (float(cfg.get("perWin", 0)) if won else 0.0)
	return maxi(roundi(base * _factor()), 0)


## Pass XP of a run played to its end (Game Over): perRun, times the factor of the difficulty level.
static func run_xp() -> int:
	return maxi(roundi(float(data().xp.get("perRun", 0)) * _factor()), 0)


## XP factor of the current difficulty level (xp.difficulty, 1 when the level is not listed).
static func _factor() -> float:
	var cfg: Dictionary = data().xp
	return float(cfg.get("difficulty", {}).get(Difficulty.level, 1.0)) if cfg.get("difficulty") is Dictionary else 1.0


## The XP rule told by the pass screen, for the current difficulty level.
static func xp_rule() -> String:
	var parts: Array[String] = []
	if run_xp() > 0:
		parts.append(L.t("+%d XP for each run played to its end (leaving by the menu does not count).") % run_xp())
	if stage_xp(true) > 0:
		parts.append(L.t("+%d XP per stage fought, +%d for a win.") % [stage_xp(false), stage_xp(true) - stage_xp(false)])
	parts.append(L.t("No XP in a run with cheats."))
	return " ".join(parts)


## Adds pass XP and saves: {gained, from, to, unlocked: the synergies of the levels reached}.
## Nothing is gained with `override_level`.
static func add_xp(amount: int) -> Dictionary:
	var from := level()
	if amount <= 0 or override_level >= 1 or not enabled():
		return {"gained": 0, "from": from, "to": from, "unlocked": []}
	_read().xp = int(_state.xp) + amount
	_save()
	return {"gained": amount, "from": from, "to": level(), "unlocked": synergies_between(from, level())}


## Synergies of the levels after `from` up to `to`.
static func synergies_between(from: int, to: int) -> Array[String]:
	var out: Array[String] = []
	for l in range(from + 1, mini(to, max_level()) + 1):
		out.append_array(rewards(l))
	return out


## What the Game Over screen tells: the XP of the run and where the pass stands
## ({xp, from, to, unlocked} + progress()).
static func report(gained: int, from: int) -> Dictionary:
	var out := progress()
	out["xp"] = gained
	out["from"] = from
	out["to"] = int(out.level)
	out["unlocked"] = synergies_between(from, int(out.level))
	return out


## Synergies unlocked since the pass screen was last opened (the "new" mark of the main menu).
static func unseen_synergies() -> Array[String]:
	if override_level >= 1 or not enabled():
		return [] as Array[String]
	return synergies_between(int(_read().seen), level())


static func mark_seen() -> void:
	if override_level < 1 and enabled() and int(_read().seen) != level():
		_state.seen = level()
		_save()


## Start of a run: the synergies unlocked since the last run started (told once, by a banner).
static func take_run_news() -> Array[String]:
	if override_level >= 1 or not enabled():
		return [] as Array[String]
	var fresh := synergies_between(int(_read().run), level())
	if int(_state.run) != level():
		_state.run = level()
		_save()
	return fresh


## Cheats / tests: jumps to a level (its first XP), or back to the start.
static func set_level(target: int) -> void:
	if not enabled():
		return
	if override_level >= 1:
		override_level = clampi(target, 1, max_level())
		return
	_read().xp = level_start_xp(clampi(target, 1, max_level()))
	_state.seen = mini(int(_state.seen), level())
	_state.run = mini(int(_state.run), level())
	_save()
#endregion
