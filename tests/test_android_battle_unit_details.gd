extends "res://tests/support/ui_base.gd"

var output="res://work/battle-unit-details"

func touch(at: Vector2,pressed: bool,canceled: bool=false):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=pressed;event.canceled=canceled
 root.push_input(event,true);await process_frame

func motion(at: Vector2,relative: Vector2):
 var event=InputEventScreenDrag.new();event.index=0;event.position=at;event.relative=relative
 root.push_input(event,true);await process_frame

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))

func mouse_echo(at: Vector2,pressed: bool):
 var event=InputEventMouseButton.new();event.device=-1;event.button_index=MOUSE_BUTTON_LEFT
 event.position=at;event.global_position=at;event.pressed=pressed
 root.push_input(event,true);await process_frame

func echo_motion(at: Vector2,relative: Vector2):
 var event=InputEventMouseMotion.new();event.device=-1;event.position=at;event.global_position=at
 event.relative=relative;event.button_mask=MOUSE_BUTTON_MASK_LEFT
 root.push_input(event,true);await process_frame

func inspect_unit(c: Dictionary,name: String,jitter: Vector2=Vector2.ZERO,with_echo: bool=false,offset: Vector2=Vector2.ZERO):
 view.inspect_id="";view.update_inspection();view.close_overlay();view.clear_attack_preview()
 await process_frame
 var at=point(c.uid)+offset
 var before=snapshot()
 if with_echo:
  await create_timer(0.3).timeout
  await mouse_echo(at,true)
 await touch(at,true)
 expect(is_instance_valid(view.android_card_touch.ring),name+" starts hold feedback")
 expect(view.unit_drag_uid==0,name+" press leaves unit dragging pending")
 await create_timer(0.5).timeout
 if with_echo:await shot(name+"-ring")
 if jitter!=Vector2.ZERO:
  if with_echo:await echo_motion(at+jitter,jitter)
  await motion(at+jitter,jitter)
 await create_timer(0.65).timeout
 expect(view.inspection.visible and view.inspect_uid==c.uid,name+" opens unit details after one second")
 expect(snapshot()==before and view.local.is_empty() and not view.action_menu_open,name+" hold does not activate, attack or toggle its passive ability")
 await shot(name)
 if with_echo:await mouse_echo(at+jitter,false)
 await touch(at+jitter,false)
 expect(view.inspect_uid==c.uid and view.inspection.visible and snapshot()==before,name+" release preserves details without an action")
 view.inspect_id="";view.update_inspection()

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path(output+"/profile-"+str(Time.get_ticks_usec()))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 root.size=Vector2i(1280,720);root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.is_android=true;app.layout_dpi_override=240;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app.refresh_ui_metrics();app.load_legacy_test_decks();app.clear_page("battle")
 view=preload("res://scripts/duel_view.gd").new();view.is_android=true
 app.duel_view=view;app.screen.add_child(view);view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 view.begin(app,app.decks[app.player_choice],app.decks[app.ai_choice],0,42)
 view.set_process(false);e=view.engine;clean()
 var own=[put("53","field"),put("24","field"),put("character-fdf-101","field")]
 var enemy=[put("character-fdn-013","field",1),put("character-fdf-117","field",1),put("character-fdn-007","field",1)]
 for c in own+enemy:c.entered_turns=0
 for top_down in [false,true]:
  view.table.set_top_down_view(top_down);view.render();view.focus_android_camera(false);await settle()
  var prefix="2d" if top_down else "3d"
  await shot(prefix+"-board")
  await inspect_unit(own[1],prefix+"-native-mouse-echo",Vector2(10,9),true)
  if OS.get_cmdline_user_args().has("--echo-only"):
   print("ANDROID BATTLE UNIT MOUSE ECHO: ",checks," checks; ",failures.size()," failures")
   app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1);return
  for c in own+enemy:
   await inspect_unit(c,prefix+"-"+c.card_id)
  await inspect_unit(own[1],prefix+"-ran-jitter",Vector2(10,9))
  await inspect_unit(enemy[1],prefix+"-nue-jitter",Vector2(18,12))
  var rect=view.projected_card_rect(view.table.visuals["card_"+str(own[2].uid)])
  var edge=Vector2(rect.end.x+18,rect.get_center().y)
  expect(view.table.card_at(view.stage_point(edge))==0,prefix+" edge touch misses the narrow physics hitbox")
  expect(view.touch_card_at(edge)==own[2].uid,prefix+" padded edge touch selects the nearest unit")
  view.is_android=false
  expect(view.touch_card_at(edge)==0,prefix+" desktop keeps the original physics hitbox")
  view.is_android=true
  await inspect_unit(own[2],prefix+"-edge-hold",Vector2(8,6),true,edge-point(own[2].uid))
  var blocker=Button.new();blocker.position=edge-Vector2(24,24);blocker.size=Vector2(48,48);view.ui.add_child(blocker)
  expect(not view.touch_camera_available(edge),prefix+" UI controls retain priority over padded units")
  blocker.queue_free();await process_frame
  var rect_far=view.projected_card_rect(view.table.visuals["card_"+str(own[2].uid)])
  var far=Vector2(rect_far.end.x+app.ui_metrics.hit,rect_far.get_center().y)
  expect(view.touch_card_at(far)==0,prefix+" distant blank space does not select a nearby unit")
  for c in own+enemy:
   expect(view.touch_card_at(point(c.uid))==c.uid,prefix+" exact card hit keeps priority "+c.card_id)
  var before_tap=snapshot()
  await mouse_echo(edge,true);await touch(edge,true)
  await mouse_echo(edge,false);await touch(edge,false)
  expect(view.attack_preview_uid==own[2].uid and not view.inspection.visible,prefix+" padded short tap keeps the unit action")
  expect(snapshot()==before_tap and view.unit_drag_uid==0,prefix+" short tap and its mouse echoes do not commit a game action")
  view.clear_attack_preview();view.close_overlay()
  var start=point(own[0].uid);var finish=point(own[2].uid)
  var order=view.table.unit_order[0].duplicate()
  await mouse_echo(start,true);await touch(start,true)
  await echo_motion(finish,finish-start);await motion(finish,finish-start)
  expect(view.unit_drag_uid==own[0].uid and view.unit_dragging and not is_instance_valid(view.android_card_touch.ring),prefix+" intentional native movement starts unit dragging and cancels the ring")
  await mouse_echo(finish,false);await touch(finish,false)
  expect(view.table.unit_order[0]!=order and view.unit_drag_uid==0,prefix+" native unit dragging still reorders units")
  expect(not view.inspection.visible,prefix+" completed unit drag leaves details closed")
  await settle()
  var at=point(own[1].uid)
  await touch(at,true);await motion(at+Vector2(80,0),Vector2(80,0));await create_timer(1.1).timeout;await touch(at+Vector2(80,0),false,true)
  expect(not view.inspection.visible,prefix+" intentional drag cancels inspection")
  await touch(point(own[1].uid),true)
  view.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
  await create_timer(1.1).timeout;await touch(point(own[1].uid),false)
  expect(not view.inspection.visible and view.camera_touches.is_empty(),prefix+" switching apps cancels a pending hold")
 print("ANDROID BATTLE UNIT DETAILS: ",checks," checks; ",failures.size()," failures")
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
