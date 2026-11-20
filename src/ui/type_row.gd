class_name TypeRow
extends HBoxContainer

## Icon + name of a synergy (shop cards, unit panel, tooltips). Scene: scenes/ui/type_row.tscn

var type := ""
var font_size := 14
## Lit in the synergy colour (shop cards: synergy active on the board).
var highlighted := false
var _tag: StyleBox ## slanted tag of the skin behind a highlighted row

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name


static func create(synergy: String, size := 14) -> TypeRow:
	var row: TypeRow = UiScenes.make(UiScenes.TYPE_ROW)
	row.type = synergy
	row.font_size = size
	return row


func _ready() -> void:
	if type == "":
		return
	_icon.texture = GameData.type_icon(type)
	_icon.custom_minimum_size = Vector2(font_size + 4, font_size + 4)
	_name.text = GameData.synergy_name(type)
	_name.add_theme_font_size_override("font_size", font_size)
	if highlighted:
		_name.add_theme_color_override("font_color", GameData.TYPE_COLORS.get(type, UiStyle.GOLD).lightened(0.55))
		queue_redraw()


## Highlighted: a slanted tag of the synergy colour behind the row (the type labels of the skin).
func _draw() -> void:
	if not highlighted:
		return
	if _tag == null:
		_tag = UiSkin.style("tag", [], GameData.TYPE_COLORS.get(type, UiStyle.GOLD).lightened(0.15))
	draw_style_box(_tag, Rect2(Vector2(-6, -1), size + Vector2(14, 2)))
