class_name Weather
extends RefCounted

## Weather of a fight, port of app/utils/weather.ts (getWeather) and the weather
## checks of pokemon-state.ts / status.ts / simulation.ts.
##
## Both boards vote: +1 per synergy of each Pokémon (GRASS -> ZENITH, FIRE -> DROUGHT...),
## +100 for weather passives (Zapdos STORM, Moltres DROUGHT, Rayquaza AIRLOCK = NEUTRAL...).
## The weather with the most points wins if it has at least config.weatherThreshold
## (8) points and no tie; otherwise NEUTRAL.

const NEUTRAL := "NEUTRAL"

const BY_SYNERGY := {
	"GRASS": "ZENITH", "FIRE": "DROUGHT", "WATER": "RAIN", "GROUND": "SANDSTORM",
	"FAIRY": "MISTY", "ICE": "SNOW", "ELECTRIC": "STORM", "DARK": "NIGHT",
	"FLYING": "WINDY", "WILD": "BLOODMOON", "POISON": "SMOG", "GHOST": "MURKY",
	"NORMAL": "NEUTRAL",
}
const BY_PASSIVE := {
	"RAIN": "RAIN", "DROUGHT": "DROUGHT", "ZENITH": "ZENITH", "SANDSTORM": "SANDSTORM",
	"MISTY": "MISTY", "SNOW": "SNOW", "STORM": "STORM", "NIGHT": "NIGHT", "WINDY": "WINDY",
	"AIRLOCK": "NEUTRAL",
}
## Passives choosing between weathers from the synergies of their own board:
## [candidates, fallback when no dominant one].
const CHOOSING_PASSIVES := {
	"CASTFORM": [["DROUGHT", "ZENITH", "RAIN", "SNOW"], ""],
	"TORNADUS": [["WINDY", "SNOW"], "WINDY"],
	"THUNDURUS": [["WINDY", "STORM"], "STORM"],
	"LANDORUS": [["WINDY", "SANDSTORM"], "SANDSTORM"],
	"ENAMORUS": [["WINDY", "MISTY"], "MISTY"],
	"RAIN_OR_STORM": [["RAIN", "STORM"], "RAIN"],
	"DROUGHT_OR_SANDSTORM": [["DROUGHT", "SANDSTORM"], "DROUGHT"],
}
## Status durations changed by the weather (status.ts): weather -> {status: factor}.
const STATUS_DURATION := {
	"SNOW": {"freeze": 1.3},
	"DROUGHT": {"freeze": 0.7},
	"NIGHT": {"sleep": 1.3},
	"ZENITH": {"sleep": 0.7},
	"MURKY": {"silence": 1.3},
	"SANDSTORM": {"confusion": 1.3},
	"MISTY": {"charm": 1.3},
	"BLOODMOON": {"wound": 1.3},
	"STORM": {"paralysis": 1.3},
}


## `boards`: one Array per team of {types: Array, passive: String} (fighting units only).
static func compute(boards: Array) -> String:
	var total := {}
	for board in boards:
		var own := {}
		for u in board:
			var from_passive: String = BY_PASSIVE.get(u.passive, "")
			if from_passive != "":
				_add(total, from_passive, 100)
				_add(own, from_passive, 100)
			for t in u.types:
				if not BY_SYNERGY.has(t):
					continue
				var w: String = BY_SYNERGY[t]
				_add(total, w, 1)
				for bonus in [["SAND_STREAM", "SANDSTORM"], ["DRIZZLE", "RAIN"], ["WIND_POWER", "STORM"]]:
					if u.passive == bonus[0] and w == bonus[1]:
						_add(total, w, 2)
						_add(own, w, 2)
				if u.passive != "CASTFORM":
					_add(own, w, 1)
		for u in board:
			if CHOOSING_PASSIVES.has(u.passive):
				var rule: Array = CHOOSING_PASSIVES[u.passive]
				var chosen := _dominant(own, rule[0])
				if chosen == "":
					chosen = rule[1]
				if chosen != "":
					_add(total, chosen, 100)
			elif u.passive == "DROUGHT_OR_ZENITH":
				var light: int = board.filter(func(p) -> bool: return p.types.has("LIGHT")).size()
				var fire: int = board.filter(func(p) -> bool: return p.types.has("FIRE")).size()
				_add(total, "ZENITH" if light >= fire else "DROUGHT", 100)
	var best := _dominant(total, total.keys())
	if best != "" and total[best] >= int(GameData.config.get("weatherThreshold", {}).get(best, 8)):
		return best
	return NEUTRAL


static func _add(scores: Dictionary, weather: String, points: int) -> void:
	scores[weather] = scores.get(weather, 0) + points


## Weather with the most points among `candidates`, "" on a tie or if none scored.
static func _dominant(scores: Dictionary, candidates: Array) -> String:
	var best := ""
	var best_score := -1
	var tie := false
	for w in candidates:
		var s: int = scores.get(w, 0)
		if not scores.has(w):
			continue
		if s > best_score:
			best = w
			best_score = s
			tie = false
		elif s == best_score:
			tie = true
	return "" if tie else best


## Unit description for the weather vote: its types and passive.
static func voter(types: Array, passive: String) -> Dictionary:
	return {"types": types, "passive": passive}


static func status_factor(weather: String, status: String) -> float:
	return float(STATUS_DURATION.get(weather, {}).get(status, 1.0))


## Passive PP per second: `base` (Difficulty.mana().perSecond, web 10), +3 under RAIN, -3 under DROUGHT.
static func pp_per_second(weather: String, base := 10.0) -> float:
	match weather:
		"RAIN": return base + 3.0
		"DROUGHT": return base - 3.0
	return base


## Stat changes given to every Pokémon of both teams when it enters the fight.
static func on_spawn(sim: BattleSim, u: BattleUnit) -> void:
	match sim.weather:
		"WINDY":
			u.add_stat("speed", 20.0 if u.types.has("FLYING") else 10.0)
		"SNOW":
			if not u.types.has("ICE"):
				u.add_stat("speed", -10.0)
		"SMOG":
			u.add_stat("dodge", 0.15)
		"NIGHT":
			u.add_stat("critChance", 10.0)
		"MURKY":
			if not u.types.has("GHOST"):
				u.add_stat("luck", -30.0)


## Damage multiplier of the weather for a damage kind (MISTY special, BLOODMOON physical).
static func damage_factor(weather: String, kind: int) -> float:
	if weather == "MISTY" and kind == BattleUnit.DamageKind.SPECIAL:
		return 1.2
	if weather == "BLOODMOON" and kind == BattleUnit.DamageKind.PHYSICAL:
		return 1.2
	return 1.0
