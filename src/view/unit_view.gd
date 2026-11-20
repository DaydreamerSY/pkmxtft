class_name UnitView
extends Node3D

## A Pokémon on the arena: a 2D PMD sprite standing on the 3D floor.
##
## The node origin is the ground point = centre of the cell the Pokémon occupies.
## The sprite is a camera-facing billboard whose feet (the PMD shadow point) sit
## on that origin; a blob shadow (+ optional team ring) is painted on the cell.
## Sprites are drawn without depth test and sorted back-to-front, so a sprite
## is never cut by the floor and nearer Pokémon always cover farther ones.

signal action_finished(action: String)

const PIXELS_PER_CELL := 48.0 ## PAC scale: a 96 px cell shows sprites at x2
const BLUE_RING := Color(0.35, 0.65, 1.0, 0.75)
const RED_RING := Color(1.0, 0.35, 0.3, 0.75)
## A one-shot animation or a walk that ends holds its last frame this long (real seconds) before Idle: the next
## attack or step, due right then (the sim runs in physics frames), goes on from it instead of showing one Idle
## frame and starting over.
const IDLE_GRACE := 0.1

## Motion drawn every frame over the PMD frames (_animate_body), so the few frames of a PMD action (an Idle
## shows ~3 a second) still move smoothly. Distances are in cells, times in fight seconds (time_scale).
const BREATH := 0.025 ## at rest the sprite breathes: its height changes by this much (x and y in opposition)
const BREATH_PERIOD := 1.9
const WALK_BOB := 0.06 ## walking: a little hop every half cell, this high
const LUNGE := 0.18 ## a melee attacker lunges this far at its foe, farthest when the hit lands
const LUNGE_W := 13.0 ## its spring (rad/s): farthest 1 / LUNGE_W s after the push, back in ~0.35 s
const SHOT_KICK := 0.06 ## a ranged attacker steps back this much as it shoots
const HIT_PUSH := 0.06 ## a hit pushes the unit away from its attacker (x1.6 on a critical hit)...
const HIT_SQUASH := 0.08 ## ...and squashes it (wider, shorter)
const HIT_W := 24.0
const SQUASH_W := 20.0
const LAND_SQUASH := 0.1 ## landing from a dash / knockback
const HOP_STRETCH := 0.07 ## stretched up while in the air
const POP_TIME := 0.32 ## appearing (bought, evolved, summoned): grows in with an overshoot
const DIE_TIME := 0.45

## Speed of every sprite animation: Game sets the fight speed (x1 / x2 / x4) while a fight runs.
static var time_scale := 1.0
## Sprites sampled "sharp bilinear" (shaders/sprite_pixel_aa.gdshader): crisp texels without the shimmer of
## NEAREST at an odd zoom when they move. false: the plain SpriteBase3D material (screenshot "pixels=nearest").
static var smooth_pixels := true

var pkm := ""
var team := BattleUnit.Team.BLUE
var entry: SpriteLibrary.Entry
var sprite: AnimatedSprite3D
var decal: MeshInstance3D
var decal_mat: ShaderMaterial
var direction := 0
var current_action := "Idle"
var pixel_size := 1.0 / PIXELS_PER_CELL
var owned_id := -1 ## PlayerState.OwnedUnit id (pick phase)
var battle_unit: BattleUnit ## during a fight
var items: Array = [] ## held items shown above the bars (outside fights)
## Copies standing in its bench slot (PlayerState.bench_stack): drawn as "x2" next to its stars.
var stack_count := 1
var dragging := false
var shiny := false ## Shiny colors (a shiny PvE stage: Celebi, shinyChance)

var _sprite_mat: ShaderMaterial ## smooth_pixels: the material_override of the sprite
var _move_tween: Tween
var _move_kind := ""
var _flash_tween: Tween
var _one_shot := false
var _action_speed := 1.0 ## speed of the current action (attack: its length fits the attack cooldown)
var _clock := 0.0 ## real seconds this view has been processed
var _idle_at := -1.0 ## _clock when the held end of a one-shot / walk turns to Idle (-1: none)
var _hop_from := Vector3.ZERO
var _hop_to := Vector3.ZERO
var _status_sprites: Dictionary = {} ## status -> AnimatedSprite3D
# _animate_body: springs (offset of the sprite from its node, squash), pushes due later, effects running
var _cell := 1.0 ## world size of a cell
var _body_clock := 0.0 ## fight seconds (time_scale) this view has been processed
var _kicks: Array = [] ## [due _body_clock, 0 = lunge / 1 = hit spring, velocity Vector3, squash velocity]
var _lunge_x := Vector3.ZERO
var _lunge_v := Vector3.ZERO
var _hit_x := Vector3.ZERO
var _hit_v := Vector3.ZERO
var _squash := 0.0
var _squash_v := 0.0
var _breath := 0.0 ## 0..1: how much the breathing shows (only at rest)
var _breath_phase := 0.0
var _breath_period := BREATH_PERIOD
var _bob := 0.0 ## 0..1: how much the walking hops show
var _walk_phase := 0.0
var _last_pos := Vector3.ZERO
var _hop_stretch := 0.0
var _pop_start := -1.0
var _die_start := -1.0


func setup(pkm_name: String, unit_team: int, cell_size: float, sprite_scale: float,
		billboard: BaseMaterial3D.BillboardMode) -> void:
	pkm = pkm_name
	team = unit_team
	name = "%s_%d" % [pkm_name, get_instance_id()]
	var data := GameData.get_pokemon(pkm_name)
	entry = SpriteLibrary.get_entry(data.get("index", "0000"))
	pixel_size = cell_size / PIXELS_PER_CELL * sprite_scale
	_cell = cell_size
	# every unit breathes at its own pace (not from the game's random numbers: a seeded run stays the same)
	var mix := fposmod(float(get_instance_id()) * 0.6180339887, 1.0)
	_breath_phase = mix * TAU
	_breath_period = BREATH_PERIOD * (0.88 + 0.24 * fposmod(mix * 7.0, 1.0))

	decal = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(cell_size, cell_size) * 0.95
	quad.orientation = PlaneMesh.FACE_Y
	decal.mesh = quad
	decal_mat = ShaderMaterial.new()
	decal_mat.shader = preload("res://src/view/shaders/ground_decal.gdshader")
	decal.material_override = decal_mat
	decal.position.y = 0.004
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(decal)

	sprite = AnimatedSprite3D.new()
	sprite.sprite_frames = entry.frames
	sprite.pixel_size = pixel_size
	sprite.billboard = billboard
	sprite.shaded = false
	sprite.double_sided = true
	sprite.no_depth_test = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.render_priority = 2
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.animation_looped.connect(_on_animation_finished) # a one-shot action drawn with a looping animation
	if smooth_pixels:
		_sprite_mat = ShaderMaterial.new()
		_sprite_mat.shader = preload("res://src/view/shaders/sprite_pixel_aa.gdshader")
		_sprite_mat.set_shader_parameter("billboard_mode", int(billboard))
		_sprite_mat.render_priority = sprite.render_priority
		sprite.material_override = _sprite_mat
		_sync_sheet()
	add_child(sprite)
	play("Idle")


## The sheet of the sprite for the smooth_pixels material (SpriteBase3D only gives it to its own material).
func _sync_sheet() -> void:
	if _sprite_mat != null:
		_sprite_mat.set_shader_parameter("texture_albedo", entry.texture)


## Another form of the same Pokémon (Aegislash Blade, Darmanitan Zen...): new sprite.
func transform(pkm_name: String) -> void:
	if pkm_name == pkm:
		return
	pkm = pkm_name
	entry = SpriteLibrary.get_entry(GameData.get_pokemon(pkm_name).get("index", "0000"), shiny)
	sprite.sprite_frames = entry.frames
	_sync_sheet()
	play(current_action, _one_shot, _action_speed)


## Shiny colors on / off.
func set_shiny(on: bool) -> void:
	if on == shiny:
		return
	shiny = on
	entry = SpriteLibrary.get_entry(GameData.get_pokemon(pkm).get("index", "0000"), shiny)
	sprite.sprite_frames = entry.frames
	_sync_sheet()
	play(current_action, _one_shot, _action_speed)


func _process(delta: float) -> void:
	if sprite == null:
		return
	_clock += delta
	sprite.speed_scale = _action_speed * time_scale
	if _idle_at >= 0.0 and _clock >= _idle_at:
		var done := current_action if _one_shot else ""
		play("Walk" if _walking() else "Idle")
		if done != "":
			action_finished.emit(done)
	_animate_body(delta)


#region body motion
## The motion of the sprite drawn every frame on top of its PMD frames: breathing at rest, a hop every half
## cell while walking, the lunge of a melee attack (farthest when its hit lands), the push and squash of a hit,
## the stretch of a dash and the squash of its landing, growing in when it appears, sinking when it faints.
## Only the sprite (and its shadow, sideways) moves: the node stays on the cell of the sim, the HP bar with it.
func _animate_body(delta: float) -> void:
	var dt := delta * time_scale
	_body_clock += dt
	var i := 0
	while i < _kicks.size():
		var k: Array = _kicks[i]
		if float(k[0]) > _body_clock:
			i += 1
			continue
		if int(k[1]) == 0:
			_lunge_v += k[2]
		else:
			_hit_v += k[2]
		_squash_v += float(k[3])
		_kicks.remove_at(i)
	var s := _spring3(_lunge_x, _lunge_v, LUNGE_W, dt)
	_lunge_x = s[0]
	_lunge_v = s[1]
	s = _spring3(_hit_x, _hit_v, HIT_W, dt)
	_hit_x = s[0]
	_hit_v = s[1]
	var q := _spring1(_squash, _squash_v, SQUASH_W, dt)
	_squash = q.x
	_squash_v = q.y
	var squash := clampf(_squash, -0.3, 0.3)
	var sx := 1.0 + squash
	var sy := 1.0 - squash
	var ground := _lunge_x + _hit_x # on the board (lunge, push): the shadow follows it
	var offset := ground
	var up := sprite_up()
	# breathing at rest (fades in / out over a third of a second)
	var resting := current_action == "Idle" and not dragging and not _walking() and _die_start < 0.0
	_breath = move_toward(_breath, 1.0 if resting else 0.0, delta * 3.0)
	if _breath > 0.0:
		var b := sin(_body_clock * TAU / _breath_period + _breath_phase) * BREATH * _breath
		sy += b
		sx -= b * 0.5
	# walking: a hop every half cell walked
	var walking := _walking() and current_action == "Walk"
	if walking:
		_walk_phase += position.distance_to(_last_pos) / (_cell * 0.5) * PI
	_last_pos = position
	_bob = move_toward(_bob, 1.0 if walking else 0.0, delta * 8.0)
	if _bob > 0.0:
		offset += up * absf(sin(_walk_phase)) * WALK_BOB * _cell * _bob
	# in the air (dash / knockback)
	sy += _hop_stretch
	sx -= _hop_stretch * 0.5
	if _pop_start >= 0.0:
		var u := (_body_clock - _pop_start) / POP_TIME
		if u >= 1.0:
			_pop_start = -1.0
		else:
			var grow := lerpf(0.3, 1.0, _back_out(maxf(u, 0.0)))
			sx *= grow
			sy *= grow
	if _die_start >= 0.0:
		var k := clampf((_body_clock - _die_start) / DIE_TIME, 0.0, 1.0)
		sy *= 1.0 - 0.3 * k * k
		sx *= 1.0 + 0.12 * k
	sprite.position = offset
	sprite.scale = Vector3(sx, sy, 1.0)
	decal.position.x = ground.x # the shadow follows on the ground, not up (step hops)
	decal.position.z = ground.z


## Pushes the lunge (0) or hit (1) spring of the sprite `delay` fight seconds from now: `peak` is the offset (and
## `squash` the squash) at its farthest, 1 / omega s after the push (critically damped spring).
func _kick(delay: float, spring: int, peak: Vector3, squash := 0.0) -> void:
	var omega := LUNGE_W if spring == 0 else HIT_W
	_kicks.append([_body_clock + maxf(delay, 0.0), spring, peak * omega * exp(1.0), squash * SQUASH_W * exp(1.0)])


## One step of a critically damped spring pulled to 0, exact (stable at any frame time and fight speed):
## x(t) = (x0 + (v0 + w x0) t) e^-wt. Returns [x, v].
static func _spring3(x: Vector3, v: Vector3, omega: float, dt: float) -> Array:
	var e := exp(-omega * dt)
	var a := v + x * omega
	return [(x + a * dt) * e, (v - a * (omega * dt)) * e]


static func _spring1(x: float, v: float, omega: float, dt: float) -> Vector2:
	var e := exp(-omega * dt)
	var a := v + x * omega
	return Vector2((x + a * dt) * e, (v - a * omega * dt) * e)


static func _back_out(u: float) -> float:
	var c := 1.70158
	var t := u - 1.0
	return 1.0 + (c + 1.0) * t * t * t + c * t * t


## The direction from this unit to a ground point, flat on the board (ZERO when it is on this cell).
func _toward(point: Vector3) -> Vector3:
	var d := point - global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.001 else Vector3.ZERO


## Grows in (bought, evolved, summoned).
func pop_in() -> void:
	_pop_start = _body_clock


## Hit: pushed away from `from` (the ground point of the attacker of a hit; null: no push, e.g. a burn tick)
## and squashed, more on a critical hit, less when `light` (damage over time).
func hit_react(from: Variant, crit := false, light := false) -> void:
	var strength := (1.6 if crit else 1.0) * (0.5 if light else 1.0)
	var away := -_toward(from) if from is Vector3 else Vector3.ZERO
	_kick(0.0, 1, away * HIT_PUSH * _cell * strength, HIT_SQUASH * strength)
#endregion


#region animation
## Plays an action ("Idle", "Walk", "Attack", ...) in the current direction, `speed` times its own pace
## (and time_scale). One-shot actions go back to Idle when done.
func play(action: String, one_shot := false, speed := 1.0) -> void:
	if not entry.has_action(action):
		action = "Idle" if entry.has_action("Idle") else (entry.actions.keys().front() if not entry.actions.is_empty() else "")
		if action == "":
			return
	current_action = action
	_one_shot = one_shot
	_action_speed = speed
	_idle_at = -1.0
	var feet: Vector2 = entry.feet.get(action, Vector2.ZERO)
	sprite.offset = Vector2(-feet.x, feet.y)
	var anim := entry.anim_name(action, direction)
	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
		if one_shot:
			sprite.frame = 0
	sprite.speed_scale = _action_speed * time_scale


## A basic attack (web animatePokemon(ATTACK) with getAttackAnimTimeScale): the attack animation is stretched
## to the whole attack cooldown, so its hit frame shows when the sim deals the damage (BattleSim._basic_attack:
## hit_delay = cooldown x d / t of delays.json, t = the length of this animation) and it ends when the next
## attack starts it again. With the ground point of its `target` and the sim's `hit_delay_ms`, a melee attacker
## lunges at it (farthest when the hit lands), a ranged one steps back as its projectile leaves (VfxPlayer.attack:
## the flight takes min(250 ms, hit_delay) and lands with the hit).
func attack(action: String, cooldown_ms: float, hit_delay_ms := -1.0, target: Variant = null, ranged := false) -> void:
	var ticks := float(entry.ticks.get(action, 0.0))
	var speed := 1.0
	if ticks > 0.0 and cooldown_ms > 0.0:
		speed = ticks / SpriteLibrary.FPS / (cooldown_ms / 1000.0)
	play(action, true, speed)
	if target is Vector3 and hit_delay_ms >= 0.0:
		var dir := _toward(target)
		if ranged:
			_kick((hit_delay_ms - minf(250.0, hit_delay_ms)) / 1000.0, 0, -dir * SHOT_KICK * _cell)
		else:
			_kick(hit_delay_ms / 1000.0 - 1.0 / LUNGE_W, 0, dir * LUNGE * _cell)


## Faces a board direction (BattleBoard.DIRECTIONS vector).
func face(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	_turn_to(BattleBoard.direction_index(dir))


## Faces another cell at the real angle (8 sprite directions; the board has 6).
func face_toward(from: Vector2i, to: Vector2i) -> void:
	if from != to:
		_turn_to(BattleBoard.sprite_direction_between(from, to))


func _turn_to(d: int) -> void:
	if d == direction:
		return
	direction = d
	var anim := entry.anim_name(current_action, direction)
	if sprite.sprite_frames.has_animation(anim):
		var frame := sprite.frame
		var progress := sprite.frame_progress
		sprite.play(anim)
		sprite.set_frame_and_progress(mini(frame, sprite.sprite_frames.get_frame_count(anim) - 1), progress)


func set_direction_index(d: int) -> void:
	direction = d
	play(current_action, _one_shot, _action_speed)


func _on_animation_finished() -> void:
	if _one_shot:
		_idle_at = _clock + IDLE_GRACE # the next attack may start it again right away


func _walking() -> bool:
	return _move_kind == "walk" and _move_tween != null and _move_tween.is_valid() and _move_tween.is_running()
#endregion


#region movement
## Slides to a ground position over `duration` seconds, walking ("walk") or with a quick hop (dash, knockback).
func move_to(world_pos: Vector3, duration: float, kind := "walk") -> void:
	var moving := _move_tween != null and _move_tween.is_valid() and _move_tween.is_running()
	if kind != "walk" and not moving and position.is_equal_approx(world_pos):
		return # already there (Game re-places every view of the player whenever its state changes): no hop
	if _move_tween:
		_move_tween.kill()
	_move_tween = create_tween()
	_move_kind = kind
	_hop_stretch = 0.0
	if kind == "walk":
		# an attack or a step that just ended (held, _idle_at) gives way to the walk
		if current_action == "Idle" or current_action == "Walk" or _idle_at >= 0.0:
			play("Walk")
		_move_tween.tween_property(self, "position", world_pos, duration)
		_move_tween.tween_callback(_end_walk)
	else:
		# dash / knockback: quick hop
		_hop_from = position
		_hop_to = world_pos
		_move_tween.tween_method(_hop, 0.0, 1.0, duration)
		_move_tween.tween_callback(_land)


func _hop(t: float) -> void:
	position = _hop_from.lerp(_hop_to, t) + Vector3.UP * sin(t * PI) * 0.35
	_hop_stretch = HOP_STRETCH * sin(t * PI)


func _land() -> void:
	_hop_stretch = 0.0
	_kick(0.0, 1, Vector3.ZERO, LAND_SQUASH)


func _end_walk() -> void:
	if current_action == "Walk":
		_idle_at = _clock + IDLE_GRACE # the next step, due now, keeps the walk cycle going


func snap_to(world_pos: Vector3) -> void:
	if _move_tween:
		_move_tween.kill()
	position = world_pos
	_last_pos = world_pos
	_hop_stretch = 0.0
#endregion


#region feedback
func flash_hit(color := Color(1.0, 0.45, 0.45)) -> void:
	if _flash_tween:
		_flash_tween.kill()
	sprite.modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.18)


func die() -> void:
	if _move_tween:
		_move_tween.kill()
	_hop_stretch = 0.0
	_die_start = _body_clock # sinks as it fades
	play("Hurt" if entry.has_action("Hurt") else "Idle")
	var t := create_tween()
	t.set_parallel()
	t.tween_property(sprite, "modulate:a", 0.0, 0.45)
	t.tween_property(decal, "transparency", 1.0, 0.45)
	t.chain().tween_callback(queue_free)


func set_ring(visible_ring: bool) -> void:
	var c := (BLUE_RING if team == BattleUnit.Team.BLUE else RED_RING) if visible_ring else Color(0, 0, 0, 0)
	decal_mat.set_shader_parameter("ring_color", c)


func set_dragging(on: bool) -> void:
	dragging = on
	sprite.render_priority = 5 if on else 2
	if _sprite_mat != null:
		_sprite_mat.render_priority = sprite.render_priority
	sprite.modulate.a = 0.85 if on else 1.0
	decal.visible = not on


func set_ghost(on: bool) -> void:
	sprite.modulate.a = 0.55 if on else 1.0


## Status animations above the Pokémon (web addBurn(), addFreeze()...), from the
## BattleUnit statuses {name: remaining ms}; {} removes them all.
func sync_statuses(statuses: Dictionary) -> void:
	for status in VfxLibrary.STATUS:
		var on: bool = float(statuses.get(status, 0.0)) > 0.0
		if on and not _status_sprites.has(status):
			var def: Array = VfxLibrary.STATUS[status]
			var sf := VfxLibrary.frames("status/" + String(def[0]))
			if sf == null:
				continue
			var s := AnimatedSprite3D.new()
			s.sprite_frames = sf
			# a web pixel is half a sprite pixel (the web draws Pokémon at x2)
			s.pixel_size = pixel_size * 0.5 * float(def[2])
			s.billboard = sprite.billboard
			s.shaded = false
			s.double_sided = true
			s.no_depth_test = true
			s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
			s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			s.render_priority = 3
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var feet: Vector2 = entry.feet.get("Idle", Vector2.ZERO)
			s.position = Vector3.UP * (maxf(feet.y, 8.0) - float(def[1]) * 0.5) * pixel_size
			add_child(s)
			s.play("default")
			_status_sprites[status] = s
		elif not on and _status_sprites.has(status):
			_status_sprites[status].queue_free()
			_status_sprites.erase(status)
#endregion


#region screen helpers
## Direction the sprite stands along: a billboard sprite faces the camera, so its top is along the
## camera's up axis, not the world's (the camera looks down at the board: a point straight above the
## feet shows at little more than half the height of the sprite).
func sprite_up() -> Vector3:
	if sprite != null and sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED and is_inside_tree():
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			return cam.global_transform.basis.y
	return Vector3.UP


## World position right above the head of the sprite as it is drawn (HP bar anchor). The exported height
## is the top of the tallest Idle frame of any direction: a few pixels above the head actually shown.
func head_position() -> Vector3:
	var feet: Vector2 = entry.feet.get("Idle", Vector2.ZERO)
	return global_position + sprite_up() * maxf(entry.height + feet.y - 3.0, 8.0) * pixel_size


## World position of the sprite frame centre: where the web game anchors effects.
func body_position() -> Vector3:
	var feet: Vector2 = entry.feet.get("Idle", Vector2.ZERO)
	return global_position + sprite_up() * maxf(feet.y, 8.0) * pixel_size


## Screen rectangle covered by the sprite (for mouse picking).
func screen_rect(camera: Camera3D) -> Rect2:
	var feet_screen := camera.unproject_position(global_position)
	var head_screen := camera.unproject_position(head_position())
	var h := maxf(feet_screen.y - head_screen.y, 24.0)
	var w := h * 0.8
	return Rect2(feet_screen.x - w * 0.5, head_screen.y, w, h + h * 0.12)
#endregion
