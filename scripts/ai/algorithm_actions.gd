extends RefCounted
## Enumerate targets/modes/selections and distinct resource payments, independently
## of deck priorities. Every bound is reported; this is a main-phase action space.
const Picker=preload("res://scripts/target_picker.gd")
const Action=preload("res://scripts/ai/action.gd")

static func canonical(value: Variant) -> Variant:
 if value is Dictionary:
  var out={};var keys=value.keys();keys.sort()
  for key in keys:out[key]=canonical(value[key])
  return out
 if value is Array:return value.map(func(v):return canonical(v))
 return value

static func key(a: Dictionary) -> String:return JSON.stringify(canonical(a))
static func id(a: Dictionary) -> int:return ("0x"+key(a).sha256_text().left(12)).hex_to_int()

static func targets(options: Array,limit: int=128) -> Dictionary:
 var result=[];var picker=Picker.new();picker.configure(options,"enumerate")
 var ctx={"nodes":0,"truncated":false,"seen":{}}
 target_walk(picker,[],result,limit,ctx)
 return {"targets":result,"truncated":ctx.truncated}

static func target_walk(picker,path: Array,out: Array,limit: int,ctx: Dictionary):
 if out.size()>=limit or ctx.nodes>=4096:ctx.truncated=true;return
 ctx.nodes+=1;picker.path=path.duplicate(true);picker.normalize()
 if picker.ready():
  var target=picker.option();var signature=key(target)
  if not ctx.seen.has(signature):ctx.seen[signature]=true;out.append(target)
  return
 var prefix=picker.path.duplicate(true);var offered=picker.available()
 for atom in offered:
  picker.path=prefix.duplicate(true)
  if picker.select(atom):target_walk(picker,picker.path.duplicate(true),out,limit,ctx)

static func payments(e,who: int,cost: Dictionary,limit: int=8,excluded: Array=[]) -> Dictionary:
 var best=e.payment(who,cost,excluded)
 if best.ways==0:return {"plans":[],"truncated":false}
 var out=[best.plan];var groups=cost.keys();var needs=groups.map(func(k):return int(cost[k]))
 var ctx={"nodes":0,"truncated":false,"seen":{key({"plan":best.plan}):true}}
 payment_walk(e,who,e.source_resources(who).filter(func(s):return s.uid not in excluded),0,groups,needs,[],out,limit,ctx,cost)
 return {"plans":out,"truncated":ctx.truncated}

static func payment_walk(e,who: int,sources: Array,index: int,groups: Array,needs: Array,plan: Array,out: Array,limit: int,ctx: Dictionary,cost: Dictionary):
 if needs.all(func(n):return n<=0):
  var signature=key({"plan":plan})
  if not ctx.seen.has(signature) and e.payment_valid(who,cost,plan):
   if out.size()>=limit:ctx.truncated=true;return
   ctx.seen[signature]=true;out.append(plan.duplicate(true))
  return
 if index>=sources.size():return
 if ctx.nodes>=4096 or out.size()>limit:ctx.truncated=true;return
 ctx.nodes+=1
 if needs.reduce(func(n,v):return n+v,0)>2*(sources.size()-index):return
 var source=sources[index]
 for color in source.colors:
  for i in range(groups.size()):
   if needs[i]<=0 or color not in str(groups[i]).split("/"):continue
   var next=needs.duplicate();next[i]-=1
   payment_walk(e,who,sources,index+1,groups,next,plan+[{"uid":source.uid,"color":color}],out,limit,ctx,cost)
 if source.has("pair"):
  for i in range(groups.size()):
   if needs[i]<=0 or source.pair[0] not in str(groups[i]).split("/"):continue
   for j in range(groups.size()):
    var next=needs.duplicate();next[i]-=1
    if next[j]<=0 or source.pair[1] not in str(groups[j]).split("/"):continue
    next[j]-=1
    payment_walk(e,who,sources,index+1,groups,next,plan+[{"uid":source.uid,"color":"黄/绿"}],out,limit,ctx,cost)
 payment_walk(e,who,sources,index+1,groups,needs,plan,out,limit,ctx,cost)

static func menu(e,who: int,max_actions: int=256) -> Dictionary:
 var result={"actions":[],"truncated":false,"unsupported":[],"scope":"main_decisions_with_heuristic_responses","payment_limit":8,"target_limit":128}
 if e.winner!=-2:return result
 if e.phase!="main" or e.active!=who or e.priority!=who or not e.pending.is_empty() or not e.stack.is_empty() or not e.combat.is_empty() or not e.entry_choices.is_empty():
  result.unsupported.append("not_a_clean_main_decision");return result
 var seen={}
 # Pass is always represented, including when an enumeration budget is reached.
 append_action(result,seen,{"kind":"pass"},max_actions)
 for c in e.legal_casts(who):
  if c.get("ai_unknown",false) or c.card_id=="back" or c.zone=="deck":continue
  var options=e.targets_for(c.card_id,who,c.uid)
  if options.is_empty() and e.cards[c.card_id].kind!="符卡":options=[{"none":true}]
  var expanded=targets(options)
  result.truncated=result.truncated or expanded.truncated
  for target in expanded.targets:
   if e.cards[c.card_id].kind=="符卡" and not e.Pack.choice_valid(e,options,target):continue
   paid_actions(e,who,{"kind":"cast","uid":c.uid,"card_id":c.card_id,"target":target},e.cast_cost(who,c,target),result,seen,max_actions)
 for c in e.players[who].field+e.players[who].grave:
  for a in e.available_actions(who,c.uid):
   match a.type:
    "attack":paid_actions(e,who,{"kind":"attack","uid":c.uid},e.attack_cost(who),result,seen,max_actions)
    "direct_attack":
     for enemy in e.units(1-who):
      if e.Pack.direct_attack(e,c) or enemy.has("rank_target"):paid_actions(e,who,{"kind":"attack","uid":c.uid,"target":e.ref_target(enemy)},e.attack_cost(who),result,seen,max_actions)
    "extension","ability":
     var options=e.activation_options(c,a.key) if a.type=="extension" else e.ability_targets()
     var expanded=targets(options);result.truncated=result.truncated or expanded.truncated
     for target in expanded.targets:
      var action={"kind":a.type,"uid":c.uid,"target":target}
      var cost={};var excluded=[]
      if a.type=="extension":action.key=a.key;cost=e.extension_cost(who,c,a.key,target)
      else:
       action.index=a.index;cost=e.ability_cost(who,c.uid,a.index,target)
       if e.ability_parameters(c.uid,a.index).get("横置",false):excluded=[c.uid]
      paid_actions(e,who,action,cost,result,seen,max_actions,excluded)
    "ran_discount":append_action(result,seen,{"kind":"ran_discount","uid":c.uid},max_actions)
    _:result.unsupported.append(a.type)
 return result

static func paid_actions(e,who: int,action: Dictionary,cost: Dictionary,result: Dictionary,seen: Dictionary,limit: int,excluded: Array=[]):
 var choices=payments(e,who,cost,8,excluded);result.truncated=result.truncated or choices.truncated
 for plan in choices.plans:
  var paid=action.duplicate(true);paid.payment=plan
  append_action(result,seen,paid,limit)

static func append_action(result: Dictionary,seen: Dictionary,action: Dictionary,limit: int):
 var signature=key(action)
 if seen.has(signature):return
 if result.actions.size()>=limit:result.truncated=true;return
 seen[signature]=true;result.actions.append({"id":id(action),"action":action})
