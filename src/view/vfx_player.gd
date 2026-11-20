class_name VfxPlayer
extends Node3D

## The visual effects of the web game on the arena: ability animations
## (data/ability_vfx.json, from abilities-animations.ts), basic attack projectiles /
## strikes and hit sparks (pokemon-sprite.ts attackAnimation, displayHit) and the
## evolution burst. Sprites face the camera (rotated in the screen plane for the
## oriented ones) and are drawn over the floor like the Pokémon.
## Sizes follow the web game (a cell is 96 px) times `size_scale`.

const WEB_CELL := 96.0
const CELLS_WINDOW_S := 3.0 ## "cells" specs follow the areas of the cast for this long
const ORBIT_SPEED := 4.8 ## rad/s (web: 0.08 rad per frame)
const EIGHT_DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0), Vector2i(1, -1),
	Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1)]

## Effect size multiplier over the web proportions (the Pokémon are drawn bigger too).
@export_range(0.5, 3.0, 0.05) var size_scale := 1.3

var camera: Camera3D
var arena: Arena
var speed := 1.0 ## fight speed (x1, x2, x4): animations and flights go faster
## Callable(BattleUnit) -> Vector3: where the unit is drawn (its view), else its cell.
var body_of: Callable

var _pending_cells: Dictionary = {} ## caster id -> {key, spec, ap, left}
var _generation := 0 ## bumped by clear(): delayed effects of an old fight are dropped


func _process(delta: float) -> void:
	for id in _pending_cells.keys():
		_pending_cells[id].left -= delta * speed
		if _pending_cells[id].left <= 0.0:
			_pending_cells.erase(id)


func clear() -> void:
	_generation += 1
	_pending_cells.clear()
	for c in get_children():
		c.queue_free()


#region game hooks
## Effects of an ability cast (data/ability_vfx.json). `everyone`: every unit on the board
## ("everyone" specs: Teeter Dance), the enemies by default.
func play_ability(ability: String, caster: BattleUnit, focus: BattleUnit, enemies: Array, everyone: Array = []) -> void:
	var from := _body(caster)
	var to := _body(focus) if focus != null else from
	var ctx := {"ability": ability, "caster": caster, "from": from, "to": to, "ap": caster.ap,
		"from_cell": caster.cell, "to_cell": focus.cell if focus != null else caster.cell,
		"enemies": enemies.map(func(e: BattleUnit) -> Vector3: return _body(e)),
		"everyone": (everyone if not everyone.is_empty() else enemies + [caster]).map(
			func(e: BattleUnit) -> Vector3: return _body(e))}
	for spec in VfxLibrary.ability_specs(ability):
		if spec is Dictionary:
			var count := int(spec.get("count", 1))
			for i in count:
				var delay := float(spec.get("delay", 0)) + i * float(spec.get("interval", 0))
				_later(delay, _play_spec.bind(spec, ctx))


## Cells hit by a step of an ability ("cells" specs: Thunder, Hail...).
func on_area(unit: BattleUnit, cells: Array) -> void:
	if unit == null or not _pending_cells.has(unit.id):
		return
	var p: Dictionary = _pending_cells[unit.id]
	for c in cells:
		_anim(p.key, _cell_body(c), p.spec, p.ap)


## Basic attack: a projectile for "…/range" sprites, else a strike on the target.
func attack(sprite: String, from: Vector3, to: Vector3, hit_delay_ms: float) -> void:
	var key := "attacks/" + sprite
	if not VfxLibrary.has(key):
		return
	var sc := VfxLibrary.attack_scale(sprite)
	var spec := {"scale": [sc.x, sc.y]}
	if sprite.ends_with("/range"):
		var flight := minf(250.0, hit_delay_ms)
		_later(hit_delay_ms - flight, func() -> void:
			_projectile(key, from + _screen_offset([0, -10]), to, flight, spec, 0.0, 0.0))
	else:
		_later(maxf(hit_delay_ms - 120.0, 0.0), func() -> void: _anim(key, to, spec, 0.0))


## Hit spark on a damaged unit (one of the attacker's hit sprites).
func hit(sprites: Array, pos: Vector3) -> void:
	if sprites.is_empty():
		return
	var sprite := String(sprites[randi() % sprites.size()])
	var sc := VfxLibrary.attack_scale(sprite)
	_anim("attacks/" + sprite, pos + _screen_offset([randf_range(-15, 15), randf_range(-15, 15)]),
		{"scale": [sc.x, sc.y]}, 0.0)


func evolution(pos: Vector3) -> void:
	_anim("abilities/EVOLUTION", pos, {"origin": [0.5, 0.4]}, 0.0)
#endregion


#region specs
func _play_spec(spec: Dictionary, ctx: Dictionary) -> void:
	var key := "%s/%s" % [spec.get("pack", "abilities"), spec.get("anim", ctx.ability)]
	var ap := float(ctx.ap)
	var from: Vector3 = ctx.from
	var to: Vector3 = ctx.to
	var angle := _screen_angle(from, to) if spec.get("oriented", false) else 0.0
	match String(spec.get("at", "caster")):
		"caster":
			_anim(key, from + _jitter(spec), spec, ap, angle)
		"target":
			_anim(key, to + _jitter(spec), spec, ap, angle)
		"enemies":
			for p in ctx.enemies:
				_anim(key, p, spec, ap, angle)
		"everyone":
			for p in ctx.everyone:
				_anim(key, p, spec, ap, angle)
		"unowns":
			_unowns(from, spec)
		"shake":
			if camera is TftCamera:
				camera.shake(0.6)
		"cells":
			_pending_cells[ctx.caster.id] = {"key": key, "spec": spec, "ap": ap, "left": CELLS_WINDOW_S}
		"row":
			_anim(key, _row_centre(ctx.to_cell.y), spec, ap, angle)
		"row_sweep":
			var y: int = ctx.to_cell.y
			_projectile(key, _cell_body(Vector2i(0, y)), _cell_body(Vector2i(BattleBoard.WIDTH - 1, y)), float(spec.get("duration", 1000)),
				spec, ap, float(spec.get("rotation", 0.0)))
		"skyfall":
			_projectile(key, to + Vector3.UP * 5.0 * arena.cell_size, to, float(spec.get("duration", 500)), spec, ap,
				angle + float(spec.get("rotation", 0.0)))
		"orbit":
			_orbit(key, from, spec, ap)
		"projectile":
			var start := to if spec.get("from", "caster") == "target" else from
			if spec.has("from_cell"):
				start = _spec_cell(spec.from_cell, ctx)
			start += _screen_offset(spec.get("offset", [0, 0]))
			var ends: Array[Vector3] = []
			if spec.has("to_cell"):
				ends.append(_spec_cell(spec.to_cell, ctx))
			elif spec.has("distance") or spec.has("dirs"):
				var dist := float(spec.get("distance", 12)) * arena.cell_size
				if int(spec.get("dirs", 0)) == 8:
					for d in EIGHT_DIRS:
						ends.append(start + Vector3(d.x, 0.0, -d.y).normalized() * dist)
				else:
					var dir := to - from
					dir.y = 0.0
					if dir.length() < 0.001:
						dir = Vector3(0, 0, -1)
					# spread: several directions around the one toward the target (Water Shuriken)
					for deg in spec.get("spread", [0]):
						ends.append(start + dir.normalized().rotated(Vector3.UP, deg_to_rad(float(deg))) * dist)
			else:
				ends.append(from if spec.get("to", "target") == "caster" else to)
			var no_offset := spec.duplicate()
			no_offset.erase("offset")
			for end in ends:
				end += _screen_offset(spec.get("to_offset", [0, 0]))
				var a := _screen_angle(start, end) + float(spec.get("rotation", 0.0)) if spec.get("oriented", false) \
					else float(spec.get("rotation", 0.0))
				_projectile(key, start, end, float(spec.get("duration", 500)), no_offset, ap, a)


## A still animation at `pos`, freed when done ("grow": scale tween over `duration`).
## `angle`: screen angle toward the target for oriented specs (the spec rotation is added).
func _anim(key: String, pos: Vector3, spec: Dictionary, ap: float, angle := 0.0) -> Node3D:
	var rot := angle + float(spec.get("rotation", 0.0))
	var holder := _sprite(key, pos + _screen_offset(spec.get("offset", [0, 0])), spec, ap, rot,
		spec.has("grow"))
	if holder != null and spec.has("grow"):
		var d := float(spec.get("duration", 500)) / 1000.0 / speed
		var t := holder.create_tween().set_parallel()
		_add_growth(t, holder, spec, ap, d)
		t.chain().tween_callback(holder.queue_free)
	return holder


## A sprite flying from `from` to `to` in `duration_ms` (yoyo: and back), then `hit`.
## `rot`: final screen rotation of the sprite.
func _projectile(key: String, from: Vector3, to: Vector3, duration_ms: float, spec: Dictionary, ap: float,
		rot: float) -> void:
	var holder := _sprite(key, from, spec, ap, rot, true)
	if holder == null:
		return
	var d := maxf(duration_ms, 1.0) / 1000.0 / speed
	var t := holder.create_tween()
	t.tween_property(holder, "global_position", to, d)
	if spec.get("yoyo", false):
		t.tween_property(holder, "global_position", from, d)
	if spec.has("grow") or spec.has("alpha_to"):
		var g := holder.create_tween().set_parallel()
		_add_growth(g, holder, spec, ap, d)
	t.tween_callback(func() -> void:
		holder.queue_free()
		var hit_spec = spec.get("hit")
		if hit_spec is Dictionary:
			var hit_key := "%s/%s" % [hit_spec.get("pack", "abilities"), hit_spec.get("anim", key.get_slice("/", 1))]
			var a := _screen_angle(from, to) if hit_spec.get("oriented", false) else 0.0
			_anim(hit_key, to, hit_spec, ap, a))


## A board cell of a spec: [x, y] where x (or y) "target" is the target's column (row) and
## "caster" the caster's, numbers are board cells (beyond the board for the edges).
func _spec_cell(c: Array, ctx: Dictionary) -> Vector3:
	var pick := func(v, i: int) -> int:
		if v is String:
			var cell: Vector2i = ctx.to_cell if v == "target" else ctx.from_cell
			return cell[i]
		return int(v)
	var x: int = pick.call(c[0], 0)
	var y: int = pick.call(c[1], 1)
	var base := arena.cell_to_world(Vector2i(clampi(x, 0, BattleBoard.WIDTH - 1), clampi(y, 0, BattleBoard.HEIGHT - 1)))
	# cells outside the board: on the same line, further
	base += Vector3(float(x - clampi(x, 0, BattleBoard.WIDTH - 1)), 0.0,
		-float(y - clampi(y, 0, BattleBoard.HEIGHT - 1)) * BattleBoard.ROW_STEP) * arena.cell_size
	return base + Vector3.UP * 0.45 * arena.cell_size


## Random screen offset of up to `jitter` web px (Arm Thrust, Hyperspace Fury hits).
func _jitter(spec: Dictionary) -> Vector3:
	var j := float(spec.get("jitter", 0.0))
	return _screen_offset([randf_range(-j, j), randf_range(-j, j)]) if j > 0.0 else Vector3.ZERO


## hiddenPowerAnimation: 8 rings of the Unowns of the word fly out spinning from the caster and fade.
func _unowns(centre: Vector3, spec: Dictionary) -> void:
	var letters: Array = spec.get("letters", [])
	var sprites: Array[AnimatedSprite3D] = []
	for _n in 8:
		for letter in letters:
			var entry := SpriteLibrary.get_entry(String(GameData.get_pokemon(String(letter)).get("index", "0000")))
			var s := AnimatedSprite3D.new()
			s.sprite_frames = entry.frames
			s.pixel_size = _px()
			s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			s.shaded = false
			s.no_depth_test = true
			s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
			s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			s.render_priority = 4
			add_child(s)
			s.global_position = centre
			if s.sprite_frames.has_animation("Idle_0"):
				s.play("Idle_0")
			sprites.append(s)
	if sprites.is_empty():
		return
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	var px := _px()
	var d := float(spec.get("duration", 2500)) / 1000.0
	var t := sprites[0].create_tween()
	t.tween_method(func(k: float) -> void:
		var eased := 1.0 - pow(1.0 - k, 4.0)
		var r := lerpf(10.0, 500.0, eased) * px
		var spin := -1.2 * k * (1.0 - k * 0.5)
		for i in sprites.size():
			if is_instance_valid(sprites[i]):
				var a := TAU * i / sprites.size() + spin
				sprites[i].global_position = centre + (right * cos(a) + up * sin(a)) * r
				sprites[i].modulate.a = clampf((1.0 - k) * 5.0, 0.0, 1.0),
		0.0, 1.0, d / speed)
	t.tween_callback(func() -> void:
		for s in sprites:
			if is_instance_valid(s):
				s.queue_free())


## `count` sprites turning around `centre` while the circle grows (Dark Harvest, Twister...).
func _orbit(key: String, centre: Vector3, spec: Dictionary, ap: float) -> void:
	var holders: Array[Node3D] = []
	var count := int(spec.get("count", 1))
	for i in count:
		var h := _sprite(key, centre, spec, ap, 0.0, true)
		if h != null:
			holders.append(h)
	if holders.is_empty():
		return
	var d := float(spec.get("duration", 1000)) / 1000.0
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	var px := _px()
	var t := holders[0].create_tween()
	t.tween_method(func(k: float) -> void:
		var eased := 1.0 - pow(1.0 - k, 4.0)
		var r := lerpf(48.0, 96.0, eased) * px
		for i in holders.size():
			if is_instance_valid(holders[i]):
				var a := TAU * i / holders.size() + k * d * ORBIT_SPEED
				holders[i].global_position = centre + (right * cos(a) + up * sin(a)) * r,
		0.0, 1.0, d / speed)
	t.tween_callback(func() -> void:
		for h in holders:
			if is_instance_valid(h):
				h.queue_free())


func _add_growth(t: Tween, holder: Node3D, spec: Dictionary, ap: float, d: float) -> void:
	var sprite: AnimatedSprite3D = holder.get_child(0)
	if spec.has("grow"):
		var g := float(spec.grow) * (1.0 + ap / 200.0)
		t.tween_property(sprite, "scale", Vector3(g, g, 1.0), d)
	if spec.has("alpha_to"):
		t.tween_property(sprite, "modulate:a", float(spec.alpha_to), d)
#endregion


#region sprites
## Holder (position + screen-plane rotation) with the animated sprite as child 0.
## `persistent`: the animation loops until the holder is freed by its tween.
func _sprite(key: String, pos: Vector3, spec: Dictionary, ap: float, rotation_rad: float,
		persistent := false) -> Node3D:
	var sf := VfxLibrary.frames(key)
	if sf == null or camera == null:
		return null
	var meta := VfxLibrary.info(key)
	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = pos
	holder.global_basis = camera.global_basis * Basis(Vector3.BACK, -rotation_rad)
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = sf
	sprite.pixel_size = _px()
	sprite.shaded = false
	sprite.double_sided = true
	sprite.no_depth_test = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.render_priority = 1 if spec.get("below", false) else 4
	var origin: Array = spec.get("origin", [0.5, 0.5])
	sprite.offset = Vector2((0.5 - float(origin[0])) * float(meta.w), (float(origin[1]) - 0.5) * float(meta.h))
	var sc := _scale_of(spec, ap)
	sprite.scale = Vector3(sc.x, sc.y, 1.0)
	var color := Color(String(spec.get("tint", "#ffffff")))
	color.a = float(spec.get("alpha", 1.0))
	sprite.modulate = color
	var fps := float(meta.get("fps", 20))
	sprite.speed_scale = speed * (float(spec.fps) / fps if spec.has("fps") else 1.0)
	holder.add_child(sprite)
	var loops := [int(spec.get("repeat", meta.get("repeat", 0)))]
	sprite.animation_finished.connect(func() -> void:
		if persistent or loops[0] > 0:
			loops[0] -= 1
			sprite.frame = 0
			sprite.play("default")
		else:
			holder.queue_free())
	sprite.play("default")
	if not persistent and loops[0] < 0:
		# looping animation shown as a one-shot: keep it one second
		holder.create_tween().tween_callback(holder.queue_free).set_delay(1.0 / speed)
	return holder


func _scale_of(spec: Dictionary, ap: float) -> Vector2:
	var s = spec.get("scale", 2.0)
	var v := Vector2(float(s[0]), float(s[1])) if s is Array else Vector2(float(s), float(s))
	return v * (1.0 + ap / 200.0)


## World size of one web pixel.
func _px() -> float:
	return (arena.cell_size if arena != null else 1.0) / WEB_CELL * size_scale


## Web pixel offset (x right, y down on screen) -> world vector in the screen plane.
func _screen_offset(px: Array) -> Vector3:
	if camera == null or px.size() < 2:
		return Vector3.ZERO
	return (camera.global_basis.x * float(px[0]) - camera.global_basis.y * float(px[1])) * _px()


## Screen angle from a to b (y down, clockwise), like the web angleBetween on screen coordinates.
func _screen_angle(a: Vector3, b: Vector3) -> float:
	if camera == null:
		return 0.0
	var pa := camera.unproject_position(a)
	var pb := camera.unproject_position(b)
	return 0.0 if pa.distance_to(pb) < 0.5 else atan2(pb.y - pa.y, pb.x - pa.x)


func _body(u: BattleUnit) -> Vector3:
	if body_of.is_valid():
		var p = body_of.call(u)
		if p is Vector3:
			return p
	return _cell_body(u.cell)


func _cell_body(cell: Vector2i) -> Vector3:
	return arena.cell_to_world(cell) + Vector3.UP * 0.45 * arena.cell_size


func _row_centre(y: int) -> Vector3:
	return (_cell_body(Vector2i(0, y)) + _cell_body(Vector2i(BattleBoard.WIDTH - 1, y))) * 0.5


## Calls `f` after `ms` of fight time (now when 0), unless clear() was called meanwhile.
func _later(ms: float, f: Callable) -> void:
	if ms <= 0.0:
		f.call()
		return
	var generation := _generation
	get_tree().create_timer(ms / 1000.0 / speed, false).timeout.connect(func() -> void:
		if generation == _generation:
			f.call())
#endregion
