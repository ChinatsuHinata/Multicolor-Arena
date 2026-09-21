extends RefCounted
## Test-only policy operating exclusively on the seat projection and command facade.
static func step(e,who: int):
 if e.winner!=-2:return
 if e.phase=="mulligan":
  if not e.players[who].mulligan_done:e.mulligan(who,[])
  return
 if not e.pending.is_empty():
  if e.pending.owner!=who:return
  match e.pending.kind:
   "trigger_order":e.choose_trigger_order(0)
   "grave_replacement":e.choose_grave_replacement(true)
   "effect_choice":
    var target=e.Pack.ai_target(e,who,e.pending.options,e.pending.trigger.get("effect",""))
    if e.pending.trigger.effect=="cat:grant":
     if e.pending.trigger.data.get("free",false) and not e.pending.trigger.data.get("payment_chosen",false):e.set_granted_payment(false)
     target=e.Pack.ai_target(e,who,e.pending.options,e.pending.trigger.effect)
     var cost=e.Cat.granted_cost(e,e.pending.trigger,target);var payment=e.payment(who,cost)
     if payment.ways>0:target.payment=payment.plan
    elif e.pending.trigger.effect=="cat:trigger_pay" and target.get("pay",false):target.payment=e.payment(who,e.pending.trigger.data.cost).plan
    e.choose_effect(target)
   "timer":e.choose_timer(0)
   "possession":e.possession()
   "leader_return":e.choose_return(true)
   "discard":e.discard(e.players[who].hand.slice(0,e.pending.count).map(func(c):return c.uid))
   "trigger":e.choose_trigger(e.pending.options[0] if not e.pending.options.is_empty() else {})
   "block":
    var blockers=e.legal_blockers();var chosen=[]
    if not blockers.is_empty():
     chosen=[blockers[0].uid]
     if e.Extra.keyword(e,e.find_card(e.combat.attacker.uid),"威吓"):
      if blockers.size()>1:chosen.append(blockers[1].uid)
      else:chosen=[]
    e.block(chosen)
   "damage_assignment":
    var allocation={};var left=e.pending.total
    for t in e.combat.blockers:
     var c=e.find_card(t.uid);var amount=mini(left,maxi(0,e.stat(c,"health")-c.damage));allocation[str(t.uid)]=amount;left-=amount
    if left>0:allocation[str(e.combat.blockers[0].uid)]+=left
    e.combat_damage(allocation)
  return
 if e.priority!=who:return
 var choices=e.legal_casts(who)
 choices.sort_custom(func(a,b):return e.ai_card_score(a)>e.ai_card_score(b))
 for c in choices:
  var options=e.targets_for(c.card_id,who,c.uid)
  if not e.stack.is_empty() and e.stack.back().owner==who:continue
  var target=e.Pack.ai_target(e,who,options) if not options.is_empty() else {}
  if e.cards[c.card_id].kind=="符卡" and target.is_empty():continue
  var payment=e.payment(who,e.cast_cost(who,c,target))
  if payment.ways>0:
   e.commit_cast(who,c.uid,target,payment.plan);return
 if e.active==who and e.phase=="main" and e.stack.is_empty() and e.combat.is_empty():
  for c in e.units(who):
   if e.can_attack(who,c.uid):e.attack(who,c.uid,{},e.payment(who,e.attack_cost(who)).plan);return
 e.pass_priority(who)
