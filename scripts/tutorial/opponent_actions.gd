extends RefCounted
## Resolve declarative actions against current legal options and real payments.

static func prepare(adapter,action: Dictionary,seat: int=1) -> Dictionary:
 var e=adapter.engine
 var source={}
 if action.type=="cast":
  if not action.card.has("card_id"):source=adapter.resolve_card(action.card)
  else:
   for card in e.players[seat].hand:
    if card.card_id==action.card.card_id:source=card;break
  if source.is_empty() or source.owner!=seat:return skipped()
  if not e.cast_error(seat,source.uid).is_empty():return skipped()
  var options=e.targets_for(source.card_id,seat,source.uid)
  var info=e.cards[source.card_id]
  if info.kind!="符卡" and info.get("variable_cost","").is_empty() and source.card_id!="character-fdf-046":options=[{}]
  var selected=target(adapter,action.get("target",{}),options)
  if not selected.error.is_empty() or not selected.available:return selected
  var payment=e.payment(seat,e.cast_cost(seat,source,selected.target))
  if payment.ways==0:return skipped()
  return ready({"name":"commit_cast","args":[int(source.uid),selected.target,payment.plan]})
 source=adapter.resolve_card(action.source)
 if source.is_empty() or source.owner!=seat:return skipped()
 var options=[];var cost={};var excluded=[];var command={}
 if action.has("index"):
  var index=int(action.index);var bindings=e.cards[source.card_id].abilities
  if index>=bindings.size() or bindings[index].get("实现","")!="activated_damage":return invalid("index：指定来源没有该启动能力")
  if not e.activation_error(seat,source.uid,index).is_empty():return skipped()
  options=e.ability_targets()
  if e.ability_parameters(source.uid,index).get("横置",false):excluded=[int(source.uid)]
  command={"name":"commit_ability","args":[int(source.uid),index]}
 else:
  if source.zone!=e.extension_activation_zone(action.key):return skipped()
  var matches=e.available_actions(seat,source.uid,true).filter(func(item):return item.type=="extension" and item.get("key","")==action.key)
  if matches.is_empty():return invalid("key：指定来源没有该启动能力")
  if not matches[0].enabled:return skipped()
  options=e.activation_options(source,action.key)
  command={"name":"commit_extension","args":[int(source.uid)]}
 var selected=target(adapter,action.get("target",{}),options)
 if not selected.error.is_empty() or not selected.available:return selected
 cost=e.ability_cost(seat,source.uid,int(action.index),selected.target) if action.has("index") else e.extension_cost(seat,source,action.key,selected.target)
 var payment=e.payment(seat,cost,excluded)
 if payment.ways==0:return skipped()
 command.args.append_array([selected.target,payment.plan])
 if action.has("key"):command.args.append(action.key)
 return ready(command)

static func skipped() -> Dictionary:
 return {"command":{},"available":false,"error":""}

static func invalid(reason: String) -> Dictionary:
 return {"command":{},"available":false,"error":reason}

static func ready(command: Dictionary) -> Dictionary:
 return {"command":command,"available":true,"error":""}

static func selector(adapter,value: Dictionary) -> Dictionary:
 var resolved=value.duplicate(true)
 if value.has("alias") or value.has("created"):
  var card=adapter.resolve_card(value)
  if card.is_empty():return {"available":false}
  resolved.erase("alias");resolved.erase("created");resolved.merge(adapter.engine.ref_target(card))
 if value.has("stack"):
  var uid=int(adapter.resolve_card(value.stack).get("uid",-1))
  var entries=adapter.engine.unresolved_stack_entries().filter(func(entry):return entry.get("card",entry.get("source",{})).get("uid",-2)==uid)
  if entries.size()!=1:return {"available":false}
  resolved.erase("stack");resolved.stack_id=int(entries[0].id)
 for key in ["player","x"]:
  if resolved.has(key):resolved[key]=int(resolved[key])
 if value.has("sacrifice"):
  var result=selector(adapter,value.sacrifice)
  if not result.available:return result
  resolved.sacrifice=result.value
 if value.has("parts"):
  resolved.parts=[]
  for part in value.parts:
   var result=selector(adapter,part)
   if not result.available:return result
   resolved.parts.append(result.value)
 if value.has("picks"):
  resolved.picks=[]
  for group in value.picks:
   var selected=[]
   for item in group:
    var result=selector(adapter,item)
    if not result.available:return result
    selected.append(result.value)
   resolved.picks.append(selected)
 if value.has("payment"):
  var plan=preload("res://scripts/tutorial/battle_commands.gd").payment_plan(adapter,value.payment)
  if not plan.available:return {"available":false}
  resolved.payment=plan.value
 return {"available":true,"value":resolved}

static func matches(option: Dictionary,requested: Dictionary) -> bool:
 for key in requested:
  if not option.has(key):return false
  if requested[key] is Dictionary:
   if not option[key] is Dictionary or not matches(option[key],requested[key]):return false
  elif requested[key] is Array:
   if not option[key] is Array or option[key].size()!=requested[key].size():return false
   for i in range(requested[key].size()):
    if not option[key][i] is Dictionary or not requested[key][i] is Dictionary or not matches(option[key][i],requested[key][i]):return false
  elif option[key]!=requested[key]:return false
 return true

static func target(adapter,requested: Dictionary,options: Array) -> Dictionary:
 var resolved=selector(adapter,requested)
 if not resolved.available:return skipped()
 var wanted=resolved.value;var candidates=[]
 var extra_payment=wanted.get("payment",null);wanted.erase("payment")
 for option in options:
  var candidate=option.duplicate(true)
  if candidate.has("selection") and not wanted.has("picks"):continue
  # Omitted targets may only choose a targetless option, never another unit.
  if wanted.is_empty():
   if not candidate.is_empty() and not candidate.get("none",false):continue
  elif wanted=={"none":true} and candidate.is_empty():pass
  elif wanted.has("picks"):
   if not candidate.has("selection") or candidate.selection.size()!=wanted.picks.size():continue
   var metadata=wanted.duplicate(true);metadata.erase("picks")
   if not matches(candidate,metadata):continue
   var picked=[];var valid=true
   for i in range(wanted.picks.size()):
    var group=[]
    for item in wanted.picks[i]:
     var found=candidate.selection[i].pool.filter(func(entry):return matches(entry,item))
     if found.size()!=1:valid=false;break
     group.append(found[0].duplicate(true))
    if not valid:break
    picked.append(group)
   if not valid:continue
   candidate.erase("selection");candidate.picks=picked
   if not adapter.engine.Pack.choice_valid(adapter.engine,[option],candidate):continue
  elif not matches(candidate,wanted):continue
  if candidate not in candidates:candidates.append(candidate)
 if candidates.is_empty():return skipped()
 if candidates.size()>1:return invalid("target：目标存在多种选择，请指定 mode、x 或 selection_id")
 if extra_payment!=null:candidates[0].payment=extra_payment
 return {"command":{},"available":true,"error":"","target":candidates[0]}
