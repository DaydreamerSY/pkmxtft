class_name SeasonSynergies
extends RefCounted

## Synergy effects of a season (not in the web game; docs/SEASON_SYNERGIES.md): a season can give a
## synergy effects of its own, built from the blocks of EFFECTS, instead of (mode "replace") or on top of (mode "add")
## the web game's (SynergyEffects). data/season_synergies.json, edited with tools\synergy_editor.bat:
##   {"seasons": {"<season id>": {"<TYPE>": {"mode": "replace" | "add", "thresholds": [2, 4, 6] (optional),
##       "text": {"vi": "...", "en": "..."} (optional), "effects": [{"type": ..., "values": [one per tier], ...}]}}}}
## BattleSim.setup_teams splits the tiers (split): a replaced synergy leaves team_tiers (no web fight effect at all),
## every synergy with effects of its own goes to custom_tiers; BattleSim / AbilityRunner call the hooks below next to
## SynergyEffects' (on_spawn, on_attack, on_hit, on_cast, on_second, on_damage_dealt, on_damage_received, on_kill,
## damage_factor, ability_factor). The between-stage items of a synergy (rod, berries, wands...) stay as they are.
## GameData reads the thresholds (apply_progression) and the texts (synergy_description, synergy_tier_texts).

const PATH := "res://data/season_synergies.json"
const MODES: Array[String] = ["replace", "add"]
## type -> {vi: name in the editor, fields: what it reads besides values}
const EFFECTS := {
	"stat": {"vi": "Chỉ số", "fields": ["who", "stat", "percent"]},
	"attack_stack": {"vi": "Cộng dồn mỗi đòn đánh", "fields": ["who", "stack", "max"]},
	"cast_bonus": {"vi": "Mỗi lần dùng skill", "fields": ["who", "gain", "to", "percent"]},
	"hit_status": {"vi": "Gây trạng thái khi trúng", "fields": ["who", "status", "duration", "on"]},
	"hit_damage": {"vi": "Sát thương thêm khi trúng", "fields": ["who", "scale", "kind", "on"]},
	"ability_power": {"vi": "Hiệu lực kỹ năng (+%)", "fields": ["who"]},
	"damage_amp": {"vi": "Tăng sát thương gây ra (+%)", "fields": ["who", "on"]},
	"damage_reduction": {"vi": "Giảm sát thương nhận (%)", "fields": ["who"]},
	"pp_regen": {"vi": "Hồi PP mỗi giây", "fields": ["who"]},
	"regen": {"vi": "Hồi % HP mỗi giây", "fields": ["who"]},
	"lifesteal": {"vi": "Hút máu (%)", "fields": ["who", "on"]},
	"low_hp": {"vi": "Khi máu thấp (một lần)", "fields": ["who", "threshold", "gain"]},
	"kill_bonus": {"vi": "Khi hạ gục", "fields": ["who", "gain"]},
}
## The choices of each field (the first is the default).
const CHOICES := {
	"who": ["members", "team"],
	"stat": ["atk", "ap", "hp", "def", "speDef", "speed", "critChance", "critPower", "dodge", "luck", "shield", "pp", "range"],
	"stack": ["atk", "ap", "speed", "def", "speDef", "critChance"],
	"gain": ["shield", "heal", "pp", "atk", "ap", "speed", "def", "speDef"],
	"to": ["self", "team", "adjacent"],
	"on": ["attack", "ability", "both"],
	"scale": ["flat", "atk"],
	"kind": ["special", "physical", "true"],
	"status": ["burn", "poison", "freeze", "sleep", "silence", "wound", "flinch", "paralysis", "confusion", "charm",
		"armor_reduction", "blinded", "fatigue", "locked"],
}
const NUMBERS := {"duration": 2000.0, "max": 0.0, "threshold": 30.0} ## number fields and their default
const STAT_TOKENS := {"atk": "ATK", "ap": "AP", "hp": "HP", "def": "DEF", "speDef": "SPE_DEF", "speed": "SPEED",
	"critChance": "CRIT_CHANCE", "critPower": "CRIT_POWER", "luck": "LUCK", "shield": "SHIELD", "pp": "PP", "range": "RANGE"}
const KIND_TOKENS := {"special": "SPECIAL", "physical": "PHYSICAL", "true": "TRUE"}

static var _data: Dictionary = {}
static var _loaded := false


#region data
static func data() -> Dictionary:
	if not _loaded:
		load_data()
	return _data


## Reads the file again, or takes `new_data` (tests, the editor).
static func load_data(new_data: Variant = null) -> void:
	_loaded = true
	if new_data is Dictionary:
		_data = new_data
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	_data = parsed if parsed is Dictionary else {}


## Every synergy with effects of its own in the season: {TYPE: spec}.
static func season_specs(season: String = Seasons.current) -> Dictionary:
	var all = data().get("seasons", {})
	var own = all.get(season, {}) if all is Dictionary else {}
	return own if own is Dictionary else {}


## The effects of its own of a synergy in the season ({} = the web game's).
static func spec(type: String, season: String = Seasons.current) -> Dictionary:
	var s = season_specs(season).get(type, {})
	return s if s is Dictionary and MODES.has(String(s.get("mode", ""))) else {}


## "web", "replace" or "add".
static func mode(type: String, season: String = Seasons.current) -> String:
	var s := spec(type, season)
	return String(s.mode) if not s.is_empty() else "web"


static func effects_of(type: String, season: String = Seasons.current) -> Array:
	var list = spec(type, season).get("effects", [])
	return list if list is Array else []


## Thresholds of its own ([] = none): any number of them when it replaces the web effect, else as many as the web's.
static func thresholds_of(type: String, web: Array, season: String = Seasons.current) -> Array:
	var own = spec(type, season).get("thresholds", [])
	if not own is Array or own.is_empty():
		return []
	for v in own:
		if not (v is float or v is int) or float(v) < 1.0:
			return []
	if mode(type, season) != "replace" and own.size() != web.size():
		return []
	return own


## [web tiers, tiers of the synergies with effects of their own] of a team's {TYPE: tier}.
static func split(tiers: Dictionary, season: String = Seasons.current) -> Array:
	var web := {}
	var custom := {}
	for type in tiers:
		var m := mode(type, season)
		if m != "replace":
			web[type] = tiers[type]
		if m != "web" and not effects_of(type, season).is_empty():
			custom[type] = tiers[type]
	return [web, custom]
#endregion


#region fight
static func _v(e: Dictionary, tier: int) -> float:
	var values = e.get("values", [])
	if not values is Array or values.is_empty():
		return 0.0
	return float(values[clampi(tier - 1, 0, values.size() - 1)])


static func _field(e: Dictionary, key: String) -> String:
	return String(e.get(key, CHOICES[key][0]))


## A block of SeasonSynergies (EFFECTS) or a mechanic of SeasonMechanics (TYPES).
static func known(e: Variant) -> bool:
	if not e is Dictionary:
		return false
	var type := String(e.get("type", ""))
	return EFFECTS.has(type) or SeasonMechanics.TYPES.has(type)


static func on_spawn(sim: BattleSim, u: BattleUnit) -> void:
	if u.inanimate:
		return
	var custom: Dictionary = sim.custom_tiers[u.team]
	for type in custom:
		var tier: int = custom[type]
		for e in effects_of(type):
			if not known(e):
				continue
			if _field(e, "who") != "team" and not u.types.has(type):
				continue
			var entry := {"e": e, "t": tier, "type": type}
			u.season_effects.append(entry)
			if e.type == "stat":
				_stat(u, _field(e, "stat"), _v(e, tier), bool(e.get("percent", false)))
			elif SeasonMechanics.TYPES.has(String(e.type)):
				SeasonMechanics.on_spawn(sim, u, entry)


## Hooks of the season mechanics (SeasonMechanics) that only BattleSim calls.
static func on_fight_start(sim: BattleSim) -> void:
	SeasonMechanics.on_fight_start(sim)


static func update(sim: BattleSim, dt: float) -> void:
	SeasonMechanics.update(sim, dt)


static func adjust_taken(sim: BattleSim, t: BattleUnit, amount: float) -> float:
	return SeasonMechanics.adjust_taken(sim, t, amount)


static func on_lethal(sim: BattleSim, t: BattleUnit) -> bool:
	return SeasonMechanics.on_lethal(sim, t)


static func blocks_status(sim: BattleSim, t: BattleUnit, status: String) -> bool:
	return SeasonMechanics.blocks_status(sim, t, status)


static func pick_target(sim: BattleSim, u: BattleUnit) -> BattleUnit:
	return SeasonMechanics.pick_target(sim, u)


static func on_death(sim: BattleSim, dead: BattleUnit) -> void:
	SeasonMechanics.on_death(sim, dead)


static func on_dodge(sim: BattleSim, t: BattleUnit) -> void:
	SeasonMechanics.on_dodge(sim, t)


static func on_area(sim: BattleSim, event: Dictionary) -> void:
	SeasonMechanics.on_area(sim, event)


## A stat of `u` up by `v` (`percent`: % of its base stat; shield: % of its max HP).
static func _stat(u: BattleUnit, stat: String, v: float, percent := false) -> void:
	match stat:
		"hp": u.add_stat("maxHP", u.base_hp * v / 100.0 if percent else v)
		"atk": u.add_stat("atk", u.base_atk * v / 100.0 if percent else v)
		"def": u.add_stat("def", u.base_def * v / 100.0 if percent else v)
		"speDef": u.add_stat("speDef", u.base_spe_def * v / 100.0 if percent else v)
		"speed": u.add_stat("speed", u.speed * v / 100.0 if percent else v)
		"ap": u.add_stat("ap", v)
		"critChance": u.add_stat("critChance", v)
		"critPower": u.add_stat("critPower", v / 100.0)
		"dodge": u.add_stat("dodge", v / 100.0)
		"luck": u.add_stat("luck", v)
		"shield": u.shield += roundf(u.max_hp * v / 100.0 if percent else v)
		"pp": u.add_pp(v)
		"range": u.attack_range += int(v)


## `to` gets `gain` from `u` (shield / heal in HP, or % of the max HP if `percent`; pp; a stat).
static func _gain(sim: BattleSim, u: BattleUnit, to: BattleUnit, gain: String, v: float, percent: bool) -> void:
	if not to.alive:
		return
	match gain:
		"shield": sim.add_shield(to, to.max_hp * v / 100.0 if percent else v, u)
		"heal": sim.heal(to, to.max_hp * v / 100.0 if percent else v, u)
		"pp": to.add_pp(v)
		_:
			_stat(to, gain, v)
			sim.emit({"type": "buff", "unit": to, "stat": gain, "amount": v})


static func _receivers(sim: BattleSim, u: BattleUnit, to: String) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = [u]
	if to == "team":
		out = sim.allies_of(u)
	elif to == "adjacent":
		for c in BattleBoard.adjacent_cells(u.cell):
			var a := sim.board.get_unit(c)
			if a != null and a.alive and a.team == u.team:
				out.append(a)
	return out


## After each basic attack (BattleSim.attack_hit, drum beats).
static func on_attack(sim: BattleSim, u: BattleUnit) -> void:
	SeasonMechanics.on_attack(sim, u)
	for i in u.season_effects.size():
		var s: Dictionary = u.season_effects[i]
		if s.e.type != "attack_stack":
			continue
		var most := int(s.e.get("max", 0))
		var key := "season_stack_%d" % i
		var n := int(u.counters.get(key, 0))
		if most > 0 and n >= most:
			continue
		u.counters[key] = n + 1
		_stat(u, _field(s.e, "stack"), _v(s.e, s.t))


## `u` hit `t` with a basic attack (`kind` attack, BattleSim.attack_hit) or its ability (ability: on_damage_dealt).
static func on_hit(sim: BattleSim, u: BattleUnit, t: BattleUnit, kind: String) -> void:
	SeasonMechanics.on_hit(sim, u, t, kind)
	for s in u.season_effects:
		if not t.alive:
			return
		var on := _field(s.e, "on")
		if on != "both" and on != kind:
			continue
		if s.e.type == "hit_status":
			if sim.chance(_v(s.e, s.t) / 100.0, u):
				sim.add_status(t, _field(s.e, "status"), float(s.e.get("duration", NUMBERS.duration)), u)
		elif s.e.type == "hit_damage":
			var v := _v(s.e, s.t)
			var amount := u.atk * v / 100.0 if _field(s.e, "scale") == "atk" else v
			if amount >= 1.0:
				sim.deal_damage(t, roundf(amount), _kind(_field(s.e, "kind")), u, false, true)


static func _kind(kind: String) -> int:
	match kind:
		"physical": return BattleUnit.DamageKind.PHYSICAL
		"true": return BattleUnit.DamageKind.TRUE
	return BattleUnit.DamageKind.SPECIAL


## After its ability (AbilityRunner.cast).
static func on_cast(sim: BattleSim, u: BattleUnit) -> void:
	SeasonMechanics.on_cast(sim, u)
	for s in u.season_effects:
		if s.e.type == "cast_bonus":
			var v := _v(s.e, s.t)
			for to in _receivers(sim, u, _field(s.e, "to")):
				_gain(sim, u, to, _field(s.e, "gain"), v, bool(s.e.get("percent", false)))


static func on_second(sim: BattleSim, u: BattleUnit) -> void:
	SeasonMechanics.on_second(sim, u)
	for s in u.season_effects:
		if s.e.type == "pp_regen":
			u.add_pp(_v(s.e, s.t))
		elif s.e.type == "regen":
			sim.heal(u, u.max_hp * _v(s.e, s.t) / 100.0, u)


## Damage of `u` to `t` (in BattleSim's damage hooks: what follows is not scaled again): lifesteal, and the hits of its
## ability (hit_status / hit_damage "on": ability).
static func on_damage_dealt(sim: BattleSim, u: BattleUnit, t: BattleUnit, taken: float, retaliation: bool) -> void:
	if u.season_effects.is_empty():
		return
	SeasonMechanics.on_damage_dealt(sim, u, t, taken, retaliation)
	var kind := sim.source_kind(u)
	if kind == "":
		return
	for s in u.season_effects:
		if s.e.type == "lifesteal":
			var on := _field(s.e, "on")
			if on == "both" or on == kind:
				sim.heal(u, ceilf(taken * _v(s.e, s.t) / 100.0), u)
	if kind == "ability" and not retaliation:
		on_hit(sim, u, t, "ability")


## `t` took damage and is still up: the low HP effects (once a fight).
static func on_damage_received(sim: BattleSim, t: BattleUnit) -> void:
	SeasonMechanics.on_damage_received(sim, t)
	for i in t.season_effects.size():
		var s: Dictionary = t.season_effects[i]
		if s.e.type != "low_hp" or not t.alive:
			continue
		var key := "season_low_%d" % i
		if t.counters.has(key) or t.hp > t.max_hp * float(s.e.get("threshold", NUMBERS.threshold)) / 100.0:
			continue
		t.counters[key] = true
		_gain(sim, t, t, _field(s.e, "gain"), _v(s.e, s.t), true)
		sim.emit({"type": "effect", "unit": t, "text": GameData.synergy_name(String(s.type)) + "!",
			"color": GameData.TYPE_COLORS.get(String(s.type), Color.WHITE)})


static func on_kill(sim: BattleSim, attacker: BattleUnit, target: BattleUnit) -> void:
	SeasonMechanics.on_kill(sim, attacker, target)
	for s in attacker.season_effects:
		if s.e.type == "kill_bonus":
			_gain(sim, attacker, attacker, _field(s.e, "gain"), _v(s.e, s.t), true)


## x on a damage of `attacker` to `t` (BattleSim.deal_damage): its damage_amp, the damage_reduction of `t`.
static func damage_factor(sim: BattleSim, attacker: BattleUnit, t: BattleUnit) -> float:
	var factor := SeasonMechanics.damage_factor(sim, attacker, t)
	if attacker != null and not attacker.season_effects.is_empty():
		var kind := sim.source_kind(attacker)
		if kind != "":
			for s in attacker.season_effects:
				if s.e.type == "damage_amp" and (_field(s.e, "on") == "both" or _field(s.e, "on") == kind):
					factor *= 1.0 + _v(s.e, s.t) / 100.0
	var cut := 0.0
	for s in t.season_effects:
		if s.e.type == "damage_reduction":
			cut += _v(s.e, s.t) / 100.0
	return factor * (1.0 - clampf(cut, 0.0, 0.9))


## x on the damage, heal and shield of its ability (BattleSim.ability_scale).
static func ability_factor(u: BattleUnit) -> float:
	var factor := 1.0
	for s in u.season_effects:
		if s.e.type == "ability_power":
			factor += _v(s.e, s.t) / 100.0
	return maxf(factor, 0.0)
#endregion


#region texts
## {desc, tiers}: the text of a synergy with effects of its own in the season (its own `text` or made from its
## effects; GameText tokens), one tier text per threshold. `lang` "": the game's.
static func texts(type: String, season: String = Seasons.current, lang := "") -> Dictionary:
	var s := spec(type, season)
	if s.is_empty():
		return {"desc": "", "tiers": []}
	if lang == "":
		lang = GameData.language
	var vi := lang == "vi"
	var effects := effects_of(type, season)
	var own = s.get("text", {})
	var desc := ""
	if own is Dictionary:
		desc = String(own.get(lang, own.get("en", "")))
	if desc == "":
		desc = _sentence(type, effects, -1, vi)
	var tiers: Array[String] = []
	for t in range(1, _tier_count(type, season) + 1):
		tiers.append(_sentence(type, effects, t, vi))
	return {"desc": desc, "tiers": tiers}


## Number of tiers of the synergy in the season: its own thresholds, else the web's.
static func _tier_count(type: String, season: String) -> int:
	var web: Array = GameData.full_thresholds().get(type, [])
	var own := thresholds_of(type, web, season)
	return own.size() if not own.is_empty() else web.size()


## The effects as one text: tier -1 = every tier's value ([a,b,c]: GameText shows a/b/c), else that tier's.
static func _sentence(type: String, effects: Array, tier: int, vi: bool) -> String:
	var members: Array[String] = []
	var team: Array[String] = []
	for e in effects:
		if not known(e):
			continue
		if SeasonMechanics.TYPES.has(String(e.type)):
			(team if _field(e, "who") == "team" else members).append(SeasonMechanics.phrase(e, tier, vi))
			continue
		var value := ""
		if tier < 0:
			var parts: Array[String] = []
			for v in e.get("values", []):
				parts.append(_num(float(v)))
			value = ("[%s]" % ",".join(parts)) if parts.size() > 1 else (parts[0] if not parts.is_empty() else "0")
		else:
			value = _num(_v(e, tier))
		if _field(e, "who") == "team":
			team.append(phrase(e, value, vi))
		else:
			members.append(phrase(e, value, vi))
	var out: Array[String] = []
	if not members.is_empty():
		if tier < 0:
			out.append(("Pokémon hệ %s: %s" if vi else "%s Pokémon: %s") % [type, "; ".join(members)])
		else:
			out.append("; ".join(members))
	if not team.is_empty():
		out.append(("Cả đội: %s" if vi else "Whole team: %s") % "; ".join(team))
	if tier < 0:
		return ". ".join(out) + ("." if not out.is_empty() else "")
	return " · ".join(out)


static func _num(v: float) -> String:
	return str(int(roundf(v))) if is_equal_approx(v, roundf(v)) else String.num(v, 2)


## What `on` of an effect reads as: [vi, en "of its ...", en "on ... hits"].
static func _on_words(on: String) -> Array:
	match on:
		"ability": return ["skill", "its abilities", "ability"]
		"both": return ["đòn đánh hoặc skill", "its attacks and abilities", "attack or ability"]
	return ["đòn đánh", "its basic attacks", "basic attack"]


## One effect in words; `v`: its value(s) as text.
static func phrase(e: Dictionary, v: String, vi: bool) -> String:
	var on := _on_words(_field(e, "on"))
	match String(e.type):
		"stat":
			var stat := _field(e, "stat")
			var pct: bool = e.get("percent", false)
			match stat:
				"shield":
					if pct:
						return ("khiên %s%% HP đầu trận" if vi else "SHIELD of %s%% HP at the start") % v
					return ("+%s SHIELD đầu trận" if vi else "+%s SHIELD at the start") % v
				"pp":
					return ("+%s PP đầu trận" if vi else "+%s PP at the start") % v
				"dodge":
					return ("+%s%% né đòn" if vi else "+%s%% dodge") % v
				"critChance", "critPower":
					return "+%s%% %s" % [v, STAT_TOKENS[stat]]
				"range":
					return "+%s RANGE" % v
			return ("+%s%% %s" if pct else "+%s %s") % [v, STAT_TOKENS.get(stat, stat)]
		"attack_stack":
			var most := int(e.get("max", 0))
			var stack := _field(e, "stack")
			var text := ("+%s %s sau mỗi đòn đánh" if vi else "+%s %s after every attack") % [v, STAT_TOKENS.get(stack, stack)]
			if most > 0:
				text += (" (tối đa %d lần)" if vi else " (up to %d times)") % most
			return text
		"cast_bonus":
			var to := ""
			match _field(e, "to"):
				"team": to = " cho cả đội" if vi else " to the whole team"
				"adjacent": to = " cho nó và đồng đội ADJACENT" if vi else " to itself and its ADJACENT allies"
			return ("mỗi lần dùng skill: %s%s" if vi else "after each ability: %s%s") % [_gain_text(e, v, vi), to]
		"hit_status":
			var status: String = GameData.STATUS_KEYS.get(_field(e, "status"), _field(e, "status"))
			var seconds := _num(float(e.get("duration", NUMBERS.duration)) / 1000.0)
			if vi:
				return "%s%% gây %s %s giây khi %s trúng" % [v, status, seconds, on[0]]
			return "%s%% chance of %s for %s s on %s hits" % [v, status, seconds, on[2]]
		"hit_damage":
			var amount := ("%s%% ATK" % v) if _field(e, "scale") == "atk" else v
			var kind: String = KIND_TOKENS[_field(e, "kind")]
			if vi:
				return "gây thêm %s %s khi %s trúng" % [amount, kind, on[0]]
			return "%s more %s on %s hits" % [amount, kind, on[2]]
		"ability_power":
			return ("+%s%% hiệu lực kỹ năng (sát thương, hồi, khiên)" if vi else "+%s%% ability strength (damage, heal, shield)") % v
		"damage_amp":
			return ("+%s%% sát thương của %s" % [v, on[0]]) if vi else ("+%s%% damage of %s" % [v, on[1]])
		"damage_reduction":
			return ("nhận ít hơn %s%% sát thương" if vi else "takes %s%% less damage") % v
		"pp_regen":
			return ("+%s PP mỗi giây" if vi else "+%s PP every second") % v
		"regen":
			return ("hồi %s%% HP tối đa mỗi giây" if vi else "heals %s%% of its max HP every second") % v
		"lifesteal":
			return ("hồi máu bằng %s%% sát thương của %s" % [v, on[0]]) if vi else ("heals %s%% of the damage of %s" % [v, on[1]])
		"low_hp":
			var below := _num(float(e.get("threshold", NUMBERS.threshold)))
			return ("lần đầu còn dưới %s%% HP: %s" if vi else "the first time under %s%% HP: %s") % [below, _gain_text(e, v, vi, true)]
		"kill_bonus":
			return ("mỗi lần hạ gục: %s" if vi else "after each KO: %s") % _gain_text(e, v, vi, true)
	return String(e.type)


## A gain in words (shield / heal: HP, or % of the max HP if `percent` / `percent_of_hp`; pp; a stat).
static func _gain_text(e: Dictionary, v: String, vi: bool, percent_of_hp := false) -> String:
	var gain := _field(e, "gain")
	var pct: bool = percent_of_hp or e.get("percent", false)
	match gain:
		"shield":
			if pct:
				return ("khiên %s%% HP" if vi else "SHIELD of %s%% HP") % v
			return "+%s SHIELD" % v
		"heal":
			if pct:
				return ("hồi %s%% HP" if vi else "heals %s%% HP") % v
			return ("hồi %s HP" if vi else "heals %s HP") % v
		"pp":
			return "+%s PP" % v
	return "+%s %s" % [v, STAT_TOKENS.get(gain, gain)]
#endregion


#region checks (sim_test, the editor)
## What is wrong in the file (unknown season / synergy / effect / choice, values that are not numbers...).
static func problems() -> Array[String]:
	var out: Array[String] = []
	var all = data().get("seasons", {})
	if not all is Dictionary:
		return ["seasons is not an object"]
	var types: Dictionary = GameData.full_thresholds()
	for season in all:
		if season != Seasons.FULL and Seasons.season(season).is_empty():
			out.append("unknown season %s" % season)
		var specs = all[season]
		if not specs is Dictionary:
			out.append("%s: not an object" % season)
			continue
		for type in specs:
			var s = specs[type]
			var where := "%s %s" % [season, type]
			if not types.has(type):
				out.append("%s: unknown synergy" % where)
			if not s is Dictionary or not MODES.has(String(s.get("mode", ""))):
				out.append("%s: mode must be replace or add" % where)
				continue
			var own = s.get("thresholds", [])
			if own is Array and not own.is_empty() and thresholds_of(type, types.get(type, []), season).is_empty():
				out.append("%s: thresholds %s (add: as many as the web's %s)" % [where, own, types.get(type, [])])
			for e in s.get("effects", []):
				out.append_array(effect_problems(e, where))
	return out


static func effect_problems(e: Variant, where: String) -> Array[String]:
	var out: Array[String] = []
	if not known(e):
		return ["%s: unknown effect %s" % [where, e]]
	if SeasonMechanics.TYPES.has(String(e.type)):
		for key in ["values"] + Array(SeasonMechanics.TYPES[e.type].params):
			var v = e.get(key, null)
			if v == null or not (v is float or v is int or (v is Array and not v.is_empty())):
				out.append("%s %s: %s missing" % [where, e.type, key])
		return out
	var values = e.get("values", [])
	if not values is Array or values.is_empty():
		out.append("%s %s: no values" % [where, e.type])
	else:
		for v in values:
			if not (v is float or v is int):
				out.append("%s %s: value %s is not a number" % [where, e.type, v])
	for key in EFFECTS[e.type].fields:
		if CHOICES.has(key) and e.has(key) and not CHOICES[key].has(String(e[key])):
			out.append("%s %s: %s %s not in %s" % [where, e.type, key, e[key], CHOICES[key]])
	return out
#endregion
