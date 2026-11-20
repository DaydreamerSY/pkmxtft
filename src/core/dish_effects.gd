class_name DishEffects
extends RefCounted

## Dishes of the Gourmet synergy (port of app/core/effects/dishes.ts): cooked by the
## chefs between stages (PlayerState / SynergyItems), eaten by a Pokémon, their effect
## applies at the start of its next fight on the board (simulation.ts applyDishEffects)
## and the dish is consumed. OnSpawn effects = fight start; "consumed" effects change
## the Pokémon for good (OwnedUnit.mods); on-hit effects are in on_hit().

## Dishes whose first basic attack surely applies their status, then 30%
## (web: effect flag present OR chance 0.3): dish -> [status, ms].
const ON_HIT_STATUS := {
	"CASTELIACONE": ["freeze", 2000.0],
	"WHIPPED_DREAM": ["charm", 2000.0],
	"BLACK_SLUDGE": ["poison", 5000.0],
}

## SANDWICH: bonus per synergy of the eater.
const SANDWICH := {
	"GRASS": ["maxHP", 20.0], "MONSTER": ["maxHP", 20.0], "GOURMET": ["maxHP", 20.0], "BUG": ["maxHP", 20.0],
	"AMORPHOUS": ["maxHP", 20.0],
	"NORMAL": ["shield", 30.0], "ARTIFICIAL": ["shield", 30.0], "DRAGON": ["shield", 30.0], "BABY": ["shield", 30.0],
	"FIRE": ["atk", 5.0], "STEEL": ["atk", 5.0], "FOSSIL": ["atk", 5.0],
	"FLYING": ["dodge", 0.05], "GHOST": ["dodge", 0.05],
	"ELECTRIC": ["speed", 10.0], "FIELD": ["speed", 10.0], "WILD": ["speed", 10.0],
	"ICE": ["speDef", 5.0], "AQUATIC": ["speDef", 5.0], "FLORA": ["speDef", 5.0],
	"GROUND": ["def", 5.0], "FIGHTING": ["def", 5.0], "ROCK": ["def", 5.0],
	"PSYCHIC": ["ap", 20.0], "HUMAN": ["ap", 20.0], "LIGHT": ["ap", 20.0],
	"FAIRY": ["crit", 0.0], "DARK": ["crit", 0.0],
	"WATER": ["pp", 20.0], "SOUND": ["pp", 20.0],
}

## Sweets eaten: permanent stat (OnDishConsumedEffect).
const SWEETS := {
	"STRAWBERRY_SWEET": ["atk", 3.0], "LOVE_SWEET": ["def", 3.0], "BERRY_SWEET": ["maxHP", 15.0],
	"CLOVER_SWEET": ["luck", 10.0], "FLOWER_SWEET": ["speed", 10.0], "STAR_SWEET": ["ap", 10.0],
	"RIBBON_SWEET": ["speDef", 3.0],
}


## Effects of `dish` eaten by `owned` (its fighting unit `u`): at the fight start.
static func apply(sim: BattleSim, u: BattleUnit, owned: PlayerState.OwnedUnit, dish: String) -> void:
	if ON_HIT_STATUS.has(dish):
		u.effects["dish_" + dish] = true
	match dish:
		"BERRY_JUICE":
			sim.add_shield(u, 100.0)
			u.effects.berry_juice = true # the next berry heals more (berries)
		"BIG_MUSHROOM":
			u.add_stat("maxHP", 0.3 * u.base_hp)
		"BALM_MUSHROOM":
			sim.add_status(u, "safeguard", 30000.0)
			u.add_stat("speed", 30.0)
			u.effects.balm_mushroom = true # heals 10% max HP every second (on_second)
		"BINDING_MOCHI":
			u.effects.dish_BINDING_MOCHI = true
		"BLACK_SLUDGE":
			if u.types.has("POISON"):
				u.effects.black_sludge_heal = true # 5% max HP every 2 s
			else:
				sim.add_status(u, "poison", 30000.0, u)
		"CURRY":
			sim.add_status(u, "enraged", 3000.0)
		"FRUIT_JUICE":
			u.add_stat("speed", 50.0)
		"LUCKY_EGG":
			u.add_stat("luck", 30.0)
			u.add_stat("ap", 30.0)
		"HEARTY_STEW":
			u.add_stat("maxHP", 0.3 * u.base_hp)
			if u.has_item("COOKING_POT"):
				sim.add_status(u, "burn", 5000.0, u)
		"HERBA_MYSTICA_SWEET":
			sim.add_status(u, "fairy_field", 1e9)
		"HERBA_MYSTICA_SPICY":
			sim.add_status(u, "psychic_field", 1e9)
		"HERBA_MYSTICA_SOUR":
			sim.add_status(u, "electric_field", 1e9)
		"HERBA_MYSTICA_BITTER":
			sim.add_status(u, "grass_field", 1e9)
		"HERBA_MYSTICA_SALTY":
			sim.add_status(u, "safeguard", BattleSim.FIGHT_DURATION_MS)
		"LARGE_LEEK":
			u.effects.ability_crit = true
			u.add_stat("critPower", 1.0)
			if u._ability_can_crit():
				u.add_stat("critPower", 0.5)
		"LEEK":
			u.effects.ability_crit = true
			u.add_stat("critChance", 50.0)
			if u._ability_can_crit():
				u.add_stat("critPower", 0.5)
		"MOOMOO_MILK":
			_permanent(u, owned, "maxHP", 15.0)
		"NUTRITIOUS_EGG":
			u.add_stat("atk", 0.5 * u.base_atk)
			u.add_stat("def", 0.5 * u.base_def)
			u.add_stat("speDef", 0.5 * u.base_spe_def)
		"OLIVE_OIL":
			u.add_stat("dodge", 0.2)
		"POFFIN":
			sim.add_shield(u, 100.0)
			for item in u.items.duplicate():
				if GameData.item_in(item, "Berries"):
					SynergyItems.eat_berry(sim, u, item, true)
		"RAGE_CANDY_BAR":
			u.add_stat("atk", 10.0)
		"ROCK_SALT":
			sim.add_status(u, "safeguard", 10000.0)
			sim.add_shield(u, 0.15 * u.max_hp)
		"SANDWICH":
			for type in u.types:
				var bonus: Array = SANDWICH.get(type, [])
				if bonus.is_empty():
					continue
				match bonus[0]:
					"shield":
						sim.add_shield(u, bonus[1])
					"crit":
						u.add_stat("critChance", 5.0)
						u.add_stat("critPower", 0.1)
					_:
						u.add_stat(bonus[0], bonus[1])
		"SMOKED_FILET":
			_permanent(u, owned, "maxHP", -5.0)
			_permanent(u, owned, "atk", 3.0)
			_permanent(u, owned, "ap", 10.0)
		"SPINDA_COCKTAIL":
			if sim.chance(0.8, u):
				u.add_stat("atk", 10.0)
			if sim.chance(0.8, u):
				u.add_stat("speed", 50.0)
			if sim.chance(0.8, u):
				u.add_stat("ap", 50.0)
			if sim.chance(0.8, u):
				sim.add_shield(u, 100.0)
			if not sim.chance(0.8, u):
				sim.add_status(u, "confusion", 5000.0, u)
			elif not sim.chance(0.8, u):
				sim.add_status(u, "blinded", 5000.0, u)
			elif not sim.chance(0.8, u):
				sim.add_status(u, "sleep", 5000.0, u)
		"SIRUPY_APPLE", "SWEET_APPLE", "TART_APPLE":
			u.effects["dish_" + dish] = true
		"TEA":
			u.add_pp(60.0)
		"TINY_MUSHROOM":
			u.add_stat("maxHP", -0.3 * u.base_hp)
			u.add_stat("speed", 30.0)
		"RICE":
			u.add_stat("maxHP", 50.0)
			u.effects.rice = true
		_:
			if SWEETS.has(dish):
				_permanent(u, owned, SWEETS[dish][0], SWEETS[dish][1])
	# Glutton (Guzzlord line): +20 max HP for good per dish eaten
	if u.passive == "GLUTTON":
		_permanent(u, owned, "maxHP", 20.0)


## A dish stat kept after the fight (web permanent = true).
static func _permanent(u: BattleUnit, owned: PlayerState.OwnedUnit, stat: String, value: float) -> void:
	u.add_stat(stat, value)
	if owned != null:
		owned.mods[stat] = float(owned.mods.get(stat, 0.0)) + value


## Basic attack landing (OnHitEffect of the dishes eaten).
static func on_hit(sim: BattleSim, attacker: BattleUnit, target: BattleUnit) -> void:
	for dish in ON_HIT_STATUS:
		var flag: String = "dish_" + dish
		if not attacker.effects.has(flag):
			continue
		# first hit sure (flag true), then 30%
		if attacker.effects[flag] == true or sim.chance(0.3, attacker):
			sim.add_status(target, ON_HIT_STATUS[dish][0], ON_HIT_STATUS[dish][1], attacker)
			attacker.effects[flag] = false
	if attacker.effects.get("dish_BINDING_MOCHI", false):
		attacker.effects.dish_BINDING_MOCHI = false
		sim.add_status(target, "possessed", 5000.0, attacker)
	if attacker.effects.has("dish_SIRUPY_APPLE") and sim.chance(0.3, attacker):
		sim.add_status(target, "paralysis", 3000.0, attacker)
	if attacker.effects.has("dish_SWEET_APPLE"):
		target.add_stat("speDef", -2.0)
	if attacker.effects.has("dish_TART_APPLE"):
		target.add_stat("def", -2.0)


## Every second: Balm Mushroom heals 10% max HP; Black Sludge (Poison eater) 5% every 2 s.
static func on_second(sim: BattleSim, u: BattleUnit) -> void:
	if u.effects.get("balm_mushroom", false):
		sim.heal(u, 0.1 * u.max_hp)
	if u.effects.get("black_sludge_heal", false):
		u.counters.sludge = int(u.counters.get("sludge", 0)) + 1
		if u.counters.sludge % 2 == 0:
			sim.heal(u, 0.05 * u.max_hp)
