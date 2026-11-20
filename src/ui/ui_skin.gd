class_name UiSkin
extends RefCounted

## Pixel-art skin of the UI (2026-11-20): nine-patch images in assets/ui/skin, drawn by tools/ui/gen_skin.py after
## the style of LostSoulsDev's "V21.1 Essentials UI Redesign" (own drawing: no image of that repo is used). The
## theme (scenes/ui/theme/ui_theme.tres, written by tools/ui/gen_theme.py) uses them; `style()` builds the same
## kind of StyleBoxTexture for frames made in code.
## 1 texel = 1 canvas unit: at a whole scale of the canvas (x1 on a 1920x1080 window, x2 on the test phone) the
## images are drawn with NEAREST (crisp pixels), at other scales (x0.83 on a 1600x900 window) with LINEAR -
## `update_filter`, called by UiScale.apply and on every resize of the window.

const DIR := "res://assets/ui/skin/"
const THEME := "res://scenes/ui/theme/ui_theme.tres"
## How far from a whole number the canvas scale may be and still count as whole.
const WHOLE_SCALE := 0.01

static var _specs := {}
static var _textures := {} ## name -> CanvasTexture (filter switched with the theme's)
static var _filter := CanvasItem.TEXTURE_FILTER_PARENT_NODE
static var _watched := false


## Nine-patch facts of an image: size, margin [l, t, r, b], axis ["stretch" | "tile" | "tile_fit", ...],
## expand, tint (skin.json).
static func spec(name: String) -> Dictionary:
	if _specs.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "skin.json"))
		_specs = (data as Dictionary).get("images", {}) if data is Dictionary else {}
	return _specs.get(name, {})


## The image wrapped in a CanvasTexture whose filter follows the UI scale; `follow_scale` false: the plain
## image (drawn with the filter of the node, e.g. bars scaled down with the board).
static func texture(name: String, follow_scale := true) -> Texture2D:
	if not follow_scale:
		return load(DIR + name + ".png")
	if not _textures.has(name):
		var t := CanvasTexture.new()
		t.diffuse_texture = load(DIR + name + ".png")
		t.texture_filter = _filter
		_textures[name] = t
	return _textures[name]


## A StyleBoxTexture of the skin image `name` like the theme's: content margins [l, t, r, b] (default: the
## texture margins), `modulate` (the grey "tint" images take a colour this way).
static func style(name: String, content: Array = [], modulate := Color.WHITE, follow_scale := true) -> StyleBoxTexture:
	var s := spec(name)
	var sb := StyleBoxTexture.new()
	sb.texture = texture(name, follow_scale)
	var margin: Array = s.get("margin", [0, 0, 0, 0])
	sb.texture_margin_left = margin[0]
	sb.texture_margin_top = margin[1]
	sb.texture_margin_right = margin[2]
	sb.texture_margin_bottom = margin[3]
	var expand := float(s.get("expand", 0))
	if expand > 0.0:
		sb.expand_margin_left = expand
		sb.expand_margin_top = expand
		sb.expand_margin_right = expand
		sb.expand_margin_bottom = expand
	var axis: Array = s.get("axis", ["stretch", "stretch"])
	sb.axis_stretch_horizontal = _axis(axis[0])
	sb.axis_stretch_vertical = _axis(axis[1])
	if content.size() == 4:
		sb.content_margin_left = content[0]
		sb.content_margin_top = content[1]
		sb.content_margin_right = content[2]
		sb.content_margin_bottom = content[3]
	sb.modulate_color = modulate
	return sb


static func _axis(mode: String) -> StyleBoxTexture.AxisStretchMode:
	match mode:
		"tile":
			return StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		"tile_fit":
			return StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH


## Keeps the filter right for `root` (now and whenever its size or scale changes).
static func watch(root: Window) -> void:
	if not _watched:
		_watched = true
		root.size_changed.connect(update_filter.bind(root))
	update_filter(root)


## NEAREST when the canvas is drawn at a whole scale of the window, LINEAR otherwise.
static func update_filter(root: Window) -> void:
	var canvas := root.get_visible_rect().size
	if canvas.y <= 0.0:
		return
	var scale := float(root.size.y) / canvas.y
	var whole := scale >= 1.0 - WHOLE_SCALE and absf(scale - roundf(scale)) <= WHOLE_SCALE
	set_filter(CanvasItem.TEXTURE_FILTER_NEAREST if whole else CanvasItem.TEXTURE_FILTER_LINEAR)


static func set_filter(filter: CanvasItem.TextureFilter) -> void:
	if filter == _filter:
		return
	_filter = filter
	for t in _textures.values():
		(t as CanvasTexture).texture_filter = filter
	var theme: Theme = load(THEME)
	for type in theme.get_stylebox_type_list():
		for style_name in theme.get_stylebox_list(type):
			var sb := theme.get_stylebox(style_name, type) as StyleBoxTexture
			if sb != null and sb.texture is CanvasTexture:
				(sb.texture as CanvasTexture).texture_filter = filter


static func filter() -> CanvasItem.TextureFilter:
	return _filter
