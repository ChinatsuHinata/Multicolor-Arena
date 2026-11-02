extends "res://tests/support/ui_base.gd"
var fixture="res://work/android-replay-ui/"+str(Time.get_ticks_usec())

func frames(count: int=4):
 for i in range(count):await process_frame

func tap(at: Vector2):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func check_camera_parity(player,label: String):
 var current=app.duel_view
 current.set_process(false)
 # Put a visible card in the opposing back row so placement is tested against it.
 var enemy_seat=1-current.local_seat
 var back_card=current.engine.players[current.local_seat].hand[0].duplicate(true)
 back_card.uid=900000;back_card.owner=enemy_seat;back_card.zone="palette";back_card.tapped=false
 current.engine.players[enemy_seat].palette.append(back_card)
 for top_down in [false,true]:
  current.table.set_top_down_view(top_down)
  # Use the identical snapshot with ordinary battle HUD/hidden opponent hand.
  current.network_session=null;current.render();current.focus_android_camera(false);await frames()
  var normal_frame=current.projected_android_focus(current.android_focus_bounds())
  var normal_transform=current.table.camera.global_transform
  var normal_scale=current.table.camera_frame_scale
  expect(current.enemy_nodes.is_empty(),label+" normal battle hides opponent hand")
  current.network_session=player;current.render();current.focus_android_camera(false);await create_timer(0.3).timeout;await frames()
  var replay_frame=current.projected_android_focus(current.android_focus_bounds())
  var mode="2d" if top_down else "3d"
  expect(replay_frame.size.x>=normal_frame.size.x-1 and replay_frame.size.y>=normal_frame.size.y-1,label+" "+mode+" replay battlefield is at least normal battle size")
  expect(current.table.camera.global_transform.is_equal_approx(normal_transform) and is_equal_approx(current.table.camera_frame_scale,normal_scale),label+" "+mode+" visible replay opponent hand does not reframe the battlefield")
  var enemy=1-current.local_seat
  var cards=current.engine.players[enemy].hand
  expect(current.enemy_nodes.size()==cards.size(),label+" "+mode+" all opponent hand cards are present")
  for tile in current.enemy_nodes.values():
   expect(tile.is_visible_in_tree() and tile.modulate.a>0.95,label+" "+mode+" opponent card is visible")
   expect(tile.get_global_rect().position.x>=current.SIDEBAR.position.x-1,label+" "+mode+" opponent card stays in the side rail")
   var back_rect=current.card_screen_rect("card_"+str(back_card.uid))
   expect(back_rect.has_area() and not tile.get_global_rect().intersects(back_rect),label+" "+mode+" opponent hand does not cover the opposing back row")
  var button=find_button(current.hud,"对手手牌 "+str(cards.size()))
  var start_index=player.index
  player.playing=true
  await tap(button.get_global_rect().get_center());await create_timer(0.8).timeout
  expect(current.debug_open and player.index==start_index,label+" "+mode+" browsing pauses replay progress")
  # Simulate an animation/browser leaving the hand layer and a card hidden.
  current.opponent_layer.hide()
  if not current.enemy_nodes.is_empty():
   var hidden=current.enemy_nodes.values()[0];hidden.hide();hidden.modulate.a=0.0
  await tap(current.browser_panel.find_child("ClosePileBrowser",true,false).get_global_rect().get_center());await frames()
  expect(not current.debug_open and current.enemy_nodes.size()==cards.size() and current.enemy_nodes.values().all(func(tile):return tile.is_visible_in_tree() and tile.modulate.a>0.95),label+" "+mode+" closing browser restores all opponent hand cards")
  expect(player.playing,label+" "+mode+" replay resumes after closing the browser")
  player.playing=false
  current.set_hand_display(false);await frames()
  expect(not current.opponent_layer.visible,label+" "+mode+" hide hands hides opponent cards")
  current.set_hand_display(true);await create_timer(0.5).timeout;await frames()
  expect(current.opponent_layer.visible and current.enemy_nodes.size()==cards.size() and current.enemy_nodes.values().all(func(tile):return tile.is_visible_in_tree() and tile.modulate.a>0.95),label+" "+mode+" showing hands restores opponent cards")
  await capture("android-replay-full-board-"+label+"-"+mode)
  await tap(player.restore_button.get_global_rect().get_center())
  expect(not player.collapsed and current.table.camera.global_transform.is_equal_approx(normal_transform),label+" "+mode+" expanded replay overlay preserves normal battle framing")
  await capture("android-replay-expanded-"+label+"-"+mode)
  await tap(player.dock.find_child("ReplayCollapse",true,false).get_global_rect().get_center())
  expect(player.collapsed and current.table.camera.global_transform.is_equal_approx(normal_transform),label+" "+mode+" collapsed replay overlay preserves normal battle framing")
  var card=current.engine.players[current.local_seat].hand[0]
  current.android_inspection_allowed=true;current.inspect_card(card.card_id,card.uid);current.android_inspection_allowed=false;await frames()
  expect(current.table.camera.global_transform.is_equal_approx(normal_transform),label+" "+mode+" preview leaves replay battlefield unchanged")
  await capture("android-replay-preview-"+label+"-"+mode)
  await create_timer(0.28).timeout
  await tap(app.ui_metrics.safe.end-Vector2(4,4));await frames()
  expect(not current.inspection.visible and current.table.camera.global_transform.is_equal_approx(normal_transform),label+" "+mode+" preview outside dismissal leaves replay camera unchanged")
 current.engine.players[enemy_seat].palette.erase(back_card)
 current.render()
 current.set_process(true)

func check_controls(player,label: String):
 expect(player.collapsed,"replay initially leaves the battlefield unobstructed")
 await tap(player.restore_button.get_global_rect().get_center())
 var before_transform=app.duel_view.table.camera.transform
 var before_scale=app.duel_view.table.camera_frame_scale
 var dock_rect=player.dock.get_global_rect()
 var safe=app.ui_metrics.safe
 expect(inside(dock_rect,safe),label+" playback controls stay in safe area")
 expect(absf(dock_rect.end.y-safe.end.y)<2 and dock_rect.size.y<=app.ui_metrics.hit+app.ui_metrics.gap*2+2,label+" controls use one compact row at the bottom edge")
 expect(is_equal_approx(app.duel_view.HAND.end.y,safe.end.y),label+" overlay controls reserve no extra battlefield or hand space")
 expect(not dock_rect.intersects(app.duel_view.responsive.log_rect) and not dock_rect.intersects(app.duel_view.responsive.toolbar_rect),label+" controls leave battle state and toolbar clear")
 for item in player.dock.find_children("*","Button",true,false):
  if not item.visible:continue
  expect(item.size.y>=app.ui_metrics.hit and dock_rect.grow(2).encloses(item.get_global_rect()),label+" touch target fits: "+item.text)
 var collapse=player.dock.find_child("ReplayCollapse",true,false)
 await tap(collapse.get_global_rect().get_center())
 expect(player.collapsed and not player.dock.visible and player.restore_button.visible,label+" actual touch collapses the replay strip")
 expect(app.duel_view.table.camera.transform.is_equal_approx(before_transform) and is_equal_approx(app.duel_view.table.camera_frame_scale,before_scale),label+" collapsing the strip does not resize or move the battlefield")
 expect(inside(player.restore_button.get_global_rect(),safe),label+" collapsed restore button stays reachable")
 expect(not player.restore_button.get_global_rect().intersects(app.duel_view.HAND) and not player.restore_button.get_global_rect().intersects(app.duel_view.responsive.hand_toggle_rect),label+" collapsed button leaves the hand and visibility button clear")
 expect(app.duel_view.camera_touches.is_empty() and app.duel_view.android_card_touch.finger<0,label+" replay tap never starts a battlefield gesture")
 await capture("android-replay-collapsed-"+label)
 await tap(player.restore_button.get_global_rect().get_center())
 expect(not player.collapsed and player.dock.visible and not player.restore_button.visible,label+" actual touch restores the strip")
 expect(app.duel_view.table.camera.transform.is_equal_approx(before_transform) and is_equal_approx(app.duel_view.table.camera_frame_scale,before_scale),label+" expanding the strip does not resize or move the battlefield")
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
 expect(current.inspection.visible and not player.controls.visible and current.table.camera.transform.is_equal_approx(before_camera),label+" preview overlays HUD and blocks replay controls without moving the board")
 var before_index=player.index
 await tap(step.get_global_rect().get_center());await frames()
 expect(not current.inspection.visible and player.index==before_index and not player.playing and current.local.is_empty(),label+" dismissing preview over replay step does not activate the underlying control")
 expect(current.table.camera.transform.is_equal_approx(before_camera),label+" closing card preview restores the replay camera")
 await tap(player.dock.find_child("ReplayCollapse",true,false).get_global_rect().get_center())
 current.android_inspection_allowed=true;current.inspect_card(card.card_id,card.uid);current.android_inspection_allowed=false;await frames()
 expect(current.inspection.visible and not player.controls.visible and current.table.camera.transform.is_equal_approx(before_camera),label+" preview also leaves collapsed replay camera unchanged")
 await tap(app.ui_metrics.safe.end-Vector2(4,4));await frames()
 expect(not current.inspection.visible and player.controls.visible and current.table.camera.transform.is_equal_approx(before_camera),label+" outside tap closes preview and restores the collapsed control")
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
  app.replay_history_tab=true
  app.replays();await frames()
  expect(find_button(app.screen,"最近历史")!=null and find_button(app.screen,"已保留")!=null,"history and saved tabs are available")
  var keep=find_button(app.screen,"保留")
  if keep!=null:keep.pressed.emit();await frames()
  expect(find_button(app.screen,"已保留").button_pressed==false and app.screen.find_child("ReplayKeep",true,false).disabled,"keeping history creates a saved copy and updates the action")
  app.screen.find_child("ReplayExport",true,false).pressed.emit();await frames()
  var picker=app.find_child("ReplayExportPicker",true,false) as FileDialog
  expect(picker!=null and picker.file_mode==FileDialog.FILE_MODE_SAVE_FILE and picker.use_native_dialog,"history export opens a native save picker")
  if picker!=null:
   var export_path=Store.Paths.root().path_join("export-"+str(dimensions.x)+".mreply")
   picker.file_selected.emit(export_path);await frames()
   expect(FileAccess.file_exists(export_path),"history export writes the selected file")
   for child in app.get_children():
    if child is AcceptDialog:child.queue_free()
   await frames()
  find_button(app.screen,"已保留").pressed.emit();await frames()
  expect(not app.replay_history_tab and app.screen.find_child("ReplayKeep",true,false)==null,"saved tab keeps the export action without a keep action")
  var safe=app.ui_metrics.safe
  var scroll=app.screen.get_node("ReplayScroll") as ScrollContainer
  var row=scroll.get_child(0).get_child(0).get_node("ReplayPlay") as Button
  expect(inside(scroll.get_global_rect(),safe),str(dimensions)+" replay list stays in safe area")
  expect(row.size.y>=app.ui_metrics.hit and scroll.get_global_rect().encloses(row.get_global_rect()),str(dimensions)+" replay row is reachable and touch sized")
  expect(scroll.get_child(0).get_children().all(func(entry):return entry.get_global_rect().end.x<=scroll.get_global_rect().end.x+2),str(dimensions)+" long replay names stay within list width")
  expect(inside(find_button(app.screen,"返回").get_global_rect(),safe),str(dimensions)+" list back button stays in safe area")
  await capture("android-replay-list-"+str(dimensions.x))
  await tap(row.get_global_rect().get_center());await frames(8)
  var player=app.replay_controller
  view=app.duel_view
  safe=app.ui_metrics.safe
  expect(is_instance_valid(player) and is_instance_valid(player.dock),str(dimensions)+" playback opens responsive controls")
  if not is_instance_valid(player) or not is_instance_valid(player.dock):continue
  await check_camera_parity(player,str(dimensions.x))
  await check_controls(player,str(dimensions.x))
  view=app.duel_view
  safe=app.ui_metrics.safe
  var dock_rect=player.dock.get_global_rect()
  for caption in ["己方手牌 ","对手手牌 "]:
   var hand_button=find_button(view.hud,caption+str(view.engine.players[view.local_seat].hand.size()))
   if caption=="对手手牌 ":hand_button=find_button(view.hud,caption+str(view.engine.players[1-view.local_seat].hand.size()))
   expect(hand_button!=null and inside(hand_button.get_global_rect(),safe) and not hand_button.get_global_rect().intersects(dock_rect),str(dimensions)+" "+caption+"button stays separate: "+str(hand_button.get_global_rect() if hand_button!=null else null)+" safe="+str(safe)+" dock="+str(dock_rect))
  app.set_replay_training_mode(true)
  player.open_training();await frames()
  expect(not app.replay_training_mode and not is_instance_valid(player.training_button) and player.training_editor==null,str(dimensions)+" Android replay training is unavailable")
  player.seek(archive.frames.size()-1);view=app.duel_view;await frames()
  expect(not view.modal and player.controls.visible,str(dimensions)+" replay end keeps playback controls available")
  app.offer_replay(archive);await frames()
  expect(app.get_children().all(func(child):return not child is ConfirmationDialog or child.title!="保存回放"),str(dimensions)+" replay end does not ask to save again")
  expect(preload("res://scripts/replay_library.gd").entries(true).size()==1,"viewing and repeated callbacks never duplicate history")
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
  var reopened_row=app.screen.get_node("ReplayScroll").get_child(0).get_child(0).get_node("ReplayPlay")
  await tap(reopened_row.get_global_rect().get_center());await frames()
  expect(app.page=="battle" and is_instance_valid(app.replay_controller),str(dimensions)+" a replay can be opened again after returning")
  app.settings();await frames()
  expect(app.screen.find_children("*","CheckButton",true,false).all(func(item):return not item.text.contains("回放训练")),str(dimensions)+" settings hide replay training switch")
  app.replays();await frames()
 print("ANDROID REPLAY UI: ",checks," checks; ",failures.size()," failures")
 app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
