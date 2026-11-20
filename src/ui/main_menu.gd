extends Control

## Main menu: Play starts an Endless run (offline, solo). Multiplayer is out of
## scope of the Godot port for now. Scene: scenes/main_menu.tscn

const GAME_SCENE := "res://scenes/game.tscn"

## Portraits of random Pokémon of the pool shown above the title.
@export var portrait_count := 7


func _ready() -> void:
	# Battle Pass: what the last run unlocked shows in the menu (pool, tooltips) and in the next run;
	# what its regions unlocked for that run only is gone
	GameData.begin_run()
	# tooltips of the pass screen (the HUD has its own HoverTip)
	var tips := HoverTip.new()
	tips.name = "Tips"
	tips.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tips.z_index = 10 # above the pass screen, opened after it in the tree
	add_child(tips)
	%Play.pressed.connect(func() -> void: get_tree().change_scene_to_file(GAME_SCENE))
	# a small canvas (phones, UiScale): no portraits row, and the box never taller than the room above the footer
	var box: Control = $Center/Box
	var fit := func() -> void:
		%Portraits.visible = not UiScale.is_compact(self)
		UiScale.fit(box, get_viewport_rect().size - Vector2(16, 96), Vector2(0.5, 0.5), $Center)
	box.resized.connect(fit)
	get_viewport().size_changed.connect(fit)
	fit.call_deferred()
	%Quit.pressed.connect(func() -> void: get_tree().quit())
	%Options.pressed.connect(func() -> void: OptionsPanel.create(false).open_over(self))
	_add_difficulty()
	Audio.play_music(Audio.MENU_MUSIC)
	%Footer.text = L.t("Port of pokemonAutoChess (web) to Godot  •  %d Pokémon, %d abilities, %d items ported") % [
		GameData.full_list("pool").size(), GameData.abilities.size(), GameData.items.size()]
	var picks := GameData.pool.duplicate()
	picks.shuffle()
	for pkm in picks.slice(0, portrait_count):
		%Portraits.add_child(UiStyle.icon_rect(GameData.portrait(pkm), 72, CanvasItem.TEXTURE_FILTER_NEAREST))


## Season (data/seasons.json) and difficulty (data/difficulty.json) of the next runs, under the Play
## button; then the featured synergies of the season, the record and the Battle Pass.
func _add_difficulty() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var record := VBoxContainer.new()
	record.alignment = BoxContainer.ALIGNMENT_CENTER
	_season_line = HBoxContainer.new()
	_season_line.alignment = BoxContainer.ALIGNMENT_CENTER
	_season_line.add_theme_constant_override("separation", 12)
	if Seasons.enabled():
		row.add_child(UiStyle.label(L.t("Season"), 18, UiStyle.TEXT_DIM))
		var seasons := OptionButton.new()
		seasons.name = "SeasonPicker"
		seasons.focus_mode = Control.FOCUS_NONE
		seasons.custom_minimum_size = Vector2(270, 40)
		var season_ids := Seasons.ids()
		for i in season_ids.size():
			seasons.add_item(Seasons.label(season_ids[i]), i)
			seasons.set_item_tooltip(i, Seasons.description(season_ids[i]))
			if season_ids[i] == Seasons.current:
				seasons.select(i)
		seasons.item_selected.connect(func(i: int) -> void:
			Settings.set_season(season_ids[i]) # the lists of GameData now hold that roster
			_show_season()
			_show_record(record))
		row.add_child(seasons)
		var gap := Control.new()
		gap.custom_minimum_size.x = 12
		row.add_child(gap)
	row.add_child(UiStyle.label(L.t("Difficulty"), 18, UiStyle.TEXT_DIM))
	var picker := OptionButton.new()
	picker.focus_mode = Control.FOCUS_NONE
	picker.custom_minimum_size = Vector2(180, 40)
	var ids := Difficulty.levels()
	for i in ids.size():
		picker.add_item(Difficulty.label(ids[i]), i)
		picker.set_item_tooltip(i, Difficulty.description(ids[i]))
		if ids[i] == Difficulty.level:
			picker.select(i)
	picker.item_selected.connect(func(i: int) -> void:
		Settings.set_difficulty(ids[i])
		_show_record(record))
	row.add_child(picker)
	%Play.add_sibling(row)
	row.add_sibling(_season_line)
	_season_line.add_sibling(record)
	_show_season()
	_show_record(record)
	_pass_line = HBoxContainer.new()
	_pass_line.alignment = BoxContainer.ALIGNMENT_CENTER
	_pass_line.add_theme_constant_override("separation", 16)
	record.add_sibling(_pass_line)
	_show_pass()


var _pass_line: HBoxContainer
var _season_line: HBoxContainer


## The season picked (Seasons), under the pickers: its featured synergies (hover / tap one: what it
## does and its Pokémon in this season) and the button opening its whole roster.
func _show_season() -> void:
	for child in _season_line.get_children():
		_season_line.remove_child(child)
		child.queue_free()
	_season_line.visible = Seasons.enabled()
	if not _season_line.visible:
		return
	if not Seasons.active():
		_season_line.add_child(UiStyle.label(L.t("Every Pokémon of the game, as in the web game"), 15, UiStyle.TEXT_DIM))
		return
	_season_line.add_child(UiStyle.label(L.t("Featured:"), 15, UiStyle.TEXT_DIM))
	_season_line.add_child(PassPanel.synergy_row(Seasons.featured()))
	var open := Button.new()
	open.name = "SeasonRoster"
	open.text = L.t("Pokémon of the season")
	open.focus_mode = Control.FOCUS_NONE
	open.custom_minimum_size = Vector2(0, 36)
	open.pressed.connect(func() -> void: SeasonPanel.create().open_over(self))
	_season_line.add_child(open)


## Battle Pass (Progression) under the record: the button opening the pass screen, the level and its
## XP bar, then the synergies just unlocked (until the screen is opened) or the next one to unlock.
func _show_pass() -> void:
	for child in _pass_line.get_children():
		_pass_line.remove_child(child)
		child.queue_free()
	_pass_line.visible = Progression.enabled()
	if not _pass_line.visible:
		return
	var open := Button.new()
	open.text = L.t("Battle Pass")
	open.focus_mode = Control.FOCUS_NONE
	open.custom_minimum_size = Vector2(170, 44)
	open.pressed.connect(func() -> void:
		var panel := PassPanel.create()
		panel.changed.connect(_show_pass)
		panel.closed.connect(_show_pass)
		panel.open_over(self))
	_pass_line.add_child(open)
	_pass_line.add_child(PassPanel.progress_row(Progression.progress(), 200.0))
	var fresh := Progression.unseen_synergies()
	var next := Progression.rewards(Progression.level() + 1)
	if not fresh.is_empty():
		_pass_line.add_child(UiStyle.label(L.t("New:"), 15, UiStyle.GREEN))
		_pass_line.add_child(PassPanel.synergy_row(fresh))
	elif not next.is_empty():
		_pass_line.add_child(UiStyle.label(L.t("Next:"), 15, UiStyle.TEXT_DIM))
		_pass_line.add_child(PassPanel.synergy_row(next))
	elif Progression.level() >= Progression.max_level():
		_pass_line.add_child(UiStyle.label(L.t("All synergies unlocked"), 15, UiStyle.TEXT_DIM))


## Best run of the picked difficulty (Records): stage, date, and the board of that run.
func _show_record(box: VBoxContainer) -> void:
	for child in box.get_children():
		child.queue_free()
	var best := Records.best(Seasons.record_key(Difficulty.level))
	if best.is_empty():
		var none := UiStyle.label(L.t("No record yet for this season and difficulty") if Seasons.enabled()
			else L.t("No record yet for this difficulty"), 15, UiStyle.TEXT_DIM)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(none)
		return
	var text := L.t("Record: stage %d") % int(best.stage)
	if String(best.date) != "":
		text += "  •  " + String(best.date)
	text += "  •  " + L.t("%d runs") % int(best.runs)
	var line := UiStyle.label(text, 16, UiStyle.GOLD)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(line)
	var team := HBoxContainer.new()
	team.alignment = BoxContainer.ALIGNMENT_CENTER
	team.add_theme_constant_override("separation", 2)
	for entry in best.team.slice(0, 10):
		var icon := UiStyle.icon_rect(GameData.portrait(String(entry.get("pkm", ""))), 36, CanvasItem.TEXTURE_FILTER_NEAREST)
		icon.tooltip_text = "%s %s" % [GameData.display_name(String(entry.get("pkm", ""))), "★".repeat(int(entry.get("stars", 1)))]
		team.add_child(icon)
	box.add_child(team)
