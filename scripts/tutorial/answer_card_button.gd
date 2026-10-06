extends Button
## Card answers select on a short click; inspection never selects or submits.
signal selected
signal inspection_requested
var is_android=false
var held=false
var hold_origin=Vector2.ZERO
var hold_ring: Control
var inspection_enabled: Callable

func _ready():
 pressed.connect(func():
  if not held:selected.emit())

func cancel_hold():
 if is_instance_valid(hold_ring):hold_ring.queue_free()
 hold_ring=null

func _exit_tree():cancel_hold()

func begin_hold(point: Vector2):
 if is_instance_valid(hold_ring):return
 held=false;hold_origin=point
 hold_ring=preload("res://scripts/card_hold_ring.gd").new()
 hold_ring.position=point
 hold_ring.valid=func():return is_visible_in_tree() and not held and not is_queued_for_deletion() and (not inspection_enabled.is_valid() or inspection_enabled.call())
 get_viewport().add_child(hold_ring)
 hold_ring.completed.connect(func():held=true;hold_ring=null;inspection_requested.emit())

func _notification(what):
 if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
  held=true;cancel_hold()

func _gui_input(event: InputEvent):
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_RIGHT:
   if not event.pressed:inspection_requested.emit()
   accept_event();return
  if event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed:
    if is_android:begin_hold(get_global_transform()*event.position)
    else:held=false
   else:cancel_hold()

func _input(event: InputEvent):
 if is_android and event is InputEventScreenTouch and event.pressed:
  var area=get_parent().get_parent().get_global_rect()
  if is_visible_in_tree() and get_global_rect().has_point(event.position) and area.has_point(event.position) and (not inspection_enabled.is_valid() or inspection_enabled.call()):begin_hold(event.position)
 elif is_android and event is InputEventScreenDrag and is_instance_valid(hold_ring) and event.position.distance_to(hold_origin)>12:
  held=true;cancel_hold()
 elif is_android and event is InputEventScreenTouch and not event.pressed:cancel_hold()
