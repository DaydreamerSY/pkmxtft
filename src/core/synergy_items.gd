class_name SynergyItems
extends RefCounted

## Items given by the synergies and what they do between stages / in fights
## (port of app/models/colyseus-models/player.ts update*(), app/core/effects/items.ts
## OnStageStart effects, pokemon-entity.ts eatBerry):
##   Gourmet  Chef Hats (1 / 1 / 2 by tier), held by Gourmet Pokémon: cook dishes each stage
##   Grass    berry trees (1 / 2 / 3 growing), ripe = pick a berry; held berries eaten < 50% HP
##   Water    Old / Good / Super Rod (tier 1 / 2 / 3) in the item bench: a fish each stage
##   Normal   1 Silk Scarf per tier (crafted scarves are remembered and given back)
##   Artificial  one of the 3 tools of the run per tier
##   Baby     eggs found after a lost fight, hatching after 5 stages (4 at tier 2+)
##   Flora    flower pots: a fainting Flora Pokémon makes the next pot blossom in the fight;
##            mulch (stars of the fallen) gives Rich Mulch to grow the pots / ripen trees

const CHEF_HAT := "CHEF_HAT"
const HATS_BY_TIER := [0, 1, 1, 2]
const DISHES_BY_TIER := [0, 1, 2, 2]
const MUSHROOM_WEIGHTS := {"TINY_MUSHROOM": 77, "BIG_MUSHROOM": 20, "BALM_MUSHROOM": 3}
const GOLDEN_BERRIES := ["GOLDEN_RAZZ_BERRY", "GOLDEN_NANAB_BERRY", "GOLDEN_PINAP_BERRY"]
const BERRY_TREE_RIPE := 3
const NO_EATERS := ["UNOWN", "TATSUGIRI"]
const RODS := ["OLD_ROD", "GOOD_ROD", "SUPER_ROD"]
const ROD_FALLBACK := {"OLD_ROD": "MAGIKARP", "GOOD_ROD": "FEEBAS", "SUPER_ROD": "WISHIWASHI"}


## Everything following the synergies of the board (called after board / item changes).
static func update_all(p: PlayerState) -> void:
	update_chef_hats(p)
	update_rods(p)
	update_scarves(p)
	update_artificial(p)
	update_tms(p)


#region Flora: flower pots
const MULCH_CAPS := [5, 8, 11, 15, 20, 27, 36, 50]
const POT_LINES := [["HOPPIP", "SKIPLOOM", "JUMPLUFF"], ["BELLSPROUT", "WEEPINBELL", "VICTREEBEL"],
	["CHIKORITA", "BAYLEEF", "MEGANIUM"], ["ODDISH", "GLOOM", "VILEPLUME"], ["BELLOSSOM"]]


## getFlowerPotsUnlocked: pots that can blossom, in the order of the run: tier 1 the pink
## one, 2 + yellow, 3 + white, 4 + blue (+ orange when all the others are fully grown).
static func pots_unlocked(p: PlayerState) -> Array[int]:
	var tier := p.synergy_tier("FLORA")
	var grown := true
	for i in 4:
		grown = grown and GameData.evolutions_of(p.flower_pots[i]).is_empty()
	var out: Array[int] = []
	for pot in p.flower_order:
		if pot < tier or (pot == 4 and tier >= 4 and grown):
			out.append(pot)
	return out


## collectMulch: mulch = stars of the Flora Pokémon fallen; at the cap, a Rich Mulch
## (Amaze Mulch once 8 were collected) and the cap grows.
static func collect_mulch(p: PlayerState, amount: int) -> void:
	if amount <= 0:
		return
	p.mulch += amount
	while p.mulch >= p.mulch_cap:
		p.mulch -= p.mulch_cap
		var i := MULCH_CAPS.find(p.mulch_cap)
		p.mulch_cap = MULCH_CAPS[mini(i + 1, MULCH_CAPS.size() - 1)]
		var grown := p.items.count("RICH_MULCH")
		for pot in p.flower_pots:
			grown += int(GameData.get_pokemon(pot).get("stars", 1))
		p.items.append("AMAZE_MULCH" if grown - 8 >= 8 else "RICH_MULCH")


## Mulch dropped on a pot (grows it) or a berry tree (Rich: ripe; Amaze: golden berry).
## `target` = {"pot": i} or {"tree": i}. Returns a message ("" = refused).
static func use_mulch(p: PlayerState, index: int, target: Dictionary) -> String:
	if index < 0 or index >= p.items.size():
		return ""
	var item := p.items[index]
	if target.has("pot"):
		var pot := int(target.pot)
		if item != "RICH_MULCH" or not pots_unlocked(p).has(pot):
			return ""
		var next := GameData.evolutions_of(p.flower_pots[pot])
		if next.is_empty():
			return ""
		p.flower_pots[pot] = next[0]
		p.items.remove_at(index)
		p._sync_form_items() # a fully grown pot gives its nectar to Oricorio
		p.changed.emit()
		return GameData.display_name(next[0])
	if target.has("tree"):
		var tree := int(target.tree)
		if tree >= p.synergy_tier("GRASS") or tree >= p.berry_tree_stages.size():
			return ""
		if item == "RICH_MULCH":
			p.berry_tree_stages[tree] = BERRY_TREE_RIPE
		elif item == "AMAZE_MULCH":
			var left := GOLDEN_BERRIES.filter(func(b: String) -> bool: return not p.berry_tree_types.has(b))
			if not left.is_empty():
				p.berry_tree_types[tree] = left[p.rng.randi() % left.size()]
			p.berry_tree_stages[tree] = BERRY_TREE_RIPE
		else:
			return ""
		p.items.remove_at(index)
		p.changed.emit()
		return GameData.item_name(p.berry_tree_types[tree])
	return ""


## onFlowerMonDeath (fight): a Flora Pokémon of the player fainted: mulch = its stars and
## the next unlocked pot blossoms (its Pokémon joins the fight far from the enemies).
static func on_flora_death(sim: BattleSim, u: BattleUnit) -> void:
	if u.owned == null and not u.effects.get("flower", false):
		return # an enemy flora (wild waves have no synergies anyway)
	sim.rewards.mulch = int(sim.rewards.get("mulch", 0)) + u.stars
	var pots: Array = sim.flower_pots
	var n := int(sim.synergy_state.get("flower_spawn", 0))
	if n >= pots.size():
		return
	sim.synergy_state.flower_spawn = n + 1
	var pkm: String = pots[n]
	if not GameData.pokemon.has(pkm):
		return
	var cell: Variant = AbilityRunner.fly_away_cell(sim, u)
	if cell == null:
		cell = sim.closest_free_cell_near(u.cell, u.team)
	if cell == null:
		return
	var flower := BattleUnit.create(pkm, u.team)
	flower.effects.flower = true
	sim.add_unit(flower, cell)
	flower.cooldown = 1000.0
	sim.emit({"type": "effect", "unit": flower, "text": "Blossom!", "color": Color(1.0, 0.6, 0.85)})
#endregion


#region Baby: eggs
const EGG_CHANCE := 0.1
const GOLDEN_EGG_CHANCE := 0.05


## After a fight (spawnBabyEggs + updateHatch): after a defeat with Baby active, each Baby
## on the board may find an egg (10%, Luck); tier 2 guarantees one, tier 3 may find a golden
## egg (5%, one at a time). Then eggs and HATCH Pokémon grow one stage. Returns messages.
static func after_fight(p: PlayerState, lost: bool) -> Array[String]:
	var messages: Array[String] = []
	var tier := p.synergy_tier("BABY")
	var eggs_found := 0
	var golden_found := false
	var golden_on_bench := p.bench.any(func(u) -> bool: return u != null and u.pkm == "EGG" and u.golden)
	if lost and tier > 0:
		var stacked := p.egg_chance
		for u in p.board.values():
			if not u.types().has("BABY"):
				continue
			if tier >= 3 and not golden_on_bench and not golden_found and p.rng.randf() < GOLDEN_EGG_CHANCE:
				eggs_found += 1
				golden_found = true
			elif p.rng.randf() < EGG_CHANCE:
				eggs_found += 1
			if tier == 1 and eggs_found == 0:
				p.egg_chance += minf(0.2, EGG_CHANCE)
		if eggs_found == 0 and (tier >= 2 or p.rng.randf() < stacked):
			eggs_found = 1
	for i in eggs_found:
		var slot := p.first_free_bench_slot()
		if slot < 0:
			break
		var egg := make_egg(p, golden_found and i == 0 and not golden_on_bench)
		p.bench[slot] = egg
		p.egg_chance = 0.0
		messages.append(L.t("A golden egg was found!") if egg.golden else L.t("An egg was found!"))
	messages.append_array(update_hatch(p))
	p._board_changed()
	return messages


## createRandomEgg: will hatch into a 1★ HATCH Pokémon not given yet this run (if any).
static func make_egg(p: PlayerState, golden := false) -> PlayerState.OwnedUnit:
	var egg := PlayerState.OwnedUnit.new("EGG")
	egg.golden = golden
	var babies := GameData.hatch.filter(func(pkm: String) -> bool: return int(GameData.get_pokemon(pkm).stars) == 1)
	var left := babies.filter(func(pkm: String) -> bool: return not p.eggs_given.has(pkm))
	var from: Array = left if not left.is_empty() else babies
	if not from.is_empty():
		egg.hatch_into = from[p.rng.randi() % from.size()]
		p.eggs_given.append(egg.hatch_into)
	return egg


## updateHatch: eggs and HATCH Pokémon (board and bench) grow; hatched / evolved ones keep
## their place and items; a golden egg also gives a golden item.
static func update_hatch(p: PlayerState) -> Array[String]:
	var messages: Array[String] = []
	var tier := p.synergy_tier("BABY")
	for u in p.bench + p.board.values():
		if u == null or String(u.data().get("evolutionRule", "")) != "hatch":
			continue
		var is_egg: bool = u.pkm == "EGG"
		var needed := int(GameData.config.get("eggHatch" if is_egg else "evolveHatch", 5)) - (1 if is_egg and tier >= 2 else 0)
		u.hatch_stacks += 1
		if u.hatch_stacks < needed:
			continue
		var next: String = u.hatch_into if is_egg else EvolutionRules.next_form(p, u)
		if next == "" or next == u.pkm or not GameData.pokemon.has(next):
			continue
		u.pkm = next
		u.hatch_stacks = 0
		if is_egg and u.golden:
			var golden_items: Array = GameData.config.get("goldenEggItems", [])
			if not golden_items.is_empty():
				p.items.append(golden_items[p.rng.randi() % golden_items.size()])
			u.golden = false
		var news: String = L.t("%s hatched!") if is_egg else L.t("%s evolved!")
		messages.append(news % GameData.display_name(next))
	p.check_merges()
	return messages
#endregion


#region Human: TMs
## updateTms: tier up = the next TMs of the run join the item bench; down = they leave
## (item bench, or the Pokémon knowing it forgets it).
static func update_tms(p: PlayerState) -> void:
	var tier := mini(p.synergy_tier("HUMAN"), p.tms.size())
	if tier == p.tms_tier:
		return
	if tier > p.tms_tier:
		for tm in p.tms.slice(p.tms_tier, tier):
			p.items.append(tm)
	else:
		for tm in p.tms.slice(tier, p.tms_tier):
			if p.items.has(tm):
				p.items.erase(tm)
				continue
			for u in p.board.values() + p.bench:
				if u != null and u.tm == tm_ability(tm):
					u.tm = ""
					break
	p.tms_tier = tier


## AbilityPerTM: TM_RAGE -> RAGE...
static func tm_ability(tm: String) -> String:
	return tm.trim_prefix("TM_")


static func tm_item(ability: String) -> String:
	return "TM_" + ability
#endregion


#region Artificial: tools
## updateArtificialItems: tier up = the next tools of the run join the item bench;
## down = they leave (a holder first, else the item bench).
static func update_artificial(p: PlayerState) -> void:
	var tier := mini(p.synergy_tier("ARTIFICIAL"), p.artificial_items.size())
	if tier == p.artificial_tier:
		return
	if tier > p.artificial_tier:
		for item in p.artificial_items.slice(p.artificial_tier, tier):
			p.items.append(item)
	else:
		for item in p.artificial_items.slice(tier, p.artificial_tier):
			_remove_one(p, item)
	p.artificial_tier = tier
#endregion


#region Normal: Silk Scarves
## getScarvesItemsWithNbScarves: the scarves of `n` Silk Scarves (+ the extra ones): the
## crafted ones first (Nullify Bandanna uses 2), then plain Silk Scarves.
static func scarves_for(p: PlayerState, n: int) -> Array[String]:
	n += p.extra_scarves
	var out: Array[String] = []
	var i := 0
	while n > 0:
		var scarf: String = p.scarves_items[i] if i < p.scarves_items.size() else "SILK_SCARF"
		n -= 2 if scarf == "NULLIFY_BANDANNA" else 1
		if n >= 0:
			out.append(scarf)
			i += 1
	return out


## updateScarves: Normal tier up = its scarves join the item bench; down = they leave
## (from a holder first, else the item bench).
static func update_scarves(p: PlayerState) -> void:
	var tier := p.synergy_tier("NORMAL")
	if tier == p.scarves_tier:
		return
	var before := scarves_for(p, p.scarves_tier)
	var after := scarves_for(p, tier)
	p.scarves_tier = tier
	if after.size() > before.size():
		for scarf in after.slice(before.size()):
			p.items.append(scarf)
	elif after.size() < before.size():
		var lost := before.duplicate()
		for s in after:
			lost.erase(s)
		for scarf in lost:
			_remove_one(p, scarf)


static func _remove_one(p: PlayerState, item: String) -> void:
	for u in p.board.values() + p.bench:
		if u != null and u.items.has(item):
			u.items.erase(item)
			return
	p.items.erase(item)


## A scarf crafted with a Silk Scarf of the synergy: remembered (given back as it is).
static func scarf_crafted(p: PlayerState, scarf: String) -> void:
	if p.scarves_items.size() < p.synergy_tier("NORMAL"):
		p.scarves_items.append(scarf)
#endregion


#region Gourmet
## updateChefsHats: the number of hats follows the Gourmet tier; extra hats leave the
## item bench first, then the last holders.
static func update_chef_hats(p: PlayerState) -> void:
	var wanted: int = HATS_BY_TIER[mini(p.synergy_tier("GOURMET"), HATS_BY_TIER.size() - 1)]
	var holders: Array = []
	for u in p.bench + p.board.values():
		if u != null and u.items.has(CHEF_HAT):
			holders.append(u)
	var current: int = p.items.count(CHEF_HAT) + holders.size()
	while current < wanted:
		p.items.append(CHEF_HAT)
		current += 1
	while current > wanted:
		if p.items.has(CHEF_HAT):
			p.items.erase(CHEF_HAT)
		elif not holders.is_empty():
			holders.pop_back().items.erase(CHEF_HAT)
		current -= 1


## chefCookEffect: every chef (hat holder) cooks its dish 1 / 2 / 2 times (Gourmet tier)
## and serves the strongest hungry ally next to it (same bench / board side), else eats
## it; some dishes go to the item bench. Returns messages for the stage banner.
static func cook(p: PlayerState) -> Array[String]:
	var messages: Array[String] = []
	var tier := p.synergy_tier("GOURMET")
	var count: int = DISHES_BY_TIER[mini(tier, DISHES_BY_TIER.size() - 1)]
	if count <= 0:
		return messages
	var dish_by_pkm: Dictionary = GameData.config.get("dishByPkm", {})
	for chef in p.bench + p.board.values():
		if chef == null or not chef.items.has(CHEF_HAT):
			continue
		var raw: Variant = dish_by_pkm.get(chef.pkm, "") # null for Tatsugiri and Guzzlord (web: no dish)
		var dish := String(raw) if raw is String else ""
		if chef.items.has("COOKING_POT"):
			dish = "HEARTY_STEW"
		elif chef.pkm.begins_with("ARCEUS") or chef.pkm == "KECLEON" or chef.items.has("GOURMET_MEMORY"):
			dish = "SANDWICH"
		if chef.passive() == "GLUTTON":
			chef.mods.maxHP = float(chef.mods.get("maxHP", 0.0)) + 30.0
		if dish == "":
			continue
		var dishes: Array[String] = []
		match dish:
			"BERRIES":
				var berries := GameData.items_in("NonSpecialBerries").filter(func(b: String) -> bool:
					return not chef.items.has(b))
				p._shuffle(berries)
				dishes.assign(berries.slice(0, count))
			"MUSHROOMS":
				for _i in count:
					dishes.append(_weighted(p.rng, MUSHROOM_WEIGHTS))
			"SWEETS":
				var sweets := GameData.items_in("Sweets")
				p._shuffle(sweets)
				dishes.assign(sweets.slice(0, count))
			_:
				for _i in count:
					dishes.append(dish)
		for d in dishes:
			var served := _serve(p, chef, d)
			if served != "":
				messages.append(served)
	return messages


## Gives one cooked dish away; returns the message ("" if nobody could eat it).
static func _serve(p: PlayerState, chef: PlayerState.OwnedUnit, dish: String) -> String:
	if chef.pkm == "SKWOVET" or chef.pkm == "GREEDENT":
		if chef.items.size() < BattleUnit.MAX_ITEMS:
			chef.items.append(dish)
		else:
			p.items.append(dish)
		return L.t("%s cooked %s") % [GameData.display_name(chef.pkm), GameData.item_name(dish)]
	if GameData.item_in(dish, "DishesGoingToInventory"):
		p.items.append(dish)
		return L.t("%s cooked %s") % [GameData.display_name(chef.pkm), GameData.item_name(dish)]
	var chef_loc := p.find(chef)
	var candidates: Array = []
	for u in p.bench + p.board.values():
		if u == null or not can_eat(u) or u.dishes.has(dish) or not _adjacent(p, chef_loc, p.find(u)):
			continue
		if dish == "HERBA_MYSTICA" and u.dishes.any(func(d: String) -> bool: return d.begins_with("HERBA_MYSTICA")):
			continue
		candidates.append(u)
	candidates.sort_custom(func(a, b) -> bool: return unit_score(a) > unit_score(b))
	var eater: PlayerState.OwnedUnit = candidates[0] if not candidates.is_empty() else chef
	if not can_eat(eater):
		return ""
	var eaten := dish
	if dish == "HERBA_MYSTICA":
		var flavors: Array[String] = []
		var types := eater.types()
		if types.has("FAIRY"):
			flavors.append("HERBA_MYSTICA_SWEET")
		if types.has("PSYCHIC"):
			flavors.append("HERBA_MYSTICA_SPICY")
		if types.has("ELECTRIC"):
			flavors.append("HERBA_MYSTICA_SOUR")
		if types.has("GRASS"):
			flavors.append("HERBA_MYSTICA_BITTER")
		if flavors.is_empty():
			flavors.append("HERBA_MYSTICA_SALTY")
		eaten = flavors[p.rng.randi() % flavors.size()]
	eater.dishes.append(eaten)
	return L.t("%s cooked %s for %s") % [GameData.display_name(chef.pkm), GameData.item_name(eaten),
		GameData.display_name(eater.pkm)]


## canEat: not an object / Unown / Tatsugiri, and nothing eaten yet (Big Eater Belt: 2).
static func can_eat(u: PlayerState.OwnedUnit) -> bool:
	if u.is_inanimate() or NO_EATERS.any(func(n: String) -> bool: return u.pkm.begins_with(n)):
		return false
	return u.dishes.is_empty() or (u.items.has("BIG_EATER_BELT") and u.dishes.size() == 1)


## Web getUnitScore: items, stars, sell price.
static func unit_score(u: PlayerState.OwnedUnit) -> float:
	return 100.0 * u.items.size() + 10.0 * u.stars() + GameData.rarity_cost(String(u.data().get("rarity", "COMMON"))) * u.stars()


## distanceC == 1 on the same side (both on the bench or both on the board).
static func _adjacent(_p: PlayerState, a: Dictionary, b: Dictionary) -> bool:
	if a.has("bench") and b.has("bench"):
		return absi(int(a.bench) - int(b.bench)) == 1
	if a.has("board") and b.has("board"):
		var d: Vector2i = a.board - b.board
		return maxi(absi(d.x), absi(d.y)) == 1
	return false


static func _weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0
	for k in weights:
		total += int(weights[k])
	var roll := rng.randi() % maxi(total, 1)
	for k in weights:
		roll -= int(weights[k])
		if roll < 0:
			return k
	return weights.keys()[0]
#endregion


#region Water: fishing rods
## updateFishingRods: the rod of the Water tier (Old 1, Good 2, Super 3) in the item bench.
static func update_rods(p: PlayerState) -> void:
	var tier := p.synergy_tier("WATER")
	for i in RODS.size():
		var wanted := tier == i + 1
		if p.items.has(RODS[i]) and not wanted:
			p.items.erase(RODS[i])
		elif wanted and not p.items.has(RODS[i]):
			p.items.append(RODS[i])


## FishingRodEffect (stage start): with a free bench slot, after stage 3 and not right
## after an original PvE stage, the rod fishes a Pokémon onto the bench (shop.ts pickFish).
static func fish(p: PlayerState) -> String:
	var rod := ""
	for r in RODS:
		if p.items.has(r):
			rod = r
	if rod == "" or p.stage <= 3 or GameData.pve_stages.has(p.stage - 1) or p.first_free_bench_slot() < 0:
		return ""
	var caught := pick_fish(p, rod)
	if caught == "" or not GameData.pokemon.has(caught):
		return ""
	p.put_on_bench(PlayerState.OwnedUnit.new(caught)) # with a copy it stacks with (Magikarp waits for 8)
	p.check_merges()
	return caught


static func pick_fish(p: PlayerState, rod: String) -> String:
	var mantine := false
	for u in p.bench + p.board.values():
		if u != null and (u.pkm == "MANTYKE" or u.pkm == "MANTINE"):
			mantine = true
	var remoraid_chance := float(GameData.config.get("remoraidRate", 1.0 / 3.0)) if mantine else 0.0
	if GameData.pokemon.has("REMORAID") and (p.rng.randf() < remoraid_chance or p.rng.randf() < Synergies.wild_chance(p)):
		return "REMORAID"
	var odds: Dictionary = GameData.config.get("fishRarity", {}).get(rod, {})
	var roll := p.rng.randf()
	var rarity := "SPECIAL"
	for r in odds:
		roll -= float(odds[r])
		if roll < 0.0:
			rarity = r
			break
	if rarity != "SPECIAL":
		# a Water Pokémon of that rarity taken from the pools (regional ones included)
		var shown := p.pool_entries(rarity)
		var candidates := shown.keys().filter(func(pkm: String) -> bool:
			return GameData.get_pokemon(shown[pkm]).types.has("WATER") and p.copies_left(pkm) > 0)
		if not candidates.is_empty():
			var caught: String = shown[candidates[p.rng.randi() % candidates.size()]]
			p.take_copy(caught)
			return caught
	return ROD_FALLBACK[rod]
#endregion


#region Grass: berry trees and berries
## growBerryTreesEffect: the first `tier` trees grow one step (ripe at 3).
static func grow_berry_trees(p: PlayerState) -> void:
	var trees := p.synergy_tier("GRASS")
	for i in mini(trees, p.berry_tree_stages.size()):
		p.berry_tree_stages[i] = mini(p.berry_tree_stages[i] + 1, BERRY_TREE_RIPE)


## OnPickBerryCommand: a ripe tree gives its berry (golden ones with Grass 4) and restarts.
static func pick_berry(p: PlayerState, index: int) -> String:
	if index < 0 or index >= p.berry_tree_stages.size() or index >= p.synergy_tier("GRASS") \
			or p.berry_tree_stages[index] < BERRY_TREE_RIPE:
		return ""
	p.berry_tree_stages[index] = 0
	var berry: String = GOLDEN_BERRIES[index] if p.synergy_tier("GRASS") >= 4 else p.berry_tree_types[index]
	p.add_item(berry)
	return berry


## New region (portal): new tree types, trees cut back.
static func reset_berry_trees(p: PlayerState) -> void:
	var berries := GameData.items_in("NonSpecialBerries")
	p._shuffle(berries)
	for i in p.berry_tree_types.size():
		p.berry_tree_types[i] = berries[i % berries.size()]
		p.berry_tree_stages[i] = 0


## A berry held and eaten in a fight (below 50% HP, Poffin, Berry Eater): its effect,
## then it is gone for good. `to_shield`: heals become shield (Poffin).
static func eat_berry(sim: BattleSim, u: BattleUnit, berry: String, to_shield := false) -> void:
	var heal := func(v: float) -> void:
		if to_shield:
			sim.add_shield(u, v)
		else:
			sim.heal(u, v)
	match berry:
		"AGUAV_BERRY":
			heal.call(minf(50.0, 0.5 * u.max_hp))
			sim.add_status(u, "confusion", 3000.0, u)
		"APICOT_BERRY":
			heal.call(50.0)
			u.add_stat("speDef", 20.0)
		"ASPEAR_BERRY":
			u.statuses.erase("freeze")
			u.effects.immune_freeze = true
			heal.call(50.0)
			u.add_stat("speed", 15.0)
		"CHERI_BERRY":
			u.statuses.erase("paralysis")
			u.effects.immune_paralysis = true
			heal.call(50.0)
			u.add_stat("atk", 10.0)
		"CHESTO_BERRY":
			u.statuses.erase("sleep")
			u.effects.immune_sleep = true
			heal.call(50.0)
			u.add_stat("ap", 50.0)
		"GANLON_BERRY":
			heal.call(50.0)
			u.add_stat("def", 20.0)
		"JABOCA_BERRY":
			heal.call(50.0)
			sim.add_status(u, "spike_armor", 10000.0)
		"LANSAT_BERRY":
			heal.call(50.0)
			u.add_stat("critChance", 50.0)
		"LEPPA_BERRY":
			heal.call(50.0)
			u.add_pp(50.0)
		"LIECHI_BERRY":
			heal.call(50.0)
			u.add_stat("atk", 15.0)
		"LUM_BERRY":
			heal.call(50.0)
			u.cleanse()
			sim.add_status(u, "safeguard", 5000.0)
		"ORAN_BERRY":
			heal.call(50.0)
			sim.add_shield(u, 80.0)
		"PECHA_BERRY":
			heal.call(100.0)
			u.statuses.erase("poison")
			u.poison_stacks = 0
			u.effects.immune_poison = true
		"PERSIM_BERRY":
			u.statuses.erase("confusion")
			u.effects.immune_confusion = true
			heal.call(50.0)
			u.add_stat("speDef", 10.0)
		"PETAYA_BERRY":
			heal.call(50.0)
			u.add_stat("ap", 80.0)
		"ROWAP_BERRY":
			heal.call(50.0)
			sim.add_status(u, "magic_bounce", 10000.0)
		"RAWST_BERRY":
			u.statuses.erase("burn")
			u.effects.immune_burn = true
			heal.call(50.0)
			u.add_stat("def", 10.0)
		"SALAC_BERRY":
			heal.call(50.0)
			u.add_stat("speed", 50.0)
		"SITRUS_BERRY":
			u.effects.buff_heal_received = true
			heal.call(100.0)
		"BERRY_JUICE":
			heal.call(u.max_hp - u.hp)
		"BABIRI_BERRY":
			heal.call(50.0)
			sim.add_status(u, "protect", 2000.0)
		"NANAB_BERRY":
			heal.call(50.0)
			sim.rewards.gold += 1
		"GOLDEN_NANAB_BERRY":
			heal.call(minf(50.0, 0.5 * u.max_hp))
			sim.rewards.gold += 5
		"GOLDEN_RAZZ_BERRY":
			heal.call(minf(50.0, 0.5 * u.max_hp))
			sim.rewards.free_rolls += 6
		"GOLDEN_PINAP_BERRY":
			heal.call(minf(50.0, 0.5 * u.max_hp))
			var sweets := GameData.items_in("Sweets")
			for _i in 3:
				sim.rewards.items.append(sweets[sim.rng.randi() % sweets.size()])
	u.items.erase(berry)
	if u.owned != null:
		u.owned.items.erase(berry) # eaten for good (removeItem permanent)
	if u.passive == "GLUTTON":
		u.add_stat("maxHP", 10.0)
		if u.owned != null:
			u.owned.mods.maxHP = float(u.owned.mods.get("maxHP", 0.0)) + 10.0
	if u.effects.get("berry_juice", false):
		sim.add_shield(u, 100.0)
	if u.effects.get("overgrow", false):
		u.add_stat("ap", 50.0)
	sim.emit({"type": "item", "unit": u, "item": berry, "text": GameData.item_name(berry)})


## Damage received: a held berry is eaten when HP falls under 50%.
static func on_damage_received(sim: BattleSim, u: BattleUnit) -> void:
	if not u.alive or u.hp <= 0.0 or u.hp >= 0.5 * u.max_hp:
		return
	for item in u.items:
		if GameData.item_in(item, "Berries"):
			eat_berry(sim, u, item)
			return
#endregion
