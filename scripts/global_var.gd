extends InteractState

## Autoload "GlobalVar" — state toàn cục RIÊNG của game này.
##
## Phần generic nằm ở InteractState trong addons/loc_toolkit/core/interact_state.gd:
##   - dlog() logger có màu theo tag + DEBUG_LOGS + TAG_COLORS
##   - IS_DRAGGING, CURRENT_INTERACTABLE
##   - dọn dẹp khi SceneManager đổi scene
## Kế thừa nên vẫn dùng bình thường qua GlobalVar.xxx — đừng khai lại ở đây.


func _ready() -> void:
	super() # BẮT BUỘC — InteractState._ready() nối log_sink + dọn dẹp khi đổi scene

	# Màu log riêng của game này (base có sẵn "scene", "clickable", "default").
	TAG_COLORS["camera"] = "#648584"
	TAG_COLORS["witch"] = "#03008a"
	TAG_COLORS["floor_cell"] = "#ad0035"
	TAG_COLORS["object_clickable"] = "#a16510"
	TAG_COLORS["door"] = "#7D9D9C"
	TAG_COLORS["maze"] = "#6d4c41"
