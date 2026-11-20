class_name Synergies
extends RefCounted

## Synergy counts and tiers of a team, port of app/models/colyseus-models/synergies.ts.
##
## computeSynergies: every family on the board counts once per type (3 Charmander
## = 1 FIRE), plus the bonus synergies (buried gems). When DRAGON is active, the
## second type of each dragon family counts once more.
## Tier = number of thresholds reached (config.synergyThresholds), 0 = inactive;
## the effect of a tier is config.synergyTiers[type][tier - 1] (web EffectEnum).


## `units`: the board Pokémon as {family, types} (types in their web order, the
## synergy given by a DRAGON item first). Returns {type: count} for counts > 0.
static func count(units: Array, bonus: Dictionary = {}) -> Dictionary:
	var counts := {}
	for type in bonus:
		if int(bonus[type]) > 0 and GameData.synergy_unlocked(type): # not a synergy the Battle Pass still locks
			counts[type] = int(bonus[type])
	var types_by_family := {}
	for u in units:
		if not types_by_family.has(u.family):
			types_by_family[u.family] = {}
		for t in u.types:
			types_by_family[u.family][t] = true
	for family in types_by_family:
		for t in types_by_family[family]:
			counts[t] = counts.get(t, 0) + 1
	if tier("DRAGON", counts.get("DRAGON", 0)) > 0:
		var doubled := {}
		for u in units:
			if u.types.has("DRAGON") and u.types.size() > 1:
				if not doubled.has(u.family):
					doubled[u.family] = {}
				doubled[u.family][u.types[1]] = true
		for family in doubled:
			for t in doubled[family]:
				counts[t] = counts.get(t, 0) + 1
	# Arceus (PROTEAN3) / Kecleon (PROTEAN2) take the types of the top synergies
	for u in units:
		var nb := {"PROTEAN3": 3, "PROTEAN2": 2}.get(u.get("passive", ""), 0) as int
		if nb == 0:
			continue
		var sorted := sort(counts)
		if sorted.slice(0, nb).has("DRAGON"):
			sorted.erase("DRAGON")
			sorted.push_front("DRAGON")
		for i in mini(nb, sorted.size()):
			var t: String = sorted[i]
			if not u.types.has(t) and counts.get(t, 0) > 0:
				u.types.append(t)
				counts[t] = counts.get(t, 0) + 1
	return counts


## sortSynergies: most points first, then most tiers reached, then the later type of the enum.
static func sort(counts: Dictionary) -> Array:
	var order: Array = GameData.config.get("synergyThresholds", {}).keys()
	var out: Array = counts.keys()
	out.sort_custom(func(a: String, b: String) -> bool: return _before(a, b, counts, order))
	return out


## Types of the player's Protean Pokémon (Arceus) this turn: {OwnedUnit id: types}.
static func dynamic_types(player: PlayerState) -> Dictionary:
	var units: Array = []
	var out := {}
	for u in player.board.values():
		if u.is_inanimate():
			continue
		var entry := {"family": u.family(), "types": u.types(), "passive": u.passive()}
		units.append(entry)
		if String(entry.passive).begins_with("PROTEAN"):
			out[u.id] = entry.types
	count(units, player.bonus_synergies)
	return out


## Counts of the player's board (bench excluded, inanimate pillars excluded).
static func count_player(player: PlayerState) -> Dictionary:
	var units: Array = []
	for u in player.board.values():
		if not u.is_inanimate():
			units.append({"family": u.family(), "types": u.types(), "passive": u.passive()})
	return count(units, player.bonus_synergies)


static func thresholds(type: String) -> Array:
	return GameData.config.get("synergyThresholds", {}).get(type, [])


## Number of thresholds reached: 0 (inactive) to 4. A synergy the Battle Pass still locks is never
## active (its types are hidden anyway: GameData.apply_progression).
static func tier(type: String, n: int) -> int:
	if not GameData.synergy_unlocked(type):
		return 0
	var reached := 0
	for threshold in thresholds(type):
		if n >= int(threshold):
			reached += 1
	return reached


## {type: tier} of the active synergies.
static func tiers(counts: Dictionary) -> Dictionary:
	var out := {}
	for type in counts:
		var t := tier(type, counts[type])
		if t > 0:
			out[type] = t
	return out


## Web effect name of a tier (STAMINA, INGRAIN...), "" if inactive.
static func effect_name(type: String, t: int) -> String:
	var effects: Array = GameData.config.get("synergyTiers", {}).get(type, [])
	if t <= 0 or effects.is_empty():
		return ""
	return String(effects[mini(t, effects.size()) - 1])


static func active_count(counts: Dictionary) -> int:
	return tiers(counts).size()


## sortSynergies + getDominantSynergy: highest count, then most tiers reached, then
## the later type of the Synergy enum. "" if none of `choices` is on the board.
static func dominant(counts: Dictionary, choices: Array) -> String:
	var order: Array = GameData.config.get("synergyThresholds", {}).keys()
	var best := ""
	for type in choices:
		if not counts.has(type):
			continue
		if best == "" or _before(type, best, counts, order):
			best = type
	return best


static func _before(a: String, b: String, counts: Dictionary, order: Array) -> bool:
	var ca := int(counts.get(a, 0))
	var cb := int(counts.get(b, 0))
	if ca != cb:
		return ca > cb
	var ta := tier(a, ca)
	var tb := tier(b, cb)
	if ta != tb:
		return ta > tb
	return order.find(a) > order.find(b)


## What a synergy does on this board ({{additionalInfo}} of the web tooltips). Web keywords are
## kept (GameText).
static func context_text(type: String, player: PlayerState) -> String:
	var counts := count_player(player)
	var t := tier(type, counts.get(type, 0))
	var lines: Array[String] = []
	match type:
		"FAIRY":
			var wands := player.active_wands()
			if not wands.is_empty():
				lines.append(L.t("Wands equipped: %s") % ", ".join(wands))
			if not player.pending_wand_choice().is_empty():
				lines.append(L.t("A wand is waiting to be picked."))
		"DRAGON":
			var stars := 0
			for u in player.board.values():
				if u.types().has("DRAGON"):
					stars += u.stars()
			lines.append(L.t("Current bonus: %d STAR") % stars)
		"WILD":
			lines.append(L.t("Chance to find a WILD Pokémon in the shop: %s%%") % String.num(wild_chance(player) * 100.0, 1))
		"LIGHT":
			lines.append(L.t("Spotlight: cell %d of row %d (lit on the board when LIGHT is active).") % [player.light_cell.x + 1, player.light_cell.y + 1])
		"GROUND":
			var dug := 0
			var full := 0
			for depth in player.ground_holes.values():
				dug += 1 if depth > 0 else 0
				full += 1 if depth >= PlayerState.MAX_HOLE_DEPTH else 0
			lines.append(L.t("Holes: %d cells dug, %d at max depth.") % [dug, full])
			if t > 0:
				lines.append(L.t("The cells of your GROUND Pokémon are outlined in orange: they dig one level deeper at the next stage. The depth is written on the floor."))
		"AMORPHOUS":
			lines.append(L.t("Active synergies: %d") % active_count(counts))
		"FIGHTING":
			if t >= 4:
				lines.append(L.t("Training: FIGHTING Pokémon in the first bench slot or right of a pillar."))
		"NORMAL":
			var scarves := SynergyItems.scarves_for(player, t)
			if not scarves.is_empty():
				lines.append(L.t("Scarves: %s") % ", ".join(scarves.map(func(i: String) -> String: return GameData.item_name(i))))
		"GRASS":
			var trees: Array[String] = []
			for i in mini(t, player.berry_tree_stages.size()):
				trees.append("%s %d/%d" % [GameData.item_name(player.berry_tree_types[i]), player.berry_tree_stages[i],
					SynergyItems.BERRY_TREE_RIPE])
			if not trees.is_empty():
				lines.append(L.t("Berry trees: %s (click a ripe tree to pick its berry).") % ", ".join(trees))
		"WATER":
			if t > 0:
				lines.append(L.t("%s: a Pokémon is fished onto the bench each stage (after stage 3, not after an original PvE stage).")
					% GameData.item_name(SynergyItems.RODS[mini(t, 3) - 1]))
		"HUMAN":
			lines.append(L.t("TMs of this run: %s") % ", ".join(player.tms.map(
				func(i: String) -> String: return GameData.item_name(i))))
		"ARTIFICIAL":
			lines.append(L.t("Tools of this run: %s") % ", ".join(player.artificial_items.map(
				func(i: String) -> String: return GameData.item_name(i))))
		"GOURMET":
			var chefs: Array[String] = []
			for u in player.bench + player.board.values():
				if u != null and u.items.has(SynergyItems.CHEF_HAT):
					chefs.append(GameData.display_name(u.pkm))
			lines.append(L.t("Chefs: %s") % (", ".join(chefs) if not chefs.is_empty() else "-"))
		"BABY":
			if t == 1:
				lines.append(L.t("Bonus egg chance after a defeat: %d%%") % roundi(player.egg_chance * 100.0))
		"FLORA":
			var pots: Array[String] = []
			for pot in SynergyItems.pots_unlocked(player):
				pots.append(GameData.display_name(player.flower_pots[pot]))
			if not pots.is_empty():
				lines.append(L.t("Flower pots (blossom order): %s") % ", ".join(pots))
			lines.append(L.t("Mulch: %d / %d") % [player.mulch, player.mulch_cap])
		"PSYCHIC":
			if t >= 3:
				lines.append(L.t("Shops since the last Unown shop: %d") % player.shops_since_unown)
		"ROCK":
			lines.append(L.t("Weather rocks are only collected against players."))
		"FIRE":
			if t >= 4:
				lines.append(L.t("A Fire Shard each stage: drop it on a Fire Pokémon for +3 ATK and +3 SPEED for good (costs 3 life)."))
		"ELECTRIC":
			if t >= 3:
				lines.append(L.t("Cell Battery charge: %d%%") % player.cell_battery)
	return "\n".join(lines)


## Chance for a shop slot to offer a WILD Pokémon (getWildChance): 6% on the original
## PvE stages or when WILD is active, +0.5% per star of WILD Pokémon on the board.
static func wild_chance(player: PlayerState) -> float:
	var counts := count_player(player)
	var wild := tier("WILD", counts.get("WILD", 0))
	var pve := player.stage == 0 or GameData.pve_stages.has(player.stage)
	var base := 6.0 if pve or wild > 0 else 0.0
	var stars := 0
	if wild > 0:
		for u in player.board.values():
			if u.types().has("WILD"):
				stars += u.stars()
	return (base + stars * 0.5) / 100.0
