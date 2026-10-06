extends Button
## A short click selects, a double click renames, and holding reorders.
const HOLD_SECONDS=0.45
const HOLD_SLOP=12.0
var editor
var step_id=""
var holding=false
var dragged=false
var elapsed=0.0
var origin=Vector2.ZERO
var insertion=-1

func _ready():
 mouse_exited.connect(func():holding=false;insertion=-1;queue_redraw())
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND

func _gui_input(event: InputEvent):
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed and event.double_click:
   holding=false;dragged=true;elapsed=0.0
   accept_event();editor.rename_step_dialog(step_id);return
  holding=event.pressed;elapsed=0.0;origin=event.position
  if event.pressed:dragged=false
 elif event is InputEventMouseMotion and holding and event.position.distance_to(origin)>HOLD_SLOP:
  holding=false

func _process(delta: float):
 if not holding:return
 if not is_visible_in_tree():holding=false;return
 elapsed+=delta
 if elapsed<HOLD_SECONDS:return
 holding=false;dragged=true;set_pressed_no_signal(false)
 editor.begin_order_drag(step_id)

func _get_drag_data(_at: Vector2):
 return null

func _notification(what: int):
 if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
  holding=false;insertion=-1;set_pressed_no_signal(step_id==editor.selected_step);queue_redraw()

func _draw():
 if insertion<0:return
 var y=2.0 if insertion==0 else size.y-2.0
 draw_line(Vector2(2,y),Vector2(size.x-2,y),editor.host.GOLD,3)
