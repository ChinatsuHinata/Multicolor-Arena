extends SceneTree

const AccountClient=preload("res://scripts/account_client.gd")
const AndroidAccountClient=preload("res://tests/support/android_account_client.gd")
const Session=preload("res://net/lan_session.gd")
const Directory=preload("res://net/cloud_directory.gd")
var errors=[]
var endpoint="ws://127.0.0.1:47872"

func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 if ok:print("PASS: ",label)
 else:errors.append(label);push_error(label)
func until(predicate: Callable,seconds: float=8.0) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<deadline:
  if predicate.call():return true
  await process_frame
 return predicate.call()
func account(action: String,username: String,android: bool=false) -> Dictionary:
 var client=AndroidAccountClient.new() if android else AccountClient.new();root.add_child(client);client.server_url=endpoint
 client.call_deferred("submit",action,username,"password123!")
 var result=await client.finished
 var answer={"ok":result[0],"message":result[1],"username":result[2],"token":client.session_token,"nickname":client.nickname}
 client.queue_free();return answer
func make_session(label: String,token: String,name: String):
 var session=Session.new();root.add_child(session)
 session.initialize("res://work/cloud-room-test/"+label)
 session.cloud_token=token;session.cloud_nickname=name
 return session
func run():
 var args=OS.get_cmdline_user_args()
 var reuse_prefix=""
 for i in range(args.size()-1):
  if args[i]=="--server":endpoint=args[i+1]
  if args[i]=="--reuse-prefix":reuse_prefix=args[i+1]
 var suffix=reuse_prefix if not reuse_prefix.is_empty() else str(Time.get_unix_time_from_system()).replace(".","")
 print("TEST_ACCOUNT_PREFIX=cloud_",suffix,"_")
 var accounts=[]
 for index in range(10):
  var name="cloud_%s_%d" % [suffix,index]
  var created={"ok":true,"message":""} if not reuse_prefix.is_empty() else await account("register",name)
  var logged=await account("login",name)
  check(created.ok and logged.ok and logged.token.length()==64,"cloud login %d" % index)
  if not created.ok or not logged.ok:
   print("ACCOUNT FAILURE: ",created.message," / ",logged.message)
   quit(1);return
  accounts.append(logged)
 var host=make_session("host",accounts[0].token,"房主甲")
 var second=make_session("second",accounts[1].token,"房主乙")
 var guest=make_session("guest",accounts[2].token,"玩家丙")
 var watcher=make_session("watcher",accounts[3].token,"观众丁")
 check(host.create_relay_room(endpoint,1,true,"unrestricted","一号房","pass123",1).is_empty(),"first cloud room starts")
 check(second.create_relay_room(endpoint,1,true,"unrestricted","二号房","",2).is_empty(),"second cloud room starts")
 check(await until(func():return host.notice.contains("已就绪") and second.notice.contains("已就绪")),"both cloud rooms registered")
 var second_guest=make_session("second_guest",accounts[9].token,accounts[9].nickname)
 check(second_guest.join_relay_room(endpoint,second.relay_code,false,1).is_empty(),"guest chooses first battle seat when host chose second")
 check(await until(func():return not second.applicant.is_empty() or second_guest.can_act()),"second room receives first-seat player")
 if not second.applicant.is_empty():second.accept_applicant(true)
 check(await until(func():return second.can_act() and second_guest.can_act()),"first and second battle seats synchronize")
 second_guest.leave(false)
 var directory=Directory.new();root.add_child(directory);directory.start(endpoint,accounts[2].token)
 check(await until(func():return directory.rooms.size()>=2),"directory lists multiple rooms")
 var first={}
 for info in directory.rooms:
  if info.id==host.relay_code:first=info
 check(not first.is_empty() and first.locked and first.seats.size()==8 and first.seats[0]==accounts[0].nickname,"room publishes password flag and eight seats")
 check(guest.join_relay_room(endpoint,host.relay_code,false,2,"wrong").is_empty(),"wrong-password request sent")
 check(await until(func():return guest.rejected),"wrong room password rejected")
 guest.leave(false)
 check(guest.join_relay_room(endpoint,host.relay_code,false,2,"pass123").is_empty(),"guest selects second battle seat")
 check(await until(func():return not host.applicant.is_empty() or guest.can_act()),"host receives guest application")
 if not host.applicant.is_empty():host.accept_applicant(true)
 check(await until(func():return host.can_act() and guest.can_act()),"battle seats synchronize")
 var android_login=await account("login",accounts[2].username,true)
 check(android_login.ok and android_login.token.length()==64,"same account keeps an Android login beside PC")
 var android_directory=Directory.new();root.add_child(android_directory)
 var android_failures=[]
 var android_snapshots=[]
 android_directory.failed.connect(func(message):android_failures.append(message))
 android_directory.changed.connect(func():android_snapshots.append(true))
 android_directory.start(endpoint,android_login.token)
 check(await until(func():return android_failures.any(func(message):return str(message).contains("另一设备"))),"second device cannot enter cloud while PC is inside")
 android_directory.stop()
 var duplicate=make_session("duplicate",accounts[2].token,accounts[2].nickname)
 check(duplicate.join_relay_room(endpoint,host.relay_code,false,3,"pass123").is_empty(),"duplicate-seat request sent")
 check(await until(func():return duplicate.rejected),"same account cannot occupy two seats")
 duplicate.leave(false)
 check(watcher.join_relay_room(endpoint,host.relay_code,false,8,"pass123").is_empty(),"spectator selects eighth seat")
 check(await until(func():return watcher.read_only and watcher.connected),"cloud spectator receives public state")
 var more_watchers=[]
 for index in range(5):
  var spectator=make_session("watcher"+str(index),accounts[4+index].token,accounts[4+index].nickname)
  more_watchers.append(spectator)
  check(spectator.join_relay_room(endpoint,host.relay_code,false,index+3,"pass123").is_empty(),"spectator chooses seat %d" % (index+3))
 var all_connected=await until(func():
  for spectator in more_watchers:
   if not spectator.connected:return false
  return true,15)
 check(all_connected,"all six spectator seats receive public state")
 if not all_connected:
  for spectator in more_watchers:print("SPECTATOR DEBUG ",spectator.cloud_slot," ",spectator.notice," online=",spectator.transport.online," connected=",spectator.connected)
 directory.refresh()
 var seats_full=await until(func():
  for info in directory.rooms:
   if info.id==host.relay_code:
    for occupant in info.seats:
     if str(occupant).is_empty():return false
    return true
  return false,15)
 check(seats_full,"directory updates selected seats")
 if not seats_full:
  for info in directory.rooms:
   if info.id==host.relay_code:print("SEATS DEBUG ",info.seats)
 var overflow=make_session("overflow",accounts[9].token,accounts[9].nickname)
 check(overflow.join_relay_room(endpoint,host.relay_code,false,8,"pass123").is_empty(),"ninth-seat request sent")
 check(await until(func():return overflow.rejected),"ninth player cannot take an occupied seat")
 overflow.leave(false)
 var relogged=await account("login",accounts[2].username)
 check(relogged.ok,"player can start a new account session")
 check(await until(func():return not guest.connected,3),"old cloud connection is removed immediately after login")
 for spectator in more_watchers:spectator.leave(false)
 watcher.leave(false);guest.leave(false);host.leave(false);second.leave(false);directory.stop()
 await create_timer(0.5).timeout
 android_directory.start(endpoint,android_login.token)
 check(await until(func():return not android_snapshots.is_empty()),"Android enters cloud after PC leaves")
 android_directory.stop()
 print("CLOUD ROOMS: ",errors.size()," failures")
 quit(0 if errors.is_empty() else 1)
