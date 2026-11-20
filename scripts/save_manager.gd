extends SaveCore

## Autoload "SaveManager" — phần RIÊNG của game này. Hạ tầng (ghi atomic, .bak,
## migrate, autosave, gom group "Saveable", cache xuyên scene) nằm ở SaveCore trong
## addons/loc_toolkit/core/save_core.gd — đừng chép lại ở đây.
##
## Ở đây chỉ khai state của các AUTOLOAD riêng (không phải node group "Saveable"):
## đồng hồ in-game, kho, và CharacterNeeds trên nhân vật.
##
## Thời gian dùng giờ THỰC (Unix) nên tiến trình trồng/craft vẫn tính khi offline
## — xem production_queue.gd / game_manager.gd / character_needs.gd.

# State của CharacterNeeds — nhân vật là instance trong từng phòng nên phải cache
# giống các node "Saveable" (SaveCore chỉ lo group "Saveable", CharacterNeeds thì
# không ở trong group đó nên xử lý riêng ở đây).
var _needs_state: Dictionary = {}


#region Hook của SaveCore
func _collect_game_state() -> Dictionary:
	_flush_needs()
	var out := {
		"game": GameManager.save_state(),
		"inventory": InventoryManager.save_state(),
	}
	if not _needs_state.is_empty():
		out["needs"] = _needs_state
	return out


func _apply_game_state(data: Dictionary) -> void:
	if data.has("game"):
		GameManager.load_state(data["game"])
	if data.has("inventory"):
		InventoryManager.load_state(data["inventory"])
	if data.has("needs"):
		_needs_state = data["needs"]
#endregion


#region CharacterNeeds đi theo scene (giống cache của SaveCore)
func flush_scene_state() -> void:
	super()
	_flush_needs()


func apply_scene_state() -> void:
	super()
	if _needs_state.is_empty():
		return
	var needs := _find_needs()
	if needs:
		needs.load_state(_needs_state)


func _flush_needs() -> void:
	var needs := _find_needs()
	if needs:
		_needs_state = needs.save_state()


func _find_needs() -> Node:
	var ch := get_tree().get_first_node_in_group("Character")
	return ch.get_node_or_null("CharacterNeeds") if ch else null
#endregion
