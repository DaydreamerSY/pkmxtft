extends Node

## Autoload "Settings": the player's options, saved in user://settings.cfg:
## language (default: the system one when translated, else English), music and sound
## volumes (0-100), difficulty level (Difficulty). apply() sets the GameData texts, the TranslationServer locale for
## the UI texts (data/i18n/ui.json) and the Audio bus volumes.

signal changed

const PATH := "user://settings.cfg"
const UI_TRANSLATIONS := "res://data/i18n/ui.json"

var language := ""
var music_volume := 60.0
var sfx_volume := 80.0
## Difficulty level of the runs (data/difficulty.json), picked in the main menu.
var difficulty := ""
## Season of the runs (data/seasons.json, Seasons), picked in the main menu.
var season := ""
## Size of the UI in percent, 0 = Auto (UiScale: bigger on a phone).
var ui_scale := 0
## Compact HUD (phones): angle of the camera over the board in degrees, 0 = auto (the angle showing the
## board the biggest in the room it has: Game._pick_pitch).
var board_pitch := 0
const BOARD_PITCHES: Array[int] = [0, 40, 45, 50, 55, 60]


func _ready() -> void:
	_load_ui_translations()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		language = String(cfg.get_value("game", "language", ""))
		music_volume = float(cfg.get_value("audio", "music", music_volume))
		sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
		difficulty = String(cfg.get_value("game", "difficulty", ""))
		ui_scale = int(cfg.get_value("game", "ui_scale", 0))
		season = String(cfg.get_value("game", "season", ""))
		board_pitch = int(cfg.get_value("game", "board_pitch", 0))
	# "difficulty=<id>" / "season=<id>" ("all": none) after "--" on the command line: that level and
	# that season for this run (tests), not saved
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("difficulty="):
			difficulty = arg.substr(11)
		elif arg.begins_with("season="):
			season = arg.substr(7)
		elif arg.begins_with("board_pitch="):
			board_pitch = int(arg.substr(12))
	Difficulty.set_level(difficulty if Difficulty.levels().has(difficulty) else Difficulty.default_level())
	difficulty = Difficulty.level
	# GameData is ready before this autoload: its lists get the roster of the season now
	Seasons.set_current(season if Seasons.ids().has(season) else Seasons.default_id())
	season = Seasons.current
	GameData.apply_progression()
	if language == "" or not GameData.languages.has(language):
		var system := OS.get_locale_language()
		language = system if GameData.languages.has(system) else "en"
	apply()


func set_language(code: String) -> void:
	language = code
	apply()
	save()


func set_difficulty(id: String) -> void:
	Difficulty.set_level(id)
	difficulty = Difficulty.level
	save()


## Picks the season of the next runs (the menu): the lists of GameData get its roster at once.
func set_season(id: String) -> void:
	Seasons.set_current(id)
	season = Seasons.current
	GameData.apply_progression()
	save()


## Angle of the camera over the board (compact HUD), 0 = auto.
func set_board_pitch(degrees: int) -> void:
	board_pitch = degrees
	save()
	changed.emit()


func set_ui_scale(percent: int) -> void:
	ui_scale = percent
	UiScale.apply(get_tree().root, ui_scale)
	save()
	changed.emit()


func set_volumes(music: float, sfx: float) -> void:
	music_volume = clampf(music, 0.0, 100.0)
	sfx_volume = clampf(sfx, 0.0, 100.0)
	Audio.apply_volumes(music_volume, sfx_volume)
	save()
	changed.emit()


func apply() -> void:
	GameData.set_language(language)
	TranslationServer.set_locale(GameData.language)
	UiScale.apply(get_tree().root, ui_scale)
	Audio.apply_volumes(music_volume, sfx_volume)
	changed.emit()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "language", language)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("game", "season", season)
	cfg.set_value("game", "ui_scale", ui_scale)
	cfg.set_value("game", "board_pitch", board_pitch)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(PATH)


## ui.json: {"English text": {"vi": "...", ...}} -> one Translation per language.
func _load_ui_translations() -> void:
	if not FileAccess.file_exists(UI_TRANSLATIONS):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(UI_TRANSLATIONS))
	if not data is Dictionary:
		push_error("Settings: invalid JSON in " + UI_TRANSLATIONS)
		return
	var by_language := {}
	for key in data:
		if key.begins_with("_") or not data[key] is Dictionary:
			continue
		for code in data[key]:
			if not by_language.has(code):
				var t := Translation.new()
				t.locale = code
				by_language[code] = t
			by_language[code].add_message(key, String(data[key][code]))
	for code in by_language:
		TranslationServer.add_translation(by_language[code])
