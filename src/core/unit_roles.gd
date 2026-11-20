class_name UnitRoles
extends RefCounted

## TFT-like role of a Pokémon ("type of character" in the unit panel): where to
## place it and which items suit it. PAC has no roles, so they are guessed from
## the range (of the web data), the bulk and what the ability does:
##   support   ability only helps allies (heal, shield, buff, cleanse)
##   assassin  melee with a dash
##   tank      melee, DEF + SPE_DEF >= 10, or bulky (HP >= 80, DEF + SPE_DEF >= 8), or shields
##             itself (stats of the first form of the family)
##   fighter   other melee
##   caster    ranged, ability deals damage
##   marksman  other ranged (fights with basic attacks)
## A role with a "range" (caster, marksman: 5) gives at least that attack range: not in the web game, so they
## shoot from the back rows of the hex board (GameData applies it to its data at load, `attack_range`).

const ROLES := {
	"tank": {
		"name": "Tank", "front": true, "color": Color(0.55, 0.75, 1.0),
		"desc": "Stands in the front row and soaks damage for the team. Wants HP, DEF and SPE_DEF.",
		"items": ["ROCKY_HELMET", "ASSAULT_VEST", "KINGS_ROCK", "STICKY_BARB", "POKE_DOLL", "MUSCLE_BAND", "MAX_REVIVE", "SHINY_CHARM"],
	},
	"fighter": {
		"name": "Fighter", "front": true, "color": Color(1.0, 0.62, 0.35),
		"desc": "Melee damage dealer that can take a few hits. Wants ATK, sustain and a bit of bulk.",
		"items": ["SHELL_BELL", "RED_ORB", "PUNCHING_GLOVE", "RAZOR_CLAW", "MUSCLE_BAND", "PROTECTIVE_PADS", "FLAME_ORB", "UPGRADE"],
	},
	"assassin": {
		"name": "Assassin", "front": true, "color": Color(0.85, 0.45, 1.0),
		"desc": "Dashes to the enemy back line with its ability. Wants crit and burst.",
		"items": ["RAZOR_CLAW", "RED_ORB", "SMOKE_BALL", "SCOPE_LENS", "REAPER_CLOTH", "SHELL_BELL", "XRAY_VISION", "PROTECTIVE_PADS"],
	},
	"caster": {
		"name": "Caster", "front": false, "color": Color(0.55, 0.6, 1.0), "range": 5,
		"desc": "Deals its damage with its ability from the back line. Wants AP and PP.",
		"items": ["CHOICE_SPECS", "AQUA_EGG", "SOUL_DEW", "POKEMONOMICON", "REAPER_CLOTH", "BLUE_ORB", "DEEP_SEA_TOOTH", "STAR_DUST"],
	},
	"marksman": {
		"name": "Marksman", "front": false, "color": Color(1.0, 0.85, 0.35), "range": 5,
		"desc": "Ranged basic attacker. Wants SPEED, crit and on-hit effects.",
		"items": ["RAZOR_FANG", "LOADED_DICE", "XRAY_VISION", "WIDE_LENS", "SCOPE_LENS", "UPGRADE", "RED_ORB", "DEEP_SEA_TOOTH"],
	},
	"support": {
		"name": "Support", "front": false, "color": Color(0.45, 0.9, 0.55),
		"desc": "Helps its allies with its ability (heals, shields, buffs). Stays safe behind the team.",
		"items": ["GREEN_ORB", "ABILITY_SHIELD", "GRACIDEA_FLOWER", "SOUL_DEW", "AQUA_EGG", "STAR_DUST", "SAFETY_GOGGLES", "KINGS_ROCK"],
	},
}

static var _cache: Dictionary = {}


static func role_of(pkm: String) -> String:
	if not _cache.has(pkm):
		_cache[pkm] = _guess(pkm)
	return _cache[pkm]


static func info(role: String) -> Dictionary:
	return ROLES.get(role, ROLES.fighter)


## Attack range of a form: at least the "range" of its role, else `web_range` (its web data).
static func attack_range(pkm: String, web_range: int) -> int:
	return maxi(web_range, int(info(role_of(pkm)).get("range", 0)))


static func _guess(pkm: String) -> String:
	var data := GameData.get_pokemon(pkm)
	if data.is_empty():
		return "fighter"
	var ab := GameData.get_ability(data.get("skill", ""))
	var helps_allies := false
	var hurts_enemies := false
	var shields_self := false
	for step in ab.get("steps", []):
		var affects: String = step.get("affects", "enemies")
		for eff in step.get("effects", []):
			var on_self: bool = eff.get("to", "") == "self" or step.get("area") == "self"
			if on_self:
				shields_self = shields_self or eff.type == "shield"
			elif affects.begins_with("allies"):
				helps_allies = helps_allies or ["heal", "shield", "buff", "cleanse"].has(eff.type)
			elif eff.type == "damage":
				hurts_enemies = true
	if helps_allies and not hurts_enemies:
		return "support"
	if int(GameData.web_stat(pkm, "range", 1)) >= 2: # the web range: the range of the role does not change a role
		return "caster" if hurts_enemies else "marksman"
	if ab.has("dash") and hurts_enemies:
		return "assassin"
	# evolutions grow every stat: compare the first form of the family, by its web stats (the auto balance of
	# data/balance.json must not change a role: it tunes the stats by role)
	var base := String(data.get("family", ""))
	if GameData.get_pokemon(base).is_empty():
		base = pkm
	var bulk := float(GameData.web_stat(base, "def")) + float(GameData.web_stat(base, "speDef"))
	if bulk >= 10.0 or (float(GameData.web_stat(base, "hp")) >= 80.0 and bulk >= 8.0) or shields_self:
		return "tank"
	return "fighter"
