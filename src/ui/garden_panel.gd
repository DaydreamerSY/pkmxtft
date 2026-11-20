class_name GardenPanel
extends HBoxContainer

## Top left of the HUD: the Grass berry trees and the Flora flower pots (web sprites on
## the board side).
##   tree  one button per growing tree (Grass tier): its berry, growth bar, glowing when
##         ripe; click a ripe tree = pick its berry (SynergyItems.pick_berry)
##   pot   the 5 pots (Flora active): the Pokémon that blossoms from it, dimmed while locked
## Mulch dragged from the item bench is dropped on a pot / tree (target_at()).

signal berry_picked(index: int)

const SIZE := 54.0
## Compact HUD: trees and pots small enough for the whole garden to be as wide as the left column.
const COMPACT_TREE := 38.0
const COMPACT_POT := 31.0

var _buttons: Array[Button] = []
var _bars: Array[ProgressBar] = []
var _ripe_tweens: Array = [null, null, null]
var _pots: Array[TextureRect] = []
var _pot_box: HBoxContainer
var _player: PlayerState


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		add_child(box)
		var b := Button.new()
		b.custom_minimum_size = Vector2(SIZE, SIZE)
		b.focus_mode = Control.FOCUS_NONE
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(func() -> void: berry_picked.emit(i))
		box.add_child(b)
		HoverTip.add(b, func() -> Control: return _tree_tip(i), HoverTip.Side.BOTTOM)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(SIZE, 6)
		bar.show_percentage = false
		bar.max_value = SynergyItems.BERRY_TREE_RIPE
		box.add_child(bar)
		_buttons.append(b)
		_bars.append(bar)
	_pot_box = HBoxContainer.new()
	_pot_box.add_theme_constant_override("separation", 4)
	add_child(_pot_box)
	for i in 5:
		var pot := TextureRect.new()
		pot.custom_minimum_size = Vector2(SIZE - 8, SIZE - 8)
		pot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pot.mouse_filter = Control.MOUSE_FILTER_PASS
		_pot_box.add_child(pot)
		HoverTip.add(pot, func() -> Control: return _pot_tip(i), HoverTip.Side.BOTTOM)
		_pots.append(pot)
	visible = false


## Compact HUD (phones): smaller trees and pots, so that the garden is not wider than the item bench and
## the synergies under it (it shares the top row with the stage bar).
func set_compact(on: bool) -> void:
	var tree := COMPACT_TREE if on else SIZE
	var pot := COMPACT_POT if on else SIZE - 8.0
	if _buttons.is_empty() or is_equal_approx(_buttons[0].custom_minimum_size.x, tree):
		return
	add_theme_constant_override("separation", 4 if on else 6)
	_pot_box.add_theme_constant_override("separation", 3 if on else 4)
	for i in _buttons.size():
		_buttons[i].custom_minimum_size = Vector2(tree, tree)
		_bars[i].custom_minimum_size = Vector2(tree, 5 if on else 6)
	for texture in _pots:
		texture.custom_minimum_size = Vector2(pot, pot)
	reset_size()


func refresh(player: PlayerState) -> void:
	_player = player
	var trees := mini(player.synergy_tier("GRASS"), 3)
	var flora := player.synergy_tier("FLORA") > 0
	visible = trees > 0 or flora
	var golden := player.synergy_tier("GRASS") >= 4
	for i in 3:
		var box: Control = _buttons[i].get_parent()
		box.visible = i < trees
		if i >= trees:
			continue
		var berry: String = SynergyItems.GOLDEN_BERRIES[i] if golden else player.berry_tree_types[i]
		var ripe := player.berry_tree_stages[i] >= SynergyItems.BERRY_TREE_RIPE
		_buttons[i].icon = GameData.item_icon(berry)
		_buttons[i].modulate = Color.WHITE if ripe else Color(0.55, 0.6, 0.55)
		_bars[i].value = player.berry_tree_stages[i]
		_set_ripe_pulse(i, ripe)
	_pot_box.visible = flora
	var unlocked := SynergyItems.pots_unlocked(player)
	for i in 5:
		_pots[i].texture = GameData.portrait(player.flower_pots[i])
		_pots[i].modulate = Color.WHITE if unlocked.has(i) else Color(0.35, 0.35, 0.35, 0.8)


## Pot / tree under a screen point: {"pot": i} or {"tree": i}, {} if none.
func target_at(pos: Vector2) -> Dictionary:
	if not visible:
		return {}
	for i in 3:
		if _buttons[i].is_visible_in_tree() and _buttons[i].get_global_rect().has_point(pos):
			return {"tree": i}
	for i in 5:
		if _pots[i].is_visible_in_tree() and _pots[i].get_global_rect().has_point(pos):
			return {"pot": i}
	return {}


func _set_ripe_pulse(i: int, ripe: bool) -> void:
	if ripe == (_ripe_tweens[i] != null):
		return
	if _ripe_tweens[i] != null:
		_ripe_tweens[i].kill()
		_ripe_tweens[i] = null
		_buttons[i].self_modulate = Color.WHITE
		return
	var t := create_tween().set_loops()
	t.tween_property(_buttons[i], "self_modulate", Color(1.4, 1.4, 1.0), 0.5)
	t.tween_property(_buttons[i], "self_modulate", Color.WHITE, 0.5)
	_ripe_tweens[i] = t


func _tree_tip(i: int) -> Control:
	if _player == null:
		return null
	var golden := _player.synergy_tier("GRASS") >= 4
	var berry: String = SynergyItems.GOLDEN_BERRIES[i] if golden else _player.berry_tree_types[i]
	var stage: int = _player.berry_tree_stages[i]
	var hint := L.t("Ripe: click to pick the berry.") if stage >= SynergyItems.BERRY_TREE_RIPE \
		else L.t("Ripe in %d stage(s).") % (SynergyItems.BERRY_TREE_RIPE - stage)
	return Tooltips.item(berry, L.t("Berry tree") + "  •  " + hint)


func _pot_tip(i: int) -> Control:
	if _player == null:
		return null
	var pkm: String = _player.flower_pots[i]
	var order := SynergyItems.pots_unlocked(_player).find(i)
	var body := L.t("Blossoms in fights when a Flora Pokémon faints (%s).") % (
		L.t("pot %d") % (order + 1) if order >= 0 else L.t("locked"))
	if not GameData.evolutions_of(pkm).is_empty():
		body += "\n" + L.t("Drop a Rich Mulch here to grow it.")
	return Tooltips.text(L.t("Flower pot") + ": " + GameData.display_name(pkm), body)
