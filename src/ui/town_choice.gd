class_name TownChoice
extends PanelContainer

## Town choices (Town): pick a portal (its synergy symbols and the region it leads to),
## then a Pokémon (shop card, with the component that comes with it).
## Stays open until picked; the game keeps running. Scene: scenes/ui/town_choice.tscn

signal portal_chosen(index: int)
signal pokemon_chosen(index: int)

const SHOP_CARD := "res://scenes/ui/shop_card.tscn"

@onready var _title: Label = %Title
@onready var _info: RichTextLabel = %Info
@onready var _row: HBoxContainer = %Row


## portals: [{synergies: [types], map}].
func show_portals(portals: Array, title: String, info := "") -> void:
	_open(title, info)
	for i in portals.size():
		var portal: Dictionary = portals[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(170, 150)
		b.focus_mode = Control.FOCUS_NONE
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := UiStyle.label(map_name(portal.map), 15, UiStyle.GOLD)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.custom_minimum_size = Vector2(150, 0)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(name_label)
		for t in portal.synergies:
			var row := TypeRow.create(t, 15)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(row)
		var unlocks: Array = portal.get("unlocks", [])
		if not unlocks.is_empty(): # the region's synergies the pass has not: unlocked for the run once there
			var line := HBoxContainer.new()
			line.alignment = BoxContainer.ALIGNMENT_CENTER
			line.add_theme_constant_override("separation", 3)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.add_child(UiStyle.label(L.t("Unlocks"), 12, UiStyle.GREEN))
			for t in unlocks:
				line.add_child(UiStyle.icon_rect(GameData.type_icon(t), 20.0))
			v.add_child(line)
		b.add_child(v)
		var index := i
		b.pressed.connect(func() -> void: _pick(func() -> void: portal_chosen.emit(index)))
		HoverTip.add(b, func() -> Control:
			var names: Array = portal.synergies.map(func(t: String) -> String: return GameData.synergy_name(t))
			var body := L.t("The Pokémon offered will have these synergies: %s") % ", ".join(names)
			if not unlocks.is_empty():
				body += "\n" + L.t("Reaching this region unlocks for this run: %s") % ", ".join(
					unlocks.map(func(t: String) -> String: return GameData.synergy_name(t)))
			return Tooltips.text(L.t("Portal to %s") % map_name(portal.map), body), HoverTip.Side.BOTTOM)
		_row.add_child(b)


## pokemons (+ the item given with each one, if any).
func show_pokemons(pokemons: Array, items: Array, title: String, info := "") -> void:
	_open(title, info)
	for i in pokemons.size():
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		_row.add_child(v)
		var index := i
		var members: PackedStringArray = String(pokemons[i]).split("+") # a duo: both cards
		var cards := HBoxContainer.new()
		cards.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(cards)
		for member in members:
			var card: ShopCard = UiScenes.make(SHOP_CARD)
			card.pkm = member
			cards.add_child(card)
			card.show_pokemon(member, true)
			card.pressed.connect(func() -> void: _pick(func() -> void: pokemon_chosen.emit(index)))
		if i < items.size() and items[i] != "":
			var item: String = items[i]
			var h := HBoxContainer.new()
			h.alignment = BoxContainer.ALIGNMENT_CENTER
			h.mouse_filter = Control.MOUSE_FILTER_STOP
			h.add_child(UiStyle.icon_rect(GameData.item_icon(item), 28))
			h.add_child(UiStyle.label("+ " + GameData.item_name(item), 13))
			HoverTip.add(h, func() -> Control: return Tooltips.item(item), HoverTip.Side.BOTTOM)
			v.add_child(h)


static func map_name(map: String) -> String:
	return String(GameData.text.get("map", {}).get(map, map))


func _open(title: String, info: String) -> void:
	_title.text = title
	_info.text = GameText.format(info)
	_info.visible = info != ""
	for c in _row.get_children():
		c.queue_free()
	visible = true


func _pick(emit: Callable) -> void:
	visible = false
	if HoverTip.current:
		HoverTip.current.close_all()
	emit.call()
