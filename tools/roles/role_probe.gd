extends Node

## Role audit, step 1 (docs/ROLES.md): casts the ability of every form on test boards, headless, and writes what it
## really does to build/roles/probe_<shard>.tsv (tools/roles/role_audit.py reads it). Each test holds every unit
## (no walking, no basic attack, no second cast): only the ability, what it schedules and the statuses run.
##   reach      farthest hex distance (1..7) at which a lone enemy focus, cast on from the back row, still takes its
##              damage, a status or a debuff (0: it never touches an enemy; 7: anywhere on the board)
##   front_*    cast from the front row (3, 3) at 7 enemies in their two front rows (ENEMIES): damage of its ability (no DEF,
##              no overkill), enemies it damaged, dot = damage of the statuses it put (burn, poison) within WAIT_MS;
##              back_*: the same from the back row (3, 0)
##   ally_*     what its 4 adjacent allies (half HP) got from the cast from the back row: heal, shield, stat buffs (sum
##              of the + changes, as a share of the stat), statuses; self_*: itself
##   cc / debuff  statuses / - stat changes (share) on enemies (back row cast), spawn: units it summoned,
##   dash       cells it moved during the cast; engage: hex distance to the nearest enemy it gained by moving
## Web stats (no auto balance), every synergy unlocked, no season, classic rules, no AP, no item, no synergy.
##   Godot_console.exe --headless --path . res://tools/roles/role_probe.tscn -- [out=build/roles] [only=A,B]
##       [shard=i/n]       (tools\role_audit.bat runs the shards and the report)

const FRONT := Vector2i(3, 3)
const BACK := Vector2i(3, 0)
## the enemy team of the full tests: 5 in its front row, 2 behind them
const ENEMIES: Array[Vector2i] = [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4),
	Vector2i(2, 5), Vector2i(4, 5)]
const WAIT_MS := 6000.0
const STEP_MS := 50.0
const DUMMY := "MAGIKARP"
const DUMMY_HP := 1000.0 ## a sturdy unit: % max HP damage and burn / poison stay near a real fight
const ALLY_HP := 1000.0
## stat -> what one point of it is worth against the stat (share of its value, at least this much)
const BUFF_STATS := {"atk": 5.0, "def": 5.0, "spe_def": 5.0, "speed": 50.0, "ap": 100.0, "crit_chance": 100.0,
	"max_hp": 100.0, "attack_range": 1.0, "dodge": 1.0}
const COLUMNS := ["pkm", "family", "rarity", "stars", "types", "skill", "scripted", "role", "web_range", "range",
	"hp", "atk", "def", "speDef", "speed", "maxPP", "reach", "front_dmg", "front_hit", "back_dmg", "back_hit",
	"front_dot", "back_dot", "phys", "spec", "true", "ally_heal", "ally_shield", "ally_buff", "ally_status", "self_heal", "self_shield",
	"self_buff", "cc", "debuff", "spawn", "dash", "engage", "error"]

var _args := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var at := arg.find("=")
		if at > 0:
			_args[arg.substr(0, at)] = arg.substr(at + 1)
	GameData.set_language("en")
	Difficulty.set_level("classic")
	Progression.override_level = 9999 # every synergy: the full types of every form
	Seasons.set_current(Seasons.FULL)
	GameData.apply_progression()
	GameData.use_balance(false) # the web kit: the role does not follow the balance
	var forms: Array = GameData.pokemon.keys()
	forms.sort()
	if _args.has("only"):
		forms = Array(String(_args.only).split(",")).filter(func(p: String) -> bool: return GameData.pokemon.has(p))
	var shard := 0
	var shards := 1
	if _args.has("shard"):
		var parts := String(_args.shard).split("/")
		shard = int(parts[0])
		shards = maxi(int(parts[1]), 1)
	var out_dir := String(_args.get("out", "build/roles"))
	if not out_dir.is_absolute_path():
		out_dir = ProjectSettings.globalize_path("res://").path_join(out_dir)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path := out_dir.path_join("probe_%d.tsv" % shard)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_line("\t".join(COLUMNS))
	var done := 0
	for i in forms.size():
		if i % shards != shard:
			continue
		var pkm: String = forms[i]
		if not _probed(pkm):
			continue
		var row := _probe(pkm)
		var cells: Array[String] = []
		for col in COLUMNS:
			var v: Variant = row.get(col, "")
			cells.append(("%.2f" % v) if v is float else str(v))
		f.store_line("\t".join(cells))
		done += 1
	f.close()
	print("role probe: %d forms -> %s" % [done, path])
	get_tree().quit(0)


## A form a player can field: an ability that is ported, not a Pillar / egg (INANIMATE).
func _probed(pkm: String) -> bool:
	var d: Dictionary = GameData.pokemon[pkm]
	var skill := String(d.get("skill", ""))
	return skill != "" and skill != "DEFAULT" and GameData.is_ability_ported(skill) \
		and String(d.get("passive", "")) != "INANIMATE"


func _probe(pkm: String) -> Dictionary:
	var d: Dictionary = GameData.pokemon[pkm]
	var ab := GameData.get_ability(String(d.skill))
	var row := {"pkm": pkm, "family": d.get("family", pkm), "rarity": d.get("rarity", ""), "stars": int(d.get("stars", 1)),
		"types": ",".join(PackedStringArray(d.get("types", []))), "skill": d.skill,
		"scripted": 1 if String(ab.get("script", "")) != "" else 0, "role": UnitRoles.role_of(pkm),
		"web_range": int(GameData.web_stat(pkm, "range", 1)), "range": int(d.get("range", 1)),
		"hp": float(d.get("hp", 0)), "atk": float(d.get("atk", 0)), "def": float(d.get("def", 0)),
		"speDef": float(d.get("speDef", 0)), "speed": float(d.get("speed", 0)), "maxPP": float(d.get("maxPP", 0))}
	var errors: Array[String] = []
	# reach: a lone enemy at 1..7 cells from the back row
	var reach := 0
	for dist in range(1, 8):
		var cell: Variant = _cell_at_distance(BACK, dist)
		if cell == null:
			continue
		var r := _test(pkm, BACK, [cell], false, true)
		if r.has("error"):
			errors.append(r.error)
		if r.dmg > 0.0 or r.cc > 0 or r.debuff > 0.001:
			reach = dist
	row.reach = reach
	# a full enemy team, from the front and from the back (with 4 allies)
	var row_cells: Array = ENEMIES.duplicate()
	var front := _diff(_test(pkm, FRONT, row_cells, true, true), _test(pkm, FRONT, row_cells, true, false))
	var back := _diff(_test(pkm, BACK, row_cells, true, true), _test(pkm, BACK, row_cells, true, false))
	for r in [front, back]:
		if r.has("error"):
			errors.append(r.error)
	row.front_dmg = front.dmg
	row.front_hit = front.hit
	row.back_dmg = back.dmg
	row.back_hit = back.hit
	row.front_dot = front.dot
	row.back_dot = back.dot
	var total := maxf(front.dmg + back.dmg, 0.0)
	for kind in ["phys", "spec", "true"]:
		row[kind] = (float(front[kind]) + float(back[kind])) / total if total > 0.0 else 0.0
	for key in ["ally_heal", "ally_shield", "ally_buff", "ally_status", "self_heal", "self_shield", "self_buff", "cc",
			"debuff", "spawn", "dash", "engage"]:
		row[key] = back[key]
	row.error = " / ".join(errors).replace("\t", " ").left(120)
	return row


## The cell at hex distance `dist` of `from` nearest to its column (null: none on the board).
func _cell_at_distance(from: Vector2i, dist: int) -> Variant:
	var best: Variant = null
	for cell in BattleBoard.all_cells():
		if BattleBoard.distance(from, cell) == dist and (best == null or absi(cell.x - from.x) < absi(best.x - from.x)):
			best = cell
	return best


## One test: the form at `at`, dummy enemies (Magikarp, DUMMY_HP, no DEF, no dodge) on `enemy_cells`, 4 allies at half
## HP next to it if `allies`; it casts on its nearest enemy (or not: the baseline of what the passives do), then the
## board runs WAIT_MS with every unit held.
func _test(pkm: String, at: Vector2i, enemy_cells: Array, allies: bool, cast: bool) -> Dictionary:
	var sim := BattleSim.new()
	sim.rng.seed = 7
	sim.setup_teams({}, {})
	var c := BattleUnit.create(pkm, BattleUnit.Team.BLUE)
	sim.add_unit(c, at)
	var mates: Array[BattleUnit] = []
	if allies:
		for cell in BattleBoard.adjacent_cells(at):
			if mates.size() < 4 and cell.y < BattleBoard.SIDE_ROWS and sim.board.get_unit(cell) == null:
				var a := BattleUnit.create(DUMMY, BattleUnit.Team.BLUE)
				a.max_hp = ALLY_HP
				a.hp = ALLY_HP * 0.5
				sim.add_unit(a, cell)
				mates.append(a)
	var foes: Array[BattleUnit] = []
	for cell in enemy_cells:
		var e := BattleUnit.create(DUMMY, BattleUnit.Team.RED)
		e.max_hp = DUMMY_HP
		e.hp = DUMMY_HP
		e.def = 0.0
		e.spe_def = 0.0
		e.dodge = 0.0
		sim.add_unit(e, cell)
		foes.append(e)
	_hold(sim)
	sim.update(1.0) # the fight starts (fight start effects in the baseline too)
	var before := {}
	for u in sim.units:
		before[u] = _stats(u)
	var start := c.cell
	var near_before := 99 # hex distance to its nearest enemy before the cast
	for e in foes:
		near_before = mini(near_before, BattleBoard.distance(start, e.cell))
	sim.drain_events()
	if cast:
		var focus: BattleUnit = null
		for e in foes:
			if focus == null or BattleBoard.distance(at, e.cell) < BattleBoard.distance(at, focus.cell):
				focus = e
		c.pp = c.max_pp
		AbilityRunner.cast(sim, c, focus)
	var events: Array[Dictionary] = sim.drain_events()
	var t := 0.0
	while t < WAIT_MS and not sim.finished:
		_hold(sim)
		sim.update(STEP_MS)
		t += STEP_MS
		events.append_array(sim.drain_events())
	var r := {"dmg": 0.0, "hit": 0, "dot": 0.0, "phys": 0.0, "spec": 0.0, "true": 0.0, "ally_heal": 0.0, "ally_shield": 0.0,
		"ally_buff": 0.0, "ally_status": 0, "self_heal": 0.0, "self_shield": 0.0, "self_buff": 0.0, "cc": 0,
		"debuff": 0.0, "spawn": 0, "dash": 0, "engage": 0}
	var hit := {}
	var statuses := {}
	for e in events:
		var u: BattleUnit = e.get("unit")
		if u == null:
			continue
		match String(e.type):
			"damage":
				if e.get("source") == c and u.team != c.team:
					var lost := float(e.get("effective", e.amount)) # shield + HP, no overkill (an execute: the HP it had)
					if e.get("ability", false):
						r.dmg += lost
						r[["phys", "spec", "true"][clampi(int(e.kind), 0, 2)]] += lost
						if lost > 0.0:
							hit[u] = true
					elif not e.get("attack", false):
						r.dot += lost # held units do not attack: the burn / poison it gave
			"heal", "shield":
				if e.get("source") == c and e.get("ability", false):
					var key := ("self_" if u == c else "ally_") + String(e.type)
					if u == c or u.team == c.team:
						r[key] += float(e.amount)
			"status":
				var pair := "%d:%s" % [u.id, e.status]
				if not statuses.has(pair):
					statuses[pair] = true
					if u.team != c.team:
						r.cc += 1
					elif u != c:
						r.ally_status += 1
			"spawn":
				if u.team == c.team:
					r.spawn += 1
	r.hit = hit.size()
	for u in sim.units:
		if not before.has(u):
			continue
		var now := _stats(u)
		for stat in BUFF_STATS:
			var base := maxf(absf(float(before[u][stat])), float(BUFF_STATS[stat]))
			var change := (float(now[stat]) - float(before[u][stat])) / base
			if u == c:
				r.self_buff += maxf(change, 0.0)
			elif u.team == c.team:
				r.ally_buff += maxf(change, 0.0)
			else:
				r.debuff += maxf(-change, 0.0)
	r.dash = BattleBoard.distance(start, c.cell) if c.alive else 0
	if c.alive and not foes.is_empty():
		var near_after := 99
		for e in foes:
			if e.alive:
				near_after = mini(near_after, BattleBoard.distance(c.cell, e.cell))
		r.engage = maxi(near_before - near_after, 0) if near_after < 99 else 0
	sim.dispose()
	return r


## Every unit stands still: no walking, no basic attack, no cast (the cooldown before its next action).
func _hold(sim: BattleSim) -> void:
	for u in sim.units:
		u.cooldown = 1e9


func _stats(u: BattleUnit) -> Dictionary:
	return {"atk": u.atk, "def": u.def, "spe_def": u.spe_def, "speed": u.speed, "ap": u.ap, "crit_chance": u.crit_chance,
		"max_hp": u.max_hp, "attack_range": float(u.attack_range), "dodge": u.dodge}


## What the cast adds to the baseline (the same board without casting: passives, fight start effects).
func _diff(with_cast: Dictionary, base: Dictionary) -> Dictionary:
	var out := with_cast.duplicate()
	for key in ["ally_heal", "ally_shield", "ally_buff", "self_heal", "self_shield", "self_buff", "debuff", "dot"]:
		out[key] = maxf(float(with_cast[key]) - float(base[key]), 0.0)
	for key in ["ally_status", "cc", "spawn"]:
		out[key] = maxi(int(with_cast[key]) - int(base[key]), 0)
	return out
