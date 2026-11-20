extends InteractBus

## Autoload "SignalBus" — signal RIÊNG của game này.
##
## 4 signal generic của hệ tương tác (mouse_clicked, character_arrived_at_interactable,
## interaction_menu_requested, interaction_menu_closed) nằm ở InteractBus trong
## addons/loc_toolkit/core/interact_bus.gd — kế thừa nên vẫn dùng bình thường qua
## SignalBus.xxx, đừng khai lại ở đây.

# Bắn khi nhân vật thu được item từ 1 object (gộp theo item_id). UI layer nghe
# và hiện hiệu ứng "+N bay lên" tại world_position của object. Xem collect_effect.gd.
signal item_collected (item_id: String, amount: int, world_position: Vector3)

# Bắn khi 1 food được TIÊU THỤ (ăn/uống) ở bàn ăn — ProductionQueueComponent ở
# CONSUME mode. nutrition: need_name -> điểm hồi. CharacterNeeds nghe & cộng chỉ số.
signal food_consumed (nutrition: Dictionary)

#region Sự kiện random (EventManager)
# Có event mới xuất hiện ở cửa. UI banner nghe để báo người chơi tới cửa.
signal event_started (event_id: String)
# Event kết thúc (đã nhận/từ chối/NPC bỏ đi). outcome: "accepted"/"declined"/"left".
signal event_ended (event_id: String, outcome: String)
# Trạng thái deal (giá/xúc xắc) của event mua vừa đổi -> popup refresh.
signal event_deal_updated (event_id: String)
#endregion
