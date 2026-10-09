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

func run():
 var app=load("res://main.tscn").instantiate()
 var fixture="res://work/matchmaking-ui/"+str(Time.get_ticks_usec())
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture+"/tutorials"))
 app.settings_path=fixture+"/settings.json";app.account_session_path=fixture+"/account.json";app.tutorial_local_directory=fixture+"/tutorials"
 app.Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 root.add_child(app);await process_frame
 app.account_name="TEST_ONLY_MATCH_UI";app.account_nickname="匹配玩家";app.account_token="a".repeat(64)
 for mobile in [false,true]:
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
  check(lobby.body.find_child("RoomResponseTimer",true,false)==null,"room creation has no response timer mode")
  check(lobby.queue_caption(0).contains("暂无") and lobby.queue_caption(3).contains("3 人") and lobby.queue_caption(1,true).contains("暂无其他"),"queue labels distinguish nobody, others, and only yourself")
  await capture("match-"+str(mobile))
  var rules=lobby.body.find_child("MatchmakingRules",true,false) as Label
  check(rules!=null and rules.text.contains("官限") and rules.text.contains("固定"),"cloud home explains the fixed official rule set for "+str(mobile))
  lobby.cloud_directory.rooms=[{"id":"ABCDEF012345","name":"自动匹配","format":2,"status":"lobby","watch_only":true,"version":lobby.session.fingerprint,"seats":["玩家一","玩家二","","","","","",""]}]
  lobby.refresh_cloud_rooms();await process_frame
  var entries=lobby.cloud_rooms_list.find_children("*","Button",true,false)
  check(entries.size()==1 and entries[0].text.contains("观战") and not entries[0].disabled,"matched lobby exposes only the spectator entrance for "+str(mobile))
  lobby.cloud_directory.rooms[0].seats=["玩家一","玩家二","观众","观众","观众","观众","观众","观众"]
  lobby.refresh_cloud_rooms();await process_frame
  entries=lobby.cloud_rooms_list.find_children("*","Button",true,false)
  check(entries.size()==1 and entries[0].disabled,"full match spectator seats disable entry for "+str(mobile))
  var session=lobby.session;session.storage=fixture+"/network"
  session.matchmaking=true;session.cloud_mode=true;session.cloud_ranked=true;session.notice="正在自动匹配 · 已等待 1:02 · 当前分差范围 200"
  lobby.refresh(true);await process_frame
  var status=lobby.body.find_child("MatchmakingStatus",true,false) as Label
  var cancel=lobby.body.find_child("CancelMatchmaking",true,false) as Button
  rules=lobby.body.find_child("MatchmakingRules",true,false) as Label
  check(rules!=null and rules.text.contains("官限") and rules.text.contains("固定"),"waiting view retains the fixed official rule set for "+str(mobile))
  check(status!=null and status.text.contains("1:02") and cancel!=null and not cancel.disabled,"waiting view displays progress and cancel for "+str(mobile))
  check(lobby.body.find_child("StartMatchmaking",true,false)==null and lobby.header_mode_button==null,"waiting view prevents concurrent matching and mode switching")
  if cancel!=null:cancel.pressed.emit()
  await process_frame
  check(not session.matchmaking and lobby.body.find_child("StartMatchmaking",true,false)!=null,"cancel returns to cloud home")
  session.cloud_mode=true;session.matchmaking=true
  session.match_deck=app.Store.clean_deck(JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks[0])
  session.on_match_found({"deck_hashes":[JSON.stringify(session.match_deck).sha256_text(),"x"],"match_id":"TEST_ONLY_UI_MATCH","room":"TEST_ONLY_UI_ROOM","role":"host","seat":1,"format":session.Series.BO3,"rule_set":"test"})
  check(session.room.rule_set=="official" and session.room.strict and session.room.format==session.Series.BO1_SIDEBOARD,"matched session locks official rules even with different supplied options")
  session.series.state.names=["匹配玩家","对手"];session.room=session.series.public_state(0)
  session.cloud_seats=["匹配玩家","对手","","","","","",""];session.cloud_room_name="自动匹配"
  lobby.refresh(true);await process_frame
  check(lobby.body.find_child("CloudSeat1",true,false)==null and lobby.body.find_child("NetworkDeckSelect",true,false)==null,"matched room cannot change its preselected deck")
  session.room.status="complete";session.room.winner=0;lobby.refresh(true);await process_frame
  var return_button: Button
  for button in lobby.body.find_children("*","Button",true,false):
   if button.text=="返回云端，重新匹配":return_button=button
  check(return_button!=null and return_button.disabled,"return waits until Elo settlement")
  session.match_settled=true;lobby.refresh(true);await process_frame
  for button in lobby.body.find_children("*","Button",true,false):
   if button.text=="返回云端，重新匹配":return_button=button
  check(return_button!=null and not return_button.disabled,"settlement enables matching again")
  session.leave(false)
 app.clear_page("menu")
 var ranks=HBoxContainer.new();app.screen.add_child(ranks);ranks.position=Vector2(30,120);ranks.size=Vector2(1200,180)
 for tier in range(5):
  app.account_rank={"tier":tier,"level":1,"stars":2,"position":8}
  var display=app.rank_display(ranks);display.custom_minimum_size=Vector2(240,140)
 await process_frame;await capture("portraits")
 app.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
