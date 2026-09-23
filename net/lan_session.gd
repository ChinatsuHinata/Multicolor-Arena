extends Node
signal changed
signal snapshot_ready
signal error_raised(message: String)
signal replay_finished(archive)
signal chat_received
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
const VERSION="1.1.1-bugfixed"
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
var read_only=false
var replay_mode=false
var spectator_hub
var recording=preload("res://scripts/replay_archive.gd").new()
var undo_history=preload("res://net/undo_history.gd").new()
var undo_request={}
var chat_log: Array=[]
var last_chat_send=0
var last_remote_chat=0
func receive_chat_entry(seat_index: int,content: String):
 var name=str(room.get("names",["房主","客机"])[seat_index])
 chat_log.append({"seat":seat_index,"name":name,"text":content,"at":Time.get_datetime_string_from_system()})
 if chat_log.size()>80:chat_log.pop_front()
 chat_received.emit()
func send_chat(content: String) -> String:
 if read_only or not connected or ended():return "当前无法发送聊天消息"
 var message=content.strip_edges()
 if message.is_empty() or message.length()>200:return "聊天内容须为 1 至 200 个字"
 var now=Time.get_ticks_msec()
 if now-last_chat_send<250:return "发送太快，请稍后重试"
 last_chat_send=now
 if is_host:
  receive_chat_entry(0,message)
  transport.send_to(remote_peer,{"type":"chat","room_id":room_id,"seat":0,"text":message},false,2)
 else:transport.send_to(1,{"type":"chat","room_id":room_id,"text":message},false,2)
 return ""
var rewind_events: Array=[]
func latency_text() -> String:
 return metrics.caption(Time.get_ticks_msec()) if connected else "已断开" if not room_id.is_empty() else "未连接"
func ended() -> bool:return room.get("status","")=="aborted" or room.has("forfeit")
func connection_status() -> String:
 if ended():return room.get("end_reason","对局结束")
 if read_only:return "观战 · "+("等待对局开始" if latest_snapshot.is_empty() else "连接已断开" if not connected else "对局已暂停" if paused else "公开视角")
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
 start_spectators()
 discovery.start(true,metadata(),bind_address)
 if not persist():transport.close();return notice
 changed.emit();return ""
func start_spectators():
 if is_instance_valid(spectator_hub):spectator_hub.close();spectator_hub.queue_free()
 spectator_hub=preload("res://net/spectator_hub.gd").new();add_child(spectator_hub);spectator_hub.start(self)
func join_spectator(host_address: String,game_port: int=47861) -> String:
 leave(false);is_host=false;read_only=true;seat=0;address=host_address.strip_edges();port=game_port
 if not address.is_valid_ip_address() or port>=65535:return "请输入有效地址和小于 65535 的对战端口"
 var error=transport.join_room(address,port+1)
 if error!=OK:return "无法连接观战端口："+error_string(error)
 joining=true;remote_last_seen=Time.get_ticks_msec();notice="正在加入观战";changed.emit();return ""
func metadata() -> Dictionary:
 return {"room_id":room_id,"name":identity.nickname,"port":port,"format":series.state.format,"players":2 if connected else 1,"status":series.state.status,"version":fingerprint,"spectate":is_instance_valid(spectator_hub) and spectator_hub.listening}
func join_room(host_address: String,game_port: int=47861,resume: bool=false) -> String:
 if not resume:leave(false)
 is_host=false;seat=1;address=host_address.strip_edges();port=game_port;rejected=false;resume_requested=resume
 if not address.is_valid_ip_address():return "请输入有效的局域网 IP 地址"
 var err=transport.join_room(address,port)
 if err!=OK:return "无法连接："+error_string(err)
 joining=true;join_stage="connecting";paused=true;connected=false;notice="正在连接房主";remote_last_seen=Time.get_ticks_msec();retry_at=remote_last_seen
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
 undo_history.entries=data.get("undo_entries",[]);rewind_events=data.get("rewind_events",[]);undo_request={}
 if not data.engine.is_empty():authority=Duel.new();Codec.restore(authority,data.engine)
 refresh_undo_status()
 var err=transport.host_room(port,bind_address)
 if err!=OK:return "无法恢复监听："+error_string(err)
 paused=true;connected=false;notice="已恢复对局，等待原玩家重连";room=series.public_state(0)
 recording.begin_capture(storage+"/capture.bin",series.state.match_id)
 disconnect_deadline_unix=float(data.get("disconnect_deadline_unix",0.0))
 if disconnect_deadline_unix<=0:disconnect_deadline_unix=Time.get_unix_time_from_system()+RECONNECT_LIMIT_MS/1000.0
 disconnected_at=maxi(1,Time.get_ticks_msec()-RECONNECT_LIMIT_MS+int((disconnect_deadline_unix-Time.get_unix_time_from_system())*1000.0))
 start_spectators()
 discovery.start(true,metadata(),bind_address)
 if series.state.status!="complete" and Time.get_unix_time_from_system()>=disconnect_deadline_unix:
  end_disconnected_match();return "重连超时，该对局已结束"
 if authority!=null:enqueue_snapshot(make_snapshot(0,[],true))
 changed.emit();return ""
func persist() -> bool:
 if not is_host:return true
 var data={"fingerprint":fingerprint,"room_id":room_id,"port":port,"bind_address":bind_address,"guest":guest,"series":series.state,"sequence":sequence,"command_results":command_results,"receipts":receipts,"disconnect_deadline_unix":disconnect_deadline_unix,"engine":Codec.capture(authority) if authority!=null else {}}
 data.undo_entries=undo_history.entries;data.rewind_events=rewind_events
 var err=Journal.save_to(storage+"/host.bin",data)
 if err!=OK:paused=true;notice="无法保存对局，已暂停："+error_string(err);error_raised.emit(notice);return false
 return true
func leave(forget: bool=true):
 undo_history.entries.clear();undo_request={};rewind_events.clear()
 rejected_peers.clear();join_stage=""
 if is_instance_valid(spectator_hub):spectator_hub.close();spectator_hub.queue_free();spectator_hub=null
 read_only=false;recording=preload("res://scripts/replay_archive.gd").new()
 metrics.reset()
 if transport and connected:transport.send_to(remote_peer,{"type":"leave"})
 if transport:transport.close()
 if discovery:discovery.start()
 connected=false;paused=true;joining=false;remote_peer=0;room_id="";room={};applicant={};authority=null;busy=false;snapshots.clear();latest_snapshot={};local_game_id="";notice="";inflight={};disconnected_at=0;disconnect_deadline_unix=0.0;rejected=false
 chat_log.clear();last_chat_send=0;last_remote_chat=0;chat_received.emit()
 if forget:identity.resume={};save_identity()
func on_connect(id: int):
 remote_last_seen=Time.get_ticks_msec()
 if is_host:return
 remote_peer=1
 if read_only:
  transport.send_to(1,{"type":"watch","version":fingerprint});return
 transport.send_to(1,{"type":"hello","version":fingerprint,"installation":identity.installation,"name":identity.nickname,"resume":identity.get("resume",{}) if resume_requested else {},"last_sequence":maxi(view_sequence,int(identity.get("resume",{}).get("sequence",0))) if resume_requested else 0})
func accept_applicant(accept: bool):
 if applicant.is_empty():return
 var id=int(applicant.peer)
 if not accept:reject_join(id,"房主拒绝或未及时确认本次加入");applicant={};changed.emit();return
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
var join_stage=""
var rejected_peers={}
func reject_join(id: int,message: String):
 transport.send_to(id,{"type":"rejected","message":message})
 # ENet must get a polling opportunity to deliver the rejection before disconnect.
 rejected_peers[id]=Time.get_ticks_msec()+500
func check_join_timeout(now: int):
 if is_host or read_only or not joining or not room_id.is_empty():return
 var limit=35000 if join_stage=="approval" else 12000
 if now-remote_last_seen<=limit:return
 joining=false;rejected=true;paused=true;transport.close()
 notice="等待房主确认超时，请房主接受加入申请后重试。" if join_stage=="approval" else "无法连接房主 %s:%d。请确认房间仍开启、双方在同一局域网或虚拟局域网，且允许游戏通过防火墙。" % [address,port]
 error_raised.emit(notice);changed.emit()
func receive(id: int,m: Dictionary):
 var type=m.get("type","")
 if not type is String:return
 if read_only:
  receive_observer(id,m);return
 if check_reconnect_timeout(Time.get_ticks_msec()):return
 if is_host and type=="hello":
  if ended():reject_join(id,"该对局已结束，不能重连");return
  if m.get("version","")!=fingerprint:reject_join(id,"游戏或卡牌规则版本不一致。请双方使用同一完整发行包（exe 和 pck）。房主校验 %s，本机校验 %s。" % [fingerprint.left(8),str(m.get("version","")).left(8)]);return
  if not m.get("installation") is String or not m.get("name") is String or not m.get("resume",{}) is Dictionary:return
  if connected and id!=remote_peer:transport.drop(id);return
  if not m.get("resume",{}).is_empty() and m.resume.get("room_id","")!=room_id:
   reject_join(id,"此地址的房间不是原对局");return
  if not guest.is_empty():
   var resume=m.get("resume",{})
   if m.installation!=guest.installation or resume.get("room_id","")!=room_id or resume.get("token","")!=guest.token:
    reject_join(id,"席位已保留给原玩家，请使用原安装和恢复记录");return
   if int(m.get("last_sequence",0))>sequence:
    reject_join(id,"房主恢复记录早于已确认的操作，无法安全继续本局");return
   welcome(id)
  else:
   applicant={"peer":id,"installation":m.installation.left(64),"name":Identity.nickname(m.name),"at":Time.get_ticks_msec()}
   transport.send_to(id,{"type":"approval_pending"});changed.emit()
  return
 if not authorized(id):return
 if is_host and type not in ["ping","pong","ack","command","room_action","chat","leave"]:return
 if not is_host and type not in ["ping","pong","welcome","room","state","ready_state","error","rejected","chat","leave","approval_pending"]:return
 remote_last_seen=Time.get_ticks_msec()
 match type:
  "approval_pending":
   join_stage="approval";notice="已连接，等待房主接受加入申请";changed.emit()
  "ping":transport.send_to(id,metrics.make_pong(m,Time.get_ticks_msec()),true)
  "pong":metrics.accept_pong(m,Time.get_ticks_msec())
  "rejected":rejected=true;joining=false;connected=false;paused=true;notice=str(m.get("message","加入被拒绝"));transport.close();error_raised.emit(notice);changed.emit()
  "welcome":
   metrics.reset();last_heartbeat=0
   connected=true;joining=false;paused=true;busy=false;inflight={};room_id=m.room_id;room=m.room;sequence=m.sequence;notice="同步中"
   if recording.frames.is_empty():recording.begin_capture(storage+"/capture.bin",m.match_id if resume_requested else "")
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
    transport.send_to(id,{"type":"ready_state","sequence":sequence})
    if is_instance_valid(spectator_hub):spectator_hub.changed()
    changed.emit()
  "ready_state":
   if not is_host:paused=false;notice="";disconnected_at=0;disconnect_deadline_unix=0.0;identity.resume.erase("deadline");save_identity();changed.emit()
  "command":
   if is_host:handle_command(1,m)
  "room_action":
   if is_host and m.get("action") is Dictionary:handle_room_action(1,m.action)
  "chat":
   if m.get("room_id","")!=room_id or not m.get("text") is String or m.text.strip_edges().is_empty() or m.text.length()>200:return
   if is_host:
    var now=Time.get_ticks_msec()
    if now-last_remote_chat<250:return
    last_remote_chat=now
    receive_chat_entry(1,m.text.strip_edges())
    transport.send_to(remote_peer,{"type":"chat","room_id":room_id,"seat":1,"text":m.text.strip_edges()},false,2)
   elif int(m.get("seat",-1)) in [0,1]:receive_chat_entry(int(m.seat),m.text.strip_edges())
  "error":
   if inflight.get("id","")==m.get("ack_id",""):busy=false;inflight={}
   error_raised.emit(str(m.get("message","操作被拒绝")))
  "leave":on_disconnect(id);transport.drop(id)
func on_disconnect(id: int):
 if read_only:
  connected=false;paused=true;notice="观战连接已断开";changed.emit();return
 if id!=remote_peer or ended() or rejected:return
 undo_request={}
 if is_host:refresh_undo_status()
 if not is_host and room_id.is_empty():
  on_failure("房主在确认加入前断开了连接，请确认房间仍开启后重试。");return
 metrics.reset()
 connected=false;paused=true;busy=false;joining=false
 start_disconnect_wait()
 notice="连接中断，已暂停，等待原玩家重连"
 if is_instance_valid(spectator_hub):spectator_hub.changed()
 changed.emit()
func on_failure(message: String):
 if read_only:
  connected=false;paused=true;notice=message;changed.emit();return
 if rejected or ended():return
 if joining and room_id.is_empty():
  joining=false;connected=false;paused=true;rejected=true
  notice="加入房间失败："+message+"。请确认房主地址、端口及防火墙放行。"
  error_raised.emit(notice);changed.emit();return
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
  series.forfeit(1);room=series.public_state(0);sequence+=1;persist()
 else:
  var result=Series.new();result.state=room.duplicate(true);result.forfeit(0,true);room=result.state
 var ended_rooms=identity.get("ended_rooms",[])
 if room_id not in ended_rooms:ended_rooms.append(room_id)
 identity.ended_rooms=ended_rooms.slice(maxi(0,ended_rooms.size()-64));identity.resume={};save_identity()
 transport.close();discovery.start();snapshots.clear()
 if not latest_snapshot.is_empty():
  var last=latest_snapshot.duplicate(true);last.room=room;last.sequence=sequence+1;last.projection.state.presentation_events=[];recording.record(last,seat)
 finish_recording()
 if is_instance_valid(spectator_hub):spectator_hub.changed()
 notice=room.end_reason;changed.emit()
func can_act(in_match: bool=false) -> bool:return not read_only and not ended() and connected and not paused and not busy and (not in_match or sequence==view_sequence and room.get("undo_request",{}).is_empty())
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
 if not undo_request.is_empty():return reject(actor,"等待悔棋请求处理")
 if authority==null or m.get("room_id","")!=room_id or m.get("game_id","")!=series.state.game_id:return reject(actor,"对局已变化")
 var expected=int(m.get("expected",-1))
 var concurrent_mulligan=expected>=0 and expected<sequence and m.command.get("name","")=="mulligan" and authority.phase=="mulligan" and not authority.players[actor].mulligan_done
 if expected!=sequence and not concurrent_mulligan:return reject(actor,"状态已更新，请重新选择")
 var before=Codec.capture(authority);var previous_series=series.state.duplicate(true)
 var previous_undo=undo_history.entries.duplicate()
 var error=Gateway.apply(authority,actor,m.command)
 if not error.is_empty():Codec.restore(authority,before);reject(actor,error);return
 sequence+=1;command_results[id]=sequence;var old_receipt=receipts[actor];receipts[actor]=id
 if authority.winner!=-2:series.record_result(authority.winner)
 var events=authority.presentation_events.duplicate(true);authority.presentation_events.clear()
 # Passing priority alone is not a completed operation to undo.
 if not (m.command.name=="pass_priority" and authority.stack.is_empty() and authority.passes==1):undo_history.remember(authority,series.state.game_id,sequence)
 refresh_undo_status()
 if not persist():
  undo_history.entries=previous_undo
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
 action["_expected"]=view_sequence;action["_game"]=room.get("game_id","")
 if is_host:handle_room_action(0,action)
 else:transport.send_to(1,{"type":"room_action","action":action})
func handle_room_action(actor: int,action: Dictionary):
 replying[actor]=str(action.get("_request_id",""))
 if paused or not connected:return reject(actor,"等待双方连接完成")
 if str(action.get("name","")).begins_with("undo_"):
  handle_undo_action(actor,action);return
 var previous_series=series.state.duplicate(true);var old_engine=authority;var old_sequence=sequence;var previous_undo=undo_history.entries.duplicate()
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
  undo_history.entries.clear();undo_request={}
  authority=Duel.new();authority.player_names=series.state.names.duplicate();authority.start(series.state.decks[0],series.state.decks[1],series.state.first)
  authority.show_result(series.coin_text())
  authority.presentation_events.push_front(authority.presentation_events.pop_back())
 sequence+=1
 var events=[]
 if authority!=null:events=authority.presentation_events.duplicate(true);authority.presentation_events.clear()
 if authority!=null and authority!=old_engine:undo_history.remember(authority,series.state.game_id,sequence)
 refresh_undo_status()
 if not persist():
  undo_history.entries=previous_undo
  series.state=previous_series;authority=old_engine;sequence=old_sequence;receipts[actor]=old_receipt;return
 publish(events)
func refresh_undo_status():
 series.state.undo_request=undo_request.duplicate(true)
 series.state.undo_available=series.state.status=="playing" and undo_request.is_empty() and undo_history.available(authority,series.state.game_id)
func publish_undo_status():
 refresh_undo_status();room=series.public_state(0)
 busy=false;inflight={}
 transport.send_to(remote_peer,{"type":"room","room":series.public_state(1),"sequence":sequence,"ack_id":receipts[1]})
 if is_instance_valid(spectator_hub):spectator_hub.changed()
 changed.emit()
func handle_undo_action(actor: int,action: Dictionary):
 if authority==null or series.state.status!="playing":return reject(actor,"当前不能悔棋")
 var name=action.get("name","")
 if name=="undo_request":
  if not undo_request.is_empty():return reject(actor,"已有悔棋请求")
  if int(action.get("_expected",-1))!=sequence or action.get("_game","")!=series.state.game_id:return reject(actor,"战况已更新，请重新发起悔棋")
  if not undo_history.available(authority,series.state.game_id):return reject(actor,"对抗为空且有上一战况时才能悔棋")
  undo_request={"id":Identity.token(),"from":actor,"game":series.state.game_id,"target":undo_history.previous().sequence}
 elif name in ["undo_accept","undo_decline","undo_cancel"]:
  if undo_request.is_empty() or action.get("ticket","")!=undo_request.id:return reject(actor,"悔棋请求已失效")
  if name=="undo_cancel" and actor!=undo_request.from or name!="undo_cancel" and actor==undo_request.from:return reject(actor,"只能由另一位玩家决定是否同意")
  if name=="undo_accept":
   var old=Codec.capture(authority);var checkpoints=undo_history.entries.duplicate();var request=undo_request.duplicate(true)
   var restored=undo_history.restore_previous(authority)
   if restored.is_empty():return reject(actor,"无法恢复上一战况")
   var old_receipt=receipts[actor];receipts[actor]=replying[actor]
   sequence+=1;restored.id=sequence;rewind_events.append(restored);undo_request={};refresh_undo_status()
   if not persist():
    Codec.restore(authority,old);undo_history.entries=checkpoints;undo_request=request;sequence-=1;receipts[actor]=old_receipt;rewind_events.pop_back();refresh_undo_status();return reject(actor,notice)
   receipts[actor]=replying[actor];busy=false;inflight={};snapshots.clear()
   if is_instance_valid(spectator_hub):spectator_hub.pending_events.clear()
   publish([],false,true);return
  undo_request={}
 else:return reject(actor,"未知悔棋操作")
 receipts[actor]=replying[actor];publish_undo_status()
func make_snapshot(for_seat: int,events: Array=[],recovery: bool=false) -> Dictionary:
 return {"type":"state","room_id":room_id,"sequence":sequence,"game_id":series.state.game_id,"room":series.public_state(for_seat),"recovery":recovery,"ack_id":receipts[for_seat],"rewinds":rewind_events.duplicate(true),"projection":SeatView.build(authority,for_seat,events)}
func publish(events: Array=[],remote_only: bool=false,recovery: bool=false):
 room=series.public_state(0);finish_receipt({"ack_id":receipts[0]})
 if authority!=null:
  if not remote_only:enqueue_snapshot(make_snapshot(0,events,recovery))
  if connected:transport.send_to(remote_peer,make_snapshot(1,events,recovery))
 else:
  view_sequence=sequence
  if connected:transport.send_to(remote_peer,{"type":"room","room":series.public_state(1),"sequence":sequence,"ack_id":receipts[1]})
 if is_instance_valid(spectator_hub):spectator_hub.changed(events)
 finish_recording()
 discovery.metadata=metadata();changed.emit()
func remember_sequence():
 if not identity.get("resume",{}).is_empty():identity.resume.sequence=sequence;save_identity()
func finish_receipt(packet: Dictionary):
 if inflight.get("id","")==packet.get("ack_id","") or packet.get("recovery",false):busy=false;inflight={}
func enqueue_snapshot(packet: Dictionary):
 if recording.capture_path.is_empty():recording.begin_capture(storage+"/capture.bin")
 recording.record(packet,-1 if read_only else seat)
 latest_snapshot=packet
 if snapshots.any(func(s):return s.sequence==packet.sequence and s.game_id==packet.game_id):return
 if packet.get("recovery",false):snapshots.clear()
 snapshots.append(packet)
 if read_only and snapshots.size()>4:
  snapshots=[packet.duplicate(true)];snapshots[0].recovery=true;snapshots[0].projection.state.presentation_events=[]
 snapshot_ready.emit()
 finish_recording()
func finish_recording():
 if room.get("status","")!="complete" or recording.finished or recording.frames.is_empty():return
 recording.finish(room);replay_finished.emit(recording)
func receive_observer(id: int,m: Dictionary):
 if id!=1:return
 if m.get("type","")=="pong":metrics.accept_pong(m,Time.get_ticks_msec());remote_last_seen=Time.get_ticks_msec();return
 if m.get("type","")!="watch_state" or not m.get("room") is Dictionary:return
 connected=true;joining=false;paused=m.get("paused",false);remote_last_seen=Time.get_ticks_msec()
 room_id=m.room_id;room=m.room;sequence=m.sequence
 transport.send_to(1,{"type":"watch_ack","sequence":sequence},true)
 if m.has("projection"):enqueue_snapshot(m)
 notice=connection_status();changed.emit()
func pop_snapshot() -> Dictionary:
 if snapshots.is_empty():return {}
 var packet=snapshots.pop_front();view_sequence=packet.sequence;local_game_id=packet.game_id;return packet
func _process(_delta):
 if transport==null:return
 var now=Time.get_ticks_msec()
 for id in rejected_peers.keys():
  if now>=rejected_peers[id]:transport.drop(id);rejected_peers.erase(id)
 check_join_timeout(now)
 if read_only:
  if connected and now-last_heartbeat>2000:last_heartbeat=now;transport.send_to(1,metrics.make_ping(now),true)
  if (connected or joining) and now-remote_last_seen>12000:joining=false;on_disconnect(1);transport.close()
  return
 if check_reconnect_timeout(now):return
 if connected:
  if now-last_heartbeat>2000:last_heartbeat=now;transport.send_to(remote_peer,metrics.make_ping(now),true)
  if now-remote_last_seen>6500:on_disconnect(remote_peer);transport.drop(remote_peer)
 elif not is_host and not rejected and not identity.get("resume",{}).is_empty() and disconnected_at>0 and now-disconnected_at<RECONNECT_LIMIT_MS and now-retry_at>3000:
  retry_at=now;resume_guest()
 if is_host and not applicant.is_empty() and now-applicant.at>30000:accept_applicant(false)
