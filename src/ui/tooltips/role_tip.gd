class_name RoleTip
extends VBoxContainer

## Role chip ("type of character"): what it does, where to place it, items that suit it.
## Scene: scenes/ui/tooltips/role_tip.tscn

var role := ""
var level := 0

@onready var _name: Label = %Name
@onready var _desc: RichTextLabel = %Desc
@onready var _position: RichTextLabel = %Position
@onready var _grid: GridContainer = %Grid


func _ready() -> void:
	var info := UnitRoles.info(role)
	_name.text = L.t(info.name)
	_name.add_theme_color_override("font_color", info.color)
	_desc.text = GameText.format(L.t(info.desc))
	if info.has("range"): # at least this range (UnitRoles.attack_range)
		_desc.text += "\n" + L.t("Attack range %d") % int(info.range)
	_position.text = L.t("Suggested position: [b]front row[/b]") if info.front else L.t("Suggested position: [b]back row[/b]")
	for item in info.items:
		var cell: RoleItem = UiScenes.make(UiScenes.ROLE_ITEM)
		cell.item = item
		cell.level = level + 1
		_grid.add_child(cell)
