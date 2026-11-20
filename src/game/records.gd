class_name Records
extends RefCounted

## Best runs of the player, one per difficulty level, saved in user://records.cfg (not in the
## web game, whose records are the online profile: ELO, history). A record = the stage reached,
## the board at the end (Pokémon + stars), the date, and the number of runs of that level.
## Runs where a cheat (F1) was used are not recorded. Tests point `path` to another file
## (or "records=<file>" after "--" on the command line: screenshots).

static var path := _default_path()


static func _default_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("records="):
			return arg.substr(8)
	return "user://records.cfg"


## {"stage", "team": [{"pkm", "stars"}], "date", "runs"} of `level` ({} when none yet).
static func best(level: String) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section(level):
		return {}
	return {
		"stage": int(cfg.get_value(level, "stage", 0)),
		"team": cfg.get_value(level, "team", []),
		"date": String(cfg.get_value(level, "date", "")),
		"runs": int(cfg.get_value(level, "runs", 0)),
	}


## Records a finished run of `level`; returns true when it beats the previous best stage.
static func submit(level: String, stage: int, team: Array) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(path) # a missing file is a first run
	var runs := int(cfg.get_value(level, "runs", 0)) + 1
	cfg.set_value(level, "runs", runs)
	var beaten := stage > int(cfg.get_value(level, "stage", 0))
	if beaten:
		cfg.set_value(level, "stage", stage)
		cfg.set_value(level, "team", team)
		cfg.set_value(level, "date", Time.get_date_string_from_system())
	cfg.save(path)
	return beaten


## The board of `player` for a record: strongest first (stars, then rarity cost).
static func team_of(player: PlayerState) -> Array:
	var units: Array = player.board.values()
	units.sort_custom(func(a, b) -> bool:
		if a.stars() != b.stars():
			return a.stars() > b.stars()
		return GameData.rarity_cost(String(GameData.get_pokemon(a.pkm).get("rarity", ""))) \
			> GameData.rarity_cost(String(GameData.get_pokemon(b.pkm).get("rarity", ""))))
	return units.map(func(u) -> Dictionary: return {"pkm": u.pkm, "stars": u.stars()})
