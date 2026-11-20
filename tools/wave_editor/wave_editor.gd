extends Control

## Editor of the Endless waves (a dev tool, not part of the game; its labels are in
## Vietnamese). Run tools\wave_editor.bat, or:
##   Godot.exe --path . res://tools/wave_editor/wave_editor.tscn [-- shot <dir>]
## Tab "Template wave": data/wave_templates.json (WaveTemplates) - which stages a
## template is used at, its slots (how many Pokémon, given or random by type / rarity,
## stars, items, row), stat changes, synergies - with a live preview of the wave built
## for a stage and a seed, and the schedule of the 60 first stages.
## Tab "Độ khó": data/difficulty.json (Difficulty) - `base` and each level's overrides,
## with a table of what the waves get at a few stages.
## "Lưu" writes both files; the game reads them when it starts.
## `-- shot <dir>` saves a picture of each tab in <dir> and quits (used to check the tool).

const SCALE_STATS: Array[String] = ["HP", "ATK", "DEF", "SPE_DEF", "SPEED"]
const FLAT_STATS: Array[String] = ["HP", "ATK", "DEF", "SPE_DEF", "AP", "SPEED"]
const RARITIES: Array[String] = ["COMMON", "UNCOMMON", "RARE", "EPIC", "ULTRA", "UNIQUE", "LEGENDARY"]
const SYNERGY_MODES: Array[String] = ["auto", "on", "off"]
const SYNERGY_MODE_LABELS: Array[String] = ["Theo độ khó", "Luôn kích hệ", "Không kích hệ"]
const REWARDS: Array[String] = ["default", "none", "component", "full", "choice_component", "choice_full"]
const REWARD_LABELS: Array[String] = ["Theo luật stage", "Không thưởng", "1 mảnh ghép", "1 item ghép", "Chọn 1 trong 3 mảnh",
	"Chọn 1 trong 3 item ghép"]
const ITEM_POOLS: Array[String] = ["auto", "component", "full"]
const ITEM_POOL_LABELS: Array[String] = ["Theo stage", "Mảnh ghép", "Item ghép"]
const STAR_LABELS: Array[String] = ["Theo stage", "1★", "2★", "3★"]
const ROW_VALUES: Array[int] = [0, 3, 2, 1]
const ROW_LABELS: Array[String] = ["Theo tầm đánh", "Hàng trước", "Hàng giữa", "Hàng sau"]
const PICKER_LIMIT := 150
const LABEL_WIDTH := 200.0
## The PP rules of a role (mana.roles.<role>, Difficulty.role_mana): key and label of each number.
const MANA_KEYS := [["perAttack", "đòn trúng"], ["perHit", "bị đánh"]]
const ROLE_HINT := "PP mỗi đòn đánh thường trúng, PP mỗi lần bị đòn đánh thường trúng. PP cần để dùng skill không theo vai trò: mỗi Pokémon có maxPP riêng (data/balance.json, tools/bot/autobalance.py). Vai trò suy từ tầm đánh / chỉ số / skill (src/core/unit_roles.gd)."

## Difficulty form: ["#", section] or [path, label, kind, ...]; kinds: num (min, max, step),
## bool, range (min, max: a [from, to] pair), stats (stat names, min, max, step), keys ([[key, label]...],
## min, max, step: a dictionary of numbers). `hint` last.
const SCHEMA := [
	["#", "Đội hình bầy hoang dã"],
	["endless.unitsBase", "Số con gốc", "num", 0, 24, 0.5, "Số con = gốc + stage × (thêm mỗi stage), kẹp trong [ít nhất, nhiều nhất]."],
	["endless.unitsPerStage", "Thêm con mỗi stage", "num", 0, 3, 0.05, ""],
	["endless.minUnits", "Ít nhất", "num", 1, 24, 1, ""],
	["endless.maxUnits", "Nhiều nhất", "num", 1, 24, 1, "Từ 10 con trở lên độ hiếm dùng tỉ lệ shop level 10."],
	["endless.twoStarsStages", "2★: từ stage → 100% ở stage", "range", 0, 500, "Tỉ lệ 2★ tăng đều từ 0% tới 100% giữa hai stage."],
	["endless.threeStarsStages", "3★: từ stage → 100% ở stage", "range", 0, 500, ""],
	["endless.bossInterval", "Boss quay lại mỗi N stage", "num", 1, 100, 1, "Sau boss gốc cuối cùng (stage 40)."],
	["#", "Item của địch"],
	["endless.firstItemStage", "Bầy hoang dã cầm item từ stage", "num", 1, 500, 1, ""],
	["endless.stagesPerItem", "Thêm 1 item mỗi N stage", "num", 1, 100, 1, ""],
	["endless.fullItemsStage", "Item ghép từ stage", "num", 1, 500, 1, "Trước đó là mảnh ghép."],
	["bossItems", "Boss cầm item", "bool", "Boss gốc cầm marowakItems của bản web (không cần gặp Marowak)."],
	["itemsPerUnit", "Tối đa item mỗi con", "num", 0, 3, 1, ""],
	["#", "Hệ của địch"],
	["enemySynergies", "Wave địch kích hệ", "bool", "Tắt = giống bản web: chỉ đội người chơi có hiệu ứng hệ."],
	["enemySynergiesFromStage", "Kích hệ từ stage", "num", 1, 500, 1, ""],
	["bossSynergies", "Boss cũng kích hệ", "bool", ""],
	["synergyBonus", "Cộng điểm cho mỗi hệ wave có", "num", 0, 9, 1, "Để wave ít con vẫn đạt mốc."],
	["#", "Chỉ số của địch"],
	["statScale", "Nhân chỉ số gốc", "stats", SCALE_STATS, 0.05, 50, 0.05, "1 = giữ nguyên. Áp trước cộng thẳng và item."],
	["statScalePerStage", "Cộng vào hệ số mỗi stage", "stats", SCALE_STATS, 0, 5, 0.005, "0.01 = +1% mỗi stage."],
	["statScaleStartStage", "… kể từ stage", "num", 1, 500, 1, ""],
	["statBoosts", "Cộng thẳng (mọi stage)", "stats", FLAT_STATS, -1000, 10000, 1, ""],
	["endless.statBoostsPerStage", "Cộng dồn mỗi stage", "stats", ["HP", "ATK", "AP", "DEF", "SPE_DEF"], 0, 1000, 0.5, ""],
	["endless.scalingStartStage", "… kể từ stage", "num", 0, 500, 1, ""],
	["#", "Mana (PP) cơ bản — mọi Pokémon, cả hai đội, theo vai trò"],
	["mana.perSecond", "PP hồi mỗi giây", "num", 0, 50, 0.5, "Web: 10. RAIN +3 / DROUGHT -3 vẫn cộng vào số này; PP của item / hệ / passive không đổi."],
	["mana.perDamage", "1 PP mỗi N sát thương nhận", "num", 0, 500, 1, "Luật của web (10), mọi nguồn sát thương. 0 = tắt."],
	["mana.perAttack", "PP mỗi đòn trúng (vai trò không ghi)", "num", 0, 50, 0.5, "Chỉ khi đòn đánh thường trúng (không bị né / chặn). Web: 5 mỗi đòn."],
	["mana.perHit", "PP mỗi lần bị đánh (vai trò không ghi)", "num", 0, 50, 0.5, "Chỉ đòn đánh thường (kể cả đòn được skill cường hoá); sát thương của skill không tính; đòn bị chặn hoàn toàn (Protect...) không tính. Web: 0."],
	["mana.roles.tank", "Tank (Đỡ đòn)", "keys", MANA_KEYS, 0, 300, 1, ROLE_HINT],
	["mana.roles.marksman", "Marksman (Xạ thủ)", "keys", MANA_KEYS, 0, 300, 1, ROLE_HINT],
	["mana.roles.caster", "Caster (Pháp sư)", "keys", MANA_KEYS, 0, 300, 1, ROLE_HINT],
	["mana.roles.support", "Support (Hỗ trợ)", "keys", MANA_KEYS, 0, 300, 1, ROLE_HINT],
	["mana.roles.fighter", "Fighter (Đấu sĩ)", "keys", MANA_KEYS, 0, 300, 1, ROLE_HINT],
	["mana.roles.assassin", "Assassin (Sát thủ)", "keys", MANA_KEYS, 0, 300, 1, ROLE_HINT],
	["#", "Phần thưởng và người chơi"],
	["endless.rewardInterval", "Bầy hoang dã thưởng item mỗi N stage", "num", 1, 100, 1, ""],
	["endless.fullItemRewardsStage", "Thưởng item ghép từ stage", "num", 1, 500, 1, ""],
	["startLife", "Máu đầu run", "num", 1, 999, 1, ""],
	["startGold", "Vàng đầu run", "num", 0, 999, 1, ""],
	["lifeLossScale", "Nhân máu mất khi thua / hoà", "num", 0, 10, 0.1, ""],
	["goldPerWave", "Vàng mỗi wave (chưa tính lãi)", "num", 0, 100, 1, "Nhận đầu mỗi stage, cộng lãi 1 / 10 vàng (tối đa 5). Web: 5."],
	["benchSize", "Số ô hàng chờ", "num", 1, 24, 1, "Web: 8. Mỗi 8 ô là một hàng trên sàn (camera lùi lại cho vừa)."],
	["benchStack", "Số con giống nhau mỗi ô hàng chờ", "num", 1, 3, 1, "Web: 1. Ô chứa tới N bản sao cùng một Pokémon (chỉ hiện con đầu kèm số đếm); đủ 3 bản thì gộp tiến hoá như thường."],
	["cheats", "Bảng cheat (F1 trong trận)", "bool", "Để playtest / cân bằng: vàng, cấp, máu, thắng trận, nhảy stage, thêm Pokémon / item, đổi vùng."],
]

var _tpl: Dictionary = {}    ## data/wave_templates.json, every template / slot with all its keys
var _diff: Dictionary = {}   ## data/difficulty.json
var _selected := -1          ## template shown in the form
var _scope := "base"         ## difficulty form: "base" or a level id
var _dirty := false
var _types: Array = []

var _status: Label
var _pages: Array[Control] = []
var _tabs: Array[Button] = []
var _template_list: ItemList
var _form: VBoxContainer
var _preview_stage: SpinBox
var _preview_seed: SpinBox
var _preview_level: OptionButton
var _preview_force: CheckBox
var _preview_title: Label
var _preview_grid: GridContainer
var _preview_info: RichTextLabel
var _schedule: ItemList
var _scope_list: ItemList
var _active_level: OptionButton
var _diff_form: VBoxContainer
var _diff_table: RichTextLabel
var _picker: PopupPanel
var _picker_title: Label
var _picker_filter: LineEdit
var _picker_list: ItemList
var _picker_entries: Array = []  ## [id, label, lower-case search text]
var _picker_icon := Callable()
var _picker_pick := Callable()
var _rebuild_queued := false


func _ready() -> void:
	get_tree().auto_accept_quit = false
	# the tool edits every wave: nothing is locked by the player's Battle Pass here, and the previews
	# use every Pokémon of the game whatever the season picked in the menu
	Progression.override_level = 9999
	Seasons.set_current(Seasons.FULL)
	GameData.apply_progression()
	theme = load("res://scenes/ui/theme/ui_theme.tres")
	_types = GameData.config.get("synergyThresholds", {}).keys()
	_load()
	_build()
	_refresh_template_list()
	_select_template(0 if not _templates().is_empty() else -1)
	_refresh_scope_list()
	_show_page(0)
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "shot":
		_take_shots.call_deferred(args[1])


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


#region data
func _load() -> void:
	WaveTemplates.load_data()
	Difficulty.load_data()
	_tpl = _whole_numbers(WaveTemplates.data().duplicate(true))
	var full: Array = []
	for raw in _tpl.get("templates", []):
		if not raw is Dictionary:
			continue
		var t: Dictionary = _whole_numbers(WaveTemplates.with_defaults(raw))
		var slots: Array = []
		for s in t.slots:
			if s is Dictionary:
				slots.append(_whole_numbers(WaveTemplates.slot_with_defaults(s)))
		t.slots = slots
		full.append(t)
	_tpl.templates = full
	_diff = _whole_numbers(Difficulty.data().duplicate(true))
	if not _diff.get("base") is Dictionary:
		_diff["base"] = {}
	if not _diff.get("levels") is Dictionary:
		_diff["levels"] = {}
	# the editor works on these dictionaries: the waves previewed are the edited ones
	WaveTemplates.load_data(_tpl)
	Difficulty.load_data(_diff)
	_dirty = false


func _templates() -> Array:
	return _tpl.templates


func _template() -> Dictionary:
	return _templates()[_selected] if _selected >= 0 and _selected < _templates().size() else {}


## Something changed: the waves are rebuilt, the preview follows.
func _changed(rebuild_form := false) -> void:
	_dirty = true
	Difficulty.load_data(_diff)
	EndlessWaves.clear_cache()
	_refresh_status()
	_refresh_template_list()
	if rebuild_form:
		_queue_rebuild()
	_refresh_preview()
	_refresh_diff_table()


## The templates file as it is written: only the keys that differ from the defaults.
func _templates_to_save() -> Dictionary:
	var out := _tpl.duplicate(true)
	var compact: Array = []
	for t in out.templates:
		var slim := {}
		for key in t:
			if key in ["id", "name", "stages", "slots"] or not _same(t[key], WaveTemplates.TEMPLATE_DEFAULTS.get(key)):
				slim[key] = t[key]
		var slots: Array = []
		for s in t.slots:
			var slim_slot := {}
			for key in s:
				if key == "count" or not _same(s[key], WaveTemplates.SLOT_DEFAULTS.get(key)):
					slim_slot[key] = s[key]
			slots.append(slim_slot)
		slim.slots = slots
		compact.append(slim)
	out.templates = compact
	return out


func _save() -> void:
	var ok := _write(WaveTemplates.PATH, _templates_to_save()) and _write(Difficulty.PATH, _diff)
	_dirty = not ok
	_refresh_status("Đã lưu data/wave_templates.json và data/difficulty.json" if ok else "LỖI: không ghi được file")


func _write(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(_json(_whole_numbers(value), 0) + "\n")
	file.close()
	return true


## JSON like the hand-written files: one-space indent, short arrays / objects on one line.
static func _json(value: Variant, depth: int) -> String:
	var inline := JSON.stringify(value, "", false)
	if not (value is Dictionary or value is Array) or value.is_empty():
		return inline
	var spaced := inline.replace("\":", "\": ").replace(",\"", ", \"").replace("},{", "}, {")
	var nested := false
	for v in (value.values() if value is Dictionary else value):
		nested = nested or ((v is Dictionary or v is Array) and not v.is_empty() and (v is Dictionary or v[0] is Dictionary or v[0] is Array))
	var numbers: bool = value is Array and value.all(func(v: Variant) -> bool: return v is int or v is float)
	if depth > 0 and (numbers or (not nested and spaced.length() <= 110) or (nested and spaced.length() <= 90 and depth > 2)):
		return _spaced_inline(value)
	var pad := " ".repeat(depth + 1)
	var lines: Array[String] = []
	if value is Dictionary:
		for key in value:
			lines.append("%s%s: %s" % [pad, JSON.stringify(str(key)), _json(value[key], depth + 1)])
		return "{\n%s\n%s}" % [",\n".join(lines), " ".repeat(depth)]
	for v in value:
		lines.append(pad + _json(v, depth + 1))
	return "[\n%s\n%s]" % [",\n".join(lines), " ".repeat(depth)]


static func _spaced_inline(value: Variant) -> String:
	if value is Dictionary:
		var parts: Array[String] = []
		for key in value:
			parts.append("%s: %s" % [JSON.stringify(str(key)), _spaced_inline(value[key])])
		return "{%s}" % ", ".join(parts)
	if value is Array:
		var parts: Array[String] = []
		for v in value:
			parts.append(_spaced_inline(v))
		return "[%s]" % ", ".join(parts)
	return JSON.stringify(value)


## JSON numbers are floats in Godot: 3.0 -> 3, so that the files stay tidy.
static func _whole_numbers(value: Variant) -> Variant:
	if value is float and is_equal_approx(value, roundf(value)) and absf(value) < 1e9:
		return int(roundf(value))
	if value is Array:
		var out: Array = []
		for v in value:
			out.append(_whole_numbers(v))
		return out
	if value is Dictionary:
		var out := {}
		for key in value:
			out[key] = _whole_numbers(value[key])
		return out
	return value


static func _same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(_whole_numbers(a)) == JSON.stringify(_whole_numbers(b))
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
	var title := UiStyle.label("Wave editor", 26, UiStyle.GOLD)
	top.add_child(title)
	var group := ButtonGroup.new()
	for i in 2:
		var tab := Button.new()
		tab.text = ["Template wave", "Độ khó"][i]
		tab.toggle_mode = true
		tab.button_group = group
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(170, 40)
		tab.pressed.connect(_show_page.bind(i))
		top.add_child(tab)
		_tabs.append(tab)
	_status = UiStyle.label("", 16, UiStyle.TEXT_DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.clip_text = true
	_status.mouse_filter = Control.MOUSE_FILTER_STOP
	top.add_child(_status)
	top.add_child(_button("Đọc lại file", func() -> void:
		_load()
		_selected = -1
		_refresh_template_list()
		_select_template(0 if not _templates().is_empty() else -1)
		_refresh_scope_list()
		_refresh_status("Đã đọc lại file"), "Bỏ mọi thay đổi chưa lưu."))
	var save := _button("Lưu  (Ctrl+S)", _save)
	save.custom_minimum_size = Vector2(170, 40)
	top.add_child(save)

	var templates_page := HBoxContainer.new()
	templates_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	templates_page.add_theme_constant_override("separation", 10)
	root.add_child(templates_page)
	_pages.append(templates_page)
	_build_template_list(templates_page)
	var form_panel := _panel(templates_page)
	form_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	form_panel.add_child(scroll)
	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 8)
	scroll.add_child(_form)
	_build_preview(templates_page)

	var diff_page := HBoxContainer.new()
	diff_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diff_page.add_theme_constant_override("separation", 10)
	root.add_child(diff_page)
	_pages.append(diff_page)
	_build_difficulty_page(diff_page)
	_build_picker()
	_refresh_status()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_S and event.ctrl_pressed:
		_save()


func _show_page(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
		_tabs[i].set_pressed_no_signal(i == index)
	if index == 1:
		_build_diff_form()
		_refresh_diff_table()
	else:
		_refresh_preview()


func _refresh_status(message := "") -> void:
	var problems := WaveTemplates.problems()
	var text := message
	if text == "":
		text = "● Chưa lưu" if _dirty else "Đã lưu"
	if not problems.is_empty():
		text = "⚠ %s   |   %s" % [problems[0] + (" (+%d)" % (problems.size() - 1) if problems.size() > 1 else ""), text]
	_status.text = text
	_status.tooltip_text = "\n".join(problems)
	_status.add_theme_color_override("font_color", UiStyle.RED if not problems.is_empty() else UiStyle.GOLD if _dirty else UiStyle.TEXT_DIM)


func _panel(parent: Control, min_width := 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = &"HudPanel"
	p.custom_minimum_size.x = min_width
	parent.add_child(p)
	return p


func _button(text: String, on_press: Callable, hint := "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = hint
	b.pressed.connect(on_press)
	return b


func _spin(value: float, min_value: float, max_value: float, step: float, on_change: Callable, suffix := "") -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_value
	s.max_value = max_value
	s.step = step
	s.value = value
	s.suffix = suffix
	s.custom_minimum_size.x = 96.0
	s.select_all_on_focus = true
	s.value_changed.connect(on_change)
	return s


func _check(text: String, value: bool, on_change: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = value
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(on_change)
	return c


func _option(labels: Array, selected: int, on_change: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	for i in labels.size():
		o.add_item(String(labels[i]), i)
	o.select(clampi(selected, 0, maxi(labels.size() - 1, 0)))
	o.item_selected.connect(on_change)
	return o


func _line(text: String, on_change: Callable, width := 260.0) -> LineEdit:
	var l := LineEdit.new()
	l.text = text
	l.custom_minimum_size.x = width
	l.text_changed.connect(on_change)
	return l


func _section(parent: Control, text: String) -> void:
	var l := UiStyle.label(text, 19, UiStyle.GOLD)
	l.custom_minimum_size.y = 34.0
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	parent.add_child(l)
	parent.add_child(HSeparator.new())


## A labelled row; returns the container the controls go into (it wraps when narrow).
func _field(parent: Control, text: String, hint := "", label_width := LABEL_WIDTH) -> HFlowContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := UiStyle.label(text, 16)
	l.custom_minimum_size.x = label_width
	l.tooltip_text = hint
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(l)
	var flow := _flow()
	row.add_child(flow)
	parent.add_child(row)
	return flow


func _flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	return flow


func _hint(text: String) -> Label:
	var l := UiStyle.label(text, 14, UiStyle.TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
#endregion


#region template list
func _build_template_list(parent: Control) -> void:
	var panel := _panel(parent, 270.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(UiStyle.label("Template", 19, UiStyle.GOLD))
	_template_list = ItemList.new()
	_template_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_template_list.focus_mode = Control.FOCUS_NONE
	_template_list.item_selected.connect(_select_template)
	v.add_child(_template_list)
	var buttons := HBoxContainer.new()
	v.add_child(buttons)
	buttons.add_child(_button("＋ Mới", _add_template))
	buttons.add_child(_button("Nhân bản", _duplicate_template))
	buttons.add_child(_button("Xoá", _delete_template))
	buttons.add_child(_button("▲", _move_template.bind(-1)))
	buttons.add_child(_button("▼", _move_template.bind(1)))
	var weight := _field(v, "Trọng số bầy hoang dã",
		"Khi vài template hợp với stage, game bốc thăm theo trọng số giữa chúng và bầy hoang dã mặc định. 0 = luôn dùng template.", 160.0)
	weight.add_child(_spin(float(_tpl.get("wildWeight", 10)), 0, 1000, 1, func(value: float) -> void:
		_tpl["wildWeight"] = int(value)
		_changed()))


func _refresh_template_list() -> void:
	var list := _templates()
	while _template_list.item_count > list.size():
		_template_list.remove_item(_template_list.item_count - 1)
	for i in list.size():
		var t: Dictionary = list[i]
		var last := int(t.stages[1])
		var text := "%s   [%d–%s]  w%d" % [t.id if String(t.name) == "" else t.name, int(t.stages[0]),
			"∞" if last <= 0 else str(last), int(t.weight)]
		if i >= _template_list.item_count:
			_template_list.add_item(text)
		else:
			_template_list.set_item_text(i, text)
		_template_list.set_item_custom_fg_color(i, UiStyle.TEXT if t.enabled else UiStyle.TEXT_DIM)
	if _selected >= 0 and _selected < _template_list.item_count:
		_template_list.select(_selected)


func _select_template(index: int) -> void:
	_selected = index if index < _templates().size() else -1
	if _selected >= 0:
		_template_list.select(_selected)
	_build_form()
	_refresh_preview()


func _unique_id(base: String) -> String:
	var ids := _templates().map(func(t: Dictionary) -> String: return String(t.id))
	var id := base
	var n := 2
	while ids.has(id):
		id = "%s_%d" % [base, n]
		n += 1
	return id


func _add_template() -> void:
	var t := WaveTemplates.with_defaults({"id": _unique_id("wave"), "name": "", "stages": [int(_preview_stage.value), 0],
		"slots": [WaveTemplates.slot_with_defaults({"count": 3})]})
	_templates().append(t)
	_changed()
	_select_template(_templates().size() - 1)


func _duplicate_template() -> void:
	if _template().is_empty():
		return
	var copy: Dictionary = _template().duplicate(true)
	copy.id = _unique_id(String(copy.id))
	_templates().insert(_selected + 1, copy)
	_changed()
	_select_template(_selected + 1)


func _delete_template() -> void:
	if _template().is_empty():
		return
	_templates().remove_at(_selected)
	_changed()
	_select_template(mini(_selected, _templates().size() - 1))


func _move_template(by: int) -> void:
	var to := _selected + by
	if _template().is_empty() or to < 0 or to >= _templates().size():
		return
	var t: Dictionary = _templates()[_selected]
	_templates().remove_at(_selected)
	_templates().insert(to, t)
	_selected = to
	_changed()
#endregion


#region template form
func _queue_rebuild() -> void:
	if not _rebuild_queued:
		_rebuild_queued = true
		_rebuild_form.call_deferred()


func _rebuild_form() -> void:
	_rebuild_queued = false
	_build_form()


func _build_form() -> void:
	for c in _form.get_children():
		_form.remove_child(c)
		c.queue_free()
	var t := _template()
	if t.is_empty():
		_form.add_child(_hint("Chưa có template nào: bấm “＋ Mới”. Không có template thì mọi stage dùng bầy hoang dã / boss mặc định."))
		return
	_section(_form, "Chung")
	var row := _field(_form, "Id / tên hiển thị", "Id phải khác nhau. Tên hiện trên thanh stage (để trống = “Bầy <con đầu đàn> hoang dã”).")
	row.add_child(_line(String(t.id), func(text: String) -> void:
		t.id = text.strip_edges()
		_changed(), 180.0))
	row.add_child(_line(String(t.name), func(text: String) -> void:
		t.name = text
		_changed()))
	row.add_child(_check("Bật", t.enabled, func(on: bool) -> void:
		t.enabled = on
		_changed()))
	row = _field(_form, "Stage: từ / đến / mỗi N", "Đến 0 = không giới hạn. Mỗi N > 0: chỉ các stage cách stage đầu một bội của N.")
	row.add_child(_spin(float(t.stages[0]), 1, 999, 1, func(value: float) -> void:
		t.stages[0] = int(value)
		_changed()))
	row.add_child(_spin(float(t.stages[1]), 0, 999, 1, func(value: float) -> void:
		t.stages[1] = int(value)
		_changed()))
	row.add_child(_spin(float(t.every), 0, 100, 1, func(value: float) -> void:
		t.every = int(value)
		_changed()))
	row = _field(_form, "Trọng số", "Bốc thăm với các template khác và bầy hoang dã (xem “Trọng số bầy hoang dã”).")
	row.add_child(_spin(float(t.weight), 0, 1000, 1, func(value: float) -> void:
		t.weight = int(value)
		_changed()))
	var always := _check("Luôn dùng", t.always, func(on: bool) -> void:
		t.always = on
		_changed())
	always.tooltip_text = "Thắng mọi lần bốc thăm ở các stage hợp lệ."
	row.add_child(always)
	var replace_boss := _check("Thay được boss", t.replaceBoss, func(on: bool) -> void:
		t.replaceBoss = on
		_changed())
	replace_boss.tooltip_text = "Ở stage boss (1, 2, 3, 9, 14, 19... và boss quay lại) chỉ template có dấu này mới được dùng, và nó thay boss."
	row.add_child(replace_boss)
	row = _field(_form, "Độ khó dùng template", "Không tích ô nào = mọi độ khó.")
	for id in Difficulty.levels():
		var level: String = id
		row.add_child(_check(level, t.levels.has(level), func(on: bool) -> void:
			t.levels.erase(level)
			if on:
				t.levels.append(level)
			_changed()))
	row = _field(_form, "Hệ của wave / thưởng")
	row.add_child(_option(SYNERGY_MODE_LABELS, SYNERGY_MODES.find(String(t.synergies)), func(i: int) -> void:
		t.synergies = SYNERGY_MODES[i]
		_changed()))
	row.add_child(_option(REWARD_LABELS, REWARDS.find(String(t.reward)), func(i: int) -> void:
		t.reward = REWARDS[i]
		_changed()))
	var stage_items := _check("Thêm item theo luật stage", t.stageItems, func(on: bool) -> void:
		t.stageItems = on
		_changed())
	stage_items.tooltip_text = "Ngoài item của từng slot, wave còn nhận số item mà một bầy hoang dã ở stage đó cầm."
	row.add_child(stage_items)

	_section(_form, "Chỉ số của wave")
	row = _field(_form, "Nhân chỉ số gốc (%)", "100% = giữ nguyên; nhân thêm với hệ số của độ khó.")
	for stat in SCALE_STATS:
		row.add_child(_stat_spin(stat, float(t.statScale.get(stat, 1.0)) * 100.0, 5, 5000, 5, func(value: float) -> void:
			if is_equal_approx(value, 100.0):
				t.statScale.erase(stat)
			else:
				t.statScale[stat] = snappedf(value / 100.0, 0.01)
			_changed()))
	row = _field(_form, "Cộng thẳng", "Cộng thêm vào phần cộng dồn theo stage của độ khó.")
	for stat in FLAT_STATS:
		row.add_child(_stat_spin(stat, float(t.statBoosts.get(stat, 0.0)), -1000, 10000, 1, func(value: float) -> void:
			if value == 0.0:
				t.statBoosts.erase(stat)
			else:
				t.statBoosts[stat] = _whole_numbers(value)
			_changed()))
	row = _field(_form, "Điểm hệ cộng thêm", "Cộng vào số đếm hệ của wave (vd 4 con Lửa + 2 điểm = mốc 6).")
	for type in t.bonusSynergies.keys():
		var bonus_type: String = type
		row.add_child(_type_chip(bonus_type, func() -> void:
			t.bonusSynergies.erase(bonus_type)
			_changed(true)))
		row.add_child(_spin(float(t.bonusSynergies[bonus_type]), 1, 9, 1, func(value: float) -> void:
			t.bonusSynergies[bonus_type] = int(value)
			_changed()))
	row.add_child(_type_menu("＋ hệ", func(type: String) -> void:
		if not t.bonusSynergies.has(type):
			t.bonusSynergies[type] = 1
		_changed(true)))

	_section(_form, "Slot  (mỗi slot = một nhóm Pokémon)")
	for i in t.slots.size():
		_form.add_child(_slot_panel(t, i))
	var add := _button("＋ Thêm slot", func() -> void:
		t.slots.append(WaveTemplates.slot_with_defaults({}))
		_changed(true))
	add.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_form.add_child(add)


## SpinBox with the stat name in front ("HP 120").
func _stat_spin(stat: String, value: float, min_value: float, max_value: float, step: float, on_change: Callable) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var l := UiStyle.label(stat, 13, UiStyle.STAT_COLORS.get(stat, UiStyle.TEXT))
	box.add_child(l)
	var s := _spin(value, min_value, max_value, step, on_change)
	s.custom_minimum_size.x = 76.0
	box.add_child(s)
	return box


## A synergy as a small button (icon + name); pressing it removes it.
func _type_chip(type: String, on_remove: Callable) -> Button:
	var b := Button.new()
	b.icon = GameData.type_icon(type)
	b.text = GameData.synergy_name(type) + " ✕"
	b.expand_icon = true
	b.custom_minimum_size = Vector2(0, 32)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_constant_override("icon_max_width", 22)
	b.add_theme_font_size_override("font_size", 14)
	b.tooltip_text = "Bấm để bỏ"
	b.pressed.connect(on_remove)
	return b


func _type_menu(text: String, on_pick: Callable) -> MenuButton:
	var m := MenuButton.new()
	m.text = text
	m.flat = false
	m.focus_mode = Control.FOCUS_NONE
	var popup := m.get_popup()
	for i in _types.size():
		popup.add_icon_item(GameData.type_icon(_types[i]), GameData.synergy_name(_types[i]), i)
		popup.set_item_icon_max_width(i, 22)
	popup.id_pressed.connect(func(id: int) -> void: on_pick.call(String(_types[id])))
	return m


func _slot_panel(t: Dictionary, index: int) -> Control:
	var s: Dictionary = t.slots[index]
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"BoxPanel"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var head := _flow()
	v.add_child(head)
	head.add_child(UiStyle.label("#%d" % (index + 1), 18, UiStyle.GOLD))
	head.add_child(_button("⧉", func() -> void:
		t.slots.insert(index + 1, s.duplicate(true))
		_changed(true), "Nhân bản slot"))
	head.add_child(_button("▲", func() -> void:
		if index > 0:
			t.slots.remove_at(index)
			t.slots.insert(index - 1, s)
			_changed(true), "Đưa slot lên"))
	head.add_child(_button("✕", func() -> void:
		t.slots.remove_at(index)
		_changed(true), "Xoá slot"))
	head.add_child(UiStyle.label("Số con", 15))
	head.add_child(_spin(float(s.count), 1, EndlessWaves.MAX_UNITS, 1, func(value: float) -> void:
		s.count = int(value)
		_changed()))
	var given := String(s.pkm) != ""
	var pick := Button.new()
	pick.focus_mode = Control.FOCUS_NONE
	pick.custom_minimum_size = Vector2(230, 44)
	pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	pick.expand_icon = true
	pick.add_theme_constant_override("icon_max_width", 40)
	pick.text = GameData.display_name(String(s.pkm)) if given else "Ngẫu nhiên (theo hệ / độ hiếm)"
	pick.icon = GameData.portrait(String(s.pkm)) if given else null
	pick.tooltip_text = "Chọn một Pokémon cố định cho slot này."
	pick.pressed.connect(func() -> void:
		_open_pokemon_picker(func(pkm: String) -> void:
			s.pkm = pkm
			_changed(true)))
	head.add_child(pick)
	if given:
		head.add_child(_button("→ ngẫu nhiên", func() -> void:
			s.pkm = ""
			_changed(true)))
	head.add_child(UiStyle.label("Bậc", 15))
	var stars := _option(STAR_LABELS, int(s.stars), func(i: int) -> void:
		s.stars = i
		_changed())
	stars.tooltip_text = "Số sao. “Theo stage” = tỉ lệ 2★ / 3★ của độ khó. Pokémon cố định đã ở bậc cao hơn thì giữ nguyên."
	head.add_child(stars)
	var rows := _option(ROW_LABELS, ROW_VALUES.find(int(s.row)), func(i: int) -> void:
		s.row = ROW_VALUES[i]
		_changed())
	rows.tooltip_text = "Hàng đứng. Hàng trước là hàng sát đội người chơi."
	head.add_child(rows)

	if not given:
		var filters := _flow()
		v.add_child(filters)
		filters.add_child(UiStyle.label("Hệ", 15))
		for type in s.types:
			var slot_type: String = type
			filters.add_child(_type_chip(slot_type, func() -> void:
				s.types.erase(slot_type)
				_changed(true)))
		if s.types.is_empty():
			filters.add_child(UiStyle.label("bất kỳ", 14, UiStyle.TEXT_DIM))
		filters.add_child(_type_menu("＋ hệ", func(type: String) -> void:
			if not s.types.has(type):
				s.types.append(type)
			_changed(true)))
		filters.add_child(VSeparator.new())
		filters.add_child(UiStyle.label("Độ hiếm", 15))
		var rarity := MenuButton.new()
		rarity.flat = false
		rarity.focus_mode = Control.FOCUS_NONE
		rarity.text = ", ".join(s.rarity.map(func(r: String) -> String: return r.capitalize())) if not s.rarity.is_empty() \
			else "Theo stage"
		rarity.tooltip_text = "Không tích = theo tỉ lệ shop của stage (như bầy hoang dã). Unique / Legendary lấy từ danh sách đề xuất của portal."
		var popup := rarity.get_popup()
		popup.hide_on_checkable_item_selection = false
		for r in RARITIES.size():
			popup.add_check_item(RARITIES[r].capitalize(), r)
			popup.set_item_checked(r, s.rarity.has(RARITIES[r]))
		popup.id_pressed.connect(func(id: int) -> void:
			if s.rarity.has(RARITIES[id]):
				s.rarity.erase(RARITIES[id])
			else:
				s.rarity.append(RARITIES[id])
			popup.set_item_checked(id, s.rarity.has(RARITIES[id]))
			_changed())
		popup.popup_hide.connect(_queue_rebuild)
		filters.add_child(rarity)
		var fits := WaveTemplates.candidates(s, int(_preview_stage.value)).size()
		filters.add_child(UiStyle.label("→ %d Pokémon phù hợp ở stage %d" % [fits, int(_preview_stage.value)], 14,
			UiStyle.RED if fits == 0 else UiStyle.TEXT_DIM))

	var items := _flow()
	v.add_child(items)
	items.add_child(UiStyle.label("Item", 15))
	for item in s.items:
		var slot_item: String = item
		var chip := Button.new()
		chip.icon = GameData.item_icon(slot_item)
		chip.expand_icon = true
		chip.custom_minimum_size = Vector2(40, 40)
		chip.focus_mode = Control.FOCUS_NONE
		chip.tooltip_text = "%s — bấm để bỏ" % GameData.item_name(slot_item)
		chip.pressed.connect(func() -> void:
			s.items.erase(slot_item)
			_changed(true))
		items.add_child(chip)
	if s.items.size() < BattleUnit.MAX_ITEMS:
		items.add_child(_button("＋ item", func() -> void:
			_open_item_picker(func(item: String) -> void:
				if not s.items.has(item) and s.items.size() < BattleUnit.MAX_ITEMS:
					s.items.append(item)
				_changed(true))))
	items.add_child(VSeparator.new())
	items.add_child(UiStyle.label("＋ ngẫu nhiên", 15))
	items.add_child(_spin(float(s.randomItems), 0, BattleUnit.MAX_ITEMS, 1, func(value: float) -> void:
		s.randomItems = int(value)
		_changed()))
	items.add_child(_option(ITEM_POOL_LABELS, ITEM_POOLS.find(String(s.itemPool)), func(i: int) -> void:
		s.itemPool = ITEM_POOLS[i]
		_changed()))
	items.add_child(UiStyle.label("(mỗi con tối đa %d item)" % BattleUnit.MAX_ITEMS, 13, UiStyle.TEXT_DIM))
	return panel
#endregion


#region pickers
func _build_picker() -> void:
	_picker = PopupPanel.new()
	_picker.theme = theme
	add_child(_picker)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(620, 640)
	_picker.add_child(v)
	_picker_title = UiStyle.label("", 18, UiStyle.GOLD)
	v.add_child(_picker_title)
	_picker_filter = LineEdit.new()
	_picker_filter.placeholder_text = "Gõ để lọc (tên, hệ, độ hiếm...)"
	_picker_filter.text_changed.connect(func(_text: String) -> void: _fill_picker())
	_picker_filter.text_submitted.connect(func(_text: String) -> void:
		if _picker_list.item_count > 0:
			_picked(0))
	v.add_child(_picker_filter)
	_picker_list = ItemList.new()
	_picker_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picker_list.fixed_icon_size = Vector2i(36, 36)
	_picker_list.item_clicked.connect(func(index: int, _pos: Vector2, button: int) -> void:
		if button == MOUSE_BUTTON_LEFT:
			_picked(index))
	v.add_child(_picker_list)


func _open_picker(title: String, entries: Array, icon: Callable, on_pick: Callable) -> void:
	_picker_title.text = title
	_picker_entries = entries
	_picker_icon = icon
	_picker_pick = on_pick
	_picker_filter.text = ""
	_fill_picker()
	_picker.popup_centered()
	_picker_filter.grab_focus()


func _fill_picker() -> void:
	_picker_list.clear()
	var words := _picker_filter.text.to_lower().split(" ", false)
	for entry in _picker_entries:
		var search: String = entry[2]
		var fits := true
		for w in words:
			fits = fits and search.contains(w)
		if not fits:
			continue
		var i := _picker_list.add_item(String(entry[1]), _picker_icon.call(String(entry[0])))
		_picker_list.set_item_metadata(i, entry[0])
		if _picker_list.item_count >= PICKER_LIMIT:
			_picker_list.add_item("… gõ thêm để lọc", null, false)
			break


func _picked(index: int) -> void:
	var id = _picker_list.get_item_metadata(index)
	if not id is String:
		return
	_picker.hide()
	_picker_pick.call(id)


func _open_pokemon_picker(on_pick: Callable) -> void:
	var entries: Array = []
	for pkm in GameData.pokemon:
		if not GameData.is_available(pkm):
			continue
		var data := GameData.get_pokemon(pkm)
		var types: Array = data.get("types", []).map(func(t: String) -> String: return GameData.synergy_name(t))
		var label := "%s   %s★  %s   %s" % [GameData.display_name(pkm), int(data.get("stars", 1)), String(data.get("rarity", "")).capitalize(),
			" / ".join(types)]
		entries.append([pkm, label, (label + " " + pkm + " " + " ".join(data.get("types", []))).to_lower()])
	entries.sort_custom(func(a: Array, b: Array) -> bool: return String(a[1]) < String(b[1]))
	_open_picker("Chọn Pokémon", entries, func(pkm: String) -> Texture2D: return GameData.portrait(pkm), on_pick)


func _open_item_picker(on_pick: Callable) -> void:
	var entries: Array = []
	var order: Array = GameData.item_components + GameData.full_items
	for item in GameData.items:
		if not order.has(item):
			order.append(item)
	for item in order:
		if not ResourceLoader.exists(GameData.item_icon_path(item)):
			continue
		var kind := "mảnh ghép" if GameData.is_component(item) else "item ghép" if GameData.full_items.has(item) else "khác"
		var label := "%s   (%s)" % [GameData.item_name(item), kind]
		entries.append([item, label, (label + " " + String(item)).to_lower()])
	_open_picker("Chọn item", entries, func(item: String) -> Texture2D: return GameData.item_icon(item), on_pick)
#endregion


#region preview
func _build_preview(parent: Control) -> void:
	var panel := _panel(parent, 540.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(UiStyle.label("Xem trước", 19, UiStyle.GOLD))
	var row := _flow()
	v.add_child(row)
	row.add_child(UiStyle.label("Stage", 15))
	_preview_stage = _spin(12, 1, 999, 1, func(_value: float) -> void:
		_queue_rebuild() # "N Pokémon fit" of the slots depends on the stage
		_refresh_preview())
	row.add_child(_preview_stage)
	row.add_child(UiStyle.label("Seed", 15))
	_preview_seed = _spin(1, 1, 999999, 1, func(_value: float) -> void: _refresh_preview())
	row.add_child(_preview_seed)
	row.add_child(_button("🎲", func() -> void: _preview_seed.value = randi_range(1, 999999), "Seed khác = lần tung khác"))
	row.add_child(UiStyle.label("Độ khó", 15))
	_preview_level = OptionButton.new()
	_preview_level.focus_mode = Control.FOCUS_NONE
	_preview_level.item_selected.connect(func(i: int) -> void:
		Difficulty.set_level(_preview_level.get_item_text(i))
		_refresh_preview()
		_refresh_diff_table())
	row.add_child(_preview_level)
	_preview_force = _check("Luôn xem template đang chọn", true, func(_on: bool) -> void: _refresh_preview())
	_preview_force.tooltip_text = "Tắt: xem đúng wave mà game sẽ dựng ở stage + seed này (có thể là bầy hoang dã, boss hoặc template khác)."
	v.add_child(_preview_force)
	_preview_title = UiStyle.label("", 18)
	v.add_child(_preview_title)
	v.add_child(UiStyle.label("hàng sau", 12, UiStyle.TEXT_DIM))
	_preview_grid = GridContainer.new()
	_preview_grid.columns = BattleBoard.WIDTH
	_preview_grid.add_theme_constant_override("h_separation", 4)
	_preview_grid.add_theme_constant_override("v_separation", 4)
	v.add_child(_preview_grid)
	v.add_child(UiStyle.label("hàng trước  ↓  đội người chơi", 12, UiStyle.TEXT_DIM))
	_preview_info = UiStyle.rich("", 14, 500.0)
	v.add_child(_preview_info)
	v.add_child(UiStyle.label("Lịch 60 stage của seed này (bấm để xem)", 15, UiStyle.GOLD))
	_schedule = ItemList.new()
	_schedule.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_schedule.focus_mode = Control.FOCUS_NONE
	_schedule.max_columns = 2
	_schedule.same_column_width = true
	_schedule.add_theme_font_size_override("font_size", 14)
	_schedule.item_selected.connect(func(i: int) -> void:
		_preview_force.set_pressed_no_signal(false)
		_preview_stage.value = i + 1
		_refresh_preview())
	v.add_child(_schedule)
	_refresh_level_options()


func _refresh_level_options() -> void:
	_preview_level.clear()
	var ids := Difficulty.levels()
	for i in ids.size():
		_preview_level.add_item(ids[i], i)
		if ids[i] == Difficulty.level:
			_preview_level.select(i)


func _preview_wave() -> Dictionary:
	var stage := int(_preview_stage.value)
	var run_seed := int(_preview_seed.value)
	var t := _template()
	if _preview_force.button_pressed and not t.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([run_seed, stage, String(t.id)])
		var built := WaveTemplates.build(t, stage, rng)
		return EndlessWaves._apply_difficulty(built, stage, "template") if not built.is_empty() else {}
	return EndlessWaves.get_stage(stage, run_seed)


func _refresh_preview() -> void:
	if _preview_grid == null or not _pages[0].visible:
		return
	for c in _preview_grid.get_children():
		_preview_grid.remove_child(c)
		c.queue_free()
	var wave := _preview_wave()
	var board: Array = wave.get("board", [])
	var held: Array = wave.get("items", [])
	var by_cell := {}
	for i in board.size():
		by_cell[Vector2i(int(board[i][1]), int(board[i][2]))] = i
	for y in [0, 1, 2, 3]:
		for x in BattleBoard.WIDTH:
			var index: int = by_cell.get(Vector2i(x, y), -1)
			_preview_grid.add_child(_preview_cell(board[index][0] if index >= 0 else "",
				held[index] if index >= 0 and index < held.size() else []))
	if wave.is_empty():
		_preview_title.text = "Không dựng được wave: không slot nào có Pokémon phù hợp"
		_preview_title.add_theme_color_override("font_color", UiStyle.RED)
		_preview_info.text = ""
	else:
		var kind: String = {"boss": "boss", "wild": "bầy hoang dã", "template": "template"}.get(wave.get("kind", ""), "")
		_preview_title.text = "%s   (%s, %d con)" % [EndlessWaves.display_name(wave), kind, board.size()]
		_preview_title.add_theme_color_override("font_color", UiStyle.TEXT)
		_preview_info.text = GameText.format(_wave_text(wave))
	# which wave each stage gets with this seed
	var sel_stage := int(_preview_stage.value)
	_schedule.clear()
	for stage in range(1, 61):
		var w := EndlessWaves.get_stage(stage, int(_preview_seed.value))
		var i := _schedule.add_item("%d  %s" % [stage, EndlessWaves.display_name(w)])
		match String(w.get("kind", "")):
			"boss": _schedule.set_item_custom_fg_color(i, UiStyle.RED)
			"template": _schedule.set_item_custom_fg_color(i, UiStyle.GOLD)
	if sel_stage <= _schedule.item_count:
		_schedule.select(sel_stage - 1)


func _preview_cell(pkm: String, items: Array) -> Control:
	var cell := PanelContainer.new()
	cell.theme_type_variation = &"PortraitCell"
	cell.custom_minimum_size = Vector2(58, 84)
	if pkm == "":
		cell.modulate.a = 0.35
		return cell
	var data := GameData.get_pokemon(pkm)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_child(v)
	var portrait := UiStyle.icon_rect(GameData.portrait(pkm), 40, CanvasItem.TEXTURE_FILTER_NEAREST)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(portrait)
	var stars := UiStyle.label("★".repeat(int(data.get("stars", 1))), 12, GameData.RARITY_COLORS.get(data.get("rarity", ""), UiStyle.TEXT))
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stars)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 1)
	row.custom_minimum_size.y = 16.0
	for item in items:
		row.add_child(UiStyle.icon_rect(GameData.item_icon(item), 16))
	v.add_child(row)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.tooltip_text = "%s  %s★  %s\n%s%s" % [GameData.display_name(pkm), int(data.get("stars", 1)), String(data.get("rarity", "")).capitalize(),
		" / ".join(data.get("types", []).map(func(t: String) -> String: return GameData.synergy_name(t))),
		"\n" + ", ".join(items.map(func(i: String) -> String: return GameData.item_name(i))) if not items.is_empty() else ""]
	return cell


## Synergies, stats, items and reward of a wave (web keywords: GameText turns them into icons).
func _wave_text(wave: Dictionary) -> String:
	var lines: Array[String] = []
	var was := wave.get("synergies", false) as bool
	wave["synergies"] = true # show the counts even when the wave does not activate them
	var counts := EndlessWaves.synergy_counts(wave)
	wave["synergies"] = was
	var active: Array[String] = []
	var inactive: Array[String] = []
	for type in Synergies.sort(counts):
		var tier := Synergies.tier(type, counts[type])
		if tier > 0:
			active.append("%s %d (mốc %d)" % [type, counts[type], tier])
		else:
			inactive.append("%s %d" % [type, counts[type]])
	if not was:
		lines.append("[color=#9aa]Hệ: wave này KHÔNG kích hệ (độ khó / template tắt). Nếu bật: %s[/color]" % (", ".join(active) if not active.is_empty() else "không mốc nào"))
	else:
		lines.append("Hệ đang kích: %s" % (", ".join(active) if not active.is_empty() else "không mốc nào"))
		if not inactive.is_empty():
			lines.append("[color=#9aa]Chưa đủ mốc: %s[/color]" % ", ".join(inactive))
	var stats: Array[String] = []
	var scale: Dictionary = wave.get("statScale", {})
	for stat in scale:
		stats.append("%s ×%s" % [stat, String.num(float(scale[stat]), 2)])
	var boosts: Dictionary = wave.get("statBoosts", {})
	for stat in boosts:
		if float(boosts[stat]) != 0.0:
			stats.append("%s %s%s" % [stat, "+" if float(boosts[stat]) > 0.0 else "", String.num(float(boosts[stat]), 1).trim_suffix(".0")])
	lines.append("Chỉ số: %s" % (", ".join(stats) if not stats.is_empty() else "không đổi"))
	var held := 0
	for list in wave.get("items", []):
		held += list.size()
	var reward = wave.get("reward")
	var reward_text := "không"
	if reward is Dictionary:
		if reward.get("pool") is Array:
			reward_text = "theo bảng boss"
		else:
			reward_text = ("chọn 1 trong 3 " if reward.get("choice", false) else "1 ") + ("item ghép" if reward.get("pool") == "full" else "mảnh ghép")
	lines.append("Item đang cầm: %d   •   Thưởng khi thắng: %s" % [held, reward_text])
	return "\n".join(lines)
#endregion


#region difficulty page
func _build_difficulty_page(parent: Control) -> void:
	var left := _panel(parent, 250.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	left.add_child(v)
	v.add_child(UiStyle.label("Mức độ khó", 19, UiStyle.GOLD))
	_scope_list = ItemList.new()
	_scope_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scope_list.focus_mode = Control.FOCUS_NONE
	_scope_list.item_selected.connect(func(i: int) -> void:
		_scope = String(_scope_list.get_item_metadata(i))
		if _scope != "base":
			Difficulty.set_level(_scope)
			_refresh_level_options()
		_build_diff_form()
		_refresh_diff_table())
	v.add_child(_scope_list)
	var buttons := HBoxContainer.new()
	v.add_child(buttons)
	buttons.add_child(_button("＋ Mức mới", func() -> void:
		var id := "level"
		var n := 2
		while _diff.levels.has(id):
			id = "level_%d" % n
			n += 1
		_diff.levels[id] = {"label": id.capitalize(), "desc": ""}
		_scope = id
		_changed()
		Difficulty.set_level(id)
		_refresh_scope_list()))
	buttons.add_child(_button("Xoá mức", func() -> void:
		if _scope == "base" or _diff.levels.size() <= 1:
			return
		_diff.levels.erase(_scope)
		_scope = "base"
		_changed()
		_refresh_scope_list()))
	var active := _field(v, "Mặc định", "Mức dùng khi người chơi chưa chọn ở menu chính.", 80.0)
	_active_level = OptionButton.new()
	_active_level.focus_mode = Control.FOCUS_NONE
	_active_level.item_selected.connect(func(i: int) -> void:
		_diff["active"] = _active_level.get_item_text(i)
		_changed())
	active.add_child(_active_level)
	v.add_child(_hint("“base” = giá trị chung. Mỗi mức chỉ ghi đè những dòng được tích; dòng không tích lấy theo base (hoặc số của bản web)."))

	var middle := _panel(parent)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(scroll)
	_diff_form = VBoxContainer.new()
	_diff_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diff_form.add_theme_constant_override("separation", 6)
	scroll.add_child(_diff_form)

	var right := _panel(parent, 470.0)
	var rv := VBoxContainer.new()
	right.add_child(rv)
	rv.add_child(UiStyle.label("Wave theo stage (mức đang chọn)", 19, UiStyle.GOLD))
	_diff_table = UiStyle.rich("", 14, 440.0)
	rv.add_child(_diff_table)


func _refresh_scope_list() -> void:
	_scope_list.clear()
	var ids: Array = ["base"]
	ids.append_array(Difficulty.levels())
	if not ids.has(_scope):
		_scope = "base"
	for id in ids:
		var i := _scope_list.add_item("base (chung)" if id == "base" else "%s — %s" % [id, _diff.levels[id].get("label", id)])
		_scope_list.set_item_metadata(i, id)
		if id == _scope:
			_scope_list.select(i)
	_active_level.clear()
	for id in Difficulty.levels():
		_active_level.add_item(id)
		if id == String(_diff.get("active", "")):
			_active_level.select(_active_level.item_count - 1)
	_refresh_level_options()
	_build_diff_form()
	_refresh_diff_table()


func _scope_dict() -> Dictionary:
	return _diff.base if _scope == "base" else _diff.levels[_scope]


## Value a path has without the scope's own override: base over the web numbers.
func _inherited(path: String) -> Variant:
	var defaults := Difficulty.merged({"endless": GameData.config.get("endless", {})}, _diff.base)
	return _get_path(defaults, path)


static func _get_path(d: Dictionary, path: String) -> Variant:
	var value: Variant = d
	for key in path.split("."):
		if not value is Dictionary or not value.has(key):
			return null
		value = value[key]
	return value


static func _set_path(d: Dictionary, path: String, value: Variant) -> void:
	var keys := path.split(".")
	for i in keys.size() - 1:
		if not d.get(keys[i]) is Dictionary:
			d[keys[i]] = {}
		d = d[keys[i]]
	d[keys[keys.size() - 1]] = value


## Removes the value at `path` (any depth), then the dictionaries it leaves empty.
static func _erase_path(d: Dictionary, path: String) -> void:
	var keys := path.split(".")
	var chain: Array[Dictionary] = [d]
	for i in keys.size() - 1:
		var next = chain[i].get(keys[i])
		if not next is Dictionary:
			return
		chain.append(next)
	chain[keys.size() - 1].erase(keys[keys.size() - 1])
	for i in range(keys.size() - 2, -1, -1):
		if chain[i + 1].is_empty():
			chain[i].erase(keys[i])


func _build_diff_form() -> void:
	if _diff_form == null:
		return
	for c in _diff_form.get_children():
		_diff_form.remove_child(c)
		c.queue_free()
	var scope := _scope_dict()
	var is_level := _scope != "base"
	if is_level:
		_section(_diff_form, "Mức “%s”" % _scope)
		var row := _field(_diff_form, "Tên / mô tả", "Tên hiện ở menu chính (dịch trong data/i18n/ui.json nếu muốn).")
		row.add_child(_line(String(scope.get("label", _scope)), func(text: String) -> void:
			scope["label"] = text
			_changed(), 160.0))
		var desc := _line(String(scope.get("desc", "")), func(text: String) -> void:
			scope["desc"] = text
			_changed())
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc)
	for entry in SCHEMA:
		if entry[0] == "#":
			_section(_diff_form, String(entry[1]))
			continue
		_diff_form.add_child(_diff_row(entry, scope, is_level))


func _diff_row(entry: Array, scope: Dictionary, is_level: bool) -> Control:
	var path: String = entry[0]
	var kind: String = entry[2]
	var own: Variant = _get_path(scope, path)
	var overridden := own != null
	var value: Variant = own if overridden else _inherited(path)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var controls := _flow()
	var write := func(v: Variant) -> void:
		_set_path(scope, path, _whole_numbers(v))
		_changed()
	if is_level:
		var toggle := _check("", overridden, func(on: bool) -> void:
			if on:
				_set_path(scope, path, _whole_numbers(_inherited(path)) if _inherited(path) != null else _diff_default(entry))
			else:
				_erase_path(scope, path)
			_changed()
			_build_diff_form.call_deferred())
		toggle.tooltip_text = "Tích = mức này ghi đè giá trị của base."
		row.add_child(toggle)
	var label := UiStyle.label(String(entry[1]), 16, UiStyle.TEXT if overridden or not is_level else UiStyle.TEXT_DIM)
	label.custom_minimum_size.x = LABEL_WIDTH + 70.0
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.tooltip_text = "%s\n(%s)" % [entry[entry.size() - 1], path]
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(label)
	row.add_child(controls)
	if value == null:
		value = _diff_default(entry)
	match kind:
		"num":
			controls.add_child(_spin(float(value), entry[3], entry[4], entry[5], write))
		"bool":
			controls.add_child(_check("", bool(value), write))
		"range":
			var pair: Array = (value as Array).duplicate() if value is Array and value.size() == 2 else [0, 0]
			for i in 2:
				controls.add_child(_spin(float(pair[i]), entry[3], entry[4], 1, func(v: float) -> void:
					pair[i] = int(v)
					write.call(pair.duplicate())))
		"keys":
			var numbers: Dictionary = (value as Dictionary).duplicate() if value is Dictionary else {}
			for pair in entry[3]:
				var key: String = pair[0]
				controls.add_child(_stat_spin(String(pair[1]), float(numbers.get(key, 0.0)), entry[4], entry[5], entry[6],
					func(v: float) -> void:
						numbers[key] = v
						write.call(numbers.duplicate())))
		"stats":
			var stats: Dictionary = (value as Dictionary).duplicate() if value is Dictionary else {}
			var neutral := 1.0 if path == "statScale" else 0.0
			for stat in entry[3]:
				controls.add_child(_stat_spin(stat, float(stats.get(stat, neutral)), entry[4], entry[5], entry[6], func(v: float) -> void:
					stats[stat] = v
					write.call(stats.duplicate())))
	if is_level and not overridden:
		for c in controls.find_children("*", "SpinBox", true, false):
			c.editable = false
		for c in controls.find_children("*", "CheckBox", true, false):
			c.disabled = true
		controls.modulate.a = 0.6
	var hint := String(entry[entry.size() - 1])
	if hint != "":
		controls.add_child(UiStyle.label(hint, 13, UiStyle.TEXT_DIM))
	return row


func _diff_default(entry: Array) -> Variant:
	match String(entry[2]):
		"bool": return false
		"range": return [1, 2]
		"stats", "keys": return {}
	return entry[3]


func _refresh_diff_table() -> void:
	if _diff_table == null or not _pages[1].visible:
		return
	var level := Difficulty.level
	var endless := Difficulty.endless()
	var text := "Mức: [b]%s[/b] — %s\n\n" % [level, Difficulty.description(level)]
	text += "[table=8][cell][b]Stage[/b][/cell][cell][b]Con[/b][/cell][cell][b]2★[/b][/cell][cell][b]3★[/b][/cell][cell][b]Item[/b][/cell][cell][b]×HP/ATK[/b][/cell][cell][b]+HP/ATK[/b][/cell][cell][b]Hệ[/b][/cell]"
	for stage in [1, 5, 10, 15, 20, 25, 30, 40, 50, 60, 80, 100]:
		var three := EndlessWaves._progress(stage, endless.threeStarsStages)
		var two := (1.0 - three) * EndlessWaves._progress(stage, endless.twoStarsStages)
		var units := EndlessWaves.stage_units(stage)
		var items := 0
		if stage >= int(endless.firstItemStage):
			items = mini(units * BattleUnit.MAX_ITEMS, 1 + (stage - int(endless.firstItemStage)) / maxi(int(endless.stagesPerItem), 1))
		var item_text := "-" if items == 0 else "%d %s" % [items, "ghép" if EndlessWaves.stage_item_kind(stage) == "full" else "mảnh"]
		var scale := Difficulty.enemy_scale(stage)
		var boosts := EndlessWaves._add_boosts(EndlessWaves.scaling_boosts(stage), Difficulty.value("statBoosts", {}))
		var cells := [str(stage), str(units), "%d%%" % roundi(two * 100.0), "%d%%" % roundi(three * 100.0), item_text,
			"%s/%s" % [String.num(float(scale.get("HP", 1.0)), 2), String.num(float(scale.get("ATK", 1.0)), 2)],
			"%d/%d" % [int(boosts.get("HP", 0)), int(boosts.get("ATK", 0))],
			"có" if Difficulty.enemy_synergies(stage, false) else "-"]
		for c in cells:
			text += "[cell]%s  [/cell]" % c
	text += "[/table]\n\n"
	text += "Boss: %s, %s.\n" % ["cầm item" if Difficulty.value("bossItems", false) else "không cầm item",
		"kích hệ" if Difficulty.value("enemySynergies", false) and Difficulty.value("bossSynergies", true) else "không kích hệ"]
	text += "Người chơi: %d máu, %d vàng, máu mất × %s, %d vàng mỗi wave + lãi, %d ô hàng chờ%s.\n" % [
		int(Difficulty.value("startLife", 100)), int(Difficulty.value("startGold", 5)),
		String.num(float(Difficulty.value("lifeLossScale", 1.0)), 2), int(Difficulty.value("goldPerWave", PlayerState.BASE_INCOME)),
		int(Difficulty.value("benchSize", PlayerState.BENCH_SIZE)), ", cheat bật" if Difficulty.value("cheats", false) else ""]
	var mana := Difficulty.mana()
	text += "Mana: %s PP/giây, %s\n" % [Tooltips.plain_number(float(mana.perSecond)),
		"1 PP mỗi %s sát thương" % Tooltips.plain_number(float(mana.perDamage)) if float(mana.perDamage) > 0.0 else "không tính theo sát thương"]
	for role in UnitRoles.ROLES:
		var rules := Difficulty.role_mana(role)
		text += "    %s: %s mỗi đòn trúng, %s mỗi lần bị đánh (PP tối đa: riêng từng Pokémon)\n" % [UnitRoles.info(role).name,
			Tooltips.plain_number(float(rules.perAttack)), Tooltips.plain_number(float(rules.perHit))]
	text += "\n[color=#9aa]“Con / 2★ / 3★ / Item” là của bầy hoang dã; template wave tự quy định đội hình của nó. Cột 2★ và 3★ là xác suất mỗi con.[/color]"
	_diff_table.text = text
#endregion


## `-- shot <dir>`: a picture of each tab, then quits.
func _take_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for i in 2:
		_show_page(i)
		if i == 1 and _scope_list.item_count > 1:
			_scope_list.select(_scope_list.item_count - 1)
			_scope_list.item_selected.emit(_scope_list.item_count - 1)
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("wave_editor_%d.png" % i))
	get_tree().quit()
