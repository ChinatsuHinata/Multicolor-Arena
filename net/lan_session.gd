extends Node
signal changed
signal snapshot_ready
signal error_raised(message: String)
signal replay_finished(archive)
signal room_joined
signal rating_updated(elo: int)
signal rank_updated(rank: Dictionary)
signal match_found
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Codec=preload("res://net/state_codec.gd")
const Journal=preload("res://net/journal_store.gd")
const Identity=preload("res://net/local_identity.gd")
const PlayerNameDisplay=preload("res://scripts/player_name_display.gd")
const Series=preload("res://net/series_controller.gd")
const MATCH_RULE_SET=Series.RuleSet.OFFICIAL
const MATCH_CATEGORIES=["ranked","casual","entertainment"]
# Entertainment submodes use distinct queue IDs to prevent mixed matches.
const MATCH_MODES=["ranked","casual","exploration","exploration_random"]
const Gateway=preload("res://net/command_gateway.gd")
const ResponseClock=preload("res://scripts/response_clock.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Transport=preload("res://net/lan_transport.gd")
const Discovery=preload("res://net/lan_discovery.gd")
const Metrics=preload("res://net/connection_metrics.gd")
const Endpoint=preload("res://net/network_endpoint.gd")
const VERSION="ranked-simultaneous-mulligan-response-forfeit-1"
const RECONNECT_LIMIT_MS=30000
const MATCH_RECONNECT_LIMIT_MS=60000
const RANKED_UNDO_LIMIT=5
var transport
var discovery
var identity={}
var storage=""
var fingerprint=""
var mod_config: Array=[]
var legacy_fingerprint=""
var is_host=false
var seat=0
var room_id=""
var address=""
var port=47861
var bind_address="*"
var cloud_mode=false
var relay_code=""
var relay_websocket=false
var cloud_token=""
var cloud_nickname=""
var cloud_account=""
var cloud_ranked=false
# cloud_ranked identifies all server-managed matchmaking modes.
var match_mode="ranked"
var cloud_match_id=""
var competition_match_id=""
var competition_format=Series.BO1_SIDEBOARD
var matchmaking=false
var match_connect_started=0
var match_wait_seconds=0
var match_rank_gap=0
var match_queued=-1
var match_deck: Dictionary={}
var match_room_public=true
var match_settled=false
var last_result_report=0
var response_timeout_release_at=0
var cloud_slot=0
var cloud_room_name=""
var cloud_password_hash=""
var cloud_published=""
var cloud_seats=["","","","","","", "", ""]
var cloud_peer_ids: Array=[]
var cloud_player_records=[{},{}]
var cloud_player_acks=[false,false]
var cloud_peer_seen={}
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
var wait_choice_pending=false
var wait_choice_confirmed=false
var last_heartbeat=0
var last_relay_heartbeat=0
var last_network_frame=0
var last_network_frame_gap=0
var relay_link_states=[]
var retry_at=0
var joining=false
var resume_requested=false
var acknowledged=-1
var local_game_id=""
var rejected=false
var metrics=Metrics.new()
var read_only=false
var replay_mode=false
var is_android=OS.has_feature("android")
var application_suspended=false
var spectator_hub
var recording=preload("res://scripts/replay_archive.gd").new()
var replay_exchange
var undo_history=preload("res://net/undo_history.gd").new()
var undo_request={}
var rewind_events: Array=[]
func latency_text() -> String:
 return metrics.caption(Time.get_ticks_msec()) if connected else "已断开" if not room_id.is_empty() else "未连接"
func ended() -> bool:return room.get("status","")=="aborted" or room.has("forfeit")
func ranked_match_pending() -> bool:
 return cloud_ranked and not read_only and not match_settled and not cloud_match_id.is_empty()
func match_rule_set() -> String:
 return MATCH_RULE_SET if match_mode=="ranked" else Series.RuleSet.UNRESTRICTED
static func match_mode_caption(mode: String) -> String:
 if mode in Series.Exploration.MODES:return "娱乐模式 · "+Series.Exploration.MODE_NAMES[Series.Exploration.MODES.find(mode)]
 return {"ranked":"排位匹配","casual":"休闲模式","entertainment":"娱乐模式"}.get(mode,"排位匹配")
func match_caption() -> String:
 if not competition_match_id.is_empty():return "比赛对局"
 return match_mode_caption(match_mode)
func match_format() -> int:
 if not competition_match_id.is_empty():return competition_format
 if match_mode in Series.Exploration.MODES:return Series.EXPLORATION_RANDOM if match_mode=="exploration_random" else Series.EXPLORATION
 return Series.BO1_SIDEBOARD
func match_format_caption() -> String:
 if not competition_match_id.is_empty():return Series.format_label(competition_format)
 return "BO1 · 固定卡组" if match_mode in Series.Exploration.MODES else "BO1 换备牌"
static func match_deck_error(deck: Dictionary,mode: String) -> String:
 if mode in Series.Exploration.MODES:return "" if Series.Exploration.fixed_deck(deck,mode=="exploration_random") else match_mode_caption(mode)+"使用双方固定卡组"
 return Series.Store.validate(deck,true,MATCH_RULE_SET if mode=="ranked" else Series.RuleSet.UNRESTRICTED)
func can_stop_waiting() -> bool:
 return disconnected_at>0 and not ranked_match_pending()
func reconnect_limit_ms() -> int:
 return MATCH_RECONNECT_LIMIT_MS if ranked_match_pending() else RECONNECT_LIMIT_MS
func connection_status() -> String:
 if ended():return PlayerNameDisplay.in_text(room.get("end_reason","对局结束"),room.get("names",[]))
 if read_only:return "观战 · "+("等待对局开始" if latest_snapshot.is_empty() else "连接已断开" if not connected else "对局已暂停" if paused else "公开视角")
 if disconnected_at>0:
  if ranked_match_pending():
   var seconds=maxi(0,ceili(minf(float(MATCH_RECONNECT_LIMIT_MS-(Time.get_ticks_msec()-disconnected_at))/1000.0,disconnect_deadline_unix-Time.get_unix_time_from_system())))
   return relay_connection_caption()+"\n"+("正在恢复原对局：%d 秒" % seconds if seconds>0 else "等待服务器确认结果")+"\n结算以服务器判定为准"
  if wait_choice_pending:return "连接中断\n30 秒已过，是否继续等待？"
  if wait_choice_confirmed:return "连接中断\n持续等待对方重新连接\n可查看战场"
  var remaining=float(RECONNECT_LIMIT_MS-(Time.get_ticks_msec()-disconnected_at))/1000.0
  if disconnect_deadline_unix>0:remaining=minf(remaining,disconnect_deadline_unix-Time.get_unix_time_from_system())
  return "连接中断\n等待重连：%d 秒\n可查看战场" % maxi(0,ceili(remaining))
 return notice if not notice.is_empty() else "同步中"
func initialize(directory: String=""):
 storage=directory if not directory.is_empty() else ("res://saves/lan" if OS.has_feature("editor") else "user://lan")
 identity=Identity.load_identity(storage+"/identity.bin")
 refresh_rules()
 transport=Transport.new();transport.process_priority=-10;add_child(transport)
 discovery=Discovery.new();add_child(discovery)
 replay_exchange=preload("res://net/replay_exchange.gd").new();replay_exchange.session=self;add_child(replay_exchange)
 transport.connected.connect(on_connect);transport.disconnected.connect(on_disconnect)
 transport.received.connect(receive);transport.failed.connect(on_failure)
 transport.relay_seats_changed.connect(on_cloud_seats)
 transport.relay_seat_changed.connect(on_cloud_seat_changed)
 transport.relay_notice.connect(func(message):error_raised.emit(message))
 transport.relay_rating.connect(func(elo):rating_updated.emit(elo))
 transport.relay_rank.connect(func(rank):rank_updated.emit(rank))
 transport.relay_match_queued.connect(func(seconds,rank_gap,queued):
  if not matchmaking:return
  match_connect_started=0
  match_wait_seconds=seconds;match_rank_gap=rank_gap;match_queued=queued
  var range_text="同一大段位内所有级别" if rank_gap==0 else "上下 %d 个大段位" % rank_gap
  if match_mode!="ranked":range_text=match_caption()+" · 不限段位 · 不影响段位"
  notice="正在自动匹配 · 已等待 %d:%02d · %s" % [seconds/60,seconds%60,range_text]
  changed.emit())
 transport.relay_matched.connect(on_match_found)
 transport.relay_match_settled.connect(on_match_settled)
 transport.relay_link_status.connect(on_relay_link_status)
 transport.relay_room_closed.connect(on_observed_room_closed)
 transport.relay_ready.connect(func():
  if cloud_mode and is_host:
   cloud_published=""
   transport.relay_update(series.state.status,cloud_room_name,series.state.ready,series.state.round,series.state.format)
   notice="匹配成功，正在登记已选卡组" if cloud_ranked else "云端房间已就绪，等待玩家选座";changed.emit())
 changed.connect(func():
  if cloud_mode and is_host and transport.online and transport.relay_seat>0 and not room_id.is_empty():
   var key=JSON.stringify([series.state.status,series.state.round,cloud_room_name,series.state.ready,series.state.format])
   if key!=cloud_published:cloud_published=key;transport.relay_update(series.state.status,cloud_room_name,series.state.ready,series.state.round,series.state.format)
  report_match_result())
 discovery.rooms_changed.connect(func():changed.emit())
 discovery.start()
func refresh_rules():
 var manifest=FileAccess.get_file_as_string("res://net/rules_manifest.json")
 var base=Duel.DB.load_cards()
 for id in base.keys():
  if not base[id].get("mod_namespace","").is_empty():base.erase(id)
 var cards=JSON.stringify(base)
 mod_config=Duel.Mods.Registry.shared().manifest()
 fingerprint=(VERSION+manifest+cards).sha256_text()
 legacy_fingerprint=("1.2"+manifest+cards).sha256_text()
func save_identity() -> bool:
 var err=Journal.save_to(storage+"/identity.bin",identity)
 if err!=OK:error_raised.emit("无法保存联机身份："+error_string(err));return false
 return true
func save_ranked_recovery():
 if not ranked_match_pending():return
 var saved={"account":cloud_account,"fingerprint":fingerprint,"is_host":is_host,"room_id":room_id,"cloud_match_id":cloud_match_id,"address":address,"port":port,"relay_code":relay_code,"relay_websocket":relay_websocket,"cloud_slot":cloud_slot,"match_room_public":match_room_public,"match_mode":match_mode,"match_deck":match_deck,"status":room.get("status","lobby"),"deadline":disconnect_deadline_unix}
 saved.competition_match_id=competition_match_id
 saved.competition_format=competition_format
 if identity.get("ranked_resume",{})==saved:return
 identity.ranked_resume=saved;save_identity()
func clear_ranked_recovery():
 if not cloud_ranked or read_only:return
 identity.ranked_resume={}
 if str(identity.get("resume",{}).get("cloud_match_id",""))==cloud_match_id:identity.resume={}
 save_identity()
func saved_ranked_recovery() -> Dictionary:
 var saved=identity.get("ranked_resume",{}).duplicate(true)
 if not identity.has("ranked_resume"):
  # Older clients stored host and guest recovery separately.
  var hosted=Journal.load_from(storage+"/host.bin")
  var joined=identity.get("resume",{})
  var host_active=not str(hosted.get("cloud_match_id","")).is_empty() and not hosted.get("match_settled",false) and hosted.get("series",{}).get("status","") not in ["complete","aborted"]
  var guest_active=not str(joined.get("cloud_match_id","")).is_empty() and int(joined.get("cloud_slot",2))<=2 and joined.get("room_id","") not in identity.get("ended_rooms",[])
  if host_active and (not guest_active or FileAccess.get_modified_time(storage+"/host.bin")>=FileAccess.get_modified_time(storage+"/identity.bin")):
   saved=hosted.duplicate(true);saved.is_host=true;saved.account=str(hosted.get("cloud_account",""))
  elif guest_active:
   saved=joined.duplicate(true);saved.is_host=false
 if saved.is_empty() or int(saved.get("cloud_slot",0)) not in [1,2]:return {}
 if not str(saved.get("account","")).is_empty() and str(saved.account).to_lower()!=cloud_account.to_lower():return {}
 if saved.get("room_id","") in identity.get("ended_rooms",[]):return {}
 return saved
func restore_ranked_match(saved: Dictionary) -> String:
 if saved.is_empty():return "没有待恢复的匹配对局"
 if cloud_token.is_empty():return "请先登录玩家账号，再恢复匹配"
 if str(saved.get("fingerprint",fingerprint)) not in [fingerprint,legacy_fingerprint]:return "保存匹配的规则版本与当前版本不一致"
 if saved.get("is_host",false):
  var error=restore_host();competition_match_id=str(saved.get("competition_match_id",""));competition_format=int(saved.get("competition_format",series.state.format));return error
 leave(false)
 cloud_ranked=true;cloud_mode=true;cloud_match_id=str(saved.cloud_match_id);relay_code=str(saved.relay_code)
 if str(identity.get("resume",{}).get("cloud_match_id",""))!=cloud_match_id:identity.resume={}
 address=str(saved.address);port=int(saved.port);relay_websocket=bool(saved.get("relay_websocket",true));cloud_slot=int(saved.cloud_slot);seat=cloud_slot-1
 room_id=str(saved.get("room_id",""));match_room_public=saved.get("match_room_public",true)==true;match_deck=saved.get("match_deck",{}).duplicate(true)
 match_mode=str(saved.get("match_mode","ranked"))
 competition_match_id=str(saved.get("competition_match_id",""))
 competition_format=int(saved.get("competition_format",Series.BO1_SIDEBOARD))
 series=Series.new();series.setup(match_format(),true,match_rule_set());series.state.match_mode=match_mode
 room=series.public_state(seat);room.status=str(saved.get("status","lobby"))
 disconnect_deadline_unix=float(saved.get("deadline",identity.get("resume",{}).get("deadline",0.0)))
 if disconnect_deadline_unix<=0:disconnect_deadline_unix=Time.get_unix_time_from_system()+reconnect_limit_ms()/1000.0
 disconnected_at=maxi(1,Time.get_ticks_msec());retry_at=0
 return reconnect_ranked_guest()
func reconnect_ranked_guest() -> String:
 var error=join_relay_room(("ws://" if relay_websocket else "")+address+":"+str(port),relay_code,true,cloud_slot)
 resume_requested=str(identity.get("resume",{}).get("cloud_match_id",""))==cloud_match_id and not str(identity.get("resume",{}).get("token","")).is_empty()
 if not error.is_empty():notice="正在恢复原匹配："+error;changed.emit()
 return error
func set_display_name(value: String):identity.nickname=Identity.nickname(value);save_identity()
func local_actor() -> int:
 if not is_host:return seat
 if not cloud_mode:return 0
 return cloud_slot-1 if cloud_slot in [1,2] else -1
func actor_for_peer(id: int) -> int:
 if not is_host:return -1
 if not cloud_mode:return 1 if id==remote_peer else -1
 for actor in range(2):
  if actor!=local_actor() and actor<cloud_peer_ids.size() and int(cloud_peer_ids[actor])==id:return actor
 return -1
func peer_for_actor(actor: int) -> int:
 if not is_host or actor==local_actor():return 0
 if cloud_mode:return int(cloud_peer_ids[actor]) if actor<cloud_peer_ids.size() else 0
 return remote_peer if actor==1 else 0
func record_for_actor(actor: int) -> Dictionary:
 return cloud_player_records[actor] if cloud_mode else guest if actor==1 else {}
func send_actor(actor: int,packet: Dictionary):
 var target=peer_for_actor(actor)
 if target>0:transport.send_to(target,packet)
func cloud_players_ready() -> bool:
 if cloud_seats[0].is_empty() or cloud_seats[1].is_empty():return false
 for actor in range(2):
  if actor!=local_actor() and (peer_for_actor(actor)<=0 or cloud_player_records[actor].is_empty()):return false
 return true
func on_cloud_seats(seats: Array,peer_ids: Array):
 if not cloud_mode:return
 cloud_seats=seats.duplicate()
 if is_host and peer_ids.size()==8:
  var previous=cloud_peer_ids.duplicate()
  cloud_peer_ids=peer_ids.duplicate()
  var players_changed=series.state.status=="lobby" and previous.size()==8 and (previous[0]!=cloud_peer_ids[0] or previous[1]!=cloud_peer_ids[1])
  if players_changed:
   for actor in range(2):
    if previous[actor]!=cloud_peer_ids[actor]:
     cloud_player_records[actor]={};cloud_player_acks[actor]=false
     series.state.decks[actor]=Series.entertainment_deck(series.state.format) if Series.is_entertainment(series.state.format) else {};series.state.ready[actor]=false
     var new_peer=int(cloud_peer_ids[actor])
     if new_peer>1:transport.send_to(new_peer,{"type":"seat_sync"})
   connected=false;paused=true
  if series.state.status=="lobby":
   for actor in range(2):series.state.names[actor]=cloud_seats[actor] if not cloud_seats[actor].is_empty() else "等待玩家"
  if players_changed:
   for actor in range(2):
    if peer_for_actor(actor)>0 and not cloud_player_records[actor].is_empty():
     cloud_player_acks[actor]=false
     send_actor(actor,{"type":"room","room":series.public_state(actor),"sequence":sequence,"ack_id":receipts[actor]})
  if is_instance_valid(spectator_hub):
   for actor in range(2):spectator_hub.watchers.erase(int(cloud_peer_ids[actor]))
  room=series.public_state(local_actor())
  persist()
  if not cloud_ranked:
   for peer_id in cloud_peer_ids:
    if int(peer_id)>1 and peer_id not in previous:room_joined.emit()
 changed.emit()
func on_cloud_seat_changed(slot: int,role: String):
 if not cloud_mode or slot<1 or slot>8:return
 var was_observer=read_only
 var old_slot=cloud_slot
 cloud_slot=slot
 read_only=slot>=3
 seat=slot-1 if slot<=2 else 1
 if is_host:
  if slot<=2:cloud_player_acks[slot-1]=true
  room=series.public_state(local_actor())
  persist()
  changed.emit();return
 if old_slot!=slot or was_observer!=read_only:
  room_id="";room={};connected=false;paused=true;joining=true;resume_requested=false
  snapshots.clear();latest_snapshot={}
  if 1 in transport.peers:on_connect(1)
 changed.emit()
func can_move_cloud_seats() -> bool:
 return cloud_mode and not cloud_ranked and is_host and series.state.status=="lobby" and series.state.round==0
func move_cloud_seat(from_slot: int,to_slot: int):
 if not can_move_cloud_seats():return
 if from_slot<1 or from_slot>8 or to_slot<1 or to_slot>8:return
 if from_slot<=2 and series.state.ready[from_slot-1] or to_slot<=2 and series.state.ready[to_slot-1]:return
 if transport.relay_seat==0:return
 transport.relay_move(from_slot,to_slot)
func create_room(format_value: int=3,strict: bool=true,game_port: int=47861,interface_address: String="*",rule_set: String="unrestricted") -> String:
 if Series.is_entertainment(format_value):strict=true;rule_set=Series.RuleSet.UNRESTRICTED
 if rule_set not in Series.RuleSet.IDS:return "规则集无效"
 if rule_set==Series.RuleSet.MOD and mod_config.is_empty():return "请先在设置中启用模组"
 if game_port<1024 or game_port>=65535:return "对战端口须在 1024 至 65534 之间（下一端口用于观战）"
 leave(false);is_host=true;seat=0;port=game_port;bind_address=interface_address
 var err=transport.host_room(port,bind_address)
 if err!=OK:return "无法建房："+error_string(err)
 series=Series.new();series.setup(format_value,strict,rule_set);series.state.names[0]=identity.nickname
 room_id=Identity.token();guest={};applicant={};sequence=0;command_results={};receipts=["",""];replying=["",""];authority=null
 connected=false;paused=true;rejected=false;notice="等待玩家加入";room=series.public_state(0)
 start_spectators()
 discovery.start(true,metadata(),bind_address)
 if not persist():transport.close();return notice
 changed.emit();return ""
func start_matchmaking(server_address: String,deck: Dictionary={},public_room: bool=true,mode: String="ranked",competition: String="",game_format: int=Series.BO1_SIDEBOARD) -> String:
 if Series.deck_has_mods(deck):return "模组卡组请创建使用模组规则集的房间，不能加入普通匹配"
 if cloud_token.is_empty():return "请先登录玩家账号，再进入自动匹配"
 if mode not in MATCH_MODES:return "匹配模式无效"
 if not competition.is_empty():
  if game_format not in [Series.BO1,Series.BO1_SIDEBOARD,Series.BO3,Series.EXPLORATION,Series.EXPLORATION_RANDOM]:return "比赛对局赛制无效"
  var expected_mode="exploration_random" if game_format==Series.EXPLORATION_RANDOM else "exploration" if game_format==Series.EXPLORATION else "casual"
  if mode!=expected_mode:return "比赛对局模式与指定赛制不一致"
 if mode in Series.Exploration.MODES:deck=Series.Exploration.deck(mode=="exploration_random")
 var rule_set=MATCH_RULE_SET if mode=="ranked" else Series.RuleSet.UNRESTRICTED
 var deck_error=match_deck_error(deck,mode)
 if not deck_error.is_empty():return "请先选择符合%s的匹配卡组：" % Series.RuleSet.label_for(rule_set)+deck_error
 if not server_address.begins_with("ws://"):return "自动匹配需要云端 WebSocket 地址"
 var endpoint=Endpoint.parse(server_address.substr(5),47862)
 if endpoint.has("error"):return endpoint.error
 var resolved=Endpoint.resolve(endpoint.host)
 if resolved.is_empty():return "无法解析中转服务器地址"
 leave(false);cloud_mode=true;cloud_ranked=true;relay_websocket=true;address=endpoint.host;port=endpoint.port
 match_deck=Series.Store.clean_deck(deck).duplicate(true)
 match_mode=mode
 competition_match_id=competition
 competition_format=game_format
 match_room_public=public_room
 matchmaking=true;match_connect_started=maxi(1,Time.get_ticks_msec());match_wait_seconds=0;match_rank_gap=0;match_settled=false
 var error=transport.relay_match(resolved,port,cloud_token,fingerprint,JSON.stringify(match_deck).sha256_text(),match_room_public,match_mode,competition_match_id)
 if error!=OK:leave(false);return "无法连接匹配服务器："+error_string(error)
 notice="正在加入自动匹配队列";changed.emit();return ""

func cancel_matchmaking():
 if not matchmaking:return
 leave(false);notice="已取消自动匹配";changed.emit()

func register_match_deck(actor: int,deck: Dictionary) -> String:
 var validation=match_deck_error(deck,match_mode)
 if not validation.is_empty():return validation
 if not deck.get("id") is String:return "匹配卡组缺少标识"
 var hashes=series.state.get("deck_hashes",[])
 if hashes.size()!=2 or JSON.stringify(Series.Store.clean_deck(deck)).sha256_text()!=str(hashes[actor]):return "匹配卡组与入队登记不一致，请重新匹配"
 if match_mode in Series.Exploration.MODES:return series.ready(actor)
 var error=series.set_deck(actor,deck)
 if not error.is_empty():return error
 return series.ready(actor)

func on_match_found(info: Dictionary):
 if not matchmaking:return
 if not competition_match_id.is_empty() and (str(info.get("match_id",""))!=competition_match_id or not info.get("tournament",false) or int(info.get("format",0))!=competition_format):
  on_failure("中转服务器未确认比赛对阵，请刷新比赛页面后重试");return
 if str(info.get("mode","ranked"))!=match_mode or match_mode!="ranked" and str(info.get("rule_set",""))!=match_rule_set() or match_mode in Series.Exploration.MODES and int(info.get("format",0))!=match_format():
  on_failure("中转服务器未确认%s匹配规则，请更新服务端后重试" % match_caption());return
 if not match_room_public and info.get("public",true)!=false:
  on_failure("中转服务器未确认私人房间，请更新服务端后重试");return
 match_room_public=info.get("public",true)==true
 matchmaking=false;match_connect_started=0;cloud_ranked=true;cloud_match_id=str(info.match_id);relay_code=str(info.room)
 is_host=str(info.role)=="host";cloud_slot=int(info.seat);seat=cloud_slot-1;read_only=false
 cloud_room_name=match_caption()+" · "+match_format_caption()
 series=Series.new();series.setup(match_format(),true,match_rule_set());series.state.match_id=cloud_match_id
 series.state.ranked=match_mode=="ranked";series.state.match_mode=match_mode;series.state.deck_hashes=info.get("deck_hashes",[])
 if match_mode=="ranked" and info.get("ranks") is Array:series.state.ranks=info.ranks.duplicate(true)
 if is_host:
  var error=register_match_deck(seat,match_deck)
  if not error.is_empty():on_failure(error);return
 series.state.names[seat]=cloud_nickname
 cloud_player_acks=[is_host,false];cloud_player_records=[{},{}];cloud_peer_ids=[]
 room=series.public_state(seat);paused=true;connected=false;rejected=false
 identity.resume={}
 if is_host:
  start_cloud_spectators()
  room_id=Identity.token();persist()
 else:joining=true;join_stage="connecting";remote_last_seen=Time.get_ticks_msec()
 start_disconnect_wait()
 save_ranked_recovery()
 notice="匹配成功，正在同步对手";match_found.emit();changed.emit()

func on_match_settled(info: Dictionary):
 if not cloud_ranked or str(info.get("match_id",""))!=cloud_match_id:return
 match_settled=true
 var winner=int(info.get("winner",-2))
 if winner in [0,1]:
  if room.get("status","")!="complete":
   if is_host:
    series.forfeit(1-winner);room=series.public_state(seat);persist()
   else:
    room.status="complete";room.winner=winner;room.forfeit=1-winner
    room.end_reason="对方掉线超时，匹配已结算" if winner==seat else "掉线超时，匹配判负"
   paused=true;connected=false;joining=false
   if not latest_snapshot.is_empty():latest_snapshot.room=room.duplicate(true)
  if match_mode!="ranked":notice=match_caption()+"对局结束 · 不影响段位和 Elo"
  else:
   notice="匹配已结算 · 我的 Elo：%d（%+d）" % [int(info.get("elo",0)),int(info.get("delta",0))]
   if info.get("rank") is Dictionary:notice+=" · "+preload("res://scripts/rank_badge.gd").caption(info.rank)
 else:
  if is_host:series.abort();room=series.public_state(seat);persist()
  elif not room.is_empty():room.status="aborted";room.winner=-2
  paused=true;connected=false;joining=false;notice="匹配取消，不计胜负和 Elo"
 connected=false;paused=true;joining=false;busy=false;metrics.reset()
 var resolution=info.get("resolution",{})
 if resolution is Dictionary:
  var reason=str(resolution.get("reason",""))
  if reason=="player_link_timeout":
   var detail="服务器确认：本方连接中断且未在期限内恢复，判负" if winner!=seat else "服务器确认：对方连接中断且未在期限内恢复，判对方负"
   room.end_reason=detail;notice=detail+" · "+notice
  elif reason in ["sync_unconfirmed","both_links_unavailable","server_transport_error"]:
   notice="服务器无法确认单方断线责任，本场取消，不计胜负"
   room.end_reason=notice
  if is_host:series.state.end_reason=room.get("end_reason","");persist()
  if not latest_snapshot.is_empty():latest_snapshot.room=room.duplicate(true)
 clear_ranked_recovery()
 if room.get("end_cause","")=="response_timeout":release_response_timeout()
 changed.emit()

func on_relay_link_status(info: Dictionary):
 if not ranked_match_pending() or str(info.get("match_id",""))!=cloud_match_id or info.get("source","")!="relay_observation":return
 if not info.get("states") is Array or info.states.size()!=2:return
 relay_link_states=info.states.duplicate()
 if not paused and connected:return
 notice=relay_connection_caption()
 changed.emit()

func relay_connection_caption() -> String:
 if transport==null or transport.last_server_seen<0 or Time.get_ticks_msec()-transport.last_server_seen>10000:return "本端与服务器失联，断线责任待核验"
 if relay_link_states.size()!=2 or seat not in [0,1]:return "正在向服务器核验连接状态"
 if relay_link_states[seat]=="offline":return "服务器确认：本方链路异常"
 if relay_link_states[1-seat]=="offline":return "服务器确认：对方链路异常"
 if relay_link_states.has("recovering"):return "连接已恢复，正在同步原对局"
 return "双方服务器连接正常，正在恢复同步"

func network_diagnostic(cause: String):
 var now=Time.get_ticks_msec()
 print("client_network ",JSON.stringify({"at":Time.get_unix_time_from_system(),"cause":cause,"match_id":cloud_match_id,"seat":seat+1,"host":is_host,"peer_silence_ms":maxi(0,now-remote_last_seen),"server_silence_ms":maxi(0,now-transport.last_server_seen) if transport!=null and transport.last_server_seen>=0 else -1,"frame_gap_ms":last_network_frame_gap,"server_states":relay_link_states}))

func on_observed_room_closed(info: Dictionary):
 if not read_only:return
 room.status="complete" if int(info.get("winner",-2)) in [0,1] else "aborted"
 room.winner=int(info.get("winner",-2));room.end_reason=str(info.get("message","匹配对战已结束，房间已关闭"))
 if not latest_snapshot.is_empty():latest_snapshot.room=room.duplicate(true)
 connected=false;paused=true;joining=false;rejected=true;notice=room.end_reason
 transport.close()
 changed.emit()

func create_relay_room(server_address: String,format_value: int=3,strict: bool=true,rule_set: String="unrestricted",title: String="",password: String="",chosen_slot: int=1) -> String:
 if Series.is_entertainment(format_value):strict=true;rule_set=Series.RuleSet.UNRESTRICTED
 if rule_set not in Series.RuleSet.IDS:return "规则集无效"
 if rule_set==Series.RuleSet.MOD and mod_config.is_empty():return "请先在设置中启用模组"
 if cloud_token.is_empty():return "请先登录玩家账号，再进入云端"
 if chosen_slot not in [1,2]:return "请选择 1 或 2 号对战位"
 if password.length()>32:return "房间密码不能超过 32 个字符"
 var websocket=server_address.begins_with("ws://")
 var endpoint=Endpoint.parse(server_address.substr(5) if websocket else server_address,47862)
 if endpoint.has("error"):return endpoint.error
 var resolved=Endpoint.resolve(endpoint.host)
 if resolved.is_empty():return "无法解析中转服务器地址"
 leave(false);is_host=true;seat=chosen_slot-1;cloud_mode=true;relay_websocket=websocket;address=endpoint.host;port=endpoint.port
 cloud_slot=chosen_slot;cloud_room_name=title.strip_edges().left(30);cloud_password_hash=password.sha256_text() if not password.is_empty() else ""
 cloud_seats=["","","","","","", "", ""];cloud_seats[chosen_slot-1]=cloud_nickname
 cloud_peer_ids=[];cloud_player_records=[{},{}];cloud_player_acks=[false,false];cloud_player_acks[chosen_slot-1]=true;cloud_peer_seen={}
 if cloud_room_name.is_empty():cloud_room_name=cloud_nickname+"的房间"
 elif not cloud_room_name.begins_with(cloud_nickname):cloud_room_name=cloud_nickname+" · "+cloud_room_name
 relay_code=Identity.token().left(12).to_upper();room_id=Identity.token()
 var options={"seat":cloud_slot,"name":cloud_room_name,"password_hash":cloud_password_hash,"format":format_value,"rule_set":rule_set,"version":fingerprint}
 var err=transport.relay_host(resolved,port,relay_code,relay_websocket,cloud_token,options)
 if err!=OK:cloud_mode=false;return "无法连接中转服务器："+error_string(err)
 series=Series.new();series.setup(format_value,strict,rule_set);series.state.names[chosen_slot-1]=cloud_nickname
 guest={};applicant={};sequence=0;command_results={};receipts=["",""];replying=["",""];authority=null
 connected=false;paused=true;rejected=false;notice="正在创建云端房间";room=series.public_state(seat)
 start_cloud_spectators()
 if not persist():transport.close();return notice
 changed.emit();return ""
func start_spectators():
 if is_instance_valid(spectator_hub):spectator_hub.close();spectator_hub.queue_free()
 spectator_hub=preload("res://net/spectator_hub.gd").new();add_child(spectator_hub);spectator_hub.start(self)
func start_cloud_spectators():
 if is_instance_valid(spectator_hub):spectator_hub.close();spectator_hub.queue_free()
 spectator_hub=preload("res://net/spectator_hub.gd").new();add_child(spectator_hub);spectator_hub.start_cloud(self)
func join_spectator(host_address: String,game_port: int=47861) -> String:
 var endpoint=Endpoint.parse(host_address,game_port)
 if endpoint.has("error"):return endpoint.error
 if endpoint.port>=65535:return "观战需要对战端口的下一端口；请输入小于 65535 的对战端口"
 var resolved=Endpoint.resolve(endpoint.host)
 if resolved.is_empty():return "无法解析房主域名，请检查地址或网络连接"
 leave(false);is_host=false;read_only=true;seat=0;address=endpoint.host;port=endpoint.port
 var error=transport.join_room(resolved,port+1)
 if error!=OK:return "无法连接观战端口："+error_string(error)
 joining=true;remote_last_seen=Time.get_ticks_msec();notice="正在加入观战";changed.emit();return ""
func metadata() -> Dictionary:
 return {"room_id":room_id,"name":identity.nickname,"port":port,"format":series.state.format,"rule_set":series.state.get("rule_set","unrestricted"),"players":2 if connected else 1,"status":series.state.status,"version":fingerprint,"spectate":is_instance_valid(spectator_hub) and spectator_hub.listening}
func join_room(host_address: String,game_port: int=47861,resume: bool=false) -> String:
 var endpoint=Endpoint.parse(host_address,game_port)
 if endpoint.has("error"):return endpoint.error
 var resolved=Endpoint.resolve(endpoint.host)
 if resolved.is_empty():return "无法解析房主域名，请检查地址或网络连接"
 if not resume:leave(false)
 is_host=false;seat=1;address=endpoint.host;port=endpoint.port;rejected=false;resume_requested=resume
 var err=transport.join_room(resolved,port)
 if err!=OK:return "无法连接："+error_string(err)
 joining=true;join_stage="connecting";paused=true;connected=false;notice="正在连接房主";remote_last_seen=Time.get_ticks_msec();retry_at=remote_last_seen
 changed.emit();return ""
func join_relay_room(server_address: String,code: String,resume: bool=false,chosen_slot: int=2,password: String="") -> String:
 if cloud_token.is_empty():return "请先登录玩家账号，再进入云端"
 var websocket=server_address.begins_with("ws://")
 var endpoint=Endpoint.parse(server_address.substr(5) if websocket else server_address,47862)
 if endpoint.has("error"):return endpoint.error
 var normalized=code.strip_edges().to_upper()
 if normalized.length()!=12 or not normalized.is_valid_hex_number():return "云端房间已失效，请刷新列表"
 if chosen_slot<1 or chosen_slot>8:return "请选择 1–8 号座位"
 var resolved=Endpoint.resolve(endpoint.host)
 if resolved.is_empty():return "无法解析中转服务器地址"
 if not resume:leave(false)
 if resume:
  cloud_match_id=str(identity.get("resume",{}).get("cloud_match_id",cloud_match_id));cloud_ranked=not cloud_match_id.is_empty()
  match_room_public=identity.get("resume",{}).get("match_room_public",match_room_public)==true
  match_mode=str(identity.get("resume",{}).get("match_mode",match_mode))
 is_host=false;seat=chosen_slot-1 if chosen_slot<=2 else 1;cloud_mode=true;relay_websocket=websocket;relay_code=normalized;address=endpoint.host;port=endpoint.port;rejected=false;resume_requested=resume;read_only=chosen_slot>=3;cloud_slot=chosen_slot
 cloud_password_hash=password.sha256_text() if not password.is_empty() else str(identity.get("resume",{}).get("password_hash","")) if resume else ""
 var options={"seat":chosen_slot,"password_hash":cloud_password_hash,"version":fingerprint,"resume":resume,"match_id":cloud_match_id}
 var err=transport.relay_join(resolved,port,relay_code,relay_websocket,cloud_token,options,read_only)
 if err!=OK:return "无法连接中转服务器："+error_string(err)
 joining=true;join_stage="connecting";paused=true;connected=false;notice="正在加入云端座位";remote_last_seen=Time.get_ticks_msec();retry_at=remote_last_seen
 changed.emit();return ""
func resume_guest(new_address: String="") -> String:
 var saved=identity.get("resume",{})
 if saved.is_empty():return "没有可恢复的客机连接"
 if saved.get("room_id","") in identity.get("ended_rooms",[]):return "该对局已结束，不能重连"
 room_id=saved.room_id
 if disconnected_at==0 and float(saved.get("deadline",0.0))>0:
  disconnect_deadline_unix=float(saved.deadline)
  disconnected_at=maxi(1,Time.get_ticks_msec()-reconnect_limit_ms()+int((disconnect_deadline_unix-Time.get_unix_time_from_system())*1000.0))
  wait_choice_pending=Time.get_unix_time_from_system()>=disconnect_deadline_unix
 if saved.get("cloud_mode",false):return join_relay_room(("ws://" if saved.get("relay_websocket",false) else "")+saved.address+":"+str(saved.port) if new_address.is_empty() else new_address,str(saved.get("relay_code","")),true,int(saved.get("cloud_slot",2)))
 return join_room(saved.address if new_address.is_empty() else new_address,int(saved.port),true)
func restore_host() -> String:
 var data=Journal.load_from(storage+"/host.bin")
 if data.is_empty():return "没有保存的房主对局"
 if data.get("cloud_mode",false) and cloud_token.is_empty():return "请先登录玩家账号，再恢复云端房间"
 if data.get("fingerprint","") not in [fingerprint,legacy_fingerprint]:return "保存对局的规则版本与当前版本不一致"
 if Series.uses_mods(data.series) and data.series.get("mods",[])!=mod_config:return "恢复房间失败：模组配置不一致"
 if data.series.get("status","")=="aborted" or data.room_id in identity.get("ended_rooms",[]):return "该对局已结束，不能恢复"
 leave(false);is_host=true;seat=0
 room_id=data.room_id;port=data.port;bind_address=data.get("bind_address","*");guest=data.guest
 cloud_mode=bool(data.get("cloud_mode",false));relay_code=str(data.get("relay_code",""));relay_websocket=bool(data.get("relay_websocket",false));address=str(data.get("address",""))
 cloud_match_id=str(data.get("cloud_match_id",""));cloud_ranked=not cloud_match_id.is_empty();match_settled=bool(data.get("match_settled",false))
 match_deck=data.get("match_deck",{}).duplicate(true)
 match_mode=str(data.get("match_mode","ranked"))
 competition_match_id=str(data.get("competition_match_id",""));competition_format=int(data.get("competition_format",data.series.get("format",Series.BO1_SIDEBOARD)))
 match_room_public=data.get("match_room_public",true)==true
 series=Series.new();series.state=data.series;sequence=data.sequence;command_results=data.command_results;receipts=data.get("receipts",["",""])
 undo_history.entries=data.get("undo_entries",[]);rewind_events=data.get("rewind_events",[]);undo_request={}
 if not data.engine.is_empty():
  authority=Duel.new()
  var mod_error=Codec.restore(authority,data.engine)
  if not mod_error.is_empty():return mod_error
 refresh_undo_status()
 cloud_slot=int(data.get("cloud_slot",1));cloud_room_name=str(data.get("cloud_room_name",cloud_nickname+"的房间"));cloud_password_hash=str(data.get("cloud_password_hash",""))
 cloud_seats=data.get("cloud_seats",["","","","","","", "", ""]).duplicate()
 cloud_player_records=data.get("cloud_player_records",[{},{}]).duplicate(true)
 cloud_player_acks=[false,false]
 if cloud_mode:
  seat=cloud_slot-1 if cloud_slot<=2 else 1
  read_only=cloud_slot>=3
  if cloud_slot<=2:cloud_player_acks[cloud_slot-1]=true
 var options={"seat":cloud_slot,"name":cloud_room_name,"password_hash":cloud_password_hash,"format":series.state.format,"rule_set":series.state.get("rule_set","unrestricted"),"version":fingerprint,"resume":cloud_mode,"match_id":cloud_match_id}
 var err=transport.relay_host(Endpoint.resolve(address),port,relay_code,relay_websocket,cloud_token,options) if cloud_mode else transport.host_room(port,bind_address)
 paused=true;connected=false;notice="已恢复对局，等待原玩家重连";room=series.public_state(local_actor())
 recording.begin_capture(storage+"/capture.bin",series.state.match_id)
 disconnect_deadline_unix=float(data.get("disconnect_deadline_unix",0.0))
 if disconnect_deadline_unix<=0:disconnect_deadline_unix=Time.get_unix_time_from_system()+reconnect_limit_ms()/1000.0
 disconnected_at=maxi(1,Time.get_ticks_msec()-reconnect_limit_ms()+int((disconnect_deadline_unix-Time.get_unix_time_from_system())*1000.0))
 wait_choice_pending=series.state.status!="complete" and Time.get_unix_time_from_system()>=disconnect_deadline_unix
 if ranked_match_pending():wait_choice_pending=false
 if err!=OK:return "无法恢复监听："+error_string(err)
 if not cloud_mode:
  start_spectators()
  discovery.start(true,metadata(),bind_address)
 else:start_cloud_spectators()
 if authority!=null:enqueue_snapshot(make_host_observer_snapshot([],true) if cloud_mode and read_only else make_snapshot(local_actor(),[],true))
 changed.emit();return ""
func persist() -> bool:
 if not is_host:return true
 if authority!=null:ResponseClock.sync(authority)
 var data={"fingerprint":fingerprint,"room_id":room_id,"port":port,"bind_address":bind_address,"cloud_mode":cloud_mode,"relay_code":relay_code,"relay_websocket":relay_websocket,"address":address,"cloud_slot":cloud_slot,"cloud_room_name":cloud_room_name,"cloud_password_hash":cloud_password_hash,"cloud_seats":cloud_seats,"cloud_player_records":cloud_player_records,"guest":guest,"series":series.state,"sequence":sequence,"command_results":command_results,"receipts":receipts,"disconnect_deadline_unix":disconnect_deadline_unix,"engine":Codec.capture(authority) if authority!=null else {}}
 data.undo_entries=undo_history.entries;data.rewind_events=rewind_events
 data.cloud_match_id=cloud_match_id;data.match_settled=match_settled;data.match_room_public=match_room_public
 data.cloud_account=cloud_account;data.match_deck=match_deck;data.match_mode=match_mode
 data.competition_match_id=competition_match_id;data.competition_format=competition_format
 var err=Journal.save_to(storage+"/host.bin",data)
 if err!=OK:paused=true;notice="无法保存对局，已暂停："+error_string(err);error_raised.emit(notice);return false
 save_ranked_recovery();return true
func leave(forget: bool=true):
 response_timeout_release_at=0
 report_match_result(true)
 undo_history.entries.clear();undo_request={};rewind_events.clear()
 rejected_peers.clear();join_stage="";resume_requested=false
 if is_instance_valid(spectator_hub):spectator_hub.close();spectator_hub.queue_free();spectator_hub=null
 read_only=false;recording=preload("res://scripts/replay_archive.gd").new()
 metrics.reset()
 if transport and connected:
  if is_host and cloud_mode:
   for actor in range(2):send_actor(actor,{"type":"leave"})
  else:transport.send_to(remote_peer,{"type":"leave"})
 if transport:transport.close()
 if discovery:discovery.start()
 connected=false;paused=true;joining=false;remote_peer=0;room_id="";room={};applicant={};authority=null;busy=false;snapshots.clear();latest_snapshot={};local_game_id="";notice="";inflight={};disconnected_at=0;disconnect_deadline_unix=0.0;wait_choice_pending=false;wait_choice_confirmed=false;rejected=false;cloud_mode=false;relay_code="";relay_websocket=false;cloud_slot=0;cloud_room_name="";cloud_password_hash="";cloud_published=""
 cloud_seats=["","","","","","", "", ""];cloud_peer_ids=[];cloud_player_records=[{},{}];cloud_player_acks=[false,false];cloud_peer_seen={}
 cloud_ranked=false;cloud_match_id="";matchmaking=false;match_mode="ranked";match_deck={};match_room_public=true;match_queued=-1;match_wait_seconds=0;match_rank_gap=0;match_settled=false;last_result_report=0
 competition_match_id=""
 competition_format=Series.BO1_SIDEBOARD
 match_connect_started=0
 relay_link_states=[]
 if forget:identity.resume={};save_identity()
func on_connect(id: int):
 remote_last_seen=Time.get_ticks_msec()
 if is_host:return
 remote_peer=1
 if read_only:
  transport.send_to(1,{"type":"watch","version":fingerprint,"mods":mod_config});return
 transport.send_to(1,{"type":"hello","mods":mod_config,"match_deck":match_deck if cloud_ranked else {},"version":fingerprint,"installation":identity.installation,"name":cloud_nickname if cloud_mode else identity.nickname,"resume":identity.get("resume",{}) if resume_requested else {},"last_sequence":maxi(view_sequence,int(identity.get("resume",{}).get("sequence",0))) if resume_requested else 0})
func accept_applicant(accept: bool):
 if applicant.is_empty():return
 var id=int(applicant.peer)
 if not accept:reject_join(id,"房主拒绝或未及时确认本次加入");applicant={};changed.emit();return
 guest={"installation":applicant.installation,"token":Identity.token(),"name":applicant.name}
 series.state.names[1]=guest.name;applicant={}
 if not persist():return
 welcome(id)
func welcome(id: int,actor: int=1):
 metrics.reset();last_heartbeat=0
 if not cloud_mode:remote_peer=id;connected=true
 else:
  cloud_peer_seen[id]=Time.get_ticks_msec()
  cloud_player_acks[actor]=false
  connected=cloud_players_ready()
 paused=true;joining=false;remote_last_seen=Time.get_ticks_msec();notice="同步中";retry_at=0
 # Match deck registration in hello may already have advanced the preparation stage.
 room=series.public_state(local_actor())
 var player_record=record_for_actor(actor)
 transport.send_to(id,{"type":"welcome","room_id":room_id,"token":player_record.token,"match_id":series.state.match_id,"room":series.public_state(actor),"sequence":sequence,"ack_id":receipts[actor]})
 if authority!=null and series.state.status!="choosing":transport.send_to(id,make_snapshot(actor,[],true))
 else:transport.send_to(id,{"type":"room","room":series.public_state(actor),"sequence":sequence,"ack_id":receipts[actor]})
 changed.emit()
func authorized(id: int) -> bool:return is_host and actor_for_peer(id)>=0 and not record_for_actor(actor_for_peer(id)).is_empty() or not is_host and id==1
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
 if ranked_match_pending():on_failure("恢复匹配连接超时");return
 joining=false;rejected=true;paused=true;transport.close()
 notice="等待房主确认超时，请房主接受加入申请后重试。" if join_stage=="approval" else "无法进入云端房间，请刷新房间列表后重试。" if cloud_mode else "无法连接房主 %s:%d。请检查地址和 UDP 端口。" % [address,port]
 error_raised.emit(notice);changed.emit()
func receive(id: int,m: Dictionary):
 var type=m.get("type","")
 if not type is String:return
 if is_host and cloud_mode and transport.relay_peer_roles.get(id,"")=="watch":
  if is_instance_valid(spectator_hub):spectator_hub.receive(id,m)
  return
 if read_only and not is_host:
  receive_observer(id,m);return
 if check_reconnect_timeout(Time.get_ticks_msec()):return
 if is_host and type=="hello":
  var actor=actor_for_peer(id) if cloud_mode else 1
  if actor<0:return
  if ended():reject_join(id,"该对局已结束，不能重连");return
  if Series.uses_mods(series.state) and m.get("mods",[])!=series.state.get("mods",[]):reject_join(id,"模组配置不一致：请在设置中启用相同模组，并确保版本、接口和全部文件内容相同。");return
  if m.get("version","")!=fingerprint:reject_join(id,"游戏或卡牌规则版本不一致。请双方使用同一完整发行包（exe 和 pck）。房主校验 %s，本机校验 %s。" % [fingerprint.left(8),str(m.get("version","")).left(8)]);return
  if not m.get("installation") is String or not m.get("name") is String or not m.get("resume",{}) is Dictionary:return
  if not cloud_mode and connected and id!=remote_peer:transport.drop(id);return
  if not m.get("resume",{}).is_empty() and m.resume.get("room_id","")!=room_id:
   reject_join(id,"此地址的房间不是原对局");return
  var existing=record_for_actor(actor)
  if not existing.is_empty():
   var resume=m.get("resume",{})
   var fresh_cloud_hello=cloud_mode and series.state.status=="lobby" and m.installation==existing.installation and resume.is_empty()
   if not fresh_cloud_hello and (m.installation!=existing.installation or resume.get("room_id","")!=room_id or resume.get("token","")!=existing.token):
    reject_join(id,"席位已保留给原玩家，请使用原安装和恢复记录");return
   if int(m.get("last_sequence",0))>sequence:
    reject_join(id,"房主恢复记录早于已确认的操作，无法安全继续本局");return
   welcome(id,actor)
  elif cloud_mode:
   if cloud_ranked and series.state.status=="lobby":
    var error=register_match_deck(actor,m.get("match_deck",{}))
    if not error.is_empty():reject_join(id,error);return
    series.prepare_choice()
   cloud_player_records[actor]={"installation":m.installation.left(64),"token":Identity.token(),"name":Identity.nickname(m.name)}
   series.state.names[actor]=cloud_player_records[actor].name
   if not persist():return
   welcome(id,actor)
  else:
   var new_applicant=applicant.get("peer",0)!=id or applicant.get("installation","")!=m.installation.left(64)
   applicant={"peer":id,"installation":m.installation.left(64),"name":Identity.nickname(m.name),"at":Time.get_ticks_msec()}
   transport.send_to(id,{"type":"approval_pending"});changed.emit()
   if new_applicant:room_joined.emit()
  return
 if not authorized(id):return
 var sender_actor=actor_for_peer(id) if is_host else -1
 if is_host and type not in ["ping","pong","ack","command","room_action","leave","replay_request"]:return
 if not is_host and type not in ["ping","pong","welcome","room","state","ready_state","error","rejected","leave","approval_pending","replay_frames","seat_sync"]:return
 remote_last_seen=Time.get_ticks_msec()
 if is_host and cloud_mode:cloud_peer_seen[id]=remote_last_seen
 match type:
  "seat_sync":
   if cloud_mode and not read_only:on_connect(1)
  "replay_request":replay_exchange.serve(id,m,transport)
  "replay_frames":replay_exchange.receive(m)
  "approval_pending":
   join_stage="approval";notice="已连接，等待房主接受加入申请";changed.emit()
  "ping":transport.send_to(id,metrics.make_pong(m,Time.get_ticks_msec()),true)
  "pong":metrics.accept_pong(m,Time.get_ticks_msec())
  "rejected":rejected=true;joining=false;connected=false;paused=true;notice=str(m.get("message","加入被拒绝"));transport.close();error_raised.emit(notice);changed.emit()
  "welcome":
   if Series.uses_mods(m.room) and m.room.get("mods",[])!=mod_config:
    rejected=true;joining=false;transport.close();error_raised.emit("房主的模组配置与本机不一致");return
   if resume_requested:
    var saved=identity.get("resume",{})
    if m.get("room_id","")!=saved.get("room_id","") or m.get("token","")!=saved.get("token","") or m.get("match_id","")!=saved.get("match_id",""):
     rejected=true;joining=false;transport.close();error_raised.emit("恢复连接的房间身份不匹配");return
   metrics.reset();last_heartbeat=0
   reset_match_view(m.room)
   connected=true;joining=false;paused=true;busy=false;inflight={};room_id=m.room_id;room=m.room;sequence=m.sequence;notice="同步中"
   if recording.frames.is_empty():recording.begin_capture(storage+"/capture.bin",m.match_id if resume_requested else "")
   identity.resume={"room_id":room_id,"token":m.token,"match_id":m.match_id,"address":address,"port":port,"cloud_mode":cloud_mode,"relay_code":relay_code,"relay_websocket":relay_websocket,"cloud_slot":cloud_slot,"cloud_match_id":cloud_match_id,"match_room_public":match_room_public,"match_mode":match_mode,"password_hash":cloud_password_hash,"sequence":sequence,"deadline":disconnect_deadline_unix};save_identity();changed.emit()
   save_ranked_recovery()
  "room":
   if is_host:return
   reset_match_view(m.room)
   room=m.room;sequence=m.sequence;view_sequence=sequence;finish_receipt(m);remember_sequence();transport.send_to(1,{"type":"ack","sequence":sequence});changed.emit()
  "state":
   if is_host:return
   if m.get("room_id","")!=room_id:return
   reset_match_view(m.room)
   sequence=m.sequence;room=m.room;finish_receipt(m);remember_sequence();enqueue_snapshot(m)
   transport.send_to(1,{"type":"ack","sequence":sequence});changed.emit()
  "ack":
   if not is_host:return
   if int(m.get("sequence",-1))==sequence:
    if cloud_mode:
     cloud_player_acks[sender_actor]=true
     connected=cloud_players_ready()
     if not connected or not cloud_player_acks.all(func(value):return value):return
     var recovered=disconnected_at>0
     acknowledged=sequence;paused=false;notice="";disconnected_at=0;disconnect_deadline_unix=0.0;wait_choice_pending=false;wait_choice_confirmed=false
     if recovered and not persist():return
     for player in range(2):send_actor(player,{"type":"ready_state","sequence":sequence})
     if is_instance_valid(spectator_hub):spectator_hub.changed()
     changed.emit()
    else:
     var recovered=disconnected_at>0
     acknowledged=sequence;paused=false;notice="";disconnected_at=0;disconnect_deadline_unix=0.0;wait_choice_pending=false;wait_choice_confirmed=false
     if recovered and not persist():return
     transport.send_to(id,{"type":"ready_state","sequence":sequence})
     if is_instance_valid(spectator_hub):spectator_hub.changed()
     changed.emit()
  "ready_state":
   if not is_host:paused=false;notice="";disconnected_at=0;disconnect_deadline_unix=0.0;wait_choice_pending=false;wait_choice_confirmed=false;identity.resume.erase("deadline");save_identity();save_ranked_recovery();changed.emit()
  "command":
   if is_host:handle_command(sender_actor,m)
  "room_action":
   if is_host and m.get("action") is Dictionary:handle_room_action(sender_actor,m.action)
  "error":
   if inflight.get("id","")==m.get("ack_id",""):busy=false;inflight={}
   error_raised.emit(str(m.get("message","操作被拒绝")))
  "leave":on_disconnect(id);transport.drop(id)
func on_disconnect(id: int,cause: String="peer_departure"):
 rejected_peers.erase(id)
 if room.get("end_cause","")=="response_timeout":return
 if cloud_ranked and match_settled:return
 if not read_only:network_diagnostic(cause)
 if is_host and cloud_mode and transport.relay_peer_roles.get(id,"")=="watch":
  if is_instance_valid(spectator_hub):spectator_hub.watchers.erase(id)
  return
 if is_host and cloud_mode:
  var actor=actor_for_peer(id)
  if actor<0:return
  cloud_player_acks[actor]=false;cloud_peer_seen.erase(id)
  connected=false;paused=true;busy=false;joining=false
  if series.state.status!="lobby" or ranked_match_pending():start_disconnect_wait()
  if is_instance_valid(spectator_hub):spectator_hub.changed()
  notice="对战位玩家已离开" if series.state.status=="lobby" else "连接中断，已暂停，等待原玩家重连"
  changed.emit();return
 if read_only:
  connected=false;paused=true;notice="观战连接已断开";changed.emit();return
 if id!=remote_peer or ended() or rejected:return
 undo_request={}
 if room.has("undo_request"):room.undo_request={}
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
 if cloud_ranked and match_settled:return
 network_diagnostic("transport_failure: "+message)
 if matchmaking:
  cancel_matchmaking();notice="自动匹配失败："+message;error_raised.emit(notice);changed.emit();return
 if cloud_ranked and (message.contains("匹配房间已") or message.contains("匹配对局已结束") or message.contains("房间已关闭")):
  match_settled=true;connected=false;paused=true;joining=false;transport.close()
  if is_host:series.abort();room=series.public_state(seat)
  elif not room.is_empty():room.status="aborted";room.winner=-2
  clear_ranked_recovery()
  notice=message;error_raised.emit(notice);changed.emit();return
 if read_only and not is_host:
  if joining and room_id.is_empty():
   joining=false;rejected=true;transport.close();notice="加入观战位失败："+message;error_raised.emit(notice)
  else:
   joining=false;transport.close();retry_at=Time.get_ticks_msec();notice=message+"，正在恢复观战连接" if cloud_mode else message
  connected=false;paused=true;changed.emit();return
 if rejected or ended():return
 if ranked_match_pending():
  connected=false;paused=true;busy=false;joining=false;transport.close();retry_at=Time.get_ticks_msec()
  start_disconnect_wait()
  if disconnected_at==0:disconnected_at=maxi(1,Time.get_ticks_msec())
  notice=message+"，正在恢复原匹配";changed.emit();return
 if joining and room_id.is_empty():
  joining=false;connected=false;paused=true;rejected=true;transport.close()
  notice="加入房间失败："+message+"。请确认中转服务器或房主地址、端口及防火墙放行。"
  error_raised.emit(notice);changed.emit();return
 metrics.reset()
 connected=false;paused=true;busy=false;joining=false
 if not (cloud_mode and is_host and series.state.status=="lobby"):start_disconnect_wait()
 if cloud_mode and is_host:retry_at=Time.get_ticks_msec()
 notice=message+("，正在重连中转服务器" if cloud_mode and is_host and series.state.status=="lobby" else "，对局已暂停");changed.emit()
func start_disconnect_wait():
 if disconnected_at>0 or room_id.is_empty() and not ranked_match_pending() or room.get("status","")=="complete":return
 disconnected_at=maxi(1,Time.get_ticks_msec());disconnect_deadline_unix=Time.get_unix_time_from_system()+reconnect_limit_ms()/1000.0
 wait_choice_pending=false;wait_choice_confirmed=false
 if ranked_match_pending():transport.relay_control("match_wait")
 if is_host:persist()
 elif not identity.get("resume",{}).is_empty():identity.resume.deadline=disconnect_deadline_unix;save_identity()
 save_ranked_recovery()
func check_reconnect_timeout(now: int) -> bool:
 if matchmaking and match_connect_started>0 and now-match_connect_started>=MATCH_RECONNECT_LIMIT_MS:
  cancel_matchmaking();notice="连接匹配服务器超时（60 秒），已自动释放，请重试"
  error_raised.emit(notice);changed.emit();return true
 if ended():return true
 if ranked_match_pending():
  wait_choice_pending=false;wait_choice_confirmed=false
  if disconnected_at>0 and (now-disconnected_at>=MATCH_RECONNECT_LIMIT_MS or disconnect_deadline_unix>0 and Time.get_unix_time_from_system()>=disconnect_deadline_unix):
   if transport.online and transport.last_server_seen>=0 and now-transport.last_server_seen<10000:
    # The relay decides responsibility. Peer silence must not make us look offline.
    return false
   expire_match_connection();return true
  return false
 if disconnected_at>0 and room.get("status","")!="complete" and not wait_choice_pending and not wait_choice_confirmed and (now-disconnected_at>=RECONNECT_LIMIT_MS or disconnect_deadline_unix>0 and Time.get_unix_time_from_system()>=disconnect_deadline_unix):
  wait_choice_pending=true;changed.emit()
 return false
func expire_match_connection():
 # Release local recovery without inventing a rated result; the relay settles it.
 match_settled=true;connected=false;paused=true;joining=false;busy=false;inflight={}
 if is_host:series.abort();room=series.public_state(seat);persist()
 elif not room.is_empty():room.status="aborted";room.winner=-2
 notice="匹配连接超时（60 秒），已自动释放，请重新匹配"
 if not room.is_empty():room.end_reason=notice
 clear_ranked_recovery();transport.close();metrics.reset();changed.emit()
func continue_waiting():
 if not wait_choice_pending or ended():return
 wait_choice_pending=false;wait_choice_confirmed=true;changed.emit()
func stop_waiting():
 if not can_stop_waiting():return
 # An ended match needs local cleanup even though it needs no further settlement.
 end_disconnected_match();leave()
func end_disconnected_match():
 if ranked_match_pending() or ended() or room.get("status","")=="complete" or disconnected_at==0:return
 if room.is_empty():room=Series.new().public_state(seat)
 connected=false;paused=true;busy=false;joining=false;inflight={};rejected=true;metrics.reset()
 if is_host:
  series.abort();room=series.public_state(0);sequence+=1;persist()
 else:
  var result=Series.new();result.state=room.duplicate(true);result.abort();room=result.state
 var ended_rooms=identity.get("ended_rooms",[])
 if room_id not in ended_rooms:ended_rooms.append(room_id)
 identity.ended_rooms=ended_rooms.slice(maxi(0,ended_rooms.size()-64));identity.resume={};save_identity()
 transport.close();discovery.start();snapshots.clear()
 if not latest_snapshot.is_empty():
  var last=latest_snapshot.duplicate(true);last.room=room;last.sequence=sequence+1;last.projection.state.presentation_events=[];recording.record(last,seat)
 finish_recording()
 if is_instance_valid(spectator_hub):spectator_hub.changed()
 notice=room.end_reason;wait_choice_pending=false;wait_choice_confirmed=false;changed.emit()
func can_act(in_match: bool=false) -> bool:return not read_only and not ended() and connected and not paused and not busy and (not in_match or sequence==view_sequence and room.get("undo_request",{}).is_empty())
func submit(command: Dictionary) -> String:
 if not can_act(true):return "等待连接或同步完成"
 command_number+=1
 var packet={"type":"command","room_id":room_id,"game_id":room.get("game_id",""),"expected":view_sequence,"id":identity.installation+":"+Identity.token(),"command":command.duplicate(true)}
 busy=true;inflight=packet
 if is_host:call_deferred("handle_command",local_actor(),packet)
 else:transport.send_to(1,packet)
 return ""
func handle_command(actor: int,m: Dictionary):
 var id=m.get("id","")
 if not id is String or id.length()>160 or not m.get("command") is Dictionary:return
 replying[actor]=id
 if command_results.has(id):
  publish([],actor!=local_actor());return
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
 if authority.winner!=-2 and authority.pending.get("kind","")!="reveal_review":series.record_result(authority.winner)
 var events=authority.presentation_events.duplicate(true);authority.presentation_events.clear()
 # Passing priority alone is not a completed operation to undo.
 if not (m.command.name=="pass_priority" and authority.stack.is_empty() and authority.passes==1):undo_history.remember(authority,series.state.game_id,sequence)
 refresh_undo_status()
 if not persist():
  undo_history.entries=previous_undo
  Codec.restore(authority,before);series.state=previous_series;sequence-=1;receipts[actor]=old_receipt;command_results.erase(id);reject(actor,notice);return
 publish(events)
func reject(actor: int,message: String):
 if actor==local_actor():busy=false;inflight={};error_raised.emit(message)
 else:
  send_actor(actor,{"type":"error","message":message,"ack_id":replying[actor]})
  if authority!=null and series.state.status!="choosing":send_actor(actor,make_snapshot(actor,[],true))
  else:send_actor(actor,{"type":"room","room":series.public_state(actor),"sequence":sequence,"ack_id":replying[actor]})
func room_action(action: Dictionary):
 if not can_act():error_raised.emit("等待双方连接完成");return
 busy=true;action["_request_id"]=Identity.token();inflight={"id":action._request_id}
 action["_expected"]=view_sequence;action["_game"]=room.get("game_id","")
 if is_host:handle_room_action(local_actor(),action)
 else:transport.send_to(1,{"type":"room_action","action":action})
func handle_room_action(actor: int,action: Dictionary):
 replying[actor]=str(action.get("_request_id",""))
 if paused or not connected:return reject(actor,"等待双方连接完成")
 if action.has("_game") and action._game!=series.state.game_id:return reject(actor,"对局已变化，请重新操作")
 if str(action.get("name","")).begins_with("undo_"):
  handle_undo_action(actor,action);return
 var previous_series=series.state.duplicate(true);var old_engine=authority;var old_sequence=sequence;var previous_undo=undo_history.entries.duplicate();var previous_rewinds=rewind_events.duplicate(true);var previous_request=undo_request.duplicate(true)
 var error="";var name=action.get("name","")
 match name:
  "entertainment_mode":
   if cloud_ranked:error="匹配模式已在入队前锁定"
   elif actor!=local_actor():error="只有房主可以切换娱乐模式"
   elif not action.get("format") is int and not action.get("format") is float:error="娱乐模式无效"
   else:error=series.select_entertainment(int(action.format))
  "deck":
   if not action.get("deck") is Dictionary:return
   error="匹配卡组已在入队前锁定" if cloud_ranked and series.state.status=="lobby" else series.set_deck(actor,action.deck)
  "ready":error=series.ready(actor)
  "unready":
   if series.state.status in ["lobby","sideboarding","between"]:series.state.ready[actor]=false
   else:error="当前不能取消准备"
  "rematch":
   error="匹配已结束，请返回云端重新自动匹配" if cloud_ranked else series.rematch()
   if error.is_empty():
    authority=null;undo_history.entries.clear();undo_request={};rewind_events.clear()
  "first":
   if not action.get("first") is bool:error="请选择先手或后手"
   else:error=series.choose_first(actor,action.first)
  "concede_series":error="投降只结束当前单局，请从战场设置操作"
  _:error="未知房间操作"
 if not error.is_empty():reject(actor,error);return
 var old_receipt=receipts[actor];receipts[actor]=replying[actor]
 series.prepare_choice()
 if series.start_game():
  undo_history.entries.clear();undo_request={}
  authority=Duel.new();authority.configure_mods(Series.uses_mods(series.state));authority.player_names=series.state.names.duplicate();authority.start(series.state.decks[0],series.state.decks[1],series.state.first)
  authority.show_result(series.opening_text())
  authority.presentation_events.push_front(authority.presentation_events.pop_back())
 sequence+=1
 var events=[]
 if authority!=null:events=authority.presentation_events.duplicate(true);authority.presentation_events.clear()
 if authority!=null and authority!=old_engine:undo_history.remember(authority,series.state.game_id,sequence)
 refresh_undo_status()
 if not persist():
  undo_history.entries=previous_undo
  undo_request=previous_request;rewind_events=previous_rewinds
  series.state=previous_series;authority=old_engine;sequence=old_sequence;receipts[actor]=old_receipt;return reject(actor,notice)
 if name=="rematch":
  finish_recording()
  recording=preload("res://scripts/replay_archive.gd").new()
  snapshots.clear();latest_snapshot={};local_game_id=""
  if is_instance_valid(spectator_hub):spectator_hub.pending_events.clear()
 publish(events)
func reset_match_view(next_room: Dictionary):
 if room.is_empty() or room.get("match_id","")==next_room.get("match_id",""):return
 finish_recording()
 recording=preload("res://scripts/replay_archive.gd").new()
 snapshots.clear();latest_snapshot={};local_game_id=""
func refresh_undo_status():
 series.state.undo_used=undo_used()
 series.state.undo_request=undo_request.duplicate(true)
 series.state.undo_limit=RANKED_UNDO_LIMIT if cloud_ranked and match_mode=="ranked" else 0
 series.state.undo_available=series.state.status=="playing" and undo_request.is_empty() and (undo_budget_available(0) or undo_budget_available(1)) and undo_history.available(authority,series.state.game_id)
func undo_used() -> Array:
 var used=series.state.get("undo_used",[])
 if used is Array and used.size()==2:return used.duplicate()
 # Older shared counters cannot identify declined requests; retain identifiable requests.
 var counts=[0,0]
 for event in rewind_events:
  var actor=int(event.get("from",-1))
  if event.get("game","")==series.state.game_id and actor in [0,1]:counts[actor]+=1
 var pending_request=series.state.get("undo_request",{})
 var requester=int(pending_request.get("from",-1))
 if pending_request.get("game","")==series.state.game_id and requester in [0,1]:counts[requester]+=1
 return counts
func undo_budget_available(actor: int) -> bool:
 if not cloud_ranked or match_mode!="ranked":return true
 return actor in [0,1] and int(undo_used()[actor])<RANKED_UNDO_LIMIT
func publish_undo_status():
 refresh_undo_status();room=series.public_state(local_actor())
 busy=false;inflight={}
 for actor in range(2):send_actor(actor,{"type":"room","room":series.public_state(actor),"sequence":sequence,"ack_id":receipts[actor]})
 if is_instance_valid(spectator_hub):spectator_hub.changed()
 changed.emit()
func handle_undo_action(actor: int,action: Dictionary):
 if authority==null or series.state.status!="playing":return reject(actor,"当前不能悔棋")
 var name=action.get("name","")
 if name=="undo_request":
  if not undo_request.is_empty():return reject(actor,"已有悔棋请求")
  if int(action.get("_expected",-1))!=sequence or action.get("_game","")!=series.state.game_id:return reject(actor,"战况已更新，请重新发起悔棋")
  if not undo_budget_available(actor):return reject(actor,"段位匹配赛每局每人最多请求悔棋 %d 次，你的次数已用完" % RANKED_UNDO_LIMIT)
  if not undo_history.available(authority,series.state.game_id):return reject(actor,"对抗为空且有上一可操作战况时才能悔棋")
  var previous_used=undo_used()
  series.state.undo_used=previous_used.duplicate();series.state.undo_used[actor]+=1
  undo_request={"id":Identity.token(),"from":actor,"game":series.state.game_id,"target":undo_history.previous(authority,series.state.game_id).sequence}
  refresh_undo_status()
  if not persist():
   undo_request={};series.state.undo_used=previous_used;refresh_undo_status();return reject(actor,notice)
 elif name in ["undo_accept","undo_decline","undo_cancel"]:
  if undo_request.is_empty() or action.get("ticket","")!=undo_request.id:return reject(actor,"悔棋请求已失效")
  if name=="undo_cancel" and actor!=undo_request.from or name!="undo_cancel" and actor==undo_request.from:return reject(actor,"只能由另一位玩家决定是否同意")
  if name=="undo_accept":
   var old=Codec.capture(authority);var checkpoints=undo_history.entries.duplicate();var request=undo_request.duplicate(true)
   var restored=undo_history.restore_previous(authority,series.state.game_id)
   if restored.is_empty():return reject(actor,"无法恢复上一战况")
   authority.response_clock={}
   var old_receipt=receipts[actor];receipts[actor]=replying[actor]
   sequence+=1;restored.id=sequence;restored.from=request.from;rewind_events.append(restored);undo_request={};refresh_undo_status()
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
func make_host_observer_snapshot(events: Array=[],recovery: bool=false) -> Dictionary:
 return {"type":"state","room_id":room_id,"sequence":sequence,"game_id":series.state.game_id,"room":series.public_state(-1),"recovery":recovery,"ack_id":"","rewinds":rewind_events.duplicate(true),"projection":preload("res://net/observer_projection.gd").build(authority,events)}
func publish(events: Array=[],remote_only: bool=false,recovery: bool=false):
 if authority!=null:ResponseClock.sync(authority)
 room=series.public_state(local_actor());finish_receipt({"ack_id":receipts[local_actor()] if local_actor()>=0 else ""})
 if cloud_mode:
  for actor in range(2):cloud_player_acks[actor]=actor==local_actor()
  paused=true
 if authority!=null and series.state.status!="choosing":
  if not remote_only:enqueue_snapshot(make_host_observer_snapshot(events,recovery) if local_actor()<0 else make_snapshot(local_actor(),events,recovery),events)
  if connected:
   for actor in range(2):send_actor(actor,make_snapshot(actor,events,recovery))
 else:
  view_sequence=sequence
  if connected:
   for actor in range(2):send_actor(actor,{"type":"room","room":series.public_state(actor),"sequence":sequence,"ack_id":receipts[actor]})
 if is_instance_valid(spectator_hub):spectator_hub.changed(events)
 finish_recording()
 discovery.metadata=metadata();changed.emit()
func remember_sequence():
 if not identity.get("resume",{}).is_empty():identity.resume.sequence=sequence;save_identity()
 save_ranked_recovery()
func finish_receipt(packet: Dictionary):
 if inflight.get("id","")==packet.get("ack_id","") or packet.get("recovery",false):busy=false;inflight={}
func enqueue_snapshot(packet: Dictionary,events: Array=[]):
 if packet.has("projection"):packet.projection.response_clock_received_at=Time.get_unix_time_from_system()
 if recording.capture_path.is_empty():recording.begin_capture(storage+"/capture.bin")
 var recorded=packet
 if is_host and authority!=null:
  recorded=packet.duplicate(true)
  recorded.projection=preload("res://net/observer_projection.gd").build(authority,events,seat,true)
 recording.record(recorded,-1 if read_only else seat)
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
 recording.finish(room)
 if is_host:
  if is_instance_valid(replay_exchange):replay_exchange.remember(recording)
  replay_finished.emit(recording)
 elif is_instance_valid(replay_exchange):replay_exchange.request(recording)
 else:replay_finished.emit(recording)
func receive_observer(id: int,m: Dictionary):
 if id!=1:return
 if m.get("type","")=="rejected":
  rejected=true;joining=false;connected=false;paused=true;notice=str(m.get("message","观战被拒绝"));transport.close();error_raised.emit(notice);changed.emit();return
 if m.get("type","")=="replay_frames":
  remote_last_seen=Time.get_ticks_msec();replay_exchange.receive(m);return
 if m.get("type","")=="pong":metrics.accept_pong(m,Time.get_ticks_msec());remote_last_seen=Time.get_ticks_msec();return
 if m.get("type","")!="watch_state" or not m.get("room") is Dictionary:return
 if Series.uses_mods(m.room) and m.room.get("mods",[])!=mod_config:
  rejected=true;joining=false;connected=false;transport.close();notice="观战模组配置不一致";error_raised.emit(notice);changed.emit();return
 if rejected:return
 connected=true;joining=false;paused=m.get("paused",false);remote_last_seen=Time.get_ticks_msec()
 reset_match_view(m.room)
 room_id=m.room_id;room=m.room;sequence=m.sequence
 transport.send_to(1,{"type":"watch_ack","sequence":sequence},true)
 if m.has("projection"):enqueue_snapshot(m)
 notice=connection_status();changed.emit()
func pop_snapshot() -> Dictionary:
 if snapshots.is_empty():return {}
 var packet=snapshots.pop_front();view_sequence=packet.sequence;local_game_id=packet.game_id;return packet
func _notification(what):
 if not is_android:return
 if what==NOTIFICATION_APPLICATION_PAUSED:
  application_suspended=true
  if is_host and not room_id.is_empty():persist()
 elif what==NOTIFICATION_APPLICATION_RESUMED:
  if not application_suspended:return
  application_suspended=false
  if transport==null or rejected or ended():return
  var now=Time.get_ticks_msec()
  # Let queued packets arrive after Android stops frame processing. An already
  # detected outage keeps its original disconnect deadline.
  remote_last_seen=now;last_heartbeat=0;metrics.reset()
  for id in cloud_peer_seen:cloud_peer_seen[id]=now
  retry_at=0
  retry_connection(now,true)
func retry_connection(now: int,immediate: bool=false):
 if cloud_ranked and match_settled:return
 if joining or rejected or ended() or application_suspended or not immediate and now-retry_at<=3000:return
 if ranked_match_pending() and not connected and transport.online:
  retry_at=now
  if transport.last_server_seen>=0 and now-transport.last_server_seen<=10000:
   # Missing opponent packets must not make the healthy player disconnect itself.
   transport.relay_control("match_wait")
   if not is_host:
    resume_requested=not identity.get("resume",{}).is_empty()
    on_connect(1)
   return
  network_diagnostic("relay_unresponsive");transport.close()
 if cloud_mode and (is_host or read_only) and not transport.online and not room_id.is_empty():
  retry_at=now
  var resolved=Endpoint.resolve(address)
  if resolved.is_empty():return
  var options={"seat":cloud_slot,"password_hash":cloud_password_hash,"version":fingerprint,"resume":true,"match_id":cloud_match_id}
  if is_host:
   options.merge({"name":cloud_room_name,"format":series.state.format,"rule_set":series.state.get("rule_set","unrestricted")})
   transport.relay_host(resolved,port,relay_code,relay_websocket,cloud_token,options)
  else:
   var error=transport.relay_join(resolved,port,relay_code,relay_websocket,cloud_token,options,true)
   if error==OK:joining=true;remote_last_seen=now;notice="正在恢复观战连接";changed.emit()
 elif ranked_match_pending() and not is_host and not connected and disconnected_at>0:
  retry_at=now;reconnect_ranked_guest()
 elif not is_host and not read_only and not connected and not identity.get("resume",{}).is_empty() and disconnected_at>0:
  retry_at=now;resume_guest()
func report_match_result(force: bool=false):
 if not cloud_ranked or match_settled or transport==null or not transport.online or room.get("status","")!="complete":return
 var now=Time.get_ticks_msec()
 if not force and now-last_result_report<1000:return
 last_result_report=now;transport.relay_result(cloud_match_id,int(room.get("winner",-2)))

func check_response_timeout(now: float=-1.0):
 if not is_host or authority==null or not connected or paused or not undo_request.is_empty() or series.state.status!="playing" or ended():return
 ResponseClock.sync(authority,now)
 if not ResponseClock.expired(authority,now):return
 var before=Codec.capture(authority);var previous_series=series.state.duplicate(true)
 var loser=authority.priority
 series.forfeit(loser)
 series.state.end_cause="response_timeout"
 series.state.end_reason=series.state.names[loser]+"响应超过 240 秒，整场判负；连接和房间已释放"
 authority.lose(loser,"响应超过 240 秒",true)
 authority.entry_choices=[];authority.paid_cast_uid=-1;authority.response_clock={}
 sequence+=1
 if not persist():
  Codec.restore(authority,before);series.state=previous_series;sequence-=1;return
 busy=false;inflight={};undo_history.entries.clear();undo_request={};refresh_undo_status()
 # Deliver the final state before closing sockets. Managed matches also wait
 # for the relay to acknowledge rating/tournament settlement of both reports.
 publish([],false,true)
 report_match_result(true)

func release_response_timeout():
 if room.get("end_cause","")!="response_timeout" or ranked_match_pending() or response_timeout_release_at<0:return
 response_timeout_release_at=-1
 connected=false;paused=true;joining=false;busy=false;inflight={};rejected=true
 disconnected_at=0;disconnect_deadline_unix=0.0;wait_choice_pending=false;wait_choice_confirmed=false
 var ended_rooms=identity.get("ended_rooms",[])
 if room_id not in ended_rooms:ended_rooms.append(room_id)
 identity.ended_rooms=ended_rooms.slice(maxi(0,ended_rooms.size()-64));identity.resume={};save_identity()
 if is_instance_valid(spectator_hub):spectator_hub.close()
 transport.close();discovery.start();metrics.reset();notice=room.end_reason
 changed.emit()

func _process(_delta):
 if transport==null or application_suspended:return
 var now=Time.get_ticks_msec()
 last_network_frame_gap=now-last_network_frame if last_network_frame>0 else 0;last_network_frame=now
 # Keep the waiting survivor alive at the relay while peer gameplay is paused.
 if ranked_match_pending() and now-last_relay_heartbeat>2000:
  last_relay_heartbeat=now;transport.relay_control("match_keepalive")
 report_match_result()
 if room.get("end_cause","")=="response_timeout":
  if not ranked_match_pending() and response_timeout_release_at==0:response_timeout_release_at=now+(5000 if is_host else 1000)
  if is_host and acknowledged==sequence and response_timeout_release_at>0:response_timeout_release_at=mini(response_timeout_release_at,now+1000)
  if response_timeout_release_at>0 and now>=response_timeout_release_at:release_response_timeout()
  return
 if cloud_ranked and match_settled:return
 for id in rejected_peers.keys():
  if now>=rejected_peers[id]:transport.drop(id);rejected_peers.erase(id)
 check_join_timeout(now)
 if read_only and not is_host:
  if connected and now-last_heartbeat>2000:last_heartbeat=now;transport.send_to(1,metrics.make_ping(now),true)
  if (connected or joining) and now-remote_last_seen>(25000 if cloud_mode else 12000):
   if joining and room_id.is_empty():on_failure("观战连接超时，请刷新房间列表后重试")
   else:on_disconnect(1);transport.close()
  retry_connection(now)
  return
 if check_reconnect_timeout(now):return
 if connected:
  if is_host and cloud_mode:
   if now-last_heartbeat>2000:
    last_heartbeat=now
    for actor in range(2):
     var target=peer_for_actor(actor)
     if target>0:transport.send_to(target,metrics.make_ping(now),true)
   for actor in range(2):
    var target=peer_for_actor(actor)
    if target>0 and now-int(cloud_peer_seen.get(target,now))>6500:
     on_disconnect(target,"peer_heartbeat_timeout")
     if not cloud_ranked:transport.drop(target)
     break
  else:
   if now-last_heartbeat>2000:last_heartbeat=now;transport.send_to(remote_peer,metrics.make_ping(now),true)
   if now-remote_last_seen>6500:
    on_disconnect(remote_peer,"peer_heartbeat_timeout")
    if not cloud_ranked:transport.drop(remote_peer)
 else:retry_connection(now)
 if is_host and not applicant.is_empty() and now-applicant.at>30000:accept_applicant(false)
 check_response_timeout()
