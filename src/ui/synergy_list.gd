class_name SynergyList
extends VBoxContainer

## Synergies of the board (TFT trait list), one SynergyRow each, active ones first.
## Scene: scenes/ui/synergy_list.tscn

## Hovering a synergy row ("" = left it): its Pokémon are highlighted (shop, board, bench).
signal synergy_hovered(type: String)

## Rows shown at most (the compact HUD has less room): the others are summed up in a "+N" line.
var max_rows := 99:
	set(v):
		if v != max_rows:
			max_rows = v
			_signature = "-"
			_rebuild.call_deferred() # the room changed (a garden appeared above the list): not at the next change of the board only

## Compact HUD: narrow rows (SynergyRow.chip), no text while the board is empty.
var chips := false:
	set(v):
		if v != chips:
			chips = v
			custom_minimum_size.x = 0.0 if v else 220.0
			_signature = "-"
			_rebuild.call_deferred()

var _signature := "-"
var _more: Label
var _player: WeakRef

@onready var _empty: Label = %Empty


## {type: count} of the board (families, Dragon doubles, buried gems: Synergies.count).
static func count_types(player: PlayerState) -> Dictionary:
	return Synergies.count_player(player)


## Families of the board and bench (owned).
static func owned_families(player: PlayerState) -> Dictionary:
	var out := {}
	for u in player.bench + player.board.values():
		if u != null:
			out[u.data().get("family", u.pkm)] = true
	return out


## Rebuild the rows on the next refresh (language changed).
func invalidate() -> void:
	_signature = "-"


func _rebuild() -> void:
	var player: PlayerState = _player.get_ref() if _player != null else null
	if player != null and is_inside_tree():
		refresh(player)


func refresh(player: PlayerState) -> void:
	_player = weakref(player)
	var counts := count_types(player)
	var owned := owned_families(player)
	var extras := {}
	for t in counts:
		extras[t] = Synergies.context_text(t, player)
	var signature := str(counts) + str(owned.keys()) + str(extras)
	if signature == _signature:
		return # keeps an open tooltip while gold / shop change
	_signature = signature
	synergy_hovered.emit("") # the hovered row is rebuilt
	for c in get_children():
		if c is SynergyRow:
			c.queue_free()
	var thresholds: Dictionary = GameData.config.get("synergyThresholds", {})
	var entries := []
	for t in counts:
		var tiers: Array = thresholds.get(t, [])
		var reached := -1
		for i in tiers.size():
			if counts[t] >= int(tiers[i]):
				reached = i
		entries.append([t, counts[t], reached])
	# active first (highest tier), then by count
	entries.sort_custom(func(a: Array, b: Array) -> bool:
		return a[2] > b[2] or (a[2] == b[2] and (a[1] > b[1] or (a[1] == b[1] and a[0] < b[0]))))
	if _more != null:
		_more.queue_free()
		_more = null
	var hidden := maxi(entries.size() - maxi(max_rows, 1), 0)
	for e in entries.slice(0, maxi(max_rows, 1)):
		var row: SynergyRow = UiScenes.make(UiScenes.SYNERGY_ROW)
		row.type = e[0]
		row.count = e[1]
		row.reached = e[2]
		row.tiers = thresholds.get(e[0], [])
		row.owned = owned
		row.extra = extras.get(e[0], "")
		row.player = player
		row.chip = chips
		var t: String = e[0]
		row.mouse_entered.connect(func() -> void: synergy_hovered.emit(t))
		row.mouse_exited.connect(func() -> void: synergy_hovered.emit(""))
		add_child(row)
	if hidden > 0:
		_more = UiStyle.label("+%d" % hidden, 14, UiStyle.TEXT_DIM)
		add_child(_more)
	_empty.visible = entries.is_empty() and not chips
