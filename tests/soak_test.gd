extends Node

## Plays the real game scene fast (bot buys, auto places, fights) for many stages
## to catch runtime errors in the view / event code. Run headless:
##   Godot_console.exe --headless --path . res://tests/soak_test.tscn
## then look for "SCRIPT ERROR" in the output.
## Played with a new Battle Pass (level 1: the starting synergies only, pass XP earned stage after
## stage in a test save); add "-- pass=all" to play with everything unlocked.

const TARGET_STAGE := 22

var game: Game
var last_stage := 0
var _over_frames := 0


func _ready() -> void:
	Records.path = "user://test_records.cfg"
	Progression.path = "user://test_progress.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Progression.path))
	Progression.forget()
	# the default season of the file (not the one the player saved), unless "season=<id>" is given
	Seasons.use_default_unless_asked()
	Engine.time_scale = 8.0
	Engine.physics_ticks_per_second = 30
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	game.planning_timer = true
	game.planning_duration = 1.5
	game.result_duration = 0.5


func _process(_delta: float) -> void:
	if game.phase == Game.Phase.OVER:
		_over_frames += 1
		if _over_frames < 6: # the Game Over panel gets its size
			return
		var panel: Control = game.hud._game_over.get_node("Center/Panel")
		var view := game.hud._game_over.get_global_rect()
		print("game over at stage %d, panel %s" % [game.player.stage, panel.size])
		if not game.hud._game_over.visible or not view.encloses(panel.get_global_rect()):
			push_error("FAIL: the Game Over panel %s does not fit %s" % [panel.get_global_rect(), view])
		_finish(true)
		return
	if game.phase == Game.Phase.PLANNING and game.player.stage != last_stage:
		last_stage = game.player.stage
		# a simple bot: lots of gold, buy what it can, level up
		game.player.gold += 30
		game.player.buy_xp()
		for i in game.player.shop.size():
			game.player.buy(i)
		game.player.auto_place()
		# exercise the drag code once per stage
		var views := game.owned_views.values()
		if not views.is_empty():
			var v: UnitView = views[0]
			game._begin_drag(game.camera.unproject_position(v.global_position + Vector3.UP * 0.3))
			game._on_mouse_motion(game.camera.unproject_position(game.arena.cell_to_world(Vector2i(4, 1))))
			game._drop(game.camera.unproject_position(game.arena.cell_to_world(Vector2i(4, 1))))
			game._inspect(game.camera.unproject_position(v.global_position + Vector3.UP * 0.3))
		# items: pick a pending reward, then drag bench items onto the board Pokémon
		game.auto_resolve_choices()
		for unit in game.player.board.values():
			if game.player.items.is_empty():
				break
			var view: UnitView = game.owned_views.get(unit.id)
			if view == null:
				continue
			var at := game.camera.unproject_position(view.global_position + Vector3.UP * 0.3)
			game._begin_item_drag(0)
			game._item_drag_motion(at)
			game._drop_item(at)
		var held := 0
		for unit in game.player.board.values():
			held += unit.items.size()
		print("stage %d: life %d, level %d, board %d, items held %d / bench %d, wave %s" % [game.player.stage,
			game.player.life, game.player.level, game.player.board.size(), held, game.player.items.size(),
			EndlessWaves.display_name(game.wave)])
		if game.player.stage >= TARGET_STAGE:
			_finish(false)


## `over`: the run ended (Game Over) - only then it gives its pass XP; alive at TARGET_STAGE: none yet.
func _finish(over: bool) -> void:
	print("battle pass: level %d (run started at %d), %d XP, +%d in this run, synergies %d / %d%s" % [Progression.level(),
		game._pass_from, Progression.xp(), game.pass_xp, GameData.synergies().size(), GameData.config.synergyThresholds.size(),
		"" if over else " (alive at stage %d: the run has not ended)" % game.player.stage])
	if over and Progression.override_level < 1 and (game.pass_xp <= 0 or Progression.xp() != game.pass_xp):
		push_error("FAIL: the run gave no pass XP (%d, saved %d)" % [game.pass_xp, Progression.xp()])
	if not over and game.pass_xp != 0:
		push_error("FAIL: pass XP before the run ended (%d)" % game.pass_xp)
	print("=== soak done ===")
	if game.sim != null:
		game.sim.dispose() # the last fight is only freed when leaving to the menu
	Engine.time_scale = 1.0
	get_tree().quit()
