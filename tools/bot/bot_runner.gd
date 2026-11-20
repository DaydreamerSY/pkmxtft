extends Node

## Plays Endless runs with bots (BotRun + BotBrain) as fast as the logic goes - no view, no sound, nothing
## saved to the player's pass or records - and writes the balance data as TSV (docs/BOT.md). Headless:
##   Godot_console.exe --headless --path . res://tools/bot/bot_runner.tscn -- runs=200 out=build/bot/b1 worker=0
## or many workers at once: tools\bot_run.bat (tools/bot_run.ps1).
## Arguments after "--" (all optional):
##   runs=N          runs to play (default 20)          seed=S      first run seed (default: from the clock)
##   out=DIR         folder of the TSV (project-relative or absolute; default build/bot/latest)
##   worker=W        suffix of the files (runs_W.tsv...) and first run id W * 1 000 000
##   diffs=a,b       difficulty levels (default: the active one)   seasons=s1,all   (default: the file's)
##   passes=1,5,all  Battle Pass levels, or "journey" (a new player: the level its runs so far give)
##   styles=a,b      bot styles (BotBrain.STYLES; default: drawn per run)
##   units=0         no unit rows (smaller files)
##   knowledge=FILE  the bots' experience (BotKnowledge; default tools/bot/knowledge.json, "none" = start from nothing);
##                   what this worker learns is written to knowledge_W.json (tools/bot/learn.py merges it)
##   model=FILE      the pro bot's win model (BotModel; default tools/bot/model.json, "none" = the knowledge tables)
## Style "pro" (styles=pro) is the pro bot (BotPro): adapts its plan to the run, decides with the model.
## Style "design" (styles=design) is the design test: run i of worker w plays combo (i x workers + w) of the list of
## every combo of `combo` synergies (2 or 3) the pool has (BotPro.design_combos) - every combo gets its share.
##   workers=W       the number of workers of the batch (the design test's share), combo=2|3
## A value is drawn per run from each list. One run a frame: a script error ends that run only
## (counted in meta: errors).

var _args := {}
var _runs := 20
var _seed := 0
var _worker := 0
var _done := 0
var _errors := 0
var _running := false
var _started := 0
var _files := {}
var _setup_rng := RandomNumberGenerator.new()
var _diffs: Array = []
var _seasons: Array = []
var _passes: Array = []
var _styles: Array = []
var _units := true
var _stages_total := 0
var _knowledge: BotKnowledge
var _model: BotModel
var _workers := 1
var _combo := 2
var _out := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var at := arg.find("=")
		if at > 0:
			_args[arg.substr(0, at)] = arg.substr(at + 1)
	_runs = maxi(int(_args.get("runs", "20")), 1)
	_seed = int(_args.get("seed", str(Time.get_ticks_usec() % 1000000007)))
	_worker = int(_args.get("worker", "0"))
	_units = String(_args.get("units", "1")) != "0"
	_setup_rng.seed = hash([_seed, "setup"])
	_diffs = _list("diffs", [Difficulty.level])
	_seasons = _list("seasons", [Seasons.default_id()])
	_passes = _list("passes", ["all"])
	_styles = _list("styles", [""])
	var out := String(_args.get("out", "build/bot/latest"))
	if not out.is_absolute_path():
		out = ProjectSettings.globalize_path("res://").path_join(out)
	_out = out
	DirAccess.make_dir_recursive_absolute(out)
	var known := String(_args.get("knowledge", BotKnowledge.DEFAULT_PATH))
	_knowledge = BotKnowledge.load_from("" if known == "none" else known)
	var model_path := String(_args.get("model", BotModel.DEFAULT_PATH))
	_model = BotModel.load_from("" if model_path == "none" else model_path)
	_workers = maxi(int(_args.get("workers", "1")), 1)
	_combo = clampi(int(_args.get("combo", "2")), 2, 3)
	for kind in ["runs", "stages", "units"]:
		var f := FileAccess.open(out.path_join("%s_%d.tsv" % [kind, _worker]), FileAccess.WRITE)
		if f == null:
			push_error("bot: cannot write in %s" % out)
			get_tree().quit(1)
			return
		_files[kind] = f
	_files.runs.store_line("\t".join(BotRun.RUN_COLUMNS))
	_files.stages.store_line("\t".join(BotRun.STAGE_COLUMNS))
	_files.units.store_line("\t".join(BotRun.UNIT_COLUMNS))
	_write_meta(out)
	_started = Time.get_ticks_msec()
	print("bot worker %d: %d runs, seed %d -> %s" % [_worker, _runs, _seed, out])


func _list(key: String, default: Array) -> Array:
	var raw := String(_args.get(key, ""))
	if raw == "":
		return default
	return Array(raw.split(",", false))


func _process(_delta: float) -> void:
	if _running: # the last run stopped on a script error
		_running = false
		_errors += 1
		_done += 1
	if _done >= _runs:
		_finish()
		return
	_running = true # still true next frame: this run stopped on a script error
	var setup := _setup(_done)
	var style: String = _styles[_setup_rng.randi() % _styles.size()]
	var brain: BotBrain
	match style:
		"pro":
			brain = BotPro.create(_seed + _done * 104729, _knowledge, _model)
		"design":
			brain = BotPro.create(_seed + _done * 104729, _knowledge, _model, _done * _workers + _worker, _combo)
		_:
			brain = BotBrain.random_profile(_seed + _done * 104729, style)
	brain.knowledge = _knowledge
	var run := BotRun.new(_worker * 1000000 + _done, _seed + _done * 7919, brain)
	run.track_units = _units
	var row := run.play(setup)
	_running = false
	_files.runs.store_line(row)
	if not run.stage_rows.is_empty():
		_files.stages.store_line("\n".join(run.stage_rows))
	if _units and not run.unit_rows.is_empty():
		_files.units.store_line("\n".join(run.unit_rows))
	for f in _files.values():
		f.flush()
	_done += 1
	_stages_total += run.stage_rows.size()
	if _done % 10 == 0 or _done == _runs:
		var secs := (Time.get_ticks_msec() - _started) / 1000.0
		print("worker %d: %d / %d runs, %.1f s/run, %d stages, %d errors" % [_worker, _done, _runs, secs / _done,
			_stages_total, _errors])


## Difficulty, season and pass of run `i` (a value drawn from each list), applied for BotRun.play().
func _setup(i: int) -> Dictionary:
	var diff := String(_diffs[_setup_rng.randi() % _diffs.size()])
	var season := String(_seasons[_setup_rng.randi() % _seasons.size()])
	var pass_value := String(_passes[_setup_rng.randi() % _passes.size()])
	Difficulty.set_level(diff)
	Seasons.set_current(season)
	var level := 9999
	if pass_value == "journey": # a new player: the level of the runs this worker played before
		level = Progression.level_at(i * Progression.run_xp()) if Progression.enabled() else 9999
	elif pass_value != "all":
		level = maxi(int(pass_value), 1)
	Progression.override_level = level
	return {"diff": Difficulty.level, "season": Seasons.current,
		"pass": mini(level, Progression.max_level()) if pass_value != "all" else "all"}


func _write_meta(out: String) -> void:
	var f := FileAccess.open(out.path_join("meta_%d.tsv" % _worker), FileAccess.WRITE)
	var rows := [["date", Time.get_datetime_string_from_system()], ["worker", _worker], ["seed", _seed], ["runs", _runs],
		["diffs", ",".join(_diffs)], ["seasons", ",".join(_seasons)], ["passes", ",".join(_passes)],
		["styles", ",".join(_styles)], ["pass_levels", Progression.max_level()],
		["mana", JSON.stringify(Difficulty.mana())], ["life_loss_scale", Difficulty.value("lifeLossScale", 1.0)],
		["balance", GameData.balance_id],
		["damage", "effective"]] # units dealt / taken without overkill (older batches: the damage events' amounts)
	for r in rows:
		f.store_line("%s\t%s" % [r[0], r[1]])


func _finish() -> void:
	set_process(false)
	for f in _files.values():
		f.close()
	_knowledge.save_added(_out.path_join("knowledge_%d.json" % _worker))
	var out := String(_args.get("out", "build/bot/latest"))
	if not out.is_absolute_path():
		out = ProjectSettings.globalize_path("res://").path_join(out)
	var meta := FileAccess.open(out.path_join("meta_%d.tsv" % _worker), FileAccess.READ_WRITE)
	if meta != null:
		meta.seek_end()
		meta.store_line("errors\t%d" % _errors)
		meta.store_line("seconds\t%d" % ((Time.get_ticks_msec() - _started) / 1000))
		meta.close()
	print("=== bot worker %d done: %d runs, %d errors, %.0f s ===" % [_worker, _done, _errors,
		(Time.get_ticks_msec() - _started) / 1000.0])
	get_tree().quit(0 if _errors == 0 else 2)
