extends "res://tests/test_v0181_ui.gd"

func capture(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v1/"+name+".png")
func tap(title: String):
 var button=find_button(app.screen,title);expect(button!=null,"button exists: "+title)
 if button:await click(button.get_global_rect().get_center())
func deck_tile(node: Node,zone: String,index: int):
 if node.get_script()==load("res://scripts/deck_card.gd") and node.source_zone==zone and node.source_index==index:return node
 for child in node.get_children():
  var found=deck_tile(child,zone,index)
  if found:return found
 return null
func sync_sessions():
 for session in [authority_session,client_session]:
  while not session.snapshots.is_empty():session.pop_snapshot()

func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 await capture("menu-1.0")
 authority_session=Session.new();client_session=Session.new();root.add_child(authority_session);root.add_child(client_session)
 authority_session.initialize("res://work/v1/ui-host");client_session.initialize("res://work/v1/ui-guest")
 app.lan_session=client_session;app.online();await process_frame
 authority_session.create_room(3,true,47982,"127.0.0.1");client_session.join_room("127.0.0.1",47982)
 expect(await until(func():return not authority_session.applicant.is_empty()),"UI guest handshake")
 authority_session.accept_applicant(true);await until(func():return client_session.can_act())
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 for seat in [0,1]:
  decks[seat].side=decks[seat].main.slice(0,10)
  expect(Store.validate(decks[seat],true).is_empty(),"strict legal sideboard fixture")
  authority_session.handle_room_action(seat,{"name":"deck","deck":decks[seat]})
 for seat in [0,1]:authority_session.handle_room_action(seat,{"name":"ready"})
 authority_session.handle_room_action(authority_session.series.state.chooser,{"name":"first","first":true})
 await until(func():return not client_session.latest_snapshot.is_empty());sync_sessions()
 authority_session.submit({"name":"surrender","args":[]})
 await until(func():return client_session.room.get("status")=="between");sync_sessions()
 app.online();await process_frame
 var original=client_session.room.own_deck.duplicate(true)
 app.draft=app.decks[0].duplicate(true);app.dirty=true;var previous=app.draft.duplicate(true)
 await tap("调整主副卡组")
 expect(app.page=="sideboard" and is_instance_valid(app.preview),"sideboarding opens the graphical editor and preview")
 expect(not is_instance_valid(app.library) and find_button(app.screen,"保存")==null and find_button(app.screen,"设为自机")==null,"library and persistent editing controls are absent")
 expect(deck_tile(app.deck_canvas,"leader",0)!=null and app.draft.main.size()==50 and app.draft.side.size()==10,"leader and all registered cards are shown")
 var initial=app.draft.duplicate(true)
 app.drop_editor_card({"card_id":initial.leader,"source_zone":"leader","source_index":0},"main")
 expect(app.draft==initial,"sideboarding cannot move the designated leader")
 app.drop_editor_card({"card_id":"53","source_zone":"library","source_index":0},"main")
 expect(app.draft==initial,"sideboarding cannot introduce outside cards")
 var first=deck_tile(app.deck_canvas,"main",0)
 await click(first.get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
 expect(app.draft==initial,"right click previews without deleting registered cards")
 await click(first.get_global_rect().get_center())
 expect(app.draft.main.size()==49 and app.draft.side.size()==11,"click moves main card to side even while rearranging a full sideboard")
 await tap("更换完成")
 expect(app.page=="sideboard" and app.sideboard_status.text.contains("副卡组") and client_session.room.own_deck==original,"invalid counts cannot submit or leave editor")
 # Move an original side card back by real mouse drag using the shared editor.
 var reserve=deck_tile(app.deck_canvas,"side",0)
 await drag(reserve.get_global_rect().get_center(),app.main_content.get_global_rect().position+Vector2(820,465))
 expect(app.draft.main.size()==50 and app.draft.side.size()==10,"drag moves a side card back to main")
 expect(app.sideboard_status.text.is_empty(),"editing clears obsolete validation message")
 await tap("排序卡组")
 expect(Session.Series.sideboard_error(app.draft,original,true).is_empty(),"completed exchange preserves registered multiset and strict rules")
 var submitted=app.draft.duplicate(true)
 await capture("bo3-sideboard")
 await tap("更换完成")
 expect(await until(func():return app.page=="online" and client_session.room.own_deck==submitted),"successful authority acknowledgment returns to previous room")
 expect(authority_session.series.state.decks[1]==submitted,"host stores exactly the graphical sideboard result")
 expect(app.draft==previous and app.dirty,"sideboarding preserves the player's unsaved normal editor draft")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"sideboarding never overwrites saved decks")
 await tap("调整主副卡组");await click(deck_tile(app.deck_canvas,"main",0).get_global_rect().get_center());await tap("返回")
 expect(client_session.room.own_deck==submitted and app.draft==previous,"leaving unfinished sideboarding discards only its draft")
 await tap("准备");await until(func():return client_session.room.ready[1])
 expect(find_button(app.screen,"调整主副卡组").disabled,"ready player cannot silently alter registered cards")
 await tap("取消准备");await until(func():return not client_session.room.ready[1])
 expect(not find_button(app.screen,"调整主副卡组").disabled,"cancel ready restores sideboarding")
 for seat in [0,1]:authority_session.handle_room_action(seat,{"name":"ready"})
 authority_session.handle_room_action(authority_session.series.state.chooser,{"name":"first","first":true})
 await until(func():return client_session.room.status=="playing" and client_session.room.round==2)
 app.return_network_battle();view=app.duel_view
 await until(func():return not view.revealing());await settle()
 var uid=view.engine.players[1].hand[0].uid
 view.hand_clicked(uid);expect(uid in view.selection,"pre-disconnect mulligan selection works")
 client_session.on_disconnect(1);client_session.transport.close();client_session.retry_at=Time.get_ticks_msec()+60000
 authority_session.on_disconnect(authority_session.remote_peer);authority_session.transport.drop(authority_session.remote_peer)
 await process_frame
 expect(view.network_locked() and view.selection.is_empty() and view.local.is_empty(),"disconnect immediately clears private selections and locks interaction")
 view.hand_clicked(uid);view.request_cast(uid);view.confirm_trigger()
 expect(view.selection.is_empty() and view.local.is_empty() and find_button(view.ui,"保留")==null,"no actionable hand or turn controls remain while disconnected")
 expect(view.network_status_label.text.contains("秒") and not view.modal,"countdown leaves battlefield visible")
 await click(view.hand_nodes[uid].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
 expect(view.inspect_uid==uid,"right click inspection remains available while paused")
 view.browse_zone(0,"deck");await process_frame
 expect(view.debug_open and view.browser_cards.get_child_count()>0 and view.browser_cards.get_children().all(func(n):return n.get_meta("display_id")=="back"),"paused player can inspect piles without revealing hidden cards")
 view.close_debug();await capture("disconnect-locked")
 client_session.check_reconnect_timeout(client_session.disconnected_at+30000);await process_frame
 expect(client_session.ended() and view.network_status_label.text.contains("判负"),"timeout shows the entire-match forfeit on the battlefield")
 expect(find_button(view.ui,"返回联机房间")!=null and find_button(view.ui,"保留")==null,"ended game offers exit but no play controls")
 await capture("disconnect-ended")
 await tap("返回联机房间")
 expect(app.page=="online" and find_button(app.screen,"准备")==null and find_button(app.screen,"查看战场")!=null,"aborted room cannot start another BO3 game but permits viewing")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"all UI checks preserve user's saved decks")
 authority_session.leave(false);client_session.leave(false)
 print("V1 UI ",checks," checks; ",failures," failures")
 quit(0 if failures.is_empty() else 1)
