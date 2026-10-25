extends RefCounted
## A private payment proposal. Selected sources can be reassigned to any of their colors.
static func solve_costs(engine,who:int,costs:Array,fixed:Array=[],excluded:Array=[],keep: Array=[]) -> Dictionary:
 var best={"ways":0,"score":999999,"plan":[]}
 for cost in costs:
  var candidate=solve(engine,who,cost,fixed,excluded,keep)
  if candidate.ways>0 and candidate.score<best.score:best=candidate
 return best
static func solve(engine,who:int,cost:Dictionary,fixed:Array=[],excluded:Array=[],keep: Array=[]) -> Dictionary:
 var sources=engine.source_resources(who);var used=excluded.duplicate();var reserved=[]
 for p in fixed:
  if p.uid in used or not sources.any(func(s):return s.uid==p.uid and p.color in s.colors):return {"ways":0,"score":999999,"plan":[]}
  used.append(p.uid);reserved.append({"uid":p.uid,"colors":[p.color]})
 return assign_sources(engine,who,cost,reserved,used,0,{},keep)
static func solve_selected_costs(engine,who:int,costs:Array,selected:Array,excluded:Array=[],keep: Array=[]) -> Dictionary:
 var sources=engine.source_resources(who);var used=excluded.duplicate();var reserved=[]
 var best={"ways":0,"score":999999,"plan":[]}
 for p in selected:
  var matches=sources.filter(func(s):return s.uid==p.uid)
  if p.uid in used or matches.is_empty():return best
  used.append(p.uid);reserved.append(matches[0])
 for cost in costs:
  var candidate=assign_sources(engine,who,cost,reserved,used,0,{},keep)
  if candidate.ways>0 and candidate.score<best.score:best=candidate
 return best
static func assign_sources(engine,who:int,cost:Dictionary,reserved:Array,excluded:Array,index:int,memo:Dictionary,keep: Array=[]) -> Dictionary:
 var key=str(index)+JSON.stringify(cost)
 if memo.has(key):return memo[key]
 if index==reserved.size():
  memo[key]=engine.payment(who,cost,excluded,keep).duplicate(true)
  return memo[key]
 var best={"ways":0,"score":999999,"plan":[]}
 for color in reserved[index].colors:
  var remainders=[]
  if color=="黄/绿":
   for yellow_group in cost:
    if cost[yellow_group]<=0 or "黄" not in yellow_group.split("/"):continue
    var after_yellow=cost.duplicate();after_yellow[yellow_group]-=1
    for green_group in cost:
     if after_yellow[green_group]<=0 or "绿" not in green_group.split("/"):continue
     var next=after_yellow.duplicate();next[green_group]-=1;remainders.append(next)
  else:
   for group in cost:
    if cost[group]<=0 or color not in group.split("/"):continue
    var next=cost.duplicate();next[group]-=1;remainders.append(next)
  for next in remainders:
   var candidate=assign_sources(engine,who,next,reserved,excluded,index+1,memo,keep)
   if candidate.ways>0 and candidate.score<best.score:
    best=candidate.duplicate(true)
    best.plan.push_front({"uid":reserved[index].uid,"color":color})
 memo[key]=best
 return best
static func options(engine,who:int,cost:Dictionary,plan:Array,excluded:Array=[],keep: Array=[]) -> Array:
 return options_for_costs(engine,who,[cost],plan,excluded,keep)
static func options_for_costs(engine,who:int,costs:Array,plan:Array,excluded:Array=[],keep: Array=[]) -> Array:
 var result=[]
 for source in engine.source_resources(who):
  if source.uid in excluded:continue
  if plan.any(func(p):return p.uid==source.uid):
   result.append(source);continue
  var solution=solve_selected_costs(engine,who,costs,plan+[{"uid":source.uid}],excluded,keep)
  if solution.ways>0:
   var candidate=source.duplicate(true)
   candidate.reservation=solution.plan.filter(func(p):return p.uid==source.uid)[0]
   result.append(candidate)
 return result
