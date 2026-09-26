extends "res://tests/support/network_base.gd"
const Replay=preload("res://scripts/replay_archive.gd")
var watcher
func send(seat:int,command:Dictionary):
 var session=host if seat==0 else guest
 var old=host.sequence
 check(session.submit(command).is_empty(),"command accepted "+command.name)
 check(await until(func():return host.sequence>old and guest.sequence==host.sequence and not session.busy),"command synchronized")
 sync_views()
func request_undo(seat:int):
 var session=host if seat==0 else guest
 session.room_action({"name":"undo_request"})
 check(await until(func():return not host.undo_request.is_empty() and not guest.room.get("undo_request",{}).is_empty()),"request reaches both seats")
 check(not host.can_act(true) and not guest.can_act(true),"both players locked during agreement")
func approve(seat:int):
 var session=host if seat==0 else guest
 var ticket=host.undo_request.id;var before=host.sequence
 session.room_action({"name":"undo_accept","ticket":ticket})
 check(await until(func():return host.sequence>before and guest.sequence==host.sequence and host.can_act() and guest.can_act()),"approved undo synchronized")
 sync_views()
func run():
 host=Session.new();guest=Session.new();root.add_child(host);root.add_child(guest)
 host.initialize("res://work/update0921/undo-host");guest.initialize("res://work/update0921/undo-guest")
 host.error_raised.connect(func(_message):pass);guest.error_raised.connect(func(_message):pass)
 check(host.create_room(3,false,47989,"127.0.0.1").is_empty(),"host listens")
 guest.join_room("127.0.0.1",47989)
 check(await until(func():return not host.applicant.is_empty()),"guest requests join")
 host.accept_applicant(true)
 check(await until(func():return host.can_act() and guest.can_act()),"connected")
 var decks=JSON.parse_string(FileAccess.get_file_as_string(Store.SAVE_PATH)).decks
 for seat in [0,1]:host.handle_room_action(seat,{"name":"deck","deck":decks[seat]})
 await until(func():return guest.sequence==host.sequence)
 await prepare()
 watcher=Session.new();root.add_child(watcher);watcher.initialize("res://work/update0921/undo-watcher")
 watcher.join_spectator("127.0.0.1",47989)
 check(await until(func():return not watcher.latest_snapshot.is_empty()),"spectator joins before branch")
 check(not host.room.undo_available,"initial state cannot rewind")
 var initial=host.Codec.capture(host.authority)
 await send(0,{"name":"mulligan","args":[[]]})
 check(await until(func():return watcher.sequence==host.sequence),"spectator sees operation before undo")
 await request_undo(1)
 var ticket=host.undo_request.id
 host.handle_undo_action(1,{"name":"undo_accept","ticket":ticket})
 check(not host.undo_request.is_empty(),"requester cannot self approve")
 await approve(0)
 check(await until(func():return watcher.sequence==host.sequence),"spectator receives approved rewind")
 check(watcher.latest_snapshot.recovery and watcher.recording.frames.size()==1,"observer drops discarded branch and stale animations")
 check(watcher.latest_snapshot.projection.state.players.all(func(p):return p.hand.all(func(c):return c.card_id=="back")),"undo does not expose either hand to spectator")
 check(host.Codec.capture(host.authority)==initial,"full graph and RNG restored")
 check(host.recording.frames.size()==1 and guest.recording.frames.size()==1,"abandoned operation and undo absent from both replays")
 check(not host.room.undo_available,"no cross initial checkpoint")
 await send(0,{"name":"mulligan","args":[[]]})
 await request_undo(0)
 guest.room_action({"name":"undo_decline","ticket":host.undo_request.id})
 check(await until(func():return host.undo_request.is_empty() and guest.room.get("undo_request",{}).is_empty()),"decline unlocks both sides")
 check(host.authority.players[0].mulligan_done,"decline preserves action")
 await send(1,{"name":"mulligan","args":[[]]})
 var e=host.authority
 # A real cast and its priority passes: only the two outer empty-stack states are checkpoints.
 e.pending={};e.triggers=[];e.stack=[];e.phase="main";e.priority=0;e.active=0
 var c=e.make_card("177",0,"hand");e.players[0].hand.append(c)
 var u=e.make_card("50",0,"void");e.enter_field(u,0);e.triggers=[];e.pending={};e.stack=[]
 for color in ["红","黄"]:
  var r=e.make_card("50",0,"palette");r.override_colors=[color];e.players[0].palette.append(r)
 # Use the engine's validated payment plan, allowing the chosen deck's existing sources.
 e.cards["177"].cost={}
 e.presentation_events=[];host.undo_history.entries.clear();host.undo_history.remember(e,host.series.state.game_id,host.sequence);host.refresh_undo_status();host.publish([],false,true)
 await until(func():return guest.sequence==host.sequence);sync_views()
 var before_chain=host.Codec.capture(e);var checkpoints=host.undo_history.entries.size()
 await send(0,{"name":"commit_cast","args":[c.uid,e.ref_target(u),[]]})
 check(e.stack.size()>0 and host.undo_history.entries.size()==checkpoints and not host.room.undo_available,"cannot rewind during stack")
 for i in range(12):
  if e.stack.is_empty():break
  await send(e.priority,{"name":"pass_priority","args":[]})
 check(e.stack.is_empty() and host.undo_history.entries.size()==checkpoints+1,"whole stack recorded as one operation")
 await request_undo(0);await approve(1)
 check(host.Codec.capture(e)==before_chain,"whole stack and costs restored")
 check(host.latest_snapshot.projection.state.stack==guest.latest_snapshot.projection.state.stack and host.latest_snapshot.projection.state.phase==guest.latest_snapshot.projection.state.phase,"same authoritative public state after recovery")
 var replay=host.recording
 var graph_after=host.Codec.capture(host.authority)
 # Empty stack during a continuation is not the end of that spell's resolution.
 var guard=preload("res://net/undo_history.gd").new()
 guard.remember(e,"continuation",1)
 e.pending={"kind":"effect_choice","owner":0,"options":[{"none":true}]}
 guard.remember(e,"continuation",2)
 check(guard.entries.size()==1 and not guard.available(e,"continuation"),"unresolved effect choice cannot split an empty-stack checkpoint")
 e.pending={};guard.remember(e,"continuation",3)
 check(guard.entries.size()==2 and guard.available(e,"continuation"),"completed continuation creates one checkpoint")
 host.Codec.restore(e,graph_after)
 host.on_disconnect(host.remote_peer);host.transport.drop(host.remote_peer)
 check(await until(func():return host.can_act() and guest.can_act(),12),"reconnect after undo completes")
 sync_views()
 check(host.Codec.capture(host.authority)==graph_after and host.undo_request.is_empty(),"reconnect restores accepted branch without stale request")
 var recovered=Replay.new();recovered.begin_capture(host.storage+"/capture.bin",host.series.state.match_id)
 check(recovered.frames.size()==replay.frames.size() and recovered.frame(recovered.frames.size()-1).projection.state.history==replay.frame(replay.frames.size()-1).projection.state.history,"capture recovery keeps only retained replay branch")
 for i in range(replay.frames.size()):
  var frame=replay.frame(i)
  check(not frame.has("rewinds") and not frame.room.has("undo_request"),"replay contains no rollback metadata")
 await concede(1);await prepare()
 check(host.undo_history.entries.size()==1 and not host.room.undo_available,"new BO3 game resets undo boundary")
 var saved=replay.save("res://work/update0921/undo-branch.mreply")
 check(not saved.has("error"),"rewound replay saved")
 var loaded=Replay.read("res://work/update0921/undo-branch.mreply")
 check(not loaded.has("error"),"rewound replay loads and validates")
 if loaded.has("archive"):check(not loaded.archive.metadata.has("_rewind_seen"),"shared replay contains no rewind bookkeeping")
 host.leave(false);guest.leave(false);watcher.leave(false)
 print("UPDATE0921 UNDO ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
