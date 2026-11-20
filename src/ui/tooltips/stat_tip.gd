class_name StatTip
extends VBoxContainer

## Stat of the unit panel: what it does, current value (base + bonus).
## Scene: scenes/ui/tooltips/stat_tip.tscn

var stat := ""
var value := 0.0
var base := 0.0
var pkm := "" ## the Pokémon of the panel ("" = none): the PP rules of its role

@onready var _title: RichTextLabel = %Title
@onready var _desc: RichTextLabel = %Desc
@onready var _current: RichTextLabel = %Current


func _ready() -> void:
	_title.text = GameText.stat_text(stat, 22)
	_desc.text = GameText.format(Tooltips.stat_info(stat, pkm))
	var line := L.t("Current: [b]%s[/b]") % Tooltips.format_stat(stat, value)
	if not is_equal_approx(value, base):
		line += "  [color=#9aa](base %s, %s%s)[/color]" % [Tooltips.format_stat(stat, base),
			"+" if value > base else "-", Tooltips.format_stat(stat, absf(value - base))]
	_current.text = line
