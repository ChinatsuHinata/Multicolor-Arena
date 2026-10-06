extends "res://scripts/duel_view.gd"
## Static authoring projection. Every edit goes back to schema data.
var editor

func resize_world():
 super.resize_world()
 if editor==null or not is_instance_valid(viewport):return
 # Keep the whole board beside the inspector, without covering its right half.
 var area=Rect2(12,68,maxf(200,editor.inspector.position.x-24),maxf(200,editor.size.y-80))
 STAGE=area;viewport.size=Vector2i(area.size)
 if is_instance_valid(stage):stage.position=area.position;stage.size=area.size

func fit_camera():
 var aspect=STAGE.size.x/maxf(1,STAGE.size.y)
 table.camera_frame_scale=maxf(1.0,1.78/aspect)
 table.set_camera()

func _input(_event):
 pass

func _process(_delta):
 if engine!=null:update_badge_positions()

func render():
 super.render()
 hud.hide();inspection.hide();stack_panel.hide();banner.hide()
 hand_scroll.hide();opponent_layer.hide()
 if is_instance_valid(android_zone_shortcuts):android_zone_shortcuts.hide()

func stage_input(event: InputEvent,_touch_uid: int=0):
 if event is InputEventScreenTouch and event.pressed:
  var click=InputEventMouseButton.new();click.position=event.position;click.pressed=true;click.button_index=MOUSE_BUTTON_LEFT
  stage_input(click);return
 if event is InputEventMouseButton and event.pressed:
  if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   var wheel=event.duplicate();wheel.position=event.position/STAGE.size*Vector2(viewport.size);table.pointer(wheel);return
  if event.button_index!=MOUSE_BUTTON_LEFT:return
  var at=event.position/STAGE.size*Vector2(viewport.size)
  var uid=table.card_at(at)
  if uid>0:object_clicked(uid);return
  var spot=table.debug_field_group(at)
  if not spot.is_empty():editor.choose_card(int(spot.owner),"field",str(spot.group))

func object_clicked(uid: int):
 var card=engine.find_card(uid)
 if not card.is_empty():editor.select_entity(uid)

func leader_zone_clicked(who: int):
 editor.select_entity(engine.players[who].leader.uid)

func inspect_card(_id: String,uid: int=0,_caption: String="",_art_id: String=""):
 if uid>0:editor.select_entity(uid)

func _unhandled_key_input(_event):
 pass
