class_name Game
extends Node3D

## An Endless run (offline, solo): planning (shop + drag & drop) -> fight -> result,
## stage after stage, until the player's life reaches 0 -> game over popup.
##
## The fight itself is BattleSim (pure logic); this node turns its events into
## sprite animations, cell flashes and floating texts.

enum Phase { PLANNING, FIGHT, RESULT, OVER }

const PLANNING_ENEMY_DIR := 0 ## PMD direction 0 = facing the camera
const OCCUPIED_BLUE := Color(0.35, 0.65, 1.0, 0.30)
const OCCUPIED_RED := Color(1.0, 0.35, 0.3, 0.30)
const VALID_COLOR := Color(1.0, 1.0, 1.0, 0.10)
const TARGET_OK := Color(0.4, 1.0, 0.5, 0.85)
const TARGET_BAD := Color(1.0, 0.3, 0.25, 0.85)
const RANGE_COLOR := Color(1.0, 0.78, 0.15, 0.75)
const HOVER_COLOR := Color(1.0, 1.0, 1.0, 0.6)
const AREA_ENEMY := Color(1.0, 0.5, 0.1, 0.9)
const AREA_ALLY := Color(0.35, 1.0, 0.45, 0.85)
const AREA_TELEGRAPH := Color(1.0, 0.25, 0.6, 0.8)
const LIGHT_COLOR := Color(1.0, 0.85, 0.2, 0.55)
const DIG_COLOR := Color(0.95, 0.62, 0.15, 0.85)
const HOLE_TEXT := Color(0.96, 0.85, 0.66)
const EMBER_COLOR := Color(1.0, 0.45, 0.1, 0.45)
## Board effect tints (EMBER first: the strongest when a cell has several).
const BOARD_EFFECT_COLORS := {
	"EMBER": EMBER_COLOR,
	"POISON_GAS": Color(0.65, 0.25, 0.85, 0.42),
	"SMOKE": Color(0.35, 0.35, 0.4, 0.5),
	"SPIKES": Color(0.75, 0.7, 0.6, 0.45),
	"STICKY_WEB": Color(0.95, 0.95, 0.85, 0.4),
	"COTTON_BALL": Color(1.0, 1.0, 1.0, 0.45),
	"STRANGE_STEAM": Color(1.0, 0.55, 0.85, 0.42),
	"STEALTH_ROCKS": Color(0.6, 0.5, 0.35, 0.5),
	"TOXIC_SPIKES": Color(0.55, 0.2, 0.7, 0.5),
	"HAIL": Color(0.75, 0.9, 1.0, 0.45),
}
const LIGHTNING_COLOR := Color(1.0, 1.0, 0.5, 0.95)

@export_group("Rules")
## Planning ends only with the Fight! button / Space. When on, it also ends after `planning_duration`.
@export var planning_timer := false
## Planning phase length in seconds when `planning_timer` is on.
@export_range(5.0, 120.0, 1.0) var planning_duration := 30.0
## Pause after a fight, in seconds.
@export_range(0.5, 10.0, 0.1) var result_duration := 2.5
## Combat speed steps of the x1 / x2 button.
@export var fight_speeds: Array[float] = [1.0, 2.0, 4.0]
## Place bench Pokémon automatically when the board is not full at fight time (TFT does it).
@export var auto_place_on_fight := true

@export_group("Pokémon sprites")
## Sprite size multiplier. 1.0 = the web game proportions (48 sprite pixels per cell).
@export_range(0.5, 3.0, 0.05) var sprite_scale := 1.8
## Compact HUD (phones): pitch of the camera framing the board when no room is known yet. The angle used
## is the player's (Settings.board_pitch) or the auto one (_pick_pitch, between these two).
@export_range(30.0, 70.0, 0.5, "suffix:°") var compact_pitch_degrees := 45.0
const AUTO_PITCH_MIN := 36
const AUTO_PITCH_MAX := 60
## Enabled = faces the camera (Don't Starve), Y-Billboard = stays upright (Arknights-like).
@export var sprite_billboard: BaseMaterial3D.BillboardMode = BaseMaterial3D.BILLBOARD_ENABLED

@export_group("Cells (Phase 2)")
## Tint the cell each Pokémon occupies (its logical cell, reserved as soon as it starts moving).
@export var show_occupied_cells := true
## Team coloured ring under each Pokémon during fights.
@export var show_team_rings := true
## Flash the cells hit by abilities.
@export var show_ability_areas := true
@export_range(0.1, 3.0, 0.05) var ability_flash_time := 0.7
## While dragging, show the attack range from the hovered cell.
@export var show_drag_range := true

@onready var camera: TftCamera = $TftCamera
@onready var arena: Arena = $Arena
@onready var units_root: Node3D = $Units
@onready var hud: Hud = $Hud

var player: PlayerState
var run_seed := 0
var phase := Phase.PLANNING
var phase_time := 0.0
var phase_total := 1.0
var wave: Dictionary = {}
var sim: BattleSim
var speed_index := 0

var owned_views: Dictionary = {} ## OwnedUnit.id -> UnitView
var enemy_views: Array[UnitView] = [] ## wave preview, same order as wave.board
var spawn_views: Array[UnitView] = [] ## units joining a fight (Bug clones, Mitosis copies...)
var battle_views: Dictionary = {} ## BattleUnit.id -> UnitView

var _drag_view: UnitView
var _drag_unit: PlayerState.OwnedUnit
var _drag_item := -1 ## item bench index being dragged, ItemBench.REMOVER = the Item Remover, -1 = none
var _combine_preview := -1 ## item bench slot showing the combined item while dragging
var _hover_slot: Dictionary = {}
var _info_view: UnitView
## Choices waiting for the player, the first one is shown (Town, rewards, wands):
## {kind: "items", source: "reward" | "carousel" | "wand", items, cost?, title?}
## {kind: "portal", portals}   {kind: "pokemon", category, pokemons, items}
var choices: Array[Dictionary] = []
var town_rng := RandomNumberGenerator.new()
var vfx: VfxPlayer
## Fight statistics per BattleUnit id (DPS meter): {unit, physical, special, true,
## reduced, shield_taken, heal, shield}; kept until the next fight starts.
var fight_stats: Dictionary = {}
var _dps_entries: Array = []
var _stage_news: Array[String] = [] ## told with the next stage banner (eggs...)
var _synergy_focus := "" ## synergy hovered in the HUD: its Pokémon's cells pulse
var _dps_timer := 0.0
## Cheats (difficulty.json "cheats", F1): playtesting / balancing, not in the web game.
var cheats: CheatPanel
var wanderers: Wanderers
var cheat_no_life_loss := false
## A cheat was used during this run: not recorded (Records).
var cheated := false
## Totals of the run for the Game Over screen (RunSummary).
var run_stats := RunStats.new()
## Battle Pass (Progression): XP earned in this run, the pass level it started at, and the synergies
## unlocked since the last run (told with the first portal).
var pass_xp := 0
var _pass_from := 1
var _run_news := ""
## Touch screens (UiScale.touch): where and when the finger went down. A short press that did not
## move is a tap: the details of the Pokémon / item under it, not a drag.
const TAP_SLOP := 16.0
const TAP_MS := 440
var _press_pos := Vector2.ZERO
var _press_ms := 0
## The camera of the scene (after the bench rows): [distance, focus_point, screen_offset], restored
## when the HUD leaves its compact layout.
var _scene_camera: Array = []
var cheat_free_reroll := false
## Shown in the info line of the next Pokémon choice (the synergies a region just unlocked for the run).
var _choice_note := ""


func _ready() -> void:
	# Battle Pass: the synergies unlocked so far are the ones of this run, whatever it earns meanwhile;
	# the regions reached add theirs until the run ends (GameData.unlock_for_run)
	GameData.begin_run()
	_pass_from = Progression.level()
	var fresh := Progression.take_run_news()
	if not fresh.is_empty():
		_run_news = L.t("New in this run: %s") % ", ".join(fresh.map(func(t: String) -> String: return GameData.synergy_name(t)))
	hud.overlay.camera = camera
	hud.overlay.cell_size = arena.cell_size
	hud.buy_pressed.connect(_on_buy)
	hud.reroll_pressed.connect(func() -> void:
		_reroll()
		Audio.play_sfx("refresh", 0.5))
	hud.buy_xp_pressed.connect(func() -> void: player.buy_xp())
	hud.lock_pressed.connect(func() -> void: player.toggle_lock())
	hud.fight_pressed.connect(func() -> void:
		if phase == Phase.PLANNING:
			_start_fight()
	)
	hud.speed_pressed.connect(_cycle_speed)
	hud.menu_pressed.connect(_to_main_menu)
	hud.game_over_confirmed.connect(_to_main_menu)
	hud.item_drag_started.connect(_begin_item_drag)
	hud.item_chosen.connect(func(item: String) -> void: _resolve_choice(item))
	hud.choice_skipped.connect(func() -> void: _resolve_choice(null))
	hud.portal_chosen.connect(func(index: int) -> void: _resolve_choice(index))
	hud.pokemon_chosen.connect(func(index: int) -> void: _resolve_choice(index))

	Settings.changed.connect(_on_settings_changed)
	vfx = VfxPlayer.new()
	vfx.name = "Vfx"
	add_child(vfx)
	vfx.camera = camera
	vfx.arena = arena
	vfx.body_of = _body_of
	wanderers = Wanderers.new()
	wanderers.name = "Wanderers"
	units_root.add_child(wanderers)
	wanderers.cell_size = arena.cell_size
	wanderers.make_view = func(pkm: String, team: int) -> UnitView:
		var v := _make_view(pkm, team)
		v.reparent(wanderers)
		return v
	hud.stage_preview = stage_preview_text
	hud.garden.berry_picked.connect(func(index: int) -> void:
		var berry := SynergyItems.pick_berry(player, index)
		if berry != "":
			hud.banner("+ " + GameData.item_name(berry), UiStyle.GREEN, 0.9))
	hud.synergy_hovered.connect(func(type: String) -> void:
		_synergy_focus = type
		_update_synergy_focus())
	Audio.play_sfx("startgame")
	player = PlayerState.new()
	player.life = int(Difficulty.value("startLife", PlayerState.START_LIFE))
	player.gold = int(Difficulty.value("startGold", PlayerState.START_GOLD))
	player.changed.connect(_on_player_changed)
	# more bench rows (difficulty benchSize): the camera steps back to keep them above the shop
	arena.bench_rows = ceili(player.bench_slots / float(Arena.BENCH_COLUMNS))
	if arena.bench_rows > 1:
		camera.distance *= 1.0 + 0.12 * (arena.bench_rows - 1)
		camera.focus_point.z += 0.5 * (arena.bench_rows - 1)
	_scene_camera = [camera.distance, camera.focus_point, camera.screen_offset, camera.pitch_degrees]
	hud.layout_changed.connect(_frame_board)
	_frame_board()
	if Difficulty.value("cheats", false):
		cheats = CheatPanel.new()
		cheats.name = "Cheats"
		cheats.game = self
		hud.get_node("Root").add_child(cheats)
	run_seed = randi() | 1
	town_rng.seed = run_seed
	# stage 0: the starter portal, then stage 1
	player.stage = 0
	_queue_choices(Town.begin_stage(player, town_rng).choices)
	player.stage = 1
	player.roll_shop()
	_start_planning()


func _physics_process(delta: float) -> void:
	match phase:
		Phase.PLANNING:
			if planning_timer:
				phase_time -= delta
				if phase_time <= 0.0:
					_start_fight()
		Phase.FIGHT:
			vfx.speed = _speed()
			var ms := delta * 1000.0 * _speed()
			while ms > 0.0 and not sim.finished:
				var step := minf(ms, BattleSim.MAX_STEP_MS)
				sim.update(step)
				ms -= step
			_handle_events(sim.drain_events())
			phase_time = maxf(0.0, (BattleSim.FIGHT_DURATION_MS - sim.time_ms) / 1000.0)
			if sim.finished:
				_end_fight()
		Phase.RESULT:
			phase_time -= delta
			if phase_time <= 0.0:
				_next_stage()


func _process(delta: float) -> void:
	UnitView.time_scale = _speed() if phase == Phase.FIGHT else 1.0 # sprite animations follow the fight speed
	_update_occupied_layer()
	if _synergy_focus != "":
		_update_synergy_focus()
	_dps_timer -= delta
	if _dps_timer <= 0.0:
		_dps_timer = 0.25
		if sim != null:
			var fighters := sim.units.filter(func(u: BattleUnit) -> bool: return u.data.get("passive", "") != "INANIMATE")
			_dps_entries = fighters.map(func(u: BattleUnit) -> Dictionary: return _stat(u))
		hud.update_dps(_dps_entries)
	var phase_text := ""
	match phase:
		Phase.PLANNING: phase_text = L.t("Planning %ds") % ceili(phase_time) if planning_timer else L.t("Planning")
		Phase.FIGHT: phase_text = L.t("Combat %ds") % ceili(phase_time)
		Phase.RESULT: phase_text = "..."
		Phase.OVER: phase_text = L.t("Game over")
	hud.refresh_stage(player.stage, wave, phase_text, phase_time, phase_total, phase == Phase.PLANNING)
	var views: Array = []
	views.append_array(owned_views.values())
	views.append_array(enemy_views)
	views.append_array(spawn_views)
	hud.overlay.views = views
	if phase == Phase.FIGHT:
		for v in battle_views.values():
			if is_instance_valid(v) and v.battle_unit != null:
				v.sync_statuses(v.battle_unit.statuses if v.battle_unit.alive else {})
				if v.team != v.battle_unit.team: # POSSESSED: its ring follows the side it fights for
					v.team = v.battle_unit.team
					v.set_ring(show_team_rings)
	while player != null and not player.wanderers.is_empty() and wanderers != null:
		wanderers.spawn(player.wanderers.pop_front())


#region phases
func _start_planning() -> void:
	phase = Phase.PLANNING
	phase_total = planning_duration
	phase_time = planning_duration
	if sim != null:
		sim.dispose()
	sim = null
	battle_views.clear()
	vfx.clear()
	player.merge_board = true
	player.check_merges()
	wave = EndlessWaves.get_stage(player.stage, run_seed)
	# shinyEncounter (game-commands.ts): Celebi met in the town, or the stage's own shiny chance
	player.shiny_encounter = player.town_encounter == "CELEBI" or town_rng.randf() < float(wave.get("shinyChance", 0.0))
	arena.clear_flashes()
	arena.clear_layer("board_effect")
	var inspected_id := _info_view.owned_id if _info_view != null and is_instance_valid(_info_view) else -1
	for v in owned_views.values():
		if is_instance_valid(v):
			v.queue_free()
	owned_views.clear()
	for v in spawn_views:
		if is_instance_valid(v):
			v.queue_free()
	spawn_views.clear()
	_sync_owned_views(false)
	_spawn_enemy_preview()
	hud.set_enemy_synergies(EndlessWaves.synergy_counts(wave, player.town_encounter))
	hud.set_shop_enabled(true)
	hud.set_shop_open(true) # compact HUD: the new shop is shown; it closes for the fight (bigger board)
	_show_next_choice()
	# the unit panel follows the inspected Pokémon to its new view, else closes
	_info_view = owned_views.get(inspected_id)
	if _info_view != null:
		_show_info(_info_view)
	else:
		_close_info()
	_on_player_changed()


func _start_fight() -> void:
	_cancel_drag()
	_cancel_item_drag()
	auto_resolve_choices()
	if auto_place_on_fight:
		player.auto_place()
	phase = Phase.FIGHT
	phase_total = BattleSim.FIGHT_DURATION_MS / 1000.0
	phase_time = phase_total
	hud.set_shop_open(false)
	player.merge_board = false
	battle_views.clear()
	fight_stats.clear()
	var fight := FightSetup.create(player, wave)
	sim = fight.sim
	for id in fight.owned:
		var u: BattleUnit = fight.owned[id]
		var v = owned_views.get(id)
		if v != null and is_instance_valid(v):
			v.transform(u.pkm) # weather forms (Lycanroc, Ursaluna)
			_bind_battle_view(v, u)
	var enemies: Array = fight.enemies
	for i in mini(enemies.size(), enemy_views.size()):
		if enemies[i] != null and is_instance_valid(enemy_views[i]):
			_bind_battle_view(enemy_views[i], enemies[i])
	hud.set_weather(sim.weather)
	if _info_view != null and is_instance_valid(_info_view):
		_show_info(_info_view) # live HP / PP / stats of the fighting unit
	hud.banner(L.t("Fight!") if sim.weather == Weather.NEUTRAL else L.t("Fight!") + "   " + GameData.weather_name(sim.weather),
		UiStyle.GOLD, 0.8)


func _bind_battle_view(v: UnitView, u: BattleUnit) -> void:
	v.battle_unit = u
	v.set_shiny(u.effects.get("shiny", false))
	battle_views[u.id] = v
	v.set_ring(show_team_rings)
	v.face(u.facing)


func _end_fight() -> void:
	phase = Phase.RESULT
	for v in battle_views.values():
		if is_instance_valid(v):
			v.sync_statuses({})
	phase_total = result_duration
	phase_time = result_duration
	player.merge_board = true
	player.after_fight()
	player.collect_fight_rewards(sim.rewards)
	run_stats.add_fight(fight_stats, sim.winner, player.stage)
	_grant_pass_xp(sim.winner == BattleUnit.Team.BLUE)
	# eggs found / hatched: told with the next stage banner
	_stage_news.append_array(SynergyItems.after_fight(player, sim.winner != BattleUnit.Team.BLUE))
	if sim.winner == BattleUnit.Team.BLUE:
		hud.banner(L.t("Victory!") + _give_reward(wave.get("reward")), UiStyle.GREEN)
		return
	var survivors := sim.alive_units(BattleUnit.Team.RED).size()
	var damage := RunRules.life_loss(player.stage, survivors)
	if cheat_no_life_loss:
		damage = 0
	player.life = maxi(player.life - damage, 0)
	hud.banner((L.t("Defeat") if sim.winner == BattleUnit.Team.RED else L.t("Draw")) + "   " + L.t("-%d life") % damage, UiStyle.RED)
	camera.shake(1.5)
	_on_player_changed()


## Battle Pass: the XP of the stage just fought (xp.perStage / perWin, 0 now: the pass counts runs, see
## _next_stage), saved at once (leaving the run keeps it); none once a cheat was used. A level reached is
## told with the next stage banner: its synergies come with the next run (Progression).
func _grant_pass_xp(won: bool) -> void:
	if cheated or cheat_no_life_loss or cheat_free_reroll:
		return
	var gain := Progression.add_xp(Progression.stage_xp(won))
	pass_xp += int(gain.gained)
	if int(gain.to) > int(gain.from):
		var names: Array = gain.unlocked.map(func(t: String) -> String: return GameData.synergy_name(t))
		var news := L.t("Battle Pass level %d!") % int(gain.to)
		if not names.is_empty():
			news += "  " + L.t("Unlocked for your next run: %s") % ", ".join(names)
		_stage_news.append(news)


func _next_stage() -> void:
	if player.life <= 0:
		phase = Phase.OVER
		var level := Seasons.record_key(Difficulty.level) # one record per season and difficulty
		var before := Records.best(level)
		var fair := not (cheated or cheat_no_life_loss or cheat_free_reroll)
		if fair: # Battle Pass: the XP of a run played to its end (leaving by the menu gives none)
			pass_xp += int(Progression.add_xp(Progression.run_xp()).gained)
		var beaten := fair and Records.submit(level, player.stage, Records.team_of(player))
		var summary := run_stats.summary(player)
		if Progression.enabled():
			summary["pass"] = Progression.report(pass_xp, _pass_from)
			summary["pass"]["fair"] = fair
		hud.show_game_over(player.stage, before, beaten, fair, summary)
		# web after-game jingle: finish<rank>.ogg, here by the stage reached
		Audio.play_sfx("finish1" if player.stage >= 30 else "finish2" if player.stage >= 20 else "finish4")
		return
	player.stage += 1
	var income := player.collect_income()
	var messages := player.start_stage()
	messages.append_array(_stage_news)
	_stage_news.clear()
	messages.append_array(_run_unlock_lines()) # a region reached another way (Lapras Passport...)
	var town := Town.begin_stage(player, town_rng)
	messages.append_array(town.messages)
	_queue_choices(town.choices)
	if not player.shop_locked:
		player.roll_shop()
	_start_planning()
	var text := L.t("Stage %d   +%dg") % [player.stage, income]
	if not messages.is_empty():
		text += "\n" + "\n".join(messages)
	hud.banner(text, UiStyle.GOLD, 1.0 + 0.6 * messages.size())


## Item reward of a won wave (RunRules.give_reward): the items given, a choice queued. Returns the text
## added to the victory banner.
func _give_reward(reward: Variant) -> String:
	var out := RunRules.give_reward(player, reward)
	var texts: Array[String] = []
	if not out.choice.is_empty():
		_queue_choices([out.choice])
		texts.append(L.t("item choice"))
	for item in out.given:
		texts.append(GameData.item_name(item))
	return ("   + " + ", ".join(texts)) if not texts.is_empty() else ""


func _queue_choices(list: Array) -> void:
	for c in list:
		choices.append(c)
	_show_next_choice()


## One choice popup at a time, in order; a Fairy wand waits behind the others.
func _show_next_choice() -> void:
	if hud.has_item_choice() or phase == Phase.OVER:
		return
	if choices.is_empty():
		var wands: Array[String] = []
		wands.assign(player.pending_wand_choice())
		if wands.is_empty():
			return
		choices.append({"kind": "items", "source": "wand", "items": wands})
	var c: Dictionary = choices[0]
	var texts: Dictionary = GameData.text.get("player_choices", {})
	if c.kind == "portal" or c.get("source", "") == "carousel":
		Audio.play_sfx("carouselunlock")
	match c.kind:
		"portal":
			var info := L.t("Each portal leads to a region; the Pokémon offered after it have its synergies.")
			if int(c.get("stage", -1)) == 0 and _run_news != "": # Battle Pass: what the last runs unlocked
				info += "\n[color=#ffd24d]%s[/color]" % _run_news
			hud.show_portal_choice(c.portals, L.t("Choose a portal"), info)
		"pokemon":
			var key: String = {"starter": "choose_starter", "unique": "choose_unique", "legendary": "choose_legendary",
				"addpick": "choose_add_pick", "form": "choose_form"}.get(c.category, "")
			var title := String(texts.get(key, L.t("Choose a Pokémon")))
			if c.category == "addpick" and GameData.season_active: # nothing joins the shop of a season
				title = L.t("Choose a Pokémon: it comes with its item.")
			hud.show_pokemon_choice(c.pokemons, c.items, title, _choice_note)
			_choice_note = ""
		"items":
			var items: Array[String] = []
			items.assign(c.items)
			var title: String = c.get("title", texts.get("choose_wand", "Choose a wand") if c.source == "wand"
				else texts.get("choose_item", "Choose an item"))
			hud.show_item_choice(items, title, int(c.get("cost", 0)), player.gold)


## Applies the answer to the shown choice (item id, index, or null = skipped: RunRules.apply_choice), then
## shows the next.
func _resolve_choice(answer: Variant) -> void:
	if choices.is_empty():
		return
	hud.hide_item_choice()
	var c: Dictionary = choices.pop_front()
	var out := RunRules.apply_choice(player, c, answer, town_rng)
	match c.kind:
		"portal":
			var offer: Dictionary = out.offer
			if not offer.is_empty():
				choices.push_front(offer)
			_tell_run_unlocks(not offer.is_empty()) # in the popup of the offer (a banner would cover it)
		"pokemon":
			if out.result == "sold":
				hud.banner(L.t("No room on the bench: %s sold") % GameData.display_name(out.pkm), UiStyle.GOLD, 1.2)
	_show_next_choice()


## Picks at random what the player has not chosen when the fight starts (web autoPickChoices);
## a priced carousel is skipped and wands wait.
func auto_resolve_choices() -> void:
	hud.hide_item_choice()
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
				_resolve_choice(auto.answer)
		hud.hide_item_choice()
	_show_next_choice()


## Web board-manager: the town themes while the portal / its Pokémon are chosen
## (stages 0, 10, 20), else the music of the region the player went to.
func _update_music() -> void:
	var town_stage := -1
	for c in choices:
		if c.kind == "portal":
			town_stage = int(c.get("stage", player.stage))
		elif c.kind == "pokemon" and c.category in ["starter", "unique", "legendary"]:
			town_stage = {"starter": 0, "unique": 10, "legendary": 20}[c.category]
		if town_stage >= 0:
			break
	if town_stage >= 0:
		Audio.play_music("Treasure Town Stage %d" % (0 if town_stage < 10 else 10 if town_stage < 20 else 20))
		return
	var region: Dictionary = GameData.config.get("maps", {}).get(player.map, {})
	Audio.play_music(String(region.get("music", Audio.TOWN_MUSIC)))


## Tooltip of the stage bar: the current and next stages (enemy, town events, reward).
func stage_preview_text() -> String:
	var lines: Array[String] = [L.t("Difficulty: %s") % Difficulty.label(Difficulty.level)]
	if Seasons.enabled():
		lines.push_front(Seasons.label())
	var enemy := enemy_text(wave)
	if enemy != "":
		lines.append(enemy)
	lines.append("")
	for s in range(maxi(player.stage, 1), maxi(player.stage, 1) + 6):
		var w := EndlessWaves.get_stage(s, run_seed)
		var parts: Array[String] = []
		var boss := String(w.get("kind", "")) == "boss"
		parts.append(("[color=#ff8a70]%s[/color]" if boss else "%s") % EndlessWaves.display_name(w))
		if Town.is_portal_stage(s):
			parts.append(L.t("portal"))
		elif Town.is_carousel_stage(s):
			parts.append(L.t("item carousel"))
		if Town.is_additional_stage(s):
			parts.append(L.t("additional pick"))
		var reward = w.get("reward")
		if reward is Dictionary:
			if reward.get("pool") is Array or reward.get("choice", false):
				parts.append(L.t("item reward"))
			else:
				parts.append(L.t("full item") if reward.get("pool") == "full" else L.t("component"))
		var line := "[b]%s[/b]   %s" % [L.t("Stage %d") % s, "  •  ".join(parts)]
		lines.append("[color=#ffd24d]%s[/color]" % line if s == player.stage else line)
	return "
".join(lines)


## What makes the coming wave stronger than its Pokémon alone: active synergies, held
## items, stat multipliers and flat boosts (web keywords, for GameText).
func enemy_text(w: Dictionary) -> String:
	var parts: Array[String] = []
	var counts := EndlessWaves.synergy_counts(w, player.town_encounter)
	var active: Array[String] = []
	for type in Synergies.sort(counts):
		if Synergies.tier(type, counts[type]) > 0:
			active.append("%s %d" % [type, counts[type]])
	if not active.is_empty():
		parts.append(L.t("Enemy synergies: %s") % ", ".join(active))
	var held := 0
	for list in EndlessWaves.held_items(w, player.town_encounter):
		held += list.size()
	if held > 0:
		parts.append(L.t("Items held: %d") % held)
	var stats: Array[String] = []
	var scale: Dictionary = w.get("statScale", {})
	for stat in scale:
		stats.append("%s x%s" % [stat, String.num(float(scale[stat]), 2)])
	var boosts: Dictionary = w.get("statBoosts", {})
	for stat in boosts:
		if float(boosts[stat]) != 0.0:
			stats.append("%s %s%s" % [stat, "+" if float(boosts[stat]) > 0.0 else "", String.num(float(boosts[stat]), 1).trim_suffix(".0")])
	if not stats.is_empty():
		parts.append(L.t("Enemy stats: %s") % ", ".join(stats))
	return "\n".join(parts)


## Where a fighting unit is drawn (VFX anchor), null when it has no view.
func _body_of(u: BattleUnit) -> Variant:
	if u == null:
		return null
	var v = battle_views.get(u.id)
	return v.body_position() if v != null and is_instance_valid(v) else null


## Where a fighting unit stands (the ground point of its view), null when it has no view.
func _ground_of(u: BattleUnit) -> Variant:
	if u == null:
		return null
	var v = battle_views.get(u.id)
	return v.global_position if v != null and is_instance_valid(v) else null


func _stat(u: BattleUnit) -> Dictionary:
	if not fight_stats.has(u.id):
		fight_stats[u.id] = {"unit": u, "physical": 0.0, "special": 0.0, "true": 0.0, "reduced": 0.0,
			"shield_taken": 0.0, "heal": 0.0, "shield": 0.0}
	return fight_stats[u.id]


func _speed() -> float:
	return fight_speeds[speed_index] if not fight_speeds.is_empty() else 1.0


func _cycle_speed() -> void:
	speed_index = (speed_index + 1) % maxi(fight_speeds.size(), 1)
	hud.set_speed_text("x%s" % str(_speed()).trim_suffix(".0"))


func _to_main_menu() -> void:
	if sim != null:
		sim.dispose()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


## Shop refresh (button, D): free while the "free reroll" cheat is on.
func _reroll() -> void:
	run_stats.rerolls += 1
	if cheat_free_reroll:
		player.free_rolls += 1
	player.reroll()
#endregion


#region cheats (CheatPanel, F1): each returns a message for the panel ("" = done)
func cheat_gold(amount: int) -> String:
	cheated = true
	player.gold = maxi(player.gold + amount, 0)
	player.changed.emit()
	return "Vàng: %d" % player.gold


func cheat_level(levels: int) -> String:
	cheated = true
	var target := mini(player.level + levels, int(GameData.config.maxLevel))
	while player.level < target:
		player.add_experience(maxi(GameData.exp_to_next_level(player.level) - player.experience, 1))
	return "Cấp %d" % player.level


func cheat_life(amount: int) -> String:
	cheated = true
	player.life = clampi(player.life + amount, 1, 999)
	_on_player_changed()
	return "Máu: %d" % player.life


## Wins the current fight (planning: starts it first): every enemy faints, then the usual end.
func cheat_win() -> String:
	cheated = true
	if phase == Phase.PLANNING:
		_start_fight()
	if phase != Phase.FIGHT or sim == null:
		return "Không có trận nào đang diễn ra."
	for u in sim.units:
		var guard := 0
		while u.team == BattleUnit.Team.RED and u.alive and guard < 5: # Max Revive, Shiny Charm...
			guard += 1
			u.statuses.erase("protect")
			u.statuses.erase("skydiving")
			u.shield = 0.0
			sim.deal_damage(u, u.hp + 1e6, BattleUnit.DamageKind.TRUE, null, false, false, false)
	return "Thắng stage %d" % player.stage


## Goes to the start of `stage` (planning only): like the end of stage - 1 (income, stage events,
## town of that stage, new wave), without fighting.
func cheat_stage(stage: int) -> String:
	cheated = true
	if phase != Phase.PLANNING:
		return "Chỉ đổi stage được lúc chuẩn bị."
	hud.hide_item_choice()
	choices.clear()
	player.stage = maxi(stage, 1) - 1
	_next_stage()
	return "Stage %d" % player.stage


func cheat_give_pokemon(pkm: String) -> String:
	cheated = true
	var result := player.give_pokemon(pkm)
	if result == "sold":
		return "Bench đầy: %s đã bị bán" % GameData.display_name(pkm)
	return "+ %s%s" % [GameData.display_name(pkm), " (gộp)" if result == "merged" else ""]


func cheat_give_item(item: String) -> String:
	cheated = true
	player.add_item(item)
	return "+ %s" % GameData.item_name(item)


## Empties the bench (no gold back, the copies do not return to the shop pool).
func cheat_clear_bench() -> String:
	cheated = true
	var n := 0
	for i in player.bench_size:
		if player.bench[i] != null:
			player.bench[i] = null
			n += 1
	player.changed.emit()
	return "Đã xoá %d Pokémon trên bench" % n


## Every additional family joins the shop now (they normally do at stages 5 / 8 / 11).
func cheat_unlock_additional() -> String:
	cheated = true
	var n := 0
	for rarity in PlayerState.ADDITIONAL_RARITIES:
		var joined: Array[String] = []
		for pkm in GameData.additional_tier1_by_rarity[rarity]:
			if not player.unlocked_additional.has(pkm):
				player.unlocked_additional[pkm] = true
				joined.append(pkm)
		if not joined.is_empty():
			player.record_pool_news(joined, rarity)
			n += joined.size()
	player.update_regional_pool(false)
	player.changed.emit()
	return "%d Pokémon additional đã vào shop" % n


func cheat_map(map: String) -> String:
	cheated = true
	player.change_map(map)
	_tell_run_unlocks()
	_update_music()
	player.changed.emit()
	return "Vùng: %s" % TownChoice.map_name(map)


## The lines telling the synergies a region unlocked for the run since the last time (PlayerState
## run_unlocks_unread), [] if none.
func _run_unlock_lines() -> Array[String]:
	var out: Array[String] = []
	if not player.run_unlocks_unread.is_empty():
		var names: Array = player.run_unlocks_unread.map(func(t: String) -> String: return GameData.synergy_name(t))
		out.append(L.t("%s: unlocked for this run: %s") % [TownChoice.map_name(player.map), ", ".join(names)])
		player.run_unlocks_unread.clear()
	return out


## A region reached (portal, cheat) unlocked synergies for the run: told by a banner, or in the info line
## of the next choice popup (`in_next_choice`: a Pokémon choice follows); the HUD shows the new types
## (synergy list, shop cards, units).
func _tell_run_unlocks(in_next_choice := false) -> void:
	var lines := _run_unlock_lines()
	if lines.is_empty():
		return
	if in_next_choice:
		_choice_note = "[color=#7fe08a]%s[/color]" % lines[0]
	else:
		hud.banner(lines[0], UiStyle.GREEN, 3.0)
	hud.synergies.invalidate()
	player.changed.emit()
#endregion


#region views
func _make_view(pkm: String, team: int) -> UnitView:
	var v := UnitView.new()
	units_root.add_child(v)
	v.setup(pkm, team, arena.cell_size, sprite_scale, sprite_billboard)
	return v


func _slot_world(loc: Dictionary) -> Vector3:
	if loc.has("bench"):
		return arena.bench_to_world(loc.bench)
	return arena.cell_to_world(loc.board)


## Creates / removes / places the views of the player's units to match PlayerState.
func _sync_owned_views(animate := true) -> void:
	var locations := {}
	for i in player.bench_size:
		if player.bench[i] != null:
			locations[player.bench[i].id] = [player.bench[i], player.bench_loc(i)]
	for cell in player.board:
		locations[player.board[cell].id] = [player.board[cell], {"board": cell}]
	for id in owned_views.keys():
		var v = owned_views[id] # may be a freed view (fainted in the last fight)
		if not locations.has(id) or not is_instance_valid(v) or v.pkm != _looks(locations[id][0]):
			if is_instance_valid(v) and v.battle_unit == null:
				v.queue_free()
			owned_views.erase(id)
	for id in locations:
		var unit: PlayerState.OwnedUnit = locations[id][0]
		var loc: Dictionary = locations[id][1]
		var v: UnitView = owned_views.get(id)
		var fighting := (phase == Phase.FIGHT or phase == Phase.RESULT) and loc.has("board")
		if v == null:
			if fighting:
				continue # its view is fighting (or fainted)
			v = _make_view(_looks(unit), BattleUnit.Team.BLUE)
			v.owned_id = id
			v.items = unit.items
			owned_views[id] = v
			v.snap_to(_slot_world(loc))
			v.set_direction_index(PLANNING_ENEMY_DIR)
			if animate:
				v.pop_in() # bought, evolved, given
			continue
		v.items = unit.items
		if v.dragging or fighting:
			continue
		if loc.has("board"):
			v.visible = true
			v.stack_count = 1
		if animate:
			v.move_to(_slot_world(loc), 0.12, "dash")
		else:
			v.snap_to(_slot_world(loc))
	_update_stack_views()


## Bench slots holding several copies (PlayerState.bench_stack): only the front copy shows, with the count
## (UnitOverlay); while one of them is dragged, the next one shows in the slot.
func _update_stack_views() -> void:
	if player == null:
		return
	for s in player.bench_slots:
		var units := player.slot_units(s).filter(func(u) -> bool: return u != _drag_unit)
		for k in units.size():
			var v = owned_views.get(units[k].id)
			if v != null and is_instance_valid(v):
				v.visible = k == 0
				v.stack_count = units.size() if k == 0 else 1
	if _drag_view != null and is_instance_valid(_drag_view):
		_drag_view.visible = true
		_drag_view.stack_count = 1


## What a unit of the player looks like (Illusion: the Pokémon it disguises as).
func _looks(unit: PlayerState.OwnedUnit) -> String:
	return unit.look if unit.look != "" and GameData.pokemon.has(unit.look) else unit.pkm


func _spawn_enemy_preview() -> void:
	for v in enemy_views:
		if is_instance_valid(v):
			v.queue_free()
	enemy_views.clear()
	var board: Array = wave.get("board", [])
	var held: Array = EndlessWaves.held_items(wave, player.town_encounter)
	for i in board.size():
		var entry: Array = board[i]
		var v := _make_view(entry[0], BattleUnit.Team.RED)
		v.set_shiny(player.shiny_encounter)
		v.items = held[i] if i < held.size() else []
		v.snap_to(arena.cell_to_world(EndlessWaves.to_sim_cell(int(entry[1]), int(entry[2]))))
		v.set_direction_index(PLANNING_ENEMY_DIR)
		enemy_views.append(v)


## Language changed in the options: rebuild the texts shown.
func _on_settings_changed() -> void:
	_frame_board() # the angle of the camera over the board may have changed
	hud.synergies.invalidate()
	_on_player_changed()
	if phase != Phase.PLANNING and sim != null:
		hud.set_weather(sim.weather)
	if hud.info_panel.visible and _info_view != null and is_instance_valid(_info_view):
		_show_info(_info_view)


func _on_player_changed() -> void:
	_update_music()
	hud.refresh_player(player)
	_update_board_layers()
	if phase == Phase.PLANNING:
		hud.set_weather(FightSetup.weather_for(player, wave))
		_show_next_choice()
	if phase != Phase.OVER:
		_sync_owned_views(true)
	# the unit panel follows item changes (equip, merge) of the inspected Pokémon
	if hud.info_panel.visible and _info_view != null and is_instance_valid(_info_view) and _info_view.owned_id >= 0 \
			and _info_view.battle_unit == null:
		if _owned_unit(_info_view.owned_id) != null:
			_show_info(_info_view)


func _on_buy(slot: int) -> void:
	var merges := player.buy(slot)
	for m in merges:
		var v: UnitView = owned_views.get(m.unit.id)
		if v != null:
			hud.overlay.float_text(v.head_position(), L.t("Evolved!"), UiStyle.GOLD, 24)
			vfx.evolution(v.body_position())
		var stars := int(GameData.get_pokemon(m.unit.pkm).get("stars", 2))
		Audio.play_sfx("evolutiont3" if stars >= 3 else "evolutiont2")
#endregion


#region fight events -> visuals
func _handle_events(events: Array[Dictionary]) -> void:
	var speed := _speed()
	for e in events:
		var u: BattleUnit = e.get("unit")
		var found = battle_views.get(u.id) if u != null else null
		var v: UnitView = found if found != null and is_instance_valid(found) else null
		match e.type:
			"move":
				if v:
					v.face_toward(e.from, e.to)
					v.move_to(arena.cell_to_world(e.to), e.duration / 1000.0 / speed, e.kind)
			"attack":
				if v:
					var attack_target: BattleUnit = e.get("target")
					if attack_target != null:
						v.face_toward(u.cell, attack_target.cell)
						var tv = _body_of(attack_target)
						if tv != null:
							vfx.attack(String(u.data.get("anim", {}).get("attackSprite", "")), v.body_position(), tv,
								float(e.get("hit_delay", 0.0)))
					v.attack(String(u.data.get("anim", {}).get("attack", "Attack")), u.attack_cooldown(),
						float(e.get("hit_delay", 0.0)), _ground_of(attack_target), u.attack_range > 1)
			"cast":
				if v:
					var focus: BattleUnit = e.get("focus")
					if focus != null and focus != u:
						v.face_toward(u.cell, focus.cell)
					v.play(String(u.data.get("anim", {}).get("ability", "Attack")), true)
					hud.overlay.float_text(v.head_position() + Vector3.UP * 0.25,
						GameData.ability_name(u.ability_id), UiStyle.GOLD, 18)
				if u != null:
					var foes := sim.alive_units(BattleUnit.Team.RED if u.team == BattleUnit.Team.BLUE else BattleUnit.Team.BLUE)
					vfx.play_ability(String(e.get("ability", u.ability_id)), u, e.get("focus"), foes,
						sim.units.filter(func(x: BattleUnit) -> bool: return x.alive))
			"area":
				if not e.get("telegraph", false):
					vfx.on_area(u, e.cells)
				if show_ability_areas and not e.cells.is_empty():
					var color := AREA_ALLY if String(e.affects).begins_with("allies") else AREA_ENEMY
					if e.get("telegraph", false):
						arena.flash(e.cells, AREA_TELEGRAPH, e.duration / 1000.0 / speed, true)
					else:
						arena.flash(e.cells, color, ability_flash_time)
					if e.cells.size() >= 20:
						camera.shake()
			"damage":
				var source: BattleUnit = e.get("source")
				if source != null and source != u:
					var st := _stat(source)
					st[["physical", "special", "true"][clampi(int(e.kind), 0, 2)]] += float(e.amount)
				if u != null:
					_stat(u).reduced += float(e.get("reduced", 0.0))
					_stat(u).shield_taken += float(e.get("shield_taken", 0.0))
				if v and source != null and not e.get("blocked", false):
					vfx.hit(source.data.get("anim", {}).get("hitSprite", []), v.body_position())
				if v:
					if e.get("blocked", false):
						hud.overlay.float_text(v.head_position(), GameData.status_name("protect"), Color(0.8, 0.9, 1.0), 16)
					else:
						v.flash_hit()
						# a hit (attack, ability) pushes it away from its attacker; other damage (burn...) only squashes
						var direct: bool = e.get("attack", false) or e.get("ability", false)
						v.hit_react(_ground_of(source) if direct and source != u else null, e.crit, not direct)
						var colors := [Color(1.0, 0.62, 0.35), Color(0.55, 0.75, 1.0), Color(1, 1, 1)]
						var size := 24 if e.crit else 18
						hud.overlay.float_text(v.head_position(), str(int(e.amount)) + ("!" if e.crit else ""), colors[e.kind], size)
			"heal":
				var healer: BattleUnit = e.get("source", u)
				if healer != null:
					_stat(healer).heal += float(e.amount)
				if v and e.amount >= 1:
					hud.overlay.float_text(v.head_position(), "+%d" % int(e.amount), UiStyle.GREEN, 16)
			"shield":
				var giver: BattleUnit = e.get("source", u)
				if giver != null:
					_stat(giver).shield += float(e.amount)
				if v and e.amount >= 1:
					hud.overlay.float_text(v.head_position(), L.t("+%d shield") % int(e.amount), Color(0.9, 0.9, 0.9), 14)
			"status":
				if v:
					hud.overlay.float_text(v.head_position() + Vector3.UP * 0.2, GameData.status_name(String(e.status)), Color(0.85, 0.6, 1.0), 14)
			"miss":
				if v:
					hud.overlay.float_text(v.head_position(), L.t("miss"), UiStyle.TEXT_DIM, 14)
			"death":
				if v:
					v.die()
					if v == _info_view:
						_info_view = null
			"remove": # left the fight without fainting (Comfey became an item...)
				if v:
					v.visible = false
					if v == _info_view:
						_info_view = null
			"resurrect":
				if v:
					v.flash_hit(Color(1.0, 0.95, 0.6))
					hud.overlay.float_text(v.head_position() + Vector3.UP * 0.2, GameData.item_name("MAX_REVIVE") + "!", UiStyle.GOLD, 20)
			"item":
				if v:
					hud.overlay.float_text(v.head_position() + Vector3.UP * 0.2, String(e.get("text", "")), UiStyle.GOLD, 18)
			"effect":
				var color: Color = e.get("color", UiStyle.GOLD)
				if v:
					hud.overlay.float_text(v.head_position() + Vector3.UP * 0.3, L.t(String(e.text)), color, 18)
				else:
					hud.banner(L.t(String(e.text)), color, 0.8)
					_refresh_board_effects() # the tidal wave washes the board
			"spawn":
				if u != null and not battle_views.has(u.id):
					var nv := _make_view(u.pkm, u.team)
					nv.snap_to(arena.cell_to_world(u.cell))
					nv.items = u.items
					_bind_battle_view(nv, u)
					nv.flash_hit(Color(0.7, 1.0, 0.7))
					nv.pop_in()
					spawn_views.append(nv)
			"transform":
				if v:
					v.transform(String(e.get("pkm", u.pkm)))
					v.flash_hit(Color(1.0, 1.0, 0.7))
					if v == _info_view:
						_show_info(v)
			"lightning":
				var struck: Array[Vector2i] = [e.cell]
				arena.flash(struck, LIGHTNING_COLOR, 0.45)
				camera.shake(0.5)
			"board_effect":
				_refresh_board_effects()


func _refresh_board_effects() -> void:
	var tints := {}
	for c in sim.board_effects:
		for effect in BOARD_EFFECT_COLORS:
			if sim.board_effects[c].has(effect):
				tints[c] = BOARD_EFFECT_COLORS[effect]
				break
	arena.set_layer("board_effect", tints)
#endregion


#region cells: occupancy, hover, drag highlights
## Light spotlight (when LIGHT is active) and Ground: the holes (a pit, wider and darker the deeper,
## "depth/5" on the floor) and, while the synergy is active, the cells where a Ground Pokémon digs
## one level deeper at the next stage (amber). At 5/5 it has found what was buried there (gold).
func _update_board_layers() -> void:
	var light := {}
	if player.synergy_tier("LIGHT") > 0:
		light[player.light_cell] = LIGHT_COLOR
	arena.set_layer("light", light)
	var holes := {}
	var dig := {}
	var labels := {}
	var digging: Array[Vector2i] = []
	if player.synergy_tier("GROUND") > 0:
		for cell in player.board:
			if (player.board[cell] as PlayerState.OwnedUnit).types().has("GROUND"):
				digging.append(cell)
	for cell in player.ground_holes:
		var depth := int(player.ground_holes[cell])
		if depth > 0:
			holes[cell] = float(depth) / PlayerState.MAX_HOLE_DEPTH
	for cell in holes.keys() + digging:
		var depth := int(player.ground_holes.get(cell, 0))
		var full := depth >= PlayerState.MAX_HOLE_DEPTH
		if digging.has(cell) and not full:
			dig[cell] = DIG_COLOR
		labels[cell] = {"text": "%d/%d" % [depth, PlayerState.MAX_HOLE_DEPTH],
			"color": UiStyle.GOLD if full else (Color(1.0, 0.78, 0.35) if digging.has(cell) else HOLE_TEXT)}
	arena.set_hole_depths(holes)
	arena.set_layer("dig", dig)
	arena.set_cell_labels("holes", labels)


func _update_occupied_layer() -> void:
	if not show_occupied_cells:
		arena.clear_layer("occupied")
		return
	var cells := {}
	if (phase == Phase.FIGHT or phase == Phase.RESULT) and sim != null:
		for u in sim.units:
			if u.alive:
				cells[u.cell] = OCCUPIED_BLUE if u.team == BattleUnit.Team.BLUE else OCCUPIED_RED
	else:
		for cell in player.board:
			cells[cell] = OCCUPIED_BLUE
		for s in player.bench_slots:
			if not player.slot_units(s).is_empty():
				cells[Vector2i(s, Arena.BENCH_ROW)] = Color(OCCUPIED_BLUE, 0.18)
		for entry in wave.get("board", []):
			cells[EndlessWaves.to_sim_cell(int(entry[1]), int(entry[2]))] = OCCUPIED_RED
	if _drag_unit != null:
		var from := player.find(_drag_unit)
		if not from.has("bench") or player.slot_units(int(from.bench)).size() <= 1: # a copy left behind keeps it occupied
			cells.erase(Arena.slot_key(from))
	arena.set_layer("occupied", cells)


func _update_drag_highlights() -> void:
	var valid := {}
	var in_fight := phase == Phase.FIGHT
	if not in_fight:
		for c in BattleBoard.all_cells():
			if PlayerState.is_player_cell(c):
				valid[c] = VALID_COLOR
	for s in player.bench_slots: # a slot takes copies of one Pokémon (PlayerState.can_place)
		if _can_drop({"bench": s}):
			valid[Vector2i(s, Arena.BENCH_ROW)] = VALID_COLOR
	arena.set_layer("valid", valid)

	var target := {}
	var range_cells := {}
	var key: Variant = Arena.slot_key(_hover_slot)
	if key != null:
		var ok := _can_drop(_hover_slot)
		target[key] = TARGET_OK if ok else TARGET_BAD
		if show_drag_range and _hover_slot.has("board"):
			var r := int(_drag_unit.data().get("range", 1))
			for c in BattleBoard.cells_in_range(_hover_slot.board, r):
				range_cells[c] = RANGE_COLOR
	arena.set_layer("target", target)
	arena.set_layer("range", range_cells)


func _clear_drag_highlights() -> void:
	arena.clear_layer("valid")
	arena.clear_layer("target")
	arena.clear_layer("range")


func _can_drop(slot: Dictionary) -> bool:
	if _drag_unit == null or slot.is_empty():
		return false
	var from := player.find(_drag_unit)
	if phase == Phase.FIGHT and not (slot.has("bench") and from.has("bench")):
		return false
	return player.can_place(_drag_unit, slot)


## Hovered synergy: the cells under the player's Pokémon of that synergy (board and
## bench, types given by items included) pulse in its colour.
func _update_synergy_focus() -> void:
	if _synergy_focus == "":
		arena.clear_layer("synergy")
		return
	var color: Color = GameData.TYPE_COLORS.get(_synergy_focus, UiStyle.GOLD)
	color.a = 0.8 + 0.2 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.4)
	var cells := {}
	for v in owned_views.values():
		if not is_instance_valid(v) or v.dragging:
			continue
		var unit := _owned_unit(v.owned_id)
		if unit == null or not unit.types().has(_synergy_focus):
			continue
		var cell: Variant = null
		if v.battle_unit != null and phase == Phase.FIGHT:
			if v.battle_unit.alive:
				cell = v.battle_unit.cell
		else:
			cell = Arena.slot_key(arena.world_to_slot(v.position))
		if cell != null:
			cells[cell] = color
	arena.set_layer("synergy", cells)


func _show_hover(view: UnitView) -> void:
	var cells := {}
	if view != null and not view.dragging:
		var cell: Variant = null
		if view.battle_unit != null and phase == Phase.FIGHT:
			cell = view.battle_unit.cell
		else:
			cell = Arena.slot_key(arena.world_to_slot(view.position))
		if cell != null:
			cells[cell] = HOVER_COLOR
	arena.set_layer("hover", cells)
#endregion


var _framed := false ## the compact HUD framed the board once (the next framings are animated)
var _frame_tween: Tween
var _auto_pitch := [Rect2(), 0.0] ## the room of the board -> its auto pitch (_pick_pitch)


## Compact HUD (phones): the camera frames the board and the bench in the room the panels leave
## (Hud.board_rect); otherwise the camera of the scene.
func _frame_board() -> void:
	if _scene_camera.is_empty():
		return
	if hud.board_rect.size.x <= 1.0:
		camera.pitch_degrees = _scene_camera[3]
		camera.distance = _scene_camera[0]
		camera.focus_point = _scene_camera[1]
		camera.screen_offset = _scene_camera[2]
		return
	var rim := arena.rim_margin * arena.cell_size
	var half := arena.board_half_width() + rim
	var near := arena.bench_near_z() + rim
	var far := arena.board_far_z() - rim
	var tall := 1.7 * arena.cell_size # sprites and health bars of the far row
	var top := arena.cell_to_world(Vector2i(0, BattleBoard.HEIGHT - 1)).z
	var points := PackedVector3Array([Vector3(-half, 0, near), Vector3(half, 0, near), Vector3(-half, 0, far), Vector3(half, 0, far),
		Vector3(-arena.board_half_width(), tall, top), Vector3(arena.board_half_width(), tall, top)])
	var before := [camera.distance, camera.screen_offset]
	camera.pitch_degrees = _pick_pitch(points)
	camera.frame(points, hud.board_rect)
	# the room changed while playing (the shop opened / closed): the board glides to its new size. Not in the
	# headless tests, which measure the board right after the layout.
	if _frame_tween != null:
		_frame_tween.kill()
	if _framed and DisplayServer.get_name() != "headless":
		var after := [camera.distance, camera.screen_offset]
		camera.distance = before[0]
		camera.screen_offset = before[1]
		_frame_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_frame_tween.tween_property(camera, "distance", after[0], 0.2)
		_frame_tween.tween_property(camera, "screen_offset", after[1], 0.2)
	_framed = true


## Compact HUD: the angle of the camera over the board. The player's (Settings.board_pitch), else the one
## showing the board the biggest - its cells cover the most of the screen - in the room it has while the shop
## is closed (Hud.board_room_full): low enough for the board to be as wide as that room, high enough for it
## to be as tall. The same angle is kept when the shop opens (the board only gets smaller).
func _pick_pitch(points: PackedVector3Array) -> float:
	if Settings.board_pitch > 0:
		return float(Settings.board_pitch)
	var room := hud.board_room_full
	if room.size.x <= 1.0 or room.size.y <= 1.0:
		return compact_pitch_degrees
	if _auto_pitch[0] == room:
		return _auto_pitch[1]
	var side := arena.board_half_width()
	var near_z := arena.bench_near_z()
	var far_z := arena.board_far_z()
	var best := compact_pitch_degrees
	var best_area := -1.0
	for p in range(AUTO_PITCH_MIN, AUTO_PITCH_MAX + 1):
		camera.pitch_degrees = p
		camera.frame(points, room)
		var near_left := camera.unproject_position(Vector3(-side, 0.0, near_z))
		var near_right := camera.unproject_position(Vector3(side, 0.0, near_z))
		var far_left := camera.unproject_position(Vector3(-side, 0.0, far_z))
		var far_right := camera.unproject_position(Vector3(side, 0.0, far_z))
		var area := 0.5 * ((near_right.x - near_left.x) + (far_right.x - far_left.x)) * absf(near_left.y - far_left.y)
		if area > best_area + 0.5:
			best_area = area
			best = p
	_auto_pitch = [room, best]
	return best


## Touch screens: the press at `pos` now was a tap (short, not moved).
func _is_tap(pos: Vector2) -> bool:
	return UiScale.touch and pos.distance_to(_press_pos) <= TAP_SLOP and Time.get_ticks_msec() - _press_ms <= TAP_MS


#region input
## While dragging, motion and release are read before the UI, so a unit can be
## dropped on the shop (sell) even though the shop panel eats mouse events.
func _input(event: InputEvent) -> void:
	if _drag_item != -1:
		if event is InputEventMouseMotion:
			_item_drag_motion(event.position)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_drop_item(event.position)
			get_viewport().set_input_as_handled()
		return
	if _drag_view == null:
		return
	if event is InputEventMouseMotion:
		_on_mouse_motion(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_drop(event.position)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.OVER:
		return
	if event is InputEventMouseMotion:
		if _drag_view == null:
			_on_mouse_motion(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_press_pos = event.position
		_press_ms = Time.get_ticks_msec()
		_point_at(event.position) # a touch gives no motion before the press: the slot under it, not the last one
		if _click_wanderer(event.position):
			return
		_begin_drag(event.position)
		if UiScale.touch and _drag_view == null:
			_inspect(event.position) # a Pokémon that cannot be dragged (enemy, fighting): its panel; nothing: closed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_point_at(event.position)
		_inspect(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				if phase == Phase.PLANNING:
					_start_fight()
			KEY_D:
				_reroll()
			KEY_F1:
				if cheats != null:
					cheats.toggle()
			KEY_F:
				player.buy_xp()
			KEY_ESCAPE:
				_close_info()


## The slot under a screen point becomes the hovered one (_pick_view falls back on it).
func _point_at(pos: Vector2) -> void:
	var ground: Variant = camera.ground_point(pos)
	_hover_slot = arena.world_to_slot(ground) if ground != null else {}


func _on_mouse_motion(pos: Vector2) -> void:
	var ground: Variant = camera.ground_point(pos)
	_hover_slot = arena.world_to_slot(ground) if ground != null else {}
	if _drag_view != null:
		if ground != null:
			_drag_view.position = ground + Vector3.UP * 0.35
		var over_shop := hud.is_over_shop(pos)
		hud.show_sell(player.sell_price(_drag_unit) if over_shop else -1, true)
		if over_shop:
			_hover_slot = {}
		_update_drag_highlights()
	else:
		_show_hover(_pick_view(pos, _all_views()))


## A wandering Pokémon clicked: caught (the catchable one stays when the bench is full).
func _click_wanderer(pos: Vector2) -> bool:
	if wanderers == null:
		return false
	var data := wanderers.pick(pos, camera, false)
	if data.is_empty():
		return false
	if not player.catch_wanderer(data):
		hud.overlay.float_text(camera.project_position(pos, 10.0), L.t("Bench full"), UiStyle.RED, 18)
		return true
	wanderers.pick(pos, camera, true)
	if String(data.kind) == "outlaw":
		hud.banner(L.t("The outlaw was caught: +%d gold") % Town.OUTLAW_GOLD, UiStyle.GOLD, 1.2)
		Audio.play_sfx("notification")
	else:
		hud.banner(L.t("%s caught!") % GameData.display_name(String(data.pkm)), UiStyle.GREEN, 1.0)
	_on_player_changed()
	return true


func _all_views() -> Array:
	var out: Array = []
	for v in owned_views.values():
		if is_instance_valid(v):
			out.append(v)
	for v in enemy_views + spawn_views:
		if is_instance_valid(v):
			out.append(v)
	return out


## Front-most view whose sprite is under the mouse, else the one on the cell.
func _pick_view(pos: Vector2, candidates: Array) -> UnitView:
	var best: UnitView = null
	for v in candidates:
		if not is_instance_valid(v) or not v.visible or v.dragging:
			continue
		if v.battle_unit != null and not v.battle_unit.alive:
			continue
		if v.screen_rect(camera).has_point(pos):
			if best == null or v.global_position.z > best.global_position.z:
				best = v
	if best == null:
		var key: Variant = Arena.slot_key(_hover_slot)
		for v in candidates:
			if is_instance_valid(v) and v.visible and key != null and Arena.slot_key(arena.world_to_slot(v.position)) == key:
				return v
	return best


func _begin_drag(pos: Vector2) -> void:
	if phase != Phase.PLANNING and phase != Phase.FIGHT:
		return
	var candidates: Array = []
	for v in owned_views.values():
		if not is_instance_valid(v):
			continue
		var unit := _owned_unit(v.owned_id)
		if unit == null:
			continue
		if phase == Phase.FIGHT and not player.find(unit).has("bench"):
			continue
		candidates.append(v)
	var v := _pick_view(pos, candidates)
	if v == null:
		return
	_drag_view = v
	_drag_unit = _owned_unit(v.owned_id)
	v.set_dragging(true)
	_update_stack_views()
	hud.tips.suspended = true
	_show_hover(null)
	_on_mouse_motion(pos)


func _drop(pos: Vector2) -> void:
	if _is_tap(pos): # touch: a tap on one's Pokémon shows its panel, it goes back to its place
		_cancel_drag()
		_point_at(pos)
		_inspect(pos)
		return
	var unit := _drag_unit
	var view := _drag_view
	_drag_view = null
	_drag_unit = null
	view.set_dragging(false)
	hud.tips.suspended = false
	hud.show_sell(-1)
	_clear_drag_highlights()
	var from := player.find(unit)
	if hud.is_over_shop(pos) and (phase == Phase.PLANNING or from.has("bench")):
		player.sell(unit)
		return
	var ground: Variant = camera.ground_point(pos)
	var slot := arena.world_to_slot(ground) if ground != null else {}
	if cheats != null and cheats.visible and cheats.get_global_rect().has_point(pos):
		slot = {} # released on the cheat panel: back to its place
	_drag_unit = unit
	var ok := _can_drop(slot)
	_drag_unit = null
	if not (ok and player.move_unit(unit, slot)):
		view.move_to(_slot_world(from), 0.15, "dash")
		_update_stack_views()
	elif slot.has("board") and unit.passive() == "STOUTLAND_SEARCH" and player.has_buried_item(slot.board):
		hud.overlay.float_text(view.head_position(), L.t("Bark!"), UiStyle.GOLD, 20)


func _cancel_drag() -> void:
	hud.tips.suspended = false
	if _drag_view != null:
		var view := _drag_view
		var from := player.find(_drag_unit)
		_drag_view = null
		_drag_unit = null
		view.set_dragging(false)
		if not from.is_empty():
			view.snap_to(_slot_world(from))
		_update_stack_views()
	hud.show_sell(-1)
	_clear_drag_highlights()


func _owned_unit(id: int) -> PlayerState.OwnedUnit:
	for u in player.bench:
		if u != null and u.id == id:
			return u
	for u in player.board.values():
		if u.id == id:
			return u
	return null


func _inspect(pos: Vector2) -> void:
	var v := _pick_view(pos, _all_views())
	_info_view = v
	if v == null:
		_close_info()
		return
	_show_info(v)


func _close_info() -> void:
	_info_view = null
	hud.info_panel.hide()
	arena.clear_layer("range")


## Fills the unit panel for a view: live unit in a fight, else a preview with its items.
func _show_info(v: UnitView) -> void:
	var fighting := v.battle_unit != null and (phase == Phase.FIGHT or phase == Phase.RESULT)
	var cell_text := ""
	var cell: Variant = null
	if fighting:
		cell = v.battle_unit.cell
	else:
		var slot := arena.world_to_slot(v.position)
		cell = slot.get("board")
		if slot.has("bench"):
			cell_text = L.t("On bench slot %d: benched Pokémon do not fight.") % (slot.bench + 1)
			var copies := player.slot_units(int(slot.bench)).size() if v.owned_id >= 0 else 1
			if copies > 1:
				cell_text += " " + L.t("%d copies share this slot (a third one merges them); drag to take one out.") % copies
	var attack_range := int(GameData.get_pokemon(v.pkm).get("range", 1))
	var owned := _owned_unit(v.owned_id) if v.owned_id >= 0 else null
	var held: Array = v.items
	if owned != null:
		held = owned.items
	if fighting:
		attack_range = v.battle_unit.attack_range
	elif held.has("WIDE_LENS"):
		attack_range += int(GameData.get_item("WIDE_LENS").stats.get("RANGE", 0))
	if cell != null:
		cell_text = L.t("Stands on cell (%d, %d). One Pokémon always occupies exactly one cell; its range is counted in cells around it.") % [cell.x, cell.y]
		var cells := {}
		for c in BattleBoard.cells_in_range(cell, attack_range):
			cells[c] = Color(RANGE_COLOR, 0.35)
		arena.set_layer("range", cells)
	var info := {
		"pkm": v.pkm, "unit": v.battle_unit if fighting else null, "items": held,
		"owned": owned != null, "team": v.team, "cell_text": cell_text, "player": player,
	}
	if owned != null:
		info.sell = player.sell_price(owned)
		info.skill = owned.tm
	if fighting:
		info.skill = v.battle_unit.ability_id
	elif owned != null: # its permanent stats (training, berries, Kubfu...) and items, like in a fight
		var preview := BattleUnit.create(owned.pkm, BattleUnit.Team.BLUE)
		for stat in owned.mods:
			preview.add_stat(stat, float(owned.mods[stat]))
		if owned.stacks > 0 and owned.passive() == "FUR_COAT":
			preview.add_stat("def", 2.0 * owned.stacks)
			preview.add_stat("speed", -5.0 * owned.stacks)
		preview.equip(owned.items)
		preview.hp = preview.max_hp
		info.unit = preview
		info.preview = true
	elif enemy_views.has(v): # a Pokémon of the next wave: its stats with the wave's multipliers and boosts
		var i := enemy_views.find(v)
		var entry: Array = wave.get("board", [])[i]
		var preview := BattleUnit.create(String(entry[0]), BattleUnit.Team.RED)
		preview.apply_stat_scale(wave.get("statScale", {}))
		preview.apply_stat_boosts(wave.get("statBoosts", {}))
		preview.equip(held)
		info.unit = preview
		info.preview = true
	hud.info_panel.show_unit(info)
#endregion


#region item drag & drop
## Items go on the player's Pokémon: any of them while planning, bench ones during a fight.
func _begin_item_drag(index: int) -> void:
	var remover := index == ItemBench.REMOVER
	if phase == Phase.OVER or (not remover and (index < 0 or index >= player.items.size())):
		return
	_cancel_drag()
	_drag_item = index
	_press_pos = get_viewport().get_mouse_position()
	_press_ms = Time.get_ticks_msec()
	hud.tips.suspended = true
	hud.show_item_drag(PlayerState.ITEM_REMOVER if remover else player.items[index])
	_item_drag_motion(get_viewport().get_mouse_position())


func _item_target(pos: Vector2) -> PlayerState.OwnedUnit:
	var candidates: Array = []
	for v in owned_views.values():
		if not is_instance_valid(v):
			continue
		var unit := _owned_unit(v.owned_id)
		if unit == null or (phase != Phase.PLANNING and not player.find(unit).has("bench")):
			continue
		candidates.append(v)
	var v := _pick_view(pos, candidates)
	return _owned_unit(v.owned_id) if v != null else null


func _item_drag_motion(pos: Vector2) -> void:
	var ground: Variant = camera.ground_point(pos)
	_hover_slot = arena.world_to_slot(ground) if ground != null else {}
	var unit := _item_target(pos)
	var target := {}
	var hint := ""
	var ok := false
	if unit != null:
		var remover := _drag_item == ItemBench.REMOVER
		var preview := player.strip_preview(unit) if remover else player.equip_preview(_drag_item, unit)
		ok = preview.ok
		var key: Variant = Arena.slot_key(player.find(unit))
		if key != null:
			target[key] = TARGET_OK if ok else TARGET_BAD
		if ok and remover:
			hint = L.t("Remove %d item(s)") % preview.count
		elif ok:
			hint = L.t("Combine: %s") % GameData.item_name(preview.result) if preview.has("combine") else L.t("Equip")
		else:
			hint = L.t(String(preview.get("reason", "")))
	arena.set_layer("target", target)
	hud.move_item_drag(pos, hint, ok)
	# over another component of the item bench: show what the two make
	# (the tooltip closes by itself when the mouse leaves the slot)
	var over := hud.item_bench.slot_at(pos) if _drag_item >= 0 else -1
	if over == _drag_item:
		over = -1
	if over >= 0 and (over != _combine_preview or not hud.tips.has_open()):
		hud.item_bench.show_combine_preview(over, player.items[_drag_item])
	_combine_preview = over


func _drop_item(pos: Vector2) -> void:
	if _is_tap(pos): # touch: a tap on an item shows what it does
		var tapped := _drag_item
		_cancel_item_drag()
		hud.item_bench.show_item_info(tapped)
		return
	var index := _drag_item
	var unit := _item_target(pos)
	var garden_target := hud.garden.target_at(pos) if index >= 0 else {}
	var bench_slot := hud.item_bench.slot_at(pos) if index >= 0 else -1
	_cancel_item_drag()
	if bench_slot >= 0 and bench_slot != index:
		# Exchange / Recycle Ticket on an item of the item bench (either way round)
		var ticket := index if ["EXCHANGE_TICKET", "RECYCLE_TICKET"].has(player.items[index]) else bench_slot
		var other := bench_slot if ticket == index else index
		var used := player.use_ticket(ticket, other)
		if used.ok:
			hud.banner("+ " + ", ".join(used.result.map(func(i: String) -> String: return GameData.item_name(i))),
				UiStyle.GOLD, 0.9)
		elif used.has("reason"):
			hud.banner(L.t(String(used.reason)), UiStyle.RED, 0.9)
		return
	if not garden_target.is_empty():
		# mulch on a flower pot / berry tree
		var grown := SynergyItems.use_mulch(player, index, garden_target)
		if grown != "":
			hud.banner("+ " + grown, UiStyle.GREEN, 0.9)
		return
	if unit == null:
		return
	if index == ItemBench.REMOVER:
		var removed := player.strip_items(unit)
		var rv: UnitView = owned_views.get(unit.id)
		if rv != null and not removed.is_empty():
			hud.overlay.float_text(rv.head_position(), L.t("-%d item(s)") % removed.size(), UiStyle.GOLD, 20)
		return
	var result := player.equip(index, unit)
	if result.ok and result.has("choice"): # Rotom Catalog: pick a form
		_queue_choices([result.choice])
	if result.ok and result.has("evolved"): # Rare Candy, Shiny Stone, orbs, nectars, masks
		var ev: UnitView = owned_views.get(unit.id)
		if ev != null:
			hud.overlay.float_text(ev.head_position(), L.t("%s evolved!") % GameData.display_name(result.evolved), UiStyle.GOLD, 20)
	if result.ok and result.has("combine"):
		var v: UnitView = owned_views.get(unit.id)
		if v != null:
			hud.overlay.float_text(v.head_position(), GameData.item_name(result.result), UiStyle.GOLD, 20)


func _cancel_item_drag() -> void:
	if _drag_item == -1:
		return
	_drag_item = -1
	_combine_preview = -1
	hud.tips.close_all()
	hud.tips.suspended = false
	hud.hide_item_drag()
	arena.clear_layer("target")
#endregion
