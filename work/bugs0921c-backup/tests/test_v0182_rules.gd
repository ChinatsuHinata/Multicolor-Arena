extends "res://tests/test_v09_rules.gd"
const Codec=preload("res://net/state_codec.gd")
const Table=preload("res://scripts/duel_table.gd")

func yuyuko():
 var c=e.players[0].leader
 c.card_id="71"; e.shift(c,"field"); e.players[0].field.append(c); c.entered_turns=0
 return c

func kill(c: Dictionary):
 e.damage_target(e.ref_target(c),20); e.judge(); e.pump_choices()

func finish_deaths():
 for i in range(80):
  e.pump_choices()
  if not e.pending.is_empty():
   match e.pending.kind:
    "trigger_order":e.choose_trigger_order(0)
    "leader_return":e.choose_return(true)
    "effect_choice":
     var aims=e.pending.options.filter(func(t):return t.get("player",-1)==1)
     e.choose_effect(aims[0] if e.pending.trigger.effect=="leader_death_damage" and not aims.is_empty() else {})
    _:expect(false,"unexpected pending "+str(e.pending));return
  elif not e.stack.is_empty():one()
  else:return
 expect(false,"death resolution terminates")

func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 fresh();var a=yuyuko();kill(a)
 expect(e.pending.get("kind")=="leader_return" and a.zone=="return_pending","lethal damage offers designated leader return")
 e.choose_return(true)
 expect(a.zone=="leader" and a.timer==2,"dead Yuyuko returns home with two timers")
 expect(e.pending.get("kind")=="effect_choice" and e.pending.trigger.effect=="leader_death_damage","returning home still offers her optional death trigger")
 expect(e.stack.size()==1 and e.stack[0].source.zone=="field","self-death uses last field information and enters stack once")
 expect(e.pending.options.has({"player":0}) and e.pending.options.has({"player":1}),"both players remain legal targets after leader return")
 e.choose_effect({"player":1});one()
 expect(e.players[1].life==19 and e.usage_count(a.uid,"death_ping")==1,"self-death resolves exactly one damage and one use")
 e.judge();e.pump_choices()
 expect(e.stack.is_empty() and e.pending.is_empty() and e.triggers.is_empty(),"repeated state checks do not replay the death")
 expect(not a.has("return_death_observers") and not a.has("return_snapshot"),"return context is removed after dispatch")

 fresh();a=yuyuko();kill(a);e.choose_return(false);finish_deaths()
 expect(a.zone=="grave" and e.players[1].life==19 and e.usage_count(a.uid,"death_ping")==1,"declining return also triggers once")
 fresh();a=yuyuko();kill(a);e.choose_return(true);e.choose_effect({});finish_deaths()
 expect(e.players[1].life==20 and e.usage_count(a.uid,"death_ping")==0,"optional self-death may be declined without spending a use")

 fresh();a=yuyuko();var b=put("53");kill(b);finish_deaths()
 expect(e.players[1].life==19,"friendly death uses the first activation")
 kill(a);e.choose_return(true);finish_deaths()
 expect(e.players[1].life==18 and e.usage_count(a.uid,"death_ping")==2,"self-death can use the second activation after a friendly death")

 fresh();a=yuyuko()
 for i in range(2):kill(put("53"));finish_deaths()
 kill(a);e.choose_return(true);finish_deaths()
 expect(e.players[1].life==18 and e.usage_count(a.uid,"death_ping")==2,"self-death respects the per-turn limit")

 # A state-check batch must retain observers even when all of them die.
 fresh();a=yuyuko();b=put("53")
 e.damage_target(e.ref_target(a),20);e.damage_target(e.ref_target(b),20);e.judge();e.pump_choices()
 expect(e.death_observers.is_empty() and a.return_death_observers.size()==2,"pending return retains its own simultaneous-death snapshot")
 e.choose_return(true);finish_deaths()
 expect(a.zone=="leader" and b.zone=="grave" and e.players[1].life==18,"simultaneous self and friendly deaths each trigger once")
 expect(e.usage_count(a.uid,"death_ping")==2,"simultaneous batch consumes exactly two uses")

 # Destruction and sacrifice bypass judge's batch but also need field observers.
 fresh();a=yuyuko();e.sacrifice(a);e.pump_choices();e.choose_return(true);finish_deaths()
 expect(a.zone=="leader" and e.players[1].life==19,"sacrificed Yuyuko triggers after returning home")
 fresh();a=yuyuko();e.destroy(a);e.pump_choices();e.choose_return(true);finish_deaths()
 expect(a.zone=="leader" and e.players[1].life==19,"destroyed Yuyuko triggers after returning home")
 for zone in ["hand","exile","deck","palette"]:
  fresh();a=yuyuko();e.move_to(a,zone);e.pump_choices();e.choose_return(true);finish_deaths()
  expect(e.players[1].life==20 and e.usage_count(a.uid,"death_ping")==0,"non-death return from "+zone+" creates no death trigger")
 fresh();a=yuyuko();a.exile_on_grave=true;kill(a);e.choose_return(true);finish_deaths()
 expect(e.players[1].life==20,"exile replacement is not a death")
 fresh();a=put("71");kill(a);finish_deaths()
 expect(a.zone=="grave" and e.players[1].life==20,"unmarked Yuyuko copy has no leader ability")

 # Save/restore at the return decision is the same path used by LAN recovery.
 fresh();a=yuyuko();b=put("53")
 e.damage_target(e.ref_target(a),20);e.damage_target(e.ref_target(b),20);e.judge();e.pump_choices()
 var restored=Duel.new();Codec.restore(restored,Codec.capture(e));e=restored;a=e.players[0].leader
 expect(is_same(e.pending.card,a) and a.return_death_observers.size()==2,"recovered pending return retains identity and observer snapshots")
 e.choose_return(true);finish_deaths()
 expect(e.players[1].life==18 and e.usage_count(a.uid,"death_ping")==2,"recovered simultaneous deaths resolve identically")

 # Actual death -> optional trigger -> selected tapped palette -> stack resolve.
 fresh();a=put("1");b=put("164","palette");b.tapped=true;kill(a)
 expect(e.pending.get("kind")=="effect_choice" and e.pending.trigger.effect=="crystal","crystal is offered on death")
 expect(e.pending.options.size()==1 and e.pending.options[0].uid==b.uid,"crystal selects only the tapped palette card")
 e.choose_effect(e.pending.options[0]);one()
 expect(a.zone=="palette" and b.zone=="grave" and not a.tapped,"crystal exchanges cards and enters palette untapped")
 expect(e.source_resources(0).any(func(s):return s.uid==a.uid),"crystallized card can immediately supply its color")
 var table=Table.new();var visual=table.description(a,Vector3.ZERO)
 expect(is_zero_approx(visual.rotation.y) and not visual.tapped,"crystallized card renders upright and undimmed");table.free()
 fresh();a=put("1");b=put("164","palette");b.tapped=true;kill(a);e.choose_effect({});settle()
 expect(a.zone=="grave" and b.zone=="palette" and b.tapped,"declining crystal leaves both zones unchanged")
 fresh();a=put("1");b=put("164","palette");kill(a)
 expect(e.pending.no_legal_targets,"upright palette is not a legal crystal payment");e.choose_effect({});settle()
 expect(a.zone=="grave" and b.zone=="palette","crystal cannot exchange an upright palette card")
 fresh();a=put("1");b=put("164","palette");b.tapped=true;kill(a);e.choose_effect(e.pending.options[0]);e.move_to(a,"exile");one()
 expect(a.zone=="exile" and b.zone=="palette","crystal does not move a corpse that left the grave")
 fresh();a=put("1");b=put("164","palette");b.tapped=true;kill(a);e.choose_effect(e.pending.options[0]);b.tapped=false;one()
 expect(a.zone=="grave" and b.zone=="palette","crystal rechecks that the selected palette card is still tapped")
 fresh();a=put("15");kill(a);settle()
 expect(a.zone=="palette" and a.tapped,"Rumia's different explicitly tapped entry is unchanged")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"saved decks unchanged")
 print("V0182_RULES: %d checks; %d failures\n%s" % [checks,failures.size(),"\n".join(failures)])
 quit(0 if failures.is_empty() else 1)
