extends "res://relay/server.gd"
var failures=[]
var sent=[]
var stored_actions=[]
var defer_store=false
func _initialize():call_deferred("run")
func _process(_delta) -> bool:return false
func control(id: int,kind: String,message: String="",extra: Dictionary={}):
 sent.append({"id":id,"kind":kind,"message":message,"extra":extra.duplicate(true)})
func match_store_request(code: String,action: String):
 stored_actions.append(action)
 if defer_store:rooms[code].store_busy=true;return
 match_store_completed(code,action,{"ok":true,"ratings":[1016,984],"deltas":[16,-16],"ranks":[{"tier":1,"level":3,"stars":0},{"tier":0,"level":2,"stars":0}]})
func check(ok: bool,label: String):
 if ok:print("PASS: ",label)
 else:failures.append(label);push_error(label)
func fixture(playing: bool=false) -> String:
 rooms={};clients={};sent=[];stored_actions=[];rejected={};match_queue.entries={};pending_matches={};defer_store=false
 for id in [11,22]:
  clients[id]={"role":"","room":"","seat":0,"account":"TEST_ONLY_"+str(id),"nickname":"Player "+str(id),"device":"test","platform":"pc","token":"a".repeat(64),"cloud_active":true,"player_id":id,"elo":1000,"match_version":"v".repeat(64)}
 pair_match(11,22)
 var code=str(clients[11].room)
 rooms[code].started=playing;rooms[code].stored_started=playing
 rooms[code].sync_pending={}
 # Synthetic time jumps assume healthy traffic unless a test sets an idle clock.
 for occupant in [11,22]:clients[occupant].erase("last_packet_at")
 return code
func replacement(actor: int) -> int:
 var id=44+actor
 clients[id]={"role":"","room":"","seat":0,"account":"TEST_ONLY_"+str(11 if actor==0 else 22),"nickname":"Replacement","device":"test","platform":"pc","token":"a".repeat(64),"cloud_active":true,"player_id":11 if actor==0 else 22,"elo":1000}
 return id
func new_match(id: int):register(id,{"kind":"match","version":"v".repeat(64),"deck_hash":"a".repeat(64)})
func wire(message: Dictionary) -> PackedByteArray:
 var data=var_to_bytes(message)
 return var_to_bytes({"count":1,"index":0,"data":data,"hash":data.hex_encode().sha256_text()})
func run():
 var code=fixture();var room=rooms[code];remove_client(22)
 var id=replacement(1);new_match(id)
 check(room.cancel and not rooms.has(code) and match_queue.entries.has(id),"new matching releases a disconnected pregame seat immediately")
 check(clients[11].role.is_empty() and sent.any(func(item):return item.id==11 and item.kind=="match_settled" and not item.extra.rated),"the waiting opponent is notified and released without rating changes")
 code=fixture();room=rooms[code];id=replacement(0);new_match(id)
 check(not clients.has(11) and room.cancel and match_queue.entries.has(id),"a new connection from the same device retires its old ranked connection")
 code=fixture();room=rooms[code];id=replacement(0);clients[id].device="another-device";new_match(id)
 check(rooms.has(code) and not room.cancel and clients.has(11),"a different device cannot replace an active cloud connection")
 code=fixture();room=rooms[code];id=replacement(0)
 register(id,{"kind":"match","version":"v".repeat(64),"deck_hash":"invalid"})
 check(rooms.has(code) and not room.cancel and clients.has(11),"invalid new matching cannot abandon the old match")
 code=fixture(true);room=rooms[code];remove_client(11);id=replacement(0);new_match(id)
 check(room.outcome==1 and stored_actions.count("settle")==1 and match_queue.entries.has(id),"leaving a started match awards the remaining opponent a win before requeue")
 code=fixture(true);room=rooms[code];report_match(22,{"match_id":room.match_id,"winner":0});remove_client(11);id=replacement(0);new_match(id)
 check(room.outcome==0 and not room.cancel,"the survivor's previously acknowledged loss is preserved")
 code=fixture(true);room=rooms[code];report_match(11,{"match_id":room.match_id,"winner":0});report_match(22,{"match_id":room.match_id,"winner":0})
 remove_client(11);remove_client(22);id=replacement(1);new_match(id)
 check(room.outcome==0 and stored_actions.count("settle")==1 and not stored_actions.has("cancel"),"a confirmed result survives both departures and a new matching request")
 code=fixture(true);room=rooms[code];remove_client(11);remove_client(22);id=replacement(0);new_match(id)
 check(room.cancel and match_queue.entries.has(id),"both absent players cancel without manufacturing a winner")
 code=fixture(true);room=rooms[code];remove_client(22);id=replacement(1);defer_store=true;new_match(id)
 check(pending_matches.has(id) and clients[id].role=="pending_match" and not match_queue.entries.has(id),"new matching waits for durable settlement rather than using stale ratings")
 var duplicate=55;clients[duplicate]=clients[id].duplicate(true);clients[duplicate].role="";new_match(duplicate)
 check(rejected.has(duplicate) and not pending_matches.has(duplicate),"a second connection cannot duplicate a pending queue request")
 remove_client(duplicate)
 match_store_completed(code,"settle",{"ok":true,"ratings":[1016,984],"deltas":[16,-16],"ranks":[{}, {"tier":1,"level":3,"stars":0}]})
 check(not pending_matches.has(id) and match_queue.entries.has(id) and clients[id].elo==984 and clients[id].rank.tier==1,"store completion automatically queues the request with the updated private rating and rank")
 code=fixture();room=rooms[code];remove_client(22);id=replacement(1);defer_store=true;new_match(id);remove_client(id)
 match_store_completed(code,"cancel",{"ok":true})
 check(pending_matches.is_empty() and match_queue.entries.is_empty(),"cancelling during old-room cleanup cannot create a ghost queue entry")
 code=fixture(true);room=rooms[code];remove_client(22);id=replacement(1)
 register(id,{"kind":"guest","room":code,"resume":true,"match_id":room.match_id,"version":room.version})
 check(rooms.has(code) and room.slots[1]==id and room.disconnected.has(1) and not room.cancel,"socket reconnection reserves the original deadline until the game handshake completes")
 tick_matches(int(room.disconnected[1])+59999)
 check(rooms.has(code) and not room.cancel,"stuck resumed connection retains its seat for 59 seconds")
 tick_matches(int(room.disconnected[1])+60000)
 check(not rooms.has(code) and room.outcome==0 and clients[id].role.is_empty(),"stuck resumed connection is released at exactly 60 seconds with server settlement")
 code=fixture();room=rooms[code]
 room.sync_pending={0:1000,1:1000}
 tick_matches(60999)
 check(rooms.has(code),"initial game handshake may recover within one minute")
 tick_matches(61000)
 check(not rooms.has(code) and room.cancel,"initial handshake stuck with two open sockets cancels and releases both players")
 code=fixture(true);room=rooms[code];remove_client(22)
 var first_departure=int(room.disconnected[1]);id=replacement(1)
 register(id,{"kind":"guest","room":code,"resume":true,"match_id":room.match_id,"version":room.version})
 remove_client(id)
 check(int(room.disconnected[1])==first_departure,"repeated reconnect failures cannot restart the one-minute deadline")
 code=fixture(true);room=rooms[code];remove_client(22);id=replacement(1)
 register(id,{"kind":"guest","room":code,"resume":true,"match_id":room.match_id,"version":room.version})
 observe_match_sync(room,id,wire({"type":"ready_state","sequence":1}))
 check(not room.disconnected.is_empty(),"host ready-state alone cannot clear a recorded opponent outage")
 observe_guest_ack(room,id,wire({"type":"ack","sequence":1}))
 observe_match_sync(room,id,wire({"type":"ready_state","sequence":1}))
 check(room.disconnected.is_empty() and room.sync_pending.is_empty(),"acknowledged game handshake clears the reconnect reservation")
 code=fixture(true);room=rooms[code]
 clients[22].last_packet_at=1000;clients[11].last_packet_at=61000
 tick_matches(61000)
 check(not rooms.has(code) and room.outcome==0,"unresponsive open game socket releases the seat and settles the surviving player")
 code=fixture(true);room=rooms[code]
 handle_packet(11,("MCR1"+JSON.stringify({"kind":"match_wait","match_id":room.match_id})).to_utf8_buffer(),0)
 var waiting_since=Time.get_ticks_msec()
 clients[11].last_packet_at=waiting_since+60000;clients[22].last_packet_at=waiting_since+60000
 tick_matches(waiting_since+60000)
 check(rooms.has(code) and room.disconnected.is_empty() and room.outcome==-2,"forged host wait cannot blame or defeat a healthy guest")
 observe_guest_ack(room,22,wire({"type":"ack","sequence":8}))
 observe_match_sync(room,22,wire({"type":"ready_state","sequence":8}))
 check(not room.has("sync_waits"),"a completed sync clears old wait reports even when both links stayed healthy")
 code=fixture(true);room=rooms[code];remove_client(22)
 room.server_fault_at=int(room.disconnected[1])+1
 tick_matches(int(room.disconnected[1])+60000)
 check(room.cancel and resolution_metadata(room).reason=="server_transport_error","server send faults prevent assigning a player loss")
 code=fixture(true);room=rooms[code]
 handle_packet(11,("MCD1"+"%08X" % 22+"MCR1"+JSON.stringify({"kind":"match_settled","winner":0,"match_id":room.match_id})).to_utf8_buffer(),0)
 check(rejected.has(11) and room.outcome==-2,"host cannot smuggle forged server settlement or attribution through a relayed frame")
 for actor in [0,1]:
  code=fixture(true);room=rooms[code];id=replacement(actor)
  var old_id=int(room.slots[actor])
  var claim={"kind":"host" if actor==0 else "guest","room":code,"resume":true,"match_id":room.match_id,"version":room.version}
  register(id,claim)
  check(room.slots[actor]==id and not clients.has(old_id) and not rejected.has(id),"authenticated same-device recovery replaces an occupied seat: "+str(actor))
  var deadline=int(room.disconnected[actor])
  remove_client(old_id)
  check(room.slots[actor]==id and int(room.disconnected[actor])==deadline,"late old-peer departure leaves the new seat and deadline intact")
  var next=id+10;clients[next]=clients[id].duplicate(true);clients[next].role=""
  register(next,claim)
  check(room.slots[actor]==next and int(room.disconnected[actor])==deadline,"repeated same-device takeover does not extend the recovery window")
 for invalid in ["device","match_id","version","resume"]:
  code=fixture(true);room=rooms[code];id=replacement(1)
  var claim={"kind":"guest","room":code,"resume":true,"match_id":room.match_id,"version":room.version}
  if invalid=="device":clients[id].device="different"
  elif invalid=="resume":claim.resume=false
  else:claim[invalid]="wrong"
  register(id,claim)
  check(room.slots[1]==22 and clients.has(22) and rejected.has(id),"invalid takeover cannot evict the original player: "+invalid)
 for missing_actor in [0,1]:
  code=fixture(true);room=rooms[code]
  var absent=int(room.slots[missing_actor]);var survivor=int(room.slots[1-missing_actor])
  clients[absent].last_packet_at=1000;clients[survivor].last_packet_at=61000
  tick_matches(61000)
  check(room.outcome==1-missing_actor and resolution_metadata(room).evidence[0].player_id==absent,"server observed silence attributes the correct seat and winner: "+str(missing_actor))
 code=fixture(true);room=rooms[code]
 clients[22].probe_support=true;clients[22].last_verified_at=1000;clients[22].probe_nonce="server-nonce"
 handle_packet(22,("MCR1"+JSON.stringify({"kind":"link_pong","nonce":"wrong"})).to_utf8_buffer(),0)
 check(clients[22].last_verified_at==1000,"ordinary traffic or a forged nonce cannot prove a bidirectional link")
 handle_packet(22,("MCR1"+JSON.stringify({"kind":"link_pong","nonce":"server-nonce"})).to_utf8_buffer(),0)
 check(clients[22].last_verified_at!=1000 and clients[22].probe_nonce.is_empty(),"a matching probe response confirms only its own authenticated connection")
 code=fixture(true);room=rooms[code];room.disconnected={1:500};clients[11].last_packet_at=1000
 last_server_frame=1000;account_for_server_pause(16000)
 check(room.disconnected[1]==15500 and clients[11].last_packet_at==16000,"server processing downtime is not charged to either player's grace period")
 code=fixture();rooms={}
 for occupant in [11,22]:clients[occupant].last_packet_at=-600000
 pair_match(11,22);code=str(clients[11].room)
 check(clients[11].last_packet_at>=0 and clients[22].last_packet_at>=0,"assignment starts a fresh connection clock after a long queue wait")
 tick_matches(Time.get_ticks_msec()+55000)
 check(rooms.has(code) and not rooms[code].cancel,"old queue activity cannot prematurely expire a newly assigned match")
 code=fixture();account_port=48049
 verify_client(11,clients[11].token)
 var verify_request=session_requests[11].request
 verify_client(11,clients[11].token,{"kind":"list"})
 check(session_requests.size()==1 and session_requests[11].request==verify_request and session_requests[11].next_message.kind=="list","duplicate account verification shares one in-flight request and preserves registration")
 remove_client(11)
 check(session_requests.is_empty() and not session_checked_at.has(11),"departure cancels the pending verification and clears its schedule")
 quit(0 if failures.is_empty() else 1)
