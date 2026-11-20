extends Node

## Headless check of the screen flow: main menu -> Play -> game -> lose -> game over
## popup -> Main Menu. Run:
##   Godot_console.exe --headless --path . res://tests/flow_test.tscn


class Driver:
	extends Node

	var step := 0
	var timeout := 40.0
	var wait := 0.0

	func _process(delta: float) -> void:
		timeout -= delta
		wait -= delta
		if timeout <= 0.0:
			push_error("FAIL: flow test timed out at step %d" % step)
			get_tree().quit(1)
			return
		if wait > 0.0:
			return
		var scene := get_tree().current_scene
		match step:
			0:
				if scene != null and scene.name == "MainMenu":
					# Seasons: the picker of the menu shows the season of the next run, then its roster screen
					if not Seasons.enabled():
						step = 5
						return
					var picker := scene.find_child("SeasonPicker", true, false) as OptionButton
					var roster := scene.find_child("SeasonRoster", true, false) as Button
					if picker == null or picker.item_count != Seasons.ids().size() or picker.get_item_text(picker.selected) != Seasons.label() \
							or (roster == null) == Seasons.active():
						push_error("FAIL: season picker of the menu (%s)" % Seasons.current)
						get_tree().quit(1)
						return
					if roster == null: # no season: nothing to list
						step = 5
						return
					roster.pressed.emit()
					step = 20
					wait = 0.3
			20:
				var panels := _all_of(scene, SeasonPanel)
				if panels.is_empty():
					push_error("FAIL: the season roster did not open")
					get_tree().quit(1)
					return
				var panel := panels[0] as SeasonPanel
				var view := scene.get_viewport().get_visible_rect()
				var portraits := _all_of(panel, SynergyMember).size()
				# a new pass has 3 synergies open (Battle Pass): a few Pokémon per row at least
				if panel._rows.get_child_count() != GameData.synergies().size() or portraits < 5 * GameData.synergies().size() \
						or not view.grow(1.0).encloses(panel.get_global_transform() * Rect2(Vector2.ZERO, panel.size)):
					push_error("FAIL: season roster: %d rows, %d portraits, rect %s in %s" % [panel._rows.get_child_count(), portraits,
						panel.get_global_rect(), view])
				print("season roster ok: %s, %d synergies, %d portraits, panel %s" % [Seasons.current, panel._rows.get_child_count(),
					portraits, panel.size])
				(panel.find_child("Close", true, false) as Button).pressed.emit()
				step = 5
				wait = 0.2
			5:
				if scene != null and scene.name == "MainMenu":
					# Battle Pass: its line in the menu, then its screen (a new pass: level 1)
					var pass_button := _find_button(scene, "Battle Pass")
					if pass_button == null or Progression.level() != 1:
						push_error("FAIL: no Battle Pass button / pass level %d" % Progression.level())
						get_tree().quit(1)
						return
					pass_button.pressed.emit()
					step = 10
					wait = 0.3 # a few frames: the panel gets its size
			10:
				var panel := _find_pass_panel(scene)
				if panel == null:
					push_error("FAIL: the Battle Pass screen did not open")
					get_tree().quit(1)
					return
				var cards := panel.find_children("*", "GridContainer", true, false)
				var view := scene.get_viewport().get_visible_rect()
				if cards.is_empty() or cards[0].get_child_count() != Progression.max_level() - 1 \
						or not view.encloses(panel.get_global_rect()):
					push_error("FAIL: Battle Pass screen: %d cards, rect %s in %s" % [
						cards[0].get_child_count() if not cards.is_empty() else -1, panel.get_global_rect(), view])
				print("battle pass screen ok: level %d / %d, %s, panel %s" % [Progression.level(), Progression.max_level(),
					Progression.unlocked_synergies(), panel.get_global_rect().size])
				# to level 2, as a first run would: the cheat button of the screen when the cheats are on
				var plus := _find_button(panel, "+1")
				if plus != null:
					plus.pressed.emit()
				else:
					Progression.set_level(2)
				step = 11
				wait = 0.3
			11:
				var panel := _find_pass_panel(scene)
				var cards := panel.find_children("*", "GridContainer", true, false) if panel != null else []
				if Progression.level() != 2 or cards.is_empty() or cards[0].get_child_count() != Progression.max_level() - 1 \
						or GameData.synergies().size() != Progression.unlocked_synergies(2).size():
					push_error("FAIL: pass level %d after +1, %d synergies" % [Progression.level(), GameData.synergies().size()])
				panel.queue_free()
				var play := _find_button(scene, "Play")
				print("main menu ok (pass level %d), pressing Play" % Progression.level())
				play.pressed.emit()
				step = 1
			1:
				if scene is Game:
					var game := scene as Game
					if game.choices.is_empty() or game.choices[0].kind != "portal":
						push_error("FAIL: the run should start with the starter portal")
					# Battle Pass: the run uses the synergies of level 2 and tells the new one with the first portal
					var fresh: Array = Progression.rewards(2).map(func(t: String) -> String: return GameData.synergy_name(t))
					var info: String = game.hud._town_choice._info.get_parsed_text()
					if game._pass_from != 2 or GameData.synergies().size() != Progression.unlocked_synergies(2).size() \
							or fresh.is_empty() or not info.contains(String(fresh[0])):
						push_error("FAIL: run at pass level %d, news '%s', portal info '%s'" % [game._pass_from, game._run_news, info])
					if not Progression.take_run_news().is_empty():
						push_error("FAIL: the new synergies are told once")
					game.auto_resolve_choices() # portal, then starter
					print("game ok: stage %d, board %s, shop %s" % [game.player.stage, game.player.board.values().map(
						func(u) -> String: return u.pkm), game.player.shop])
					_check_cheats(game)
					game.player.life = 1
					game.player.board.clear()
					game.player.bench.fill(null)
					game.auto_place_on_fight = false
					game._start_fight()
					step = 2
			2:
				if scene is Game and (scene as Game).phase == Game.Phase.OVER:
					var hud: Hud = (scene as Game).hud
					if not hud._game_over.visible:
						push_error("FAIL: game over popup hidden")
						get_tree().quit(1)
						return
					if (hud.get_node("%GameOverRecord") as Label).text == "":
						push_error("FAIL: game over record line empty")
					# the run used cheats: no pass XP (still the first XP of level 2); the Game Over panel fits the screen
					var over_panel: Control = hud._game_over.get_node("Center/Panel")
					if Progression.xp() != Progression.level_start_xp(2) 							or not hud._game_over.get_global_rect().encloses(over_panel.get_global_rect()):
						push_error("FAIL: game over: pass XP %d, panel %s" % [Progression.xp(), over_panel.get_global_rect()])
					print("game over popup ok (%s), back to menu" % (hud.get_node("%GameOverRecord") as Label).text)
					hud.game_over_confirmed.emit()
					step = 3
			3:
				if scene != null and scene.name == "MainMenu":
					print("=== OK flow ===")
					get_tree().quit(0)

	## The cheat panel's actions (F1, data/difficulty.json "cheats"), through the Game.
	func _check_cheats(game: Game) -> void:
		var gold := game.player.gold
		game.cheat_gold(100)
		game.cheat_level(99)
		var commons: Array = GameData.tier1_by_rarity["COMMON"].slice(0, 10)
		for pkm in commons:
			game.cheat_give_pokemon(pkm)
		game.cheat_give_item("RED_ORB")
		game.cheat_unlock_additional()
		var benched := game.player.bench.filter(func(u) -> bool: return u != null).size()
		if game.player.gold < gold + 100 or game.player.level != int(GameData.config.maxLevel) \
				or benched < mini(10, game.player.bench_slots) or not game.player.items.has("RED_ORB") \
				or (not GameData.season_active and game.player.unlocked_additional.size() < 50):
			push_error("FAIL: cheats: gold %d, level %d, bench %d, items %s" % [game.player.gold, game.player.level,
				benched, game.player.items])
		game.cheat_stage(4)
		if game.player.stage != 4 or game.phase != Game.Phase.PLANNING:
			push_error("FAIL: cheat stage: %d" % game.player.stage)
		game.auto_resolve_choices()
		if game.cheats != null:
			game.cheats.toggle()
			game.cheats._fill_pokemon("fire")
			if game.cheats._pkm_list.item_count == 0:
				push_error("FAIL: cheat panel finds no FIRE Pokémon")
			game.cheats.toggle()
		print("cheats ok: stage %d, bench %d (of %d slots)" % [game.player.stage, benched, game.player.bench_slots])

	## Every node under `node` that is a `type` (a class_name script or a native class).
	func _all_of(node: Node, type: Variant, out: Array = []) -> Array:
		for child in node.get_children():
			if is_instance_of(child, type):
				out.append(child)
			_all_of(child, type, out)
		return out

	func _find_pass_panel(node: Node) -> PassPanel:
		for child in node.get_children():
			if child is PassPanel:
				return child
			var found := _find_pass_panel(child)
			if found != null:
				return found
		return null

	func _find_button(node: Node, text: String) -> Button:
		for b in node.find_children("*", "Button", true, false):
			if (b as Button).text == text:
				return b
		return null


func _ready() -> void:
	Records.path = "user://test_records.cfg"
	# a new Battle Pass, not the player's: the run is played with the starting synergies only
	Progression.override_level = -1
	Progression.path = "user://test_progress.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Progression.path))
	Progression.forget()
	# the default season of the file (not the one the player saved), unless "season=<id>" is given
	Seasons.use_default_unless_asked()
	get_tree().root.add_child.call_deferred(Driver.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu.tscn")
