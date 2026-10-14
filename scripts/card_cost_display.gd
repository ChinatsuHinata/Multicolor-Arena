extends RefCounted
const ORDER=["红","蓝","绿","黄","黑"]
static func for_card(info: Dictionary) -> Dictionary:
 var cost: Dictionary=info.get("cost",{})
 if info.get("token",false) and not info.get("colors",[]).is_empty() and info.get("variable_cost","").is_empty() and cost.values().all(func(n):return int(n)==0):
  return {"/".join(info.colors):0}
 return cost
static func sorted_keys(cost: Dictionary) -> Array:
 var keys=cost.keys()
 keys.sort_custom(func(a,b):
  var ai=ORDER.find(str(a).split("/")[0]);var bi=ORDER.find(str(b).split("/")[0])
  return ai<bi if ai!=bi else str(a)<str(b))
 return keys
static func caption(cost: Dictionary) -> String:
 var keys=sorted_keys(cost)
 var parts=[]
 for key in keys:
  var amount=int(cost[key])
  if amount>0:parts.append(str(key)+str(amount))
 return "费用："+("免费" if parts.is_empty() else "  ".join(parts))
