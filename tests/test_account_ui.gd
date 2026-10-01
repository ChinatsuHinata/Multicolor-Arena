extends SceneTree

const AccountClient=preload("res://scripts/account_client.gd")
const AccountSessionStore=preload("res://scripts/account_session_store.gd")
const PasswordEdit=preload("res://scripts/password_edit.gd")
var errors=[]
var app

func _initialize():call_deferred("run")

func check(ok: bool,label: String):
 if ok:print("PASS: ",label)
 else:errors.append(label);push_error(label)

func run():
 app=load("res://main.tscn").instantiate();root.add_child(app)
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
 app.account_action="login"
 app.account_request_finished(true,"登录成功","sample_user");await process_frame
 check(app.account_status_label.text=="登录成功" and app.account_name=="sample_user","successful response shows the signed-in player")
 check(AccountSessionStore.load_token(AccountClient.device_id(),app.account_session_path)=="b".repeat(64),"login remembers a device-bound token")
 AccountSessionStore.clear(app.account_session_path)
 check(AccountSessionStore.load_token(AccountClient.device_id(),app.account_session_path).is_empty(),"clearing the token prevents the next automatic login")
 print("ACCOUNT UI: ",11-errors.size(),"/11 checks")
 quit(0 if errors.is_empty() else 1)
