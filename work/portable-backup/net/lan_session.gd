extends Node
signal changed
signal snapshot_ready
signal error_raised(message: String)
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Codec=preload("res://net/state_codec.gd")
const Journal=preload("res://net/journal_store.gd")
const Identity=preload("res://net/local_identity.gd")
const Series=preload("res://net/series_controller.gd")
const Gateway=preload("res://net/command_gateway.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Transport=preload("res://net/lan_transport.gd")
const Discovery=preload("res://net/lan_discovery.gd")
const Metrics=preload("res://net/connection_metrics.gd")
const VERSION="1.0"
const RECONNECT_LIMIT_MS=30000
var transport
var discovery
var identity={}
var storage=""
var fingerprint=""
var is_host=false
var seat=0
var room_id=""
var address=""
var port=47861
var bind_address="*"
var series=Series.new()
var room={}
var authority
var guest={}
var applicant={}
var remote_peer=0
var connected=false
var paused=true
var notice=""
var sequence=0
var view_sequence=0
var command_number=0
var command_results={}
var receipts=["",""]
var replying=["",""]
var snapshots=[]
var latest_snapshot={}
var busy=false
var inflight={}
var remote_last_seen=0
var disconnected_at=0
var disconnect_deadline_unix=0.0
var last_heartbeat=0
var retry_at=0
var joining=false
var resume_requested=false
var acknowledged=-1
var local_game_id=""
var rejected=false
var metrics=Metrics.new()
func latency_text() -> String:
 return metrics.caption(Time.get_ticks_msec()) if connected else "已断开" if not room_id.is_empty() else "未连接"
func ended() -> bool:return room.get("status","")=="aborted"
func connection_status() -> String:
 if ended():return "连接中断，对局结束 · 不计胜负"
 if disconnected_at>0:
  var remaining=float(RECONNECT_LIMIT_MS-(Time.get_ticks_msec()-disconnected_at))/1000.0
  if disconnect_deadline_unix>0:remaining=minf(remaining,disconnect_deadline_unix-Time.get_unix_time_from_system())
  return "连接中断\n等待重连：%d 秒\n可查看战场" % maxi(0,ceili(remaining))
 return notice if not notice.is_empty() else "同步中"
func initialize(directory: String=""):
 storage=directory if not directory.is_empty() else ("res://saves/lan" if OS.has_feature("editor") else "user://lan")
 identity=Identity.load_identity(storage+"/identity.bin")
 var manifest=FileAccess.get_file_as_string("res://net/rules_manifest.json")
 fingerprint=(VERSION+manifest+JSON.stringify(Duel.DB.load_cards())).sha256_text()
 transport=Transport.new();add_child(transport)
 discovery=Discovery.new();add_child(discovery)
 transport.connected.connect(on_connect);transport.disconnected.connect(on_disconnect)
 transport.received.connect(receive);transport.failed.connect(on_failure)
 discovery.rooms_changed.connect(func():changed.emit())
 discovery.start()
func save_identity() -> bool:
 var err=Journal.save_to(storage+"/identity.bin",identity)
 if err!=OK:error_raised.emit("无法保存联机身份："+error_string(err));return false
 return true
func set_display_name(value: String):identity.nickname=Identity.nickname(value);save_identity()
func create_room(format_value: int=3,strict: bool=true,game_port: int=47861,interface_address: String="*") -> String:
 leave(false);is_host=true;seat=0;port=game_port;bind_address=interface_address
 var err=transport.host_room(port,bind_address)
 if err!=OK:return "无法建房："+error_string(err)
 series=Series.new();series.setup(format_value,strict);series.state.names[0]=identity.nickname
 room_id=Identity.token();guest={};applicant={};sequence=0;command_results={};receipts=["",""];replying=["",""];authority=null
 connected=false;paused=true;rejected=false;notice="等待玩家加入";room=series.public_state(0)
 discovery.start(true,metadata(),bind_address)
 if not persist():transport.close();return notice
 changed.emit();return ""
func metadata() -> Dictionary:
 return {"room_id":room_id,"name":identity.nickname,"port":port,"format":series.state.format,"players":2 if connected else 1,"status":series.state.status,"version":fingerprint}
func join_room(host_address: String,game_port: int=47861,resume: bool=false) -> String:
 if not resume:leave(false)
 is_host=false;seat=1;address=host_address.strip_edges();port=game_port;rejected=false;resume_requested=resume
 if not address.is_valid_ip_address():return "请输入有效的局域网 IP 地址"
 var err=transport.join_room(address,port)
 if err!=OK:return "无法连接："+error_string(err)
 joining=true;paused=true;connected=false;notice="正在连接房主";remote_last_seen=Time.get_ticks_msec();retry_at=remote_last_seen
 changed.emit();return ""
func resume_guest(new_address: String="") -> String:
 var saved=identity.get("resume",{})
 if saved.is_empty():return "没有可恢复的客机连接"
 if saved.get("room_id","") in identity.get("ended_rooms",[]):return "该对局已结束，不能重连"
 if float(saved.get("deadline",0.0))>0 and Time.get_unix_time_from_system()>=float(saved.deadline):
  room_id=saved.room_id;end_disconnected_match();return "重连超时，该对局已结束"
 room_id=saved.room_id
 if disconnected_at==0 and float(saved.get("deadline",0.0))>0:
  disconnect_deadline_unix=float(saved.deadline)
  disconnected_at=maxi(1,Time.get_ticks_msec()-RECONNECT_LIMIT_MS+int((disconnect_deadline_unix-Time.get_unix_time_from_system())*1000.0))
 return join_room(saved.address if new_address.is_empty() else new_address,int(saved.port),true)
func restore_host() -> String:
 var data=Journal.load_from(storage+"/host.bin")
 if data.is_empty():return "没有保存的房主对局"
 if data.get("fingerprint","")!=fingerprint:return "保存对局的规则版本与当前版本不一致"
 if data.series.get("status","")=="aborted" or data.room_id in identity.get("ended_rooms",[]):return "该对局已结束，不能恢复"
 leave(false);is_host=true;seat=0
 room_id=data.room_id;port=data.port;bind_address=data.get("bind_address","*");guest=data.guest
 series=Series.new();series.state=data.series;sequence=data.sequence;command_results=data.command_results;receipts=data.get("receipts",["",""])
 if not data.engine.is_empty():authority=Duel.new();Codec.restore(authority,data.engine)
 var err=transport.host_room(port,bind_address)
 if err!=OK:return "无法恢复监听："+error_string(err)
 paused=true;connected=false;notice="已恢复对局，等待原玩家重连";room=series.public_state(0)
 disconnect_deadline_unix=float(data.get("disconnect_deadline_unix",0.0))
 if disconnect_deadline_unix<=0:disconnect_deadline_unix=Time.get_unix_time_from_system()+RECONNECT_LIMIT_MS/1000.0
 disconnected_at=maxi(1,Time.get_ticks_msec()-RECONNECT_LIMIT_MS+int((disconnect_deadline_unix-Time.get_unix_time_from_system())*1000.0))
 discovery.start(true,metadata(),bind_address)
 if series.state.status!="complete" and Time.get_unix_time_from_system()>=disconnect_deadline_unix:
  end_disconnected_match();return "重连超时，该对局已结束"
 if authority!=null:enqueue_snapshot(make_snapshot(0,[],true))
 changed.emit();return ""
func persist() -> bool:
 if not is_host:return true
 var data={"fingerprint":fingerprint,"room_id":room_id,"port":port,"bind_address":bind_address,"guest":guest,"series":series.state,"sequence":sequence,"command_results":command_results,"receipts":receipts,"disconnect_deadline_unix":disconnect_deadline_unix,"engine":Codec.capture(authority) if authority!=null else {}}
 var err=Journal.save_to(storage+"/host.bin",data)
 if err!=OK:paused=true;notice="无法保存对局，已暂停："+error_string(err);error_raised.emit(notice);return false
 return true
func leave(forget: bool=true):
 metrics.reset()
 if transport and connected:transport.send_to(remote_peer,{"type":"leave"})
 if transport:transport.close()
 if discovery:discovery.start()
 connected=false;paused=true;joining=false;remote_peer=0;room_id="";room={};applicant={};authority=null;busy=false;snapshots.clear();latest_snapshot={};local_game_id="";notice="";inflight={};disconnected_at=0;disconnect_deadline_unix=0.0;rejected=false
 if forget:identity.resume={};save_identity()
func on_connect(id: int):
 remote_last_seen=Time.get_ticks_msec()
 if is_host:return
 remote_peer=1
 transport.send_to(1,{"type":"hello","version":fingerprint,"installation":identity.installation,"name":identity.nickname,"resume":identity.get("resume",{}) if resume_requested else {},"last_sequence":maxi(view_sequence,int(identity.get("resume",{}).get("sequence",0))) if resume_requested else 0})
func accept_applicant(accept: bool):
 if applicant.is_empty():return
 var id=int(applicant.peer)
 if not accept:transport.send_to(id,{"type":"rejected","message":"房主拒绝了本次加入"});transport.drop(id);applicant={};changed.emit();return
 guest={"installation":applicant.installation,"token":Identity.token(),"name":applicant.name}
 series.state.names[1]=guest.name;applicant={}
 if not persist():return
 welcome(id)
func welcome(id: int):
 metrics.reset();last_heartbeat=0
 remote_peer=id;connected=true;paused=true;joining=false;remote_last_seen=Time.get_ticks_msec();notice="同步中";retry_at=0
 transport.send_to(id,{"type":"welcome","room_id":room_id,"token":guest.token,"match_id":series.state.match_id,"room":series.public_state(1),"sequence":sequence,"ack_id":receipts[1]})
 if authority!=null:transport.send_to(id,make_snapshot(1,[],true))
 else:transport.send_to(id,{"type":"room","room":series.public_state(1),"sequence":sequence,"ack_id":receipts[1]})
 changed.emit()
func authorized(id: int) -> bool:return is_host and connected and id==remote_peer or not is_host and id==1
func receive(id: int,m: Dictionary):
 var type=m.get("type","")
 if not type is String:return
 if check_reconnect_timeout(Time.get_ticks_msec()):return
 if is_host and type=="hello":
  if ended():transport.send_to(id,{"type":"rejected","message":"该对局已结束，不能重连"});transport.drop(id);return
  if m.get("version","")!=fingerprint:transport.send_to(id,{"type":"rejected","message":"游戏或卡牌规则版本不一致，请使用同一个发行包"});transport.drop(id);return
  if not m.get("installation") is String or not m.get("name") is String or not m.get("resume",{}) is Dictionary:return
  if connected and id!=remote_peer:transport.drop(id);return
  if not m.get("resume",{}).is_empty() and m.resume.get("room_id","")!=room_id:
   transport.send_to(id,{"type":"rejected","message":"此地址的房间不是原对局"});transport.drop(id);return
  if not guest.is_empty():
   var resume=m.get("resume",{})
   if m.installation!=guest.installation or resume.get("room_id","")!=room_id or resume.get("token","")!=guest.token:
    transport.send_to(id,{"type":"rejected","message":"席位已保留给原玩家，请使用原安装和恢复记录"});transport.drop(id);return
   if int(m.get("last_sequence",0))>sequence:
    transport.send_to(id,{"type":"rejected","message":"房主恢复记录早于已确认的操作，无法安全继续本局"});transport.drop(id);return
   welcome(id)
  else:applicant={"peer":id,"installation":m.installation.left(64),"name":Identity.nickname(m.name),"at":Time.get_ticks_msec()};changed.emit()
  return
 if not authorized(id):return
 if is_host and type not in ["ping","pong","ack","command","room_action","leave"]:return
 if not is_host and type not in ["ping","pong","welcome","room","state","ready_state","error","rejected","leave"]:return
 remote_last_seen=Time.get_ticks_msec()
 match type:
  "ping":transport.send_to(id,metrics.make_pong(m,Time.get_ticks_msec()),true)
  "pong":metrics.accept_pong(m,Time.get_ticks_msec())
  "rejected":rejected=true;joining=false;connected=false;paused=true;notice=str(m.get("message","加入被拒绝"));transport.close();error_raised.emit(notice);changed.emit()
  "welcome":
   metrics.reset();last_heartbeat=0
   connected=true;joining=false;paused=true;busy=false;inflight={};room_id=m.room_id;room=m.room;sequence=m.sequence;notice="同步中"
   identity.resume={"room_id":room_id,"token":m.token,"match_id":m.match_id,"address":address,"port":port,"sequence":sequence,"deadline":disconnect_deadline_unix};save_identity();changed.emit()
  "room":
   if is_host:return
   room=m.room;sequence=m.sequence;view_sequence=sequence;finish_receipt(m);remember_sequence();transport.send_to(1,{"type":"ack","sequence":sequence});changed.emit()
  "state":
   if is_host:return
   if m.get("room_id","")!=room_id:return
   sequence=m.sequence;room=m.room;finish_receipt(m);remember_sequence();enqueue_snapshot(m)
   transport.send_to(1,{"type":"ack","sequence":sequence});changed.emit()
  "ack":
   if not is_host:return
   if int(m.get("sequence",-1))==sequence:
    var recovered=disconnected_at>0
    acknowledged=sequence;paused=false;notice="";disconnected_at=0;disconnect_deadline_unix=0.0
    if recovered and not persist():return
    transport.send_to(id,{"type":"ready_state","sequence":sequence});changed.emit()
  "ready_state":
   if not is_host:paused=false;notice="";disconnected_at=0;disconnect_deadline_unix=0.0;identity.resume.erase("deadline");save_identity();changed.emit()
  "command":
   if is_host:handle_command(1,m)
  "room_action":
   if is_host and m.get("action") is Dictionary:handle_room_action(1,m.action)
  "error":
   if inflight.get("id","")==m.get("ack_id",""):busy=false;inflight={}
   error_raised.emit(str(m.get("message","操作被拒绝")))
  "leave":on_disconnect(id);transport.drop(id)
func on_disconnect(id: int):
 if id!=remote_peer or ended():return
 metrics.reset()
 connected=false;paused=true;busy=false;joining=false
 start_disconnect_wait()
 notice="连接中断，已暂停，等待原玩家重连";changed.emit()
func on_failure(message: String):
 if rejected or ended():return
 metrics.reset()
 connected=false;paused=true;busy=false;joining=false
 start_disconnect_wait()
 notice=message+"，对局已暂停";changed.emit()
func start_disconnect_wait():
 if disconnected_at>0 or room_id.is_empty() or room.get("status","")=="complete":return
 disconnected_at=maxi(1,Time.get_ticks_msec());disconnect_deadline_unix=Time.get_unix_time_from_system()+RECONNECT_LIMIT_MS/1000.0
 if is_host:persist()
 elif not identity.get("resume",{}).is_empty():identity.resume.deadline=disconnect_deadline_unix;save_identity()
func check_reconnect_timeout(now: int) -> bool:
 if ended():return true
 if disconnected_at>0 and room.get("status","")!="complete" and (now-disconnected_at>=RECONNECT_LIMIT_MS or disconnect_deadline_unix>0 and Time.get_unix_time_from_system()>=disconnect_deadline_unix):
  end_disconnected_match();return true
 return false
func end_disconnected_match():
 if ended() or room.get("status","")=="complete":return
 if room.is_empty():room=Series.new().public_state(seat)
 connected=false;paused=true;busy=false;joining=false;inflight={};rejected=true;metrics.reset()
 if is_host:
  series.abort();room=series.public_state(0);persist()
 else:
  room.status="aborted";room.winner=-2;room.ready=[false,false];room.end_reason="连接中断，对局结束"
 var ended_rooms=identity.get("ended_rooms",[])
 if room_id not in ended_rooms:ended_rooms.append(room_id)
 identity.ended_rooms=ended_rooms.slice(maxi(0,ended_rooms.size()-64));identity.resume={};save_identity()
 transport.close();discovery.start();snapshots.clear()
 notice="连接中断，对局结束 · 不计胜负";changed.emit()
func can_act(in_match: bool=false) -> bool:return not ended() and connected and not paused and not busy and (not in_match or sequence==view_sequence)
func submit(command: Dictionary) -> String:
 if not can_act(true):return "等待连接或同步完成"
 command_number+=1
 var packet={"type":"command","room_id":room_id,"game_id":room.get("game_id",""),"expected":view_sequence,"id":identity.installation+":"+Identity.token(),"command":command.duplicate(true)}
 busy=true;inflight=packet
 if is_host:call_deferred("handle_command",0,packet)
 else:transport.send_to(1,packet)
 return ""
func handle_command(actor: int,m: Dictionary):
 var id=m.get("id","")
 if not id is String or id.length()>160 or not m.get("command") is Dictionary:return
 replying[actor]=id
 if command_results.has(id):
  publish([],actor==1);return
 if paused or not connected:return reject(actor,"连接暂停，操作未提交")
 if authority==null or m.get("room_id","")!=room_id or m.get("game_id","")!=series.state.game_id:return reject(actor,"对局已变化")
 var expected=int(m.get("expected",-1))
 var concurrent_mulligan=expected>=0 and expected<sequence and m.command.get("name","")=="mulligan" and authority.phase=="mulligan" and not authority.players[actor].mulligan_done
 if expected!=sequence and not concurrent_mulligan:return reject(actor,"状态已更新，请重新选择")
 var before=Codec.capture(authority);var previous_series=series.state.duplicate(true)
 var error=Gateway.apply(authority,actor,m.command)
 if not error.is_empty():Codec.restore(authority,before);reject(actor,error);return
 sequence+=1;command_results[id]=sequence;var old_receipt=receipts[actor];receipts[actor]=id
 if authority.winner!=-2:series.record_result(authority.winner)
 var events=authority.presentation_events.duplicate(true);authority.presentation_events.clear()
 if not persist():
  Codec.restore(authority,before);series.state=previous_series;sequence-=1;receipts[actor]=old_receipt;command_results.erase(id);reject(actor,notice);return
 publish(events)
func reject(actor: int,message: String):
 if actor==0:busy=false;inflight={};error_raised.emit(message)
 else:
  transport.send_to(remote_peer,{"type":"error","message":message,"ack_id":replying[1]})
  if authority!=null:transport.send_to(remote_peer,make_snapshot(1,[],true))
  else:transport.send_to(remote_peer,{"type":"room","room":series.public_state(1),"sequence":sequence,"ack_id":replying[1]})
func room_action(action: Dictionary):
 if not can_act():error_raised.emit("等待双方连接完成");return
 busy=true;action["_request_id"]=Identity.token();inflight={"id":action._request_id}
 if is_host:handle_room_action(0,action)
 else:transport.send_to(1,{"type":"room_action","action":action})
func handle_room_action(actor: int,action: Dictionary):
 replying[actor]=str(action.get("_request_id",""))
 if paused or not connected:return reject(actor,"等待双方连接完成")
 var previous_series=series.state.duplicate(true);var old_engine=authority;var old_sequence=sequence
 var error="";var name=action.get("name","")
 match name:
  "deck":
   if not action.get("deck") is Dictionary:return
   error=series.set_deck(actor,action.deck)
  "ready":error=series.ready(actor)
  "unready":
   if series.state.status in ["lobby","between"]:series.state.ready[actor]=false
   else:error="当前不能取消准备"
  "first":error="先后手由每局开始时的硬币决定"
  "concede_series":error="投降只结束当前单局，请从战场设置操作"
  _:error="未知房间操作"
 if not error.is_empty():reject(actor,error);return
 var old_receipt=receipts[actor];receipts[actor]=replying[actor]
 if series.start_game():
  authority=Duel.new();authority.player_names=series.state.names.duplicate();authority.start(series.state.decks[0],series.state.decks[1],series.state.first)
  authority.show_result(series.coin_text())
  authority.presentation_events.push_front(authority.presentation_events.pop_back())
 sequence+=1
 var events=[]
 if authority!=null:events=authority.presentation_events.duplicate(true);authority.presentation_events.clear()
 if not persist():
  series.state=previous_series;authority=old_engine;sequence=old_sequence;receipts[actor]=old_receipt;return
 publish(events)
func make_snapshot(for_seat: int,events: Array=[],recovery: bool=false) -> Dictionary:
 return {"type":"state","room_id":room_id,"sequence":sequence,"game_id":series.state.game_id,"room":series.public_state(for_seat),"recovery":recovery,"ack_id":receipts[for_seat],"projection":SeatView.build(authority,for_seat,events)}
func publish(events: Array=[],remote_only: bool=false):
 room=series.public_state(0);finish_receipt({"ack_id":receipts[0]})
 if authority!=null:
  if not remote_only:enqueue_snapshot(make_snapshot(0,events))
  if connected:transport.send_to(remote_peer,make_snapshot(1,events))
 else:
  view_sequence=sequence
  if connected:transport.send_to(remote_peer,{"type":"room","room":series.public_state(1),"sequence":sequence,"ack_id":receipts[1]})
 discovery.metadata=metadata();changed.emit()
func remember_sequence():
 if not identity.get("resume",{}).is_empty():identity.resume.sequence=sequence;save_identity()
func finish_receipt(packet: Dictionary):
 if inflight.get("id","")==packet.get("ack_id","") or packet.get("recovery",false):busy=false;inflight={}
func enqueue_snapshot(packet: Dictionary):
 latest_snapshot=packet
 if snapshots.any(func(s):return s.sequence==packet.sequence and s.game_id==packet.game_id):return
 if packet.get("recovery",false):snapshots.clear()
 snapshots.append(packet);snapshot_ready.emit()
func pop_snapshot() -> Dictionary:
 if snapshots.is_empty():return {}
 var packet=snapshots.pop_front();view_sequence=packet.sequence;local_game_id=packet.game_id;return packet
func _process(_delta):
 if transport==null:return
 var now=Time.get_ticks_msec()
 if check_reconnect_timeout(now):return
 if connected:
  if now-last_heartbeat>2000:last_heartbeat=now;transport.send_to(remote_peer,metrics.make_ping(now),true)
  if now-remote_last_seen>6500:on_disconnect(remote_peer);transport.drop(remote_peer)
 elif not is_host and not rejected and not identity.get("resume",{}).is_empty() and disconnected_at>0 and now-disconnected_at<RECONNECT_LIMIT_MS and now-retry_at>3000:
  retry_at=now;resume_guest()
 if is_host and not applicant.is_empty() and now-applicant.at>30000:accept_applicant(false)
