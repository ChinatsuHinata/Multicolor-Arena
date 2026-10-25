extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Emotes=preload("res://scripts/rules/leader_emotes.gd")
const Gateway=preload("res://net/command_gateway.gd")
const Seat=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const Codec=preload("res://net/state_codec.gd")
const Undo=preload("res://net/undo_history.gd")
var failures=[]
var checks=0
func expect(ok: bool,title: String):
 checks+=1
 if not ok:failures.append(title);push_error(title)
func _initialize():call_deferred("run")
func run():
 var a=Store.blank("自机表情测试");a.leader="70";a.main=["100","100","100","100","100","100"];a.rule_set="test"
 a.leader_emotes={"enabled":true};a.emote_enabled=true
 var e=Duel.new();e.start(a,a,0,8457)
 expect(e.leader_emote_profiles.all(func(p):return p.enabled==false),"unowned leaders and deck metadata cannot opt in")
 e.phase="main";e.pending={};e.active=0;e.priority=0;e.presentation_events.clear()
 expect(not e.send_emote(0,"greeting").is_empty() and e.presentation_events.is_empty(),"disabled own leader cannot send")
 e.leader_emote_profiles[0].enabled=true
 expect(not Gateway.apply(e,0,{"name":"send_emote","args":["surrender"]}).is_empty(),"manual command cannot forge surrender dialogue")
 expect(not Gateway.apply(e,0,{"name":"send_emote","args":[1]}).is_empty(),"network validates emote parameter type")
 expect(not e.send_emote(-1,"greeting").is_empty(),"invalid seat rejected")
 e.priority=1
 expect(not e.send_emote(0,"greeting").is_empty(),"other player's priority rejects emotes")
 e.priority=0;e.pending={"kind":"effect_choice","owner":0}
 expect(not e.send_emote(0,"greeting").is_empty(),"pending choice rejects emotes")
 e.pending={};e.entry_choices=[{}]
 expect(not e.send_emote(0,"greeting").is_empty(),"queued entry choice rejects emotes")
 e.entry_choices=[];e.phase="mulligan"
 expect(not e.send_emote(0,"greeting").is_empty(),"mulligan rejects emotes")
 e.phase="main";e.response_clock={"key":"unchanged","deadline":123.0}
 var gameplay=[e.priority,e.passes,e.phase,e.history.size(),e.log.size(),e.rng.state,e.response_clock.duplicate(true)]
 expect(Gateway.apply(e,0,{"name":"send_emote","args":["greeting"]}).is_empty(),"valid manual emote passes authoritative gateway")
 expect(gameplay==[e.priority,e.passes,e.phase,e.history.size(),e.log.size(),e.rng.state,e.response_clock],"emote does not change priority, response timer, history or RNG")
 expect(e.emote_remaining(0)>9.0 and e.emote_remaining(0)<=10.0,"accepted send starts ten-second cooldown")
 expect(not e.send_emote(0,"praise").is_empty() and e.presentation_events.size()==1,"repeat send rejected without duplicate event")
 var event=e.presentation_events[0]
 expect(event.type=="result" and event.get("emote",false) and event.owner==0 and event.kind=="greeting" and event.text==Emotes.DEFAULT_LINES.greeting and event.leader_uid==e.players[0].leader.uid,"authority selects dialogue and primary leader anchor using legacy-safe result type")
 for projection in [Seat.build(e,0,[event]),Seat.build(e,1,[event]),Observer.build(e,[event])]:
  var remote=Remote.new();remote.apply_snapshot(bytes_to_var(var_to_bytes(projection)))
  expect(remote.presentation_events==[event] and remote.leader_emote_profiles[0].enabled and remote.emote_remaining(0)>9.0,"player and observer projections retain dialogue, availability and cooldown")
 var snapshot=Seat.build(e,0,[event]);var deadlines=snapshot.state.emote_ready_at.duplicate()
 snapshot.response_clock_received_at=float(snapshot.response_clock_sampled_at)+123.0
 var translated=Remote.new();translated.apply_snapshot(snapshot);translated.apply_snapshot(snapshot)
 expect(snapshot.state.emote_ready_at==deadlines and absf(translated.emote_ready_at[0]-deadlines[0]-123.0)<0.001,"clock translation neither mutates snapshots nor accumulates on repeated apply")
 var restored=Duel.new();Codec.restore(restored,bytes_to_var(var_to_bytes(Codec.capture(e))))
 expect(restored.emote_ready_at==e.emote_ready_at and restored.emote_serial==e.emote_serial and restored.leader_emote_profiles==e.leader_emote_profiles,"save/reconnect preserves authoritative emote state")
 e.emote_ready_at=[110.0,0.0]
 expect(not Emotes.send(e,0,"praise",109.999).is_empty(),"send before ten seconds rejected")
 expect(Emotes.send(e,0,"praise",110.0).is_empty(),"send exactly at ten-second boundary accepted")
 for kind in Emotes.KINDS:
  e.emote_ready_at=[0.0,0.0]
  expect(e.send_emote(0,kind).is_empty() and e.presentation_events.back().text==Emotes.DEFAULT_LINES[kind],"category selects its own text: "+kind)
 var before=e.presentation_events.size();e.surrender(0)
 expect(e.presentation_events.size()==before+1 and e.presentation_events.back().kind=="surrender" and e.winner==1,"surrender emits once even during manual cooldown")
 e.surrender(0)
 expect(e.presentation_events.size()==before+1,"repeated surrender never repeats dialogue")
 expect(not e.send_emote(0,"greeting").is_empty(),"finished game rejects manual emotes")
 e.start(a,a,0,8457);e.presentation_events.clear();e.surrender(1)
 expect(not e.leader_emote_profiles[1].enabled and e.presentation_events.size()==1 and e.presentation_events[0].owner==1,"disabled opponent still emits surrender dialogue for other viewers")
 e.start(a,a,0,8457);e.phase="main";e.pending={};e.leader_emote_profiles[0].enabled=true
 var undo=Undo.new();undo.remember(e,"test-emotes",1)
 e.players[0].life=19;e.revision+=1;undo.remember(e,"test-emotes",2)
 e.send_emote(0,"greeting");var deadline=e.emote_ready_at[0];var serial=e.emote_serial
 expect(not undo.restore_previous(e,"test-emotes").is_empty() and e.players[0].life==20,"gameplay undo still restores the preceding operation")
 expect(e.emote_ready_at[0]==deadline and e.emote_serial==serial and e.presentation_events.is_empty(),"gameplay undo preserves emote cooldown and prevents event replay")
 e.start(a,a,0,8457)
 expect(e.emote_serial==0 and e.emote_ready_at==[0.0,0.0] and not e.leader_emote_profiles[0].enabled,"new game clears cooldown, serial and test-only unlock")
 print("LEADER_EMOTES: ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
