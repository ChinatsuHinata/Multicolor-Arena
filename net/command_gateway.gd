extends RefCounted
## Only these player intentions can reach the authoritative rules engine.
static func apply(e,seat: int,command: Dictionary) -> String:
 if not safe_value(command):return "操作数据不合法"
 var name=command.get("name","");var a=command.get("args",[])
 if not a is Array or a.size()>6:return "操作格式错误"
 var count={"mulligan":1,"pass_priority":0,"possession":2,"discard":1,"attack":3,"block":1,"combat_damage":1,"surrender":0,"choose_trigger_order":1,"choose_ward":1,"choose_trigger":1,"choose_return":1,"choose_grave_replacement":1,"choose_effect":1,"choose_timer":1,"commit_cast":3,"commit_ability":4,"commit_extension":4}
 if not count.has(name) or a.size()!=count[name]:return "未知操作"
 if e.winner!=-2:return "本局已结束"
 var needs_pending={"possession":"possession","discard":"discard","block":"block","combat_damage":"damage_assignment","choose_trigger_order":"trigger_order","choose_ward":"ward_order","choose_trigger":"trigger","choose_return":"leader_return","choose_grave_replacement":"grave_replacement","choose_effect":"effect_choice","choose_timer":"timer"}
 if needs_pending.has(name) and (e.pending.get("kind","")!=needs_pending[name] or e.pending.get("owner",-1)!=seat):return "不是你的选择时机"
 var types={"mulligan":[TYPE_ARRAY],"possession":[TYPE_INT,TYPE_INT],"discard":[TYPE_ARRAY],"attack":[TYPE_INT,TYPE_DICTIONARY,TYPE_ARRAY],"block":[TYPE_ARRAY],"combat_damage":[TYPE_DICTIONARY],"choose_trigger_order":[TYPE_INT],"choose_ward":[TYPE_INT],"choose_trigger":[TYPE_DICTIONARY],"choose_return":[TYPE_BOOL],"choose_grave_replacement":[TYPE_BOOL],"choose_effect":[TYPE_DICTIONARY],"choose_timer":[TYPE_INT],"commit_cast":[TYPE_INT,TYPE_DICTIONARY,TYPE_ARRAY],"commit_ability":[TYPE_INT,TYPE_INT,TYPE_DICTIONARY,TYPE_ARRAY],"commit_extension":[TYPE_INT,TYPE_DICTIONARY,TYPE_ARRAY,TYPE_STRING]}
 for i in range(a.size()):
  if typeof(a[i])!=types[name][i]:return "操作参数错误"
 if name in ["mulligan","discard","block"]:
  if a[0].size()>100 or a[0].any(func(v):return not v is int):return "卡牌选择格式错误"
 if name in ["commit_cast","commit_ability","commit_extension","attack"]:
  var plan=a[3] if name=="commit_ability" else a[2]
  for p in plan:
   if not p is Dictionary or not p.get("uid") is int or not p.get("color") is String:return "支付格式错误"
 if name=="attack" and not e.payment_valid(seat,e.attack_cost(seat),a[2]):return "支付方案已失效"
 if name=="combat_damage":
  for k in a[0]:
   if not a[0][k] is int or a[0][k]<0:return "伤害分配错误"
 var before=e.revision;var result
 e.paid_cast_uid=int(command.get("paid_uid",-1))
 if name=="choose_effect" and e.pending.trigger.effect=="cat:grant" and command.has("grant_payment"):
  e.set_granted_payment(command.grant_payment==true);e.revision=before
 if name in ["mulligan","pass_priority","attack","surrender","commit_cast","commit_ability","commit_extension"]:result=e.callv(name,[seat]+a)
 else:result=e.callv(name,a)
 e.paid_cast_uid=-1
 if result is String and not result.is_empty():return result
 return "" if e.revision!=before or e.winner!=-2 else "操作已失效，请按最新状态重试"

static func safe_value(value: Variant,depth: int=0) -> bool:
 if depth>16:return false
 if value is Object or value is Callable or value is Signal:return false
 if value is String:return value.length()<256
 if value is Array:
  if value.size()>600:return false
  for item in value:
   if not safe_value(item,depth+1):return false
 if value is Dictionary:
  if value.size()>80:return false
  for key in value:
   if not key is String and not key is StringName and not key is int:return false
   if key in ["uid","epoch","player","stack_id","paid_uid","index","x"] and not value[key] is int:return false
   if key=="player" and value[key] not in [0,1]:return false
   if not safe_value(value[key],depth+1):return false
 return true
