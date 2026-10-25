extends SceneTree
const Session=preload("res://net/lan_session.gd")
const Series=preload("res://net/series_controller.gd")
const Store=preload("res://scripts/deck_store.gd")
class Wire:
 extends "res://net/lan_transport.gd"
 var packets=[]
 var results=[]
 func send_to(id: int,message: Dictionary,_heartbeat: bool=false):
  packets.append({"peer":id,"message":message.duplicate(true)})
 func relay_result(match_id: String,winner: int,evidence: Dictionary={},scores: Array=[]):
  results.append({"match_id":match_id,"winner":winner,"evidence":evidence.duplicate(true),"scores":scores.duplicate()})
var failures=[]
var fixture="res://work/task-network/"+str(Time.get_ticks_usec())
func _initialize():call_deferred("run")
func check(value: bool,label: String):
 if value:print("PASS: ",label)
 else:failures.append(label);push_error(label)
func make_session(actor: int,deck: Dictionary):
 var session=Session.new();root.add_child(session);session.initialize(fixture+"/"+str(actor))
 session.set_process(false);session.discovery.set_process(false)
 session.transport.close();session.transport.queue_free()
 session.transport=Wire.new();session.add_child(session.transport);session.transport.set_process(false)
 session.cloud_mode=true;session.cloud_ranked=true;session.matchmaking=true;session.match_mode="ranked"
 session.cloud_token="a".repeat(64);session.cloud_nickname="TEST_ONLY "+str(actor);session.match_deck=Store.clean_deck(deck)
 return session
func deliver(sender,receiver,peer_id: int):
 var packets=sender.transport.packets.duplicate(true);sender.transport.packets.clear()
 for packet in packets:receiver.receive(peer_id,packet.message)
func synchronize(host,guest):
 for index in range(12):
  if host.transport.packets.is_empty() and guest.transport.packets.is_empty():break
  deliver(host,guest,1);deliver(guest,host,22)
func run():
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 var host=make_session(0,decks[0]);var guest=make_session(1,decks[1])
 var info={"mode":"ranked","match_id":"a".repeat(32),"room":"ABCDEF123456","format":host.match_format(),"rule_set":host.match_rule_set(),"deck_hashes":decks.map(func(deck):return JSON.stringify(Store.clean_deck(deck)).sha256_text())}
 host.on_match_found(info.merged({"role":"host","seat":1}));guest.on_match_found(info.merged({"role":"guest","seat":2}))
 host.on_cloud_seats(["TEST_ONLY 0","TEST_ONLY 1","","","","","",""],[1,22,0,0,0,0,0,0])
 guest.on_connect(1);deliver(guest,host,22);synchronize(host,guest)
 host.room_action({"name":"ready"});synchronize(host,guest)
 guest.room_action({"name":"ready"});synchronize(host,guest)
 var choosing=host if host.room.chooser==0 else guest
 choosing.room_action({"name":"first","first":true});synchronize(host,guest)
 check(host.room.status=="playing" and guest.room.status=="playing","two matching sessions reach the same battlefield")
 host.authority.damage_context={"source":host.authority.players[0].leader,"combat":false}
 host.authority.damage_target({"player":1},7)
 host.authority.damage_context={}
 host.handle_command(1,{"id":"TEST_ONLY_task_surrender","room_id":host.room_id,"game_id":host.series.state.game_id,"expected":host.sequence,"command":{"name":"surrender","args":[]}})
 synchronize(host,guest)
 check(host.room.status=="complete" and guest.room.status=="complete","actual surrender command synchronizes a completed result")
 check(host.room.get("task_evidence",{})==guest.room.get("task_evidence",{}) and host.room.has("task_evidence"),"both players receive the same final evidence")
 check(int(guest.room.get("task_evidence",{}).get("players",[{},{}])[0].get("player_damage",0))==7,"actual engine damage reaches the guest's task evidence")
 host.transport.online=true;guest.transport.online=true
 host.report_match_result(true);guest.report_match_result(true)
 check(not host.transport.results.is_empty() and not guest.transport.results.is_empty() and host.transport.results.back()==guest.transport.results.back(),"both clients report the same winner and evidence to the relay")
 var saved=Session.Journal.load_from(host.storage+"/host.bin")
 check(saved.get("series",{}).get("task_evidence",{})==host.room.task_evidence,"host recovery journal retains the final task summary")
 var series=Series.new()
 series.record_task_evidence({"version":1,"players":[{"player_damage":8,"royal_flare_damage":0,"royal_flare_kill":false,"cast_cards":{"121":1},"final_life":10},{}]})
 series.record_task_evidence({"version":1,"players":[{"player_damage":20,"royal_flare_damage":20,"royal_flare_kill":true,"cast_cards":{"121":2},"final_life":32},{}]})
 var stats=series.state.task_evidence.players[0]
 check(stats.player_damage==28 and stats.cast_cards["121"]==3 and stats.final_life==32,"drawn games accumulate counters while final life stays per game")
 check(stats.final_game.player_damage==20 and stats.final_game.royal_flare_damage==20,"victory conditions retain only the decisive game's damage sources")
 check(stats.royal_flare_kill is bool and stats.royal_flare_kill and stats.final_game.royal_flare_kill,"royal killing-blow proof stays boolean through series aggregation")
 series.state.status="playing"
 series.forfeit(1)
 check(not series.state.has("task_evidence"),"unconfirmed disconnect cannot reuse a prior drawn game's victory conditions")
 series.state.status="playing"
 series.forfeit(1,false,{"version":1,"players":[{"player_damage":7,"final_life":17},{}]})
 check(series.state.task_evidence.players[0].final_game.final_life==17,"synchronized response timeout captures the current game's final state")
 host.leave(false);guest.leave(false);host.queue_free();guest.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
