extends "res://tests/support/network_ui_base.gd"
const Series=preload("res://net/series_controller.gd")
const Fixtures=preload("res://tests/support/sideboard_fixtures.gd")

func lobby_node():
 for child in app.screen.get_children():
  if child.get_script()==preload("res://net/lan_lobby.gd"):return child
 return null

func capture(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/bo1-sideboard-ui-"+name+".png")

func check_formats(lobby):
 expect(lobby.format_input.item_count==3 and lobby.format_input.get_item_id(0)==Series.BO3 and lobby.format_input.get_item_id(1)==Series.BO1 and lobby.format_input.get_item_id(2)==Series.BO1_SIDEBOARD,"format selector includes BO3, BO1 and BO1 with sideboarding")
 lobby.format_input.select(2)
 expect(lobby.format_input.get_selected_id()==Series.BO1_SIDEBOARD,"new option sends its own protocol value")

func move_reserves(count: int):
 for i in range(count):app.drop_editor_card({"card_id":app.draft.side[i],"source_zone":"side","source_index":i},"main",i,true)

func touch_card(at: Vector2,pressed: bool):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=pressed
 root.push_input(event,true);await process_frame

func check_leader_card(id: String):
 var tile=app.screen.find_child("OpponentLeaderCard",true,false)
 expect(tile!=null and tile.card_id==id and tile.picture.texture!=null,"opponent card has the revealed leader artwork")
 if tile==null:return
 expect(app.ui_metrics.safe.grow(1).encloses(tile.get_global_rect()),"opponent card fits within the screen safe area")
 var before=app.draft.duplicate(true);var selected=app.selected
 var at=tile.get_global_rect().get_center()
 if app.is_android:
  await touch_card(at,true);await touch_card(at,false);await create_timer(1.12).timeout
  expect(not is_instance_valid(tile.overlay),"short touch leaves opponent details closed")
  await touch_card(at,true)
  var motion=InputEventScreenDrag.new();motion.index=0;motion.position=at+Vector2(30,0)
  root.push_input(motion,true);await touch_card(motion.position,false);await create_timer(1.12).timeout
  expect(not is_instance_valid(tile.overlay),"moving the finger cancels opponent inspection")
  await touch_card(at,true);await create_timer(1.12).timeout
  expect(is_instance_valid(tile.overlay),"native one-second hold opens opponent details")
  await touch_card(at,false)
 else:
  var event=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=true
  root.push_input(event,true);await process_frame
  event=event.duplicate();event.pressed=false;root.push_input(event,true);await process_frame
  expect(is_instance_valid(tile.overlay),"right click opens opponent details")
 if is_instance_valid(tile.overlay):
  var art=tile.overlay.find_child("CardInspectionArt",true,false) as TextureRect
  expect(art!=null and art.texture==tile.picture.texture,"details keep the displayed opponent artwork")
  expect(app.ui_metrics.safe.grow(1).encloses(tile.popup.get_global_rect()),"opponent details fit the screen safe area")
  expect(tile.overlay.find_child("CardInspectionRules",true,false)!=null,"opponent details include full card rules")
  await capture(("android" if app.is_android else "desktop")+"-"+app.page+"-details")
  tile.close_details();await process_frame
 expect(app.draft==before and app.selected==selected,"opponent inspection leaves the player's deck and selection unchanged")

func run():
 root.size=Vector2i(1600,900);root.gui_embed_subwindows=true
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/bo1-sideboard-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate()
 var local_fixture="res://work/bo1-sideboard-ui/"+str(Time.get_ticks_usec())
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(local_fixture+"/tutorials"))
 app.settings_path=local_fixture+"/settings.json";app.account_session_path=local_fixture+"/account.json";app.tutorial_local_directory=local_fixture+"/tutorials"
 root.add_child(app);await process_frame
 app.load_legacy_test_decks()
 authority_session=Session.new();client_session=Session.new();root.add_child(authority_session);root.add_child(client_session)
 var run_id=str(Time.get_ticks_usec())
 authority_session.initialize("res://work/bo1-sideboard-ui/%s-host" % run_id);client_session.initialize("res://work/bo1-sideboard-ui/%s-guest" % run_id)
 app.lan_session=client_session;app.online();await process_frame
 var lobby=lobby_node();lobby.mode_selected=true;lobby.refresh(true);await process_frame;check_formats(lobby)
 lobby.cloud_selected=true;lobby.refresh(true);await process_frame;check_formats(lobby)
 lobby.cloud_selected=false;app.is_android=true;app.refresh_ui_metrics();app.online();await process_frame
 lobby=lobby_node();lobby.mode_selected=true;lobby.cloud_selected=false;lobby.refresh(true);await process_frame;check_formats(lobby)
 app.is_android=false;app.refresh_ui_metrics()
 expect(authority_session.create_room(Series.BO1_SIDEBOARD,true,48033,"127.0.0.1","test").is_empty(),"create UI test room")
 client_session.join_room("127.0.0.1",48033)
 if not await until(func():return not authority_session.applicant.is_empty()):
  expect(false,"UI guest handshake");authority_session.leave(false);client_session.leave(false);quit(1);return
 authority_session.accept_applicant(true);await until(func():return client_session.can_act())
 var decks=[Fixtures.deck("70","BO1 换备牌界面测试"),Fixtures.deck("68","BO1 换备牌界面测试")]
 var variants=app.CardArt.options(decks[0].leader,Store.CARDS)
 if not variants.is_empty():decks[0].art_overrides={decks[0].leader:variants.back().id}
 for seat in [0,1]:authority_session.handle_room_action(seat,{"name":"deck","deck":decks[seat]})
 for seat in [0,1]:authority_session.handle_room_action(seat,{"name":"ready"})
 expect(await until(func():return client_session.room.get("status","")=="sideboarding" and client_session.can_act()),"preparation is synchronized")
 app.online();await process_frame
 var reveal=app.screen.find_child("OpponentLeaderReveal",true,false) as Label
 expect(reveal!=null and reveal.text.contains(Store.CARDS[decks[0].leader].name),"desktop room tells the player the opposing leader")
 expect(find_button(app.screen,"调整主副卡组")!=null and find_button(app.screen,"选择此卡组")==null,"revealed phase offers sideboarding instead of full deck replacement")
 await check_leader_card(decks[0].leader)
 await capture("desktop-room")
 var previous=app.draft.duplicate(true);var previous_dirty=app.dirty
 find_button(app.screen,"调整主副卡组").pressed.emit();await process_frame
 expect(app.page=="sideboard" and app.sideboard_original==decks[1],"desktop opens registered sideboard editor")
 var instructions=app.screen.find_child("SideboardInstructions",true,false) as Label
 expect(instructions!=null and instructions.text.contains("3 张") and app.sideboard_info.text.contains(Store.CARDS[decks[0].leader].name),"editor explains the limit and opposing leader")
 expect(instructions.get_global_rect().end.x<=app.screen.get_global_rect().end.x,"desktop instructions fit within the screen")
 expect(app.sideboard_leader_card.picture.texture.resource_path==app.CardArt.image_path(decks[0].leader,app.CardArt.selected(decks[0],decks[0].leader,Store.CARDS),Store.CARDS),"revealed artwork comes from the opponent's registration")
 await check_leader_card(decks[0].leader)
 move_reserves(4)
 expect(app.sideboard_info.text.contains("4 / 3"),"live count handles repeated copies")
 app.complete_sideboard()
 expect(app.page=="sideboard" and app.sideboard_status.text.contains("3") and client_session.room.own_deck==decks[1],"fourth swap is blocked before network submission")
 app.drop_editor_card({"card_id":app.draft.main[3],"source_zone":"main","source_index":3},"side",3,true)
 expect(app.sideboard_status.text.is_empty() and app.sideboard_info.text.contains("3 / 3"),"undoing the excess swap updates the count and clears the error")
 await capture("desktop-editor")
 var submitted=app.draft.duplicate(true)
 app.complete_sideboard()
 expect(await until(func():return app.page=="online" and client_session.room.own_deck==submitted),"valid three-card change returns to room")
 expect(app.draft==previous and app.dirty==previous_dirty,"normal deck draft is restored after sideboarding")
 app.open_sideboard(client_session);await process_frame
 expect(app.sideboard_original==decks[1] and app.sideboard_info.text.contains("3 / 3"),"reopening uses the original registration and retains the count")
 app.online();await process_frame
 root.size=Vector2i(1280,720);app.is_android=true;app.layout_dpi_override=160.0;app.refresh_ui_metrics();app.online();await process_frame
 reveal=app.screen.find_child("OpponentLeaderReveal",true,false) as Label
 expect(reveal!=null and reveal.text.contains(Store.CARDS[decks[0].leader].name),"Android room also reveals the opposing leader")
 await check_leader_card(decks[0].leader)
 await capture("android-room")
 app.open_sideboard(client_session);await process_frame
 expect(app.page=="sideboard" and app.sideboard_info.text.contains("3 / 3") and app.sideboard_info.text.contains(Store.CARDS[decks[0].leader].name),"Android editor shows opposing leader and original swap count")
 expect(is_instance_valid(app.sideboard_done) and not app.sideboard_done.disabled,"Android editor can confirm legal swaps")
 await check_leader_card(decks[0].leader)
 await capture("android-editor")
 app.layout_dpi_override=360.0;app.refresh_ui_metrics();app.editor(true);await process_frame;await process_frame
 expect(app.ui_metrics.safe.grow(1).encloses(app.sideboard_done.get_global_rect()),"high-density Android keeps the confirmation button on screen")
 await check_leader_card(decks[0].leader)
 await capture("android-dense-editor")
 app.online();await process_frame
 client_session.room_action({"name":"ready"});await until(func():return client_session.room.ready[1] and client_session.can_act())
 expect(find_button(app.screen,"调整主副卡组").disabled,"prepared player cannot reopen sideboard editor")
 client_session.room_action({"name":"unready"});await until(func():return not client_session.room.ready[1] and client_session.can_act())
 expect(not find_button(app.screen,"调整主副卡组").disabled,"canceling readiness restores editor access")
 authority_session.leave(false);client_session.leave(false)
 print("BO1 SIDEBOARD UI ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
