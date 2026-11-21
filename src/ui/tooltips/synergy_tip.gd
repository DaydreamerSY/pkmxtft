class_name SynergyTip
extends VBoxContainer

## Synergy: description, tiers (the reached one lit) and the Pokémon having it in groups
## (Tooltips.synergy_groups: shop, additional, regional, unique, legendary): border = cost colour,
## owned families checked, the ones the player's shop cannot have now dim with a lock.
## Scene: scenes/ui/tooltips/synergy_tip.tscn

var type := ""
var count := 0 ## families on the board with the type
var owned: Dictionary = {} ## family -> true (board and bench)
var level := 0
var extra := "" ## what it does on this board: wands, spotlight, dragon stars...
var player: PlayerState ## null: enemy synergy (no shop state)

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _desc: RichTextLabel = %Desc
@onready var _tiers: VBoxContainer = %Tiers
@onready var _members: GridContainer = %Members


## Compact HUD (phones): in one column the tooltip is taller than the canvas and would be shrunk to fit;
## in two (the text on the left, the Pokémon on the right) it keeps its size.
func _two_columns() -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	add_child(columns)
	columns.add_child(left)
	columns.add_child(VSeparator.new())
	columns.add_child(right)
	for node in [_icon.get_parent(), _desc, _tiers]:
		node.reparent(left, false)
	_members.reparent(right, false)
	($Sep as Control).visible = false


func _ready() -> void:
	if UiScale.is_compact(self):
		_two_columns()
	_icon.texture = GameData.type_icon(type)
	_name.text = GameData.synergy_name(type)
	_name.add_theme_color_override("font_color", GameData.TYPE_COLORS.get(type, UiStyle.TEXT).lightened(0.3))
	var desc := GameData.synergy_description(type) # the web's, or the season's own effects
	_desc.text = GameText.format(desc)
	if extra != "":
		_desc.text += "\n[color=#9fd8ff]%s[/color]" % GameText.format(extra)
	_desc.visible = desc != "" or extra != ""
	var thresholds: Array = GameData.config.get("synergyThresholds", {}).get(type, [])
	var tier_texts := GameData.synergy_tier_texts(type)
	var reached := -1
	for i in thresholds.size():
		if count >= int(thresholds[i]):
			reached = i
	for i in thresholds.size():
		var lit := i == reached
		var tier_text := GameText.format(String(tier_texts[i])) if i < tier_texts.size() else ""
		var line := "[color=%s][b](%d)[/b][/color] " % ["#ffd24d" if lit else "#7f8a8a", int(thresholds[i])]
		line += tier_text if lit else "[color=#7f8a8a]%s[/color]" % Tooltips.strip_colors(tier_text)
		_tiers.add_child(UiStyle.rich(line, 14, 360))
	var parent := _members.get_parent()
	var first := true
	for group in Tooltips.synergy_groups(type):
		var grid: GridContainer = _members
		if group.key != "shop": # caption above every group but the shop's
			var caption := UiStyle.label(group.label, 12, UiStyle.TEXT_DIM)
			parent.add_child(caption)
			if first:
				parent.move_child(caption, _members.get_index())
		if not first:
			grid = GridContainer.new()
			grid.columns = _members.columns
			grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_theme_constant_override("h_separation", 4)
			grid.add_theme_constant_override("v_separation", 4)
			parent.add_child(grid)
		first = false
		for pkm in group.pokemons:
			var member: SynergyMember = UiScenes.make(UiScenes.SYNERGY_MEMBER)
			member.pkm = pkm
			var family := String(GameData.get_pokemon(pkm).get("family", pkm))
			member.owned = owned.has(family) or (PlayerState.FLABEBE_FORMS.has(family) and player != null
				and owned.has(player.flower_color))
			member.locked = player != null and Tooltips.unlock_info(pkm, player).state == "locked"
			member.player = player
			member.level = level + 1
			grid.add_child(member)
