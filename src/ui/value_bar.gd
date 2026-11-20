class_name ValueBar
extends ProgressBar

## Bar with its value written in the middle ("700 / 700"). Scene: scenes/ui/value_bar.tscn
## Colours: theme type variations HpBar, PpBar, XpBar.

@onready var _value: Label = %Value


func set_values(current: float, maximum: float) -> void:
	max_value = maxf(maximum, 1.0)
	value = clampf(current, 0.0, max_value)
	_value.text = "%d / %d" % [roundi(current), roundi(maximum)]


func set_text(text: String) -> void:
	_value.text = text
