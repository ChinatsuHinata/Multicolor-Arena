extends RefCounted
## Ranks come from the account store; client supplied ranks are never used.
const EXPAND_MS=20000
const MAX_RANK_STEP=11
const MAX_RANK_TIER=4
var entries={}

static func rank_step(rank: Dictionary) -> int:
 var tier=clampi(int(rank.get("tier",0)),0,4)
 if tier==4:return MAX_RANK_STEP
 var levels=2 if tier==0 else 3
 return [2,5,8,11][tier]-clampi(int(rank.get("level",levels)),1,levels)

static func rank_tier(step: int) -> int:
 for tier in range(MAX_RANK_TIER):
  if step<[2,5,8,11][tier]:return tier
 return MAX_RANK_TIER

func add(id: int,player_id: int,rank: Dictionary,version: String,now: int,mode: String="ranked"):
 if not entries.has(id):entries[id]={"player_id":player_id,"rank_step":rank_step(rank),"version":version,"since":now,"mode":mode}

func remove(id: int):entries.erase(id)

func allowed_rank_gap(id: int,now: int) -> int:
 return clampi((now-int(entries[id].since))/EXPAND_MS,0,MAX_RANK_TIER)

func take_pairs(now: int) -> Array:
 var result=[];var candidates=[];var ids=entries.keys()
 for i in range(ids.size()):
  for j in range(i+1,ids.size()):
   var a=ids[i];var b=ids[j];var first=entries[a];var second=entries[b]
   if first.player_id==second.player_id or first.version!=second.version or first.mode!=second.mode:continue
   var gap=absi(int(first.rank_step)-int(second.rank_step))
   var tier_gap=absi(rank_tier(int(first.rank_step))-rank_tier(int(second.rank_step)))
   if first.mode in ["casual","exploration","exploration_random"]:gap=0;tier_gap=0
   elif tier_gap>maxi(allowed_rank_gap(a,now),allowed_rank_gap(b,now)):continue
   candidates.append({"pair":[a,b],"tier_gap":tier_gap,"gap":gap,"since":mini(int(first.since),int(second.since)),"later_since":maxi(int(first.since),int(second.since)),"order":i*ids.size()+j})
 candidates.sort_custom(func(a,b):
  if a.tier_gap!=b.tier_gap:return a.tier_gap<b.tier_gap
  if a.gap!=b.gap:return a.gap<b.gap
  if a.since!=b.since:return a.since<b.since
  if a.later_since!=b.later_since:return a.later_since<b.later_since
  return a.order<b.order)
 for candidate in candidates:
  var pair=candidate.pair
  if not entries.has(pair[0]) or not entries.has(pair[1]):continue
  if entries[pair[1]].since<entries[pair[0]].since:pair.reverse()
  result.append(pair);remove(pair[0]);remove(pair[1])
 return result
