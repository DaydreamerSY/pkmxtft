@tool
class_name Arena
extends Node3D

## The arena: painted ground, the board platform (BattleBoard.WIDTH x HEIGHT pointy-top hexagons, odd rows
## shifted half a cell to the right, + `bench_rows` rows of 8 square bench slots) and the cell highlights.
## The floor is a Pokémon battle field: a big Poké Ball painted in the middle (red half on the enemy side),
## thin lines between the cells. Runs in the editor (@tool) so the layout can be tuned with the camera.
##
## Cell <-> world (see docs/PORTING.md, "Lưới lục giác"), cell_size = width of a hexagon (column spacing):
##   board cell (x, y): X = (x + 0.5 (y odd) - 3.25) * cell_size, Z = (3.5 - y) * ROW_STEP * cell_size
##   bench slot i:      X = (-half width + (i % 8 + 0.5) * bench_slot) * cell_size,
##                      Z = (half depth + bench_gap + (i / 8 + 0.5) * bench_slot) * cell_size
## (BattleBoard.center gives the board coordinates of a cell). A Pokémon stands with its feet on the centre
## of exactly one cell.
##
## Highlights are layers of {cell: Color} (bench slot i = Vector2i(i, BENCH_ROW)),
## drawn in LAYER_ORDER, plus timed flashes on top (ability areas). The Ground holes are
## pits painted by the board shader (set_hole_depths); short texts can lie on the floor of
## cells (set_cell_labels: the depth of the holes).

const BENCH_ROW := -1
const BENCH_COLUMNS := 8
## Texels of the highlight / hole textures per row: the 7 board columns or the 8 bench slots.
const TEX_W := 8
## dig = cells a Ground Pokémon digs at the next stage, light = Light spotlight, board_effect = EMBER cells.
## synergy = cells of the Pokémon of the hovered synergy.
const LAYER_ORDER: Array[String] = ["light", "board_effect", "occupied", "dig", "synergy", "valid", "range", "ability", "hover",
	"target"]
## Optional painted Poké Ball (any image with transparency around a round ball), used instead of the
## procedural one when the file exists.
const BALL_IMAGE := "res://assets/arena/pokeball.png"

## Board geometry in cells (1 cell = cell_size world units).
const ROW_STEP := BattleBoard.ROW_STEP
## Centre of the board in BattleBoard.center coordinates (the world origin).
const CENTER := Vector2((BattleBoard.WIDTH - 0.5) * 0.5, (BattleBoard.HEIGHT - 1) * 0.5 * BattleBoard.ROW_STEP)
## Half width of the board (the outer sides of the hexagons) and half depth (their points).
const HALF_W := (BattleBoard.WIDTH + 0.5) * 0.5
const HALF_D := (BattleBoard.HEIGHT - 1) * 0.5 * BattleBoard.ROW_STEP + 0.57735027
## Width (and depth) of a bench slot: the 8 slots span the board width.
const BENCH_SLOT := 2.0 * HALF_W / BENCH_COLUMNS

@export_group("Layout")
## Size of one cell (width of a hexagon) in world units. The camera distance is tuned for 1.0.
@export_range(0.25, 4.0, 0.05) var cell_size := 1.0:
	set(v):
		cell_size = v
		_rebuild()
## Rows of 8 bench slots (the game sets it from PlayerState.bench_size).
@export_range(1, 3, 1) var bench_rows := 1:
	set(v):
		bench_rows = clampi(v, 1, 3)
		_rebuild()
## Empty space between the board and the bench, in cells.
@export_range(0.0, 2.0, 0.05) var bench_gap := 0.4:
	set(v):
		bench_gap = v
		_rebuild()
## Border around board and bench, in cells.
@export_range(0.0, 2.0, 0.05) var rim_margin := 0.3:
	set(v):
		rim_margin = v
		_rebuild()
## Height of the platform slab (its front side is visible, it gives depth).
@export_range(0.0, 1.0, 0.01) var platform_thickness := 0.22:
	set(v):
		platform_thickness = v
		_rebuild()

@export_group("Look")
## Snaps the painted floor to a pixel grid (pixels per cell) so it matches the
## pixel-art sprites. 48 / Game.sprite_scale gives the sprite pixel size. 0 = smooth.
@export_range(0.0, 96.0, 1.0) var pixel_density := 27.0:
	set(v):
		pixel_density = v
		_apply_params()
@export var show_grid := true:
	set(v):
		show_grid = v
		_apply_params()
## Lines between the cells: how dark (0 = none) and how wide (in cells, at least one floor pixel).
@export_range(0.0, 1.0, 0.01) var grid_strength := 0.22:
	set(v):
		grid_strength = v
		_apply_params()
@export_range(0.0, 0.2, 0.005) var grid_width := 0.03:
	set(v):
		grid_width = v
		_apply_params()
## The field: two clay tones (the cells alternate in 3 shades), tinted toward each team on its side.
@export var stone_light := Color(0.80, 0.72, 0.57):
	set(v):
		stone_light = v
		_apply_params()
@export var stone_dark := Color(0.74, 0.66, 0.52):
	set(v):
		stone_dark = v
		_apply_params()
@export var player_tint := Color(0.30, 0.52, 0.95):
	set(v):
		player_tint = v
		_apply_params()
@export var enemy_tint := Color(0.95, 0.38, 0.32):
	set(v):
		enemy_tint = v
		_apply_params()
@export_range(0.0, 1.0, 0.01) var side_tint := 0.12:
	set(v):
		side_tint = v
		_apply_params()
## White paint of the field lines (border, centre line, circle).
@export var field_line_color := Color(0.97, 0.96, 0.92):
	set(v):
		field_line_color = v
		_apply_params()
@export_range(0.0, 1.0, 0.01) var field_line_strength := 0.7:
	set(v):
		field_line_strength = v
		_apply_params()
## The Poké Ball painted in the middle: radius in cells and how strong the paint is.
@export_range(0.5, 4.0, 0.05) var ball_radius := 2.35:
	set(v):
		ball_radius = v
		_apply_params()
@export_range(0.0, 1.0, 0.01) var ball_strength := 0.6:
	set(v):
		ball_strength = v
		_apply_params()
@export var ball_red := Color(0.86, 0.2, 0.18):
	set(v):
		ball_red = v
		_apply_params()
@export var ball_white := Color(0.97, 0.96, 0.93):
	set(v):
		ball_white = v
		_apply_params()
@export var ball_black := Color(0.13, 0.12, 0.14):
	set(v):
		ball_black = v
		_apply_params()
## Painted Poké Ball image (replaces the procedural one); BALL_IMAGE when the file exists.
@export var ball_texture: Texture2D:
	set(v):
		ball_texture = v
		_apply_params()
@export var bench_color := Color(0.55, 0.47, 0.38):
	set(v):
		bench_color = v
		_apply_params()
@export var rim_color := Color(0.36, 0.30, 0.26):
	set(v):
		rim_color = v
		_apply_params()
@export var platform_side_color := Color(0.22, 0.18, 0.16):
	set(v):
		platform_side_color = v
		_apply_params()
@export var grass_a := Color(0.30, 0.42, 0.24):
	set(v):
		grass_a = v
		_apply_params()
@export var grass_b := Color(0.22, 0.33, 0.19):
	set(v):
		grass_b = v
		_apply_params()
## Optional painted image for the ground (replaces the procedural grass),
## e.g. an arena background. It covers `ground_texture_rect` (world X/Z).
@export var ground_texture: Texture2D:
	set(v):
		ground_texture = v
		_rebuild()
@export var ground_texture_rect := Rect2(-12.0, -8.0, 24.0, 16.0):
	set(v):
		ground_texture_rect = v
		_rebuild()

var _board_mat: ShaderMaterial
var _ground_mat: Material
var _side_mat: StandardMaterial3D
var _highlight_image: Image
var _highlight_tex: ImageTexture
var _hole_image: Image
var _hole_tex: ImageTexture
var _hole_depths: Dictionary = {} ## cell -> depth 0..1
var _layers: Dictionary = {}
var _floor_labels: Dictionary = {} ## label layer -> Array[Label3D]
var _floor_label_data: Dictionary = {} ## label layer -> the cells it shows
var _flashes: Array = [] ## {cells, color, time, duration, pulse}
var _dirty := true
var _built := false


func _ready() -> void:
	if ball_texture == null and ResourceLoader.exists(BALL_IMAGE):
		ball_texture = load(BALL_IMAGE)
	_rebuild()


func _process(delta: float) -> void:
	if not _flashes.is_empty():
		for f in _flashes:
			f.time += delta
		_flashes = _flashes.filter(func(f: Dictionary) -> bool: return f.time < f.duration)
		_dirty = true
	if _dirty:
		_upload_highlights()


#region coordinates
func cell_to_world(cell: Vector2i) -> Vector3:
	if cell.y == BENCH_ROW:
		return bench_to_world(cell.x)
	var c := BattleBoard.center(cell) - CENTER
	return Vector3(c.x, 0.0, -c.y) * cell_size


func bench_to_world(slot: int) -> Vector3:
	var row := slot / BENCH_COLUMNS
	return Vector3(-HALF_W + (slot % BENCH_COLUMNS + 0.5) * BENCH_SLOT, 0.0,
		HALF_D + bench_gap + (row + 0.5) * BENCH_SLOT) * cell_size


## {"board": Vector2i} or {"bench": int} under a ground point, {} elsewhere.
func world_to_slot(p: Vector3) -> Dictionary:
	var cell := BattleBoard.cell_at(Vector2(p.x / cell_size, -p.z / cell_size) + CENTER)
	if BattleBoard.in_bounds(cell):
		return {"board": cell}
	var xf := (p.x / cell_size + HALF_W) / BENCH_SLOT
	var bench_z := (p.z / cell_size - HALF_D - bench_gap) / BENCH_SLOT
	if xf >= 0.0 and xf < BENCH_COLUMNS and bench_z >= 0.0 and bench_z < bench_rows:
		return {"bench": int(floor(bench_z)) * BENCH_COLUMNS + int(floor(xf))}
	return {}


static func slot_key(slot: Dictionary) -> Variant:
	if slot.has("board"):
		return slot.board
	if slot.has("bench"):
		return Vector2i(slot.bench, BENCH_ROW)
	return null


## Edges of the board (the outer sides / points of its hexagons) in world units.
func board_half_width() -> float:
	return HALF_W * cell_size


func board_far_z() -> float:
	return -HALF_D * cell_size


func board_near_z() -> float:
	return HALF_D * cell_size


## Near edge of the last bench row, in world units.
func bench_near_z() -> float:
	return (HALF_D + bench_gap + bench_rows * BENCH_SLOT) * cell_size
#endregion


#region highlights
## Replaces a highlight layer. `cells` maps Vector2i (bench = (i, BENCH_ROW)) -> Color.
func set_layer(layer: String, cells: Dictionary) -> void:
	_layers[layer] = cells
	_dirty = true


func clear_layer(layer: String) -> void:
	if _layers.has(layer):
		_layers.erase(layer)
		_dirty = true


## Ground holes: `depths` maps board cells to their depth, 0..1 (1 = the deepest hole).
func set_hole_depths(depths: Dictionary) -> void:
	_hole_depths = depths.duplicate()
	_upload_holes()


func _upload_holes() -> void:
	if _hole_image == null:
		return
	_hole_image.fill(Color(0, 0, 0, 0))
	for cell in _hole_depths:
		if BattleBoard.in_bounds(cell):
			_hole_image.set_pixel(cell.x, cell.y, Color(clampf(float(_hole_depths[cell]), 0.0, 1.0), 0.0, 0.0, 1.0))
	_hole_tex.update(_hole_image)


## Replaces the texts lying on the floor of cells. `cells` maps Vector2i -> {text, color}.
## They sit on the edge of the cell facing the camera, below the feet of a Pokémon standing there.
func set_cell_labels(layer: String, cells: Dictionary) -> void:
	if _floor_label_data.get(layer, {}) == cells:
		return
	_floor_label_data[layer] = cells.duplicate(true)
	for old in _floor_labels.get(layer, []):
		if is_instance_valid(old):
			old.queue_free()
	var made: Array[Label3D] = []
	for cell in cells:
		var info: Dictionary = cells[cell]
		var label := Label3D.new()
		label.text = String(info.get("text", ""))
		label.modulate = info.get("color", Color.WHITE)
		label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
		label.outline_size = 10
		label.font_size = 40
		label.pixel_size = 0.0055 * cell_size
		label.shaded = false
		label.double_sided = false
		label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		label.position = cell_to_world(cell) + Vector3(0.0, 0.02, 0.33 * cell_size)
		add_child(label)
		made.append(label)
	_floor_labels[layer] = made


## Lights cells for a moment (ability area). pulse = blinking telegraph.
func flash(cells: Array, color: Color, duration := 0.6, pulse := false) -> void:
	_flashes.append({"cells": cells, "color": color, "time": 0.0, "duration": duration, "pulse": pulse})
	_dirty = true


func clear_flashes() -> void:
	_flashes.clear()
	_dirty = true


func _upload_highlights() -> void:
	_dirty = false
	if _highlight_image == null:
		return
	_highlight_image.fill(Color(0, 0, 0, 0))
	for layer in LAYER_ORDER:
		var cells: Dictionary = _layers.get(layer, {})
		for cell in cells:
			_blend(cell, cells[cell])
	for f in _flashes:
		var k: float = 1.0 - f.time / f.duration
		if f.pulse:
			k = 0.55 + 0.45 * sin(f.time * 14.0)
		var c: Color = f.color
		c.a *= clampf(k * 1.5, 0.0, 1.0)
		for cell in f.cells:
			_blend(cell, c)
	_highlight_tex.update(_highlight_image)


## Texel of a cell in the highlight / hole textures: board rows first, then the bench rows.
func _texel(cell: Vector2i) -> Vector2i:
	if cell.y == BENCH_ROW:
		return Vector2i(cell.x % BENCH_COLUMNS, BattleBoard.HEIGHT + cell.x / BENCH_COLUMNS)
	return cell if BattleBoard.in_bounds(cell) else Vector2i(-1, -1)


func _blend(cell: Vector2i, color: Color) -> void:
	var t := _texel(cell)
	if t.x < 0 or t.x >= TEX_W or t.y < 0 or t.y >= BattleBoard.HEIGHT + bench_rows:
		return
	var under := _highlight_image.get_pixel(t.x, t.y)
	var a := color.a + under.a * (1.0 - color.a)
	var rgb := (Color(color.r, color.g, color.b) * color.a + Color(under.r, under.g, under.b) * under.a * (1.0 - color.a)) / maxf(a, 0.001)
	_highlight_image.set_pixel(t.x, t.y, Color(rgb.r, rgb.g, rgb.b, a))
#endregion


#region build
func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.has_meta("arena_generated"):
			child.queue_free()

	_highlight_image = Image.create(TEX_W, BattleBoard.HEIGHT + bench_rows, false, Image.FORMAT_RGBA8)
	_highlight_tex = ImageTexture.create_from_image(_highlight_image)
	_hole_image = Image.create(TEX_W, BattleBoard.HEIGHT + bench_rows, false, Image.FORMAT_RGBA8)
	_hole_tex = ImageTexture.create_from_image(_hole_image)
	_upload_holes()

	var rect := _platform_rect()
	var center := Vector3(rect.get_center().x, 0.0, rect.get_center().y)

	# ground
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(80.0, 80.0) * cell_size
	ground.mesh = ground_mesh
	ground.position = Vector3(0.0, -platform_thickness, center.z)
	if ground_texture:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = ground_texture
		ground_mesh.size = ground_texture_rect.size
		ground.position = Vector3(ground_texture_rect.get_center().x, -platform_thickness, ground_texture_rect.get_center().y)
		_ground_mat = mat
	else:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://src/view/shaders/ground.gdshader")
		_ground_mat = mat
	ground.material_override = _ground_mat
	_add_generated(ground, "Ground")

	# platform slab: its front face gives the board some thickness
	if platform_thickness > 0.0:
		var slab := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(rect.size.x, platform_thickness, rect.size.y)
		slab.mesh = box
		slab.position = center + Vector3(0.0, -platform_thickness * 0.5 - 0.002, 0.0)
		_side_mat = StandardMaterial3D.new()
		_side_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		slab.material_override = _side_mat
		_add_generated(slab, "PlatformSlab")

	# board surface (cells, bench, highlights)
	var top := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = rect.size
	top.mesh = plane
	top.position = center
	_board_mat = ShaderMaterial.new()
	_board_mat.shader = preload("res://src/view/shaders/board.gdshader")
	top.material_override = _board_mat
	_add_generated(top, "Board")

	_built = true
	_apply_params()
	_dirty = true


## The platform (board, bench and their border) on the ground, world X / Z.
func _platform_rect() -> Rect2:
	var min_x := -(HALF_W + rim_margin) * cell_size
	var min_z := -(HALF_D + rim_margin) * cell_size
	var max_z := bench_near_z() + rim_margin * cell_size
	return Rect2(min_x, min_z, -2.0 * min_x, max_z - min_z)


func _add_generated(node: Node3D, node_name: String) -> void:
	node.name = node_name
	node.set_meta("arena_generated", true)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _apply_params() -> void:
	if not _built or _board_mat == null:
		return
	_board_mat.set_shader_parameter("cell_size", cell_size)
	_board_mat.set_shader_parameter("board_size", Vector2(BattleBoard.WIDTH, BattleBoard.HEIGHT))
	_board_mat.set_shader_parameter("bench_gap", bench_gap)
	_board_mat.set_shader_parameter("bench_rows", bench_rows)
	_board_mat.set_shader_parameter("bench_slot", BENCH_SLOT)
	_board_mat.set_shader_parameter("rim_margin", rim_margin)
	_board_mat.set_shader_parameter("highlight_tex", _highlight_tex)
	_board_mat.set_shader_parameter("hole_tex", _hole_tex)
	_board_mat.set_shader_parameter("show_grid", show_grid)
	_board_mat.set_shader_parameter("grid_strength", grid_strength)
	_board_mat.set_shader_parameter("grid_width", grid_width)
	_board_mat.set_shader_parameter("pixel_density", pixel_density)
	_board_mat.set_shader_parameter("stone_light", stone_light)
	_board_mat.set_shader_parameter("stone_dark", stone_dark)
	_board_mat.set_shader_parameter("player_tint", player_tint)
	_board_mat.set_shader_parameter("enemy_tint", enemy_tint)
	_board_mat.set_shader_parameter("side_tint", side_tint)
	_board_mat.set_shader_parameter("field_line_color", field_line_color)
	_board_mat.set_shader_parameter("field_line_strength", field_line_strength)
	_board_mat.set_shader_parameter("ball_radius", ball_radius)
	_board_mat.set_shader_parameter("ball_strength", ball_strength)
	_board_mat.set_shader_parameter("ball_red", ball_red)
	_board_mat.set_shader_parameter("ball_white", ball_white)
	_board_mat.set_shader_parameter("ball_black", ball_black)
	_board_mat.set_shader_parameter("use_ball_tex", ball_texture != null)
	if ball_texture != null:
		_board_mat.set_shader_parameter("ball_tex", ball_texture)
	_board_mat.set_shader_parameter("bench_color", bench_color)
	_board_mat.set_shader_parameter("rim_color", rim_color)
	if _side_mat:
		_side_mat.albedo_color = platform_side_color
	if _ground_mat is ShaderMaterial:
		var gm := _ground_mat as ShaderMaterial
		var rect := _platform_rect()
		gm.set_shader_parameter("grass_a", grass_a)
		gm.set_shader_parameter("grass_b", grass_b)
		gm.set_shader_parameter("pixel_density", pixel_density / cell_size)
		gm.set_shader_parameter("platform_half", rect.size * 0.5)
		gm.set_shader_parameter("platform_center_z", rect.get_center().y)
#endregion
