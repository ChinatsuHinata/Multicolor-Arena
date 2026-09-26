extends "res://tests/support/network_ui_base.gd"

func run():
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
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
 client_session.check_reconnect_timeout(client_session.disconnected_at+30000);await process_frame
 expect(find_button(view.ui,"继续等待")!=null and find_button(view.ui,"不再等待，离开对局")!=null,"both choices appear after 30 seconds")
 await press("继续等待")
 expect(client_session.wait_choice_confirmed and find_button(view.ui,"不再等待，离开对局")!=null,"exit remains available during indefinite wait")
 await press("不再等待，离开对局")
 expect(app.page=="online" and client_session.room_id.is_empty() and client_session.identity.resume.is_empty(),"exit returns to room list without an active match")
 authority_session.leave(false);client_session.leave(false)
 print("DISCONNECT WAIT UI ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
