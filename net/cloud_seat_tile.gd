extends Button

var session
var slot=0

func _get_drag_data(_position: Vector2) -> Variant:
 if session==null or not session.can_move_cloud_seats():return null
 if slot<1 or slot>session.cloud_seats.size() or str(session.cloud_seats[slot-1]).is_empty():return null
 if slot<=2 and session.room.ready[slot-1]:return null
 var preview=Label.new()
 preview.text=text
 preview.add_theme_font_size_override("font_size",20)
 set_drag_preview(preview)
 return {"from":slot}

func _can_drop_data(_position: Vector2,data: Variant) -> bool:
 if session==null or not session.can_move_cloud_seats() or not data is Dictionary:return false
 var source=int(data.get("from",0))
 if source not in range(1,9) or slot not in range(1,9):return false
 if source<=2 and session.room.ready[source-1]:return false
 if slot<=2 and session.room.ready[slot-1]:return false
 return true

func _drop_data(_position: Vector2,data: Variant):
 session.move_cloud_seat(int(data.get("from",0)),slot)
