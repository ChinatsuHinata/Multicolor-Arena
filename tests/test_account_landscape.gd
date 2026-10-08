extends SceneTree

var errors: Array=[]
var app

func _initialize():call_deferred("run")

func check(ok: bool,description: String):
 if ok:print("PASS: ",description)
 else:errors.append(description);push_error(description)

func frames(count: int=3):
 for index in range(count):await process_frame

func find_button(node: Node,caption: String) -> Button:
 if node is Button and node.text==caption:return node
 for child in node.get_children():
  var found=find_button(child,caption)
  if found!=null:return found
 return null

func controls_fit(captions: Array) -> bool:
 var bounds=app.screen.get_global_rect().grow(2)
 var panel=app.screen.find_child("AccountPanel",true,false) as Control
 if panel==null:return false
 if not bounds.encloses(panel.get_global_rect()):
  print("Outside account panel: ",panel.get_global_rect()," screen=",bounds)
  return false
 for control in [app.account_username_input,app.account_password_input,app.account_confirm_input,app.account_status_label]:
  if is_instance_valid(control) and not bounds.encloses(control.get_global_rect()):
   print("Outside account control: ",control.name," ",control.get_global_rect())
   return false
 for caption in captions:
  var action=find_button(app.screen,caption)
  if action==null:return false
  if not bounds.encloses(action.get_global_rect()):
   print("Outside account action: ",caption," ",action.get_global_rect())
   return false
 return true

func signed_in_settings_fit() -> bool:
 var bounds=app.screen.get_global_rect().grow(2)
 var panel=app.screen.find_child("AccountPanel",true,false) as Control
 var scroll=app.screen.find_child("AccountSettingsScroll",true,false) as ScrollContainer
 var rating=app.screen.find_child("AccountElo",true,false) as Label
 if panel==null or scroll==null or rating==null:return false
 if not bounds.encloses(panel.get_global_rect()) or not bounds.encloses(scroll.get_global_rect()) or not bounds.encloses(rating.get_global_rect()):return false
 var controls=[app.account_username_input,app.account_old_password_input,app.account_password_input,app.account_confirm_input]
 for caption in ["保存昵称","修改密码","退出账号","返回主菜单"]:controls.append(find_button(app.screen,caption))
 for control in controls:
  if not is_instance_valid(control):return false
  scroll.ensure_control_visible(control)
  await frames()
  if not scroll.get_global_rect().grow(2).encloses(control.get_global_rect()):
   print("Account setting cannot be fully reached: ",control.name," ",control.get_global_rect()," viewport=",scroll.get_global_rect())
   return false
 return true

func run():
 root.mode=Window.MODE_WINDOWED
 root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app)
 await frames()
 app.is_android=true
 app.layout_dpi_override=360
 for resolution in [Vector2i(1280,720),Vector2i(1600,900)]:
  root.size=resolution
  app.layout_safe_override=Rect2(40,0,resolution.x-80,resolution.y-40)
  app.refresh_responsive_layout()
  await frames()
  app.account_name="";app.account_mode="register";app.account_page()
  await frames()
  var size_label=str(resolution.x)+"x"+str(resolution.y)
  check(app.screen.find_child("AccountScroll",true,false)==null,size_label+" Android account page has no vertical scroll")
  check(controls_fit(["登录","注册","注册账号","返回主菜单"]),size_label+" registration fits one screen")
  app.account_username_input.text="sample_user"
  app.account_password_input.text="password123!"
  app.account_confirm_input.text="password123!"
  app.account_status_label.text="密码只能使用英文字母、数字和英文符号"
  await frames()
  check(controls_fit(["登录","注册","注册账号","返回主菜单"]),size_label+" registration status fits one screen")
  find_button(app.screen,"登录").pressed.emit()
  await frames()
  check(app.account_username_input.text=="sample_user" and app.account_password_input.text=="password123!",size_label+" switching to login keeps entered credentials")
  check(controls_fit(["登录","注册","返回主菜单"]),size_label+" login fits one screen")
  app.account_name="sample_user";app.account_nickname="玩家甲";app.account_page()
  await frames()
  check(await signed_in_settings_fit(),size_label+" signed-in identity fits and every setting is reachable in the local scroll")
  check(app.screen.find_child("AccountElo",true,false).text=="我的 Elo：%d" % app.account_elo,size_label+" signed-in account retains personal Elo")
  app.account_old_password_input.text="password123!"
  app.account_password_input.text="new-password!"
  app.account_confirm_input.text="new-password!"
  app.account_confirm_input.text_changed.emit(app.account_confirm_input.text)
  check(not app.account_password_change_button.disabled,size_label+" valid password change can be submitted")
  app.account_old_password_input.grab_focus();app.account_old_password_input.set_caret_column(3)
  app.account_page();await frames()
  check(app.account_old_password_input.text=="password123!" and app.account_password_input.text=="new-password!" and app.account_confirm_input.text=="new-password!",size_label+" signed-in reflow retains password change fields")
  check(app.account_old_password_input.has_focus() and app.account_old_password_input.get_caret_column()==3,size_label+" signed-in reflow restores old password focus and caret")
  app.account_name="abcdefghijklmnopqrstuvwx";app.account_nickname="昵称".repeat(10);app.account_page()
  await frames()
  check(await signed_in_settings_fit(),size_label+" long account identity fits beside reachable settings")
  app.account_name=""
 app.is_android=false
 app.layout_dpi_override=0
 app.layout_safe_override=Rect2()
 app.refresh_responsive_layout()
 app.account_mode="register";app.account_page()
 await frames()
 check(app.screen.find_child("AccountScroll",true,false)!=null,"desktop account page retains scroll container")
 var panel=app.screen.find_child("AccountPanel",true,false) as Control
 check(panel!=null and panel.custom_minimum_size.x==560,"desktop account panel keeps its width")
 print("ACCOUNT LANDSCAPE: ",errors.size()," failures")
 quit(0 if errors.is_empty() else 1)
