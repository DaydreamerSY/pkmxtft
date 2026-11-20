class_name ShopCard
extends Button

## Pokémon card of the shop (layout of the web game card): the portrait on the right,
## the left half fading to black under the synergies, name + cost on a dark band at
## the bottom; frame colour = rarity.
## Highlight (glow): a pulsing frame of the synergy colour with fireflies running
## around it, on the Pokémon having a synergy active on the board (its synergy name
## lit too), or, while a synergy is hovered (synergy list, a synergy of a card), on
## the Pokémon of that synergy — the others are dimmed.
## Hover: its ability. Scene: scenes/ui/shop_card.tscn (theme type variation ShopCard;
## the rarity frames are recoloured copies of its "normal" style).

## Hovering one of its synergies ("" = left it).
signal synergy_hovered(type: String)

const FRAME_WIDTH := 3 ## rarity frame of a StyleBoxFlat theme (hover / pressed: 4); the skin image has its own
const PULSE_TIME := 0.35 ## s from bright to dim
const NAME_FONT := 16
## Compact card: the name shrinks down to this to stay whole.
const MIN_NAME_FONT := 11

var pkm := ""

var _active: Array = [] ## synergies of the card active on the board
var _focus := "" ## hovered synergy
var _glow_color := Color.TRANSPARENT
var _glow_tween: Tween
var _fireflies: FireflyFrame
var _compact := false
var _select: NinePatchRect ## red corner brackets shown on hover

@onready var _portrait: TextureRect = %Portrait
@onready var _types: VBoxContainer = %Types
@onready var _bottom: HBoxContainer = %Bottom
@onready var _name: Label = %Name
@onready var _cost: Label = %Cost
@onready var _glow: Panel = %Glow


func _ready() -> void:
	# own copy of the frame style (the scene sub-resource is shared by the 6 cards)
	_glow.add_theme_stylebox_override("panel", _glow.get_theme_stylebox("panel").duplicate())
	_fireflies = FireflyFrame.new()
	_fireflies.visible = false
	add_child(_fireflies)
	# hover: the selection brackets of the skin, inside the card (it clips its contents)
	_select = NinePatchRect.new()
	_select.texture = UiSkin.texture("select")
	var m: Array = UiSkin.spec("select").get("margin", [13, 13, 13, 13])
	_select.patch_margin_left = int(m[0])
	_select.patch_margin_top = int(m[1])
	_select.patch_margin_right = int(m[2])
	_select.patch_margin_bottom = int(m[3])
	_select.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_select.visible = false
	add_child(_select)
	_select.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_entered.connect(_show_select.bind(true))
	mouse_exited.connect(_show_select.bind(false))
	HoverTip.add(self, func() -> Control: return Tooltips.skill(pkm) if pkm != "" else null, HoverTip.Side.TOP)
	_name.resized.connect(_fit_name)
	show_pokemon(pkm, false)


## Compact HUD (phones): a narrow card. The name keeps its whole text in a smaller font instead of being
## cut, the coin is smaller, the synergies sit closer to the frame.
func set_compact(on: bool) -> void:
	if on == _compact:
		return
	_compact = on
	(_bottom.get_node("Coin") as Control).custom_minimum_size = Vector2(13, 13) if on else Vector2(16, 16)
	_bottom.add_theme_constant_override("separation", 2 if on else 4)
	_bottom.offset_left = 8.0 if on else 10.0
	_bottom.offset_right = -8.0 if on else -10.0
	_types.offset_left = 8.0 if on else 10.0
	_types.offset_top = 7.0 if on else 9.0
	_fit_name()


## Compact: the largest font (NAME_FONT down to MIN_NAME_FONT) that shows the whole name in its room.
func _fit_name() -> void:
	var font_size := NAME_FONT
	if _compact and pkm != "":
		var font := _name.get_theme_font("font")
		while font_size > MIN_NAME_FONT and font.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > _name.size.x:
			font_size -= 1
	if _name.get_theme_font_size("font_size") != font_size:
		_name.add_theme_font_size_override("font_size", font_size)


## `active`: {synergy: true} of the synergies active on the player's board.
func show_pokemon(id: String, can_buy: bool, active := {}) -> void:
	pkm = id
	if not is_node_ready():
		return
	for c in _types.get_children():
		c.queue_free()
	_bottom.visible = pkm != ""
	for state in ["normal", "hover", "pressed"]:
		remove_theme_stylebox_override(state)
	_active = []
	if pkm == "":
		_portrait.texture = null
		disabled = true
		remove_theme_stylebox_override("disabled")
		_update_glow()
		return
	var data := GameData.get_pokemon(pkm)
	var color: Color = GameData.RARITY_COLORS.get(data.rarity, UiStyle.TEXT)
	_portrait.texture = GameData.portrait(pkm)
	_name.text = GameData.display_name(pkm)
	_cost.text = str(GameData.rarity_cost(data.rarity))
	_fit_name()
	for t in data.types:
		var row := TypeRow.create(t, 13)
		row.highlighted = active.has(t)
		# hovering a synergy of the card highlights that synergy everywhere
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.mouse_entered.connect(func() -> void: synergy_hovered.emit(t))
		row.mouse_exited.connect(func() -> void: synergy_hovered.emit(""))
		_types.add_child(row)
		if active.has(t):
			_active.append(t)
	disabled = not can_buy
	_recolor("normal", color.darkened(0.72), color, FRAME_WIDTH)
	_recolor("hover", color.darkened(0.6), color.lightened(0.35), FRAME_WIDTH + 1)
	_recolor("pressed", color.darkened(0.8), UiStyle.GOLD, FRAME_WIDTH + 1)
	_recolor("disabled", color.darkened(0.85), color.darkened(0.5), FRAME_WIDTH)
	_portrait.modulate = Color.WHITE if can_buy else Color(0.55, 0.55, 0.55)
	_show_select(is_hovered())
	_update_glow()


## Hover: the red corner brackets of the skin over the card (an empty or unaffordable card: none).
func _show_select(on: bool) -> void:
	if _select != null:
		_select.visible = on and pkm != "" and not disabled


## A synergy is hovered somewhere ("" = none): glow if this Pokémon has it, else dim.
func set_synergy_focus(type: String) -> void:
	_focus = type
	_update_glow()


func has_type(type: String) -> bool:
	return pkm != "" and GameData.get_pokemon(pkm).get("types", []).has(type)


func _update_glow() -> void:
	var lit := ""
	if _focus != "":
		lit = _focus if has_type(_focus) else ""
		modulate = Color.WHITE if lit != "" or pkm == "" else Color(0.5, 0.5, 0.5)
	else:
		modulate = Color.WHITE
		lit = _active[0] if not _active.is_empty() else ""
	var c: Color = GameData.TYPE_COLORS.get(lit, UiStyle.GOLD).lightened(0.2) if lit != "" else Color.TRANSPARENT
	if c == _glow_color and (lit == "" or _glow_tween != null):
		return # same glow: keep the pulse going (the shop refreshes on every gold change)
	_glow_color = c
	if _glow_tween:
		_glow_tween.kill()
		_glow_tween = null
	_glow.visible = lit != ""
	_fireflies.visible = lit != ""
	if lit == "":
		return
	UiStyle.tint(_glow.get_theme_stylebox("panel"), c)
	_fireflies.color = c.lightened(0.25)
	_glow.modulate.a = 1.0
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(_glow, "modulate:a", 0.2, PULSE_TIME).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(_glow, "modulate:a", 1.0, PULSE_TIME).set_trans(Tween.TRANS_SINE)


## The rarity frame of a state: the grey card image of the skin tinted with `border` (`bg` / `width`: for a
## StyleBoxFlat theme).
func _recolor(state: String, bg: Color, border: Color, width: int) -> void:
	var base := get_theme_stylebox("normal")
	if not UiStyle.is_frame(base):
		return # another kind of frame from the theme: keep it as it is
	add_theme_stylebox_override(state, UiStyle.recolored(base, bg, border, width))
