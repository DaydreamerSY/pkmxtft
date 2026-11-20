class_name UiStyle
extends RefCounted

## Colour palette of the data-driven parts of the UI (stats, damage kinds, rarity-coloured
## frames) and a few helpers for small nodes built at runtime.
## The look itself (panels, buttons, bars, fonts) is scenes/ui/theme/ui_theme.tres and
## the scenes of scenes/ui/; its frames are nine-patch images of the pixel-art skin (UiSkin: dark "battle" look
## after the Essentials UI redesign - grid fill, slate double line, cut corners, red corner brackets on hover).

const BG := Color(0.085, 0.1, 0.125, 0.94)
const BORDER := Color(0.52, 0.58, 0.76) ## slate outline of the frames
const TEXT := Color(0.94, 0.95, 0.97)
const TEXT_DIM := Color(0.6, 0.64, 0.73)
const GOLD := Color(1.0, 0.82, 0.3)
const BLUE := Color(0.35, 0.65, 1.0)
const RED := Color(1.0, 0.38, 0.32)
const GREEN := Color(0.45, 0.85, 0.4)
const STATUS_COLOR := Color(0.8, 0.62, 1.0)
const ACCENT := Color(0.96, 0.62, 0.22) ## thin orange lines, pinned tooltips, pressed buttons
const SELECT := Color(0.94, 0.22, 0.16) ## corner brackets: hover / selection
const LIME := Color(0.55, 0.82, 0.3) ## angled end of the active synergy rows

## Colours of the stats in texts and in the unit panel.
const STAT_COLORS := {
	"HP": Color(0.45, 0.85, 0.4), "ATK": Color(1.0, 0.62, 0.3), "AP": Color(0.62, 0.55, 1.0),
	"DEF": Color(0.95, 0.75, 0.3), "SPE_DEF": Color(0.4, 0.8, 0.95), "SPEED": Color(1.0, 0.9, 0.45),
	"PP": Color(0.35, 0.65, 1.0), "MAX_PP": Color(0.35, 0.65, 1.0), "CRIT_CHANCE": Color(1.0, 0.42, 0.35),
	"CRIT_POWER": Color(1.0, 0.42, 0.35), "SHIELD": Color(0.85, 0.88, 0.92), "LUCK": Color(0.5, 0.95, 0.6),
	"RANGE": Color(0.92, 0.92, 0.92),
}
const DAMAGE_COLORS := {
	"PHYSICAL": Color(1.0, 0.62, 0.35), "SPECIAL": Color(0.55, 0.75, 1.0), "TRUE": Color(1, 1, 1),
}


## A HUD frame of the skin (DPS meter, shop dock): the plain slate panel. Another `border` colour: the grey
## frame tinted with it (Battle Pass cards, buttons made in code); `bg`, `border_width` and `radius` are kept for
## the callers, the image gives the fill, the line and the cut corners.
static func panel(bg := BG, border := BORDER, border_width := 2, radius := 8) -> StyleBox:
	var sb := UiSkin.style("panel_plain" if border == BORDER else "frame_tint", [10, 6, 10, 6],
		Color.WHITE if border == BORDER else border)
	return sb


## Pointed chip of the skin tinted with `color` (role, passive of the unit panel).
static func chip(color: Color, content := [7, 0, 7, 0]) -> StyleBox:
	return UiSkin.style("chip", content, color)


## Frames whose colour code can change: a StyleBoxTexture of the skin (its grey "tint" images take the colour
## through modulate_color), a StyleBoxFlat.
static func is_frame(style: StyleBox) -> bool:
	return style is StyleBoxTexture or style is StyleBoxFlat


## Frames with a fill colour of their own (StyleBoxFlat): `bg_color` can be changed.
static func has_fill(style: StyleBox) -> bool:
	return style is StyleBoxFlat


## Colours a frame: the outline of a StyleBoxFlat, the whole tint image of a StyleBoxTexture.
static func tint(style: StyleBox, color: Color) -> void:
	if style is StyleBoxTexture:
		(style as StyleBoxTexture).modulate_color = color
	elif style is StyleBoxFlat:
		(style as StyleBoxFlat).border_color = color


## A copy of `frame` with another fill / outline colour / outline width (null / negative: unchanged).
## StyleBoxTexture: `border` tints the image, the fill and the width come from the image.
static func recolored(frame: StyleBox, bg: Variant = null, border: Variant = null, width := -1.0) -> StyleBox:
	var copy: StyleBox = frame.duplicate()
	if copy is StyleBoxTexture:
		if border != null:
			(copy as StyleBoxTexture).modulate_color = border
	elif copy is StyleBoxFlat:
		var flat := copy as StyleBoxFlat
		if bg != null:
			flat.bg_color = bg
		if border != null:
			flat.border_color = border
		if width >= 0.0:
			flat.set_border_width_all(int(width))
	return copy


static func label(text: String, size := 18, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func icon_rect(texture: Texture2D, size := 24.0, filter := CanvasItem.TEXTURE_FILTER_LINEAR) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = filter
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Wrapped BBCode text of a fixed width.
static func rich(bbcode: String, size := 15, width := 300.0, color := TEXT) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(width, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.add_theme_color_override("default_color", color)
	r.text = bbcode
	return r
