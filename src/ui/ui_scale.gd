class_name UiScale
extends RefCounted

## Size of the UI (not in the web game). The canvas is designed for 1920x1080; on a phone that makes
## every text about 1.2 mm high. The whole canvas is scaled up there (Window.content_scale_factor):
## Auto picks the factor from the physical height of the screen (about x1.65 on a 6.8" phone, x1 on
## a tablet or a desktop), the Options let the player choose another one (Settings.ui_scale).
## A scaled canvas is smaller in its own units (1080 / factor high): under COMPACT_HEIGHT the HUD
## uses its compact layout (Hud._layout) and the camera frames the board in the room left.
##
## Tests and screenshots: "ui_scale=<factor>" forces the factor, "touch" makes the game behave as on
## a touch screen, "insets=<left>,<right>" and "cutout=<x>,<y>,<w>,<h>" (canvas units) stand for the camera
## cutout of a phone (after "--" on the command line).

## The HUD is compact when the canvas is lower than this.
const COMPACT_HEIGHT := 840.0
## Auto: factor = AUTO_INCHES / height of the screen in inches (landscape).
const AUTO_INCHES := 4.67
const MIN_FACTOR := 0.75
const MAX_FACTOR := 2.2
## Choices of the Options, in percent (0 = Auto).
const CHOICES: Array[int] = [0, 100, 125, 150, 165, 180, 200]

## > 0: this factor whatever the setting.
static var forced := _forced_arg()
## Behave as on a touch screen (tap = details, no hover): the real ones, or "touch" in the arguments.
static var touch := _touch_arg()


static func _forced_arg() -> float:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("ui_scale="):
			return clampf(float(arg.substr(9)), MIN_FACTOR, MAX_FACTOR)
	return 0.0


static func _touch_arg() -> bool:
	return OS.get_cmdline_user_args().has("touch") or (DisplayServer.is_touchscreen_available() and OS.has_feature("mobile"))


## The factor Auto gives on this device.
static func auto_factor() -> float:
	if not OS.has_feature("mobile"):
		return 1.0
	var dpi := DisplayServer.screen_get_dpi()
	var size := DisplayServer.screen_get_size()
	var height := mini(size.x, size.y)
	if dpi <= 0 or height <= 0:
		return 1.6
	return clampf(snappedf(AUTO_INCHES * dpi / height, 0.05), 1.0, 2.0)


## Factor of a setting in percent (0 = Auto).
static func factor(percent: int) -> float:
	if forced > 0.0:
		return forced
	return auto_factor() if percent <= 0 else clampf(percent / 100.0, MIN_FACTOR, MAX_FACTOR)


static func apply(root: Window, percent: int) -> void:
	var f := factor(percent)
	if not is_equal_approx(root.content_scale_factor, f):
		root.content_scale_factor = f
	UiSkin.watch(root) # pixel-art frames: crisp at whole scales


## Tests and screenshots: left / right safe insets in canvas units (x < 0: the real ones of the device);
## "insets=<left>,<right>" in the arguments.
static var test_insets := _insets_arg()
## Tests and screenshots: the camera cutouts in canvas units (null: the real ones of the device);
## "cutout=<x>,<y>,<width>,<height>" in the arguments.
static var test_cutouts: Variant = _cutout_arg()

## A cutout this close (canvas units) to a horizontal band counts as reaching it.
const CUTOUT_PAD := 6.0


static func _insets_arg() -> Vector2:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("insets="):
			var parts := arg.substr(7).split(",")
			if parts.size() == 2:
				return Vector2(float(parts[0]), float(parts[1]))
	return Vector2(-1.0, -1.0)


static func _cutout_arg() -> Variant:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("cutout="):
			var parts := arg.substr(7).split(",")
			if parts.size() == 4:
				return [Rect2(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]))]
	return null


## Room to leave on the left and on the right of a canvas `canvas_width` wide, in canvas units: the strip
## of the screen where the camera cutout is (DisplayServer.get_display_safe_area). See band_insets():
## the cutout itself is only a hole in that strip.
static func safe_insets(canvas_width: float) -> Vector2:
	if test_insets.x >= 0.0:
		return test_insets
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if safe.size.x <= 0 or screen.x <= 0:
		return Vector2.ZERO
	var k := canvas_width / float(screen.x)
	return Vector2(clampf(safe.position.x * k, 0.0, 90.0), clampf((screen.x - safe.end.x) * k, 0.0, 90.0))


## The camera cutouts of the screen (punch hole, notch) in the units of a canvas `canvas` large
## (DisplayServer.get_display_cutouts); empty when the device does not tell where they are.
static func cutouts(canvas: Vector2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if test_cutouts != null:
		out.assign(test_cutouts)
		return out
	if not OS.has_feature("mobile"):
		return out
	var screen := DisplayServer.screen_get_size()
	if screen.x <= 0 or screen.y <= 0:
		return out
	var k := Vector2(canvas.x / float(screen.x), canvas.y / float(screen.y))
	for r in DisplayServer.get_display_cutouts():
		var rect := Rect2(r)
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			out.append(Rect2(rect.position * k, rect.size * k))
	return out


## What a camera cutout hides on the left and on the right of the horizontal band y0..y1 of a canvas
## (canvas units): the safe inset of the side where a cutout reaches the band, nothing where none does.
## A punch hole sits at mid height: the rows at the top and at the bottom of the screen can use the whole
## width. A device that does not tell where its cutouts are: the safe inset on the whole height.
static func band_insets(canvas: Vector2, y0: float, y1: float) -> Vector2:
	var strip := safe_insets(canvas.x)
	if strip.x <= 0.0 and strip.y <= 0.0:
		return Vector2.ZERO
	var holes := cutouts(canvas)
	if holes.is_empty():
		return strip
	var out := Vector2.ZERO
	for hole in holes:
		# a cutout lies in the strip the safe area leaves for it; rectangles that do not (other axes, another
		# orientation) cannot be trusted: the whole strip then
		var in_left := strip.x > 0.0 and hole.end.x <= strip.x + CUTOUT_PAD
		var in_right := strip.y > 0.0 and hole.position.x >= canvas.x - strip.y - CUTOUT_PAD
		if not in_left and not in_right:
			return strip
		if hole.end.y < y0 - CUTOUT_PAD or hole.position.y > y1 + CUTOUT_PAD:
			continue
		if in_left:
			out.x = strip.x
		if in_right:
			out.y = strip.y
	return out


## The canvas of `control` is low: compact layouts.
static func is_compact(control: CanvasItem) -> bool:
	return control.get_viewport_rect().size.y < COMPACT_HEIGHT


## Shrinks `control` (never enlarges it) so that it fits `max_size`, around `pivot` (0..1 of its size):
## the safety net of the panels that are too tall or too wide for a small canvas.
## A container resets the scale of its children: for a panel inside a CenterContainer, pass that
## container as `scaled` (it is scaled around its centre, where the panel is).
static func fit(control: Control, max_size: Vector2, pivot := Vector2(0.5, 0.5), scaled: Control = null) -> void:
	var size := control.size
	var k := 1.0
	if size.x > 0.0 and size.y > 0.0:
		k = minf(1.0, minf(max_size.x / size.x, max_size.y / size.y))
	var target := scaled if scaled != null else control
	target.pivot_offset = target.size * pivot
	target.scale = Vector2(k, k)
