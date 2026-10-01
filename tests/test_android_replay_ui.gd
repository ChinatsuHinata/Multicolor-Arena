extends "res://tests/support/ui_base.gd"

func frames(count: int=4):
 for i in range(count):await process_frame

func inside(rect: Rect2,outer: Rect2) -> bool:
 return outer.grow(2).encloses(rect)

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-replay-ui/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED
 root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
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
 for dimensions in [Vector2i(1280,720),Vector2i(2340,1080)]:
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
  row.pressed.emit();await frames(8)
  var player=app.replay_controller
  view=app.duel_view
  expect(is_instance_valid(player) and is_instance_valid(player.dock),str(dimensions)+" playback opens responsive controls")
  if not is_instance_valid(player) or not is_instance_valid(player.dock):continue
  var dock_rect=player.dock.get_global_rect()
  expect(inside(dock_rect,safe),str(dimensions)+" playback controls stay in safe area")
  expect(dock_rect.position.y>=view.responsive.log_rect.end.y,str(dimensions)+" playback controls leave battle status visible")
  for item in player.dock.find_children("*","Button",true,false):
   if not item.visible:continue
   expect(item.size.y>=app.ui_metrics.hit and dock_rect.grow(2).encloses(item.get_global_rect()),str(dimensions)+" playback button fits: "+item.text)
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
  view.close_overlay();await frames()
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
  app.settings();await frames()
  expect(app.screen.find_children("*","CheckButton",true,false).all(func(item):return not item.text.contains("回放训练")),str(dimensions)+" settings hide replay training switch")
  app.replays();await frames()
 print("ANDROID REPLAY UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
