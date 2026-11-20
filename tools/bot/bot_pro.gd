class_name BotPro
extends BotBrain

## The pro bot: plays like a strong player who adapts to the run instead of forcing one recipe. Its judgement is
## learned, not written: a win model (BotModel, logistic regression on the bots' fights: stage, level, wave,
## synergy tiers, pairs of synergies, Pokémon, items) and the experience tables (BotKnowledge) when there is no model.
##   plan      2 or 3 synergies chosen from THIS run: what it owns, what the shop pool offers, the learned value of
##             their tiers and of their pair (a damage synergy with a buff / tank one gets a small bonus); drawn
##             among the best ones (softmax: some variety, never a fixed recipe), looked at again every 3 stages
##             (a pivot when another path is clearly better)
##   board     the team the model rates best against the wave of the stage (swaps of owned Pokémon), a little
##             for the plan's progress, 2 front-liners and a carry at least
##   shop      what raises the model's odds most (instead of the weakest of the team, or a free slot), copies toward
##             a 3-star, the plan's synergies; rerolls with gold to spare; the shop locked on a wanted Pokémon
##   items     where the model values them most (components kept for the carry / a front-liner), evolution items,
##             TMs, dishes, synergy stones that complete a tier, Cell Battery
##   economy   keeps gold for the interest while the model says the team is safe, spends it all when the odds
##             against the wave are low (or a boss, a low life, a lost fight); the keep / level pace of the run is
##             drawn among the learned ones (softmax)
##   place     front-liners in front, carries in the back corners, the carry in the Light spotlight, Ground on its hole
## Style "design" (BotPro with a fixed plan): the design test - every combo of synergies of the pool shared evenly
## between the runs (`design_index`), played with the best known economy, the rest of the run adapted as usual.

const DAMAGE: Array[String] = ["FIRE", "ELECTRIC", "DARK", "POISON", "MONSTER", "FAIRY", "BUG", "GHOST", "WILD", "PSYCHIC"]
const KEEPS: Array[int] = [10, 20, 30, 40, 50]
const PACES: Array[float] = [3.0, 3.5, 4.0, 4.5, 5.0]
const FRONT_ROLES: Array[String] = ["tank", "fighter"]
const CARRY_ROLES: Array[String] = ["caster", "marksman", "assassin"]
const SCALE := 30.0 ## tables: an adj of 1 in unit-value points (a 1-star Common = 1)
const FRONT_X: Array[int] = [3, 2, 4, 1, 5, 0, 6]
const BACK_X: Array[int] = [0, 6, 1, 5, 2, 4, 3]
const TEMPERATURE := 0.12 ## softmax of the plan / economy choices (higher = more variety)

var model: BotModel = null
var plan_types: Array[String] = []
var econ_key := ""
## Design test: the run's place in the list of combos (-1 = an adaptive pro), and the size of the combos.
var design_index := -1
var combo_size := 2
var _lost_last := false
var _run: BotRun
var _value_cache := {}


static func create(seed_value: int, mind: BotKnowledge, win_model: BotModel, design := -1, size := 2) -> BotPro:
	var b := BotPro.new()
	b.rng.seed = seed_value
	b.style = "pro" if design < 0 else "design"
	b.knowledge = mind
	b.model = win_model
	b.design_index = design
	b.combo_size = clampi(size, 2, 3)
	b.items_rule = "pro"
	b.noise = 0.0
	b.aims = 2
	b.rolls = 2
	return b


func begin(run: BotRun) -> void:
	_run = run
	targets.clear()
	plan_types.clear()
	_lost_last = false
	# the economy: the best known one for a design test, else one drawn among the learned ones
	var keys: Array[String] = []
	var scores: Array[float] = []
	for k in KEEPS:
		for pc in PACES:
			var key := "%d:%.1f" % [k, pc]
			keys.append(key)
			scores.append(knowledge.mean("econ", key, 20.0, 3.0) / 30.0)
	econ_key = keys[_argmax(scores) if design_index >= 0 else _softmax_pick(scores)]
	var parts := econ_key.split(":")
	keep = int(parts[0])
	pace = float(parts[1])
	if design_index >= 0:
		var combos := design_combos(combo_size)
		if not combos.is_empty():
			plan_types.assign(combos[design_index % combos.size()])
			targets.assign(plan_types)


func plan(run: BotRun) -> void:
	var p := run.player
	_run = run
	_value_cache.clear()
	if design_index < 0 and (plan_types.is_empty() or p.stage % 3 == 2):
		_choose_plan(p)
	_pro_choices(run)
	for data in p.wanderers:
		if ["catchable", "outlaw"].has(String(data.get("kind", ""))):
			p.catch_wanderer(data)
	p.wanderers.clear()
	for tree in 3:
		SynergyItems.pick_berry(p, tree)
	_pro_level(run)
	_pro_shop(run)
	_pro_board(p)
	_pro_items(run)
	_value_cache.clear()
	_pro_board(p)
	_pro_choices(run)
	_pro_lock(p)


func after_fight(run: BotRun, info: Dictionary) -> void:
	super.after_fight(run, info)
	_lost_last = int(info.win) == 0


## What the run reached with its plan and its economy (BotKnowledge; analysis and the economy choice).
func end(run: BotRun) -> void:
	var sorted_plan := plan_types.duplicate()
	sorted_plan.sort()
	if not sorted_plan.is_empty():
		knowledge.add("plan", "+".join(sorted_plan), run.player.stage)
	knowledge.add("econ", econ_key, run.player.stage)


## Every combo of `size` synergies the shop pool has 3 families of at least (the design test's list, sorted).
static func design_combos(size: int) -> Array:
	var counts := {}
	for rarity in GameData.SHOP_RARITIES:
		for pkm in GameData.tier1_by_rarity[rarity]:
			for t in GameData.get_pokemon(pkm).get("types", []):
				counts[t] = int(counts.get(t, 0)) + 1
	var types: Array = counts.keys().filter(func(t: String) -> bool: return int(counts[t]) >= 3)
	types.sort()
	var out: Array = []
	for i in types.size():
		for j in range(i + 1, types.size()):
			if size == 2:
				out.append([types[i], types[j]])
			else:
				for k in range(j + 1, types.size()):
					out.append([types[i], types[j], types[k]])
	return out


#region adaptive plan
## The plan from what this run has: each synergy is worth the learned value of the tiers it can still reach (what
## it owns + part of what the shop pool offers), plus the learned value of the pair; the plan is drawn among the
## best (softmax) with a bonus for the current one (a pivot needs a clearly better path). A third synergy joins when
## it adds enough (wide teams at higher levels).
func _choose_plan(p: PlayerState) -> void:
	var pool := {}
	for rarity in GameData.SHOP_RARITIES:
		for pkm in GameData.tier1_by_rarity[rarity]:
			for t in GameData.get_pokemon(pkm).get("types", []):
				pool[t] = int(pool.get(t, 0)) + 1
	var owned := {}
	for u in _owned(p):
		for t in u.types():
			owned[t] = int(owned.get(t, 0)) + 1
	var offered := {} # what this run's shop shows now
	for pkm in p.shop:
		if pkm != "":
			for t in GameData.get_pokemon(pkm).get("types", []):
				offered[t] = int(offered.get(t, 0)) + 1
	var single := {}
	for t in pool:
		if int(pool[t]) < 2 and not owned.has(t):
			continue
		# what the run gives decides: owned Pokémon, the shop now, a little of the pool (the same for every run)
		var reach := roundi(int(owned.get(t, 0)) + 0.5 * int(offered.get(t, 0)) + 0.2 * mini(int(pool[t]), 6))
		single[t] = _tier_worth(t, Synergies.tier(t, reach)) + 0.08 * int(owned.get(t, 0))
	var names: Array = single.keys()
	names.sort()
	var pairs: Array = []
	var scores: Array[float] = []
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: String = names[i]
			var b: String = names[j]
			var s := float(single[a]) + float(single[b]) + _pair_worth(a, b)
			if plan_types.has(a) and plan_types.has(b):
				s += 0.15 # keeping its line unless another one is clearly better
			pairs.append([a, b])
			scores.append(s)
	if pairs.is_empty():
		return
	var chosen: Array = pairs[_softmax_pick(scores)]
	plan_types.assign(chosen)
	if p.level >= 6: # a third synergy when it adds enough to the two
		var best := ""
		var top := 0.25
		for t in names:
			if plan_types.has(t) or int(owned.get(t, 0)) < 2: # a third synergy it has started already
				continue
			var add := float(single[t]) + _pair_worth(plan_types[0], t) + _pair_worth(plan_types[1], t)
			if add > top:
				top = add
				best = t
		if best != "":
			plan_types.append(best)
	targets.assign(plan_types)


## Learned value (log-odds) of a synergy up to `tier`.
func _tier_worth(type: String, tier: int) -> float:
	var v := 0.0
	for k in range(1, tier + 1):
		v += model.weight("sy:%s:%d" % [type, k]) if model != null \
			else knowledge.mean("syn", "%s:%d" % [type, k], 0.0, 20.0) * 4.0
	return v


func _pair_worth(a: String, b: String) -> float:
	var x := a if a < b else b
	var y := b if a < b else a
	var learned := model.weight("pr:%s+%s" % [x, y]) if model != null \
		else knowledge.mean("pair", "%s+%s" % [x, y], 0.0, 20.0) * 4.0
	return learned + 0.05 * _complement(a, b)


## 1 for a damage synergy with a support / tank one, 0.3 for two damage ones, 0 for two support ones.
static func _complement(a: String, b: String) -> float:
	var da := DAMAGE.has(a)
	var db := DAMAGE.has(b)
	if da != db:
		return 1.0
	return 0.3 if da else 0.0


## Index drawn with softmax weights (TEMPERATURE).
func _softmax_pick(scores: Array[float]) -> int:
	var top := -INF
	for s in scores:
		top = maxf(top, s)
	var weights: Array[float] = []
	var total := 0.0
	for s in scores:
		var e := exp((s - top) / TEMPERATURE)
		weights.append(e)
		total += e
	var roll := rng.randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1


func _argmax(scores: Array[float]) -> int:
	var best := 0
	for i in scores.size():
		if scores[i] > scores[best]:
			best = i
	return best
#endregion


#region values
func _cost_value(rarity: String, stars: int) -> float:
	return float(maxi(GameData.rarity_cost(rarity), 1)) * pow(3.0, stars - 1)


## Strength of a team: the model's log-odds against the wave of the stage (or the tables' points), the plan's
## progress, 2 front-liners and a carry. Model and tables are on different scales: only compared with each other.
func _board_value(p: PlayerState, units: Array) -> float:
	var list: Array = []
	var front := 0
	var carry := 0
	for u in units:
		list.append({"family": u.family(), "types": u.types(), "passive": u.passive()})
		var role := UnitRoles.role_of(u.pkm)
		if FRONT_ROLES.has(role):
			front += 1
		elif CARRY_ROLES.has(role):
			carry += 1
	var counts := Synergies.count(list, p.bonus_synergies)
	var v := 0.0
	var unit_scale := 1.0
	if model != null:
		v = model.logit(p.stage, p.level, BotRun.wave_code(_run.wave), units, counts)
		unit_scale = 0.1 # the bonuses below in log-odds
	else:
		for u in units:
			v += _unit_value(u)
		v += _table_synergy_value(counts)
	for type in counts:
		if plan_types.has(type):
			v += 0.8 * unit_scale * int(counts[type])
	if units.size() >= 4:
		v -= 3.0 * unit_scale * (maxi(2 - front, 0) + maxi(1 - carry, 0))
	return v


## Tables (no model): cost x stars, items, learned adj of the Pokémon.
func _unit_value(u: PlayerState.OwnedUnit) -> float:
	if _value_cache.has(u):
		return float(_value_cache[u])
	var v := _cost_value(String(u.data().get("rarity", "COMMON")), u.stars()) * (1.0 + 0.15 * u.items.size()) \
		+ SCALE * clampf(knowledge.mean("unit", u.pkm, 0.0, 20.0), -0.15, 0.15)
	_value_cache[u] = v
	return v


func _table_synergy_value(counts: Dictionary) -> float:
	var v := 0.0
	var active: Array[String] = []
	for type in counts:
		var tier := Synergies.tier(type, int(counts[type]))
		if tier > 0:
			active.append(type)
			v += 2.5 * tier + SCALE * knowledge.mean("syn", "%s:%d" % [type, tier], 0.0, 20.0)
	active.sort()
	for i in active.size():
		for j in range(i + 1, active.size()):
			v += 0.5 * SCALE * knowledge.mean("pair", active[i] + "+" + active[j], 0.03 * _complement(active[i], active[j]), 20.0)
	return v


## A Pokémon not owned yet (a choice): its learned worth, its plan synergies, copies toward a merge.
func _pkm_value(p: PlayerState, pkm: String) -> float:
	var data := GameData.get_pokemon(pkm)
	if data.is_empty():
		return 0.0
	var v := _cost_value(String(data.get("rarity", "COMMON")), int(data.get("stars", 1))) * 0.2
	v += model.weight("u:" + pkm) * 5.0 if model != null else SCALE * clampf(knowledge.mean("unit", pkm, 0.0, 20.0), -0.15, 0.15)
	for t in data.get("types", []):
		v += 1.5 if plan_types.has(t) else 0.0
	return v + 1.5 * _copies(p, pkm)


## Odds of the team on the board against the wave of the stage (0.5 without a model).
func _win_odds(p: PlayerState) -> float:
	if model == null:
		return 0.5
	var units: Array = p.board.values().filter(func(u: PlayerState.OwnedUnit) -> bool: return not u.is_inanimate())
	return BotModel.prob(model.logit(p.stage, p.level, BotRun.wave_code(_run.wave), units, p.synergy_counts()))
#endregion


#region choices
func _pro_choices(run: BotRun) -> void:
	var guard := 0
	while guard < 20:
		guard += 1
		if run.choices.is_empty():
			var wands := run.player.pending_wand_choice()
			if wands.is_empty():
				return
			run.choices.append({"kind": "items", "source": "wand", "items": wands})
		run.resolve(_pro_answer(run.player, run.choices[0]))


func _pro_answer(p: PlayerState, c: Dictionary) -> Variant:
	var scores: Array[float] = []
	match c.kind:
		"portal":
			for portal in c.portals:
				var s := rng.randf() * 0.1
				for t in portal.synergies:
					s += 2.0 if plan_types.has(t) else 0.0
				for t in portal.get("unlocks", []):
					s += 3.0 if plan_types.has(t) else 0.5
				scores.append(s)
			return _argmax(scores)
		"pokemon":
			for choice in c.pokemons:
				var s := 0.0
				for member in String(choice).split("+"):
					s += _pkm_value(p, member)
				scores.append(s)
			return _argmax(scores)
		"items":
			var items: Array = c.items
			if items.is_empty():
				return null
			if c.source == "wand":
				return items[rng.randi() % items.size()]
			var cost := int(c.get("cost", 0))
			if cost > 0 and p.gold - cost < keep - 10:
				return null
			var carry := _main_carry(p.board.values())
			for item in items:
				scores.append(_item_worth(String(item), UnitRoles.role_of(carry.pkm) if carry != null else "fighter"))
			return items[_argmax(scores)]
	return null
#endregion


#region economy and shop
## In danger: a boss, a low life, a lost fight, or low odds against this wave (the model) - every gold goes in.
func _danger(run: BotRun) -> bool:
	var p := run.player
	return p.life <= 40 or _lost_last or String(run.wave.get("kind", "")) == "boss" or _win_odds(p) < 0.35


## Gold kept: none in danger, the interest target when safe (more of it when the model says the fight is won).
func _floor_gold(run: BotRun) -> int:
	if _danger(run):
		return 0
	var wanted := 50 if _win_odds(run.player) > 0.85 and run.player.life > 50 else keep
	return mini(wanted, 4 * run.player.stage)


func _pro_level(run: BotRun) -> void:
	var p := run.player
	var max_level := int(GameData.config.maxLevel)
	var floor_gold := _floor_gold(run)
	var wanted := clampi(3 + int(maxi(p.stage - 2, 0) / pace) + (1 if _danger(run) else 0), 1, max_level)
	var guard := 0
	while p.level < max_level and guard < 30:
		guard += 1
		var rich := p.gold - PlayerState.XP_COST >= floor_gold + 30
		if not (rich or (p.level < wanted and p.gold - PlayerState.XP_COST >= floor_gold)):
			break
		if not p.buy_xp():
			break
		run.stage_xp += 1


## How much a shop Pokémon raises the team: with the model, the gain of its odds when it joins the team (instead of
## the weakest, or on a free slot); copies toward a 3-star and the plan's synergies on top.
func _shop_want(p: PlayerState, pkm: String) -> float:
	var copies := _copies(p, pkm)
	var plan_bonus := 0.0
	for t in GameData.get_pokemon(pkm).get("types", []):
		plan_bonus += 1.0 if plan_types.has(t) else 0.0
	if model == null:
		return _pkm_value(p, pkm) + (8.0 if copies >= 2 else 0.0)
	var board: Array = p.board.values().filter(func(u: PlayerState.OwnedUnit) -> bool: return not u.is_inanimate())
	var before := _board_value(p, board)
	var trial := board.duplicate()
	var newcomer := PlayerState.OwnedUnit.new(pkm)
	if trial.size() < p.max_team_size():
		trial.append(newcomer)
	elif not trial.is_empty():
		var weakest := 0
		for i in trial.size():
			if model.weight("u:" + String(trial[i].pkm)) < model.weight("u:" + String(trial[weakest].pkm)):
				weakest = i
		trial[weakest] = newcomer
	var gain := _board_value(p, trial) - before
	return 10.0 * gain + 1.5 * plan_bonus + (8.0 if copies >= 2 else 2.5 * copies) \
		+ (2.0 if p.team_count() + _bench_count(p) < p.max_team_size() else 0.0)


func _pro_shop(run: BotRun) -> void:
	var p := run.player
	var danger := _danger(run)
	var floor_gold := _floor_gold(run)
	var budget := rolls + clampi((p.gold - floor_gold - 10) / 8, 0, 12) + (6 if danger else 0)
	for attempt in budget + 1:
		var guard := 0
		while guard < 12:
			guard += 1
			var best := -1
			var top := 0.0
			for i in p.shop.size():
				if p.shop[i] == "":
					continue
				var s := _shop_want(p, p.shop[i])
				if s > top:
					top = s
					best = i
			if best < 0 or top < 2.0:
				break
			var pkm := p.shop[best]
			var needed := _copies(p, pkm) >= 2 or p.team_count() + _bench_count(p) < p.max_team_size() or top >= 6.0
			if p.gold - PlayerState.buy_price(pkm) < (0 if needed else floor_gold):
				break
			if not p.can_buy(best) and not _pro_room(run, pkm, top):
				break
			if not p.can_buy(best):
				break
			p.buy(best)
			run.stage_bought += 1
			_value_cache.clear()
		if attempt < budget and p.gold - PlayerState.REROLL_COST >= floor_gold + 2:
			if not p.reroll():
				break
			run.stage_rolls += 1
		else:
			break


## Sells the bench Pokémon worth least (not a copy of `for_pkm`) when it is worth less than what comes.
func _pro_room(run: BotRun, for_pkm: String, want: float) -> bool:
	var p := run.player
	var worst: PlayerState.OwnedUnit = null
	var low := INF
	for u in p.bench:
		if u == null or u.is_inanimate() or u.pkm == for_pkm:
			continue
		var s: float = _pkm_value(p, u.pkm) + 2.0 * u.stars()
		if s < low:
			low = s
			worst = u
	if worst == null or low >= want:
		return false
	p.sell(worst)
	run.stage_sold += 1
	_value_cache.clear()
	return true


func _pro_lock(p: PlayerState) -> void:
	var lock := false
	for pkm in p.shop:
		if pkm != "" and p.gold < PlayerState.buy_price(pkm) and _shop_want(p, pkm) >= 6.0:
			lock = true
	if lock != p.shop_locked:
		p.toggle_lock()
#endregion


#region board
## The best team (swaps that raise _board_value), then its cells.
func _pro_board(p: PlayerState) -> void:
	var size := p.max_team_size()
	var owned := _owned(p)
	if owned.is_empty():
		return
	var solo := func(u: PlayerState.OwnedUnit) -> float: return _board_value(p, [u])
	var ranked: Array = []
	for u in owned:
		ranked.append([solo.call(u), u])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var chosen: Array = []
	var rest: Array = []
	for i in ranked.size():
		(chosen if i < size else rest).append(ranked[i][1])
	var value := _board_value(p, chosen)
	for _pass in 3:
		var improved := false
		for i in chosen.size():
			for j in rest.size():
				var trial := chosen.duplicate()
				trial[i] = rest[j]
				var tv := _board_value(p, trial)
				if tv > value + 0.001:
					var out: PlayerState.OwnedUnit = chosen[i]
					chosen = trial
					rest[j] = out
					value = tv
					improved = true
		if not improved:
			break
	_place(p, chosen)


func _place(p: PlayerState, chosen: Array) -> void:
	for u in chosen: # on the board: in place of one not chosen, or on a free cell
		if p.find(u).has("board"):
			continue
		var swap_cell: Variant = null
		for c in p.board:
			var b: PlayerState.OwnedUnit = p.board[c]
			if not b.is_inanimate() and not chosen.has(b):
				swap_cell = c
				break
		if swap_cell != null:
			p.move_unit(u, {"board": swap_cell})
		elif p.team_count() < p.max_team_size():
			var free: Variant = _empty_board_cell(p)
			if free != null:
				p.move_unit(u, {"board": free})
	var cells := _target_cells(p, chosen)
	for _pass in 2:
		for u in cells:
			var loc := p.find(u)
			var want: Vector2i = cells[u]
			if loc.has("board") and loc.board != want:
				p.move_unit(u, {"board": want})


## The carry: the model's / tables' most valued Pokémon among the damage roles (anyone when there is none).
func _main_carry(units: Array) -> PlayerState.OwnedUnit:
	var best: PlayerState.OwnedUnit = null
	var top := -INF
	for u in units:
		if u == null or u.is_inanimate():
			continue
		var worth: float = model.weight("u:" + u.pkm) * 10.0 + u.stars() * 2.0 + u.items.size() if model != null else _unit_value(u)
		var s: float = worth * (1.0 + 3.0 * knowledge.mean("share", u.pkm, 0.15, 10.0)) * (1.5 if CARRY_ROLES.has(UnitRoles.role_of(u.pkm)) else 1.0)
		if s > top:
			top = s
			best = u
	return best


func _target_cells(p: PlayerState, chosen: Array) -> Dictionary:
	var out := {}
	var taken := {}
	for c in p.board:
		if (p.board[c] as PlayerState.OwnedUnit).is_inanimate():
			taken[c] = true
	var carry := _main_carry(chosen)
	if carry != null and p.synergy_tier("LIGHT") > 0 and PlayerState.is_player_cell(p.light_cell) and not taken.has(p.light_cell):
		out[carry] = p.light_cell
		taken[p.light_cell] = true
	if p.synergy_tier("GROUND") > 0:
		for u in chosen:
			var loc := p.find(u)
			if not out.has(u) and u.types().has("GROUND") and loc.has("board") and not taken.has(loc.board):
				out[u] = loc.board
				taken[loc.board] = true
	var front: Array = []
	var back: Array = []
	var middle: Array = []
	for u in chosen:
		if out.has(u):
			continue
		var role := UnitRoles.role_of(u.pkm)
		var r := int(u.data().get("range", 1))
		if FRONT_ROLES.has(role) or r <= 1:
			front.append(u)
		elif r >= 3 or CARRY_ROLES.has(role):
			back.append(u)
		else:
			middle.append(u)
	front.sort_custom(func(a: PlayerState.OwnedUnit, b: PlayerState.OwnedUnit) -> bool: return _bulk(a) > _bulk(b))
	if carry != null and back.has(carry): # the carry takes the safest corner
		back.erase(carry)
		back.push_front(carry)
	for u in front:
		_assign(out, taken, u, [3, 2, 1, 0], FRONT_X)
	for u in back:
		_assign(out, taken, u, [0, 1, 2, 3], BACK_X)
	for u in middle:
		_assign(out, taken, u, [2, 1, 0, 3], FRONT_X)
	return out


func _assign(out: Dictionary, taken: Dictionary, u: PlayerState.OwnedUnit, rows: Array, xs: Array[int]) -> void:
	for y in rows:
		for x in xs:
			var c := Vector2i(x, y)
			if not taken.has(c):
				out[u] = c
				taken[c] = true
				return


func _empty_board_cell(p: PlayerState) -> Variant:
	for y in [3, 2, 1, 0]:
		for x in FRONT_X:
			if not p.board.has(Vector2i(x, y)):
				return Vector2i(x, y)
	return null


func _bulk(u: PlayerState.OwnedUnit) -> float:
	var d := u.data()
	return float(d.get("hp", 0)) * (1.0 + 0.1 * (float(d.get("def", 0)) + float(d.get("speDef", 0))))
#endregion


#region items
## Learned worth of an item held by a Pokémon of `role`: the model's weight of the item, or the tables' adj.
func _item_worth(item: String, role: String) -> float:
	if model != null:
		return 1.0 + 10.0 * model.weight("it:" + item) + (0.2 if UnitRoles.info(role).items.has(item) else 0.0)
	var prior := 0.03 if UnitRoles.info(role).items.has(item) else 0.0
	return 1.0 + 10.0 * knowledge.mean("item", "%s@%s" % [item, role], prior, 15.0)


func _pro_items(run: BotRun) -> void:
	var p := run.player
	var guard := 0
	while guard < 30 and not p.items.is_empty():
		guard += 1
		var units: Array = p.board.values().filter(func(u: PlayerState.OwnedUnit) -> bool: return not u.is_inanimate())
		var carry := _main_carry(units)
		var best_i := -1
		var best_u: PlayerState.OwnedUnit = null
		var top := 0.0
		for i in p.items.size():
			for u in units:
				var s := _equip_score(p, i, u, carry)
				if s > top:
					top = s
					best_i = i
					best_u = u
		if best_i < 0:
			return
		var result := p.equip(best_i, best_u)
		if not result.get("ok", false):
			return
		if result.has("choice"):
			run.choices.append(result.choice)
		_value_cache.clear()


func _equip_score(p: PlayerState, index: int, u: PlayerState.OwnedUnit, carry: PlayerState.OwnedUnit) -> float:
	var preview := p.equip_preview(index, u)
	if not preview.get("ok", false):
		return 0.0
	var item := p.items[index]
	var weight := 1.5 if u == carry else 1.0
	if preview.has("teach"):
		return 3.0 * weight
	if preview.get("eat", false):
		return 2.0 * weight
	if preview.get("special", false):
		return 6.0
	if preview.get("use", false):
		return 2.0 if item == "CELL_BATTERY" else 0.0
	if u.data().get("evolutionByItem", {}).has(item):
		return 6.0
	if GameData.item_in(item, "SynergyStones"):
		return _stone_score(p, u, GameData.item_synergy(item))
	var result := String(preview.get("result", item))
	if GameData.is_component(result):
		return (0.8 if u == carry else 0.4) if u.items.size() < 2 else 0.0
	return weight * _item_worth(result, UnitRoles.role_of(u.pkm))


func _stone_score(p: PlayerState, u: PlayerState.OwnedUnit, type: String) -> float:
	if type == "" or u.types().has(type):
		return 0.0
	var n := int(p.synergy_counts().get(type, 0))
	if Synergies.tier(type, n + 1) > Synergies.tier(type, n):
		return 5.0 if plan_types.has(type) else 2.5
	return 0.3
#endregion
