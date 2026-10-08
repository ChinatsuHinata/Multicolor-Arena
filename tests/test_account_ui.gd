extends SceneTree

const AccountClient=preload("res://scripts/account_client.gd")
const AccountSessionStore=preload("res://scripts/account_session_store.gd")
const PasswordEdit=preload("res://scripts/password_edit.gd")
var errors=[]
var checks=0
var app

func _initialize():call_deferred("run")

func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS: ",label)
 else:errors.append(label);push_error(label)

func run():
 app=load("res://main.tscn").instantiate()
 app.tutorial_local_directory="res://work/account-plaza-checks/tutorials"
 DirAccess.make_dir_recursive_absolute(app.tutorial_local_directory)
 root.add_child(app)
 app.account_session_path="res://work/test_account_ui_session.json"
 AccountSessionStore.clear(app.account_session_path)
 await process_frame
 app.account_page();await process_frame
 check(app.page=="account" and app.account_username_input!=null and app.account_password_input.secret,"login page has account and masked password fields")
 check(app.account_password_input is PasswordEdit and app.account_password_input.virtual_keyboard_type==LineEdit.KEYBOARD_TYPE_PASSWORD,"login uses the IME-rejecting field and native password keyboard")
 app.account_password_input.grab_focus();await process_frame
 var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_A;key.unicode=65
 root.push_input(key,true);await process_frame
 check(app.account_password_input.text=="A","direct English keys still enter the password")
 key=key.duplicate();key.keycode=KEY_NONE;key.unicode=20013
 root.push_input(key,true);await process_frame
 check(app.account_password_input.text=="A","Chinese input cannot enter the password")
 app.account_password_input.release_focus()
 app.account_mode="register";app.account_page();await process_frame
 check(app.account_confirm_input!=null and app.account_confirm_input.secret,"registration page confirms masked password")
 check(app.account_password_input is PasswordEdit and app.account_confirm_input is PasswordEdit and app.account_confirm_input.virtual_keyboard_type==LineEdit.KEYBOARD_TYPE_PASSWORD,"registration and confirmation reject IME composition")
 check(app.account_username_input is not PasswordEdit,"ordinary text inputs keep their normal input method")
 app.account_username_input.text="sample_user"
 app.account_password_input.text="password123!"
 app.account_confirm_input.text="different"
 app.account_submit()
 check(app.account_status_label.text.contains("不一致") and not app.account_pending,"mismatched registration is blocked locally")
 app.account_client=AccountClient.new();app.add_child(app.account_client)
 app.account_client.session_token="a".repeat(64)
 app.account_client.remember_token="b".repeat(64)
 app.account_client.nickname="云端玩家"
 app.account_client.elo=1000
 app.account_action="login"
 app.account_request_finished(true,"登录成功","sample_user");await process_frame
 check(app.account_status_label.text=="登录成功" and app.account_name=="sample_user","successful response shows the signed-in player")
 check(app.account_elo==1000 and app.screen.find_child("AccountElo",true,false).text=="我的 Elo：1000","account page displays the signed-in player's initial Elo")
 app.is_android=true;app.account_page();await process_frame
 check(app.screen.find_child("AccountElo",true,false).text=="我的 Elo：1000","Android account page also displays personal Elo")
 app.menu();await process_frame
 check(app.screen.find_child("AccountElo",true,false)==null,"personal Elo is only displayed on the account page")
 check(AccountSessionStore.load_token(AccountClient.device_id(),app.account_session_path)=="b".repeat(64),"login remembers a device-bound token")
 for android in [false,true]:
  app.is_android=android;app.account_page();await process_frame
  check(app.account_old_password_input is PasswordEdit and app.account_password_input is PasswordEdit and app.account_confirm_input is PasswordEdit,"password change masks all three fields on each platform")
  check(app.account_password_change_button.disabled,"empty password change remains locked")
  app.account_old_password_input.text="password123!"
  app.account_password_input.text="new-password!"
  app.account_confirm_input.text="different-password!"
  app.account_confirm_input.text_changed.emit(app.account_confirm_input.text)
  check(app.account_password_change_button.disabled,"mismatched new passwords keep the change button locked")
  app.account_change_password()
  check(not app.account_pending and app.account_status_label.text.contains("不一致"),"Enter and direct submission also reject mismatched confirmation")
  app.account_confirm_input.text="new-password!";app.account_confirm_input.text_changed.emit(app.account_confirm_input.text)
  check(not app.account_password_change_button.disabled,"valid old, new, and matching confirmation unlock submission")
  app.account_old_password_input.grab_focus();app.account_old_password_input.set_caret_column(3)
  app.account_page();await process_frame;await process_frame
  check(app.account_old_password_input.text=="password123!" and app.account_password_input.text=="new-password!" and app.account_confirm_input.text=="new-password!" and app.account_old_password_input.has_focus() and app.account_old_password_input.get_caret_column()==3,"rebuilding the account page preserves all fields and old-password focus")
  app.account_old_password_input.text="new-password!";app.account_old_password_input.text_changed.emit(app.account_old_password_input.text)
  check(app.account_password_change_button.disabled,"reusing the old password keeps submission locked")
  app.account_old_password_input.text="password123!";app.account_pending=true;app.account_refresh_password_button()
  check(app.account_password_change_button.disabled,"pending requests cannot be submitted twice")
  app.account_pending=false
  for field in [app.account_old_password_input,app.account_password_input,app.account_confirm_input]:field.clear()
 app.account_client=AccountClient.new();app.add_child(app.account_client);app.account_action="password"
 app.account_request_finished(false,"账号或旧密码错误","");await process_frame
 check(app.account_name=="sample_user" and app.account_token=="a".repeat(64) and AccountSessionStore.load_token(AccountClient.device_id(),app.account_session_path)=="b".repeat(64),"failed password change retains the current login and remembered credential")
 app.account_client=AccountClient.new();app.add_child(app.account_client);app.account_action="password"
 app.account_request_finished(true,"密码已修改，请使用新密码重新登录","");await process_frame
 check(app.account_name.is_empty() and app.account_token.is_empty() and app.account_remember_token.is_empty() and AccountSessionStore.load_token(AccountClient.device_id(),app.account_session_path).is_empty(),"successful password change clears current and remembered credentials")
 check(app.account_mode=="login" and app.account_old_password_input==null and app.account_password_input.text.is_empty() and app.account_status_label.text.contains("新密码重新登录"),"password change returns to a cleared login form")
 AccountSessionStore.clear(app.account_session_path)
 check(AccountSessionStore.load_token(AccountClient.device_id(),app.account_session_path).is_empty(),"clearing the token prevents the next automatic login")
 print("ACCOUNT UI: ",checks-errors.size(),"/",checks," checks")
 quit(0 if errors.is_empty() else 1)
