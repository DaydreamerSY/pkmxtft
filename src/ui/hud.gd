class_name Hud
extends CanvasLayer

## In-game UI, laid out like TFT (screenshot example/TFT-UI-breakdown.drawio):
##   top: stage bar + timer + speed        top right: life, level, menu
##   left edge: item bench                  left: synergies (hover: tiers + Pokémon)
##   right: unit panel (right click a Pokémon)
##   bottom: shop (level/xp, odds, gold, lock, Buy XP / Refresh, 6 cards) + Fight button
##   popups: item choice, round banner, game over.
## Scene: scenes/ui/hud.tscn (layout, frames and icons are edited there and in
## scenes/ui/theme/ui_theme.tres). Tooltips (HoverTip, node Tips) open next to the hovered element.

signal buy_pressed(slot: int)
signal reroll_pressed
signal buy_xp_pressed
signal lock_pressed
signal fight_pressed
signal speed_pressed
signal menu_pressed
signal game_over_confirmed
signal item_drag_started(index: int)
signal item_chosen(item: String)
signal choice_skipped
signal portal_chosen(index: int)
signal pokemon_chosen(index: int)
## A synergy is hovered (synergy list or shop card; "" = none): the game lights the cells
## of the player's Pokémon of that synergy, the shop its cards.
signal synergy_hovered(type: String)
## The HUD was laid out again (canvas resized, UI size changed): see `compact` and `board_rect`.
signal layout_changed

@onready var overlay: UnitOverlay = %Overlay
@onready var info_panel: UnitInfoPanel = %UnitInfoPanel
@onready var tips: HoverTip = %Tips
@onready var shop: ShopBar = %ShopBar
@onready var item_bench: ItemBench = %ItemBench
@onready var synergies: SynergyList = %Synergies

@onready var _stage_label: Label = %Stage
@onready var _wave_label: Label = %Wave
@onready var _weather_label: Label = %Weather
@onready var _phase_label: Label = %Phase
@onready var _timer_bar: ProgressBar = %TimerBar
@onready var _speed_button: Button = %Speed
@onready var _fight_button: Button = %Fight
@onready var _life_label: Label = %Life
@onready var _level_label: Label = %Level
@onready var _item_choice: ItemChoice = %ItemChoice
@onready var _town_choice: TownChoice = %TownChoice
@onready var _drag_icon: TextureRect = %DragIcon
@onready var _drag_hint_panel: PanelContainer = %DragHint
@onready var _drag_hint: Label = %DragHintText
@onready var _banner: Label = %Banner
@onready var _banner_notes: Label = %BannerNotes
@onready var _game_over: Control = %GameOver
@onready var _game_over_text: Label = %GameOverText

const BANNER_FONT := 56
const BANNER_WIDTH := 980.0
var _banner_font := BANNER_FONT ## compact layout: smaller
var _banner_width := BANNER_WIDTH
const BANNER_NOTES := 7
const BANNER_MAX_TIME := 4.5

var dps_meter: DpsMeter
var garden: GardenPanel
## Callable() -> String: the coming stages (tooltip of the stage bar), set by the Game.
var stage_preview: Callable


func _ready() -> void:
	_speed_button.pressed.connect(func() -> void: speed_pressed.emit())
	_fight_button.pressed.connect(func() -> void: fight_pressed.emit())
	%Menu.pressed.connect(func() -> void:
		var options := OptionsPanel.create(true)
		options.leave_pressed.connect(func() -> void: menu_pressed.emit())
		options.open_over($Root))
	%Back.pressed.connect(func() -> void: game_over_confirmed.emit())
	shop.buy_pressed.connect(func(slot: int) -> void: buy_pressed.emit(slot))
	shop.reroll_pressed.connect(func() -> void: reroll_pressed.emit())
	shop.buy_xp_pressed.connect(func() -> void: buy_xp_pressed.emit())
	shop.lock_pressed.connect(func() -> void: lock_pressed.emit())
	shop.synergy_hovered.connect(_on_synergy_hovered)
	shop.close_pressed.connect(func() -> void: set_shop_open(false))
	_build_dock()
	synergies.synergy_hovered.connect(_on_synergy_hovered)
	item_bench.drag_started.connect(func(index: int) -> void: item_drag_started.emit(index))
	_item_choice.chosen.connect(func(item: String) -> void: item_chosen.emit(item))
	_item_choice.skipped.connect(func() -> void: choice_skipped.emit())
	_town_choice.portal_chosen.connect(func(i: int) -> void: portal_chosen.emit(i))
	_town_choice.pokemon_chosen.connect(func(i: int) -> void: pokemon_chosen.emit(i))
	tips.attach(_speed_button, func() -> Control:
		return Tooltips.text(L.t("Combat speed"), L.t("Speeds the fights up (x1, x2, x4).")), HoverTip.Side.BOTTOM)
	tips.attach(%Menu, func() -> Control:
		return Tooltips.text(L.t("Menu"), L.t("Options, or leave the run and go back to the main menu.")), HoverTip.Side.LEFT)
	tips.attach(_fight_button, func() -> Control:
		return Tooltips.text(L.t("Start the fight  (Space)"), L.t("Ends the planning phase. Empty board slots are filled from the bench.")),
		HoverTip.Side.TOP)
	tips.attach(_weather_label, func() -> Control:
		return Tooltips.weather(_weather), HoverTip.Side.BOTTOM)
	for label in [_stage_label, _wave_label]:
		tips.attach(label, func() -> Control:
			var tip := Tooltips.text(L.t("Next stages"), stage_preview.call() if stage_preview.is_valid() else "")
			tip.custom_minimum_size.x = 420.0
			return tip, HoverTip.Side.BOTTOM)
	# region the last portal led to, before the weather; hover: its regional Pokémon
	_region_label = Label.new()
	_region_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_region_label.add_theme_font_size_override("font_size", 16)
	_region_label.add_theme_color_override("font_color", UiStyle.GOLD)
	_region_label.visible = false
	_weather_label.add_sibling(_region_label)
	_weather_label.get_parent().move_child(_region_label, _weather_label.get_index())
	tips.attach(_region_label, _region_tip, HoverTip.Side.BOTTOM)
	# active synergies of the coming wave, right of its name
	_enemy_synergies = HBoxContainer.new()
	_enemy_synergies.add_theme_constant_override("separation", 6)
	_wave_label.add_sibling(_enemy_synergies)
	# Grass berry trees, top left
	garden = GardenPanel.new()
	$Root.add_child(garden)
	garden.position = Vector2(12, 12)
	# fight statistics, under the player panel (hidden while a unit is inspected)
	dps_meter = DpsMeter.new()
	dps_meter.visible = false
	$Root.add_child(dps_meter)
	$Root.move_child(dps_meter, %UnitInfoPanel.get_index())
	dps_meter.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dps_meter.offset_left = -250.0
	dps_meter.offset_right = -10.0
	dps_meter.offset_top = 118.0
	dps_meter.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# layout: the scene's, or the compact one on a small canvas (phones)
	_stage_bar = $Root/StageBar
	_player_panel = $Root/PlayerPanel
	for node in [shop, _fight_button, item_bench, synergies, info_panel, _stage_bar, _player_panel, _item_choice,
			_town_choice, _banner, _banner_notes]:
		_scene_layout[node] = [node.anchor_left, node.anchor_top, node.anchor_right, node.anchor_bottom,
			node.offset_left, node.offset_top, node.offset_right, node.offset_bottom, node.grow_horizontal, node.grow_vertical]
	if UiScale.touch:
		$Root/Hint.text = L.t("Tap a Pokémon or an item: details  •  hold: recipes, what a button does  •  drag onto the shop: sell")
	get_viewport().size_changed.connect(_layout)
	garden.visibility_changed.connect(_layout)
	garden.resized.connect(_layout)
	# a text that changes the size of a part (level 10, a long region name): the parts next to it move
	for part in [shop, _stage_bar, _player_panel]:
		part.minimum_size_changed.connect(_layout_later)
	info_panel.resized.connect(_fit_panels)
	_item_choice.resized.connect(_fit_panels)
	_town_choice.resized.connect(_fit_panels)
	(%GameOver.get_node("Center/Panel") as Control).resized.connect(_fit_panels)
	_layout()


#region layout: the scene's (desktop) or compact (small canvases: phones, see UiScale)
## The canvas is low (UiScale.COMPACT_HEIGHT): compact layout.
var compact := false
## Compact: the room the panels leave to the board, in viewport coordinates (the game frames the
## board there: TftCamera.frame). Empty with the scene layout (the scene's camera).
var board_rect := Rect2()
## node -> its anchors (4), offsets (4) and grow directions (2) in the scene
var _scene_layout: Dictionary = {}
var _laying_out := false
var _layout_queued := false
var _stage_bar: PanelContainer
var _player_panel: PanelContainer
var _stage_row2: HBoxContainer ## compact: enemy synergies, region, weather and the timer bar on a second line
var _player_row: HBoxContainer ## compact: life + level left of the Menu button
var _shop_top := 0.0 ## compact: top of the shop bar on the canvas
## Compact: the shop is shown (set_shop_open). Closed, the board takes its room down to the bottom of the
## screen (as in TFT on a phone) and the dock - gold, the button opening the shop - sits under the left column.
var shop_open := true
var _board_bottom := 0.0 ## compact: where the room of the board ends (the top of the shop, or the bottom of the canvas)
## Compact: the room of the board while the shop is closed (the camera picks its angle for it, whatever
## the state of the shop: TftCamera keeps the same angle when the shop opens).
var board_room_full := Rect2()
var _dps_folded_once := false
var _dock: PanelContainer ## compact, shop closed: gold and the "Shop" button; a unit dropped on it is sold
var _dock_row: VBoxContainer
var _dock_gold: Label
var _dock_sell: Label
var _region_room := 0.0 ## compact: widest the region name may be

const COMPACT_MARGIN := 8.0
## Compact: distance kept from the left and right edges of the screen where a part sits in a corner
## (phone screens have rounded corners).
const COMPACT_CORNER := 22.0
## Compact: the synergies are narrow chips (SynergyRow.chip).
const SYNERGY_WIDTH := 64.0
## Compact: size of the Fight button (in the bottom right corner of the room of the board).
const COMPACT_FIGHT := Vector2(140.0, 60.0)
## Compact: width of the fight statistics (the unit panel keeps UNIT_PANEL_WIDTH).
const DPS_WIDTH := 240.0
const UNIT_PANEL_WIDTH := 300.0
const GROW_BEGIN := Control.GROW_DIRECTION_BEGIN
const GROW_END := Control.GROW_DIRECTION_END
const GROW_BOTH := Control.GROW_DIRECTION_BOTH


## A part changed its minimum size (a text): lay out again once this frame is over.
func _layout_later() -> void:
	if _layout_queued or _laying_out:
		return
	_layout_queued = true
	_layout.call_deferred()


func _layout() -> void:
	_layout_queued = false
	if _laying_out or not is_inside_tree():
		return
	_laying_out = true
	var canvas: Vector2 = $Root.get_viewport_rect().size
	var was := [compact, board_rect]
	compact = canvas.y < UiScale.COMPACT_HEIGHT
	shop.set_compact(compact)
	info_panel.set_compact(compact)
	item_bench.set_compact(compact)
	garden.set_compact(compact)
	synergies.chips = compact
	shop.visible = shop_open or not compact
	_dock.visible = compact and not shop_open
	_compact_stage_bar(compact)
	_compact_player_panel(compact)
	$Root/Hint.visible = not compact
	if compact:
		if not _dps_folded_once: # the fight statistics would cover the right side of the board: folded at first
			_dps_folded_once = true
			dps_meter.set_folded(true)
		_layout_compact(canvas)
	else:
		for node in _scene_layout:
			var l: Array = _scene_layout[node]
			_place(node, l.slice(0, 4), l.slice(4, 8), l[8], l[9])
		shop.scale = Vector2.ONE
		_stage_bar.scale = Vector2.ONE
		item_bench.set_page_size(99)
		synergies.max_rows = 99
		dps_meter.max_rows = DpsMeter.MAX_ROWS
		dps_meter.offset_left = -250.0
		dps_meter.offset_right = -10.0
		dps_meter.offset_top = 118.0
		garden.position = Vector2(12, 12)
		board_rect = Rect2()
		_banner_font = BANNER_FONT
		_banner_width = BANNER_WIDTH
		_banner_notes.add_theme_font_size_override("font_size", 26)
	_update_region_label()
	_laying_out = false
	_fit_panels()
	if was != [compact, board_rect]: # the camera frames the board again (its zoom is reset): only when it must
		layout_changed.emit()


## Compact layout (phones). Canvas units; `m` between the parts and from the top / bottom edges.
##   top      stage bar (two lines) centred over the board, the player panel in the right corner
##   left     item bench, synergy chips        right    fight statistics, unit panel (over the edge of the board room)
##   bottom   shop open: the shop in one row, the Fight button right above its right end;
##            shop closed: the dock (gold, Shop button) under the left column, the Fight button in the right corner
## The board takes the room between the left column and its mirror on the right, from the stage bar down to
## the shop - or to the bottom of the screen while the shop is closed (the camera frames it again).
## The left / right margins come from _sides(): the rounded corners of the screen, and the camera
## cutout where it reaches (UiScale.band_insets).
func _layout_compact(canvas: Vector2) -> void:
	var m := COMPACT_MARGIN
	var half := canvas.x * 0.5
	# bottom: the shop between the corners of the screen, shrunk if it still does not fit
	var shop_min := shop.get_combined_minimum_size()
	var low := _sides(canvas, canvas.y - m - shop_min.y, canvas.y)
	var shop_room := canvas.x - low.x - low.y
	var shop_width := minf(1500.0, shop_room)
	var shop_left := low.x + (shop_room - shop_width) * 0.5
	_place(shop, [0.0, 1.0, 0.0, 1.0], [shop_left, -m - shop_min.y, shop_left + shop_width, -m], GROW_BOTH, GROW_BEGIN)
	var shop_scale := minf(1.0, shop_width / maxf(shop_min.x, 1.0))
	shop.pivot_offset = Vector2(shop.size.x * 0.5, shop.size.y)
	shop.scale = Vector2(shop_scale, shop_scale)
	_shop_top = canvas.y - m - shop_min.y * shop_scale
	_board_bottom = _shop_top if shop_open else canvas.y - 2.0
	# everything above: the sides of the screen there (a camera cutout sits at mid height)
	var up := _sides(canvas, 0.0, _board_bottom)
	var left := up.x
	var right := up.y
	# right: the player panel in the corner; the Fight button above the right end of the shop, or in the corner
	var player_size := _player_panel.get_combined_minimum_size()
	player_size.x = maxf(player_size.x, UNIT_PANEL_WIDTH)
	_place(_player_panel, [1.0, 0.0, 1.0, 0.0], [-right - player_size.x, m, -right, m + player_size.y], GROW_BEGIN, GROW_END)
	var fight_right := right if shop_open else low.y
	var fight_top := (_shop_top - m if shop_open else canvas.y - m) - COMPACT_FIGHT.y
	_place(_fight_button, [1.0, 0.0, 1.0, 0.0], [-fight_right - COMPACT_FIGHT.x, fight_top, -fight_right, fight_top + COMPACT_FIGHT.y],
		GROW_BEGIN, GROW_BEGIN)
	# left: the garden (berry trees, pots) when shown, then the item bench and the synergy chips, down to the
	# shop or to the dock
	garden.position = Vector2(left, m)
	var has_garden := garden.visible and garden.size.y > 1.0
	var top := m + (garden.size.y + m if has_garden else 0.0)
	var synergy_left := left + 74.0
	var column_right := synergy_left + SYNERGY_WIDTH
	var dock_size := _dock.get_combined_minimum_size()
	var dock_height := dock_size.y
	var dock_right := maxf(column_right, low.x + dock_size.x)
	_place(_dock, [0.0, 1.0, 0.0, 1.0], [low.x, -m - dock_height, dock_right, -m], GROW_END, GROW_BEGIN)
	var room := (_shop_top if shop_open else canvas.y - m - dock_height) - m - top
	_place(item_bench, [0.0, 0.0, 0.0, 0.0], [left, top, left + 54.0, top + 54.0], GROW_END, GROW_END)
	item_bench.set_page_size(int((room - ItemBench.COMPACT_EXTRA) / ItemBench.SLOT_PITCH))
	_place(synergies, [0.0, 0.0, 0.0, 0.0], [synergy_left, top, column_right, top + 40.0], GROW_END, GROW_END)
	synergies.max_rows = maxi(int((room - 24.0) / 50.0), 2) # a chip = 50 with its gap, 24 for the "+N" line
	# top: the stage bar centred over the board when the left column and the player panel leave the room on
	# both sides, else between them; its texts are cut before it gets wider than that (wave and region names),
	# and it shrinks if needed
	var bar_left := maxf(half - 410.0, maxf(column_right, left + garden.size.x if has_garden else 0.0) + m)
	var bar_right := minf(half + 410.0, canvas.x - right - player_size.x - m)
	var centred := minf(half - bar_left, bar_right - half)
	if centred >= 230.0:
		bar_left = half - centred
		bar_right = half + centred
	# the region name may take what the enemy synergies, the weather and a short timer bar leave of the second line
	_region_room = bar_right - bar_left - 20.0 - 60.0 - 12.0
	for other in [_enemy_synergies, _weather_label]:
		if other.visible:
			_region_room -= other.get_combined_minimum_size().x + 12.0
	_update_region_label()
	var bar_min := _stage_bar.get_combined_minimum_size()
	_place(_stage_bar, [0.0, 0.0, 0.0, 0.0], [bar_left, m, bar_right, m + bar_min.y], GROW_BOTH, GROW_END)
	var bar_scale := minf(1.0, (bar_right - bar_left) / maxf(bar_min.x, 1.0))
	_stage_bar.pivot_offset = Vector2(_stage_bar.size.x * 0.5, 0.0)
	_stage_bar.scale = Vector2(bar_scale, bar_scale)
	var bar_bottom := m + bar_min.y * bar_scale
	# right, under the player panel: the fight statistics; the unit panel from the top, over them
	dps_meter.offset_left = -right - DPS_WIDTH
	dps_meter.offset_right = -right
	dps_meter.offset_top = m + player_size.y + 6.0
	dps_meter.max_rows = clampi(int((fight_top - m - dps_meter.offset_top - 70.0) / 26.0), 2, DpsMeter.MAX_ROWS)
	_place(info_panel, [1.0, 0.0, 1.0, 0.0], [-right - UNIT_PANEL_WIDTH, m, -right, m + 10.0], GROW_BEGIN, GROW_END)
	# popups and banner: under the stage bar
	_place(_item_choice, [0.5, 0.0, 0.5, 0.0], [-200.0, bar_bottom + 6.0, 200.0, bar_bottom + 146.0], GROW_BOTH, GROW_END)
	_place(_town_choice, [0.5, 0.0, 0.5, 0.0], [-210.0, bar_bottom + 6.0, 210.0, bar_bottom + 156.0], GROW_BOTH, GROW_END)
	_banner_font = 40
	_banner_width = minf(BANNER_WIDTH, canvas.x - 2.0 * COMPACT_CORNER)
	_banner_notes.add_theme_font_size_override("font_size", 20)
	_place(_banner, [0.5, 0.0, 0.5, 0.0], [-_banner_width * 0.5, bar_bottom + 6.0, _banner_width * 0.5, bar_bottom + 62.0], GROW_BOTH, GROW_END)
	_place(_banner_notes, [0.5, 0.0, 0.5, 0.0], [-_banner_width * 0.5, bar_bottom + 62.0, _banner_width * 0.5, bar_bottom + 200.0], GROW_BOTH, GROW_END)
	# the board: from the left column (and the dock under it) to the Fight button, from the stage bar down to
	# the shop or to the bottom of the screen. Its near edge, the widest, is at the bottom between the dock and
	# the Fight button; the far one is narrower (perspective), clear of the player panel and of the fight
	# statistics (folded); the unit panel opens over its right side.
	var room_left := maxf(column_right, dock_right) + m
	var room_right := canvas.x - maxf(right, low.y) - COMPACT_FIGHT.x - m
	var room_top := bar_bottom + 4.0
	board_rect = Rect2(room_left, room_top, maxf(room_right - room_left, 420.0), _board_bottom - 4.0 - room_top)
	board_room_full = Rect2(board_rect.position, Vector2(board_rect.size.x, canvas.y - 6.0 - room_top))


## Compact: opens / closes the shop (the button of the dock, the one of the shop, the game at the start of
## a planning phase and of a fight). The scene layout always shows it.
func set_shop_open(open: bool) -> void:
	if open == shop_open:
		return
	shop_open = open
	tips.close_all()
	if compact:
		_layout()


## The dock of the compact HUD while the shop is closed: gold and the button opening the shop.
func _build_dock() -> void:
	_dock = PanelContainer.new()
	_dock.name = "ShopDock"
	_dock.visible = false
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	_dock.add_theme_stylebox_override("panel", UiStyle.panel())
	$Root.add_child(_dock)
	$Root.move_child(_dock, shop.get_index())
	# gold above the button: as narrow as the left column, the board takes the width
	_dock_row = VBoxContainer.new()
	_dock_row.add_theme_constant_override("separation", 4)
	_dock.add_child(_dock_row)
	var gold_line := HBoxContainer.new()
	gold_line.alignment = BoxContainer.ALIGNMENT_CENTER
	gold_line.add_theme_constant_override("separation", 6)
	_dock_row.add_child(gold_line)
	gold_line.add_child(UiStyle.icon_rect(GameData.icon("money"), 22))
	_dock_gold = UiStyle.label("0", 20, UiStyle.GOLD)
	gold_line.add_child(_dock_gold)
	var open := Button.new()
	open.name = "Open"
	open.text = L.t("Shop") + " ▲"
	open.focus_mode = Control.FOCUS_NONE
	open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open.custom_minimum_size = Vector2(96, 36)
	open.pressed.connect(func() -> void: set_shop_open(true))
	_dock_row.add_child(open)
	_dock_sell = UiStyle.label("", 15, UiStyle.TEXT_DIM)
	_dock_sell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock_sell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dock_sell.visible = false
	_dock.add_child(_dock_sell)


## Compact: margins on the left and on the right of the horizontal band y0..y1 of the canvas.
func _sides(canvas: Vector2, y0: float, y1: float) -> Vector2:
	var inset := UiScale.band_insets(canvas, y0, y1)
	return Vector2(maxf(COMPACT_CORNER, inset.x + COMPACT_MARGIN), maxf(COMPACT_CORNER, inset.y + COMPACT_MARGIN))


## Anchors, offsets and grow directions of a part. The grow directions are always set here: a scene loses
## the ones equal to the default when it is exported, and "anchors_preset" then leaves its own.
func _place(node: Control, anchors: Array, offsets: Array, grow_horizontal: int, grow_vertical: int) -> void:
	node.grow_horizontal = grow_horizontal
	node.grow_vertical = grow_vertical
	node.anchor_left = anchors[0]
	node.anchor_top = anchors[1]
	node.anchor_right = anchors[2]
	node.anchor_bottom = anchors[3]
	node.offset_left = offsets[0]
	node.offset_top = offsets[1]
	node.offset_right = offsets[2]
	node.offset_bottom = offsets[3]


## Compact stage bar: two lines instead of a long one.
##   Stage 3  vs Gyarados                               Planning  [x1]
##   [enemy synergies]  region  weather  [timer bar ----------------]
func _compact_stage_bar(on: bool) -> void:
	if on == (_stage_row2 != null and _stage_row2.get_parent() != null):
		return
	var row: HBoxContainer = _stage_label.get_parent()
	var v: VBoxContainer = row.get_parent()
	if on:
		if _stage_row2 == null:
			_stage_row2 = HBoxContainer.new()
			_stage_row2.name = "Row2"
			_stage_row2.add_theme_constant_override("separation", 12)
		v.add_child(_stage_row2)
		v.move_child(_stage_row2, row.get_index() + 1)
		_enemy_synergies.reparent(_stage_row2, false)
		_region_label.reparent(_stage_row2, false)
		_weather_label.reparent(_stage_row2, false)
		_timer_bar.reparent(_stage_row2, false)
		_timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_timer_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_timer_bar.custom_minimum_size = Vector2(60, 8)
	else:
		# back to the scene: Stage, Wave, enemy synergies, region, Weather, Phase, Speed; the timer bar under them
		_enemy_synergies.reparent(row, false)
		row.move_child(_enemy_synergies, _wave_label.get_index() + 1)
		_region_label.reparent(row, false)
		row.move_child(_region_label, _phase_label.get_index())
		_weather_label.reparent(row, false)
		row.move_child(_weather_label, _phase_label.get_index())
		_timer_bar.reparent(v, false)
		_timer_bar.size_flags_horizontal = Control.SIZE_FILL
		_timer_bar.size_flags_vertical = Control.SIZE_FILL
		_timer_bar.custom_minimum_size = Vector2(0, 8)
		v.remove_child(_stage_row2)
	for label in [_region_label, _weather_label]:
		label.add_theme_font_size_override("font_size", 14 if on else 16)
	v.add_theme_constant_override("separation", 2 if on else 4)


## Compact: a region name longer than its room is cut with "..." (its tooltip has the whole name).
func _update_region_label() -> void:
	if _region_label == null:
		return
	if not compact:
		_region_label.clip_text = false
		_region_label.custom_minimum_size.x = 0.0
		return
	var font := _region_label.get_theme_font("font")
	var natural := font.get_string_size(_region_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _region_label.get_theme_font_size("font_size")).x + 2.0
	_region_label.clip_text = true
	_region_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_region_label.custom_minimum_size.x = clampf(natural, 0.0, maxf(_region_room, 40.0))


## Compact player panel: life and level on two short lines, the Menu button right of them.
func _compact_player_panel(on: bool) -> void:
	if on == (_player_row != null and _player_row.get_parent() != null):
		return
	var box: VBoxContainer = _life_label.get_parent()
	var menu: Button = %Menu
	if on:
		if _player_row == null:
			_player_row = HBoxContainer.new()
			_player_row.name = "H"
			_player_row.add_theme_constant_override("separation", 10)
		_player_panel.add_child(_player_row)
		box.reparent(_player_row, false)
		menu.reparent(_player_row, false)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		menu.custom_minimum_size = Vector2(66, 42)
	else:
		box.reparent(_player_panel, false)
		menu.reparent(box, false)
		_player_panel.remove_child(_player_row)
		box.size_flags_horizontal = Control.SIZE_FILL
		menu.size_flags_vertical = Control.SIZE_FILL
		menu.custom_minimum_size = Vector2.ZERO
	box.add_theme_constant_override("separation", 0 if on else 4)
	_life_label.add_theme_font_size_override("font_size", 20 if on else 24)
	_level_label.add_theme_font_size_override("font_size", 14 if on else 16)


## Panels that may be larger than a small canvas shrink to fit it (UiScale.fit): the unit panel (compact:
## it stays above the shop), the choice popups, the Game Over panel.
func _fit_panels() -> void:
	if not is_inside_tree():
		return
	var canvas: Vector2 = $Root.get_viewport_rect().size
	var m := COMPACT_MARGIN
	UiScale.fit(info_panel, Vector2(canvas.x, _board_bottom - 2.0 * m) if compact else canvas, Vector2(1, 0))
	UiScale.fit(_item_choice, Vector2(canvas.x - 2.0 * m, canvas.y - _item_choice.position.y - m), Vector2(0.5, 0))
	UiScale.fit(_town_choice, Vector2(canvas.x - 2.0 * m, canvas.y - _town_choice.position.y - m), Vector2(0.5, 0))
	UiScale.fit(%GameOver.get_node("Center/Panel"), canvas - Vector2(2.0 * m, 2.0 * m), Vector2(0.5, 0.5), %GameOver.get_node("Center"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# the compact helpers out of the tree (scene layout) are nobody's children
		for node in [_stage_row2, _player_row]:
			if node != null and is_instance_valid(node) and node.get_parent() == null:
				node.free()
#endregion


func _on_synergy_hovered(type: String) -> void:
	shop.set_synergy_focus(type)
	synergy_hovered.emit(type)


#region refresh
## Fight statistics of the last / current fight ([] = none yet).
func update_dps(entries: Array) -> void:
	dps_meter.visible = not entries.is_empty() and not info_panel.visible
	if dps_meter.visible:
		dps_meter.update(entries)


func refresh_player(player: PlayerState) -> void:
	_player = weakref(player)
	_region_label.visible = player.map != "town"
	_region_label.text = TownChoice.map_name(player.map)
	_update_region_label()
	garden.refresh(player)
	_life_label.text = L.t("Life %d") % player.life
	_life_label.add_theme_color_override("font_color", UiStyle.GREEN if player.life > 30 else UiStyle.RED)
	_level_label.text = L.t("Level %d  •  team %d/%d") % [player.level, player.team_count(), player.max_team_size()]
	shop.refresh(player)
	_dock_gold.text = str(player.gold)
	item_bench.set_items(player.items)
	synergies.refresh(player)


func refresh_stage(stage: int, wave: Dictionary, phase_text: String, time_left: float, time_total: float, planning: bool) -> void:
	_stage_label.text = L.t("Stage %d") % stage
	_wave_label.text = L.t("vs %s") % EndlessWaves.display_name(wave) if not wave.is_empty() else ""
	_phase_label.text = phase_text
	_timer_bar.value = 100.0 * time_left / maxf(time_total, 0.001)
	_fight_button.visible = planning


var _region_label: Label
var _enemy_synergies: HBoxContainer
var _player: WeakRef


## Active synergies of the coming wave ({type: points}, see EndlessWaves.synergy_counts):
## an icon and the points each, hover for the tiers.
func set_enemy_synergies(counts: Dictionary) -> void:
	for c in _enemy_synergies.get_children():
		_enemy_synergies.remove_child(c)
		c.queue_free()
	for type in Synergies.sort(counts):
		var n: int = counts[type]
		if Synergies.tier(type, n) <= 0:
			continue
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 2)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.add_child(UiStyle.icon_rect(GameData.type_icon(type), 18 if compact else 22))
		chip.add_child(UiStyle.label(str(n), 14 if compact else 15, UiStyle.RED))
		var t: String = type
		tips.attach(chip, func() -> Control:
			return Tooltips.synergy(t, n, {}, 0, L.t("Synergy of the enemy wave.")), HoverTip.Side.BOTTOM)
		_enemy_synergies.add_child(chip)
	_enemy_synergies.visible = _enemy_synergies.get_child_count() > 0


## Region tooltip: its synergies and the regional Pokémon of its shop (web regional
## Pokémon list): the ones found only there and the variants replacing a form.
func _region_tip() -> Control:
	var player: PlayerState = _player.get_ref() if _player != null else null
	if player == null:
		return null
	var types: Array = GameData.config.get("maps", {}).get(player.map, {}).get("synergies", [])
	var found: Array = player.regional_counts.keys()
	for pkm in player.regional_pokemons:
		if not found.has(pkm):
			found.append(pkm)
	found.sort_custom(func(a: String, b: String) -> bool:
		var ca := GameData.rarity_cost(GameData.get_pokemon(a).rarity)
		var cb := GameData.rarity_cost(GameData.get_pokemon(b).rarity)
		return ca < cb or (ca == cb and a < b))
	var names: Array = found.map(func(pkm: String) -> String:
		var color: Color = GameData.RARITY_COLORS.get(GameData.get_pokemon(pkm).rarity, UiStyle.TEXT)
		return "[color=#%s]%s[/color]" % [color.to_html(false), GameData.display_name(pkm)])
	var body := L.t("Regional Pokémon share a synergy with their region: %s") % " ".join(types)
	body += "\n" + (L.t("In the shop here: %s") % ", ".join(names) if not names.is_empty()
		else L.t("No regional Pokémon in this shop."))
	if GameData.season_active: # a season (Seasons) has no regional Pokémon
		body = L.t("Synergies of the region: %s") % " ".join(types) + "\n" \
			+ L.t("The shop of a season is the same in every region.")
	var tip := Tooltips.text(L.t("Region: %s") % TownChoice.map_name(player.map), body)
	tip.custom_minimum_size.x = 380.0
	return tip


var _weather := Weather.NEUTRAL
var _banner_tween: Tween


## Weather of the coming (planning) or current fight; hover: its effects.
func set_weather(weather: String) -> void:
	_weather = weather
	_weather_label.text = GameData.weather_name(weather)
	_weather_label.add_theme_color_override("font_color", UiStyle.TEXT_DIM if weather == Weather.NEUTRAL else UiStyle.GOLD)


func set_speed_text(text: String) -> void:
	_speed_button.text = text


func set_shop_enabled(on: bool) -> void:
	shop.set_enabled(on)


## Selling: the shop turns into a sell zone while a unit is dragged over it (`price` < 0: not over it).
## Compact, shop closed: the dock is the sell zone - it says so as long as a unit is `dragging`.
func show_sell(price: int, dragging := false) -> void:
	shop.show_sell(price if shop.visible else -1)
	var on_dock := dragging and _dock.visible
	_dock_row.visible = not on_dock
	_dock_sell.visible = on_dock
	if on_dock:
		_dock_sell.text = L.t("Sell for %s gold") % str(price) if price >= 0 else L.t("Drop here to sell")
		_dock_sell.add_theme_color_override("font_color", UiStyle.GOLD if price >= 0 else UiStyle.TEXT_DIM)


## Over the sell zone: the shop, or the dock while the shop is closed (compact).
func is_over_shop(screen_pos: Vector2) -> bool:
	var zone: Control = shop if shop.visible else _dock
	return zone.visible and shown_rect(zone).has_point(screen_pos)


func is_over_ui(screen_pos: Vector2) -> bool:
	for c in [shop, _dock, info_panel, item_bench, synergies, _item_choice, _town_choice]:
		if c.visible and shown_rect(c).has_point(screen_pos):
			return true
	return tips.is_over_tip(screen_pos)


## Where a part is drawn on the canvas, its scale included (a part shrunk to fit: UiScale.fit).
static func shown_rect(control: Control) -> Rect2:
	var xf := control.get_global_transform()
	return Rect2(xf.origin, control.size * xf.get_scale())


## Item dragged from the item bench: its icon follows the mouse with what the drop would do.
func show_item_drag(item: String) -> void:
	tips.close_all()
	_drag_icon.texture = GameData.item_icon(item)
	_drag_icon.visible = true


## `hint`: what dropping here does ("Equip", "Combine: Choice Specs", "Already holds 3 items").
func move_item_drag(pos: Vector2, hint := "", ok := true) -> void:
	_drag_icon.position = pos - _drag_icon.size * 0.5
	_drag_hint_panel.visible = hint != ""
	_drag_hint.text = hint
	_drag_hint.add_theme_color_override("font_color", UiStyle.GREEN if ok else UiStyle.RED)
	_drag_hint_panel.reset_size()
	_drag_hint_panel.position = pos + Vector2(30, 14)


func hide_item_drag() -> void:
	_drag_icon.visible = false
	_drag_hint_panel.visible = false


func show_item_choice(items: Array[String], title := "", cost := 0, gold := 0) -> void:
	_item_choice.show_items(items, title, cost, gold)


func show_portal_choice(portals: Array, title: String, info := "") -> void:
	_town_choice.show_portals(portals, title, info)


func show_pokemon_choice(pokemons: Array, items: Array, title: String, info := "") -> void:
	_town_choice.show_pokemons(pokemons, items, title, info)


## A choice popup is open (item, portal or Pokémon).
func has_item_choice() -> bool:
	return _item_choice.visible or _town_choice.visible


func hide_item_choice() -> void:
	_item_choice.visible = false
	_town_choice.visible = false


## Big message in the middle of the screen: the first line large (shrunk to fit), the other
## lines smaller under it (at most BANNER_NOTES, then "and N more"); never longer than BANNER_MAX_TIME.
func banner(text: String, color: Color, duration := 1.6) -> void:
	var lines := text.split("\n")
	var notes: Array[String] = []
	notes.assign(lines.slice(1))
	if notes.size() > BANNER_NOTES:
		var hidden := notes.size() - (BANNER_NOTES - 1)
		notes = notes.slice(0, BANNER_NOTES - 1)
		notes.append(L.t("... and %d more") % hidden)
	_banner.text = lines[0]
	var font_size := _banner_font
	var width := _banner.get_theme_font("font").get_string_size(lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, _banner_font).x
	if width > _banner_width:
		font_size = maxi(floori(_banner_font * _banner_width / width), 20)
	_banner.add_theme_font_size_override("font_size", font_size)
	_banner.add_theme_color_override("font_color", color)
	_banner_notes.text = "\n".join(notes)
	_banner_notes.add_theme_color_override("font_color", color)
	_banner.visible = true
	_banner_notes.visible = not notes.is_empty()
	_set_banner_alpha(0.0)
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_method(_set_banner_alpha, 0.0, 1.0, 0.15)
	_banner_tween.tween_interval(minf(duration, BANNER_MAX_TIME))
	_banner_tween.tween_method(_set_banner_alpha, 1.0, 0.0, 0.3)
	_banner_tween.tween_callback(func() -> void:
		_banner.hide()
		_banner_notes.hide())


func _set_banner_alpha(alpha: float) -> void:
	_banner.modulate.a = alpha
	_banner_notes.modulate.a = alpha


## `record`: the best run of this difficulty before this one (Records.best), `beaten` when this
## run beats it, `fair` false when a cheat was used (not recorded), `summary`: RunStats.summary.
func show_game_over(stage: int, record := {}, beaten := false, fair := true, summary := {}) -> void:
	_game_over_text.text = L.t("You reached stage %d") % stage
	var note: Label = %GameOverRecord
	if not fair:
		note.text = L.t("Cheats were used: not recorded")
		note.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	elif beaten:
		note.text = L.t("New record!") + ("" if record.is_empty() else "  " + L.t("(before: stage %d)") % int(record.stage))
		note.add_theme_color_override("font_color", UiStyle.GOLD)
	else:
		note.text = L.t("Record (%s): stage %d") % [Seasons.run_label(), int(record.get("stage", 0))]
		note.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	if not summary.is_empty():
		var stats := RunSummary.new()
		note.add_sibling(stats)
		stats.setup(summary)
	_game_over.visible = true
	info_panel.hide()
	tips.close_all()


func is_game_over_shown() -> bool:
	return _game_over.visible
#endregion
