class_name RunStats
extends RefCounted

## Statistics of one run, shown on the Game Over screen (RunSummary). Not in the web game (its
## after-game screen ranks the players of the lobby): the fights won / lost, the time played and,
## per Pokémon family of the player's team, the totals of the DPS meter (Game.fight_stats) added
## fight after fight. A family = the first form of the line, so that a Pokémon keeps its totals
## when it evolves; the form shown is the last one that fought.

var fights := 0
var wins := 0
var losses := 0
var draws := 0
var rerolls := 0
var started_ms := Time.get_ticks_msec()
## family -> {pkm, physical, special, true, reduced, shield_taken, heal, shield, fights}
var units: Dictionary = {}
## The best damage of one Pokémon in one fight: {pkm, damage, stage} ({} before the first fight).
var best_fight: Dictionary = {}


## Adds a finished fight: `stats` = Game.fight_stats (BattleUnit id -> totals of that fight).
func add_fight(stats: Dictionary, winner: int, stage: int) -> void:
	fights += 1
	if winner == BattleUnit.Team.BLUE:
		wins += 1
	elif winner == BattleUnit.Team.RED:
		losses += 1
	else:
		draws += 1
	var fought: Dictionary = {}
	for id in stats:
		var e: Dictionary = stats[id]
		var u: BattleUnit = e.unit
		if u == null or u.team != BattleUnit.Team.BLUE:
			continue
		var family := family_of(u.pkm)
		if not units.has(family):
			units[family] = {"pkm": u.pkm, "physical": 0.0, "special": 0.0, "true": 0.0, "reduced": 0.0,
				"shield_taken": 0.0, "heal": 0.0, "shield": 0.0, "fights": 0}
		var total: Dictionary = units[family]
		total.pkm = u.pkm
		for key in ["physical", "special", "true", "reduced", "shield_taken", "heal", "shield"]:
			total[key] += float(e.get(key, 0.0))
		if not fought.has(family):
			fought[family] = true
			total.fights += 1
		var damage := float(e.physical) + float(e.special) + float(e["true"])
		if damage > float(best_fight.get("damage", 0.0)):
			best_fight = {"pkm": u.pkm, "damage": damage, "stage": stage}


## The first form of the line of `pkm`.
static func family_of(pkm: String) -> String:
	var root := pkm
	for i in 8: # no line is that long: guards against a loop in the data
		var before := GameData.prevolution(root)
		if before == "":
			break
		root = before
	return root


static func damage_of(e: Dictionary) -> float:
	return float(e.physical) + float(e.special) + float(e["true"])


static func blocked_of(e: Dictionary) -> float:
	return float(e.reduced) + float(e.shield_taken)


static func healing_of(e: Dictionary) -> float:
	return float(e.heal) + float(e.shield)


## The `count` best totals by `value` (damage_of / blocked_of / healing_of), without the zeros.
func top(value: Callable, count: int) -> Array:
	var list: Array = units.values().filter(func(e: Dictionary) -> bool: return float(value.call(e)) > 0.0)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(value.call(a)) > float(value.call(b)))
	return list.slice(0, count)


func seconds() -> int:
	return int((Time.get_ticks_msec() - started_ms) / 1000.0)


## What RunSummary shows: plain data (the screenshot test builds one by hand).
func summary(player: PlayerState) -> Dictionary:
	return {
		"fights": fights, "wins": wins, "losses": losses, "draws": draws,
		"seconds": seconds(), "gold": player.gold_earned, "rerolls": rerolls, "level": player.level,
		"team": Records.team_of(player),
		"damage": top(damage_of, 5),
		"blocked": top(blocked_of, 1),
		"healing": top(healing_of, 1),
		"best_fight": best_fight,
	}
