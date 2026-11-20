class_name ItemChoiceButton
extends Button

## One item of the "Choose an item" popup (hover: item tooltip), with its price if any.
## A tap / click on the card picks the item; the "i" button in its corner shows what the item does
## without picking it (on a phone the card has no hover, and holding it is not obvious).
## Scene: scenes/ui/item_choice_button.tscn

const INFO_SIZE := 28.0

var item := ""
var cost := 0

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name


func _ready() -> void:
	_icon.texture = GameData.item_icon(item)
	_name.text = GameData.item_name(item) + ("\n" + L.t("%d gold") % cost if cost > 0 else "")
	HoverTip.add(self, func() -> Control: return Tooltips.item(item), HoverTip.Side.BOTTOM)
	_add_info_button()


## The "i" button in the top right corner: opens / closes the item's tooltip, pinned under the card.
func _add_info_button() -> void:
	var info := Button.new()
	info.name = "Info"
	info.text = "i"
	info.focus_mode = Control.FOCUS_NONE
	info.add_theme_font_size_override("font_size", 17)
	info.add_theme_color_override("font_color", UiStyle.GOLD)
	info.add_theme_color_override("font_hover_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := UiStyle.panel(Color(0.05, 0.08, 0.12, 0.95) if state != "hover" else Color(0.12, 0.18, 0.26, 0.98),
			UiStyle.GOLD if state != "disabled" else UiStyle.TEXT_DIM, 2, int(INFO_SIZE * 0.3))
		style.set_content_margin_all(0.0)
		info.add_theme_stylebox_override(state, style)
	info.anchor_left = 1.0
	info.anchor_right = 1.0
	info.anchor_top = 0.0
	info.anchor_bottom = 0.0
	info.offset_left = -INFO_SIZE - 3.0
	info.offset_right = -3.0
	info.offset_top = 3.0
	info.offset_bottom = 3.0 + INFO_SIZE
	info.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info.grow_vertical = Control.GROW_DIRECTION_END
	add_child(info)
	# a disabled card (too expensive) still tells what the item does
	info.pressed.connect(show_details)


## The item's tooltip pinned under the card (closed again by a second press).
func show_details() -> void:
	if HoverTip.current != null:
		HoverTip.current.toggle(self, Tooltips.item(item), HoverTip.Side.BOTTOM)
