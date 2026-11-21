class_name SeasonMechanics
extends RefCounted

## Synergy mechanics of the seasons (not in the web game; docs/DESIGN_S1.md): effect blocks with a rule of their own,
## next to the simple blocks of SeasonSynergies. In data/season_synergies.json:
##   {"type": <mechanic>, "values": [one per tier], <param>: [one per tier] or a number, "say": {"vi": ..., "en": ...}}
## "say" is the text of one tier: {v} = values, {<param>} = that param (GameText tokens allowed).
## SeasonSynergies forwards its hooks here (BattleSim / AbilityRunner call them); a unit holds its blocks in
## u.season_effects ({e, t, type}); what the whole fight shares sits in sim's meta "season_mech" (_state).

## mechanic -> {vi: name in the editor, params: numbers per tier besides values}
const TYPES := {
	"cheat_death": {"vi": "Sống sót đòn chí tử (1 lần)", "params": ["s"]},
	"seed_drain": {"vi": "Gieo hạt hút máu", "params": []},
	"scorch_cells_on_cast": {"vi": "Skill đốt ô", "params": ["s"]},
	"cast_chain_pp": {"vi": "Skill chuyền PP", "params": []},
	"charge_release_chain": {"vi": "Tích điện phóng sét", "params": ["n"]},
	"same_target_ramp": {"vi": "Đánh liên tục một mục tiêu", "params": []},
	"ability_echo": {"vi": "Skill đánh lại sau 2 giây", "params": []},
	"stat_steal_on_hit": {"vi": "Cướp ATK / AP khi trúng", "params": ["ap"]},
	"opening_fortify": {"vi": "Pháo đài đầu trận", "params": ["s"]},
	"periodic_quake": {"vi": "Dậm đất định kỳ", "params": []},
	"poison_contagion": {"vi": "Độc lây khi gục", "params": []},
	"cast_stacks_type_team": {"vi": "Skill cộng dồn cho cả hệ", "params": ["ap"]},
	"focus_fire_bonus": {"vi": "Cùng nhắm một mục tiêu", "params": []},
	"half_hp_rampage": {"vi": "Cuồng nộ dưới 50% HP", "params": ["s", "speed"]},
	"row_strategy": {"vi": "Bày trận theo hàng", "params": ["atk", "ap"]},
	"dodge_reward": {"vi": "Né đòn được thưởng", "params": []},
	"adjacency_swarm": {"vi": "Thưởng mỗi đồng loại kề bên", "params": ["def"]},
	"tailwind_team_haste": {"vi": "Gió xuôi cho cả đội", "params": []},
	"cast_heals_lowest_allies": {"vi": "Skill hồi đồng minh yếu nhất", "params": ["n"]},
	"damage_cap_per_hit": {"vi": "Giới hạn sát thương mỗi đòn", "params": []},
	"afterlife_spirit": {"vi": "Hồn ở lại sau khi gục", "params": ["s"]},
	"aura_status_immunity": {"vi": "Hào quang chặn hiệu ứng xấu", "params": ["s"]},
	"chill_stacks_freeze": {"vi": "Tầng lạnh rồi đóng băng", "params": []},
	"shell_burst": {"vi": "Vỏ đá vỡ thì nổ", "params": ["dmg"]},
	"nth_attack_wave": {"vi": "Đòn thứ 3 phát sóng", "params": []},
	"cast_cost_down": {"vi": "Mỗi skill giảm PP lần sau", "params": []},
	"growth_over_time": {"vi": "Lớn dần trong trận", "params": []},
	"periodic_blind_flash": {"vi": "Lóe sáng làm chói", "params": ["ap"]},
	"hunt_lowest_hp": {"vi": "Săn kẻ ít HP nhất", "params": []},
	"damage_stagger": {"vi": "Dồn sát thương trừ dần", "params": []},
	"feast_on_enemy_death": {"vi": "Ăn khi kẻ địch gục", "params": ["hp"]},
}
const HARD_CC: Array[String] = ["freeze", "sleep", "locked", "paralysis", "flinch", "charm", "confusion", "possessed"]
const SEED_MS := 5000.0
const ECHO_MS := 2000.0
const CHARGES := 8
const RAMP_MAX := 5
const STEAL_MAX := 10
const DRAGON_MAX := 8
const SCORCH_HIT := "burn"


#region values
## The value `key` ("values" or a param) of an effect at a tier.
static func n(e: Dictionary, tier: int, key := "values") -> float:
	var v = e.get(key, e.get("values", 0.0) if key == "values" else 0.0)
	if v is Array:
		if v.is_empty():
			return 0.0
		return float(v[clampi(tier - 1, 0, v.size() - 1)])
	return float(v)


static func _state(sim: BattleSim) -> Dictionary:
	if not sim.has_meta("season_mech"):
		sim.set_meta("season_mech", {"scorch": {}, "tailwind": {}, "clock": 0.0})
	return sim.get_meta("season_mech")


## The first block of `mechanic` that `u` holds ({} if none).
static func held(u: BattleUnit, mechanic: String) -> Dictionary:
	if u == null:
		return {}
	for s in u.season_effects:
		if String(s.e.get("type", "")) == mechanic:
			return s
	return {}


## Allies of `u`'s team holding `mechanic`.
static func holders(sim: BattleSim, team: int, mechanic: String) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for a in sim.alive_units(team):
		if not held(a, mechanic).is_empty():
			out.append(a)
	return out


static func _flash(sim: BattleSim, u: BattleUnit, type: String) -> void:
	sim.emit({"type": "effect", "unit": u, "text": GameData.synergy_name(type) + "!",
		"color": GameData.TYPE_COLORS.get(type, Color.WHITE)})


static func _other(team: int) -> int:
	return BattleUnit.Team.RED if team == BattleUnit.Team.BLUE else BattleUnit.Team.BLUE


## Rows nearest the enemy: the two front rows of its side.
static func in_front_rows(u: BattleUnit) -> bool:
	return u.cell.y >= 2 if u.team == BattleUnit.Team.BLUE else u.cell.y <= 5


## The ally standing in the next row toward its own back (dir -1) or toward the enemy (dir 1), adjacent to `u`.
static func ally_in_row(sim: BattleSim, u: BattleUnit, toward_enemy: bool) -> BattleUnit:
	var dy := 1 if (u.team == BattleUnit.Team.BLUE) == toward_enemy else -1
	for c in BattleBoard.adjacent_cells(u.cell):
		if c.y == u.cell.y + dy:
			var a := sim.board.get_unit(c)
			if a != null and a.alive and a.team == u.team and not a.inanimate:
				return a
	return null
#endregion


#region texts
## One tier of the effect in words (tier -1: every tier, "a/b/c").
static func phrase(e: Dictionary, tier: int, vi: bool) -> String:
	var say = e.get("say", {})
	var text := ""
	if say is Dictionary:
		text = String(say.get("vi" if vi else "en", say.get("en", "")))
	if text == "":
		text = String(TYPES.get(String(e.get("type", "")), {}).get("vi", e.get("type", "")))
	for key in ["values"] + Array(TYPES.get(String(e.get("type", "")), {}).get("params", [])):
		var token := "{v}" if key == "values" else "{%s}" % key
		if text.find(token) < 0:
			continue
		text = text.replace(token, _value_text(e, key, tier))
	return text


static func _value_text(e: Dictionary, key: String, tier: int) -> String:
	var v = e.get(key, 0.0)
	if not v is Array:
		return _num(float(v))
	if tier > 0:
		return _num(n(e, tier, key))
	var parts: Array[String] = []
	for x in v:
		parts.append(_num(float(x)))
	return "/".join(parts)


static func _num(v: float) -> String:
	return str(int(roundf(v))) if is_equal_approx(v, roundf(v)) else String.num(v, 2)
#endregion


#region fight: start, every second
## Fight start (BattleSim.update, after the web synergies): Tailwind, the Human rows, Steel, the first Light flash.
static func on_fight_start(sim: BattleSim) -> void:
	for team in [BattleUnit.Team.BLUE, BattleUnit.Team.RED]:
		var wind := holders(sim, team, "tailwind_team_haste")
		if not wind.is_empty():
			_tailwind(sim, wind[0])
	for u in sim.units.duplicate():
		if not u.alive:
			continue
		var s := held(u, "row_strategy")
		if not s.is_empty():
			_row_strategy(sim, u, s)
		s = held(u, "periodic_blind_flash")
		if not s.is_empty():
			_blind_flash(sim, u, s)
		s = held(u, "opening_fortify")
		if not s.is_empty():
			u.add_status("fortified", n(s.e, s.t, "s") * 1000.0)


## A unit joins the fight with its blocks (SeasonSynergies.on_spawn): Fossil shell, Aquatic dodge.
static func on_spawn(_sim: BattleSim, u: BattleUnit, s: Dictionary) -> void:
	match String(s.e.type):
		"shell_burst":
			u.shield += roundf(u.max_hp * n(s.e, s.t) / 100.0)
			u.counters.shell = true
		"dodge_reward":
			u.add_stat("dodge", n(s.e, s.t) / 100.0)


## Every second of a unit holding blocks (BattleSim._each_second).
static func on_second(sim: BattleSim, u: BattleUnit) -> void:
	u.counters.season_seconds = int(u.counters.get("season_seconds", 0)) + 1
	var sec: int = u.counters.season_seconds
	for s in u.season_effects:
		if not u.alive:
			return
		match String(s.e.type):
			"periodic_quake":
				if sec % 4 == 0:
					_quake(sim, u, s)
			"growth_over_time":
				if sec % 3 == 0 and int(u.counters.get("growth", 0)) < 8:
					u.counters.growth = int(u.counters.get("growth", 0)) + 1
					u.add_stat("atk", u.base_atk * n(s.e, s.t) / 100.0)
					u.add_stat("maxHP", u.base_hp * n(s.e, s.t) / 100.0)
			"adjacency_swarm":
				_swarm(sim, u, s)
			"periodic_blind_flash":
				if sec % 8 == 0:
					_blind_flash(sim, u, s)
			"opening_fortify":
				if not u.has_status("fortified") and not u.counters.has("fortify_done"):
					u.counters.fortify_done = true
					var gain := roundf(float(u.counters.get("fortify_blocked", 0.0)) * 0.1)
					if gain >= 1.0:
						u.add_stat("def", gain)
						sim.emit({"type": "buff", "unit": u, "stat": "def", "amount": gain})
			"damage_stagger":
				_stagger_tick(sim, u)


## Every step of the fight: the burning cells (each second), the end of Tailwind.
static func update(sim: BattleSim, dt: float) -> void:
	var st := _state(sim)
	st.clock = float(st.clock) + dt
	while float(st.clock) >= 1000.0:
		st.clock = float(st.clock) - 1000.0
		_scorch_tick(sim, st)
	for team in st.tailwind.keys():
		if sim.time_ms >= float(st.tailwind[team]):
			st.tailwind.erase(team)
			_tailwind_end(sim, int(team))


static func _scorch_tick(sim: BattleSim, st: Dictionary) -> void:
	var cells: Dictionary = st.scorch
	var cooled: Array[Vector2i] = []
	for cell in cells.keys():
		var c: Dictionary = cells[cell]
		if sim.time_ms > float(c.until):
			cells.erase(cell)
			if sim.board_effects.has(cell):
				sim.board_effects[cell].erase("SCORCH")
			cooled.append(cell)
			continue
		var u := sim.board.get_unit(cell)
		if u == null or not u.alive or u.team == int(c.team) or u.inanimate:
			continue
		var owner: BattleUnit = c.owner if c.owner != null and c.owner.alive else null
		sim.deal_damage(u, roundf(u.max_hp * float(c.pct) / 100.0), BattleUnit.DamageKind.SPECIAL, owner, false, true, false, true)
		sim.add_status(u, SCORCH_HIT, 1200.0, owner)
	if not cooled.is_empty():
		sim.emit({"type": "board_effect", "cells": cooled, "effect": "SCORCH"})


## Tailwind: every ally +v% SPEED while it blows (6 s, again after each Flying cast); a Flying holder keeps half.
static func _tailwind(sim: BattleSim, holder: BattleUnit) -> void:
	var s := held(holder, "tailwind_team_haste")
	var st := _state(sim)
	var pct := n(s.e, s.t) / 100.0
	for a in sim.allies_of(holder):
		if a.inanimate or a.counters.has("tailwind_bonus"):
			continue
		var bonus := roundf(a.speed * pct)
		a.add_stat("speed", bonus)
		a.counters.tailwind_bonus = bonus
	st.tailwind[holder.team] = sim.time_ms + 6000.0
	_flash(sim, holder, String(s.type))


static func _tailwind_end(sim: BattleSim, team: int) -> void:
	for a in sim.alive_units(team):
		if not a.counters.has("tailwind_bonus"):
			continue
		var bonus := float(a.counters.tailwind_bonus)
		a.counters.erase("tailwind_bonus")
		if not held(a, "tailwind_team_haste").is_empty():
			if a.counters.has("tailwind_kept"):
				a.add_stat("speed", -bonus)
			else:
				a.counters.tailwind_kept = true
				a.add_stat("speed", -roundf(bonus * 0.5))
		else:
			a.add_stat("speed", -bonus)


static func _row_strategy(sim: BattleSim, u: BattleUnit, s: Dictionary) -> void:
	if in_front_rows(u):
		var behind := ally_in_row(sim, u, false)
		if behind != null:
			sim.add_shield(behind, n(s.e, s.t), u)
	else:
		var ahead := ally_in_row(sim, u, true)
		if ahead != null:
			ahead.add_stat("atk", ahead.base_atk * n(s.e, s.t, "atk") / 100.0)
			ahead.add_stat("ap", n(s.e, s.t, "ap"))
			sim.emit({"type": "buff", "unit": ahead, "stat": "atk", "amount": n(s.e, s.t, "atk")})


static func _blind_flash(sim: BattleSim, u: BattleUnit, s: Dictionary) -> void:
	var blinded := 0
	for e in sim.enemies_of(u):
		if BattleBoard.distance(u.cell, e.cell) <= 2:
			sim.add_status(e, "blinded", n(s.e, s.t) * 1000.0, u)
			blinded += 1
	if blinded > 0:
		u.add_stat("ap", n(s.e, s.t, "ap") * blinded)
		_flash(sim, u, String(s.type))


static func _quake(sim: BattleSim, u: BattleUnit, s: Dictionary) -> void:
	var hit := false
	for c in BattleBoard.adjacent_cells(u.cell):
		var e := sim.board.get_unit(c)
		if e != null and e.alive and e.team != u.team:
			sim.deal_damage(e, roundf(u.def * n(s.e, s.t) / 100.0), BattleUnit.DamageKind.SPECIAL, u, false, true)
			e.add_stat("speed", -10.0)
			hit = true
	if hit:
		sim.emit({"type": "area", "unit": u, "cells": BattleBoard.adjacent_cells(u.cell), "affects": "enemies",
			"delay": 0.0, "season": true})


## Bug swarm: its bonus follows the Bug allies ADJACENT to it (recomputed each second).
static func _swarm(sim: BattleSim, u: BattleUnit, s: Dictionary) -> void:
	var near := 0
	for c in BattleBoard.adjacent_cells(u.cell):
		var a := sim.board.get_unit(c)
		if a != null and a.alive and a.team == u.team and not held(a, "adjacency_swarm").is_empty():
			near += 1
	var base_speed := float(u.counters.get("swarm_base_speed", u.speed)) # its SPEED when the swarm first counted
	u.counters.swarm_base_speed = base_speed
	var want_speed := roundf(base_speed * n(s.e, s.t) / 100.0 * near)
	var want_def := n(s.e, s.t, "def") * near
	var had_speed := float(u.counters.get("swarm_speed", 0.0))
	var had_def := float(u.counters.get("swarm_def", 0.0))
	if want_speed != had_speed:
		u.add_stat("speed", want_speed - had_speed)
		u.counters.swarm_speed = want_speed
	if want_def != had_def:
		u.add_stat("def", want_def - had_def)
		u.counters.swarm_def = want_def


static func _stagger_tick(sim: BattleSim, u: BattleUnit) -> void:
	var chunks: Array = u.counters.get("stagger", [])
	if chunks.is_empty():
		return
	var due := 0.0
	var left: Array = []
	for ch in chunks:
		due += float(ch[0])
		if int(ch[1]) > 1:
			left.append([ch[0], int(ch[1]) - 1])
	u.counters.stagger = left
	if due >= 1.0:
		u.counters.stagger_tick = true
		sim.deal_damage(u, roundf(due), BattleUnit.DamageKind.TRUE, null, false, true, false, true)
		u.counters.erase("stagger_tick")
#endregion


#region fight: attacks, hits, abilities
## After each basic attack of `u` (SeasonSynergies.on_attack).
static func on_attack(sim: BattleSim, u: BattleUnit) -> void:
	for s in u.season_effects:
		match String(s.e.type):
			"same_target_ramp":
				var t := u.target
				if t == null:
					continue
				if int(u.counters.get("ramp_target", -1)) == t.id:
					u.counters.ramp = mini(int(u.counters.get("ramp", 0)) + 1, RAMP_MAX)
				else:
					u.counters.ramp_target = t.id
					u.counters.ramp = 1
			"nth_attack_wave":
				u.counters.wave = int(u.counters.get("wave", 0)) + 1
				if int(u.counters.wave) % 3 == 0 and u.target != null and u.target.alive:
					_sound_wave(sim, u, s)
			"charge_release_chain":
				_charge(sim, u, s)


static func _sound_wave(sim: BattleSim, u: BattleUnit, s: Dictionary) -> void:
	var cells := AbilityScripts.line_through(u, u.target)
	sim.emit({"type": "area", "unit": u, "cells": cells, "affects": "enemies", "delay": 0.0, "season": true})
	for c in cells:
		var e := sim.board.get_unit(c)
		if e != null and e.alive and e.team != u.team:
			sim.deal_damage(e, n(s.e, s.t), BattleUnit.DamageKind.SPECIAL, u, false, true)


## Electric: a charge per attack / hit taken; at CHARGES, a bolt jumping through `n` enemies.
static func _charge(sim: BattleSim, u: BattleUnit, s: Dictionary) -> void:
	u.counters.charge = int(u.counters.get("charge", 0)) + 1
	if int(u.counters.charge) < CHARGES:
		return
	u.counters.charge = 0
	var from := u.cell
	var hit := {}
	for i in int(n(s.e, s.t, "n")):
		var next: BattleUnit = null
		for e in sim.enemies_of(u):
			if hit.has(e) or e.is_untargetable():
				continue
			if next == null or BattleBoard.distance(from, e.cell) < BattleBoard.distance(from, next.cell):
				next = e
		if next == null:
			break
		hit[next] = true
		sim.emit({"type": "lightning", "cell": next.cell})
		sim.deal_damage(next, n(s.e, s.t), BattleUnit.DamageKind.SPECIAL, u, false, true)
		from = next.cell
	_flash(sim, u, String(s.type))


## `u` hit `t` with a basic attack ("attack") or its ability ("ability").
static func on_hit(sim: BattleSim, u: BattleUnit, t: BattleUnit, kind: String) -> void:
	for s in u.season_effects:
		if not t.alive:
			return
		match String(s.e.type):
			"seed_drain":
				if sim.time_ms >= float(t.counters.get("seed_until", -1.0)):
					t.counters.seed_until = sim.time_ms + SEED_MS
					for i in range(1, 6):
						sim.schedule(1000.0 * i, null, _seed_tick.bind(sim, t, u.team, n(s.e, s.t)))
			"stat_steal_on_hit":
				var key := "steal_%d" % t.id
				if int(u.counters.get("steal_n", 0)) < STEAL_MAX and sim.time_ms >= float(u.counters.get(key, -1.0)):
					u.counters[key] = sim.time_ms + 1000.0
					u.counters.steal_n = int(u.counters.get("steal_n", 0)) + 1
					var atk := minf(n(s.e, s.t), maxf(t.atk - 1.0, 0.0))
					t.add_stat("atk", -atk)
					u.add_stat("atk", atk)
					t.add_stat("ap", -n(s.e, s.t, "ap"))
					u.add_stat("ap", n(s.e, s.t, "ap"))
			"chill_stacks_freeze":
				_chill(sim, u, t, s)
			"poison_contagion":
				if kind == "ability":
					sim.add_status(t, "poison", 3000.0, u)


static func _seed_tick(sim: BattleSim, t: BattleUnit, team: int, pct: float) -> void:
	if not t.alive or sim.finished:
		return
	var amount := roundf(t.max_hp * pct / 100.0)
	sim.deal_damage(t, amount, BattleUnit.DamageKind.TRUE, null, false, true, false, true)
	var lowest: BattleUnit = null
	for a in sim.alive_units(team):
		if not a.inanimate and (lowest == null or a.hp_ratio() < lowest.hp_ratio()):
			lowest = a
	if lowest != null:
		sim.heal(lowest, amount, null)


static func _chill(sim: BattleSim, u: BattleUnit, t: BattleUnit, s: Dictionary) -> void:
	var stacks := int(t.counters.get("chill", 0)) + 1
	var loss := roundf(t.speed * n(s.e, s.t) / 100.0)
	t.add_stat("speed", -loss)
	t.counters.chill_speed = float(t.counters.get("chill_speed", 0.0)) + loss
	t.counters.chill = stacks
	var stamp := sim.time_ms
	t.counters.chill_stamp = stamp
	if stacks >= 5:
		_chill_clear(t)
		sim.add_status(t, "freeze", 1000.0, u)
	else:
		sim.schedule(3000.0, null, _chill_expire.bind(t, stamp))


static func _chill_expire(t: BattleUnit, stamp: float) -> void:
	if float(t.counters.get("chill_stamp", -1.0)) == stamp:
		_chill_clear(t)


static func _chill_clear(t: BattleUnit) -> void:
	t.add_stat("speed", float(t.counters.get("chill_speed", 0.0)))
	t.counters.erase("chill")
	t.counters.erase("chill_speed")


## After its ability (SeasonSynergies.on_cast).
static func on_cast(sim: BattleSim, u: BattleUnit) -> void:
	for s in u.season_effects:
		match String(s.e.type):
			"cast_chain_pp":
				var low: BattleUnit = null
				for a in holders(sim, u.team, "cast_chain_pp"):
					if a != u and (low == null or a.pp / maxf(a.max_pp, 1.0) < low.pp / maxf(low.max_pp, 1.0)):
						low = a
				if low != null:
					low.add_pp(n(s.e, s.t))
			"cast_stacks_type_team":
				var key := "dragon_%d" % u.team
				var st := _state(sim)
				if int(st.get(key, 0)) < DRAGON_MAX:
					st[key] = int(st.get(key, 0)) + 1
					for a in holders(sim, u.team, "cast_stacks_type_team"):
						a.add_stat("atk", n(s.e, s.t))
						a.add_stat("ap", n(s.e, s.t, "ap"))
						a.add_stat("speed", 5.0)
					_flash(sim, u, String(s.type))
			"cast_heals_lowest_allies":
				var allies := sim.allies_of(u).filter(func(a: BattleUnit) -> bool: return not a.inanimate)
				allies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.hp_ratio() < b.hp_ratio())
				for i in mini(int(n(s.e, s.t, "n")), allies.size()):
					var a: BattleUnit = allies[i]
					sim.heal(a, a.max_hp * n(s.e, s.t) / 100.0, u)
					if s.t >= 4:
						a.cleanse()
			"cast_cost_down":
				var base := float(u.counters.get("base_max_pp", u.max_pp))
				u.counters.base_max_pp = base
				u.max_pp = maxf(u.max_pp - base * n(s.e, s.t) / 100.0, base * 0.5)
			"tailwind_team_haste":
				_tailwind(sim, u)
			"damage_stagger":
				u.counters.erase("stagger")


## Damage of `u` to `t` that landed (SeasonSynergies.on_damage_dealt): Psychic echo, Monster lifesteal.
static func on_damage_dealt(sim: BattleSim, u: BattleUnit, t: BattleUnit, taken: float, retaliation: bool) -> void:
	var kind := sim.source_kind(u)
	for s in u.season_effects:
		match String(s.e.type):
			"ability_echo":
				if kind == "ability" and not retaliation and taken >= 1.0:
					var echo := roundf(taken * n(s.e, s.t) / 100.0)
					sim.schedule(ECHO_MS, u, func() -> void:
						if t.alive:
							sim.deal_damage(t, echo, BattleUnit.DamageKind.SPECIAL, u, false, true, false))
			"half_hp_rampage":
				if u.counters.has("rampage") and kind != "":
					sim.heal(u, ceilf(taken * n(s.e, s.t) / 100.0), u)


## `t` took damage and is still up (SeasonSynergies.on_damage_received).
static func on_damage_received(sim: BattleSim, t: BattleUnit) -> void:
	for s in t.season_effects:
		if not t.alive:
			return
		match String(s.e.type):
			"charge_release_chain":
				_charge(sim, t, s)
			"half_hp_rampage":
				if not t.counters.has("rampage") and t.hp < 0.5 * t.max_hp:
					t.counters.rampage = true
					t.add_status("unstoppable", n(s.e, s.t, "s") * 1000.0)
					t.add_stat("speed", roundf(t.speed * n(s.e, s.t, "speed") / 100.0))
					for c in BattleBoard.adjacent_cells(t.cell):
						var e := sim.board.get_unit(c)
						if e != null and e.alive and e.team != t.team:
							sim.add_status(e, "flinch", 2000.0, t)
					_flash(sim, t, String(s.type))
			"shell_burst":
				if t.counters.get("shell", false) and t.shield <= 0.0:
					t.counters.shell = false
					for c in BattleBoard.adjacent_cells(t.cell):
						var e := sim.board.get_unit(c)
						if e != null and e.alive and e.team != t.team:
							sim.deal_damage(e, n(s.e, s.t, "dmg"), BattleUnit.DamageKind.SPECIAL, t, false, true)
					t.add_stat("atk", t.base_atk * n(s.e, s.t) / 100.0)
					_flash(sim, t, String(s.type))
#endregion


#region fight: damage, death, statuses, targets
## x on a damage of `attacker` to `t` before DEF (SeasonSynergies.damage_factor).
static func damage_factor(sim: BattleSim, attacker: BattleUnit, t: BattleUnit) -> float:
	var factor := 1.0
	if attacker != null and not attacker.season_effects.is_empty():
		var kind := sim.source_kind(attacker)
		for s in attacker.season_effects:
			match String(s.e.type):
				"same_target_ramp":
					if kind == "attack" and int(attacker.counters.get("ramp_target", -1)) == t.id:
						factor *= 1.0 + n(s.e, s.t) / 100.0 * int(attacker.counters.get("ramp", 0))
				"focus_fire_bonus":
					if kind != "":
						var others := 0
						for a in holders(sim, attacker.team, "focus_fire_bonus"):
							if a != attacker and a.target == t:
								others += 1
						factor *= 1.0 + n(s.e, s.t) / 100.0 * others
				"hunt_lowest_hp":
					if kind != "" and t == _lowest_enemy(sim, attacker, false):
						factor *= 1.0 + n(s.e, s.t) / 100.0
				"afterlife_spirit":
					if attacker.counters.has("spirit"):
						factor *= n(s.e, s.t) / 100.0
	if attacker != null and sim.source_kind(attacker) == "ability" and attacker.team != t.team:
		var cut := 0.0
		for a in holders(sim, t.team, "aura_status_immunity"):
			if a == t or BattleBoard.distance(a.cell, t.cell) <= 1:
				var s := held(a, "aura_status_immunity")
				cut = maxf(cut, n(s.e, s.t) / 100.0)
		factor *= 1.0 - cut
	return factor


## The damage `t` takes after DEF (BattleSim.deal_damage): a spirit takes none, Steel's opening cut, the Rock cap,
## the Amorphous stagger (the deferred part comes back each second, _stagger_tick).
static func adjust_taken(_sim: BattleSim, t: BattleUnit, amount: float) -> float:
	if t.season_effects.is_empty():
		return amount
	if t.counters.has("spirit"):
		return 0.0
	for s in t.season_effects:
		match String(s.e.type):
			"opening_fortify":
				if t.has_status("fortified"):
					var blocked := amount * n(s.e, s.t) / 100.0
					t.counters.fortify_blocked = float(t.counters.get("fortify_blocked", 0.0)) + blocked
					amount -= blocked
			"damage_cap_per_hit":
				amount = minf(amount, ceilf(t.max_hp * n(s.e, s.t) / 100.0))
			"damage_stagger":
				if not t.counters.has("stagger_tick") and amount >= 3.0:
					var deferred := floorf(amount * n(s.e, s.t) / 100.0)
					var chunks: Array = t.counters.get("stagger", [])
					chunks.append([deferred / 3.0, 3])
					t.counters.stagger = chunks
					amount -= deferred
	return maxf(amount, 0.0)


## `t` would faint (BattleSim.deal_damage): true if a block keeps it up (Normal endures, Ghost lingers).
static func on_lethal(sim: BattleSim, t: BattleUnit) -> bool:
	var s := held(t, "cheat_death")
	if not s.is_empty() and not t.counters.has("endured"):
		t.counters.endured = true
		t.hp = 1.0
		var ms := n(s.e, s.t, "s") * 1000.0
		t.add_status("protect", ms)
		var shield := t.max_hp * n(s.e, s.t) / 100.0
		sim.schedule(ms, t, func() -> void: sim.add_shield(t, shield, t))
		_flash(sim, t, String(s.type))
		return true
	s = held(t, "afterlife_spirit")
	if not s.is_empty() and not t.counters.has("spirit"):
		t.counters.spirit = true
		t.hp = 1.0
		t.cleanse()
		var ms := n(s.e, s.t, "s") * 1000.0
		t.add_status("untargetable", ms)
		for e in sim.units:
			if e.target == t:
				e.target = null
		sim.schedule(ms, null, func() -> void:
			if t.alive:
				sim._faint(t))
		_flash(sim, t, String(s.type))
		return true
	return false


## A negative status about to land on `t` (BattleSim.add_status): true = it does not.
static func blocks_status(sim: BattleSim, t: BattleUnit, status: String) -> bool:
	if not BattleUnit.NEGATIVE_STATUSES.has(status):
		return false
	if HARD_CC.has(status):
		if t.counters.get("shell", false) and t.shield > 0.0 and not held(t, "shell_burst").is_empty():
			return true
		if t.has_status("unstoppable"):
			return true
	for a in holders(sim, t.team, "aura_status_immunity"):
		if a == t or BattleBoard.distance(a.cell, t.cell) <= 1:
			var s := held(a, "aura_status_immunity")
			if sim.time_ms >= float(t.counters.get("misty_ready", -1.0)):
				t.counters.misty_ready = sim.time_ms + n(s.e, s.t, "s") * 1000.0
				_flash(sim, t, String(s.type))
				return true
			break
	return false


## Wild: the enemy with the least HP within its range (null: the usual target).
static func pick_target(sim: BattleSim, u: BattleUnit) -> BattleUnit:
	if held(u, "hunt_lowest_hp").is_empty():
		return null
	return _lowest_enemy(sim, u, true)


static func _lowest_enemy(sim: BattleSim, u: BattleUnit, in_range: bool) -> BattleUnit:
	var best: BattleUnit = null
	for e in sim.enemies_of(u):
		if e.is_untargetable() or e.inanimate:
			continue
		if in_range and BattleBoard.distance_c(u.cell, e.cell) > u.attack_range:
			continue
		if best == null or e.hp + e.shield < best.hp + best.shield:
			best = e
	return best


## A unit fainted (BattleSim._faint): Poison spreads, Gourmet feasts.
static func on_death(sim: BattleSim, dead: BattleUnit) -> void:
	var foes := _other(dead.team)
	if dead.poison_stacks > 0 or dead.has_status("poison"):
		var spreaders := holders(sim, foes, "poison_contagion")
		if not spreaders.is_empty():
			var s := held(spreaders[0], "poison_contagion")
			var near := sim.alive_units(dead.team)
			near.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
				return BattleBoard.distance(a.cell, dead.cell) < BattleBoard.distance(b.cell, dead.cell))
			for i in mini(int(n(s.e, s.t)), near.size()):
				for k in maxi(dead.poison_stacks, 1) + 1:
					sim.add_status(near[i], "poison", 3000.0, spreaders[0])
	var eaters := holders(sim, foes, "feast_on_enemy_death")
	if not eaters.is_empty():
		eaters.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
			return BattleBoard.distance(a.cell, dead.cell) < BattleBoard.distance(b.cell, dead.cell))
		var g: BattleUnit = eaters[0]
		var s := held(g, "feast_on_enemy_death")
		g.add_stat("maxHP", n(s.e, s.t, "hp"))
		sim.heal(g, g.max_hp * n(s.e, s.t) / 100.0, g)
		_flash(sim, g, String(s.type))


## `t` dodged a basic attack (BattleSim.attack_hit): Aquatic gets PP and SPEED (up to 10 times).
static func on_dodge(_sim: BattleSim, t: BattleUnit) -> void:
	if held(t, "dodge_reward").is_empty() or int(t.counters.get("dodges", 0)) >= 10:
		return
	t.counters.dodges = int(t.counters.get("dodges", 0)) + 1
	t.add_pp(8.0)
	t.add_stat("speed", 5.0)


## Cells an ability step hits (BattleSim.emit "area"): Fire sets them alight.
static func on_area(sim: BattleSim, event: Dictionary) -> void:
	if event.get("season", false):
		return
	var u: BattleUnit = event.get("unit")
	var s := held(u, "scorch_cells_on_cast")
	if s.is_empty() or String(event.get("affects", "enemies")) == "allies":
		return
	var st := _state(sim)
	var lit: Array[Vector2i] = []
	for cell in event.get("cells", []):
		if not BattleBoard.in_bounds(cell):
			continue
		st.scorch[cell] = {"until": sim.time_ms + float(event.get("delay", 0.0)) + n(s.e, s.t, "s") * 1000.0,
			"team": u.team, "pct": n(s.e, s.t), "owner": u}
		if not sim.board_effects.has(cell):
			sim.board_effects[cell] = {}
		sim.board_effects[cell]["SCORCH"] = true # only the tint of the view: the damage is _scorch_tick's
		lit.append(cell)
	if not lit.is_empty():
		sim.emit({"type": "board_effect", "cells": lit, "effect": "SCORCH"})


static func on_kill(_sim: BattleSim, attacker: BattleUnit, _t: BattleUnit) -> void:
	if not held(attacker, "hunt_lowest_hp").is_empty():
		attacker.add_stat("speed", roundf(attacker.speed * 0.1))
#endregion
