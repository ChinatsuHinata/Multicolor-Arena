extends Panel
signal preview_requested(id: String)
signal clicked(id: String, zone: String, index: int, right: bool)
signal art_requested(id: String)
var card_id=""
var source_zone=""
var source_index=-1
var dragged=false
var held=false
var draggable=true
var is_android=OS.has_feature("android")
var hold_timer: Timer
var hold_origin=Vector2.ZERO
var face_texture: Texture2D
var texture_provider: Callable
func _ready():
 focus_mode=Control.FOCUS_ALL
 focus_entered.connect(queue_redraw)
 focus_exited.connect(queue_redraw)
 mouse_entered.connect(func(): preview_requested.emit(card_id))
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 if is_android:
  hold_timer=Timer.new()
  hold_timer.one_shot=true
  hold_timer.wait_time=0.55
  hold_timer.timeout.connect(func():
   if not dragged:
    held=true
    art_requested.emit(card_id))
  add_child(hold_timer)
func _gui_input(event):
 if is_android and event is InputEventMouseMotion and hold_timer!=null and not hold_timer.is_stopped() and event.position.distance_to(hold_origin)>12:
  hold_timer.stop()
 if event is InputEventMouseButton:
  if event.pressed:
   grab_focus()
   dragged=false
   held=false
   if is_android and event.button_index==MOUSE_BUTTON_LEFT:
    hold_origin=event.position
    hold_timer.start()
  elif is_android:
   if hold_timer!=null:hold_timer.stop()
   if not dragged and not held and event.button_index==MOUSE_BUTTON_LEFT:
    clicked.emit(card_id,source_zone,source_index,false)
  elif not dragged and event.button_index==MOUSE_BUTTON_MIDDLE:
   art_requested.emit(card_id)
   accept_event()
  elif not dragged and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
   clicked.emit(card_id,source_zone,source_index,event.button_index==MOUSE_BUTTON_RIGHT)
func _get_drag_data(_at):
 if not draggable:return null
 dragged=true
 if hold_timer!=null:hold_timer.stop()
 var ghost=TextureRect.new()
 ghost.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 ghost.texture=texture_provider.call() if texture_provider.is_valid() else face_texture
 ghost.custom_minimum_size=Vector2(100,140)
 ghost.size=Vector2(100,140)
 ghost.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 ghost.modulate.a=0.85
 set_drag_preview(ghost)
 return {"card_id":card_id,"source_zone":source_zone,"source_index":source_index}

func _draw():
 if has_focus():draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),Color("#e8c77e"),false,3)
