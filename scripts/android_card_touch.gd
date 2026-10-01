extends RefCounted
## Native touch routing keeps card inspection independent of mouse emulation.
const HOLD_SECONDS=0.55
const DRAG_THRESHOLD=12.0
var finger=-1
var origin=Vector2.ZERO
var target: WeakRef
var dragged=false
var held=false
var generation=0

func bind_card(tile: Control,inspect: Callable,activate: Callable=Callable(),long_press: bool=false):
 tile.set_meta("android_card_inspect",inspect)
 tile.set_meta("android_card_activate",activate)
 tile.set_meta("android_card_long_press",long_press)

func surface_at(node: Node,point: Vector2) -> Control:
 if node is CanvasItem and not node.is_visible_in_tree():return null
 var inside=not node is Control or node.get_global_rect().has_point(point)
 if node is Control and node.clip_contents and not inside:return null
 var children=node.get_children();children.reverse()
 for child in children:
  var found=surface_at(child,point)
  if found!=null:return found
 if inside and node is Control and node.mouse_filter!=Control.MOUSE_FILTER_IGNORE:
  if node.has_meta("android_card_inspect") or node.mouse_filter==Control.MOUSE_FILTER_STOP:return node
 return null

func handle(event: InputEvent,view) -> bool:
 if not (event is InputEventScreenTouch or event is InputEventScreenDrag):return false
 if event is InputEventScreenTouch and event.pressed:
  if view.revealing() or view.table.combat_animating:return false
  if finger>=0:
   dragged=true;generation+=1
   view.suppress_touch_mouse_until=Time.get_ticks_msec()+250
   view.suppress_touch_mouse_point=event.position
   view.get_viewport().set_input_as_handled()
   return true
  var tile=surface_at(view.ui,event.position)
  if tile==null or not tile.has_meta("android_card_inspect"):return false
  finger=event.index;origin=event.position;target=weakref(tile)
  dragged=false;held=false;generation+=1
  # Scroll routers need the press even when the card consumes its mouse echo.
  view.touch_battle_choice_scroll(event)
  view.android_swipe_scroll.handle(event,view)
  if tile.get_meta("android_card_long_press",false):hold(view,generation)
 elif event.index!=finger:return false
 elif event is InputEventScreenDrag:
  if event.position.distance_to(origin)>DRAG_THRESHOLD:
   dragged=true;generation+=1
  view.touch_battle_choice_scroll(event)
  view.android_swipe_scroll.handle(event,view)
 else:
  var tile=target.get_ref() if target!=null else null
  var activate=not dragged and not held and not event.canceled and is_instance_valid(tile) and not tile.is_queued_for_deletion() and tile.is_visible_in_tree() and tile.get_global_rect().has_point(event.position)
  view.touch_battle_choice_scroll(event)
  view.android_swipe_scroll.handle(event,view)
  finger=-1;target=null;generation+=1
  if activate:
   # Capture callbacks before the action potentially rebuilds the card row.
   var action: Callable=tile.get_meta("android_card_activate",Callable())
   var inspect: Callable=tile.get_meta("android_card_inspect")
   var long_press=tile.get_meta("android_card_long_press",false)
   if action.is_valid():action.call()
   if not long_press and inspect.is_valid():inspect.call()
 view.suppress_touch_mouse_until=Time.get_ticks_msec()+250
 view.suppress_touch_mouse_point=event.position
 view.get_viewport().set_input_as_handled()
 return true

func hold(view,stamp: int):
 await view.get_tree().create_timer(HOLD_SECONDS).timeout
 if not is_instance_valid(view) or stamp!=generation or finger<0 or dragged:return
 var tile=target.get_ref() if target!=null else null
 if not is_instance_valid(tile) or tile.is_queued_for_deletion() or not tile.is_visible_in_tree():return
 if view.revealing() or view.table.combat_animating or surface_at(view.ui,origin)!=tile:return
 held=true
 var inspect: Callable=tile.get_meta("android_card_inspect")
 if inspect.is_valid():inspect.call()
