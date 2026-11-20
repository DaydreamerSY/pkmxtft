class_name SeasonPanel
extends PanelContainer

## Roster of the season picked in the main menu (Seasons, not in the web game): one row per synergy
## with its thresholds in this season and its Pokémon - the shop ones, then the Unique and the
## Legendary ones. Opened by the "Pokémon of the season" button of the menu. Built in code.
## Hover / tap a portrait: its card; a synergy: what it does.

signal closed

const NAME_WIDTH := 138.0
const TIERS_WIDTH := 76.0
## Portraits of a row before it wraps.
const ROW_PORTRAITS := 15
const PORTRAIT := 42.0
const FEATURED := Color("#ffd24d")
const SPECIAL := Color("#7fd0ff")

var _scroll: ScrollContainer
var _rows: VBoxContainer


static func create() -> SeasonPanel:
	var panel := SeasonPanel.new()
	panel._build()
	return panel


func _build() -> void:
	theme = load("res://scenes/ui/theme/ui_theme.tres")
	theme_type_variation = &"ChoicePanel"
	var style := theme.get_stylebox("panel", &"ChoicePanel").duplicate()
	if UiStyle.has_fill(style):
		style.bg_color.a = 1.0 # opaque: the menu must not show through the small texts
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	add_child(content)
	var title := Label.new()
	title.text = Seasons.label()
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	content.add_child(_centered(Seasons.description(), 15, UiStyle.TEXT))
	content.add_child(_centered(L.t("%d Pokémon lines in the shop, all of them from the first stage  •  %d Unique  •  %d Legendary") % [
		lines_in(GameData.pool), lines_in(GameData.unique), lines_in(GameData.legendary)], 14, UiStyle.TEXT_DIM))
	var legend := HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 18)
	legend.add_child(UiStyle.label("★ " + L.t("featured: a full roster in this season only"), 13, FEATURED))
	legend.add_child(UiStyle.label("◆ " + L.t("special: few Pokémon, tiers of their own"), 13, SPECIAL))
	content.add_child(legend)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_child(_rows)
	content.add_child(_scroll)
	var featured := Seasons.featured()
	var special := Seasons.special()
	for type in GameData.synergies():
		_rows.add_child(_row(type, featured.has(type), special.has(type)))
	var close := Button.new()
	close.name = "Close"
	close.text = L.t("Close")
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(160, 40)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void:
		queue_free()
		closed.emit())
	content.add_child(close)


## Lines (families) of a list of forms; the Flabébé colours are one line.
static func lines_in(forms: Array) -> int:
	var seen := {}
	for pkm in forms:
		var family := String(GameData.get_pokemon(pkm).get("family", pkm))
		seen["FLABEBE" if PlayerState.FLABEBE_FORMS.has(family) else family] = true
	return seen.size()


## One synergy: its name (★ featured, ◆ special), its thresholds in this season, its Pokémon.
func _row(type: String, featured: bool, special: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var chip := TypeRow.create(type, 15)
	chip.custom_minimum_size.x = NAME_WIDTH
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	HoverTip.add(chip, func() -> Control: return Tooltips.synergy(type, 0, {}, 0, ""), HoverTip.Side.BOTTOM)
	row.add_child(chip)
	var tiers: Array = Synergies.thresholds(type).map(func(t) -> String: return str(int(t)))
	var mark := "★ " if featured else ("◆ " if special else "")
	var tiers_label := UiStyle.label(mark + "/".join(tiers), 14, FEATURED if featured else (SPECIAL if special else UiStyle.TEXT_DIM))
	tiers_label.custom_minimum_size.x = TIERS_WIDTH
	tiers_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tiers_label)
	var flow := HFlowContainer.new()
	flow.custom_minimum_size.x = ROW_PORTRAITS * (PORTRAIT + 3.0) + 2.0 * 11.0 # and the two gaps between the groups
	flow.add_theme_constant_override("h_separation", 3)
	flow.add_theme_constant_override("v_separation", 3)
	var first := true
	for group in Tooltips.synergy_groups(type):
		if not first: # a gap between the shop, the Unique and the Legendary Pokémon
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(8, PORTRAIT)
			flow.add_child(gap)
		first = false
		for pkm in group.pokemons:
			var member: SynergyMember = UiScenes.make(UiScenes.SYNERGY_MEMBER)
			member.pkm = pkm
			flow.add_child(member)
	row.add_child(flow)
	return row


func _centered(text: String, size: int, color: Color) -> Label:
	var label := UiStyle.label(text, size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Centers the panel over `parent` (full-rect dimmer behind it); the list takes the height left.
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
	var fit := func() -> void:
		var canvas := get_viewport_rect().size
		var needed := _rows.get_combined_minimum_size()
		_scroll.custom_minimum_size = Vector2(needed.x + 14.0, clampf(minf(needed.y, canvas.y - 230.0), 120.0, 760.0))
		# a small canvas (phone): never larger than the screen
		UiScale.fit(self, canvas - Vector2(16, 16), Vector2(0.5, 0.5), center)
	resized.connect(fit)
	get_viewport().size_changed.connect(fit)
	fit.call_deferred()
