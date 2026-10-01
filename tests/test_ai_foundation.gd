extends "res://tests/support/rules_base.gd"
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")
const Observation=preload("res://scripts/ai/observation.gd")
const State=preload("res://scripts/ai/simulation_state.gd")
const Action=preload("res://scripts/ai/action.gd")
const Value=preload("res://scripts/ai/position_evaluator.gd")
const Round=preload("res://scripts/ai/public_round.gd")
const Agent=preload("res://scripts/ai/decision_agent.gd")
func run():
 fresh()
 var hidden=put("18","hand",1);var own=put("129","hand")
 var before=JSON.stringify([e.players,e.stack,e.pending,e.revision,e.ai_memory])
 var view=Observation.build(e,0)
 expect(view.players[1].hand.is_empty() and view.players[1].hand_count==1,"observation hides unknown opposing identities but retains counts")
 expect(not view.players[0].has("deck") and not view.players[1].has("deck"),"observation never includes either deck order")
 expect(JSON.stringify([e.players,e.stack,e.pending,e.revision,e.ai_memory])==before,"observation leaves live state unchanged")
 e.reveal_card(hidden)
 expect(Observation.build(e,0).players[1].hand[0].card_id=="18","publicly revealed hand identity is observable")
 hidden.epoch+=1
 expect(Observation.known_hand(e,0).is_empty(),"stale reveal epoch cannot expose a new hidden identity")
 e.players[0].leader=e.make_card(AI.REMILIA,0,"field",true);e.players[0].field.append(e.players[0].leader)
 e.ai_memory[0].leader_died=true;e.ai_memory[0].death_turns=2;e.ai_memory[0].pressure_plan=[{"kind":"pass"}]
 var rng_state=e.rng.state;var sim=State.fork(e,0)
 expect(is_same(sim.players[0].leader,sim.players[0].field.back()),"fork preserves leader and battlefield alias")
 expect(sim.ai_memory[0].leader_died and sim.ai_memory[0].death_turns==2,"fork retains tactical recovery memory")
 expect(not sim.ai_memory[0].has("pressure_plan"),"fork removes stale search plans")
 expect(sim.players[1].hand[0].ai_unknown and sim.players[1].hand[0].card_id=="164","fork masks unknown cards")
 expect(not Action.apply(sim,1,{"kind":"cast","uid":hidden.uid,"target":{"none":true}}),"masked unknown card cannot become a playable guessed card")
 sim.players[0].leader.damage=1
 expect(e.players[0].leader.damage==0 and e.rng.state==rng_state,"simulation cannot mutate live cards or random state")
 fresh();put("165","palette");put("168","palette");own=put(AI.WINGS,"hand")
 expect(Action.apply(e,0,{"kind":"cast","uid":own.uid,"target":{"none":true}}),"shared action executes a real paid cast")
 expect(e.players[0].palette.all(func(c):return c.tapped),"shared action consumes actual resources")
 settle()
 var candidates=Action.main_candidates(e,0,AI.spell_target)
 expect(candidates.any(func(a):return a.kind=="pass"),"holding resources remains a legal candidate")
 var f=Value.features(e,0)
 expect(Value.score_features(f)==Value.value(e,0),"feature scoring and runtime evaluator agree")
 e.winner=0
 expect(Value.value(e,0)>999000 and Value.value(e,1)<-999000,"terminal outcome dominates material")
 fresh();e.players[1].hand=[]
 var live=JSON.stringify([e.players,e.turn,e.revision,e.pending])
 var outlook=Round.rollout(e,0,AI)
 expect(outlook.complete and outlook.reason=="next_main","round model advances opponent turn and returns to own main")
 expect(JSON.stringify([e.players,e.turn,e.revision,e.pending])==live,"round model does not advance live gameplay")
 var limit=Round.rollout(e,0,AI,1)
 expect(not limit.complete and limit.reason=="step_limit","exhausted rollout budget is explicitly incomplete")
 var agent=Agent.step(e,0,AI)
 expect(agent.has("action") or agent.get("fallback",false),"experimental decision agent returns an action or explicit fallback")
 # Counterfactual public sweep uses the real ETO ability and choice menu.
 fresh();e.players[0].leader=e.make_card(AI.REMILIA,0,"leader",true)
 e.players[1].leader=e.make_card("new-eto-001",1,"leader",true)
 var double=e.make_card("new-eto-002",1,"field",true);e.players[1].extra_leaders=[double];e.players[1].field.append(double)
 put("new-eto-s001","field",1);put("18","field")
 e.Roster.New.event(e,double,"ETO-002",true);e.pump_choices()
 expect(e.pending.get("kind","")=="effect_choice","public double entry exposes a real pending choice")
 if e.pending.get("kind","")=="effect_choice":
  var chosen=Round.effect_choice(e,1,e.pending.options,e.pending.trigger)
  expect(chosen.get("x",0)==1,"public opponent compares bead counts and selects a useful sweep")
 fresh();e.active=1;e.priority=1;e.players[0].life=1
 var attacker=put(AI.REMILIA,"field",1);var blocker=put("18","field",0)
 e.combat={"attacker":e.ref_target(attacker)}
 expect(blocker.uid in Round.survival_blocks(e,0,AI),"public rollout chump blocks to prevent lethal even when blocker dies")
 fresh();e.ai_profiles[0]=AI.PROFILE;e.ai_memory[0].decision_mode="public_round"
 var revision=e.revision
 e.ai_step(0)
 expect(e.revision>revision and e.ai_memory[0].decision_mode=="public_round","opt-in runtime advances state and restores mode without recursive fallback")
 print("AI foundation: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
