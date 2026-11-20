class_name Tooltips
extends RefCounted

## Builds the HUD tooltips (shown by HoverTip) from the scenes of scenes/ui/tooltips/,
## one per breakdown screen:
##   item()       hover an item (item bench, unit panel)
##   recipes()    right click an item: what it combines into
##   skill()      hover the ability (unit panel, shop card)
##   stat()       hover a stat of the unit panel
##   synergy()    hover a synergy (list on the left, types of the unit panel)
##   role()       hover the role chip: suggested position and items
##   unit_mini()  hover a Pokémon of the synergy tooltip (with how it gets into the shop: unlock_info())
##   text()       simple title + text (buttons, lock, range, position)
##   pool()       click the "!" of the shop: the Pokémon that joined the shop pool
## `level` = level of the tooltip itself; its rows open theirs at level + 1.

const STAT_INFO := {
	"HP": "Health points. The Pokémon faints at 0.",
	"ATK": "Damage of each basic attack (PHYSICAL).",
	"AP": "Ability power: +1% damage, heal and shield of its ability per point.",
	"DEF": "Reduces PHYSICAL taken: damage / (1 + 5% DEF).",
	"SPE_DEF": "Reduces SPECIAL taken: damage / (1 + 5% SPE_DEF).",
	"SPEED": "Attack and move speed: one attack every 1000 / (0.4 + 0.007 x SPEED) ms.",
	"CRIT_CHANCE": "Chance for a basic attack to be a critical hit.",
	"CRIT_POWER": "Damage multiplier of critical hits.",
	"SHIELD": "Absorbs damage before HP.",
	"LUCK": "Makes random effects more likely.",
	"RANGE": "Attack range in cells (range 1 = the 6 cells around).",
}

## Portal stages offering Uniques / Legendaries (Town.propositions).
const UNIQUE_STAGE := 10
const LEGENDARY_STAGE := 20

static var _color_tag_re: RegEx


static func item(item_id: String, hint := "") -> Control:
	if GameData.get_item(item_id).is_empty():
		return null
	var tip: ItemTip = UiScenes.make(UiScenes.ITEM_TIP)
	tip.item = item_id
	tip.hint = hint
	return tip


static func recipes(item_id: String, level := 0) -> Control:
	if GameData.get_item(item_id).is_empty():
		return null
	var tip: RecipesTip = UiScenes.make(UiScenes.RECIPES_TIP)
	tip.item = item_id
	tip.level = level
	return tip


static func skill(pkm: String, ability := "") -> Control:
	if GameData.get_pokemon(pkm).is_empty():
		return null
	var tip: SkillTip = UiScenes.make(UiScenes.SKILL_TIP)
	tip.pkm = pkm
	tip.skill = ability
	return tip


## `pkm`: the Pokémon of the panel (PP: the rules of its role).
static func stat(stat_id: String, value: float, base: float, pkm := "") -> Control:
	var tip: StatTip = UiScenes.make(UiScenes.STAT_TIP)
	tip.stat = stat_id
	tip.value = value
	tip.base = base
	tip.pkm = pkm
	return tip


## `player`: its shop state for the unlock line (null = the rule only).
static func unit_mini(pkm: String, player: PlayerState = null) -> Control:
	if GameData.get_pokemon(pkm).is_empty():
		return null
	var tip: UnitMiniTip = UiScenes.make(UiScenes.UNIT_MINI_TIP)
	tip.pkm = pkm
	tip.player = player
	return tip


static func role(role_id: String, level := 0) -> Control:
	var tip: RoleTip = UiScenes.make(UiScenes.ROLE_TIP)
	tip.role = role_id
	tip.level = level
	return tip


## `count` = families on the board with the type, `owned` = families of the board and bench,
## `extra` = what the synergy does on this board (Synergies.context_text), `player` = whose shop
## the Pokémon list tells about (locked ones dim; null = the enemy wave's synergy).
static func synergy(type: String, count: int, owned: Dictionary, level := 0, extra := "",
		player: PlayerState = null) -> Control:
	var tip: SynergyTip = UiScenes.make(UiScenes.SYNERGY_TIP)
	tip.type = type
	tip.count = count
	tip.owned = owned
	tip.level = level
	tip.extra = extra
	tip.player = player
	return tip


## Weather of the fight and its effects.
static func weather(weather_id: String) -> Control:
	var body := GameData.weather_desc(weather_id)
	if weather_id == Weather.NEUTRAL:
		body = L.t("No weather. The synergies of both teams vote for one: GRASS -> Zenith, FIRE -> Drought, WATER -> Rain, ELECTRIC -> Storm... (8 points needed, weather passives count 100).")
	return text(L.t("Weather: %s") % GameData.weather_name(weather_id), body)


static func text(title: String, body: String) -> Control:
	var tip: TextTip = UiScenes.make(UiScenes.TEXT_TIP)
	tip.title = title
	tip.body = body
	return tip


## What a stat does, in the UI language. PP follows the mana rules of the difficulty (Difficulty.mana()):
## those of the role of `pkm` when given, else of every role (roles with the same rules on one line).
static func stat_info(stat_id: String, pkm := "") -> String:
	if stat_id != "PP":
		return L.t(String(STAT_INFO.get(stat_id, "")))
	var text := L.t("Power points: the ability is cast when PP is full.")
	var mana := Difficulty.mana()
	if pkm != "":
		var role := UnitRoles.role_of(pkm)
		return text + " " + L.t(UnitRoles.info(role).name) + ": " + pp_rules(Difficulty.role_mana(role)) + "."
	var roles = mana.get("roles")
	if not roles is Dictionary or roles.is_empty():
		return text + " " + pp_rules(mana) + "."
	var groups := {} # rules in words -> names of the roles
	for role in UnitRoles.ROLES:
		var rule := pp_rules(Difficulty.role_mana(role))
		if not groups.has(rule):
			groups[rule] = []
		groups[rule].append(L.t(UnitRoles.info(role).name))
	var lines: Array[String] = []
	for rule in groups:
		lines.append("%s: %s." % [", ".join(groups[rule]), rule])
	return text + " " + " ".join(lines)


## A set of PP rules in words: "+10 per attack that hits, +5 each time an attack hits it" (the PP to cast is
## the form's own, the PP stat).
static func pp_rules(rules: Dictionary) -> String:
	var parts: Array[String] = []
	if float(rules.get("perAttack", 0.0)) > 0.0:
		parts.append(L.t("+%s per attack that hits") % plain_number(float(rules.perAttack)))
	if float(rules.get("perHit", 0.0)) > 0.0:
		parts.append(L.t("+%s each time an attack hits it") % plain_number(float(rules.perHit)))
	if float(rules.get("perSecond", 0.0)) > 0.0:
		parts.append(L.t("+%s per second") % plain_number(float(rules.perSecond)))
	if float(rules.get("perDamage", 0.0)) > 0.0:
		parts.append(L.t("+1 per %s damage taken") % plain_number(float(rules.perDamage)))
	return ", ".join(parts)


## 5 for 5.0, 0.5 for 0.5.
static func plain_number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else str(snappedf(value, 0.01))


static func format_stat(stat_id: String, value: float) -> String:
	match stat_id:
		"CRIT_CHANCE", "LUCK":
			return "%d%%" % roundi(value)
		"CRIT_POWER":
			return "%d%%" % roundi(value * 100.0)
	return str(roundi(value))


## One Pokémon per family of `source` (default: the shop pool) having `type`, cheapest first: its
## first form HAVING the type (Politoed stands for the Poliwag family in SOUND, Poliwag has not the
## type). Web: synergy-detail-component.tsx keepFirstOfFamily (there in Pokédex order, here by stars).
static func pokemons_of_type(type: String, source: Array = []) -> Array[String]:
	var families := {} # family -> its form shown
	for pkm in (source if not source.is_empty() else GameData.pool):
		var data := GameData.get_pokemon(pkm)
		if not data.types.has(type):
			continue
		var family: String = data.get("family", pkm)
		var shown: String = families.get(family, "")
		if shown == "" or int(data.stars) < int(GameData.get_pokemon(shown).stars):
			families[family] = pkm
	var out: Array[String] = []
	out.assign(families.values())
	out.sort_custom(func(a: String, b: String) -> bool:
		var ca := GameData.rarity_cost(GameData.get_pokemon(a).rarity)
		var cb := GameData.rarity_cost(GameData.get_pokemon(b).rarity)
		return ca < cb or (ca == cb and a < b))
	return out


## Pool of the shop: what joined it and when, what joins next, the regional Pokémon.
static func pool(player: PlayerState, level := 0) -> Control:
	var tip := PoolTip.new()
	tip.player = player
	tip.level = level
	return tip


## The Pokémon of a synergy tooltip in groups, like the web (synergy-detail-component.tsx: regulars,
## additionals, uniques, legendaries), plus the regional lines: [{key, label, pokemons}], a family
## only in its first group. Unlike the web, the additional families not unlocked yet are listed
## (dim, with a lock) so their unlock condition can be read.
static func synergy_groups(type: String) -> Array[Dictionary]:
	var groups: Array[Dictionary] = [
		{"key": "shop", "label": L.t("In the shop"), "source": GameData.pool},
		{"key": "additional", "label": L.t("Additional: join the shop at stages %s") % "/".join(
			GameData.config.get("additionalPickStages", []).map(func(s) -> String: return str(int(s)))), "source": GameData.additional},
		{"key": "regional", "label": L.t("Regional: in the shop of some regions"), "source": GameData.regional},
		{"key": "unique", "label": L.t("%s: offered at stage %d") % [GameData.rarity_name("UNIQUE"), UNIQUE_STAGE], "source": GameData.unique},
		{"key": "legendary", "label": L.t("%s: offered at stage %d") % [GameData.rarity_name("LEGENDARY"), LEGENDARY_STAGE],
			"source": GameData.legendary},
	]
	var seen := {}
	var out: Array[Dictionary] = []
	for g in groups:
		var pokemons: Array[String] = []
		for pkm in pokemons_of_type(type, g.source):
			var family := String(GameData.get_pokemon(pkm).get("family", pkm))
			if PlayerState.FLABEBE_FORMS.has(family): # one entry for the colours (one per run)
				family = "FLABEBE"
			if not seen.has(family):
				seen[family] = true
				pokemons.append(pkm)
		if not pokemons.is_empty():
			out.append({"key": g.key, "label": g.label, "pokemons": pokemons})
	return out


## How a Pokémon gets into the shop (mini card of the synergy tooltip): {text, state}. `text` keeps the
## web keywords (GameText.format); `state`: "owned" (family on the board / bench), "available" (can be
## in the shop now), "locked" (not yet / not in this region / not this run), "offered" (Unique /
## Legendary: a portal choice). Without `player`: the rule only, state "available".
static func unlock_info(pkm: String, player: PlayerState = null) -> Dictionary:
	var data := GameData.get_pokemon(pkm)
	var family := String(data.get("family", pkm))
	var first := GameData.get_pokemon(family)
	var rarity := String(first.get("rarity", data.get("rarity", "")))
	var lines: Array[String] = []
	var state := "available"
	if rarity == "UNIQUE" or rarity == "LEGENDARY":
		lines.append(L.t("%s: one of the %d Pokémon offered after the portal of stage %d.") % [GameData.rarity_name(rarity),
			int(GameData.config.get("nbUniquePropositions", 6)), UNIQUE_STAGE if rarity == "UNIQUE" else LEGENDARY_STAGE])
		state = "offered"
	elif GameData.regional_info.has(family) or GameData.regional_info.has(pkm):
		var key := family if GameData.regional_info.has(family) else pkm
		var regions := " / ".join(region_types(key))
		var base := String(GameData.regional_base.get(key, ""))
		if base != "":
			lines.append(L.t("Regional form of %s: replaces it in the shop of the regions with %s.") % [GameData.display_name(base), regions])
		else:
			lines.append(L.t("Regional: only in the shop of the regions with %s.") % regions)
		var requires := String(GameData.regional_info[key].get("requires", ""))
		if requires != "" and requires != base:
			lines.append(L.t("%s must have joined the shop first.") % GameData.display_name(requires))
		elif requires != "":
			lines.append(L.t("%s is an additional Pokémon: it must have joined the shop first.") % GameData.display_name(requires))
		if player != null:
			var here := player.regional_counts.has(key) or player.regional_pokemons.has(key) or player.regional_pokemons.has(pkm)
			state = "available" if here else "locked"
			var region := TownChoice.map_name(player.map) if player.map != "town" else L.t("the town")
			lines.append((L.t("In the shop of the current region (%s).") if here
				else L.t("Not in the shop of the current region (%s).")) % region)
	elif GameData.additional.has(family) or GameData.additional.has(pkm):
		var index := PlayerState.ADDITIONAL_RARITIES.find(rarity)
		var stages: Array = GameData.config.get("additionalPickStages", [])
		var at := int(stages[index]) if index >= 0 and index < stages.size() else 0
		if player != null and player.unlocked_additional.has(family):
			lines.append(L.t("Additional: in your shop since stage %d.") % at)
		else:
			lines.append(L.t("Additional: joins the shop at stage %d, with the other %s additional Pokémon.") % [at,
				GameData.rarity_name(rarity)])
			if player != null:
				state = "locked"
	elif PlayerState.FLABEBE_FORMS.has(family):
		lines.append(L.t("Only one Flabébé color is in the shop each run, picked at random."))
		if player != null:
			lines.append(L.t("This run: %s.") % GameData.display_name(player.flower_color))
			family = player.flower_color # owned: this run's colour
	elif data.get("types", []).has("WILD"):
		lines.append(L.t("WILD: only shows up in the shop through the WILD chance (PvE stages, or the WILD synergy)."))
		if player != null:
			var chance := Synergies.wild_chance(player)
			state = "available" if chance > 0.0 else "locked"
			lines.append(L.t("WILD chance now: %s%%") % plain_number(snappedf(chance * 100.0, 0.1)))
	else:
		lines.append(L.t("In the shop from the start."))
	if player != null and SynergyList.owned_families(player).has(family):
		state = "owned"
	return {"text": " ".join(lines), "state": state}


## Synergies of the regions where a regional Pokémon is found (isInRegion: its own types, not the ones
## of the form it replaces).
static func region_types(pkm: String) -> Array[String]:
	var map_types := {}
	for m in GameData.regional_info.get(pkm, {}).get("maps", []):
		for t in GameData.config.get("maps", {}).get(m, {}).get("synergies", []):
			map_types[t] = true
	var base := String(GameData.regional_base.get(pkm, ""))
	var base_types: Array = GameData.get_pokemon(base).get("types", []) if base != "" else []
	var out: Array[String] = []
	for t in GameData.get_pokemon(pkm).get("types", []):
		if map_types.has(t) and not base_types.has(t):
			out.append(t)
	if out.is_empty():
		for t in GameData.get_pokemon(pkm).get("types", []):
			if map_types.has(t):
				out.append(t)
	return out


static func strip_colors(bbcode: String) -> String:
	if _color_tag_re == null:
		_color_tag_re = RegEx.create_from_string("\\[/?color[^\\]]*\\]")
	return _color_tag_re.sub(bbcode, "", true)
