extends Node

## Autoload "Audio": music and sound effects on the "Music" and "SFX" buses (created
## here), volumes from Settings (0-100). Files exported from the web game by
## tools/export_pac.bat: assets/music/<name>.ogg (DungeonMusic names) and
## assets/sounds/<name>.ogg (SOUNDS of app/public/src/pages/utils/audio.ts).
## A missing file is skipped silently (the music can be left out of the export).

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const MENU_MUSIC := "Top Menu Theme"
const TOWN_MUSIC := "Treasure Town"
const FADE_TIME := 0.8

var _music: AudioStreamPlayer
var _fading: AudioStreamPlayer
var _music_name := ""
var _sfx_players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {} ## sound path -> AudioStream or null (music is not kept)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	_music = _make_player(MUSIC_BUS)
	_fading = _make_player(MUSIC_BUS)
	for _i in 6:
		_sfx_players.append(_make_player(SFX_BUS))
	# like the web game: every button clicks and ticks on hover
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta(&"_ui_sounds"): # re-added (reparented) buttons keep theirs
		node.set_meta(&"_ui_sounds", true)
		node.pressed.connect(play_sfx.bind("buttonclick"))
		node.mouse_entered.connect(play_sfx.bind("buttonhover", 0.6))


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func apply_volumes(music: float, sfx: float) -> void:
	_set_volume(MUSIC_BUS, music)
	_set_volume(SFX_BUS, sfx)


func _set_volume(bus: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, volume <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.01) / 100.0))


## Plays a music in a loop, cross-fading from the current one (same name: kept).
func play_music(music_name: String) -> void:
	if music_name == _music_name:
		return
	var path := "res://assets/music/%s.ogg" % music_name
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	_music_name = music_name
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var old := _music
	_music = _fading
	_fading = old
	if _fading.playing:
		var fade := create_tween()
		fade.tween_property(_fading, "volume_db", -40.0, FADE_TIME)
		fade.tween_callback(_fading.stop)
	_music.stream = stream
	_music.volume_db = -30.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", 0.0, FADE_TIME)


func current_music() -> String:
	return _music_name


## One-shot sound effect ("buttonclick", "evolutiont2", "finish1"...).
func play_sfx(sound: String, volume := 1.0) -> void:
	var stream := _stream("res://assets/sounds/%s.ogg" % sound)
	if stream == null:
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = linear_to_db(maxf(volume, 0.01))
			p.play()
			return


func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]
