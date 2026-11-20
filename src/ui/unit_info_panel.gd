class_name UnitInfoPanel
extends PanelContainer

## Details of a Pokémon (right click on it), docked on the right like the TFT unit panel:
##   stars (rank)                     empty stars = evolutions still to come
##   portrait banner + synergies      hover a synergy: synergy tooltip
##   name + sell value (or cost)
##   HP and PP bars                   live during a fight
##   ability | position | range       hover: ability text + cells (Phase 2), suggested row, range cells
##   3 item slots                     hover: item; right click: recipes
##   role                             hover: suggested position and items
##   stats                            hover: what the stat does, base + bonus
## Everything is read from a BattleUnit: the fighting one, or a preview with the held items.
## Scene: scenes/ui/unit_info_panel.tscn
##
## Compact HUD (phones, set_compact): the same parts in about half the height, so that the panel fits
## between the top of the screen and the Fight button:
##   portrait | name, sell value               HP bar | PP bar
##   (stars)  | synergies, [Passive]           ability diagram | 3 items
##                                                             | position, range
##   stats (5 x 2)                                             | role
## The passive text and the legend of the diagram move to tooltips (the Passive chip, the diagram).

## Star icons of the rank row (filled / evolution to come).
@export var star_icon: Texture2D = preload("res://assets/icons/star.svg")
@export var star_empty_icon: Texture2D = preload("res://assets/icons/star_empty.svg")

var _info: Dictionary = {}
var _unit: BattleUnit ## live (fight) or preview
var _live := false

@onready var _stars: HBoxContainer = %Stars
@onready var _portrait: TextureRect = %Portrait
@onready var _types: VBoxContainer = %Types
@onready var _name: Label = %Name
@onready var _value: Label = %Value
@onready var _hp_bar: ValueBar = %HpBar
@onready var _pp_bar: ValueBar = %PpBar
@onready var _skill_box: PanelContainer = %SkillBox
@onready var _skill_view: AbilityShapeView = %SkillView
@onready var _position_box: PanelContainer = %PositionBox
@onready var _position: Label = %Position
@onready var _range_box: PanelContainer = %RangeBox
@onready var _range: Label = %Range
@onready var _role_chip: PanelContainer = %RoleChip
@onready var _role: Label = %Role
@onready var _passive: RichTextLabel = %Passive
@onready var _item_slots: Array[ItemSlot] = []
@onready var _stat_cells: Array[StatCell] = []
@onready var _body: VBoxContainer = $V
@onready var _banner: PanelContainer = %Portrait.get_parent()
@onready var _name_row: HBoxContainer = %Name.get_parent()
@onready var _row3: HBoxContainer = %SkillBox.get_parent()
@onready var _items: HBoxContainer = %Items
@onready var _stats: GridContainer = %Stats

## Compact: the name shrinks from its font size down to this to stay whole next to the stars.
const NAME_FONT := 20
const MIN_NAME_FONT := 13

var _compact := false
## Compact only (kept out of the tree otherwise):
var _header: HBoxContainer ## portrait | _head_text
var _head_text: VBoxContainer ## name row, _type_flow
var _type_flow: HFlowContainer ## synergies and the Passive chip, in lines
var _bars: HBoxContainer ## HP | PP
var _side: VBoxContainer ## right of the ability diagram: items, _chips, role
var _chips: HBoxContainer ## position | range


func _ready() -> void:
	for child in %Items.get_children():
		if child is ItemSlot:
			_item_slots.append(child)
	for child in %Stats.get_children():
		if child is StatCell:
			_stat_cells.append(child)
	_name.resized.connect(_fit_name)
	HoverTip.add(_value, func() -> Control:
		var owned: bool = _info.get("owned", false)
		return Tooltips.text(L.t("Sell value") if owned else L.t("Cost"),
			L.t("Gold you get by dropping it on the shop.") if owned else L.t("Price of this Pokémon in the shop.")), HoverTip.Side.LEFT)
	HoverTip.add(_hp_bar, func() -> Control: return _stat_tip("HP"), HoverTip.Side.LEFT)
	HoverTip.add(_pp_bar, func() -> Control: return _stat_tip("PP"), HoverTip.Side.LEFT)
	HoverTip.add(_skill_box, func() -> Control: return Tooltips.skill(_info.get("pkm", ""), _info.get("skill", "")), HoverTip.Side.LEFT)
	HoverTip.add(_position_box, func() -> Control:
		var role := UnitRoles.info(UnitRoles.role_of(_info.get("pkm", "")))
		if role.front:
			return Tooltips.text(L.t("Suggested position: front row"), L.t("As a %s it should stand in the front row, facing the enemies. Your side is the 3 rows under the middle line; row 3 is the front.") % L.t(role.name))
		return Tooltips.text(L.t("Suggested position: back row"), L.t("As a %s it should stand in the back rows, behind the tanks. Your side is the 3 rows under the middle line; row 3 is the front.") % L.t(role.name)),
		HoverTip.Side.LEFT)
	HoverTip.add(_range_box, func() -> Control:
		var r := _unit.attack_range if _unit != null else 1
		var body := L.t("Attacks the enemies in the 6 cells around.") if r == 1 \
			else L.t("Attacks enemies up to %d cells away, diagonals included (a %dx%d square).") % [r, 2 * r + 1, 2 * r + 1]
		if String(_info.get("cell_text", "")) != "":
			body += "\n" + String(_info.cell_text)
		return Tooltips.text(L.t("Attack range %d") % r, body), HoverTip.Side.LEFT)
	for i in _item_slots.size():
		var slot := _item_slots[i]
		HoverTip.add(slot, func() -> Control:
			return Tooltips.item(slot.item, L.t("Right click: recipes")) if slot.item != "" else null, HoverTip.Side.LEFT)
		slot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				if slot.item != "" and HoverTip.current:
					HoverTip.current.toggle(slot, Tooltips.recipes(slot.item), HoverTip.Side.LEFT)
				accept_event())
	HoverTip.add(_role_chip, func() -> Control:
		return Tooltips.role(UnitRoles.role_of(_info.get("pkm", ""))), HoverTip.Side.LEFT, 0, true)
	for cell in _stat_cells:
		var stat_id := cell.stat
		HoverTip.add(cell, func() -> Control: return _stat_tip(stat_id), HoverTip.Side.LEFT)


## Compact HUD (phones): the parts are moved to the compact arrangement (see the top of the file), or
## back to the order of the scene.
func set_compact(on: bool) -> void:
	if on == _compact:
		return
	_compact = on
	if on:
		if _header == null:
			_header = HBoxContainer.new()
			_header.add_theme_constant_override("separation", 8)
			_head_text = VBoxContainer.new()
			_head_text.add_theme_constant_override("separation", 3)
			_head_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_head_text.alignment = BoxContainer.ALIGNMENT_CENTER
			_header.add_child(_head_text)
			_type_flow = HFlowContainer.new()
			_type_flow.add_theme_constant_override("h_separation", 10)
			_type_flow.add_theme_constant_override("v_separation", 2)
			_bars = HBoxContainer.new()
			_bars.add_theme_constant_override("separation", 6)
			_side = VBoxContainer.new()
			_side.add_theme_constant_override("separation", 4)
			_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_chips = HBoxContainer.new()
			_chips.add_theme_constant_override("separation", 4)
		_body.add_child(_header)
		_body.move_child(_header, 0)
		_banner.reparent(_header, false)
		_header.move_child(_banner, 0)
		_name_row.reparent(_head_text, false)
		_stars.reparent(_banner, false) # over the bottom of the portrait: the name keeps the whole line
		_head_text.add_child(_type_flow)
		_body.add_child(_bars)
		_body.move_child(_bars, 1)
		_hp_bar.reparent(_bars, false)
		_pp_bar.reparent(_bars, false)
		_row3.add_child(_side)
		_items.reparent(_side, false)
		_side.add_child(_chips)
		_position_box.reparent(_chips, false)
		_range_box.reparent(_chips, false)
		_role_chip.reparent(_side, false)
	else:
		# the order of the scene: Stars, Banner, NameRow, HpBar, PpBar, Row3 (SkillBox, PositionBox, RangeBox),
		# Items, RoleChip, Passive, Sep, Stats
		var order: Array[Control] = [_stars, _banner, _name_row, _hp_bar, _pp_bar]
		for i in order.size():
			order[i].reparent(_body, false)
			_body.move_child(order[i], i)
		_position_box.reparent(_row3, false)
		_range_box.reparent(_row3, false)
		_items.reparent(_body, false)
		_role_chip.reparent(_body, false)
		_head_text.remove_child(_type_flow)
		_side.remove_child(_chips)
		_row3.remove_child(_side)
		_body.remove_child(_header)
		_body.remove_child(_bars)
		_body.move_child(_row3, 5)
		_body.move_child(_items, 6)
		_body.move_child(_role_chip, 7)
	_body.add_theme_constant_override("separation", 5 if on else 6)
	# portrait: a square thumbnail left of the name, or the wide banner under the stars
	_banner.custom_minimum_size = Vector2(64, 64) if on else Vector2(0, 150)
	_banner.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if on else Control.SIZE_FILL
	_banner.size_flags_vertical = Control.SIZE_SHRINK_CENTER if on else Control.SIZE_FILL
	(_types.get_parent() as Control).visible = not on
	_stars.size_flags_vertical = Control.SIZE_SHRINK_END if on else Control.SIZE_FILL
	# bars side by side
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.size_flags_stretch_ratio = 1.5 if on else 1.0
	_pp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pp_bar.custom_minimum_size.y = 20.0 if on else 16.0
	# ability diagram: smaller cells, its legend in the tooltip; the boxes right of it become chips
	_skill_view.cell_px = 17.0 if on else 22.0
	_skill_view.show_legend = not on
	_skill_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if on else Control.SIZE_EXPAND_FILL
	for box in [_position_box, _range_box]:
		box.custom_minimum_size.y = 27.0 if on else 58.0
	_position.add_theme_font_size_override("font_size", 14 if on else 15)
	_range.add_theme_font_size_override("font_size", 16 if on else 20)
	(_range.get_parent().get_node("RangeIcon") as Control).custom_minimum_size = Vector2(17, 17) if on else Vector2(22, 22)
	_role.add_theme_font_size_override("font_size", 14 if on else 16)
	# items: smaller slots right of the diagram
	_items.add_theme_constant_override("separation", 4 if on else 8)
	for slot in _item_slots:
		slot.custom_minimum_size = Vector2(40, 40) if on else Vector2(58, 58)
		(slot.get_node("%Icon") as Control).custom_minimum_size = Vector2(32, 32) if on else Vector2(46, 46)
	# stats: lower cells; no separator line
	(_body.get_node("Sep") as Control).visible = not on
	_stats.add_theme_constant_override("v_separation", 4 if on else 6)
	for cell in _stat_cells:
		(cell.get_node("%Icon") as Control).custom_minimum_size = Vector2(19, 19) if on else Vector2(22, 22)
		(cell.get_node("%Value") as Control).add_theme_font_size_override("font_size", 14 if on else 15)
	_fit_name()
	if visible and not _info.is_empty():
		show_unit(_info)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# the compact helpers out of the tree (scene layout) are nobody's children
		for node in [_header, _type_flow, _bars, _side, _chips]:
			if node != null and is_instance_valid(node) and node.get_parent() == null:
				node.free()


## Compact: the largest font (NAME_FONT down to MIN_NAME_FONT) that shows the whole name in its room.
func _fit_name() -> void:
	var font_size := NAME_FONT
	if _compact:
		var font := _name.get_theme_font("font")
		while font_size > MIN_NAME_FONT and font.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > _name.size.x:
			font_size -= 1
	if _name.get_theme_font_size("font_size") != font_size:
		_name.add_theme_font_size_override("font_size", font_size)


## The container of the synergy rows: on the portrait banner, or (compact) in lines under the name.
func _type_box() -> Container:
	return _type_flow if _compact else _types


## Compact: the passive is a chip after the synergies; its text is the tooltip of the chip.
func _passive_chip(text: String) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiStyle.chip(Color(UiStyle.GOLD, 0.9), [9, 0, 9, 0]))
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	var label := UiStyle.label(L.t("Passive"), 13, UiStyle.GOLD)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)
	HoverTip.add(chip, func() -> Control:
		var tip := Tooltips.text(L.t("Passive"), text) # the tooltip formats the keywords itself
		tip.custom_minimum_size.x = 340.0
		return tip, HoverTip.Side.LEFT)
	return chip


## info: {pkm, unit (BattleUnit fighting, or a preview with its stats, or null), preview, items, owned, sell,
## team, cell_text, player}
func show_unit(info: Dictionary) -> void:
	var data := GameData.get_pokemon(info.get("pkm", ""))
	if data.is_empty():
		hide()
		return
	# the same Pokémon refreshed (a preview unit is rebuilt each time: same when both are previews)
	var same: bool = visible and _info.get("pkm") == info.pkm and (_info.get("unit") == info.get("unit")
		or (info.get("preview", false) and _info.get("preview", false)))
	_info = info
	_live = info.get("unit") != null
	if _live:
		_unit = info.unit
	else:
		_unit = BattleUnit.create(info.pkm, info.get("team", BattleUnit.Team.BLUE))
		_unit.equip(info.get("items", []))
	visible = true
	if not same and HoverTip.current:
		HoverTip.current.close_all()
	var pkm: String = info.pkm
	var rarity_color: Color = GameData.RARITY_COLORS.get(data.rarity, UiStyle.TEXT)
	remove_theme_stylebox_override("panel")
	var frame := get_theme_stylebox("panel")
	if UiStyle.is_frame(frame):
		var recolored := UiStyle.recolored(frame, null, rarity_color.darkened(0.2))
		if _compact and UiStyle.has_fill(recolored): # it lies over the player panel: nothing must show through
			recolored.set("bg_color", Color(recolored.get("bg_color"), 1.0))
		add_theme_stylebox_override("panel", recolored)

	for c in _stars.get_children():
		c.queue_free()
	var stars := int(data.stars)
	var max_stars := stars + GameData.family_stages(pkm) - 1
	for i in maxi(max_stars, stars):
		_stars.add_child(UiStyle.icon_rect(star_icon if i < stars else star_empty_icon, 14 if _compact else 20))

	_portrait.texture = GameData.portrait(pkm)
	for box in [_types, _type_flow]:
		if box != null:
			for c in box.get_children():
				c.queue_free()
	for t in _unit.types:
		var row := TypeRow.create(t, 14 if _compact else 15)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var type: String = t
		HoverTip.add(row, func() -> Control:
			var player: PlayerState = info.get("player")
			var count: int = SynergyList.count_types(player).get(type, 0) if player != null else 0
			var owned := SynergyList.owned_families(player) if player != null else {}
			var extra := Synergies.context_text(type, player) if player != null else ""
			return Tooltips.synergy(type, count, owned, 0, extra, player), HoverTip.Side.LEFT, 0, true)
		_type_box().add_child(row)
	var passive_text := GameData.passive_desc(_unit.passive)
	_passive.visible = passive_text != "" and not _compact
	if passive_text != "":
		_passive.text = "[b]%s[/b]  " % L.t("Passive") + GameText.format(passive_text, 13)
		if _compact:
			_type_flow.add_child(_passive_chip(passive_text))

	_name.text = GameData.display_name(pkm)
	_name.add_theme_color_override("font_color", rarity_color.lightened(0.35))
	_fit_name()
	_value.text = str(info.get("sell", GameData.rarity_cost(data.rarity)))
	_skill_view.show_pokemon(pkm)
	var role := UnitRoles.info(UnitRoles.role_of(pkm))
	_position.text = L.t("Front") if role.front else L.t("Back")
	_position.add_theme_color_override("font_color", Color(1.0, 0.75, 0.45) if role.front else Color(0.6, 0.8, 1.0))
	_role.text = L.t(role.name)
	_role.add_theme_color_override("font_color", role.color)
	_role_chip.add_theme_stylebox_override("panel", UiStyle.chip(role.color, [12, 2, 12, 2]))
	_refresh_values()


func _process(_delta: float) -> void:
	if visible and _live:
		_refresh_values()


func _refresh_values() -> void:
	if _unit == null:
		return
	_hp_bar.set_values(ceilf(_unit.hp) if _live else _unit.max_hp, _unit.max_hp)
	_pp_bar.set_values(_unit.pp, _unit.max_pp)
	_range.text = " %d" % _unit.attack_range
	for i in _item_slots.size():
		var item: String = _unit.items[i] if i < _unit.items.size() else ""
		if _item_slots[i].item != item:
			_item_slots[i].set_item(item)
	for cell in _stat_cells:
		cell.set_value(Tooltips.format_stat(cell.stat, _stat_value(cell.stat)))


func _stat_value(stat: String) -> float:
	match stat:
		"HP": return _unit.max_hp
		"ATK": return _unit.atk
		"AP": return _unit.ap
		"DEF": return _unit.def
		"SPE_DEF": return _unit.spe_def
		"SPEED": return _unit.speed
		"CRIT_CHANCE": return _unit.crit_chance
		"CRIT_POWER": return _unit.crit_power
		"SHIELD": return _unit.shield
		"LUCK": return _unit.luck
		"PP": return _unit.max_pp
	return 0.0


## Value of the stat without items and buffs (the Pokémon data).
func _base_value(stat: String) -> float:
	var data := GameData.get_pokemon(_info.get("pkm", ""))
	match stat:
		"HP": return float(data.get("hp", 0))
		"ATK": return float(data.get("atk", 0))
		"DEF": return float(data.get("def", 0))
		"SPE_DEF": return float(data.get("speDef", 0))
		"SPEED": return float(data.get("speed", 0))
		"PP": return Difficulty.max_pp_of(float(data.get("maxPP", 100)))
		"AP": return float(data.get("ap", 0)) # the auto balance (data/balance.json)
		"CRIT_CHANCE": return 10.0
		"CRIT_POWER": return 2.0
	return 0.0


func _stat_tip(stat: String) -> Control:
	if _unit == null:
		return null
	return Tooltips.stat(stat, _stat_value(stat), _base_value(stat), String(_info.get("pkm", "")))
