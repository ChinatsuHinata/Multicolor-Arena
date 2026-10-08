extends RefCounted
## Ratings come from the account store; client supplied ratings are never used.
const INITIAL_GAP=100
const EXPAND_MS=60000
const GAP_STEP=100
var entries={}

func add(id: int,player_id: int,elo: int,version: String,now: int):
 if not entries.has(id):entries[id]={"player_id":player_id,"elo":elo,"version":version,"since":now}

func remove(id: int):entries.erase(id)

func allowed_gap(id: int,now: int) -> int:
 return INITIAL_GAP+maxi(0,(now-int(entries[id].since))/EXPAND_MS)*GAP_STEP

func take_pairs(now: int) -> Array:
 var result=[];var candidates=[];var ids=entries.keys()
 for i in range(ids.size()):
  for j in range(i+1,ids.size()):
   var a=ids[i];var b=ids[j];var first=entries[a];var second=entries[b]
   if first.player_id==second.player_id or first.version!=second.version:continue
   var gap=absi(int(first.elo)-int(second.elo))
   if gap>maxi(allowed_gap(a,now),allowed_gap(b,now)):continue
   candidates.append({"pair":[a,b],"gap":gap,"since":mini(int(first.since),int(second.since)),"order":i*ids.size()+j})
 candidates.sort_custom(func(a,b):
  if a.gap!=b.gap:return a.gap<b.gap
  if a.since!=b.since:return a.since<b.since
  return a.order<b.order)
 for candidate in candidates:
  var pair=candidate.pair
  if not entries.has(pair[0]) or not entries.has(pair[1]):continue
  if entries[pair[1]].since<entries[pair[0]].since:pair.reverse()
  result.append(pair);remove(pair[0]);remove(pair[1])
 return result
