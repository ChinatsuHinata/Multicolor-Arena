extends SceneTree

var errors=[]
var app

func _initialize():call_deferred("run")

func check(ok: bool,description: String):
 if ok:print("PASS: ",description)
 else:errors.append(description);push_error(description)

func find_button(node: Node,caption: String) -> Button:
 if node is Button and node.text==caption:return node
 for child in node.get_children():
  var found=find_button(child,caption)
  if found!=null:return found
 return null

func find_lobby() -> Control:
 for child in app.screen.get_children():
  if child.get_script()==load("res://net/lan_lobby.gd"):return child
 return null

func visible_text(node: Node) -> Array:
 var result=[]
 if node is Label:result.append(node.text)
 elif node is Button:result.append(node.text)
 for child in node.get_children():result.append_array(visible_text(child))
 return result

func frames(count: int=3):
 for index in range(count):await process_frame

func account_controls_fit(captions: Array) -> bool:
 var bounds=app.screen.get_global_rect().grow(2)
 var panel=app.screen.find_child("AccountPanel",true,false) as Control
 if panel==null:return false
 if not bounds.encloses(panel.get_global_rect()):
  print("ACCOUNT OUTSIDE PANEL: ",panel.get_global_rect()," screen=",bounds)
  return false
 for control in [app.account_username_input,app.account_password_input,app.account_confirm_input,app.account_status_label]:
  if control!=null and not bounds.encloses(control.get_global_rect()):
   print("ACCOUNT OUTSIDE CONTROL: ",control.name," ",control.get_global_rect()," screen=",bounds)
   return false
 for caption in captions:
  var action=find_button(app.screen,caption)
  if action==null:return false
  if not bounds.encloses(action.get_global_rect()):
   print("ACCOUNT OUTSIDE ACTION: ",caption," ",action.get_global_rect()," screen=",bounds)
   return false
 return true

func run():
 root.mode=Window.MODE_WINDOWED
 root.size=Vector2i(1280,720)
 root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app)
 await frames()
 app.is_android=true
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app.layout_dpi_override=360
 app.layout_safe_override=Rect2(40,0,1200,680)
 app.account_mode="register"
 app.account_page()
 await frames()
 check(app.screen.find_child("AccountScroll",true,false)==null,"Android account page does not need a vertical scroll viewport")
 check(account_controls_fit(["登录","注册","注册账号","返回主菜单"]),"Android registration fits in one landscape screen")
 app.account_username_input.text="sample_user"
 app.account_password_input.text="password123!"
 app.account_confirm_input.text="password123!"
 app.account_confirm_input.grab_focus()
 app.account_confirm_input.set_caret_column(5)
 app.refresh_responsive_layout()
 await frames()
 check(app.account_username_input.text=="sample_user" and app.account_password_input.text=="password123!" and app.account_confirm_input.text=="password123!","Android reflow retains unfinished registration")
 check(app.account_confirm_input.has_focus() and app.account_confirm_input.get_caret_column()==5,"Android reflow retains the active input and caret")
 check(account_controls_fit(["登录","注册","注册账号","返回主菜单"]),"registration still fits after Android reflow")
 app.account_mode="login";app.account_page();await frames()
 check(account_controls_fit(["登录","注册","返回主菜单"]),"Android login fits in one landscape screen")
 app.account_mode="register";app.account_page();await frames()

 app.account_name="sample_user";app.account_nickname="玩家甲";app.account_token="f".repeat(64)
 var home_text_pc=[]
 var room_text_pc=[]
 var match_text_pc=[]
 for mobile in [false,true]:
  app.is_android=mobile
  app.layout_dpi_override=360 if mobile else 0
  app.layout_safe_override=Rect2(40,0,1200,680) if mobile else Rect2()
  app.online()
  await frames()
  var lobby=find_lobby()
  check(lobby!=null,"online lobby opens on "+("Android" if mobile else "PC"))
  lobby.cloud_selected=true
  lobby.cloud_directory.rooms=[{"id":"ABCDEF123456","name":"测试房间","owner":"玩家甲","locked":false,"format":3,"status":"lobby","version":lobby.session.fingerprint,"seats":["玩家甲","","","","","","",""]}]
  lobby.refresh(true)
  await frames()
  check(lobby.cloud_rooms_list!=null and lobby.cloud_rooms_list.get_child_count()==1,"cloud directory appears on "+("Android" if mobile else "PC"))
  check(lobby.cloud_rooms_list.get_global_rect().end.x<=app.screen.get_global_rect().end.x+2,"cloud directory fits screen width on "+("Android" if mobile else "PC"))
  var home_text=visible_text(lobby.body)
  if mobile:check(home_text==home_text_pc,"PC and Android cloud home expose the same information and actions")
  else:home_text_pc=home_text
  lobby.session.cloud_mode=true
  lobby.session.room_id="ABCDEF123456"
  lobby.session.cloud_room_name="测试房间"
  lobby.session.cloud_slot=1
  lobby.session.cloud_seats=["玩家甲","","","","","","",""]
  lobby.session.room={"status":"lobby","format":3,"names":["玩家甲","玩家乙"],"scores":[0,0],"strict":true,"ready":[false,false],"own_deck":{},"rule_set":app.RuleSet.UNRESTRICTED}
  lobby.refresh(true)
  await frames()
  check(lobby.body.find_child("CloudSeat8",true,false)!=null,"all eight cloud seats appear on "+("Android" if mobile else "PC"))
  check(lobby.body.find_child("CloudSeat8",true,false).get_global_rect().end.x<=app.screen.get_global_rect().end.x+2,"cloud seats fit screen width on "+("Android" if mobile else "PC"))
  var room_text=visible_text(lobby.body)
  if mobile:check(room_text==room_text_pc,"PC and Android cloud lobby expose the same information and actions")
  else:room_text_pc=room_text
  lobby.session.room.status="playing";lobby.session.room.round=1
  lobby.refresh(true)
  await frames()
  var match_text=visible_text(lobby.body)
  if mobile:check(match_text==match_text_pc,"PC and Android active cloud rooms expose the same actions")
  else:match_text_pc=match_text
  lobby.session.room_id="";lobby.session.room={};lobby.session.cloud_mode=false
  if mobile:
   lobby.refresh(true)
   lobby.cloud_title_input.text="我的云端房间"
   lobby.cloud_password_input.text="secret123"
   lobby.format_input.selected=1
   lobby.cloud_host_slot.selected=1
   lobby.cloud_password_input.grab_focus()
   lobby.cloud_password_input.set_caret_column(3)
   app.refresh_responsive_layout()
   await frames()
   lobby=find_lobby()
   check(lobby.cloud_selected and lobby.cloud_title_input!=null,"Android resize keeps cloud mode selected")
   check(lobby.cloud_title_input.text=="我的云端房间" and lobby.cloud_password_input.text=="secret123" and lobby.format_input.selected==1 and lobby.cloud_host_slot.selected==1,"Android reflow retains cloud room draft")
   check(lobby.cloud_password_input.has_focus() and lobby.cloud_password_input.get_caret_column()==3,"Android reflow retains cloud password input focus")
  lobby.cloud_selected=false; lobby.cloud_directory.stop()
 root.size=Vector2i(2340,1080)
 app.layout_safe_override=Rect2(60,0,2280,1056)
 await frames()
 app.refresh_responsive_layout()
 await frames()
 var wide_lobby=find_lobby()
 wide_lobby.cloud_selected=true
 wide_lobby.cloud_directory.rooms=[{"id":"ABCDEF123456","name":"测试房间","locked":false,"format":3,"status":"lobby","version":wide_lobby.session.fingerprint,"seats":["玩家甲","","","","","","",""]}]
 wide_lobby.refresh(true)
 await frames()
 var wide_grid=wide_lobby.cloud_rooms_list.get_child(0).get_child(0).get_child(1) as GridContainer
 check(wide_grid.columns==4,"wide Android cloud directory uses four readable seat columns")
 check(wide_lobby.cloud_rooms_list.get_global_rect().end.x<=app.screen.get_global_rect().end.x+2,"wide Android cloud directory fits safe width")
 wide_lobby.cloud_directory.stop()
 print("ACCOUNT AND CLOUD LAYOUT: ",errors.size()," failures")
 quit(0 if errors.is_empty() else 1)
