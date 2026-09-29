extends RefCounted
## Bounded search independent of deck tactics; existing profile supplies callbacks.
static func select(e,who: int,tactics,deadline: int=-1) -> Dictionary:
 if deadline>=0 and Time.get_ticks_msec()>=deadline:return {}
 if e.players[who].palette.size()<6 or e.players[who].leader.zone=="grave":return {}
 var memory=e.ai_memory[who];var plan=memory.get("pressure_plan",[])
 if not plan.is_empty():
  if plan[0].expected==tactics.position_key(e,who) and (plan[0].kind!="attack" or tactics.attack_allowed(e,e.find_card(plan[0].uid))):return plan.pop_front()
  memory.erase("pressure_plan")
 var sim=tactics.simulation(e,who);var start=tactics.capture_sim(sim);var night_risk=tactics.night_priority(e,who)
 var life=e.players[1-who].life;var own_life=e.players[who].life
 deadline=mini(deadline,Time.get_ticks_msec()+tactics.PRESSURE_MSEC) if deadline>=0 else Time.get_ticks_msec()+tactics.PRESSURE_MSEC
 var best=tactics.pressure_evaluate(sim,who,[],life,own_life,night_risk)
 # Reach the deck's cheap aura + four-haste-body combination before spending
 # the budget on the next-round outlook of every standalone expensive body.
 if e.players[who].hand.any(func(c):return c.card_id==tactics.CASTLE) and e.players[who].hand.any(func(c):return c.card_id==tactics.QUEEN):
  tactics.restore_sim(sim,start)
  var seed=[]
  for id in [tactics.CASTLE,tactics.QUEEN]:
   if Time.get_ticks_msec()>=deadline:break
   var offered=sim.legal_casts(who).filter(func(c):return c.card_id==id)
   if offered.is_empty() or id==tactics.QUEEN and sim.Cat.field_limit(sim,who)-sim.field_slots(who)<4:break
   var action={"kind":"cast","uid":offered[0].uid,"card_id":id,"target":{"none":true},"expected":tactics.position_key(sim,who)}
   if not tactics.pressure_execute(sim,who,action) or not tactics.settle_sim(sim,who):break
   seed.append(action)
  if seed.size()==2:
   var value=tactics.pressure_evaluate(sim,who,seed,life,own_life,night_risk)
   if value.score>best.score:best=value
 var frontier=[{"state":start,"route":[],"score":best.score}];var seen={}
 for depth in range(tactics.PRESSURE_DEPTH):
  var next=[]
  for node in frontier:
   if Time.get_ticks_msec()>=deadline:break
   tactics.restore_sim(sim,node.state)
   var actions=tactics.search_actions(sim,who).filter(func(a):return a.kind=="cast")
   actions.sort_custom(func(a,b):return tactics.card_priority(sim,who,sim.find_card(a.uid))>tactics.card_priority(sim,who,sim.find_card(b.uid)))
   for original in actions:
    if Time.get_ticks_msec()>=deadline:break
    tactics.restore_sim(sim,node.state)
    var action=original.duplicate(true);action.expected=tactics.position_key(sim,who)
    if not tactics.pressure_execute(sim,who,action) or not tactics.settle_sim(sim,who):continue
    var key=tactics.position_key(sim,who)
    if seen.has(key):continue
    seen[key]=true
    var route=node.route+[action];var state=tactics.capture_sim(sim)
    var value=tactics.pressure_evaluate(sim,who,route,life,own_life,night_risk)
    if value.score>best.score or value.score==best.score and value.route.size()<best.route.size():best=value
    next.append({"state":state,"route":route,"score":value.score})
  next.sort_custom(func(a,b):return a.score>b.score)
  frontier=next.slice(0,tactics.PRESSURE_WIDTH)
  if frontier.is_empty() or Time.get_ticks_msec()>=deadline:break
 memory.last_pressure_trace={"score":best.score,"route_size":best.route.size(),"planner":"beam"}
 if best.route.is_empty():return {}
 memory.pressure_plan=best.route
 return memory.pressure_plan.pop_front()
