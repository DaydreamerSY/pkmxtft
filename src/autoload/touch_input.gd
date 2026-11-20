extends Node

## Autoload "TouchInput": touch screens (Android). Taps already act as left clicks (Godot's
## emulate_mouse_from_touch): buy, drag and drop, buttons; a tap on a Pokémon or an item shows its
## details (Game._is_tap), a tap on any other element with a tooltip shows it (HoverTip._touch).
## A long press (finger held
## LONG_PRESS seconds without moving) acts as a right click there: pinned tooltip of a HUD
## element, info panel of a Pokémon. The left press it started is cancelled first (released
## off screen: no button press, a dragged unit / item goes back to its place) and the real
## release is dropped. Inactive without a touch screen (desktop, headless tests).

const LONG_PRESS := 0.45
## Pixels the finger may move before the press is a drag instead.
const SLOP := 18.0
const OFF_SCREEN := Vector2(-10000, -10000)

var _active := false
var _pressed := false
var _start := Vector2.ZERO ## where the finger went down (window coordinates, for the fake clicks)
var _held := 0.0
## Left releases still to see after a long press: 2 = our off-screen one (passed on), then
## 1 = the real one when the finger lifts (dropped).
var _releases := 0


func _ready() -> void:
	_active = UiScale.touch
	set_process(false)
	set_process_input(_active)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			_pressed = true
			_releases = 0
			_held = 0.0
			# events reach _input in viewport coordinates, parse_input_event wants window ones
			_start = get_viewport().get_final_transform() * event.position
			set_process(true)
		else:
			_pressed = false
			set_process(false)
	elif event is InputEventScreenDrag and event.index == 0 and _pressed:
		if (get_viewport().get_final_transform() * event.position).distance_to(_start) > SLOP:
			_pressed = false
			set_process(false)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed \
			and _releases > 0:
		_releases -= 1
		if _releases == 0: # the real release of a long press: already cancelled
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _pressed:
		set_process(false)
		return
	_held += delta
	if _held < LONG_PRESS:
		return
	_pressed = false
	_releases = 2
	set_process(false)
	_click(MOUSE_BUTTON_LEFT, false, OFF_SCREEN)
	_click(MOUSE_BUTTON_RIGHT, true, _start)
	_click(MOUSE_BUTTON_RIGHT, false, _start)


func _click(button: MouseButton, pressed: bool, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)
