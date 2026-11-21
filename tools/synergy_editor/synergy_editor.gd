extends Control

## Editor of the synergy effects of each season (a dev tool, not part of the game; its labels are in Vietnamese):
## data/season_synergies.json (SeasonSynergies). Run tools\synergy_editor.bat, or:
##   Godot.exe --path . res://tools/synergy_editor/synergy_editor.tscn [-- shot <dir>]
## Pick a season and a synergy: keep the web game's effect, replace it or add to it with effect blocks
## (SeasonSynergies.EFFECTS), own thresholds, own text. The panel shows the season's Pokémon of the synergy with their
## roles (UnitRoles) and previews the synergy tooltip as the game will show it. "Lưu" writes the file and
## docs/SEASON_SYNERGIES.md; the game reads the file when it starts.
## `-- shot <dir>`: fills an example (not saved), saves a picture in <dir> and quits (to check the tool on the hidden
## desktop: SHOT_SCENE=res://tools/synergy_editor/synergy_editor.tscn tools/screenshot_hidden.ps1 <dir> shot).
## `-- doc` (headless is fine): writes docs/SEASON_SYNERGIES.md from the file and quits.

const DOC_PATH := "res://docs/SEASON_SYNERGIES.md"
const MODE_KEYS: Array[String] = ["web", "replace", "add"]
const MODE_LABELS: Array[String] = ["Giữ hiệu ứng bản web", "Thay hiệu ứng web", "Thêm vào hiệu ứng web"]
const MODE_SHORT := {"web": "web", "replace": "THAY", "add": "THÊM"}
const FIELD_LABELS := {"who": "Ai nhận", "stat": "Chỉ số", "stack": "Chỉ số", "gain": "Nhận", "to": "Cho ai",
	"on": "Khi", "scale": "Theo", "kind": "Loại sát thương", "status": "Trạng thái", "duration": "Thời gian (ms)",
	"max": "Tối đa (0 = không giới hạn)", "threshold": "Dưới % HP", "percent": "Theo %"}
const CHOICE_LABELS := {"members": "Pokémon của hệ", "team": "Cả đội", "self": "Bản thân", "adjacent": "Nó + đồng đội kề",
	"attack": "Đòn đánh trúng", "ability": "Skill trúng", "both": "Cả hai", "flat": "Số cố định", "special": "Phép",
	"physical": "Vật lý", "true": "Chuẩn", "atk": "ATK", "ap": "AP", "hp": "HP", "def": "DEF", "speDef": "SPE_DEF",
	"speed": "SPEED", "critChance": "Tỉ lệ chí mạng", "critPower": "ST chí mạng", "dodge": "Né đòn", "luck": "May mắn",
	"shield": "Khiên", "pp": "PP", "range": "Tầm đánh", "heal": "Hồi máu"}
const VALUE_HINTS := {"stat": "số cộng (theo % thì % chỉ số gốc; khiên theo % = % HP)", "attack_stack": "cộng mỗi đòn",
	"cast_bonus": "lượng (khiên / hồi theo % = % HP tối đa)", "hit_status": "% tỉ lệ", "hit_damage": "sát thương (theo ATK: % ATK)",
	"ability_power": "+% sát thương / hồi / khiên của skill", "damage_amp": "+% sát thương", "damage_reduction": "% bớt",
	"pp_regen": "PP mỗi giây", "regen": "% HP tối đa mỗi giây", "lifesteal": "% sát thương", "low_hp": "khiên / hồi: % HP; chỉ số: số cộng",
	"kill_bonus": "khiên / hồi: % HP; chỉ số: số cộng"}
const ROLE_SHORT := {"tank": "Đỡ đòn", "fighter": "Đấu sĩ", "assassin": "Sát thủ", "marksman": "Xạ thủ", "caster": "Pháp sư",
	"support": "Hỗ trợ"}
const LISTS_ALL: Array[String] = ["pool", "additional", "regional", "unique", "legendary"]

var _data: Dictionary = {}
var _season := ""
var _type := ""
var _types: Array[String] = []
var _dirty := false
var _family_forms: Dictionary = {} # family -> forms
var _season_pick: OptionButton
var _list: ItemList
var _panel: VBoxContainer
var _preview: RichTextLabel
var _problems: RichTextLabel
var _status: Label


func _ready() -> void:
	get_tree().auto_accept_quit = false
	# every synergy and every Pokémon, whatever the player's pass and season: the tool edits every season
	Progression.override_level = 9999
	Seasons.set_current(Seasons.FULL)
	GameData.set_language("vi")
	GameData.apply_progression()
	theme = load("res://scenes/ui/theme/ui_theme.tres")
	for pkm in GameData.pokemon:
		var fam := String(GameData.pokemon[pkm].get("family", pkm))
		if not _family_forms.has(fam):
			_family_forms[fam] = []
		_family_forms[fam].append(pkm)
	for type in GameData.full_thresholds():
		_types.append(String(type))
	_types.sort_custom(func(a: String, b: String) -> bool: return GameData.synergy_name(a) < GameData.synergy_name(b))
	_load()
	_build()
	_select_season(0)
	var args := OS.get_cmdline_user_args()
	if args.has("doc"):
		var doc := FileAccess.open(DOC_PATH, FileAccess.WRITE)
		doc.store_string(_doc_text())
		doc.close()
		print("synergy editor: wrote docs/SEASON_SYNERGIES.md")
		get_tree().quit.call_deferred()
		return
	var at := args.find("shot")
	if at >= 0:
		_take_shot.call_deferred(args[at + 1] if at + 1 < args.size() else args[0])


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	if not _dirty:
		get_tree().quit()
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Chưa lưu"
	dialog.dialog_text = "Có thay đổi chưa lưu. Lưu trước khi thoát?"
	dialog.ok_button_text = "Lưu và thoát"
	dialog.cancel_button_text = "Ở lại"
	dialog.add_button("Thoát không lưu", true, "discard")
	dialog.confirmed.connect(func() -> void:
		_save()
		get_tree().quit())
	dialog.custom_action.connect(func(_action: StringName) -> void: get_tree().quit())
	add_child(dialog)
	dialog.popup_centered()


#region file
func _load() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SeasonSynergies.PATH)) \
		if FileAccess.file_exists(SeasonSynergies.PATH) else null
	_data = parsed if parsed is Dictionary else {}
	if not _data.get("seasons") is Dictionary:
		_data["seasons"] = {}
	SeasonSynergies.load_data(_data) # the same dictionary: the previews follow the edits
	_dirty = false


func _save() -> void:
	var file := FileAccess.open(SeasonSynergies.PATH, FileAccess.WRITE)
	var doc := FileAccess.open(DOC_PATH, FileAccess.WRITE)
	if file == null or doc == null:
		_set_status("LỖI: không ghi được file", true)
		return
	file.store_string(_file_text())
	file.close()
	doc.store_string(_doc_text())
	doc.close()
	_dirty = false
	_set_status("Đã lưu data/season_synergies.json và docs/SEASON_SYNERGIES.md", false)


## The file as written by hand: one synergy a line, one effect a line.
func _file_text() -> String:
	var lines: Array[String] = ["{", "\t\"_doc\": ["]
	var doc: Array = _data.get("_doc", [])
	for i in doc.size():
		lines.append("\t\t%s%s" % [JSON.stringify(String(doc[i])), "," if i < doc.size() - 1 else ""])
	lines.append("\t],")
	lines.append("\t\"seasons\": {")
	var seasons: Dictionary = _data.seasons
	var ids := seasons.keys()
	for si in ids.size():
		var specs: Dictionary = seasons[ids[si]]
		lines.append("\t\t%s: {" % JSON.stringify(String(ids[si])))
		var types := specs.keys()
		for ti in types.size():
			var s: Dictionary = specs[types[ti]]
			var head: Array[String] = []
			for key in s:
				if key != "effects":
					head.append("%s: %s" % [JSON.stringify(String(key)), _inline(s[key])])
			var effects: Array = s.get("effects", [])
			head.append("\"effects\": [")
			lines.append("\t\t\t%s: {%s" % [JSON.stringify(String(types[ti])), ", ".join(head)])
			for ei in effects.size():
				lines.append("\t\t\t\t%s%s" % [_inline(effects[ei]), "," if ei < effects.size() - 1 else ""])
			lines.append("\t\t\t]}%s" % ("," if ti < types.size() - 1 else ""))
		lines.append("\t\t}%s" % ("," if si < ids.size() - 1 else ""))
	lines.append("\t}")
	lines.append("}")
	return "\n".join(lines) + "\n"


static func _inline(v: Variant) -> String:
	if v is Dictionary:
		var parts: Array[String] = []
		for k in v:
			parts.append("%s: %s" % [JSON.stringify(String(k)), _inline(v[k])])
		return "{" + ", ".join(parts) + "}"
	if v is Array:
		var parts: Array[String] = []
		for x in v:
			parts.append(_inline(x))
		return "[" + ", ".join(parts) + "]"
	if v is float and is_equal_approx(v, roundf(v)) and absf(v) < 1e12:
		return str(int(roundf(v)))
	return JSON.stringify(v)


## docs/SEASON_SYNERGIES.md: every season's synergies with effects of their own, in words.
func _doc_text() -> String:
	var lines: Array[String] = ["# Hiệu ứng hệ theo mùa", "",
		"*Sinh bằng `tools\\synergy_editor.bat` (nút Lưu, hoặc chạy scene với `-- doc`); đừng sửa tay. Dữ liệu: "
		+ "`data/season_synergies.json`, code: `src/core/season_synergies.gd`. Không có ở bản web.*", "",
		"Mỗi mùa có thể cho một hệ hiệu ứng riêng: **thay** (bỏ hẳn hiệu ứng trong trận của bản web, chỉ còn các khối dưới) "
		+ "hoặc **thêm** (hiệu ứng web + các khối dưới). Hệ không có trong bảng của mùa giữ hiệu ứng web. Item giữa các "
		+ "stage của hệ (cần câu, cây quả mọng, đũa phép...) giữ nguyên. Mốc riêng: chỉ khi thay (số mốc tuỳ ý); thêm dùng "
		+ "mốc web / mốc của mùa. Mô tả và chữ từng mốc trong tooltip hệ tự sinh từ các khối (hoặc mô tả riêng vi / en).", "",
		"Sửa: mở `tools\\synergy_editor.bat` → chọn mùa → chọn hệ (danh sách trái: số họ của mùa, chữ THAY / THÊM; rê chuột "
		+ "xem vai trò) → chọn kiểu hiệu ứng → thêm khối → nhập giá trị mỗi mốc (cách nhau dấu phẩy) → xem trước tooltip "
		+ "bên phải → Lưu. Phần giữa liệt kê Pokémon của hệ trong mùa và vai trò của chúng, để chọn hiệu ứng hợp đội hình "
		+ "(`docs/ROLES.md`).", "",
		"| Khối | Giá trị mỗi mốc | Tuỳ chọn |", "|---|---|---|"]
	for kind in SeasonSynergies.EFFECTS:
		var fields: Array[String] = []
		for key in SeasonSynergies.EFFECTS[kind].fields:
			fields.append(String(FIELD_LABELS.get(key, key)))
		lines.append("| %s (`%s`) | %s | %s |" % [SeasonSynergies.EFFECTS[kind].vi, kind, VALUE_HINTS.get(kind, ""),
			", ".join(fields)])
	lines.append("")
	for sid in _season_ids():
		lines.append("## %s" % _season_label(sid))
		lines.append("")
		var specs: Dictionary = SeasonSynergies.season_specs(sid)
		if specs.is_empty():
			lines.append("Mùa này giữ hiệu ứng web của mọi hệ.")
			lines.append("")
			continue
		lines.append("| Hệ | Kiểu | Mốc | Hiệu ứng | Từng mốc |")
		lines.append("|---|---|---|---|---|")
		for type in _types:
			if SeasonSynergies.spec(type, sid).is_empty():
				continue
			var t := SeasonSynergies.texts(type, sid, "vi")
			var marks := _thresholds(type, sid)
			var tiers: Array[String] = []
			for i in t.tiers.size():
				tiers.append("(%s) %s" % [str(int(marks[i])) if i < marks.size() else "?", _plain(String(t.tiers[i]))])
			lines.append("| %s | %s | %s | %s | %s |" % [GameData.synergy_name(type),
				"thay" if SeasonSynergies.mode(type, sid) == "replace" else "thêm",
				"/".join(PackedStringArray(marks.map(func(v: Variant) -> String: return str(int(v))))),
				_plain(String(t.desc)).replace("|", "/"), "<br>".join(PackedStringArray(tiers)).replace("|", "/")])
		lines.append("")
	return "\n".join(lines)


## A game text without its markup: [10,25,45] -> 10/25/45, FIRE / ATK / BURN -> their names.
func _plain(text: String) -> String:
	var lists := RegEx.create_from_string("\\[([^\\]]*)\\]")
	for m in lists.search_all(text):
		text = text.replace(m.get_string(), m.get_string(1).replace(",", "/"))
	var words := RegEx.create_from_string("\\b[A-Z][A-Z0-9_]*[A-Z0-9]\\b")
	var out := ""
	var last := 0
	for m in words.search_all(text):
		out += text.substr(last, m.get_start() - last)
		var token := m.get_string()
		var shown := token
		for section in ["synergy", "stat", "status", "damage", "technical_terms"]:
			if GameData.text.get(section, {}).has(token):
				shown = String(GameData.text[section][token])
				break
		out += shown
		last = m.get_end()
	return out + text.substr(last)
#endregion


#region seasons and synergies
func _season_ids() -> Array[String]:
	var ids: Array[String] = []
	for s in Seasons.data().get("seasons", []):
		ids.append(String(s.get("id", "")))
	ids.append(Seasons.FULL)
	return ids


func _season_label(sid: String) -> String:
	return "Không mùa (mọi Pokémon)" if sid == Seasons.FULL else "%s (%s)" % [Seasons.label(sid), sid]


## The thresholds of a synergy in a season: its own (this file), the season's (data/seasons.json), else the web's.
func _thresholds(type: String, sid: String) -> Array:
	var web: Array = GameData.full_thresholds().get(type, [])
	var own := SeasonSynergies.thresholds_of(type, web, sid)
	if not own.is_empty():
		return own
	var season = Seasons.thresholds(sid).get(type) if sid != Seasons.FULL else null
	return season if season is Array and season.size() == web.size() else web


## The season's families having the synergy (by their last forms' types), as [{pkm, role}] of those forms.
func _members(type: String, sid: String) -> Array:
	var families: Array[String] = []
	if sid == Seasons.FULL:
		for list in LISTS_ALL:
			for p in GameData.full_list(list):
				var fam := String(GameData.pokemon.get(p, {}).get("family", p))
				if not families.has(fam):
					families.append(fam)
	else:
		for list in Seasons.LISTS:
			for fam in Seasons.families(list, sid):
				if not families.has(fam):
					families.append(fam)
	var out := []
	for fam in families:
		for pkm in _family_forms.get(fam, []):
			var d: Dictionary = GameData.pokemon[pkm]
			if String(d.get("evolution", "")) == "" and d.get("evolutions", []).is_empty() and d.get("types", []).has(type):
				out.append({"pkm": pkm, "role": UnitRoles.role_of(pkm)})
	return out


func _spec() -> Dictionary:
	return SeasonSynergies.spec(_type, _season)


## The spec of the synergy in the season, made if needed (mode replace / add).
func _own_spec(mode: String) -> Dictionary:
	var seasons: Dictionary = _data.seasons
	if not seasons.get(_season) is Dictionary:
		seasons[_season] = {}
	var specs: Dictionary = seasons[_season]
	if not specs.get(_type) is Dictionary:
		specs[_type] = {"mode": mode, "effects": []}
	specs[_type].mode = mode
	return specs[_type]


func _drop_spec() -> void:
	var specs = _data.seasons.get(_season)
	if specs is Dictionary:
		specs.erase(_type)
		if specs.is_empty():
			_data.seasons.erase(_season)
#endregion


#region layout
func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	top.add_child(UiStyle.label("Hiệu ứng hệ theo mùa", 26, UiStyle.GOLD))
	top.add_child(UiStyle.label("Mùa:", 18, UiStyle.TEXT))
	_season_pick = OptionButton.new()
	for sid in _season_ids():
		_season_pick.add_item(_season_label(sid))
	_season_pick.custom_minimum_size = Vector2(320, 40)
	_season_pick.item_selected.connect(_select_season)
	top.add_child(_season_pick)
	_status = UiStyle.label("", 16, UiStyle.TEXT_DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.clip_text = true
	top.add_child(_status)
	top.add_child(_button("Đọc lại file", func() -> void:
		_load()
		_select_season(_season_pick.selected)
		_set_status("Đã đọc lại data/season_synergies.json", false)))
	top.add_child(_button("Lưu", _save))

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 330
	root.add_child(split)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(330, 0)
	_list.item_selected.connect(func(i: int) -> void: _show_type(_types[i]))
	split.add_child(_list)
	var right := HSplitContainer.new()
	right.split_offset = 560
	split.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(560, 0)
	right.add_child(scroll)
	_panel = VBoxContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_theme_constant_override("separation", 8)
	scroll.add_child(_panel)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	right.add_child(side)
	side.add_child(UiStyle.label("Xem trước (tooltip trong game)", 18, UiStyle.GOLD))
	_preview = _rich(side, true)
	side.add_child(UiStyle.label("Kiểm tra cả file", 18, UiStyle.GOLD))
	_problems = _rich(side, false)


func _rich(parent: Control, expand: bool) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = not expand
	r.scroll_active = expand
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_FILL
	r.custom_minimum_size = Vector2(380, 120)
	r.add_theme_font_size_override("normal_font_size", 16)
	r.add_theme_font_size_override("bold_font_size", 16)
	parent.add_child(r)
	return r


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b


func _set_status(text: String, error: bool) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", Color(1, 0.45, 0.4) if error else UiStyle.TEXT_DIM)


func _select_season(index: int) -> void:
	_season = _season_ids()[clampi(index, 0, _season_ids().size() - 1)]
	_season_pick.select(_season_ids().find(_season))
	_refresh_list()
	_show_type(_type if _type != "" else _types[0])


func _refresh_list() -> void:
	_list.clear()
	for type in _types:
		var mode := SeasonSynergies.mode(type, _season)
		var members := _members(type, _season)
		var i := _list.add_item("%s%s  ·  %d họ" % [GameData.synergy_name(type),
			"" if mode == "web" else "  [%s]" % MODE_SHORT[mode], members.size()], GameData.type_icon(type))
		_list.set_item_custom_fg_color(i, UiStyle.GOLD if mode != "web" else UiStyle.TEXT)
		_list.set_item_tooltip(i, _role_mix(members))
	if _type != "":
		_list.select(_types.find(_type))


func _role_mix(members: Array) -> String:
	var counts := {}
	for m in members:
		counts[m.role] = int(counts.get(m.role, 0)) + 1
	var parts: Array[String] = []
	for role in ROLE_SHORT:
		if counts.has(role):
			parts.append("%s %d" % [ROLE_SHORT[role], counts[role]])
	return ", ".join(parts)
#endregion


#region the synergy
func _show_type(type: String) -> void:
	_type = type
	_list.select(_types.find(type))
	for child in _panel.get_children():
		child.queue_free()
	var head := HBoxContainer.new()
	var icon := TextureRect.new()
	icon.texture = GameData.type_icon(type)
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(icon)
	head.add_child(UiStyle.label("%s (%s) — %s" % [GameData.synergy_name(type), type, _season_label(_season)], 22,
		GameData.TYPE_COLORS.get(type, UiStyle.TEXT).lightened(0.3)))
	_panel.add_child(head)
	var web := String(GameData.text.get("synergy_description", {}).get(type, ""))
	_panel.add_child(UiStyle.rich("[color=#9aa0ad]Bản web: %s[/color]" % GameText.format(web), 15, 540))
	var members := _members(type, _season)
	var names: Array[String] = []
	for m in members:
		names.append("%s (%s)" % [String(GameData.text.get("pkm", {}).get(m.pkm, m.pkm)), ROLE_SHORT.get(m.role, m.role)])
	_panel.add_child(UiStyle.rich("[b]%d họ mùa này[/b] — %s\n[color=#9aa0ad]%s[/color]" % [members.size(), _role_mix(members),
		", ".join(names)], 15, 540))
	# mode
	var mode_row := HBoxContainer.new()
	mode_row.add_child(_caption("Hiệu ứng"))
	var mode_pick := OptionButton.new()
	for label in MODE_LABELS:
		mode_pick.add_item(label)
	mode_pick.select(MODE_KEYS.find(SeasonSynergies.mode(type, _season)))
	mode_pick.item_selected.connect(_set_mode)
	mode_row.add_child(mode_pick)
	_panel.add_child(mode_row)
	var s := _spec()
	if not s.is_empty():
		_build_spec(s)
	_refresh_preview()


func _caption(text: String, width := 190.0) -> Label:
	var l := UiStyle.label(text, 16, UiStyle.TEXT_DIM)
	l.custom_minimum_size = Vector2(width, 0)
	return l


func _set_mode(index: int) -> void:
	var mode := MODE_KEYS[index]
	if mode == "web":
		_drop_spec()
	else:
		var s := _own_spec(mode)
		if mode == "add":
			s.erase("thresholds") # add: the web's thresholds
	_changed()
	_refresh_list()
	_show_type(_type)


func _build_spec(s: Dictionary) -> void:
	var web: Array = GameData.full_thresholds().get(_type, [])
	var row := HBoxContainer.new()
	row.add_child(_caption("Mốc riêng"))
	var marks := LineEdit.new()
	marks.custom_minimum_size = Vector2(220, 0)
	var own = s.get("thresholds", [])
	marks.text = ", ".join(PackedStringArray((own if own is Array else []).map(func(v: Variant) -> String: return str(int(v)))))
	marks.placeholder_text = ", ".join(PackedStringArray(_thresholds(_type, _season).map(func(v: Variant) -> String: return str(int(v)))))
	marks.editable = s.mode == "replace"
	marks.text_changed.connect(func(text: String) -> void:
		var nums := _numbers(text)
		if nums.is_empty():
			s.erase("thresholds")
		else:
			s["thresholds"] = nums
		_changed())
	row.add_child(marks)
	row.add_child(UiStyle.label("trống = %s; chỉ khi Thay (Thêm: mốc web %s)" % [marks.placeholder_text,
		"/".join(PackedStringArray(web.map(func(v: Variant) -> String: return str(int(v)))))], 13, UiStyle.TEXT_DIM))
	_panel.add_child(row)
	var effects: Array = s.get("effects", [])
	for i in effects.size():
		_panel.add_child(_effect_box(s, i))
	var add := _button("+ Thêm hiệu ứng", func() -> void:
		effects.append(_new_effect("stat", [10]))
		s["effects"] = effects
		_changed()
		_show_type(_type))
	add.custom_minimum_size = Vector2(200, 40)
	_panel.add_child(add)
	for lang in ["vi", "en"]:
		var text_row := HBoxContainer.new()
		text_row.add_child(_caption("Mô tả riêng (%s)" % lang))
		var line := LineEdit.new()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.placeholder_text = "trống = tự sinh từ các hiệu ứng"
		var own_text = s.get("text", {})
		line.text = String(own_text.get(lang, "")) if own_text is Dictionary else ""
		line.text_changed.connect(_set_text.bind(s, lang))
		text_row.add_child(line)
		_panel.add_child(text_row)


func _set_text(text: String, s: Dictionary, lang: String) -> void:
	if not s.get("text") is Dictionary:
		s["text"] = {}
	if text.strip_edges() == "":
		s.text.erase(lang)
	else:
		s.text[lang] = text
	if s.text.is_empty():
		s.erase("text")
	_changed()


## An effect with its fields in order (type, its fields, values), the defaults of SeasonSynergies.
func _new_effect(kind: String, values: Array) -> Dictionary:
	var e := {"type": kind}
	if SeasonMechanics.TYPES.has(kind): # a mechanic: its params, one number per tier (the text: "say", by hand)
		for key in SeasonMechanics.TYPES[kind].params:
			e[key] = [1]
		e["values"] = values
		return e
	for key in SeasonSynergies.EFFECTS[kind].fields:
		if SeasonSynergies.CHOICES.has(key):
			e[key] = SeasonSynergies.CHOICES[key][0]
		elif SeasonSynergies.NUMBERS.has(key):
			e[key] = SeasonSynergies.NUMBERS[key]
	e["values"] = values
	return e


func _effect_box(s: Dictionary, index: int) -> Control:
	var effects: Array = s.effects
	var e: Dictionary = effects[index]
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.15)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	box.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	box.add_child(col)
	var top := HBoxContainer.new()
	var kinds: Array = SeasonSynergies.EFFECTS.keys() + SeasonMechanics.TYPES.keys()
	var pick := OptionButton.new()
	for k in kinds:
		pick.add_item(String(SeasonSynergies.EFFECTS.get(k, SeasonMechanics.TYPES.get(k, {})).get("vi", k)))
	pick.select(kinds.find(String(e.get("type", "stat"))))
	pick.item_selected.connect(func(i: int) -> void:
		effects[index] = _new_effect(kinds[i], e.get("values", [10]))
		_changed()
		_show_type(_type))
	top.add_child(pick)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(_button("Xoá", func() -> void:
		effects.remove_at(index)
		_changed()
		_show_type(_type)))
	col.add_child(top)
	var fields: Array = SeasonSynergies.EFFECTS.get(String(e.get("type", "")), {"fields": []}).fields
	var grid := GridContainer.new()
	grid.columns = 2
	for key in fields:
		grid.add_child(_caption(FIELD_LABELS.get(key, key), 170))
		grid.add_child(_field_input(e, key))
	for key in SeasonMechanics.TYPES.get(String(e.get("type", "")), {"params": []}).params:
		grid.add_child(_caption("{%s} mỗi mốc" % key, 170))
		var line := LineEdit.new()
		line.custom_minimum_size = Vector2(200, 0)
		var v = e.get(key, [])
		line.text = ", ".join(PackedStringArray((v if v is Array else [v]).map(func(x: Variant) -> String:
			return SeasonSynergies._num(float(x)))))
		line.text_changed.connect(func(text: String) -> void:
			e[key] = _numbers(text)
			_changed())
		grid.add_child(line)
	col.add_child(grid)
	var values_row := HBoxContainer.new()
	values_row.add_child(_caption("Giá trị mỗi mốc", 170))
	var values := LineEdit.new()
	values.custom_minimum_size = Vector2(200, 0)
	values.text = ", ".join(PackedStringArray(e.get("values", []).map(func(v: Variant) -> String: return SeasonSynergies._num(float(v)))))
	values.text_changed.connect(func(text: String) -> void:
		e["values"] = _numbers(text)
		_changed())
	values_row.add_child(values)
	values_row.add_child(UiStyle.label(VALUE_HINTS.get(String(e.get("type", "")), ""), 13, UiStyle.TEXT_DIM))
	col.add_child(values_row)
	return box


func _field_input(e: Dictionary, key: String) -> Control:
	if key == "percent":
		var check := CheckBox.new()
		check.button_pressed = bool(e.get("percent", false))
		check.toggled.connect(func(on: bool) -> void:
			if on:
				e["percent"] = true
			else:
				e.erase("percent")
			_changed())
		return check
	if SeasonSynergies.NUMBERS.has(key):
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 60000 if key == "duration" else 100
		spin.step = 100 if key == "duration" else 1
		spin.value = float(e.get(key, SeasonSynergies.NUMBERS[key]))
		spin.value_changed.connect(func(v: float) -> void:
			e[key] = v
			_changed())
		return spin
	var pick := OptionButton.new()
	var choices: Array = SeasonSynergies.CHOICES.get(key, [])
	for c in choices:
		pick.add_item(GameData.status_name(c) if key == "status" else String(CHOICE_LABELS.get(c, c)))
	pick.select(maxi(choices.find(String(e.get(key, choices[0] if not choices.is_empty() else ""))), 0))
	pick.item_selected.connect(func(i: int) -> void:
		e[key] = choices[i]
		_changed())
	return pick


func _numbers(text: String) -> Array:
	var out := []
	for part in text.replace(";", ",").split(",", false):
		var p := part.strip_edges()
		if p.is_valid_float():
			out.append(float(p))
	return out


func _changed() -> void:
	_dirty = true
	_set_status("Có thay đổi chưa lưu", false)
	_refresh_preview()


func _refresh_preview() -> void:
	var lines: Array[String] = []
	var mode := SeasonSynergies.mode(_type, _season)
	var marks := _thresholds(_type, _season)
	var desc := String(GameData.text.get("synergy_description", {}).get(_type, ""))
	var tiers: Array = GameData.text.get("synergy_tiers", {}).get(_type, [])
	if mode != "web":
		var own := SeasonSynergies.texts(_type, _season, "vi")
		desc = own.desc if mode == "replace" else desc + "\n" + String(own.desc)
		if mode == "replace":
			tiers = own.tiers
		else:
			var merged := []
			for i in maxi(tiers.size(), own.tiers.size()):
				var parts := PackedStringArray()
				if i < tiers.size():
					parts.append(String(tiers[i]))
				if i < own.tiers.size():
					parts.append(String(own.tiers[i]))
				merged.append(" · ".join(parts))
			tiers = merged
	lines.append("[b]%s[/b]  [color=#9aa0ad](%s)[/color]" % [GameData.synergy_name(_type), MODE_LABELS[MODE_KEYS.find(mode)]])
	lines.append(GameText.format(desc))
	for i in marks.size():
		lines.append("[color=#ffd24d][b](%d)[/b][/color] %s" % [int(marks[i]), GameText.format(String(tiers[i])) if i < tiers.size() else "[color=#ff7766]thiếu chữ mốc này[/color]"])
	if mode != "web":
		lines.append("")
		lines.append("[color=#9aa0ad]Tiếng Anh: %s[/color]" % GameText.format(String(SeasonSynergies.texts(_type, _season, "en").desc)))
	_preview.text = "\n".join(lines)
	var problems := SeasonSynergies.problems()
	_problems.text = "[color=#8fe08f]Không có lỗi.[/color]" if problems.is_empty() else \
		"[color=#ff7766]%s[/color]" % "\n".join(problems)
#endregion


## `-- shot <dir>`: an example on Fire in the first season (not saved), a picture, then quits.
func _take_shot(dir: String) -> void:
	_select_season(0)
	_type = "FIRE"
	var s := _own_spec("replace")
	s["thresholds"] = [2.0, 4.0, 6.0]
	s["effects"] = [
		{"type": "stat", "who": "members", "stat": "ap", "values": [10.0, 25.0, 45.0]},
		{"type": "hit_status", "who": "members", "status": "burn", "duration": 3000.0, "on": "ability", "values": [30.0, 45.0, 60.0]},
		{"type": "cast_bonus", "who": "members", "gain": "shield", "to": "adjacent", "percent": true, "values": [5.0, 10.0, 15.0]},
	]
	_refresh_list()
	_show_type("FIRE")
	DirAccess.make_dir_recursive_absolute(dir)
	for _i in 3:
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("synergy_editor.png"))
	# what "Lưu" would write, next to the picture (the files of the project stay as they are)
	var text := _file_text()
	var parsed = JSON.parse_string(text)
	var ok: bool = parsed is Dictionary and parsed.get("seasons", {}).get("s1", {}).get("FIRE", {}).get("effects", []).size() == 3
	print("synergy editor: file text %s" % ("OK" if ok else "BROKEN"))
	for out in [["season_synergies.json", text], ["SEASON_SYNERGIES.md", _doc_text()]]:
		var f := FileAccess.open(dir.path_join(out[0]), FileAccess.WRITE)
		f.store_string(out[1])
		f.close()
	_dirty = false
	get_tree().quit()
