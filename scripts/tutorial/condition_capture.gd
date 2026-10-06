extends RefCounted
## Translate observed state and accepted actions into existing schema predicates.
const Adapter=preload("res://scripts/tutorial/game_adapter.gd")

static func context(adapter) -> Dictionary:
 var e=adapter.engine
 var items=[{"type":"phase","value":e.phase},{"type":"combat_step","value":e.combat.get("step","none")}]
 if e.pending.is_empty():items.append({"type":"priority","value":int(e.priority)})
 else:items.append({"type":"pending","owner":int(e.pending.owner),"kind":e.pending.kind})
 return {"type":"all","conditions":items}

static func sample(c: Dictionary,adapter) -> Dictionary:
 var value=c.duplicate(true);var e=adapter.engine
 var card=adapter.resolve_card(c)
 match c.get("type"):
  "life":value.value=int(e.players[int(c.player)].life)
  "priority":value.value=int(e.priority)
  "phase":value.value=e.phase
  "combat_step":value.value=e.combat.get("step","none")
  "pending":
   if e.pending.is_empty():return {}
   value.owner=int(e.pending.owner);value.kind=e.pending.kind
  "player_count":value.value=int(e.players[int(c.player)].get(c.key,0))
  "entity_zone":
   if card.is_empty():return {}
   value.zone=card.zone
  "entity_state","entity_count":
   if card.is_empty():return {}
   value.value=card.get(c.key,false) if c.type=="entity_state" else int(card.get(c.key,0))
  "entity_color_counter":
   if card.is_empty():return {}
   if c.color not in card.get("color_counters",[]):return {"type":"not","condition":value}
  "zone_count":
   var ids=e.players[int(c.player)].get(c.zone,[])
   if c.has("card_id"):ids=ids.filter(func(item):return item.card_id==c.card_id)
   if c.has("kind"):ids=ids.filter(func(item):return e.cards[item.card_id].kind==c.kind)
   value.value=ids.size()
  _:return {}
 return value

static func candidates(recorder,focused: Dictionary) -> Array:
 var result=[];var origin=Adapter.new();origin.restore(recorder.points[0].adapter)
 for item in recorder.victory_candidates():
  var c=item.condition
  if c.type=="life" and origin.engine.players[int(c.player)].life==recorder.adapter.engine.players[int(c.player)].life:continue
  result.append(item.duplicate(true))
 var current=sample(focused,recorder.adapter)
 if not current.is_empty() and not result.any(func(item):return item.condition==current):
  result.append({"label":"当前选中条件的实际值","selected":true,"condition":current})
 for item in result:item.selected=not current.is_empty() and item.condition==current
 var before=origin.engine;var after=recorder.adapter.engine
 if before.phase!=after.phase:result.append({"label":"当前阶段","selected":false,"condition":{"type":"phase","value":after.phase}})
 if before.priority!=after.priority:result.append({"label":"当前执行权","selected":false,"condition":{"type":"priority","value":int(after.priority)}})
 if before.combat.get("step","none")!=after.combat.get("step","none"):result.append({"label":"战斗响应时点","selected":false,"condition":{"type":"combat_step","value":after.combat.get("step","none")}})
 if not after.pending.is_empty() and before.pending!=after.pending:result.append({"label":"正在等待的选择","selected":false,"condition":{"type":"pending","kind":after.pending.kind,"owner":int(after.pending.owner)}})
 return result

static func trigger(recorder,index: int,existing: Dictionary) -> Dictionary:
 if index<0 or index>=recorder.actions.size() or recorder.actions[index].type=="delay":return {}
 var rule=existing.duplicate(true)
 rule.event="command_accepted";rule.on_action=recorder.actions[index].duplicate(true);rule.on_action.erase("payment")
 var state=Adapter.new();state.restore(recorder.points[index+1].adapter);rule.when=context(state)
 var first=index+1;var last=first-1
 while last+1<recorder.actions.size() and recorder.actions[last+1].get("player")==1:last+=1
 if last>=first:
  var response=recorder.response_rule(index,first,last,false)
  rule.erase("action");rule.sequence=response.sequence
 return rule

static func references(c: Dictionary,adapter) -> Array:
 var result=[]
 if c.get("type") in ["all","any"]:
  for child in c.get("conditions",[]):result.append_array(references(child,adapter))
 elif c.get("type")=="not":result.append_array(references(c.get("condition",{}),adapter))
 if c.has("alias") or c.has("created"):
  var card=adapter.resolve_card(c)
  if not card.is_empty():
   result.append({"kind":"card","ref":adapter.engine.ref_target(card)})
   if c.get("type")=="entity_zone":result.append({"kind":"zone","player":int(card.owner),"zone":c.zone})
 if c.has("player"):
  if c.get("type")=="zone_count":result.append({"kind":"zone","player":int(c.player),"zone":c.zone})
  else:result.append({"kind":"player","player":int(c.player)})
 if c.get("type")=="priority":result.append({"kind":"player","player":int(c.value)})
 if c.get("type")=="pending":result.append({"kind":"player","player":int(c.owner)})
 if c.get("type") in ["phase","combat_step"]:result.append({"kind":"phase"})
 return result
