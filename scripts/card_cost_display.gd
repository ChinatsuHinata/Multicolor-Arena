extends RefCounted
const ORDER=["红","蓝","绿","黄","黑"]
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
