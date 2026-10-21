extends RefCounted
const Registry=preload("res://scripts/rules/mod_registry.gd")
const Context=preload("res://scripts/rules/mod_context.gd")
const Rules=preload("res://scripts/rules/mod_rules.gd")
const PREFIX="mod:"

static func bindings(e,c: Dictionary,kind: String="") -> Array:
 var result=[];var occurrences={}
 for binding in e.cards.get(c.get("card_id",""),{}).get("abilities",[]):
  if binding.get("实现","")!="mod":continue
  var id=binding.get("参数",{}).get("能力","")
  var d=e.mod_registry.descriptor(id)
  if not d.is_empty() and (kind.is_empty() or d.kind==kind):
   var copy=binding.duplicate(true);var identity=id+":"+binding["实例键"]
   copy._occurrence=int(occurrences.get(identity,0));occurrences[identity]=copy._occurrence+1;result.append(copy)
 return result

static func frame_for(e,c: Dictionary,b: Dictionary,who: int,event: Dictionary={},with_stats: bool=true) -> Dictionary:
 var snapshot=c.duplicate(true)
 if with_stats and not snapshot.has("mod_stats") and e.cards.has(c.card_id):
  snapshot.mod_stats={}
  for key in ["power","health","spirit"]:snapshot.mod_stats[key]=e.stat(c,key)
 return {"api":Registry.API_VERSION,"ability_id":b["参数"]["能力"],"instance":b["实例键"],"occurrence":b.get("_occurrence",0),"source":snapshot,"owner":who,"params":b["参数"].duplicate(true),"step":0,"data":{},"event":event.duplicate(true),"target":{}}

static func key_for(c: Dictionary,b: Dictionary) -> String:return PREFIX+b["参数"]["能力"]+":"+b["实例键"]+":"+str(b.get("_occurrence",0))+":"+str(c.epoch)
static func binding_for(e,c: Dictionary,key: String) -> Dictionary:
 for b in bindings(e,c,"activated"):
  if key_for(c,b)==key:return b
 return {}

static func enabled(e,c: Dictionary,b: Dictionary) -> bool:
 var d=e.mod_registry.descriptor(b["参数"]["能力"])
 return c.zone in d.zones and (d.role!="leader" or c.get("mod_leader_enabled",e.has_leader_ability(c)))

static func describe(e,frame: Dictionary) -> Dictionary:
 var ctx=Context.new(e,frame)
 var result=e.mod_registry.invoke(frame.ability_id,"describe_action",[ctx,frame.params.duplicate(true)])
 if not ctx.error.is_empty() or not result is Dictionary or not Registry.serializable(result):return {}
 if not valid_options(result.get("options",[])):return {}
 if result.get("timing","priority") not in ["priority","main"] or not result.get("tap",false) is bool:return {}
 if not result.get("cost",{}) is Dictionary or not result.get("extra_costs",[]) is Array:return {}
 for color in result.get("cost",{}):
  var amount=result.cost[color]
  if not e.DB.integer_value(amount):return {}
  for part in str(color).split("/"):
   if part not in e.COLORS:return {}
 for cost in result.get("extra_costs",[]):
  if not cost is Dictionary or cost.get("kind","") not in ["discard","sacrifice"] or not cost.get("group") is int or cost.group<0:return {}
 if e.mod_registry.descriptor(frame.ability_id).kind!="activated" and (not result.get("cost",{}).is_empty() or result.get("tap",false) or not result.get("extra_costs",[]).is_empty()):return {}
 return result.duplicate(true)

static func valid_options(options: Variant) -> bool:
 if not options is Array or not Registry.serializable(options):return false
 for option in options:
  if not option is Dictionary:return false
  if option.has("selection"):
   if not option.selection is Array:return false
   for group in option.selection:
    if not group is Dictionary or not group.get("pool") is Array or not group.get("min") is int or not group.get("max") is int:return false
    if group.min<0 or group.max<group.min or group.max>100:return false
    for item in group.pool:
     if not item is Dictionary or item.has("selection"):return false
 return true

static func choice_valid(e,options: Array,answer: Dictionary) -> bool:
 # Reject arbitrary extra fields, including forged costs / frame steps.
 if not Registry.serializable(answer):return false
 for option in options:
  if not option.has("selection"):
   if option==answer:return true
   continue
  var expected=option.duplicate(true);expected.erase("selection");expected.picks=answer.get("picks",null)
  if expected==answer and e.Pack.choice_valid(e,[option],answer):return true
 return false

static func feasible(options: Array) -> Array:
 return options.filter(func(option):return option.get("selection",[]).all(func(group):return group.pool.size()>=group.min))

static func retarget_options(e,entry: Dictionary) -> Array:
 var frame=entry.mod_frame.duplicate(true);frame.owner=entry.owner
 var options=describe(e,frame).get("options",[])
 # Costs were paid by the original declaration; copying/redirecting only selects targets.
 for option in options:
  for i in range(option.get("selection",[]).size()):
   if option.selection[i].get("cost",false):
    option.selection[i].pool=e.Pack.picked(entry.target,i).duplicate(true)
    option.selection[i].min=option.selection[i].pool.size();option.selection[i].max=option.selection[i].pool.size()
 return e.Roster.filter_options(e,options,entry.owner,false)

static func actions(e,c: Dictionary,who: int,include_disabled: bool) -> Array:
 var result=[]
 for b in bindings(e,c,"activated"):
  var d=e.mod_registry.descriptor(b["参数"]["能力"])
  if c.zone not in d.zones:continue
  var key=key_for(c,b);var reason=activation_error(e,who,c,key)
  if include_disabled or reason.is_empty():
   var spec=describe(e,frame_for(e,c,b,who))
   result.append({"type":"extension","uid":c.uid,"key":key,"label":d.text,"enabled":reason.is_empty(),"reason":reason,"mod_cost":spec.get("cost",{}),"payment_tap":spec.get("tap",false),"payment_groups":spec.get("extra_costs",[]).map(func(cost):return cost.group)})
 return result

static func activation_error(e,who: int,c: Dictionary,key: String) -> String:
 if c.is_empty() or who not in [0,1] or c.owner!=who:return "需要操控该来源"
 if e.winner!=-2 or e.phase=="mulligan" or not e.pending.is_empty() or not e.mod_resolution.is_empty() or not e.entry_choices.is_empty() or e.priority!=who or e.Pack.response_locked(e):return "当前不能发动"
 var b=binding_for(e,c,key)
 if b.is_empty() or not enabled(e,c,b):return "能力实例或区域已失效"
 if Rules.query(e,{"kind":"action_lock","card":c,"controller":who,"action":"activate"},false):return "模组常驻效果禁止发动该能力"
 if e.Cat.State.activation_locked(e,c) or e.Roster.Batch.locked(e,c):return "该对象的启动能力被禁止"
 var a=describe(e,frame_for(e,c,b,who))
 if a.is_empty():return "模组动作规格无效"
 if a.get("timing","priority")=="main" and (e.active!=who or e.phase!="main" or not e.stack.is_empty() or not e.combat.is_empty()):return "只能在自己的主要阶段空对抗发动"
 if a.get("tap",false) and (c.zone!="field" or c.tapped or e.is_unit(c) and e.summoning_sick(c)):return "不能横置"
 if e.payment(who,a.get("cost",{}),[c.uid] if a.get("tap",false) else []).ways==0:return "费用不足"
 if options_for(e,c,key).is_empty():return "没有合法选择"
 return ""

static func options_for(e,c: Dictionary,key: String) -> Array:
 var b=binding_for(e,c,key)
 if b.is_empty():return []
 var a=describe(e,frame_for(e,c,b,c.owner))
 return e.Roster.filter_options(e,feasible(a.get("options",[])),c.owner,false)

static func action_cost(e,who: int,c: Dictionary,key: String,target: Dictionary) -> Dictionary:
 var b=binding_for(e,c,key)
 if b.is_empty():return {}
 var cost=describe(e,frame_for(e,c,b,who)).get("cost",{}).duplicate(true)
 var tax=e.Cat.target_tax(e,who,target)
 if tax>0:cost["红/蓝/绿/黄/黑"]=int(cost.get("红/蓝/绿/黄/黑",0))+tax
 return cost

static func commit(e,who: int,c: Dictionary,key: String,target: Dictionary,plan: Array) -> String:
 var error=activation_error(e,who,c,key)
 if not error.is_empty():return error
 var b=binding_for(e,c,key);var frame=frame_for(e,c,b,who);var a=describe(e,frame)
 var options=options_for(e,c,key)
 if not choice_valid(e,options,target):return "选择已失效"
 var selected_spec={}
 for spec in options:
  if choice_valid(e,[spec],target):selected_spec=spec;break
 var costs=[];var seen=[]
 for extra in a.get("extra_costs",[]):
  var index=extra.group
  if index>=selected_spec.get("selection",[]).size() or not selected_spec.selection[index].get("cost",false):return "额外费用规格无效"
  for r in e.Pack.picked(target,index):
   var paid=e.find_card(int(r.get("uid",-1)))
   if paid.is_empty() or paid.epoch!=r.get("epoch",-1) or paid.owner!=who or paid.uid in seen:return "额外费用已失效"
   if extra.kind=="discard" and paid.zone!="hand" or extra.kind=="sacrifice" and not e.can_sacrifice(paid):return "不能支付额外费用"
   seen.append(paid.uid);costs.append({"kind":extra.kind,"card":paid})
 # Every cost group must have an engine operation; a mod cannot label a target as a cost.
 for i in range(selected_spec.get("selection",[]).size()):
  if selected_spec.selection[i].get("cost",false) and not a.get("extra_costs",[]).any(func(cost):return cost.group==i):return "额外费用缺少支付操作"
 if a.get("tap",false):seen.append(c.uid)
 if plan.any(func(resource):return resource.get("uid",0) in seen):return "同一资源不能重复支付"
 if not e.payment_valid(who,action_cost(e,who,c,key,target),plan):return "支付方案已失效"
 # Commit starts only after the complete declaration has been validated.
 e.catalogue_serial+=1;e.Cat.pay(e,who,plan)
 if a.get("tap",false):e.tap_card(c)
 for cost in costs:
  if cost.kind=="discard":e.move_to(cost.card,"grave")
  else:e.sacrifice(cost.card)
 var d=e.mod_registry.descriptor(frame.ability_id)
 var entry={"id":e.next_stack,"kind":"ability","activation":true,"effect":key,"source":frame.source.duplicate(true),"owner":who,"target":target.duplicate(true),"name":e.cards[frame.source.card_id].name,"ability_text":d.text,"mod_frame":frame,"target_spec":selected_spec.duplicate(true)}
 if e.optional_single_target(options,target):entry.optional_single_target=true
 e.stack.append(entry);e.next_stack+=1;e.passes=0;e.priority=1-who
 e.Roster.on_ability_announced(e,entry);e.Roster.New.on_target(e,target,entry);targeted(e,target,who)
 e.note("发动 "+entry.name,e.history_art(frame.source));entry.history_index=e.history.size()-1
 e.record_declaration(who,target,frame.source);e.judge();e.pump_choices()
 return ""

static func spell_options(e,id: String,who: int,uid: int) -> Variant:
 var source=e.find_card(uid) if uid>=0 else {"card_id":id,"uid":-1,"epoch":0,"zone":"hand","owner":who}
 var list=bindings(e,source,"spell")
 if list.is_empty():
  if not e.DB.has_ability(e.cards[id],"mod"):return null
  if not e.cards[id].get("variable_cost","").is_empty():
   var result=[]
   for x in range(e.VariableChoice.limit(e,id,who)+1):result.append({"none":true,"x":x,"mode":"X = %d" % x})
   return result
  return [{"none":true}] if e.cards[id].kind=="符卡" else null
 return e.Roster.filter_options(e,feasible(describe(e,frame_for(e,source,list[0],who)).get("options",[])),who,true)

static func spell_resolve(e,entry: Dictionary) -> bool:
 var list=bindings(e,entry.card,"spell")
 if list.is_empty():
  if not e.DB.has_ability(e.cards[entry.card.card_id],"mod"):return false
  if "时符" in e.cards[entry.card.card_id].spell_type:
   var info=e.cards[entry.card.card_id]
   if e.enter_field(entry.card,entry.owner):e.add_timer(entry.card,int(entry.card.get("cast_x",0)) if not info.variable_cost.is_empty() else info.time)
  else:e.to_grave(entry.card)
  return true
 var frame=frame_for(e,entry.card,list[0],entry.owner)
 start_resolution(e,entry,frame)
 return true

static func event(e,c: Dictionary,name: String,after: Dictionary={},details: Dictionary={}):
 if e.Pack.trigger_locked(e):return
 for b in bindings(e,c,"triggered"):
  var d=e.mod_registry.descriptor(b["参数"]["能力"])
  if name not in d.events or not enabled(e,c,b):continue
  var event_data={"type":name,"source":c.duplicate(true),"after":after.duplicate(true)}
  event_data.merge(details,true)
  var frame=frame_for(e,c,b,c.owner,event_data);var ctx=Context.new(e,frame)
  var collected=e.mod_registry.invoke(frame.ability_id,"collect_triggers",[ctx,event_data.duplicate(true),frame.params.duplicate(true)])
  if not ctx.error.is_empty() or not collected is Array or collected.size()>32 or not Registry.serializable(collected):continue
  for data in collected:
   if data is Dictionary:
    var once=d.get("once_per_turn",false)
    if once:
     var use_key="mod:"+frame.ability_id+":"+frame.instance+":trigger"
     if e.usage_count(c.uid,use_key)>0:continue
     e.use_once(c.uid,use_key)
    var copy=frame.duplicate(true);copy.data=data;enqueue(e,copy,d)

static func broadcast(e,name: String,details: Dictionary):
 var seen={}
 for item in Rules.sources(e,"triggered"):
  if seen.has(item.card.uid):continue
  seen[item.card.uid]=true;event(e,item.card,name,{},details)

static func finish_cast(e,c: Dictionary,who: int,old_zone: String,heart: Dictionary,target: Dictionary):
 if not e.cards[c.card_id].get("variable_cost","").is_empty():e.mod_x_casts[str(who)]=int(e.mod_x_casts.get(str(who),0))+1
 e.Roster.on_cast(e,c,who,old_zone,heart)
 var declaration={}
 for entry in e.stack:
  if entry.get("kind","")=="card" and entry.get("card",{}).get("uid",-1)==c.uid and entry.card.get("epoch",-1)==c.epoch:declaration=entry;break
 e.Pack.on_cast(e,c,who,target);e.Roster.New.on_target(e,target,declaration)
 broadcast(e,"cast",{"card":c.duplicate(true),"controller":who,"x":int(c.get("cast_x",0))})
 targeted(e,target,who)
 if e.cards[c.card_id].kind=="符卡":e.Effects.spell_used(e,who)

static func targeted(e,target: Dictionary,who: int):
 var seen={}
 for ref in e.Pack.declared_targets({"target":target}):
  if not ref.has("uid") or seen.has(ref.uid):continue
  var c=e.find_card(ref.uid)
  if c.is_empty() or c.zone!="field":continue
  seen[ref.uid]=true;event(e,c,"targeted",{},{"controller":who})

static func enqueue(e,frame: Dictionary,d: Dictionary):
 e.Cat.enqueue(e,{"extended":true,"effect":PREFIX+frame.ability_id,"mod_frame":frame.duplicate(true),"owner":frame.owner,"source":frame.source.duplicate(true),"optional":d.optional,"name":e.cards[frame.source.card_id].name,"ability_text":d.text,"data":{"single_instance":true}})

static func force(e,c: Dictionary,role: String="main",ignore_authorization: bool=false):
 if e.Pack.trigger_locked(e):return
 for b in bindings(e,c,"triggered"):
  var d=e.mod_registry.descriptor(b["参数"]["能力"])
  if d.role!=role or d.forced=="skip" or c.zone not in d.zones or not ignore_authorization and not enabled(e,c,b):continue
  if d.get("once_per_turn",false):
   var use_key="mod:"+b["参数"]["能力"]+":"+b["实例键"]+":trigger"
   if e.usage_count(c.uid,use_key)>0:continue
   e.use_once(c.uid,use_key)
  for repeat in range(2 if e.Cat.character(e,c,"秦心") else 1):enqueue(e,frame_for(e,c,b,c.owner,{"type":"forced"}),d)

static func trigger_options(e,t: Dictionary) -> Array:
 return e.Roster.filter_options(e,feasible(describe(e,t.mod_frame).get("options",[])),t.owner,false)

static func start_resolution(e,entry: Dictionary,frame: Dictionary={}):
 if frame.is_empty():frame=entry.mod_frame.duplicate(true)
 frame.owner=entry.owner
 frame.target=entry.target.duplicate(true)
 e.mod_resolution={"entry":entry,"frame":frame,"operations":[],"cursor":0,"choice":[],"done":false,"again":false,"steps":0}
 run_step(e,{})

static func fail(e,message: String):
 e.note("模组结算失败："+message)
 var entry=e.mod_resolution.get("entry",{})
 e.mod_resolution={}
 if entry.get("kind","")=="card" and entry.card.zone=="stack":e.to_grave(entry.card)

static func run_step(e,answer: Dictionary):
 var r=e.mod_resolution
 if r.is_empty():return
 r.steps+=1
 if r.steps>128:fail(e,"超过步骤上限");return
 var ctx=Context.new(e,r.frame,true)
 var result=e.mod_registry.invoke(r.frame.ability_id,"resolve",[ctx,r.frame.duplicate(true),answer.duplicate(true)])
 if not ctx.error.is_empty() or not result is Dictionary or not Registry.serializable(result):fail(e,"结算结果必须为普通数据");return
 if not result.get("done",false):
  if not result.get("step") is int or result.step<0 or not valid_options(result.get("choice",[])) or not result.get("continue",false) and result.get("choice",[]).is_empty():fail(e,"需要下一步骤及选择规格或 continue");return
 if not result.get("done",false) is bool or not result.get("continue",false) is bool:fail(e,"done / continue 必须为布尔值");return
 if not result.get("data",{}) is Dictionary:fail(e,"临时数据必须为对象");return
 if ctx.operations.size()>100:fail(e,"超过单步操作上限");return
 for op in ctx.operations:
  if not valid_operation(e,r.frame,op):fail(e,"操作不在接口支持范围："+str(op.get("op","")));return
 r.operations=ctx.operations.duplicate(true);r.cursor=0;r.choice=result.get("choice",[]).duplicate(true);r.done=result.get("done",false)
 r.again=result.get("continue",false)
 r.frame.step=result.get("step",r.frame.step);r.frame.data=result.get("data",{}).duplicate(true)
 advance(e)

static func valid_operation(e,frame: Dictionary,op: Dictionary) -> bool:
 if not Registry.serializable(op) or not op.get("op") is String:return false
 match op.op:
  "damage":return op.target is Dictionary and op.amount is int and op.amount>=0 and op.amount<=10000 and op.get("result_key","") is String
  "draw":return op.owner in [0,1] and op.count is int and op.count>=0 and op.count<=100
  "move":return op.target is Dictionary and op.zone in ["hand","grave","exile","palette"] and op.get("tapped",false) is bool
  "sacrifice":return op.target is Dictionary
  "reorder_top":return op.owner in [0,1] and op.cards is Array and op.cards.size()<=100
  "state":return not state_schema(e,frame,op.key).is_empty()
  "life":return op.owner in [0,1] and op.amount is int and op.amount>=0 and op.amount<=10000
  "counters":return op.target is Dictionary and op.amount is int and op.amount>=0 and op.amount<=10000
  "tap":return op.target is Dictionary and op.tapped is bool
  "deck_move":return op.target is Dictionary and op.bottom is bool
  "enter":return op.target is Dictionary and op.timer is int and op.timer>=-1 and op.timer<=10000
  "buff":return op.target is Dictionary and op.stats is Dictionary and op.stats.keys().all(func(k):return k in ["攻击力","血量","灵力","疾行"])
  "random_damage":return op.targets is Array and op.targets.all(func(t):return t is Dictionary) and op.amount is int and op.amount>=0 and op.amount<=10000
  "fight":return op.first is Dictionary and op.second is Dictionary
  "force_leader":return op.target is Dictionary and op.count is int and op.count>=0 and op.count<=32
  "tokens":return op.owner in [0,1] and op.count is int and op.count>=0 and op.count<=100 and op.card_id is String and op.card_id.begins_with(frame.ability_id.get_slice("/",0)+"/") and e.cards.get(op.card_id,{}).get("token",false)
  "mill":return op.owner in [0,1] and op.count is int and op.count>=0 and op.count<=100
  "shuffle":return op.owner in [0,1]
  "end_turn":return true
  "grant_cast":return op.target is Dictionary and op.discount is int and op.discount>=0 and op.discount<=100 and op.free is bool and op.get("zone","") in ["","grave","exile"]
  "cast_now":return op.target is Dictionary and op.free is bool
  "linked_enter":return op.target is Dictionary and op.anchor is Dictionary
 return false

static func interrupted(e) -> bool:
 return not e.pending.is_empty() or not e.mod_changes.is_empty() or not e.returns.is_empty() or not e.timer_changes.is_empty() or not e.zone_replacements.is_empty() or not e.entry_choices.is_empty() or not e.damage_queue.is_empty()

static func advance(e):
 if e.mod_resolution.is_empty() or interrupted(e):return
 var r=e.mod_resolution
 var old_damage=e.damage_context;var old_spell=e.resolving_spell
 e.damage_context={"source":r.frame.source,"combat":false,"single":e.Pack.single_damage_target(r.entry)}
 e.resolving_spell=r.entry.kind=="card"
 while r.cursor<r.operations.size():
  var op=r.operations[r.cursor];r.cursor+=1;execute(e,r.frame,op)
  if e.mod_resolution.is_empty():e.damage_context=old_damage;e.resolving_spell=old_spell;return
  if e.winner!=-2:
   e.mod_resolution={};e.damage_context=old_damage;e.resolving_spell=old_spell;return
  if interrupted(e):break
 e.damage_context=old_damage;e.resolving_spell=old_spell
 if interrupted(e):return
 if r.done:
  var entry=r.entry;e.mod_resolution={}
  if entry.kind=="card" and entry.card.zone=="stack":e.to_grave(entry.card)
  e.revision+=1
 elif r.again:run_step(e,{})
 else:
  var source=r.frame.source
  e.pending={"kind":"effect_choice","owner":r.frame.owner,"trigger":{"effect":"mod:resume","mod_resume":true,"continuation":true,"optional":false,"owner":r.frame.owner,"source":source.duplicate(true),"name":e.cards[source.card_id].name,"ability_text":e.mod_registry.descriptor(r.frame.ability_id).text},"options":r.choice.duplicate(true),"resolving_entry":r.entry.duplicate(true)}
  e.revision+=1

static func execute(e,frame: Dictionary,op: Dictionary):
 var c=e.find_card(int(op.get("target",{}).get("uid",-1)))
 if c.is_empty() and not e.mod_resolution.is_empty():
  var entry=e.mod_resolution.entry
  if entry.get("card",{}).get("uid",-2)==op.get("target",{}).get("uid",-1):c=entry.card
 if not c.is_empty() and (c.epoch!=op.target.get("epoch",-1) or c.zone!=op.target.get("zone",c.zone)):c={}
 match op.op:
  "damage":
   var key=op.get("result_key","")
   if not key.is_empty():
    if not frame.has("results"):frame.results={}
    frame.results[key]=0
   if not op.target.get("invalid",false) and e.target_valid(op.target) and not e.Roster.protected(e,op.target,frame.owner,e.resolving_spell):
    if not key.is_empty():e.damage_context.mod_result={"key":key,"source":frame.source.uid,"target":op.target}
    e.damage_target(op.target,op.amount)
    e.damage_context.erase("mod_result")
  "draw":e.draw(op.owner,op.count)
  "move":
   if not c.is_empty():
    e.move_to(c,op.zone)
    if op.zone=="palette":c.tapped=op.get("tapped",false)
  "sacrifice":
   if not c.is_empty():e.sacrifice(c)
  "state":write_state(e,frame,op.key,op.value)
  "life":e.gain_life(op.owner,op.amount)
  "counters":
   if not c.is_empty() and c.zone=="field" and not op.target.get("invalid",false):e.Roster.plus(e,c,op.amount,frame.owner)
  "tap":
   if not c.is_empty() and c.zone in ["field","palette"]:
    if op.tapped:e.tap_card(c)
    else:c.tapped=false
  "deck_move":
   if not c.is_empty():
    e.move_to(c,"deck")
    if c.zone=="deck" and not op.bottom:e.players[c.owner].deck.erase(c);e.players[c.owner].deck.push_front(c)
  "enter":
   if not c.is_empty() and e.field_error(c,frame.owner).is_empty():
    e.detach(c)
    if e.enter_field(c,frame.owner) and op.timer>=0:e.add_timer(c,op.timer)
  "buff":e.apply_turn_buff(op.target,op.stats)
  "random_damage":
   var targets=op.targets.filter(func(t):return e.target_valid(t))
   if not targets.is_empty():e.damage_target(targets[e.rng.randi_range(0,targets.size()-1)],op.amount)
  "fight":
   if not op.first.get("invalid",false) and not op.second.get("invalid",false) and not e.Roster.protected(e,op.first,frame.owner,e.resolving_spell) and not e.Roster.protected(e,op.second,frame.owner,e.resolving_spell):e.Cat.forced_battle(e,op.first,op.second)
  "force_leader":
   if not c.is_empty() and c.zone=="field" and not op.target.get("invalid",false):
    for repeat in range(op.count):e.Roster.TriggerInventory.force_leader(e,c)
  "tokens":e.Cat.printed_tokens(e,op.owner,op.count,op.card_id)
  "mill":e.mill_cards(e.players[op.owner].deck.slice(0,op.count))
  "shuffle":e.shuffle(e.players[op.owner].deck)
  "end_turn":
   var entry=e.mod_resolution.get("entry",{})
   e.mod_resolution={}
   if entry.get("kind","")=="card" and entry.card.zone=="stack":e.move_to(entry.card,"exile")
   e.Roster.end_now(e)
  "grant_cast":
   if not c.is_empty():c.mod_access={"owner":frame.owner,"turn":e.turn,"discount":op.discount,"free":op.free,"zone":op.zone if not op.get("zone","").is_empty() else c.zone}
  "cast_now":
   if not c.is_empty():e.Cat.grant_cast(e,c,frame.owner,op.free)
  "linked_enter":
   var anchor=e.find_card(int(op.anchor.get("uid",-1)))
   if not c.is_empty() and not anchor.is_empty() and anchor.zone=="field" and anchor.epoch==op.anchor.get("epoch",-1) and e.field_error(c,frame.owner).is_empty():
    e.detach(c)
    if e.enter_field(c,frame.owner):
     anchor.mod_linked=anchor.get("mod_linked",[])+[{"uid":c.uid,"epoch":c.epoch,"zone":"field"}]
     if anchor.zone!="field" or anchor.epoch!=op.anchor.epoch:e.sacrifice(c)
  "reorder_top":
   var deck=e.players[op.owner].deck
   var seen=[];var picked=[]
   for target in op.cards:
    if not target is Dictionary:return
    var found=e.find_card(int(target.get("uid",-1)))
    if found.is_empty() or found.zone!="deck" or found.owner!=op.owner or found.epoch!=target.get("epoch",-1) or found.uid in seen:return
    seen.append(found.uid);picked.append(found)
   for card in deck.slice(0,picked.size()):
    if card.uid not in seen:return
   for card in picked:deck.erase(card)
   for i in range(picked.size()-1,-1,-1):deck.push_front(picked[i])

static func answer(e,target: Dictionary):
 if e.mod_resolution.is_empty() or not choice_valid(e,e.pending.options,target):return
 e.pending={};run_step(e,target);e.revision+=1

static func record_damage(e,target: Dictionary,amount: int):
 var report=e.damage_context.get("mod_result",{})
 if report.is_empty() or e.mod_resolution.is_empty() or report.target!=target or e.mod_resolution.frame.source.uid!=report.source:return
 e.mod_resolution.frame.results[report.key]=int(e.mod_resolution.frame.results.get(report.key,0))+amount
 e.damage_context.erase("mod_result")

static func access(e,c: Dictionary,who: int) -> Dictionary:
 var grant=c.get("mod_access",{})
 return grant if grant.get("owner",-1)==who and grant.get("turn",-1)==e.turn and grant.get("zone","")==c.get("zone","") else {}

static func leave_links(e,before: Dictionary):
 for target in before.get("mod_linked",[]):
  var c=e.find_card(int(target.get("uid",-1)))
  if not c.is_empty() and c.zone=="field" and c.epoch==target.epoch:e.sacrifice(c)

static func state_schema(e,frame: Dictionary,key: String) -> Dictionary:
 var pack_id=e.mod_registry.abilities[frame.ability_id].pack_id
 return e.mod_registry.packs[pack_id].state.get(key,{})
static func state_key(e,frame: Dictionary,key: String) -> String:
 var schema=state_schema(e,frame,key)
 return key+":"+str(frame.owner)+("/"+str(frame.source.uid)+":"+str(frame.source.epoch) if schema.get("scope","")=="source" else "")
static func read_state(e,frame: Dictionary,key: String) -> Variant:
 var pack_id=e.mod_registry.abilities[frame.ability_id].pack_id
 var record=e.mod_state.get(pack_id,{}).get(state_key(e,frame,key),{})
 if record.is_empty() or record.scope=="turn" and record.turn!=e.turn:return null
 if record.scope=="source" and e.find_card(record.source_uid).get("epoch",-1)!=record.source_epoch:return null
 var value=record.value
 return value.duplicate(true) if value is Array or value is Dictionary else value
static func write_state(e,frame: Dictionary,key: String,value: Variant):
 var pack_id=e.mod_registry.abilities[frame.ability_id].pack_id;var schema=state_schema(e,frame,key)
 if not e.mod_state.has(pack_id):e.mod_state[pack_id]={}
 e.mod_state[pack_id][state_key(e,frame,key)]={"value":value,"visibility":schema.visibility,"scope":schema.scope,"turn":e.turn,"owner":frame.owner,"source_uid":frame.source.uid,"source_epoch":frame.source.epoch}
static func reset_source(e,uid: int):
 for pack_id in e.mod_state:
  for key in e.mod_state[pack_id].keys():
   var record=e.mod_state[pack_id][key]
   if record.scope=="source" and record.source_uid==uid:e.mod_state[pack_id].erase(key)
static func projected_state(e,seat: int) -> Dictionary:
 var result={}
 for pack_id in e.mod_state:
  var values={}
  for key in e.mod_state[pack_id]:
   var record=e.mod_state[pack_id][key]
   if record.scope=="turn" and record.turn!=e.turn:continue
   if record.scope=="source" and e.find_card(record.source_uid).get("epoch",-1)!=record.source_epoch:continue
   if record.visibility=="public" or record.visibility=="owner" and record.owner==seat:values[key]=record.duplicate(true)
  if not values.is_empty():result[pack_id]=values
 return result
static func public_data(value: Variant) -> Variant:
 if value is Array:return value.map(func(item):return public_data(item))
 if value is Dictionary:
  var result={}
  for key in value:
   if key not in ["mod_frame","target_spec","original_choice"]:result[key]=public_data(value[key])
  return result
 return value
