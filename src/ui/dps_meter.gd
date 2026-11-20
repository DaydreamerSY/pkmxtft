class_name DpsMeter
extends PanelContainer

## Fight statistics of the web game (game-dps-meter.tsx): per Pokémon, the damage
## dealt (physical / special / true), the damage blocked (DEF, SPE_DEF... and
## shield) and the heal + shield given. Lives in the HUD, fed by Game.fight_stats;
## stays after the fight until the next one. Header click: fold / unfold.

enum Tab { DAMAGE, BLOCKED, HEAL }

const TABS := [["ATK", "Damage dealt"], ["SHIELD", "Damage blocked"], ["HP", "Heal and shield"]]
const ROW_HEIGHT := 26.0
const MAX_ROWS := 10

## Rows shown at most (fewer in the compact HUD).
var max_rows := MAX_ROWS

var tab := Tab.DAMAGE
var team := BattleUnit.Team.BLUE
var folded := false

var _body: VBoxContainer
var _rows: VBoxContainer
var _tab_buttons: Array[Button] = []
var _team_button: Button
var _title: Button
var _total: Label
var _last: Array = []


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel())
	custom_minimum_size = Vector2(240, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	_title = Button.new()
	_title.flat = true
	_title.focus_mode = Control.FOCUS_NONE
	_title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.add_theme_font_size_override("font_size", 15)
	_title.pressed.connect(func() -> void: set_folded(not folded))
	v.add_child(_title)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 3)
	v.add_child(_body)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	_body.add_child(bar)
	for i in TABS.size():
		var b := Button.new()
		b.icon = GameData.icon(TABS[i][0])
		b.expand_icon = true
		b.custom_minimum_size = Vector2(34, 26)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			tab = i
			_refresh_texts()
			update(_last))
		bar.add_child(b)
		_tab_buttons.append(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_team_button = Button.new()
	_team_button.focus_mode = Control.FOCUS_NONE
	_team_button.add_theme_font_size_override("font_size", 13)
	_team_button.pressed.connect(func() -> void:
		team = BattleUnit.Team.RED if team == BattleUnit.Team.BLUE else BattleUnit.Team.BLUE
		_refresh_texts()
		update(_last))
	bar.add_child(_team_button)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	_body.add_child(_rows)
	_total = UiStyle.label("", 13, UiStyle.TEXT_DIM)
	_body.add_child(_total)
	_refresh_texts()
	Settings.changed.connect(_refresh_texts)


## Folds the panel to its title, or unfolds it (the compact HUD starts it folded: it would cover the board).
func set_folded(on: bool) -> void:
	folded = on
	_refresh_texts()
	if not on and not _last.is_empty():
		update(_last)


func _refresh_texts() -> void:
	_title.text = ("▸ " if folded else "▾ ") + L.t("Fight stats")
	_body.visible = not folded
	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = i == tab
		_tab_buttons[i].tooltip_text = L.t(TABS[i][1])
	_team_button.text = L.t("Your team") if team == BattleUnit.Team.BLUE else L.t("Opponents")


## `entries`: [{unit: BattleUnit, physical, special, true, reduced, shield_taken, heal, shield}]
## of every unit of the fight (zeros included).
func update(entries: Array) -> void:
	_last = entries
	if folded:
		return
	var shown: Array = entries.filter(func(e: Dictionary) -> bool: return e.unit.team == team)
	shown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _total_of(a) > _total_of(b))
	shown = shown.slice(0, clampi(max_rows, 1, MAX_ROWS))
	var best := 1.0
	var sum := 0.0
	for e in shown:
		best = maxf(best, _total_of(e))
		sum += _total_of(e)
	while _rows.get_child_count() < shown.size():
		_rows.add_child(_make_row())
	for i in _rows.get_child_count():
		var row: Control = _rows.get_child(i)
		row.visible = i < shown.size()
		if row.visible:
			_fill_row(row, shown[i], best)
	_total.text = L.t("Total: %d") % roundi(sum)


func _total_of(e: Dictionary) -> float:
	match tab:
		Tab.BLOCKED:
			return e.reduced + e.shield_taken
		Tab.HEAL:
			return e.heal + e.shield
	return e.physical + e.special + e["true"]


## [value, colour] parts of the bar.
func _parts(e: Dictionary) -> Array:
	match tab:
		Tab.BLOCKED:
			return [[e.reduced, UiStyle.STAT_COLORS.DEF], [e.shield_taken, UiStyle.STAT_COLORS.SHIELD]]
		Tab.HEAL:
			return [[e.heal, UiStyle.GREEN], [e.shield, UiStyle.STAT_COLORS.SHIELD]]
	return [[e.physical, UiStyle.DAMAGE_COLORS.PHYSICAL], [e.special, UiStyle.DAMAGE_COLORS.SPECIAL],
		[e["true"], UiStyle.DAMAGE_COLORS.TRUE]]


func _make_row() -> Control:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	h.add_theme_constant_override("separation", 6)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(ROW_HEIGHT, ROW_HEIGHT)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(portrait)
	var bar := Control.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.draw.connect(func() -> void:
		var r := Rect2(Vector2(0, 6), Vector2(bar.size.x, bar.size.y - 12))
		bar.draw_rect(r, Color(1, 1, 1, 0.06))
		var x := 0.0
		for part in bar.get_meta("parts", []):
			var w: float = r.size.x * float(part[0]) / maxf(float(bar.get_meta("best", 1.0)), 1.0)
			if w > 0.0:
				bar.draw_rect(Rect2(Vector2(x, r.position.y), Vector2(w, r.size.y)), part[1])
			x += w)
	h.add_child(bar)
	var value := UiStyle.label("", 14)
	value.custom_minimum_size = Vector2(46, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(value)
	return h


func _fill_row(row: Control, e: Dictionary, best: float) -> void:
	var u: BattleUnit = e.unit
	var portrait: TextureRect = row.get_child(0)
	portrait.texture = GameData.portrait(u.pkm)
	portrait.modulate.a = 1.0 if u.alive else 0.45
	var bar: Control = row.get_child(1)
	bar.set_meta("parts", _parts(e))
	bar.set_meta("best", best)
	bar.queue_redraw()
	(row.get_child(2) as Label).text = str(roundi(_total_of(e)))
	row.tooltip_text = GameData.display_name(u.pkm)
