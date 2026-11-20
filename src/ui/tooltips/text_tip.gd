class_name TextTip
extends VBoxContainer

## Simple title + text tooltip (buttons, lock, range, position).
## Scene: scenes/ui/tooltips/text_tip.tscn

var title := ""
var body := ""

@onready var _title: Label = %Title
@onready var _body: RichTextLabel = %Body


func _ready() -> void:
	_title.text = title
	_title.visible = title != ""
	_body.text = GameText.format(body)
	_body.visible = body != ""
