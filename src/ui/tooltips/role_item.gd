class_name RoleItem
extends VBoxContainer

## Suggested item of the role tooltip: icon + its recipe (hover: the item).
## Scene: scenes/ui/tooltips/role_item.tscn

var item := ""
var level := 1

@onready var _icon: TextureRect = %Icon
@onready var _recipe: HBoxContainer = %Recipe
@onready var _a: TextureRect = %A
@onready var _b: TextureRect = %B


func _ready() -> void:
	_icon.texture = GameData.item_icon(item)
	var recipe = GameData.get_item(item).get("recipe")
	_recipe.visible = recipe is Array
	if recipe is Array:
		_a.texture = GameData.item_icon(recipe[0])
		_b.texture = GameData.item_icon(recipe[1])
	HoverTip.add(self, func() -> Control: return Tooltips.item(item), HoverTip.Side.RIGHT, level)
