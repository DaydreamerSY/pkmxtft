extends Node

## Headless checks of the pure game logic. Run:
##   Godot_console.exe --headless --path . res://tests/sim_test.tscn
## Exit code 0 = all good.

var failures := 0


func _ready() -> void:
	# the checks read English texts, whatever the saved / system language
	GameData.set_language("en")
	TranslationServer.set_locale("en")
	# the checks of the ported rules run like the web game: no enemy synergies, no templates
	Difficulty.set_level("classic")
	# ... and with everything unlocked, whatever the Battle Pass of the player (see _check_progression)
	Progression.override_level = 9999
	# ... and with every Pokémon of the game, whatever the season picked in the menu (see _check_seasons)
	Seasons.set_current(Seasons.FULL)
	GameData.apply_progression()
	# ... and with the web stats: the auto balance (data/balance.json) off, checked apart in _check_balance
	GameData.use_balance(false)
	_check_hex_board()
	_check_scripts()
	_check_waves()
	_check_every_ability()
	_check_previews()
	_check_player_state()
	_check_items()
	_check_item_fights()
	_check_roles_and_texts()
	_check_synergy_counts_and_weather()
	_check_synergy_effects()
	_check_passives()
	_check_stage_rules()
	_check_town()
	_check_languages()
	_check_vfx()
	_check_synergy_items()
	_check_shiny_items()
	_check_town_items()
	_check_regions()
	_check_synergy_members()
	_check_hover_tip()
	_check_difficulty()
	_check_mana()
	_check_balance()
	_check_ability_events()
	_check_skill_scale()
	_check_player_config()
	_check_fights()
	_check_ported_rules()
	_check_records()
	_check_progression()
	_check_progression_switch()
	_check_seasons()
	print("=== %s (%d failure(s)) ===" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _fail(msg: String) -> void:
	failures += 1
	push_error("FAIL: " + msg)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fail(msg)


## The hex board (BattleBoard, docs/PORTING.md "Lưới lục giác"): 7 x 8 pointy-top cells, odd rows shifted.
func _check_hex_board() -> void:
	_expect(BattleBoard.all_cells().size() == 56, "hex: 7 x 8 cells")
	_expect(BattleBoard.adjacent_cells(Vector2i(3, 3)).size() == 6 and BattleBoard.adjacent_cells(Vector2i(3, 4)).size() == 6,
		"hex: 6 neighbours on both row parities")
	_expect(BattleBoard.adjacent_cells(Vector2i(0, 0)).size() == 2 and BattleBoard.adjacent_cells(Vector2i(6, 1)).size() == 3,
		"hex: neighbours clipped at the corners")
	# odd row (3) shifted right: its neighbours forward are (x, 4) and (x + 1, 4); even row (4): (x - 1, 5) and (x, 5)
	_expect(BattleBoard.adjacent_cells(Vector2i(3, 3)).has(Vector2i(4, 4)) and not BattleBoard.adjacent_cells(Vector2i(3, 3)).has(Vector2i(2, 4)),
		"hex: odd rows are shifted to the right")
	_expect(BattleBoard.adjacent_cells(Vector2i(3, 4)).has(Vector2i(2, 5)) and not BattleBoard.adjacent_cells(Vector2i(3, 4)).has(Vector2i(4, 5)),
		"hex: even rows are not shifted")
	var ring_sizes := [1, 6, 12, 18]
	for r in 4:
		var n := 0
		for c in BattleBoard.all_cells():
			if BattleBoard.distance(Vector2i(3, 4), c) == r:
				n += 1
		_expect(n == ring_sizes[r], "hex: %d cells %d steps from the middle (got %d)" % [ring_sizes[r], r, n])
	_expect(BattleBoard.cells_in_range(Vector2i(3, 4), 2, true).size() == 19, "hex: range 2 = 19 cells")
	for a in BattleBoard.all_cells():
		for b in [Vector2i(0, 0), Vector2i(6, 7), Vector2i(2, 5)]:
			if BattleBoard.distance(a, b) != BattleBoard.distance(b, a):
				_fail("hex: distance not symmetric %s %s" % [a, b])
			var line := BattleBoard.cells_between(a, b)
			if line.size() != BattleBoard.distance(a, b) + 1 or line[0] != a or line.back() != b:
				_fail("hex: line %s -> %s is %s" % [a, b, line])
			for i in range(1, line.size()):
				if BattleBoard.distance(line[i - 1], line[i]) != 1:
					_fail("hex: line %s -> %s has a gap" % [a, b])
	for c in BattleBoard.all_cells():
		for d in BattleBoard.DIRECTIONS:
			var n := BattleBoard.step(c, d)
			if BattleBoard.distance(c, n) != 1 or BattleBoard.orientation(c, n) != d:
				_fail("hex: step / orientation %s %s" % [c, d])
		if BattleBoard.cell_at(BattleBoard.center(c)) != c:
			_fail("hex: cell_at(center(%s))" % c)
	# straight ahead (two rows up) is between two directions: the one toward the middle of the board
	_expect(BattleBoard.orientation(Vector2i(0, 2), Vector2i(0, 4)) == BattleBoard.DIRECTIONS[1]
		and BattleBoard.orientation(Vector2i(6, 2), Vector2i(6, 4)) == BattleBoard.DIRECTIONS[2], "hex: straight ahead leans inward")
	_expect(BattleBoard.cells_in_front(Vector2i(3, 2), Vector2i(3, 6), 2).size() == 8, "hex: cone of depth 2 = 3 + 5 cells")
	_expect(BattleBoard.ray_cells(Vector2i(0, 3), Vector2i(6, 3)).size() == 6, "hex: ray along the row to the edge")
	_expect(BattleBoard.line_cells(Vector2i(3, 1), Vector2i(3, 5))[0] == Vector2i(3, 1)
		and BattleBoard.line_cells(Vector2i(3, 1), Vector2i(3, 5)).back().y == BattleBoard.HEIGHT - 1, "hex: line to the far edge")
	# sprites: 8 directions at the real angle
	_expect(BattleBoard.sprite_direction_between(Vector2i(3, 2), Vector2i(3, 6)) == 4
		and BattleBoard.sprite_direction_between(Vector2i(3, 6), Vector2i(3, 2)) == 0
		and BattleBoard.direction_index(BattleBoard.DIRECTIONS[0]) == 2, "hex: sprite directions")
	# getClosestFreeCellTo: the cell itself, then sideways, then toward the own side
	var order := BattleSim.near_order()
	_expect(order.size() == 37 and order[0] == Vector2i.ZERO and order[1] == Vector2i(-1, 0) and order[2] == Vector2i(1, 0)
		and order[3].y == -1 and order[5].y == 1, "hex: free cell search order %s" % [order.slice(0, 7)])
	var sim := BattleSim.new()
	sim.add_unit(BattleUnit.create("MACHOP", BattleUnit.Team.RED), Vector2i(3, 5))
	_expect(sim.closest_free_cell_near(Vector2i(3, 5), BattleUnit.Team.RED) == Vector2i(2, 5), "hex: red search sideways first")
	sim.add_unit(BattleUnit.create("MACHOP", BattleUnit.Team.RED), Vector2i(2, 5))
	sim.add_unit(BattleUnit.create("MACHOP", BattleUnit.Team.RED), Vector2i(4, 5))
	var back: Variant = sim.closest_free_cell_near(Vector2i(3, 5), BattleUnit.Team.RED)
	_expect(back is Vector2i and back.y == 6, "hex: red search toward its side (%s)" % [back])
	sim.dispose()
	# waves: front row 3 -> row 4, the 4th row 0 -> row 7; the web boss boards fit 7 columns
	_expect(EndlessWaves.to_sim_cell(0, 3) == Vector2i(0, 4) and EndlessWaves.to_sim_cell(6, 0) == Vector2i(6, 7), "hex: wave rows")
	var fitted := GameData.fit_wave_board([["A", 0, 1], ["B", 7, 1], ["C", 3, 2], ["D", 4, 2]])
	_expect(fitted[0][1] == 0 and fitted[1][1] == 6 and fitted[2][1] != fitted[3][1], "hex: boss boards fit 7 columns (%s)" % [fitted])
	for stage in GameData.pve_stages:
		for entry in GameData.pve_stages[stage].get("board", []):
			if not BattleBoard.in_bounds(EndlessWaves.to_sim_cell(int(entry[1]), int(entry[2]))):
				_fail("hex: boss %d off the board %s" % [stage, entry])
	print("hex board ok")


func _check_scripts() -> void:
	var dirs := ["res://src/core", "res://src/view", "res://src/ui", "res://src/game", "res://src/autoload",
		"res://tools/wave_editor", "res://tests"]
	var count := 0
	for d in dirs:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				var s: Script = load(d + "/" + f)
				if s == null or not s.can_instantiate():
					_fail("script " + f)
				count += 1
	print("scripts loaded: %d" % count)


func _check_waves() -> void:
	var seed := 12345
	for stage in range(1, 61):
		var w := EndlessWaves.get_stage(stage, seed)
		if w.is_empty() or w.get("board", []).is_empty():
			_fail("empty wave at stage %d" % stage)
			continue
		for entry in w.board:
			if GameData.get_pokemon(entry[0]).is_empty():
				_fail("unknown pokemon %s at stage %d" % [entry[0], stage])
	var sample := []
	for s in [4, 10, 26, 45, 50]:
		var w := EndlessWaves.get_stage(s, seed)
		sample.append("%d:%s(%d)" % [s, w.name, w.board.size()])
	print("waves ok: ", ", ".join(sample))


## Casts every ported ability once in a small fight, star 1 to 3.
func _check_every_ability() -> void:
	var by_ability := {}
	for pkm in GameData.pokemon:
		var skill: String = GameData.pokemon[pkm].skill
		if GameData.abilities.has(skill) and not by_ability.has(skill):
			by_ability[skill] = pkm
	var casts := 0
	for skill in by_ability:
		var sim := BattleSim.new()
		sim.rng.seed = 42
		var caster := BattleUnit.create(by_ability[skill], BattleUnit.Team.BLUE)
		sim.add_unit(caster, Vector2i(3, 2))
		sim.add_unit(BattleUnit.create("PIKACHU", BattleUnit.Team.BLUE), Vector2i(2, 1))
		for c in [Vector2i(3, 3), Vector2i(4, 4), Vector2i(1, 5), Vector2i(6, 3)]:
			sim.add_unit(BattleUnit.create("MACHAMP", BattleUnit.Team.RED), c)
		caster.pp = caster.max_pp
		var target := sim.board.get_unit(Vector2i(3, 3))
		AbilityRunner.cast(sim, caster, target)
		for i in 200:
			sim.update(50.0)
		var events := sim.drain_events()
		sim.dispose()
		var cast_seen := events.any(func(e: Dictionary) -> bool: return e.type == "cast")
		if not cast_seen:
			_fail("no cast event for " + skill)
		casts += 1
	print("abilities cast: %d / %d defined" % [casts, GameData.abilities.size()])


func _check_previews() -> void:
	var n := 0
	for pkm in GameData.pool:
		var p := AbilityRunner.preview(pkm)
		if p.is_empty():
			_fail("preview " + pkm)
		var text := AbilityRunner.describe_areas(GameData.get_ability(GameData.get_pokemon(pkm).skill), 1, 1)
		if text == "" and not GameData.get_ability(GameData.get_pokemon(pkm).skill).get("steps", []).is_empty():
			_fail("area text " + pkm)
		n += 1
	var p := AbilityRunner.preview("SQUIRTLE")
	print("previews: %d, e.g. SQUIRTLE Hydro Pump cells: %s" % [n, p.steps[0].cells])
	print("  ", AbilityRunner.describe_areas(GameData.get_ability("FLOWER_TRICK"), 1, 1))


func _check_player_state() -> void:
	var p := PlayerState.new()
	p.gold = 200
	p.give_starter()
	# force three identical copies to test the merge
	var pkm: String = GameData.tier1_by_rarity["COMMON"][0]
	for i in 3:
		p.set_shop_slot(0, pkm)
		p.buy(0)
	var evolved := false
	for u in p.bench + p.board.values():
		if u != null and u.pkm == GameData.get_pokemon(pkm).evolution:
			evolved = true
	if not evolved:
		_fail("3 copies of %s did not evolve" % pkm)
	p.roll_shop()
	for i in p.shop.size():
		p.buy(i)
	var placed := p.auto_place()
	if p.board.size() > p.max_team_size():
		_fail("board over team size")
	p.buy_xp()
	var income := p.collect_income()
	print("player: level %d, gold %d, board %d, bench %d, placed %d, income %d" % [
		p.level, p.gold, p.board.size(), p.bench.filter(func(u) -> bool: return u != null).size(), placed, income])


## Item data, recipes, equip / combine rules, items of sold and merged Pokémon, wave items.
func _check_items() -> void:
	if GameData.items.size() != 358 or GameData.item_components.size() != 10:
		_fail("expected 358 items / 10 components, got %d / %d" % [GameData.items.size(), GameData.item_components.size()])
	for a in GameData.item_components:
		for b in GameData.item_components:
			if GameData.combine(a, b) == "":
				_fail("no recipe for %s + %s" % [a, b])
	for item in GameData.items:
		if GameData.item_desc(item).contains("?"):
			_fail("item template with an unknown param: " + item)
		if GameData.item_icon(item) == null:
			_fail("no icon for " + item)

	var p := PlayerState.new()
	p.give_starter()
	var unit: PlayerState.OwnedUnit = p.board.values()[0]
	p.items.assign(["CHARCOAL", "CHARCOAL", "TWISTED_SPOON", "RED_ORB", "MAGNET", "HEART_SCALE"])
	p.equip(0, unit) # Charcoal
	var combined := p.equip(0, unit) # + Charcoal -> Red Orb
	if unit.items != (["RED_ORB"] as Array[String]) or combined.get("result") != "RED_ORB":
		_fail("Charcoal + Charcoal should make Red Orb, got %s" % [unit.items])
	if p.equip(p.items.find("RED_ORB"), unit).ok:
		_fail("a second Red Orb should be refused")
	p.equip(p.items.find("TWISTED_SPOON"), unit)
	p.equip(p.items.find("MAGNET"), unit) # Spoon + Magnet -> Upgrade
	p.equip(p.items.find("HEART_SCALE"), unit)
	if unit.items.size() != 3 or not unit.items.has("UPGRADE"):
		_fail("expected Red Orb, Upgrade, Heart Scale, got %s" % [unit.items])
	p.items.append("MIRACLE_SEED")
	var full := p.equip(p.items.find("MIRACLE_SEED"), unit) # Heart Scale + Miracle Seed -> Sticky Barb
	if not full.ok or not unit.items.has("STICKY_BARB"):
		_fail("combining on a Pokémon holding 3 items should work, got %s" % [unit.items])
	p.items.append("BLACK_GLASSES")
	if p.equip(p.items.size() - 1, unit).ok:
		_fail("a 4th item should be refused")
	var bench_before := p.items.size()
	p.sell(unit)
	if p.items.size() != bench_before + 3:
		_fail("selling should give back the 3 items")

	# merge: the evolved Pokémon takes the items of the 3 copies (3 max, 1 component)
	var m := PlayerState.new()
	var pkm: String = GameData.tier1_by_rarity["COMMON"][0]
	var carried := [["CHOICE_SPECS"], ["CHARCOAL"], ["RED_ORB", "MAGNET"]]
	for i in 3:
		var copy := PlayerState.OwnedUnit.new(pkm)
		copy.items.assign(carried[i])
		m.bench[i] = copy
	m.check_merges()
	var evolved: PlayerState.OwnedUnit = null
	for u in m.bench:
		if u != null and u.pkm == GameData.get_pokemon(pkm).evolution:
			evolved = u
	if evolved == null or evolved.items != (["CHOICE_SPECS", "RED_ORB", "CHARCOAL"] as Array[String]) or m.items != (["MAGNET"] as Array[String]):
		_fail("merge items: evolved %s, bench %s" % [evolved.items if evolved else "none", m.items])

	var sample := []
	var seen_full := false
	for stage in range(1, 45):
		var w := EndlessWaves.get_stage(stage, 4242)
		var held: Array = w.get("items", [])
		if held.size() != w.board.size():
			_fail("stage %d: %d item lists for %d Pokémon" % [stage, held.size(), w.board.size()])
			continue
		var count := 0
		for list in held:
			count += list.size()
			for item in list:
				seen_full = seen_full or not GameData.is_component(item)
				if not GameData.items.has(item):
					_fail("stage %d: unknown item %s" % [stage, item])
		if stage < int(GameData.config.endless.firstItemStage) and count > 0 and not GameData.pve_stages.has(stage):
			_fail("stage %d: wild items before firstItemStage" % stage)
		if w.get("reward") != null:
			sample.append("%d:%s" % [stage, w.reward.get("kind", "choice" if w.reward.get("choice", false) else "random")])
	if not seen_full:
		_fail("no full item held by any wave")
	print("items ok, rewards: ", ", ".join(sample.slice(0, 12)))


## Every item held in a fight (both teams), plus a few effects checked on their own.
func _check_item_fights() -> void:
	var events_by_item := {}
	for item in GameData.items:
		var sim := BattleSim.new()
		sim.rng.seed = 3
		var holders: Array[BattleUnit] = []
		for c in [Vector2i(3, 2), Vector2i(4, 2), Vector2i(2, 1)]:
			var u := BattleUnit.create("MACHOP", BattleUnit.Team.BLUE)
			u.equip([item], sim.rng)
			sim.add_unit(u, c)
			holders.append(u)
		for c in [Vector2i(3, 3), Vector2i(5, 4), Vector2i(2, 5)]:
			var e := BattleUnit.create("MAGNEMITE", BattleUnit.Team.RED)
			e.equip([item], sim.rng)
			sim.add_unit(e, c)
		if item == "WONDER_BOX" and (holders[0].items.has("WONDER_BOX") or holders[0].items.size() != 2):
			_fail("Wonder Box should turn into 2 items, got %s" % [holders[0].items])
		var kinds := {}
		while not sim.finished:
			sim.update(25.0)
			for e in sim.drain_events():
				kinds[e.type] = kinds.get(e.type, 0) + 1
		events_by_item[item] = kinds
		sim.dispose()

	# Kings Rock: 20% max HP shield when the fight starts
	var sim := BattleSim.new()
	var rock := BattleUnit.create("MACHOP", BattleUnit.Team.BLUE)
	rock.equip(["KINGS_ROCK"])
	sim.add_unit(rock, Vector2i(3, 2))
	sim.add_unit(BattleUnit.create("MAGIKARP", BattleUnit.Team.RED), Vector2i(3, 5))
	sim.update(10.0)
	if absf(rock.shield - roundf(0.2 * rock.max_hp)) > 0.5:
		_fail("Kings Rock shield %s, expected %s" % [rock.shield, roundf(0.2 * rock.max_hp)])
	sim.dispose()

	# Max Revive: the holder comes back once
	sim = BattleSim.new()
	var revived := BattleUnit.create("MAGIKARP", BattleUnit.Team.BLUE)
	revived.equip(["MAX_REVIVE"])
	sim.add_unit(revived, Vector2i(3, 2))
	sim.add_unit(BattleUnit.create("MACHAMP", BattleUnit.Team.RED), Vector2i(3, 3))
	sim.deal_damage(revived, 9999.0, BattleUnit.DamageKind.TRUE, null)
	# triggerResurrection: 2 s out of the fight (no damage taken), then back with full HP
	if not revived.alive or not revived.has_status("resurrecting"):
		_fail("Max Revive did not start the resurrection")
	sim.deal_damage(revived, 9999.0, BattleUnit.DamageKind.TRUE, null)
	for _i in 45:
		sim.update(50.0)
	if not revived.alive or revived.hp < revived.max_hp or revived.has_item("MAX_REVIVE") or revived.has_status("resurrecting"):
		_fail("Max Revive did not resurrect (hp %s / %s)" % [revived.hp, revived.max_hp])
	sim.deal_damage(revived, 9999.0, BattleUnit.DamageKind.TRUE, null)
	if revived.alive:
		_fail("Max Revive should work only once")
	sim.dispose()

	# Rocky Helmet negates crits, Poke Doll takes 30% less
	sim = BattleSim.new()
	var attacker := BattleUnit.create("MACHAMP", BattleUnit.Team.RED)
	var helmet := BattleUnit.create("MACHOP", BattleUnit.Team.BLUE)
	helmet.equip(["ROCKY_HELMET"])
	if sim.crit_multiplier(attacker, helmet) != 1.0:
		_fail("Rocky Helmet should negate crit damage")
	var doll := BattleUnit.create("MACHOP", BattleUnit.Team.BLUE)
	var plain := BattleUnit.create("MACHOP", BattleUnit.Team.BLUE)
	doll.equip(["POKE_DOLL"])
	sim.add_unit(doll, Vector2i(1, 1))
	sim.add_unit(plain, Vector2i(5, 1))
	var with_doll: float = sim.deal_damage(doll, 100.0, BattleUnit.DamageKind.SPECIAL, attacker).taken
	var without: float = sim.deal_damage(plain, 100.0, BattleUnit.DamageKind.SPECIAL, attacker).taken
	if with_doll >= without:
		_fail("Poke Doll should reduce damage (%s vs %s)" % [with_doll, without])
	sim.dispose()

	var resurrects := 0
	var item_events := 0
	for item in events_by_item:
		resurrects += events_by_item[item].get("resurrect", 0)
		item_events += events_by_item[item].get("item", 0)
	print("item fights: %d items, %d resurrect / %d item events" % [events_by_item.size(), resurrects, item_events])


func _check_roles_and_texts() -> void:
	var roles := {}
	for pkm in GameData.pool:
		var role := UnitRoles.role_of(pkm)
		roles[role] = roles.get(role, 0) + 1
		for item in UnitRoles.info(role).items:
			if not GameData.items.has(item):
				_fail("role %s suggests unknown item %s" % [role, item])
	print("roles: ", roles)
	# caster / marksman: at least the range of the role (5), the others the web range; the web range stays readable
	var raised := 0
	for pkm in GameData.pokemon:
		var role := UnitRoles.role_of(pkm)
		var web := int(GameData.web_stat(pkm, "range", 1))
		var r := int(GameData.get_pokemon(pkm).get("range", 1))
		var want := maxi(web, int(UnitRoles.info(role).get("range", 0)))
		if r != want:
			_fail("range of %s (%s): %d, expected %d (web %d)" % [pkm, role, r, want, web])
		if (role == "caster" or role == "marksman") != (web >= 2 and role != "support"):
			_fail("role of %s from its web range %d: %s" % [pkm, web, role])
		raised += 1 if r > web else 0
	_expect(raised > 300, "role range: only %d forms raised" % raised)
	var shooter := BattleUnit.create("ABRA", BattleUnit.Team.BLUE) # web range 4
	_expect(shooter.role in ["caster", "marksman"] and shooter.attack_range == 5 and shooter.base_range == 5,
		"Abra (%s): attack range %d, expected 5" % [shooter.role, shooter.attack_range])
	var text := GameText.format("Attacks deal SPECIAL and [30,LK]% chance to BURN ADJACENT FIRE allies. +10 AP")
	if text.contains("SPECIAL") or text.contains("[30") or not text.contains("Burn"):
		_fail("text format: " + text)
	for type in GameData.config.synergyThresholds:
		if GameData.type_icon(type) == null:
			_fail("no icon for synergy " + type)
		if GameData.synergy_tier_texts(type).size() != GameData.config.synergyThresholds[type].size():
			_fail("synergy %s: %d tier texts for %d tiers" % [type, GameData.synergy_tier_texts(type).size(),
				GameData.config.synergyThresholds[type].size()])
		# the Pokémon of the synergy tooltip have the type themselves (Politoed, not Poliwag, in SOUND)
		var families := {}
		for pkm in Tooltips.pokemons_of_type(type):
			var data := GameData.get_pokemon(pkm)
			if not data.types.has(type):
				_fail("synergy tooltip %s lists %s, which has not the type" % [type, pkm])
			if families.has(data.get("family", pkm)):
				_fail("synergy tooltip %s lists the family of %s twice" % [type, pkm])
			families[data.get("family", pkm)] = true
	if not Tooltips.pokemons_of_type("SOUND").has("POLITOED") or Tooltips.pokemons_of_type("WATER").has("POLITOED"):
		_fail("synergy tooltip: Politoed should stand for its family in SOUND only")


#region synergies, weather, passives (Phase 4)
## First form of the shop pool (or additional) having `type`, `skip` ones skipped.
func _first_of_type(type: String, skip := 0) -> String:
	for pkm in GameData.pool + GameData.additional:
		var data := GameData.get_pokemon(pkm)
		if int(data.stars) == 1 and data.types.has(type) and not data.types.has("WILD"):
			if skip == 0:
				return pkm
			skip -= 1
	return ""


## A fight with given units ([pkm, cell]) and the blue team context.
func _fight(blue: Array, red: Array, tiers := {}, info := {}, weather := Weather.NEUTRAL) -> BattleSim:
	var sim := BattleSim.new()
	sim.rng.seed = 11
	sim.weather = weather
	sim.setup_teams(tiers, info)
	for b in blue:
		var u := BattleUnit.create(b[0], BattleUnit.Team.BLUE)
		u.owned_id = 1000 + b[1].x + 8 * b[1].y
		sim.add_unit(u, b[1])
	for r in red:
		sim.add_unit(BattleUnit.create(r[0], BattleUnit.Team.RED), r[1])
	return sim


func _run(sim: BattleSim, ms: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var t := 0.0
	while t < ms and not sim.finished:
		sim.update(25.0)
		t += 25.0
		events.append_array(sim.drain_events())
	return events


func _count(events: Array[Dictionary], type: String, text := "") -> int:
	return events.filter(func(e: Dictionary) -> bool:
		return e.type == type and (text == "" or String(e.get("text", e.get("status", ""))) == text)).size()


func _check_synergy_counts_and_weather() -> void:
	# families count once, the second type of dragons counts twice when DRAGON is active
	var counts := Synergies.count([
		{"family": "A", "types": ["DRAGON", "FIRE"]}, {"family": "A", "types": ["DRAGON", "FIRE"]},
		{"family": "B", "types": ["DRAGON", "WATER"]}, {"family": "C", "types": ["DRAGON"]},
	])
	if counts.get("DRAGON") != 3 or counts.get("FIRE") != 2 or counts.get("WATER") != 2:
		_fail("dragon double synergy: %s" % counts)
	if Synergies.tier("FIRE", 4) != 2 or Synergies.effect_name("FIRE", 2) != "WILDFIRE":
		_fail("synergy tiers: FIRE 4 -> %d %s" % [Synergies.tier("FIRE", 4), Synergies.effect_name("FIRE", 2)])
	if Synergies.dominant({"PSYCHIC": 3, "FIELD": 3}, ["PSYCHIC", "FIELD"]) == "":
		_fail("dominant synergy on a tie")
	var water := []
	for i in 8:
		water.append(Weather.voter(["WATER"], "NONE"))
	if Weather.compute([water, []]) != "RAIN":
		_fail("8 WATER should bring RAIN")
	if Weather.compute([[Weather.voter(["FLYING"], "STORM")], water]) != "STORM":
		_fail("Zapdos (STORM passive) should win over 8 WATER")
	if Weather.compute([[Weather.voter([], "AIRLOCK")], water]) != Weather.NEUTRAL:
		_fail("Rayquaza AIRLOCK should keep the weather neutral")
	var mixed := [Weather.voter(["WATER"], "NONE"), Weather.voter(["FIRE"], "NONE")]
	if Weather.compute([mixed, mixed]) != Weather.NEUTRAL:
		_fail("a weather needs 8 points")
	print("synergy counts and weather ok")


func _check_synergy_effects() -> void:
	var red := [["MACHOP", Vector2i(3, 3)], ["MACHOP", Vector2i(4, 4)], ["MACHOP", Vector2i(2, 5)]]
	# every tier of every synergy runs a whole fight
	var fights := 0
	for type in GameData.config.synergyThresholds:
		var units := []
		for i in 3:
			var pkm := _first_of_type(type, i)
			if pkm != "":
				units.append([pkm, Vector2i(2 + i, 1 + i % 2)])
		if units.is_empty():
			continue
		for tier in range(1, GameData.config.synergyThresholds[type].size() + 1):
			var info := {"active": 4, "dragon_stars": 6, "light": Vector2i(2, 1), "holes": {Vector2i(2, 1): 5, Vector2i(3, 2): 3},
				"wands": GameData.config.fairyWands.map(func(l: Array) -> String: return l[tier % l.size()])}
			var sim := _fight(units, red, {type: tier}, info)
			_run(sim, 50000.0)
			if not sim.finished:
				_fail("%s %d: fight not finished" % [type, tier])
			sim.dispose()
			fights += 1

	# stat buffs when entering the fight
	var sim := _fight([["ABRA", Vector2i(2, 1)], ["MACHOP", Vector2i(4, 1)]], red, {"PSYCHIC": 1, "STEEL": 1, "ICE": 1})
	var abra := sim.board.get_unit(Vector2i(2, 1))
	var machop := sim.board.get_unit(Vector2i(4, 1))
	if abra.ap != 50.0 or machop.ap != 0.0:
		_fail("Psychic 1: +50 AP for PSYCHIC only (%s / %s)" % [abra.ap, machop.ap])
	if machop.def != float(machop.data.def) + 3.0 or machop.spe_def != float(machop.data.speDef) + 4.0:
		_fail("Steel / Ice: +3 DEF and +4 SPE_DEF to the whole team")
	sim.dispose()

	# Normal: shield for itself and its neighbours when the fight starts
	sim = _fight([["LILLIPUP", Vector2i(2, 1)], ["MACHOP", Vector2i(3, 1)], ["MACHOP", Vector2i(6, 1)]], red, {"NORMAL": 1})
	sim.update(10.0)
	if sim.board.get_unit(Vector2i(2, 1)).shield < 15.0 or sim.board.get_unit(Vector2i(3, 1)).shield < 15.0 \
			or sim.board.get_unit(Vector2i(6, 1)).shield > 0.0:
		_fail("Normal 1: 15 shield to itself and adjacent allies only")
	sim.dispose()

	# Fossil: awakens once at 30% HP
	var fossil := _first_of_type("FOSSIL")
	if fossil != "":
		sim = _fight([[fossil, Vector2i(2, 1)]], red, {"FOSSIL": 1})
		var f := sim.board.get_unit(Vector2i(2, 1))
		var atk := f.atk
		sim.deal_damage(f, f.hp - 0.2 * f.max_hp, BattleUnit.DamageKind.TRUE, null)
		if f.shield <= 0.0 or f.atk <= atk or f.synergy_tier("FOSSIL") != 0:
			_fail("Fossil 1: shield and ATK at 30% HP, once")
		sim.dispose()

	# Poison: stacks up to 5 with Toxic (tier 3), 5% max HP per stack every second
	sim = _fight([["WEEDLE", Vector2i(2, 1)]], [["MACHOP", Vector2i(3, 4)]], {"POISON": 3})
	var weedle := sim.board.get_unit(Vector2i(2, 1))
	var target := sim.board.get_unit(Vector2i(3, 4))
	for i in 6:
		sim.add_status(target, "poison", 4000.0, weedle)
	if target.poison_stacks != 5:
		_fail("Toxic: 5 poison stacks max, got %d" % target.poison_stacks)
	var hp := target.hp
	target.tick(1000.0)
	sim._poison_tick(target)
	if hp - target.hp < roundf(target.max_hp * 0.25) - 1.0:
		_fail("poison damage with 5 stacks: %s" % (hp - target.hp))
	sim.dispose()

	# Bug: clones of the strongest bugs join the fight
	sim = _fight([["CATERPIE", Vector2i(2, 1)], ["WEEDLE", Vector2i(4, 1)]], red, {"BUG": 2})
	var events := _run(sim, 100.0)
	if _count(events, "spawn") != 2:
		_fail("Bug 2: 2 clones, got %d" % _count(events, "spawn"))
	sim.dispose()

	# Ghost 4: every curse, Curse of Fate knocks out after 8 s
	var ghosts := [["GASTLY", Vector2i(0, 0)]]
	var tanks := [["AGGRON", Vector2i(0, 5)], ["AGGRON", Vector2i(6, 7)], ["AGGRON", Vector2i(3, 5)], ["AGGRON", Vector2i(5, 5)]]
	if GameData.pokemon.has("AGGRON"):
		sim = _fight(ghosts, tanks, {"GHOST": 4})
		events = _run(sim, 100.0)
		if _count(events, "effect") < 4:
			_fail("Ghost 4: 4 curses, got %d" % _count(events, "effect"))
		var cursed := sim.units.filter(func(u: BattleUnit) -> bool: return u.curses.has("fate"))
		if cursed.is_empty():
			_fail("Curse of Fate not applied")
		else:
			_run(sim, 8500.0)
			if cursed[0].alive and not sim.finished:
				_fail("Curse of Fate should knock out after 8 s")
		sim.dispose()

	# Aquatic: a tidal wave after 7 s
	sim = _fight([["POLIWAG", Vector2i(0, 0)]], [["AGGRON", Vector2i(6, 7)]], {"AQUATIC": 1})
	events = _run(sim, 7500.0)
	if _count(events, "effect", "Tidal Wave!") != 1:
		_fail("Aquatic 1: one tidal wave at 7 s")
	sim.dispose()

	# Light: the Pokémon on the spotlight cell gets +20 AP (and +8 PP/s from tier 2)
	sim = _fight([["MAREEP", Vector2i(2, 1)], ["SHINX", Vector2i(5, 1)]], red, {"LIGHT": 2}, {"light": Vector2i(2, 1)})
	if sim.board.get_unit(Vector2i(2, 1)).ap != 20.0 or sim.board.get_unit(Vector2i(5, 1)).ap != 0.0:
		_fail("Light: +20 AP in the spotlight only")
	sim.dispose()

	# Ground: DEF / SPE_DEF from the hole depth, ATK at max depth
	sim = _fight([["GEODUDE", Vector2i(2, 1)]], red, {"GROUND": 1}, {"holes": {Vector2i(2, 1): 5}})
	var geodude := sim.board.get_unit(Vector2i(2, 1))
	if geodude.def != float(geodude.data.def) + 5.0 or geodude.atk != float(geodude.data.atk) + 3.0:
		_fail("Ground 1 in a hole of depth 5: +5 DEF, +3 ATK (%s / %s)" % [geodude.def, geodude.atk])
	sim.dispose()

	# Fighting blocks flat damage, Rock resists crits, Steel deals true damage
	sim = _fight([["MACHOP", Vector2i(2, 1)], ["ARON", Vector2i(4, 1)]], red, {"FIGHTING": 2, "ROCK": 1, "STEEL": 1})
	var fighter := sim.board.get_unit(Vector2i(2, 1))
	var plain := BattleUnit.create("MACHOP", BattleUnit.Team.BLUE)
	sim.add_unit(plain, Vector2i(6, 1))
	var blocked: float = sim.deal_damage(fighter, 40.0, BattleUnit.DamageKind.TRUE, null).taken
	var physical: float = sim.deal_damage(fighter, 60.0, BattleUnit.DamageKind.PHYSICAL, null).taken
	var physical_plain: float = sim.deal_damage(plain, 60.0, BattleUnit.DamageKind.PHYSICAL, null).taken
	if blocked != 40.0 or physical_plain - physical < 5.0:
		_fail("Fighting 2 blocks 6 non-true damage (%s vs %s)" % [physical, physical_plain])
	if SynergyEffects.crit_reduction(sim.board.get_unit(Vector2i(4, 1))) != 0.7:
		_fail("Rock 1: -30% crit damage")
	if SynergyEffects.steel_true_part(sim.board.get_unit(Vector2i(4, 1))) != 0.33:
		_fail("Steel 1: 33% of the attack as true damage")
	sim.dispose()

	# Flying: flies away under 20% HP with Protect (tier 2)
	sim = _fight([["SPEAROW", Vector2i(3, 2)]], [["AGGRON", Vector2i(3, 3)]], {"FLYING": 2})
	var bird := sim.board.get_unit(Vector2i(3, 2))
	sim.deal_damage(bird, bird.hp - 0.1 * bird.max_hp, BattleUnit.DamageKind.TRUE, sim.board.get_unit(Vector2i(3, 3)))
	if bird.cell == Vector2i(3, 2) or not bird.has_status("protect"):
		_fail("Flying 2: fly away with Protect under 20% HP")
	sim.dispose()

	# Enraged after 35 s: +80 SPEED
	sim = _fight([["AGGRON", Vector2i(0, 0)]], [["AGGRON", Vector2i(6, 7)]])
	var slow := sim.board.get_unit(Vector2i(0, 0))
	var speed := slow.speed
	_run(sim, 35100.0)
	if sim.time_ms >= BattleSim.ENRAGE_MS and slow.alive and (not slow.has_status("enraged") or slow.speed < speed + 79.0):
		_fail("everyone is enraged after 35 s")
	if sim.time_ms < BattleSim.ENRAGE_MS:
		sim.dispose()
		sim = BattleSim.new()
		var lone := BattleUnit.create("AGGRON", BattleUnit.Team.BLUE)
		sim.add_unit(lone, Vector2i(0, 0))
		sim.add_unit(BattleUnit.create("AGGRON", BattleUnit.Team.RED), Vector2i(6, 7))
		lone.statuses["locked"] = 1e9
		sim.board.get_unit(Vector2i(6, 7)).statuses["locked"] = 1e9
		speed = lone.speed
		_run(sim, 35100.0)
		if not lone.has_status("enraged") or lone.speed < speed + 79.0:
			_fail("everyone is enraged after 35 s")
	sim.dispose()

	# Storm: lightning strikes
	sim = _fight([["AGGRON", Vector2i(0, 0)]], [["AGGRON", Vector2i(6, 7)]], {}, {}, "STORM")
	events = _run(sim, 12000.0)
	if _count(events, "lightning") == 0:
		_fail("STORM weather should strike")
	sim.dispose()
	print("synergy effects ok: %d fights (every tier of every synergy)" % fights)


func _check_passives() -> void:
	var red := [["AGGRON", Vector2i(6, 7)]]
	# Mitosis: Reunicluses split into 2 Duosions
	var sim := _fight([["REUNICLUS", Vector2i(3, 1)]], red)
	sim.update(10.0)
	sim.deal_damage(sim.board.get_unit(Vector2i(3, 1)), 9999.0, BattleUnit.DamageKind.TRUE, null)
	var copies := sim.alive_units(BattleUnit.Team.BLUE).filter(func(u: BattleUnit) -> bool: return u.pkm == "DUOSION")
	if copies.size() != 2:
		_fail("Mitosis: 2 Duosion, got %d" % copies.size())
	sim.dispose()

	# Darmanitan: Zen mode under 30% HP, special attacks
	sim = _fight([["DARMANITAN", Vector2i(3, 1)]], red)
	var darm := sim.board.get_unit(Vector2i(3, 1))
	sim.deal_damage(darm, darm.hp - 0.2 * darm.max_hp, BattleUnit.DamageKind.TRUE, null)
	if darm.pkm != "DARMANITAN_ZEN" or not darm.effects.get("special_attacks", false) or darm.ability_id != "TRANSE":
		_fail("Darmanitan should turn into Zen mode, got %s" % darm.pkm)
	darm.pp = darm.max_pp
	AbilityRunner.cast(sim, darm, null)
	if darm.pkm != "DARMANITAN":
		_fail("Transe should turn Zen mode back")
	sim.dispose()

	# Aegislash: King's Shield swaps to Blade forme
	sim = _fight([["AEGISLASH", Vector2i(3, 1)]], red)
	var aegis := sim.board.get_unit(Vector2i(3, 1))
	var atk := aegis.atk
	aegis.pp = aegis.max_pp
	AbilityRunner.cast(sim, aegis, sim.board.get_unit(Vector2i(6, 7)))
	_run(sim, 1600.0)
	if aegis.pkm != "AEGISLASH_BLADE" or aegis.atk != atk + 10.0:
		_fail("Aegislash should be in Blade forme after King's Shield")
	sim.dispose()

	# Gears: +1 SPEED to the team every 3 s (1★)
	sim = _fight([["KLINK", Vector2i(3, 1)], ["MACHOP", Vector2i(4, 1)]], red)
	var ally := sim.board.get_unit(Vector2i(4, 1))
	var speed := ally.speed
	_run(sim, 3100.0)
	if ally.alive and ally.speed < speed + 1.0:
		_fail("Gears: +1 SPEED after 3 s")
	sim.dispose()

	# Slow Start: -30 SPEED
	sim = _fight([["REGIGIGAS", Vector2i(3, 1)]], red)
	var regi := sim.board.get_unit(Vector2i(3, 1))
	if regi.speed != float(regi.data.speed) - 30.0:
		_fail("Slow Start: -30 SPEED")
	sim.dispose()

	# Pickup: an item when holding none
	sim = _fight([["ZIGZAGOON", Vector2i(3, 1)]], red)
	if sim.board.get_unit(Vector2i(3, 1)).items.size() != 1:
		_fail("Pickup should give an item")
	sim.dispose()
	print("passives ok")


func _check_stage_rules() -> void:
	# divergent evolutions
	var p := PlayerState.new()
	for i in 3:
		p.bench[i] = PlayerState.OwnedUnit.new("POLIWHIRL")
	p.check_merges()
	if not p.bench.any(func(u) -> bool: return u != null and u.pkm == "POLITOED"):
		_fail("3 Poliwhirl on the bench should become Politoed")
	p = PlayerState.new()
	p.board[Vector2i(3, 3)] = PlayerState.OwnedUnit.new("POLIWHIRL")
	p.bench[0] = PlayerState.OwnedUnit.new("POLIWHIRL")
	p.bench[1] = PlayerState.OwnedUnit.new("POLIWHIRL")
	p.check_merges()
	if p.board.get(Vector2i(3, 3)) == null or p.board[Vector2i(3, 3)].pkm != "POLIWRATH":
		_fail("a Poliwhirl on the front row should make Poliwrath")
	p = PlayerState.new()
	for i in 3:
		p.bench[i] = PlayerState.OwnedUnit.new("FLABEBE_BLUE")
	p.check_merges()
	if not p.bench.any(func(u) -> bool: return u != null and u.pkm == "FLOETTE_BLUE"):
		_fail("blue Flabébé should keep its color")

	# pillars: built by Timburr, no team slot, cannot be sold
	p = PlayerState.new()
	p.board[Vector2i(0, 0)] = PlayerState.OwnedUnit.new("TIMBURR")
	p.update_pillars()
	var pillars := p.board.values().filter(func(u) -> bool: return u.pkm == "PILLAR_WOOD")
	if pillars.size() != 1 or p.team_count() != 1:
		_fail("Timburr should build 1 wood pillar outside the team size")
	elif true:
		var gold := p.gold
		p.sell(pillars[0])
		if p.gold != gold or p.find(pillars[0]).is_empty():
			_fail("pillars cannot be sold")
	p.move_unit(p.board[Vector2i(0, 0)], {"bench": 0})
	if p.board.values().any(func(u) -> bool: return u.pkm == "PILLAR_WOOD"):
		_fail("pillars leave with their builder")

	# ground: dig, buried items at max depth
	p = PlayerState.new()
	p.board[Vector2i(1, 1)] = PlayerState.OwnedUnit.new("GEODUDE")
	p.board[Vector2i(2, 1)] = PlayerState.OwnedUnit.new("SWINUB")
	p.ground_holes[Vector2i(1, 1)] = 4
	p.buried_items[Vector2i(1, 1)] = "BIG_NUGGET"
	var gold_before := p.gold
	p.stage = 2
	var messages := p.start_stage()
	if p.ground_holes.get(Vector2i(1, 1)) != 5 or p.ground_holes.get(Vector2i(2, 1)) != 1 or p.gold != gold_before + 10:
		_fail("ground dig: %s, gold +%d, %s" % [p.ground_holes, p.gold - gold_before, messages])

	# additional families join the shop at stage 5
	p = PlayerState.new()
	p.stage = 5
	var stage5 := p.start_stage()
	var joined := p.unlocked_additional.keys()
	if joined.is_empty() or not joined.all(func(pkm: String) -> bool: return GameData.get_pokemon(pkm).rarity == "UNCOMMON"):
		_fail("stage 5 should add the uncommon additional families: %s" % [joined])
	# ... told with ONE short line (not one per Pokémon); the list is kept for the "!" of the shop
	if stage5.size() != 1 or stage5[0].length() > 70:
		_fail("stage 5 messages should be one short line: %s" % [stage5])
	if p.pool_news.size() != 1 or p.pool_news[0].pokemons.size() != joined.size() or not p.pool_news_unread \
			or p.pool_news[0].stage != 5 or p.pool_news[0].rarity != "UNCOMMON":
		_fail("pool news of stage 5: %s" % [p.pool_news])
	var rare: Array = GameData.additional_tier1_by_rarity["RARE"]
	p.unlock_additional(rare[0])
	if not p.unlocked_additional.has(rare[0]) or p.pool_news.size() != 2 or not p.pool_news[1].pick \
			or p.pool_news[1].pokemons.size() != 1 or p.pool_news[1].pokemons[0] != rare[0]:
		_fail("a town pick joins the pool and the list: %s" % [p.pool_news])
	p.unlock_additional(rare[0])
	if p.pool_news.size() != 2:
		_fail("picking a family twice should not add news: %s" % [p.pool_news])
	var pool_tip := Tooltips.pool(p)
	add_child(pool_tip)
	var portraits := pool_tip.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is SynergyMember).size()
	if portraits < joined.size() + 1:
		_fail("pool tip shows %d portraits, %d Pokémon joined" % [portraits, joined.size() + 1])
	pool_tip.queue_free()
	if not PlayerState.new().shop_candidates("UNCOMMON").all(func(pkm: String) -> bool: return not GameData.additional.has(pkm)):
		_fail("additional families should not be in the shop before their stage")

	# WILD Pokémon only with the wild chance (none outside PvE stages without WILD)
	p = PlayerState.new()
	p.stage = 4
	p.level = 5
	var wild_seen := 0
	for i in 60:
		p.roll_shop()
		for pkm in p.shop:
			if pkm != "" and GameData.get_pokemon(pkm).types.has("WILD"):
				wild_seen += 1
	if wild_seen > 0:
		_fail("WILD Pokémon in the shop at stage 4 without the synergy: %d" % wild_seen)
	if FightSetup.weather_for(p, EndlessWaves.get_stage(4, 1)) == "":
		_fail("weather preview")

	# Fairy wands: a choice per level
	p = PlayerState.new()
	p.board[Vector2i(1, 1)] = PlayerState.OwnedUnit.new("AZURILL")
	p.board[Vector2i(2, 1)] = PlayerState.OwnedUnit.new("TOGEPI")
	var options := p.pending_wand_choice()
	if options.size() != 3:
		_fail("Fairy 1 should offer 3 wands, got %s" % [options])
	else:
		p.choose_wand(options[0])
		if p.active_wands() != ([options[0]] as Array[String]) or not p.pending_wand_choice().is_empty():
			_fail("wand choice: %s" % [p.active_wands()])

	# Fur Coat grows on the board, groomed on the bench
	p = PlayerState.new()
	var wooloo := PlayerState.OwnedUnit.new("WOOLOO")
	p.board[Vector2i(1, 1)] = wooloo
	p.start_stage()
	p.start_stage()
	if wooloo.stacks != 2:
		_fail("Fur Coat stacks on the board: %d" % wooloo.stacks)
	var fight := FightSetup.create(p, EndlessWaves.get_stage(4, 1))
	var coated: BattleUnit = fight.owned[wooloo.id]
	if coated.def != float(wooloo.data().def) + 4.0:
		_fail("Fur Coat: +2 DEF per stage")
	fight.sim.dispose()
	p.move_unit(wooloo, {"bench": 0})
	p.start_stage()
	if wooloo.stacks != 0:
		_fail("Fur Coat groomed on the bench")
	print("stage rules ok")


## Town phase: portals, propositions, carousel, additional picks, encounters (Phase 5).
func _check_town() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var p := PlayerState.new()
	p.stage = 0
	var begin := Town.begin_stage(p, rng)
	if begin.choices.size() != 1 or begin.choices[0].kind != "portal" or begin.choices[0].portals.size() != 3:
		_fail("stage 0 should offer 3 portals: %s" % [begin.choices])
	else:
		var portal: Dictionary = begin.choices[0].portals[0]
		if portal.synergies.size() != 2 or portal.map == "":
			_fail("portal: 2 synergies and a region, got %s" % [portal])
		var offer := Town.propositions(p, 0, portal.synergies, rng)
		var families := {}
		for pkm in offer.pokemons:
			families[GameData.get_pokemon(pkm).family] = true
			if GameData.get_pokemon(pkm).rarity != "COMMON":
				_fail("starter %s is not common" % pkm)
		if offer.pokemons.size() != 3 or offer.items.size() != 3 or families.size() != 3:
			_fail("3 starters of 3 families with a component each: %s" % [offer])
	var uniques := Town.propositions(p, 10, [], rng)
	if uniques.category != "unique" or uniques.pokemons.is_empty() or not uniques.pokemons.all(func(u: String) -> bool:
			return Array(u.split("+")).all(func(m: String) -> bool: return GameData.unique.has(m))): # duos: "A+B"
		_fail("stage 10 offers Uniques: %s" % [uniques.pokemons])
	var legends := Town.propositions(p, 20, ["FLYING"], rng)
	if legends.pokemons.size() != 6 or not GameData.get_pokemon(legends.pokemons[0]).types.has("FLYING"):
		_fail("stage 20 offers 6 Legendaries, the first one FLYING: %s" % [legends.pokemons])

	var carousel := Town.carousel(p, 4, "", rng)
	if carousel.items.size() != 5 or not carousel.items.all(func(i: String) -> bool: return GameData.is_component(i)):
		_fail("carousel of stage 4: 5 components, got %s" % [carousel.items])
	var late := Town.carousel(p, 22, "", rng)
	if late.items.size() != 6 or late.items.any(func(i: String) -> bool: return GameData.is_component(i)):
		_fail("carousel from stage 20: 6 full items, got %s" % [late.items])
	if Town.carousel(p, 12, "KANGASKHAN", rng).cost != 10:
		_fail("Kangaskhan sells its items")
	if Town.carousel(p, 12, "SABLEYE", rng).items.filter(func(i: String) -> bool: return GameData.item_in(i, "SynergyGems")).size() != 4:
		_fail("Sableye brings 4 gems")
	var pick := Town.additional_pick(5, rng)
	if pick.pokemons.is_empty() or not pick.pokemons.all(func(u: String) -> bool:
			return GameData.additional.has(u) and GameData.get_pokemon(u).rarity == "UNCOMMON"):
		_fail("additional pick of stage 5: %s" % [pick.pokemons])
	var seen := {}
	var met := {}
	for i in 400:
		var e := Town.pick_encounter(12, rng, seen)
		if e != "":
			met[e] = true
			seen.clear()
	if met.keys().any(func(e: String) -> bool: return not Town.PORTED_ENCOUNTERS.has(e)):
		_fail("only ported encounters: %s" % [met.keys()])

	# encounters and town items
	p = PlayerState.new()
	p.town_encounter = "REGIROCK"
	Town._apply_encounter(p)
	if p.life != PlayerState.START_LIFE + Town.REGIROCK_LIFE:
		_fail("Regirock: +15 life")
	var marowak := 0
	for stage in GameData.pve_stages:
		var w := EndlessWaves.get_stage(stage, 1)
		if EndlessWaves.held_items(w, "").any(func(l: Array) -> bool: return not l.is_empty()):
			_fail("boss of stage %d holds items without Marowak" % stage)
		marowak += EndlessWaves.held_items(w, "MAROWAK").filter(func(l: Array) -> bool: return not l.is_empty()).size()
	if marowak == 0:
		_fail("Marowak should give items to the bosses")
	p.treasure_reward = "itemComponents"
	p.items.assign(["TREASURE_BOX"])
	p.life = 30
	p.start_stage()
	if p.items.has("TREASURE_BOX") or p.items.size() != 4:
		_fail("Treasure Box at 30 life: 4 components, got %s" % [p.items])
	p.items.clear()
	var gold := p.gold
	p.take_town_item("GIMMIGHOUL_COIN")
	p.take_town_item("FIRE_GEM")
	if p.gold != gold + 5 or p.max_interest() != 6 or Synergies.count_player(p).get("FIRE", 0) != 1:
		_fail("Gimmighoul Coin (+5 gold, +1 max interest) and Fire Gem (+1 FIRE)")
	p.board[Vector2i(0, 0)] = PlayerState.OwnedUnit.new("KYOGRE")
	if p.equip(p.items.find("FIRE_GEM"), p.board[Vector2i(0, 0)]).ok:
		_fail("gems cannot be held")
	p.items.append("BLUE_ORB")
	p.equip(p.items.find("BLUE_ORB"), p.board[Vector2i(0, 0)])
	if p.board[Vector2i(0, 0)].pkm != "PRIMAL_KYOGRE":
		_fail("Kyogre + Blue Orb should become Primal Kyogre")
	# Item Remover: everything back to the item bench but the orb of the Primal form
	var primal: PlayerState.OwnedUnit = p.board[Vector2i(0, 0)]
	primal.items.append_array(["CHARCOAL", "SHELL_BELL"])
	var bench_before := p.items.size()
	if not p.strip_preview(primal).ok or p.strip_items(primal).size() != 2:
		_fail("Item Remover takes the 2 items off")
	if primal.items != ["BLUE_ORB"] or p.items.size() != bench_before + 2 or not p.items.has("SHELL_BELL"):
		_fail("Item Remover: Primal Kyogre keeps its Blue Orb, the others go to the bench: %s" % [primal.items])
	if p.strip_preview(primal).ok:
		_fail("Item Remover on a Pokémon with nothing to remove")
	var plain := PlayerState.OwnedUnit.new("CHARMANDER")
	plain.items.assign(["MAGNET", "CHARCOAL", "RED_ORB"])
	if p.strip_items(plain).size() != 3 or not plain.items.is_empty():
		_fail("Item Remover takes every item")
	var q := PlayerState.new()
	var arceus := PlayerState.OwnedUnit.new("ARCEUS")
	q.board[Vector2i(0, 0)] = arceus
	for i in 3:
		q.board[Vector2i(1 + i, 0)] = PlayerState.OwnedUnit.new(["CHARMANDER", "FENNEKIN", "CYNDAQUIL"][i])
	var dynamic := Synergies.dynamic_types(q)
	if not dynamic.get(arceus.id, []).has("FIRE") or Synergies.count_player(q).get("FIRE", 0) != 4:
		_fail("Arceus should take the top synergies: %s" % [dynamic])
	for i in p.bench_size:
		p.bench[i] = PlayerState.OwnedUnit.new("MACHOP")
	gold = p.gold
	if p.give_pokemon("MEWTWO") != "sold" or p.gold <= gold:
		_fail("a Pokémon given with a full bench is sold")
	print("town ok: portals %s, e.g. %s" % [begin.choices[0].portals.map(func(x: Dictionary) -> String: return x.map),
		legends.pokemons])
#endregion


#region synergy items (Gourmet, Grass...)
## Town encounters of mini-game.ts and their items.
func _check_town_items() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var p := PlayerState.new()
	p.board[Vector2i(3, 0)] = PlayerState.OwnedUnit.new("CHARMANDER")
	p.board[Vector2i(4, 0)] = PlayerState.OwnedUnit.new("SQUIRTLE")
	p._board_changed()
	var meowth := Town.carousel(p, 4, "MEOWTH", rng)
	if meowth.items.count("AMULET_COIN") != 4:
		_fail("Meowth: 4 Amulet Coins in the carousel")
	var elec := Town.carousel(p, 12, "ELECTIVIRE", rng)
	if not elec.items.all(func(i: String) -> bool: return GameData.item_in(i, "Tools")) or elec.cost != 10:
		_fail("Electivire sells tools for 10 gold: %s" % [elec])
	var ludicolo := Town.carousel(p, 4, "LUDICOLO", rng)
	if not ludicolo.items.has("AQUA_MONICA"):
		_fail("Ludicolo brings the seven treasures")
	var chansey := Town.carousel(p, 4, "CHANSEY", rng)
	if chansey.items != ["EGG_FOR_SELL"]:
		_fail("Chansey sells an egg: %s" % [chansey.items])
	p.take_town_item("EGG_FOR_SELL")
	if not p.bench.any(func(u) -> bool: return u != null and u.pkm == "EGG"):
		_fail("the egg bought from Chansey is on the bench")
	# Soothe Bell: the shop is rolled again with the types of the Pokémon
	p.items.append("SOOTHE_BELL")
	var charm: PlayerState.OwnedUnit = p.board[Vector2i(3, 0)]
	if not p.equip(p.items.find("SOOTHE_BELL"), charm).ok or p.items.has("SOOTHE_BELL"):
		_fail("Soothe Bell used on a Pokémon")
	var charm_types := charm.types()
	if not p.shop.all(func(pkm: String) -> bool: return pkm == "" \
			or GameData.get_pokemon(pkm).types.any(func(t: String) -> bool: return charm_types.has(t))):
		_fail("Soothe Bell: shop of its types %s %s" % [charm_types, p.shop])
	# Picnic Set: a Sandwich for it and its neighbours
	p.items.append("PICNIC_SET")
	p.equip(p.items.find("PICNIC_SET"), charm)
	if not charm.dishes.has("SANDWICH") or not p.board[Vector2i(4, 0)].dishes.has("SANDWICH"):
		_fail("Picnic Set: sandwiches for neighbours")
	# Recycle Ticket: full items fall apart
	var squirtle: PlayerState.OwnedUnit = p.board[Vector2i(4, 0)]
	var full: String = GameData.full_items.filter(func(i: String) -> bool: return not GameData.recipe_of(i).is_empty())[0]
	squirtle.items.append(full)
	var recipe := GameData.recipe_of(full)
	p.items.append("RECYCLE_TICKET")
	var before := p.items.size()
	p.equip(p.items.find("RECYCLE_TICKET"), squirtle)
	if squirtle.items.has(full) or p.items.size() != before - 1 + recipe.size():
		_fail("Recycle Ticket splits held items: %s" % [p.items])
	# Exchange Ticket on a component of the item bench
	p.items.assign(["EXCHANGE_TICKET", "CHARCOAL"])
	var ex := p.use_ticket(0, 1)
	if not ex.ok or p.items.size() != 1 or p.items[0] == "CHARCOAL" or not GameData.is_component(p.items[0]):
		_fail("Exchange Ticket: another component %s" % [p.items])
	# Makuhita: a Dojo ticket sends a Pokémon away for 3 stages, a Substitute holds its items
	var d := PlayerState.new()
	var pika := PlayerState.OwnedUnit.new("PIKACHU")
	pika.items.append("CHARCOAL")
	d.board[Vector2i(2, 0)] = pika
	d.items.append("BRONZE_DOJO_TICKET")
	d.stage = 5
	d.equip(d.items.find("BRONZE_DOJO_TICKET"), pika)
	if d.board[Vector2i(2, 0)].pkm != "SUBSTITUTE" or not d.board[Vector2i(2, 0)].items.has("CHARCOAL"):
		_fail("Dojo: a Substitute takes the place")
	d.stage = 8
	d._town_items_stage()
	var back: PlayerState.OwnedUnit = d.board[Vector2i(2, 0)]
	if back != pika or float(pika.mods.get("atk", 0.0)) != 5.0 or not pika.items.has("CHARCOAL"):
		_fail("Dojo: back after 3 stages with +5 ATK (%s %s)" % [back.pkm, pika.mods])
	# Wigglytuff: mission orders pay 30 gold once done
	d.items.append("MISSION_ORDER_BLUE")
	d.level = 9
	var gold := d.gold
	d.check_missions()
	if d.items.has("MISSION_ORDER_BLUE") or d.gold != gold + 30:
		_fail("Blue mission order: level 9 = +30 gold")
	# Magnezone: the outlaw runs across at its stage (a wanderer); clicked = caught, +10 gold
	d.items.append("WANTED_NOTICE")
	d.outlaw_stage = 9
	d.stage = 9
	gold = d.gold
	d.wanderers.clear()
	d._town_items_stage()
	var outlaws := d.wanderers.filter(func(w: Dictionary) -> bool: return w.kind == "outlaw")
	if outlaws.size() != 1 or outlaws[0].pkm != "DROWZEE":
		_fail("Wanted Notice: the outlaw shows up at its stage (%s)" % [d.wanderers])
	elif not d.catch_wanderer(outlaws[0]) or d.items.has("WANTED_NOTICE") or d.gold != gold + 10:
		_fail("Wanted Notice: +10 gold when the outlaw is caught")
	# Lapras: the passport changes the region
	d.items.append("LAPRAS_PASSPORT")
	var old_map := d.map
	d.equip(d.items.find("LAPRAS_PASSPORT"), pika)
	if d.map == old_map or d.map == "town":
		_fail("Lapras Passport: another region")
	print("town items ok")


## Golden egg items (ShinyItems): stats in the fight, Rare Candy / Eviolite / Gold Bow rules.
func _check_shiny_items() -> void:
	var u := BattleUnit.create("CHARMANDER", BattleUnit.Team.BLUE)
	var base_hp := u.max_hp
	u.equip(["DYNAMAX_BAND", "STAR_PIECE", "SACRED_ASH"])
	if u.max_hp != base_hp + 2.0 * u.base_hp or u.stars != 2 or not u.effects.get("resurrection", false):
		_fail("Dynamax Band / Star Piece / Sacred Ash: %s hp, %d stars" % [u.max_hp, u.stars])
	var p := PlayerState.new()
	var charm := PlayerState.OwnedUnit.new("CHARMANDER")
	p.board[Vector2i(3, 0)] = charm
	p.items.append("RARE_CANDY")
	var r := p.equip(p.items.find("RARE_CANDY"), charm)
	if not r.ok or charm.pkm != "CHARMELEON" or not charm.items.has("RARE_CANDY"):
		_fail("Rare Candy evolves at once: %s %s" % [r, charm.pkm])
	var mega := PlayerState.OwnedUnit.new("CHARIZARD")
	p.board[Vector2i(4, 0)] = mega
	p.items.append("EVIOLITE")
	if p.equip_preview(p.items.find("EVIOLITE"), mega).ok:
		_fail("Eviolite needs an evolution")
	# Eviolite: the 3 copies do not merge
	var q := PlayerState.new()
	q.merge_board = true
	for i in 3:
		q.bench[i] = PlayerState.OwnedUnit.new("SQUIRTLE")
	q.bench[0].items.append("EVIOLITE")
	if not q.check_merges().is_empty():
		_fail("Eviolite: no merge")
	# Gold Bow: does not count in the team size
	q.board[Vector2i(3, 0)] = PlayerState.OwnedUnit.new("PIKACHU")
	q.board[Vector2i(3, 0)].items.append("GOLD_BOW")
	if q.team_count() != 0:
		_fail("Gold Bow: free team slot")
	# Absorb Bulb: the damage stopped by DEF bursts on the adjacent enemies under 50% HP
	var sim := BattleSim.new()
	var bulb := BattleUnit.create("GEODUDE", BattleUnit.Team.BLUE)
	bulb.equip(["ABSORB_BULB"])
	var foe := BattleUnit.create("MACHAMP", BattleUnit.Team.RED)
	sim.add_unit(bulb, Vector2i(3, 2))
	sim.add_unit(foe, Vector2i(3, 3))
	var foe_hp := foe.hp
	for _i in 10:
		if bulb.has_item("ABSORB_BULB") and bulb.alive:
			sim.deal_damage(bulb, bulb.max_hp * 0.3, BattleUnit.DamageKind.PHYSICAL, foe)
	if bulb.has_item("ABSORB_BULB") or foe.hp >= foe_hp:
		_fail("Absorb Bulb bursts under 50%% HP (%s -> %s)" % [foe_hp, foe.hp])
	sim.dispose()
	# Gold Mask: Pokémon sharing a type join the fight
	var sim2 := BattleSim.new()
	var masked := BattleUnit.create("CHARMANDER", BattleUnit.Team.BLUE)
	masked.equip(["GOLD_MASK"])
	sim2.add_unit(masked, Vector2i(3, 1))
	sim2.add_unit(BattleUnit.create("MACHAMP", BattleUnit.Team.RED), Vector2i(3, 5))
	sim2.update(50.0)
	if sim2.alive_units(BattleUnit.Team.BLUE).size() != 4:
		_fail("Gold Mask: 3 spawns (%d units)" % sim2.alive_units(BattleUnit.Team.BLUE).size())
	sim2.dispose()
	# Eevee: Fossil Stone + Mystic Water = Water Stone -> Vaporeon
	var e := PlayerState.new()
	var eevee := PlayerState.OwnedUnit.new("EEVEE")
	e.board[Vector2i(3, 0)] = eevee
	e.items.append("FOSSIL_STONE")
	e.equip(e.items.find("FOSSIL_STONE"), eevee)
	e.items.append("MYSTIC_WATER")
	var er := e.equip(e.items.find("MYSTIC_WATER"), eevee)
	if eevee.pkm != "VAPOREON" or not eevee.items.has("WATER_STONE"):
		_fail("Eevee + Water Stone -> Vaporeon: %s %s %s" % [er, eevee.pkm, eevee.items])
	# Amulet Coin: -1 max interest each
	var before := e.max_interest()
	e.items.append("AMULET_COIN")
	if e.max_interest() != before - 1:
		_fail("Amulet Coin lowers the max interest")
	print("shiny items ok")


func _check_synergy_items() -> void:
	# Gourmet 3: one Chef Hat, only a Gourmet Pokémon can wear it
	var p := PlayerState.new()
	p.board[Vector2i(3, 0)] = PlayerState.OwnedUnit.new("LICKITUNG")
	p.board[Vector2i(4, 0)] = PlayerState.OwnedUnit.new("SMOLIV")
	p.board[Vector2i(2, 0)] = PlayerState.OwnedUnit.new("NACLI")
	p.board[Vector2i(3, 1)] = PlayerState.OwnedUnit.new("CHARMANDER")
	p._board_changed()
	if p.items.count("CHEF_HAT") != 1:
		_fail("Gourmet 3 gives 1 Chef Hat: %s" % [p.items])
	var hat := p.items.find("CHEF_HAT")
	if p.equip_preview(hat, p.board[Vector2i(3, 1)]).ok or not p.equip(hat, p.board[Vector2i(3, 0)]).ok:
		_fail("Chef Hat: Gourmet only")
	# the chef (Lickitung) cooks a Rage Candy Bar for the strongest hungry neighbour
	p.board[Vector2i(3, 1)].items.assign(["CHARCOAL", "MAGNET"])
	var messages := SynergyItems.cook(p)
	if messages.is_empty() or not p.board[Vector2i(3, 1)].dishes.has("RAGE_CANDY_BAR"):
		_fail("chef cooks for the strongest neighbour: %s" % [messages])
	# eaten dish applies at the next fight, then it is consumed
	var fight := FightSetup.create(p, EndlessWaves.get_stage(1, 7))
	var eater: BattleUnit = fight.owned[p.board[Vector2i(3, 1)].id]
	var plain := BattleUnit.create("CHARMANDER", BattleUnit.Team.BLUE)
	plain.equip(["CHARCOAL", "MAGNET"])
	if eater.atk != plain.atk + 10.0 or not p.board[Vector2i(3, 1)].dishes.is_empty():
		_fail("Rage Candy Bar: +10 ATK in the fight, then consumed (%s vs %s)" % [eater.atk, plain.atk])
	fight.sim.dispose()
	# a dish of the item bench dropped on a Pokémon is eaten (one dish at a time)
	p.items.append("TEA")
	var unit: PlayerState.OwnedUnit = p.board[Vector2i(4, 0)]
	if not p.equip(p.items.find("TEA"), unit).ok or unit.dishes != ["TEA"] or not unit.items.is_empty():
		_fail("Tea eaten, not held")
	p.items.append("CURRY")
	if p.equip_preview(p.items.find("CURRY"), unit).ok:
		_fail("belly full after one dish")
	# Gourmet drops: the hats leave
	p.board.erase(Vector2i(2, 0))
	p._board_changed()
	if p.items.has("CHEF_HAT") or p.board[Vector2i(3, 0)].items.has("CHEF_HAT"):
		_fail("Gourmet inactive: no Chef Hat")

	# Grass 3: one berry tree grows, ripe after 3 stages, pick gives its berry
	var g := PlayerState.new()
	for i in 3:
		g.board[Vector2i(i, 0)] = PlayerState.OwnedUnit.new(["BULBASAUR", "SMOLIV", "BOUNSWEET"][i])
	g.berry_tree_stages.assign([0, 0, 0])
	for _i in 3:
		SynergyItems.grow_berry_trees(g)
	if g.berry_tree_stages != [3, 0, 0]:
		_fail("Grass 3: one tree grows: %s" % [g.berry_tree_stages])
	var berry := SynergyItems.pick_berry(g, 0)
	if berry != g.berry_tree_types[0] or not g.items.has(berry) or g.berry_tree_stages[0] != 0:
		_fail("pick a ripe berry")
	if SynergyItems.pick_berry(g, 1) != "":
		_fail("tree 2 is not growing at Grass 3")
	# a held berry is eaten under 50% HP, for good
	var holder := PlayerState.OwnedUnit.new("CHARMANDER")
	holder.items.assign(["ORAN_BERRY"])
	g.board[Vector2i(4, 0)] = holder
	var gf := FightSetup.create(g, EndlessWaves.get_stage(1, 7))
	var bu: BattleUnit = gf.owned[holder.id]
	gf.sim.deal_damage(bu, bu.max_hp * 0.6, BattleUnit.DamageKind.TRUE, null)
	if bu.items.has("ORAN_BERRY") or holder.items.has("ORAN_BERRY") or bu.shield < 80.0:
		_fail("Oran Berry eaten under 50%% HP (shield %s)" % bu.shield)
	var golden := BattleUnit.create("CHARMANDER", BattleUnit.Team.BLUE)
	golden.equip(["GOLDEN_NANAB_BERRY"])
	gf.sim.add_unit(golden, Vector2i(6, 0))
	SynergyItems.eat_berry(gf.sim, golden, "GOLDEN_NANAB_BERRY")
	if gf.sim.rewards.gold != 5:
		_fail("Golden Nanab Berry: +5 gold after the fight")
	gf.sim.dispose()
	# Water: the rod of the tier in the item bench, a fish each stage onto the bench
	var w := PlayerState.new()
	for i in 3:
		w.board[Vector2i(i, 0)] = PlayerState.OwnedUnit.new(["SQUIRTLE", "TOTODILE", "POLIWAG"][i])
	w._board_changed()
	if not w.items.has("OLD_ROD") or w.items.has("GOOD_ROD"):
		_fail("Water 3: Old Rod: %s" % [w.items])
	w.stage = 5
	var fished := SynergyItems.fish(w)
	if fished == "" or w.bench.filter(func(b) -> bool: return b != null).size() != 1:
		_fail("a fish on the bench: %s" % fished)
	w.stage = 10 # stage 9 is an original PvE stage: no fishing after it
	if SynergyItems.fish(w) != "":
		_fail("no fishing right after a PvE stage")
	# 8 Magikarp -> Gyarados (merge count of the rule)
	var m := PlayerState.new()
	for i in 7:
		m.bench[i] = PlayerState.OwnedUnit.new("MAGIKARP")
	m.check_merges()
	if m.bench.filter(func(b) -> bool: return b != null and b.pkm == "MAGIKARP").size() != 7:
		_fail("7 Magikarp do not merge")
	m.bench.append(PlayerState.OwnedUnit.new("MAGIKARP"))
	m.check_merges()
	m._compact_overflow()
	if not (m.bench + m.board.values()).any(func(b) -> bool: return b != null and b.pkm == "GYARADOS"):
		_fail("8 Magikarp -> Gyarados")
	# Normal 3: one Silk Scarf; the scarf crafted with it comes back when Normal is lost and found again
	var n := PlayerState.new()
	for i in 3:
		n.board[Vector2i(i, 0)] = PlayerState.OwnedUnit.new(["RATTATA", "PIDGEY", "SENTRET"][i])
	n._board_changed()
	if n.items.count("SILK_SCARF") != 1:
		_fail("Normal 3: one Silk Scarf: %s" % [n.items])
	var holder2: PlayerState.OwnedUnit = n.board[Vector2i(0, 0)]
	holder2.items.assign(["MAGNET"])
	n.equip(n.items.find("SILK_SCARF"), holder2)
	if not holder2.items.has("MACH_RIBBON") or n.scarves_items != ["MACH_RIBBON"]:
		_fail("Silk Scarf + Magnet = Mach Ribbon (remembered): %s %s" % [holder2.items, n.scarves_items])
	var sentret: PlayerState.OwnedUnit = n.board[Vector2i(2, 0)]
	n.board.erase(Vector2i(2, 0))
	n._board_changed()
	if holder2.items.has("MACH_RIBBON"):
		_fail("Normal lost: the Mach Ribbon leaves")
	n.board[Vector2i(2, 0)] = sentret
	n._board_changed()
	if not n.items.has("MACH_RIBBON"):
		_fail("Normal back: the Mach Ribbon comes back: %s" % [n.items])
	# scarves in a fight: Nullify Bandanna cannot cast, Cover Band takes the killing blow
	var nb := BattleUnit.create("CHARMANDER", BattleUnit.Team.BLUE)
	nb.equip(["NULLIFY_BANDANNA"])
	nb.pp = nb.max_pp
	if nb.can_cast():
		_fail("Nullify Bandanna: no cast")
	var cs := _fight([["CHARMANDER", Vector2i(3, 1)], ["SQUIRTLE", Vector2i(4, 1)]], [["BULBASAUR", Vector2i(3, 4)]])
	var weak: BattleUnit = cs.board.get_unit(Vector2i(3, 1))
	var coverer: BattleUnit = cs.board.get_unit(Vector2i(4, 1))
	coverer.equip(["COVER_BAND"])
	var cover_hp := coverer.hp
	cs.deal_damage(weak, weak.hp + 5.0, BattleUnit.DamageKind.TRUE, null)
	if not weak.alive or coverer.hp >= cover_hp:
		_fail("Cover Band: the adjacent ally takes the killing blow")
	cs.dispose()
	# Artificial 2: the first tool of the run; lost when the tier drops
	var a := PlayerState.new()
	var artificial := GameData.pool.filter(func(pkm: String) -> bool:
		return GameData.get_pokemon(pkm).types.has("ARTIFICIAL") and int(GameData.get_pokemon(pkm).stars) == 1)
	var needed := int(GameData.config.synergyThresholds.ARTIFICIAL[0])
	for i in needed:
		a.board[Vector2i(i, 0)] = PlayerState.OwnedUnit.new(artificial[i])
	a._board_changed()
	if not a.items.has(a.artificial_items[0]):
		_fail("Artificial: first tool %s given: %s" % [a.artificial_items[0], a.items])
	a.board.erase(Vector2i(0, 0))
	a._board_changed()
	if a.items.has(a.artificial_items[0]):
		_fail("Artificial lost: tool taken back")
	# Human 2: the bronze TM teaches a Human Pokémon; back to the item bench on the bench
	var h := PlayerState.new()
	var humans := GameData.pool.filter(func(pkm: String) -> bool:
		return GameData.get_pokemon(pkm).types.has("HUMAN") and int(GameData.get_pokemon(pkm).stars) == 1)
	for i in int(GameData.config.synergyThresholds.HUMAN[0]) + 1: # one more: the tier stays when one goes to the bench
		h.board[Vector2i(i, 0)] = PlayerState.OwnedUnit.new(humans[i])
	h._board_changed()
	var tm := h.tms[0]
	if not h.items.has(tm):
		_fail("Human: first TM %s given" % tm)
	var student: PlayerState.OwnedUnit = h.board[Vector2i(0, 0)]
	if not h.equip(h.items.find(tm), student).ok or student.skill() != SynergyItems.tm_ability(tm) or h.items.has(tm):
		_fail("TM teaches %s: %s" % [tm, student.skill()])
	var tf := FightSetup.create(h, EndlessWaves.get_stage(1, 7))
	if tf.owned[student.id].ability_id != SynergyItems.tm_ability(tm):
		_fail("TM ability used in fights")
	tf.sim.dispose()
	h.move_unit(student, {"bench": 0})
	if student.tm != "" or not h.items.has(tm):
		_fail("moved to the bench: the TM comes back")
	# Fire Shard: +3 ATK / SPEED for good on a Fire Pokémon, 3 life
	var f := PlayerState.new()
	var fire_unit := PlayerState.OwnedUnit.new("CHARMANDER")
	f.board[Vector2i(0, 0)] = fire_unit
	f.items.append("FIRE_SHARD")
	var life_before := f.life
	if not f.equip(f.items.find("FIRE_SHARD"), fire_unit).ok or f.life != life_before - 3 or float(fire_unit.mods.get("atk", 0)) != 3.0:
		_fail("Fire Shard")
	# Aquatic 4: a surfing Pikachu joins with the first tidal wave
	var aq := _fight([["CHARMANDER", Vector2i(3, 1)]], [["BULBASAUR", Vector2i(3, 4)]], {"AQUATIC": 4})
	var before := aq.units.size()
	_run(aq, 7500.0)
	if not aq.units.any(func(u: BattleUnit) -> bool: return u.pkm == "PIKACHU_SURFER") or aq.units.size() <= before:
		_fail("Aquatic 4: surfing Pikachu")
	aq.dispose()
	# Baby 2: an egg after a lost fight, hatching after 4 fights into a 1-star HATCH Pokémon
	var b := PlayerState.new()
	var babies := GameData.pool.filter(func(pkm: String) -> bool:
		return GameData.get_pokemon(pkm).types.has("BABY") and int(GameData.get_pokemon(pkm).stars) == 1)
	for i in int(GameData.config.synergyThresholds.BABY[1]):
		b.board[Vector2i(i, 0)] = PlayerState.OwnedUnit.new(babies[i % babies.size()])
	SynergyItems.after_fight(b, true)
	var egg: PlayerState.OwnedUnit = null
	for u in b.bench:
		if u != null and u.pkm == "EGG":
			egg = u
	if egg == null or egg.hatch_into == "":
		_fail("Baby 2: an egg after a defeat")
	elif b.can_place(egg, {"board": Vector2i(5, 1)}):
		_fail("an egg cannot go on the board")
	else:
		for _i in 4:
			SynergyItems.after_fight(b, false)
		if egg.pkm == "EGG" or not GameData.hatch.has(egg.pkm):
			_fail("egg hatched after 4 fights (Baby 2): %s" % egg.pkm)
	# Flora 1: the pink pot blossoms when a Flora Pokémon faints; mulch grows a pot
	var fl := PlayerState.new()
	var floras := GameData.pool.filter(func(pkm: String) -> bool:
		return GameData.get_pokemon(pkm).types.has("FLORA") and int(GameData.get_pokemon(pkm).stars) == 1)
	for i in int(GameData.config.synergyThresholds.FLORA[0]):
		fl.board[Vector2i(i, 0)] = PlayerState.OwnedUnit.new(floras[i])
	if SynergyItems.pots_unlocked(fl) != [0]:
		_fail("Flora 1: pink pot only: %s" % [SynergyItems.pots_unlocked(fl)])
	var ff := FightSetup.create(fl, EndlessWaves.get_stage(1, 7))
	var dying: BattleUnit = ff.owned[fl.board[Vector2i(0, 0)].id]
	ff.sim.deal_damage(dying, dying.hp + dying.shield + 10.0, BattleUnit.DamageKind.TRUE, null)
	if not ff.sim.units.any(func(u: BattleUnit) -> bool: return u.pkm == "HOPPIP"):
		_fail("Flora: the pink pot blossoms (Hoppip)")
	fl.collect_fight_rewards(ff.sim.rewards)
	ff.sim.dispose()
	fl.items.append("RICH_MULCH")
	if SynergyItems.use_mulch(fl, fl.items.find("RICH_MULCH"), {"pot": 0}) == "" or fl.flower_pots[0] != "SKIPLOOM":
		_fail("Rich Mulch grows the pink pot: %s" % fl.flower_pots[0])
	# Psychic 3: the stage shop is all Unowns; an Unown casting its Hidden Power is used up
	var ps := PlayerState.new()
	var psychics := GameData.pool.filter(func(pkm: String) -> bool:
		return GameData.get_pokemon(pkm).types.has("PSYCHIC") and int(GameData.get_pokemon(pkm).stars) == 1)
	for i in int(GameData.config.synergyThresholds.PSYCHIC[2]):
		ps.board[Vector2i(i % 8, i / 8)] = PlayerState.OwnedUnit.new(psychics[i % psychics.size()])
	ps.stage = 5
	ps.roll_shop()
	if not ps.shop.all(func(pkm: String) -> bool: return pkm.begins_with("UNOWN")):
		_fail("Psychic 3: Unown shop: %s" % [ps.shop])
	var unown := PlayerState.OwnedUnit.new("UNOWN_G")
	ps.board.clear()
	ps.board[Vector2i(3, 1)] = unown
	var uf := FightSetup.create(ps, EndlessWaves.get_stage(5, 7))
	var ub: BattleUnit = uf.owned[unown.id]
	ub.pp = ub.max_pp
	AbilityRunner.cast(uf.sim, ub, null)
	if ub.alive or ps.board.has(Vector2i(3, 1)) or uf.sim.rewards.gold != 5:
		_fail("Hidden Power G: +5 gold, the Unown is used up")
	uf.sim.dispose()
	print("synergy items ok: Gourmet, Grass, Water, Normal, Artificial, Human, Fire 4, Electric 3, Aquatic 4, Baby (eggs), Flora (pots), Psychic (Unowns)")
#endregion


#region audio, VFX (Phase 7)
func _check_vfx() -> void:
	var specs = JSON.parse_string(FileAccess.get_file_as_string(VfxLibrary.SPECS))
	var checked := 0
	for ability in specs:
		if ability.begins_with("_"):
			continue
		if not GameData.abilities.has(ability):
			_fail("vfx for an ability not ported: " + ability)
		for spec in specs[ability]:
			for sp in [spec, spec.get("hit")]:
				if sp is Dictionary and sp.get("at", "") == "unowns": # Pokémon sprites (Hidden Power)
					for letter in sp.get("letters", []):
						if GameData.get_pokemon(String(letter)).is_empty():
							_fail("vfx %s: no Pokémon %s" % [ability, letter])
				elif sp is Dictionary and sp.get("at", "") != "shake":
					var key := "%s/%s" % [sp.get("pack", "abilities"), sp.get("anim", ability)]
					checked += 1
					if VfxLibrary.frames(key) == null:
						_fail("vfx %s: no animation %s (run tools/export_pac.bat)" % [ability, key])
	for pkm in GameData.pool:
		var anim: Dictionary = GameData.get_pokemon(pkm).get("anim", {})
		if not VfxLibrary.has("attacks/" + String(anim.get("attackSprite", ""))):
			_fail("%s: no attack sprite %s" % [pkm, anim.get("attackSprite")])
		for h in anim.get("hitSprite", []):
			if not VfxLibrary.has("attacks/" + String(h)):
				_fail("%s: no hit sprite %s" % [pkm, h])
	for status in VfxLibrary.STATUS:
		if VfxLibrary.frames("status/" + String(VfxLibrary.STATUS[status][0])) == null:
			_fail("no status animation for " + status)
	for sound in ["buttonclick", "buttonhover", "refresh", "evolutiont2", "evolutiont3", "carouselunlock", "startgame", "finish1"]:
		if not ResourceLoader.exists("res://assets/sounds/%s.ogg" % sound):
			_fail("no sound " + sound)
	var musics := 0
	for map in GameData.config.get("maps", {}):
		if ResourceLoader.exists("res://assets/music/%s.ogg" % GameData.config.maps[map].music):
			musics += 1
	# damage events carry their source (hit sparks, DPS meter)
	var sim := _fight([["CHARMANDER", Vector2i(3, 2)]], [["BULBASAUR", Vector2i(3, 3)]])
	var sources := _run(sim, 6000.0).filter(func(e: Dictionary) -> bool:
		return e.type == "damage" and e.get("source") != null)
	if sources.is_empty():
		_fail("damage events without source")
	print("vfx ok: %d effect specs, %d/%d region musics" % [checked, musics, GameData.config.get("maps", {}).size()])
#endregion


#region languages (Phase 6)
func _check_languages() -> void:
	if GameData.languages.size() < 10 or not GameData.languages.has("vi"):
		_fail("languages: " + str(GameData.languages.keys()))
	var spec := RegEx.create_from_string("%[-0-9.]*[dsf%]")
	var ui = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/ui.json"))
	for key in ui:
		if key.begins_with("_"):
			continue
		for code in ui[key]:
			var a := spec.search_all(key).map(func(m: RegExMatch) -> String: return m.get_string())
			var b := spec.search_all(String(ui[key][code])).map(func(m: RegExMatch) -> String: return m.get_string())
			if a != b:
				_fail("ui.json %s: %s -> %s" % [code, key, ui[key][code]])
	var param_re := RegEx.create_from_string("\\{([A-Za-z0-9_.]+)(?:\\|[a-z%]+)?\\}")
	for code in GameData.languages:
		GameData.set_language(code)
		for type in GameData.config.synergyThresholds:
			if GameData.synergy_tier_texts(type).size() != GameData.config.synergyThresholds[type].size():
				_fail("%s: synergy %s tier texts" % [code, type])
		for item in GameData.items:
			if GameData.item_desc(item).contains("{") or GameData.item_name(item) == "":
				_fail("%s: item text %s" % [code, item])
		for ability in GameData.abilities:
			if not ability.begins_with("_") and GameData.ability_desc(ability) == "":
				_fail("%s: no description for %s" % [code, ability])
	# the port templates only use params / stats of their item
	var vi = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/vi.json"))
	for item in vi.item_port:
		for m in param_re.search_all(vi.item_port[item]):
			var key := m.get_string(1)
			var known := GameData.item_stats(item).has(key.substr(5)) if key.begins_with("stat.") \
				else GameData.item_param(item, key, null) != null
			if not known:
				_fail("vi item_port %s: unknown {%s}" % [item, key])
	GameData.set_language("vi")
	TranslationServer.set_locale("vi")
	var fire := GameText.format("FIRE ON_HIT BURN")
	if GameData.synergy_name("FIRE") != "Lửa" or not fire.contains("Bỏng") or not fire.contains("khi trúng đòn"):
		_fail("vi texts: %s / %s" % [GameData.synergy_name("FIRE"), fire])
	if not GameData.item_desc("SHELL_BELL").begins_with("Người cầm") or GameData.item_name("CHARCOAL") != "Than củi":
		_fail("vi item: " + GameData.item_desc("SHELL_BELL"))
	if not GameData.ability_desc("THUNDER_SHOCK").begins_with("Gây"):
		_fail("vi ability: " + GameData.ability_desc("THUNDER_SHOCK"))
	if L.t("Fight!") != "Chiến!" or L.t("Life %d") % 7 != "Máu 7":
		_fail("vi ui: " + L.t("Fight!"))
	print("languages ok: %d, vi: %s | %s" % [GameData.languages.size(), GameData.item_desc("SHELL_BELL"),
		Synergies.context_text("DARK", PlayerState.new())])
	GameData.set_language("en")
	TranslationServer.set_locale("en")
#endregion


## Full fights: a random player team against endless waves.
## Regions (updateRegionalPool): regional pool, variants, propositions, regional passives.
func _check_regions() -> void:
	var maps: Array = GameData.config.get("maps", {}).keys().filter(func(m: String) -> bool: return m != "town")
	# the region with the most regional first forms
	var best_map := ""
	var best_n := 0
	for m in maps:
		var n := GameData.regional_in(m).filter(func(pkm: String) -> bool:
			return int(GameData.get_pokemon(pkm).stars) == 1 and not GameData.regional_base.has(pkm)).size()
		if n > best_n:
			best_n = n
			best_map = m
	if best_map == "":
		_fail("no region has regional Pokémon")
		return
	var p := PlayerState.new()
	p.change_map(best_map)
	if p.regional_counts.is_empty():
		_fail("regional pool empty in %s" % best_map)
	for pkm in p.regional_counts:
		if not GameData.in_region(pkm, best_map) or p.regional_counts[pkm] != GameData.pool_size(pkm):
			_fail("regional pool entry %s (%d)" % [pkm, p.regional_counts[pkm]])
	p.level = 9
	var seen := false
	for i in 300:
		p.roll_shop()
		seen = seen or p.shop.any(func(pkm: String) -> bool: return p.regional_counts.has(pkm))
	if not seen:
		_fail("no regional Pokémon in 300 shops of %s" % best_map)
	# leaving: the regional pool of the old region is gone; sold out of region = lost
	var regional_pkm: String = p.regional_counts.keys()[0]
	var other := ""
	for m in maps:
		if not GameData.in_region(regional_pkm, m):
			other = m
			break
	if other != "":
		var unit := PlayerState.OwnedUnit.new(regional_pkm)
		p.bench[0] = unit
		p.change_map(other)
		if p.regional_counts.has(regional_pkm):
			_fail("regional pool should be reset when leaving %s" % best_map)
		p.sell(unit)
		if p.copies_left(regional_pkm) != 0:
			_fail("a regional Pokémon sold out of its region should be lost")

	# variants: Rattata -> Alolan Rattata where it lives, sharing Rattata's copies
	if GameData.is_available("ALOLAN_RATTATA") and GameData.pool.has("RATTATA"):
		var alola := ""
		for m in maps:
			if GameData.in_region("ALOLAN_RATTATA", m):
				alola = m
				break
		p = PlayerState.new()
		p.change_map(alola)
		if p.regional_form("RATTATA") != "ALOLAN_RATTATA":
			_fail("Rattata should be Alolan Rattata in %s: %s" % [alola, p.regional_pokemons])
		var before := p.copies_left("RATTATA")
		p.set_shop_slot(0, "ALOLAN_RATTATA")
		p.gold = 10
		p.buy(0)
		if p.copies_left("RATTATA") != before - 1:
			_fail("buying Alolan Rattata should take a Rattata copy")
		var offer := Town.propositions(p, 0, ["NORMAL"], RandomNumberGenerator.new())
		if offer.pokemons.has("RATTATA"):
			_fail("the starter Rattata should be its Alolan variant in %s" % alola)

	# Unique / Legendary propositions: regional ones only in their region
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for m in maps.slice(0, 20):
		p = PlayerState.new()
		p.map = m
		for stage in [10, 20]:
			var offer := Town.propositions(p, stage, [], rng)
			for pkm in offer.pokemons:
				if GameData.get_pokemon(pkm).get("regional", false) and not GameData.in_region(pkm, m):
					_fail("%s proposed out of its region (%s)" % [pkm, m])

	# Corsola: KO once -> Galarian Corsola; Water Spring: +5 PP when an enemy casts
	if GameData.is_available("CORSOLA") and GameData.is_available("GALAR_CORSOLA"):
		var sim := _fight([["CORSOLA", Vector2i(3, 1)]], [["MUDKIP", Vector2i(3, 4)]])
		var corsola := sim.board.get_unit(Vector2i(3, 1))
		corsola.owned = PlayerState.OwnedUnit.new("CORSOLA")
		var mudkip := sim.board.get_unit(Vector2i(3, 4))
		sim.update(10.0)
		var pp := mudkip.pp
		corsola.pp = corsola.max_pp
		AbilityRunner.cast(sim, corsola, mudkip)
		if mudkip.pp < pp + mudkip.web_pp(5.0) - 0.001: # 5 PP of a 100-PP bar (BattleUnit.add_pp)
			_fail("Water Spring: +5 PP (of a 100-PP bar) when an enemy casts (%s -> %s)" % [pp, mudkip.pp])
		sim.deal_damage(corsola, 9999.0, BattleUnit.DamageKind.TRUE, null)
		if corsola.owned.pkm != "GALAR_CORSOLA":
			_fail("Corsola KO should evolve into Galarian Corsola")
		sim.dispose()
	# Tapu Koko: Electric allies get an Electric field, lost when it falls
	if GameData.is_available("TAPU_KOKO"):
		var sim := _fight([["TAPU_KOKO", Vector2i(3, 1)], ["PIKACHU", Vector2i(4, 1)]], [["AGGRON", Vector2i(6, 7)]])
		sim.update(10.0)
		var pika := sim.board.get_unit(Vector2i(4, 1))
		if not pika.has_status("electric_field"):
			_fail("Electric Terrain should give an Electric field to Pikachu")
		sim.deal_damage(sim.board.get_unit(Vector2i(3, 1)), 9999.0, BattleUnit.DamageKind.TRUE, null)
		if pika.has_status("electric_field"):
			_fail("the Electric field should leave with Tapu Koko")
		sim.dispose()
	# Ogerpon: the masks are in the item bench; wearing one sets the form, the shield broken drops it
	if GameData.is_available("OGERPON_TEAL") and GameData.is_available("OGERPON_HEARTHFLAME_MASK"):
		p = PlayerState.new()
		p.give_pokemon("OGERPON_TEAL")
		var ogerpon: PlayerState.OwnedUnit = p.bench[0]
		if not PassiveEffects.OGERPON_MASKS.keys().all(func(m: String) -> bool: return p.items.has(m)):
			_fail("Ogerpon should bring its 4 masks: %s" % [p.items])
		p.equip(p.items.find("HEARTHFLAME_MASK"), ogerpon)
		if ogerpon.pkm != "OGERPON_HEARTHFLAME_MASK" or p.items.has("HEARTHFLAME_MASK") or not ogerpon.items.has("HEARTHFLAME_MASK"):
			_fail("Hearthflame Mask should turn Ogerpon masked: %s %s" % [ogerpon.pkm, p.items])
		p.equip(p.items.find("TEAL_MASK"), ogerpon)
		if ogerpon.pkm != "OGERPON_TEAL_MASK" or not p.items.has("HEARTHFLAME_MASK"):
			_fail("another mask should replace the worn one: %s %s" % [ogerpon.pkm, p.items])
		var sim := _fight([["OGERPON_TEAL_MASK", Vector2i(3, 1)]], [["AGGRON", Vector2i(6, 7)]])
		var og := sim.board.get_unit(Vector2i(3, 1))
		og.equip(["TEAL_MASK"])
		og.shield = 50.0
		sim.deal_damage(og, 100.0, BattleUnit.DamageKind.TRUE, null)
		if og.pkm != "OGERPON_TEAL" or og.has_item("TEAL_MASK"):
			_fail("a broken shield should drop Ogerpon's mask: %s" % og.pkm)
		sim.dispose()
		p.sell(ogerpon)
		if PassiveEffects.OGERPON_MASKS.keys().any(func(m: String) -> bool: return p.items.has(m)):
			_fail("the masks should leave with Ogerpon")
	# Rotom: the catalog offers its forms
	if GameData.is_available("ROTOM"):
		p = PlayerState.new()
		p.give_pokemon("ROTOM")
		var rotom: PlayerState.OwnedUnit = p.bench[0]
		var r := p.equip(p.items.find("ROTOM_CATALOG"), rotom)
		if not r.get("ok", false) or not r.has("choice") or not p.items.has("ROTOM_CATALOG"):
			_fail("Rotom Catalog should offer a form choice and stay: %s" % [r])
		elif not r.choice.pokemons.is_empty():
			p.change_form(rotom.id, r.choice.pokemons[0])
			if rotom.pkm != r.choice.pokemons[0]:
				_fail("Rotom should possess %s" % r.choice.pokemons[0])
	print("regions ok: %s (%d regional first forms), %d regional forms" % [best_map, best_n, GameData.regional.size()])


## Difficulty levels (data/difficulty.json) and wave templates (data/wave_templates.json).
func _check_difficulty() -> void:
	for id in ["classic", "normal", "hard"]:
		if not Difficulty.levels().has(id):
			_fail("difficulty.json: no level " + id)
	# classic = the web game: no synergies, no boss items, no multipliers
	for stage in range(1, 61):
		var w := EndlessWaves.get_stage(stage, 31)
		if w.get("synergies", true) or not w.get("statScale", {}).is_empty() or w.kind == "template":
			_fail("classic stage %d: %s" % [stage, w.kind])
	# normal: bosses hold their items, waves activate their synergies
	Difficulty.set_level("normal")
	var boss := EndlessWaves.get_stage(28, 31)
	if boss.kind != "boss" or not boss.items.any(func(l: Array) -> bool: return not l.is_empty()):
		_fail("normal: the boss of stage 28 should hold items (%s)" % boss.kind)
	var with_tiers := 0
	var seen_templates := {}
	for stage in range(1, 61):
		var w := EndlessWaves.get_stage(stage, 31)
		if w.kind == "template":
			seen_templates[w.template] = true
		if stage < int(Difficulty.value("enemySynergiesFromStage", 1)):
			if not EndlessWaves.synergy_counts(w).is_empty():
				_fail("normal stage %d: synergies before enemySynergiesFromStage" % stage)
			continue
		var p := PlayerState.new()
		p.stage = stage
		p.give_pokemon("PIKACHU")
		p.auto_place()
		var fight := FightSetup.create(p, w)
		var tiers: Dictionary = fight.sim.team_tiers[BattleUnit.Team.RED]
		if tiers != Synergies.tiers(EndlessWaves.synergy_counts(w)):
			_fail("normal stage %d: red tiers %s" % [stage, tiers])
		if not tiers.is_empty():
			with_tiers += 1
			var benefits := false
			for u in fight.enemies:
				benefits = benefits or (u != null and not u.synergy.is_empty())
			if not benefits and not (tiers.keys() as Array).all(func(type: String) -> bool: return type in ["LIGHT", "AMORPHOUS"]):
				_fail("normal stage %d: no enemy benefits from %s" % [stage, tiers])
		fight.sim.dispose()
	if with_tiers < 20:
		_fail("normal: only %d waves of 60 have an active synergy" % with_tiers)
	if seen_templates.is_empty():
		_fail("normal: no template wave in 60 stages")
	var problems := WaveTemplates.problems()
	if not problems.is_empty():
		_fail("wave_templates.json: " + "; ".join(problems))

	# stat multipliers and player side of a level
	var custom := Difficulty.data().duplicate(true)
	custom.levels["test"] = {"statScale": {"HP": 2, "ATK": 3}, "statScalePerStage": {"HP": 0.5}, "statScaleStartStage": 10,
		"statBoosts": {"HP": 7}, "enemySynergies": true, "enemySynergiesFromStage": 1, "synergyBonus": 2, "bossItems": false,
		"endless": {"unitsBase": 9, "firstItemStage": 1, "stagesPerItem": 1}}
	Difficulty.load_data(custom)
	Difficulty.set_level("test")
	WaveTemplates.load_data({"wildWeight": 10, "templates": []})
	var scale := Difficulty.enemy_scale(12)
	if not is_equal_approx(scale.HP, 3.0) or not is_equal_approx(scale.ATK, 3.0) or scale.has("DEF"):
		_fail("enemy_scale(12): %s" % scale)
	var magikarp := EndlessWaves.get_stage(1, 5)
	var mp := PlayerState.new()
	mp.give_pokemon("PIKACHU")
	mp.auto_place()
	var mf := FightSetup.create(mp, magikarp)
	var karp: BattleUnit = mf.enemies[0]
	var data := GameData.get_pokemon("MAGIKARP")
	if karp.max_hp != float(data.hp) * 2.0 + 7.0 or karp.base_atk != float(data.atk) * 3.0:
		_fail("scaled Magikarp: %s HP, %s ATK" % [karp.max_hp, karp.base_atk])
	# 2 Magikarp = 1 WATER family + 2 bonus points = tier 1
	if int(mf.sim.team_tiers[BattleUnit.Team.RED].get("WATER", 0)) != 1 or karp.synergy_tier("WATER") != 1:
		_fail("synergyBonus: %s" % [mf.sim.team_tiers[BattleUnit.Team.RED]])
	mf.sim.dispose()
	var pack := EndlessWaves.get_stage(4, 5)
	if pack.board.size() != 9 or pack.items.filter(func(l: Array) -> bool: return not l.is_empty()).size() < 4:
		_fail("endless overrides: %d units, items %s" % [pack.board.size(), pack.items])

	# templates: given and random slots, items, rows, synergies, stage filters
	WaveTemplates.load_data({"wildWeight": 0, "templates": [
		{"id": "t", "name": "Test wave", "stages": [7, 9], "synergies": "on", "bonusSynergies": {"FIRE": 3},
			"statScale": {"ATK": 0.5}, "statBoosts": {"AP": 11}, "reward": "choice_full", "slots": [
			{"count": 2, "pkm": "CHARMANDER", "stars": 2, "items": ["CHARCOAL"], "row": 1},
			{"count": 3, "types": ["WATER"], "rarity": ["COMMON"], "stars": 1, "randomItems": 2, "itemPool": "component", "row": 3}]},
		{"id": "off", "enabled": false, "stages": [1, 0], "always": true, "slots": [{"pkm": "PIKACHU"}]},
		{"id": "other_level", "levels": ["classic"], "stages": [1, 0], "always": true, "slots": [{"pkm": "PIKACHU"}]},
		{"id": "boss", "stages": [14, 14], "replaceBoss": true, "slots": [{"count": 30, "types": ["GRASS"]}]}]})
	var tw := EndlessWaves.get_stage(7, 5)
	if tw.kind != "template" or EndlessWaves.display_name(tw) != "Test wave" or tw.board.size() != 5:
		_fail("template wave: %s %s" % [tw.kind, tw.get("board")])
	else:
		for i in tw.board.size():
			var entry: Array = tw.board[i]
			var pdata := GameData.get_pokemon(entry[0])
			if i < 2 and (entry[0] != "CHARMELEON" or int(entry[2]) != 1 or tw.items[i] != ["CHARCOAL"]):
				_fail("template given slot: %s %s" % [entry, tw.items[i]])
			if i >= 2 and (not pdata.types.has("WATER") or pdata.rarity != "COMMON" or int(pdata.stars) != 1
					or int(entry[2]) != 3 or tw.items[i].size() != 2 or not GameData.is_component(tw.items[i][0])):
				_fail("template random slot: %s %s" % [entry, tw.items[i]])
		var counts := EndlessWaves.synergy_counts(tw)
		if int(counts.get("FIRE", 0)) != 6 or int(counts.get("WATER", 0)) < 3: # 1 family + 3 bonus + 2 (synergyBonus)
			_fail("template synergies: %s" % counts)
		if not is_equal_approx(tw.statScale.ATK, 1.5) or float(tw.statBoosts.AP) != 11.0 or not tw.reward.choice:
			_fail("template stats: %s %s %s" % [tw.statScale, tw.statBoosts, tw.reward])
	if EndlessWaves.get_stage(9, 5).kind != "boss" or EndlessWaves.get_stage(10, 5).kind != "wild":
		_fail("template stages: a boss is kept, stage 10 is out of range")
	if EndlessWaves.get_stage(8, 5).kind != "template":
		_fail("template stage 8 should use the template too")
	var grass := EndlessWaves.get_stage(14, 5)
	if grass.kind != "template" or grass.board.size() != EndlessWaves.MAX_UNITS:
		_fail("replaceBoss template: %s, %d units" % [grass.kind, grass.board.size()])
	if WaveTemplates.problems().is_empty() == false:
		_fail("test templates: %s" % [WaveTemplates.problems()])

	WaveTemplates.load_data()
	Difficulty.load_data()
	Difficulty.set_level("classic")
	# the editor writes the files back without changing what they hold
	var editor: GDScript = load("res://tools/wave_editor/wave_editor.gd")
	for path in [WaveTemplates.PATH, Difficulty.PATH]:
		var original = JSON.parse_string(FileAccess.get_file_as_string(path))
		var written: String = editor._json(editor._whole_numbers(original), 0)
		if JSON.stringify(JSON.parse_string(written)) != JSON.stringify(original):
			_fail("wave editor JSON round trip: " + path)
		if OS.get_cmdline_user_args().has("print-json"):
			print(written)
	_check_wave_editor()
	print("difficulty ok: levels %s, %d/60 normal waves with synergies, templates seen %s" % [Difficulty.levels(), with_tiers,
		seen_templates.keys()])


## Interactive tooltips (synergy -> its Pokémon) can be reached with the mouse: the gap between the
## owner and the panel, a short time outside, and another owner crossed on the way keep them open.
func _check_hover_tip() -> void:
	var root := Control.new()
	root.size = Vector2(1920, 1080)
	add_child(root)
	var tips := HoverTip.new()
	root.add_child(tips)
	var rows: Array[Control] = []
	for i in 2:
		var row := Control.new()
		row.position = Vector2(10, 100 + 40 * i)
		row.size = Vector2(180, 40)
		root.add_child(row)
		rows.append(row)
		HoverTip.add(row, func() -> Control:
			var c := Control.new()
			c.custom_minimum_size = Vector2(200, 300)
			return c, HoverTip.Side.RIGHT, 0, true)
	var step := func(mouse: Vector2, seconds: float) -> void:
		tips._mouse = mouse
		var t := 0.0
		while t < seconds:
			tips._process(0.02)
			t += 0.02
	var a := rows[0].get_global_rect()
	step.call(a.get_center(), 0.0)
	rows[0].mouse_entered.emit()
	step.call(a.get_center(), 0.06)
	if not tips.has_open():
		_fail("hover tip: no tooltip on the synergy row")
	else:
		var panel: Rect2 = (tips._levels[0].panel as Control).get_global_rect()
		step.call(Vector2(a.end.x + HoverTip.GAP * 0.5, a.get_center().y), 0.6) # in the gap
		if not tips.has_open():
			_fail("hover tip: closed in the gap between the row and its tooltip")
		step.call(Vector2(a.get_center().x, 900), 0.2) # outside, shortly
		if not tips.has_open():
			_fail("hover tip: closed at once outside (should wait %s s)" % HoverTip.CLOSE_DELAY)
		step.call(panel.get_center(), 0.1)
		# crossing the second row on the way to the tooltip does not replace it
		step.call(rows[1].get_global_rect().get_center(), 0.0)
		rows[1].mouse_entered.emit()
		step.call(rows[1].get_global_rect().get_center(), HoverTip.SWITCH_DELAY * 0.5)
		step.call(panel.get_center(), 0.4)
		if not tips.has_open() or tips._levels[0].owner != rows[0]:
			_fail("hover tip: replaced by a row crossed on the way to it")
		# staying on the second row replaces it
		step.call(rows[1].get_global_rect().get_center(), 0.0)
		rows[1].mouse_entered.emit()
		step.call(rows[1].get_global_rect().get_center(), 0.3)
		if not tips.has_open() or tips._levels[0].owner != rows[1]:
			_fail("hover tip: the hovered row should get its tooltip")
		step.call(Vector2(1500, 900), 0.5) # away
		if tips.has_open():
			_fail("hover tip: still open %s s after the mouse left" % 0.5)
	root.queue_free()


## Pokémon of a synergy tooltip: groups like the web (shop, additional, regional, unique, legendary),
## one entry per family (one for the Flabébé colours), and how each one gets into the shop.
func _check_synergy_members() -> void:
	for type in GameData.config.get("synergyThresholds", {}):
		var families := {}
		for group in Tooltips.synergy_groups(type):
			for pkm in group.pokemons:
				var family := String(GameData.get_pokemon(pkm).get("family", pkm))
				if PlayerState.FLABEBE_FORMS.has(family):
					family = "FLABEBE"
				if families.has(family):
					_fail("synergy %s lists the family %s twice" % [type, family])
				families[family] = true
				if not GameData.get_pokemon(pkm).get("types", []).has(type):
					_fail("synergy %s lists %s" % [type, pkm])
				if GameData.portrait(pkm) == null:
					_fail("synergy %s: %s has no portrait" % [type, pkm])
	var keys: Array = Tooltips.synergy_groups("FIRE").map(func(g: Dictionary) -> String: return g.key)
	if keys.slice(0, 2) != ["shop", "additional"] or not keys.has("unique") or not keys.has("legendary"):
		_fail("FIRE groups: %s" % [keys])

	var p := PlayerState.new()
	p.stage = 1
	var additional: String = GameData.additional_tier1_by_rarity["RARE"][0]
	if Tooltips.unlock_info(additional, p).state != "locked" or Tooltips.unlock_info(additional).state != "available":
		_fail("additional %s before its stage: %s" % [additional, Tooltips.unlock_info(additional, p)])
	p.unlock_additional(additional)
	if Tooltips.unlock_info(additional, p).state != "available":
		_fail("additional %s unlocked: %s" % [additional, Tooltips.unlock_info(additional, p)])
	var regional := ""
	for pkm in GameData.regional_info:
		if GameData.is_available(pkm) and String(GameData.regional_info[pkm].get("requires", "")) == "" \
				and not GameData.regional_base.has(pkm) and int(GameData.get_pokemon(pkm).stars) == 1 \
				and GameData.SHOP_RARITIES.has(GameData.get_pokemon(pkm).rarity):
			regional = pkm
			break
	if regional != "":
		if Tooltips.unlock_info(regional, p).state != "locked":
			_fail("regional %s in town: %s" % [regional, Tooltips.unlock_info(regional, p)])
		p.change_map(GameData.regional_info[regional].maps[0])
		var info := Tooltips.unlock_info(regional, p)
		if info.state != "available" or Tooltips.region_types(regional).is_empty():
			_fail("regional %s in its region: %s %s" % [regional, info, Tooltips.region_types(regional)])
	var unique: String = GameData.unique[0]
	if Tooltips.unlock_info(unique, p).state != "offered":
		_fail("unique %s: %s" % [unique, Tooltips.unlock_info(unique, p)])
	var common: String = GameData.tier1_by_rarity["COMMON"].filter(func(x: String) -> bool:
		return not GameData.get_pokemon(x).types.has("WILD") and not PlayerState.FLABEBE_FORMS.has(x))[0]
	if Tooltips.unlock_info(common, p).state != "available":
		_fail("shop Pokémon %s: %s" % [common, Tooltips.unlock_info(common, p)])
	p.give_pokemon(common)
	if Tooltips.unlock_info(common, p).state != "owned":
		_fail("owned %s: %s" % [common, Tooltips.unlock_info(common, p)])
	# the tooltip itself: border by cost, locked members dim with a lock
	var tip := Tooltips.synergy(String(GameData.get_pokemon(additional).types[0]), 0, {}, 0, "", p)
	add_child(tip)
	var members: Array = tip.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is SynergyMember)
	if members.is_empty() or not members.any(func(m: SynergyMember) -> bool: return m.locked):
		_fail("synergy tooltip members: %d, none locked" % members.size())
	tip.queue_free()
	print("synergy members ok")


## benchSize, benchStack and goldPerWave of difficulty.json: the bench of a new run, the income of a stage.
func _check_player_config() -> void:
	var p := PlayerState.new()
	var slots := int(Difficulty.value("benchSize", PlayerState.BENCH_SIZE))
	var stack := int(Difficulty.value("benchStack", 1))
	if p.bench_slots != slots or p.bench_stack != stack or p.bench.size() != slots * stack or p.bench_size != slots * stack:
		_fail("bench of a run: %d slots of %d, %d places" % [p.bench_slots, p.bench_stack, p.bench.size()])
	var commons: Array = GameData.tier1_by_rarity["COMMON"] + GameData.tier1_by_rarity["UNCOMMON"]
	for i in p.bench_slots: # different Pokémon: one slot each
		p.give_pokemon(commons[i])
	if p.first_free_bench_slot() != -1 or p.give_pokemon(commons[p.bench_slots]) != "sold":
		_fail("a full bench of %d slots should sell the next Pokémon" % p.bench_slots)
	if stack > 1 and p.give_pokemon(commons[0]) != "bench": # a second copy stacks in the slot of the first
		_fail("a second copy of %s should stack on a full bench" % commons[0])
	var custom := Difficulty.data().duplicate(true)
	custom.base["benchSize"] = 10
	custom.base["benchStack"] = 1
	custom.base["goldPerWave"] = 7
	Difficulty.load_data(custom)
	p = PlayerState.new()
	p.gold = 0
	var income := p.collect_income()
	if p.bench_slots != 10 or p.bench_size != 10 or income != 7 or p.gold != 7:
		_fail("benchSize 10 / goldPerWave 7: bench %d, income %d" % [p.bench_slots, income])
	p.gold = 30
	if p.collect_income() != 7 + 3:
		_fail("goldPerWave + interest (30 gold: +3)")
	Difficulty.load_data()
	Difficulty.set_level("classic")
	# bench slots on the arena: rows of 8, a slot's centre maps back to it, highlights in range
	var arena := Arena.new()
	arena.bench_rows = 3
	add_child(arena)
	for i in 24:
		var back := arena.world_to_slot(arena.bench_to_world(i))
		if back.get("bench", -1) != i:
			_fail("bench slot %d -> %s" % [i, back])
	if arena.world_to_slot(arena.bench_to_world(0) + Vector3(0, 0, 3.0)) != {}:
		_fail("below the last bench row should be no slot")
	arena.set_layer("valid", {Vector2i(23, Arena.BENCH_ROW): Color.WHITE})
	arena._upload_highlights()
	arena.queue_free()
	print("player config ok: bench %d x %d, %d gold per wave" % [int(Difficulty.value("benchSize", 8)),
		int(Difficulty.value("benchStack", 1)), int(Difficulty.value("goldPerWave", 5))])
	_check_bench_stacks()


## Bench slots holding two copies of the same Pokémon (difficulty benchStack 2; not in the web game):
## buying stacks, a third copy merges, different Pokémon never share a slot, drag & drop (stack, swap,
## a copy taken out of a pair), selling one copy, the copies behind hold nothing.
func _check_bench_stacks() -> void:
	var custom := Difficulty.data().duplicate(true)
	custom.base["benchSize"] = 8
	custom.base["benchStack"] = 2
	Difficulty.load_data(custom)
	var p := PlayerState.new()
	p.gold = 500
	p.level = 9
	var a := "CHARMANDER"
	var b := "SQUIRTLE"
	for pkm in [a, b]:
		_expect(GameData.is_available(pkm) and int(GameData.get_pokemon(pkm).stars) == 1, "stacks: %s is a first form" % pkm)
	# two copies share a slot; the third merges
	p.give_pokemon(a)
	p.give_pokemon(a)
	_expect(p.slot_units(0).size() == 2 and p.slot_units(1).is_empty(), "stacks: 2 copies in slot 0, got %s" % [
		p.slot_units(0).map(func(u) -> String: return u.pkm)])
	_expect(p.find(p.bench[1]) == {"bench": 0, "layer": 1}, "stacks: the second copy is behind the first")
	_expect(p.give_pokemon(a) == "merged" and p.slot_units(0).size() == 1 and p.slot_units(0)[0].pkm == "CHARMELEON",
		"stacks: the third copy merges into Charmeleon in slot 0")
	# another Pokémon takes another slot
	p.give_pokemon(b)
	_expect(p.slot_units(1).size() == 1 and p.slot_units(1)[0].pkm == b, "stacks: %s in slot 1" % b)
	p.give_pokemon(b)
	_expect(p.slot_units(1).size() == 2, "stacks: two %s in slot 1" % b)
	# a full bench: 8 slots of pairs, the 17th copy of something new is sold; a pair still takes its third
	for i in p.bench_size:
		p.bench[i] = null
	var fillers: Array = GameData.tier1_by_rarity["COMMON"].filter(func(x: String) -> bool:
		return not GameData.evolutions_of(x).is_empty() and PlayerState.merge_count(x) == 3).slice(0, 9)
	for s in 8:
		p.bench[2 * s] = PlayerState.OwnedUnit.new(fillers[s])
		p.bench[2 * s + 1] = PlayerState.OwnedUnit.new(fillers[s])
	_expect(not p.has_bench_room(fillers[8]) and p.give_pokemon(fillers[8]) == "sold", "stacks: a full bench sells a new Pokémon")
	_expect(p.give_pokemon(fillers[0]) == "merged" and p.slot_units(0).size() == 1, "stacks: a full pair still merges its third copy")
	# drag & drop: a copy dropped on its twin stacks; on another Pokémon they swap; out of a pair onto the board
	for i in p.bench_size:
		p.bench[i] = null
	p.board.clear()
	var a1 := PlayerState.OwnedUnit.new(a)
	var a2 := PlayerState.OwnedUnit.new(a)
	var b1 := PlayerState.OwnedUnit.new(b)
	p.bench[0] = a1 # slot 0
	p.bench[2] = a2 # slot 1
	p.bench[4] = b1 # slot 2
	_expect(p.move_unit(a2, {"bench": 0}) and p.slot_units(0) == [a1, a2] and p.slot_units(1).is_empty(),
		"stacks: a copy dropped on its twin joins its slot")
	_expect(p.move_unit(b1, {"bench": 0}) and p.slot_units(0) == [b1] and p.slot_units(2) == [a1, a2],
		"stacks: a Pokémon dropped on a pair swaps slots with it: %s / %s" % [p.slot_units(0), p.slot_units(2)])
	_expect(p.move_unit(a2, {"board": Vector2i(3, 2)}) and p.board.get(Vector2i(3, 2)) == a2 and p.slot_units(2) == [a1],
		"stacks: a copy taken out of a pair goes to the board, the other stays")
	_expect(p.move_unit(a2, {"bench": 2}) and p.slot_units(2).size() == 2 and p.board.is_empty(),
		"stacks: back from the board onto its twin")
	# a different Pokémon from the board onto a pair: no room for the pair on one cell
	var c1 := PlayerState.OwnedUnit.new("BULBASAUR" if GameData.pokemon.has("BULBASAUR") else b)
	p.board[Vector2i(4, 2)] = c1
	_expect(not p.can_place(c1, {"bench": 2}) and not p.move_unit(c1, {"bench": 2}), "stacks: a board Pokémon cannot swap with a pair")
	_expect(p.move_unit(c1, {"bench": 0}) and p.board.get(Vector2i(4, 2)) == b1 and p.slot_units(0) == [c1],
		"stacks: a board Pokémon swaps with a single one")
	# out of a pair onto an occupied cell: the one there goes to an empty slot (not into the pair)
	var front: PlayerState.OwnedUnit = p.slot_units(2)[0]
	_expect(p.move_unit(front, {"board": Vector2i(4, 2)}) and p.board.get(Vector2i(4, 2)) == front and p.slot_units(2).size() == 1
		and p.slot_units(1) == [b1], "stacks: the Pokémon of the cell goes to the first empty slot: %s" % [
		range(8).map(func(s: int) -> Array: return p.slot_units(s).map(func(u) -> String: return u.pkm))])
	# items: only the front copy holds some; equipping the front keeps the pair, a holder never goes behind
	p.board.clear()
	for i in p.bench_size:
		p.bench[i] = null
	var h1 := PlayerState.OwnedUnit.new(a)
	var h2 := PlayerState.OwnedUnit.new(a)
	h2.items.append("CHARCOAL")
	p.bench[0] = h1
	p.bench[1] = h2
	p._normalize_bench()
	_expect(p.slot_units(0) == [h2, h1], "stacks: the copy holding an item goes in front")
	var h3 := PlayerState.OwnedUnit.new(a)
	h3.items.append("MAGNET")
	p.bench[0] = null
	p.bench[1] = null
	p.bench[0] = h2
	p.bench[2] = h3
	_expect(not p.can_place(h3, {"bench": 0}) or p.slot_units(0).size() == 1, "stacks: two holders do not stack")
	_expect(PlayerState.stack_order([h2, h3]).is_empty(), "stacks: two holders cannot share a slot")
	# selling the front copy: the other one comes to the front
	p.bench[2] = null
	p.bench[1] = h1
	p.sell(h2)
	_expect(p.slot_units(0) == [h1] and p.bench[0] == h1, "stacks: sold the front copy, the other is at the front")
	# eggs never stack
	var egg1 := PlayerState.OwnedUnit.new("EGG")
	var egg2 := PlayerState.OwnedUnit.new("EGG")
	_expect(not PlayerState.stackable(egg1, egg2), "stacks: eggs do not stack")
	Difficulty.load_data()
	Difficulty.set_level("classic")
	print("bench stacks ok")


## Basic PP rules (Difficulty.mana), by role (mana.roles, Difficulty.role_mana) at every level of
## difficulty.json: no passive PP, PP for a basic attack that lands and each time a basic attack lands on it
## written for every role (the numbers are the user's to tune), nothing from the damage of an ability, both
## teams; the PP to cast is the form's own maxPP (no role: none in the file), a TM 100. The web rules (10 PP/s,
## 5 per attack, 1 per 10 damage taken) when a level does not set `mana`. The weather still adds / removes 3 PP
## per second.
## Auto balance (data/balance.json): each form's own multipliers (HP, Attack, skill = base AP 100 (m - 1), DEF, PP...),
## a number for HP, Attack and skill together; HP and PP in tens; the file on (use_balance(true)) and the web stats
## back (false).
func _check_balance() -> void:
	var fire := _first_of_type("FIRE")
	var src := GameData.get_pokemon(fire)
	var d := src.duplicate(true)
	GameData.balance_form(d, 1.2)
	if int(d.hp) != maxi(roundi(float(src.hp) * 1.2 / 10.0) * 10, 10) or not is_equal_approx(float(d.get("skillScale", 0)), 1.2) \
			or d.has("ap") or int(d.hp) % 10 != 0 \
			or absf(float(d.atk) - maxf(snappedf(float(src.atk) * 1.2, 0.1), 1.0)) > 0.001 or d.maxPP != src.maxPP:
		_fail("balance of a form x1.2: %s -> hp %s atk %s skill %s pp %s" % [fire, d.hp, d.atk, d.get("skillScale"), d.maxPP])
	d = src.duplicate(true)
	GameData.balance_form(d, {"hp": 1.1, "skill": 0.9, "def": 2.0, "pp": 0.67})
	if int(d.hp) != maxi(roundi(float(src.hp) * 1.1 / 10.0) * 10, 10) or float(d.atk) != float(src.atk) \
			or not is_equal_approx(float(d.get("skillScale", 0)), 0.9) or d.has("ap") \
			or absf(float(d.def) - 2.0 * float(src.def)) > 0.11 or float(d.speed) != float(src.speed) \
			or int(d.maxPP) != maxi(roundi(float(src.maxPP) * 0.67 / 10.0) * 10, 10) or int(d.maxPP) % 10 != 0:
		_fail("balance of a form's own stats: %s -> hp %s atk %s skill %s def %s pp %s"
			% [fire, d.hp, d.atk, d.get("skillScale"), d.def, d.maxPP])
	d = src.duplicate(true)
	GameData.balance_form(d, {"skill": 0.001, "def": 0.001, "atk": 0.001, "hp": 0.001})
	if float(d.skillScale) < 0.1 or float(d.def) < 0.0 or float(d.atk) < 1.0 or int(d.hp) < 10:
		_fail("balance of a form may not go below 0 (strength 0.1, ATK 1, HP 10): %s" % d)
	var u := BattleUnit.create(fire, BattleUnit.Team.BLUE)
	if u.ap != 0.0 or u.max_hp != float(src.hp): # the web stats in sim_test (use_balance(false) in _ready)
		_fail("balance off: %s starts with AP %s, HP %s" % [fire, u.ap, u.max_hp])
	var forms: Dictionary = GameData._load_json_optional("res://data/balance.json").get("pokemon", {})
	if not forms.is_empty():
		var pkm: String = forms.keys()[0]
		var web := GameData.get_pokemon(pkm).duplicate(true)
		var expected := web.duplicate(true)
		GameData.balance_form(expected, forms[pkm])
		GameData.use_balance(true)
		var tuned := GameData.get_pokemon(pkm).duplicate(true)
		var unit := BattleUnit.create(pkm, BattleUnit.Team.BLUE)
		var unit_scale := unit.skill_scale() # (its data is the GameData entry, back to the web's just below)
		GameData.use_balance(false)
		if tuned.hp != expected.hp or tuned.atk != expected.atk \
				or tuned.get("skillScale", 1.0) != expected.get("skillScale", 1.0) \
				or tuned.maxPP != expected.maxPP or unit.max_pp != Difficulty.max_pp_of(float(expected.maxPP)) \
				or unit.ap != 0.0 or unit_scale != float(expected.get("skillScale", 1.0)) \
				or GameData.get_pokemon(pkm).hp != web.hp or GameData.get_pokemon(pkm).has("skillScale") \
				or GameData.get_pokemon(pkm).maxPP != web.maxPP:
			_fail("use_balance: %s %s web %s -> %s -> %s" % [pkm, forms[pkm], web.hp, tuned.hp, GameData.get_pokemon(pkm).hp])
	# no stat of any form goes below 0 with the balance (a too strong ability: lower strength or more PP, never a stat)
	GameData.use_balance(true)
	var negative: Array[String] = []
	for pkm in GameData.pokemon:
		var p: Dictionary = GameData.pokemon[pkm]
		for stat in ["hp", "atk", "def", "speDef", "speed", "maxPP", "range"]:
			if float(p.get(stat, 0)) < 0.0:
				negative.append("%s %s %s" % [pkm, stat, p[stat]])
		if p.has("ap") or float(p.get("skillScale", 1.0)) <= 0.0:
			negative.append("%s ap %s skill %s" % [pkm, p.get("ap"), p.get("skillScale")])
	var probe := BattleUnit.create(forms.keys()[0] if not forms.is_empty() else fire, BattleUnit.Team.BLUE)
	GameData.use_balance(false)
	if not negative.is_empty() or probe.ap != 0.0:
		_fail("balance: negative stats %s (AP of a unit %s)" % [negative.slice(0, 8), probe.ap])


## The damage of an ability (now or scheduled: BattleSim.ability_source) is marked "ability", a basic attack's
## "attack" (bot TSV sdealt / adealt).
func _check_ability_events() -> void:
	var sim := _fight([["CHARMANDER", Vector2i(3, 2)]], [["MAGIKARP", Vector2i(3, 3)]])
	var c: BattleUnit = sim.units[0]
	var t: BattleUnit = sim.units[1]
	t.max_hp = 100000.0
	t.hp = t.max_hp
	t.dodge = 0.0
	sim.drain_events()
	AbilityRunner.cast(sim, c, t)
	sim.schedule(100.0, c, func() -> void: # scheduled by no ability: its damage is not the ability's
		sim.deal_damage(t, 7.0, BattleUnit.DamageKind.TRUE, c))
	for _i in 20:
		sim.update(BattleSim.MAX_STEP_MS)
	var from_ability := 0
	var plain := 0
	for e in sim.drain_events():
		if e.type == "damage" and e.get("source") == c and float(e.amount) > 0.0:
			if e.get("ability", false):
				from_ability += 1
			elif not e.get("attack", false):
				plain += 1
	if from_ability == 0 or plain == 0 or sim.ability_source != null:
		_fail("ability events: %d marked of Blast Burn, %d unmarked, source after %s" % [from_ability, plain, sim.ability_source])
	sim.attack_hit(c, t)
	for e in sim.drain_events():
		if e.type == "damage" and e.get("source") == c and (not e.get("attack", false) or e.get("ability", false)):
			_fail("a basic attack's damage should be attack only: %s" % e)
	sim.dispose()


## The auto balance's strength of an ability (data/balance.json "skill" -> skillScale, BattleUnit.skill_scale, never a
## stat): x the damage, heal and shield of its OWN ability while it runs - not its attacks, not what follows a damage
## (lifesteal), not another ability (TM, Skill Swap); its AP stays 0.
func _check_skill_scale() -> void:
	var dealt: Array[float] = []
	var attacks: Array[float] = []
	for scale in [1.0, 0.5]:
		var sim := _fight([["CHARMANDER", Vector2i(3, 2)]], [["MAGIKARP", Vector2i(3, 3)]])
		var c: BattleUnit = sim.units[0]
		var t: BattleUnit = sim.units[1]
		c.data = c.data.duplicate() # not the GameData entry
		c.data["skillScale"] = scale
		t.max_hp = 100000.0
		t.hp = t.max_hp
		t.dodge = 0.0
		sim.drain_events()
		AbilityRunner.cast(sim, c, t)
		for _i in 20:
			sim.update(BattleSim.MAX_STEP_MS)
		sim.attack_hit(c, t)
		var by_ability := 0.0
		var by_attack := 0.0
		for e in sim.drain_events():
			if e.type == "damage" and e.get("source") == c and e.unit == t:
				if e.get("ability", false):
					by_ability += float(e.amount)
				elif e.get("attack", false):
					by_attack += float(e.amount)
		dealt.append(by_ability)
		attacks.append(by_attack)
		if scale == 0.5:
			var gained: Array[float] = []
			sim.ability_source = c # its ability: x0.5
			var before := c.shield
			sim.add_shield(c, 100.0, c)
			gained.append(c.shield - before)
			sim.damage_hooks = 1 # what follows a damage: as it is
			before = c.shield
			sim.add_shield(c, 100.0, c)
			gained.append(c.shield - before)
			sim.damage_hooks = 0
			c.ability_id = "SPLASH" # another ability than its own
			before = c.shield
			sim.add_shield(c, 100.0, c)
			gained.append(c.shield - before)
			c.ability_id = String(c.data.skill)
			sim.ability_source = null # no ability running
			before = c.shield
			sim.add_shield(c, 100.0, c)
			gained.append(c.shield - before)
			if gained != [50.0, 100.0, 100.0, 100.0] or c.ap != 0.0:
				_fail("strength 0.5 of the ability on shields (own, after a damage, other ability, none): %s, AP %s"
					% [gained, c.ap])
		sim.dispose()
	if dealt[0] <= 0.0 or absf(dealt[1] / dealt[0] - 0.5) > 0.1 or attacks[0] != attacks[1]: # (DEF rounds up each hit)
		_fail("strength 0.5 of the ability: ability damage %s -> %s (x0.5), attack %s -> %s (same)"
			% [dealt[0], dealt[1], attacks[0], attacks[1]])


func _check_mana() -> void:
	var written: Dictionary = Difficulty.data().base.get("mana", {}).get("roles", {})
	var expected := {} # role -> [0 (no maxPP of the role), perAttack, perHit] of the file
	for role in UnitRoles.ROLES:
		var r: Dictionary = written.get(role, {})
		expected[role] = [float(r.get("maxPP", 0)), float(r.get("perAttack", 0)), float(r.get("perHit", 0))]
		if expected[role][0] != 0.0 or minf(expected[role][1], expected[role][2]) <= 0.0:
			_fail("mana: role %s needs perAttack and perHit > 0 and no maxPP (the form's own) in difficulty.json: %s" % [role, r])
	for level in Difficulty.levels():
		Difficulty.set_level(level)
		var rules := Difficulty.mana()
		if float(rules.perSecond) != 0.0 or float(rules.perDamage) != 0.0:
			_fail("mana of level %s: %s" % [level, rules])
		for role in expected:
			var own := Difficulty.role_mana(role)
			if [float(own.get("maxPP", 0.0)), float(own.perAttack), float(own.perHit)] != expected[role]:
				_fail("mana of level %s, role %s: %s" % [level, role, own])
	Difficulty.set_level("classic")
	# PP to cast: the Pokémon's own (balanced in the game, the web's here), whatever the rules; a TM 100
	var by_role := {}
	for pkm in GameData.pool:
		var role := UnitRoles.role_of(pkm)
		if not by_role.has(role):
			by_role[role] = pkm
	for role in by_role:
		var u := BattleUnit.create(by_role[role], BattleUnit.Team.BLUE)
		if u.role != role or u.max_pp != Difficulty.max_pp_of(float(GameData.get_pokemon(by_role[role]).get("maxPP", 100))) \
				or Difficulty.max_pp_of(100.0) != 100.0 or Difficulty.max_pp_of(0.0) != 100.0:
			_fail("mana: %s (%s) needs %s PP to cast" % [by_role[role], role, u.max_pp])
	var without := Difficulty.data().duplicate(true)
	without.base.erase("mana")
	Difficulty.load_data(without)
	if Difficulty.mana() != Difficulty.WEB_MANA:
		_fail("a level without mana should have the web rules: %s" % [Difficulty.mana()])
	for role in by_role:
		var u := BattleUnit.create(by_role[role], BattleUnit.Team.BLUE)
		if u.max_pp != float(GameData.get_pokemon(by_role[role]).get("maxPP", 100)):
			_fail("mana (web rules): %s needs %s PP to cast" % [by_role[role], u.max_pp])
	Difficulty.load_data()
	Difficulty.set_level("classic")
	for rules_name in ["web", "game"]:
		var web: bool = rules_name == "web"
		var level: String = rules_name
		var sim := _fight([["MAGIKARP", Vector2i(3, 2)]], [["MAGIKARP", Vector2i(3, 3)]])
		sim.mana = Difficulty.WEB_MANA if web else Difficulty.mana()
		var a: BattleUnit = sim.units[0]
		var b: BattleUnit = sim.units[1]
		var per_attack := float(sim.mana_of(a).perAttack) # web 5, game 10
		var per_hit := float(sim.mana_of(b).perHit) # web 0, game 5 (10 for a tank)
		if per_attack != (5.0 if web else float(expected[a.role][1])) or per_hit != (0.0 if web else float(expected[b.role][2])):
			_fail("mana %s: rules of %s: %s" % [level, a.role, sim.mana_of(a)])
		for u in [a, b]:
			u.dodge = 0.0
			u.max_hp = 100000.0
			u.hp = u.max_hp
			u.pp = 0.0
		# passive PP
		for weather in [Weather.NEUTRAL, "RAIN", "DROUGHT"]:
			sim.weather = weather
			a.pp = 20.0
			sim._each_second(a)
			# the rule as it is; the weather's +-3 of a 100-PP bar (BattleUnit.add_pp: a.web_pp)
			var passive: float = (10.0 if web else 0.0) + a.web_pp({Weather.NEUTRAL: 0.0, "RAIN": 3.0, "DROUGHT": -3.0}[weather])
			if not is_equal_approx(a.pp, 20.0 + passive):
				_fail("mana %s, %s: passive PP %s -> %s" % [level, weather, 20.0, a.pp])
		sim.weather = Weather.NEUTRAL
		# a basic attack: the attacker gains perAttack, the target perHit (web: 1 per 10 damage taken)
		a.pp = 0.0
		b.pp = 0.0
		sim.attack_hit(a, b)
		var taken := b.max_hp - b.hp
		var from_hit := ceilf(taken / 10.0) if web else per_hit
		if taken <= 0.0 or not is_equal_approx(a.pp, per_attack):
			_fail("mana %s: attacker has %s PP after a basic attack (damage %s)" % [level, a.pp, taken])
		if not is_equal_approx(b.pp, from_hit):
			_fail("mana %s: target has %s PP after taking %s damage" % [level, b.pp, taken])
		# the other team gets the same: a hit on the blue unit
		a.pp = 0.0
		sim.attack_hit(b, a)
		if not is_equal_approx(b.pp - from_hit, per_attack) or a.pp <= 0.0:
			_fail("mana %s: red attacker %s PP / blue target %s PP" % [level, b.pp, a.pp])
		# a basic attack on a shield still counts at the new levels (the web pays by damage: none)
		b.pp = 0.0
		b.shield = 100000.0
		sim.attack_hit(a, b)
		if not is_equal_approx(b.pp, 0.0 if web else per_hit):
			_fail("mana %s: %s PP after an attack absorbed by a shield" % [level, b.pp])
		b.shield = 0.0
		# the damage of an ability: no flat PP (the web still pays by damage)
		b.pp = 0.0
		var hp_before := b.hp
		sim.deal_damage(b, 30.0, BattleUnit.DamageKind.SPECIAL, a)
		if not is_equal_approx(b.pp, ceilf((hp_before - b.hp) / 10.0) if web else 0.0):
			_fail("mana %s: %s PP after the hit of an ability" % [level, b.pp])
		# an attack or a hit blocked by Protect: nothing for either side
		a.pp = 0.0
		b.pp = 0.0
		sim.add_status(b, "protect", 2000.0)
		sim.attack_hit(a, b)
		sim.deal_damage(b, 30.0, BattleUnit.DamageKind.SPECIAL, a)
		if b.pp != 0.0 or a.pp != 0.0:
			_fail("mana %s: attacker %s / target %s PP after a blocked attack" % [level, a.pp, b.pp])
		# a burn tick is not a hit (no flat PP at the new levels, the web rule still pays by damage)
		b.statuses.erase("protect")
		b.pp = 0.0
		sim._burn_tick(b)
		if (b.pp > 0.0) != web:
			_fail("mana %s: %s PP from a burn tick" % [level, b.pp])
		# poison never gives PP
		b.pp = 0.0
		sim.deal_damage(b, 30.0, BattleUnit.DamageKind.TRUE, null, false, false, false)
		if b.pp != 0.0:
			_fail("mana %s: %s PP from damage that gives none" % [level, b.pp])
		sim.dispose()
	# the PP tooltip follows the rules: the web's (no `mana` in the data), then the game's, by role
	Difficulty.load_data(without)
	Difficulty.set_level("classic")
	var pp_text := Tooltips.stat_info("PP")
	if not pp_text.contains("+10 per second") or not pp_text.contains("+1 per 10 damage taken") or pp_text.contains("hits it"):
		_fail("PP tooltip (web rules): " + pp_text)
	Difficulty.load_data()
	Difficulty.set_level("classic")
	pp_text = Tooltips.stat_info("PP")
	if pp_text.contains("per second") or pp_text.contains("damage taken"):
		_fail("PP tooltip: " + pp_text)
	for role in expected:
		var rule: Array = expected[role]
		var words := "+%s per attack that hits, +%s each time an attack hits it" % [ # no PP to cast: the form's own
			Tooltips.plain_number(rule[1]), Tooltips.plain_number(rule[2])]
		if not pp_text.contains(words):
			_fail("PP tooltip without the rules of %s (%s): %s" % [role, words, pp_text])
		if by_role.has(role) and not Tooltips.stat_info("PP", by_role[role]).contains(words):
			_fail("PP tooltip of a %s: %s" % [role, Tooltips.stat_info("PP", by_role[role])])
	# PP of the effects in the web's scale (a 100-PP bar, BattleUnit.add_pp / drain_pp), the rules as they are
	var probe := BattleUnit.create("MAGIKARP", BattleUnit.Team.BLUE)
	probe.max_pp = 50.0
	probe.pp = 0.0
	probe.add_pp(10.0)
	probe.add_pp(10.0, true)
	var lost := probe.drain_pp(20.0)
	if not is_equal_approx(lost, 20.0) or not is_equal_approx(probe.pp, 5.0):
		_fail("PP of a 100-PP bar: a 50-PP unit after +10, +10 raw, -20: %s PP, lost %s" % [probe.pp, lost])
	print("mana ok: %s" % pp_text)


## A region reached unlocks its locked synergies for the run (GameData.unlock_for_run, PlayerState.change_map):
## types, shop pool, portals; a new run (begin_run) locks them again. At pass level 1 (`open` unlocked).
func _check_run_unlocks(open: Array) -> void:
	var region := ""
	for m in GameData.config.maps:
		if m != "town" and GameData.region_unlocks(m).size() >= 2:
			region = m
			break
	if region == "":
		_fail("run unlocks: no region with 2 locked synergies at pass level 1")
		return
	var fresh := GameData.region_unlocks(region)
	var p := PlayerState.new()
	var pool_before := GameData.pool.size()
	var counts_before := p.pool_counts.size()
	p.change_map(region)
	var pool_after := GameData.pool.size()
	for s in fresh:
		_expect(GameData.synergy_unlocked(s) and GameData.run_unlocked.has(s) and p.run_unlocks.has(s),
			"run unlocks: %s of %s not unlocked" % [s, region])
	_expect(GameData.region_unlocks(region).is_empty() and Array(GameData.synergies()).size() == open.size() + fresh.size(),
		"run unlocks: %s, synergies %s" % [region, GameData.synergies()])
	_expect(GameData.pool.size() > pool_before and p.pool_counts.size() > counts_before and not p.pool_news.is_empty(),
		"run unlocks: the shop pool did not grow (%d -> %d families)" % [pool_before, GameData.pool.size()])
	var joined := 0
	for rarity in GameData.SHOP_RARITIES:
		for pkm in p.shop_candidates(rarity):
			if p.pool_counts.get(pkm, 0) <= 0:
				_fail("run unlocks: %s in the shop without copies" % pkm)
			var types: Array = GameData.get_pokemon(pkm).types
			joined += 1 if types.any(func(t: String) -> bool: return fresh.has(t)) else 0
	_expect(joined > 0, "run unlocks: no family of %s in the shop" % [fresh])
	for i in 30:
		p.roll_shop()
	for portal in Town.portals(p, 10, RandomNumberGenerator.new()):
		for s in portal.unlocks:
			_expect(not GameData.synergy_unlocked(s), "run unlocks: a portal unlocks %s again" % s)
	# the same region again: nothing more; a new run: the pass alone
	p.change_map("town")
	p.change_map(region)
	_expect(p.run_unlocks.size() == fresh.size(), "run unlocks: %s twice" % [p.run_unlocks])
	GameData.begin_run()
	_expect(GameData.run_unlocked.is_empty() and Array(GameData.synergies()) == open and GameData.pool.size() == pool_before,
		"run unlocks: a new run still has %s" % [GameData.run_unlocked])
	print("run unlocks ok: %s unlocks %s, shop pool %d -> %d forms" % [region, fresh, pool_before, pool_after])


## Drives the wave editor (tools/wave_editor) without saving: every action of both tabs.
func _check_wave_editor() -> void:
	var ed: Control = load("res://tools/wave_editor/wave_editor.tscn").instantiate()
	add_child(ed)
	var on_disk = JSON.parse_string(FileAccess.get_file_as_string(WaveTemplates.PATH))
	if JSON.stringify(ed._whole_numbers(ed._templates_to_save())) != JSON.stringify(ed._whole_numbers(on_disk)):
		_fail("wave editor: saving unchanged templates would change the file")
	var before: int = ed._templates().size()
	ed._add_template()
	ed._duplicate_template()
	ed._move_template(-1)
	var tpl: Dictionary = ed._template()
	tpl.slots.append(WaveTemplates.slot_with_defaults({"pkm": "PIKACHU", "items": ["MAGNET"], "stars": 2}))
	tpl.slots.append(WaveTemplates.slot_with_defaults({"count": 2, "types": ["WATER"], "rarity": ["COMMON", "UNIQUE"], "randomItems": 1}))
	tpl.bonusSynergies["ELECTRIC"] = 2
	ed._changed(true)
	ed._rebuild_form()
	ed._open_pokemon_picker(func(pkm: String) -> void: tpl.slots[0].pkm = pkm)
	ed._picker_filter.text = "charizard"
	ed._fill_picker()
	if ed._picker_list.item_count == 0:
		_fail("wave editor: the Pokémon picker finds no Charizard")
	else:
		ed._picked(0)
	ed._open_item_picker(func(item: String) -> void: tpl.slots[0].items.append(item))
	ed._picked(0)
	if not String(tpl.slots[0].pkm).begins_with("CHARIZARD") and tpl.slots[0].pkm != "CHARMANDER" or tpl.slots[0].items.is_empty():
		_fail("wave editor pickers: %s" % [tpl.slots[0]])
	for force in [true, false]:
		ed._preview_force.button_pressed = force
		for stage in [1, 7, 14, 33]:
			ed._preview_stage.value = stage
			ed._refresh_preview()
	var forced: Dictionary = {}
	ed._preview_force.button_pressed = true
	forced = ed._preview_wave()
	if forced.get("kind", "") != "template" or forced.board.size() < 4:
		_fail("wave editor preview: %s" % [forced.get("board")])
	var saved: Dictionary = ed._templates_to_save()
	if saved.templates.size() != before + 2 or saved.templates[0].has("enabled"):
		_fail("wave editor: templates to save %s" % [saved.templates.size()])
	ed._delete_template()
	# difficulty tab: every scope, overriding and clearing every row
	ed._show_page(1)
	for i in ed._scope_list.item_count:
		ed._scope_list.select(i)
		ed._scope_list.item_selected.emit(i)
	var level: Dictionary = ed._scope_dict()
	for entry in ed.SCHEMA:
		if entry[0] == "#":
			continue
		var value = ed._inherited(entry[0])
		ed._set_path(level, entry[0], value if value != null else ed._diff_default(entry))
	ed._changed()
	ed._build_diff_form()
	ed._refresh_diff_table()
	if ed._get_path(level, "endless.maxUnits") == null or not ed._diff_table.text.contains("[table"):
		_fail("wave editor: difficulty form")
	for entry in ed.SCHEMA:
		if entry[0] != "#":
			ed._erase_path(level, entry[0])
	ed._show_page(0)
	ed.queue_free()
	WaveTemplates.load_data()
	Difficulty.load_data()
	Difficulty.set_level("classic")
	get_tree().auto_accept_quit = true
	print("wave editor ok")


func _check_fights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var results := []
	for stage in [1, 3, 8, 15, 24, 33, 45]:
		var wave := EndlessWaves.get_stage(stage, 777)
		var sim := BattleSim.new()
		var team_size := clampi(2 + stage / 5, 2, 9)
		var cells := BattleBoard.all_cells().filter(func(c: Vector2i) -> bool: return c.y < BattleBoard.SIDE_ROWS)
		cells.shuffle()
		for i in team_size:
			var pkm: String = GameData.pool[rng.randi() % GameData.pool.size()]
			sim.add_unit(BattleUnit.create(GameData.evolve_to(pkm, 1 + stage / 12), BattleUnit.Team.BLUE), cells[i])
		for i in wave.board.size():
			var entry: Array = wave.board[i]
			var u := BattleUnit.create(entry[0], BattleUnit.Team.RED)
			u.apply_stat_boosts(wave.get("statBoosts", {}))
			u.equip(wave.items[i], sim.rng)
			sim.add_unit(u, EndlessWaves.to_sim_cell(int(entry[1]), int(entry[2])))
		var events := 0
		var kinds := {}
		while not sim.finished:
			sim.update(16.6)
			for e in sim.drain_events():
				events += 1
				kinds[e.type] = kinds.get(e.type, 0) + 1
		sim.dispose()
		if sim.time_ms < 100.0:
			_fail("fight ended instantly at stage %d" % stage)
		results.append("s%d %s in %.1fs (%d casts, %d deaths)" % [stage,
			{0: "WIN", 1: "LOSS", -1: "DRAW"}[sim.winner], sim.time_ms / 1000.0,
			kinds.get("cast", 0), kinds.get("death", 0)])
	print("fights:\n  " + "\n  ".join(results))


## The rules ported on 2026-10-04 (statuses, passives, evolution rules, shop specials, rewards...).
## Records: best stage per difficulty, runs counted (test file, not the player's records).
func _check_records() -> void:
	Records.path = "user://test_records.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Records.path))
	_expect(Records.best("normal").is_empty(), "records: none at first")
	_expect(Records.submit("normal", 12, [{"pkm": "PIKACHU", "stars": 2}]), "records: first run is a record")
	_expect(not Records.submit("normal", 9, []), "records: lower stage is not a record")
	_expect(Records.submit("hard", 4, []), "records: per difficulty")
	var best := Records.best("normal")
	_expect(int(best.get("stage", 0)) == 12 and int(best.get("runs", 0)) == 2 and best.team.size() == 1,
		"records: best %s" % best)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Records.path))


func _check_ported_rules() -> void:
	_check_status_rules()
	_check_new_passives()
	_check_evolution_rules()
	_check_shop_rules()
	_check_stage_rewards()


func _new_fight(blue: Array, red: Array) -> BattleSim:
	var sim := BattleSim.new()
	sim.rng.seed = 11
	for entry in blue:
		sim.add_unit(entry[0], entry[1])
	for entry in red:
		sim.add_unit(entry[0], entry[1])
	return sim


func _check_status_rules() -> void:
	# CONFUSION: half of the time the allies and itself are targets too (attacking-state.ts)
	var a := BattleUnit.create("MACHOP", BattleUnit.Team.BLUE)
	var ally := BattleUnit.create("MACHOP", BattleUnit.Team.BLUE)
	var foe := BattleUnit.create("MAGIKARP", BattleUnit.Team.RED)
	var sim := _new_fight([[a, Vector2i(3, 2)], [ally, Vector2i(2, 2)]], [[foe, Vector2i(3, 3)]])
	sim.add_status(a, "confusion", 5000.0)
	var hit_friend := false
	for _i in 60:
		var t := sim._confused_target(a)
		hit_friend = hit_friend or (t != null and t.team == a.team)
	if not hit_friend:
		_fail("confusion: never targets an ally or itself")
	# a status that cannot be stacked: a second FREEZE is ignored; after a SLEEP, 1.5 s without crowd control
	sim.add_status(ally, "freeze", 1000.0)
	sim.add_status(ally, "freeze", 5000.0)
	if ally.statuses.get("freeze", 0.0) > 1001.0:
		_fail("freeze stacked (%s)" % ally.statuses.freeze)
	for _i in 30:
		sim.update(50.0)
	if ally.has_status("freeze") or not ally.counters.has("cc_cooldown"):
		_fail("freeze end: crowd control cooldown")
	sim.add_status(ally, "sleep", 2000.0)
	if ally.has_status("sleep"):
		_fail("sleep during the crowd control cooldown")
	# LOCKED: range 1 while it lasts, then back
	var ranged := BattleUnit.create("ABRA", BattleUnit.Team.BLUE)
	sim.add_unit(ranged, Vector2i(5, 0))
	var base := ranged.attack_range
	sim.add_status(ranged, "locked", 500.0)
	if ranged.attack_range != 1:
		_fail("locked: range 1")
	for _i in 15:
		sim.update(50.0)
	if ranged.attack_range != base:
		_fail("locked end: range %d, expected %d" % [ranged.attack_range, base])
	# Protect blocks damage, not statuses (only Rune Protect does)
	sim.add_status(a, "protect", 3000.0)
	sim.add_status(a, "burn", 3000.0)
	if not a.has_status("burn"):
		_fail("Protect should not block BURN")
	sim.dispose()

	# COTTON_BALL: asleep once while it stays on the cell, again after leaving and coming back
	var sleeper := BattleUnit.create("MACHOP", BattleUnit.Team.RED)
	var b := BattleUnit.create("MACHOP", BattleUnit.Team.BLUE)
	sim = _new_fight([[b, Vector2i(0, 0)]], [[sleeper, Vector2i(6, 7)]])
	sim.add_status(sleeper, "safeguard", 0.0)
	AbilityScripts.board_effect(sim, [Vector2i(6, 7)], "COTTON_BALL")
	sim._each_second(sleeper)
	if not sleeper.has_status("sleep"):
		_fail("cotton ball: no sleep")
	sleeper.statuses.erase("sleep")
	sleeper.counters.erase("cc_cooldown")
	sim._each_second(sleeper)
	if sleeper.has_status("sleep"):
		_fail("cotton ball: slept twice on the same cell")
	sim.move_unit(sleeper, Vector2i(6, 5), 100.0)
	sim.move_unit(sleeper, Vector2i(6, 7), 100.0)
	sim._each_second(sleeper)
	if not sleeper.has_status("sleep"):
		_fail("cotton ball: back on the cell, no sleep")
	if not sim.board_effects.get(Vector2i(6, 7), {}).has("COTTON_BALL"):
		_fail("cotton ball: the cell lost it")
	sim.dispose()

	# Resurrection: back after 2 s with the stats it had when it entered the fight
	var r := BattleUnit.create("MACHOP", BattleUnit.Team.BLUE)
	r.equip(["MAX_REVIVE"])
	sim = _new_fight([[r, Vector2i(3, 0)]], [[BattleUnit.create("MAGIKARP", BattleUnit.Team.RED), Vector2i(0, 5)]])
	var atk := r.atk
	r.add_stat("atk", 50.0)
	sim.deal_damage(r, 9999.0, BattleUnit.DamageKind.TRUE, null)
	for _i in 45:
		sim.update(50.0)
	if r.has_status("resurrecting") or absf(r.atk - atk) > 0.01 or r.pp != 0.0:
		_fail("resurrection: stats of the fight start (atk %s, expected %s)" % [r.atk, atk])
	sim.dispose()


func _check_new_passives() -> void:
	var p := PlayerState.new()
	# Falinks formation: the troopers of the bench give the brass their ATK / DEF / HP and count for No Retreat
	if GameData.is_available("FALINKS_BRASS") and GameData.is_available("FALINKS_TROOPER"):
		var brass_owned := PlayerState.OwnedUnit.new("FALINKS_BRASS")
		p.board[Vector2i(3, 2)] = brass_owned
		p.bench[0] = PlayerState.OwnedUnit.new("FALINKS_TROOPER")
		p.bench[1] = PlayerState.OwnedUnit.new("FALINKS_TROOPER")
		var setup := FightSetup.create(p, {"board": [["MAGIKARP", 3, 3]], "items": [[]]})
		var brass: BattleUnit = setup.owned[brass_owned.id]
		if int(brass.effects.get("falinks", 0)) != 2:
			_fail("Falinks formation: %s troopers counted" % brass.effects.get("falinks", 0))
		setup.sim.dispose()
		p.board.clear()
		p.bench[0] = null
		p.bench[1] = null
	# Kubfu: a physical KO = +3 SPEED for good
	if GameData.pokemon.has("KUBFU"):
		var k := BattleUnit.create("KUBFU", BattleUnit.Team.BLUE)
		k.owned = PlayerState.OwnedUnit.new("KUBFU")
		var victim := BattleUnit.create("MAGIKARP", BattleUnit.Team.RED)
		var sim := _new_fight([[k, Vector2i(3, 2)]], [[victim, Vector2i(3, 3)]])
		sim.deal_damage(victim, 9999.0, BattleUnit.DamageKind.PHYSICAL, k)
		if float(k.owned.mods.get("speed", 0.0)) != 3.0:
			_fail("Kubfu: +3 SPEED after a physical KO (%s)" % k.owned.mods)
		sim.dispose()
	# Comfey becomes the item of an ally
	if GameData.pokemon.has("COMFEY"):
		var comfey := BattleUnit.create("COMFEY", BattleUnit.Team.BLUE)
		var holder := BattleUnit.create("MACHOP", BattleUnit.Team.BLUE)
		var sim := _new_fight([[comfey, Vector2i(3, 1)], [holder, Vector2i(3, 2)]], [[BattleUnit.create("MAGIKARP", BattleUnit.Team.RED), Vector2i(0, 5)]])
		sim.update(10.0)
		if comfey.alive or not holder.has_item("COMFEY"):
			_fail("Comfey: not held by its ally")
		sim.dispose()
	# Melmetal: SPEED buffs give half as much ATK
	if GameData.pokemon.has("MELMETAL"):
		var m := BattleUnit.create("MELMETAL", BattleUnit.Team.BLUE)
		var atk := m.atk
		var speed := m.speed
		m.add_stat("speed", 20.0)
		if m.speed != speed or m.atk != atk + 10.0:
			_fail("Melmetal: SPEED buff as ATK")
	# Magnet Pull: a catchable Steel Pokémon (or Meltan) watches the fight
	var mp := PlayerState.new()
	var pulled := mp.magnet_pull_pick(0.0, 0.0)
	if pulled == "" or (pulled != "MELTAN" and not GameData.get_pokemon(pulled).types.has("STEEL")):
		_fail("Magnet Pull picked %s" % pulled)


func _check_evolution_rules() -> void:
	_check_apples_and_shown_copies()
	var p := PlayerState.new()
	# STACK: Primeape evolves at 10 stacks
	if GameData.is_available("ANNIHILAPE"):
		var u := PlayerState.OwnedUnit.new("PRIMEAPE")
		p.board[Vector2i(0, 0)] = u
		u.stacks = 10
		EvolutionRules.check_board(p, ["stack"])
		if u.pkm != "ANNIHILAPE":
			_fail("Primeape: 10 stacks = Annihilape (%s)" % u.pkm)
		p.board.clear()
	# MONEY: Gimmighoul at 99 gold
	if GameData.is_available("GHOLDENGO"):
		var g := PlayerState.OwnedUnit.new("GIMMIGHOUL")
		p.board[Vector2i(1, 0)] = g
		p.gold = 99
		p._board_changed()
		if g.pkm != "GHOLDENGO":
			_fail("Gimmighoul: 99 gold = Gholdengo (%s)" % g.pkm)
		p.board.clear()
	# STATE: Tandemaus from stage 15
	if GameData.is_available("MAUSHOLD_THREE"):
		var t := PlayerState.OwnedUnit.new("TANDEMAUS")
		p.board[Vector2i(2, 0)] = t
		p.stage = 15
		EvolutionRules.check_board(p, ["state"])
		if t.pkm != "MAUSHOLD_THREE":
			_fail("Tandemaus: stage 15 = Maushold (%s)" % t.pkm)
		p.board.clear()
	# PLACEMENT: Mantyke next to a Remoraid
	if GameData.is_available("MANTINE"):
		var m := PlayerState.OwnedUnit.new("MANTYKE")
		p.board[Vector2i(3, 1)] = m
		p.board[Vector2i(4, 1)] = PlayerState.OwnedUnit.new("REMORAID")
		p._board_changed()
		if m.pkm != "MANTINE":
			_fail("Mantyke next to Remoraid = Mantine (%s)" % m.pkm)
		p.board.clear()
	# COUNT, regional: Dewott into Hisuian Samurott in its region
	if GameData.is_available("HISUI_SAMUROTT"):
		p.regional_pokemons.assign(["HISUI_SAMUROTT"])
		var copies := [PlayerState.OwnedUnit.new("DEWOTT"), PlayerState.OwnedUnit.new("DEWOTT"), PlayerState.OwnedUnit.new("DEWOTT")]
		if p.evolution_for("DEWOTT", copies) != "HISUI_SAMUROTT":
			_fail("Dewott: the regional evolution of the region")
		p.regional_pokemons.clear()
	# COUNT: the permanent stats of the copies add up
	var b1 := PlayerState.OwnedUnit.new("CHARMANDER")
	b1.mods.atk = 4.0
	var b2 := PlayerState.OwnedUnit.new("CHARMANDER")
	b2.mods.atk = 4.0
	p.bench[0] = b1
	p.bench[1] = b2
	p.bench[2] = PlayerState.OwnedUnit.new("CHARMANDER")
	p.check_merges()
	var evolved: PlayerState.OwnedUnit = p.bench[0]
	if evolved == null or evolved.pkm != "CHARMELEON" or float(evolved.mods.get("atk", 0.0)) != 8.0:
		_fail("merge: permanent stats carried over (%s)" % (evolved.mods if evolved != null else "none"))
	for i in p.bench_size:
		p.bench[i] = null
	# Nincada: Ninjask brings a Shedinja
	if GameData.is_available("NINJASK") and GameData.is_available("SHEDINJA"):
		for i in 3:
			p.bench[i] = PlayerState.OwnedUnit.new("NINCADA")
		p.check_merges()
		var names: Array = p.bench.filter(func(u) -> bool: return u != null).map(func(u) -> String: return u.pkm)
		if not names.has("NINJASK") or not names.has("SHEDINJA"):
			_fail("Nincada x3: Ninjask and Shedinja (%s)" % [names])
		for i in p.bench_size:
			p.bench[i] = null
	# Ditto dropped on a Pokémon: a copy of its first form
	if GameData.is_available("DITTO"):
		var ditto := PlayerState.OwnedUnit.new("DITTO")
		p.bench[0] = ditto
		p.board[Vector2i(3, 2)] = PlayerState.OwnedUnit.new("CHARMELEON")
		if not p.move_unit(ditto, {"board": Vector2i(3, 2)}) or p.bench[0] == null or p.bench[0].pkm != "CHARMANDER":
			_fail("Ditto: copy of the first form")
		p.board.clear()
		for i in p.bench_size:
			p.bench[i] = null


func _check_shop_rules() -> void:
	var p := PlayerState.new()
	# finished lines leave the shop
	p.board[Vector2i(0, 0)] = PlayerState.OwnedUnit.new("CHARIZARD")
	if not p.finalized_lines().has("CHARMANDER"):
		_fail("finalized lines: Charizard owned")
	p.level = 3
	for _i in 200:
		p.roll_shop()
		if p.shop.has("CHARMANDER"):
			_fail("the shop offers a finished line")
			break
	p.board.clear()
	# sell prices (getSellPrice)
	var prices := {"DITTO": 5, "MAGIKARP": 0, "EGG": 2}
	for pkm in prices:
		if GameData.pokemon.has(pkm) and p.sell_price(PlayerState.OwnedUnit.new(pkm)) != prices[pkm]:
			_fail("sell price of %s: %d" % [pkm, p.sell_price(PlayerState.OwnedUnit.new(pkm))])
	if not GameData.unique.is_empty():
		var u: String = GameData.unique.filter(func(x: String) -> bool: return GameData.duo_of(x) == "")[0]
		if p.sell_price(PlayerState.OwnedUnit.new(u)) != PlayerState.UNIQUE_SELL:
			_fail("sell price of a Unique")


func _check_stage_rewards() -> void:
	# the Treasure Box rewards that exist now
	var p := PlayerState.new()
	p.treasure_reward = "sweets"
	Town.open_treasure_box(p, p.rng)
	if p.items.filter(func(i: String) -> bool: return GameData.item_in(i, "Sweets")).size() != 5:
		_fail("Treasure Box: 5 sweets")
	# Celebi makes the next waves shiny
	var shiny := PlayerState.new()
	shiny.shiny_encounter = true
	var setup := FightSetup.create(shiny, {"board": [["MAGIKARP", 3, 3]], "items": [[]]})
	if not setup.enemies[0].effects.get("shiny", false):
		_fail("shiny encounter: the wave is not shiny")
	setup.sim.dispose()
	if not Town.PORTED_ENCOUNTERS.has("CELEBI") or not Town.PORTED_ENCOUNTERS.has("KINGAMBIT"):
		_fail("Celebi / Kingambit encounters")


## Applin eats an apple to evolve (game-commands.ts: the dish is held just in time for the item
## evolution, the form acquired consumes it); a Pokémon shown in the shop has left its pool.
func _check_apples_and_shown_copies() -> void:
	var p := PlayerState.new()
	if GameData.is_available("APPLIN") and GameData.is_available("HYDRAPPLE"):
		var applin := PlayerState.OwnedUnit.new("APPLIN")
		p.bench[0] = applin
		p.items.append("SIRUPY_APPLE")
		p.equip(p.items.find("SIRUPY_APPLE"), applin)
		if applin.pkm != "DIPPLIN" or not applin.dishes.is_empty() or applin.items.has("SIRUPY_APPLE"):
			_fail("Applin + Sirupy Apple: %s dishes %s items %s" % [applin.pkm, applin.dishes, applin.items])
		p.items.append("SIRUPY_APPLE")
		p.equip(p.items.find("SIRUPY_APPLE"), applin)
		if applin.pkm != "HYDRAPPLE" or not applin.dishes.is_empty():
			_fail("Dipplin + Sirupy Apple: %s dishes %s" % [applin.pkm, applin.dishes])
		var other := PlayerState.OwnedUnit.new("APPLIN")
		p.bench[1] = other
		p.items.append("TART_APPLE")
		p.equip(p.items.find("TART_APPLE"), other)
		if other.pkm != "FLAPPLE":
			_fail("Applin + Tart Apple: " + other.pkm)
	p = PlayerState.new()
	var total := func() -> int:
		var n := 0
		for k in p.pool_counts:
			n += int(p.pool_counts[k])
		return n
	var full: int = total.call()
	p.level = 3
	p.stage = 2
	for _i in 20:
		p.roll_shop()
		var shown := p.shop.filter(func(s: String) -> bool: return p.pool_counts.has(GameData.regional_base.get(s, s))).size()
		if total.call() != full - shown:
			_fail("shop copies should be out of the pool: %d shown, %d of %d left" % [shown, total.call(), full])
			break
	var slot := -1
	for i in p.shop.size():
		if p.pool_counts.has(p.shop[i]):
			slot = i
	if slot >= 0:
		var before: int = total.call()
		p.gold = 50
		p.buy(slot)
		if total.call() != before:
			_fail("buying must not take a second copy")
		var bought: PlayerState.OwnedUnit = p.bench[0]
		p.sell(bought)
		if total.call() != before + 1:
			_fail("selling a 1 star gives its copy back")


## Battle Pass (Progression, data/progression.json; not in the web game): the file, the XP / level rule
## on a test save, and what a locked synergy hides (GameData.apply_progression).
func _check_progression() -> void:
	for problem in Progression.problems():
		_fail("progression.json: " + problem)
	var every: Array = GameData.config.synergyThresholds.keys()
	var by_level := {}
	for l in range(1, Progression.max_level() + 1):
		for s in Progression.rewards(l):
			_expect(not by_level.has(s), "progression: %s unlocked twice" % s)
			by_level[s] = l
	_expect(by_level.size() == every.size(), "progression: %d of %d synergies have a level" % [by_level.size(), every.size()])
	_expect(Progression.unlocked_synergies(Progression.max_level()).size() == every.size(), "progression: the last level unlocks everything")
	_expect(GameData.all_unlocked and GameData.pool.size() == GameData.full_list("pool").size(),
		"progression: the checks above run with everything unlocked")

	# XP and levels, on a test save
	var real_path := Progression.path
	var real_override := Progression.override_level
	Progression.override_level = -1
	Progression.path = "user://test_progress.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Progression.path))
	Progression.forget()
	_expect(Progression.level() == 1 and Progression.xp() == 0, "progression: a new pass starts at level 1")
	if Progression.max_level() >= 3:
		var cost := Progression.level_cost(2)
		var gain := Progression.add_xp(cost - 1)
		_expect(Progression.level() == 1 and int(gain.to) == 1, "progression: level 2 needs its whole cost")
		gain = Progression.add_xp(1)
		_expect(Progression.level() == 2 and int(gain.from) == 1 and int(gain.to) == 2 and gain.unlocked == Progression.rewards(2),
			"progression: level 2 reached: %s" % gain)
		Progression.forget() # read back from the file
		_expect(Progression.level() == 2 and Progression.xp() == cost, "progression: the pass is saved")
		var p2 := Progression.progress()
		_expect(int(p2.into) == 0 and int(p2.need) == Progression.level_cost(3), "progression: progress %s" % p2)
		_expect(Progression.unseen_synergies() == Progression.rewards(2), "progression: level 2 not seen yet")
		Progression.mark_seen()
		_expect(Progression.unseen_synergies().is_empty(), "progression: seen once the pass screen opened")
		_expect(Progression.take_run_news() == Progression.rewards(2) and Progression.take_run_news().is_empty(),
			"progression: the run start tells the new synergies once")
		var report := Progression.report(cost, 1)
		_expect(int(report.xp) == cost and int(report.from) == 1 and int(report.to) == 2 and report.unlocked == Progression.rewards(2),
			"progression: report %s" % report)
	Difficulty.set_level("hard")
	var hard_xp := Progression.run_xp() + Progression.stage_xp(true)
	Difficulty.set_level("classic")
	_expect(Progression.stage_xp(true) >= Progression.stage_xp(false), "progression: a win gives no less XP than a loss")
	_expect(hard_xp >= Progression.run_xp() + Progression.stage_xp(true), "progression: no less XP on hard than on classic")
	# the pace asked for: one run reaches level 2, then a level (two synergies) every three runs
	if Progression.max_level() >= 3 and Progression.run_xp() > 0:
		_expect(Progression.level_cost(2) <= Progression.run_xp(), "progression: one run reaches level 2")
		_expect(Progression.level_cost(3) <= 3 * Progression.run_xp() and Progression.level_cost(3) > 2 * Progression.run_xp(),
			"progression: level 3 takes three runs (%d XP, %d a run)" % [Progression.level_cost(3), Progression.run_xp()])
	Progression.add_xp(1000000)
	_expect(Progression.level() == Progression.max_level() and int(Progression.progress().need) == 0, "progression: the last level is the cap")

	# level 1: the locked synergies are hidden everywhere
	Progression.set_level(1)
	GameData.apply_progression()
	var open: Array = Progression.unlocked_synergies()
	var locked: Array = every.filter(func(t: String) -> bool: return not open.has(t))
	if locked.is_empty():
		print("progression: nothing is locked at level 1")
	else:
		_expect(not GameData.all_unlocked and Array(GameData.synergies()) == open, "progression: GameData.synergies %s" % [GameData.synergies()])
		var leaked := 0
		for pkm in GameData.pokemon:
			for t in GameData.pokemon[pkm].types:
				leaked += 0 if open.has(t) else 1
		_expect(leaked == 0, "progression: %d locked types still on Pokémon" % leaked)
		for list in [GameData.pool, GameData.additional, GameData.unique, GameData.legendary, GameData.hatch, GameData.regional]:
			for pkm in list:
				var first: Dictionary = GameData.get_pokemon(String(GameData.get_pokemon(pkm).family))
				if not first.all_types.is_empty() and first.types.is_empty():
					_fail("progression: %s is offered but its family has no unlocked synergy" % pkm)
				for gate in Progression.gated_types():
					if locked.has(gate) and first.all_types.has(gate):
						_fail("progression: %s is offered but %s is locked" % [pkm, gate])
		_expect(GameData.pool.size() < GameData.full_list("pool").size(), "progression: the pool shrinks at level 1")
		for rarity in GameData.SHOP_RARITIES: # three starting synergies: 3 Ultra families
			_expect(GameData.tier1_by_rarity[rarity].size() >= 3,
				"progression: only %d %s families in the shop at level 1" % [GameData.tier1_by_rarity[rarity].size(), rarity])
		for s in open:
			var families := 0
			for rarity in GameData.SHOP_RARITIES:
				families += GameData.tier1_by_rarity[rarity].filter(func(pkm: String) -> bool: return GameData.get_pokemon(pkm).types.has(s)).size()
			_expect(families >= int(Synergies.thresholds(s)[0]),
				"progression: %s cannot reach its first tier with the shop of level 1 (%d families)" % [s, families])
		for m in GameData.config.maps:
			for s in GameData.config.maps[m].synergies:
				_expect(open.has(s), "progression: region %s shows the locked %s" % [m, s])
		# counting: a locked synergy never counts nor activates; its items give nothing and are not offered
		var hidden: String = locked[0]
		_expect(Synergies.tier(hidden, 9) == 0 and Synergies.count([], {hidden: 3}).is_empty(), "progression: %s must not count" % hidden)
		for item in GameData.items:
			var given := String(GameData.items[item].get("synergy", ""))
			if given != "" and locked.has(given):
				_expect(GameData.item_synergy(item) == "" and GameData.item_locked(item), "progression: %s gives the locked %s" % [item, given])
				for category in ["SynergyGems", "SynergyStones", "SynergyItems", "Tools", "ToolsBuried", "SynergyGemsBuried", "MemoryDiscs"]:
					if GameData.item_in(item, category) and GameData.items_in(category).has(item):
						_fail("progression: %s of the locked %s is in the pool %s" % [item, given, category])
				_expect(not GameData.full_items.has(item), "progression: %s is a full item of the pools" % item)
		# a run: shop, portals, propositions, waves
		var p := PlayerState.new()
		p.level = 9
		p.stage = 12
		for _i in 40:
			p.roll_shop()
			for s in p.shop:
				if s != "" and not GameData.pokemon_unlocked(s):
					_fail("progression: the shop offers %s" % s)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for stage in [0, 10, 20]:
			for portal in Town.portals(p, stage, rng):
				for s in portal.synergies:
					_expect(open.has(s), "progression: a portal shows the locked %s" % s)
			for offered in Town.propositions(p, stage, [open[0], open[1 % open.size()]], rng).pokemons:
				for member in String(offered).split("+"):
					_expect(GameData.pokemon_unlocked(member), "progression: %s is offered at stage %d" % [member, stage])
		for stage in [5, 8, 11]:
			for offered in Town.additional_pick(stage, rng).pokemons:
				_expect(GameData.pokemon_unlocked(offered), "progression: additional pick %s" % offered)
		Difficulty.set_level("hard") # templates and enemy synergies
		for run_seed in [3, 77]:
			for stage in range(1, 46):
				var wave := EndlessWaves.get_stage(stage, run_seed)
				if String(wave.get("kind", "")) != "boss":
					for entry in wave.board:
						_expect(GameData.pokemon_unlocked(entry[0]), "progression: %s in the wave of stage %d (%s)" % [
							entry[0], stage, wave.get("template", wave.get("name", ""))])
				for t in EndlessWaves.synergy_counts(wave):
					_expect(open.has(t), "progression: the wave of stage %d counts the locked %s" % [stage, t])
		Difficulty.set_level("classic")
		# a fight of level 1 runs (types and synergies of both teams come from the unlocked ones)
		var fighter: String = GameData.tier1_by_rarity["COMMON"][0]
		p = PlayerState.new()
		p.board[Vector2i(3, 2)] = PlayerState.OwnedUnit.new(fighter)
		var fight := FightSetup.create(p, EndlessWaves.get_stage(6, 77))
		for _i in 400:
			if fight.sim.finished:
				break
			fight.sim.update(BattleSim.MAX_STEP_MS)
		for u in fight.sim.units:
			for t in u.types:
				_expect(open.has(t), "progression: %s fights with the locked %s" % [u.pkm, t])
		fight.sim.dispose()
		# a regional variant waits for the region synergy it lives by (Alolan Vulpix: ICE regions)
		# (a region none of its links explains: by its own types there, Shellos East Sea in Aquatic regions)
		for variant in GameData.regional_info:
			for m in GameData.regional_info[variant].maps:
				var reasons := GameData.region_reasons(variant, m)
				if not reasons.is_empty() and not reasons.any(func(s: String) -> bool: return open.has(s)):
					_expect(not GameData.in_region(variant, m), "progression: %s found in %s by a locked synergy" % [variant, m])
		_check_run_unlocks(open)
		print("progression ok: %d levels, start %s, level 1 shop %d / %d families, %d synergies locked" % [Progression.max_level(),
			open, GameData.SHOP_RARITIES.map(func(r: String) -> int: return GameData.tier1_by_rarity[r].size()).reduce(
				func(a: int, b: int) -> int: return a + b, 0),
			GameData.full_list("pool").filter(func(pkm: String) -> bool:
				var d := GameData.get_pokemon(pkm)
				return int(d.stars) == 1 and GameData.SHOP_RARITIES.has(d.rarity)).size(), locked.size()])

	# every level: nothing breaks, the shop only grows
	var before := 0
	for l in range(1, Progression.max_level() + 1):
		Progression.set_level(l)
		GameData.apply_progression()
		var shop_families := 0
		for rarity in GameData.SHOP_RARITIES:
			shop_families += GameData.tier1_by_rarity[rarity].size()
		_expect(shop_families >= before, "progression: the shop shrinks at level %d (%d < %d)" % [l, shop_families, before])
		before = shop_families
	_expect(GameData.all_unlocked and GameData.pool.size() == GameData.full_list("pool").size(), "progression: the last level hides nothing")
	for variant in GameData.regional_info: # the inferred links never hide a region once everything is unlocked
		for m in GameData.regional_info[variant].maps:
			_expect(GameData.in_region(variant, m), "progression: %s lost its region %s" % [variant, m])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Progression.path))
	Progression.path = real_path
	Progression.override_level = real_override
	Progression.forget()
	GameData.apply_progression()


## The master switch of the pass (progression.json "enabled"): off = everything unlocked, no XP.
func _check_progression_switch() -> void:
	var file: Dictionary = Progression.data().duplicate(true)
	var real_override := Progression.override_level
	Progression.override_level = 1
	var off := file.duplicate(true)
	off["enabled"] = false
	Progression.load_data(off)
	GameData.apply_progression()
	_expect(not Progression.enabled() and Progression.level() == Progression.max_level() and GameData.all_unlocked,
		"progression off: level %d, all unlocked %s" % [Progression.level(), GameData.all_unlocked])
	_expect(int(Progression.add_xp(50).gained) == 0, "progression off: no XP")
	Progression.load_data(file)
	GameData.apply_progression()
	_expect(Progression.enabled() and Progression.level() == 1 and (Progression.max_level() == 1 or not GameData.all_unlocked),
		"progression on again: level %d" % Progression.level())
	Progression.override_level = real_override
	GameData.apply_progression()

## Lines (families) of the shop having `type` in one of their forms; the Flabébé colours are one line.
func _season_lines(type: String) -> int:
	var seen := {}
	for pkm in Tooltips.pokemons_of_type(type):
		var family := String(GameData.get_pokemon(pkm).family)
		seen["FLABEBE" if PlayerState.FLABEBE_FORMS.has(family) else family] = true
	return seen.size()


## Seasons (Seasons, data/seasons.json; not in the web game): the file, what a season leaves in the
## lists of GameData, a run in a season (shop, picks, portals, waves), every season at Battle Pass
## level 1, and the way back to the pools of the web game.
func _check_seasons() -> void:
	for problem in Seasons.problems():
		_fail("seasons.json: " + problem)
	_expect(Seasons.current == Seasons.FULL and not GameData.season_active, "seasons: the checks above run without a season")
	var web_pool := GameData.pool.size()
	var web_additional := GameData.additional.size()
	var web_thresholds: Dictionary = GameData.full_thresholds()
	var web_regional := GameData.regional_info.size()
	var real_override := Progression.override_level
	var ids := Seasons.ids().filter(func(id: String) -> bool: return id != Seasons.FULL)
	if ids.is_empty():
		print("seasons: none (data/seasons.json disabled)")
		return
	_expect(Seasons.ids().has(Seasons.default_id()), "seasons: the default season exists")
	for id in ids:
		Seasons.set_current(id)
		GameData.apply_progression()
		_expect(GameData.season_active and Seasons.active(), "seasons %s: active" % id)
		# the lists hold the roster only, the whole shop is in `pool`
		var shop := Seasons.families("shop")
		var first_forms := {}
		for rarity in GameData.SHOP_RARITIES:
			for pkm in GameData.tier1_by_rarity[rarity]:
				first_forms[pkm] = true
			_expect(GameData.additional_tier1_by_rarity[rarity].is_empty(), "seasons %s: additional %s lines left" % [id, rarity])
			_expect(GameData.tier1_by_rarity[rarity].size() >= 8, "seasons %s: only %d %s lines" % [id,
				GameData.tier1_by_rarity[rarity].size(), rarity])
		_expect(GameData.additional.is_empty() and GameData.regional.is_empty(), "seasons %s: additional / regional lists must be empty" % id)
		for family in shop:
			_expect(first_forms.has(family), "seasons %s: %s is not in the shop" % [id, family])
		_expect(first_forms.size() == shop.size(), "seasons %s: %d lines in the shop, %d listed" % [id, first_forms.size(), shop.size()])
		for pkm in GameData.pool:
			_expect(shop.has(String(GameData.get_pokemon(pkm).family)), "seasons %s: %s in the pool" % [id, pkm])
		for list_name in ["unique", "legendary", "hatch"]:
			var listed := Seasons.families(list_name)
			var got := {}
			for pkm in GameData.get(list_name):
				got[String(GameData.get_pokemon(pkm).family)] = true
			_expect(got.size() == listed.size() and listed.all(func(f: String) -> bool: return got.has(f)),
				"seasons %s: %s has %d lines, %d listed" % [id, list_name, got.size(), listed.size()])
		for duo in GameData.unique_duos:
			for member in GameData.DUOS[duo]:
				_expect(GameData.unique.has(member), "seasons %s: duo %s without %s" % [id, duo, member])
		# synergies: the tiers of the game, the first one in reach of the shop; the season's own thresholds
		var own := Seasons.thresholds()
		var counts: Array[String] = []
		for type in GameData.synergies():
			var lines := _season_lines(type)
			var tiers: Array = Synergies.thresholds(type)
			_expect(tiers.size() == web_thresholds[type].size(), "seasons %s: %s has %d tiers" % [id, type, tiers.size()])
			_expect(lines >= int(tiers[0]), "seasons %s: %s has %d lines for a first tier of %d" % [id, type, lines, int(tiers[0])])
			if own.has(type):
				_expect(tiers == own[type] and Synergies.tier(type, int(tiers[0])) == 1 and Synergies.tier(type, int(tiers[-1])) == tiers.size(),
					"seasons %s: thresholds of %s are %s" % [id, type, tiers])
			else:
				_expect(tiers == web_thresholds[type], "seasons %s: %s keeps the thresholds of the game" % [id, type])
			counts.append("%s %d" % [type.substr(0, 3), lines])
		# no regional pool, no regional variant
		_expect(GameData.regional_info.is_empty() and GameData.regional_base.is_empty(), "seasons %s: regional data left" % id)
		for map in ["AmpPlains", "FrostyForest", "MagmaCavern2"]:
			_expect(GameData.regional_in(map).is_empty(), "seasons %s: regional Pokémon in %s" % [id, map])
		# a run: the pool, the stages where additional families join, the shop
		var p := PlayerState.new()
		_expect(p.pool_counts.size() == first_forms.size(), "seasons %s: %d pool entries" % [id, p.pool_counts.size()])
		p.change_map("FrostyForest")
		_expect(p.regional_counts.is_empty() and p.regional_pokemons.is_empty(), "seasons %s: a regional pool in a region" % id)
		for stage in [5, 8, 11]:
			p.stage = stage
			p.start_stage()
		_expect(p.unlocked_additional.is_empty() and p.pool_news.is_empty(), "seasons %s: something joined the shop" % id)
		p.level = 9
		p.stage = 12
		var offered := {}
		for _i in 60:
			p.roll_shop()
			for s in p.shop:
				if s == "":
					continue
				offered[String(GameData.get_pokemon(s).family)] = true
				_expect(GameData.pokemon_unlocked(s), "seasons %s: the shop offers %s" % [id, s])
		_expect(offered.size() >= 40, "seasons %s: 60 shops showed only %d lines" % [id, offered.size()])
		var copies_before := p.copies_left(shop[0])
		p.take_copy(shop[0])
		_expect(p.copies_left(shop[0]) == copies_before - 1, "seasons %s: %s has its own copies" % [id, shop[0]])
		p.return_copies(shop[0], 1)
		_expect(p.copies_left(shop[0]) == copies_before, "seasons %s: sold copies of %s come back" % [id, shop[0]])
		# town: the additional pick is among the shop of the season, the portals offer its Unique / Legendary
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 3:
			var stage := int(GameData.config.additionalPickStages[i])
			var pick := Town.additional_pick(stage, rng, "town", p)
			_expect(pick.pokemons.size() == 3, "seasons %s: additional pick of stage %d offers %s" % [id, stage, pick.pokemons])
			for pkm in pick.pokemons:
				_expect(shop.has(pkm) and String(GameData.get_pokemon(pkm).rarity) == PlayerState.ADDITIONAL_RARITIES[i],
					"seasons %s: additional pick %s at stage %d" % [id, pkm, stage])
			p.unlock_additional(pick.pokemons[0])
		_expect(p.pool_news.is_empty(), "seasons %s: a pick is not news of the pool" % id)
		for stage in [10, 20]:
			var listed := Seasons.families("unique" if stage == 10 else "legendary")
			var types: Array = GameData.synergies()
			var offer := Town.propositions(p, stage, [types[0], types[2], types[5], types[9]], rng)
			_expect(offer.pokemons.size() == int(GameData.config.nbUniquePropositions), "seasons %s: %d propositions at stage %d" % [id,
				offer.pokemons.size(), stage])
			for entry in offer.pokemons:
				for member in String(entry).split("+"):
					_expect(listed.has(String(GameData.get_pokemon(member).family)), "seasons %s: %s offered at stage %d" % [id, member, stage])
		for _i in 6:
			var egg := SynergyItems.make_egg(p)
			_expect(Seasons.families("hatch").has(egg.hatch_into), "seasons %s: an egg hatches into %s" % [id, egg.hatch_into])
		# waves: wild packs and templates use the roster
		Difficulty.set_level("hard")
		for run_seed in [3, 77]:
			for stage in range(1, 46):
				var wave := EndlessWaves.get_stage(stage, run_seed)
				_expect(not wave.get("board", []).is_empty(), "seasons %s: empty wave at stage %d" % [id, stage])
				if String(wave.get("kind", "")) != "boss":
					for entry in wave.board:
						_expect(GameData.pokemon_unlocked(entry[0]), "seasons %s: %s in the wave of stage %d (%s)" % [id,
							entry[0], stage, wave.get("template", wave.get("name", ""))])
		Difficulty.set_level("classic")
		_expect(Seasons.record_key("normal") == "normal@" + id and Seasons.record_key("normal", Seasons.FULL) == "normal",
			"seasons %s: record key %s" % [id, Seasons.record_key("normal")])
		# the synergy tooltip lists the Pokémon of the season in two groups at most besides the shop
		for group in Tooltips.synergy_groups(GameData.synergies()[0]):
			_expect(["shop", "unique", "legendary"].has(group.key), "seasons %s: tooltip group %s" % [id, group.key])
		# a new Battle Pass in this season: enough lines in every rarity, every open synergy can start
		Progression.override_level = 1
		GameData.apply_progression()
		var open_lines := 0
		for rarity in GameData.SHOP_RARITIES:
			open_lines += GameData.tier1_by_rarity[rarity].size()
			_expect(GameData.tier1_by_rarity[rarity].size() >= 2, "seasons %s: only %d %s lines at pass level 1" % [id,
				GameData.tier1_by_rarity[rarity].size(), rarity])
		for type in GameData.synergies():
			_expect(_season_lines(type) >= int(Synergies.thresholds(type)[0]), "seasons %s: %s cannot start at pass level 1 (%d lines)" % [
				id, type, _season_lines(type)])
		var starter := PlayerState.new()
		var first_offer := Town.propositions(starter, 0, [GameData.synergies()[0], GameData.synergies()[1]], rng)
		_expect(first_offer.pokemons.size() == int(GameData.config.nbStarters), "seasons %s: starters at pass level 1: %s" % [id, first_offer.pokemons])
		Progression.override_level = real_override
		print("season %s ok: %d lines (%d at pass level 1), %d unique, %d legendary, own thresholds %s | %s" % [id, shop.size(), open_lines,
			Seasons.families("unique").size(), Seasons.families("legendary").size(), own.keys(), " ".join(counts)])

	# the switch: off = the pools of the web game, whatever the season saved
	var file: Dictionary = Seasons.data().duplicate(true)
	var off := file.duplicate(true)
	off["enabled"] = false
	Seasons.load_data(off)
	GameData.apply_progression()
	_expect(not Seasons.enabled() and Seasons.ids() == [Seasons.FULL] and Seasons.current == Seasons.FULL and not GameData.season_active,
		"seasons off: current %s" % Seasons.current)
	Seasons.load_data(file)
	# back to no season: everything of the web game again
	Seasons.set_current(Seasons.FULL)
	GameData.apply_progression()
	_expect(not GameData.season_active and GameData.pool.size() == web_pool and GameData.additional.size() == web_additional,
		"seasons: back to the whole game (%d / %d in the pool)" % [GameData.pool.size(), web_pool])
	_expect(GameData.regional_info.size() == web_regional and not GameData.regional_in("FrostyForest").is_empty(),
		"seasons: the regional Pokémon are back")
	for type in web_thresholds:
		_expect(Synergies.thresholds(type) == web_thresholds[type], "seasons: thresholds of %s are back" % type)
