class_name BattleSim
extends RefCounted

## One fight between the player's team (BLUE) and a wave (RED).
## Port of app/core/simulation.ts + moving/attacking states, run in fixed ms steps.
##
## The simulation never touches nodes. Everything the view needs is pushed in
## `events` (drained by the game every frame):
##   {type="move", unit, from, to, duration}      walk / dash / knockback (cell reserved at once)
##   {type="attack", unit, target, hit_delay}     basic attack starts (target null = drum beat)
##   {type="cast", unit, ability, focus}          ability starts (after the PP is spent)
##   {type="area", unit, cells, affects, delay}   cells hit by an ability step (see AbilityRunner)
##   {type="damage", unit, amount, kind, crit}    hp lost (shield included)
##   {type="heal"/"shield", unit, amount}
##   {type="status", unit, status, duration}
##   {type="buff", unit, stat, amount}
##   {type="item", unit, item, text}              an item triggers (Shiny Charm, Smoke Ball...)
##   {type="effect", unit, text, color}           a synergy / passive triggers (Tidal Wave, Fossil...)
##   {type="spawn", unit}                         a unit joins the fight (Bug clone, Mitosis...)
##   {type="transform", unit, pkm?}               a unit changes form (unit.pkm, or pkm: looks only)
##   {type="lightning", cell}                     STORM weather strikes a cell
##   {type="board_effect", cells, effect}         cells get a board effect (EMBER...)
##   {type="miss", unit}                          an attack is dodged
##   {type="death", unit}
##   {type="resurrect", unit}                     back to full HP instead of fainting
##   {type="end", winner}                         winner = Team or -1 (draw / timeout)
##
## Before adding units, `setup_teams()` gives each team its synergy tiers and the
## player's board context (light cell, ground holes, fairy wands). Held items:
## BattleUnit.equip() adds their stats, ItemEffects runs their effects; synergies
## are SynergyEffects, passives PassiveEffects, the weather Weather.

const FIGHT_DURATION_MS := 45000.0
const MAX_STEP_MS := 50.0
const ENRAGE_MS := 35000.0 ## status.ts enrageDelay: everyone becomes enraged
const ENRAGE_SPEED := 80.0
const SANDSTORM_DAMAGE := 5.0
const LIGHTNING_DAMAGE := 100.0
const CC_COOLDOWN := 1500.0 ## after a FREEZE, SLEEP or LOCKED ends, none of them can start for 1.5 s
const RAGE_SPEED := 80.0
## Berries eaten as soon as their status starts (status.ts trigger*).
const STATUS_BERRIES := {"burn": "RAWST_BERRY", "poison": "PECHA_BERRY", "freeze": "ASPEAR_BERRY",
	"sleep": "CHESTO_BERRY", "confusion": "PERSIM_BERRY", "paralysis": "CHERI_BERRY"}

var board := BattleBoard.new()
var units: Array[BattleUnit] = []
var time_ms := 0.0
var finished := false
var winner := -1
var fallen := [0, 0] ## fainted units per team (Retaliate, Kowtow Cleave)
var events: Array[Dictionary] = []
## What the player gains during the fight (golden berries...), given after it:
## PlayerState.collect_fight_rewards().
var rewards := {"gold": 0, "free_rolls": 0, "items": [], "cell_battery": 0}
## Callable(pkm) -> int: removes the player's bench units of that Pokémon, returns how
## many (Schooling). Set by FightSetup; invalid for other fights.
var player_bench_absorb := Callable()
## Flora: Pokémon of the unlocked flower pots of the player, in blossom order (FightSetup).
var flower_pots: Array = []
## The PlayerState of the blue team (Unown Hidden Powers act on it), null otherwise.
var player = null
## Abilities cast by each team in order (Encore).
var abilities_cast := [[], []]
var rng := RandomNumberGenerator.new()

var weather := Weather.NEUTRAL
## Basic PP rules of every unit (Difficulty.mana(): perSecond, perAttack, perHit, perDamage, maxPP and
## `roles` overriding them by role); a unit's own rules: mana_of(u).
var mana: Dictionary = Difficulty.mana():
	set(value):
		mana = value
		_role_mana = {}
var _role_mana := {} ## role -> Difficulty.role_mana of `mana`
## The unit whose basic attack is dealing its damage now (attack_hit): its damage events get "attack": true.
var _attack_source: BattleUnit = null
## Per team: {type: tier} of the active synergies (a wave has some when the difficulty says so).
var team_tiers: Array = [{}, {}]
## Per team: {counts, active, dragon_stars, light: Vector2i or null, holes: {cell: depth},
## wands: Array, stage} (see setup_teams).
var team_info: Array = [{}, {}]
## Board effects on cells: Vector2i -> {effect: true} (EMBER).
var board_effects: Dictionary = {}
## Team-level synergy timers (Aquatic tidal wave), owned by SynergyEffects.
var synergy_state: Dictionary = {}

var _scheduled: Array = [] ## [time_ms, BattleUnit owner, Callable, ability_source when scheduled]
## The unit whose ability is running now (AbilityRunner.cast, and what the ability scheduled): its damage, heal
## and shield events get "ability": true (bot TSV sdealt / ssus; the hits of basic attacks stay "attack").
var ability_source: BattleUnit = null
var _started := false
var _enraged := false
var _storm_timer := 0.0


func _init() -> void:
	rng.randomize()
	_storm_timer = rng.randf_range(4000.0, 8000.0)


## Team context, before adding units. `tiers` = {type: tier}, `info` = see team_info.
func setup_teams(blue_tiers: Dictionary, blue_info: Dictionary, red_tiers := {}, red_info := {}) -> void:
	team_tiers = [blue_tiers, red_tiers]
	team_info = [blue_info, red_info]
	SynergyEffects.setup(self)


## Random roll with luck (utils/random.ts chance): p^(1 - luck/100), at most `cap`.
func chance(probability: float, unit: BattleUnit = null, cap := 1.0) -> bool:
	if probability <= 0.0:
		return false
	var luck := unit.luck if unit != null else 0.0
	return rng.randf() < minf(cap, pow(minf(probability, 1.0), 1.0 - luck / 100.0))


## Crit multiplier of `attacker` on `t`: Rocky Helmet negates the bonus of crits.
func crit_multiplier(attacker: BattleUnit, t: BattleUnit, kind := BattleUnit.DamageKind.PHYSICAL) -> float:
	if t.has_item("ROCKY_HELMET") and kind != BattleUnit.DamageKind.TRUE:
		return 1.0
	return attacker.crit_power


## Adds a unit to the board. Synergies, weather and passives change its stats
## (applySynergyEffects / OnSpawn); a unit added once the fight runs is a spawn.
func add_unit(unit: BattleUnit, at: Vector2i) -> void:
	units.append(unit)
	board.place(unit, at)
	if _started:
		unit.is_spawn = true
	# Dark melee Pokémon move first
	unit.cooldown = 300.0 if unit.types.has("DARK") and unit.attack_range == 1 else unit.attack_cooldown() * 0.5
	SynergyEffects.on_spawn(self, unit)
	Weather.on_spawn(self, unit)
	PassiveEffects.on_spawn(self, unit)
	# its stats as it entered the fight (synergies, items, spawn effects): a resurrection restores them
	unit.counters.spawn_stats = {"max_hp": unit.max_hp, "atk": unit.atk, "def": unit.def, "spe_def": unit.spe_def,
		"ap": unit.ap, "speed": unit.speed, "crit_chance": unit.crit_chance, "crit_power": unit.crit_power,
		"dodge": unit.dodge, "attack_range": unit.attack_range, "luck": unit.luck}
	if _enraged:
		_enrage(unit)
	if _started:
		emit({"type": "spawn", "unit": unit})


## Breaks the reference cycles (scheduled lambdas -> sim, unit targets) so the
## fight is freed. Call once the views do not need the units any more.
func dispose() -> void:
	_scheduled.clear()
	events.clear()
	for u in units:
		u.target = null
		u.status_origin.clear()
		u.counters.clear()
	board.cells.fill(null)
	units.clear()


func alive_units(team: int) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for u in units:
		if u.alive and u.team == team:
			out.append(u)
	return out


func enemies_of(unit: BattleUnit) -> Array[BattleUnit]:
	return alive_units(BattleUnit.Team.RED if unit.team == BattleUnit.Team.BLUE else BattleUnit.Team.BLUE)


func allies_of(unit: BattleUnit) -> Array[BattleUnit]:
	return alive_units(unit.team)


func emit(event: Dictionary) -> void:
	events.append(event)


func drain_events() -> Array[Dictionary]:
	var out := events
	events = []
	return out


## Runs `callable` after `delay_ms`, skipped if `owner` fainted meanwhile.
func schedule(delay_ms: float, owner: BattleUnit, callable: Callable) -> void:
	if delay_ms <= 0.0:
		if owner == null or owner.alive:
			callable.call()
		return
	_scheduled.append([time_ms + delay_ms, owner, callable, ability_source])


func update(dt_ms: float) -> void:
	if finished:
		return
	dt_ms = minf(dt_ms, MAX_STEP_MS)
	if not _started:
		_started = true
		SynergyEffects.before_start(self) # Bug clones (spawns) join first
		ItemEffects.on_fight_start(self)
		SynergyEffects.on_fight_start(self)
		PassiveEffects.on_fight_start(self)
	time_ms += dt_ms

	var due: Array = []
	var later: Array = []
	for entry in _scheduled:
		(due if entry[0] <= time_ms else later).append(entry)
	_scheduled = later
	for entry in due:
		var owner: BattleUnit = entry[1]
		if owner == null or owner.alive:
			var outer := ability_source
			ability_source = entry[3] # a delayed hit of an ability is still the ability
			entry[2].call()
			ability_source = outer

	if not _enraged and time_ms >= ENRAGE_MS:
		_enraged = true
		for u in units:
			if u.alive:
				_enrage(u)
	_update_weather(dt_ms)
	SynergyEffects.update(self, dt_ms)

	for u in units.duplicate():
		if u.alive:
			_update_unit(u, dt_ms)

	_update_possessed()
	var blue_alive := alive_units(BattleUnit.Team.BLUE).size()
	var red_alive := alive_units(BattleUnit.Team.RED).size()
	if blue_alive == 0 or red_alive == 0:
		_finish(BattleUnit.Team.BLUE if red_alive == 0 and blue_alive > 0
			else BattleUnit.Team.RED if blue_alive == 0 and red_alive > 0 else -1)
	elif time_ms >= FIGHT_DURATION_MS:
		_finish(-1)


func _finish(winning_team: int) -> void:
	finished = true
	winner = winning_team
	emit({"type": "end", "winner": winner})


## Enraged (end of the fight): +80 SPEED, deals double damage, heals and shields
## halved, no more Protect; freeze / sleep / lock / blind last half as long.
func _enrage(u: BattleUnit) -> void:
	if u.inanimate:
		return
	u.statuses.erase("protect")
	var raging := u.has_status("enraged") # already in a Rage: it just never ends now (updateRage)
	u.add_status("enraged", 1e9)
	if not raging:
		u.add_stat("speed", ENRAGE_SPEED)
	emit({"type": "status", "unit": u, "status": "enraged", "duration": 1e9})


#region weather
## STORM: a lightning strikes a random cell every 2-6 s (100 special damage,
## ELECTRIC Pokémon get an Electric Field, 20 SPEED and 30 shield instead).
func _update_weather(dt: float) -> void:
	if weather != "STORM":
		return
	_storm_timer -= dt
	if _storm_timer > 0.0:
		return
	_storm_timer = rng.randf_range(2000.0, 6000.0)
	var cell := Vector2i(rng.randi_range(0, BattleBoard.WIDTH - 1), rng.randi_range(0, BattleBoard.HEIGHT - 1))
	emit({"type": "lightning", "cell": cell})
	var u := board.get_unit(cell)
	if u == null or not u.alive:
		return
	if u.types.has("ELECTRIC"):
		add_status(u, "electric_field", 1e9)
		u.add_stat("speed", 20.0)
		add_shield(u, 30.0)
	else:
		deal_damage(u, LIGHTNING_DAMAGE, BattleUnit.DamageKind.SPECIAL, null, false, false, false)
#endregion


#region unit loop
func _update_unit(u: BattleUnit, dt: float) -> void:
	var ticks := u.tick(dt)
	for s in ticks.expired:
		_status_ended(u, s)
	if ticks.burn:
		_burn_tick(u)
	if ticks.poison and u.alive:
		_poison_tick(u)
	if ticks.curse and u.alive:
		deal_damage(u, 9999.0, BattleUnit.DamageKind.TRUE, null, false, false, false)
		emit({"type": "effect", "unit": u, "text": "Curse!", "color": Color(0.6, 0.35, 0.9)})
	if not u.alive:
		return
	if ticks.second:
		_each_second(u)
		if not u.alive:
			return
	SynergyEffects.on_tick(self, u, dt)
	PassiveEffects.on_tick(self, u, dt)
	ItemEffects.on_tick(self, u, dt)
	if not u.alive or not u.can_act():
		return
	u.cooldown -= dt
	if u.cooldown > 0.0:
		return
	if u.has_status("skydiving"):
		u.statuses.erase("skydiving")
	if u.effects.get("tree", false): # treeEffect (idle-state.ts): stands still until its PP is full
		if u.max_pp > 0.0 and u.pp >= u.max_pp:
			u.effects.erase("tree")
		else:
			u.cooldown = 500.0
			return

	# CHARM (moving-state.ts): neither attacks nor casts, walks to whoever charmed it
	if u.has_status("charm"):
		u.cooldown = u.move_cooldown()
		var charmer: BattleUnit = u.status_origin.get("charm")
		if charmer != null and charmer.alive and u.can_move() and BattleBoard.distance_c(u.cell, charmer.cell) > 1:
			_step_toward(u, charmer.cell)
		return

	var t := _pick_target(u)
	u.target = t
	if t != null:
		if t.cell != u.cell:
			u.facing = BattleBoard.orientation(u.cell, t.cell)
		else: # confused, hitting itself: a random orientation
			u.facing = BattleBoard.DIRECTIONS[rng.randi() % 6]
		u.cooldown = u.attack_cooldown()
		if u.pp >= u.max_pp and u.can_cast():
			AbilityRunner.cast(self, u, t)
		else:
			_basic_attack(u, t)
		return

	u.cooldown = u.move_cooldown()
	if u.pp >= u.max_pp and u.can_cast() and u.ability().get("no_target", false):
		AbilityRunner.cast(self, u, null)
		return
	if PassiveEffects.drum_beat(self, u):
		return
	if u.can_move():
		if u.types.has("DARK") and u.attack_range == 1 and u.passive != "GUZZLORD":
			_dark_jump(u)
		else:
			_step_toward_enemy(u)


## PP rules of a unit: `mana` with the overrides of its role (BattleUnit.role).
func mana_of(u: BattleUnit) -> Dictionary:
	if not _role_mana.has(u.role):
		_role_mana[u.role] = Difficulty.role_mana(u.role, mana)
	return _role_mana[u.role]


## Passive PP (`perSecond` of its rules, RAIN +3, DROUGHT -3), SANDSTORM, board effects,
## then the synergies ticking every second (Water PP, Light PP).
func _each_second(u: BattleUnit) -> void:
	u.add_pp(float(mana_of(u).perSecond), true) # the rule
	u.add_pp(Weather.pp_per_second(weather, 0.0)) # RAIN +3 / DROUGHT -3 of a 100-PP bar
	SynergyEffects.on_second(self, u)
	DishEffects.on_second(self, u)
	PassiveEffects.on_second(self, u)
	if weather == "SANDSTORM" and not u.types.has("GROUND") and not u.has_item("SAFETY_GOGGLES"):
		deal_damage(u, SANDSTORM_DAMAGE, BattleUnit.DamageKind.SPECIAL, null, false, false, false)
	if u.alive and board_effects.get(u.cell, {}).has("EMBER") and not u.has_item("HEAVY_DUTY_BOOTS") \
			and not u.types.has("FIRE") and not u.types.has("FLYING"):
		deal_damage(u, 10.0, BattleUnit.DamageKind.SPECIAL, null)
		add_status(u, "burn", 2200.0)
	# POISON_GAS (Poison Gas, Stench): keeps non-Poison units poisoned.
	if u.alive and board_effects.get(u.cell, {}).has("POISON_GAS") and not u.has_item("HEAVY_DUTY_BOOTS") \
			and not u.types.has("POISON") and not u.has_status("poison"):
		add_status(u, "poison", 1500.0)
	# SMOKE (Smog): BLINDED while standing in it.
	if u.alive and board_effects.get(u.cell, {}).has("SMOKE") and not u.has_item("HEAVY_DUTY_BOOTS"):
		add_status(u, "blinded", 1100.0)
	# STICKY_WEB (Sticky Web): PARALYSIS 2 s.
	if u.alive and board_effects.get(u.cell, {}).has("STICKY_WEB") and not u.has_item("HEAVY_DUTY_BOOTS") \
			and not u.has_status("paralysis"):
		add_status(u, "paralysis", 2000.0)
	# COTTON_BALL (Cotton Guard, Cotton Spore): SLEEP 1 s, once per unit while it stays on the
	# cell (status.ts: the effect leaves the unit, the cell keeps it)
	if u.alive and board_effects.get(u.cell, {}).has("COTTON_BALL") and not u.has_item("HEAVY_DUTY_BOOTS") \
			and not u.has_status("sleep") and not u.effects.has("cotton_spent"):
		u.effects.cotton_spent = true
		add_status(u, "sleep", 1000.0)
	# STEALTH_ROCKS (Stone Axe): 10 PHYSICAL and WOUND 1 s (not Rock).
	if u.alive and board_effects.get(u.cell, {}).has("STEALTH_ROCKS") and not u.has_item("HEAVY_DUTY_BOOTS") \
			and not u.types.has("ROCK"):
		deal_damage(u, 10.0, BattleUnit.DamageKind.PHYSICAL, null)
		add_status(u, "wound", 1000.0)
	# TOXIC_SPIKES (Glimmora): POISONED 1 s (not Poison).
	if u.alive and board_effects.get(u.cell, {}).has("TOXIC_SPIKES") and not u.has_item("HEAVY_DUTY_BOOTS") \
			and not u.types.has("POISON"):
		add_status(u, "poison", 1000.0)
	# HAIL (Hail): once per unit entering the cell, 10 SPECIAL and FREEZE 1 s (not Ice).
	if u.alive and board_effects.get(u.cell, {}).has("HAIL") and not u.has_item("HEAVY_DUTY_BOOTS") \
			and not u.types.has("ICE") and not u.effects.has("hail_spent"):
		u.effects.hail_spent = true
		deal_damage(u, 10.0, BattleUnit.DamageKind.SPECIAL, null)
		add_status(u, "freeze", 1000.0)
	# SPIKES (Spikes, Ceaseless Edge): 10 TRUE and ARMOR_BREAK 1 s (not Flying / Steel).
	if u.alive and board_effects.get(u.cell, {}).has("SPIKES") and not u.has_item("HEAVY_DUTY_BOOTS") \
			and not u.types.has("FLYING") and not u.types.has("STEEL"):
		deal_damage(u, 10.0, BattleUnit.DamageKind.TRUE, null)
		add_status(u, "armor_reduction", 1000.0)


## BURN: 5% max HP as TRUE every second (DROUGHT +30%, RAIN -30%, Assault Vest and
## Aquatic reduce it, Well Baked ignores it), credited to whoever burned it.
func _burn_tick(u: BattleUnit) -> void:
	var damage := u.max_hp * 0.05
	if weather == "DROUGHT":
		damage *= 1.3
	elif weather == "RAIN":
		damage *= 0.7
	if u.has_item("ASSAULT_VEST"):
		damage *= 0.5
	damage *= SynergyEffects.status_damage_factor(u)
	if u.passive == "WELL_BAKED" or u.has_item("MAGMARIZER"):
		damage = 0.0
	if u.has_item("COOKING_POT"):
		u.add_stat("speed", 10.0)
	damage = roundf(damage)
	if damage > 0.0:
		deal_damage(u, damage, BattleUnit.DamageKind.TRUE, _origin(u, "burn"), false, false, true, true)


## POISONED: 5% max HP per stack as TRUE every second (RAIN -30%, Assault Vest, Aquatic).
func _poison_tick(u: BattleUnit) -> void:
	var stacks := u.poison_stacks - (2 if u.passive == "GLISCOR" else 0)
	var damage := u.max_hp * 0.05 * stacks
	if u.passive == "TOXIC_BOOST":
		damage *= 0.5
	if weather == "RAIN":
		damage *= 0.7
	if u.has_item("ASSAULT_VEST"):
		damage *= 0.5
	damage *= SynergyEffects.status_damage_factor(u)
	if stacks <= 0:
		return
	damage = maxf(roundf(damage), 1.0)
	deal_damage(u, damage, BattleUnit.DamageKind.TRUE, _origin(u, "poison"), false, false, false)


func _origin(u: BattleUnit, status: String) -> BattleUnit:
	var o: BattleUnit = u.status_origin.get(status)
	return o if o != null and o.alive and o != u else null


## Target of this step: the current one if still in range, else the nearest.
## Monster 4 (Merciless) always picks the weakest unit in range, allies under 10 HP included.
func _pick_target(u: BattleUnit) -> BattleUnit:
	if u.synergy_tier("MONSTER") >= 4 and u.pp < u.max_pp:
		var weakest: BattleUnit = null
		for other in units:
			if not other.alive or other == u or BattleBoard.distance_c(u.cell, other.cell) > u.attack_range:
				continue
			if other.team == u.team and other.hp > 10.0:
				continue
			if weakest == null or other.hp + other.shield < weakest.hp + weakest.shield:
				weakest = other
		return weakest
	var t: BattleUnit = u.target if _is_valid_target(u, u.target) else _nearest_target_in_range(u)
	if t != null and u.has_status("confusion"):
		return _confused_target(u)
	return t


## getTargetWhenConfused (attacking state): half of the time (luck helps) only the enemies
## count, else the allies too and itself; a random one of the closest within its range (Manhattan).
func _confused_target(u: BattleUnit) -> BattleUnit:
	var with_allies := not chance(0.5, u)
	var best_distance := u.attack_range + 1
	var candidates: Array[BattleUnit] = []
	for other in board.units():
		if other == u or not other.alive or other.is_untargetable():
			continue
		if other.team == u.team and not with_allies:
			continue
		var d := BattleBoard.distance_m(u.cell, other.cell)
		if d < best_distance:
			best_distance = d
			candidates = [other]
		elif d == best_distance:
			candidates.append(other)
	if with_allies:
		candidates.append(u) # sometimes hits itself
	return candidates[rng.randi() % candidates.size()] if not candidates.is_empty() else null


func _is_valid_target(u: BattleUnit, t: BattleUnit) -> bool:
	return t != null and t.alive and t.team != u.team and not t.is_untargetable() \
		and BattleBoard.distance_c(u.cell, t.cell) <= u.attack_range


func _nearest_target_in_range(u: BattleUnit) -> BattleUnit:
	var best: Array[BattleUnit] = []
	var best_distance := 999
	for e in enemies_of(u):
		if e.is_untargetable():
			continue
		var d := BattleBoard.distance_c(u.cell, e.cell)
		if d > u.attack_range:
			continue
		if d < best_distance:
			best_distance = d
			best = [e]
		elif d == best_distance:
			best.append(e)
	# Poke Doll: its holder is picked first among the closest
	var dolls := best.filter(func(e: BattleUnit) -> bool: return e.has_item("POKE_DOLL"))
	if not dolls.is_empty():
		best.assign(dolls)
	return best[rng.randi() % best.size()] if not best.is_empty() else null


func nearest_enemy_manhattan(u: BattleUnit) -> BattleUnit:
	var best: Array[BattleUnit] = []
	var best_distance := 999
	for e in enemies_of(u):
		var d := BattleBoard.distance_m(u.cell, e.cell)
		if d < best_distance:
			best_distance = d
			best = [e]
		elif d == best_distance:
			best.append(e)
	return best[rng.randi() % best.size()] if not best.is_empty() else null


## STRANGE_STEAM (Strange Steam): ability damage x1.2 when the attacker or the target
## stands in it (handleSpecialDamage).
func strange_steam_factor(attacker: BattleUnit, t: BattleUnit) -> float:
	for u in [attacker, t]:
		if u != null and board_effects.get(u.cell, {}).has("STRANGE_STEAM"):
			return 1.2
	return 1.0


## getFarthestTarget: the first targetable enemy of the board (row by row) at the greatest
## Manhattan distance.
func farthest_enemy(u: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	var best_distance := 0
	for e in board.units():
		if not e.alive or e.team == u.team or e.is_untargetable():
			continue
		var d := BattleBoard.distance_m(u.cell, e.cell)
		if d > best_distance:
			best_distance = d
			best = e
	return best


## getFarthestTargetCoordinateAvailablePlace: going through the board row by row, each
## targetable unit farther than the ones before (enemies, or allies with `allies`) offers the
## free cell around it farthest from `u` (Manhattan); the last one offering a cell wins. When
## none could, the free cell closest to the farthest one. {cell, target} or {}.
func farthest_spot(u: BattleUnit, allies := false) -> Dictionary:
	var best_target_distance := 0
	var selected := {}
	var farthest: BattleUnit = null
	for e in board.units():
		if not e.alive or e.is_untargetable() or e == u or (e.team == u.team) != allies:
			continue
		var d := BattleBoard.distance_m(u.cell, e.cell)
		if d <= best_target_distance:
			continue
		best_target_distance = d
		farthest = e
		var best_cell_distance := 0
		for c in BattleBoard.adjacent_cells(e.cell):
			if board.is_free(c) and BattleBoard.distance_m(c, u.cell) > best_cell_distance:
				best_cell_distance = BattleBoard.distance_m(c, u.cell)
				selected = {"cell": c, "target": e}
	if selected.is_empty() and farthest != null:
		var free: Variant = board.closest_free_cell(farthest.cell)
		if free != null:
			selected = {"cell": free, "target": farthest}
	return selected


## getClosestFreeCellTo: free cells around `cell` in the web priority order (sideways first, then
## toward the own side, then the next ring: near_order()), else the first free cell of the team side.
func closest_free_cell_near(cell: Vector2i, team: int) -> Variant:
	var red := team == BattleUnit.Team.RED
	for o in near_order():
		# red: the same offset mirrored across the row (axial (q, r) -> (q + r, -r))
		var c := BattleBoard.step(cell, Vector2i(o.x + o.y, -o.y) if red else o)
		if board.is_free(c):
			return c
	var rows := range(BattleBoard.HEIGHT) if team == BattleUnit.Team.BLUE else range(BattleBoard.HEIGHT - 1, -1, -1)
	for y in rows:
		for x in BattleBoard.WIDTH:
			if board.is_free(Vector2i(x, y)):
				return Vector2i(x, y)
	return null


static var _near_order: Array[Vector2i] = []


## Axial offsets within 3 steps for the blue team, in the order getClosestFreeCellTo tries them:
## by distance, then the row (the same row, then toward the own side, then forward), then the
## closest sideways, the left one first. The red team mirrors the rows.
static func near_order() -> Array[Vector2i]:
	if _near_order.is_empty():
		var all: Array[Vector2i] = []
		for q in range(-3, 4):
			for r in range(-3, 4):
				var o := Vector2i(q, r)
				if BattleBoard.distance(Vector2i.ZERO, BattleBoard.from_axial(o)) <= 3:
					all.append(o)
		all.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _near_key(a) < _near_key(b))
		_near_order = all
	return _near_order


static func _near_key(o: Vector2i) -> Vector3:
	var d := (absi(o.x) + absi(o.y) + absi(o.x + o.y)) / 2
	var side := float(o.x) + 0.5 * float(o.y) # sideways position, in cell widths
	var row_rank := 0 if o.y == 0 else (1 if o.y < 0 else 2) * 10 + absi(o.y)
	return Vector3(d, row_rank, absf(side) * 2.0 + (0.5 if side > 0.0 else 0.0))


## getNearestAvailablePlaceCoordinates: a random one of the free cells closest to `cell`
## (Manhattan), at most `max_range` away (-1 = any). null if none.
func nearest_free_cell(cell: Vector2i, max_range := -1) -> Variant:
	var best: Array[Vector2i] = []
	var best_distance := 999
	for c in board.free_cells():
		var d := BattleBoard.distance_m(c, cell)
		if max_range >= 0 and d > max_range:
			continue
		if d < best_distance:
			best_distance = d
			best = [c]
		elif d == best_distance:
			best.append(c)
	return best[rng.randi() % best.size()] if not best.is_empty() else null


## getTeleportationCell: the free cell farthest from `from` on the lines toward
## the two back corners of `team`'s side.
func teleport_cell(from: Vector2i, team: int) -> Variant:
	var y := 0 if team == BattleUnit.Team.BLUE else BattleBoard.HEIGHT - 1
	var best: Variant = null
	var best_distance := -1
	for corner in [Vector2i(0, y), Vector2i(BattleBoard.WIDTH - 1, y)]:
		for c in BattleBoard.cells_between(from, corner):
			if board.is_free(c) and BattleBoard.distance_c(from, c) > best_distance:
				best_distance = BattleBoard.distance_c(from, c)
				best = c
	return best


## getSafePlaceAwayFrom: the free cell farthest (Manhattan) from `from`, on `side`
## (a Team, -1 = anywhere), at most `max_distance` cells away (Chebyshev, -1 = any).
func safe_place_away(from: Vector2i, side := -1, max_distance := -1) -> Variant:
	var best: Variant = null
	var best_distance := -1
	for c in board.free_cells():
		if side == BattleUnit.Team.BLUE and c.y >= BattleBoard.HEIGHT / 2:
			continue
		if side == BattleUnit.Team.RED and c.y < BattleBoard.HEIGHT / 2:
			continue
		if max_distance >= 0 and BattleBoard.distance_c(c, from) > max_distance:
			continue
		if BattleBoard.distance_m(c, from) > best_distance:
			best_distance = BattleBoard.distance_m(c, from)
			best = c
	return best
#endregion


#region movement
## One cell toward the nearest enemy (hex distance; web: Manhattan). The goal is any free cell
## within attack range of that enemy; paths go through the 6 neighbours (web: 8 directions,
## diagonal cost √2) and other Pokémon block the way, like app/utils/pathfind.ts.
func _step_toward_enemy(u: BattleUnit) -> void:
	var enemy := nearest_enemy_manhattan(u)
	if enemy != null:
		_step_toward(u, enemy.cell)


## One cell toward the cells within attack range of `target` (pathfind.ts).
func _step_toward(u: BattleUnit, target: Vector2i) -> void:
	var goals := {}
	for c in BattleBoard.cells_in_range(target, u.attack_range):
		if board.is_free(c):
			goals[c] = true
	if goals.is_empty():
		return
	var step: Variant = _first_step(u.cell, goals)
	if step == null:
		return
	move_unit(u, step, u.move_cooldown())


## Melee DARK Pokémon jump next to the farthest enemy instead of walking (moving-state.ts);
## Stench leaves POISON_GAS on the cells it jumps over, Parting Shot (Pangoro) weakens the
## enemy it lands next to once.
func _dark_jump(u: BattleUnit) -> void:
	var spot := farthest_spot(u)
	if spot.is_empty():
		return
	var from := u.cell
	if u.passive == "STENCH":
		var cells: Array = BattleBoard.cells_between(spot.cell, from)
		cells.erase(spot.cell)
		AbilityScripts.board_effect(self, cells, "POISON_GAS")
	var t: BattleUnit = spot.target
	if u.passive == "PARTING_SHOT" and not t.effects.get("parting_shot", false):
		PassiveEffects.parting_shot(self, u, t)
	move_unit(u, spot.cell, 250.0, "dash")


func _first_step(from: Vector2i, goals: Dictionary) -> Variant:
	# Dijkstra on the 56 cells; small enough to run every step.
	var dist := {from: 0.0}
	var first := {from: from}
	var open: Array[Vector2i] = [from]
	var best_goal: Variant = null
	var best_cost := INF
	while not open.is_empty():
		var current: Vector2i = open[0]
		var current_i := 0
		for i in open.size():
			if dist[open[i]] < dist[current]:
				current = open[i]
				current_i = i
		open.remove_at(current_i)
		if dist[current] >= best_cost:
			break
		if goals.has(current) and current != from:
			best_cost = dist[current]
			best_goal = current
			continue
		for dir in BattleBoard.DIRECTIONS:
			var next := BattleBoard.step(current, dir)
			if not board.is_free(next):
				continue
			var cost: float = dist[current] + 1.0
			if cost < dist.get(next, INF):
				dist[next] = cost
				first[next] = next if current == from else first[current]
				if not open.has(next):
					open.append(next)
	return first[best_goal] if best_goal != null else null


## Moves a unit to a free cell. The cell is reserved immediately; the view
## slides the sprite over `duration` ms.
func move_unit(u: BattleUnit, to: Vector2i, duration: float, kind := "walk") -> void:
	var from := u.cell
	if from == to or not board.is_free(to):
		return
	u.facing = BattleBoard.orientation(from, to)
	board.move(u, to)
	if kind == "walk":
		ItemEffects.on_move(u)
	PassiveEffects.on_move(u)
	emit({"type": "move", "unit": u, "from": from, "to": to, "duration": duration, "kind": kind})
	_on_displaced(u, from, to)


## moveTo(x, y, board, forcedDisplacement = true): a skydiving or LOCKED unit, or one wearing
## Heavy-Duty Boots, is not moved. False when it stays.
func force_move(u: BattleUnit, to: Vector2i, duration := 250.0, kind := "knockback") -> bool:
	if not u.can_be_moved() or not board.is_free(to):
		return false
	move_unit(u, to, duration, kind)
	return true


## board.swapCells: two cells trade their units (one may be empty), shown as dashes.
func swap_cells(a: Vector2i, b: Vector2i, kind := "dash", duration := 250.0) -> void:
	var ua := board.get_unit(a)
	var ub := board.get_unit(b)
	board.swap(a, b)
	if ua != null:
		ua.facing = BattleBoard.orientation(a, b)
		emit({"type": "move", "unit": ua, "from": a, "to": b, "duration": duration, "kind": kind})
		_on_displaced(ua, a, b)
	if ub != null:
		ub.facing = BattleBoard.orientation(b, a)
		emit({"type": "move", "unit": ub, "from": b, "to": a, "duration": duration, "kind": kind})
		_on_displaced(ub, b, a)


## OnMoveEffect (board.swapCells): what follows a unit changing cell.
##   COTTON_BALL: a cotton ball slept on is used up only while it stays on that cell
##   Pursuit: a marked unit that jumps (more than one cell) is chased (pursuit.ts PursuitEffect)
##   Stench: leaves POISON_GAS where it was
func _on_displaced(u: BattleUnit, from: Vector2i, to: Vector2i) -> void:
	u.effects.erase("cotton_spent")
	u.effects.erase("hail_spent")
	if u.passive == "STENCH" and BattleBoard.in_bounds(from):
		AbilityScripts.board_effect(self, [from], "POISON_GAS")
	if u.effects.has("pursuers") and BattleBoard.distance_c(from, to) > 1:
		for id in u.effects.pursuers.duplicate():
			var p := unit_by_id(id)
			if p != null and p.alive and p.can_move():
				_pursue(p, u)


## PursuitEffect: the pursuer lands on the free cell closest to its jumping target and casts
## Pursuit on it again once it got there.
func _pursue(p: BattleUnit, t: BattleUnit) -> void:
	var spot: Variant = board.closest_free_cell(t.cell)
	if spot == null:
		return
	move_unit(p, spot, 250.0, "dash")
	p.target = t
	schedule(p.move_cooldown(), p, func() -> void:
		if t.alive and p.can_cast() and GameData.abilities.has("PURSUIT"):
			AbilityRunner.cast(self, p, t, "PURSUIT"))


## A unit leaving the fight without fainting (Comfey becoming an item, Tatsugiri in Dondozo's
## mouth): not counted as fallen, no KO effect.
func remove_unit(u: BattleUnit) -> void:
	if not u.alive:
		return
	u.alive = false
	u.hp = 0.0
	u.effects.removed = true
	board.clear(u.cell)
	emit({"type": "remove", "unit": u})


func unit_by_id(id: int) -> BattleUnit:
	for u in units:
		if u.id == id:
			return u
	return null
#endregion


#region attacks and damage
func _basic_attack(u: BattleUnit, t: BattleUnit) -> void:
	var cooldown := u.attack_cooldown()
	var delays: Dictionary = GameData.delays.get(u.data.get("index", ""), {"d": 18, "t": 36})
	var ratio := float(delays.get("d", 18)) / maxf(float(delays.get("t", 36)), 1.0)
	var hit_delay := minf(cooldown * 0.5, cooldown * ratio)
	if u.attack_range > 1:
		hit_delay += BattleBoard.distance_c(u.cell, t.cell) * 1000.0 / (3.0 * (1.0 + u.speed / 100.0))
	u.counters.attacks = u.counters.get("attacks", 0) + 1
	emit({"type": "attack", "unit": u, "target": t, "hit_delay": hit_delay})
	schedule(hit_delay, u, func() -> void:
		if t.alive:
			attack_hit(u, t)
	)


## Damage of a basic attack (pokemon-state.ts attack): dodge, fairy wands, steel /
## Red Orb true part, crit (reduced by Rock), Punching Glove, then the on-attack
## and on-hit effects. `triple` = 2nd / 3rd hit of an Electric triple attack.
func attack_hit(u: BattleUnit, t: BattleUnit, triple := false) -> void:
	if not t.alive:
		return
	if t.effects.get("obstruct", false): # Obstruct: its attackers lose 2 DEF
		u.add_stat("def", AbilityRunner.adjust_buff(t, u, -2.0))
	var special_mode: bool = u.effects.get("special_attacks", false) \
		or float(t.effects.get("wonder_room_until", 0.0)) > time_ms # Wonder Room
	var damage := u.atk
	var crit := chance(u.crit_chance / 100.0 + SynergyEffects.crit_chance_bonus(self, u, t), u)
	var crit_factor := SynergyEffects.crit_reduction(t) if crit else 1.0
	if special_mode:
		damage = ceilf(damage * (1.0 + u.ap / 100.0))
	var landed := true
	var dodge_chance := t.dodge + (0.5 if u.has_status("blinded") else 0.0)
	var lock_on: bool = u.effects.get("lock_on", false) # Lock-On: cannot be dodged, true damage
	if chance(dodge_chance, t, BattleUnit.MAX_DODGE) and not u.has_item("XRAY_VISION") and not lock_on \
			and not (t.has_status("paralysis") or t.has_status("sleep") or t.has_status("freeze") or t.has_status("locked")):
		landed = false
	if not landed:
		damage = 0.0
		emit({"type": "miss", "unit": t})
	if t.has_status("protect") or t.has_status("skydiving"):
		landed = false
		damage = 0.0
	var killed := false
	var taken := 0.0
	_attack_source = u # the damage events of this hit are marked "attack" (bot data: attack vs ability damage)
	if landed and u.types.has("FAIRY"):
		var wand := SynergyEffects.apply_wands(self, u, t, crit)
		taken += wand.taken
		killed = wand.death
	# bonus SPECIAL of pokemon-state.ts attack(), dodged or not (`damage` is 0 then)
	var bonus_special := 0.0
	if u.effects.get("charge", false): # Charge: x casts done (x2 at 4★)
		bonus_special += ceilf(damage * (2.0 if u.stars >= 4 else 1.0) * u.cast_count * (1.0 + u.ap / 100.0))
	if u.has_item("NULLIFY_BANDANNA"):
		bonus_special += u.pp
		u.pp = 0.0
	if u.passive == "SPOT_PANDA" and t.has_status("confusion"): # Spinda
		bonus_special += damage * (1.0 + u.ap / 100.0)
	var true_part := SynergyEffects.steel_true_part(u) + (0.25 if u.has_item("RED_ORB") else 0.0) \
		+ (0.1 if u.effects.get("steely_spirit", false) else 0.0) # Perrserker's row
	if lock_on:
		true_part += (5.0 if u.stars >= 4 else 2.0) * (1.0 + u.ap / 100.0)
		u.effects.erase("lock_on")
	var true_damage := 0.0
	if true_part > 0.0:
		true_damage = damage * true_part * (u.crit_power if crit else 1.0)
		damage = maxf(damage * (1.0 - true_part), 0.0)
	if crit:
		damage *= 1.0 + (u.crit_power - 1.0) * crit_factor
	var physical := 0.0 if special_mode else damage
	var special := bonus_special + (damage if special_mode else 0.0)
	if u.effects.get("stone_edge", false): # Stone Edge: + DEF x 1 / 1 / 2 (+AP)
		physical += u.def * (AbilityScripts.by_stars(u, [1, 1, 2, 4]) + u.ap / 100.0)
	if u.has_item("PUNCHING_GLOVE"):
		physical += 0.08 * t.max_hp
	if u.effects.has("next_attack_special"): # Shadow Punch...
		special += float(u.effects.next_attack_special)
		u.effects.erase("next_attack_special")
	if u.effects.get("teleport_next_attack", false): # Teleport: 15 / 30 / 60 SPECIAL (AP, ability crit)
		var ability_crit: bool = crit and u.effects.get("ability_crit", false)
		special += ceilf(AbilityScripts.by_stars(u, [15, 30, 60, 120]) * (1.0 + u.ap / 100.0)
			* ((1.0 + (u.crit_power - 1.0) * crit_factor) if ability_crit else 1.0))
		u.effects.erase("teleport_next_attack")
	if u.effects.get("attack_order_next_attack", false): # Attack Order: + per Combee ally
		var ability_crit: bool = crit and u.effects.get("ability_crit", false)
		var combees := alive_units(u.team).filter(func(a: BattleUnit) -> bool: return a.pkm == "COMBEE").size()
		special += ceilf((AbilityScripts.by_stars(u, [20, 40, 60, 120]) + combees * AbilityScripts.by_stars(u, [10, 20, 30, 60]))
			* (1.0 + u.ap / 100.0) * ((1.0 + (u.crit_power - 1.0) * crit_factor) if ability_crit else 1.0))
		u.effects.erase("attack_order_next_attack")
	physical = roundf(physical)
	special = roundf(special)
	true_damage = roundf(true_damage)
	if landed:
		ItemEffects.on_hit(self, u, t)
		DishEffects.on_hit(self, u, t)
		if t.has_status("spike_armor") and BattleBoard.distance_c(u.cell, t.cell) == 1 \
				and not u.has_item("PROTECTIVE_PADS"):
			_spike_armor(t, u)
	var struck := false # a part of the hit went through (not blocked): the target's perHit
	if physical > 0.0 and t.alive:
		var r := deal_damage(t, physical, BattleUnit.DamageKind.PHYSICAL, u, crit)
		taken += r.taken
		killed = r.death or killed
		struck = struck or r.taken > 0.0
	if special > 0.0 and t.alive:
		var r := deal_damage(t, special, BattleUnit.DamageKind.SPECIAL, u, crit)
		taken += r.taken
		killed = r.death or killed
		struck = struck or r.taken > 0.0
	if true_damage > 0.0 and t.alive:
		var r := deal_damage(t, true_damage, BattleUnit.DamageKind.TRUE, u, crit)
		taken += r.taken
		killed = r.death or killed
		struck = struck or r.taken > 0.0
	_attack_source = null
	# basic PP (Difficulty.mana, by role): the attacker for a hit that lands, the target once per hit of
	# a basic attack (an ability's damage gives none; abilities that power basic attacks go through here)
	if landed:
		u.add_pp(float(mana_of(u).perAttack), true) # the rules: PP as they are, not of a 100-PP bar
		if struck and t.alive:
			t.add_pp(float(mana_of(t).perHit), true)
	var hit := {"target": t, "physical": physical, "special": special, "true_damage": true_damage,
		"total": physical + special + true_damage, "taken": taken, "killed": killed, "crit": crit,
		"landed": landed, "triple": triple}
	ItemEffects.on_attack(self, u, hit)
	SynergyEffects.on_attack(self, u, hit)
	PassiveEffects.on_attack(self, u, hit)
	SynergyEffects.on_attack_received(self, t, u, hit)
	if landed:
		ItemEffects.on_attack_received(self, t, u)
		SynergyEffects.on_hit(self, u, t)
		PassiveEffects.on_hit(self, u, t, taken)


## Applies damage after armor, shield and protect (pokemon-state.ts handleDamage).
## Returns {taken, death}. `retaliation`: damage sent back (Reflect, Power Lens,
## Sticky Barb, Fighting throw), never sent back again. `gain_pp`: the target gains
## PP from the damage (`perDamage` of its rules; not from poison) — the flat `perHit` is only for the
## hits of a basic attack (attack_hit). `over_time`: burn tick (kept for the callers).
func deal_damage(t: BattleUnit, amount: float, kind: int, attacker: BattleUnit, crit := false,
		retaliation := false, gain_pp := true, over_time := false) -> Dictionary:
	if not t.alive:
		return {"taken": 0.0, "death": false}
	if attacker != null and attacker.has_status("enraged"):
		amount *= 2.0
	# Magic Bounce (Rowap Berry): special damage is blocked and bounced back
	if t.has_status("magic_bounce") and kind == BattleUnit.DamageKind.SPECIAL and attacker != null \
			and attacker != t and not retaliation:
		emit({"type": "damage", "unit": t, "amount": 0, "kind": kind, "crit": false, "blocked": true, "source": attacker,
			"reduced": roundf(amount), "shield_taken": 0.0})
		if not attacker.has_item("PROTECTIVE_PADS"):
			var bounce := roundf([0.5, 1.0, 2.0, 4.0][clampi(t.stars - 1, 0, 3)] * amount * (1.0 + t.ap / 100.0))
			deal_damage(attacker, bounce, BattleUnit.DamageKind.SPECIAL, t, false, true)
		return {"taken": 0.0, "death": false}
	if t.has_status("resurrecting"):
		return {"taken": 0.0, "death": false}
	if t.has_status("protect") or t.has_status("skydiving"):
		emit({"type": "damage", "unit": t, "amount": 0, "kind": kind, "crit": false, "blocked": true, "source": attacker,
			"reduced": roundf(amount), "shield_taken": 0.0})
		return {"taken": 0.0, "death": false}
	if attacker != null:
		amount *= 1.0 + 0.2 * attacker.field_count()
		if t.has_status("freeze") and attacker.synergy_tier("ICE") >= 4:
			amount *= 1.3 # Sheer Cold
		if attacker.passive == "HISUIAN_TYPHLOSION" and (t.has_status("burn") or t.has_status("silence")):
			amount *= 1.2
	amount *= Weather.damage_factor(weather, kind)
	# Reflect: physical damage is blocked; the attacker takes x0.5 / 0.75 / 1 of it (AP, ability crit)
	if t.has_status("reflect") and kind == BattleUnit.DamageKind.PHYSICAL:
		if attacker != null and attacker.alive and not attacker.has_item("PROTECTIVE_PADS") and not retaliation:
			var reflect_crit: bool = t.effects.get("ability_crit", false) and chance(t.crit_chance / 100.0, t)
			var reflected := roundf(AbilityScripts.by_stars(t, [0.5, 0.75, 1.0, 1.5]) * amount * (1.0 + t.ap / 100.0)
				* (t.crit_power if reflect_crit else 1.0))
			deal_damage(attacker, reflected, BattleUnit.DamageKind.SPECIAL, t, reflect_crit, true)
		emit({"type": "damage", "unit": t, "amount": 0, "kind": kind, "crit": false, "blocked": true, "source": attacker,
			"reduced": roundf(amount), "shield_taken": 0.0})
		return {"taken": 0.0, "death": false}
	var before := amount
	var pads := attacker != null and attacker != t and attacker.has_item("PROTECTIVE_PADS")
	var reduced := amount
	var wonder := float(t.effects.get("wonder_room_until", 0.0)) > time_ms # DEF and SPE_DEF swapped
	if kind == BattleUnit.DamageKind.PHYSICAL:
		reduced = amount / (1.0 + BattleUnit.ARMOR_FACTOR * (t.effective_spe_def() if wonder else t.effective_def()))
	elif kind == BattleUnit.DamageKind.SPECIAL:
		reduced = amount / (1.0 + BattleUnit.ARMOR_FACTOR * (t.effective_def() if wonder else t.effective_spe_def()))
	if kind != BattleUnit.DamageKind.TRUE:
		if t.has_item("POKE_DOLL"):
			reduced *= 0.7
		reduced -= SynergyEffects.blocked_damage(t)
		if t.passive == "WONDER_GUARD": # Shedinja: 20 less damage from every non-TRUE hit
			reduced -= 20.0
	reduced = maxf(ceilf(reduced), 1.0)
	if t.has_item("ABSORB_BULB"): # stores the damage its defenses stopped
		t.counters.reduced = float(t.counters.get("reduced", 0.0)) + maxf(amount - reduced, 0.0)

	var residual := reduced
	var taken := 0.0
	var shield_before := t.shield
	if t.shield > 0.0:
		var on_shield := ceilf(reduced * 0.5) if t.has_status("flinch") else reduced
		residual = reduced - on_shield
		if pads:
			on_shield *= 2.0 # Protective Pads: double damage on shields
		if on_shield >= t.shield:
			residual += on_shield - t.shield
			on_shield = t.shield
		t.shield -= on_shield
		taken += on_shield
		if t.shield <= 0.0 and t.has_item("EXPLOSIVE_BAND"):
			ItemEffects.explosive_band(self, t)
		if t.shield <= 0.0:
			PassiveEffects.on_shield_depleted(self, t)
	if t.has_item("SHINY_CHARM") and t.hp - residual < 0.3 * t.max_hp:
		t.use_up("SHINY_CHARM")
		residual = 0.0
		taken = 0.0
		t.add_pp(50.0)
		add_status(t, "protect", 1500.0)
		emit({"type": "item", "unit": t, "item": "SHINY_CHARM", "text": "Shiny Charm!"})
	# Cover Band: an ADJACENT ally wearing it takes the killing blow instead
	if t.hp - residual <= 0.0 and not t.has_item("COVER_BAND"):
		for c in BattleBoard.adjacent_cells(t.cell):
			var cover := board.get_unit(c)
			if cover != null and cover.alive and cover.team == t.team and cover.has_item("COVER_BAND") and cover.hp > 0.0:
				t.shield += taken # undo the shield part taken from the covered unit
				return deal_damage(cover, amount, kind, attacker, crit, retaliation, gain_pp, over_time)
	var fossil := SynergyEffects.fossil_awaken(self, t, residual)
	taken += fossil.taken
	residual = fossil.residual
	taken += minf(residual, t.hp)
	t.hp -= residual
	var per_damage := float(mana_of(t).perDamage)
	if gain_pp and residual > 0.0 and per_damage > 0.0:
		t.add_pp(ceilf(residual / per_damage), true) # the rule
	# source: attacker (hit sprite, DPS meter), reduced: damage stopped by DEF / SPE_DEF...
	# effective: what it really lost (shield + HP, not past 0 HP: an execute's 9999 counts as the HP it had)
	emit({"type": "damage", "unit": t, "amount": reduced, "kind": kind, "crit": crit, "source": attacker, "effective": taken,
		"reduced": maxf(roundf(amount - reduced), 0.0), "shield_taken": shield_before - t.shield,
		"attack": attacker != null and attacker == _attack_source, # from the hit of a basic attack (attack_hit)
		"ability": attacker != null and attacker == ability_source and attacker != _attack_source}) # from its ability

	var can_retaliate := attacker != null and attacker.alive and not retaliation \
		and not attacker.has_item("PROTECTIVE_PADS")
	if can_retaliate and kind == BattleUnit.DamageKind.SPECIAL and t.has_item("POWER_LENS") and amount >= 1.0:
		# Power Lens: the special damage blocked by SPE_DEF goes back to the attacker
		var blocked := amount - amount / (1.0 + BattleUnit.ARMOR_FACTOR * t.effective_spe_def())
		if blocked >= 1.0:
			deal_damage(attacker, roundf(blocked), BattleUnit.DamageKind.SPECIAL, t, false, true)

	if attacker != null and attacker.alive and taken > 0.0:
		ItemEffects.on_damage_dealt(self, attacker, t, taken, kind)
		SynergyEffects.on_damage_dealt(self, attacker, t, taken, retaliation)
	if t.hp <= 0.0:
		if t.has_item("SMOKE_BALL"):
			ItemEffects.smoke_ball(self, t)
		if _try_resurrect(t):
			return {"taken": taken, "death": false}
		_faint(t, attacker, kind)
		return {"taken": taken, "death": true}
	if taken > 0.0:
		if t.has_status("sleep") and t.passive != "COMATOSE": # each hit wakes it up 0.3 s sooner
			t.statuses.sleep -= 300.0
		if t.has_status("charm") and attacker != null and attacker == t.status_origin.get("charm"):
			t.statuses.charm -= 500.0
		if t.effects.has("bide_damage"): # Bide stores the damage received
			t.effects.bide_damage += taken
		ItemEffects.on_damage_received(self, t, taken)
		SynergyItems.on_damage_received(self, t)
		SynergyEffects.on_damage_received(self, t, attacker, taken, retaliation)
		PassiveEffects.on_damage_received(self, t, attacker, kind, before, retaliation)
	return {"taken": taken, "death": false}


## Spike armor (Spiky Shield, Jaboca Berry): a melee attacker takes DEF x 0.6 / 0.8 / 1
## as SPECIAL (AP and ability crit apply) and is wounded 2 s (pokemon-entity.ts onHit).
func _spike_armor(t: BattleUnit, attacker: BattleUnit) -> void:
	var crit: bool = t.effects.get("ability_crit", false) and chance(t.crit_chance / 100.0, attacker)
	var factor: float = [0.6, 0.8, 1.0][clampi(t.stars - 1, 0, 2)]
	var damage := roundf(t.def * factor * (1.0 + t.ap / 100.0) * (t.crit_power if crit else 1.0))
	add_status(attacker, "wound", 2000.0, t)
	deal_damage(attacker, damage, BattleUnit.DamageKind.SPECIAL, t, crit, true)


## Resurrection (Max Revive, Light 4, Roar of Time...): the first KO is not one (triggerResurrection):
## for 2 s it is out of the fight (untargetable, no damage), its negative statuses gone; then it
## comes back (resurrect()) with its stats of the fight start, full HP, no PP, no shield, no status
## but the ones of its items; Max Revive, Sacred Ash (3 fallen allies back) and Dynamax Band are spent.
func _try_resurrect(t: BattleUnit) -> bool:
	if not t.effects.get("resurrection", false):
		return false
	t.effects.erase("resurrection")
	t.hp = 1.0
	t.cleanse()
	t.add_status("resurrecting", 2000.0)
	t.target = null
	for e in units:
		if e.target == t:
			e.target = null
			e.cooldown = 0.0
	PassiveEffects.on_resurrecting(self, t)
	emit({"type": "resurrect", "unit": t})
	schedule(2000.0, t, func() -> void: _resurrect(t))
	return true


func _resurrect(t: BattleUnit) -> void:
	var snap: Dictionary = t.counters.get("spawn_stats", {})
	if not snap.is_empty():
		t.max_hp = float(snap.max_hp)
		t.atk = float(snap.atk)
		t.def = float(snap.def)
		t.spe_def = float(snap.spe_def)
		t.ap = float(snap.ap)
		t.speed = float(snap.speed)
		t.crit_chance = float(snap.crit_chance)
		t.crit_power = float(snap.crit_power)
		t.dodge = float(snap.dodge)
		t.attack_range = int(snap.attack_range)
		t.luck = float(snap.luck)
	for key in ["mach_ms", "muscle_band", "soul_dew_ms", "upgrade", "sound_cry"]: # stacking items start again
		t.counters.erase(key)
	if t.has_item("SACRED_ASH"):
		_sacred_ash(t)
	t.use_up("SACRED_ASH")
	t.use_up("MAX_REVIVE")
	if t.has_item("DYNAMAX_BAND"): # removed: its max HP bonus too
		t.use_up("DYNAMAX_BAND")
		t.max_hp = maxf(1.0, t.max_hp - 2.0 * t.base_hp)
	var enraged := t.has_status("enraged") and _enraged
	t.statuses.clear() # clearAllStatus, then the statuses of its items
	t.poison_stacks = 0
	if enraged:
		t.statuses.enraged = 1e9
	if t.has_item("SAFETY_GOGGLES"):
		t.add_status("safeguard", 60000.0)
	if t.has_item("FLAME_ORB"):
		t.add_status("burn", 300000.0)
	t.hp = t.max_hp
	t.pp = 0.0
	t.shield = 0.0
	t.cooldown = 0.0
	PassiveEffects.on_resurrect(self, t)


## Sacred Ash: up to 3 fainted allies of the board come back next to its holder.
func _sacred_ash(t: BattleUnit) -> void:
	var fallen_allies: Array = units.filter(func(u: BattleUnit) -> bool:
		return not u.alive and u != t and u.team == t.team and not u.is_spawn and u.owned_id >= 0 \
			and not u.effects.get("removed", false))
	for _i in mini(3, fallen_allies.size()):
		var dead: BattleUnit = fallen_allies.pop_at(rng.randi() % fallen_allies.size())
		var cell: Variant = closest_free_cell_near(t.cell, t.team)
		if cell == null:
			return
		var u := BattleUnit.create(dead.pkm, t.team)
		u.is_spawn = true
		add_unit(u, cell)


## POSSESSED (Malignant Chain, Mind Bend, Binding Mochi): fights for the other team while it
## lasts, unless it is the last free unit of its team. False when it cannot be possessed.
func _possess(t: BattleUnit, origin: BattleUnit) -> bool:
	if t.has_status("safeguard"):
		return true # Rune Protect: nothing happens
	var home: int = t.effects.get("base_team", t.team)
	var free := alive_units(home).filter(func(u: BattleUnit) -> bool: return u != t)
	if free.is_empty():
		return false
	if not t.effects.has("base_team"):
		t.effects.base_team = t.team
		t.team = 1 - t.team
	t.target = null
	if origin != null:
		origin.target = null
	return true


## Ends possessions that ran out, or when a team only has possessed units left.
func _update_possessed() -> void:
	for u in units:
		if not u.effects.has("base_team"):
			continue
		var home: int = u.effects.base_team
		if u.alive and u.has_status("possessed") and not alive_units(home).is_empty():
			continue
		u.team = home
		u.effects.erase("base_team")
		u.statuses.erase("possessed")
		u.target = null


## Heals `t` (Wound blocks it, Burn and Enraged halve it, ZENITH +20%). Returns the
## overheal; Grass Pokémon turn 40% of it into max HP.
## `source`: who heals (DPS meter), the healed unit itself by default.
func heal(t: BattleUnit, amount: float, source: BattleUnit = null) -> float:
	if not t.alive or amount <= 0.0 or t.has_status("protect"):
		return 0.0
	if t.effects.get("buff_heal_received", false): # Sitrus Berry
		amount *= 1.3
	if t.has_status("wound"):
		return 0.0
	if t.has_status("burn"):
		amount *= 0.5
	if t.has_status("enraged"):
		amount *= 0.5
	if weather == "ZENITH":
		amount *= 1.2
	amount = roundf(amount)
	var healed := minf(amount, t.max_hp - t.hp)
	t.hp += healed
	if healed > 0.0:
		var healer: BattleUnit = source if source != null else t
		emit({"type": "heal", "unit": t, "amount": roundf(healed), "source": healer,
			"ability": healer == ability_source and healer != _attack_source})
	var overheal := amount - healed
	if overheal > 0.0 and t.synergy_tier("GRASS") > 0:
		t.max_hp += 0.4 * overheal
	return overheal


func add_shield(t: BattleUnit, amount: float, source: BattleUnit = null) -> void:
	if not t.alive or amount <= 0.0:
		return
	if t.has_status("enraged"):
		amount *= 0.5
	amount = roundf(amount)
	t.shield += amount
	t.counters.shield_gained = float(t.counters.get("shield_gained", 0.0)) + amount # Explosive Band
	var giver: BattleUnit = source if source != null else t
	emit({"type": "shield", "unit": t, "amount": amount, "source": giver,
		"ability": giver == ability_source and giver != _attack_source})


## Inflicts a status: immunities, weather and Aquatic durations, Enraged halving
## hard crowd control, poison stacks (3, 4 Venomous, 5 Toxic), Safeguard cleansing.
func add_status(t: BattleUnit, status: String, duration: float, origin: BattleUnit = null) -> void:
	if not t.alive or duration <= 0.0:
		return
	if t.is_immune_to(status):
		return
	if status == "possessed" and not _possess(t, origin):
		add_status(t, "charm", duration, origin) # the last free unit of a team is charmed instead
		return
	if status == "protect" and t.has_status("enraged"):
		return
	match status: # status.ts trigger*: some cannot be stacked, hard crowd control has a cooldown
		"freeze", "sleep", "locked":
			if t.has_status(status) or t.has_status("skydiving") or float(t.counters.get("cc_cooldown", 0.0)) > 0.0:
				return
		"confusion", "charm", "blinded":
			if t.has_status(status):
				return
		"silence":
			if t.effects.get("tree", false):
				return
		"curse": # cursed again: it falls at once; cleansed, it keeps what was left of the timer
			if t.has_status("curse"):
				t.statuses.curse = 0.001
				return
			var left := float(t.counters.get("curse_left", 0.0))
			if left > 0.0:
				duration = minf(duration, left)
	duration *= Weather.status_factor(weather, status)
	if t.has_status("enraged") and status in ["freeze", "sleep", "locked", "blinded"]:
		duration *= 0.5
	if BattleUnit.REDUCIBLE_STATUSES.has(status):
		duration = roundf(duration * SynergyEffects.status_duration_factor(t))
	match status:
		"poison":
			var max_stacks := 3
			if origin != null:
				var poison_tier := origin.synergy_tier("POISON")
				max_stacks = 5 if poison_tier >= 3 else (4 if poison_tier == 2 else 3)
			t.poison_stacks = mini(t.poison_stacks + 1, max_stacks)
		"safeguard":
			t.cleanse()
	var fresh := not t.has_status(status)
	if origin != null and origin != t and (fresh or duration > t.statuses.get(status, 0.0)):
		t.status_origin[status] = origin
	t.add_status(status, duration)
	match status:
		"charm": # it goes for whoever charmed it
			if origin != null:
				t.target = origin
		"locked": # LOCKED: range 1 while it lasts
			t.attack_range = 1
			t.target = null
		"enraged": # Rage (triggerRage): +80 SPEED, no more Protect, SLEEP / FREEZE halved
			if fresh and not _enraged:
				t.add_stat("speed", RAGE_SPEED)
				t.statuses.erase("protect")
				for s in ["sleep", "freeze"]:
					if t.has_status(s):
						t.statuses[s] = floorf(t.statuses[s] * 0.5)
	PassiveEffects.on_status(self, t, status, fresh, origin)
	emit({"type": "status", "unit": t, "status": status, "duration": duration})
	var berry: String = STATUS_BERRIES.get(status, "")
	if berry != "" and t.has_item(berry):
		SynergyItems.eat_berry(self, t, berry)


## A status running out (status.ts update*).
func _status_ended(u: BattleUnit, status: String) -> void:
	match status:
		"freeze", "sleep", "locked":
			u.counters.cc_cooldown = maxf(float(u.counters.get("cc_cooldown", 0.0)), CC_COOLDOWN)
	match status:
		"locked": # back to its range (BASE range, Wide Lens, Long Wand)
			var r := u.base_range + (1 if u.has_item("WIDE_LENS") else 0)
			if u.types.has("FAIRY") and u.base_range > 1 and team_info[u.team].get("wands", []).has("LONG_WAND"):
				r += 1
			u.attack_range = r
		"enraged":
			if not _enraged:
				u.add_stat("speed", -RAGE_SPEED)
		"confusion", "charm":
			u.target = null


func _faint(t: BattleUnit, attacker: BattleUnit = null, kind := BattleUnit.DamageKind.SPECIAL) -> void:
	t.hp = 0.0
	t.alive = false
	board.clear(t.cell)
	fallen[t.team] += 1
	emit({"type": "death", "unit": t})
	if t.types.has("FLORA") and t.synergy_tier("FLORA") > 0 and not flower_pots.is_empty():
		SynergyItems.on_flora_death(self, t)
	ItemEffects.on_death(self, t, attacker)
	SynergyEffects.on_death(self, t)
	PassiveEffects.on_death(self, t)
	if attacker != null and attacker != t and attacker.alive:
		SynergyEffects.on_kill(self, attacker, t)
		PassiveEffects.on_kill(self, attacker, t, kind)
#endregion
