extends Panel
signal preview_requested(id: String)
signal clicked(id: String, zone: String, index: int, right: bool)
signal art_requested(id: String)
signal remove_requested(id: String, zone: String, index: int)
var card_id=""
var source_zone=""
var source_index=-1
var dragged=false
var held=false
var draggable=true
var hold_to_drag=false
var hold_to_remove=false
var tap_action=false
var long_press_enabled=true
var is_android=OS.has_feature("android")
var hold_timer: Timer
var hold_ring: Control
var hold_origin=Vector2.ZERO
var face_texture: Texture2D
var texture_provider: Callable
func _notification(what):
 if is_android and what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:cancel_touch_hold()
func _ready():
 focus_mode=Control.FOCUS_ALL
 focus_entered.connect(queue_redraw)
 focus_exited.connect(queue_redraw)
 if not is_android:mouse_entered.connect(func(): preview_requested.emit(card_id))
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 if is_android and long_press_enabled:
  hold_timer=Timer.new()
  hold_timer.one_shot=true
  hold_timer.wait_time=1.0
  add_child(hold_timer)
func _gui_input(event):
 if is_android and event is InputEventMouseMotion and event.position.distance_to(hold_origin)>12:
  cancel_touch_hold()
 if event is InputEventMouseButton:
  if event.pressed:
   grab_focus()
   dragged=false
   held=false
   if is_android and event.button_index==MOUSE_BUTTON_LEFT:
    hold_origin=event.position
    if long_press_enabled:begin_touch_hold(get_global_transform()*event.position)
  elif is_android:
   var activate=tap_action and not dragged and not held and event.button_index==MOUSE_BUTTON_LEFT
   cancel_touch_hold()
   if activate:held=false;clicked.emit(card_id,source_zone,source_index,false)
  elif not dragged and event.button_index==MOUSE_BUTTON_MIDDLE:
   art_requested.emit(card_id)
   accept_event()
  elif not dragged and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
   clicked.emit(card_id,source_zone,source_index,event.button_index==MOUSE_BUTTON_RIGHT)
func _get_drag_data(_at):
 if not draggable:return null
 dragged=true
 cancel_touch_hold()
 set_drag_preview(drag_picture())
 return drag_data()

func cancel_touch_hold():
 if hold_timer!=null:hold_timer.stop()
 if is_instance_valid(hold_ring):hold_ring.queue_free()
 hold_ring=null
 held=true

func begin_touch_hold(point: Vector2):
 cancel_touch_hold();held=false
 hold_timer.start()
 hold_ring=preload("res://scripts/card_hold_ring.gd").new()
 hold_ring.valid=func():return is_visible_in_tree() and not is_queued_for_deletion() and not dragged and not held
 get_viewport().add_child(hold_ring);hold_ring.position=point
 hold_ring.completed.connect(func():
  held=true;hold_timer.stop()
  clicked.emit(card_id,source_zone,source_index,false))

func drag_data() -> Dictionary:
 return {"card_id":card_id,"source_zone":source_zone,"source_index":source_index}

func drag_picture() -> TextureRect:
 var ghost=TextureRect.new()
 ghost.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 ghost.texture=texture_provider.call() if texture_provider.is_valid() else face_texture
 ghost.custom_minimum_size=Vector2(100,140)
 ghost.size=Vector2(100,140)
 ghost.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 ghost.modulate.a=0.85
 return ghost

func _draw():
 if has_focus():draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),Color("#e8c77e"),false,3)
