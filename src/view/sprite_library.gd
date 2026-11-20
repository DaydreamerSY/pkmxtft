class_name SpriteLibrary
extends RefCounted

## Builds SpriteFrames from the PMD sprite atlases exported from the web project
## (assets/pokemons/<index>.png + .json). Cached per sprite index.
##
## Animation names are "<Action>_<dir>", dir = PMD direction 0..7
## (0 DOWN = facing the camera, 4 UP = facing away, see BattleBoard.DIRECTIONS).
## Non-oriented animations (Sleep, Eat...) only have dir 0.
## Frames are trimmed in the atlas; AtlasTexture.margin restores the full frame
## so every frame of an action shares the same centre, like in PMD.
## The Shiny colors are in the same sheet: "shiny" gives where each frame is ([x, y], or the
## whole frame when it differs); get_entry(index, true) builds those frames.

const FPS := 36.0 ## PMD frame durations are in ticks of 1/36 s (animation-manager.ts)
const LOOPING: Array[String] = ["Idle", "Walk", "Sleep", "Charge", "Rotate"]

class Entry:
	extends RefCounted
	var frames: SpriteFrames
	var actions: Dictionary = {} ## action -> true
	var oriented: Dictionary = {} ## action -> true if it has 8 directions
	var feet: Dictionary = {} ## action -> Vector2 ground point, from the frame centre (pixels, y down)
	var ticks: Dictionary = {} ## action -> length of one play in ticks of 1/FPS s (web delays.json "t")
	var height := 32.0 ## pixels from the frame centre to the top of the Idle sprite
	var texture: Texture2D ## the sheet every frame is cut from

	func has_action(action: String) -> bool:
		return actions.has(action)

	func anim_name(action: String, dir: int) -> String:
		return "%s_%d" % [action, dir if oriented.get(action, false) else 0]


static var _cache: Dictionary = {}


static func get_entry(index: String, shiny := false) -> Entry:
	var key := index + ("|shiny" if shiny else "")
	if _cache.has(key):
		return _cache[key]
	var entry := _build(index, shiny)
	_cache[key] = entry
	return entry


static func _build(index: String, shiny := false) -> Entry:
	var entry := Entry.new()
	entry.frames = SpriteFrames.new()
	entry.frames.remove_animation("default")
	var text := FileAccess.get_file_as_string("res://assets/pokemons/%s.json" % index)
	var json = JSON.parse_string(text) if not text.is_empty() else null
	var tex_path := "res://assets/pokemons/%s.png" % index
	if not (json is Dictionary) or not ResourceLoader.exists(tex_path):
		push_warning("SpriteLibrary: no sprite for %s" % index)
		return entry
	var texture: Texture2D = load(tex_path)
	entry.texture = texture
	entry.height = float(json.get("height", 32))
	var anims: Dictionary = json.anims
	var shiny_frames: Dictionary = json.get("shiny", {}) if shiny else {}
	for action in anims:
		var anim: Dictionary = anims[action]
		var durations: Array = anim.get("durations", [])
		var dirs: Dictionary = anim.get("dirs", {})
		if dirs.is_empty():
			continue
		entry.actions[action] = true
		entry.oriented[action] = dirs.size() > 1
		var feet: Array = anim.get("feet", [0, 0])
		entry.feet[action] = Vector2(float(feet[0]), float(feet[1]))
		for dir in dirs:
			var anim_name := "%s_%s" % [action, dir]
			entry.frames.add_animation(anim_name)
			entry.frames.set_animation_speed(anim_name, FPS)
			entry.frames.set_animation_loop(anim_name, LOOPING.has(action))
			var frames: Array = dirs[dir]
			var shiny_dir: Array = shiny_frames.get(action, {}).get(dir, [])
			for i in frames.size():
				var f = frames[i]
				if f == null:
					continue
				if i < shiny_dir.size() and shiny_dir[i] is Array:
					var sf: Array = shiny_dir[i]
					f = sf if sf.size() >= 8 else [sf[0], sf[1], f[2], f[3], f[4], f[5], f[6], f[7]]
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(f[0], f[1], f[2], f[3])
				atlas.margin = Rect2(f[4], f[5], f[6] - f[2], f[7] - f[3])
				atlas.filter_clip = true
				var ticks := float(durations[i]) if i < durations.size() else 4.0
				entry.frames.add_frame(anim_name, atlas, maxf(ticks, 1.0))
			if not entry.ticks.has(action):
				var total := 0.0
				for i in entry.frames.get_frame_count(anim_name):
					total += entry.frames.get_frame_duration(anim_name, i)
				entry.ticks[action] = total
	return entry
