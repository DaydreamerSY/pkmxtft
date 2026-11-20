class_name RecipesTip
extends VBoxContainer

## Right click on an item: every full item a component makes, or the recipe of a
## full item. Rows open their own tooltip one level up.
## Scene: scenes/ui/tooltips/recipes_tip.tscn

var item := ""
var level := 0

@onready var _header: ItemHeader = %Header
@onready var _rows: VBoxContainer = %Rows
@onready var _desc: RichTextLabel = %Desc
@onready var _made_from: HBoxContainer = %MadeFrom


func _ready() -> void:
	_header.show_item(item)
	var component := GameData.is_component(item)
	_rows.visible = component
	_desc.visible = not component
	_made_from.visible = false
	if component:
		for pair in GameData.recipes_with(item):
			var row: RecipeRow = UiScenes.make(UiScenes.RECIPE_ROW)
			row.other = pair[0]
			row.result = pair[1]
			row.level = level + 1
			_rows.add_child(row)
		return
	_desc.text = GameText.format(GameData.item_desc(item))
	var recipe = GameData.get_item(item).get("recipe")
	if recipe is Array:
		_made_from.visible = true
		for i in recipe.size():
			if i > 0:
				_made_from.add_child(UiStyle.label("+", 18, UiStyle.TEXT_DIM))
			var part: String = recipe[i]
			var icon := UiStyle.icon_rect(GameData.item_icon(part), 34)
			HoverTip.add(icon, func() -> Control: return Tooltips.item(part), HoverTip.Side.RIGHT, level + 1)
			_made_from.add_child(icon)
