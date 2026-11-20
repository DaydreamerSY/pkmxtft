class_name FireflyFrame
extends Control

## Fireflies running around the inner edge of the parent rectangle (highlighted shop
## cards): small glowing dots with a short trail, twinkling, some going the other way.
## Drawn additively; animates only while visible.

@export var color := Color(1.0, 0.85, 0.35)
@export var count := 12
@export var inset := 7.0 ## distance from the edge, px

var _flies: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	for i in count:
		_flies.append({
			"t": randf(),
			"speed": randf_range(0.05, 0.14) * (1.0 if i % 3 != 0 else -1.0), # laps per second
			"phase": randf() * TAU,
			"wobble": randf_range(1.0, 3.5),
			"size": randf_range(1.4, 2.4),
		})


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	for f in _flies:
		f.t = fposmod(f.t + f.speed * delta, 1.0)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	for f in _flies:
		var twinkle := 0.55 + 0.45 * sin(_time * 5.0 + f.phase)
		# trail: fading dots behind the firefly
		for k in range(4, -1, -1):
			var t: float = f.t - sign(f.speed) * 0.006 * k
			var p := _edge_point(r, t, sin(_time * 3.0 + f.phase + k * 0.3) * f.wobble)
			var a := twinkle * (1.0 - k / 5.0)
			if k == 0:
				draw_circle(p, f.size * 3.2, Color(color, 0.18 * a))
				draw_circle(p, f.size * 1.8, Color(color, 0.35 * a))
				draw_circle(p, f.size, Color(color.lightened(0.6), 0.95 * a))
			else:
				draw_circle(p, f.size * (1.0 - k * 0.15), Color(color, 0.3 * a))


## Point at `t` (0..1) along the perimeter of `r` (clockwise from the top left),
## pushed `out` px along the outward normal.
func _edge_point(r: Rect2, t: float, out: float) -> Vector2:
	t = fposmod(t, 1.0)
	var w := r.size.x
	var h := r.size.y
	var d := t * 2.0 * (w + h)
	if d < w:
		return r.position + Vector2(d, -out)
	d -= w
	if d < h:
		return r.position + Vector2(w + out, d)
	d -= h
	if d < w:
		return r.position + Vector2(w - d, h + out)
	d -= w
	return r.position + Vector2(-out, h - d)
