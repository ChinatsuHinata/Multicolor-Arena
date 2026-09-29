extends RefCounted
const State=preload("res://scripts/ai/simulation_state.gd")
const Action=preload("res://scripts/ai/action.gd")
const Value=preload("res://scripts/ai/position_evaluator.gd")
## A bounded public-information opponent policy, not an optimal adversary.
## Advances actual phases, triggers, combat and returns. Unknown cards stay unknown.
static func rollout(e,who: int,tactics,max_steps: int=160) -> Dictionary:
 var sim=State.fork(e,who)
 # Neutral placeholders carry no colors, abilities or playable actions. Future
 # unknown draws therefore change counts but never invent a useful known card.
 sim.cards["ai_unknown"]=sim.cards["164"].duplicate(true)
 sim.cards.ai_unknown.merge({"name":"未知牌","colors":[],"color":"","cost":{},"abilities":[],"keywords":[],"power":0,"health":0,"spirit":0,"title":"","character":"","requires_character":""},true)
 for p in sim.players:
  for zone in ["deck","hand","palette"]:
   for c in p[zone]:
    if c.get("ai_unknown",false):c.card_id="ai_unknown"
 var enemy_seen=false
 for i in range(max_steps):
  if tactics.think_expired(sim,who):return result(sim,who,false,i,"time_limit")
  if sim.winner!=-2:return result(sim,who,true,i,"terminal")
  sim.pump_choices()
  if sim.active==1-who:enemy_seen=true
  if enemy_seen and sim.active==who and sim.phase=="main" and sim.pending.is_empty() and sim.stack.is_empty() and sim.combat.is_empty():return result(sim,who,true,i,"next_main")
  var before=sim.revision
  if not sim.pending.is_empty():
   if not choice(sim,who,tactics):return result(sim,who,false,i,"unsupported_choice:"+str(sim.pending.get("kind","")))
  elif not sim.stack.is_empty() or not sim.combat.is_empty():sim.pass_priority(sim.priority)
  elif sim.active==1-who and sim.phase=="main" and sim.priority==1-who:
   if not opponent_action(sim,1-who,tactics.think_deadline(sim,who)):sim.pass_priority(sim.priority)
  else:sim.pass_priority(sim.priority)
  if sim.revision==before:return result(sim,who,false,i,"no_progress")
 return result(sim,who,false,max_steps,"step_limit")

static func result(e,who: int,complete: bool,steps: int,reason: String) -> Dictionary:
 return {"complete":complete,"steps":steps,"reason":reason,"winner":e.winner,"features":Value.features(e,who),"value":Value.value(e,who),"state":State.capture(e)}

static func choice(e,who: int,tactics) -> bool:
 var p=e.pending;var seat=p.owner
 match p.kind:
  "possession":e.possession()
  "effect_choice":
   var target=tactics.effect_target(e,seat,p.options,p.trigger) if seat==who else effect_choice(e,seat,p.options,p.trigger)
   e.choose_effect(target)
  "block":
   if seat==who:e.block(survival_blocks(e,seat,tactics))
   else:e.block(tactics.simulated_blocks(e,who))
  "damage_assignment":
   var a=e.find_card(e.combat.attacker.uid)
   e.combat_damage(tactics.damage_allocation(e,a,e.combat.blockers.map(func(t):return e.find_card(t.uid)),p.total))
  "trigger_order":e.choose_trigger_order(0)
  "leader_return":e.choose_return(p.card.get("return_destination","")!="hand")
  "timer":e.choose_timer(0)
  "grave_replacement":e.choose_grave_replacement(true)
  "ward_order":e.choose_ward(p.options[0])
  "discard":e.discard(e.players[seat].hand.slice(0,p.count).map(func(c):return c.uid))
  "trigger":e.choose_trigger(e.Pack.ai_target(e,seat,p.options))
  _:return false
 return true

static func survival_blocks(e,seat: int,tactics) -> Array:
 var attacker=e.find_card(e.combat.attacker.uid)
 var candidates=[[]]
 candidates.append_array(tactics.groups(e,attacker))
 var best=[];var best_score=-INF
 for group in candidates:
  var outcome=tactics.fight(e,attacker,group)
  var damage=e.stat(attacker,"spirit") if group.is_empty() or e.Extra.keyword(e,attacker,"歼灭") and not outcome.dead.is_empty() else 0
  var score=-float(damage)*20.0
  if damage>=e.players[seat].life:score-=1000000.0
  for c in group:
   if c.uid in outcome.dead:score-=float(e.Extra.cost_value(e,c))*8.0+float(e.stat(c,"spirit"))*4.0
  if outcome.attacker_dead:score+=float(e.Extra.cost_value(e,attacker))*8.0
  if score>best_score:best_score=score;best=group.map(func(c):return c.uid)
 return best

static func effect_choice(e,seat: int,options: Array,trigger: Dictionary) -> Dictionary:
 # ETO-002 is public: compare every legal bead count including the opponent's
 # own casualties, rather than assigning its first (zero-damage) option.
 if trigger.get("effect","")=="n21:ETO-002":
  var best={};var score=-INF
  var before=State.capture(e)
  for option in options:
   var sim=e.get_script().new(e.cards);State.restore(sim,before)
   sim.choose_effect(option)
   # The selected ability is now announced; resolve this one entry and the
   # resulting automatic deaths, without guessing future opposing choices.
   for i in range(16):
    sim.pump_choices()
    if not sim.pending.is_empty():
     if sim.pending.kind=="leader_return":sim.choose_return(true)
     elif sim.pending.kind=="trigger_order":sim.choose_trigger_order(0)
     else:break
    elif not sim.stack.is_empty():sim.pass_priority(sim.priority)
    else:break
   var value=Value.value(sim,seat)
   if value>score:score=value;best=option
  return best
 return e.Pack.ai_target(e,seat,options,trigger.get("effect",""))

static func opponent_target(e,seat: int,c: Dictionary) -> Dictionary:
 if e.is_unit(c):return {"none":true}
 return e.ai_spell_target(seat,c)

static func opponent_action(e,seat: int,deadline: int=-1) -> bool:
 var candidates=Action.main_candidates(e,seat,opponent_target,16)
 var before=State.capture(e);var best={};var score=Value.value(e,seat)
 for action in candidates:
  if deadline>=0 and Time.get_ticks_msec()>=deadline:break
  if action.kind=="pass":continue
  var sim=e.get_script().new(e.cards);State.restore(sim,before)
  if not Action.apply(sim,seat,action):continue
  var timed_out=false
  for i in range(48):
   if deadline>=0 and Time.get_ticks_msec()>=deadline:timed_out=true;break
   sim.pump_choices()
   if not sim.pending.is_empty():
    if sim.pending.kind=="effect_choice":sim.choose_effect(effect_choice(sim,sim.pending.owner,sim.pending.options,sim.pending.trigger))
    elif sim.pending.kind=="leader_return":sim.choose_return(true)
    elif sim.pending.kind=="trigger_order":sim.choose_trigger_order(0)
    elif sim.pending.kind=="block":sim.block([])
    elif sim.pending.kind=="timer":sim.choose_timer(0)
    else:break
   elif not sim.stack.is_empty() or not sim.combat.is_empty():sim.pass_priority(sim.priority)
   else:break
  if timed_out:break
  var value=Value.value(sim,seat)
  if value>score:score=value;best=action
 return not best.is_empty() and Action.apply(e,seat,best)
