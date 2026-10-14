extends SceneTree
var connections=[]
var failures=[]
var checks=0
var endpoint=""
var players=[]
func _initialize():call_deferred("run")
func _process(_delta) -> bool:
 for connection in connections:
  var socket=connection.socket
  socket.poll()
  while socket.get_available_packet_count()>0:
   var raw=socket.get_packet().get_string_from_utf8()
   if not raw.begins_with("MCR1"):continue
   var msg=JSON.parse_string(raw.substr(4))
   if msg is Dictionary:connection.messages.append(msg)
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
 connection.socket.set_target_peer(1)
 connection.socket.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
 connection.socket.put_packet(("MCR1"+JSON.stringify(msg)).to_utf8_buffer())
func queue(connection: Dictionary):
 send_to(connection,{"kind":"match","token":players[connection.player].token,"version":"a".repeat(64),"deck_hash":"b".repeat(64)})
func open_client(player: int) -> Dictionary:
 var socket=WebSocketMultiplayerPeer.new()
 var connection={"socket":socket,"player":player,"messages":[]}
 connections.append(connection)
 check(socket.create_client(endpoint)==OK and await until(func():return socket.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED),"client %d connects" % player)
 return connection
func messages(connection: Dictionary,kind: String) -> Array:
 return connection.messages.filter(func(msg):return msg.get("kind","")==kind)
func paired(connection: Dictionary) -> Dictionary:return messages(connection,"matched").back()
func run():
 var args=OS.get_cmdline_user_args()
 if args.size()!=1:push_error("Requires isolated test manifest");quit(2);return
 var manifest=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 endpoint=manifest.endpoint;players=manifest.players
 if not endpoint.begins_with("ws://127.0.0.1:"):push_error("Test requires loopback relay");quit(2);return
 var first=await open_client(0);var second=await open_client(1)
 queue(first);queue(second)
 check(await until(func():return not messages(first,"matched").is_empty() and not messages(second,"matched").is_empty()),"isolated service pairs both authenticated players")
 if not failures.is_empty():quit(1);return
 second.socket.close()
 var replacement=await open_client(1);queue(replacement)
 check(await until(func():return not messages(first,"match_settled").is_empty() and not messages(replacement,"match_queued").is_empty()),"crashed pregame player immediately requeues after old match cancellation")
 check(not messages(first,"match_settled").back().rated,"pregame cancellation does not change Elo")
 queue(first)
 check(await until(func():return messages(first,"matched").size()==2 and not messages(replacement,"matched").is_empty()),"the surviving opponent also joins a fresh match")
 var takeover=await open_client(1);queue(takeover)
 check(await until(func():return messages(first,"match_settled").size()==2 and not messages(takeover,"match_queued").is_empty()),"same-device replacement releases an old connection which has not closed yet")
 queue(first)
 check(await until(func():return messages(first,"matched").size()==3 and not messages(takeover,"matched").is_empty()),"next match starts after retiring the old connection")
 var battle_host=first if paired(first).role=="host" else takeover
 send_to(battle_host,{"kind":"update","status":"playing","round":1})
 await create_timer(0.2).timeout
 var saved=paired(takeover).duplicate(true)
 takeover.socket.close()
 var resumed=await open_client(1)
 send_to(resumed,{"kind":saved.role,"room":saved.room,"match_id":saved.match_id,"resume":true,"version":"a".repeat(64),"token":players[1].token})
 check(await until(func():return not messages(resumed,"registered").is_empty() or not messages(resumed,"paired").is_empty()),"original player still resumes the started match during the grace period")
 check(messages(first,"match_settled").size()==2,"reconnection does not cancel or settle the active match")
 resumed.socket.close()
 var fresh=await open_client(1);queue(fresh)
 check(await until(func():return messages(first,"match_settled").size()==3 and not messages(fresh,"match_queued").is_empty()),"new matching after a battle crash settles before entering the next queue")
 var result=messages(first,"match_settled").back()
 check(result.rated and result.winner==int(paired(first).seat)-1 and result.elo==1016,"started-match abandonment awards the connected opponent one persisted win")
 queue(first)
 check(await until(func():return messages(first,"matched").size()==4 and not messages(fresh,"matched").is_empty()),"matching continues after repeated cancellations, reconnects and forfeits")
 # Leave both WebSocket connections open without acknowledging any game state.
 var before_timeout=messages(first,"match_settled").size()
 var fresh_before_timeout=messages(fresh,"match_settled").size()
 await create_timer(55).timeout
 check(messages(first,"match_settled").size()==before_timeout and messages(fresh,"match_settled").size()==fresh_before_timeout,"open but unsynchronized sockets retain their reservations before one minute")
 check(await until(func():return messages(first,"match_settled").size()==before_timeout+1 and messages(fresh,"match_settled").size()==fresh_before_timeout+1,10),"real relay releases both stalled connections after one minute")
 check(not messages(first,"match_settled").back().rated and messages(first,"match_settled").back().winner==-2,"stalled pregame timeout is durably cancelled without a rating result")
 queue(first);queue(fresh)
 check(await until(func():return messages(first,"matched").size()==5 and messages(fresh,"matched").size()==2),"both released sockets can immediately enter and receive a new match")
 for connection in connections:connection.socket.close()
 print("MATCH RECOVERY NETWORK ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
