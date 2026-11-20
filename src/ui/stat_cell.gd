class_name StatCell
extends VBoxContainer

## Icon + value of one stat in the unit panel. Scene: scenes/ui/stat_cell.tscn

## Stat id (ATK, AP, DEF, SPE_DEF, SPEED, CRIT_CHANCE, CRIT_POWER, SHIELD, LUCK...).
@export var stat := "ATK"

@onready var _icon: TextureRect = %Icon
@onready var _value: Label = %Value


func _ready() -> void:
	if _icon.texture == null:
		_icon.texture = GameData.icon(stat)


func set_value(text: String) -> void:
	_value.text = text
