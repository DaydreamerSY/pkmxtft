class_name ItemHeader
extends HBoxContainer

## Icon, name and stat line of an item (item and recipe tooltips).
## Scene: scenes/ui/tooltips/item_header.tscn

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _stats: RichTextLabel = %Stats


func show_item(item: String) -> void:
	_icon.texture = GameData.item_icon(item)
	_name.text = GameData.item_name(item)
	var stats := GameText.item_stats(item)
	_stats.text = stats
	_stats.visible = stats != ""
