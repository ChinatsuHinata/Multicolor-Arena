extends RefCounted
## X bounds use the same cost transformations and payment solver as declarations.
static func capacity(e,who: int) -> int:
 var total=0
 for source in e.source_resources(who):total+=2 if source.has("pair") else 1
 return total
static func limit(e,id: String,who: int) -> int:
 var c=e.catalogue_x_source
 if c.is_empty():c={"uid":-999999,"card_id":id,"owner":who,"zone":"hand"}
 if e.Roster.free_cast(e,c,who):return maxi(0,e.catalogue_x_override)
 var budget=capacity(e,who)
 var counters=e.Cat.counter_total(e,e.units(who)) if e.Cat.has(e,c,"spell-fdf-053") else 0
 if e.debug_enabled and e.debug_free_payment:return maxi(e.catalogue_x_override,budget+counters)
 var low=0;var high=maxi(1,budget+counters+1)
 while within_budget(e,c,who,high,budget,counters):
  # A fixed/free override does not buy an arbitrary X declaration.
  if e.cast_cost_options(who,c,{"x":high,"counter_payment":mini(high,counters)})==e.cast_cost_options(who,c,{"x":high*2,"counter_payment":mini(high*2,counters)}):return maxi(0,e.catalogue_x_override)
  low=high;high*=2
 while high-low>1:
  var middle=(low+high)/2
  if within_budget(e,c,who,middle,budget,counters):low=middle
  else:high=middle
 return maxi(low,e.catalogue_x_override)
static func within_budget(e,c: Dictionary,who: int,x: int,budget: int,counters: int) -> bool:
 for cost in e.cast_cost_options(who,c,{"x":x,"counter_payment":mini(x,counters)}):
  var total=0
  for amount in cost.values():total+=int(amount)
  if total<=budget:return true
 return false
static func cheapest_target(e,who: int,option: Dictionary) -> Dictionary:
 if not option.has("selection"):return option
 var target=option.duplicate(true);target.erase("selection");target.picks=[]
 var previous=[]
 for group in option.selection:
  var pool=group.pool.duplicate()
  pool.sort_custom(func(a,b):return e.Cat.target_tax(e,who,a)<e.Cat.target_tax(e,who,b))
  var picks=[]
  for ref in pool:
   if picks.size()>=int(group.min):break
   if ref in picks or group.get("exclude_previous",false) and ref in previous:continue
   picks.append(ref)
  if picks.size()<int(group.min):return {}
  target.picks.append(picks);previous.append_array(picks)
 return target
static func payable(e,who: int,options: Array,costs: Callable,excluded: Array=[]) -> Array:
 var cache={};var result=[]
 for option in options:
  if not option.has("x") and not option.get("x_input",false):result.append(option);continue
  var target=cheapest_target(e,who,option)
  if target.is_empty():continue
  var candidates=costs.call(target);var key=JSON.stringify(candidates)
  if not cache.has(key):cache[key]=candidates.any(func(cost):return e.payment(who,cost,excluded).ways>0)
  if cache[key]:result.append(option)
 return result
