extends RefCounted
## One action representation for planners, offline agents and execution.
static func apply(e,who: int,a: Dictionary,caster: Callable=Callable()) -> bool:
 if e.winner!=-2 or e.priority!=who:return false
 var before=e.revision
 match a.get("kind",""):
  "cast":
   var c=e.find_card(int(a.get("uid",-1)))
   if c.is_empty() or c.get("ai_unknown",false) or not e.cast_error(who,c.uid).is_empty():return false
   var target=a.get("target",{})
   if caster.is_valid():return caster.call(e,who,c,target)
   var pay=e.payment(who,e.cast_cost(who,c,target))
   var plan=a.get("payment",pay.plan)
   return pay.ways>0 and e.commit_cast(who,c.uid,target,plan).is_empty()
  "attack":
   if not e.can_attack(who,int(a.get("uid",-1))):return false
   var pay=e.payment(who,e.attack_cost(who))
   if pay.ways==0:return false
   e.attack(who,a.uid,a.get("target",{}),a.get("payment",pay.plan))
  "extension":
   var c=e.find_card(int(a.get("uid",-1)))
   if c.is_empty():return false
   var target=a.get("target",{});var key=a.get("key","")
   var pay=e.payment(who,e.extension_cost(who,c,key,target))
   return pay.ways>0 and e.commit_extension(who,c.uid,target,a.get("payment",pay.plan),key).is_empty()
  "ability":
   var target=a.get("target",{});var uid=int(a.get("uid",-1));var index=int(a.get("index",-1))
   var pay=e.payment(who,e.ability_cost(who,uid,index,target))
   return pay.ways>0 and e.commit_ability(who,uid,index,target,a.get("payment",pay.plan)).is_empty()
  "ran_discount":return e.toggle_ran_discount(who,int(a.get("uid",-1))).is_empty()
  "pass":e.pass_priority(who)
  "possession":
   if e.pending.get("kind","")!="possession" or e.pending.owner!=who:return false
   e.possession(a.get("palette_uid",-1),a.get("hand_uid",-1))
  _:return false
 return e.revision!=before

static func main_candidates(e,who: int,target_policy: Callable,limit: int=48) -> Array:
 var result=[]
 if e.active!=who or e.priority!=who or e.phase!="main" or not e.pending.is_empty() or not e.stack.is_empty() or not e.combat.is_empty():return result
 for c in e.legal_casts(who):
  if c.get("ai_unknown",false):continue
  var t=target_policy.call(e,who,c)
  if not t.is_empty():result.append({"kind":"cast","uid":c.uid,"card_id":c.card_id,"target":t})
  if result.size()>=limit:break
 for c in e.units(who):
  if e.can_attack(who,c.uid):result.append({"kind":"attack","uid":c.uid})
 result.append({"kind":"pass"})
 return result
