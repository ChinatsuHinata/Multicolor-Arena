extends SceneTree
var connections=[]
var failures=[]
var checks=0
var endpoint=""
var players=[]
func _initialize():call_deferred("run")
func _process(_delta) -> bool:
 for connection in connections:
  connection.socket.poll()
  while connection.socket.get_available_packet_count()>0:
   var raw=connection.socket.get_packet().get_string_from_utf8()
   if not raw.begins_with("MCR1"):continue
   var msg=JSON.parse_string(raw.substr(4))
   if not msg is Dictionary:continue
   connection.messages.append(msg)
   if msg.get("kind","")=="link_probe" and connection.respond:send_to(connection,{"kind":"link_pong","nonce":msg.nonce})
 return false
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS: ",label)
 else:failures.append(label);push_error(label)
func until(predicate: Callable,seconds: float=8) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<deadline:
  if predicate.call():return true
  await process_frame
 return false
func send_to(connection: Dictionary,msg: Dictionary):
 raw_send(connection,("MCR1"+JSON.stringify(msg)).to_utf8_buffer())
func raw_send(connection: Dictionary,data: PackedByteArray):
 connection.socket.set_target_peer(1)
 connection.socket.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
 connection.socket.put_packet(data)
func messages(connection: Dictionary,kind: String) -> Array:return connection.messages.filter(func(msg):return msg.get("kind","")==kind)
func paired(connection: Dictionary) -> Dictionary:return messages(connection,"matched").back()
func wire(message: Dictionary) -> PackedByteArray:
 var data=var_to_bytes(message)
 return var_to_bytes({"id":1,"count":1,"index":0,"data":data,"hash":data.hex_encode().sha256_text()})
func run():
 var args=OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 var manifest=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 endpoint=manifest.endpoint;players=manifest.players
 if not endpoint.begins_with("ws://127.0.0.1:"):quit(2);return
 for lost_actor in [0,1]:
  connections=[]
  for player in range(2):
   var connection={"socket":WebSocketMultiplayerPeer.new(),"player":player,"messages":[],"respond":true}
   connections.append(connection)
   check(connection.socket.create_client(endpoint)==OK and await until(func():return connection.socket.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED),"connect isolated player "+str(player))
   send_to(connection,{"kind":"match","net_protocol":1,"token":players[player].token,"version":"a".repeat(64),"deck_hash":"b".repeat(64)})
  check(await until(func():return connections.all(func(c):return not messages(c,"matched").is_empty())),"both players receive the same match")
  if not failures.is_empty():quit(1);return
  var host=connections[0] if paired(connections[0]).role=="host" else connections[1]
  var guest=connections[1] if host==connections[0] else connections[0]
  # A real guest acknowledgment must precede the host's confirmation.
  raw_send(guest,wire({"type":"ack","sequence":7}))
  await create_timer(0.1).timeout
  raw_send(host,("MCD1"+"%08X" % guest.socket.get_unique_id()).to_utf8_buffer()+wire({"type":"ready_state","sequence":7}))
  send_to(host,{"kind":"update","status":"playing","round":1})
  await create_timer(2.5).timeout
  check(not messages(host,"link_probe").is_empty() and not messages(guest,"link_probe").is_empty(),"both authenticated sides independently answer server challenges")
  send_to(host,{"kind":"match_wait","match_id":paired(host).match_id})
  await create_timer(0.2).timeout
  check(messages(host,"link_status").back().states==["online","online"],"one player's accusation cannot mark the opponent offline")
  var absent=host if lost_actor==0 else guest
  var survivor=guest if lost_actor==0 else host
  absent.respond=false
  # Keep TCP open and continue arbitrary traffic: only a valid fresh challenge proves both directions.
  send_to(absent,{"kind":"link_pong","nonce":"forged"})
  check(await until(func():return not messages(survivor,"link_status").is_empty() and messages(survivor,"link_status").back().states[lost_actor]=="offline",14),"server identifies the nonresponsive seat: "+str(lost_actor+1))
  check(messages(survivor,"match_settled").is_empty(),"detection preserves the recovery grace period")
  check(await until(func():return not messages(survivor,"match_settled").is_empty(),60),"server resolves the real elapsed timeout")
  if messages(survivor,"match_settled").is_empty():quit(1);return
  var result=messages(survivor,"match_settled").back()
  check(result.winner==1-lost_actor and result.rated and result.resolution.reason=="player_link_timeout","only the observed unresponsive side loses: "+str(lost_actor+1))
  check(result.resolution.evidence.size()==1 and result.resolution.evidence[0].seat==lost_actor+1 and result.resolution.evidence[0].cause=="probe_timeout","settlement carries server evidence for the correct seat")
  for connection in connections:connection.socket.close()
  await create_timer(0.5).timeout
 print("CONNECTION ATTRIBUTION: ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
