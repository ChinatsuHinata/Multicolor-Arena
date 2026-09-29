extends RefCounted
const State=preload("res://scripts/ai/simulation_state.gd")
const Action=preload("res://scripts/ai/action.gd")
const Value=preload("res://scripts/ai/position_evaluator.gd")
const Round=preload("res://scripts/ai/public_round.gd")
const Models=preload("res://scripts/ai/matchup_models.gd")
## Experimental agent for offline arenas and opt-in local tests. Profile is the fallback.
static func step(e,seat: int,tactics,weights: Dictionary={},opponent_round: bool=false) -> Dictionary:
 var routing=Models.select(e,seat,weights);weights=routing.weights
 routing.erase("weights")
 if e.phase!="main" or e.active!=seat or e.priority!=seat or not e.pending.is_empty() or not e.stack.is_empty() or not e.combat.is_empty():
  e.ai_step(seat);return {"fallback":true,"model_routing":routing}
 var target_policy=tactics.spell_target if e.ai_profiles[seat]==tactics.PROFILE else Round.opponent_target
 var actions=Action.main_candidates(e,seat,target_policy,24)
 if weights.has(Value.Strategic.KEYS[0]):
  # Load on use to avoid the engine/profile/agent preload cycle.
  var environment=load("res://scripts/ai/game_environment.gd").new();environment.setup(e)
  var allowed=environment.policy_actions().ids
  actions=environment.legal_actions().actions.filter(func(a):return a.id in allowed).map(func(a):return a.action)
 var best={};var best_score=-INF;var trace=[]
 for action in actions:
  if tactics.think_expired(e,seat):break
  var sim=State.fork(e,seat)
  if not Action.apply(sim,seat,action):continue
  if not tactics.settle_sim(sim,seat):continue
  var f=Value.strategic_features(sim,seat) if weights.has(Value.Strategic.KEYS[0]) else Value.features(sim,seat)
  var score=Value.value(sim,seat,weights);var complete=true
  if opponent_round and sim.winner==-2:
   var outlook=Round.rollout(sim,seat,tactics)
   complete=outlook.complete
   if complete:
    State.restore(sim,outlook.state);f=Value.strategic_features(sim,seat) if weights.has(Value.Strategic.KEYS[0]) else outlook.features;score=Value.value(sim,seat,weights)
  trace.append({"action":action.duplicate(true),"features":f,"score":score,"round_complete":complete})
  if complete and score>best_score:best_score=score;best=action
 if best.is_empty():
  if tactics.think_expired(e,seat):e.pass_priority(seat)
  else:e.ai_step(seat)
  return {"fallback":true,"candidates":trace,"model_routing":routing}
 var applied=Action.apply(e,seat,best)
 return {"fallback":false,"applied":applied,"action":best,"score":best_score,"candidates":trace,"model_routing":routing}
