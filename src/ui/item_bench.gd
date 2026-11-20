class_name ItemBench
extends VBoxContainer

## Item bench on the left edge of the screen (TFT), in pages: Endless runs collect far
## more items than fit, so the slots show one page of PAGE_SIZE items and the pager
## under them (or the mouse wheel over the slots) turns pages. On top, the Item
## Remover: a tool, not an item (unlimited uses), dropped on a Pokémon it sends
## all its items back here (PlayerState.strip_items).
## Scene: scenes/ui/item_bench.tscn (its 10 slots = one page).
##   hover        item tooltip
##   right click  recipes (pinned, rows have their own tooltip)
##   drag         drop the item on a Pokémon (the game handles the drop)

## `index`: index in PlayerState.items, or REMOVER for the Item Remover.
signal drag_started(index: int)

const REMOVER := -2
## Compact HUD: height of a slot with its gap, and of everything but the slots (remover, gap, pager).
const SLOT_PITCH := 58.0
const COMPACT_EXTRA := 124.0

var page := 0

var _items: Array[String] = []
var _slots: Array[ItemSlot] = [] ## the slots of a page (the first ones of the scene, see set_page_size)
var _all_slots: Array[ItemSlot] = []
var _remover: ItemSlot
var _pager: VBoxContainer
var _page_label: Label
var _prev: Button
var _next: Button
var _compact := false


func _ready() -> void:
	for child in get_children():
		if child is ItemSlot:
			_register(child)
	_build_remover()
	_build_pager()
	_refresh_page()


func page_size() -> int:
	return maxi(_slots.size(), 1)


## Compact HUD (phones): larger page buttons (fingers), and no pager at all while one page holds
## every item.
func set_compact(on: bool) -> void:
	if on == _compact:
		return
	_compact = on
	for button in [_prev, _next]:
		button.custom_minimum_size = Vector2(29, 34) if on else Vector2(25, 24)
		button.add_theme_font_size_override("font_size", 14 if on else 12)
	_refresh_page()


## Slots of a page: the compact HUD shows fewer (the others are hidden).
func set_page_size(count: int) -> void:
	count = clampi(count, 1, _all_slots.size())
	if count == _slots.size():
		return
	_slots = _all_slots.slice(0, count)
	for i in _all_slots.size():
		_all_slots[i].visible = i < count
	page = clampi(page, 0, page_count() - 1)
	_refresh_page()


## Touch screens: a tap on an item (`index` in PlayerState.items, or REMOVER) pins its tooltip until a
## tap elsewhere - the press already starts a drag, so there is no hover to rely on.
func show_item_info(index: int) -> void:
	if HoverTip.current == null:
		return
	if index == REMOVER:
		HoverTip.current.show_tip(_remover, Tooltips.text(L.t("Item Remover"),
			L.t("Drag onto a Pokémon: all its items go back to the item bench, so you can move them without selling it. Unlimited uses.")),
			HoverTip.Side.RIGHT, 0, false, true)
		return
	var slot := index - page * page_size()
	var item := slot_item(index)
	if slot < 0 or slot >= _slots.size() or item == "":
		return
	HoverTip.current.show_tip(_slots[slot], Tooltips.item(item, L.t("Drag onto a Pokémon  •  hold: recipes")),
		HoverTip.Side.RIGHT, 0, false, true)


func page_count() -> int:
	return maxi(ceili(float(_items.size()) / page_size()), 1)


func set_items(items: Array[String]) -> void:
	var grew := items.size() > _items.size()
	_items = items.duplicate()
	# a new item: show the page it lands on (the last one)
	page = page_count() - 1 if grew else clampi(page, 0, page_count() - 1)
	_refresh_page()


func turn_page(delta: int) -> void:
	var p := clampi(page + delta, 0, page_count() - 1)
	if p == page:
		return
	page = p
	if HoverTip.current:
		HoverTip.current.close_all()
	_refresh_page()


## Item at `index` of PlayerState.items ("" if none).
func slot_item(index: int) -> String:
	return _items[index] if index >= 0 and index < _items.size() else ""


## Slot showing item `index` of PlayerState.items (turns to its page), null if none.
func slot_control(index: int) -> ItemSlot:
	if index < 0 or index >= _items.size():
		return null
	page = index / page_size()
	_refresh_page()
	return _slots[index % page_size()]


## Index in PlayerState.items of the filled slot under a screen point, -1 if none.
func slot_at(pos: Vector2) -> int:
	for i in _slots.size():
		var index := _item_index(i)
		if index < _items.size() and _slots[i].is_visible_in_tree() and _slots[i].get_global_rect().has_point(pos):
			return index
	return -1


## Dragging a component over another one (item `index`): tooltip of the item they make together.
func show_combine_preview(index: int, dragged: String) -> void:
	var slot := index - page * page_size()
	if slot < 0 or slot >= _slots.size():
		return
	var other := slot_item(index)
	var both := GameData.is_component(dragged) and GameData.is_component(other)
	var result := GameData.combine(dragged, other) if both else ""
	if result == "" or HoverTip.current == null:
		return
	HoverTip.current.show_tip(_slots[slot], Tooltips.item(result, L.t("%s + %s: drop both on the same Pokémon") % [
		GameData.item_name(dragged), GameData.item_name(other)]), HoverTip.Side.RIGHT, 0, false, false, &"TipPanelPinned")


func _item_index(slot: int) -> int:
	return page * page_size() + slot


func _refresh_page() -> void:
	for i in _slots.size():
		_slots[i].set_item(slot_item(_item_index(i)))
	if _page_label == null:
		return
	_pager.visible = not _compact or page_count() > 1
	_page_label.text = "%d/%d" % [page + 1, page_count()]
	_prev.disabled = page <= 0
	_next.disabled = page >= page_count() - 1


func _register(slot: ItemSlot) -> void:
	var i := _slots.size()
	_slots.append(slot)
	_all_slots.append(slot)
	slot.gui_input.connect(func(event: InputEvent) -> void: _on_slot_input(i, event))
	HoverTip.add(slot, func() -> Control:
		var item := slot_item(_item_index(i))
		return Tooltips.item(item, L.t("Drag onto a Pokémon  •  hold: recipes") if UiScale.touch
			else L.t("Drag onto a Pokémon  •  right click: recipes")) if item != "" else null)


func _on_slot_input(slot: int, event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			turn_page(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			accept_event()
			return
	var index := _item_index(slot)
	var item := slot_item(index)
	if item == "":
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if HoverTip.current:
			HoverTip.current.close_all()
		drag_started.emit(index)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if HoverTip.current:
			HoverTip.current.toggle(_slots[slot], Tooltips.recipes(item))
		accept_event()


## The Item Remover slot, gold framed, above the items.
func _build_remover() -> void:
	_remover = UiScenes.make(UiScenes.ITEM_SLOT)
	_remover.name = "ItemRemover"
	add_child(_remover)
	move_child(_remover, 0)
	_remover.set_item(PlayerState.ITEM_REMOVER)
	var frame: StyleBox = _remover.get_theme_stylebox("panel", _remover.filled_variation)
	if UiStyle.is_frame(frame):
		_remover.add_theme_stylebox_override("panel", UiStyle.recolored(frame, null, UiStyle.GOLD))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gap)
	move_child(gap, 1)
	_remover.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if HoverTip.current:
				HoverTip.current.close_all()
			drag_started.emit(REMOVER)
			accept_event())
	HoverTip.add(_remover, func() -> Control:
		return Tooltips.text(L.t("Item Remover"),
			L.t("Drag onto a Pokémon: all its items go back to the item bench, so you can move them without selling it. Unlimited uses.")))


## "n/m" and ◀ ▶ under the slots.
func _build_pager() -> void:
	var box := VBoxContainer.new()
	box.name = "Pager"
	box.add_theme_constant_override("separation", 1)
	add_child(box)
	_pager = box
	_page_label = UiStyle.label("1/1", 13, UiStyle.TEXT_DIM)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_page_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	_prev = _pager_button("◀", -1)
	_next = _pager_button("▶", 1)
	row.add_child(_prev)
	row.add_child(_next)
	for control in [_page_label, _prev, _next]:
		HoverTip.add(control, func() -> Control:
			return Tooltips.text(L.t("Item pages"), L.t("Page %d of %d. The mouse wheel over the items turns pages too.") % [
				page + 1, page_count()]), HoverTip.Side.RIGHT)


func _pager_button(text: String, delta: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(25, 24)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(turn_page.bind(delta))
	return b
