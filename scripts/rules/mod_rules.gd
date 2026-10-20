extends RefCounted
## Continuous queries and replacement changes are separate from triggered stack objects.
const Context=preload("res://scripts/rules/mod_context.gd")

static func sources(e,kind: String) -> Array:
 var result=[]
 if e.players.size()!=2 or not e.mod_registry.kinds.has(kind):return result
 for who in range(2):
  var seen={}
  for c in e.players[who].field+e.players[who].exile+e.players[who].grave+e.players[who].hand+e.players[who].deck+e.players[who].palette+e.leaders(who):
   if seen.has(c.uid):continue
   seen[c.uid]=true
   for b in e.Mods.bindings(e,c,kind):
    if e.Mods.enabled(e,c,b):result.append({"card":c,"binding":b,"frame":e.Mods.frame_for(e,c,b,c.owner,{},false)})
 return result

static func invoke(e,item: Dictionary,method: String,query: Dictionary) -> Array:
 var ctx=Context.new(e,item.frame)
 var value=e.mod_registry.invoke(item.frame.ability_id,method,[ctx,query.duplicate(true),item.frame.params.duplicate(true)])
 return value if ctx.error.is_empty() and value is Array and value.size()<=100 and e.Mods.Registry.serializable(value) else []

static func identity(item: Dictionary,id: String) -> String:
 return str(item.card.uid)+":"+str(item.card.epoch)+":"+item.frame.ability_id+":"+item.frame.instance+":"+str(item.frame.occurrence)+":"+id

static func earlier(a: Dictionary,b: Dictionary) -> bool:
 if a.timestamp!=b.timestamp:return a.timestamp<b.timestamp
 return a.identity<b.identity

static func query(e,query_spec: Dictionary,base: Variant,layer: int=30) -> Variant:
 if not e.mod_registry.kinds.has("static"):return base
 var guard=JSON.stringify(query_spec)+":"+str(layer)
 if e.mod_query_guard.has(guard):return base
 e.mod_query_guard[guard]=true
 var q=query_spec.duplicate(true);q.value=base;q.layer=layer
 var candidates=sources(e,"static");var applied=[];var value=base
 for iteration in range(128):
  var pending=[];q.value=value
  for item in candidates:
   var seen={}
   for m in invoke(e,item,"get_modifiers",q):
    if not valid_modifier(m) or int(m.layer)!=layer or seen.has(m.id):continue
    seen[m.id]=true
    var key=identity(item,m.id)
    if key not in applied:pending.append({"item":item,"modifier":m,"identity":key,"dependency":item.frame.ability_id+"/"+m.id,"timestamp":item.card.get("mod_timestamp",item.card.uid)})
  if pending.is_empty():break
  pending.sort_custom(earlier)
  var ready=pending.filter(func(a):return not pending.any(func(b):return a.identity!=b.identity and b.dependency in a.modifier.get("depends_on",[])))
  # Circular dependencies use the oldest timestamp, then stable instance identity.
  var next=pending[0] if ready.is_empty() else ready[0]
  applied.append(next.identity)
  var current=next.modifier
  if value is bool:
   if current.operation=="set" and current.value is bool:value=current.value
  elif (value is int or value is float) and (current.value is int or current.value is float):
   match current.operation:
    "set":value=current.value
    "add":value+=current.value
    "multiply":value*=current.value
   value=clampf(value,-1000000,1000000)
 e.mod_query_guard.erase(guard)
 return value

static func valid_modifier(m: Variant) -> bool:
 return m is Dictionary and m.get("id") is String and not m.id.is_empty() and int(m.get("layer",0)) in [10,30,40] and m.get("operation","") in ["set","add","multiply"] and m.get("depends_on",[]) is Array and m.get("depends_on",[]).all(func(key):return key is String) and m.has("value")

static func offers(e,change: Dictionary) -> Array:
 var result=[]
 for item in sources(e,"replacement"):
  if change.type not in e.mod_registry.descriptor(item.frame.ability_id).changes:continue
  var seen={}
  for proposal in invoke(e,item,"get_replacements",change):
   if not proposal is Dictionary or not proposal.get("id") is String or seen.has(proposal.id):continue
   seen[proposal.id]=true
   var id=identity(item,proposal.id)
   if id in change.used or not proposal.get("optional",false) is bool:continue
   if not proposal.get("operations",[]) is Array or proposal.get("operations",[]).size()>100:continue
   if not proposal.get("operations",[]).all(func(op):return op is Dictionary and op.get("op","")!="draw" and e.Mods.valid_operation(e,item.frame,op)):continue
   if change.type=="cast_x" and (not proposal.get("x") is int or proposal.x<0 or proposal.x>10000):continue
   if change.type=="draw" and proposal.get("cancel",false)!=true:continue
   if proposal.has("recover_draw"):
    if change.type!="draw" or not valid_recovery(e,change,proposal.recover_draw):continue
   result.append({"identity":id,"frame":item.frame,"proposal":proposal,"text":e.mod_registry.descriptor(item.frame.ability_id).text})
 result.sort_custom(func(a,b):return a.identity<b.identity)
 return result

static func valid_recovery(e,change: Dictionary,recovery: Variant) -> bool:
 if not recovery is Dictionary or not recovery.get("pool") is Array or not recovery.get("title","") is String:return false
 var seen=[]
 for ref in recovery.pool:
  if not ref is Dictionary:return false
  var card=e.find_card(int(ref.get("uid",-1)))
  if card.is_empty() or ref!={"uid":card.uid,"epoch":card.epoch,"zone":card.zone} or card.zone!="exile" or card.get("original_owner",card.owner)!=change.owner or card.owner!=change.owner or card.uid in seen:return false
  seen.append(card.uid)
 return true

static func recovery_options(change: Dictionary,offer: Dictionary) -> Array:
 var count=mini(100,int(change.get("count",1)))
 return [{"selection_id":"mod:draw_recovery","replacement":offer.identity,"selection":[{"pool":offer.proposal.recover_draw.pool.duplicate(true),"min":count,"max":count,"title":offer.proposal.recover_draw.get("title","")+"（选择 %d 张）" % count,"cost":true,"exclude_previous":true}]}]

static func choose_offer(e,change: Dictionary,offer: Dictionary):
 if not offer.proposal.has("recover_draw"):
  apply_offer(e,change,offer);return
 e.pending={"kind":"effect_choice","owner":change.owner,"trigger":{"effect":"mod:replacement","mod_replace":true,"mod_replace_selection":true,"intrinsic_entry":true,"continuation":true,"optional":false,"owner":change.owner,"source":offer.frame.source.duplicate(true),"name":"选择替代抓牌的道具","ability_text":offer.text},"options":recovery_options(change,offer)}
 e.revision+=1

static func begin(e,change: Dictionary):
 e.mod_change_serial+=1;change.id=e.mod_change_serial;change.used=[];change.cancel=false
 e.mod_changes.append(change);advance(e)

static func apply_offer(e,change: Dictionary,offer: Dictionary):
 change.used.append(offer.identity)
 var p=offer.proposal
 if change.type=="cast_x":change.x=p.x
 if p.get("cancel",false):change.cancel=true
 change.operations=p.get("operations",[]).duplicate(true);change.cursor=0;change.frame=offer.frame.duplicate(true)

static func intrinsic_pending(e) -> bool:
 return not e.pending.is_empty() or not e.returns.is_empty() or not e.timer_changes.is_empty() or not e.zone_replacements.is_empty() or not e.entry_choices.is_empty() or not e.damage_queue.is_empty()

static func advance(e):
 if e.mod_change_processing or intrinsic_pending(e):return
 e.mod_change_processing=true
 while not e.mod_changes.is_empty() and e.pending.is_empty() and e.winner==-2:
  var change=e.mod_changes[0]
  while int(change.get("cursor",0))<change.get("operations",[]).size():
   var op=change.operations[change.cursor];change.cursor+=1
   var old_context=e.damage_context;var old_spell=e.resolving_spell
   e.damage_context={"source":change.frame.source,"combat":false,"single":false};e.resolving_spell=false
   e.Mods.execute(e,change.frame,op)
   e.damage_context=old_context;e.resolving_spell=old_spell
   if intrinsic_pending(e) or e.winner!=-2:break
  if intrinsic_pending(e) or e.winner!=-2:break
  var available=[] if change.cancel else offers(e,change)
  if available.any(func(offer):return offer.proposal.has("recover_draw") and offer.proposal.recover_draw.pool.size()<int(change.get("count",1))):
   e.lose(change.owner,"移除区道具不足，无法替代欠抽的 %d 张牌" % int(change.get("count",1)));break
  if change.used.size()>=128:available=[]
  if available.size()==1 and not available[0].proposal.get("optional",false):
   choose_offer(e,change,available[0]);continue
  if not available.is_empty():
   var options=[]
   for offer in available:
    var recovery=offer.proposal.has("recover_draw")
    options.append({"none":true,"replacement":offer.identity,"mode":"发动道具替代抓牌" if recovery else "应用 · "+offer.text})
    if offer.proposal.get("optional",false):options.append({"none":true,"replacement":offer.identity,"decline":true,"mode":"不发动，正常抓牌" if recovery else "不应用 · "+offer.text})
   e.pending={"kind":"effect_choice","owner":change.owner,"trigger":{"effect":"mod:replacement","mod_replace":true,"intrinsic_entry":true,"continuation":true,"optional":false,"owner":change.owner,"source":available[0].frame.source.duplicate(true),"name":"选择替代效果","ability_text":"选择一个替代效果；应用后重新检查。"},"options":options}
   e.revision+=1;break
  e.mod_changes.pop_front()
  if not change.cancel:commit(e,change)
  if change.type=="draw" and e.winner==-2 and int(change.get("count",1))>int(change.get("recovered_count",1)):
   e.mod_change_serial+=1
   e.mod_changes.push_front({"type":"draw","owner":change.owner,"count":int(change.count)-int(change.get("recovered_count",1)),"id":e.mod_change_serial,"used":[],"cancel":false})
 e.mod_change_processing=false

static func answer(e,answer: Dictionary):
 if e.mod_changes.is_empty() or not e.Mods.choice_valid(e,e.pending.options,answer):return
 var change=e.mod_changes[0];var available=offers(e,change)
 for offer in available:
  if offer.identity!=answer.get("replacement",""):continue
  if e.pending.trigger.get("mod_replace_selection",false):
   if not offer.proposal.has("recover_draw") or not e.Mods.choice_valid(e,recovery_options(change,offer),answer):return
   apply_offer(e,change,offer)
   change.recovered_count=answer.picks[0].size()
   for ref in answer.picks[0]:change.operations.append({"op":"move","target":ref.duplicate(true),"zone":"hand"})
  elif answer.get("decline",false):
   if not offer.proposal.get("optional",false):return
   change.used.append(offer.identity)
  else:
   e.pending={};choose_offer(e,change,offer)
   if not e.pending.is_empty():return
  e.pending={};e.revision+=1;advance(e);e.pump_choices();return

static func commit(e,change: Dictionary):
 if change.type=="draw":e.draw_unreplaced(change.owner,1)
 elif change.type=="cast_x":
  var c=e.find_card(change.source.uid)
  if c.is_empty() or c.zone!="stack" or c.epoch!=change.source.epoch:return
  c.cast_x=change.x
  var target=change.target.duplicate(true);target.x=change.x
  for entry in e.stack:
   if entry.get("card",{}).get("uid",-1)==c.uid:entry.target=target
  e.Mods.finish_cast(e,c,change.owner,change.old_zone,change.heart,target)
