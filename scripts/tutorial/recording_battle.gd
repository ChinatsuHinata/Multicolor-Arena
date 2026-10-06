extends "res://scripts/duel_view.gd"
var recorder
var owner_editor
var recorded_arrow_index=-1
var recorded_arrow_origin: Rect2
var recorded_arrow_destinations: Array=[]

func _ready():
 var planned=preload("res://scripts/tutorial/recording_arrows.gd").new();planned.name="RecordedFlowArrows";planned.view=self
 planned.mouse_filter=Control.MOUSE_FILTER_IGNORE;planned.z_index=220;add_child(planned)

func _process(delta):
 if engine==null:return
 layout_recording_hand()
 if not engine.presentation_events.is_empty() or revealing():render()
 update_badge_positions()
 var reason=recorder.tick(delta,revealing() or table.is_animating() or not engine.presentation_events.is_empty())
 if not reason.is_empty():host.alert(reason,"重播错误")
 if last_revision!=engine.revision:render()

func layout_recording_hand():
 if not is_instance_valid(opponent_layer):return
 var offset=0.0
 if is_instance_valid(owner_editor.record_tools) and owner_editor.record_tools.is_visible_in_tree():
  var tools_rect=owner_editor.record_tools.get_global_rect()
  var tools_bottom=ui.get_global_transform().affine_inverse()*tools_rect.end
  var hand_top=responsive.log_rect.end.y+8 if is_android else 64.0
  offset=maxf(0,tools_bottom.y+8-hand_top)
 # Move the hand layer so the native card positions and tweens stay intact.
 opponent_layer.position.y=offset

func can_debug_add() -> bool:
 return recorder.can_edit_setup() and debug_mode and network_session==null and local.is_empty() and not history_open and not debug_open and not observing and not modal and not table.is_animating() and debug_drag_uid==0

func can_begin_debug_drag() -> bool:
 return recorder.can_edit_setup() and debug_mode and not observing and not history_open and not modal and local.is_empty() and not table.is_animating()

func render_life(who: int,rect: Rect2):
 super.render_life(who,rect)
 if recorder.editing_setup():life_widgets[who].button.tooltip_text+="\n右键修改初始血量"

func hand_clicked(uid: int):
 if select_setup_card(uid):return
 super.hand_clicked(uid)

func object_clicked(uid: int):
 if select_setup_card(uid):return
 super.object_clicked(uid)

func browse_card_action(card: Dictionary):
 if select_setup_card(int(card.uid)):return
 super.browse_card_action(card)

func leader_zone_clicked(who: int):
 if select_setup_card(int(engine.players[who].leader.uid)):return
 super.leader_zone_clicked(who)

func select_setup_card(uid: int) -> bool:
 if not recorder.editing_setup() or not can_begin_debug_drag():return false
 var card=engine.find_card(uid)
 if card.is_empty():return false
 selection=[] if selection==[uid] else [uid]
 message="";render();update_browser_styles();return true

func _unhandled_key_input(event: InputEvent):
 if event is InputEventKey and event.keycode in [KEY_D,KEY_C,KEY_P]:
  if not event.pressed or event.echo or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:return
  if not recorder.editing_setup() or is_instance_valid(owner_editor.dialog_layer) or host.menu_popup_open():return
  if not is_visible_in_tree() or not is_instance_valid(table):return
  var focus=get_viewport().gui_get_focus_owner()
  if focus is LineEdit or focus is TextEdit:return
  if modal or history_open or observing or revealing() or table.is_animating():return
  if debug_open and not is_instance_valid(browser_panel):return
  if drag_uid!=0 or debug_drag_uid!=0 or unit_drag_uid!=0 or not local.is_empty() or selection.size()!=1:return
  var uid=int(selection[0]);var applied=false
  if event.keycode==KEY_D:
   applied=recorder.remove_setup_card(uid)
   if applied:selection=[]
  elif event.keycode==KEY_P:
   applied=recorder.toggle_setup_unit_ready(uid)
  else:
   var copy=recorder.copy_setup_card(uid);applied=copy>0
   if applied:selection=[copy]
  if applied:
   var browsing=debug_open;var scroll_position=browser_scroll.scroll_vertical if browsing else 0
   message="";render()
   if browsing:browse_zone(browser_owner,browser_zone,scroll_position)
   get_viewport().set_input_as_handled()
  return
 super._unhandled_key_input(event)

func _input(event: InputEvent):
 if is_instance_valid(owner_editor.dialog_layer):return
 if event is InputEventMouse and is_instance_valid(owner_editor.record_tools) and owner_editor.record_tools.is_visible_in_tree() and owner_editor.record_tools.get_global_rect().has_point(event.position):return
 if recorder.replaying:get_viewport().set_input_as_handled();return
 # The ordinary debug C shortcut opens the graveyard picker in _input.
 # Let setup C reach GUI text fields or our copy handler instead.
 if recorder.editing_setup() and event is InputEventKey and event.keycode==KEY_C:return
 if recorder.can_edit_setup() and not host.menu_popup_open() and not modal and not debug_open and not history_open and not revealing() and not table.is_animating() and drag_uid==0 and debug_drag_uid==0 and unit_drag_uid==0 and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
  for who in life_widgets:
   if life_widgets[who].button.get_global_rect().has_point(event.position):
    owner_editor.edit_setup_life(int(who));get_viewport().set_input_as_handled();return
 super._input(event)

func stage_input(event: InputEvent,touch_uid: int=0):
 if is_instance_valid(owner_editor.dialog_layer):return
 if recorder.replaying:return
 super.stage_input(event,touch_uid)

func recorded_rect(ref: Dictionary) -> Rect2:
 if ref.has("player"):return target_rect(ref)
 if ref.has("stack"):
  var source=recorder.adapter.resolve_card(ref.stack)
  for entry in engine.unresolved_stack_entries():
   if entry.get("card",entry.get("source",{})).get("uid")==source.get("uid",-1):return target_rect({"stack_id":entry.id})
 var card=recorder.adapter.resolve_card(ref)
 return target_rect(engine.ref_target(card)) if not card.is_empty() else Rect2()

func recorded_destinations(value: Dictionary) -> Array:
 var result=[]
 for key in ["parts","picks"]:
  for item in value.get(key,[]):
   for ref in item if item is Array else [item]:result.append_array(recorded_destinations(ref))
 if value.has("player") or value.has("alias") or value.has("created") or value.has("stack"):
  var rect=recorded_rect(value)
  if rect.has_area():result.append(rect)
 return result

func recorded_action_arrows() -> Array:
 if recorder.recording or recorder.actions.is_empty():recorded_arrow_index=-1;return []
 # During playback keep the just-submitted action through the animation.
 var index=recorder.cursor-1 if recorder.replaying and recorder.cursor>0 else recorder.cursor
 if index>=recorder.actions.size():index=recorder.actions.size()-1
 var action=recorder.actions[index]
 var origin=recorded_rect(action.get("source",action.get("card",{"player":action.get("player",0)})))
 var destinations=recorded_destinations(action.get("target",{}))
 if action.type=="block" and not action.cards.is_empty():
  origin=recorded_rect(action.cards[0]);destinations=[target_rect(engine.combat.get("attacker",{}))]
 if destinations.is_empty() and action.type=="attack":destinations=[target_rect({"player":1-int(action.player)})]
 if index!=recorded_arrow_index:recorded_arrow_index=index;recorded_arrow_origin=Rect2();recorded_arrow_destinations=[]
 if origin.has_area():recorded_arrow_origin=origin
 if not destinations.is_empty():recorded_arrow_destinations=destinations
 var result=[]
 for rect in recorded_arrow_destinations:
  if not recorded_arrow_origin.has_area() or not rect.has_area():continue
  result.append({"from":rect_edge(recorded_arrow_origin,rect.get_center()),"to":rect_edge(rect,recorded_arrow_origin.get_center())})
 return result

func menu():
 if owner_editor.editing_initial_board:owner_editor.close_recording()
 else:owner_editor.finish_recording()
