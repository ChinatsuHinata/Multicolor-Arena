extends "res://tests/support/ui_base.gd"
var fixture="res://work/android-replay-ui/"+str(Time.get_ticks_usec())

func frames(count: int=4):
 for i in range(count):await process_frame

func tap(at: Vector2):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func check_controls(player,label: String):
 var dock_rect=player.dock.get_global_rect()
 var safe=app.ui_metrics.safe
 expect(inside(dock_rect,safe),label+" playback controls stay in safe area")
 expect(absf(dock_rect.end.y-safe.end.y)<2 and dock_rect.size.y<=app.ui_metrics.hit+app.ui_metrics.gap*2+2,label+" controls use one compact row at the bottom edge")
 expect(app.duel_view.HAND.end.y<=dock_rect.position.y-app.ui_metrics.gap+2,label+" hand cards have their own space above the transport")
 expect(not dock_rect.intersects(app.duel_view.responsive.log_rect) and not dock_rect.intersects(app.duel_view.responsive.toolbar_rect),label+" controls leave battle state and toolbar clear")
 for item in player.dock.find_children("*","Button",true,false):
  if not item.visible:continue
  expect(item.size.y>=app.ui_metrics.hit and dock_rect.grow(2).encloses(item.get_global_rect()),label+" touch target fits: "+item.text)
 var collapse=player.dock.find_child("ReplayCollapse",true,false)
 await tap(collapse.get_global_rect().get_center())
 expect(player.collapsed and not player.dock.visible and player.restore_button.visible,label+" actual touch collapses the replay strip")
 expect(inside(player.restore_button.get_global_rect(),safe),label+" collapsed restore button stays reachable")
 expect(not player.restore_button.get_global_rect().intersects(app.duel_view.HAND) and not player.restore_button.get_global_rect().intersects(app.duel_view.responsive.hand_toggle_rect),label+" collapsed button leaves the hand and visibility button clear")
 expect(app.duel_view.camera_touches.is_empty() and app.duel_view.android_card_touch.finger<0,label+" replay tap never starts a battlefield gesture")
 await capture("android-replay-collapsed-"+label)
 await tap(player.restore_button.get_global_rect().get_center())
 expect(not player.collapsed and player.dock.visible and not player.restore_button.visible,label+" actual touch restores the strip")
 var before=player.index
 var step=player.dock.find_child("ReplayNext",true,false)
 await tap(step.get_global_rect().get_center())
 expect(player.index==mini(before+1,player.archive.frames.size()-1),label+" next-step touch changes playback once")
 var previous=player.dock.find_child("ReplayPrevious",true,false)
 await tap(previous.get_global_rect().get_center())
 expect(player.index==maxi(0,mini(before+1,player.archive.frames.size()-1)-1),label+" previous-step touch changes playback once")
 var old_speed=player.speed
 await tap(player.speed_button.get_global_rect().get_center())
 expect(player.speed!=old_speed,label+" touch changes playback speed")
 await tap(player.play_button.get_global_rect().get_center())
 expect(player.playing,label+" touch starts playback")
 await tap(player.play_button.get_global_rect().get_center())
 expect(not player.playing,label+" touch pauses playback")
 var slider_rect=player.slider.get_global_rect()
 var from=Vector2(slider_rect.position.x+4,slider_rect.get_center().y)
 var to=Vector2(slider_rect.end.x+40,from.y)
 var touch=InputEventScreenTouch.new();touch.index=0;touch.position=from;touch.pressed=true
 root.push_input(touch,true);await process_frame
 var drag=InputEventScreenDrag.new();drag.index=0;drag.position=to;drag.relative=to-from
 root.push_input(drag,true);await process_frame
 expect(app.duel_view.camera_touches.is_empty(),label+" dragging past the replay slider does not pan the battlefield")
 touch=touch.duplicate();touch.pressed=false;touch.position=to;root.push_input(touch,true);await frames()
 expect(player.index==player.archive.frames.size()-1,label+" scrub release reaches the final frame")
 expect(player.control_finger<0 and not player.control_scrubbing,label+" scrub ends its touch capture")
 await tap(player.slider.get_global_rect().position+Vector2(1,player.slider.size.y*0.5))
 expect(player.index==0,label+" slider tap seeks back to the first frame")
 expect(app.duel_view.camera_touches.is_empty(),label+" seeking does not leave a stuck battlefield touch")
 touch=InputEventScreenTouch.new();touch.index=0;touch.position=player.slider.get_global_rect().get_center();touch.pressed=true
 root.push_input(touch,true);await process_frame
 touch=touch.duplicate();touch.pressed=false;touch.canceled=true;root.push_input(touch,true);await frames()
 expect(player.index==0 and player.slider.value==0,label+" cancelled scrub preserves the current frame")
 await tap(player.dock.find_child("ReplayCollapse",true,false).get_global_rect().get_center())
 player.seek(1);await frames()
 expect(player.collapsed and not player.dock.visible and player.restore_button.visible,label+" seeking preserves the collapsed preference")
 await tap(player.restore_button.get_global_rect().get_center());player.seek(0);await frames()
 var current=app.duel_view
 var return_at=player.dock.find_child("ReplayReturn",true,false).get_global_rect().get_center()
 current.open_android_battle_menu()
 await tap(return_at)
 expect(app.page=="battle" and not player.controls.visible and player.control_finger<0,label+" battle menu blocks underlying replay return immediately")
 await tap(current.android_battle_menu_root.find_child("CloseBattleMenu",true,false).get_global_rect().get_center())
 expect(player.controls.visible and not is_instance_valid(current.android_battle_menu_root),label+" closing the menu restores replay controls")
 current.open_history()
 await tap(return_at)
 expect(app.page=="battle" and not player.controls.visible and player.control_finger<0,label+" battle history blocks underlying replay return")
 await tap(find_button(current.history_root,"关闭记录").get_global_rect().get_center())
 expect(player.controls.visible and not current.history_open,label+" closing history restores replay controls")
 current.overlay("回放遮挡测试")
 await tap(return_at)
 expect(app.page=="battle" and not player.controls.visible and player.control_finger<0,label+" modal panel blocks underlying replay return")
 current.close_overlay();await frames()
 expect(player.controls.visible,label+" closing modal restores replay controls")
 var card=current.engine.players[current.local_seat].hand[0]
 var before_camera=current.table.camera.transform
 current.android_inspection_allowed=true;current.inspect_card(card.card_id,card.uid);current.android_inspection_allowed=false;await frames()
 expect(current.inspection.visible and not current.inspection.get_global_rect().intersects(player.dock.get_global_rect()),label+" card preview does not overlap the expanded replay strip")
 current.inspect_id="";current.update_inspection();await frames()
 expect(current.table.camera.transform.is_equal_approx(before_camera),label+" closing card preview restores the replay camera")
 current.android_inspection_allowed=true;current.inspect_card(card.card_id,card.uid);current.android_inspection_allowed=false;await frames()
 await tap(player.dock.find_child("ReplayCollapse",true,false).get_global_rect().get_center())
 expect(current.inspection.visible and not current.inspection.get_global_rect().intersects(player.restore_button.get_global_rect()),label+" collapsing replay controls leaves the preview usable")
 current.inspect_id="";current.update_inspection();await frames()
 expect(current.android_inspection_camera_restore.is_empty() and current.android_camera_area==current.responsive.camera_focus_rect(),label+" closing preview adapts the camera to the newly available space")
 await tap(player.restore_button.get_global_rect().get_center());await frames()

func inside(rect: Rect2,outer: Rect2) -> bool:
 return outer.grow(2).encloses(rect)

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture+"/tutorials"))
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 root.mode=Window.MODE_WINDOWED
 root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();app.settings_path=fixture+"/settings.json";app.account_session_path=fixture+"/account.json";app.tutorial_local_directory=fixture+"/tutorials"
 root.add_child(app);await frames()
 app.is_android=true
 app.load_legacy_test_decks()
 app.setup();app.begin_battle(true);view=app.duel_view;e=view.engine
 await settle()
 e.surrender(0);view.render();await frames()
 for child in app.get_children():
  if child is AcceptDialog:child.queue_free()
 await frames()
 var archive=view.replay_recording
 var path=Store.Paths.root().path_join("replay/安卓回放测试.mreply")
 expect(archive.save(path).has("path"),"replay fixture saves")
 var long_path=Store.Paths.root().path_join("replay/"+"安卓横屏回放名称很长的玩家对战记录".repeat(4)+".mreply")
 expect(archive.save(long_path).has("path"),"long replay name fixture saves")
 for dimensions in [Vector2i(1280,720),Vector2i(2340,1080),Vector2i(2670,1200)]:
  root.size=dimensions
  app.layout_dpi_override=float(dimensions.y)/3.0
  app.layout_safe_override=Rect2(60,0,dimensions.x-84,dimensions.y-24)
  await frames()
  app.replays();await frames()
  var safe=app.ui_metrics.safe
  var scroll=app.screen.get_node("ReplayScroll") as ScrollContainer
  var row=scroll.get_child(0).get_child(0) as Button
  expect(inside(scroll.get_global_rect(),safe),str(dimensions)+" replay list stays in safe area")
  expect(row.size.y>=app.ui_metrics.hit and scroll.get_global_rect().encloses(row.get_global_rect()),str(dimensions)+" replay row is reachable and touch sized")
  expect(scroll.get_child(0).get_children().all(func(entry):return entry.get_global_rect().end.x<=scroll.get_global_rect().end.x+2),str(dimensions)+" long replay names stay within list width")
  expect(inside(find_button(app.screen,"返回").get_global_rect(),safe),str(dimensions)+" list back button stays in safe area")
  await capture("android-replay-list-"+str(dimensions.x))
  await tap(row.get_global_rect().get_center());await frames(8)
  var player=app.replay_controller
  view=app.duel_view
  expect(is_instance_valid(player) and is_instance_valid(player.dock),str(dimensions)+" playback opens responsive controls")
  if not is_instance_valid(player) or not is_instance_valid(player.dock):continue
  await check_controls(player,str(dimensions.x))
  view=app.duel_view
  safe=app.ui_metrics.safe
  var dock_rect=player.dock.get_global_rect()
  for caption in ["己方手牌 ","对手手牌 "]:
   var hand_button=find_button(view.hud,caption+str(view.engine.players[view.local_seat].hand.size()))
   if caption=="对手手牌 ":hand_button=find_button(view.hud,caption+str(view.engine.players[1-view.local_seat].hand.size()))
   expect(hand_button!=null and inside(hand_button.get_global_rect(),safe) and not hand_button.get_global_rect().intersects(dock_rect),str(dimensions)+" "+caption+"button stays separate")
  app.set_replay_training_mode(true)
  player.open_training();await frames()
  expect(not app.replay_training_mode and not is_instance_valid(player.training_button) and player.training_editor==null,str(dimensions)+" Android replay training is unavailable")
  player.seek(archive.frames.size()-1);view=app.duel_view;await frames()
  expect(not view.modal and player.controls.visible,str(dimensions)+" replay end keeps playback controls available")
  archive.prompted=false
  app.offer_replay(archive);await frames()
  expect(app.get_children().all(func(child):return not child is ConfirmationDialog or child.title!="保存回放"),str(dimensions)+" replay end does not ask to save again")
  await capture("android-replay-"+str(dimensions.x))
  player.seek(0);await frames()
  expect(inside(player.dock.get_global_rect(),safe),str(dimensions)+" seeking keeps controls aligned")
  view=app.duel_view
  view.settings_menu();await frames()
  expect(view.ui.find_children("*","CheckButton",true,false).all(func(item):return not item.text.contains("回放训练")),str(dimensions)+" battle settings hide replay training switch")
  await tap(view.android_battle_menu_root.find_child("CloseBattleMenu",true,false).get_global_rect().get_center())
  if dimensions.x==1280:
   root.size=Vector2i(1600,900)
   app.layout_dpi_override=300.0
   app.layout_safe_override=Rect2(60,0,1516,876)
   await frames();app.refresh_responsive_layout();await frames()
   expect(inside(player.dock.get_global_rect(),app.ui_metrics.safe),"active replay relayout stays in safe area")
   root.size=dimensions
   app.layout_dpi_override=float(dimensions.y)/3.0
   app.layout_safe_override=Rect2(60,0,dimensions.x-84,dimensions.y-24)
   await frames();app.refresh_responsive_layout();await frames()
  var return_button=player.dock.find_child("ReplayReturn",true,false)
  await tap(return_button.get_global_rect().get_center())
  expect(app.page=="replays",str(dimensions)+" actual touch returns to the replay list")
  await frames()
  var reopened_row=app.screen.get_node("ReplayScroll").get_child(0).get_child(0)
  await tap(reopened_row.get_global_rect().get_center());await frames()
  expect(app.page=="battle" and is_instance_valid(app.replay_controller),str(dimensions)+" a replay can be opened again after returning")
  app.settings();await frames()
  expect(app.screen.find_children("*","CheckButton",true,false).all(func(item):return not item.text.contains("回放训练")),str(dimensions)+" settings hide replay training switch")
  app.replays();await frames()
 print("ANDROID REPLAY UI: ",checks," checks; ",failures.size()," failures")
 app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
