class_name RunRules
extends RefCounted

## The rules of a run that the Game scene and the bot (tools/bot) share, without node nor HUD text:
## what a won wave gives, what a lost one costs, what an answer to a town choice does, what is picked
## when the player leaves a choice open. The stage loop itself (Game._next_stage / _start_planning /
## _start_fight / _end_fight) is mirrored by BotRun: keep both in step when it changes.


## Life lost after a lost or drawn fight (game-commands.ts): (ceil(stage / 2) + enemies alive), times
## the difficulty's lifeLossScale.
static func life_loss(stage: int, survivors: int) -> int:
	return ceili((ceili(stage / 2.0) + survivors) * float(Difficulty.value("lifeLossScale", 1.0)))


## The player has this Pokémon (board, bench or Dojo).
static func owns(player: PlayerState, pkm: String) -> bool:
	for u in player.bench + player.board.values():
		if u != null and u.pkm == pkm:
			return true
	return player.dojo.any(func(e: Dictionary) -> bool: return e.unit.pkm == pkm)


## Item reward of a won wave (pve-stages.ts getRewards / getRewardsPropositions, described by the
## exporter; endless-stages.ts for the wild waves). The items are given at once; a choice is returned
## for the caller to queue: {given: Array[String], choice: {} or an "items" choice}.
##   kind random: `count` items of `pool` (`unique`: not one given by a random reward yet;
##     `remember`: they count as given); weighted: twice the chance for the ones not given yet
##   kind choice: pick 1 of `count` items of `pool` (+ `extra` more from `extra_pool`)
##   kind fixed: all of `pool`; `extra` (a list): given too
##   shiny: the reward of a shiny boss; if_board: Charcadet on the board (or in the Dojo) gives
##     an armor (Psychic vs Ghost), Zacian the Rusted Sword
static func give_reward(player: PlayerState, reward: Variant) -> Dictionary:
	var out := {"given": [] as Array[String], "choice": {}}
	if not reward is Dictionary:
		return out
	var given: Array[String] = []
	var if_board: Dictionary = reward.get("if_board", {})
	for pkm in if_board:
		if not owns(player, pkm):
			continue
		var item := String(if_board[pkm])
		if item == "ARMOR":
			var counts := player.synergy_counts()
			var psy := int(counts.get("PSYCHIC", 0))
			var ghost := int(counts.get("GHOST", 0))
			item = "AUSPICIOUS_ARMOR" if psy > ghost or (psy == ghost and player.rng.randf() < 0.5) else "MALICIOUS_ARMOR"
		given.append(item)
	var spec: Dictionary = reward.shiny if player.shiny_encounter and reward.has("shiny") else reward
	var pool: Array[String] = []
	if spec.get("pool") is Array:
		pool.assign(spec.pool)
	else:
		pool = EndlessWaves.item_pool(String(spec.get("pool", "component")))
	# Battle Pass: no stone of a synergy still locked among the rewards
	pool.assign(pool.filter(func(i: String) -> bool: return not GameData.item_locked(i)))
	if spec.get("unique", false):
		pool.assign(pool.filter(func(i: String) -> bool: return not player.random_components_given.has(i)))
	var kind: String = spec.get("kind", "choice" if spec.get("choice", false) else "random")
	var count := int(spec.get("count", 1))
	match kind:
		"fixed":
			given.append_array(pool)
		"choice":
			var options: Array[String] = []
			options.assign(Town._pick_n(pool, count, player.rng))
			var extra_pool: Array = spec.get("extra_pool", []).filter(func(i: String) -> bool: return not GameData.item_locked(i))
			for _i in int(spec.get("extra", 0)) if extra_pool.size() > 0 else 0:
				var rest := extra_pool.filter(func(i: String) -> bool: return not options.has(i))
				if not rest.is_empty():
					options.append(rest[player.rng.randi() % rest.size()])
			if not options.is_empty():
				out.choice = {"kind": "items", "source": "reward", "items": options}
		"weighted":
			for _i in count:
				var weights := {}
				for item in pool:
					weights[item] = 1 if player.random_components_given.has(item) else 2
				var item := SynergyItems._weighted(player.rng, weights)
				given.append(item)
				if spec.get("remember", false):
					player.random_components_given.append(item)
		_:
			for _i in count:
				if pool.is_empty():
					break
				var item: String = pool[player.rng.randi() % pool.size()]
				given.append(item)
				if spec.get("remember", false):
					player.random_components_given.append(item)
	for item in spec.get("extra", []) if spec.get("extra") is Array else []:
		given.append(String(item))
	for item in given:
		player.add_item(item)
	out.given = given
	return out


## Applies the answer to a town choice `c` (portal index, Pokémon index, item id; null = skipped).
## Returns {offer: the propositions after a portal ({} = none), pkm: the Pokémon taken, result: what
## give_pokemon did ("bench", "merged", "sold"), starter: placed on the board}.
static func apply_choice(player: PlayerState, c: Dictionary, answer: Variant, town_rng: RandomNumberGenerator) -> Dictionary:
	var out := {"offer": {}, "pkm": "", "result": "", "starter": false}
	match c.kind:
		"portal":
			var portal: Dictionary = c.portals[clampi(int(answer), 0, c.portals.size() - 1)]
			player.change_map(portal.map) # new region: its locked synergies for the run, berry trees, regional Pokémon
			var offer := Town.propositions(player, int(c.get("stage", player.stage)), portal.synergies, town_rng)
			if not offer.pokemons.is_empty():
				out.offer = offer
		"pokemon":
			var i := clampi(int(answer), 0, c.pokemons.size() - 1)
			var pkm: String = c.pokemons[i]
			out.pkm = pkm
			if c.category == "form":
				player.change_form(int(c.unit), pkm)
				return out
			if c.category == "addpick": # a regional variant unlocks the form it replaces
				player.unlock_additional(pkm)
			if pkm.contains("+"): # a duo: both Pokémon
				for member in pkm.split("+"):
					player.give_pokemon(member)
				return out
			out.result = player.give_pokemon(pkm)
			if c.category == "starter" and player.board.is_empty():
				out.starter = place_starter(player, pkm)
			if i < c.items.size():
				player.add_item(c.items[i])
		"items":
			if answer is String:
				match c.source:
					"wand":
						player.choose_wand(answer)
					"carousel":
						player.gold -= int(c.get("cost", 0))
						player.take_town_item(answer)
					_:
						player.add_item(answer)
	return out


## The first Pokémon goes straight to the board.
static func place_starter(player: PlayerState, pkm: String) -> bool:
	for i in player.bench_size:
		var u: PlayerState.OwnedUnit = player.bench[i]
		if u != null and u.pkm == pkm:
			return player.move_unit(u, {"board": Vector2i(3, PlayerState.PLAYER_ROWS - 1)})
	return false


## web autoPickChoices: what is done with a choice the player left open when the fight starts:
## {action: "answer" (with `answer`), "drop" (a form choice: Rotom keeps its form) or "wait" (a Fairy
## wand waits)}. Random answers, a priced carousel skipped.
static func auto_answer(c: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	match c.kind:
		"portal":
			return {"action": "answer", "answer": rng.randi() % c.portals.size()}
		"pokemon":
			if c.category == "form":
				return {"action": "drop"}
			return {"action": "answer", "answer": rng.randi() % c.pokemons.size()}
		"items":
			if c.source == "wand":
				return {"action": "wait"}
			return {"action": "answer", "answer": null if int(c.get("cost", 0)) > 0 else c.items[rng.randi() % c.items.size()]}
	return {"action": "drop"}
