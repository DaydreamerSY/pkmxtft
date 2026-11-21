class_name BattleUnit
extends RefCounted

## A Pokémon during a fight (port of PokemonEntity / PokemonState).
## Pure data + rules, no nodes: the view reads it and the simulation events.

enum Team { BLUE, RED }
enum DamageKind { PHYSICAL, SPECIAL, TRUE }

const ARMOR_FACTOR := 0.05
const NEGATIVE_STATUSES: Array[String] = [
	"paralysis", "burn", "freeze", "sleep", "silence", "flinch",
	"armor_reduction", "confusion", "charm", "locked", "fatigue", "poison",
	"wound", "blinded", "curse",
]
## Statuses whose duration Aquatic (and the weather) shortens (applyStatusDurationReductions).
const REDUCIBLE_STATUSES: Array[String] = [
	"paralysis", "burn", "freeze", "sleep", "silence", "flinch",
	"armor_reduction", "confusion", "charm", "locked", "fatigue", "poison",
	"wound", "blinded",
]
## Terrain statuses: +20% damage dealt (Electric / Psychic / Grassy / Misty terrain).
const FIELDS: Array[String] = ["electric_field", "psychic_field", "grass_field", "fairy_field"]
const MAX_ITEMS := 3
const MAX_DODGE := 0.9

static var _next_id := 1

var id: int
var pkm: String
var data: Dictionary
var ability_id: String
var passive := "NONE"
var team: int = Team.BLUE
var stars := 1
var types: Array = []
var inanimate := false ## pillars: never move nor attack, immune to statuses
var is_spawn := false ## added during the fight (clones, Mitosis copies...)
var owned_id := -1 ## PlayerState.OwnedUnit id for the player's units
## The PlayerState.OwnedUnit itself (player's units): what changes it for good
## during a fight (a berry eaten, a dish stat) is written there too. Untyped: no cycle.
var owned = null

var cell := Vector2i.ZERO
var facing := Vector2i(0, 1)
var alive := true

var max_hp := 10.0
var hp := 10.0
var shield := 0.0
var atk := 1.0
var def := 1.0
var spe_def := 1.0
var speed := 50.0
var ap := 0.0
var crit_chance := 10.0
var crit_power := 2.0
var attack_range := 1
var pp := 0.0
var max_pp := 100.0 ## PP to cast: the form's own maxPP (data/balance.json "pp", tens), not by role
var pp_gained := 0.0 ## PP gained this fight (what add_pp really added; bot TSV "ppgain")
## UnitRoles role of the form it entered the fight with (kept when it changes form): its PP rules
## (Difficulty.role_mana, BattleSim.mana_of).
var role := "fighter"
var luck := 0.0 ## makes chance effects likelier: p -> p^(1 - luck/100)
var dodge := 0.0 ## chance to dodge basic attacks (max 90%)
## BASE stats: the Pokémon data (Flame Orb, Fossil, Light, Wild... use them).
var base_atk := 1.0
var base_def := 1.0
var base_spe_def := 1.0
var base_hp := 10.0
var base_range := 1

## Held items (ids of data/pac/items.json). Some are used up during the fight
## (Shiny Charm, Max Revive, Smoke Ball); the owned unit keeps its items.
var items: Array[String] = []
## Flags set by items and effects: ability_crit, resurrection, immune_<status>,
## special_attacks (attacks deal SPECIAL scaled by AP)...
var effects: Dictionary = {}
## Synergy effects of this unit: type -> tier (only the synergies it benefits from).
var synergy: Dictionary = {}
## Item, synergy and passive stacks and timers (upgrade, muscle_band, attacks, fighting_blocks...).
var counters: Dictionary = {}
## Synergy effects of the season it gets (SeasonSynergies.on_spawn): [{e: effect, t: tier, type}].
var season_effects: Array = []

var target: BattleUnit = null
var cooldown := 0.0 ## ms before the next action (step, attack or cast)
var statuses: Dictionary = {} ## status name -> remaining ms
var poison_stacks := 0
## Who inflicted a status (burn / poison damage credit, Synchro): status -> BattleUnit.
var status_origin: Dictionary = {}
## Ghost curses sticking to the unit (re-applied when cleansed): vulnerability, weakness, torment, fate.
var curses: Dictionary = {}
var cast_count := 0
var _second_timer := 1000.0
var _burn_timer := 1000.0
var _poison_timer := 1000.0


static func create(pkm_name: String, unit_team: int) -> BattleUnit:
	var u := BattleUnit.new()
	u.id = _next_id
	_next_id += 1
	u.team = unit_team
	u._load(pkm_name)
	u.hp = u.max_hp
	u.facing = Vector2i(0, 1) if unit_team == Team.BLUE else Vector2i(0, -1) # BattleBoard.DIRECTIONS 1 / 4
	return u


## Stats of the Pokémon data.
func _load(pkm_name: String) -> void:
	pkm = pkm_name
	data = GameData.get_pokemon(pkm_name)
	stars = int(data.get("stars", 1))
	types = data.get("types", []).duplicate()
	ability_id = data.get("skill", "")
	passive = String(data.get("passive", "NONE"))
	inanimate = passive == "INANIMATE"
	max_hp = float(data.get("hp", 10))
	atk = float(data.get("atk", 1))
	def = float(data.get("def", 1))
	spe_def = float(data.get("speDef", 1))
	speed = float(data.get("speed", 50))
	attack_range = int(data.get("range", 1))
	ap = 0.0 # every Pokémon starts at 0 (web); the auto balance scales its ability instead (skill_scale)
	role = UnitRoles.role_of(pkm_name)
	max_pp = Difficulty.max_pp_of(float(data.get("maxPP", 100))) # its own (balanced), not by role
	base_atk = atk
	base_def = def
	base_spe_def = spe_def
	base_hp = max_hp
	base_range = attack_range


## Strength of its own ability given by the auto balance (data/balance.json "skill" -> GameData "skillScale", never a
## negative stat): x the damage, heal and shield it deals (BattleSim.ability_scale); 1 while it has another ability than
## its own (TM, Skill Swap, Mimic...).
func skill_scale() -> float:
	if ability_id != String(data.get("skill", "")):
		return 1.0
	return float(data.get("skillScale", 1.0))


## Changes form during the fight (Aegislash Blade, Darmanitan Zen...): new name,
## sprite, ability and passive; the stats are changed by the caller.
func transform(pkm_name: String) -> void:
	pkm = pkm_name
	data = GameData.get_pokemon(pkm_name)
	ability_id = data.get("skill", ability_id)
	passive = String(data.get("passive", passive))


## Gives the held items and their stats (ItemStats of the web game). A Wonder Box
## turns into 2 random full items for this fight when `rng` is given.
func equip(held: Array, rng: RandomNumberGenerator = null) -> void:
	if inanimate:
		return
	var list: Array[String] = []
	for item in held:
		if GameData.items.has(item) and list.size() < MAX_ITEMS:
			list.append(item)
	if rng != null and list.has("WONDER_BOX"):
		list.erase("WONDER_BOX")
		var picked: Array[String] = []
		for _i in 2:
			var eligible := GameData.full_items.filter(func(i: String) -> bool:
				return i != "WONDER_BOX" and not picked.has(i) and not list.has(i) \
					and not GameData.item_in(i, "SynergyStones") and not GameData.item_in(i, "Scarves"))
			picked.append(eligible[rng.randi() % eligible.size()])
		for item in picked:
			if list.size() < MAX_ITEMS:
				list.append(item)
	for item in list:
		items.append(item)
		var stats: Dictionary = GameData.item_stats(item)
		for stat in stats:
			_add_item_stat(stat, float(stats[stat]))
		var given := GameData.item_synergy(item)
		if given != "" and not types.has(given):
			if given == "DRAGON":
				types.push_front(given)
			else:
				types.append(given)
	# golden egg items (ShinyItems, items.ts OnItemGainedEffect)
	if has_item("DYNAMAX_BAND"):
		max_hp += 2.0 * base_hp
		hp = max_hp
	if has_item("STAR_PIECE"):
		stars = mini(stars + 1, 5)
	if has_item("SACRED_ASH"):
		effects.resurrection = true
	if has_item("REAPER_CLOTH"):
		effects.ability_crit = true
		if _ability_can_crit():
			crit_power += 0.5
	if has_item("MAX_REVIVE"):
		effects.resurrection = true
	if has_item("XRAY_VISION"):
		effects.immune_sleep = true
	if has_item("FLAME_ORB"):
		effects.immune_freeze = true
		atk += base_atk
	if has_item("HEAVY_DUTY_BOOTS"):
		effects.immune_locked = true
	if has_item("RUSTED_SWORD"): # +50% of its BASE ATK
		atk += 0.5 * base_atk


func _add_item_stat(stat: String, v: float) -> void:
	match stat:
		"HP":
			max_hp += v
			hp = max_hp
		"ATK": atk += v
		"DEF": def += v
		"SPE_DEF": spe_def += v
		"SPEED":
			if passive == "MELMETAL": # SPEED buffs give half as much ATK instead
				atk = maxf(atk + 0.5 * v, 1.0)
			else:
				speed = clampf(speed + v, 0.0, 300.0)
		"AP": ap += v
		"PP": pp += v
		"CRIT_CHANCE": crit_chance += v
		"CRIT_POWER": crit_power += v / 100.0
		"SHIELD": shield += v
		"RANGE": attack_range += int(v)
		"LUCK": luck += v


## Abilities that can already crit (crit_bonus / always_crit): Reaper Cloth gives crit power instead.
func _ability_can_crit() -> bool:
	for step in ability().get("steps", []):
		for eff in step.get("effects", []):
			if eff.has("crit_bonus") or eff.get("always_crit", false):
				return true
	return false


func has_item(item: String) -> bool:
	return items.has(item)


## Removes an item used up during the fight (Shiny Charm, Max Revive, Smoke Ball).
func use_up(item: String) -> void:
	items.erase(item)


## Multipliers of the base stats (difficulty / wave template: {"HP": 1.2, "ATK": 1.1...}),
## applied before the flat boosts and the items.
func apply_stat_scale(scale: Dictionary) -> void:
	for stat in scale:
		var f := float(scale[stat])
		match stat:
			"HP":
				max_hp = maxf(roundf(max_hp * f), 1.0)
				base_hp = max_hp
				hp = max_hp
			"ATK":
				atk = roundf(atk * f)
				base_atk = atk
			"DEF":
				def = roundf(def * f)
				base_def = def
			"SPE_DEF":
				spe_def = roundf(spe_def * f)
				base_spe_def = spe_def
			"SPEED": speed = clampf(roundf(speed * f), 0.0, 300.0)


## Flat stat boosts of PvE stages / endless scaling ({"HP": 50, "DEF": 5...}).
func apply_stat_boosts(boosts: Dictionary) -> void:
	for stat in boosts:
		var v := float(boosts[stat])
		match stat:
			"HP":
				max_hp += v
				hp = max_hp
			"ATK": atk += v
			"DEF": def += v
			"SPE_DEF": spe_def += v
			"AP": ap += v
			"SPEED": speed += v
			"PP": pp += v
			"CRIT_CHANCE": crit_chance += v


func ability() -> Dictionary:
	return GameData.get_ability(ability_id)


## Tier of a synergy effect this unit benefits from (0 = none).
func synergy_tier(type: String) -> int:
	return int(synergy.get(type, 0))


#region statuses
func has_status(status: String) -> bool:
	return statuses.get(status, 0.0) > 0.0


func add_status(status: String, duration_ms: float) -> void:
	statuses[status] = maxf(statuses.get(status, 0.0), duration_ms)


## Statuses this unit ignores (Rune Protect, item immunities, inanimate objects). Protect only
## blocks damage (status.ts trigger* check runeProtect).
func is_immune_to(status: String) -> bool:
	if NEGATIVE_STATUSES.has(status) and (inanimate or has_status("safeguard")):
		return true
	return effects.get("immune_" + status, false)


func has_negative_status() -> bool:
	for s in NEGATIVE_STATUSES:
		if has_status(s):
			return true
	return false


## Clears the negative statuses (clearNegativeStatus). A curse lifted keeps its timer + 2 s: cursed
## again, it falls when that runs out (Curse of Fate comes back by itself).
func cleanse() -> void:
	for s in NEGATIVE_STATUSES:
		if s == "curse":
			if has_status("curse"):
				counters.curse_left = statuses.curse + 2000.0
		if has_status(s) and s in ["locked", "freeze", "sleep", "confusion", "charm"]:
			statuses[s] = 0.001 # ends at the next step, with what follows (range back, crowd control cooldown)
		else:
			statuses.erase(s)
	poison_stacks = 0


func can_act() -> bool:
	return alive and not inanimate and not has_status("freeze") and not has_status("resurrecting") \
		and not (has_status("sleep") and passive != "COMATOSE") and not has_status("stasis")


## Out of reach of attacks and targeting (Sky Attack dive, Galarian Darmanitan turning Zen).
func is_untargetable() -> bool:
	return has_status("skydiving") or has_status("untargetable") or has_status("resurrecting") \
		or has_status("stasis") # stasis: season skills (Bubble Shelter, Sky Drop): out of the fight a moment


func can_move() -> bool:
	return can_act() and not has_status("locked")


## canBeMoved: forced displacements (knockbacks, pulls, swaps) leave it in place.
func can_be_moved() -> bool:
	return not has_status("skydiving") and not has_status("locked") and not has_item("HEAVY_DUTY_BOOTS") \
		and not has_status("fortified") # Steel of a season (SeasonMechanics opening_fortify)


## canCast: not while SILENCE, with a Nullify Bandanna or a Teleport attack waiting.
func can_cast() -> bool:
	if items.has("NULLIFY_BANDANNA") or effects.get("teleport_next_attack", false):
		return false
	return can_act() and not has_status("silence")


## Terrain fields held: each one adds 20% to the damage dealt.
func field_count() -> int:
	var n := 0
	for f in FIELDS:
		if has_status(f):
			n += 1
	return n
#endregion


#region derived stats
func effective_speed() -> float:
	return speed * (0.5 if has_status("paralysis") else 1.0)


## Time between two attacks: 1000 / (0.4 + 0.007 * speed) ms.
func attack_cooldown() -> float:
	return roundf(1000.0 / (0.4 + 0.007 * maxf(effective_speed(), 0.0)))


## Time to walk one cell: 500 / (0.5 + speed / 100) ms.
func move_cooldown() -> float:
	return roundf(500.0 / (0.5 + minf(maxf(effective_speed(), 0.0), 300.0) / 100.0))


func effective_def() -> float:
	return roundf(def * 0.5) if has_status("armor_reduction") else def


func effective_spe_def() -> float:
	return roundf(spe_def * 0.5) if has_status("armor_reduction") else spe_def


func stat(stat_name: String) -> float:
	match stat_name:
		"atk": return atk
		"def": return def
		"speDef": return spe_def
		"speed": return speed
		"maxHP": return max_hp
		"hp": return hp
		"ap": return ap
	return 0.0


func add_stat(stat_name: String, value: float) -> void:
	match stat_name:
		"atk": atk = maxf(atk + value, 1.0)
		"def": def = maxf(def + value, 0.0)
		"speDef": spe_def = maxf(spe_def + value, 0.0)
		"speed":
			if passive == "MELMETAL": # Melmetal: SPEED buffs give half as much ATK instead
				atk = maxf(atk + 0.5 * value, 1.0)
			else:
				speed = clampf(speed + value, 0.0, 300.0)
		"ap":
			if items.has("NULLIFY_BANDANNA"): # AP is gained as ATK instead
				atk = maxf(atk + roundf(0.2 * value), 1.0)
			else:
				ap += value
		"critChance": crit_chance = clampf(crit_chance + value, 0.0, 100.0)
		"critPower": crit_power = maxf(crit_power + value, 1.0)
		"luck": luck += value
		"dodge": dodge = clampf(dodge + value, 0.0, MAX_DODGE)
		"maxHP":
			max_hp = maxf(max_hp + value, 1.0)
			hp = clampf(hp + value, 1.0 if alive else 0.0, max_hp)
		"pp": add_pp(value)


## PP to this unit. `value` is of the web's scale (a bar of 100 PP: items, synergies, passives, abilities, the
## weather and the PP stat give and take PP for that bar) unless `raw`: the rules of the fight (Difficulty.mana:
## perAttack, perHit, perSecond, perDamage) and amounts already in max_pp. Not in the web game: every form has its own
## maxPP (data/balance.json), so an effect keeps the share of the bar the web gives it (web_pp).
func add_pp(value: float, raw := false) -> void:
	if not raw:
		value = web_pp(value)
	if value > 0.0 and effects.get("no_pp_gain", false): # Bide
		return
	if value > 0.0 and has_status("fatigue"):
		value *= 0.5
	var before := pp
	pp = clampf(pp + value, 0.0, 2.0 * max_pp - 1.0)
	if pp > before:
		pp_gained += pp - before


## PP of the web's scale (a 100-PP bar) in this unit's own bar.
func web_pp(value: float) -> float:
	return value * max_pp / 100.0


## Takes up to `value` PP of the web's scale (a drain, a theft); returns what it lost, in the web's scale.
func drain_pp(value: float) -> float:
	var lost := minf(pp, web_pp(maxf(value, 0.0)))
	pp -= lost
	return lost * 100.0 / max_pp if max_pp > 0.0 else 0.0


func hp_ratio() -> float:
	return hp / max_hp if max_hp > 0.0 else 0.0


## getUnitScore: strongest = most items, then stars, then sell price.
func unit_score() -> float:
	return 100.0 * items.size() + 10.0 * stars + GameData.rarity_cost(String(data.get("rarity", "COMMON"))) * stars
#endregion


## Advances statuses and the 1 s timers. The simulation applies what happens:
## {second: 1 s passed (passive PP...), burn / poison: a damage tick, curse: Curse of Fate expired}.
func tick(dt: float) -> Dictionary:
	var out := {"second": false, "burn": false, "poison": false, "curse": false, "expired": []}
	var burning := has_status("burn")
	for s in statuses.keys():
		statuses[s] -= dt * (2.0 if s == "freeze" and burning else 1.0) # burn makes freeze wear off faster
		if statuses[s] <= 0.0:
			statuses.erase(s)
			out.expired.append(s)
			if s == "curse":
				out.curse = true
			elif s == "poison":
				poison_stacks = 0
	if counters.has("cc_cooldown"):
		counters.cc_cooldown = float(counters.cc_cooldown) - dt
		if counters.cc_cooldown <= 0.0:
			counters.erase("cc_cooldown")
	_second_timer -= dt
	if _second_timer <= 0.0:
		_second_timer += 1000.0
		out.second = true
	if has_status("burn"):
		_burn_timer -= dt
		if _burn_timer <= 0.0:
			_burn_timer += 1000.0
			out.burn = true
	else:
		_burn_timer = 1000.0
	if poison_stacks > 0 and has_status("poison"):
		_poison_timer -= dt
		if _poison_timer <= 0.0:
			_poison_timer += 1000.0
			out.poison = true
	else:
		_poison_timer = 1000.0
	return out
