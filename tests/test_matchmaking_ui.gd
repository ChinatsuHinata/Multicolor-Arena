extends SceneTree
var failures=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 if ok:print("PASS: ",label)
 else:failures.append(label);push_error(label)
func capture(label: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/rank-"+label+".png")

func check_rank_rules(lobby,stage: String):
 var trigger=lobby.body.find_child("RankRulesButton",true,false) as Button
 check(trigger!=null,"rank rules entry is available in "+stage)
 if trigger==null:return
 check(lobby.body.find_child("MatchmakingRangeRules",true,false)==null,"full matching rules move into the popup in "+stage)
 trigger.grab_focus();trigger.pressed.emit()
 for i in range(6):await process_frame
 var popup=app_popup(lobby.app)
 check(popup!=null and popup.layer==popup.TOP_LAYER,"rank rules open above the lobby in "+stage)
 if popup==null:return
 var styles=popup.find_child("RankTierStyles",true,false)
 check(styles!=null and styles.get_child_count()==5,"rank rules display five major tier styles in "+stage)
 var loaded=true
 for tier in range(5):
  var badge=popup.find_child("RankTierImage"+str(tier),true,false)
  var title=popup.find_child("RankTierTitle"+str(tier),true,false) as Label
  loaded=loaded and badge!=null and badge.portrait!=null and badge.tier==tier and title!=null and title.text==preload("res://scripts/rank_badge.gd").TITLES[tier]
 check(loaded,"all five tier images use their real card illustrations and names in "+stage)
 check(lobby.app.ui_metrics.safe.grow(1).encloses(popup.panel.get_global_rect()) and popup.panel.get_global_rect().encloses(popup.close_button.get_global_rect()),"rank popup and close control fit the safe area in "+stage)
 var range_rules=popup.find_child("MatchmakingRangeRules",true,false) as Label
 check(range_rules!=null and range_rules.text.contains("所有级别") and range_rules.text.contains("20 秒") and range_rules.text.contains("1 个大段位") and range_rules.text.contains("贤者排名"),"popup explains major tier priority and expansion in "+stage)
 check(popup.find_child("RankProgressionRules",true,false)!=null and popup.find_child("RankFormatRules",true,false)!=null and popup.find_child("SageRankingRules",true,false)!=null,"popup includes progression, format and Sage settlement in "+stage)
 await capture("rules-"+stage)
 if lobby.app.is_android:
  var start=popup.scroll.get_global_rect().get_center()+Vector2(0,popup.scroll.size.y*0.25)
  var touch=InputEventScreenTouch.new();touch.index=0;touch.position=start;touch.pressed=true
  root.push_input(touch,true);await process_frame
  for i in range(1,7):
   var drag=InputEventScreenDrag.new();drag.index=0;drag.position=start-Vector2(0,popup.scroll.size.y*0.08*i);drag.relative=Vector2(0,-popup.scroll.size.y*0.08)
   root.push_input(drag,true);await process_frame
  touch=touch.duplicate();touch.pressed=false;touch.position=start-Vector2(0,popup.scroll.size.y*0.48)
  root.push_input(touch,true);await process_frame
  check(popup.scroll.scroll_vertical>0,"native Android swipe scrolls the rule content in "+stage)
  popup.scroll.scroll_vertical=int(popup.scroll.get_v_scroll_bar().max_value)
  for i in range(4):await process_frame
  var settlement=popup.find_child("SageRankingRules",true,false) as Label
  check(popup.scroll.get_global_rect().grow(1).encloses(settlement.get_global_rect()),"last rule section is reachable without horizontal clipping in "+stage)
  await capture("rules-bottom-"+stage)
 if stage.begins_with("waiting"):
  var event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=true
  root.push_input(event,true)
 else:popup.close_button.pressed.emit()
 await process_frame
 check(not lobby.app.menu_popup_open() and root.gui_get_focus_owner()==trigger,"closing rank rules returns focus to the lobby in "+stage)

func app_popup(app):
 return app.menu_popup if app.menu_popup_open() else null

func run():
 var app=load("res://main.tscn").instantiate()
 var fixture="res://work/matchmaking-ui/"+str(Time.get_ticks_usec())
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture+"/tutorials"))
 app.settings_path=fixture+"/settings.json";app.account_session_path=fixture+"/account.json";app.tutorial_local_directory=fixture+"/tutorials"
 app.Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 root.add_child(app);await process_frame
 app.account_name="TEST_ONLY_MATCH_UI";app.account_nickname="匹配玩家";app.account_token="a".repeat(64)
 for mobile in [false,true]:
  app.match_room_public=true
  app.match_mode="ranked"
  app.is_android=mobile;app.layout_dpi_override=360 if mobile else 0
  root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
  app.menu();await process_frame;await capture("menu-"+str(mobile))
  check(app.screen.find_child("PlayerRank",true,false)!=null,"homepage displays the hexagonal rank")
  check(app.screen.find_children("*","Label",true,false).all(func(label):return not label.text.contains("以色彩") and label.text!="multicolor:arena"),"homepage removes the title and slogan")
  if mobile:
   check(app.screen.find_children("*","ScrollContainer",true,false).is_empty(),"Android homepage has no scrolling container")
   var safe=app.screen.get_global_rect().grow(1)
   check(app.screen.find_children("*","Button",true,false).all(func(button):return safe.encloses(button.get_global_rect())),"all eight Android menu actions fit inside the screen")
  app.online();await process_frame
  var lobby=app.screen.find_child("LanLobby",true,false)
  if lobby==null:
   for child in app.screen.get_children():
    if child.get_script()!=null and child.get_script().resource_path=="res://net/lan_lobby.gd":lobby=child;break
  check(lobby!=null,"lobby opens for "+str(mobile))
  if lobby==null:quit(1);return
  lobby.mode_selected=true;lobby.cloud_selected=true;lobby.cloud_directory.stop();lobby.refresh(true)
  await process_frame
  var start=lobby.body.find_child("StartMatchmaking",true,false) as Button
  check(start!=null and start.disabled,"cloud home requires choosing a deck before matching for "+str(mobile))
  check(lobby.body.find_child("MatchDeckSelect",true,false)!=null and lobby.body.find_child("PlayerRank",true,false)!=null,"match screen offers deck picker and hexagonal rank")
  var privacy=lobby.body.find_child("MatchmakingPrivacy",true,false) as CheckButton
  check(privacy!=null and privacy.button_pressed,"matching defaults to a public room for "+str(mobile))
  if privacy!=null:privacy.button_pressed=false
  var saved_settings=JSON.parse_string(FileAccess.get_file_as_string(app.settings_path))
  check(not app.match_room_public and saved_settings is Dictionary and saved_settings.get("match_room_public",true)==false,"private preference is saved for "+str(mobile))
  lobby.refresh(true);await process_frame
  privacy=lobby.body.find_child("MatchmakingPrivacy",true,false) as CheckButton
  check(privacy!=null and not privacy.button_pressed,"rebuilding the match panel preserves the privacy choice for "+str(mobile))
  check(privacy!=null and app.screen.get_global_rect().grow(1).encloses(privacy.get_global_rect()),"privacy toggle fits inside the screen for "+str(mobile))
  check(privacy!=null and privacy.text_overrun_behavior==TextServer.OVERRUN_NO_TRIMMING,"privacy toggle keeps its complete label for "+str(mobile))
  check(lobby.body.find_child("RoomResponseTimer",true,false)==null,"room creation has no response timer mode")
  check(lobby.queue_caption(0).contains("暂无") and lobby.queue_caption(3).contains("3 人") and lobby.queue_caption(1,true).contains("暂无其他"),"queue labels distinguish nobody, others, and only yourself")
  await capture("match-"+str(mobile))
  var rules=lobby.body.find_child("MatchmakingRules",true,false) as Label
  check(rules!=null and rules.text.contains("官限") and rules.text.contains("固定"),"cloud home explains the fixed official rule set for "+str(mobile))
  await check_rank_rules(lobby,"home-"+str(mobile))
  if mobile:
   (lobby.body.find_child("CloudRoomsTab",true,false) as Button).pressed.emit()
   await process_frame
  lobby.cloud_directory.rooms=[{"id":"ABCDEF012345","name":"自动匹配","format":2,"status":"lobby","watch_only":true,"version":lobby.session.fingerprint,"seats":["玩家一","玩家二","","","","","",""]}]
  lobby.refresh_cloud_rooms();await process_frame
  var entries=lobby.cloud_rooms_list.find_children("*","Button",true,false)
  check(entries.size()==1 and entries[0].text.contains("观战") and not entries[0].disabled,"matched lobby exposes only the spectator entrance for "+str(mobile))
  lobby.cloud_directory.rooms[0].seats=["玩家一","玩家二","观众","观众","观众","观众","观众","观众"]
  lobby.refresh_cloud_rooms();await process_frame
  entries=lobby.cloud_rooms_list.find_children("*","Button",true,false)
  check(entries.size()==1 and entries[0].disabled,"full match spectator seats disable entry for "+str(mobile))
  if mobile:
   (lobby.body.find_child("CloudMatchTab",true,false) as Button).pressed.emit()
   await process_frame
  var session=lobby.session;session.storage=fixture+"/network"
  var queue_deck=app.Store.clean_deck(JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks[0])
  var mode=lobby.body.find_child("MatchmakingMode",true,false) as OptionButton
  check(mode!=null and mode.selected==0,"matching offers a mode selector and defaults to ranked for "+str(mobile))
  check(mode.text_overrun_behavior==TextServer.OVERRUN_NO_TRIMMING,"mode selector preserves its full casual and unrestricted label for "+str(mobile))
  mode.item_selected.emit(1);await process_frame
  rules=lobby.body.find_child("MatchmakingRules",true,false) as Label
  saved_settings=JSON.parse_string(FileAccess.get_file_as_string(app.settings_path))
  check(app.match_mode=="casual" and saved_settings.get("match_mode","")=="casual" and rules.text.contains("无限制"),"casual mode persists and changes the rules for "+str(mobile))
  check(lobby.body.find_child("PlayerRank",true,false)==null and lobby.body.find_child("CasualMatchHint",true,false)!=null and (lobby.body.find_child("MatchmakingHeading",true,false) as Label).text=="休闲模式","casual home displays its mode without a rank badge for "+str(mobile))
  mode=lobby.body.find_child("MatchmakingMode",true,false) as OptionButton
  check(app.screen.get_global_rect().grow(1).encloses(mode.get_global_rect()),"casual selector fits the screen for "+str(mobile))
  await capture("casual-home-"+str(mobile))
  var unrestricted=queue_deck.duplicate(true);unrestricted.side=["new-spx-001"]
  check(not app.Store.validate(unrestricted,true,session.MATCH_RULE_SET).is_empty(),"casual fixture is excluded from ranked matching")
  app.decks.append(unrestricted);lobby.select_match_deck(app.decks.size()-1)
  check(lobby.match_deck_index==app.decks.size()-1,"casual deck picker accepts unrestricted cards for "+str(mobile))
  check(session.start_matchmaking("ws://127.0.0.1:1",unrestricted,false,"casual").is_empty() and session.transport.relay_options.mode=="casual","queue request locks in casual mode and unrestricted deck for "+str(mobile))
  session.transport.relay_match_queued.emit(20,1,1);lobby.refresh(true);await process_frame
  check(lobby.body.find_child("MatchmakingMode",true,false)==null and (lobby.body.find_child("MatchmakingStatus",true,false) as Label).text.contains("不限段位") and session.match_mode=="casual","casual queue locks switching and shows unrestricted opponent ranks for "+str(mobile))
  await capture("casual-wait-"+str(mobile))
  session.cancel_matchmaking();lobby.refresh(true)
  mode=lobby.body.find_child("MatchmakingMode",true,false) as OptionButton;mode.item_selected.emit(0);await process_frame
  check(lobby.match_deck_index==-1 and (lobby.body.find_child("StartMatchmaking",true,false) as Button).disabled,"returning to ranked clears an incompatible selected deck for "+str(mobile))
  app.decks.pop_back()
  check(session.start_matchmaking("ws://127.0.0.1:1",queue_deck,app.match_room_public).is_empty() and not session.match_room_public and session.transport.relay_options.get("public",true)==false,"private preference is locked into the queue request for "+str(mobile))
  session.cancel_matchmaking()
  session.matchmaking=true;session.cloud_mode=true;session.cloud_ranked=true
  session.match_room_public=false
  session.transport.relay_match_queued.emit(0,0,1)
  check(session.match_rank_gap==0 and session.notice.contains("同一大段位内所有级别"),"initial queue status includes all levels of the same major tier")
  session.transport.relay_match_queued.emit(20,1,3)
  lobby.refresh(true);await process_frame
  var status=lobby.body.find_child("MatchmakingStatus",true,false) as Label
  var cancel=lobby.body.find_child("CancelMatchmaking",true,false) as Button
  rules=lobby.body.find_child("MatchmakingRules",true,false) as Label
  check(rules!=null and rules.text.contains("官限") and rules.text.contains("固定"),"waiting view retains the fixed official rule set for "+str(mobile))
  check(status!=null and status.text.contains("0:20") and cancel!=null and not cancel.disabled,"waiting view displays progress and cancel for "+str(mobile))
  check(session.match_rank_gap==1 and status.text.contains("上下 1 个大段位") and not status.text.contains("分差"),"waiting progress displays the expanded major tier range")
  await check_rank_rules(lobby,"waiting-"+str(mobile))
  check(session.matchmaking and lobby.body.find_child("CancelMatchmaking",true,false)==cancel,"reading and closing rank rules keeps the active queue")
  check(lobby.body.find_child("StartMatchmaking",true,false)==null and lobby.header_mode_button==null,"waiting view prevents concurrent matching and mode switching")
  var privacy_status=lobby.body.find_child("MatchmakingPrivacyStatus",true,false) as Label
  check(privacy_status!=null and privacy_status.text.contains("私人") and lobby.body.find_child("MatchmakingPrivacy",true,false)==null,"waiting view shows the locked privacy choice for "+str(mobile))
  if cancel!=null:cancel.pressed.emit()
  await process_frame
  check(not session.matchmaking and lobby.body.find_child("StartMatchmaking",true,false)!=null,"cancel returns to cloud home")
  check(not app.match_room_public and not (lobby.body.find_child("MatchmakingPrivacy",true,false) as CheckButton).button_pressed,"cancel retains the privacy preference for "+str(mobile))
  session.cloud_mode=true;session.matchmaking=true
  session.match_deck=app.Store.clean_deck(JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks[0])
  var match_ranks=[{"tier":2,"level":1,"stars":2},{"tier":1,"level":3,"stars":1}]
  session.on_match_found({"deck_hashes":[JSON.stringify(session.match_deck).sha256_text(),"x"],"ranks":match_ranks,"match_id":"TEST_ONLY_UI_MATCH","room":"TEST_ONLY_UI_ROOM","role":"host","seat":1,"format":session.Series.BO3,"rule_set":"test","public":false})
  check(session.room.rule_set=="official" and session.room.strict and session.room.format==session.Series.BO1_SIDEBOARD,"matched session locks official rules even with different supplied options")
  session.series.state.names=["匹配玩家","对手"];session.room=session.series.public_state(0)
  session.cloud_seats=["匹配玩家","对手","","","","","",""];session.cloud_room_name="自动匹配"
  lobby.refresh(true);await process_frame
  privacy_status=lobby.body.find_child("MatchedRoomPrivacy",true,false) as Label
  check(not session.match_room_public and privacy_status!=null and privacy_status.text.contains("私人"),"matched room shows the server's final privacy setting for "+str(mobile))
  check(lobby.body.find_child("CloudSeat1",true,false)==null and lobby.body.find_child("NetworkDeckSelect",true,false)==null,"matched room cannot change its preselected deck")
  check(not lobby.back_button.visible and lobby.back_button.disabled and lobby.body.find_children("*","Button",true,false).all(func(button):return not button.text.contains("离开")),"matched lobby has no return or leave entrance for "+str(mobile))
  var matched_room_id=session.room_id
  lobby.back_button.pressed.emit();await process_frame
  check(app.page=="online" and session.room_id==matched_room_id,"hidden header callback cannot leave matched preparation for "+str(mobile))
  session.series.set_deck(1,session.match_deck);session.series.ready(1);session.series.prepare_choice()
  session.room=session.series.public_state(0);session.connected=true;session.paused=false
  lobby.refresh(true);await process_frame
  check(session.room.status=="sideboarding" and lobby.body.find_child("OpponentLeaderReveal",true,false)!=null,"matched preparation reveals leaders for "+str(mobile))
  check(not lobby.back_button.visible and lobby.body.find_children("*","Button",true,false).all(func(button):return not button.text.contains("离开")),"leader reveal and sideboarding have no exit button for "+str(mobile))
  app.open_sideboard(session);await process_frame
  check(app.page=="sideboard","matched sideboard editor opens for "+str(mobile))
  check(app.sideboard_info.text.contains("对方段位：妖精级 3 · ★☆☆"),"host sideboard displays the opposing rank and stars for "+str(mobile))
  session.seat=1;session.room=session.series.public_state(1);app.sideboard_changed()
  check(app.sideboard_info.text.contains("对方段位：天狗级 1 · ★★☆"),"guest sideboard uses the opposite battle seat's rank for "+str(mobile))
  session.series.state.ranks[0]={"tier":4,"position":8};session.room=session.series.public_state(1);app.sideboard_changed()
  check(app.sideboard_info.text.contains("对方段位：贤者 · 第 8 名"),"sideboard displays the opposing Sage position for "+str(mobile))
  session.room.erase("ranks");app.sideboard_changed()
  check(not app.sideboard_info.text.contains("对方段位") and app.sideboard_info.text.contains("对方自机") and app.sideboard_info.text.contains("0 / 3"),"missing rank data preserves leader reveal and swap count for "+str(mobile))
  session.seat=0;session.series.state.ranks=match_ranks.duplicate(true);session.room=session.series.public_state(0);app.sideboard_changed()
  for i in range(4):await process_frame
  check(app.screen.get_global_rect().grow(1).encloses(app.sideboard_info.get_global_rect()) and app.sideboard_info.get_global_rect().end.y<=app.sideboard_status.get_global_rect().position.y and app.sideboard_info.get_visible_line_count()==app.sideboard_info.get_line_count(),"opponent rank and swap count fit without clipping or status overlap for "+str(mobile))
  await capture("sideboard-"+str(mobile))
  var editor_back: Button
  for button in app.screen.find_children("*","Button",true,false):
   if button.text=="返回":editor_back=button
  check(editor_back!=null,"matched sideboard editor can return to preparation for "+str(mobile))
  if editor_back!=null:editor_back.pressed.emit()
  await process_frame
  lobby=app.screen.find_child("LanLobby",true,false)
  if lobby==null:
   for child in app.screen.get_children():
    if child.get_script()!=null and child.get_script().resource_path=="res://net/lan_lobby.gd":lobby=child;break
  check(app.page=="online" and session.room_id==matched_room_id and not lobby.back_button.visible,"returning from the editor keeps the match and exit lock for "+str(mobile))
  session.disconnected_at=1;lobby.refresh(true);await process_frame
  check(not lobby.back_button.visible and lobby.body.find_children("*","Button",true,false).all(func(button):return not button.text.contains("离开")),"sideboarding disconnection preserves the exit lock while waiting for settlement for "+str(mobile))
  session.disconnected_at=0;session.room.status="choosing";session.room.chooser=1;session.room.roll={"values":[6,1]}
  lobby.refresh(true);await process_frame
  check(not lobby.back_button.visible and lobby.body.find_children("*","Button",true,false).all(func(button):return not button.text.contains("离开")),"matched first-player selection keeps the exit lock for "+str(mobile))
  session.room.status="complete";session.room.winner=0;lobby.refresh(true);await process_frame
  var return_button: Button
  for button in lobby.body.find_children("*","Button",true,false):
   if button.text=="返回云端，重新匹配":return_button=button
  check(return_button!=null and return_button.disabled,"return waits until Elo settlement")
  session.match_settled=true;lobby.refresh(true);await process_frame
  for button in lobby.body.find_children("*","Button",true,false):
   if button.text=="返回云端，重新匹配":return_button=button
  check(return_button!=null and not return_button.disabled,"settlement enables matching again")
  session.room.status="aborted";lobby.refresh(true);await process_frame
  check(lobby.back_button.visible and not lobby.back_button.disabled,"settled cancellation restores return for "+str(mobile))
  session.match_settled=false;session.read_only=true;session.room.status="sideboarding";lobby.refresh(true);await process_frame
  check(lobby.back_button.visible and lobby.body.find_children("*","Button",true,false).any(func(button):return button.text=="离开观战"),"spectators can leave during ranked sideboarding for "+str(mobile))
  session.cloud_ranked=false;session.read_only=false;lobby.refresh(true);await process_frame
  check(lobby.back_button.visible and lobby.body.find_children("*","Button",true,false).any(func(button):return button.text=="离开房间"),"custom rooms retain their sideboarding leave action for "+str(mobile))
  session.leave(false)
  session.matchmaking=true;session.cloud_mode=true;session.cloud_ranked=true;session.match_mode="casual";session.match_deck=unrestricted
  session.on_match_found({"deck_hashes":[JSON.stringify(unrestricted).sha256_text(),"x"],"mode":"casual","match_id":"TEST_ONLY_CASUAL_UI","room":"TEST_ONLY_CASUAL_ROOM","role":"host","seat":1,"rule_set":"unrestricted","public":true})
  check(session.room.rule_set=="unrestricted" and session.room.match_mode=="casual" and not session.room.ranked,"casual initialization keeps unrestricted rules for "+str(mobile))
  check(session.Journal.load_from(session.storage+"/host.bin").get("match_mode","")=="casual" and session.saved_ranked_recovery().get("match_mode","")=="casual","casual recovery saves the locked mode for "+str(mobile))
  session.on_match_settled({"match_id":session.cloud_match_id,"winner":0,"rated":false,"mode":"casual"})
  check(session.match_settled and session.room.status=="complete" and session.room.winner==0 and session.notice.contains("不影响段位"),"unrated casual completion keeps the winner and explains unchanged rank for "+str(mobile))
  session.leave(false)
 var unsupported=preload("res://net/lan_session.gd").new();root.add_child(unsupported);unsupported.initialize(fixture+"/unsupported")
 var privacy_errors=[];unsupported.error_raised.connect(func(message):privacy_errors.append(message))
 unsupported.matchmaking=true;unsupported.match_room_public=false
 unsupported.on_match_found({"match_id":"TEST_ONLY_OLD_SERVER","public":true})
 check(not unsupported.matchmaking and unsupported.room_id.is_empty() and not privacy_errors.is_empty(),"unconfirmed private matching cannot silently become public on an older server")
 unsupported.matchmaking=true;unsupported.match_mode="casual"
 unsupported.on_match_found({"match_id":"TEST_ONLY_OLD_SERVER","public":true,"rule_set":"official"})
 check(not unsupported.matchmaking and unsupported.room_id.is_empty() and privacy_errors.back().contains("休闲"),"an older relay cannot silently turn casual matching into ranked matching")
 unsupported.queue_free()
 app.clear_page("menu")
 check(preload("res://scripts/rank_badge.gd").caption({"tier":4,"position":8})=="贤者 · 第 8 名","Sage rank uses the shortened name and keeps its leaderboard position")
 var ranks=HBoxContainer.new();app.screen.add_child(ranks);ranks.position=Vector2(30,120);ranks.size=Vector2(1200,180)
 for tier in range(5):
  app.account_rank={"tier":tier,"level":1,"stars":2,"position":8}
  var display=app.rank_display(ranks);display.custom_minimum_size=Vector2(240,140)
 await process_frame;await capture("portraits")
 app.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
