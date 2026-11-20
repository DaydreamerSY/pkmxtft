class_name ItemChoice
extends PanelContainer

## Pick 1 item out of several (hover: item tooltip): the reward of some PvE stages,
## the town carousel (Kangaskhan sells its items), or a Fairy wand. Stays open until an
## item is picked (or skipped when allowed); the game keeps running.
## Scene: scenes/ui/item_choice.tscn

signal chosen(item: String)
signal skipped

@onready var _title: Label = %Title
@onready var _row: HBoxContainer = %Row
@onready var _skip: Button = %Skip


func _ready() -> void:
	_skip.pressed.connect(func() -> void:
		visible = false
		skipped.emit())


## `cost` > 0: each item costs that much gold (disabled when `gold` is not enough),
## and the choice can be skipped.
func show_items(items: Array[String], title := "", cost := 0, gold := 0) -> void:
	_title.text = title if title != "" else L.t("Choose an item")
	# a small canvas (phones): a long title wraps instead of widening the popup over the side columns
	var small := UiScale.is_compact(self)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if small else TextServer.AUTOWRAP_OFF
	custom_minimum_size.x = 440.0 if small else 400.0
	for c in _row.get_children():
		c.queue_free()
	for item in items:
		var b: ItemChoiceButton = UiScenes.make(UiScenes.ITEM_CHOICE_BUTTON)
		b.item = item
		b.cost = cost
		b.disabled = cost > gold
		b.pressed.connect(func() -> void:
			visible = false
			if HoverTip.current:
				HoverTip.current.close_all()
			chosen.emit(item))
		_row.add_child(b)
	_skip.visible = cost > 0
	visible = true
