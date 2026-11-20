class_name Wanderers
extends Node3D

## Wandering Pokémon of the web game (public/src/game/components/wanderers-manager.ts,
## Player.spawnWanderingPokemon): sprites walking around the arena, clicked to be caught.
##   catchable  the Steel Pokémon attracted by Magnet Pull: walks in and watches beside the
##              board until clicked (it joins the bench if there is room)
##   outlaw     the Drowzee of the Wanted Notice: runs across once, faster; clicked = caught
##   dialog     Magnemite / Magnezone looking for the outlaw: only walk across
## The game queues them in PlayerState.wanderers ({pkm, kind, behavior, delay}); this node shows
## them and reports clicks (pick()).

const RUN_SPEED := 0.25 ## web DEFAULT_WANDERER_SPEED (screen px per ms, a whole screen in 4-6 s)
const OUTLAW_SPEED := 0.4

## Callable(pkm, team) -> UnitView (Game._make_view).
var make_view: Callable
var cell_size := 1.0
var _active: Array[Dictionary] = [] ## {data, view, tween}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## Starts a wanderer after its delay (seconds).
func spawn(data: Dictionary) -> void:
	var delay := float(data.get("delay", 0.0))
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(_show.bind(data))
	else:
		_show(data)


func _show(data: Dictionary) -> void:
	if not make_view.is_valid() or not GameData.pokemon.has(String(data.pkm)):
		return
	var v: UnitView = make_view.call(String(data.pkm), BattleUnit.Team.BLUE)
	v.set_ring(false)
	var from_left: bool = _rng.randf() < 0.5 or data.get("kind", "") == "dialog"
	var side := -1.0 if from_left else 1.0
	var start := Vector3(side * 7.0 * cell_size, 0.0, _rng.randf_range(-2.5, 2.5) * cell_size)
	var end := Vector3(-side * 7.0 * cell_size, 0.0, _rng.randf_range(-2.5, 2.5) * cell_size)
	var duration := 5.0
	if String(data.get("behavior", "")) == "spectate": # walks in and watches beside the board
		end = Vector3(side * 5.0 * cell_size, 0.0, _rng.randf_range(-1.5, 2.5) * cell_size)
		duration = 4.0
	elif String(data.get("kind", "")) == "outlaw":
		duration = 5.0 * RUN_SPEED / OUTLAW_SPEED
	v.snap_to(start)
	v.face(Vector2i(1 if from_left else -1, 0))
	var entry := {"data": data, "view": v}
	_active.append(entry)
	v.move_to(end, duration, "walk")
	if String(data.get("behavior", "")) != "spectate":
		get_tree().create_timer(duration).timeout.connect(_leave.bind(entry))


func _leave(entry: Dictionary) -> void:
	_active.erase(entry)
	var v: UnitView = entry.view
	if is_instance_valid(v):
		v.queue_free()


## The wanderer under the mouse ({} if none); it leaves when `take` is true.
func pick(pos: Vector2, camera: Camera3D, take := true) -> Dictionary:
	for i in range(_active.size() - 1, -1, -1):
		var entry: Dictionary = _active[i]
		var v: UnitView = entry.view
		if not is_instance_valid(v) or not v.screen_rect(camera).has_point(pos):
			continue
		if String(entry.data.get("kind", "")) == "dialog":
			return {}
		if take:
			_leave(entry)
		return entry.data
	return {}


## The catchable ones still watching (a new run, the game over).
func clear() -> void:
	for entry in _active.duplicate():
		_leave(entry)
