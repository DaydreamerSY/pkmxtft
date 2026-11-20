class_name PassPanel
extends PanelContainer

## The Battle Pass screen of the main menu (Progression, data/progression.json; not in the web game):
## the player's level and XP, the synergies of the start and the one each level unlocks (hover: what
## the synergy does). Built in code like OptionsPanel. With the cheats of the difficulty on
## (difficulty.json "cheats"), buttons move the level. progress_row() / synergy_row() are also used by
## the main menu and the Game Over screen.

signal closed
## A cheat button changed the level (the menu refreshes its pass line).
signal changed

const COLUMNS := 7
const CARD_SIZE := Vector2(140, 96)
## A small canvas (phones): the cards are lower, as wide as the screen allows.
const COMPACT_CARD_SIZE := Vector2(120, 88)
const REACHED_BG := Color(0.12, 0.16, 0.14, 0.95)
const LOCKED_BG := Color(0.07, 0.08, 0.1, 0.95)
const LOCKED_BORDER := Color(0.3, 0.33, 0.36)

var _content: VBoxContainer
## The canvas is low (phones, UiScale.COMPACT_HEIGHT): the compact screen (_fill_compact).
var _compact := false


static func create() -> PassPanel:
	var panel := PassPanel.new()
	panel._build()
	return panel


## "Level 3 / 22", the XP bar of the level and "45 / 140 XP" ("MAX" at the last level).
static func progress_row(p: Dictionary, bar_width := 240.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiStyle.label(L.t("Level %d / %d") % [int(p.get("level", 1)), int(p.get("max_level", 1))], 16, UiStyle.GOLD))
	var need := int(p.get("need", 0))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(bar_width, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = maxi(need, 1)
	bar.value = int(p.get("into", 0)) if need > 0 else 1
	row.add_child(bar)
	row.add_child(UiStyle.label("%d / %d XP" % [int(p.get("into", 0)), need] if need > 0 else L.t("MAX"), 14, UiStyle.TEXT_DIM))
	return row


## Icon + name of each synergy in a row (centred); hover: the synergy tooltip where a HoverTip exists.
static func synergy_row(types: Array, font_size := 15) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for type in types:
		var chip := TypeRow.create(String(type), font_size)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		_add_tip(chip, String(type))
		row.add_child(chip)
	return row


## What a synergy does, with the pass level that unlocks it while it is locked.
static func _add_tip(owner: Control, type: String) -> void:
	HoverTip.add(owner, func() -> Control:
		var level := Progression.level_of(type)
		var note := "" if level <= Progression.level() else L.t("Unlocks at pass level %d.") % level
		return Tooltips.synergy(type, 0, {}, 0, note), HoverTip.Side.BOTTOM)


func _build() -> void:
	theme = load("res://scenes/ui/theme/ui_theme.tres")
	theme_type_variation = &"ChoicePanel"
	var style := theme.get_stylebox("panel", &"ChoicePanel").duplicate()
	if UiStyle.has_fill(style):
		style.bg_color.a = 1.0 # opaque: the menu title must not show through the small texts
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var canvas: Vector2 = (Engine.get_main_loop() as SceneTree).root.get_visible_rect().size
	_compact = canvas.y < UiScale.COMPACT_HEIGHT
	if _compact: # as wide as the screen (clear of a camera hole): the level cards get the width, the text keeps its size
		var insets := UiScale.safe_insets(canvas.x)
		custom_minimum_size.x = canvas.x - 16.0 - 2.0 * maxf(insets.x, insets.y)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8 if _compact else 10)
	add_child(_content)
	Progression.mark_seen()
	_fill()


func _fill() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	if _compact:
		_fill_compact()
		return
	var level := Progression.level()
	var title := Label.new()
	title.text = L.t("Battle Pass")
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)
	_content.add_child(_centered(L.t("Play to earn pass XP. Each level unlocks new synergies, used from your next run on."), 15, UiStyle.TEXT))
	_content.add_child(progress_row(Progression.progress(), 420.0))
	_content.add_child(_centered(Progression.xp_rule(), 13, UiStyle.TEXT_DIM))

	_content.add_child(_centered(L.t("Starting synergies"), 15, UiStyle.GOLD))
	var start := Progression.rewards(1)
	var half := ceili(start.size() / 2.0) if start.size() > 6 else start.size()
	_content.add_child(synergy_row(start.slice(0, half)))
	if half < start.size():
		_content.add_child(synergy_row(start.slice(half)))

	if Progression.max_level() > 1:
		_content.add_child(_centered(L.t("Unlocked by the pass"), 15, UiStyle.GOLD))
		var grid := GridContainer.new()
		grid.columns = COLUMNS
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		for l in range(2, Progression.max_level() + 1):
			grid.add_child(_level_card(l, level))
		_content.add_child(grid)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	_content.add_child(buttons)
	if Difficulty.value("cheats", false):
		buttons.add_child(UiStyle.label("Cheat", 13, UiStyle.TEXT_DIM))
		for entry in [["-1", level - 1], ["+1", level + 1], [L.t("Unlock all"), Progression.max_level()], [L.t("Reset"), 1]]:
			var cheat := Button.new()
			cheat.text = String(entry[0])
			cheat.focus_mode = Control.FOCUS_NONE
			cheat.pressed.connect(_set_level.bind(int(entry[1])))
			buttons.add_child(cheat)
	buttons.add_child(_close_button(Vector2(160, 40)))


## A phone: everything on the screen at its size, no shrinking - the title, the level, the cheat buttons and
## Close on one line, the XP rule, the starting synergies on one line, then the level cards (7 columns).
func _fill_compact() -> void:
	var level := Progression.level()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	_content.add_child(head)
	var title := Label.new()
	title.text = L.t("Battle Pass")
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 24)
	head.add_child(title)
	var progress := progress_row(Progression.progress(), 220.0)
	head.add_child(progress)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	if Difficulty.value("cheats", false):
		for entry in [["-1", level - 1], ["+1", level + 1], [L.t("Unlock all"), Progression.max_level()], [L.t("Reset"), 1]]:
			var cheat := Button.new()
			cheat.text = String(entry[0])
			cheat.focus_mode = Control.FOCUS_NONE
			cheat.add_theme_font_size_override("font_size", 14)
			cheat.pressed.connect(_set_level.bind(int(entry[1])))
			head.add_child(cheat)
	head.add_child(_close_button(Vector2(120, 40)))
	_content.add_child(_centered(L.t("Play to earn pass XP. Each level unlocks new synergies, used from your next run on.") + "  "
		+ Progression.xp_rule(), 13, UiStyle.TEXT_DIM))
	var start := HBoxContainer.new()
	start.add_theme_constant_override("separation", 10)
	_content.add_child(start)
	var start_label := UiStyle.label(L.t("Starting synergies"), 15, UiStyle.GOLD)
	start_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	start.add_child(start_label)
	var chips := HFlowContainer.new()
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("h_separation", 12)
	chips.add_theme_constant_override("v_separation", 4)
	start.add_child(chips)
	for type in Progression.rewards(1):
		var chip := TypeRow.create(String(type), 14)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		_add_tip(chip, String(type))
		chips.add_child(chip)
	if Progression.max_level() > 1:
		var grid := GridContainer.new()
		grid.name = "Levels"
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		for l in range(2, Progression.max_level() + 1):
			var card := _level_card(l, level, COMPACT_CARD_SIZE)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(card)
		_content.add_child(grid)


func _close_button(size: Vector2) -> Button:
	var close := Button.new()
	close.name = "Close"
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = size
	close.pressed.connect(func() -> void:
		queue_free()
		closed.emit())
	return close


## Cheat buttons: the pass jumps to `target`; what it unlocks applies at once (we are in the menu).
func _set_level(target: int) -> void:
	Progression.set_level(target)
	Progression.mark_seen()
	GameData.apply_progression()
	_fill.call_deferred() # not while the pressed button is still handling its click
	changed.emit()


func _centered(text: String, size: int, color: Color) -> Label:
	var label := UiStyle.label(text, size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## One level of the pass: "Lv N", its cost (or its progress for the next one), the synergies it
## unlocks. Reached: gold frame; the next one: blue frame; later ones: dim with a lock.
func _level_card(level: int, current: int, size := CARD_SIZE) -> Control:
	var reached := level <= current
	var next := level == current + 1
	var small := size.y < CARD_SIZE.y
	var card := PanelContainer.new()
	card.custom_minimum_size = size
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", UiStyle.panel(REACHED_BG if reached else LOCKED_BG,
		UiStyle.GOLD if reached else (UiStyle.BLUE if next else LOCKED_BORDER), 2, 8))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(UiStyle.label(L.t("Lv %d") % level, 13, UiStyle.GOLD if reached else UiStyle.TEXT_DIM))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(spacer)
	if reached:
		head.add_child(UiStyle.label(L.t("Unlocked"), 12, UiStyle.GREEN))
	elif next:
		var p := Progression.progress()
		head.add_child(UiStyle.label("%d / %d XP" % [int(p.into), int(p.need)], 12, UiStyle.BLUE))
	else:
		head.add_child(UiStyle.icon_rect(GameData.icon("lock-close"), 13))
		head.add_child(UiStyle.label("%d XP" % Progression.level_cost(level), 12, UiStyle.TEXT_DIM))
	v.add_child(head)
	var types := Progression.rewards(level)
	var icons := HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override("separation", 6)
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for type in types:
		var icon := UiStyle.icon_rect(GameData.type_icon(type), (28.0 if small else 36.0) if types.size() <= 2 else (22.0 if small else 26.0))
		icon.modulate.a = 1.0 if reached or next else 0.55
		icons.add_child(icon)
		if types.size() > 1: # several synergies: a tooltip each
			icon.mouse_filter = Control.MOUSE_FILTER_STOP
			_add_tip(icon, type)
	v.add_child(icons)
	var names: Array = types.map(func(t: String) -> String: return GameData.synergy_name(t))
	var name_label := UiStyle.label(", ".join(names) if not names.is_empty() else "-", 14,
		UiStyle.TEXT if reached or next else UiStyle.TEXT_DIM)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_label)
	if types.size() == 1:
		_add_tip(card, types[0])
	return card


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
