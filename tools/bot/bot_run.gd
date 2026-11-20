class_name BotRun
extends RefCounted

## One Endless run played by a bot (BotBrain) with the rules of the game and no view: the stage loop of
## the Game scene (Game._ready / _start_planning / _start_fight / _end_fight / _next_stage) and RunRules.
## Keep it in step with Game. Recorded as TSV rows for the balance data (docs/BOT.md):
##   RUN_COLUMNS    one row per run (play() returns it)
##   STAGE_COLUMNS  one row per stage fought (stage_rows)
##   UNIT_COLUMNS   one row per unit and fight, both teams (unit_rows, when track_units)
## Codes: board "PKM*stars[ITEM+ITEM]@x.y|..." (y 3 = front row), synergies "TYPE:count:tier|..." (tier >= 1),
## aims: the synergies the bot was aiming for at that stage,
## picks "kind:answer|..." (p = portal map, s/u/l/a/f = starter, unique, legendary, add pick, form,
## i = item, w = wand, c = carousel), result W / L / D.

const MAX_STAGE := 150 ## safety cap (an Endless run ends when the life does)
const RUN_COLUMNS := ["run", "seed", "diff", "season", "pass", "bot", "aims", "stage", "wins", "losses", "draws",
	"level", "gold", "board", "wave", "fight_s", "real_ms", "unlocks"]
const STAGE_COLUMNS := ["run", "stage", "map", "life", "gold", "level", "income", "team", "bench", "itembench", "rolls",
	"bought", "sold", "xp", "syn", "board", "wave", "wkind", "wn", "wpkm", "wsyn", "res", "fight_s", "alive_b", "alive_r",
	"loss", "reward", "picks", "unlocks", "aims"]
## adealt: damage of its basic attacks (the rest of `dealt` comes from its ability, items, synergies...); casts /
## first_cast (s): its abilities; maxpp: PP to cast; t_dead: when it fainted (s, -1 alive); y: its row at the start
## (player 3 = front, 0 = back; enemies 4 = front, 7 = back); ppgain: PP it gained (BattleUnit.pp_gained); attacks:
## basic attacks started; tphys / tspec / ttrue: `taken` by kind; mitig: damage its DEF / SPE_DEF (and flat
## reductions) stopped; blocked: damage stopped whole (Protect, Reflect...); hp0 ... crit0: its stats once the fight
## started (after items, synergies and the fight-start effects; a unit that joins later: at the end); sdealt / ssus:
## damage / heal + shield of its ability (events with "ability": BattleSim.ability_source, delayed hits included; the
## rest of dealt - adealt is items, synergies, passives, statuses).
const UNIT_COLUMNS := ["run", "stage", "team", "pkm", "stars", "rarity", "items", "role", "dealt", "phys", "spec", "true",
	"adealt", "taken", "heal", "shield", "casts", "first_cast", "maxpp", "alive", "t_dead", "y", "ppgain", "attacks",
	"tphys", "tspec", "ttrue", "mitig", "blocked", "hp0", "atk0", "def0", "spedef0", "speed0", "ap0", "crit0",
	"sdealt", "ssus"]

var id := 0
var run_seed := 0
var player: PlayerState
var brain: BotBrain
var town_rng := RandomNumberGenerator.new()
var choices: Array[Dictionary] = []
var wave: Dictionary = {}
var track_units := true
var stage_rows: PackedStringArray = []
var unit_rows: PackedStringArray = []
var wins := 0
var losses := 0
var draws := 0
var fight_ms := 0.0
## What the brain did in the planning phase of the stage (for its row).
var stage_rolls := 0
var stage_bought := 0
var stage_sold := 0
var stage_xp := 0
var stage_picks: PackedStringArray = []
var _income := 0


func _init(run_id: int, seed_value: int, profile: BotBrain) -> void:
	id = run_id
	run_seed = seed_value
	brain = profile


## Plays the run to its end (Game._ready, then the stage loop); returns its TSV row (RUN_COLUMNS).
## `setup`: {diff, season, pass} as applied by the runner.
func play(setup: Dictionary) -> String:
	var started := Time.get_ticks_msec()
	GameData.begin_run()
	player = PlayerState.new()
	player.rng.seed = hash([run_seed, "player"])
	player.life = int(Difficulty.value("startLife", PlayerState.START_LIFE))
	player.gold = int(Difficulty.value("startGold", PlayerState.START_GOLD))
	town_rng.seed = run_seed
	brain.begin(self)
	player.stage = 0
	choices.append_array(Town.begin_stage(player, town_rng).choices)
	player.stage = 1
	player.roll_shop()
	while player.stage <= MAX_STAGE:
		_planning()
		_fight()
		if player.life <= 0:
			break
		_next_stage()
	brain.end(self)
	var row := [id, run_seed, setup.diff, setup.season, setup.pass, brain.code(), ",".join(brain.targets), player.stage,
		wins, losses, draws, player.level, player.gold, board_code(player), wave_code(wave), roundi(fight_ms / 1000.0),
		Time.get_ticks_msec() - started, ",".join(GameData.run_unlocked)]
	EndlessWaves.clear_cache() # the waves of this seed are not needed again
	return _tsv(row)


## Game._start_planning, then the brain plays the phase.
func _planning() -> void:
	player.merge_board = true
	player.check_merges()
	wave = EndlessWaves.get_stage(player.stage, run_seed)
	# shinyEncounter (game-commands.ts): Celebi met in the town, or the stage's own shiny chance
	player.shiny_encounter = player.town_encounter == "CELEBI" or town_rng.randf() < float(wave.get("shinyChance", 0.0))
	stage_rolls = 0
	stage_bought = 0
	stage_sold = 0
	stage_xp = 0
	stage_picks = PackedStringArray()
	brain.plan(self)


## Answers the first choice of the queue (Game._resolve_choice with RunRules); the offer of a portal
## comes next.
func resolve(answer: Variant) -> void:
	var c: Dictionary = choices.pop_front()
	var out := RunRules.apply_choice(player, c, answer, town_rng)
	stage_picks.append(_pick_code(c, answer, out))
	if c.kind == "portal" and not out.offer.is_empty():
		choices.push_front(out.offer)


## Game._start_fight (choices left open picked at random, the bench fills the board), the fight at full
## speed, then Game._end_fight.
func _fight() -> void:
	var guard := 0
	while not choices.is_empty() and guard < 20:
		guard += 1
		var auto := RunRules.auto_answer(choices[0], town_rng)
		match String(auto.action):
			"wait":
				break
			"drop":
				choices.pop_front()
			_:
				resolve(auto.answer)
	player.auto_place()
	var life := player.life
	var gold := player.gold
	var board := board_code(player)
	var syn_counts := player.synergy_counts()
	var syn := synergy_code(syn_counts)
	var team := player.team_count()
	var bench := player.bench.filter(func(u) -> bool: return u != null).size()
	player.merge_board = false
	var fight := FightSetup.create(player, wave)
	var sim: BattleSim = fight.sim
	var stats := {}
	var start_y := {}
	var start := {} # unit id -> its stats after the first step (the fight-start effects): unit_stats()
	for u in sim.units:
		start_y[u.id] = u.cell.y
	while not sim.finished:
		sim.update(BattleSim.MAX_STEP_MS)
		if start.is_empty():
			for u in sim.units:
				start[u.id] = unit_stats(u)
		_tally(sim.drain_events(), stats, sim.time_ms)
	_tally(sim.drain_events(), stats, sim.time_ms)
	var blue_alive := sim.alive_units(BattleUnit.Team.BLUE).size()
	var red_alive := sim.alive_units(BattleUnit.Team.RED).size()
	var res := "W" if sim.winner == BattleUnit.Team.BLUE else ("L" if sim.winner == BattleUnit.Team.RED else "D")
	if track_units:
		for u in sim.units:
			if u.inanimate:
				continue
			var st: Dictionary = stats.get(u.id, {})
			unit_rows.append(_tsv([id, player.stage, "B" if u.team == BattleUnit.Team.BLUE else "R", u.pkm, u.stars,
				String(u.data.get("rarity", "")), "+".join(u.items), u.role,
				roundi(float(st.get("p", 0.0)) + float(st.get("s", 0.0)) + float(st.get("t", 0.0))),
				roundi(float(st.get("p", 0.0))), roundi(float(st.get("s", 0.0))), roundi(float(st.get("t", 0.0))),
				roundi(float(st.get("a", 0.0))), roundi(float(st.get("taken", 0.0))), roundi(float(st.get("heal", 0.0))),
				roundi(float(st.get("shield", 0.0))), int(st.get("casts", 0)), snappedf(float(st.get("first_cast", -1.0)), 0.1),
				roundi(u.max_pp), 1 if u.alive else 0, snappedf(float(st.get("dead", -1.0)), 0.1), int(start_y.get(u.id, u.cell.y)),
				roundi(u.pp_gained), int(u.counters.get("attacks", 0)), roundi(float(st.get("tp", 0.0))),
				roundi(float(st.get("ts", 0.0))), roundi(float(st.get("tt", 0.0))), roundi(float(st.get("mitig", 0.0))),
				roundi(float(st.get("blocked", 0.0)))] + start.get(u.id, unit_stats(u))
				+ [roundi(float(st.get("k", 0.0))), roundi(float(st.get("ks", 0.0)))]))
	# what the bots learn from this fight (BotKnowledge): the synergies, the Pokémon, their items, their damage share
	var blue_dealt := 0.0
	for u in sim.units:
		if u.team == BattleUnit.Team.BLUE:
			var st: Dictionary = stats.get(u.id, {})
			blue_dealt += float(st.get("p", 0.0)) + float(st.get("s", 0.0)) + float(st.get("t", 0.0))
	var mine: Array = []
	for u in sim.units:
		if u.team == BattleUnit.Team.BLUE and u.owned_id >= 0 and not u.inanimate:
			var st: Dictionary = stats.get(u.id, {})
			var dealt := float(st.get("p", 0.0)) + float(st.get("s", 0.0)) + float(st.get("t", 0.0))
			mine.append({"pkm": u.pkm, "role": u.role, "items": u.items.duplicate(), "share": dealt / maxf(blue_dealt, 1.0)})
	brain.after_fight(self, {"stage": player.stage, "win": 1 if res == "W" else 0, "counts": syn_counts, "units": mine})
	fight_ms += sim.time_ms
	# Game._end_fight
	player.merge_board = true
	player.after_fight()
	player.collect_fight_rewards(sim.rewards)
	SynergyItems.after_fight(player, sim.winner != BattleUnit.Team.BLUE)
	var loss := 0
	var reward := ""
	if sim.winner == BattleUnit.Team.BLUE:
		wins += 1
		var out := RunRules.give_reward(player, wave.get("reward"))
		reward = "+".join(out.given)
		if not out.choice.is_empty():
			choices.append(out.choice)
			reward += "+choice" if reward != "" else "choice"
	else:
		if res == "L":
			losses += 1
		else:
			draws += 1
		loss = RunRules.life_loss(player.stage, red_alive)
		player.life = maxi(player.life - loss, 0)
	var wave_syn := {}
	if wave.get("synergies", false):
		wave_syn = EndlessWaves.synergy_counts(wave, player.town_encounter)
	stage_rows.append(_tsv([id, player.stage, player.map, life, gold, player.level, _income, team, bench, player.items.size(),
		stage_rolls, stage_bought, stage_sold, stage_xp, syn, board, wave_code(wave), String(wave.get("kind", "")),
		wave.get("board", []).size(), "+".join(wave.get("board", []).map(func(e) -> String: return String(e[0]))),
		synergy_code(wave_syn), res, snappedf(sim.time_ms / 1000.0, 0.1), blue_alive, red_alive, loss, reward,
		"|".join(stage_picks), GameData.run_unlocked.size(), ",".join(brain.targets)]))
	sim.dispose()


## Game._next_stage (the run goes on).
func _next_stage() -> void:
	player.stage += 1
	_income = player.collect_income()
	player.start_stage()
	choices.append_array(Town.begin_stage(player, town_rng).choices)
	if not player.shop_locked:
		player.roll_shop()


## Damage (and the part of basic attacks), heal, shield, casts and fainting of each unit from the fight
## events (Game._handle_events / DPS meter); `now_ms`: the fight time of these events.
func _tally(events: Array, stats: Dictionary, now_ms: float) -> void:
	for e in events:
		match String(e.get("type", "")):
			"cast":
				var caster = e.get("unit")
				if caster != null:
					var cs := _stat(stats, caster)
					cs.casts += 1
					if cs.first_cast < 0.0:
						cs.first_cast = now_ms / 1000.0
			"death":
				var dead = e.get("unit")
				if dead != null:
					_stat(stats, dead).dead = now_ms / 1000.0
			"damage":
				# what the target really lost (no overkill: an execute's 9999 is the HP it had left)
				var lost := float(e.get("effective", e.get("amount", 0.0)))
				var source = e.get("source")
				if source != null and source != e.get("unit"):
					var st := _stat(stats, source)
					st[["p", "s", "t"][clampi(int(e.get("kind", 0)), 0, 2)]] += lost
					if e.get("attack", false):
						st.a += lost
					elif e.get("ability", false):
						st.k += lost
				var target = e.get("unit")
				if target != null:
					var ts := _stat(stats, target)
					ts.taken += lost
					ts[["tp", "ts", "tt"][clampi(int(e.get("kind", 0)), 0, 2)]] += lost
					ts["blocked" if e.get("blocked", false) else "mitig"] += float(e.get("reduced", 0.0))
			"heal":
				var healer = e.get("source", e.get("unit"))
				if healer != null:
					var hs := _stat(stats, healer)
					hs.heal += float(e.get("amount", 0.0))
					if e.get("ability", false):
						hs.ks += float(e.get("amount", 0.0))
			"shield":
				var giver = e.get("source", e.get("unit"))
				if giver != null:
					var gs := _stat(stats, giver)
					gs.shield += float(e.get("amount", 0.0))
					if e.get("ability", false):
						gs.ks += float(e.get("amount", 0.0))


static func _stat(stats: Dictionary, u: BattleUnit) -> Dictionary:
	if not stats.has(u.id):
		stats[u.id] = {"p": 0.0, "s": 0.0, "t": 0.0, "a": 0.0, "taken": 0.0, "heal": 0.0, "shield": 0.0,
			"casts": 0, "first_cast": -1.0, "dead": -1.0, "tp": 0.0, "ts": 0.0, "tt": 0.0, "mitig": 0.0, "blocked": 0.0,
			"k": 0.0, "ks": 0.0}
	return stats[u.id]


## hp0, atk0, def0, spedef0, speed0, ap0, crit0 of UNIT_COLUMNS: the unit's stats now.
static func unit_stats(u: BattleUnit) -> Array:
	return [roundi(u.max_hp), snappedf(u.atk, 0.1), snappedf(u.def, 0.1), snappedf(u.spe_def, 0.1), snappedf(u.speed, 0.1),
		roundi(u.ap), roundi(u.crit_chance)]


#region codes
static func board_code(p: PlayerState) -> String:
	var parts := PackedStringArray()
	for cell in p.board:
		var u: PlayerState.OwnedUnit = p.board[cell]
		parts.append("%s*%d[%s]@%d.%d" % [u.pkm, u.stars(), "+".join(u.items), cell.x, cell.y])
	return "|".join(parts)


## The active synergies (tier >= 1) of {type: count}.
static func synergy_code(counts: Dictionary) -> String:
	var parts := PackedStringArray()
	for type in counts:
		var tier := Synergies.tier(type, int(counts[type]))
		if tier > 0:
			parts.append("%s:%d:%d" % [type, int(counts[type]), tier])
	return "|".join(parts)


## A wave: "tpl:<template id>", "boss:<stage name>" or "wild:<leader>".
static func wave_code(w: Dictionary) -> String:
	match String(w.get("kind", "")):
		"template":
			return "tpl:" + String(w.get("template", ""))
		"wild":
			return "wild:" + String(w.get("leader", ""))
	return "boss:" + String(w.get("name", ""))


static func _pick_code(c: Dictionary, answer: Variant, out: Dictionary) -> String:
	match c.kind:
		"portal":
			var portal: Dictionary = c.portals[clampi(int(answer), 0, c.portals.size() - 1)]
			return "p:" + String(portal.map)
		"pokemon":
			var letter: String = {"starter": "s", "unique": "u", "legendary": "l", "addpick": "a", "form": "f"}.get(c.category, "k")
			return "%s:%s" % [letter, out.pkm]
		"items":
			var letter: String = {"wand": "w", "carousel": "c"}.get(c.source, "i")
			return "%s:%s" % [letter, String(answer) if answer is String else "-"]
	return "?"


static func _tsv(values: Array) -> String:
	return "\t".join(values.map(func(v) -> String: return str(v)))
#endregion
