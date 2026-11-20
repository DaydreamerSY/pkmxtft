class_name GameText
extends RefCounted

## Turns the web game descriptions (data/pac/text.json, items.json) into BBCode for
## RichTextLabel, like addIconsToDescription() of the web client:
##   SPECIAL / PHYSICAL / TRUE       -> coloured "special damage"...
##   ATK, AP, SPE_DEF...             -> stat icon + coloured name
##   BURN, WOUND...                  -> status name
##   ON_HIT, ADJACENT...             -> technical term
##   FIRE, SILK_SCARF...             -> synergy / item name
##   [25,50,100,SP]                  -> 25/50/100 (per star level)

const ICON_SIZE := 16

static var _token_re: RegEx
static var _placeholder_re: RegEx


static func format(desc: String, icon_size := ICON_SIZE) -> String:
	if _token_re == null:
		_token_re = RegEx.create_from_string("\\[[^\\]]*\\]|\\b[A-Z][A-Z0-9_]*[A-Z0-9]\\b")
		_placeholder_re = RegEx.create_from_string("\\{\\{[^}]*\\}\\}")
	desc = _placeholder_re.sub(desc, "", true).strip_edges()
	var out := ""
	var last := 0
	for m in _token_re.search_all(desc):
		out += desc.substr(last, m.get_start() - last)
		out += _token(m.get_string(), icon_size)
		last = m.get_end()
	return out + desc.substr(last)


static func _token(token: String, icon_size: int) -> String:
	var t: Dictionary = GameData.text
	if token.begins_with("["):
		# web value lists ([30,LK], [1,2,3]) -> "30" / "1/2/3"; BBCode tags ([b], [color=...]) stay
		var values: Array[String] = []
		for part in token.substr(1, token.length() - 2).split(","):
			var p := part.strip_edges()
			if p.is_valid_float():
				values.append(p)
			elif p != "LK" and p != "":
				return token
		return _color("/".join(values), UiStyle.GOLD) if not values.is_empty() else ""
	if t.get("damage", {}).has(token):
		return _color(t.damage[token], UiStyle.DAMAGE_COLORS.get(token, UiStyle.TEXT))
	if t.get("stat", {}).has(token):
		return stat_text(token, icon_size)
	if t.get("status", {}).has(token):
		return _color(t.status[token], UiStyle.STATUS_COLOR)
	if t.get("technical_terms", {}).has(token):
		return "[i]%s[/i]" % t.technical_terms[token]
	if t.get("synergy", {}).has(token):
		return "[img=%d]%s[/img]%s" % [icon_size, "res://assets/types/%s.svg" % token,
			_color(t.synergy[token], GameData.TYPE_COLORS.get(token, UiStyle.TEXT).lightened(0.25))]
	if t.get("item", {}).has(token):
		return _color(t.item[token], UiStyle.GOLD)
	if t.get("weather", {}).has(token):
		return _color(t.weather[token], Color(0.7, 0.85, 1.0))
	if t.get("effect", {}).has(token):
		return _color(t.effect[token], Color(0.7, 0.85, 1.0))
	return token


## Stat icon + coloured stat name ("[img]ATK[/img] Attack").
static func stat_text(stat: String, icon_size := ICON_SIZE, with_name := true) -> String:
	var icon_path := "res://assets/icons/%s.png" % stat
	var img := "[img=%d]%s[/img]" % [icon_size, icon_path] if ResourceLoader.exists(icon_path) else ""
	var shown: String = GameData.stat_name(stat) if with_name else ""
	return img + _color(shown, UiStyle.STAT_COLORS.get(stat, UiStyle.TEXT))


## "+10 [AP] +15 [PP]" line of an item.
static func item_stats(item: String, icon_size := ICON_SIZE) -> String:
	var parts: Array[String] = []
	var stats: Dictionary = GameData.item_stats(item)
	for stat in stats:
		var v := float(stats[stat])
		var shown := ("%+d" % roundi(v)) + ("%" if stat in ["CRIT_CHANCE", "CRIT_POWER", "LUCK"] else "")
		parts.append(_color(shown, UiStyle.STAT_COLORS.get(stat, UiStyle.TEXT)) + stat_text(stat, icon_size, false))
	return "  ".join(parts)


static func _color(text: String, color: Color) -> String:
	return "[color=#%s]%s[/color]" % [color.to_html(false), text]
