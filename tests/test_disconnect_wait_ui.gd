extends "res://tests/support/network_ui_base.gd"

func run():
 app=load("res://main.tscn").instantiate();app.account_session_path="res://work/disconnect-wait/account.bin";root.add_child(app);await process_frame
 authority_session=Session.new();client_session=Session.new();root.add_child(authority_session);root.add_child(client_session)
 authority_session.initialize("res://work/disconnect-wait/ui-host")
 client_session.initialize("res://work/disconnect-wait/ui-guest")
 app.lan_session=client_session;app.online();await process_frame
 expect(authority_session.create_room(3,false,47991,"127.0.0.1").is_empty(),"host creates room")
 expect(client_session.join_room("127.0.0.1",47991).is_empty(),"guest connects")
 expect(await until(func():return not authority_session.applicant.is_empty()),"host receives guest request")
 authority_session.accept_applicant(true)
 expect(await until(func():return authority_session.can_act() and client_session.can_act()),"both players synchronize")
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 for seat in [0,1]:authority_session.handle_room_action(seat,{"name":"deck","deck":decks[seat]})
 for seat in [0,1]:authority_session.handle_room_action(seat,{"name":"ready"})
 authority_session.handle_room_action(authority_session.series.state.chooser,{"name":"first","first":true})
 expect(await until(func():return not client_session.latest_snapshot.is_empty()),"game reaches battlefield")
 app.return_network_battle();view=app.duel_view
 await until(func():return not view.revealing())
 client_session.room.undo_request={"id":"pending","from":0};view.network_changed()
 client_session.on_disconnect(1);client_session.transport.close();client_session.retry_at=Time.get_ticks_msec()+60000
 authority_session.on_disconnect(authority_session.remote_peer);authority_session.transport.drop(authority_session.remote_peer)
 await process_frame
 expect(find_button(view.ui,"不再等待，离开对局")!=null and view.network_status_label.text.contains("秒"),"exit is available during initial countdown even after another lock")
 expect(find_button(view.ui,"继续等待")==null,"continue choice appears after 30 seconds")
 client_session.cloud_ranked=true;client_session.cloud_match_id="TEST_ONLY_WAIT_MATCH"
 var saved_room=client_session.room_id;var saved_resume=client_session.identity.resume.duplicate(true)
 for mobile in [false,true]:
  app.is_android=mobile;app.return_network_battle();view=app.duel_view
  await until(func():return not view.revealing());view.render();await process_frame
  expect(find_button(view.ui,"不再等待，离开对局")==null and view.network_status_label!=null,"ranked battlefield hides abandon waiting for "+str(mobile))
  client_session.check_reconnect_timeout(client_session.disconnected_at+30000);view.network_changed();await process_frame
  expect(not client_session.wait_choice_pending and find_button(view.ui,"继续等待")==null,"ranked outage automatically keeps recovering for "+str(mobile))
  client_session.stop_waiting()
  expect(client_session.room_id==saved_room and client_session.identity.resume==saved_resume,"ranked abandon callback cannot erase recovery for "+str(mobile))
  app.online();await process_frame
  var lobby=app.screen.get_children().filter(func(child):return child.get_script()==preload("res://net/lan_lobby.gd"))[0]
  expect(not lobby.back_button.visible and find_button(lobby.body,"不再等待，离开对局")==null,"ranked lobby hides its exit during a battle outage for "+str(mobile))
 client_session.cloud_ranked=false;client_session.cloud_match_id="";app.is_android=false;app.return_network_battle();view=app.duel_view
 await until(func():return not view.revealing())
 client_session.check_reconnect_timeout(client_session.disconnected_at+30000);view.render();await process_frame
 expect(find_button(view.ui,"继续等待")!=null and find_button(view.ui,"不再等待，离开对局")!=null,"both choices appear after 30 seconds")
 await press("继续等待")
 expect(client_session.wait_choice_confirmed and find_button(view.ui,"不再等待，离开对局")!=null,"exit remains available during indefinite wait")
 await press("不再等待，离开对局")
 expect(app.page=="online" and client_session.room_id.is_empty() and client_session.identity.resume.is_empty(),"exit returns to room list without an active match")
 authority_session.leave(false);client_session.leave(false)
 print("DISCONNECT WAIT UI ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
