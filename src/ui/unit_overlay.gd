class_name UnitOverlay
extends Control

## 2D layer over the 3D arena: HP / shield / PP bars, held items and stars above every Pokémon, and
## floating combat texts. Positions follow the camera each frame.
## Everything sits above the head, never over the sprite: bars, then the held items, then the stars.
## The sizes follow the size of the Pokémon on the screen (the width of its cell there): full size on
## a desktop, smaller on the far rows and on the compact HUD of a phone, where the board is small.

const BAR_WIDTH := 58.0
const HP_HEIGHT := 7.0
const PP_HEIGHT := 4.0
const STAR_COLOR := Color(1.0, 0.84, 0.25)
const ITEM_SIZE := 20.0
## Width of a cell on the screen (canvas units) from which the bars have their full size, and the
## smallest they get under it.
const FULL_CELL := 80.0
const MIN_SCALE := 0.55

var camera: Camera3D
var views: Array = [] ## UnitView list, set by the game
## World size of a board cell (the game sets it): how wide a Pokémon is on the screen.
var cell_size := 1.0

## Slanted bars and frames of the pixel-art skin (UiSkin), drawn with the LINEAR filter of this layer: they
## shrink with the cells on the far rows and on small boards.
var _bar_back_hp := UiSkin.style("ubar_bg_9", [], Color.WHITE, false)
var _bar_back_pp := UiSkin.style("ubar_bg_6", [], Color.WHITE, false)
var _bar_hp := UiSkin.style("ubar_hp_7", [], Color.WHITE, false)
var _bar_foe := UiSkin.style("ubar_foe_7", [], Color.WHITE, false)
var _bar_shield := UiSkin.style("ubar_shield_7", [], Color.WHITE, false)
var _bar_pp := UiSkin.style("ubar_pp_4", [], Color.WHITE, false)
var _item_frame := UiSkin.style("item_frame_small", [], Color.WHITE, false) ## a held item
var _count_frame := UiSkin.style("count_badge", [], Color.WHITE, false) ## "xN" of a bench slot


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR # item icons are drawn much smaller than their 90 px
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


## Size factor of the bars of a Pokémon standing at `ground` (world): 1 on a cell FULL_CELL wide.
func scale_at(ground: Vector3) -> float:
	var cell := absf(camera.unproject_position(ground + Vector3(cell_size, 0.0, 0.0)).x - camera.unproject_position(ground).x)
	return clampf(cell / FULL_CELL, MIN_SCALE, 1.0)


func _draw() -> void:
	if camera == null:
		return
	for v in views:
		if not is_instance_valid(v) or not v.visible or v.dragging:
			continue
		var head: Vector3 = v.head_position()
		if camera.is_position_behind(head):
			continue
		var p := camera.unproject_position(head)
		var u: BattleUnit = v.battle_unit
		var hp_ratio := 1.0
		var shield_ratio := 0.0
		var pp_ratio := -1.0
		var stars := int(GameData.get_pokemon(v.pkm).get("stars", 1))
		if u != null:
			if not u.alive:
				continue
			hp_ratio = u.hp / u.max_hp
			shield_ratio = minf(u.shield / u.max_hp, 1.0)
			pp_ratio = clampf(u.pp / u.max_pp, 0.0, 1.0)
		var k := scale_at(v.global_position)
		var width := roundf(BAR_WIDTH * k)
		var hp_height := maxf(roundf(HP_HEIGHT * k), 4.0)
		var pp_height := maxf(roundf(PP_HEIGHT * k), 3.0)
		var x := roundf(p.x - width * 0.5)
		# from the head up: PP bar, HP bar, held items, stars
		var y := roundf(p.y) + 2.0
		# slanted bars of the skin: the top edge about half the height right of the bottom one
		var lean := floorf((hp_height - 1.0) * 0.5)
		if pp_ratio >= 0.0:
			y -= pp_height
			draw_style_box(_bar_back_pp, Rect2(x - 1.0, y - 1.0, width + 2.0, pp_height + 2.0))
			_fill(_bar_pp, x, y, width * pp_ratio, pp_height)
			y -= 1.0
		y -= hp_height
		# the team it fights for now (POSSESSED units fight for the other side)
		var side: int = v.battle_unit.team if v.battle_unit != null else v.team
		draw_style_box(_bar_back_hp, Rect2(x - 1.0, y - 1.0, width + 2.0, hp_height + 2.0))
		_fill(_bar_hp if side == BattleUnit.Team.BLUE else _bar_foe, x, y, width * hp_ratio, hp_height)
		if shield_ratio > 0.0:
			var sx := x + width * hp_ratio
			var sw := minf(width * shield_ratio, x + width - sx)
			if sw <= 0.0:
				_fill(_bar_shield, x + width * (1.0 - shield_ratio), y, width * shield_ratio, hp_height)
			else:
				_fill(_bar_shield, sx, y, sw, hp_height)
		if u != null:
			# ticks every 100 HP, like TFT (slanted like the bar)
			var ticks := int(u.max_hp / 100.0)
			for i in range(1, ticks + 1):
				var tx := x + width * (i * 100.0 / u.max_hp)
				if tx < x + width:
					draw_line(Vector2(tx + lean * 0.5, y), Vector2(tx - lean * 0.1, y + hp_height * 0.6), Color(0, 0, 0, 0.6))
		# held items in a row above the bars (the sprite stays clear)
		var held: Array = u.items if u != null else v.items
		if not held.is_empty():
			var item := roundf(ITEM_SIZE * k)
			var pitch := item + 3.0
			y -= item + 4.0
			for i in held.size():
				var tex := GameData.item_icon(held[i])
				if tex != null:
					var ix := roundf(p.x + (i - (held.size() - 1) * 0.5) * pitch - item * 0.5)
					draw_style_box(_item_frame, Rect2(ix - 1, y - 1, item + 2, item + 2))
					draw_texture_rect(tex, Rect2(ix, y, item, item), false)
		var radius := maxf(6.0 * k, 4.0)
		for i in stars:
			var sx := p.x + (i - (stars - 1) * 0.5) * radius * 2.0
			draw_star(self, Vector2(sx, y - radius - 2.0), radius, STAR_COLOR)
		if v.stack_count > 1: # copies sharing its bench slot: a gold "x2" badge in the front right corner of the cell
			var feet := camera.unproject_position(v.global_position)
			var cell := FULL_CELL * k if k < 1.0 else absf(camera.unproject_position(v.global_position + Vector3(cell_size, 0.0, 0.0)).x - feet.x)
			_draw_count(Vector2(feet.x + 0.5 * cell - 4.0, feet.y + 0.28 * cell), v.stack_count, k, true)


## "xN" in a dark gold-framed badge whose bottom left (`right_aligned`: bottom right) corner is `corner`.
func _draw_count(corner: Vector2, count: int, k: float, right_aligned := false) -> void:
	var font := get_theme_default_font()
	var size := maxi(roundi(16.0 * k), 11)
	var text := "x%d" % count
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 6.0
	var h := size + 3.0
	var r := Rect2(corner.x - (w if right_aligned else 0.0), corner.y - h, w, h)
	draw_style_box(_count_frame, r)
	draw_string(font, Vector2(r.position.x + 3.0, r.end.y - 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, STAR_COLOR)


## The filled part of a bar (a skin image stretched to `w` x `h`; nothing under one unit wide).
func _fill(style: StyleBox, x: float, y: float, w: float, h: float) -> void:
	if w >= 1.0:
		draw_style_box(style, Rect2(x, y, w, h))


## Small 5-point star (fonts may lack the ★ glyph).
static func draw_star(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var outer := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		var a := -PI * 0.5 + i * PI / 5.0
		outer.append(center + Vector2(cos(a), sin(a)) * r)
	var shadow := PackedVector2Array()
	for pt in outer:
		shadow.append(pt + (pt - center).normalized() * 1.5)
	canvas.draw_colored_polygon(shadow, Color(0, 0, 0, 0.8))
	canvas.draw_colored_polygon(outer, color)


## Floating number / word above a world point.
func float_text(world_pos: Vector3, text: String, color: Color, size := 20) -> void:
	if camera == null or camera.is_position_behind(world_pos):
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var p := camera.unproject_position(world_pos) + Vector2(randf_range(-14, 14), 0)
	l.position = p - Vector2(l.get_minimum_size().x * 0.5, 0)
	var t := l.create_tween()
	t.set_parallel()
	t.tween_property(l, "position:y", l.position.y - 42.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.45)
	t.chain().tween_callback(l.queue_free)
