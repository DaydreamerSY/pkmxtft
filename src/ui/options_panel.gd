class_name OptionsPanel
extends PanelContainer

## Options (main menu and in-game Menu): language, music and sound volumes, saved by
## Settings. In a game it also offers to leave the run. Built in code, themed by the
## "ChoicePanel" panel of scenes/ui/theme/ui_theme.tres.

signal closed
signal leave_pressed

var _language: OptionButton
var _music: HSlider
var _sfx: HSlider
var _codes: Array = []


## `in_game`: adds "Leave the run" (back to the main menu).
static func create(in_game: bool) -> OptionsPanel:
	var panel := OptionsPanel.new()
	panel._build(in_game)
	return panel


func _build(in_game: bool) -> void:
	theme = load("res://scenes/ui/theme/ui_theme.tres")
	theme_type_variation = &"ChoicePanel"
	var style := theme.get_stylebox("panel", &"ChoicePanel").duplicate()
	if UiStyle.has_fill(style):
		style.bg_color.a = 0.97 # opaque: the menu texts must not show through
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(440, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	var title := Label.new()
	title.text = "Options"
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	grid.add_child(_row_label("Language"))
	_language = OptionButton.new()
	_language.focus_mode = Control.FOCUS_NONE
	_language.custom_minimum_size = Vector2(240, 0)
	_codes = GameData.languages.keys()
	for i in _codes.size():
		_language.add_item(String(GameData.languages[_codes[i]]), i)
		if _codes[i] == Settings.language:
			_language.select(i)
	_language.item_selected.connect(func(i: int) -> void: Settings.set_language(_codes[i]))
	grid.add_child(_language)
	grid.add_child(_row_label("UI size"))
	var ui_size := OptionButton.new()
	ui_size.focus_mode = Control.FOCUS_NONE
	ui_size.custom_minimum_size = Vector2(240, 0)
	for i in UiScale.CHOICES.size():
		var percent: int = UiScale.CHOICES[i]
		ui_size.add_item(L.t("Auto (%d%%)") % roundi(UiScale.auto_factor() * 100.0) if percent == 0 else "%d%%" % percent, i)
		if percent == Settings.ui_scale:
			ui_size.select(i)
	ui_size.item_selected.connect(func(i: int) -> void: Settings.set_ui_scale(UiScale.CHOICES[i]))
	grid.add_child(ui_size)
	# the angle of the camera over the board: only the compact HUD (phones) frames the board itself
	var root_canvas: Vector2 = (Engine.get_main_loop() as SceneTree).root.get_visible_rect().size
	if root_canvas.y < UiScale.COMPACT_HEIGHT:
		grid.add_child(_row_label("Board view"))
		var pitch := OptionButton.new()
		pitch.name = "BoardPitch"
		pitch.focus_mode = Control.FOCUS_NONE
		pitch.custom_minimum_size = Vector2(240, 0)
		for i in Settings.BOARD_PITCHES.size():
			var degrees: int = Settings.BOARD_PITCHES[i]
			pitch.add_item(L.t("Auto (biggest board)") if degrees == 0 else L.t("%d° (higher = seen from above)") % degrees, i)
			if degrees == Settings.board_pitch:
				pitch.select(i)
		pitch.item_selected.connect(func(i: int) -> void: Settings.set_board_pitch(Settings.BOARD_PITCHES[i]))
		grid.add_child(pitch)
	grid.add_child(_row_label("Music"))
	_music = _slider(Settings.music_volume)
	grid.add_child(_music)
	grid.add_child(_row_label("Sounds"))
	_sfx = _slider(Settings.sfx_volume)
	grid.add_child(_sfx)
	var apply_volumes := func(_v: float) -> void: Settings.set_volumes(_music.value, _sfx.value)
	_music.value_changed.connect(apply_volumes)
	_sfx.value_changed.connect(apply_volumes)

	var note := Label.new()
	note.text = "Game texts come from the translations of the web game; untranslated texts stay in English."
	note.theme_type_variation = &"DimLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(400, 0)
	v.add_child(note)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	v.add_child(buttons)
	if in_game:
		var leave := Button.new()
		leave.text = "Leave the run"
		leave.focus_mode = Control.FOCUS_NONE
		leave.pressed.connect(func() -> void: leave_pressed.emit())
		buttons.add_child(leave)
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void:
		queue_free()
		closed.emit())
	buttons.add_child(close)


func _row_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _slider(value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 100.0
	s.step = 1.0
	s.value = value
	s.custom_minimum_size = Vector2(240, 24)
	s.focus_mode = Control.FOCUS_NONE
	return s


## Centers the panel over `parent` (full-rect dimmer behind it).
func open_over(parent: Control) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# a panel taller than the canvas makes the container grow: on both sides, so that it stays centred
	# (a container made in code grows down only, and the panel shrunk by UiScale.fit sat too low)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.add_child(center)
	center.add_child(self)
	tree_exited.connect(dim.queue_free)
	# a small canvas (phone): never larger than the screen
	var fit := func() -> void: UiScale.fit(self, get_viewport_rect().size - Vector2(16, 16), Vector2(0.5, 0.5), center)
	resized.connect(fit)
	get_viewport().size_changed.connect(fit)
	fit.call_deferred()
