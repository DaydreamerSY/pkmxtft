class_name SkillTip
extends VBoxContainer

## Ability of a Pokémon: name, PP, text, the cells it hits in words and on the
## Phase 2 mini board. Scene: scenes/ui/tooltips/skill_tip.tscn

var pkm := ""
## Ability shown instead of the Pokémon's own (TM, Skill Swap...).
var skill := ""

@onready var _title: Label = %Title
@onready var _pp: RichTextLabel = %Pp
@onready var _desc: RichTextLabel = %Desc
@onready var _cells: RichTextLabel = %Cells
@onready var _shape: AbilityShapeView = %Shape
@onready var _note: RichTextLabel = %Note


func _ready() -> void:
	var data := GameData.get_pokemon(pkm).duplicate()
	if skill != "":
		data.skill = skill
		data.maxPP = 100 # a TM ability (web)
	if pkm != "": # its own maxPP (balanced, data/balance.json)
		data.maxPP = Difficulty.max_pp_of(float(data.get("maxPP", 100)))
	var ab := GameData.get_ability(data.skill)
	_title.text = GameData.ability_name(data.skill)
	_pp.text = "[right]%s %d[/right]" % [GameText.stat_text("PP", 16, false), int(data.maxPP)]
	_desc.text = GameText.format(GameData.ability_desc(data.skill))
	var scale := float(data.get("skillScale", 1.0)) if skill == "" else 1.0 # the auto balance, on its own ability
	if not is_equal_approx(scale, 1.0):
		_desc.text += "\n[color=#%s]%s[/color]" % [UiStyle.STAT_COLORS.get("AP", UiStyle.TEXT).to_html(false),
			L.t("Ability strength: %d%% (damage, heal, shield)") % roundi(scale * 100.0)]
	_cells.text = "[color=#ffb866]%s[/color] " % L.t("Cells:") + AbilityRunner.describe_areas(ab, int(data.range), int(data.stars))
	_shape.show_pokemon(pkm)
	var approx = ab.get("approx", null)
	_note.visible = approx != null or not GameData.is_ability_ported(data.skill)
	if not GameData.is_ability_ported(data.skill):
		_note.text = L.t("(%s is not ported yet, placeholder)") % data.skill
	elif approx != null:
		_note.text = L.t("(simplified port)") if not approx is String else L.t("(simplified port: %s)") % approx
