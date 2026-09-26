extends "res://tests/support/network_base.gd"
const Undo=preload("res://net/undo_history.gd")
var watcher
var e

func put(id: String,zone: String="field",seat: int=0):
 var c=e.make_card(id,seat,zone);e.players[seat][zone].append(c);c.entered_turns=0
 return c
func fresh():
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 e=Session.Duel.new();e.start(decks[0],decks[1],0,123)
 for p in e.players:
  p.hand=[];p.field=[];p.palette=[];p.grave=[];p.exile=[];p.potato=false;p.mulligan_done=true;p.turns=3
 e.phase="main";e.turn=5;e.active=0;e.priority=0;e.passes=0;e.pending={};e.presentation_events.clear()
 host.authority=e
func checkpoint():
 e.presentation_events.clear();host.undo_history.entries.clear();host.sequence+=1
 host.undo_history.remember(e,host.series.state.game_id,host.sequence)
 host.refresh_undo_status();check(host.persist(),"fixture checkpoint saved");host.publish([],false,true)
 check(await until(func():return guest.sequence==host.sequence and watcher.sequence==host.sequence),"fixture synchronized")
 sync_views()
func send(seat: int,command: Dictionary):
 var session=host if seat==0 else guest
 var before=host.sequence
 check(session.submit(command).is_empty(),"submit "+command.name)
 check(await until(func():return host.sequence>before and guest.sequence==host.sequence and watcher.sequence==host.sequence and not session.busy),"synchronize "+command.name)
 sync_views()
func passes():
 await send(e.priority,{"name":"pass_priority","args":[]})
 await send(e.priority,{"name":"pass_priority","args":[]})
func attack(uid: int):
 await send(0,{"name":"attack","args":[uid,{},e.payment(0,e.attack_cost(0)).plan]})
 check(host.undo_history.entries.size()==1 and not host.room.undo_available,"attack remains inside one operation")
func finish_combat():
 for i in range(12):
  if e.combat.is_empty():break
  if not e.pending.is_empty():break
  await passes()
 check(e.combat.is_empty() and e.pending.is_empty(),"combat completed")
func undo_to(before: Dictionary,target_sequence: int):
 var frames=[]
 for session in [host,guest,watcher]:
  var count=0
  for i in range(session.recording.frames.size()):
   if session.recording.frame(i).sequence<=target_sequence:count+=1
  frames.append(count)
 guest.room_action({"name":"undo_request"})
 check(await until(func():return not host.undo_request.is_empty() and not guest.room.get("undo_request",{}).is_empty()),"undo request synchronized")
 if host.undo_request.is_empty():return
 check(host.undo_request.target==target_sequence,"undo targets state before attack")
 check(not host.can_act(true) and not guest.can_act(true),"agreement locks both players")
 var sequence=host.sequence
 host.room_action({"name":"undo_accept","ticket":host.undo_request.id})
 check(await until(func():return host.sequence>sequence and guest.sequence==host.sequence and watcher.sequence==host.sequence and host.can_act() and guest.can_act()),"approved undo synchronized to players and spectator")
 sync_views()
 check(host.Codec.capture(e)==before,"undo restores complete pre-attack graph and RNG")
 check(host.latest_snapshot.recovery and guest.latest_snapshot.recovery and watcher.latest_snapshot.recovery,"all viewers discard combat animations")
 check(host.recording.frames.size()==frames[0] and guest.recording.frames.size()==frames[1] and watcher.recording.frames.size()==frames[2],"all replays discard the entire combat branch")
 check(host.latest_snapshot.projection.state.combat.is_empty() and guest.latest_snapshot.projection.state.combat.is_empty(),"neither player returns to an intermediate combat step")

func run():
 host=Session.new();guest=Session.new();root.add_child(host);root.add_child(guest)
 var storage="res://work/network-undo/"+str(Time.get_ticks_usec())
 host.initialize(storage+"/host");guest.initialize(storage+"/guest")
 host.error_raised.connect(func(_message):pass);guest.error_raised.connect(func(_message):pass)
 check(host.create_room(3,false,47989,"127.0.0.1").is_empty(),"host listens")
 guest.join_room("127.0.0.1",47989)
 check(await until(func():return not host.applicant.is_empty()),"guest joins")
 host.accept_applicant(true)
 check(await until(func():return host.can_act() and guest.can_act()),"both connected")
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 for seat in [0,1]:host.handle_room_action(seat,{"name":"deck","deck":decks[seat]})
 await until(func():return guest.sequence==host.sequence)
 await prepare()
 watcher=Session.new();root.add_child(watcher);watcher.initialize(storage+"/watcher")
 watcher.join_spectator("127.0.0.1",47989)
 check(await until(func():return not watcher.latest_snapshot.is_empty()),"spectator connected")

 # An unblocked attack includes its resource payment and damage window.
 fresh();var attacker=put("53");put("spell-ucs-031","field",1);var resource=put("164","palette")
 await checkpoint();var before=host.Codec.capture(e);var target=host.sequence
 await attack(attacker.uid)
 check(attacker.tapped and attacker.attacked and resource.tapped,"attack pays its tax and taps attacker")
 await finish_combat()
 check(e.players[1].life==19 and host.undo_history.entries.size()==2 and host.room.undo_available,"completed attack records one checkpoint")
 # Serialized history must retain the same boundary when a host resumes.
 var saved=host.Journal.load_from(host.storage+"/host.bin");var restored_history=Undo.new()
 restored_history.entries=saved.undo_entries;var restored_engine=Session.Duel.new();host.Codec.restore(restored_engine,saved.engine)
 check(restored_history.restore_previous(restored_engine).get("sequence",-1)==target and host.Codec.capture(restored_engine)==before,"saved history restores before the entire attack")
 await undo_to(before,target)
 check(not host.room.undo_available,"undo cannot cross initial boundary")

 # Multiple blockers, a fast response and manual damage allocation are one battle.
 fresh();attacker=put("50");var b1=put("53","field",1);var b2=put("53","field",1)
 var spell=put("177","hand",1);e.cards["177"].cost={}
 await checkpoint();before=host.Codec.capture(e);target=host.sequence
 await attack(attacker.uid);await passes()
 check(e.pending.get("kind","")=="block" and host.undo_history.entries.size()==1,"block choice creates no checkpoint")
 await send(1,{"name":"block","args":[[b1.uid,b2.uid]]})
 await send(0,{"name":"pass_priority","args":[]})
 await send(1,{"name":"commit_cast","args":[spell.uid,e.ref_target(b1),[]]})
 await passes()
 check(e.stack.is_empty() and not e.combat.is_empty() and host.undo_history.entries.size()==1,"resolved response stays inside combat operation")
 await passes()
 check(e.pending.get("kind","")=="damage_assignment" and host.undo_history.entries.size()==1,"damage assignment creates no checkpoint")
 await send(0,{"name":"combat_damage","args":[{str(b1.uid):3,str(b2.uid):2}]})
 await finish_combat()
 check(attacker.zone=="grave" and b2.zone=="grave" and spell.zone=="grave","battle and response change card zones")
 var steps=[];var response_recorded=false;var combat_frames=0
 for i in range(host.recording.frames.size()):
  var frame=host.recording.frame(i)
  if frame.sequence<=target:continue
  combat_frames+=1
  var state=frame.projection.state
  var step=state.combat.get("step","")
  if step not in steps:steps.append(step)
  if not state.stack.is_empty():response_recorded=true
 check(combat_frames==host.sequence-target and steps.has("attack_window") and steps.has("block_window") and steps.has("damage_window") and steps.has("") and response_recorded,"replay retains every combat command and response as separate frames")
 await undo_to(before,target)

 # Consecutive attacks preserve separate boundaries, including an early end.
 fresh();attacker=put("53");var second=put("53");var blocker=put("53","field",1)
 await checkpoint()
 await attack(attacker.uid);await passes();await send(1,{"name":"block","args":[[blocker.uid]]})
 await finish_combat()
 before=host.Codec.capture(e);target=host.sequence
 await send(0,{"name":"attack","args":[second.uid,{},[]]})
 await finish_combat()
 await undo_to(before,target)
 check(e.find_card(attacker.uid).zone=="grave" and not e.find_card(second.uid).tapped,"undo only rewinds the latest attack")

 # Queued forced battles and unfinished spell choices cannot become boundaries.
 var guard=Undo.new();guard.remember(e,"guards",1)
 e.combat_queue=[{"attacker":e.ref_target(second)}];guard.remember(e,"guards",2)
 check(guard.entries.size()==1 and not guard.available(e,"guards"),"queued battle cannot split an operation")
 e.combat_queue=[];e.pending={"kind":"effect_choice"};guard.remember(e,"guards",3)
 check(guard.entries.size()==1,"unfinished spell choice still creates no checkpoint")
 e.pending={};guard.remember(e,"guards",4)
 check(guard.entries.size()==2 and guard.available(e,"guards"),"settled ordinary operation remains undoable")
 host.leave(false);guest.leave(false);watcher.leave(false)
 print("NETWORK UNDO ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
