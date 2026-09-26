extends "res://tests/support/rules_base.gd"
const Pack=preload("res://scripts/rules/precon_abilities.gd")
const Picker=preload("res://scripts/target_picker.gd")
func settle():
 for i in range(160):
  if e.winner!=-2: return
  e.pump_choices()
  if not e.pending.is_empty():
   match e.pending.kind:
    "trigger_order": e.choose_trigger_order(0)
    "effect_choice": e.choose_effect(Pack.ai_target(e,e.pending.owner,e.pending.options,e.pending.trigger.effect))
    "leader_return": e.choose_return(false)
    "trigger": e.choose_trigger({})
    "timer": e.choose_timer(0)
    _: return
  elif not e.stack.is_empty(): one()
  else: return
 expect(false,"settlement finished without looping")
func selected(options: Array,picks: Array,index: int=0) -> Dictionary:
 return {"selection_id":options[index].selection_id,"picks":picks}
func trigger(c: Dictionary,key: String,target: Dictionary={"none":true},data: Dictionary={}):
 Pack.resolve_trigger(e,{"precon":true,"source":c.duplicate(true),"effect":key,"owner":c.owner,"target":target,"data":data,"optional":false})
func cast_new(id: String,target: Dictionary={}) -> Dictionary:
 var c=put(id,"hand"); var options=e.targets_for(id,0)
 if target.is_empty(): target=Pack.ai_target(e,0,options,Pack.key(e.cards[id],Pack.SPELLS)) if not options.is_empty() else {}
 var error=e.commit_cast(0,c.uid,target,e.payment(0,e.cast_cost(0,c,target)).plan)
 expect(error.is_empty(),"cast "+id+" "+error)
 settle(); e.priority=0
 return c
func activate(c: Dictionary,t: Dictionary):
 var k=e.Extra.activation_kind(e.cards[c.card_id]); e.priority=c.owner
 var error=e.commit_extension(c.owner,c.uid,t,e.payment(c.owner,e.Extra.activation_cost(k)).plan)
 expect(error.is_empty(),"activate "+k+" "+error); settle(); e.priority=0
func spell_context(c: Dictionary,single: bool=true): e.damage_context={"source":c,"single":single,"combat":false}
