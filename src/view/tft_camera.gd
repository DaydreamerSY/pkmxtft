@tool
class_name TftCamera
extends Camera3D

## TFT-like camera: a perspective view from the player's side, looking down at
## the board so the far (enemy) rows get narrower, like Teamfight Tactics.
##
## It orbits `focus_point` (a point on the ground): pitch = how steep it looks
## down, yaw = rotation around the board, distance = how far it stands.
## The script runs in the editor (@tool): change any value in the Inspector and
## the 3D viewport / "Preview" of this camera updates immediately.
##
## Board scale: 1 cell = 1 unit (see Arena.cell_size), the board is 7 x 8 hexagons (7.5 x 7.2 units)
## centred on the origin, the player's side toward +Z (bottom of the screen).

@export_group("Framing")
## Point on the ground the camera looks at. z > 0 moves the view toward the player side / bench.
@export var focus_point := Vector3(0.0, 0.0, 1.45):
	set(v):
		focus_point = v
		_refresh()
## Angle below the horizon, in degrees. 90 = straight top-down, TFT is around 50-60.
@export_range(15.0, 89.0, 0.5, "suffix:°") var pitch_degrees := 55.0:
	set(v):
		pitch_degrees = v
		_refresh()
## Rotation around the board, in degrees. 0 = behind the player's side.
@export_range(-180.0, 180.0, 0.5, "suffix:°") var yaw_degrees := 0.0:
	set(v):
		yaw_degrees = v
		_refresh()
## Distance from the focus point, at zoom 1.
@export_range(2.0, 60.0, 0.05) var distance := 14.6:
	set(v):
		distance = v
		_refresh()
## Vertical field of view. Lower = flatter, more "telephoto" (TFT uses a narrow FOV).
@export_range(5.0, 120.0, 0.5, "suffix:°") var field_of_view := 38.0:
	set(v):
		field_of_view = v
		_refresh()
## Shifts the picture without changing the angle (Camera3D h/v offset), e.g. to
## leave room for the shop at the bottom of the screen.
@export var screen_offset := Vector2(0.0, -0.5):
	set(v):
		screen_offset = v
		_refresh()
## Orthographic view (no perspective), for comparison.
@export var use_orthographic := false:
	set(v):
		use_orthographic = v
		_refresh()
@export_range(1.0, 40.0, 0.1) var orthographic_size := 9.5:
	set(v):
		orthographic_size = v
		_refresh()

@export_group("Zoom")
## Mouse wheel zoom (in game only).
@export var zoom_enabled := true
## Closest zoom, as a factor of `distance`.
@export_range(0.2, 1.0, 0.01) var zoom_min := 0.8
## Farthest zoom, as a factor of `distance`.
@export_range(1.0, 3.0, 0.01) var zoom_max := 1.15
## Zoom change per wheel notch.
@export_range(0.01, 0.5, 0.01) var zoom_step := 0.05
## How fast the zoom follows the wheel (higher = snappier).
@export_range(1.0, 30.0, 0.5) var zoom_smoothing := 10.0
## Extra pitch (degrees) when fully zoomed in, 0 keeps the angle constant like TFT.
@export_range(-30.0, 30.0, 0.5, "suffix:°") var zoom_pitch_bonus := 0.0

@export_group("Pan")
## Drag with the middle mouse button to pan (in game only). TFT does not pan.
@export var pan_enabled := false
## Maximum pan away from focus_point, in cells (x = sideways, y = forward).
@export var pan_limit := Vector2(2.0, 1.5)
## Pan speed, in cells per screen pixel at zoom 1.
@export_range(0.001, 0.05, 0.001) var pan_speed := 0.012

@export_group("Shake")
## Maximum shake offset, in cells (big hits call shake()).
@export_range(0.0, 0.5, 0.01) var shake_strength := 0.06
@export_range(0.05, 2.0, 0.01) var shake_duration := 0.25

var _zoom := 1.0
var _zoom_target := 1.0
var _pan := Vector2.ZERO
var _panning := false
var _shake_time := 0.0


func _ready() -> void:
	_refresh()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var dirty := false
	if not is_equal_approx(_zoom, _zoom_target):
		_zoom = lerpf(_zoom, _zoom_target, 1.0 - exp(-zoom_smoothing * delta))
		if absf(_zoom - _zoom_target) < 0.0005:
			_zoom = _zoom_target
		dirty = true
	if _shake_time > 0.0:
		_shake_time = maxf(_shake_time - delta, 0.0)
		dirty = true
	if dirty:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if zoom_enabled and mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_target = clampf(_zoom_target - zoom_step, zoom_min, zoom_max)
		elif zoom_enabled and mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_target = clampf(_zoom_target + zoom_step, zoom_min, zoom_max)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = pan_enabled and mb.pressed
	elif event is InputEventMouseMotion and _panning:
		var motion := (event as InputEventMouseMotion).relative
		var yaw := deg_to_rad(yaw_degrees)
		var right := Vector2(cos(yaw), -sin(yaw))
		var forward := Vector2(sin(yaw), cos(yaw))
		var d := (-right * motion.x - forward * motion.y) * pan_speed * _zoom
		_pan = (_pan + d).clamp(-pan_limit, pan_limit)
		_refresh()


## Short camera shake, e.g. for a big ability.
func shake(strength_scale := 1.0) -> void:
	_shake_time = shake_duration * strength_scale


## Frames the world `points` inside `rect` (viewport coordinates): the closest distance at which
## they all fit, the picture shifted (screen_offset) so that they are centred. Pitch, yaw and field of
## view are kept, the wheel zoom is reset. Used by the compact HUD (phones): the board takes the room
## the panels leave, whatever the screen ratio and the UI size.
func frame(points: PackedVector3Array, rect: Rect2) -> void:
	if points.is_empty() or rect.size.x <= 1.0 or rect.size.y <= 1.0 or not is_inside_tree():
		return
	_zoom = 1.0
	_zoom_target = 1.0
	var near_limit := 3.0
	var far_limit := 60.0
	for _i in 18:
		distance = (near_limit + far_limit) * 0.5
		var box := _centre(points, rect)
		if box.size.x <= rect.size.x and box.size.y <= rect.size.y:
			far_limit = distance
		else:
			near_limit = distance
	distance = far_limit
	_centre(points, rect)


## Shifts the picture so that the screen box of `points` is centred on `rect`; returns that box.
func _centre(points: PackedVector3Array, rect: Rect2) -> Rect2:
	var box := screen_box(points)
	for _i in 4:
		var delta := rect.get_center() - box.get_center()
		if delta.length() < 0.5:
			break
		var before := screen_offset
		screen_offset = before + Vector2(0.1, 0.1)
		var per_unit := (screen_box(points).get_center() - box.get_center()) / 0.1 # pixels per unit of offset
		if absf(per_unit.x) < 0.001 or absf(per_unit.y) < 0.001:
			screen_offset = before
			break
		screen_offset = before + Vector2(delta.x / per_unit.x, delta.y / per_unit.y)
		box = screen_box(points)
	return box


## Bounding box on the screen of world points.
func screen_box(points: PackedVector3Array) -> Rect2:
	var box := Rect2(unproject_position(points[0]), Vector2.ZERO)
	for p in points:
		box = box.expand(unproject_position(p))
	return box


func reset_view() -> void:
	_zoom = 1.0
	_zoom_target = 1.0
	_pan = Vector2.ZERO
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var pitch := deg_to_rad(pitch_degrees + zoom_pitch_bonus * clampf((1.0 - _zoom) / maxf(1.0 - zoom_min, 0.001), 0.0, 1.0))
	var yaw := deg_to_rad(yaw_degrees)
	var target := focus_point + Vector3(_pan.x, 0.0, _pan.y)
	if _shake_time > 0.0:
		var k := _shake_time / shake_duration * shake_strength
		target += Vector3(randf_range(-k, k), 0.0, randf_range(-k, k))
	var arm := Vector3(0.0, sin(pitch), cos(pitch)).rotated(Vector3.UP, yaw)
	var eye := target + arm * distance * _zoom
	look_at_from_position(eye, target, Vector3.UP)
	fov = field_of_view
	h_offset = screen_offset.x
	v_offset = screen_offset.y
	projection = PROJECTION_ORTHOGONAL if use_orthographic else PROJECTION_PERSPECTIVE
	size = orthographic_size * _zoom
	near = 0.05
	far = 200.0


## Point of the ground plane (y = 0) under a screen position, or null.
func ground_point(screen_pos: Vector2) -> Variant:
	var from := project_ray_origin(screen_pos)
	var dir := project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return null
	var t := -from.y / dir.y
	if t < 0.0:
		return null
	return from + dir * t
