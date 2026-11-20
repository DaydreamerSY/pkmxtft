extends Node

## Headless check of the Battle Pass screens (no window, no screenshot): each one is built at a few
## pass levels and must fit the 1920x1080 canvas, with its parts in place. Run:
##   Godot_console.exe --headless --path . res://tests/layout_test.tscn
## Sizes are printed (layout works headless: only the drawing is missing). Nothing is saved to the
## player's pass (override_level).

var failures := 0


func _ready() -> void:
	GameData.set_language("vi") # the longest texts of the two written languages
	TranslationServer.set_locale("vi")
	Seasons.use_default_unless_asked() # the season of the file, not the one the player saved
	await _menu(1)
	await _menu(11)
	await _menu(Progression.max_level())
	await _menu_news()
	await _game_over()
	_export_fidelity()
	_insets()
	await _phone(1.65)
	await _phone(2.0)
	# the phone this layout was tuned on: x2.0, the camera punch hole at mid height of the left edge
	await _phone(2.0, Vector2(60, 0), [Rect2(0, 246, 60, 48)])
	await _phone(2.0, Vector2(0, 60), [Rect2(1111, 246, 60, 48)]) # held the other way round
	await _phone(2.0, Vector2(60, 0)) # a device that does not tell where the hole is: the whole strip
	await _phone(1.65, Vector2(64, 40))
	# berry trees and flower pots above the left column (Grass and Flora active)
	await _phone(2.0, Vector2(60, 0), [Rect2(0, 246, 60, 48)], true)
	# a small 16:9 phone at the largest size: cramped (parts may shrink), but nothing leaves the screen
	await _phone(2.0, Vector2(-1, -1), null, false, Vector2i(1920, 1080), false)
	UiScale.test_insets = Vector2(-1, -1)
	UiScale.test_cutouts = null
	await _rescale()
	await _touch()
	print("=== %s layout (%d failure(s)) ===" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _fail(msg: String) -> void:
	failures += 1
	push_error("FAIL: " + msg)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _set_level(level: int) -> void:
	Progression.override_level = level
	GameData.apply_progression()


## The main menu with its pass line, then the pass screen over it.
func _menu(level: int) -> void:
	_set_level(level)
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await _frames(4)
	var view := menu.get_viewport().get_visible_rect()
	var box: Control = menu.get_node("Center/Box")
	var line: Control = menu._pass_line
	var footer: Control = menu.get_node("%Footer")
	if not view.encloses(box.get_global_rect()) or box.get_global_rect().end.y > footer.get_global_rect().position.y:
		_fail("menu (level %d): box %s, footer %s, view %s" % [level, box.get_global_rect(), footer.get_global_rect(), view])
	if line.get_child_count() < 3 or not view.encloses(line.get_global_rect()):
		_fail("menu (level %d): pass line %s with %d parts" % [level, line.get_global_rect(), line.get_child_count()])
	await _season_roster(menu, "menu (level %d)" % level)
	var panel := PassPanel.create()
	panel.open_over(menu)
	await _frames(4)
	var rect := Hud.shown_rect(panel)
	var grids := panel.find_children("*", "GridContainer", true, false)
	var cards: int = grids[0].get_child_count() if not grids.is_empty() else 0
	if not view.grow(-8.0).encloses(rect):
		_fail("pass screen (level %d): %s does not fit %s" % [level, rect, view])
	if cards != Progression.max_level() - 1:
		_fail("pass screen (level %d): %d level cards" % [level, cards])
	# every card has the same size (a long synergy name must not widen its column)
	var widths := {}
	for card in (grids[0].get_children() if not grids.is_empty() else []):
		widths[(card as Control).size] = true
	if widths.size() > 1:
		_fail("pass screen (level %d): cards of different sizes %s" % [level, widths.keys()])
	print("level %2d: menu box %s, pass line %s (%d parts), pass screen %s, %d cards of %s" % [level, box.size, line.size,
		line.get_child_count(), rect.size, cards, widths.keys()])
	menu.queue_free()
	await _frames(2)


## Seasons: the line of the menu under the pickers, then the roster screen over it - one row per
## synergy, inside the canvas (scaled down on a small one).
func _season_roster(menu: Control, label: String) -> void:
	if not Seasons.enabled():
		return
	var view := menu.get_viewport().get_visible_rect()
	var line: Control = menu._season_line
	var shown_line := line.get_global_transform() * Rect2(Vector2.ZERO, line.size)
	if line.get_child_count() < 1 or not view.grow(1.0).encloses(shown_line):
		_fail("%s: season line %s with %d parts" % [label, shown_line, line.get_child_count()])
	if not Seasons.active():
		return
	var roster := SeasonPanel.create()
	roster.open_over(menu)
	await _frames(5)
	var shown := roster.get_global_transform() * Rect2(Vector2.ZERO, roster.size)
	if not view.grow(1.0).encloses(shown) or roster._rows.get_child_count() != GameData.synergies().size():
		_fail("%s: season roster %s in %s, %d rows for %d synergies" % [label, shown, view, roster._rows.get_child_count(),
			GameData.synergies().size()])
	print("%s: season line %s, roster %s x%.2f (%d rows)" % [label, line.size, roster.size, (roster.get_parent() as Control).scale.y,
		roster._rows.get_child_count()])
	roster.queue_free()
	await _frames(2)


## Back from a run that reached two levels (a test save): the menu shows the new synergies until the
## pass screen is opened, then the next one.
func _menu_news() -> void:
	Progression.override_level = -1
	Progression.path = "user://test_progress.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Progression.path))
	Progression.forget()
	Progression.add_xp(Progression.level_start_xp(3))
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await _frames(4)
	var view := menu.get_viewport().get_visible_rect()
	var line: Control = menu._pass_line
	var fresh := Progression.unseen_synergies()
	var chips: int = line.get_child(line.get_child_count() - 1).get_child_count()
	if fresh != Progression.synergies_between(1, 3) or chips != fresh.size() or not view.encloses(line.get_global_rect()):
		_fail("menu after a run: new %s, %d chips, line %s" % [fresh, chips, line.get_global_rect()])
	var new_width := line.size.x
	var panel := PassPanel.create()
	panel.closed.connect(menu._show_pass)
	panel.open_over(menu)
	await _frames(2)
	panel.queue_free()
	panel.closed.emit()
	await _frames(3)
	chips = line.get_child(line.get_child_count() - 1).get_child_count()
	if not Progression.unseen_synergies().is_empty() or chips != Progression.rewards(4).size():
		_fail("menu after the pass screen: still new %s, %d chips" % [Progression.unseen_synergies(), chips])
	print("after a run: pass line %s with the new %s, then %s with the next one" % [new_width, fresh, line.size.x])
	menu.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Progression.path))
	Progression.forget()


## The Game Over panel with the statistics of a run and a pass level reached.
func _game_over() -> void:
	_set_level(4)
	var game: Game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await _frames(4)
	var entry := func(pkm: String, physical: float, special: float) -> Dictionary:
		return {"pkm": pkm, "physical": physical, "special": special, "true": physical * 0.1, "reduced": special * 0.5,
			"shield_taken": 120.0, "heal": physical * 0.2, "shield": 80.0, "fights": 17}
	var pokemons: Array = GameData.tier1_by_rarity["COMMON"].slice(0, 5)
	var team: Array = []
	for pkm in GameData.tier1_by_rarity["COMMON"].slice(0, 9):
		team.append({"pkm": pkm, "stars": 2})
	var damage: Array = pokemons.map(func(pkm: String) -> Dictionary: return entry.call(pkm, 4200.0, 18400.0))
	var pass_report := {"level": 4, "max_level": Progression.max_level(), "into": 60, "need": 160, "xp": 615, "from": 2, "to": 4,
		"unlocked": Progression.synergies_between(2, 4), "fair": false}
	game.hud.show_game_over(17, {"stage": 21}, false, false, {"fights": 17, "wins": 12, "losses": 5, "draws": 0,
		"seconds": 1234, "gold": 312, "rerolls": 41, "level": 8, "team": team, "damage": damage,
		"blocked": [damage[0]], "healing": [damage[1]],
		"best_fight": {"pkm": pokemons[0], "damage": 3456.0, "stage": 15}, "pass": pass_report})
	await _frames(4)
	var view := game.hud.get_node("Root").get_viewport().get_visible_rect()
	var panel: Control = game.hud._game_over.get_node("Center/Panel")
	if not view.grow(-8.0).encloses(panel.get_global_rect()):
		_fail("game over: panel %s does not fit %s" % [panel.get_global_rect(), view])
	var summaries := panel.find_children("*", "VBoxContainer", true, false).filter(func(n: Node) -> bool: return n is RunSummary)
	if summaries.is_empty():
		_fail("game over: no run summary")
	print("game over: panel %s (pass level-up with %s)" % [panel.size, pass_report.unlocked])
	if game.sim != null:
		game.sim.dispose()
	game.queue_free()
	await _frames(2)


## UiScale.band_insets: the strip of the camera cutout is avoided only where the cutout reaches, and
## everywhere when the device does not tell where the cutout is (or tells nonsense).
func _insets() -> void:
	var canvas := Vector2(1171, 540)
	var cases := [
		# [strip, cutouts, band y0, y1, expected]
		[Vector2(0, 0), [Rect2(0, 246, 60, 48)], 0.0, 408.0, Vector2(0, 0)],
		[Vector2(60, 0), null, 416.0, 540.0, Vector2(60, 0)],
		[Vector2(60, 0), [], 416.0, 540.0, Vector2(60, 0)],
		[Vector2(60, 0), [Rect2(0, 246, 60, 48)], 0.0, 408.0, Vector2(60, 0)],
		[Vector2(60, 0), [Rect2(0, 246, 60, 48)], 416.0, 540.0, Vector2(0, 0)],
		[Vector2(60, 0), [Rect2(0, 246, 60, 48)], 0.0, 75.0, Vector2(0, 0)],
		[Vector2(0, 60), [Rect2(1111, 246, 60, 48)], 0.0, 408.0, Vector2(0, 60)],
		[Vector2(0, 60), [Rect2(1111, 246, 60, 48)], 416.0, 540.0, Vector2(0, 0)],
		[Vector2(60, 60), [Rect2(0, 246, 60, 48)], 0.0, 408.0, Vector2(60, 0)],
		[Vector2(60, 0), [Rect2(250, 0, 40, 60)], 416.0, 540.0, Vector2(60, 0)], # axes swapped: not trusted
		[Vector2(60, 0), [Rect2(1111, 246, 60, 48)], 416.0, 540.0, Vector2(60, 0)], # on the other side: not trusted
	]
	for c in cases:
		UiScale.test_insets = c[0]
		UiScale.test_cutouts = c[1]
		var got := UiScale.band_insets(canvas, c[2], c[3])
		if not got.is_equal_approx(c[4]):
			_fail("insets: strip %s cutouts %s band %s..%s gives %s, expected %s" % [c[0], c[1], c[2], c[3], got, c[4]])
	UiScale.test_insets = Vector2(-1, -1)
	UiScale.test_cutouts = null
	print("insets: %d cases of the camera cutout" % cases.size())


## What an export does to the scenes: it packs them again, and a property equal to its default is not
## saved. A property set before it may then leave another value: "anchors_preset" sets the grow directions,
## so a hand-written "grow_vertical = 1" next to "anchors_preset = 6" is BOTH in the exported game and END
## in the editor (the unit panel left the top of the screen on a phone that way). Every scene of the game
## must instantiate the same before and after being packed again.
func _export_fidelity() -> void:
	var scenes: Array[String] = []
	_scene_files("res://scenes", scenes)
	var differences := 0
	for path in scenes:
		var packed: PackedScene = load(path)
		var a := packed.instantiate()
		var b_source := packed.instantiate()
		var repacked := PackedScene.new()
		if repacked.pack(b_source) != OK:
			_fail("export: cannot pack %s" % path)
		else:
			var b := repacked.instantiate()
			differences += _compare_nodes(a, b, a, path)
			b.free()
		b_source.free()
		a.free()
	if differences > 0:
		_fail("export: %d value(s) change when the scenes are exported (see above)" % differences)
	print("export: %d scenes keep their values when packed again" % scenes.size())


func _scene_files(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_scene_files(dir.path_join(d), out)


## Stored values of two instances of a scene (objects apart), node by node; prints what differs.
func _compare_nodes(a: Node, b: Node, root: Node, path: String) -> int:
	var n := 0
	for property in a.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_STORAGE):
			continue
		var va: Variant = a.get(property.name)
		var vb: Variant = b.get(property.name)
		if va is Object or vb is Object:
			continue
		if typeof(va) != typeof(vb) or va != vb:
			n += 1
			push_error("FAIL: export: %s  %s.%s is %s in the editor, %s once exported" % [path, root.get_path_to(a), property.name, va, vb])
	for i in mini(a.get_child_count(), b.get_child_count()):
		n += _compare_nodes(a.get_child(i), b.get_child(i), root, path)
	return n


## Where a control is drawn on the canvas (its scale included).
func _shown(control: Control) -> Rect2:
	return Hud.shown_rect(control)


## A phone: a 2000x922 screen with the UI scaled up (UiScale): the HUD takes its compact layout, nothing
## leaves the canvas, hides under the camera cutout or overlaps, with the longest texts of the game; the
## unit panel fits above the Fight button at its normal size; the camera frames the board in the room left;
## the menus fit too. `insets`: the strip of the cutout (left, right), `holes`: the cutouts (canvas units;
## none: the device does not tell), `garden`: with the berry trees and the flower pots, `screen`: its
## size in pixels, `strict` false: a screen too small for the layout - parts may shrink or overlap the
## Fight button, they must only stay on the canvas.
func _phone(factor: float, insets := Vector2(-1, -1), holes: Variant = null, garden := false,
		screen := Vector2i(2000, 922), strict := true) -> void:
	var window := get_window()
	var old_size := window.size
	window.size = screen
	window.content_scale_factor = factor
	UiScale.test_insets = insets
	UiScale.test_cutouts = holes
	var label := "phone %dx%d x%s" % [screen.x, screen.y, factor] + ("" if insets.x < 0.0 else " insets %s%s" % [insets,
		" with the hole" if holes != null else ""]) + (" + garden" if garden else "")
	_set_level(9999)
	var game: Game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await _frames(5)
	var hud := game.hud
	var canvas: Rect2 = hud.get_node("Root").get_viewport_rect()
	if not hud.compact or canvas.size.y > UiScale.COMPACT_HEIGHT:
		_fail("%s: canvas %s is not compact" % [label, canvas.size])
	game.auto_resolve_choices()
	game.player.gold = 500
	game.player.level = 9
	for _round in 4: # a full board of different Pokémon: as many synergy rows as it gets
		for i in 6:
			game.player.buy(i)
		game.player.roll_shop()
	game.player.auto_place()
	for item in ["CHARCOAL", "MAGNET", "TWISTED_SPOON", "MYSTIC_WATER", "HEART_SCALE", "BLACK_GLASSES", "RED_ORB", "CHOICE_SPECS", "MIRACLE_SEED"]:
		game.player.items.append(item)
	game._on_player_changed()
	if garden: # three berry trees and the five pots, whatever the synergies of the board
		for i in 3:
			(hud.garden._buttons[i].get_parent() as Control).visible = true
			hud.garden._buttons[i].icon = GameData.item_icon("ORAN_BERRY")
		hud.garden._pot_box.visible = true
		hud.garden.visible = true
	# the longest texts: region name, wave name, phase, enemy synergies, level
	var longest_map := ""
	for map in GameData.config.get("maps", {}):
		if TownChoice.map_name(map).length() > longest_map.length():
			longest_map = TownChoice.map_name(map)
	hud._region_label.text = longest_map
	hud._region_label.visible = true
	hud._update_region_label()
	hud.set_enemy_synergies({"FIRE": 4, "WATER": 6, "GRASS": 5, "NORMAL": 6, "ELECTRIC": 5})
	hud._wave_label.text = L.t("vs %s") % "Regigigas, Regirock & Registeel"
	hud._phase_label.text = L.t("Combat %ds") % 45
	hud._level_label.text = L.t("Level %d  •  team %d/%d") % [10, 10, 10]
	await _frames(6)
	var parts := {"shop": hud.shop, "fight": hud._fight_button, "items": hud.item_bench, "synergies": hud.synergies,
		"stage": hud._stage_bar, "player": hud._player_panel}
	if garden:
		parts["garden"] = hud.garden
		if not hud.garden.visible or hud.garden.size.x < 250.0:
			_fail("%s: the garden is not shown whole (%s, visible %s)" % [label, hud.garden.size, hud.garden.visible])
	for part_name in parts:
		_check_inside(label, part_name, parts[part_name], canvas)
	var names: Array = parts.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a := _shown(parts[names[i]])
			var b := _shown(parts[names[j]])
			if a.grow(-1.0).intersects(b.grow(-1.0)):
				_fail("%s: %s %s overlaps %s %s" % [label, names[i], a, names[j], b])
	# the stage bar: both lines whole (the wave name alone may be cut, the region name ends with "...")
	var bar_content: Control = hud._stage_bar.get_child(0)
	if bar_content.get_combined_minimum_size().x > bar_content.size.x + 0.5:
		_fail("%s: the stage bar needs %s, has %s" % [label, bar_content.get_combined_minimum_size().x, bar_content.size.x])
	# shop cards: the names whole (a smaller font), but for the few longer than a card at the smallest font
	var pool: Array = GameData.full_list("pool")
	var cut: Array = []
	var card: ShopCard = hud.shop.cards[0]
	var font := card._name.get_theme_font("font")
	for pkm in pool:
		var text := GameData.display_name(pkm)
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ShopCard.MIN_NAME_FONT).x > card._name.size.x:
			cut.append(text)
	if strict and cut.size() * 10 > pool.size():
		_fail("%s: %d of %d shop names are cut on a card %s wide: %s" % [label, cut.size(), pool.size(), card.size.x, cut.slice(0, 8)])
	var longest_fitting := ""
	for pkm in pool: # the longest one with a few pixels to spare (the cost next to it is not always as wide)
		var text := GameData.display_name(pkm)
		if text.length() > longest_fitting.length() \
				and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ShopCard.MIN_NAME_FONT).x < card._name.size.x - 6.0:
			longest_fitting = text
			card.show_pokemon(pkm, true)
	await _frames(2)
	var name_font := card._name.get_theme_font_size("font_size")
	if font.get_string_size(card._name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_font).x > card._name.size.x + 0.5:
		_fail("%s: the card name '%s' is cut at font %d (room %s)" % [label, card._name.text, name_font, card._name.size.x])
	# the board: framed inside the room the panels leave, and not tiny
	var rim := game.arena.rim_margin * game.arena.cell_size
	var half := game.arena.board_half_width() + rim
	var near := game.arena.bench_near_z() + rim
	var far := game.arena.board_far_z() - rim
	var corners := PackedVector3Array([Vector3(-half, 0, near), Vector3(half, 0, near),
		Vector3(-half, 0, far), Vector3(half, 0, far)])
	var board := game.camera.screen_box(corners)
	if not hud.board_rect.grow(2.0).encloses(board) or (strict and board.size.y < 0.45 * canvas.size.y):
		_fail("%s: board %s in the room %s (canvas %s)" % [label, board, hud.board_rect, canvas.size])
	for part_name in parts:
		if strict and board.grow(-2.0).intersects(_shown(parts[part_name])):
			_fail("%s: the board %s is under %s" % [label, board, part_name])
	# Pokémon inspected (the tallest panels: three synergies, a passive, items): the panel keeps its size,
	# stays on the canvas and leaves the Fight button, the shop, the stage bar and the left column alone
	var info := hud.info_panel
	var tallest := 0.0
	var views: Array = game.owned_views.values()
	views.sort_custom(func(a: UnitView, b: UnitView) -> bool: return _panel_weight(a.pkm) > _panel_weight(b.pkm))
	for view in views.slice(0, 4):
		game._show_info(view)
		await _frames(5)
		var rect := _shown(info)
		tallest = maxf(tallest, rect.size.y)
		_check_inside(label, "unit panel (%s)" % (view as UnitView).pkm, info, canvas)
		if not info.visible or (strict and not is_equal_approx(info.scale.y, 1.0)):
			_fail("%s: unit panel of %s is shrunk x%s (%s)" % [label, (view as UnitView).pkm, info.scale.y, info.size])
		for part_name in ["shop", "fight", "items", "synergies", "stage"] if strict else ["shop", "items", "synergies"]:
			if rect.grow(-1.0).intersects(_shown(parts[part_name])):
				_fail("%s: unit panel %s of %s overlaps %s %s" % [label, rect, (view as UnitView).pkm, part_name, _shown(parts[part_name])])
	# the longest name of the shop pool: whole in the header of the panel (a smaller font)
	var long_pkm: String = pool[0]
	for pkm in pool:
		if GameData.display_name(pkm).length() > GameData.display_name(long_pkm).length():
			long_pkm = pkm
	info.show_unit({"pkm": long_pkm, "team": BattleUnit.Team.BLUE, "items": [], "player": game.player})
	await _frames(5)
	var panel_name: Label = info._name
	if strict and panel_name.get_theme_font("font").get_string_size(panel_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			panel_name.get_theme_font_size("font_size")).x > panel_name.size.x + 0.5:
		_fail("%s: the name '%s' is cut in the unit panel (font %d, room %s)" % [label, panel_name.text,
			panel_name.get_theme_font_size("font_size"), panel_name.size.x])
	_check_inside(label, "unit panel (%s)" % long_pkm, info, canvas)
	game._close_info()
	# the item choice with its longest title (a Fairy wand): the title wraps, the popup stays narrow and
	# under the stage bar
	var wands: Array[String] = ["TWISTED_SPOON", "CHARCOAL", "MAGNET"]
	hud.show_item_choice(wands, String(GameData.text.get("choose_wand", "Chọn một đũa phép, thêm hiệu ứng cho đòn đánh của Pokémon Tiên")))
	await _frames(5)
	var choice := _shown(hud._item_choice)
	_check_inside(label, "item choice", hud._item_choice, canvas)
	if choice.position.y < _shown(hud._stage_bar).end.y - 0.5 or (strict and choice.size.x > 520.0):
		_fail("%s: item choice %s (stage bar %s)" % [label, choice, _shown(hud._stage_bar)])
	# each item card has an "i" button: it shows what the item does (pinned tooltip on the canvas) without picking it
	var item_card: Control = hud._item_choice._row.get_child(0)
	var info_button := item_card.find_child("Info", true, false) as Button
	if info_button == null:
		_fail("%s: no detail button on the item cards" % label)
	else:
		hud.tips.close_all()
		info_button.pressed.emit()
		await _frames(4)
		var tip_panel: Control = hud.tips._levels[0].panel if hud.tips.has_open() else null
		if tip_panel == null or not hud._item_choice.visible or not canvas.grow(1.0).encloses(Hud.shown_rect(tip_panel)) 				or not _shown(info_button).grow(-1.0).intersects(_shown(item_card)):
			_fail("%s: the detail button of %s: tooltip %s, choice still open %s" % [label, item_card.item,
				Hud.shown_rect(tip_panel) if tip_panel != null else Rect2(), hud._item_choice.visible])
		info_button.pressed.emit() # a second press closes it
		await _frames(2)
		if hud.tips.has_open():
			_fail("%s: a second press on the detail button should close the tooltip" % label)
	hud.hide_item_choice()
	# the fight statistics (shown during and after a fight) and the banner: on the canvas, clear of the shop
	hud.update_dps(views.slice(0, 8).map(func(v: UnitView) -> Dictionary:
		return {"unit": BattleUnit.create(v.pkm, BattleUnit.Team.BLUE), "physical": 120.0, "special": 40.0, "true": 0.0,
			"reduced": 30.0, "shield_taken": 10.0, "heal": 5.0, "shield": 0.0}))
	hud.banner("%s\n%s" % [L.t("Victory!"), "+ " + GameData.item_name("TWISTED_SPOON")], UiStyle.GREEN, 1.0)
	await _frames(4)
	if hud.dps_meter.visible:
		_check_inside(label, "fight statistics", hud.dps_meter, canvas)
		if _shown(hud.dps_meter).grow(-1.0).intersects(_shown(hud.shop)) or _shown(hud.dps_meter).grow(-1.0).intersects(_shown(hud._player_panel)):
			_fail("%s: fight statistics %s over the shop / the player panel" % [label, _shown(hud.dps_meter)])
	if _shown(hud._banner).position.y < _shown(hud._stage_bar).end.y - 0.5 or _shown(hud._banner).size.x > canvas.size.x:
		_fail("%s: banner %s over the stage bar %s" % [label, _shown(hud._banner), _shown(hud._stage_bar)])
	# the shop closed (the game closes it for the fights, the player with its button): the dock under the left
	# column, the Fight button in the corner, and the board down to the bottom of the screen
	hud.dps_meter.visible = false
	hud.set_shop_open(false)
	await _frames(6)
	var closed := label + ", shop closed"
	var closed_parts := {"dock": hud._dock, "fight": hud._fight_button, "items": hud.item_bench, "synergies": hud.synergies,
		"stage": hud._stage_bar, "player": hud._player_panel}
	if hud.shop.visible or not hud._dock.visible:
		_fail("%s: shop visible %s, dock visible %s" % [closed, hud.shop.visible, hud._dock.visible])
	for part_name in closed_parts:
		_check_inside(closed, part_name, closed_parts[part_name], canvas)
	var closed_names: Array = closed_parts.keys()
	for i in closed_names.size():
		for j in range(i + 1, closed_names.size()):
			var a := _shown(closed_parts[closed_names[i]])
			var b := _shown(closed_parts[closed_names[j]])
			if a.grow(-1.0).intersects(b.grow(-1.0)):
				_fail("%s: %s %s overlaps %s %s" % [closed, closed_names[i], a, closed_names[j], b])
	var big := game.camera.screen_box(corners)
	# the board fills the room the panels leave (the auto angle: as wide or as tall as that room)
	var room := hud.board_room_full
	if strict and big.size.x < 0.9 * room.size.x and big.size.y < 0.8 * room.size.y:
		_fail("%s: board %s does not fill its room %s (angle %s°)" % [closed, big.size, room.size, game.camera.pitch_degrees])
	if not hud.board_rect.grow(2.0).encloses(big) or (strict and (big.size.y < 0.65 * canvas.size.y or big.size.x < 1.2 * board.size.x)):
		_fail("%s: board %s in the room %s (canvas %s, board with the shop %s)" % [closed, big, hud.board_rect, canvas.size, board.size])
	for part_name in closed_parts:
		if big.grow(-2.0).intersects(_shown(closed_parts[part_name])):
			_fail("%s: the board %s is under %s %s" % [closed, big, part_name, _shown(closed_parts[part_name])])
	# selling without the shop: the dock is the sell zone and says so while a unit is dragged
	var dock_rect := _shown(hud._dock)
	hud.show_sell(-1, true)
	var hint := hud._dock_sell.visible and hud._dock_sell.text != "" and not hud._dock_row.visible
	hud.show_sell(3, true)
	var price := hud._dock_sell.visible and hud._dock_sell.text.contains("3")
	hud.show_sell(-1)
	if not hud.is_over_shop(dock_rect.get_center()) or hud.is_over_shop(canvas.get_center()) or not hint or not price \
			or hud._dock_sell.visible or not hud._dock_row.visible:
		_fail("%s: the dock %s as a sell zone (hint %s, price %s)" % [closed, dock_rect, hint, price])
	if hud._dock_gold.text != str(game.player.gold):
		_fail("%s: the dock shows %s gold, the player has %d" % [closed, hud._dock_gold.text, game.player.gold])
	# a Pokémon inspected: the panel on the canvas, clear of the left column, the stage bar and the Fight button
	game._show_info(views[0])
	await _frames(5)
	_check_inside(closed, "unit panel", info, canvas)
	for part_name in ["dock", "items", "synergies", "stage"] + (["fight"] if strict else []):
		if _shown(info).grow(-1.0).intersects(_shown(closed_parts[part_name])):
			_fail("%s: unit panel %s overlaps %s %s" % [closed, _shown(info), part_name, _shown(closed_parts[part_name])])
	game._close_info()
	# the fight statistics next to the bigger board
	hud.update_dps(views.slice(0, 8).map(func(v: UnitView) -> Dictionary:
		return {"unit": BattleUnit.create(v.pkm, BattleUnit.Team.BLUE), "physical": 120.0, "special": 40.0, "true": 0.0,
			"reduced": 30.0, "shield_taken": 10.0, "heal": 5.0, "shield": 0.0}))
	await _frames(4)
	if hud.dps_meter.visible:
		_check_inside(closed, "fight statistics", hud.dps_meter, canvas)
		# the board is a trapezoid on the screen (wider at the bottom): its right edge at the bottom of the statistics
		var meter := _shown(hud.dps_meter)
		var far_right := game.camera.unproject_position(corners[3])
		var near_right := game.camera.unproject_position(corners[1])
		var edge := lerpf(far_right.x, near_right.x, clampf(inverse_lerp(far_right.y, near_right.y, meter.end.y), 0.0, 1.0))
		if meter.grow(-1.0).intersects(_shown(hud._fight_button)) or (strict and meter.position.x < edge):
			_fail("%s: fight statistics %s over the Fight button / the board (its right edge there: %s)" % [closed, meter, edge])
	# the angle of the board is a setting (Options, compact only): a fixed angle is used as it is, auto again after
	Settings.board_pitch = 50
	game._frame_board()
	var fixed := game.camera.pitch_degrees
	Settings.board_pitch = 0
	game._frame_board()
	if not is_equal_approx(fixed, 50.0) or game.camera.pitch_degrees < Game.AUTO_PITCH_MIN or game.camera.pitch_degrees > Game.AUTO_PITCH_MAX:
		_fail("%s: board angle 50 -> %s, auto -> %s" % [closed, fixed, game.camera.pitch_degrees])
	var options := OptionsPanel.create(true)
	if options.find_child("BoardPitch", true, false) == null:
		_fail("%s: no board angle in the options of a phone" % closed)
	options.free()
	await _frames(2)
	# the button of the dock opens the shop again: the board is back to its room above it
	(hud._dock.find_child("Open", true, false) as Button).pressed.emit()
	await _frames(6)
	var again := game.camera.screen_box(corners)
	if not hud.shop.visible or hud._dock.visible or not again.size.is_equal_approx(board.size):
		_fail("%s: shop opened again: visible %s, board %s (was %s)" % [label, hud.shop.visible, again.size, board.size])
	# the Game Over panel
	var view: UnitView = views[0]
	hud.show_game_over(17, {"stage": 21}, false, true, {"fights": 17, "wins": 12, "losses": 5, "draws": 0, "seconds": 1234,
		"gold": 312, "rerolls": 41, "level": 8, "team": [{"pkm": view.pkm, "stars": 2}], "damage": [], "blocked": [], "healing": [],
		"best_fight": {}, "pass": {"level": 4, "max_level": 22, "into": 60, "need": 160, "xp": 215, "from": 3, "to": 4,
		"unlocked": Progression.rewards(4), "fair": true}})
	await _frames(4)
	var over: Control = hud._game_over.get_node("Center/Panel")
	var over_scale: Vector2 = (hud._game_over.get_node("Center") as Control).scale
	if over.size.y * over_scale.y > canvas.size.y or over.size.x * over_scale.x > canvas.size.x:
		_fail("%s: Game Over panel %s x%s in %s" % [label, over.size, over_scale, canvas.size])
	var rows: int = hud.synergies.get_children().filter(func(n: Node) -> bool: return n is SynergyRow and not n.is_queued_for_deletion()).size()
	print("%s: canvas %s, shop %s (cards %s, %d long names cut), stage bar %s, %d item slots, %d synergy rows, board %s in %s (shop closed: %s = x%.2f), unit panel up to %s high (Fight at %s), game over x%.2f" % [
		label, canvas.size, _shown(hud.shop), card.size.x, cut.size(), _shown(hud._stage_bar), hud.item_bench.page_size(), rows,
		board.size, hud.board_rect.size, big.size, big.size.x / maxf(board.size.x, 1.0), tallest, _shown(hud._fight_button).position.y, over_scale.y])
	print("%s: camera angle %s°, room with the shop closed %s, bench %d slots x %d" % [label, game.camera.pitch_degrees,
		hud.board_room_full.size, game.player.bench_slots, game.player.bench_stack])
	if game.sim != null:
		game.sim.dispose()
	game.queue_free()
	await _frames(2)
	# the main menu and the pass screen
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await _frames(5)
	var box: Control = menu.get_node("Center/Box")
	var box_scale: Vector2 = (menu.get_node("Center") as Control).scale
	var footer: Control = menu.get_node("%Footer")
	if box.size.y * box_scale.y > footer.get_global_rect().position.y or box.size.x * box_scale.x > canvas.size.x:
		_fail("%s: menu box %s x%s, footer at %s" % [label, box.size, box_scale, footer.get_global_rect().position.y])
	await _season_roster(menu, label)
	var panel := PassPanel.create()
	panel.open_over(menu)
	await _frames(5)
	# where the screen is really drawn (its container may be scaled): inside the canvas, and on a phone at its
	# size (the compact screen fits without shrinking its texts); every level card shown
	var panel_scale: Vector2 = (panel.get_parent() as Control).scale
	var shown := Hud.shown_rect(panel)
	var level_cards: int = panel.find_children("*", "GridContainer", true, false).map(func(g: Node) -> int:
		return g.get_child_count()).reduce(func(a: int, b: int) -> int: return a + b, 0)
	if not canvas.grow(1.0).encloses(shown) or (strict and panel_scale.y < 0.99) or level_cards != Progression.max_level() - 1:
		_fail("%s: pass screen drawn at %s x%s in %s, %d level cards" % [label, shown, panel_scale, canvas.size, level_cards])
	var menu_options := OptionsPanel.create(false)
	menu_options.open_over(menu)
	await _frames(4)
	if not canvas.grow(1.0).encloses(Hud.shown_rect(menu_options)):
		_fail("%s: options drawn at %s in %s" % [label, Hud.shown_rect(menu_options), canvas.size])
	menu_options.queue_free()
	print("%s: menu box %s x%.2f, pass screen %s x%.2f at %s" % [label, box.size, box_scale.y, panel.size, panel_scale.y, shown.position])
	menu.queue_free()
	await _frames(2)
	window.content_scale_factor = 1.0
	window.size = old_size
	await _frames(2)


## A part of the compact HUD is on the canvas, clear of the rounded corners of the screen and of the
## camera cutout where it reaches (UiScale.band_insets).
func _check_inside(label: String, part_name: String, part: Control, canvas: Rect2) -> void:
	var rect := _shown(part)
	var inset := UiScale.band_insets(canvas.size, rect.position.y, rect.end.y)
	var left := maxf(inset.x, Hud.COMPACT_CORNER - 0.5)
	var right := maxf(inset.y, Hud.COMPACT_CORNER - 0.5)
	if rect.position.x < left - 0.5 or rect.end.x > canvas.size.x - right + 0.5 \
			or rect.position.y < canvas.position.y + Hud.COMPACT_MARGIN - 0.5 or rect.end.y > canvas.end.y - Hud.COMPACT_MARGIN + 0.5:
		_fail("%s: %s %s leaves the canvas %s (left %s, right %s)" % [label, part_name, rect, canvas.size, left, right])


## How tall the unit panel of a Pokémon gets: synergies, a passive.
func _panel_weight(pkm: String) -> int:
	var data := GameData.get_pokemon(pkm)
	return data.get("types", []).size() * 2 + (3 if GameData.passive_desc(String(data.get("passive", ""))) != "" else 0)


## The UI size changed during a run (Options): the HUD goes compact and back, the shop bar gets its
## scene layout again.
func _rescale() -> void:
	var window := get_window()
	var old_size := window.size
	window.size = Vector2i(2000, 922)
	_set_level(4)
	var game: Game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await _frames(5)
	var hud := game.hud
	var was_compact := hud.compact
	var camera_distance := game.camera.distance
	window.content_scale_factor = 1.65
	await _frames(5)
	var compact_now := hud.compact
	var one_row: bool = not (hud.shop.get_node("V/Top") as Control).visible and hud.shop._buy_xp.get_parent().name != "Left"
	window.content_scale_factor = 1.0
	await _frames(5)
	var back: bool = not hud.compact and (hud.shop.get_node("V/Top") as Control).visible \
		and hud.shop._buy_xp.get_parent().name == "Left" and hud.shop._buy_xp.get_index() == 0 \
		and hud.shop._lock.get_parent().name == "Top" and is_equal_approx(game.camera.distance, camera_distance)
	if was_compact or not compact_now or not one_row or not back:
		_fail("rescale: compact %s -> %s (one row %s) -> back %s" % [was_compact, compact_now, one_row, back])
	# the other compact parts: every node back where the scene has it
	var fresh: Hud = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(fresh)
	await _frames(3)
	for part in ["Root/StageBar", "Root/PlayerPanel", "Root/UnitInfoPanel", "Root/ItemBench"]:
		var now := _tree_names(hud.get_node(part))
		var scene := _tree_names(fresh.get_node(part))
		if now != scene:
			_fail("rescale: %s is not back to its scene order:\n  now   %s\n  scene %s" % [part, now, scene])
	for part in ["Root/StageBar", "Root/PlayerPanel", "Root/UnitInfoPanel", "Root/Fight", "Root/ShopBar", "Root/Banner"]:
		var a: Control = hud.get_node(part)
		var b: Control = fresh.get_node(part)
		if a.position.distance_to(b.position) > 0.5 or a.grow_vertical != b.grow_vertical or a.grow_horizontal != b.grow_horizontal:
			_fail("rescale: %s at %s (grow %d %d), the scene has it at %s (grow %d %d)" % [part, a.position, a.grow_horizontal,
				a.grow_vertical, b.position, b.grow_horizontal, b.grow_vertical])
	fresh.queue_free()
	await _frames(2)
	HoverTip.current = hud.tips
	print("rescale: scene layout -> compact -> scene layout (camera, stage bar, player panel and unit panel restored)")
	if game.sim != null:
		game.sim.dispose()
	game.queue_free()
	window.size = old_size
	await _frames(2)


## Touch screens (UiScale.touch): a tap shows the details of a Pokémon / an item / an element with a
## tooltip, a drag still moves; a button shows its tooltip on a long press only.
func _touch() -> void:
	UiScale.touch = true
	_set_level(4)
	var game: Game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await _frames(5)
	game.auto_resolve_choices()
	game.player.gold = 60
	for i in 3:
		game.player.buy(i)
	game.player.auto_place()
	game.player.items.append("CHARCOAL")
	game._on_player_changed()
	await _frames(4)
	# the new Pokémon dash to their cells and pop in (UnitView): tap them once they stand still
	await get_tree().create_timer(0.6).timeout
	var hud := game.hud
	var unit: PlayerState.OwnedUnit = game.player.board.values()[0]
	var view: UnitView = game.owned_views[unit.id]
	var from := game.player.find(unit)
	var at := game.camera.unproject_position(view.global_position + Vector3.UP * 0.3)
	# tap on one's Pokémon: its panel, and it stays where it was
	game._unhandled_input(_button(at, true))
	game._input(_button(at, false))
	await _frames(2)
	if not hud.info_panel.visible or game.player.find(unit) != from or game._drag_view != null:
		_fail("touch: a tap on a Pokémon should open its panel (visible %s, moved %s)" % [hud.info_panel.visible, game.player.find(unit) != from])
	# tap on the empty ground: the panel closes
	var empty := game.camera.unproject_position(Vector3(3.5, 0, 6.2))
	game._unhandled_input(_button(empty, true))
	await _frames(1)
	if hud.info_panel.visible:
		_fail("touch: a tap on the ground should close the unit panel")
	# a drag still moves the Pokémon to another cell
	var target_cell := Vector2i(BattleBoard.WIDTH - 1, 0)
	if not game.player.board.has(target_cell):
		var to := game.camera.unproject_position(game.arena.cell_to_world(target_cell))
		game._unhandled_input(_button(at, true))
		game._on_mouse_motion(to)
		game._input(_button(to, false))
		await _frames(1)
		if game.player.board.get(target_cell) != unit or hud.info_panel.visible:
			_fail("touch: a drag should move the Pokémon (at %s)" % [game.player.find(unit)])
	# tap on an enemy of the coming wave: its panel
	if not game.enemy_views.is_empty():
		var enemy: UnitView = game.enemy_views[0]
		game._unhandled_input(_button(game.camera.unproject_position(enemy.global_position + Vector3.UP * 0.3), true))
		await _frames(1)
		if not hud.info_panel.visible:
			_fail("touch: a tap on an enemy should open its panel")
		game._close_info()
	# tap on an item of the item bench: its tooltip, pinned
	hud.tips.close_all()
	game._begin_item_drag(0)
	game._drop_item(game._press_pos)
	await _frames(2)
	if not hud.tips.has_open() or game._drag_item != -1:
		_fail("touch: a tap on an item should show its tooltip")
	hud.tips.close_all()
	# tap on a synergy row: its tooltip; on a button: nothing, a long press shows it
	var row: Control = null
	for child in hud.synergies.get_children():
		if child is SynergyRow:
			row = child
			break
	if row != null:
		hud.tips._input(_button(row.get_global_rect().get_center(), true))
		await _frames(2)
		if not hud.tips.has_open():
			_fail("touch: a tap on a synergy row should show its tooltip")
		hud.tips.close_all()
	var button: Control = hud.shop._buy_xp
	hud.tips._input(_button(button.get_global_rect().get_center(), true))
	var on_tap := hud.tips.has_open()
	var hold := _button(button.get_global_rect().get_center(), true)
	hold.button_index = MOUSE_BUTTON_RIGHT # a long press (TouchInput)
	hud.tips._input(hold)
	await _frames(2)
	if on_tap or not hud.tips.has_open():
		_fail("touch: a button shows its tooltip on a long press only (tap %s, hold %s)" % [on_tap, hud.tips.has_open()])
	print("touch: taps open the unit panel / item tooltip / synergy tooltip, a drag moves, a button tooltip needs a long press")
	if game.sim != null:
		game.sim.dispose()
	game.queue_free()
	UiScale.touch = false
	await _frames(2)


func _button(pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	return e


## Names of the named nodes under `node`, in tree order (nodes made in code have "@" names: skipped).
func _tree_names(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if not String(child.name).begins_with("@"):
			out.append(String(node.get_path_to(child)))
		for deeper in _tree_names(child):
			out.append(String(child.name) + "/" + String(deeper))
	return out
