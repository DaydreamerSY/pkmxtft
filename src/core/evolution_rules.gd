class_name EvolutionRules
extends RefCounted

## The evolution rules of the web game that are not "copies merging" (PlayerState.check_merges)
## nor items (PlayerState._item_evolution): app/core/evolution-logic/*-evolution-handler.ts and
## the evolutionRule of each Pokémon class (models/colyseus-models/pokemon.ts).
##   STACK      Primeape (10), Poipole (20), Chingling (30), Hisuian Qwilfish (20), Cosmog /
##              Cosmoem (8), Dunsparce (20), Basculin White (5 KO or 5 KO done): stacks gained
##              in fights (PassiveEffects) or by Cosmog's passive
##   STATE      Tandemaus (stage 15), Maushold (stage 20), Stantler (another region, stage 20),
##              Corsola (PassiveEffects: KO once)
##   MONEY      Gimmighoul: 99 gold
##   PLACEMENT  Mantyke next to a Remoraid on the board
##   divergent  Cosmoem: Solgaleo in the spotlight, else Lunala; Basculin White: female after
##              5 KO, else male; Spewpa: the Vivillon of the player (PlayerState.vivillon)
## afterEvolve: every other evolution gives the Cosmog / Cosmoem of the board +10 max HP and a
## stack. onAcquired: Ninjask brings a Shedinja, Cosmoem loses Cosmog's HP buffs, Stantler
## remembers its region.

## stacksRequired of the classes (pokemon.json "stacksRequired" when the exporter gives it).
const STACKS_REQUIRED := {"PRIMEAPE": 10, "POIPOLE": 20, "CHINGLING": 30, "HISUIAN_QWILFISH": 20,
	"COSMOG": 8, "COSMOEM": 8, "DUNSPARCE": 20, "BASCULIN_WHITE": 5}
const GIMMIGHOUL_MONEY := 99


static func rule(pkm: String) -> String:
	return String(GameData.get_pokemon(pkm).get("evolutionRule", "count"))


static func stacks_required(pkm: String) -> int:
	var data := GameData.get_pokemon(pkm)
	var n := int(data.get("stacksRequired", 0))
	return n if n > 0 else int(STACKS_REQUIRED.get(pkm, 0))


## The next form of a STACK / STATE / MONEY / PLACEMENT / HATCH rule (its divergent one).
static func next_form(p: PlayerState, u: PlayerState.OwnedUnit) -> String:
	var data := u.data()
	match u.pkm:
		"COSMOEM":
			return "SOLGALEO" if _in_light(p, u) else "LUNALA"
		"BASCULIN_WHITE":
			return "BASCULEGION_FEMALE" if u.death_count >= stacks_required(u.pkm) else "BASCULEGION_MALE"
		"SPEWPA":
			return p.vivillon_form()
	var next := String(data.get("evolution", ""))
	if next == "":
		var options: Array = data.get("evolutions", [])
		next = String(options[0]) if not options.is_empty() else ""
	return next


## Cosmoem / Cherubi: on the light cell of an active LIGHT synergy.
static func _in_light(p: PlayerState, u: PlayerState.OwnedUnit) -> bool:
	var loc := p.find(u)
	return loc.has("board") and loc.board == p.light_cell and p.synergy_tier("LIGHT") > 0


## Can `u` evolve now by its rule (EvolutionHandler.canEvolve)? An Eviolite stops it.
static func can_evolve(p: PlayerState, u: PlayerState.OwnedUnit) -> bool:
	if u.items.has("EVIOLITE") or p.find(u).is_empty():
		return false
	var next := next_form(p, u)
	if next == "" or not GameData.is_available(next):
		return false
	match rule(u.pkm):
		"stack":
			var needed := stacks_required(u.pkm)
			return needed > 0 and u.stacks >= needed
		"state":
			match u.passive():
				"FAMILY":
					return p.stage >= (15 if u.pkm == "TANDEMAUS" else 20)
				"STANTLER":
					return p.map != u.original_map and p.stage >= 20
			return false
		"money":
			return p.gold >= GIMMIGHOUL_MONEY
		"placement":
			return _mantyke_placed(p, u)
	return false


## Mantyke: on the board next to a Remoraid also on the board.
static func _mantyke_placed(p: PlayerState, u: PlayerState.OwnedUnit) -> bool:
	var loc := p.find(u)
	if not loc.has("board"):
		return false
	for cell in p.board:
		if p.board[cell].pkm == "REMORAID" and BattleBoard.distance_c(cell, loc.board) == 1:
			return true
	return false


## tryEvolve: evolves it if its rule allows (twice in a row if it can). Returns the new form or "".
static func try_evolve(p: PlayerState, u: PlayerState.OwnedUnit) -> String:
	var evolved := ""
	var guard := 0
	while can_evolve(p, u) and guard < 3:
		evolved = evolve(p, u, next_form(p, u))
		guard += 1
	return evolved


## player.transformPokemon + EvolutionManager.afterEvolve: the same unit becomes `into` (its items,
## dishes, permanent stats and TM stay), its stacks start again; the Cosmog of the board grow.
static func evolve(p: PlayerState, u: PlayerState.OwnedUnit, into: String) -> String:
	var before := u.pkm
	u.pkm = into
	u.stacks = 0
	on_acquired(p, u)
	after_evolve(p, u, before)
	return into


## afterEvolve: another evolution makes the Cosmog / Cosmoem of the board grow (+10 max HP, a stack).
static func after_evolve(p: PlayerState, evolved: PlayerState.OwnedUnit, before: String) -> void:
	var passive := String(GameData.get_pokemon(evolved.pkm).get("passive", ""))
	if passive == "COSMOG" or passive == "COSMOEM":
		return
	for cell in p.board.keys():
		var c: PlayerState.OwnedUnit = p.board.get(cell)
		if c != null and c != evolved and (c.passive() == "COSMOG" or c.passive() == "COSMOEM"):
			c.mods.maxHP = float(c.mods.get("maxHP", 0.0)) + 10.0
			c.stacks += 1
			try_evolve(p, c)


## onAcquired of the forms (pokemon.ts): Ninjask brings a Shedinja to the bench, Cosmoem loses the
## HP buffs of Cosmog, Stantler remembers the region it was found in.
static func on_acquired(p: PlayerState, u: PlayerState.OwnedUnit) -> void:
	match u.pkm:
		"NINJASK":
			var free := p.first_free_bench_slot()
			if free >= 0 and GameData.is_available("SHEDINJA"):
				p.bench[free] = PlayerState.OwnedUnit.new("SHEDINJA")
		"COSMOEM":
			u.stacks = -1
			u.mods.maxHP = float(u.mods.get("maxHP", 0.0)) - 90.0
		"STANTLER":
			u.original_map = p.map
		"DIPPLIN", "HYDRAPPLE": # the meal is consumed to evolve
			u.dishes.erase("SIRUPY_APPLE")
			u.items.erase("SIRUPY_APPLE")
		"APPLETUN":
			u.dishes.erase("SWEET_APPLE")
			u.items.erase("SWEET_APPLE")
		"FLAPPLE":
			u.dishes.erase("TART_APPLE")
			u.items.erase("TART_APPLE")
		"ARMAROUGE":
			u.items.erase("AUSPICIOUS_ARMOR")
		"CERULEDGE":
			u.items.erase("MALICIOUS_ARMOR")
		"URSHIFU_RAPID", "URSHIFU_SINGLE":
			for scroll in ["SCROLL_OF_WATERS", "SCROLL_OF_DARKNESS"]:
				u.items.erase(scroll)
				p.items.erase(scroll)
	if u.pkm.begins_with("ALCREMIE"): # alcremieOnAcquired: its flavor is eaten
		var by_flavor: Dictionary = GameData.get_pokemon("MILCERY").get("evolutionByItem", {})
		for flavor in by_flavor:
			if by_flavor[flavor] == u.pkm:
				u.items.erase(flavor)
				p.items.erase(flavor)


## STACK (and STATE) rules checked at the stage start and after the ground was dug.
static func check_board(p: PlayerState, kinds: Array) -> Array[String]:
	var messages: Array[String] = []
	for u in p.bench + p.board.values():
		if u == null or not kinds.has(rule(u.pkm)):
			continue
		var from: String = u.pkm
		var into := try_evolve(p, u)
		if into != "":
			messages.append(L.t("%s evolved into %s") % [GameData.display_name(from), GameData.display_name(into)])
	return messages


## A stack won in a fight (Pokemon entity addStack): the board unit evolves at once when its
## STACK rule is met (stack-evolution-handler.ts), the fighter keeps its form.
static func add_stack(sim: BattleSim, u: BattleUnit, n := 1) -> void:
	if u.owned == null:
		return
	u.owned.stacks += n
	if sim.player != null and rule(u.owned.pkm) == "stack":
		try_evolve(sim.player, u.owned)


## Poipole / Dunsparce: when only spawned copies fought, the original of the board gets the stack.
static func add_stack_to_owned(p: PlayerState, family: String, atk_every_two := false) -> void:
	for u in p.board.values():
		if u.family() == family:
			u.stacks += 1
			if atk_every_two and u.stacks % 2 == 0:
				u.mods.atk = float(u.mods.get("atk", 0.0)) + 1.0
			if rule(u.pkm) == "stack":
				try_evolve(p, u)
			return


## Basculin White: its stacks are its KO (or the KO it did, the highest); 5 of either evolves it.
static func basculin_count(sim: BattleSim, o: PlayerState.OwnedUnit) -> void:
	o.stacks = maxi(o.death_count, o.kill_count)
	if sim.player != null:
		try_evolve(sim.player, o)
