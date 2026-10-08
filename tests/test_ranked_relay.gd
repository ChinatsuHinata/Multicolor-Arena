extends "res://relay/server.gd"
var failures=[]
var sent=[]
var stored_actions=[]
func _initialize():call_deferred("run")
func _process(_delta) -> bool:return false
func control(id: int,kind: String,message: String="",extra: Dictionary={}):
 sent.append({"id":id,"kind":kind,"message":message,"extra":extra.duplicate(true)})
func match_store_request(code: String,action: String):
 stored_actions.append(action)
 var winner=int(rooms[code].outcome)
 match_store_completed(code,action,{"ok":true,"ratings":[1016,984] if winner==0 else [984,1016],"deltas":[16,-16] if winner==0 else [-16,16]})
func check(ok: bool,label: String):
 if ok:print("PASS: ",label)
 else:failures.append(label);push_error(label)
func fixture() -> String:
 rooms={};clients={};sent=[];stored_actions=[];rejected={};match_queue.entries={}
 for id in [11,22,33]:
  clients[id]={"role":"","room":"","seat":0,"account":"TEST_ONLY_"+str(id),"nickname":"Player "+str(id),"device":"test","platform":"pc","token":"a".repeat(64),"cloud_active":true,"player_id":id,"elo":1000,"match_version":"v".repeat(64)}
 pair_match(11,22)
 return str(clients[11].room)
func packet(id: int,message: Dictionary):handle_packet(id,("MCR1"+JSON.stringify(message)).to_utf8_buffer(),0)
func run():
 var code=fixture();var room=rooms[code]
 check(room.rule_set=="official" and public_rooms()[0].rule_set=="official","ranked room and directory fix the rule set to official")
 check(public_rooms().size()==1 and public_rooms()[0].watch_only and not JSON.stringify(public_rooms()).contains("elo"),"ranked room is listed for spectating without ratings")
 check(sent.filter(func(item):return item.kind=="matched").size()==2,"match success is delivered once to both players")
 check(sent.filter(func(item):return item.kind=="matched").all(func(item):return item.extra.rule_set=="official"),"both matched responses require the official rule set")
 register(33,{"kind":"guest","room":code,"seat":1,"version":room.version})
 check(clients[33].role=="" and room.slots[0]==11,"outsider cannot join a matched battle seat")
 rejected.erase(33)
 register(33,{"kind":"watch","room":code,"seat":8,"version":room.version})
 check(clients[33].role=="watch" and room.slots[7]==33,"matched lobby admits an observer into an automatically assigned seat")
 packet(11,{"kind":"drop","peer":22});packet(11,{"kind":"move","from":1,"to":8})
 check(room.slots[0]==11 and room.slots[1]==22,"ranked host cannot kick or move its opponent")
 report_match(11,{"match_id":room.match_id,"winner":0.0})
 check(room.reports.is_empty(),"unstarted match ignores result reports")
 room.started=true;room.stored_started=true
 packet(11,{"kind":"match_result","match_id":room.match_id,"winner":0})
 tick_matches(Time.get_ticks_msec())
 check(not room.settled,"one report cannot settle a connected match")
 packet(22,{"kind":"match_result","match_id":"wrong","winner":0})
 check(room.reports.size()==1,"wrong match identifier cannot settle a result")
 packet(22,{"kind":"match_result","match_id":room.match_id,"winner":0})
 tick_matches(Time.get_ticks_msec())
 check(room.settled and stored_actions.count("settle")==1,"JSON numeric reports agree and settle exactly once")
 check(not rooms.has(code) and clients[11].room.is_empty() and clients[22].room.is_empty() and clients[33].room.is_empty(),"settlement removes the room and releases every occupant immediately")
 var closed=sent.filter(func(item):return item.kind=="room_closed")
 check(closed.size()==1 and closed[0].id==33 and closed[0].extra.winner==0 and not closed[0].extra.has("elo"),"observer receives the result and room closure without Elo")
 packet(22,{"kind":"match_result","match_id":room.match_id,"winner":0});tick_matches(Time.get_ticks_msec())
 check(stored_actions.count("settle")==1,"repeated result never repeats settlement")
 var results=sent.filter(func(item):return item.kind=="match_settled")
 check(results.size()==2 and results[0].extra.elo==1016 and results[1].extra.elo==984 and not results[0].extra.has("ratings"),"each recipient sees only its own Elo")
 code=fixture();room=rooms[code]
 register(33,{"kind":"watch","room":code,"seat":8,"version":room.version})
 remove_client(33)
 check(room.slots[7]==0 and room.disconnected.is_empty() and not room.cancel,"observer departure frees its seat without affecting the match")
 for id in range(100,106):
  clients[id]=clients[11].duplicate(true);clients[id].role="";clients[id].room="";clients[id].account="TEST_ONLY_"+str(id);clients[id].player_id=id
  register(id,{"kind":"watch","room":code,"seat":8,"version":room.version})
 check(room.slots.slice(2).all(func(id):return id!=0),"six observers get distinct seats")
 clients[106]=clients[100].duplicate(true);clients[106].role="";clients[106].room="";clients[106].account="TEST_ONLY_106"
 register(106,{"kind":"watch","room":code,"seat":8,"version":room.version})
 check(clients[106].role.is_empty(),"full observer seats reject another visitor")
 code=fixture();room=rooms[code];room.started=true;room.stored_started=true
 packet(11,{"kind":"match_result","match_id":room.match_id,"winner":0});packet(22,{"kind":"match_result","match_id":room.match_id,"winner":0})
 remove_client(11);remove_client(22);tick_matches(Time.get_ticks_msec())
 check(stored_actions.has("settle") and not stored_actions.has("cancel"),"confirmed result survives both clients leaving before the store reply")
 code=fixture();room=rooms[code];room.started=true;room.stored_started=true
 packet(11,{"kind":"match_result","match_id":room.match_id,"winner":0});packet(22,{"kind":"match_result","match_id":room.match_id,"winner":1})
 tick_matches(Time.get_ticks_msec())
 check(room.settled and stored_actions.has("cancel") and not stored_actions.has("settle"),"conflicting reports cannot alter Elo")
 code=fixture();room=rooms[code];room.started=true;room.stored_started=true
 remove_client(11)
 check(rooms.has(code) and room.host==0 and public_rooms().is_empty(),"host disconnection preserves the reserved match and hides its unavailable spectator entry")
 var departure=int(room.disconnected[0])
 tick_matches(departure+MATCH_RECONNECT_MS-1)
 check(not room.settled,"disconnect keeps the reconnect grace period")
 tick_matches(departure+MATCH_RECONNECT_MS)
 check(room.settled and room.outcome==1,"host absence past grace awards the surviving guest a win")
 code=fixture();room=rooms[code];remove_client(22)
 tick_matches(Time.get_ticks_msec()+MATCH_RECONNECT_MS+1)
 check(room.settled and stored_actions.has("cancel"),"pregame disconnect cancels without changing Elo")
 code=fixture();room=rooms[code];room.started=true;room.stored_started=true;remove_client(11);remove_client(22)
 tick_matches(Time.get_ticks_msec()+MATCH_RECONNECT_MS+1)
 check(not rooms.has(code) and stored_actions.has("cancel"),"both disconnected players cannot manufacture a winner")
 code=fixture();room=rooms[code];remove_client(22)
 clients[44]=clients[33].duplicate(true);clients[44].player_id=22;clients[44].account="TEST_ONLY_22"
 register(44,{"kind":"match","version":"v".repeat(64)})
 check(not match_queue.entries.has(44),"pending disconnected match blocks a second queue request")
 rejected.erase(44)
 register(44,{"kind":"guest","room":code,"resume":true,"match_id":room.match_id,"version":room.version})
 check(room.slots[1]==44 and not room.disconnected.has(1),"only the original account resumes a reserved seat")
 rooms={};clients[44].role="";clients[44].room=""
 register(44,{"kind":"host","room":code,"resume":true,"match_id":room.match_id,"version":room.version})
 check(rooms.is_empty(),"missing rated room cannot be recreated as a public room")
 quit(0 if failures.is_empty() else 1)
