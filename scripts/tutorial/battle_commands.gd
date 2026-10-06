extends RefCounted
## Portable intentions contain scenario aliases, never transient UIDs/epochs.
const LABELS={"cast":"使用卡牌","ability":"启动异能","attack":"宣言攻击","block":"宣言阻挡","pass_priority":"让过执行权","possession":"凭依","mulligan":"起手调度","discard":"弃牌","choose_trigger":"触发目标","choose_effect":"效果选择","choose_trigger_order":"触发排序","choose_ward":"守护排序","choose_return":"自机回手","choose_grave_replacement":"墓地替换","choose_timer":"时间指示物","combat_damage":"伤害分配","delay":"等待","toggle_ran_discount":"切换减费","toggle_murder_dolls_skip":"切换空场跳过"}

static func card_ref(adapter,uid: int) -> Dictionary:
 for alias in adapter.aliases:
  if int(adapter.aliases[alias])==uid:return {"alias":alias}
 if uid>=adapter.created_origin and not adapter.engine.find_card(uid).is_empty():return {"created":uid-adapter.created_origin}
 return {}

static func target(adapter,value: Dictionary) -> Dictionary:
 var result={}
 if value.has("uid"):result=card_ref(adapter,int(value.uid))
 if value.has("stack_id"):
  for entry in adapter.engine.unresolved_stack_entries():
   if int(entry.id)==int(value.stack_id):
    result.stack=card_ref(adapter,int(entry.get("card",entry.get("source",{})).get("uid",-1)))
 for key in ["player","none","mode","color","x","selection_id","pay","self","free"]:
  if value.has(key):result[key]=value[key]
 if value.has("sacrifice"):result.sacrifice=target(adapter,value.sacrifice)
 if value.has("parts"):result.parts=value.parts.map(func(item):return target(adapter,item))
 if value.has("picks"):
  result.picks=[]
  for group in value.picks:result.picks.append(group.map(func(item):return target(adapter,item)))
 if value.has("plan"):result.payment=payment(adapter,value.plan)
 if value.has("payment"):result.payment=payment(adapter,value.payment)
 return result

static func payment(adapter,plan: Array) -> Array:
 var result=[]
 for source in plan:
  var item={"color":source.color}
  if int(source.uid)<0:item.resource=int(source.uid)
  else:item.card=card_ref(adapter,int(source.uid))
  result.append(item)
 return result

static func encode(adapter,seat: int,command: Dictionary) -> Dictionary:
 var name=command.name;var args=command.args
 var action={"type":name,"player":seat}
 match name:
  "commit_cast":
   action.type="cast";action.card=card_ref(adapter,int(args[0]));action.target=target(adapter,args[1]);action.payment=payment(adapter,args[2])
   if action.card.is_empty():action.card={"card_id":adapter.engine.find_card(int(args[0])).get("card_id","")}
   if adapter.engine.paid_cast_uid==int(args[0]):action.pay_colors=true
  "commit_ability":
   action.type="ability";action.source=card_ref(adapter,int(args[0]));action.index=int(args[1]);action.target=target(adapter,args[2]);action.payment=payment(adapter,args[3])
  "commit_extension":
   action.type="ability";action.source=card_ref(adapter,int(args[0]));action.key=args[3];action.target=target(adapter,args[1]);action.payment=payment(adapter,args[2])
  "attack":
   action.card=card_ref(adapter,int(args[0]));action.target=target(adapter,args[1]);action.payment=payment(adapter,args[2])
  "toggle_ran_discount","toggle_murder_dolls_skip":action.card=card_ref(adapter,int(args[0]))
  "block","discard","mulligan":action.cards=args[0].map(func(uid):return card_ref(adapter,int(uid)))
  "possession":
   if int(args[0])>=0:action.palette=card_ref(adapter,int(args[0]));action.hand=card_ref(adapter,int(args[1]))
  "choose_trigger","choose_effect":
   action.target=target(adapter,args[0])
   if name=="choose_effect" and adapter.engine.pending.get("trigger",{}).get("effect")=="cat:grant":action.grant_payment=adapter.engine.paid_cast_uid>=0
  "choose_trigger_order","choose_ward":action.index=int(args[0])
  "choose_return","choose_grave_replacement":action.yes=args[0]
  "choose_timer":action.value=int(args[0])
  "combat_damage":
   action.assignments=[]
   for uid in args[0]:action.assignments.append({"card":card_ref(adapter,int(uid)),"amount":int(args[0][uid])})
  "pass_priority":pass
  _:return {}
 return action

static func payment_plan(adapter,items: Array) -> Dictionary:
 var plan=[]
 for item in items:
  var uid=int(item.resource) if item.has("resource") else int(adapter.resolve_card(item.card).get("uid",-1))
  if uid==-1 and not item.has("resource"):return {"available":false}
  plan.append({"uid":uid,"color":item.color})
 return {"available":true,"value":plan}

static func matches(adapter,expected: Variant,actual: Variant) -> bool:
 if expected is Dictionary:
  if not actual is Dictionary:return false
  if expected.is_empty():return actual.is_empty()
  if expected.has("card_id") and actual.has("alias"):
   if adapter.entity(actual.alias).get("card_id","")!=expected.card_id:return false
   var rest=expected.duplicate();rest.erase("card_id");return rest.is_empty() or matches(adapter,rest,actual)
  for key in expected:
   if key=="payment":continue
   if not actual.has(key) or not matches(adapter,expected[key],actual[key]):return false
  return true
 if expected is Array:
  if not actual is Array or expected.size()!=actual.size():return false
  for i in range(expected.size()):
   if not matches(adapter,expected[i],actual[i]):return false
  return true
 return expected==actual

static func caption(adapter,action: Dictionary) -> String:
 var value=("我方 · " if int(action.get("player",0))==0 else "对方 · ")+LABELS.get(action.get("type"),action.get("type","?"))
 for key in ["card","source"]:
  if action.has(key):
   var card=adapter.resolve_card(action[key])
   value+=" · "+adapter.engine.cards.get(card.get("card_id",action[key].get("card_id","")),{}).get("name",str(action[key]))
 if action.has("cards") and not action.cards.is_empty():
  value+=" · "+", ".join(action.cards.map(func(ref):return adapter.engine.cards.get(adapter.resolve_card(ref).get("card_id",""),{}).get("name",str(ref))))
 return value
