class_name SynergyMember
extends PanelContainer

## Portrait of a Pokémon in the synergy tooltip. Border = colour of its cost (grey 1, green 2,
## blue 3, purple 4, red 5, yellow Unique / Legendary), a check when its family is owned, dim
## with a lock when the player's shop cannot have it now. Hover: small card with how it gets
## into the shop. Scene: scenes/ui/tooltips/synergy_member.tscn (frame: theme type variation
## PortraitCell).

const BORDER := 3
const BADGE := 14.0

var pkm := ""
var owned := false
var locked := false
var level := 1
var player: PlayerState

@onready var _portrait: TextureRect = %Portrait


func _ready() -> void:
	var data := GameData.get_pokemon(pkm)
	var rarity_color: Color = GameData.RARITY_COLORS.get(data.get("rarity", ""), UiStyle.TEXT)
	var frame := get_theme_stylebox("panel")
	if UiStyle.is_frame(frame):
		var recolored := UiStyle.recolored(frame, null, rarity_color if not locked else rarity_color.darkened(0.3), BORDER)
		recolored.set_content_margin_all(BORDER) # the portrait inside the border, not over it
		add_theme_stylebox_override("panel", recolored)
	_portrait.texture = GameData.portrait(pkm)
	_portrait.self_modulate = Color.WHITE if owned else (Color(0.35, 0.35, 0.35) if locked else Color(0.82, 0.82, 0.82))
	var badge: Control = null
	if owned:
		badge = CheckBadge.new()
	elif locked:
		badge = UiStyle.icon_rect(GameData.icon("lock-close"), BADGE)
		badge.modulate = Color(1.0, 0.85, 0.55)
	if badge != null: # on the portrait's corner (bottom right: check, top right: lock)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.size = Vector2(BADGE, BADGE)
		_portrait.add_child(badge)
		var place := func() -> void:
			badge.position = Vector2(_portrait.size.x - BADGE + 2.0, (_portrait.size.y - BADGE + 2.0) if owned else -2.0)
		_portrait.resized.connect(place)
		place.call()
	HoverTip.add(self, func() -> Control: return Tooltips.unit_mini(pkm, player), HoverTip.Side.BOTTOM, level)


## Green round check of an owned family (web: .pokemon-portrait.acquired).
class CheckBadge extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size * 0.5, size.x * 0.5, Color(0.12, 0.5, 0.2))
		draw_polyline(PackedVector2Array([Vector2(0.26, 0.52) * size, Vector2(0.44, 0.7) * size,
			Vector2(0.76, 0.32) * size]), Color.WHITE, 2.0, true)
