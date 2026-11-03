extends "res://tests/support/rules_base.gd"

const Codec=preload("res://net/state_codec.gd")

func setup(who: int) -> Dictionary:
 fresh()
 var c=put("71","field",who);c.leader=true;c.original_owner=who;e.players[who].leader=c
 return c

func trigger() -> bool:
 return e.pending.get("trigger",{}).get("effect","")=="leader_death_damage"

func decisions(who: int,choices: Array):
 var y=setup(who)
 for i in range(3):
  e.destroy(put("53","field",who));e.pump_choices()
  expect(trigger()==(i<2),"death %d offered only within limit, seat %d" % [i+1,who])
  if i<2:
   expect(e.usage_count(y.uid,"death_ping")==i+1,"death consumes allowance before choice")
   e.choose_effect({"player":1-who} if choices[i] else {})
   if choices[i]:one()
  expect(e.pending.is_empty() and e.stack.is_empty(),"decision completed")
 expect(e.players[1-who].life==20-int(choices[0])-int(choices[1]),"damage only for accepted decisions")
 e.phase="end";e.priority=e.active;e.passes=0;one()
 expect(e.usage_count(y.uid,"death_ping")==0,"next turn resets usage")
 e.destroy(put("53","field",who));e.pump_choices()
 expect(trigger(),"next turn permits another death trigger")

func simultaneous(who: int):
 var y=setup(who)
 for i in range(3):
  var c=put("53","field",who);c.damage=e.stat(c,"health")
 e.judge();e.pump_choices()
 var offered=0
 for i in range(12):
  if e.pending.get("kind","")=="trigger_order":e.choose_trigger_order(0)
  elif trigger():
   offered+=1;e.choose_effect({})
  else:
   e.pump_choices()
   if e.pending.is_empty() and e.triggers.is_empty():break
 expect(offered==2 and e.usage_count(y.uid,"death_ping")==2,"simultaneous deaths offer only two choices")

func leader_return(who: int):
 var y=setup(who)
 e.destroy(put("53","field",who));e.pump_choices();e.choose_effect({})
 e.destroy(y);e.pump_choices()
 expect(e.pending.get("kind","")=="leader_return","leader death asks where to return")
 e.choose_return(true)
 expect(trigger(),"leader death consumes remaining choice after return")
 var restored=Duel.new();expect(Codec.restore(restored,Codec.capture(e)).is_empty(),"pending choice saves")
 e=restored;e.choose_effect({})
 expect(e.usage_count(y.uid,"death_ping")==2,"declining after restore consumes second choice")
 e.enter_field(e.players[who].leader,who)
 e.destroy(put("53","field",who));e.pump_choices()
 expect(not trigger(),"returning leader cannot evade the limit")

func run():
 for who in [0,1]:
  decisions(who,[false,false]);decisions(who,[true,false]);decisions(who,[false,true]);simultaneous(who);leader_return(who)
 print("YUYUKO DEATH LIMIT: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
