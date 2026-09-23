extends RefCounted
## A slash-separated cost key is one shared pool, not separate color requirements.
static func assign(cost: Dictionary,colors: Array,index: int=0) -> Dictionary:
 if index>=colors.size(): return {"ok":true,"remaining":cost}
 var keys=cost.keys()
 keys.sort_custom(func(a,b): return a.split("/").size()<b.split("/").size())
 for key in keys:
  if cost[key]<=0 or colors[index] not in key.split("/"): continue
  var next=cost.duplicate(); next[key]-=1
  var result=assign(next,colors,index+1)
  if result.ok: return result
 return {"ok":false,"remaining":{}}
static func allows(cost: Dictionary,plan: Array,color: String) -> bool:
 var colors=[]
 for p in plan:colors.append_array(str(p.color).split("/"))
 colors.append_array(color.split("/"))
 return assign(cost,colors).ok
static func remaining(cost: Dictionary,plan: Array) -> Dictionary:
 var colors=[]
 for p in plan:colors.append_array(str(p.color).split("/"))
 return assign(cost,colors)
