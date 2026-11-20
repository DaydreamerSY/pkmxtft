class_name PoolTip
extends VBoxContainer

## Pool of the shop, opened by the "!" button next to the lock: the Pokémon that joined it and
## when (newest first), what joins next, and the regional Pokémon of the current region.
## Pinned tooltip; the portraits open their small card (level + 1). Built in code.

const COLUMNS := 10
const WIDTH := 470.0
const MAX_HEIGHT := 400.0

var player: PlayerState
var level := 0

var _scroll: ScrollContainer
var _content: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = L.t("Shop pool")
	add_child(title)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	_content.custom_minimum_size.x = WIDTH - 14.0
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(WIDTH, 60.0)
	_scroll.add_child(_content)
	add_child(_scroll)
	if player == null:
		return
	_fill()
	_fit.call_deferred()


func _fill() -> void:
	if GameData.season_active:
		_fill_season()
		return
	for i in range(player.pool_news.size() - 1, -1, -1):
		var news: Dictionary = player.pool_news[i]
		var rarity := String(news.get("rarity", ""))
		var color: Color = GameData.RARITY_COLORS.get(rarity, UiStyle.TEXT)
		var head := L.t("Stage %d: picked") % int(news.stage) if news.get("pick", false) \
			else L.t("Stage %d: %s Pokémon joined the shop") % [int(news.stage), GameData.rarity_name(rarity)]
		_section(head, color, news.pokemons)
	# stages that still add Pokémon (config additionalPickStages: one rarity each)
	var stages: Array = GameData.config.get("additionalPickStages", [])
	for i in mini(stages.size(), PlayerState.ADDITIONAL_RARITIES.size()):
		if int(stages[i]) > player.stage:
			_note(L.t("Stage %d: %s Pokémon will join the shop") % [int(stages[i]),
				GameData.rarity_name(PlayerState.ADDITIONAL_RARITIES[i])], UiStyle.TEXT_DIM)
	if player.pool_news.is_empty():
		_note(L.t("Nothing has joined the shop yet."), UiStyle.TEXT_DIM)
	# regional Pokémon of the region (same list as the region tooltip of the HUD)
	if player.map != "town":
		var found: Array[String] = []
		found.assign(player.regional_counts.keys())
		for pkm in player.regional_pokemons:
			if not found.has(pkm):
				found.append(pkm)
		if not found.is_empty():
			_section(L.t("Regional Pokémon: %s") % TownChoice.map_name(player.map), UiStyle.GREEN, found)


## A season (Seasons): its shop never changes; the whole roster, one section per rarity.
func _fill_season() -> void:
	(get_child(0) as Label).text = Seasons.label()
	_note(L.t("The shop of a season is fixed: every Pokémon below is in it from the first stage."), UiStyle.TEXT_DIM)
	var owned := SynergyList.owned_families(player) # a check on the lines the player has
	for rarity in GameData.SHOP_RARITIES:
		var pokemons := player.shop_candidates(rarity)
		if not pokemons.is_empty():
			_section(GameData.rarity_name(rarity), GameData.RARITY_COLORS.get(rarity, UiStyle.TEXT), pokemons, owned)


## A coloured heading and the portraits of `pokemons` under it, all bright with a check; with
## `owned` (family -> true), only the ones of those families.
func _section(head: String, color: Color, pokemons: Array, owned: Variant = null) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var label := UiStyle.label("%s  (%d)" % [head, pokemons.size()], 15, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = WIDTH - 14.0
	box.add_child(label)
	var sorted := pokemons.duplicate()
	sorted.sort_custom(func(a: String, b: String) -> bool:
		var ca := GameData.rarity_cost(GameData.get_pokemon(a).get("rarity", ""))
		var cb := GameData.rarity_cost(GameData.get_pokemon(b).get("rarity", ""))
		return ca < cb or (ca == cb and GameData.display_name(a) < GameData.display_name(b)))
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	for pkm in sorted:
		var member: SynergyMember = UiScenes.make(UiScenes.SYNERGY_MEMBER)
		member.pkm = pkm
		member.owned = owned == null or owned.has(String(GameData.get_pokemon(pkm).get("family", pkm)))
		member.player = player if owned != null else null
		member.level = level + 1
		grid.add_child(member)
	box.add_child(grid)
	_content.add_child(box)


func _note(text: String, color: Color) -> void:
	var label := UiStyle.label(text, 14, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = WIDTH - 14.0
	_content.add_child(label)


## The list is as tall as its content, up to MAX_HEIGHT (then it scrolls); on a low canvas (phones) it
## stays above the shop row, where its "!" button is.
func _fit() -> void:
	var most := MAX_HEIGHT
	if UiScale.is_compact(self):
		most = minf(most, get_viewport_rect().size.y * 0.78 - 140.0)
	_scroll.custom_minimum_size.y = minf(_content.get_combined_minimum_size().y + 4.0, most)
