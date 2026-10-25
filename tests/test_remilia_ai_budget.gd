extends "res://tests/support/rules_base.gd"
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")

func board(count: int,menace: bool=false):
 fresh()
 e.ai_profiles=[AI.PROFILE,""]
 e.ai_memory=[{},{}]
 e.cards["budget_unit"]=e.cards["164"].duplicate(true)
 e.cards.budget_unit.merge({"kind":"单位","title":"","character":"测试单位","race":[],"colors":["黄"],"cost":{},"abilities":[],"power":1,"health":3,"spirit":1,"keywords":[]},true)
 var leader=e.make_card(AI.REMILIA,0,"field",true)
 leader.entered_turns=0
 e.players[0].leader=leader
 e.players[0].field.append(leader)
 if menace:leader.modifiers=[{"威吓":true}]
 for i in range(count):put("budget_unit","field",1)
 return leader

func blocking_choice(count: int,menace: bool=false):
 board(0)
 e.players[0].leader.zone="leader"
 e.players[0].field=[]
 var attacker=put("budget_unit","field",1)
 if menace:attacker.modifiers=[{"威吓":true}]
 for i in range(count):put("budget_unit","field",0)
 e.active=1;e.priority=0
 e.combat={"attacker":e.ref_target(attacker),"owner":1,"blockers":[],"blocked":false,"step":"attack_window"}
 e.pending={"kind":"block","owner":0}
 return attacker

func run():
 var attacker=board(6)
 expect(AI.groups(e,attacker).size()==63,"ordinary six-unit boards retain every blocking combination")
 attacker.modifiers=[{"威吓":true}]
 expect(AI.groups(e,attacker).size()==57,"exact menace search excludes illegal single blockers")
 attacker=board(3)
 for c in e.units(1):c.modifiers=[{"攻击力":-1}]
 expect(AI.attack_allowed(e,attacker),"three harmless blockers still use the normal survival check")
 put("budget_unit","field",1).modifiers=[{"攻击力":-1}]
 expect(not AI.attack_allowed(e,attacker),"four legal blockers immediately keep ordinary small Remilia home")
 e.units(1).back().tapped=true
 expect(AI.attack_allowed(e,attacker),"tapped units do not count toward the four-blocker hold")
 e.units(1).back().tapped=false
 attacker.modifiers=[{"攻击力":4,"血量":4,"灵力":3,"歼灭":true}]
 e.players[1].night_lock=e.turn
 expect(AI.night_empowered(e,attacker) and AI.attack_allowed(e,attacker),"Night King empowerment ignores the four-blocker hold and uses actual combat safety")
 for count in [20,32,64,80]:
  attacker=board(count)
  var before=Time.get_ticks_msec()
  var candidates=AI.groups(e,attacker)
  var elapsed=Time.get_ticks_msec()-before
  print("BLOCK_GROUPS units=",count," candidates=",candidates.size()," elapsed_ms=",elapsed)
  expect(not candidates.is_empty() and candidates.size()<=AI.BLOCK_GROUP_LIMIT,"bounded candidates with "+str(count)+" blockers, including integer shift boundaries")
  expect(candidates.any(func(group):return group.size()==count),"full retaliation is included with "+str(count)+" blockers")
  expect(elapsed<2000,"dense blocker generation finishes without an exponential allocation")
  expect(not AI.attack_allowed(e,attacker),"sampled search never certifies protected Remilia as safe")
 attacker=board(32,true)
 expect(AI.groups(e,attacker).all(func(group):return group.size()>=2),"sampled menace groups also satisfy the two-blocker rule")

 # Both seats' inner combat work must honor the original caller's deadline.
 e.ai_memory[1]._think_deadline=Time.get_ticks_msec()-1
 var before=Time.get_ticks_msec()
 expect(AI.groups(e,attacker).is_empty(),"expired opposing-seat deadline stops blocker generation immediately")
 expect(AI.fatal_block_possible(e,attacker) and not AI.attack_allowed(e,attacker),"interrupted analysis is treated as unknown risk")
 expect(not AI.settle_sim(e,0) and not AI.settle_response(e),"expired simulations do not continue resolving new branches")
 expect(Time.get_ticks_msec()-before<250,"expired combat returns promptly")
 e.ai_memory[1].erase("_think_deadline")

 var outer=Time.get_ticks_msec()+5000
 e.ai_memory[0]._think_deadline=outer
 var previous=AI.push_think_deadline(e,0,Time.get_ticks_msec()+50)
 var inner=AI.think_deadline(e,0)
 var sim=AI.simulation(e,0)
 expect(inner<outer and AI.think_deadline(sim,0)==inner,"nested budgets reach isolated rule simulations")
 var nested=AI.push_think_deadline(e,0,outer+1000)
 expect(AI.think_deadline(e,0)==inner,"nested calls cannot extend a shorter budget")
 AI.restore_think_deadline(e,0,nested)
 AI.restore_think_deadline(e,0,previous)
 expect(AI.think_deadline(e,0)==outer,"nested budget restoration preserves the outer deadline")
 var expired=Time.get_ticks_msec()-1
 e.ai_memory[0]._think_deadline=expired
 expect(AI.pressure_action(e,0).is_empty() and AI.think_deadline(e,0)==expired,"expired pressure search returns without replacing the outer deadline")
 expect(AI.lethal_route(e,0).is_empty() and AI.think_deadline(e,0)==expired,"expired lethal search returns without replacing the outer deadline")

 attacker=board(80)
 var revision=e.revision
 before=Time.get_ticks_msec()
 AI.push_think_deadline(e,0,before+AI.MOBILE_THINK_LIMIT_MSEC)
 e.ai_step(0)
 var elapsed=Time.get_ticks_msec()-before
 print("DENSE_AI_STEP units=80 elapsed_ms=",elapsed)
 expect(elapsed<2000 and e.revision>revision,"live AI completes an action under the mobile-sized budget on an eighty-unit board")
 expect(e.combat.is_empty() and e.players[0].leader.zone=="field","dense-board fallback preserves small Remilia")

 attacker=board(80)
 put(AI.GUNGNIR,"hand")
 for id in ["165","168","165","168"]:put(id,"palette")
 before=Time.get_ticks_msec()
 AI.push_think_deadline(e,0,before+AI.MOBILE_THINK_LIMIT_MSEC)
 e.ai_step(0)
 elapsed=Time.get_ticks_msec()-before
 print("DENSE_AI_REMOVAL units=80 elapsed_ms=",elapsed)
 expect(elapsed<2000,"dense removal scoring and sorting obey the mobile-sized budget")

 attacker=blocking_choice(80)
 before=Time.get_ticks_msec()
 AI.push_think_deadline(e,0,before+AI.MOBILE_THINK_LIMIT_MSEC)
 var blocks=AI.defensive_blocks(e)
 elapsed=Time.get_ticks_msec()-before
 print("DENSE_AI_DEFENSE units=80 elapsed_ms=",elapsed)
 expect(elapsed<2000,"dense defense stops evaluating combat under the mobile-sized budget")
 e.block(blocks)
 expect(e.pending.get("kind","")!="block","dense defense submits a legal choice after the preview ends")

 board(0)
 var calls=[]
 var sorted=AI.sorted_by(e,[3,1,2],func(value):calls.append(value);return value)
 expect(sorted==[1,2,3] and calls.size()==3,"sorting scores each candidate exactly once")
 calls=[]
 sorted=AI.sorted_by(e,[3,1,2],func(value):
  calls.append(value)
  e.ai_memory[0]._think_deadline=Time.get_ticks_msec()-1
  return value)
 expect(sorted.is_empty() and calls.size()==1,"sorting stops between expensive rule queries when the budget expires")

 for menace in [false,true]:
  attacker=blocking_choice(32,menace)
  e.ai_memory[0]._think_deadline=Time.get_ticks_msec()-1
  e.ai_step(0)
  expect(e.pending.get("kind","")!="block","expired live AI still submits a legal blocking choice")
  expect(e.combat.blockers.size()==(2 if menace else 1),"timeout fallback obeys the blocker's minimum count")

 print("Remilia AI budget: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
