extends "res://tests/support/rules_base.gd"
const Seat=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const Codec=preload("res://net/state_codec.gd")

func setup(who: int=0) -> Dictionary:
 fresh();e.debug_enabled=true;e.debug_free_payment=true
 e.active=who;e.priority=who;e.phase="end";e.passes=0
 var butterfly=put("120","field",who);butterfly.timer=1
 for player in range(2):
  for id in ["165","167","166","164","168"]:
   for i in range(3):put(id,"palette",player)
 return butterfly

func trigger_entry() -> Dictionary:
 var found=e.stack.filter(func(s):return s.get("effect","")=="timed_life_expired")
 return found[0] if found.size()==1 else {}

func timed_trigger(owner: int):
 var butterfly=setup(owner);var old_turn=e.turn
 one()
 var entry=trigger_entry()
 expect(e.turn==old_turn and e.phase=="end" and e.winner==-2,"countdown 0 remains in end phase with no immediate loss, seat "+str(owner))
 expect(not entry.is_empty() and entry.kind=="ability" and e.pending.is_empty(),"countdown announces exactly one triggered ability, seat "+str(owner))
 expect(butterfly.zone=="grave","zero-timer time spell moves to grave while the ability remains")
 if entry.is_empty():return
 expect(e.priority==1-owner,"opponent receives priority to respond")
 var saved=Codec.capture(e);var restored=Duel.new();Codec.restore(restored,saved)
 expect(restored.stack.any(func(s):return s.id==entry.id and s.get("effect","")=="timed_life_expired"),"save/restore preserves triggered ability")
 var counter=put("123","hand",1-owner)
 var remote=Remote.new();remote.seat=1-owner;remote.apply_snapshot(Seat.build(e,1-owner))
 expect(remote.stack.any(func(s):return s.id==entry.id and s.kind=="ability"),"opponent projection preserves triggered ability")
 expect({"stack_id":entry.id} in remote.targets_for("123",1-owner,counter.uid),"network opponent can select the triggered ability for Tengu Defense")
 one()
 expect(e.winner==1-owner,"uncountered ability makes its controller lose, seat "+str(owner))

func counter(owner: int,who: int):
 var butterfly=setup(owner);one();var entry=trigger_entry()
 expect(not entry.is_empty(),"ability is available for counter")
 if entry.is_empty():return
 var spell=put("123","hand",who)
 if e.priority!=who:e.pass_priority(e.priority)
 expect(e.priority==who and {"stack_id":entry.id} in e.targets_for("123",who,spell.uid),"Tengu Defense targets butterfly ability, responder "+str(who))
 var error=e.commit_cast(who,spell.uid,{"stack_id":entry.id},[])
 expect(error.is_empty(),"Tengu Defense can be cast: "+error)
 if not error.is_empty():return
 one()
 expect(e.winner==-2 and not e.stack.any(func(s):return s.id==entry.id),"counter removes ability and controller does not lose")
 expect(butterfly.zone=="grave","counter does not undo the time spell leaving the field")
 for i in range(3):e.judge();e.pump_choices()
 expect(trigger_entry().is_empty(),"repeated checks do not re-trigger a countered zero timer")
 var turn=e.turn;one()
 expect(e.turn==turn+1 and e.winner==-2,"normal play proceeds after both players pass")

func changed_timer():
 var butterfly=setup();e.phase="main"
 put("75","field")
 var spell=put("spell-fdf-055","hand")
 var choices=e.targets_for(spell.card_id,0,spell.uid)
 var matches=choices.filter(func(t):return t.get("uid",-1)==butterfly.uid and t.get("mode","")=="移除2个计时")
 expect(not matches.is_empty(),"Clock Corpse can choose butterfly and remove its last timer")
 if matches.is_empty():return
 var error=e.commit_cast(0,spell.uid,matches[0],[])
 expect(error.is_empty(),"Clock Corpse casts normally: "+error)
 if not error.is_empty():return
 one();var entry=trigger_entry()
 expect(not entry.is_empty() and butterfly.zone=="grave","resolving Clock Corpse announces the triggered ability")
 if entry.is_empty():return
 e.counter_entry(entry.id);e.judge();e.pump_choices()
 expect(trigger_entry().is_empty(),"countered ability is not recreated by repeated checks")
 e.move_to(butterfly,"field");butterfly.timer=1;e.judge();e.pump_choices()
 expect(butterfly.zone=="field" and trigger_entry().is_empty(),"returning a new instance with a timer does not trigger")
 e.add_timer(butterfly,-1);e.judge();e.pump_choices()
 expect(not trigger_entry().is_empty(),"a new instance reaching zero announces a new ability")

func sakuya_double():
 var butterfly=setup();put("character-fdf-041","field");one()
 if e.pending.get("kind","")=="trigger_order":e.choose_trigger_order([0,1])
 var entries=e.stack.filter(func(s):return s.get("effect","")=="timed_life_expired")
 expect(entries.size()==2,"Sakuya causes two independent butterfly triggers")
 if entries.size()!=2:return
 var who=e.priority;var spell=put("123","hand",who)
 var error=e.commit_cast(who,spell.uid,{"stack_id":entries.back().id},[])
 expect(error.is_empty(),"Tengu Defense can counter one doubled trigger: "+error)
 if not error.is_empty():return
 one()
 expect(e.winner==-2 and e.stack.filter(func(s):return s.get("effect","")=="timed_life_expired").size()==1,"countering one trigger leaves the other on stack")
 one();expect(e.winner==1,"remaining doubled trigger makes controller lose")

func multiple_butterflies():
 var first=setup();var second=put("120","field");second.timer=1
 one()
 if e.pending.get("kind","")=="trigger_order":e.choose_trigger_order([0,1])
 expect(e.stack.filter(func(s):return s.get("effect","")=="timed_life_expired").size()==2 and first.zone=="grave" and second.zone=="grave","two simultaneous expirations create independent abilities")

func other_protection():
 var butterfly=setup();var other=put("120","field");other.timer=2
 one();var entry=trigger_entry()
 expect(not entry.is_empty(),"zero timer triggers even with another butterfly")
 if entry.is_empty():return
 expect(other.timer==1,"other butterfly retains one timer")
 one()
 expect(e.winner==-2 and other.zone=="field","another butterfly's active protection prevents losing")

func source_leaves_grave():
 var butterfly=setup();one();var entry=trigger_entry()
 expect(not entry.is_empty() and butterfly.zone=="grave","ability remains on stack after its source leaves the field")
 if entry.is_empty():return
 e.move_to(butterfly,"exile");one()
 expect(e.winner==1,"moving the source again does not erase an announced ability")

func enters_without_timer():
 var butterfly=setup();butterfly.timer=0;e.phase="main"
 e.judge();e.pump_choices()
 expect(butterfly.zone=="grave" and not trigger_entry().is_empty(),"a zero-timer time spell triggers on state check and goes to grave")

func cast_from_hand(owner: int):
 fresh();e.debug_enabled=true;e.debug_free_payment=true
 e.active=owner;e.priority=owner;e.phase="main"
 put("71","field",owner)
 for id in ["165","167","166","164","168"]:
  for i in range(3):put(id,"palette",owner)
 var butterfly=put("120","hand",owner)
 var error=e.commit_cast(owner,butterfly.uid,{"none":true},[])
 expect(error.is_empty(),"butterfly may be cast by seat %d: %s" % [owner,error])
 if not error.is_empty():return
 one()
 expect(butterfly.zone=="field" and butterfly.timer==3,"resolved butterfly enters with three counters, seat "+str(owner))
 expect(e.winner==-2 and trigger_entry().is_empty() and e.pending.is_empty(),"initial timer setup never causes premature expiry, seat "+str(owner))

func run():
 for owner in [0,1]:
  cast_from_hand(owner)
  timed_trigger(owner)
  counter(owner,1-owner)
  counter(owner,owner)
 changed_timer();other_protection();sakuya_double();multiple_butterflies();source_leaves_grave();enters_without_timer()
 print("BUTTERFLY TRIGGER: %d checks; %d failures" % [checks,failures.size()]);quit(0 if failures.is_empty() else 1)
