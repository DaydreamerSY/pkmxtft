class_name RecipeRow
extends HBoxContainer

## "+ [component] > [full item] Name" line of the recipe tooltip (hover: the full item).
## Scene: scenes/ui/tooltips/recipe_row.tscn

var other := ""
var result := ""
var level := 1

@onready var _other: TextureRect = %Other
@onready var _result: TextureRect = %Result
@onready var _name: Label = %Name


func _ready() -> void:
	_other.texture = GameData.item_icon(other)
	_result.texture = GameData.item_icon(result)
	_name.text = GameData.item_name(result)
	HoverTip.add(self, func() -> Control: return Tooltips.item(result), HoverTip.Side.RIGHT, level)
