extends RefCounted
## Routes a touch drag to the scrollable control beneath its starting point.
## Mouse and short touch gestures remain available to the child controls.
const DRAG_THRESHOLD=12.0
var touch_index=-1
var touch_start=Vector2.ZERO
var touch_last=Vector2.ZERO
var target: Control
var axis=""

func reset():
 touch_index=-1
 target=null
 axis=""

func handle(event: InputEvent,root: Node) -> bool:
 if not (event is InputEventScreenTouch or event is InputEventScreenDrag):return false
 if event is InputEventScreenTouch and event.pressed:
  if touch_index>=0:return false
  var found=_at(root,event.position)
  if not found is Control:return false
  target=found
  touch_index=event.index
  touch_start=event.position
  touch_last=event.position
  axis=""
  return false
 if event.index!=touch_index:return false
 if event is InputEventScreenDrag:
  if not is_instance_valid(target) or not target.is_visible_in_tree():reset();return false
  var movement=event.position-touch_start
  if axis.is_empty():
   if movement.length()<DRAG_THRESHOLD:return false
   var vertical=_can_scroll(target,true)
   var horizontal=_can_scroll(target,false)
   if absf(movement.y)>absf(movement.x) and vertical:axis="vertical"
   elif absf(movement.x)>absf(movement.y) and horizontal:axis="horizontal"
   else:reset();return false
  var delta=touch_last-event.position
  if axis=="vertical":_scroll_bar(target,true).value+=delta.y
  else:_scroll_bar(target,false).value+=delta.x
  touch_last=event.position
  root.get_viewport().set_input_as_handled()
  return true
 var was_dragging=not axis.is_empty()
 reset()
 if was_dragging:root.get_viewport().set_input_as_handled()
 return was_dragging

func _scroll_bar(control: Control,vertical: bool) -> ScrollBar:
 return control.get_v_scroll_bar() if vertical else control.get_h_scroll_bar()

func _can_scroll(control: Control,vertical: bool) -> bool:
 if control is ScrollContainer:
  if vertical and control.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED:return false
  if not vertical and control.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED:return false
 elif control is RichTextLabel:
  if not vertical or not control.scroll_active:return false
 elif control is TextEdit:
  if not vertical:return false
 else:return false
 var bar=_scroll_bar(control,vertical)
 return bar!=null and bar.max_value>bar.page+1.0

func _at(node: Node,point: Vector2) -> Variant:
 if node is CanvasItem and not node.is_visible_in_tree():return null
 var inside=not node is Control or node.get_global_rect().has_point(point)
 if node is Control and node.clip_contents and not inside:return null
 var children=node.get_children()
 children.reverse()
 for child in children:
  var found=_at(child,point)
  if found is Control:return found
  if found==true:
   if inside and node is Control and (_can_scroll(node,true) or _can_scroll(node,false)) and not node.get_meta("android_swipe_handled",false):return node
   return true
 if inside and node is Control:
  if (_can_scroll(node,true) or _can_scroll(node,false)) and not node.get_meta("android_swipe_handled",false):return node
  if node.mouse_filter==Control.MOUSE_FILTER_STOP:return true
 return null
