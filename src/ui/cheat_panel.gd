class_name CheatPanel
extends PanelContainer

## Cheats for playtesting and balancing (not in the web game): F1 in a run, when "cheats" is on in
## data/difficulty.json. Built in code, Vietnamese texts like the other dev tool (tools/wave_editor).
## Every action goes through the Game (`cheat_*`) so the views, the HUD and the phases follow.

const WIDTH := 440.0
const LIST_HEIGHT := 110.0
const LIST_LIMIT := 150 ## rows shown by a search list

var game: Game

var _built := false
var _status: Label
var _god: CheckBox
var _free_rolls: CheckBox
var _stage: SpinBox
var _maps: OptionButton
var _map_ids: Array[String] = []
var _pkm_filter: LineEdit
var _pkm_list: ItemList
var _item_filter: LineEdit
var _item_list: ItemList


func _ready() -> void:
	theme_type_variation = &"HudPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -WIDTH - 16.0
	offset_right = -16.0
	offset_top = 110.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN # stays on screen if a row gets wider


## F1: opens (built on first use) or closes the panel.
func toggle() -> void:
	if not _built:
		_build()
	visible = not visible
	if visible:
		_refresh()


func _build() -> void:
	_built = true
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size.x = WIDTH
	add_child(v)
	var head := HBoxContainer.new()
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Cheat  (F1)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("×", func() -> void: visible = false))
	v.add_child(head)

	_section(v, "Người chơi")
	var row := _row(v)
	row.add_child(_button("+10 vàng", func() -> void: _done(game.cheat_gold(10))))
	row.add_child(_button("+100 vàng", func() -> void: _done(game.cheat_gold(100))))
	row.add_child(_button("+1 cấp", func() -> void: _done(game.cheat_level(1))))
	row.add_child(_button("Cấp max", func() -> void: _done(game.cheat_level(99))))
	row = _row(v)
	row.add_child(_button("+20 máu", func() -> void: _done(game.cheat_life(20))))
	row.add_child(_button("-20 máu", func() -> void: _done(game.cheat_life(-20))))
	_god = _check("Không mất máu", func(on: bool) -> void: game.cheat_no_life_loss = on)
	row.add_child(_god)
	row = _row(v)
	_free_rolls = _check("Đổi shop miễn phí", func(on: bool) -> void: game.cheat_free_reroll = on)
	row.add_child(_free_rolls)

	_section(v, "Trận / stage")
	row = _row(v)
	row.add_child(_button("Thắng trận này", func() -> void: _done(game.cheat_win())))
	row.add_child(_label("Tới stage"))
	_stage = SpinBox.new()
	_stage.min_value = 1
	_stage.max_value = 500
	row.add_child(_stage)
	row.add_child(_button("Đi", func() -> void: _done(game.cheat_stage(int(_stage.value)))))
	row = _row(v)
	row.add_child(_button("Mở hết additional", func() -> void: _done(game.cheat_unlock_additional())))
	_maps = OptionButton.new()
	_maps.fit_to_longest_item = false
	_maps.clip_text = true
	_maps.custom_minimum_size.x = 200.0
	_maps.add_theme_font_size_override("font_size", 14)
	var maps: Dictionary = GameData.config.get("maps", {})
	_map_ids.assign(maps.keys())
	_map_ids.sort_custom(func(a: String, b: String) -> bool: return TownChoice.map_name(a) < TownChoice.map_name(b))
	for m in _map_ids:
		_maps.add_item("%s  (%s)" % [TownChoice.map_name(m), " ".join(maps[m].get("synergies", []))])
	row.add_child(_maps)
	row.add_child(_button("Đổi vùng", func() -> void:
		if _maps.selected >= 0:
			_done(game.cheat_map(_map_ids[_maps.selected]))))

	_section(v, "Thêm Pokémon vào bench (gõ tên, id hoặc hệ; dạng tiến hoá = nhiều sao)")
	_pkm_filter = _search(v, _fill_pokemon)
	_pkm_list = _list(v, func(i: int) -> void: _done(game.cheat_give_pokemon(String(_pkm_list.get_item_metadata(i)))))
	row = _row(v)
	row.add_child(_button("Thêm vào bench", func() -> void:
		for i in _pkm_list.get_selected_items():
			_done(game.cheat_give_pokemon(String(_pkm_list.get_item_metadata(i))))))
	row.add_child(_button("Xoá bench", func() -> void: _done(game.cheat_clear_bench())))

	_section(v, "Thêm item (gõ tên hoặc id)")
	_item_filter = _search(v, _fill_items)
	_item_list = _list(v, func(i: int) -> void: _done(game.cheat_give_item(String(_item_list.get_item_metadata(i)))))
	row = _row(v)
	row.add_child(_button("Thêm vào kho item", func() -> void:
		for i in _item_list.get_selected_items():
			_done(game.cheat_give_item(String(_item_list.get_item_metadata(i))))))

	_status = _label("")
	_status.add_theme_color_override("font_color", UiStyle.GREEN)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	_fill_pokemon("")
	_fill_items("")


func _refresh() -> void:
	_stage.value = game.player.stage + 1
	_god.set_pressed_no_signal(game.cheat_no_life_loss)
	_free_rolls.set_pressed_no_signal(game.cheat_free_reroll)
	var current := _map_ids.find(game.player.map)
	if current >= 0:
		_maps.select(current)


## Pokémon whose id, name or a type matches `text` (every one the port can show), cheapest first.
func _fill_pokemon(text: String) -> void:
	var needle := text.strip_edges().to_lower()
	var found: Array[String] = []
	for pkm in GameData.pokemon:
		if not GameData.is_available(pkm):
			continue
		var data := GameData.get_pokemon(pkm)
		if needle == "" or pkm.to_lower().contains(needle) or GameData.display_name(pkm).to_lower().contains(needle) \
				or _has_type(data.get("types", []), needle):
			found.append(pkm)
	found.sort_custom(func(a: String, b: String) -> bool:
		var da := GameData.get_pokemon(a)
		var db := GameData.get_pokemon(b)
		var ca := GameData.rarity_cost(da.rarity) * 10 + int(da.stars)
		var cb := GameData.rarity_cost(db.rarity) * 10 + int(db.stars)
		return ca < cb or (ca == cb and GameData.display_name(a) < GameData.display_name(b)))
	_pkm_list.clear()
	for pkm in found.slice(0, LIST_LIMIT):
		var data := GameData.get_pokemon(pkm)
		var i := _pkm_list.add_item("%s   %d★  %s  [%s]" % [GameData.display_name(pkm), int(data.stars),
			GameData.rarity_name(data.rarity), " ".join(data.get("types", []))], GameData.portrait(pkm))
		_pkm_list.set_item_metadata(i, pkm)
		_pkm_list.set_item_custom_fg_color(i, GameData.RARITY_COLORS.get(data.rarity, UiStyle.TEXT).lightened(0.3))
	if found.size() > LIST_LIMIT:
		_pkm_list.add_item("… còn %d kết quả, gõ thêm để lọc" % (found.size() - LIST_LIMIT), null, false)


## A type typed in full: its id (fire) or its name in the game language (lửa).
static func _has_type(types: Array, needle: String) -> bool:
	for t in types:
		if String(t).to_lower() == needle or GameData.synergy_name(t).to_lower() == needle:
			return true
	return false


func _fill_items(text: String) -> void:
	var needle := text.strip_edges().to_lower()
	var found: Array[String] = []
	for item in GameData.items:
		if needle == "" or item.to_lower().contains(needle) or GameData.item_name(item).to_lower().contains(needle):
			found.append(item)
	found.sort_custom(func(a: String, b: String) -> bool: return GameData.item_name(a) < GameData.item_name(b))
	_item_list.clear()
	for item in found.slice(0, LIST_LIMIT):
		var i := _item_list.add_item("%s   (%s)" % [GameData.item_name(item), item], GameData.item_icon(item))
		_item_list.set_item_metadata(i, item)
	if found.size() > LIST_LIMIT:
		_item_list.add_item("… còn %d kết quả, gõ thêm để lọc" % (found.size() - LIST_LIMIT), null, false)


## Result of an action: "" = done (generic), else its message.
func _done(message: String) -> void:
	if _status != null:
		_status.text = message if message != "" else "OK"


#region widgets
func _section(parent: Control, text: String) -> void:
	var l := _label(text)
	l.add_theme_color_override("font_color", UiStyle.GOLD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)


func _row(parent: Control) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 4)
	parent.add_child(row)
	return row


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(action)
	return b


func _check(text: String, toggled: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 14)
	c.toggled.connect(toggled)
	return c


func _search(parent: Control, on_change: Callable) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = "Tìm..."
	e.clear_button_enabled = true
	e.add_theme_font_size_override("font_size", 14)
	e.text_changed.connect(on_change)
	parent.add_child(e)
	return e


## Double click / Enter on a row = its action; several rows can be selected for the button.
func _list(parent: Control, activate: Callable) -> ItemList:
	var l := ItemList.new()
	l.custom_minimum_size = Vector2(WIDTH, LIST_HEIGHT)
	l.fixed_icon_size = Vector2i(28, 28)
	l.select_mode = ItemList.SELECT_MULTI
	l.add_theme_font_size_override("font_size", 14)
	l.item_activated.connect(activate)
	parent.add_child(l)
	return l
#endregion
