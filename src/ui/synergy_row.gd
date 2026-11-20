class_name SynergyRow
extends PanelContainer

## One synergy of the list: badge (type icon, border = reached tier), count, name,
## tiers "2 > 4 > 6". Hover: synergy tooltip. Scene: scenes/ui/synergy_row.tscn

## Badge colour per reached tier (bronze, silver, gold, prismatic).
@export var tier_colors: Array[Color] = [
	Color(0.72, 0.45, 0.25), Color(0.75, 0.78, 0.82), Color(1.0, 0.8, 0.3), Color(0.55, 0.95, 1.0),
]

var type := ""
var count := 0
var reached := -1 ## index of the reached tier, -1 = inactive
var tiers: Array = []
var owned: Dictionary = {}
var extra := "" ## Synergies.context_text for the tooltip
var player: PlayerState ## whose shop the tooltip's Pokémon list tells about
## Compact HUD (phones): a narrow chip - the badge, the count above the tier to reach next ("2" over
## "/4"); the name and the other tiers are in the tooltip (tap).
var chip := false

@onready var _badge: PanelContainer = %Badge
@onready var _icon: TextureRect = %Icon
@onready var _count: Label = %Count
@onready var _name: Label = %Name
@onready var _tiers: RichTextLabel = %Tiers


func _ready() -> void:
	var active := reached >= 0
	theme_type_variation = &"SynergyRow" if active else &"SynergyRowInactive"
	if active:
		var color := tier_colors[mini(reached, tier_colors.size() - 1)]
		var frame := _badge.get_theme_stylebox("panel")
		if UiStyle.is_frame(frame):
			_badge.add_theme_stylebox_override("panel", UiStyle.recolored(frame, color.darkened(0.45), color))
	_icon.texture = GameData.type_icon(type)
	_icon.modulate = Color.WHITE if active else Color(0.6, 0.6, 0.6)
	_count.text = str(count)
	_count.add_theme_color_override("font_color", Color.WHITE if active else UiStyle.TEXT_DIM)
	_name.text = GameData.synergy_name(type)
	_name.add_theme_color_override("font_color", Color.WHITE if active else UiStyle.TEXT_DIM)
	var steps: Array[String] = []
	for i in tiers.size():
		var color := "#ffd24d" if i == reached else ("#d0d0d0" if count >= int(tiers[i]) else "#6f7777")
		steps.append("[color=%s]%d[/color]" % [color, int(tiers[i])])
	_tiers.text = " [color=#556]>[/color] ".join(steps)
	if chip:
		custom_minimum_size = Vector2.ZERO
		# a narrow upright chip (the row image is slanted for its full height), a lime band when active
		add_theme_stylebox_override("panel", UiSkin.style("synergy_chip" if active else "synergy_chip_off", [4, 4, 4, 4]))
		($H as HBoxContainer).add_theme_constant_override("separation", 3)
		_icon.custom_minimum_size = Vector2(24, 24)
		_tiers.visible = false
		var target := int(tiers[-1]) if not tiers.is_empty() else 0 # the next tier, the last one once it is reached
		for t in tiers:
			if count < int(t):
				target = int(t)
				break
		_count.reparent(_name.get_parent(), false) # the count above "/4"
		_count.get_parent().move_child(_count, 0)
		_count.add_theme_font_size_override("font_size", 17)
		_count.custom_minimum_size.x = 0.0
		_name.text = "/%d" % target
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name.add_theme_font_size_override("font_size", 12)
		_name.add_theme_color_override("font_color", Color("#ffd24d") if active and count >= target else UiStyle.TEXT_DIM)
	HoverTip.add(self, func() -> Control: return Tooltips.synergy(type, count, owned, 0, extra, player), HoverTip.Side.RIGHT, 0, true)
