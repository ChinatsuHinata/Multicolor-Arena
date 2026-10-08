extends RefCounted
## Basic opponent responses use the same legal choices and gateway as the UI.
const Blocks=preload("res://scripts/tutorial/block_priorities.gd")

static func command(adapter) -> Dictionary:
 var e=adapter.engine
 if e==null or e.winner!=-2:return {}
 if e.phase=="mulligan":
  return {"name":"mulligan","args":[[]]} if not e.players[1].mulligan_done else {}
 if not e.pending.is_empty():
  var p=e.pending
  if int(p.get("owner",-1))!=1:return {}
  match p.kind:
   "reveal_review":return {"name":"confirm_revealed","args":[int(p.serial)]}
   "block":
    var uids=[]
    if e.must_block():
     var prepared=Blocks.prepare(adapter,[{"strategy":"largest"},{"strategy":"all"}])
     if not prepared.available:return {}
     uids=prepared.uids
    return {"name":"block","args":[uids]}
   "possession":return {"name":"possession","args":[-1,-1]}
   "discard":return {"name":"discard","args":[e.players[1].hand.slice(0,int(p.count)).map(func(card):return int(card.uid))]}
   "trigger_order":return {"name":"choose_trigger_order","args":[0]}
   "ward_order":return {"name":"choose_ward","args":[int(p.options[0])]}
   "leader_return":return {"name":"choose_return","args":[true]}
   "grave_replacement":return {"name":"choose_grave_replacement","args":[true]}
   "timer":return {"name":"choose_timer","args":[0]}
   "trigger","effect_choice":
    var target={} if p.kind=="trigger" and p.trigger.get("optional",true) else e.Pack.ai_target(e,1,p.options,p.trigger.get("effect",""))
    return {"name":"choose_trigger" if p.kind=="trigger" else "choose_effect","args":[target]}
   "damage_assignment":
    var attacker=e.find_card(e.combat.attacker.uid)
    var blockers=e.combat.blockers.map(func(ref):return e.find_card(ref.uid))
    return {"name":"combat_damage","args":[e.RemiliaAI.damage_allocation(e,attacker,blockers,int(p.total))]}
  return {}
 if e.priority!=1 or not e.entry_choices.is_empty():return {}
 if e.tutorial_turn_end_blocked and e.phase=="main" and e.stack.is_empty() and e.combat.is_empty():return {}
 return {"name":"pass_priority","args":[]}

static func tick(adapter) -> String:
 var move=command(adapter)
 if move.is_empty():return ""
 var reason=adapter.submit(1,move)
 return "" if reason.is_empty() else "opponent.auto_response.%s：%s" % [move.name,reason]
