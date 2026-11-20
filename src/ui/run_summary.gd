class_name RunSummary
extends VBoxContainer

## Statistics of the run on the Game Over screen (RunStats.summary): fights, time, gold, the
## final team, the best damage dealers (bars split like the DPS meter) and the best blocker /
## healer. Built in code; not in the web game.

const ROW_HEIGHT := 30.0


func setup(s: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	add_theme_constant_override("separation", 8)
	var record := L.t("Fights: %d") % int(s.get("fights", 0)) + "  •  " + L.t("%d won") % int(s.get("wins", 0)) \
		+ "  •  " + L.t("%d lost") % (int(s.get("losses", 0)) + int(s.get("draws", 0)))
	_centered(record, 17, UiStyle.TEXT)
	var secs := int(s.get("seconds", 0))
	var line := L.t("Time: %s") % ("%d:%02d" % [secs / 60, secs % 60]) + "  •  " + L.t("Level %d") % int(s.get("level", 1)) \
		+ "  •  " + L.t("Gold earned: %d") % int(s.get("gold", 0)) + "  •  " + L.t("Rerolls: %d") % int(s.get("rerolls", 0))
	_centered(line, 15, UiStyle.TEXT_DIM)
	_pass_block(s.get("pass", {}))
	var team: Array = s.get("team", [])
	if not team.is_empty():
		_heading(L.t("Final team"))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 2)
		for entry in team.slice(0, 12):
			var pkm := String(entry.get("pkm", ""))
			var icon := UiStyle.icon_rect(GameData.portrait(pkm), 40, CanvasItem.TEXTURE_FILTER_NEAREST)
			icon.tooltip_text = "%s %s" % [GameData.display_name(pkm), "★".repeat(int(entry.get("stars", 1)))]
			row.add_child(icon)
		add_child(row)
	var damage: Array = s.get("damage", [])
	if not damage.is_empty():
		_heading(L.t("Damage dealt"))
		var best := RunStats.damage_of(damage[0])
		for e in damage:
			add_child(_bar_row(e, [[e.physical, UiStyle.DAMAGE_COLORS.PHYSICAL], [e.special, UiStyle.DAMAGE_COLORS.SPECIAL],
				[e["true"], UiStyle.DAMAGE_COLORS.TRUE]], RunStats.damage_of(e), best))
	var bests := HBoxContainer.new()
	bests.alignment = BoxContainer.ALIGNMENT_CENTER
	bests.add_theme_constant_override("separation", 28)
	for pair in [["blocked", L.t("Damage blocked"), RunStats.blocked_of], ["healing", L.t("Heal and shield"), RunStats.healing_of]]:
		var list: Array = s.get(pair[0], [])
		if not list.is_empty():
			bests.add_child(_best(String(pair[1]), list[0], float((pair[2] as Callable).call(list[0]))))
	var fight: Dictionary = s.get("best_fight", {})
	if not fight.is_empty():
		bests.add_child(_best(L.t("Best fight (stage %d)") % int(fight.stage), fight, float(fight.damage)))
	if bests.get_child_count() > 0:
		add_child(bests)
	else:
		bests.free()


## Battle Pass (Progression.report): the XP of the run, where the pass stands, what was unlocked.
func _pass_block(p: Dictionary) -> void:
	if p.is_empty():
		return
	var gained := int(p.get("xp", 0))
	_heading(L.t("Battle Pass") + ("   " + L.t("+%d XP") % gained if gained > 0 else ""))
	add_child(PassPanel.progress_row(p, 280.0))
	if not p.get("fair", true):
		_centered(L.t("No pass XP: cheats were used"), 13, UiStyle.TEXT_DIM)
	var unlocked: Array = p.get("unlocked", [])
	if int(p.get("to", 1)) > int(p.get("from", 1)):
		_centered(L.t("Level up!") + ("  " + L.t("Unlocked for your next run:") if not unlocked.is_empty() else ""), 15, UiStyle.GREEN)
		if not unlocked.is_empty():
			add_child(PassPanel.synergy_row(unlocked))


func _centered(text: String, size: int, color: Color) -> void:
	var label := UiStyle.label(text, size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)


func _heading(text: String) -> void:
	_centered(text, 15, UiStyle.GOLD)


func _portrait(pkm: String, size: float) -> TextureRect:
	var icon := UiStyle.icon_rect(GameData.portrait(pkm), size, CanvasItem.TEXTURE_FILTER_NEAREST)
	icon.tooltip_text = GameData.display_name(pkm)
	return icon


## portrait, name, a bar of coloured `parts` ([value, colour]) scaled to `best`, and the total.
func _bar_row(e: Dictionary, parts: Array, total: float, best: float) -> Control:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	h.add_theme_constant_override("separation", 8)
	h.add_child(_portrait(String(e.pkm), ROW_HEIGHT))
	var name_label := UiStyle.label(GameData.display_name(String(e.pkm)), 15)
	name_label.custom_minimum_size = Vector2(130, 0)
	name_label.clip_text = true
	h.add_child(name_label)
	var bar := Control.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.draw.connect(_draw_bar.bind(bar, parts, best))
	h.add_child(bar)
	var value := UiStyle.label(_number(total), 15)
	value.custom_minimum_size = Vector2(64, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(value)
	return h


func _draw_bar(bar: Control, parts: Array, best: float) -> void:
	var r := Rect2(Vector2(0, 8), Vector2(bar.size.x, bar.size.y - 16))
	bar.draw_rect(r, Color(1, 1, 1, 0.06))
	var x := 0.0
	for part in parts:
		var w: float = r.size.x * float(part[0]) / maxf(best, 1.0)
		if w > 0.0:
			bar.draw_rect(Rect2(Vector2(x, r.position.y), Vector2(w, r.size.y)), part[1])
		x += w


## A small "title / portrait + name + value" block.
func _best(title: String, e: Dictionary, value: float) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var head := UiStyle.label(title, 13, UiStyle.TEXT_DIM)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	h.add_child(_portrait(String(e.pkm), 28))
	h.add_child(UiStyle.label("%s  %s" % [GameData.display_name(String(e.pkm)), _number(value)], 15))
	v.add_child(h)
	return v


## 1234 -> "1,234"
static func _number(value: float) -> String:
	var digits := str(roundi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return digits + out
