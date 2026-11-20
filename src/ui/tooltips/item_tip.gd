class_name ItemTip
extends VBoxContainer

## Hover an item: name, stats, description, recipe, hint.
## Scene: scenes/ui/tooltips/item_tip.tscn

var item := ""
var hint := ""

@onready var _header: ItemHeader = %Header
@onready var _desc: RichTextLabel = %Desc
@onready var _recipe: RichTextLabel = %Recipe
@onready var _hint: RichTextLabel = %Hint


func _ready() -> void:
	_header.show_item(item)
	var desc := GameData.item_desc(item)
	_desc.text = GameText.format(desc)
	if GameData.item_locked(item): # Battle Pass: a stone / tool crafted or kept from before its synergy is unlocked
		_desc.text += "\n[color=#9aa]%s[/color]" % L.t("Its synergy is not unlocked yet (Battle Pass): it only gives its stats.")
	_desc.visible = desc != ""
	var recipe = GameData.get_item(item).get("recipe")
	_recipe.visible = recipe is Array and recipe.size() == 2
	if _recipe.visible:
		_recipe.text = "[color=#9aa]Recipe:[/color]  [img=26]%s[/img] + [img=26]%s[/img]" % [
			GameData.item_icon_path(recipe[0]), GameData.item_icon_path(recipe[1])]
	_hint.visible = hint != ""
	_hint.text = "[i]%s[/i]" % hint
