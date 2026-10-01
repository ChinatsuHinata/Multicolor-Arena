extends SceneTree
## Cloud room directory and packet switch. Rules and private state stay on the host.
const DEFAULT_PORT=47862
const MAX_FRAME=13024
const MAX_ROOMS=512
const ACCOUNT_PREFIX="MCA1"
const ACCOUNT_DB_URL="http://127.0.0.1:47864/account"
const SESSION_DB_URL="http://127.0.0.1:47864/session"
const PLAZA_PREFIX="MCP1"
const PLAZA_DB_URL="http://127.0.0.1:47864/deck-plaza"
const MAX_PLAZA_FRAME=16384
var peer: MultiplayerPeer
var websocket=false
var clients={}
var rooms={}
var rejected={}
var account_key: CryptoKey
var account_requests={}
var plaza_requests={}
var account_attempts={}
var account_nonces={}
var last_nonce_cleanup=0
var last_session_check=0
var session_check_cursor=0

func _initialize():call_deferred("start")

func start():
 var port=DEFAULT_PORT
 var bind_address="*"
 var args=OS.get_cmdline_user_args()
 for i in range(args.size()-1):
  if args[i]=="--port" and args[i+1].is_valid_int():port=int(args[i+1])
  if args[i]=="--bind":bind_address=args[i+1]
  if args[i]=="--transport" and args[i+1]=="websocket":websocket=true
 if port<1024 or port>65535:push_error("Invalid relay port");quit(2);return
 if FileAccess.file_exists("res://account_private.pem"):
  account_key=CryptoKey.new()
  if account_key.load_from_string(FileAccess.get_file_as_string("res://account_private.pem"))!=OK:
   account_key=null;push_error("Account private key could not be loaded")
 var err: Error
 if websocket:
  var websocket_peer=WebSocketMultiplayerPeer.new()
  err=websocket_peer.create_server(port,bind_address)
  peer=websocket_peer
 else:
  var enet_peer=ENetMultiplayerPeer.new()
  err=enet_peer.create_server(port,1024,2)
  peer=enet_peer
 if err!=OK:push_error("Relay listen failed: "+error_string(err));quit(2);return
 peer.peer_connected.connect(func(id):
  if clients.size()>=1024:peer.disconnect_peer(id);return
  clients[id]={"role":"","room":"","seat":0,"account":"","nickname":"","device":"","platform":"","token":"","cloud_active":false}
  print("relay connection ",id))
 peer.peer_disconnected.connect(remove_client)
 print("Multicolor relay listening on ","TCP/WebSocket " if websocket else "UDP ",port)

func valid_code(code: Variant) -> bool:
 if not code is String or code.length()!=12:return false
 for ch in code:
  if ch not in "0123456789ABCDEF":return false
 return true

func control(id: int,kind: String,message: String="",extra: Dictionary={}):
 if peer==null or not clients.has(id):return
 var payload={"kind":kind,"message":message}
 payload.merge(extra,true)
 send_raw(id,("MCR1"+JSON.stringify(payload)).to_utf8_buffer())

func send_raw(id: int,data: PackedByteArray,channel: int=0):
 var target=peer.get_peer(id)
 if target==null:return
 if websocket:
  if target.get_ready_state()!=WebSocketPeer.STATE_OPEN:return
 elif target.get_state()!=ENetPacketPeer.STATE_CONNECTED:return
 peer.set_target_peer(id)
 peer.transfer_channel=0 if websocket else channel
 peer.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
 peer.put_packet(data)

func reject(id: int,message: String):
 control(id,"error",message)
 rejected[id]=Time.get_ticks_msec()+500

func remove_client(id: int):
 if not clients.has(id):return
 if account_requests.has(id):
  account_requests[id].queue_free();account_requests.erase(id)
 if plaza_requests.has(id):
  plaza_requests[id].queue_free();plaza_requests.erase(id)
 account_attempts.erase(id)
 var client=clients[id]
 print("relay departure ",id," role=",client.role)
 clients.erase(id);rejected.erase(id)
 var code=client.room
 if not rooms.has(code):return
 var room=rooms[code]
 if client.role=="host" and room.host==id:
  rooms.erase(code)
  for occupant in room.slots:
   if occupant!=0 and occupant!=id and clients.has(occupant):
    control(occupant,"guest_left")
    clients[occupant].role="";clients[occupant].room=""
    rejected[occupant]=Time.get_ticks_msec()+500
 elif client.seat>=1 and client.seat<=8 and room.slots[client.seat-1]==id:
  room.slots[client.seat-1]=0
  if clients.has(room.host):control(room.host,"guest_left","",{"peer":id,"seat":client.seat})
  broadcast_seats(code)

func broadcast_seats(code: String):
 if not rooms.has(code):return
 var room=rooms[code]
 var names=[]
 for occupant in room.slots:
  names.append(clients[occupant].nickname if occupant!=0 and clients.has(occupant) else "")
 for occupant in room.slots:
  if occupant==0 or not clients.has(occupant):continue
  control(occupant,"seat_state","",{"seats":names,"peers":room.slots if occupant==room.host else []})
  control(occupant,"seat_changed","",{"seat":clients[occupant].seat,"role":clients[occupant].role})

func public_rooms() -> Array:
 var result=[]
 for key in rooms:
  var room=rooms[key]
  var seats=[]
  for occupant in room.slots:
   seats.append(clients[occupant].nickname if occupant!=0 and clients.has(occupant) else "")
  result.append({"id":key,"name":room.name,"owner":room.owner,"locked":not room.password.is_empty(),"format":room.format,"rule_set":room.rule_set,"status":room.status,"version":room.version,"seats":seats})
 return result

func register(id: int,msg: Dictionary):
 var kind=str(msg.get("kind",""))
 var code=str(msg.get("room",""))
 var seat=int(msg.get("seat",0))
 if clients[id].account.is_empty():reject(id,"请先登录玩家账号");return
 if clients[id].role!="":reject(id,"连接已登记");return
 for other_id in clients.keys():
  if other_id==id or not clients[other_id].cloud_active:continue
  if clients[other_id].account.to_lower()!=clients[id].account.to_lower():continue
  if clients[other_id].platform!=clients[id].platform or clients[other_id].device!=clients[id].device:
   reject(id,"此账号已在另一设备使用云端");return
 if kind=="list":
  clients[id].cloud_active=true
  var all_rooms=public_rooms()
  var pages=maxi(1,ceili(float(all_rooms.size())/16.0))
  var page=clampi(int(msg.get("page",0)),0,pages-1)
  control(id,"rooms","",{"rooms":all_rooms.slice(page*16,mini((page+1)*16,all_rooms.size())),"page":page,"pages":pages})
  return
 for other_id in clients.keys():
  if other_id!=id and clients[other_id].role in ["host","guest","watch"] and clients[other_id].account.to_lower()==clients[id].account.to_lower():
   reject(id,"此账号已在云端房间中");return
 if kind=="host":
  if not valid_code(code):reject(id,"房间标识无效");return
  if rooms.has(code):reject(id,"房间已被占用，请重试");return
  if rooms.size()>=MAX_ROOMS:reject(id,"中转服务房间已满");return
  if seat<1 or seat>8 or seat>2 and not msg.get("resume",false):reject(id,"建房请选择 1 或 2 号对战位");return
  var password=str(msg.get("password_hash",""))
  if not password.is_empty() and password.length()!=64:reject(id,"房间密码无效");return
  var title=str(msg.get("name","")).strip_edges().left(30)
  if title.is_empty():title=clients[id].nickname+"的房间"
  elif not title.begins_with(clients[id].nickname):title=clients[id].nickname+" · "+title
  var slots=[0,0,0,0,0,0,0,0];slots[seat-1]=id
  rooms[code]={"host":id,"slots":slots,"owner":clients[id].nickname,"name":title,"password":password,"format":int(msg.get("format",3)),"rule_set":str(msg.get("rule_set","unrestricted")),"version":str(msg.get("version","")),"status":"lobby","round":0,"ready":[false,false]}
  clients[id].role="host";clients[id].room=code;clients[id].seat=seat;clients[id].cloud_active=true
  control(id,"registered","",{"seat":seat});broadcast_seats(code);return
 if not rooms.has(code):reject(id,"房间已关闭，请刷新列表");return
 var room=rooms[code]
 if room.password!="" and str(msg.get("password_hash",""))!=room.password:reject(id,"房间密码错误");return
 if str(msg.get("version",""))!=room.version:reject(id,"游戏或规则版本不一致");return
 var late=room.status!="lobby" and not (kind=="guest" and msg.get("resume",false) and seat in [1,2])
 if late:
  kind="watch"
  seat=0
  for index in range(7,1,-1):
   if room.slots[index]==0:seat=index+1;break
  if seat==0:reject(id,"观战位已满");return
 if kind=="guest" and seat not in [1,2] or kind=="watch" and (seat<3 or seat>8):reject(id,"请选择对应的空位");return
 if kind not in ["guest","watch"]:reject(id,"入房类型无效");return
 if room.slots[seat-1]!=0:reject(id,"座位已被占用，请刷新列表");return
 if kind=="guest" and room.status=="complete":reject(id,"对局已结束");return
 room.slots[seat-1]=id
 clients[id].role=kind;clients[id].room=code;clients[id].seat=seat;clients[id].cloud_active=true
 control(room.host,"joined","",{"peer":id,"seat":seat,"role":kind})
 control(id,"paired","",{"seat":seat,"role":kind,"late":late})
 broadcast_seats(code)

func account_reply(id: int,answer: Dictionary):
 if not clients.has(id):return
 send_raw(id,(ACCOUNT_PREFIX+JSON.stringify(answer)).to_utf8_buffer())

func verify_client(id: int,token: String,next_message: Dictionary={}):
 if not clients.has(id):return
 if token.length()!=64:reject(id,"请登录后再进入云端");return
 var request=HTTPRequest.new();root.add_child(request);request.timeout=10.0
 request.request_completed.connect(func(result: int,status: int,_headers: PackedStringArray,body: PackedByteArray):
  request.queue_free()
  if not clients.has(id):return
  if result!=HTTPRequest.RESULT_SUCCESS or status!=200:reject(id,"账号服务暂不可用");return
  var answer=JSON.parse_string(body.get_string_from_utf8())
  if not answer is Dictionary or not answer.get("ok",false):reject(id,"登录已失效，请重新登录");return
  var account=str(answer.get("username",""))
  var device=str(answer.get("device",""))
  var platform=str(answer.get("platform",""))
  for other_id in clients.keys():
   if other_id!=id and clients[other_id].account.to_lower()==account.to_lower() and clients[other_id].platform==platform and clients[other_id].token!=token:
    reject(other_id,"账号已在另一设备登录")
  clients[id].account=account;clients[id].device=device;clients[id].platform=platform;clients[id].nickname=str(answer.get("nickname",account));clients[id].token=token
  if not next_message.is_empty():register(id,next_message)
  else:control(id,"authenticated","",{"nickname":clients[id].nickname}))
 var err=request.request(SESSION_DB_URL,["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify({"action":"verify","token":token}))
 if err!=OK:request.queue_free();reject(id,"账号服务暂不可用")

func handle_account(id: int,data: PackedByteArray):
 if account_key==null:account_reply(id,{"ok":false,"message":"账号服务尚未启用"});return
 if data.size()!=260:account_reply(id,{"ok":false,"message":"账号请求长度无效"});return
 if account_requests.has(id):account_reply(id,{"ok":false,"message":"请等待当前请求完成"});return
 var now=Time.get_unix_time_from_system()
 var attempts=account_attempts.get(id,[])
 attempts=attempts.filter(func(t):return now-t<60)
 if attempts.size()>=6:account_reply(id,{"ok":false,"message":"操作过于频繁，请稍后重试"});return
 attempts.append(now);account_attempts[id]=attempts
 var plain=Crypto.new().decrypt(account_key,data.slice(4))
 if plain.is_empty():account_reply(id,{"ok":false,"message":"账号请求解密失败"});return
 var input=JSON.parse_string(plain.get_string_from_utf8())
 if not input is Dictionary:account_reply(id,{"ok":false,"message":"账号请求格式无效"});return
 var nonce=input.get("n","")
 var stamp=input.get("t",0)
 if not nonce is String or nonce.length()!=16 or not stamp is float and not stamp is int:
  account_reply(id,{"ok":false,"message":"账号请求格式无效"});return
 if absf(now-float(stamp))>300 or account_nonces.has(nonce):
  account_reply(id,{"ok":false,"message":"账号请求已过期，请重试"});return
 account_nonces[nonce]=now
 var platform_code=str(input.get("o","p"))
 if platform_code not in ["p","a"]:account_reply(id,{"ok":false,"message":"设备平台无效"});return
 var payload={"action":input.get("a",""),"username":input.get("u",""),"password":input.get("p",""),"device":input.get("d",""),"platform":"android" if platform_code=="a" else "pc","nickname":input.get("v",""),"token":input.get("s",""),"remember_token":input.get("r","")}
 var request=HTTPRequest.new();root.add_child(request);request.timeout=10.0
 account_requests[id]=request
 request.request_completed.connect(func(result: int,status: int,_headers: PackedStringArray,body: PackedByteArray):
  account_requests.erase(id)
  request.queue_free()
  if not clients.has(id):return
  if result!=HTTPRequest.RESULT_SUCCESS or status!=200:
   account_reply(id,{"ok":false,"message":"账号服务暂不可用"});return
  var answer=JSON.parse_string(body.get_string_from_utf8())
  if not answer is Dictionary:account_reply(id,{"ok":false,"message":"账号服务响应无效"});return
  if payload.action in ["login","resume"] and answer.get("ok",false):
   var account=str(answer.get("username","")).to_lower()
   var platform=str(answer.get("platform",""))
   for other_id in clients.keys():
    if other_id!=id and clients.has(other_id) and clients[other_id].account.to_lower()==account and clients[other_id].platform==platform:
     reject(other_id,"账号已在另一设备重新登录")
  account_reply(id,answer))
 var err=request.request(ACCOUNT_DB_URL,["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify(payload))
 if err!=OK:
  account_requests.erase(id);request.queue_free();account_reply(id,{"ok":false,"message":"账号服务暂不可用"})

func plaza_reply(id: int,answer: Dictionary):
 send_raw(id,(PLAZA_PREFIX+JSON.stringify(answer)).to_utf8_buffer())

func handle_plaza(id: int,data: PackedByteArray):
 if account_key==null:plaza_reply(id,{"ok":false,"message":"套牌广场尚未启用"});return
 if data.size()<=260 or data.size()>MAX_PLAZA_FRAME:plaza_reply(id,{"ok":false,"message":"套牌请求长度无效"});return
 if plaza_requests.has(id):plaza_reply(id,{"ok":false,"message":"请等待当前请求完成"});return
 var auth=JSON.parse_string(Crypto.new().decrypt(account_key,data.slice(4,260)).get_string_from_utf8())
 if not auth is Dictionary:plaza_reply(id,{"ok":false,"message":"套牌请求凭据无效"});return
 var nonce=auth.get("n","")
 var stamp=auth.get("t",0)
 var body=data.slice(260)
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(body)
 if not nonce is String or nonce.length()!=16 or typeof(stamp) not in [TYPE_INT,TYPE_FLOAT] or absf(Time.get_unix_time_from_system()-float(stamp))>300 or account_nonces.has(nonce) or hash.finish().hex_encode()!=auth.get("h",""):
  plaza_reply(id,{"ok":false,"message":"套牌请求已过期或校验失败，请重试"});return
 account_nonces[nonce]=Time.get_unix_time_from_system()
 var input=JSON.parse_string(body.get_string_from_utf8())
 if not input is Dictionary or input.has("token"):plaza_reply(id,{"ok":false,"message":"套牌请求格式无效"});return
 input["token"]=auth.get("s","")
 var request=HTTPRequest.new();root.add_child(request);request.timeout=10.0;request.body_size_limit=65536
 plaza_requests[id]=request
 request.request_completed.connect(func(result: int,status: int,_headers: PackedStringArray,answer_body: PackedByteArray):
  plaza_requests.erase(id);request.queue_free()
  if not clients.has(id):return
  if result!=HTTPRequest.RESULT_SUCCESS or status!=200:plaza_reply(id,{"ok":false,"message":"套牌广场暂不可用"});return
  var answer=JSON.parse_string(answer_body.get_string_from_utf8())
  if not answer is Dictionary:plaza_reply(id,{"ok":false,"message":"套牌广场响应无效"});return
  plaza_reply(id,answer))
 if request.request(PLAZA_DB_URL,["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify(input))!=OK:
  plaza_requests.erase(id);request.queue_free();plaza_reply(id,{"ok":false,"message":"套牌广场暂不可用"})

func handle_packet(id: int,data: PackedByteArray,channel: int):
 if not clients.has(id) or rejected.has(id):return
 if data.size()>=4 and data.slice(0,4).get_string_from_ascii()==PLAZA_PREFIX:
  handle_plaza(id,data);return
 if data.size()<4 or data.size()>MAX_FRAME:reject(id,"数据包长度无效");return
 if data.slice(0,4).get_string_from_ascii()==ACCOUNT_PREFIX:
  handle_account(id,data);return
 if data.slice(0,4).get_string_from_ascii()=="MCR1":
  if data.size()>2048:reject(id,"控制消息过长");return
  var msg=JSON.parse_string(data.slice(4).get_string_from_utf8())
  if not msg is Dictionary:return
  var kind=msg.get("kind","")
  if kind=="auth":verify_client(id,str(msg.get("token","")))
  elif kind=="drop" and clients[id].role=="host":
   var room=rooms.get(clients[id].room,{})
   var target=int(msg.get("peer",0))
   if not room.is_empty() and target in room.slots and target!=id:
    room.slots[room.slots.find(target)]=0
    if clients.has(target):control(target,"guest_left");rejected[target]=Time.get_ticks_msec()+500
   if not room.is_empty():broadcast_seats(clients[id].room)
  elif kind=="move" and clients[id].role=="host":
   var room=rooms.get(clients[id].room,{})
   var source=int(msg.get("from",0))-1
   var target=int(msg.get("to",0))-1
   if room.is_empty() or room.status!="lobby" or room.round!=0:control(id,"move_error","只能在首场开局前或整场结束后的新一场准备阶段调整座位")
   elif source<0 or source>=8 or target<0 or target>=8 or room.slots[source]==0:control(id,"move_error","座位已变化，请刷新后重试")
   elif source<2 and room.ready[source] or target<2 and room.ready[target]:control(id,"move_error","已准备的玩家不能换位")
   elif source!=target:
    var moving=room.slots[source]
    room.slots[source]=room.slots[target];room.slots[target]=moving
    for index in [source,target]:
     var occupant=room.slots[index]
     if occupant!=0 and clients.has(occupant):
      clients[occupant].seat=index+1
      if occupant!=room.host:clients[occupant].role="guest" if index<2 else "watch"
    broadcast_seats(clients[id].room)
  elif kind=="update" and clients[id].role=="host":
   var room=rooms.get(clients[id].room,{})
   if not room.is_empty():
    room.status=str(msg.get("status","lobby"))
    room.round=maxi(0,int(msg.get("round",0)))
    var ready=msg.get("ready",[false,false])
    if ready is Array and ready.size()==2:room.ready=[bool(ready[0]),bool(ready[1])]
  elif kind in ["host","guest","watch","list"]:
   if clients[id].token!=str(msg.get("token","")) or clients[id].account.is_empty():verify_client(id,str(msg.get("token","")),msg)
   else:register(id,msg)
  return
 if data.slice(0,4).get_string_from_ascii()=="MCD1":
  if clients[id].role!="host" or data.size()<13:return
  var target=data.slice(4,12).get_string_from_ascii().hex_to_int()
  var room=rooms.get(clients[id].room,{})
  if not room.is_empty() and target in room.slots and target!=id:send_raw(target,data.slice(12),channel)
  return
 var client=clients[id]
 if client.role=="" or not rooms.has(client.room):return
 var room=rooms[client.room]
 if client.role=="host":return
 if room.host!=0 and clients.has(room.host):
  send_raw(room.host,("MCD1"+"%08X" % id).to_utf8_buffer()+data,channel)

func _process(_delta) -> bool:
 if peer==null:return false
 if Time.get_ticks_msec()-last_nonce_cleanup>10000:
  last_nonce_cleanup=Time.get_ticks_msec()
  var now=Time.get_unix_time_from_system()
  for nonce in account_nonces.keys():
   if now-account_nonces[nonce]>300:account_nonces.erase(nonce)
 if Time.get_ticks_msec()-last_session_check>1000:
  last_session_check=Time.get_ticks_msec()
  var ids=clients.keys()
  for offset in range(mini(64,ids.size())):
   var id=ids[(session_check_cursor+offset)%ids.size()]
   if clients.has(id) and not clients[id].token.is_empty():verify_client(id,clients[id].token)
  if not ids.is_empty():session_check_cursor=(session_check_cursor+64)%ids.size()
 peer.poll()
 var budget=0
 while peer.get_available_packet_count()>0 and budget<4096:
  budget+=1
  var id=peer.get_packet_peer()
  var channel=peer.get_packet_channel()
  var packet=peer.get_packet()
  handle_packet(id,packet,channel)
 for id in rejected.keys():
  if Time.get_ticks_msec()>=rejected[id]:
   rejected.erase(id)
   if clients.has(id):peer.disconnect_peer(id)
 return false
