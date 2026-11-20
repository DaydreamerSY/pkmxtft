class_name BotBrain
extends RefCounted

## The decisions of a bot player (BotRun calls plan() once per planning phase). Each run draws a profile
## so that the data covers many ways to play, like many players would:
##   style  random (buys on a whim, no aim) | synergy (aims 2 synergies) | reroll (stays low, rerolls for
##          3 stars) | fast (levels up early) | econ (keeps 40-50 gold for the interest)
##   keep   gold kept for the interest     pace   stages per level it aims for     rolls  rerolls a stage
##   aims   synergies aimed for (picked from what it owns, changed when another grows)
##   items  carry (best unit first) | spread (fewest items first) | role (the role's items first)
##   noise  chance of a random decision
## The player actions are the game's (PlayerState: buy, sell, reroll, buy_xp, move_unit, equip, catch_wanderer;
## SynergyItems.pick_berry; the town choices through BotRun.resolve).

const STYLES: Array[String] = ["random", "synergy", "reroll", "fast", "econ"]
const ITEM_RULES: Array[String] = ["carry", "spread", "role"]
const ROW_X: Array[int] = [3, 2, 4, 1, 5, 0, 6]

var style := "random"
var keep := 0
var pace := 6.0
var rolls := 1
var aims := 2
var items_rule := "carry"
var noise := 0.1
var targets: Array[String] = []
var rng := RandomNumberGenerator.new()
## The worker's experience (BotKnowledge): every bot adds its fights to it, the pro bot (BotPro) decides with it.
var knowledge: BotKnowledge = null


## A profile drawn with `seed_value` (`wanted_style`: one of STYLES, else drawn too).
static func random_profile(seed_value: int, wanted_style := "") -> BotBrain:
	var b := BotBrain.new()
	b.rng.seed = seed_value
	b.style = wanted_style if STYLES.has(wanted_style) else STYLES[b.rng.randi() % STYLES.size()]
	match b.style: # pace: stages per level after level 3 (PAC players: ~5 at stage 8, ~8 at stage 20)
		"random":
			b.keep = b.rng.randi_range(0, 20)
			b.pace = b.rng.randf_range(4.0, 6.5)
			b.rolls = b.rng.randi_range(0, 1)
			b.aims = 0
			b.noise = 0.5
		"synergy":
			b.keep = b.rng.randi_range(10, 30)
			b.pace = b.rng.randf_range(4.0, 5.0)
			b.rolls = b.rng.randi_range(0, 2)
			b.aims = 2
		"reroll":
			b.keep = b.rng.randi_range(0, 10)
			b.pace = b.rng.randf_range(5.5, 7.5)
			b.rolls = b.rng.randi_range(2, 6)
			b.aims = b.rng.randi_range(1, 2)
		"fast":
			b.keep = b.rng.randi_range(20, 50)
			b.pace = b.rng.randf_range(3.0, 3.8)
			b.rolls = b.rng.randi_range(0, 1)
			b.aims = 2
		"econ":
			b.keep = b.rng.randi_range(40, 50)
			b.pace = b.rng.randf_range(3.5, 4.5)
			b.rolls = b.rng.randi_range(0, 1)
			b.aims = b.rng.randi_range(2, 3)
			b.noise = 0.05
	b.items_rule = ITEM_RULES[b.rng.randi() % ITEM_RULES.size()]
	return b


## The profile in the TSV: style:keep:pace:rolls:aims:items:noise.
func code() -> String:
	return "%s:%d:%.1f:%d:%d:%s:%.2f" % [style, keep, pace, rolls, aims, items_rule, noise]


func begin(_run: BotRun) -> void:
	targets.clear()


## A fight just ended (BotRun): {stage, win 0 / 1, counts {type: count}, units [{pkm, role, items, share}]}.
func after_fight(_run: BotRun, info: Dictionary) -> void:
	if knowledge != null:
		knowledge.observe(info)


## The run ended (its stage is player.stage).
func end(_run: BotRun) -> void:
	pass


## One planning phase: the choices, wandering Pokémon, berries, aims, level, shop, board, items.
func plan(run: BotRun) -> void:
	var p := run.player
	_choices(run)
	for data in p.wanderers: # the player taps most of the Pokémon walking by
		if ["catchable", "outlaw"].has(String(data.get("kind", ""))) and rng.randf() < 0.9:
			p.catch_wanderer(data)
	p.wanderers.clear()
	for tree in 3:
		SynergyItems.pick_berry(p, tree)
	_retarget(p)
	_level(run)
	_shop(run)
	_lineup(p)
	_items(run)
	_choices(run) # a choice made by an item (Rotom Catalog), a wand of the new board


#region choices
func _choices(run: BotRun) -> void:
	var guard := 0
	while guard < 20:
		guard += 1
		if run.choices.is_empty():
			var wands := run.player.pending_wand_choice() # Game._show_next_choice: a wand waits behind the rest
			if wands.is_empty():
				return
			run.choices.append({"kind": "items", "source": "wand", "items": wands})
		var c: Dictionary = run.choices[0]
		var answer: Variant = _answer(run.player, c)
		if c.kind == "items" and c.source == "wand" and not answer is String:
			return
		run.resolve(answer)


func _answer(p: PlayerState, c: Dictionary) -> Variant:
	match c.kind:
		"portal":
			return _best_index(c.portals.map(func(portal: Dictionary) -> float:
				var aimed := 0.0
				for t in portal.synergies + portal.get("unlocks", []):
					aimed += 1.0 if targets.has(t) else 0.0
				return aimed))
		"pokemon":
			return _best_index(c.pokemons.map(func(choice: String) -> float:
				var score := 0.0
				for member in choice.split("+"):
					score += _want(p, member)
				return score))
		"items":
			var items: Array = c.items
			if items.is_empty():
				return null
			if int(c.get("cost", 0)) > 0 and p.gold - int(c.cost) < keep / 2:
				return null # a carousel item too dear for this bot
			var carry := _carry(p)
			if items_rule == "role" and carry != null:
				var wished: Array = UnitRoles.info(UnitRoles.role_of(carry.pkm)).items
				var fits := items.filter(func(i: String) -> bool: return wished.has(i))
				if not fits.is_empty():
					return fits[rng.randi() % fits.size()]
			return items[rng.randi() % items.size()]
	return null


## Index of the highest score (ties and `noise`: at random).
func _best_index(scores: Array) -> int:
	if scores.is_empty():
		return 0
	if rng.randf() < noise or aims == 0 and style == "random" and rng.randf() < 0.5:
		return rng.randi() % scores.size()
	var best: Array[int] = []
	var top := -INF
	for i in scores.size():
		var s := float(scores[i])
		if s > top + 0.001:
			top = s
			best = [i]
		elif absf(s - top) <= 0.001:
			best.append(i)
	return best[rng.randi() % best.size()]
#endregion


#region economy and shop
## Aims: the synergies most present in what it owns (a random one when it owns nothing that counts).
func _retarget(p: PlayerState) -> void:
	if aims <= 0:
		return
	var counts := {}
	for u in _owned(p):
		for t in u.types():
			counts[t] = int(counts.get(t, 0)) + 1
	var kept: Array[String] = []
	for t in targets:
		if int(counts.get(t, 0)) >= 2 or p.stage < 4:
			kept.append(t)
	var ranked: Array = counts.keys()
	for i in range(ranked.size() - 1, 0, -1): # shuffled with the run's rng (ties at random, same seed = same run)
		var j := rng.randi() % (i + 1)
		var swap = ranked[i]
		ranked[i] = ranked[j]
		ranked[j] = swap
	ranked.sort_custom(func(a: String, b: String) -> bool: return int(counts[a]) > int(counts[b]))
	for t in ranked:
		if kept.size() >= aims:
			break
		if not kept.has(t):
			kept.append(t)
	var all_types := GameData.synergies()
	while kept.size() < aims and not all_types.is_empty():
		var t: String = all_types[rng.randi() % all_types.size()]
		if not kept.has(t):
			kept.append(t)
		elif kept.size() >= all_types.size():
			break
	targets = kept


## Gold that must stay: grows over the first stages (players spend their first gold on a board), less
## when the life runs low (all in).
func _keep(p: PlayerState) -> int:
	var wanted := mini(keep, 4 * p.stage)
	return wanted if p.life > 40 else wanted / 3


## Levels up toward its curve (level 3 at stage 2, then one every `pace` stages; one more when the life
## runs low), and with any gold well above what it keeps (players do not sit on 100 gold).
func _level(run: BotRun) -> void:
	var p := run.player
	var max_level := int(GameData.config.maxLevel)
	var wanted := clampi(3 + int(maxi(p.stage - 2, 0) / pace) + (1 if p.life <= 40 else 0), 1, max_level)
	var guard := 0
	while p.level < max_level and guard < 30:
		guard += 1
		var rich := p.gold - PlayerState.XP_COST >= _keep(p) + 30
		if not (rich or (p.level < wanted and p.gold - PlayerState.XP_COST >= _keep(p))):
			break
		if not p.buy_xp():
			break
		run.stage_xp += 1


func _shop(run: BotRun) -> void:
	var p := run.player
	# more rerolls with gold to spare (above what it keeps): one per 10 gold, 10 at most
	var budget := rolls + clampi((p.gold - _keep(p) - 10) / 10, 0, 10)
	for attempt in budget + 1:
		var guard := 0
		while guard < 12:
			guard += 1
			var best := -1
			var top := 0.0
			for i in p.shop.size():
				if p.shop[i] == "":
					continue
				var s := _want(p, p.shop[i])
				if s > top:
					top = s
					best = i
			if best < 0 or top < 1.0:
				break
			var pkm := p.shop[best]
			# a merge, or a board not full yet: worth all the gold
			var needed := _copies(p, pkm) >= 2 or p.team_count() + _bench_count(p) < p.max_team_size()
			if p.gold - PlayerState.buy_price(pkm) < (0 if needed else _keep(p)):
				break
			if not p.can_buy(best) and not _make_room(run, pkm):
				break
			if not p.can_buy(best):
				break
			p.buy(best)
			run.stage_bought += 1
		if attempt < budget and p.gold - PlayerState.REROLL_COST >= _keep(p) + 2:
			if not p.reroll():
				break
			run.stage_rolls += 1
		else:
			break


## How much it wants `pkm` (shop or choice): copies toward a merge, aimed synergies, rarity, bodies
## for the team, a whim.
func _want(p: PlayerState, pkm: String) -> float:
	var data := GameData.get_pokemon(pkm)
	if data.is_empty():
		return 0.0
	var score := 0.3 * GameData.rarity_cost(String(data.get("rarity", "COMMON")))
	score += 2.5 * _copies(p, pkm)
	for t in data.get("types", []):
		score += 2.0 if targets.has(t) else 0.0
	if p.team_count() + _bench_count(p) < p.max_team_size() + 1:
		score += 1.5 # bodies for the board
	var weakest := INF # stronger than the weakest of the board: an upgrade of the team
	for u in p.board.values():
		if not u.is_inanimate():
			weakest = minf(weakest, _score(u))
	if p.team_count() >= p.max_team_size() and GameData.rarity_cost(String(data.get("rarity", "COMMON"))) > weakest:
		score += 2.0
	if aims == 0 or rng.randf() < noise:
		score += rng.randf() * 3.0
	return score


## Sells the bench Pokémon it wants least to make room (never one toward a merge with `for_pkm`).
func _make_room(run: BotRun, for_pkm: String) -> bool:
	var p := run.player
	var worst: PlayerState.OwnedUnit = null
	var low := INF
	for u in p.bench:
		if u == null or u.is_inanimate() or u.pkm == for_pkm:
			continue
		var s := _score(u)
		if s < low:
			low = s
			worst = u
	if worst == null or low >= _want(p, for_pkm) * 2.0:
		return false
	p.sell(worst)
	run.stage_sold += 1
	return true


func _copies(p: PlayerState, pkm: String) -> int:
	var n := 0
	for u in _owned(p):
		if u.pkm == pkm:
			n += 1
	return n


func _bench_count(p: PlayerState) -> int:
	return p.bench.filter(func(u) -> bool: return u != null and not u.is_inanimate()).size()
#endregion


#region board and items
## Value of an owned Pokémon: rarity x stars, aimed synergies, items held.
func _score(u: PlayerState.OwnedUnit) -> float:
	var cost := GameData.rarity_cost(String(u.data().get("rarity", "COMMON")))
	var score := float(maxi(cost, 1)) * pow(3.0, u.stars() - 1)
	for t in u.types():
		score += 2.0 if targets.has(t) else 0.0
	return score + 0.5 * u.items.size()


func _owned(p: PlayerState) -> Array:
	var out: Array = []
	for u in p.board.values() + p.bench:
		if u != null and not u.is_inanimate():
			out.append(u)
	return out


## The best Pokémon on the board, up to the team size: a bench one replaces the weakest of the board,
## a free cell takes it by range (melee front, range 2 middle, farther back).
func _lineup(p: PlayerState) -> void:
	var guard := 0
	while guard < 12:
		guard += 1
		var best_bench: PlayerState.OwnedUnit = null
		for u in p.bench:
			if u != null and not u.is_inanimate() and (best_bench == null or _score(u) > _score(best_bench)):
				best_bench = u
		if best_bench == null:
			return
		if p.team_count() < p.max_team_size():
			var cell: Variant = _free_cell(p, best_bench)
			if cell == null or not p.move_unit(best_bench, {"board": cell}):
				return
			continue
		var worst_cell: Variant = null
		var low := INF
		for c in p.board:
			var b: PlayerState.OwnedUnit = p.board[c]
			if not b.is_inanimate() and _score(b) < low:
				low = _score(b)
				worst_cell = c
		if worst_cell == null or low >= _score(best_bench) or not p.move_unit(best_bench, {"board": worst_cell}):
			return


func _free_cell(p: PlayerState, u: PlayerState.OwnedUnit) -> Variant:
	var r := int(u.data().get("range", 1))
	var rows: Array = [3, 2, 1, 0] if r <= 1 else ([2, 3, 1, 0] if r == 2 else [0, 1, 2, 3])
	for y in rows:
		for x in ROW_X:
			if not p.board.has(Vector2i(x, y)):
				return Vector2i(x, y)
	return null


## The Pokémon getting the items first.
func _carry(p: PlayerState) -> PlayerState.OwnedUnit:
	var best: PlayerState.OwnedUnit = null
	for u in p.board.values():
		if not u.is_inanimate() and u.items.size() < 3 and (best == null or _score(u) > _score(best)):
			best = u
	return best


## Every item of the item bench to a board Pokémon (PlayerState.equip: it combines, evolves, refuses...).
func _items(run: BotRun) -> void:
	var p := run.player
	var i := p.items.size() - 1
	while i >= 0:
		if i < p.items.size():
			var target := _item_target(p, p.items[i])
			if target != null:
				var result := p.equip(i, target)
				if result.get("ok", false) and result.has("choice"):
					run.choices.append(result.choice)
		i -= 1


func _item_target(p: PlayerState, item: String) -> PlayerState.OwnedUnit:
	var units: Array = p.board.values().filter(func(u: PlayerState.OwnedUnit) -> bool:
		return not u.is_inanimate() and u.items.size() < 3)
	if units.is_empty():
		return null
	match items_rule:
		"spread":
			units.sort_custom(func(a: PlayerState.OwnedUnit, b: PlayerState.OwnedUnit) -> bool:
				return a.items.size() < b.items.size() or (a.items.size() == b.items.size() and _score(a) > _score(b)))
			return units[0]
		"role":
			for u in units:
				if UnitRoles.info(UnitRoles.role_of(u.pkm)).items.has(item):
					return u
	return _carry(p)
#endregion
