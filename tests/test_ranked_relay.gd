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
 match_store_completed(code,action,{"ok":true,"mode":rooms[code].get("mode","ranked"),"ratings":[1016,984] if winner==0 else [984,1016],"deltas":[16,-16] if winner==0 else [-16,16]})
func check(ok: bool,label: String):
 if ok:print("PASS: ",label)
 else:failures.append(label);push_error(label)
func fixture(first_public: bool=true,second_public: bool=true,mode: String="ranked") -> String:
 rooms={};clients={};sent=[];stored_actions=[];rejected={};match_queue.entries={};pending_matches={}
 for id in [11,22,33]:
  clients[id]={"role":"","room":"","seat":0,"account":"TEST_ONLY_"+str(id),"nickname":"Player "+str(id),"device":"test","platform":"pc","token":"a".repeat(64),"cloud_active":true,"player_id":id,"elo":1000,"match_version":"v".repeat(64)}
 clients[11].match_public=first_public;clients[22].match_public=second_public
 clients[11].match_mode=mode;clients[22].match_mode=mode
 clients[11].rank={"tier":2,"level":1,"stars":2};clients[22].rank={"tier":4,"position":8}
 pair_match(11,22)
 rooms[str(clients[11].room)].sync_pending={}
 for occupant in [11,22]:clients[occupant].erase("last_packet_at")
 return str(clients[11].room)
func packet(id: int,message: Dictionary):handle_packet(id,("MCR1"+JSON.stringify(message)).to_utf8_buffer(),0)
func run():
 fixture();rooms={};sent=[]
 for id in clients:
  clients[id].role="";clients[id].room=""
 clients[11].rank={"tier":0,"level":2,"stars":0};clients[11].elo=1000
 clients[22].rank={"tier":1,"level":3,"stars":0};clients[22].elo=1000
 clients[33].rank={"tier":0,"level":2,"stars":2};clients[33].elo=2500
 for id in [11,22,33]:register(id,{"kind":"match","version":"v".repeat(64),"deck_hash":"a".repeat(64),"elo":1000,"rank":{"tier":4,"level":0},"public":id!=33})
 check(clients[11].match_public and not clients[33].match_public,"queue registration retains each player's privacy preference")
 check(match_queue.entries[11].rank_step==0 and match_queue.entries[22].rank_step==2 and not match_queue.entries[11].has("elo"),"queue uses authenticated ranks and ignores client Elo and forged rank")
 var queued=sent.filter(func(item):return item.kind=="match_queued")
 check(queued.size()==3 and queued.all(func(item):return item.extra.rank_gap==0 and not item.extra.has("gap")),"initial queue response uses a zero rank range")
 tick_matches(Time.get_ticks_msec())
 check(not clients[11].room.is_empty() and clients[11].room==clients[33].room and clients[22].role=="queue","relay pairs same ranks regardless of Elo and keeps the adjacent major tier queued")
 check(not rooms[clients[11].room].public and public_rooms().is_empty(),"privacy does not split matchmaking and either player's private choice hides the room")
 var waiting=sent.filter(func(item):return item.id==22 and item.kind=="match_queued")
 check(waiting.back().extra.rank_gap==0 and waiting.back().extra.queued==1,"waiting progress reports the rank range and remaining queue count")
 var since=int(match_queue.entries[22].since)
 tick_matches(since+19999)
 waiting=sent.filter(func(item):return item.id==22 and item.kind=="match_queued")
 check(waiting.back().extra.wait_seconds==19 and waiting.back().extra.rank_gap==0,"relay retains the initial major tier range before twenty seconds")
 tick_matches(since+20000)
 waiting=sent.filter(func(item):return item.id==22 and item.kind=="match_queued")
 check(waiting.back().extra.wait_seconds==20 and waiting.back().extra.rank_gap==1,"relay reports one major tier of expansion at twenty seconds")
 var code=fixture();var room=rooms[code]
 check(room.rule_set=="official" and public_rooms()[0].rule_set=="official","ranked room and directory fix the rule set to official")
 check(public_rooms().size()==1 and public_rooms()[0].watch_only and not JSON.stringify(public_rooms()).contains("elo"),"ranked room is listed for spectating without ratings")
 check(sent.filter(func(item):return item.kind=="matched").size()==2,"match success is delivered once to both players")
 check(sent.filter(func(item):return item.kind=="matched").all(func(item):return item.extra.rule_set=="official"),"both matched responses require the official rule set")
 check(room.ranks==[clients[11].rank,clients[22].rank] and sent.filter(func(item):return item.kind=="matched").all(func(item):return item.extra.ranks==room.ranks and not item.extra.has("elo")),"both matched responses carry authenticated ranks in battle seat order without Elo")
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
 register(44,{"kind":"guest","room":code,"resume":true,"match_id":room.match_id,"version":room.version})
 check(room.slots[1]==44 and room.disconnected.has(1),"only the original account resumes a reserved seat pending game synchronization")
 remove_client(44)
 clients[44]=clients[33].duplicate(true);clients[44].player_id=22;clients[44].account="TEST_ONLY_22"
 register(44,{"kind":"match","version":"v".repeat(64),"deck_hash":"a".repeat(64)})
 check(room.settled and match_queue.entries.has(44),"starting a new match cancels the previous pregame reservation and queues the player")
 rooms={};clients[44].role="";clients[44].room=""
 register(44,{"kind":"host","room":code,"resume":true,"match_id":room.match_id,"version":room.version})
 check(rooms.is_empty(),"missing rated room cannot be recreated as a public room")
 for preferences in [[true,true],[false,true],[true,false],[false,false]]:
  code=fixture(preferences[0],preferences[1]);room=rooms[code]
  var expected=preferences[0] and preferences[1]
  check(room.public==expected and (public_rooms().size()==1)==expected,"both players must opt in to publish the room: "+str(preferences))
  check(sent.filter(func(item):return item.kind=="matched").all(func(item):return item.extra.public==expected),"both matched clients receive the final privacy setting: "+str(preferences))
 code=fixture(false,true);room=rooms[code]
 register(33,{"kind":"watch","room":code,"seat":8,"version":room.version})
 check(clients[33].role.is_empty() and room.slots.slice(2)==[0,0,0,0,0,0] and sent.back().message.contains("私人"),"knowing a private room code cannot bypass the spectator restriction")
 packet(11,{"kind":"update","status":"sideboarding","public":true})
 check(not room.public and public_rooms().is_empty(),"host updates cannot override the opponent's private choice")
 remove_client(22)
 clients[44]=clients[33].duplicate(true);clients[44].player_id=22;clients[44].account="TEST_ONLY_22"
 register(44,{"kind":"guest","room":code,"resume":true,"match_id":room.match_id,"version":room.version})
 check(room.slots[1]==44 and not room.public and public_rooms().is_empty(),"private matches preserve the original player's reconnect seat and remain hidden")
 fixture();rooms={};clients[33].role="";clients[33].room=""
 register(33,{"kind":"match","version":"v".repeat(64),"deck_hash":"a".repeat(64),"public":"false"})
 check(not match_queue.entries.has(33) and clients[33].role.is_empty(),"invalid privacy values are rejected before entering the queue")
 fixture();rooms={};sent=[]
 for id in clients:clients[id].role="";clients[id].room=""
 register(11,{"kind":"match","version":"v".repeat(64),"deck_hash":"a".repeat(64),"mode":"ranked"})
 register(22,{"kind":"match","version":"v".repeat(64),"deck_hash":"a".repeat(64),"mode":"casual"})
 check(queued_count("v".repeat(64),"casual")==1 and queued_count("v".repeat(64),"ranked")==1,"queue counts only include the selected mode")
 tick_matches(Time.get_ticks_msec()+999999)
 check(rooms.is_empty() and match_queue.entries.size()==2,"relay never pairs different matchmaking modes")
 for disconnect in [false,true]:
  code=fixture(true,true,"casual");room=rooms[code]
  check(room.rule_set=="unrestricted" and room.ranks.is_empty() and public_rooms()[0].name.contains("休闲"),"casual match uses unrestricted rules and a casual directory label")
  check(sent.filter(func(item):return item.kind=="matched").all(func(item):return item.extra.mode=="casual" and item.extra.rule_set=="unrestricted"),"both players receive confirmed casual mode")
  register(33,{"kind":"watch","room":code,"seat":8,"version":room.version})
  room.started=true;room.stored_started=true
  if disconnect:remove_client(22);tick_matches(Time.get_ticks_msec()+MATCH_RECONNECT_MS+1)
  else:
   report_match(11,{"match_id":room.match_id,"winner":0});report_match(22,{"match_id":room.match_id,"winner":0});tick_matches(Time.get_ticks_msec())
  results=sent.filter(func(item):return item.kind=="match_settled")
  check(room.settled and not rooms.has(code) and results.all(func(item):return not item.extra.rated and item.extra.winner==0 and not item.extra.has("elo") and not item.extra.has("rank")),"casual completion and disconnect preserve a winner without rating updates: "+str(disconnect))
  closed=sent.filter(func(item):return item.kind=="room_closed")
  check(closed.size()==1 and closed[0].extra.winner==0 and not closed[0].extra.rated,"casual spectators receive the final winner without ranked settlement")
 fixture();rooms={};clients[33].role="";clients[33].room=""
 register(33,{"kind":"match","version":"v".repeat(64),"deck_hash":"a".repeat(64),"mode":"invalid"})
 check(not match_queue.entries.has(33),"invalid match modes cannot enter the queue")
 code=fixture(true,true,"casual");room=rooms[code];sent.clear();room.stored=false
 match_store_completed(code,"create",{"ok":true})
 check(room.cancel and sent.all(func(item):return item.kind!="matched") and sent.any(func(item):return item.kind=="error" and item.message.contains("休闲")),"an older account backend cannot start a casual match as ranked")
 quit(0 if failures.is_empty() else 1)
