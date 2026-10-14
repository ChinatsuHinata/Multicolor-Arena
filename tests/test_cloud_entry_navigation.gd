extends SceneTree

class LoginReply:
 extends Node
 var session_token="b".repeat(64)
 var remember_token=""
 var nickname="已登录玩家"
 var elo=1000
 var rank={}

var failures=[]

func _initialize():call_deferred("run")

func check(ok: bool,description: String):
 if ok:print("PASS: ",description)
 else:failures.append(description);push_error(description)

func lobby_of(app):
 for child in app.screen.get_children():
  if child.get_script()==preload("res://net/lan_lobby.gd"):return child
 return null

func settle():
 for i in range(3):await process_frame

func run():
 var fixture="res://work/cloud-entry-navigation/"+str(Time.get_ticks_usec())
 var app=preload("res://main.tscn").instantiate()
 app.settings_path=fixture+"/settings.json";app.account_session_path=fixture+"/account.json"
 app.Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 root.add_child(app);await settle()
 app.account_name="cloud_navigation_test";app.account_nickname="测试玩家";app.account_token="a".repeat(64)
 for mobile in [false,true]:
  root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
  app.is_android=mobile;app.layout_dpi_override=360.0 if mobile else 0.0
  app.refresh_ui_metrics();app.menu();await settle()
  var entry=app.screen.find_child("MainMenuActions",true,false).find_children("*","Button",true,false).filter(func(button):return button.text=="联网对战") if mobile else app.screen.find_children("*","Button",true,false).filter(func(button):return button.text=="联网对战")
  check(not entry.is_empty(),"main menu has an online entrance on "+str(mobile))
  if entry.is_empty():continue
  entry[0].pressed.emit();await settle()
  var lobby=lobby_of(app)
  check(lobby!=null and lobby.cloud_selected and lobby.mode_selected,"online opens cloud matchmaking directly on "+str(mobile))
  if lobby==null:continue
  lobby.cloud_directory.stop()
  check(lobby.body.find_child("StartMatchmaking",true,false)!=null and lobby.body.find_child("OnlineModeSelection",true,false)==null,"cloud matchmaking is the initial page on "+str(mobile))
  if mobile:
   check(lobby.cloud_rooms_list==null and lobby.cloud_title_input!=null,"Android starts on matching and room creation")
   var safe_body=lobby.body.get_global_rect().grow(1)
   var create_button=lobby.body.find_child("CreateCloudRoom",true,false) as Button
   var match_button=lobby.body.find_child("StartMatchmaking",true,false) as Button
   check(create_button!=null and match_button!=null and safe_body.encloses(create_button.get_global_rect()) and safe_body.encloses(match_button.get_global_rect()),"Android matching and room creation actions fit in one screen")
   var privacy=lobby.body.find_child("MatchmakingPrivacy",true,false) as CheckButton
   check(privacy!=null and safe_body.encloses(privacy.get_global_rect()),"Android matching privacy toggle fits the screen")
   lobby.cloud_title_input.text="保留房间草稿"
   lobby.cloud_password_input.text="draft-password"
   lobby.format_input.select(1)
   lobby.cloud_host_slot.select(1)
   var rooms_tab=lobby.body.find_child("CloudRoomsTab",true,false) as Button
   check(rooms_tab!=null,"Android has a room-list switch")
   if rooms_tab!=null:rooms_tab.pressed.emit();await settle()
   check(lobby.cloud_home_view=="rooms" and lobby.cloud_rooms_list!=null and lobby.body.find_child("StartMatchmaking",true,false)==null,"Android room list is a separate page")
   lobby.cloud_directory.rooms=[{"id":"TESTROOM12345","name":"测试房间","locked":false,"format":3,"status":"lobby","version":lobby.session.fingerprint,"seats":["房主","","","","","","",""]}]
   lobby.refresh_cloud_rooms();await settle()
   check(lobby.cloud_rooms_list.get_child_count()==1,"Android room list displays discovered rooms")
   var match_tab=lobby.body.find_child("CloudMatchTab",true,false) as Button
   check(match_tab!=null,"Android room list can return to matching")
   if match_tab!=null:match_tab.pressed.emit();await settle()
   check(lobby.cloud_home_view=="match" and lobby.cloud_title_input.text=="保留房间草稿" and lobby.cloud_password_input.text=="draft-password" and lobby.format_input.selected==1 and lobby.cloud_host_slot.selected==1,"switching pages preserves the room draft")
   check(lobby.body.find_child("StartMatchmaking",true,false)!=null and lobby.cloud_rooms_list==null,"match page hides the directory")
  else:
   check(lobby.cloud_rooms_list!=null and lobby.cloud_title_input!=null,"desktop cloud page keeps matching, creation and room list together")
  var lan=lobby.header_mode_button
  check(lan!=null and lan.text=="局域网","LAN remains available from the cloud page on "+str(mobile))
  if lan!=null:lan.pressed.emit();await settle()
  check(not lobby.cloud_selected and lobby.mode_selected,"LAN switch opens the local connection page on "+str(mobile))
  app.menu();await settle()
 app.account_name="";app.account_nickname="";app.account_token=""
 app.menu();await settle()
 var anonymous_entry=app.screen.find_children("*","Button",true,false).filter(func(button):return button.text=="联网对战")
 if not anonymous_entry.is_empty():anonymous_entry[0].pressed.emit();await settle()
 check(app.page=="account" and app.account_notice.contains("云端匹配"),"unauthenticated online entry opens login guidance")
 var back=app.screen.find_children("*","Button",true,false).filter(func(button):return button.text=="返回主菜单")
 if not back.is_empty():back[0].pressed.emit();await settle()
 check(app.page=="menu" and not app.has_meta("online_account_return"),"canceling online login returns to the main menu")
 anonymous_entry=app.screen.find_children("*","Button",true,false).filter(func(button):return button.text=="联网对战")
 if not anonymous_entry.is_empty():anonymous_entry[0].pressed.emit();await settle()
 app.account_action="login";app.account_client=LoginReply.new();app.add_child(app.account_client)
 app.account_request_finished(true,"登录成功","cloud_navigation_test")
 await settle()
 var returned_lobby=lobby_of(app)
 check(app.page=="online" and returned_lobby!=null and returned_lobby.cloud_selected and returned_lobby.body.find_child("StartMatchmaking",true,false)!=null,"successful login returns directly to cloud matchmaking")
 if returned_lobby!=null:returned_lobby.cloud_directory.stop()
 print("CLOUD ENTRY NAVIGATION: ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
