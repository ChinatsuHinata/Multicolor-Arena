extends RefCounted
## A private payment proposal. Fixed reservations are kept until the player removes them.
static func solve(engine,who:int,cost:Dictionary,fixed:Array=[],excluded:Array=[]) -> Dictionary:
 var sources=engine.source_resources(who);var used=excluded.duplicate()
 for p in fixed:
  if p.uid in used or not sources.any(func(s):return s.uid==p.uid and p.color in s.colors):return {"ways":0,"score":999999,"plan":[]}
  used.append(p.uid)
 return assign_fixed(engine,who,cost,fixed,used,0,{})
static func assign_fixed(engine,who:int,cost:Dictionary,fixed:Array,excluded:Array,index:int,memo:Dictionary) -> Dictionary:
 if index==fixed.size():
  var result=engine.payment(who,cost,excluded).duplicate(true)
  if result.ways>0:result.plan=fixed.duplicate(true)+result.plan
  return result
 var key=str(index)+JSON.stringify(cost)
 if memo.has(key):return memo[key]
 var best={"ways":0,"score":999999,"plan":[]}
 for group in cost:
  if cost[group]<=0 or fixed[index].color not in group.split("/"):continue
  var next=cost.duplicate();next[group]-=1
  var candidate=assign_fixed(engine,who,next,fixed,excluded,index+1,memo)
  if candidate.ways>0 and candidate.score<best.score:best=candidate
 memo[key]=best
 return best
static func options(engine,who:int,cost:Dictionary,plan:Array,excluded:Array=[]) -> Array:
 var result=[]
 for source in engine.source_resources(who):
  if source.uid in excluded:continue
  if plan.any(func(p):return p.uid==source.uid):
   result.append(source);continue
  var best={};var score=999999
  for color in source.colors:
   var solution=solve(engine,who,cost,plan+[{"uid":source.uid,"color":color}],excluded)
   if solution.ways>0 and solution.score<score:best={"uid":source.uid,"color":color};score=solution.score
  if not best.is_empty():
   var candidate=source.duplicate(true);candidate.reservation=best;result.append(candidate)
 return result
