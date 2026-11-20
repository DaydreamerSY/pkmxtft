class_name HoverTip
extends Control
## Tooltips of the HUD, placed next to the hovered element like in TFT (not at the
## mouse). Levels stack: a tooltip can hold elements with their own tooltip
## (synergy -> Pokémon of the synergy, recipes -> full item).
##   HoverTip.add(control, builder, side)  builder() returns the content (or null)
##   show_tip(owner, content, side, level, interactive, pinned)
## A level closes when the mouse leaves its owner (and its panel if interactive),
## unless it is pinned (right click recipes): pinned ones close on a click
## outside, Esc, or a second right click on the owner (toggle()).
## Interactive tooltips can be reached with the mouse: the gap between the owner and
## the panel counts as inside, they close only after CLOSE_DELAY outside, and another
## owner of the same level waits SWITCH_DELAY before replacing them (the mouse may
## only be passing over it on its way to the panel).
## The frame is a PanelContainer with the theme type variation TipPanel (TipPanelPinned).
## Lives in scenes/ui/hud.tscn (node Tips); the scenes reach it with HoverTip.current.

enum Side { RIGHT, LEFT, TOP, BOTTOM }

const GAP := 6.0
const MARGIN := 8.0
## Seconds an interactive tooltip stays open with the mouse outside it and its owner.
const CLOSE_DELAY := 0.35
## Seconds the mouse must stay on another owner before it replaces an open interactive tooltip.
const SWITCH_DELAY := 0.05

## The HUD's tooltip layer (null outside a game, e.g. in the main menu).
static var current: HoverTip

## No new tooltip while true (the game sets it while a Pokémon or an item is dragged).
var suspended := false:
	set(value):
		suspended = value
		if value:
			close_all()
var _levels: Array = [] ## {owner, panel, side, interactive, pinned, frames, outside, corridor}
## Everything attach() knows: {owner: WeakRef, builder, side, level, interactive}. Touch screens have no
## hover: a tap finds the element under the finger here.
var _attached: Array = []
## A tooltip waiting to replace an interactive one: {owner, builder, side, level, interactive, time}.
var _pending: Dictionary = { }
var _mouse := Vector2(-1e6, -1e6) ## last mouse position seen by _input (canvas coordinates)


## Shows `builder.call()` next to `owner` while it is hovered (no-op without a HUD).
static func add(owner: Control, builder: Callable, side := Side.RIGHT, level := 0, interactive := false) -> void:
	if current != null:
		current.attach(owner, builder, side, level, interactive)


## The space the mouse crosses between an owner and its tooltip: the gap between the two rects
## where they face each other (the owner's span when they do not), a little wider.
static func _corridor(a: Rect2, b: Rect2) -> Rect2:
	var r := Rect2()
	if b.position.x >= a.end.x or a.position.x >= b.end.x: # side by side
		var x0 := minf(a.end.x, b.end.x)
		var x1 := maxf(a.position.x, b.position.x)
		var y0 := maxf(a.position.y, b.position.y)
		var y1 := minf(a.end.y, b.end.y)
		if y1 <= y0:
			y0 = a.position.y
			y1 = a.end.y
		r = Rect2(x0, y0, x1 - x0, y1 - y0)
	elif b.position.y >= a.end.y or a.position.y >= b.end.y: # one above the other
		var y0 := minf(a.end.y, b.end.y)
		var y1 := maxf(a.position.y, b.position.y)
		var x0 := maxf(a.position.x, b.position.x)
		var x1 := minf(a.end.x, b.end.x)
		if x1 <= x0:
			x0 = a.position.x
			x1 = a.end.x
		r = Rect2(x0, y0, x1 - x0, y1 - y0)
	return r.grow(3.0)


func _enter_tree() -> void:
	current = self


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mouse = get_global_mouse_position()


func _process(delta: float) -> void:
	var mouse := _mouse
	_update_pending(delta, mouse)
	# top level first: a level stays while the mouse is on a level above it
	var inside_above := false
	for i in range(_levels.size() - 1, -1, -1):
		if i >= _levels.size():
			continue
		var entry: Dictionary = _levels[i]
		var owner: Control = entry.owner
		if not is_instance_valid(owner) or not owner.is_visible_in_tree() or not is_instance_valid(entry.panel):
			close(i)
			inside_above = false
			continue
		var on_owner := owner.get_global_rect().has_point(mouse)
		var on_panel: bool = entry.panel.get_global_rect().has_point(mouse)
		var corridor: Rect2 = entry.get("corridor", Rect2())
		var inside: bool = inside_above or entry.pinned or on_owner \
				or (entry.interactive and (on_panel or corridor.has_point(mouse)))
		if inside:
			entry.outside = 0.0
		else:
			entry.outside = float(entry.get("outside", 0.0)) + delta
			if not entry.interactive or entry.outside >= CLOSE_DELAY:
				close(i)
				continue
		inside_above = inside_above or on_panel or on_owner
	for entry in _levels:
		_place(entry)


func _exit_tree() -> void:
	if current == self:
		current = null


## Pinned tooltips close on a click outside them.
func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_mouse = event.position
	if event is InputEventMouseButton and event.pressed and not _levels.is_empty():
		var pos: Vector2 = event.position
		for i in _levels.size():
			var entry: Dictionary = _levels[i]
			if not entry.pinned:
				continue
			var inside := false
			for j in range(i, _levels.size()):
				var e: Dictionary = _levels[j]
				if is_instance_valid(e.panel) and e.panel.get_global_rect().has_point(pos):
					inside = true
				if is_instance_valid(e.owner) and (e.owner as Control).get_global_rect().has_point(pos):
					inside = true
			if not inside:
				close(i)
				break
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not _levels.is_empty():
		close_all()
	if UiScale.touch and event is InputEventMouseButton and event.pressed and not suspended:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_touch(event.position, false)
		elif event.button_index == MOUSE_BUTTON_RIGHT: # a long press (TouchInput)
			_touch(event.position, true)


## Touch screens: a tap on an element shows its tooltip - except on a button, whose tap is its
## action: a long press (`hold`) shows the tooltip of a button too. The tooltip stays until a touch
## elsewhere (_process: the last touch is the "mouse").
func _touch(pos: Vector2, hold: bool) -> void:
	var best: Dictionary = {}
	var best_depth := -1
	for i in range(_attached.size() - 1, -1, -1):
		var entry: Dictionary = _attached[i]
		var owner: Control = entry.owner.get_ref()
		if owner == null:
			_attached.remove_at(i)
			continue
		if not owner.is_visible_in_tree() or not owner.get_global_rect().has_point(pos):
			continue
		var depth := 0
		var node: Node = owner
		while node != null:
			depth += 1
			node = node.get_parent()
		if depth > best_depth:
			best = entry
			best_depth = depth
	if best.is_empty():
		return
	var target: Control = best.owner.get_ref()
	if target is BaseButton and not hold:
		return
	# not through a popup covering it: the control really under the finger is it, or inside it
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null and hovered != target and not target.is_ancestor_of(hovered):
		return
	var level: int = best.level
	if _levels.size() > level and _levels[level].owner == target:
		return # already open
	_open(target, best.builder, best.side, level, best.interactive)


func attach(owner: Control, builder: Callable, side := Side.RIGHT, level := 0, interactive := false) -> void:
	if owner.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		owner.mouse_filter = Control.MOUSE_FILTER_PASS
	_attached.append({"owner": weakref(owner), "builder": builder, "side": side, "level": level, "interactive": interactive})
	owner.mouse_entered.connect(
		func() -> void:
			if UiScale.touch: # no hover on a touch screen: taps and long presses (_touch)
				return
			if suspended or not is_instance_valid(owner) or not owner.is_visible_in_tree():
				return
			if _pinned_on(owner, level):
				return
			if _levels.size() > level and _levels[level].owner == owner:
				_pending = { }
				return # back on the owner of the open tooltip (within CLOSE_DELAY): keep it
			if _levels.size() > level and _levels[level].interactive:
				# maybe only crossed on the way to the open tooltip: replace it if the mouse stays
				_pending = {
					"owner": owner,
					"builder": builder,
					"side": side,
					"level": level,
					"interactive": interactive,
					"time": SWITCH_DELAY,
				}
				return
			_open(owner, builder, side, level, interactive)
	)


func show_tip(
		owner: Control,
		content: Control,
		side := Side.RIGHT,
		level := 0,
		interactive := false,
		pinned := false,
		variation := &"TipPanel",
) -> PanelContainer:
	close(level)
	var panel := PanelContainer.new()
	panel.theme_type_variation = variation
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if interactive or pinned else Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	panel.modulate.a = 0.0 # shown once placed (its size is known after one layout pass)
	add_child(panel)
	_levels.append({ "owner": owner, "panel": panel, "side": side, "interactive": interactive, "pinned": pinned })
	return panel


## Right click on an element: opens its pinned tooltip, or closes it if already open.
func toggle(owner: Control, content: Control, side := Side.RIGHT, level := 0) -> void:
	if _pinned_on(owner, level):
		close(level)
		content.queue_free()
		return
	show_tip(owner, content, side, level, true, true, &"TipPanelPinned")


## Closes `level` and every level above it.
func close(level := 0) -> void:
	while _levels.size() > level:
		var entry: Dictionary = _levels.pop_back()
		if is_instance_valid(entry.panel):
			entry.panel.queue_free()


func close_all() -> void:
	_pending = { }
	close(0)


func has_open() -> bool:
	return not _levels.is_empty()


## True if the mouse is on an open tooltip panel.
func is_over_tip(pos: Vector2) -> bool:
	for entry in _levels:
		if is_instance_valid(entry.panel) and entry.panel.get_global_rect().has_point(pos):
			return true
	return false


func _open(owner: Control, builder: Callable, side: Variant, level: int, interactive: bool) -> void:
	_pending = { }
	var content: Control = builder.call()
	if content != null:
		show_tip(owner, content, side, level, interactive)


func _pinned_on(owner: Control, level: int) -> bool:
	return _levels.size() > level and _levels[level].owner == owner and _levels[level].pinned


## A tooltip waiting to replace an open interactive one: dropped when the mouse leaves its owner or
## reaches the open tooltip, shown once the mouse stayed SWITCH_DELAY on the owner (or the open one
## closed meanwhile).
func _update_pending(delta: float, mouse: Vector2) -> void:
	if _pending.is_empty():
		return
	var owner: Control = _pending.owner
	var level: int = _pending.level
	if suspended or not is_instance_valid(owner) or not owner.is_visible_in_tree() \
			or not owner.get_global_rect().has_point(mouse):
		_pending = { }
		return
	if _levels.size() > level and is_instance_valid(_levels[level].panel) \
			and (_levels[level].panel as Control).get_global_rect().has_point(mouse):
		_pending = { }
		return
	_pending.time = float(_pending.time) - delta
	if _pending.time <= 0.0 or _levels.size() <= level or not _levels[level].interactive:
		_open(owner, _pending.builder, _pending.side, level, _pending.interactive)


func _place(entry: Dictionary) -> void:
	var panel: PanelContainer = entry.panel
	var owner_rect: Rect2 = (entry.owner as Control).get_global_rect()
	panel.reset_size()
	var s := panel.size
	var view := get_viewport_rect().size
	# a tooltip larger than the canvas (small phones): shrunk to fit
	var k := minf(1.0, minf((view.x - 2.0 * MARGIN) / maxf(s.x, 1.0), (view.y - 2.0 * MARGIN) / maxf(s.y, 1.0)))
	panel.pivot_offset = Vector2.ZERO
	panel.scale = Vector2(k, k)
	s *= k
	var p := Vector2.ZERO
	match entry.side:
		Side.RIGHT:
			p = Vector2(owner_rect.end.x + GAP, owner_rect.position.y)
			if p.x + s.x > view.x - MARGIN:
				p.x = owner_rect.position.x - GAP - s.x
		Side.LEFT:
			p = Vector2(owner_rect.position.x - GAP - s.x, owner_rect.position.y)
			if p.x < MARGIN:
				p.x = owner_rect.end.x + GAP
		Side.TOP:
			p = Vector2(owner_rect.get_center().x - s.x * 0.5, owner_rect.position.y - GAP - s.y)
			if p.y < MARGIN:
				p.y = owner_rect.end.y + GAP
		Side.BOTTOM:
			p = Vector2(owner_rect.get_center().x - s.x * 0.5, owner_rect.end.y + GAP)
	p.x = clampf(p.x, MARGIN, maxf(MARGIN, view.x - s.x - MARGIN))
	p.y = clampf(p.y, MARGIN, maxf(MARGIN, view.y - s.y - MARGIN))
	panel.global_position = p
	entry.corridor = _corridor(owner_rect, Rect2(p, s))
	entry.frames = entry.get("frames", 0) + 1
	if entry.frames >= 2: # wrapped texts get their height after a layout pass
		panel.modulate.a = 1.0
