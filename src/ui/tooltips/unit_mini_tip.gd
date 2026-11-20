class_name UnitMiniTip
extends VBoxContainer

## Small card of a Pokémon (synergy tooltip): name, cost, types, role, and how it gets into
## the shop (Tooltips.unlock_info: rule + state for `player`).
## Scene: scenes/ui/tooltips/unit_mini_tip.tscn

const STATES := {
	"owned": ["On your team", Color(0.5, 0.9, 0.5)],
	"available": ["Available in your shop", Color(0.5, 0.9, 0.5)],
	"locked": ["Not in your shop yet", Color(1.0, 0.7, 0.35)],
	"offered": ["Portal choice", Color(1.0, 0.82, 0.3)],
}

var pkm := ""
var player: PlayerState

@onready var _name: Label = %Name
@onready var _cost: Label = %Cost
@onready var _types: VBoxContainer = %Types
@onready var _role: Label = %Role


func _ready() -> void:
	var data := GameData.get_pokemon(pkm)
	var rarity_color: Color = GameData.RARITY_COLORS.get(data.rarity, UiStyle.TEXT)
	_name.text = GameData.display_name(pkm)
	_name.add_theme_color_override("font_color", rarity_color.lightened(0.3))
	_cost.text = str(GameData.rarity_cost(data.rarity))
	for t in data.types:
		_types.add_child(TypeRow.create(t, 14))
	_role.text = UnitRoles.info(UnitRoles.role_of(pkm)).name
	var unlock := Tooltips.unlock_info(pkm, player)
	add_child(HSeparator.new())
	if player != null:
		var state: Array = STATES.get(unlock.state, STATES.available)
		add_child(UiStyle.label(L.t(state[0]), 14, state[1]))
	add_child(UiStyle.rich(GameText.format(unlock.text, 14), 13, 260.0))
