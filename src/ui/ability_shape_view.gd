class_name AbilityShapeView
extends Control

## Mini board showing which cells an ability affects (Phase 2), computed by the
## real AbilityRunner on a sample formation: the caster (blue ring) on its side,
## allies (blue dots), enemies (red dots), the chosen target (crosshair).
## Orange = cells hit on enemies, green = allies, purple = itself,
## yellow outline = attack range, dashed ring = where a dash starts.

const AREA_ENEMY := Color(1.0, 0.55, 0.15, 0.75)
const AREA_ALLY := Color(0.35, 0.9, 0.45, 0.7)
const AREA_SELF := Color(0.75, 0.45, 1.0, 0.7)
const RANGE_COLOR := Color(1.0, 0.9, 0.3, 0.9)

var pkm := ""
## Cell size in pixels; small views (the skill icon of the unit panel) hide the legend.
var cell_px := 22.0
var show_legend := true
var _preview: Dictionary = {}


func show_pokemon(pkm_name: String) -> void:
	pkm = pkm_name
	_preview = AbilityRunner.preview(pkm_name) if pkm_name != "" else {}
	custom_minimum_size = Vector2(cell_px * _board_size().x, cell_px * _board_size().y + (30.0 if show_legend else 0.0))
	queue_redraw()


## The board in cells: hexagons one cell wide, odd rows shifted half a cell (BattleBoard).
static func _board_size() -> Vector2:
	return Vector2(BattleBoard.WIDTH + 0.5, (BattleBoard.HEIGHT - 1) * BattleBoard.ROW_STEP + 1.1547005)


## Centre of a cell in pixels (the enemy side on top).
func _center(c: Vector2i) -> Vector2:
	var b := BattleBoard.center(c)
	return Vector2(b.x + 0.5, (BattleBoard.HEIGHT - 1) * BattleBoard.ROW_STEP - b.y + 0.5773503) * cell_px


## Hexagon of a cell (pointy top), `shrink` pixels inside its sides.
func _hex(c: Vector2i, shrink := 0.0) -> PackedVector2Array:
	var center := _center(c)
	var r := maxf(cell_px * 0.5773503 - shrink * 1.1547005, 0.5)
	var out := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(90.0 + 60.0 * i)
		out.append(center + Vector2(cos(a), -sin(a)) * r)
	return out


func _outline(c: Vector2i, shrink: float, color: Color, width: float) -> void:
	var points := _hex(c, shrink)
	points.append(points[0])
	draw_polyline(points, color, width, true)


func _draw() -> void:
	if _preview.is_empty():
		return
	var line := clampf(cell_px / 14.0, 0.75, 1.5)
	var inset := maxf(1.0, cell_px * 0.09)
	for c in BattleBoard.all_cells():
		var base := Color(0.16, 0.22, 0.32) if c.y < BattleBoard.SIDE_ROWS else Color(0.32, 0.17, 0.17)
		if posmod(BattleBoard.to_axial(c).x - c.y, 3) == 0:
			base = base.lightened(0.06)
		draw_colored_polygon(_hex(c, inset * 0.25), base)

	for step in _preview.steps:
		var color := AREA_ENEMY
		match step.affects:
			"allies", "allies_others": color = AREA_ALLY
			"self": color = AREA_SELF
			"all": color = AREA_ENEMY.lerp(AREA_ALLY, 0.5)
		for c in step.cells:
			draw_colored_polygon(_hex(c, inset * 0.5), color)
			_outline(c, inset * 0.5, color.lightened(0.45), line)

	var caster: Vector2i = _preview.caster
	var attack_range := int(GameData.get_pokemon(pkm).get("range", 1))
	for c in BattleBoard.cells_in_range(caster, attack_range):
		_outline(c, inset, RANGE_COLOR, maxf(line * 0.7, 0.75))

	for c in _preview.allies:
		draw_circle(_center(c), cell_px * 0.22, UiStyle.BLUE.darkened(0.2))
	for c in _preview.enemies:
		draw_circle(_center(c), cell_px * 0.17, UiStyle.RED)

	var start: Vector2i = _preview.caster_start
	if start != caster:
		var a := _center(start)
		var b := _center(caster)
		draw_arc(a, cell_px * 0.3, 0.0, TAU, 16, UiStyle.BLUE, line)
		draw_dashed_line(a, b, UiStyle.BLUE, line, cell_px * 0.14)
	var cc := _center(caster)
	draw_circle(cc, cell_px * 0.3, UiStyle.BLUE)
	draw_arc(cc, cell_px * 0.38, 0.0, TAU, 20, Color.WHITE, line)

	if _preview.focus != null:
		var fc := _center(_preview.focus)
		var r := cell_px * 0.42
		var tick := cell_px * 0.16
		draw_arc(fc, r, 0.0, TAU, 20, Color.WHITE, line)
		draw_line(fc - Vector2(r + tick * 0.5, 0), fc - Vector2(r - tick, 0), Color.WHITE, line)
		draw_line(fc + Vector2(r - tick, 0), fc + Vector2(r + tick * 0.5, 0), Color.WHITE, line)
		draw_line(fc - Vector2(0, r + tick * 0.5), fc - Vector2(0, r - tick), Color.WHITE, line)
		draw_line(fc + Vector2(0, r - tick), fc + Vector2(0, r + tick * 0.5), Color.WHITE, line)

	if not show_legend:
		return
	var font := get_theme_default_font()
	var y := cell_px * _board_size().y + 16
	var items := [[AREA_ENEMY, "hit"], [AREA_ALLY, "ally"], [RANGE_COLOR, "range"]]
	var x := 0.0
	for item in items:
		draw_rect(Rect2(x, y - 9, 10, 10), item[0], item[1] != "range")
		if item[1] == "range":
			draw_rect(Rect2(x, y - 9, 10, 10), item[0], false, 1.0)
		var label := L.t(item[1])
		draw_string(font, Vector2(x + 14, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiStyle.TEXT_DIM)
		x += maxf(58.0, font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 26.0)
