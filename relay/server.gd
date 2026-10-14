extends SceneTree
## Cloud room directory and packet switch. Rules and private state stay on the host.
const DEFAULT_PORT=47862
const MAX_FRAME=13024
const MAX_ROOMS=512
const ACCOUNT_PREFIX="MCA1"
const PLAZA_PREFIX="MCP1"
const TOURNAMENT_PREFIX="MCT1"
const MAX_PLAZA_FRAME=16384
const MatchQueue=preload("match_queue.gd")
const MATCH_RULE_SET="official"
const MATCH_RECONNECT_MS=60000
const SESSION_CHECK_MS=30000
var match_queue=MatchQueue.new()
var pending_matches={}
var last_match_tick=0
var character_log=preload("match_character_log.gd").new()
var account_port=47864
var peer: MultiplayerPeer
var websocket=false
var clients={}
var rooms={}
var rejected={}
var account_key: CryptoKey
var account_requests={}
var plaza_requests={}
var tournament_waiting={}
var tournament_queue_checks={}
var account_attempts={}
var account_nonces={}
var last_nonce_cleanup=0
var last_session_check=0
var session_check_cursor=0
var session_requests={}
var session_checked_at={}

func _initialize():call_deferred("start")

func start():
 var port=DEFAULT_PORT
 var bind_address="*"
 var args=OS.get_cmdline_user_args()
 for i in range(args.size()-1):
  if args[i]=="--port" and args[i+1].is_valid_int():port=int(args[i+1])
  if args[i]=="--bind":bind_address=args[i+1]
  if args[i]=="--transport" and args[i+1]=="websocket":websocket=true
  if args[i]=="--account-port" and args[i+1].is_valid_int():account_port=int(args[i+1])
 character_log.log_path=character_log.get_script().resource_path.get_base_dir().path_join("data/match_leaders-"+("websocket" if websocket else "enet")+".jsonl")
 if account_port<1024 or account_port>65535:push_error("Invalid account port");quit(2);return
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
  clients[id]={"role":"","room":"","seat":0,"account":"","nickname":"","device":"","platform":"","token":"","cloud_active":false,"player_id":0,"elo":1000,"last_packet_at":Time.get_ticks_msec()}
  print("relay connection ",id))
 peer.peer_disconnected.connect(remove_client)
 print("Multicolor relay listening on ","TCP/WebSocket " if websocket else "UDP ",port)
 print("Matchmaking enabled: same major tier first, one major tier expansion per 20 seconds; account port ",account_port)

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
 match_queue.remove(id)
 pending_matches.erase(id)
 print("relay rejection ",id," ",message)
 control(id,"error",message)
 rejected[id]=Time.get_ticks_msec()+500

func remove_client(id: int):
 if not clients.has(id):return
 match_queue.remove(id)
 pending_matches.erase(id)
 if session_requests.has(id):
  session_requests[id].request.queue_free();session_requests.erase(id)
 session_checked_at.erase(id)
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
 if room.get("ranked",false):
  var actor=int(client.seat)-1
  if actor in [0,1] and room.slots[actor]==id:
   room.slots[actor]=0
   if room.host==id:room.host=0
   if not room.disconnected.has(actor):room.disconnected[actor]=int(room.get("sync_pending",{}).get(actor,Time.get_ticks_msec()))
   for occupant in room.slots:
    if occupant!=0:control(occupant,"guest_left","",{"peer":id if actor==1 else 1,"seat":client.seat})
   broadcast_seats(code)
  elif client.seat in range(3,9) and room.slots[client.seat-1]==id:
   room.slots[client.seat-1]=0
   if room.host!=0:control(room.host,"guest_left","",{"peer":id,"seat":client.seat})
   broadcast_seats(code)
  if room.get("settled",false) and room.slots[0]==0 and room.slots[1]==0:rooms.erase(code)
  return
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
  var ranked=bool(room.get("ranked",false))
  if ranked and not room.get("public",true):continue
  if ranked and (not room.stored or room.settled or room.cancel or room.status=="complete" or room.host==0):continue
  var seats=[]
  for occupant in room.slots:
   seats.append(clients[occupant].nickname if occupant!=0 and clients.has(occupant) else "")
  result.append({"id":key,"name":room.name,"owner":room.owner,"locked":not room.password.is_empty(),"format":room.format,"rule_set":room.rule_set,"status":room.status,"version":room.version,"seats":seats,"watch_only":ranked})
 return result

func queued_count(version: String="",mode: String="") -> int:
 var count=0
 for entry in match_queue.entries.values():
  if (version.is_empty() or entry.version==version) and (mode.is_empty() or entry.mode==mode):count+=1
 return count

func active_matches(player_id: int) -> Array:
 var result=[]
 for code in rooms:
  var room=rooms[code]
  if room.get("ranked",false) and not room.settled and player_id in room.players:result.append(code)
 return result

func replace_previous_matches(id: int,msg: Dictionary) -> bool:
 var previous=active_matches(int(clients[id].player_id))
 if previous.is_empty():return false
 # Wait for the old result to persist before entering the queue with the new rank.
 clients[id].role="pending_match";clients[id].cloud_active=true
 pending_matches[id]=msg.duplicate(true)
 for code in previous:
  var room=rooms[code]
  var actor=room.players.find(clients[id].player_id)
  var old_peer=int(room.slots[actor])
  if old_peer!=0 and old_peer!=id:
   remove_client(old_peer)
   if peer!=null:peer.disconnect_peer(old_peer)
  if room.outcome==-2 and not room.cancel:
   var survivor=1-actor
   if room.started and room.slots[survivor]!=0:
    room.outcome=int(room.reports[survivor]) if room.reports.has(survivor) else survivor
   else:room.cancel=true
  print("match replaced room=",code," player=",clients[id].player_id)
 tick_matches(Time.get_ticks_msec())
 return true

func release_pending_matches():
 for id in pending_matches.keys():
  if not pending_matches.has(id):continue
  if not clients.has(id):pending_matches.erase(id);continue
  if not active_matches(int(clients[id].player_id)).is_empty():continue
  var msg=pending_matches[id]
  pending_matches.erase(id);clients[id].role=""
  register(id,msg)

func register(id: int,msg: Dictionary):
 var kind=str(msg.get("kind",""))
 var code=str(msg.get("room",""))
 var seat=int(msg.get("seat",0))
 if clients[id].account.is_empty():reject(id,"请先登录玩家账号");return
 if kind=="match" and clients[id].role in ["queue","pending_match"]:return
 if clients[id].role!="":reject(id,"连接已登记");return
 if kind=="match":
  var hash_pattern=RegEx.new();hash_pattern.compile("^[a-f0-9]{64}$")
  if str(msg.get("version","")).length()!=64 or clients[id].player_id<=0:reject(id,"匹配版本或账号无效");return
  if hash_pattern.search(str(msg.get("deck_hash","")))==null:reject(id,"请先选择并登记匹配卡组");return
  if not msg.get("public",true) is bool:reject(id,"房间公开设置无效");return
  if msg.get("mode","ranked") not in ["ranked","casual","exploration","exploration_random"]:reject(id,"匹配模式无效");return
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
  control(id,"rooms","",{"rooms":all_rooms.slice(page*16,mini((page+1)*16,all_rooms.size())),"page":page,"pages":pages,"mode":str(msg.get("mode","ranked")),"queued":queued_count(str(msg.get("version","")),str(msg.get("mode","ranked"))),"rank":clients[id].get("rank",{})})
  return
 for other_id in clients.keys():
  if other_id!=id and clients[other_id].role in ["host","guest","watch","queue","pending_match","tournament_queue"] and clients[other_id].account.to_lower()==clients[id].account.to_lower():
   var previous_room=rooms.get(clients[other_id].room,{})
   if kind=="match" and str(msg.get("tournament_match","")).is_empty() and previous_room.get("ranked",false) and clients[id].player_id in previous_room.players:continue
   reject(id,"此账号已在云端房间或匹配队列中");return
 if kind=="match" and str(msg.get("tournament_match","")).is_empty() and replace_previous_matches(id,msg):return
 for active_code in rooms:
  var active_room=rooms[active_code]
  if active_room.get("ranked",false) and not active_room.settled and clients[id].player_id in active_room.players and (kind=="match" or active_code!=code):
   reject(id,"上一场匹配尚未结束，请等待结算或重连");return
 if kind=="match":
  var version=str(msg.get("version",""))
  var deck_hash=str(msg.get("deck_hash",""))
  clients[id].match_deck_hash=deck_hash
  clients[id].match_public=msg.get("public",true)
  clients[id].match_mode=str(msg.get("mode","ranked"))
  if not str(msg.get("tournament_match","")).is_empty():
   clients[id].match_version=version
   join_tournament_match(id,msg);return
  clients[id].role="queue";clients[id].cloud_active=true
  clients[id].match_version=version
  match_queue.add(id,clients[id].player_id,clients[id].get("rank",{}),version,Time.get_ticks_msec(),clients[id].match_mode)
  print("match queued peer=",id," player=",clients[id].player_id," version=",version.left(12))
  control(id,"match_queued","",{"wait_seconds":0,"rank_gap":0,"queued":queued_count(version,clients[id].match_mode)});return
 if rooms.has(code) and rooms[code].get("ranked",false):
  if kind!="watch":resume_match(id,msg);return
  var ranked_room=rooms[code]
  if not ranked_room.get("public",true):reject(id,"私人匹配房间禁止观战");return
  if not ranked_room.stored or ranked_room.settled or ranked_room.cancel or ranked_room.status=="complete" or ranked_room.host==0:
   reject(id,"匹配对局已结束或暂不可观战");return
 if not str(msg.get("match_id","")).is_empty():reject(id,"匹配房间已失效，请返回云端重新匹配");return
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
 var late=room.get("ranked",false) or room.status!="lobby" and not (kind=="guest" and msg.get("resume",false) and seat in [1,2])
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

func store_url(path: String) -> String:
 return "http://127.0.0.1:%d/%s" % [account_port,path]

func join_tournament_match(id: int,msg: Dictionary):
 var ticket=str(msg.get("tournament_match",""))
 if ticket.length()!=32 or not ticket.is_valid_hex_number():reject(id,"比赛对局标识无效");return
 clients[id].role="tournament_queue";clients[id].cloud_active=true
 var request=HTTPRequest.new();root.add_child(request);request.timeout=10.0
 request.request_completed.connect(func(result: int,status: int,_headers: PackedStringArray,body: PackedByteArray):
  request.queue_free()
  if not clients.has(id) or rejected.has(id):return
  var answer=JSON.parse_string(body.get_string_from_utf8())
  if result!=HTTPRequest.RESULT_SUCCESS or status!=200 or not answer is Dictionary:reject(id,"比赛服务暂不可用");return
  if not answer.get("ok",false):reject(id,str(answer.get("message","无法进入比赛")));return
  var game_format=int(answer.get("game_format",2))
  var expected_mode="exploration_random" if game_format==5 else "exploration" if game_format==4 else "casual"
  if game_format not in [1,2,3,4,5] or str(msg.get("mode",""))!=expected_mode:reject(id,"比赛对局模式与指定赛制不一致，请刷新比赛页面");return
  var players=answer.get("players",[])
  if not players is Array or players.size()!=2:reject(id,"比赛对阵无效");return
  players=[int(players[0]),int(players[1])]
  if clients[id].player_id not in players:reject(id,"比赛对阵无效");return
  if not tournament_waiting.has(ticket):tournament_waiting[ticket]={}
  var waiting=tournament_waiting[ticket]
  for player in waiting.keys():
   if not clients.has(waiting[player]) or rejected.has(waiting[player]):waiting.erase(player)
  if waiting.has(clients[id].player_id) and waiting[clients[id].player_id]!=id:reject(id,"你已在等待本桌对手");return
  waiting[clients[id].player_id]=id
  control(id,"match_queued","等待本桌对手进入游戏",{"wait_seconds":0,"rank_gap":0,"queued":waiting.size()})
  if not waiting.has(int(players[0])) or not waiting.has(int(players[1])):return
  var first=int(waiting[int(players[0])]);var second=int(waiting[int(players[1])])
  tournament_waiting.erase(ticket)
  tournament_queue_checks.erase(ticket)
  if clients[first].match_version!=clients[second].match_version:
   reject(first,"双方游戏版本不同，请更新后重新进入比赛");reject(second,"双方游戏版本不同，请更新后重新进入比赛");return
  if rooms.size()>=MAX_ROOMS:reject(first,"云端房间已满");reject(second,"云端房间已满");return
  pair_match(first,second,ticket,str(answer.get("name","比赛"))+" · 第%d轮" % int(answer.get("round_number",0)),game_format))
 if request.request(store_url("tournament-game"),["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify({"action":"lookup","match_id":ticket,"player_id":clients[id].player_id}))!=OK:
  request.queue_free();reject(id,"无法连接比赛服务")

func check_tournament_queue(ticket: String):
 tournament_queue_checks[ticket]={"busy":true,"at":Time.get_ticks_msec()}
 var request=HTTPRequest.new();root.add_child(request);request.timeout=10.0
 request.request_completed.connect(func(result: int,status: int,_headers: PackedStringArray,body: PackedByteArray):
  request.queue_free()
  if not tournament_waiting.has(ticket) or not tournament_queue_checks.has(ticket):return
  tournament_queue_checks[ticket].busy=false
  var answer=JSON.parse_string(body.get_string_from_utf8())
  if result!=HTTPRequest.RESULT_SUCCESS or status!=200 or not answer is Dictionary:return
  if answer.get("ok",false) and not answer.get("closed",false):return
  var waiting=tournament_waiting[ticket]
  tournament_waiting.erase(ticket);tournament_queue_checks.erase(ticket)
  for id in waiting.values():
   if clients.has(id):reject(id,"本桌已结束或比赛已删除，请刷新比赛页面"))
 if request.request(store_url("tournament-game"),["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify({"action":"status","match_id":ticket}))!=OK:
  request.queue_free();tournament_queue_checks[ticket].busy=false

func check_tournament_room(code: String):
 if not rooms.has(code):return
 var room=rooms[code]
 room.tournament_check_busy=true;room.tournament_checked_at=Time.get_ticks_msec()
 var request=HTTPRequest.new();root.add_child(request);request.timeout=10.0
 request.request_completed.connect(func(result: int,status: int,_headers: PackedStringArray,body: PackedByteArray):
  request.queue_free()
  if not rooms.has(code):return
  room.tournament_check_busy=false
  var answer=JSON.parse_string(body.get_string_from_utf8())
  if result==HTTPRequest.RESULT_SUCCESS and status==200 and answer is Dictionary and (not answer.get("ok",false) or answer.get("closed",false)):
   if room.outcome==-2:room.cancel=true)
 if request.request(store_url("tournament-game"),["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify({"action":"status","match_id":room.match_id}))!=OK:
  request.queue_free();room.tournament_check_busy=false

func pair_match(first: int,second: int,competition: String="",title: String="",competition_format: int=2):
 if not clients.has(first) or not clients.has(second):return
 var match_id=Crypto.new().generate_random_bytes(16).hex_encode() if competition.is_empty() else competition
 var code=match_id.left(12).to_upper()
 while rooms.has(code):
  if competition.is_empty():match_id=Crypto.new().generate_random_bytes(16).hex_encode()
  code=Crypto.new().generate_random_bytes(6).hex_encode().to_upper()
 var slots=[first,second,0,0,0,0,0,0]
 rooms[code]={"host":first,"slots":slots,"owner":"","name":"自动匹配","password":"","format":2,"rule_set":MATCH_RULE_SET,"version":str(clients[first].get("match_version","")),"status":"lobby","round":0,"ready":[false,false],"ranked":true,"match_id":match_id,"players":[clients[first].player_id,clients[second].player_id],"reports":{},"disconnected":{},"stored":false,"started":false,"stored_started":false,"settled":false,"store_busy":false,"store_retry":0,"outcome":-2,"cancel":false}
 rooms[code].deck_hashes=[clients[first].get("match_deck_hash",""),clients[second].get("match_deck_hash","")]
 rooms[code].sync_pending={0:Time.get_ticks_msec(),1:Time.get_ticks_msec()}
 rooms[code].mode=str(clients[first].get("match_mode","ranked"))
 if rooms[code].mode=="casual":rooms[code].rule_set="unrestricted";rooms[code].name="休闲模式 · BO1 换备牌"
 if rooms[code].mode in ["exploration","exploration_random"]:
  rooms[code].rule_set="unrestricted";rooms[code].format=5 if rooms[code].mode=="exploration_random" else 4
  rooms[code].name=("探索幻想乡全随机版" if rooms[code].mode=="exploration_random" else "探索幻想乡")+" · BO1 固定卡组"
 rooms[code].ranks=[clients[first].get("rank",{}).duplicate(true),clients[second].get("rank",{}).duplicate(true)] if rooms[code].mode=="ranked" else []
 rooms[code].public=clients[first].get("match_public",true) and clients[second].get("match_public",true)
 if not competition.is_empty():
  rooms[code].tournament=true;rooms[code].name=title;rooms[code].tournament_checked_at=0;rooms[code].tournament_check_busy=false
  rooms[code].format=competition_format;rooms[code].rule_set="unrestricted"
 for actor in range(2):
  var id=slots[actor]
  clients[id].role="host" if actor==0 else "guest";clients[id].room=code;clients[id].seat=actor+1
  clients[id].last_packet_at=Time.get_ticks_msec()
 match_store_request(code,"create")

func announce_match(code: String):
 if not rooms.has(code):return
 var room=rooms[code]
 print("match paired room=",code," players=",room.players," version=",room.version.left(12))
 for actor in range(2):
  var id=int(room.slots[actor])
  if id==0:continue
  control(id,"matched","",{"room":code,"match_id":room.match_id,"role":"host" if actor==0 else "guest","seat":actor+1,"format":room.format,"rule_set":room.rule_set,"mode":room.get("mode","ranked"),"deck_hashes":room.get("deck_hashes",[]),"ranks":room.get("ranks",[]),"public":room.get("public",true),"tournament":room.get("tournament",false)})
 if room.host!=0:
  control(room.host,"registered","",{"seat":1})
  if room.slots[1]!=0:control(room.host,"joined","",{"peer":room.slots[1],"seat":2,"role":"guest"})
 if room.slots[1]!=0:control(room.slots[1],"paired","",{"seat":2,"role":"guest"})
 broadcast_seats(code)

func resume_match(id: int,msg: Dictionary):
 var code=str(msg.get("room",""));var room=rooms[code]
 var actor=room.players.find(clients[id].player_id)
 if not msg.get("resume",false) or actor<0 or str(msg.get("match_id",""))!=room.match_id or str(msg.get("version",""))!=room.version:
  reject(id,"匹配房间仅限原玩家重连");return
 if room.settled or room.cancel:reject(id,"匹配对局已结束");return
 if room.slots[actor]!=0:reject(id,"匹配座位已占用");return
 var deadline_start=int(room.disconnected.get(actor,room.get("sync_pending",{}).get(actor,Time.get_ticks_msec())))
 if Time.get_ticks_msec()-deadline_start>=MATCH_RECONNECT_MS:
  reject(id,"匹配连接超时，原座位已释放");return
 room.slots[actor]=id
 if not room.get("sync_pending",{}).has(actor):
  if not room.has("sync_pending"):room.sync_pending={}
  room.sync_pending[actor]=int(room.disconnected.get(actor,Time.get_ticks_msec()))
 clients[id].role="host" if actor==0 else "guest";clients[id].room=code;clients[id].seat=actor+1;clients[id].cloud_active=true
 if actor==0:
  room.host=id;control(id,"registered","",{"seat":1})
  if room.slots[1]!=0:
   control(id,"joined","",{"peer":room.slots[1],"seat":2,"role":"guest"})
   control(room.slots[1],"paired","",{"seat":2,"role":"guest"})
 else:
  if room.host!=0:control(room.host,"joined","",{"peer":id,"seat":2,"role":"guest"})
  control(id,"paired","",{"seat":2,"role":"guest"})
 broadcast_seats(code)

func report_match(id: int,msg: Dictionary):
 var room=rooms.get(clients[id].room,{})
 if not room.get("ranked",false) or room.settled or room.cancel or not room.started:return
 var winner=msg.get("winner",-2)
 if str(msg.get("match_id",""))!=room.match_id or not (winner is int or winner is float):return
 if int(winner) not in [0,1] or float(winner)!=float(int(winner)):return
 var actor=room.players.find(clients[id].player_id)
 if actor<0 or room.slots[actor]!=id:return
 if room.reports.has(actor) and room.reports[actor]!=int(winner):room.cancel=true;return
 room.reports[actor]=int(winner)
 if room.reports.size()==2:
  if room.reports[0]==room.reports[1]:room.outcome=room.reports[0]
  else:room.cancel=true

func match_store_request(code: String,action: String):
 if not rooms.has(code):return
 var room=rooms[code]
 room.store_busy=true
 var payload={"action":action,"match_id":room.match_id}
 if action=="create":payload.players=room.players;payload.mode=room.get("mode","ranked")
 if action=="settle":payload.winner=room.outcome
 var request=HTTPRequest.new();root.add_child(request);request.timeout=10.0
 request.request_completed.connect(func(result: int,status: int,_headers: PackedStringArray,body: PackedByteArray):
  request.queue_free()
  if not rooms.has(code):return
  room.store_busy=false;room.store_retry=Time.get_ticks_msec()+3000
  var answer=JSON.parse_string(body.get_string_from_utf8())
  if result!=HTTPRequest.RESULT_SUCCESS or status!=200 or not answer is Dictionary:
   print("match store retry room=",code," action=",action," result=",result," HTTP=",status);return
  if not answer.get("ok",false):
   print("match store rejected room=",code," action=",action," message=",answer.get("message",""))
   if action=="create":
    for occupant in room.slots:
     if occupant!=0 and clients.has(occupant):reject(occupant,"无法开始匹配："+str(answer.get("message","账号服务错误")))
    rooms.erase(code)
    release_pending_matches()
   elif action!="cancel":room.cancel=true
   return
  match_store_completed(code,action,answer))
 var err=request.request(store_url("match"),["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify(payload))
 if err!=OK:
  request.queue_free();room.store_busy=false;room.store_retry=Time.get_ticks_msec()+3000
  print("match store request failed room=",code," action=",action," error=",error_string(err))

func match_store_completed(code: String,action: String,answer: Dictionary):
 var room=rooms[code]
 if action=="create" and room.get("mode","ranked")!="ranked" and answer.get("mode","")!=room.mode:
  room.stored=true;room.cancel=true
  for occupant in room.slots:
   if occupant!=0 and clients.has(occupant):reject(occupant,"账号服务未支持%s，请更新服务端后重试" % ("娱乐模式" if room.mode in ["exploration","exploration_random"] else "休闲模式"))
  return
 var rated=action=="settle" and room.get("mode","ranked")=="ranked"
 match action:
  "create":
   room.stored=true
   if not room.cancel:announce_match(code)
  "start":room.stored_started=true
  "settle","cancel":
   room.settled=true
   if rated:
    for waiting_id in pending_matches:
     if not clients.has(waiting_id):continue
     var actor=room.players.find(clients[waiting_id].player_id)
     if actor<0:continue
     clients[waiting_id].elo=int(answer.ratings[actor])
     if answer.get("ranks") is Array:clients[waiting_id].rank=answer.ranks[actor]
   for actor in range(2):
    var id=int(room.slots[actor])
    if id==0 or not clients.has(id):continue
    var extra={"match_id":room.match_id,"rated":rated,"mode":room.get("mode","ranked"),"winner":room.outcome if action=="settle" else -2}
    if rated:
     clients[id].elo=int(answer.ratings[actor]);extra.elo=clients[id].elo;extra.delta=int(answer.deltas[actor])
     if answer.get("ranks") is Array:
      clients[id].rank=answer.ranks[actor];extra.rank=answer.ranks[actor]
    control(id,"match_settled",("匹配已结算" if rated else ("娱乐模式" if room.mode in ["exploration","exploration_random"] else "休闲")+"对局结束，不影响段位") if action=="settle" else "匹配取消，不计分",extra)
   for index in range(2,room.slots.size()):
    var watcher=int(room.slots[index])
    if watcher!=0:control(watcher,"room_closed","匹配对战已结束，房间已关闭",{"rated":rated,"winner":room.outcome if action=="settle" else -2})
   for occupant in room.slots:
    if occupant!=0 and clients.has(occupant):
     clients[occupant].role="";clients[occupant].room="";clients[occupant].seat=0
   rooms.erase(code)
   release_pending_matches()

func tick_matches(now: int):
 for ticket in tournament_waiting.keys():
  var waiting=tournament_waiting[ticket]
  for player in waiting.keys():
   if not clients.has(waiting[player]) or rejected.has(waiting[player]):waiting.erase(player)
  if waiting.is_empty():
   tournament_waiting.erase(ticket);tournament_queue_checks.erase(ticket);continue
  var check_state=tournament_queue_checks.get(ticket,{"busy":false,"at":0})
  if not check_state.busy and now-int(check_state.at)>=3000:check_tournament_queue(ticket)
 for pair in match_queue.take_pairs(now):
  if rooms.size()>=MAX_ROOMS:
   for id in pair:reject(id,"中转服务房间已满，请稍后重试")
  else:pair_match(pair[0],pair[1])
 for id in match_queue.entries:
  control(id,"match_queued","",{"wait_seconds":maxi(0,(now-int(match_queue.entries[id].since))/1000),"rank_gap":match_queue.allowed_rank_gap(id,now),"queued":queued_count(str(match_queue.entries[id].version),str(match_queue.entries[id].mode))})
 for code in rooms.keys():
  var room=rooms[code]
  if not room.get("ranked",false) or room.settled:continue
  if room.get("tournament",false) and room.stored and not room.cancel and not room.get("tournament_check_busy",false) and now-int(room.get("tournament_checked_at",0))>=3000:
   check_tournament_room(code)
  # A TCP connection or repeated hello is not a completed game-state handshake.
  for actor in range(2):
   var id=int(room.slots[actor])
   var pending=room.get("sync_pending",{})
   if pending.has(actor) and now-int(pending[actor])>=MATCH_RECONNECT_MS:
    room.disconnected[actor]=mini(int(room.disconnected.get(actor,pending[actor])),int(pending[actor]))
   elif id!=0 and clients.has(id) and now-int(clients[id].get("last_packet_at",now))>=MATCH_RECONNECT_MS:
    room.disconnected[actor]=int(clients[id].last_packet_at)
  if room.outcome==-2 and not room.cancel:
   for actor in room.disconnected:
    if now-int(room.disconnected[actor])>=MATCH_RECONNECT_MS:
     if room.started and room.disconnected.size()==1:
      var survivor=1-int(actor)
      # A surviving player can acknowledge a loss already received before the departure.
      room.outcome=int(room.reports[survivor]) if room.reports.has(survivor) else survivor
     else:room.cancel=true
     break
  if room.store_busy or now<int(room.store_retry):continue
  if not room.stored:match_store_request(code,"create")
  elif room.cancel:match_store_request(code,"cancel")
  elif room.started and not room.stored_started:match_store_request(code,"start")
  elif room.outcome in [0,1]:match_store_request(code,"settle")

func account_reply(id: int,answer: Dictionary):
 if not clients.has(id):return
 send_raw(id,(ACCOUNT_PREFIX+JSON.stringify(answer)).to_utf8_buffer())

func verify_client(id: int,token: String,next_message: Dictionary={}):
 if not clients.has(id):return
 if token.length()!=64:reject(id,"请登录后再进入云端");return
 if session_requests.has(id):
  var pending=session_requests[id]
  if pending.token==token:
   if not next_message.is_empty():pending.next_message=next_message.duplicate(true)
   return
  pending.request.queue_free();session_requests.erase(id)
 var request=HTTPRequest.new();root.add_child(request);request.timeout=10.0
 var pending={"request":request,"token":token,"next_message":next_message.duplicate(true)}
 session_requests[id]=pending
 request.request_completed.connect(func(result: int,status: int,_headers: PackedStringArray,body: PackedByteArray):
  request.queue_free()
  if not session_requests.has(id) or session_requests[id].request!=request:return
  session_requests.erase(id)
  session_checked_at[id]=Time.get_ticks_msec()
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
  clients[id].player_id=int(answer.get("player_id",0));clients[id].elo=int(answer.get("elo",1000))
  clients[id].rank=answer.get("rank",{})
  if match_queue.entries.has(id):match_queue.entries[id].rank_step=MatchQueue.rank_step(clients[id].rank)
  if not pending.next_message.is_empty():register(id,pending.next_message)
  else:control(id,"authenticated","",{"nickname":clients[id].nickname,"elo":clients[id].elo,"rank":clients[id].get("rank",{})}))
 var err=request.request(store_url("session"),["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify({"action":"verify","token":token}))
 if err!=OK:session_requests.erase(id);request.queue_free();reject(id,"账号服务暂不可用")

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
 var err=request.request(store_url("account"),["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify(payload))
 if err!=OK:
  account_requests.erase(id);request.queue_free();account_reply(id,{"ok":false,"message":"账号服务暂不可用"})

func plaza_reply(id: int,answer: Dictionary,prefix: String=PLAZA_PREFIX):
 send_raw(id,(prefix+JSON.stringify(answer)).to_utf8_buffer())

func handle_plaza(id: int,data: PackedByteArray,tournament: bool=false):
 var prefix=TOURNAMENT_PREFIX if tournament else PLAZA_PREFIX
 var service="比赛服务" if tournament else "套牌广场"
 if account_key==null:plaza_reply(id,{"ok":false,"message":service+"尚未启用"},prefix);return
 if data.size()<=260 or data.size()>MAX_PLAZA_FRAME:plaza_reply(id,{"ok":false,"message":service+"请求长度无效"},prefix);return
 if plaza_requests.has(id):plaza_reply(id,{"ok":false,"message":"请等待当前请求完成"},prefix);return
 var auth=JSON.parse_string(Crypto.new().decrypt(account_key,data.slice(4,260)).get_string_from_utf8())
 if not auth is Dictionary:plaza_reply(id,{"ok":false,"message":service+"请求凭据无效"},prefix);return
 var nonce=auth.get("n","")
 var stamp=auth.get("t",0)
 var body=data.slice(260)
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(body)
 if not nonce is String or nonce.length()!=16 or typeof(stamp) not in [TYPE_INT,TYPE_FLOAT] or absf(Time.get_unix_time_from_system()-float(stamp))>300 or account_nonces.has(nonce) or hash.finish().hex_encode()!=auth.get("h",""):
  plaza_reply(id,{"ok":false,"message":service+"请求已过期或校验失败，请重试"},prefix);return
 account_nonces[nonce]=Time.get_unix_time_from_system()
 var input=JSON.parse_string(body.get_string_from_utf8())
 if not input is Dictionary or input.has("token"):plaza_reply(id,{"ok":false,"message":service+"请求格式无效"},prefix);return
 input["token"]=auth.get("s","")
 var request=HTTPRequest.new();root.add_child(request);request.timeout=10.0;request.body_size_limit=65536
 plaza_requests[id]=request
 request.request_completed.connect(func(result: int,status: int,_headers: PackedStringArray,answer_body: PackedByteArray):
  plaza_requests.erase(id);request.queue_free()
  if not clients.has(id):return
  if result!=HTTPRequest.RESULT_SUCCESS or status!=200:plaza_reply(id,{"ok":false,"message":service+"暂不可用"},prefix);return
  var answer=JSON.parse_string(answer_body.get_string_from_utf8())
  if not answer is Dictionary:plaza_reply(id,{"ok":false,"message":service+"响应无效"},prefix);return
  plaza_reply(id,answer,prefix))
 if request.request(store_url("tournaments" if tournament else "deck-plaza"),["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify(input))!=OK:
  plaza_requests.erase(id);request.queue_free();plaza_reply(id,{"ok":false,"message":service+"暂不可用"},prefix)

func handle_packet(id: int,data: PackedByteArray,channel: int):
 if not clients.has(id) or rejected.has(id):return
 clients[id].last_packet_at=Time.get_ticks_msec()
 if data.size()>=4 and data.slice(0,4).get_string_from_ascii()==PLAZA_PREFIX:
  handle_plaza(id,data);return
 if data.size()>=4 and data.slice(0,4).get_string_from_ascii()==TOURNAMENT_PREFIX:
  handle_plaza(id,data,true);return
 if data.size()<4 or data.size()>MAX_FRAME:reject(id,"数据包长度无效");return
 if data.slice(0,4).get_string_from_ascii()==ACCOUNT_PREFIX:
  handle_account(id,data);return
 if data.slice(0,4).get_string_from_ascii()=="MCR1":
  if data.size()>2048:reject(id,"控制消息过长");return
  var msg=JSON.parse_string(data.slice(4).get_string_from_utf8())
  if not msg is Dictionary:return
  var kind=msg.get("kind","")
  if kind=="auth":verify_client(id,str(msg.get("token","")))
  elif kind=="match_result":report_match(id,msg)
  elif kind=="match_wait" and clients[id].role=="host":
   var room=rooms.get(clients[id].room,{})
   if room.get("ranked",false) and not room.settled and not room.cancel and str(msg.get("match_id",""))==room.match_id and not room.disconnected.has(1):
    room.disconnected[1]=int(room.get("sync_pending",{}).get(1,Time.get_ticks_msec()))
  elif kind=="drop" and clients[id].role=="host":
   var room=rooms.get(clients[id].room,{})
   if room.get("ranked",false):return
   var target=int(msg.get("peer",0))
   if not room.is_empty() and target in room.slots and target!=id:
    room.slots[room.slots.find(target)]=0
    if clients.has(target):control(target,"guest_left");rejected[target]=Time.get_ticks_msec()+500
   if not room.is_empty():broadcast_seats(clients[id].room)
  elif kind=="move" and clients[id].role=="host":
   var room=rooms.get(clients[id].room,{})
   if room.get("ranked",false):control(id,"move_error","匹配对局不能调整座位");return
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
    if room.get("ranked",false):
     if room.settled or room.cancel:return
     if str(msg.get("status",""))=="playing" and int(msg.get("round",0))>0:room.started=true
    room.status=str(msg.get("status","lobby"))
    if not room.get("ranked",false) and room.status=="lobby" and room.format in [4,5] and int(msg.get("format",0)) in [4,5]:room.format=int(msg.format)
    room.round=maxi(0,int(msg.get("round",0)))
    var ready=msg.get("ready",[false,false])
    if ready is Array and ready.size()==2:room.ready=[bool(ready[0]),bool(ready[1])]
  elif kind in ["host","guest","watch","list","match"]:
   if clients[id].token!=str(msg.get("token","")) or clients[id].account.is_empty():verify_client(id,str(msg.get("token","")),msg)
   else:register(id,msg)
  return
 if data.slice(0,4).get_string_from_ascii()=="MCD1":
  if clients[id].role!="host" or data.size()<13:return
  var target=data.slice(4,12).get_string_from_ascii().hex_to_int()
  var room=rooms.get(clients[id].room,{})
  if not room.is_empty() and target in room.slots and target!=id:
   observe_match_sync(room,target,data.slice(12))
   character_log.observe(room,target,data.slice(12))
   send_raw(target,data.slice(12),channel)
  return
 var client=clients[id]
 if client.role=="" or not rooms.has(client.room):return
 var room=rooms[client.room]
 if client.role=="host":return
 if room.host!=0 and clients.has(room.host):
  send_raw(room.host,("MCD1"+"%08X" % id).to_utf8_buffer()+data,channel)

func observe_match_sync(room: Dictionary,target: int,wire: PackedByteArray):
 # Existing clients send a small ready_state only after both players acknowledge.
 if not room.get("ranked",false) or target!=room.slots[1] or room.cancel:return
 if room.disconnected.is_empty() and room.get("sync_pending",{}).is_empty():return
 if wire.size()<4 or wire[0]!=TYPE_DICTIONARY:return
 var frame=bytes_to_var(wire)
 if not frame is Dictionary or frame.get("count",0)!=1 or frame.get("index",-1)!=0 or not frame.get("data") is PackedByteArray:return
 var data=frame.data
 if data.size()<4 or data[0]!=TYPE_DICTIONARY or data.hex_encode().sha256_text()!=frame.get("hash",""):return
 var message=bytes_to_var(data)
 if not message is Dictionary or message.get("type","")!="ready_state":return
 # Late handshakes must not revive a seat beyond its original deadline.
 var now=Time.get_ticks_msec()
 for started in room.disconnected.values()+room.get("sync_pending",{}).values():
  if now-int(started)>=MATCH_RECONNECT_MS:return
 room.disconnected.clear();room.sync_pending={}

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
   if clients.has(id) and not rejected.has(id) and not clients[id].token.is_empty() and not session_requests.has(id) and Time.get_ticks_msec()-int(session_checked_at.get(id,-SESSION_CHECK_MS))>=SESSION_CHECK_MS:verify_client(id,clients[id].token)
  if not ids.is_empty():session_check_cursor=(session_check_cursor+64)%ids.size()
 peer.poll()
 var budget=0
 while peer.get_available_packet_count()>0 and budget<4096:
  budget+=1
  var id=peer.get_packet_peer()
  var channel=peer.get_packet_channel()
  var packet=peer.get_packet()
  handle_packet(id,packet,channel)
 if Time.get_ticks_msec()-last_match_tick>=1000:
  last_match_tick=Time.get_ticks_msec();tick_matches(last_match_tick)
 for id in rejected.keys():
  if Time.get_ticks_msec()>=rejected[id]:
   rejected.erase(id)
   if clients.has(id):peer.disconnect_peer(id)
 return false
