extends "res://tests/support/ui_base.gd"

const Lobby=preload("res://net/lan_lobby.gd")
const LOOPBACK="ws://127.0.0.1:47976"
var fixture="res://work/match-room-exit-ui/"+str(Time.get_ticks_usec())

func lobby_of():
 return app.screen.get_children().filter(func(child):return child.get_script()==load("res://net/lan_lobby.gd"))[0]

func open_online():
 # This fixture checks UI lifecycle only. Real directory responses are covered
 # by test_cloud_directory_refresh against its isolated loopback relay.
 app.clear_page("online")
 var lobby=Lobby.new();lobby.cloud_server_url=LOOPBACK
 app.screen.add_child(lobby);lobby.build(app,app.lan_session)
 if app.lan_session.room_id.is_empty():lobby.set_cloud_mode(true)
 lobby.cloud_directory.set_process(false)
 return lobby

func finish_match(session,reason: String):
 if reason=="timeout":session.check_reconnect_timeout(session.disconnected_at+60000)
 else:session.on_failure("匹配房间已失效，请返回云端重新匹配")
 for child in app.get_children():
  if child is AcceptDialog:child.hide();child.queue_free()

func completed_returns(session,mobile: bool):
 for mode in ["manual","ranked","casual","exploration"]:
  for role in ["host","guest","spectator"]:
   session.leave(false)
   session.cloud_mode=true;session.cloud_ranked=mode!="manual";session.match_settled=session.cloud_ranked
   session.is_host=role=="host";session.read_only=role=="spectator";session.cloud_slot=1 if session.is_host else 8 if session.read_only else 2
   session.seat=0 if session.is_host else 1;session.room_id="TEST_ONLY_COMPLETED_ROOM"
   session.cloud_match_id="TEST_ONLY_COMPLETED_MATCH" if session.cloud_ranked else ""
   session.match_mode=mode if session.cloud_ranked else "ranked";app.match_mode=session.match_mode
   session.series=session.Series.new();session.series.setup(session.match_format(),true,session.match_rule_set())
   session.series.state.status="complete";session.series.state.winner=0
   session.room=session.series.public_state(session.seat)
   app.clear_page("battle");open_online()
   var lobby=lobby_of();var directory=lobby.cloud_directory
   var label="%s / %s / %s" % ["Android" if mobile else "desktop",mode,role]
   expect(lobby.cloud_selected and directory.active,label+": battle return restores cloud connection")
   expect(directory.token==app.account_token and directory.version==session.fingerprint and directory.match_mode==app.match_mode,label+": directory uses the current account, game and mode")
   directory.set_process(false);await process_frame
   var caption="离开观战" if session.read_only else "返回云端，重新匹配" if session.cloud_ranked else "离开房间"
   var exit_button=find_button(lobby.body,caption)
   expect(exit_button!=null,label+": completed room offers direct cloud return")
   if exit_button!=null:exit_button.pressed.emit()
   await process_frame
   if mobile:lobby.set_cloud_home_view("rooms");await process_frame
   expect(app.page=="online" and session.room_id.is_empty() and is_instance_valid(lobby.cloud_rooms_list) and directory.active,label+": cloud home stays connected without visiting the main menu")
   var old_peer=directory.peer
   app.menu();await process_frame
   expect(not is_instance_valid(directory) and old_peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED,label+": leaving the lobby closes its directory connection")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 app=load("res://main.tscn").instantiate()
 app.settings_path=fixture+"/settings.json";app.account_session_path=fixture+"/account.bin";app.tutorial_local_directory=fixture+"/tutorials"
 app.lan_storage_directory=fixture+"/lan";app.tournament_server_url=LOOPBACK
 root.add_child(app);await process_frame
 app.account_name="TEST_ONLY_ROOM_EXIT";app.account_nickname="Test";app.account_token="a".repeat(64)
 app.ensure_lan_session()
 var session=app.lan_session
 session.set_process(false);session.transport.set_process(false);session.discovery.set_process(false)
 for mobile in [false,true]:
  app.menu()
  app.is_android=mobile;app.layout_dpi_override=240 if mobile else 0
  root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
  if mobile:app.screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
  app.refresh_responsive_layout()
  for frame in range(6):await process_frame
  for host in [false,true]:
   for reason in ["timeout","closed"]:
    for exit_path in ["room","header"]:
     session.leave(false)
     session.cloud_mode=true;session.cloud_ranked=true;session.is_host=host;session.cloud_slot=1 if host else 2;session.seat=session.cloud_slot-1
     session.cloud_match_id="TEST_ONLY_OLD_MATCH";session.room_id="TEST_ONLY_OLD_ROOM"
     session.relay_code="ABCDEF123456";session.address="127.0.0.1";session.port=48049
     session.series=session.Series.new();session.series.setup(session.Series.BO1_SIDEBOARD,true,session.MATCH_RULE_SET)
     session.room=session.series.public_state(session.seat)
     session.start_disconnect_wait()
     var label="%s / %s / %s / %s" % ["Android" if mobile else "desktop","host" if host else "guest",reason,exit_path]
     session.stop_waiting()
     expect(session.ranked_match_pending() and not session.room_id.is_empty(),label+": unsettled match still blocks leaving")
     finish_match(session,reason);await process_frame
     expect(session.match_settled and session.ended() and session.saved_ranked_recovery().is_empty(),label+": dead match is released")
     app.clear_page("battle");open_online()
     var lobby=lobby_of()
     expect(lobby.cloud_directory.active,label+": returning from the match starts the cloud directory")
     lobby.cloud_directory.set_process(false)
     await process_frame
     expect(lobby.can_leave_room() and lobby.back_button.visible==not mobile,label+": ended match has one explicit mobile room exit or the desktop header")
     if exit_path=="room":
      var exit_button=find_button(lobby.body,"不再等待，离开对局")
      expect(exit_button!=null,label+": room exit is available")
      if exit_button!=null:exit_button.pressed.emit()
     elif mobile:app.android_system_back()
     else:lobby.back_button.pressed.emit()
     await process_frame
     expect(session.room_id.is_empty() and session.room.is_empty() and not session.cloud_ranked and session.disconnected_at==0,label+": exit clears local room and reconnect state")
     if exit_path=="room" or mobile:expect(lobby.cloud_selected and lobby.cloud_directory.active and lobby.queue_label.text!="尚未连接匹配队列",label+": direct cloud return keeps the directory and queue connected")
     if exit_path=="header" and not mobile:expect(app.page=="menu",label+": header returns to main menu")
     elif exit_path=="header":expect(app.page=="online",label+": Android system back uses the room exit and stays in cloud")
     open_online();await process_frame;lobby=lobby_of()
     expect(session.room_id.is_empty() and (lobby.header_mode_button!=null or lobby.body.find_child("ChooseCloudMode",true,false)!=null),label+": reopening online permits cloud entry")
  await completed_returns(session,mobile)
 session.leave(false);app.queue_free();await process_frame
 print("MATCH ROOM EXIT UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
