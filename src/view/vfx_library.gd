class_name VfxLibrary
extends RefCounted

## Ability / attack / status animations exported from the web game by
## tools/export_pac.bat: assets/vfx/<pack>/<ANIM>.png (grid of equal cells, frames
## centred) + assets/vfx/vfx.json {anims: {"<pack>/<ANIM>": {file, w, h, cols, frames,
## fps, repeat, yoyo}}, attackScale: {"FIRE/range": [x, y]...}}.
## What plays for each ability: data/ability_vfx.json (see its _doc).
## Keys are "<pack>/<ANIM>": "abilities/THUNDER", "attacks/FIRE/range", "status/BURN".

const INDEX := "res://assets/vfx/vfx.json"
const SPECS := "res://data/ability_vfx.json"

## Port status -> [status animation, web y offset from the Pokémon centre (px, down), scale]
## (pokemon-sprite.ts addBurn(), addFreeze()...).
const STATUS := {
	"burn": ["BURN", -30, 2.0], "sleep": ["SLEEP", -30, 2.0], "silence": ["SILENCE", -30, 2.0],
	"fatigue": ["FATIGUE", -10, 2.0], "freeze": ["FREEZE", 0, 2.0], "confusion": ["CONFUSION", -30, 2.0],
	"paralysis": ["PARALYSIS", -30, 2.0], "wound": ["WOUND", -30, 2.0], "poison": ["POISON", -30, 2.0],
	"locked": ["LOCKED", -30, 2.0], "blinded": ["BLINDED", -30, 3.0], "armor_reduction": ["ARMOR_BREAK", -40, 2.0],
	"charm": ["CHARM", -40, 2.0], "flinch": ["FLINCH", -40, 2.0], "curse": ["CURSE", -65, 1.5],
	"protect": ["PROTECT", -30, 2.0], "safeguard": ["SAFEGUARD", -40, 2.0],
}

static var _index: Dictionary = {}
static var _specs: Dictionary = {}
static var _frames: Dictionary = {} ## key -> SpriteFrames (null = missing)
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for pair in [[INDEX, "_index"], [SPECS, "_specs"]]:
		if not FileAccess.file_exists(pair[0]):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(pair[0]))
		if data is Dictionary:
			if pair[1] == "_index":
				_index = data
			else:
				_specs = data


static func has(key: String) -> bool:
	_load()
	return _index.get("anims", {}).has(key)


## {file, w, h, cols, frames, fps, repeat, yoyo} of an animation, {} if not exported.
static func info(key: String) -> Dictionary:
	_load()
	return _index.get("anims", {}).get(key, {})


## Specs played when `ability` is cast (data/ability_vfx.json), [] if none.
static func ability_specs(ability: String) -> Array:
	_load()
	var list = _specs.get(ability)
	return list if list is Array else []


## Scale of a basic attack / hit sprite (web AttackSpriteScale), [1, 1] by default.
static func attack_scale(sprite: String) -> Vector2:
	_load()
	var s = _index.get("attackScale", {}).get(sprite)
	return Vector2(float(s[0]), float(s[1])) if s is Array and s.size() >= 2 else Vector2.ONE


## One animation "default" (frames of the sheet, yoyo unfolded, fps of the web game).
static func frames(key: String) -> SpriteFrames:
	if _frames.has(key):
		return _frames[key]
	var meta := info(key)
	var sf: SpriteFrames = null
	var path := "res://assets/vfx/" + String(meta.get("file", ""))
	if not meta.is_empty() and ResourceLoader.exists(path):
		var sheet: Texture2D = load(path)
		sf = SpriteFrames.new()
		sf.set_animation_speed("default", float(meta.get("fps", 20)))
		sf.set_animation_loop("default", int(meta.get("repeat", 0)) == -1)
		var w := int(meta.w)
		var h := int(meta.h)
		var cols := maxi(int(meta.cols), 1)
		var order: Array[int] = []
		for i in int(meta.frames):
			order.append(i)
		if meta.get("yoyo", false):
			for i in range(int(meta.frames) - 2, 0, -1):
				order.append(i)
		for i in order:
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2((i % cols) * w, (i / cols) * h, w, h)
			sf.add_frame("default", at)
	_frames[key] = sf
	return sf
