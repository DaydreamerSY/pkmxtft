class_name ShopBar
extends PanelContainer

## Shop at the bottom of the screen, laid out like TFT:
##   top strip  level + xp, shop odds of the level, gold (centre), "!" (pool of the shop), lock
##   left       Buy XP / Refresh
##   cards      6 ShopCard (hover: its ability; click: buy)
## While a Pokémon is dragged, the whole bar becomes the sell zone.
## Scene: scenes/ui/shop_bar.tscn

signal buy_pressed(slot: int)
signal reroll_pressed
signal buy_xp_pressed
signal lock_pressed
## Compact HUD: the button hiding the shop was pressed (Hud.set_shop_open).
signal close_pressed
## A synergy of a card is hovered ("" = left it).
signal synergy_hovered(type: String)

## Icons of the lock button (open / closed).
@export var lock_open_icon: Texture2D = preload("res://assets/icons/lock-open.svg")
@export var lock_closed_icon: Texture2D = preload("res://assets/icons/lock-close.svg")

## Compact HUD: narrowest a card may get (its name shrinks to fit), width of the gold / level / buttons block.
const COMPACT_CARD_WIDTH := 104.0
const COMPACT_LEFT_WIDTH := 300.0

var cards: Array[ShopCard] = []

var _player: WeakRef
var _pool_pulse: Tween
var _compact := false
var _info_row: HBoxContainer ## compact: gold + level above the buttons
var _button_row: HBoxContainer ## compact: Buy XP and Refresh side by side
var _side: VBoxContainer ## compact: "!" and lock right of the cards
var _close: Button ## compact: hides the shop (the board takes its room), right of the level

@onready var _level: Label = %Level
@onready var _xp_bar: ValueBar = %XpBar
@onready var _odds: RichTextLabel = %Odds
@onready var _gold: Label = %GoldValue
@onready var _lock: Button = %Lock
@onready var _pool_info: Button = %PoolInfo
@onready var _buy_xp: Button = %BuyXp
@onready var _refresh: Button = %Refresh
@onready var _sell_overlay: PanelContainer = %SellOverlay
@onready var _sell_text: RichTextLabel = %SellText


func _ready() -> void:
	for child in %Cards.get_children():
		if child is ShopCard:
			var slot := cards.size()
			cards.append(child)
			child.pressed.connect(func() -> void: buy_pressed.emit(slot))
			child.synergy_hovered.connect(func(t: String) -> void: synergy_hovered.emit(t))
	_buy_xp.pressed.connect(func() -> void: buy_xp_pressed.emit())
	_refresh.pressed.connect(func() -> void: reroll_pressed.emit())
	_lock.pressed.connect(func() -> void: lock_pressed.emit())
	_pool_info.pressed.connect(_toggle_pool_list)
	_set_cost(_buy_xp, PlayerState.XP_COST)
	_set_cost(_refresh, PlayerState.REROLL_COST)
	HoverTip.add(_buy_xp, func() -> Control:
		return Tooltips.text(L.t("Buy XP  (F)"), L.t("+%d XP for %d gold. Higher levels place more Pokémon and find rarer ones.") % [
			PlayerState.XP_PER_BUY, PlayerState.XP_COST]), HoverTip.Side.TOP)
	HoverTip.add(_refresh, func() -> Control:
		return Tooltips.text(L.t("Refresh  (D)"), L.t("New Pokémon in the shop for %d gold.") % PlayerState.REROLL_COST), HoverTip.Side.TOP)
	HoverTip.add(_odds, func() -> Control:
		return Tooltips.text(L.t("Shop odds"), L.t("Chance of each rarity in the shop at your level: Common, Uncommon, Rare, Epic, Ultra.")),
		HoverTip.Side.TOP)
	# compact HUD: the odds strip is not shown; the level tells them (tap / hover)
	HoverTip.add(_level.get_parent(), func() -> Control:
		if not _compact:
			return null
		return Tooltips.text(L.t("Shop odds"), _odds.text + "\n"
			+ L.t("Chance of each rarity in the shop at your level: Common, Uncommon, Rare, Epic, Ultra.")),
		HoverTip.Side.TOP)
	HoverTip.add(_pool_info, func() -> Control:
		return Tooltips.text(L.t("Shop pool"), L.t("Pokémon that joined your shop, and the ones that join next. Click to open the list.")),
		HoverTip.Side.TOP)
	HoverTip.add(_lock, func() -> Control:
		return Tooltips.text(L.t("Lock the shop"), L.t("Keeps the Pokémon currently in the shop for the next round (the shop is not refreshed).")),
		HoverTip.Side.TOP)


## Compact HUD (phones, UiScale): one row only, so that the board keeps its room. The top strip goes away:
## gold and level sit above Buy XP / Refresh (side by side), "!" and the lock in a column right of the
## cards, which are shorter and share the width left. The shop odds are not shown.
func set_compact(on: bool) -> void:
	if on == _compact:
		return
	_compact = on
	var top: Control = $V/Top
	var row: Control = $V/Row
	var left: Control = $V/Row/Left
	var gold: Control = _gold.get_parent()
	var level_box: Control = _level.get_parent()
	if on:
		if _info_row == null:
			_info_row = HBoxContainer.new()
			_info_row.add_theme_constant_override("separation", 14)
			_button_row = HBoxContainer.new()
			_button_row.add_theme_constant_override("separation", 6)
			_side = VBoxContainer.new()
			_side.add_theme_constant_override("separation", 6)
			_side.alignment = BoxContainer.ALIGNMENT_CENTER
			_close = Button.new()
			_close.name = "Close"
			_close.text = "▼"
			_close.focus_mode = Control.FOCUS_NONE
			_close.custom_minimum_size = Vector2(42, 0)
			_close.pressed.connect(func() -> void: close_pressed.emit())
			_info_row.add_child(_close)
			HoverTip.add(_close, func() -> Control:
				return Tooltips.text(L.t("Hide the shop"), L.t("The board takes the room of the shop. The Shop button brings it back.")),
				HoverTip.Side.TOP)
		left.add_child(_info_row)
		left.add_child(_button_row)
		row.add_child(_side)
		gold.reparent(_info_row, false)
		level_box.reparent(_info_row, false)
		_info_row.move_child(_close, -1)
		_buy_xp.reparent(_button_row, false)
		_refresh.reparent(_button_row, false)
		_pool_info.reparent(_side, false)
		_lock.reparent(_side, false)
	else:
		# back to the order of the scene: Top = LevelBox, Odds, Spacer, Gold, Spacer2, PoolInfo, Lock
		level_box.reparent(top, false)
		top.move_child(level_box, 0)
		gold.reparent(top, false)
		top.move_child(gold, 3)
		_pool_info.reparent(top, false)
		_lock.reparent(top, false)
		_buy_xp.reparent(left, false)
		_refresh.reparent(left, false)
		left.remove_child(_info_row)
		left.remove_child(_button_row)
		row.remove_child(_side)
	top.visible = not on
	for card in cards:
		card.custom_minimum_size = Vector2(COMPACT_CARD_WIDTH, 104) if on else Vector2(176, 150)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL if on else Control.SIZE_FILL
		card.set_compact(on)
	%Cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL if on else Control.SIZE_FILL
	left.custom_minimum_size.x = COMPACT_LEFT_WIDTH if on else 180.0
	level_box.custom_minimum_size.x = 150.0 if on else 180.0
	level_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL if on else Control.SIZE_FILL
	for button in [_buy_xp, _refresh]:
		button.custom_minimum_size.y = 56.0 if on else 54.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if on else Control.SIZE_FILL
		(button.get_node("H/Icon") as Control).visible = not on
	_pool_info.custom_minimum_size = Vector2(46, 46) if on else Vector2(32, 32)
	_lock.custom_minimum_size = Vector2(46, 46) if on else Vector2(40, 32)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# the compact helpers out of the tree (scene layout) are nobody's children
		for node in [_info_row, _button_row, _side]:
			if node != null and is_instance_valid(node) and node.get_parent() == null:
				node.free()


func _set_cost(button: Button, cost: int) -> void:
	var label := button.find_child("Cost", true, false) as Label
	if label:
		label.text = str(cost)


func refresh(player: PlayerState) -> void:
	_player = weakref(player)
	_show_pool_news(player.pool_news_unread)
	var max_level := int(GameData.config.maxLevel)
	_level.text = L.t("Lv %d") % player.level
	if player.level >= max_level:
		_xp_bar.set_values(1, 1)
		_xp_bar.set_text("max")
	else:
		_xp_bar.set_values(player.experience, GameData.exp_to_next_level(player.level))
	var odds := GameData.shop_odds(player.level)
	var parts: Array[String] = []
	for i in GameData.SHOP_RARITIES.size():
		var color: Color = GameData.RARITY_COLORS[GameData.SHOP_RARITIES[i]]
		parts.append("[color=#%s]●[/color] %d%%" % [color.to_html(false), roundi(float(odds[i]) * 100.0)])
	_odds.text = "   ".join(parts)
	_gold.text = str(player.gold)
	_buy_xp.disabled = player.gold < PlayerState.XP_COST or player.level >= max_level
	_refresh.disabled = player.gold < PlayerState.REROLL_COST
	_lock.button_pressed = player.shop_locked
	_lock.icon = lock_closed_icon if player.shop_locked else lock_open_icon
	# synergies active on the board: the cards sharing one are highlighted
	var active := {}
	var counts := player.synergy_counts()
	for t in counts:
		if Synergies.tier(t, counts[t]) > 0:
			active[t] = true
	for i in cards.size():
		var pkm: String = player.shop[i] if i < player.shop.size() else ""
		cards[i].show_pokemon(pkm, pkm != "" and player.can_buy(i), active)


## Click on "!": the list of the shop pool (pinned tooltip), which counts as read.
func _toggle_pool_list() -> void:
	var player: PlayerState = _player.get_ref() if _player != null else null
	if player == null or HoverTip.current == null:
		return
	player.pool_news_unread = false
	_show_pool_news(false)
	HoverTip.current.toggle(_pool_info, Tooltips.pool(player), HoverTip.Side.TOP)


## "!" glows gold and pulses while something joined the pool that the list has not shown yet.
func _show_pool_news(unread: bool) -> void:
	if unread:
		_pool_info.add_theme_color_override("font_color", UiStyle.GOLD)
		if _pool_pulse == null or not _pool_pulse.is_valid():
			_pool_pulse = create_tween().set_loops()
			_pool_pulse.tween_property(_pool_info, "modulate:a", 0.45, 0.6)
			_pool_pulse.tween_property(_pool_info, "modulate:a", 1.0, 0.6)
	else:
		_pool_info.remove_theme_color_override("font_color")
		if _pool_pulse != null:
			_pool_pulse.kill()
			_pool_pulse = null
		_pool_info.modulate.a = 1.0


## A synergy is hovered ("" = none): its cards glow, the others dim.
func set_synergy_focus(type: String) -> void:
	for card in cards:
		card.set_synergy_focus(type)


func set_enabled(on: bool) -> void:
	modulate.a = 1.0 if on else 0.8


## Selling: the shop turns into a sell zone while a unit is dragged (price < 0 hides it).
func show_sell(price: int) -> void:
	_sell_overlay.visible = price >= 0
	if price >= 0:
		_sell_text.text = "[center]%s[/center]" % (L.t("Sell for %s gold") % ("[img=30]res://assets/icons/money.svg[/img] [color=#ffd24d]%d[/color]" % price))
