extends "res://tests/support/ui_base.gd"
const Session=preload("res://net/lan_session.gd")
var fixture="res://work/battle-result-ui/"+str(Time.get_ticks_usec())
func frames(count: int=5):
 for i in range(count):await process_frame
func dialog(title: String):
 for child in app.get_children():
  if child is AcceptDialog and child.title==title and child.visible:return child
 return null
func check_return(title: String):
 var button=view.find_child("BattleResultReturn",true,false)
 expect(button!=null and button.text==title and not button.disabled,"finished battle exposes an enabled "+title)
 if button==null:return
 var rect=button.get_global_rect();var safe=app.ui_metrics.safe
 expect(safe.grow(1).encloses(rect) and rect.get_center().x>safe.get_center().x and rect.get_center().y>safe.get_center().y,"return button fits at the bottom right: "+str(rect)+" safe="+str(safe))
 expect(not is_instance_valid(view.modal_root),"result navigation leaves the battlefield free of a modal blocker")
func finish_replay(save: bool):
 await frames()
 var prompt=dialog("保存回放")
 expect(prompt!=null,"finished battle offers replay saving")
 if prompt==null:return
 if save:
  prompt.confirmed.emit();await frames()
  var saved=dialog("回放已保存")
  expect(saved!=null,"replay is saved successfully")
  if saved!=null:saved.confirmed.emit()
 else:prompt.hide();prompt.canceled.emit()
 await frames()
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture+"/tutorials"))
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate();app.settings_path=fixture+"/settings.json";app.account_session_path=fixture+"/account.json";app.tutorial_local_directory=fixture+"/tutorials"
 root.add_child(app);await frames();app.load_legacy_test_decks()
 for mobile in [false,true]:
  app.is_android=mobile;app.layout_dpi_override=240 if mobile else 0
  root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
  await frames();app.refresh_responsive_layout()
  for save in [true,false]:
   app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
   view.replay_recording.prompted=false;e.surrender(1);view.reveal_player.reset();view.render()
   await finish_replay(save);check_return("退出对局")
   var button=view.find_child("BattleResultReturn",true,false)
   if button!=null:await click(button.get_global_rect().get_center())
   expect(app.page=="setup","saving or declining replay allows returning to offline setup")
   await frames()
  var session=Session.new();app.add_child(session);session.initialize(fixture+"/network");session.set_process(false)
  session.series.setup(1,true);session.series.state.status="complete";session.series.state.game_id="TEST_ONLY_RESULT";session.series.state.scores=[1,0];session.series.state.winner=0
  session.authority=Session.Duel.new();session.authority.start(app.decks[0],app.decks[1],0,42);session.authority.surrender(1);session.authority.presentation_events.clear()
  session.room_id="TEST_ONLY_RESULT_ROOM";session.seat=0;session.connected=false;session.paused=true;session.match_settled=true
  session.room=session.series.public_state(0);session.latest_snapshot=session.make_snapshot(0)
  app.lan_session=session;app.return_network_battle();view=app.duel_view;view.set_process(false);await frames()
  expect(view.find_child("DecisionClock",true,false)==null,"network battlefield contains no decision countdown")
  # Exercise the same prompt after the relay closes the settled room.
  var archive=preload("res://scripts/replay_archive.gd").new();archive.record(session.latest_snapshot);archive.finish(session.room)
  app.offer_replay(archive);await finish_replay(true);check_return("回到联机房间")
  await capture("battle-result-"+("android" if mobile else "pc"))
  var button=view.find_child("BattleResultReturn",true,false)
  if button!=null:await click(button.get_global_rect().get_center())
  expect(app.page=="online","settled disconnected match can return after replay saving")
  app.menu();session.leave(false);session.queue_free();app.lan_session=null;await frames()
 print("BATTLE RESULT UI ",checks," checks; failures=",failures)
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
