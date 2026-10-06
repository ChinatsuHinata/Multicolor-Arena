extends Control
## Persistent screen-space shortcuts, independent of the rebuilt battle HUD.
const SKULL=preload("res://assets/zone_skull.svg")
const BLACK_HOLE=preload("res://assets/zone_black_hole.svg")
const HoldRing=preload("res://scripts/card_hold_ring.gd")
const HOLD_MS=1000
const SIZE_SCALE=1.5
const DRAG_THRESHOLD=12.0
const KEYS=["own_grave","enemy_grave","exile"]
const TITLES=["我方墓地","敌方墓地","除外区"]
const COLORS=[Color("#ef5350"),Color("#4b9df5"),Color.WHITE]
var view
var buttons={}
var bounds=Rect2()
var edge=0.0
var active_key=""
var finger=-1
var origin=Vector2.ZERO
var start_position=Vector2.ZERO
var offset=Vector2.ZERO
var started_ms=0
var held=false
var moved=false
var canceled=false
var ring: Control

func build(owner_view):
 view=owner_view;name="AndroidZoneShortcuts"
 z_index=110
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for i in range(KEYS.size()):
  var key=KEYS[i]
  var button=Button.new();button.name=key;button.tooltip_text=TITLES[i]+"\n长按 1 秒后拖动"
  button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
  button.pressed.connect(func():activate(key))
  add_child(button);buttons[key]=button
  var icon=TextureRect.new();icon.name="ZoneIcon"
  icon.texture=BLACK_HOLE if key=="exile" else SKULL
  icon.self_modulate=COLORS[i]
  icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
  if key=="enemy_grave":icon.rotation=PI
  button.add_child(icon)
 refresh_layout()

func can_show() -> bool:
 return view.is_android and view.host.android_zone_shortcuts and not (view.modal or view.history_open or view.debug_open or view.observing or view.host.menu_popup_open() or view.inspection.visible)

func can_use() -> bool:
 return can_show() and not view.revealing() and not view.table.combat_animating

func refresh_visibility():
 visible=can_show()
 var popup=view.android_choice_panel
 for button in buttons.values():
  button.disabled=not can_use()
  button.visible=not is_instance_valid(popup) or not popup.is_visible_in_tree() or not button.get_global_rect().intersects(popup.get_global_rect())
 if not active_key.is_empty() and not buttons[active_key].visible:cancel()
 if not can_use():cancel()

func refresh_layout():
 var safe: Rect2=view.host.ui_metrics.safe
 var new_edge: float=view.host.ui_metrics.hit*SIZE_SCALE
 var resized=safe!=bounds or not is_equal_approx(new_edge,edge)
 if resized:cancel()
 bounds=safe;edge=new_edge
 for i in range(KEYS.size()):
  var key=KEYS[i];var button: Button=buttons[key]
  button.custom_minimum_size=Vector2(edge,edge);button.size=Vector2(edge,edge)
  if key!=active_key:
   button.position=clamp_position(default_position(key))
   var saved=view.host.android_zone_shortcut_positions.get(key)
   if saved is Array and saved.size()==2 and (saved[0] is float or saved[0] is int) and (saved[1] is float or saved[1] is int):
    if is_finite(float(saved[0])) and is_finite(float(saved[1])):
     button.position=bounds.position+Vector2(saved[0],saved[1]).clamp(Vector2.ZERO,Vector2.ONE)*travel()
  if not resized:continue
  var icon: TextureRect=button.get_node("ZoneIcon")
  icon.size=Vector2.ONE*edge*0.6;icon.position=(button.size-icon.size)*0.5;icon.pivot_offset=icon.size*0.5
  for state in ["normal","hover","pressed","disabled","focus"]:
   button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
 refresh_visibility()

func default_position(key: String) -> Vector2:
 var gap: float=view.host.ui_metrics.gap
 if key=="own_grave":return Vector2(view.HAND.end.x-edge,view.HAND.position.y-edge-gap)
 if key=="enemy_grave":
  var corner=Vector2(view.STAGE.get_center().x-35,view.responsive.log_rect.end.y+8)
  for card in view.enemy_nodes.values():
   if is_instance_valid(card):
    var target: Vector2=card.get_meta("target",card.position)
    corner=corner.min(target)
  return corner-Vector2(edge+gap,0)
 return Vector2(view.HAND.end.x-edge*2-gap,view.HAND.position.y-edge)

func position_exile():
 if active_key=="exile" or view.host.android_zone_shortcut_positions.has("exile"):return
 buttons.exile.position=clamp_position(default_position("exile"))

func travel() -> Vector2:
 return (bounds.size-Vector2.ONE*edge).max(Vector2.ZERO)

func clamp_position(at: Vector2) -> Vector2:
 return at.clamp(bounds.position,bounds.position+travel())

func cancel():
 if is_instance_valid(ring):ring.queue_free()
 ring=null
 if not active_key.is_empty() and moved:buttons[active_key].position=start_position
 active_key="";finger=-1;held=false;moved=false;canceled=false

func begin_hold_ring(at: Vector2):
 var key=active_key;var stamp=started_ms
 ring=HoldRing.new();ring.duration=HOLD_MS/1000.0
 ring.radius=maxf(24,view.host.ui_metrics.hit*0.35)
 ring.valid=func():return active_key==key and started_ms==stamp and not canceled and can_use()
 view.ui.add_child(ring)
 ring.position=view.ui.get_global_transform().affine_inverse()*at
 ring.completed.connect(func():held=true;ring=null)

func activate(key: String):
 if not can_use():return
 var who=view.local_seat if key!="enemy_grave" else 1-view.local_seat
 view.browse_zone(who,"exile" if key=="exile" else "grave")
 refresh_visibility()

func button_at(at: Vector2) -> String:
 # These controls draw above the rebuilt HUD. Tree-order surface picking can
 # otherwise let an invisible HUD panel swallow the enlarged touch target.
 for i in range(KEYS.size()-1,-1,-1):
  var key=KEYS[i];var button: Button=buttons[key]
  if button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(at):return key
 return ""

func handle(event: InputEvent) -> bool:
 if not (event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventMouseMotion):return false
 if (event is InputEventMouseButton or event is InputEventMouseMotion) and finger>=0:
  view.get_viewport().set_input_as_handled();return true
 if (event is InputEventMouseButton or event is InputEventMouseMotion) and Time.get_ticks_msec()<view.suppress_touch_mouse_until:
  if event.position.distance_to(view.suppress_touch_mouse_point)<28:
   view.get_viewport().set_input_as_handled();return true
 var touch=event is InputEventScreenTouch or event is InputEventScreenDrag
 var index=event.index if touch else -1
 var press=event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT
 var release=event is InputEventScreenTouch and not event.pressed or event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT
 var at=make_input_local(event).position
 if active_key.is_empty():
  if not press or not can_use():return false
  var key=button_at(event.position)
  if key.is_empty():return false
  active_key=key;finger=index;origin=at
  start_position=buttons[key].position;offset=at-start_position
  started_ms=Time.get_ticks_msec();held=false;moved=false;canceled=false
  begin_hold_ring(event.position)
 elif index!=finger:
  if press:
   # Android can deliver the emulated mouse press before its native touch.
   # Hand that same hold to the finger instead of treating it as a second one.
   if touch and finger==-1 and button_at(event.position)==active_key:finger=index
   else:cancel()
  else:return false
 elif release:
  var key=active_key;var was_held=held;var was_moved=moved
  var aborted=canceled or event is InputEventScreenTouch and event.canceled
  var tapped=not was_held and Time.get_ticks_msec()-started_ms<HOLD_MS and not aborted and buttons[key].get_global_rect().has_point(event.position)
  var final_position: Vector2=buttons[key].position
  cancel()
  if was_moved and not aborted:
   buttons[key].position=final_position
   var ratio=(final_position-bounds.position)/travel().max(Vector2.ONE)
   view.host.set_android_zone_shortcut_position(key,ratio)
  elif tapped:activate(key)
 elif event is InputEventScreenDrag or event is InputEventMouseMotion:
  if event is InputEventMouseMotion and (event.button_mask&MOUSE_BUTTON_MASK_LEFT)==0:
   cancel();return false
  if not held and at.distance_to(origin)>maxf(DRAG_THRESHOLD,view.host.ui_metrics.hit/6.0):
   canceled=true
   if is_instance_valid(ring):ring.queue_free()
   ring=null
  if held:
   buttons[active_key].position=clamp_position(at-offset);moved=true
 if touch:
  view.suppress_touch_mouse_until=Time.get_ticks_msec()+250
  view.suppress_touch_mouse_point=event.position
 view.get_viewport().set_input_as_handled()
 return true

func _process(_delta):
 refresh_visibility()

func _notification(what):
 if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT or what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():cancel()

func _exit_tree():
 cancel()

