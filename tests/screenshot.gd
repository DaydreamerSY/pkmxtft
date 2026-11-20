extends Node

## Renders the game scene and saves screenshots (needs a real window, not --headless):
##   Godot.exe --path . res://tests/screenshot.tscn -- <output dir> [menu | synergy | difficulty | pool | cheat | vfx [ABILITY...]] [lang=vi] [difficulty=hard] [records=user://file.cfg]
## Used to check the camera / board / sprite look and the HUD (one shot per
## screen of screenshot example/TFT-UI-breakdown.drawio) after changes.
## "synergy": synergies, passives and weather (spotlight, holes, wands, passive text).
## "difficulty": waves of later stages with their synergies, items and stat changes on the stage bar.
## "cheat": the cheat panel (F1), 12 Pokémon given (two bench rows), a won fight.
## "pool": Ground holes with their depth, the stage banner when Pokémon join the shop, the "!" of the shop and its list.

var out_dir := "user://screenshots"
var game: Game


## Enemy waves of a few stages: synergy chips of the stage bar, their tooltip, the stage tooltip.
func _difficulty_shots() -> void:
	var p := game.player
	p.gold = 60
	p.level = 6
	for i in 6:
		p.buy(i)
	p.auto_place()
	for stage in [12, 20, 28]:
		p.stage = stage
		game._start_planning()
		await _wait(0.5)
		_shot("d%d_wave" % stage)
	var chips := game.hud._enemy_synergies.get_children()
	if not chips.is_empty():
		await _hover(chips[0])
		_shot("d_hover_enemy_synergy")
	await _hover(game.hud._stage_label)
	_shot("d_hover_stage")
	game.hud.tips.close_all()
	game._start_fight()
	await _wait(2.5)
	_shot("d_fight")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	# "lang=vi" anywhere in the args: shots in that language (default English, not saved)
	Settings.language = "en"
	for a in args.duplicate():
		if a.begins_with("lang="):
			Settings.language = a.substr(5)
			args.erase(a)
		elif a.begins_with("difficulty=") or a.begins_with("records=") or a.begins_with("season="): # read by Settings / Records
			args.erase(a)
		elif a.begins_with("seed="): # the same run every time (motion: two versions compared frame by frame)
			seed(int(a.substr(5)))
			args.erase(a)
		elif a == "pixels=nearest": # the sprites drawn like before UnitView.smooth_pixels (to compare)
			UnitView.smooth_pixels = false
			args.erase(a)
	Settings.apply()
	# the default season of the file unless "season=<id>" ("all": every Pokémon), not the one the player saved
	Seasons.use_default_unless_asked()
	# the shots show the whole game whatever the player's Battle Pass ("pass=<level>": a locked state);
	# either way nothing is saved to the pass
	if Progression.override_level < 1:
		Progression.override_level = 9999
	GameData.apply_progression()
	for a in args.duplicate():
		if a.begins_with("pass=") or a.begins_with("pass_file="):
			args.erase(a)
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	if args.size() > 1 and args[1] == "menu":
		var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
		add_child(menu)
		await _wait(0.5)
		_shot("0_main_menu")
		var options := OptionsPanel.create(false)
		options.open_over(menu)
		await _wait(0.3)
		_shot("0b_options")
		options.queue_free()
		var pass_panel := PassPanel.create()
		pass_panel.open_over(menu)
		await _wait(0.3)
		_shot("0c_battle_pass")
		pass_panel.queue_free()
		if Seasons.active():
			var roster := SeasonPanel.create()
			roster.open_over(menu)
			await _wait(0.4)
			_shot("0d_season_roster")
		menu.queue_free()
		game = load("res://scenes/game.tscn").instantiate()
		add_child(game)
		await _wait(0.5)
		var entry := func(pkm: String, physical: float, special: float) -> Dictionary:
			return {"pkm": pkm, "physical": physical, "special": special, "true": physical * 0.1, "reduced": special * 0.5,
				"shield_taken": 120.0, "heal": physical * 0.2, "shield": 80.0, "fights": 17}
		game.hud.show_game_over(17, {"stage": 21}, false, true, {"fights": 17, "wins": 12, "losses": 5, "draws": 0,
			"seconds": 1234, "gold": 312, "rerolls": 41, "level": 8,
			"team": [{"pkm": "CHARIZARD", "stars": 3}, {"pkm": "PIKACHU", "stars": 2}, {"pkm": "BULBASAUR", "stars": 1}],
			"damage": [entry.call("CHARIZARD", 4200.0, 18400.0), entry.call("PIKACHU", 9100.0, 2300.0), entry.call("BULBASAUR", 800.0, 3100.0)],
			"blocked": [entry.call("BULBASAUR", 800.0, 9000.0)], "healing": [entry.call("PIKACHU", 9100.0, 2300.0)],
			"best_fight": {"pkm": "CHARIZARD", "damage": 3456.0, "stage": 15},
			"pass": {"level": 4, "max_level": 22, "into": 60, "need": 160, "xp": 215, "from": 3, "to": 4,
				"unlocked": ["ICE"], "fair": true}})
		await _wait(0.2)
		_shot("6_game_over")
		get_tree().quit()
		return
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await _wait(0.6)
	# the starter portal, then the starter pick
	_shot("00_portal_choice")
	game._resolve_choice(0)
	await _wait(0.4)
	_shot("00b_starter_choice")
	game._resolve_choice(0)
	await _wait(0.3)
	if args.size() > 1 and args[1] == "synergy":
		await _synergy_shots()
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "difficulty":
		await _difficulty_shots()
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "cheat":
		await _cheat_shots()
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "pool":
		await _pool_shots()
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "board":
		await _board_shots()
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "vfx":
		await _vfx_shots(args.slice(2))
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "motion":
		await _motion_shots(args.slice(2))
		get_tree().quit()
		return
	# a fuller team with items for the pictures
	var p := game.player
	p.gold = 60
	p.level = 6
	for i in 6:
		p.buy(i)
	p.roll_shop()
	p.auto_place()
	for item in ["CHARCOAL", "MAGNET", "TWISTED_SPOON", "MYSTIC_WATER", "HEART_SCALE", "BLACK_GLASSES", "RED_ORB", "CHOICE_SPECS"]:
		p.items.append(item)
	var units: Array = p.board.values()
	p.equip(p.items.find("RED_ORB"), units[0])
	p.equip(p.items.find("CHARCOAL"), units[0])
	p.equip(p.items.find("CHOICE_SPECS"), units[1])
	p.changed.emit()
	await _wait(0.8)
	_shot("01_planning")
	await _hover(game.hud._region_label)
	await _wait(0.3)
	_shot("01b_hover_region")

	var hud := game.hud
	var rows := hud.synergies.get_children().filter(func(n: Node) -> bool: return n is SynergyRow)
	if not rows.is_empty():
		await _hover(rows[0])
		_shot("02_hover_synergy")
		var tip := _last_tip()
		var cells: Array = tip.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is SynergyMember) if tip else []
		if not cells.is_empty():
			await _hover(cells[0])
			_shot("03_hover_synergy_pokemon")
			# a locked additional and a regional Pokémon: their unlock condition
			var locked: Array = cells.filter(func(c: SynergyMember) -> bool: return c.locked)
			if not locked.is_empty():
				await _hover(locked[0])
				_shot("03b_hover_locked_pokemon")
				await _hover(locked[locked.size() - 1])
				_shot("03c_hover_last_locked_pokemon")
	# a synergy of a shop card hovered: its cards glow (fireflies), the others dim, board cells pulse
	await _hover(hud.shop)
	var card_type: String = GameData.get_pokemon(hud.shop.cards[0].pkm).types[0]
	hud._on_synergy_hovered(card_type)
	await _wait(0.3)
	_shot("02b_hover_shop_synergy")
	hud._on_synergy_hovered("")

	await _hover(hud.item_bench.slot_control(0))
	_shot("04_hover_item")
	await _click(hud.item_bench.slot_control(0), MOUSE_BUTTON_RIGHT)
	_shot("05_right_click_recipes")
	var recipe_tip := _last_tip()
	var recipe_rows: Array = recipe_tip.find_children("*", "", true, false).filter(
		func(n: Node) -> bool: return n is RecipeRow) if recipe_tip else []
	if not recipe_rows.is_empty():
		await _hover(recipe_rows[0])
		_shot("06_hover_upper_tier_item")
	hud.tips.close_all()

	await _hover(hud.shop.cards[2])
	_shot("07_hover_shop_card")
	await _hover(hud.shop.find_children("*", "Button", true, false).filter(
		func(b: Node) -> bool: return (b as Button).toggle_mode)[0])
	_shot("08_hover_lock_shop")

	var view: UnitView = game.owned_views[units[0].id]
	var from := game.camera.unproject_position(view.global_position + Vector3.UP * 0.4)
	game._begin_drag(from)
	var to := game.camera.unproject_position(game.arena.cell_to_world(Vector2i(2, 1)))
	game._on_mouse_motion(to)
	await _wait(0.3)
	_shot("09_drag_range")
	var shop_point := hud.shop.get_global_rect().get_center()
	game._on_mouse_motion(shop_point)
	await _wait(0.2)
	_shot("10_drag_sell_zone")
	game._drop(to)

	var index := p.items.find("MAGNET")
	game._begin_item_drag(index)
	var over := game.camera.unproject_position(game.owned_views[units[2].id].global_position + Vector3.UP * 0.4)
	game._item_drag_motion(over)
	await _wait(0.2)
	_shot("11_drag_item")
	# over another component of the item bench: the item they make together
	var spoon_slot: Control = hud.item_bench.slot_control(p.items.find("TWISTED_SPOON"))
	await _hover(spoon_slot)
	game._item_drag_motion(spoon_slot.get_global_rect().get_center())
	await _wait(0.3)
	_shot("11b_drag_combine_preview")
	game._item_drag_motion(over)
	game._drop_item(over)

	await _wait(0.3)
	game._inspect(game.camera.unproject_position(view.global_position + Vector3.UP * 0.4))
	await _wait(0.3)
	_shot("12_right_click_unit")
	var panel := hud.info_panel
	await _hover(panel._skill_box)
	_shot("13_hover_skill")
	await _hover(panel._type_box().get_child(0))
	_shot("14_hover_unit_synergy")
	await _hover(panel._item_slots[0])
	_shot("15_hover_unit_item")
	await _hover(panel._stat_cells.filter(func(c: StatCell) -> bool: return c.stat == "CRIT_CHANCE")[0])
	_shot("16_hover_stat")
	await _hover(panel._role_chip)
	_shot("17_hover_role")
	hud.tips.close_all()

	game._queue_choices([{"kind": "items", "source": "reward", "items": ["MIRACLE_SEED", "MAGNET", "CHARCOAL"]}])
	await _wait(0.3)
	_shot("18_item_choice")
	# the "i" button of a card: what the item does, without picking it
	var item_cards: Array = hud._item_choice._row.get_children()
	if not item_cards.is_empty():
		(item_cards[1].find_child("Info", true, false) as Button).pressed.emit()
		await _wait(0.3)
		_shot("18a_item_choice_details")
		hud.tips.close_all()
	game._resolve_choice("MAGNET")

	# many items (pages) and a shop sharing the active synergies
	for item in ["MIRACLE_SEED", "MYSTIC_WATER", "NEVER_MELT_ICE", "TWISTED_SPOON", "CHARCOAL", "MAGNET",
			"HEART_SCALE", "BLACK_GLASSES", "SHELL_BELL", "SOUL_DEW", "UPGRADE", "LEAF_STONE"]:
		p.items.append(item)
	p.changed.emit()
	await _wait(0.3)
	_shot("18b_item_pages")
	game.hud.item_bench.turn_page(1)
	await _wait(0.2)
	_shot("18c_item_page_2")
	game._begin_item_drag(ItemBench.REMOVER)
	var target_view: UnitView = game.owned_views.get(units[0].id)
	var tpos := game.camera.unproject_position(target_view.body_position())
	game._item_drag_motion(tpos)
	await _wait(0.2)
	_shot("18d_item_remover_drag")
	game._drop_item(tpos)
	await _wait(0.3)
	_shot("18e_item_removed")

	game._start_fight()
	await _wait(2.5)
	_shot("19_fight")
	await _wait(2.0)
	_shot("20_fight_later")
	game._close_info()
	await _wait(0.4)
	_shot("21_dps_meter")
	_hover(game.hud.get_node("%Stage"))
	await _wait(0.5)
	_shot("22_stage_preview")
	get_tree().quit()


## Phase 4: a board with Fairy (wand choice), Light (spotlight), Ground (holes),
## Bug (clones) and passives, then a fight.
func _synergy_shots() -> void:
	var p := game.player
	p.level = 9
	p.board.clear()
	p.light_cell = Vector2i(2, 3)
	var team := {Vector2i(2, 3): "MAREEP", Vector2i(5, 3): "SHINX", Vector2i(1, 2): "AZURILL", Vector2i(5, 2): "TOGEPI",
		Vector2i(3, 2): "GEODUDE", Vector2i(4, 1): "SWINUB", Vector2i(0, 0): "CATERPIE", Vector2i(6, 0): "WEEDLE",
		Vector2i(3, 0): "KLINK"}
	for cell in team:
		p.board[cell] = PlayerState.OwnedUnit.new(team[cell])
	for cell in [Vector2i(3, 2), Vector2i(4, 1), Vector2i(3, 3), Vector2i(0, 1)]:
		p.ground_holes[cell] = 2 + cell.x % 4
	p.changed.emit()
	await _wait(0.8)
	_shot("p4_01_planning_wand_choice")
	var hud := game.hud
	game.auto_resolve_choices()
	for row in hud.synergies.get_children():
		if row is SynergyRow and row.type == "FAIRY":
			await _hover(row)
			_shot("p4_02_hover_fairy")
		if row is SynergyRow and row.type == "LIGHT":
			await _hover(row)
			_shot("p4_03_hover_light")
	hud.tips.close_all()
	await _hover(hud._weather_label)
	_shot("p4_04_hover_weather")
	hud.tips.close_all()
	var klink: UnitView = null
	for id in game.owned_views:
		if game.owned_views[id].pkm == "KLINK":
			klink = game.owned_views[id]
	if klink != null:
		game._inspect(game.camera.unproject_position(klink.global_position + Vector3.UP * 0.4))
		await _wait(0.4)
		_shot("p4_05_passive_panel")
	game._close_info()
	game._start_fight()
	await _wait(1.2)
	_shot("p4_06_fight_start")
	await _wait(3.0)
	_shot("p4_07_fight")


## The cheat panel: search lists, Pokémon given to the bench (second row), items, a won fight.
func _cheat_shots() -> void:
	if game.cheats == null:
		push_error("cheats are off in data/difficulty.json")
		return
	game.cheats.toggle()
	await _wait(0.4)
	_shot("cheat_01_panel")
	game.cheats._pkm_filter.text = "char"
	game.cheats._fill_pokemon("char")
	game.cheats._item_filter.text = "orb"
	game.cheats._fill_items("orb")
	var commons: Array = GameData.tier1_by_rarity["COMMON"].slice(0, 12)
	for pkm in commons:
		game.cheat_give_pokemon(pkm)
	game.cheat_give_item("RED_ORB")
	game.cheat_gold(100)
	await _wait(0.6)
	_shot("cheat_02_search_and_bench")
	game.cheats.toggle()
	game.cheat_win()
	await _wait(1.0)
	_shot("cheat_03_win")


## Ground holes (grey depth text, amber = dug at the next stage), then stage 5: the uncommon families join the
## shop (one short line in the banner), the "!" glows, its click opens the list.
func _pool_shots() -> void:
	var p := game.player
	p.level = 9
	p.board.clear()
	var team := {Vector2i(3, 2): "GEODUDE", Vector2i(4, 2): "SWINUB", Vector2i(2, 3): "DIGLETT", Vector2i(5, 3): "PHANPY",
		Vector2i(1, 2): "MAREEP"}
	for cell in team:
		p.board[cell] = PlayerState.OwnedUnit.new(team[cell])
	p.ground_holes[Vector2i(3, 2)] = 5
	p.ground_holes[Vector2i(4, 2)] = 2
	p.ground_holes[Vector2i(0, 0)] = 3
	p.stage = 4
	p.changed.emit()
	await _wait(0.8)
	_shot("pool_01_ground_cells")
	p.stage = 5
	var messages := p.start_stage()
	game.hud.banner(L.t("Stage %d   +%dg") % [5, 5] + "
" + "
".join(messages), UiStyle.GOLD, 3.0)
	await _wait(0.6)
	_shot("pool_02_banner")
	await _wait(3.2)
	_shot("pool_03_glowing_button")
	game.hud.shop._pool_info.pressed.emit()
	await _wait(0.6)
	_shot("pool_04_list")
	game.hud.tips.close_all()
	p.stage = 8
	p.start_stage()
	game.hud.shop._pool_info.pressed.emit()
	await _wait(0.6)
	_shot("pool_05_list_two_stages")


## "board": the size of the board and of the Pokémon (compact HUD: the shop open, closed, a unit dragged to
## the dock, a fight) with a full team holding items.
func _board_shots() -> void:
	var p := game.player
	p.gold = 300
	p.level = 9
	for _round in 3:
		for i in 6:
			p.buy(i)
		p.roll_shop()
	p.auto_place()
	for item in ["CHARCOAL", "MAGNET", "TWISTED_SPOON", "MYSTIC_WATER", "HEART_SCALE", "BLACK_GLASSES", "RED_ORB", "CHOICE_SPECS",
			"MIRACLE_SEED", "NEVER_MELT_ICE", "SOFT_SAND", "HARD_STONE"]:
		p.items.append(item)
	var units: Array = p.board.values()
	for i in mini(units.size(), 4): # one, two and three items, like a mid-game team
		for _n in mini(i + 1, 3):
			if not p.items.is_empty():
				p.equip(0, units[i])
	# the bench: a pair sharing a slot (benchStack) and a few single ones
	for i in p.bench_size:
		p.bench[i] = null
	var commons: Array = GameData.tier1_by_rarity["COMMON"].filter(func(x: String) -> bool:
		return not GameData.evolutions_of(x).is_empty())
	for pkm in [commons[0], commons[0], commons[1], commons[2], commons[2], commons[3]]:
		p.give_pokemon(pkm)
	p.changed.emit()
	await _wait(0.3)
	game.auto_resolve_choices()
	var guard := 0
	while not game.choices.is_empty() and guard < 8: # a wand to choose (Fairy) waits: not in these pictures
		guard += 1
		game._resolve_choice(0)
	await _wait(0.9)
	_shot("board_01_shop_open")
	game.hud.set_shop_open(false)
	await _wait(0.6)
	_shot("board_02_shop_closed")
	if not units.is_empty(): # a unit dragged over the dock: the sell zone
		var view: UnitView = game.owned_views.get(units[0].id)
		if view != null and game.hud._dock.visible:
			var from := game.camera.unproject_position(view.global_position + Vector3.UP * 0.3)
			var to := Hud.shown_rect(game.hud._dock).get_center()
			game._begin_drag(from)
			game._on_mouse_motion(to)
			await _wait(0.3)
			_shot("board_03_drag_to_dock")
			game._cancel_drag()
	game.hud.set_shop_open(true)
	await _wait(0.4)
	game._start_fight()
	await _wait(1.2)
	_shot("board_04_fight")
	await _wait(2.5)
	_shot("board_05_fight_later")


## "vfx [ABILITY...]": ability effects cast by a blue unit on a red one (fight paused),
## status icons, a basic attack and the evolution burst.
func _vfx_shots(abilities: Array) -> void:
	var p := game.player
	p.board.clear()
	p.give_pokemon("GEODUDE")
	p.auto_place()
	game._start_fight()
	await _wait(0.2)
	var blue: BattleUnit = game.sim.alive_units(BattleUnit.Team.BLUE)[0]
	var red: BattleUnit = game.sim.alive_units(BattleUnit.Team.RED)[0]
	game.set_physics_process(false) # freeze the fight, effects keep playing
	if abilities.is_empty():
		abilities = ["THUNDER_SHOCK", "FLAMETHROWER", "SHADOW_BALL", "DARK_HARVEST", "HYDRO_PUMP", "SPIKY_SHIELD",
			"FIRE_BLAST", "GEAR_GRIND", "PSYCHO_CUT", "SKY_ATTACK"]
	for ab in abilities:
		game.vfx.clear()
		game.vfx.play_ability(String(ab), blue, red, [red])
		game.vfx.on_area(blue, [red.cell]) # "cells" specs: the cells the ability shows
		await _wait(0.3)
		_shot("vfx_" + String(ab))
	game.vfx.clear()
	for st in ["burn", "freeze", "paralysis", "confusion"]:
		red.statuses[st] = 5000.0
	blue.statuses["protect"] = 5000.0
	game.phase = Game.Phase.FIGHT
	await _wait(0.3)
	_shot("vfx_statuses")
	game.vfx.attack("FIRE/range", game._body_of(blue), game._body_of(red), 200.0)
	await _wait(0.1)
	_shot("vfx_attack_range")
	game.vfx.evolution(game._body_of(blue))
	await _wait(0.3)
	_shot("vfx_evolution")


## "motion [frames=N] [speed=X] [stage=N]": a fight recorded frame by frame (motion_NNN.png, the board only) to
## judge how smooth the Pokémon move: tools/motion_gif.py makes a GIF of them. Run it with
## SHOT_ENGINE_ARGS="--fixed-fps 50" (every frame is then 1/50 s of game time, however long a shot takes) and
## "seed=<n>": the same team, wave and fight every time, so two versions of the view compare frame by frame.
## "speed=2": the fight at x2 (the HUD speed button). "full=1": whole frames (the compact HUD frames the board
## again when the shop closes for the fight, after the board part is measured).
func _motion_shots(rest: Array) -> void:
	var opts := {"frames": 220, "speed": 1.0, "stage": 6, "full": 0}
	for a in rest:
		var kv := String(a).split("=")
		if kv.size() == 2 and opts.has(kv[0]):
			opts[kv[0]] = float(kv[1])
	var p := game.player
	p.level = 6
	p.board.clear()
	for i in p.bench_size:
		p.bench[i] = null
	# melee and ranged attackers, slow and fast ones
	for pkm in ["CHARMANDER", "MACHOP", "GEODUDE", "SQUIRTLE", "BULBASAUR", "TREECKO"]:
		p.give_pokemon(pkm)
	p.auto_place()
	p.stage = int(opts.stage)
	game._start_planning()
	game.auto_resolve_choices()
	var guard := 0
	while not game.choices.is_empty() and guard < 8:
		guard += 1
		game._resolve_choice(0)
	var speed := float(opts.speed)
	game.speed_index = maxi(game.fight_speeds.find(speed), 0)
	await _wait(0.6)
	_shot("motion_planning") # a whole frame: the sprites at rest
	game._start_fight()
	game.sim.rng.seed = 7 # the fight itself: the same crits, dodges and targets every run
	# the board on screen (cell centres, in window pixels) with a margin: the part of each frame that is saved
	var to_window := get_viewport().get_final_transform()
	var corners: Array[Vector2] = []
	for c in [Vector2i(0, 0), Vector2i(BattleBoard.WIDTH - 1, 0), Vector2i(0, BattleBoard.HEIGHT - 1),
			Vector2i(BattleBoard.WIDTH - 1, BattleBoard.HEIGHT - 1)]:
		corners.append(to_window * game.camera.unproject_position(game.arena.cell_to_world(c)))
	var box := Rect2(corners[0], Vector2.ZERO)
	for corner in corners:
		box = box.expand(corner)
	var whole := Rect2(Vector2.ZERO, Vector2(get_viewport().get_texture().get_size()))
	box = whole if opts.full > 0 else box.grow_individual(80, 170, 80, 60).intersection(whole)
	# motion.tsv: every unit at every frame (window pixels): where its node is (the sim), how far its sprite is
	# drawn from it (UnitView body motion) and the frame of its animation
	var tsv := FileAccess.open(out_dir.path_join("motion.tsv"), FileAccess.WRITE)
	tsv.store_line("\t".join(["frame", "id", "pkm", "x", "y", "dx", "dy", "scale_x", "scale_y", "action", "anim", "anim_frame"]))
	for i in int(opts.frames):
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image().get_region(Rect2i(box))
		img.save_png(out_dir.path_join("motion_%03d.png" % i))
		for id in game.battle_views:
			var v = game.battle_views[id]
			if v == null or not is_instance_valid(v) or not v.is_inside_tree():
				continue
			var at: Vector2 = to_window * game.camera.unproject_position(v.global_position)
			var drawn: Vector2 = to_window * game.camera.unproject_position(v.sprite.global_position)
			tsv.store_line("\t".join([str(i), str(id), v.pkm, "%.1f" % at.x, "%.1f" % at.y, "%.2f" % (drawn.x - at.x),
				"%.2f" % (drawn.y - at.y), "%.3f" % v.sprite.scale.x, "%.3f" % v.sprite.scale.y, v.current_action,
				String(v.sprite.animation), str(v.sprite.frame)]))
	tsv.close()
	print("saved %d frames of %s in %s" % [int(opts.frames), str(Rect2i(box)), out_dir])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Hovers a control like a player would, with a synthetic mouse motion: the real cursor is never moved
## (the tool must not take the mouse of someone working next to it).
func _hover(control: Control) -> void:
	var pos := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = get_viewport().get_final_transform() * pos # window coordinates
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await get_tree().process_frame
	control.mouse_entered.emit() # the GUI may not see synthetic motion as a hover
	await _wait(0.25)


func _click(control: Control, button: MouseButton) -> void:
	await _hover(control)
	var pos := control.get_global_rect().get_center()
	var click := InputEventMouseButton.new()
	click.position = pos
	click.global_position = pos
	click.button_index = button
	click.pressed = true
	control.gui_input.emit(click)
	await _wait(0.25)


func _last_tip() -> Control:
	var tips := game.hud.tips
	return tips.get_child(tips.get_child_count() - 1) if tips.get_child_count() > 0 else null


func _shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(shot_name + ".png")
	img.save_png(path)
	print("saved ", path)
