class_name ItemSlot
extends PanelContainer

## One item square (item bench, unit panel). Scene: scenes/ui/item_slot.tscn
## The frame comes from the theme type variations below.

@export var filled_variation := &"ItemSlot"
@export var empty_variation := &"ItemSlotEmpty"

var item := ""

@onready var _icon: TextureRect = %Icon


func _ready() -> void:
	set_item(item)


func set_item(id: String) -> void:
	item = id
	if not is_node_ready():
		return
	_icon.texture = GameData.item_icon(id) if id != "" else null
	theme_type_variation = filled_variation if id != "" else empty_variation
