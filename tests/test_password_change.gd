extends SceneTree

const AccountClient=preload("res://scripts/account_client.gd")
var errors=[]
var checks=0
const USERNAME="TEST_ONLY_password_maxxx"
const SERVER="ws://127.0.0.1:48055"

func _initialize():call_deferred("run")

func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS: ",label)
 else:errors.append(label);push_error(label)

func change(old_password: String,new_password: String,confirmation: String) -> Dictionary:
 var client=AccountClient.new();root.add_child(client);client.server_url=SERVER
 client.call_deferred("change_password",USERNAME,old_password,new_password,confirmation)
 var result=await client.finished
 var answer={"ok":result[0],"message":result[1],"stage":client.password_change_stage,"next":client.password_next,"confirmation":client.password_confirmation,"secret":client.password_secret,"ticket":client.password_ticket,"packet_size":client.packet.size()}
 client.queue_free()
 return answer

func run():
 var old_password="\\".repeat(64)
 var new_password="\"".repeat(64)
 var client=AccountClient.new();root.add_child(client)
 for data in [client.password_change_data("pwa",old_password),client.password_change_data("pw_set",new_password,"a".repeat(32)),client.password_change_data("pw_confirm",new_password,"a".repeat(32))]:
  if data.a=="pwa":data["u"]="u".repeat(24);data["v"]="a".repeat(22)
  check(JSON.stringify(data).to_utf8_buffer().size()<=245,"maximum escaped password fits the unchanged RSA relay packet")
 client.queue_free()
 var result=await change(old_password,new_password,"different-password!")
 check(not result.ok and result.message.contains("不一致"),"client rejects mismatched confirmation before sending")
 result=await change(old_password,old_password,old_password)
 check(not result.ok and result.message.contains("相同"),"client rejects an unchanged password")
 result=await change("wrong-password!",new_password,new_password)
 check(not result.ok and result.message=="账号或旧密码错误","old password is checked by the account service")
 check(result.stage.is_empty() and result.next.is_empty() and result.confirmation.is_empty() and result.secret.is_empty() and result.ticket.is_empty() and result.packet_size==0,"failed change clears retained passwords, credentials, and encrypted packet")
 result=await change(old_password,new_password,new_password)
 check(result.ok and result.message=="密码已修改，请使用新密码重新登录","all three encrypted requests work through the existing relay")
 check(result.stage.is_empty() and result.next.is_empty() and result.confirmation.is_empty() and result.secret.is_empty() and result.ticket.is_empty() and result.packet_size==0,"successful change clears retained passwords, credentials, and encrypted packet")
 result=await change(old_password,"another-password!","another-password!")
 check(not result.ok and result.message=="账号或旧密码错误","the old password no longer authorizes a change")
 client=AccountClient.new();root.add_child(client);client.server_url=SERVER
 client.call_deferred("submit","login",USERNAME,new_password)
 var login=await client.finished
 check(login[0] and login[2]==USERNAME and client.session_token.length()==64,"maximum escaped new password can log in through the unchanged relay")
 client.queue_free()
 print("PASSWORD CHANGE: ",checks-errors.size(),"/",checks," checks")
 quit(0 if errors.is_empty() else 1)
