class_name UiScenes
extends RefCounted

## Paths of the UI scenes built at runtime (rows, cards, tooltips). Edit the scenes in
## scenes/ui/ (layout, frames, fonts, icons) and the look of the HUD follows; the
## scripts only fill in the data. Loaded on first use (no preload: the scenes' own
## scripts use this class).

const TYPE_ROW := "res://scenes/ui/type_row.tscn"
const ITEM_SLOT := "res://scenes/ui/item_slot.tscn"
const SYNERGY_ROW := "res://scenes/ui/synergy_row.tscn"
const ITEM_CHOICE_BUTTON := "res://scenes/ui/item_choice_button.tscn"
const ITEM_TIP := "res://scenes/ui/tooltips/item_tip.tscn"
const RECIPES_TIP := "res://scenes/ui/tooltips/recipes_tip.tscn"
const RECIPE_ROW := "res://scenes/ui/tooltips/recipe_row.tscn"
const SKILL_TIP := "res://scenes/ui/tooltips/skill_tip.tscn"
const STAT_TIP := "res://scenes/ui/tooltips/stat_tip.tscn"
const SYNERGY_TIP := "res://scenes/ui/tooltips/synergy_tip.tscn"
const SYNERGY_MEMBER := "res://scenes/ui/tooltips/synergy_member.tscn"
const ROLE_TIP := "res://scenes/ui/tooltips/role_tip.tscn"
const ROLE_ITEM := "res://scenes/ui/tooltips/role_item.tscn"
const UNIT_MINI_TIP := "res://scenes/ui/tooltips/unit_mini_tip.tscn"
const TEXT_TIP := "res://scenes/ui/tooltips/text_tip.tscn"

static var _packed: Dictionary = {}


static func make(path: String) -> Node:
	if not _packed.has(path):
		_packed[path] = load(path)
	return (_packed[path] as PackedScene).instantiate()
