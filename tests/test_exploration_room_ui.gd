extends "res://tests/support/ui_base.gd"
const Session=preload("res://net/lan_session.gd")
const Series=preload("res://net/series_controller.gd")
const G=preload("res://scripts/rules/gensokyo_exploration.gd")
func run():
 var fixture="res://work/exploration-room-ui/"+str(Time.get_ticks_usec())
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 DirAccess.make_dir_recursive_absolute(Store.Paths.root_override.path_join("tutorials"))
 app=load("res://main.tscn").instantiate()
 app.settings_path=fixture+"/settings.json";app.account_session_path=fixture+"/account.json";app.tutorial_local_directory=fixture+"/tutorials"
 root.add_child(app);await process_frame
 app.lan_storage_directory=fixture+"/unused-session"
 var session=Session.new();root.add_child(session);session.initialize(fixture+"/session");session.set_process(false)
 session.cloud_mode=true;session.is_host=true;session.cloud_slot=1;session.seat=0;session.room_id="TEST_ONLY_EXPLORATION_ROOM"
 session.series.setup(Series.EXPLORATION,true);session.cloud_peer_ids=[1,0,0,0,0,0,0,0]
 session.on_cloud_seats(["房主","二号玩家","","","","","",""],[1,22,0,0,0,0,0,0])
 expect(session.series.state.decks[1]==G.deck(),"cloud seat arrival retains seat two's fixed deck")
 session.is_host=false;session.cloud_slot=2;session.seat=1;session.room=session.series.public_state(1)
 session.connected=true;session.paused=false;session.notice="";app.lan_session=session
 for mobile in [false,true]:
  app.page="test_exploration_room"
  app.is_android=mobile;app.layout_dpi_override=240 if mobile else 0
  root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
  for i in range(4):await process_frame
  session.room=session.series.public_state(1);session.room.ready[0]=true
  app.clear_page("test_exploration_room")
  var lobby=preload("res://net/lan_lobby.gd").new();app.screen.add_child(lobby);lobby.build(app,session);await process_frame
  var ready=find_button(app.screen,"准备")
  expect(ready!=null and not ready.disabled,"seat two has an enabled ready button: "+str(mobile))
  session.series.ready(0);session.series.ready(1);session.series.prepare_choice()
  session.room=session.series.public_state(1);lobby.refresh(true);await process_frame
  var rolls=app.screen.find_children("*","Label",true,false).filter(func(label):return label.text.begins_with("投骰"))
  expect(rolls.size()==1 and not rolls[0].text.contains("%s") and not rolls[0].text.contains("%d"),"first-player dice results render without format placeholders: "+str(mobile))
  session.series=Series.new();session.series.setup(Series.EXPLORATION,true)
 session.leave(false);session.queue_free();app.queue_free();await process_frame
 print("EXPLORATION ROOM UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
