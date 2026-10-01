extends SceneTree

const AccountClient=preload("res://scripts/account_client.gd")
var errors=[]
var server_url="ws://127.0.0.1:47872"

func _initialize():call_deferred("run")

func check(condition: bool,label: String):
 if condition:print("PASS: ",label)
 else:errors.append(label);push_error(label)

func request(action: String,username: String,password: String) -> Dictionary:
 var client=AccountClient.new();root.add_child(client)
 client.server_url=server_url
 client.call_deferred("submit",action,username,password)
 var result=await client.finished
 var answer={"ok":result[0],"message":result[1],"username":result[2],"token":client.session_token,"remember_token":client.remember_token,"nickname":client.nickname}
 client.queue_free()
 return answer

func session_request(action: String,token: String,value: String="") -> Dictionary:
 var client=AccountClient.new();root.add_child(client);client.server_url=server_url
 if action=="nickname":client.call_deferred("update_nickname",value,token)
 elif action=="resume":client.call_deferred("resume",token)
 else:client.call_deferred("logout",token,value)
 var result=await client.finished
 var answer={"ok":result[0],"message":result[1],"username":result[2],"token":client.session_token,"remember_token":client.remember_token,"nickname":client.nickname}
 client.queue_free();return answer

func run():
 var args=OS.get_cmdline_user_args()
 for i in range(args.size()-1):
  if args[i]=="--server":server_url=args[i+1]
 var username="acct_test_"+str(Time.get_unix_time_from_system()).replace(".","")
 var result=await request("register",username,"password123!")
 check(result.ok and result.username==username,"registration creates cloud player")
 result=await request("register",username,"password123!")
 check(not result.ok and result.message=="账号已存在","duplicate username rejected")
 result=await request("login",username,"wrong-pass")
 check(not result.ok and result.message=="账号或密码错误","wrong password rejected")
 result=await request("login",username,"password123!")
 check(result.ok and result.username==username,"registered player can log in")
 var remembered=str(result.remember_token)
 check(remembered.length()==64,"login returns a persistent device credential")
 result=await session_request("resume",remembered)
 check(result.ok and result.username==username and result.remember_token!=remembered,"saved credential signs in again and rotates")
 var token=str(result.token)
 var rotated_remembered=str(result.remember_token)
 result=await session_request("nickname",token,"云端玩家")
 check(result.ok and result.nickname=="云端玩家","signed-in player can set a nickname")
 result=await session_request("logout",token,rotated_remembered)
 check(result.ok,"signed-in player can log out")
 result=await request("register","x","password123!")
 check(not result.ok,"short username rejected")
 print("ACCOUNT: ",9-errors.size(),"/9 checks")
 quit(0 if errors.is_empty() else 1)
