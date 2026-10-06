extends Button
## A continuous mouse/touch hold, cancelled by release, leaving or a blocked action.
signal hold_completed
var hold_seconds=1.0
var allowed: Callable
var holding=false
var progress=0.0
var started_ms=0
var touch_index=-1
var ink=Color("#edc676")

func cancel_hold():
 holding=false;progress=0.0;touch_index=-1
 queue_redraw()

func can_hold() -> bool:
 return is_visible_in_tree() and not disabled and (not allowed.is_valid() or allowed.call())

func _notification(what):
 if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT or what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():cancel_hold()

func _input(event: InputEvent):
 if not is_visible_in_tree():return
 var inside=false
 if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag:
  inside=Rect2(Vector2.ZERO,size).has_point(make_input_local(event).position)
 if event is InputEventScreenTouch:
  if holding and event.index==touch_index:
   if not event.pressed or event.canceled:cancel_hold()
   get_viewport().set_input_as_handled()
  elif event.pressed and inside and not holding and can_hold():
   begin_hold(event.index);get_viewport().set_input_as_handled()
 elif event is InputEventScreenDrag and holding and event.index==touch_index:
  if not inside:cancel_hold()
  get_viewport().set_input_as_handled()
 elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if holding and touch_index==-1:
   if not event.pressed:cancel_hold()
   get_viewport().set_input_as_handled()
  elif event.pressed and inside and not holding and can_hold():
   begin_hold(-1);get_viewport().set_input_as_handled()
 elif event is InputEventMouseMotion and holding and touch_index==-1:
  if not inside:cancel_hold()
  get_viewport().set_input_as_handled()

func begin_hold(index: int):
 holding=true;progress=0.0;started_ms=Time.get_ticks_msec();touch_index=index
 queue_redraw()

func _process(_delta):
 if not holding:return
 if not can_hold():cancel_hold();return
 # Keep the completed circle on screen for one frame before submitting.
 if progress>=1.0:
  holding=false;hold_completed.emit();return
 progress=minf(1.0,float(Time.get_ticks_msec()-started_ms)/(hold_seconds*1000.0))
 queue_redraw()

func _draw():
 var radius=minf(18.0,size.y*0.28)
 var center=Vector2(28,size.y*0.5)
 draw_arc(center,radius,0,TAU,64,Color(ink,0.22),3,true)
 if progress>0:
  draw_arc(center,radius,-PI*0.5,-PI*0.5+TAU*progress,96,ink,3.5,true)
  var tip=center+Vector2.from_angle(-PI*0.5+TAU*progress)*radius
  draw_circle(tip,2.3,ink)
