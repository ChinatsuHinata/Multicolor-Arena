extends "res://tests/support/rules_base.gd"

func advance_pair():
 e.pass_priority(e.priority);e.pass_priority(e.priority)

func consume_death_triggers(yuyuko: Dictionary,count: int):
 for i in range(count):
  var other=put("53")
  e.destroy(other);e.pump_choices()
  expect(e.pending.get("trigger",{}).get("effect","")=="leader_death_damage","earlier unit death actually offers Yuyuko's ability")
  if e.pending.get("trigger",{}).get("effect","")!="leader_death_damage":return
  e.choose_effect({"player":1});advance_pair()
  expect(e.usage_count(yuyuko.uid,"death_ping")==i+1,"earlier announced ability counts toward its turn limit")

func case_death(used: int):
 fresh()
 var yuyuko=put("71")
 yuyuko.leader=true;yuyuko.original_owner=0;e.players[0].leader=yuyuko
 var momoyo=put("43","field",1)
 e.apply_turn_buff(e.ref_target(yuyuko),{"攻击力":2,"血量":2})
 e.combat_hit(momoyo,e.ref_target(yuyuko),2)
 expect(e.stat(yuyuko,"health")==2 and yuyuko.get("minus_counters",0)==2,"Momoyo's counters leave buffed Yuyuko alive")
 consume_death_triggers(yuyuko,used)
 e.phase="end";e.priority=0;e.passes=0
 var old_turn=e.turn
 advance_pair()
 expect(e.turn==old_turn and e.phase=="end","cleanup death is processed in the original end phase")
 expect(e.pending.get("kind","")=="leader_return","dying leader asks about its ordinary return")
 if e.pending.get("kind","")!="leader_return":return
 e.choose_return(false)
 if used==1:
  expect(e.turn==old_turn and e.pending.get("trigger",{}).get("effect","")=="leader_death_damage","remaining once-per-turn trigger is offered before the next turn")
  if e.pending.get("trigger",{}).get("effect","")!="leader_death_damage":return
  e.choose_effect({"player":1})
  expect(e.usage_count(yuyuko.uid,"death_ping")==2 and e.stack.size()==1,"accepting cleanup trigger consumes the second use")
  var life=e.players[1].life
  advance_pair()
  expect(e.players[1].life==life-1 and e.phase=="end" and e.turn==old_turn,"cleanup trigger resolves before end phase priority is asked again")
  var survivor=put("53")
  e.apply_turn_buff(e.ref_target(survivor),{"攻击力":2,"血量":2})
  advance_pair()
  expect(e.turn==old_turn+1 and e.active==1 and survivor.modifiers.is_empty(),"both players pass again and new temporary effects are cleaned up")
 else:
  expect(e.stack.is_empty() and e.triggers.is_empty() and e.pending.is_empty(),"exhausted ability never enters the stack")
  expect(e.turn==old_turn and e.phase=="end","after leader return both players receive end phase priority again")
  advance_pair()
  expect(e.turn==old_turn+1 and e.active==1,"turn ends after the renewed priority window")

func case_no_return(used: int):
 fresh()
 var yuyuko=put("71");yuyuko.leader_counters=1
 var momoyo=put("43","field",1)
 e.apply_turn_buff(e.ref_target(yuyuko),{"攻击力":2,"血量":2})
 e.combat_hit(momoyo,e.ref_target(yuyuko),2)
 consume_death_triggers(yuyuko,used)
 e.phase="end";e.priority=0;var old_turn=e.turn
 advance_pair()
 if used==2:
  expect(e.turn==old_turn+1 and e.active==1 and e.stack.is_empty(),"exhausted ability without a return choice does not interrupt cleanup")
 else:
  expect(e.turn==old_turn and e.phase=="end" and e.pending.get("trigger",{}).get("effect","")=="leader_death_damage","cleanup death with one use remaining interrupts before the next turn")
  e.choose_effect({})
  expect(e.priority==e.active and e.passes==0,"declining the optional ability restores active player's priority")
  advance_pair()
  expect(e.turn==old_turn+1 and e.active==1,"declined ability still requires both players to pass")

func cleanup_during_resolution():
 fresh()
 var yuyuko=put("71");yuyuko.leader=true;yuyuko.original_owner=0;e.players[0].leader=yuyuko
 var momoyo=put("43","field",1)
 e.apply_turn_buff(e.ref_target(yuyuko),{"攻击力":2,"血量":2})
 e.combat_hit(momoyo,e.ref_target(yuyuko),2)
 consume_death_triggers(yuyuko,2)
 e.phase="end";var original_turn=e.turn;e.reveal_resolution_depth=1
 e.cleanup_end()
 expect(e.turn==original_turn and e.phase=="end" and not e.returns.is_empty(),"cleanup inside another resolution waits for queued leader return")
 e.reveal_resolution_depth=0;e.pump_choices()
 expect(e.pending.get("kind","")=="leader_return" and e.turn==original_turn,"queued return is offered in the original turn after resolution")
 e.choose_return(false);advance_pair()
 expect(e.turn==original_turn+1,"original turn ends only after the return and priority window")

func run():
 case_death(1);case_death(2);case_no_return(1);case_no_return(2);cleanup_during_resolution()
 fresh()
 var unit=put("53");unit.damage=1
 e.phase="end";e.priority=0
 var old_turn=e.turn
 advance_pair()
 expect(unit.zone=="field" and unit.damage==0 and e.turn==old_turn+1,"ordinary marked damage clears without creating a spurious death")
 print("END CLEANUP TRIGGERS: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
