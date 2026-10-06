extends "res://scripts/duel_view.gd"
## Select subjects in a static preview, then use native actions while recording.
var workspace

func resize_world():
 super.resize_world()
 if workspace==null or not is_instance_valid(viewport):return
 if workspace.capturing:
  if is_instance_valid(table):table.camera_frame_scale=1.0;table.set_camera()
  return
 STAGE=workspace.battle_area();viewport.size=Vector2i(STAGE.size)
 if is_instance_valid(stage):stage.position=STAGE.position;stage.size=STAGE.size
 if is_instance_valid(table):
  table.reset_camera()
  table.camera_frame_scale=maxf(1.0,1.78/(STAGE.size.x/maxf(1,STAGE.size.y)));table.set_camera()

func _process(_delta):
 if engine==null:return
 if not engine.presentation_events.is_empty() or revealing() or last_revision!=engine.revision:render()
 update_badge_positions()

func focus_android_camera(animate: bool):
 if workspace!=null and workspace.capturing:super.focus_android_camera(animate)

func sync_automatic_camera_focus():
 if workspace!=null and workspace.capturing:super.sync_automatic_camera_focus()

func render():
 super.render()
 if workspace!=null and not workspace.capturing:
  hud.hide();inspection.hide();hand_scroll.hide();opponent_layer.hide();stack_panel.hide();banner.hide()
  if is_instance_valid(android_zone_shortcuts):android_zone_shortcuts.hide()
  if is_instance_valid(android_back_button):android_back_button.hide()
  arrow_layer.hide()
 elif is_instance_valid(hud):
  hud.show();arrow_layer.show()
  if is_instance_valid(android_back_button):android_back_button.show()

func _input(event: InputEvent):
 if not workspace.capturing:
  if event is InputEventScreenTouch and event.pressed and STAGE.has_point(event.position):
   var local_event=event.duplicate();local_event.position-=STAGE.position;stage_input(local_event);get_viewport().set_input_as_handled()
  return
 if event is InputEventMouse and workspace.controls.get_global_rect().has_point(event.position):return
 if event is InputEventScreenTouch and workspace.controls.get_global_rect().has_point(event.position):return
 super._input(event)

func stage_input(event: InputEvent,touch_uid: int=0):
 if workspace.capturing:super.stage_input(event,touch_uid);return
 if not (event is InputEventMouseButton or event is InputEventScreenTouch) or not event.pressed:return
 if event is InputEventMouseButton and event.button_index!=MOUSE_BUTTON_LEFT:return
 var point=event.position/STAGE.size*Vector2(viewport.size)
 var uid=table.card_at(point)
 if uid>0:workspace.pick_card(uid);return
 var spot=table.debug_field_group(point)
 if not spot.is_empty():workspace.pick_zone(int(spot.owner),"palette" if spot.group=="palette" else "field");return
 for who in range(2):
  var zone=table.debug_drop_zone(point,who)
  if not zone.is_empty():workspace.pick_zone(who,zone);return

func object_clicked(uid: int):
 if workspace.capturing:super.object_clicked(uid)
 else:workspace.pick_card(uid)

func hand_clicked(uid: int):
 if workspace.capturing:super.hand_clicked(uid)
 else:workspace.pick_card(uid)

func leader_zone_clicked(who: int):
 if workspace.capturing:super.leader_zone_clicked(who)
 else:workspace.pick_card(engine.players[who].leader.uid)

func choose_target(target: Dictionary):
 if workspace.capturing:super.choose_target(target)
 elif target.has("uid"):workspace.pick_card(int(target.uid))
 elif target.has("player"):workspace.pick_player(int(target.player))

func inspect_card(id: String,uid: int=0,caption: String="",art_id: String=""):
 if workspace.capturing:super.inspect_card(id,uid,caption,art_id)
 elif uid>0:workspace.pick_card(uid)

func can_debug_add() -> bool:return false
func can_begin_debug_drag() -> bool:return false
func _unhandled_key_input(event: InputEvent):
 if workspace.capturing:super._unhandled_key_input(event)
func menu():
 if workspace.capturing:workspace.stop_capture()
 else:workspace.cancel()
