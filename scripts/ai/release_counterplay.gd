extends RefCounted
## Authored release tactics. No trained weights or experiment files are loaded.
const Matchup=preload("res://scripts/ai/matchup.gd")
const Observation=preload("res://scripts/ai/observation.gd")
const SCHEMA="multicolor.ai.release_counterplay.v1"
const PATH="res://data/release_counterplay.json"
const DEFAULT_POLICY={"target_bonus":0,"night_bonus":0,"castle_bonus":0,"queen_bonus":0,"life_loss_threshold":12}
const LIMITS={"target_bonus":[0,2000],"night_bonus":[0,200],"castle_bonus":[0,200],"queen_bonus":[0,200],"life_loss_threshold":[12,15]}
static var cached: Dictionary={}
static var loaded=false

static func valid_policy(value) -> bool:
 if not value is Dictionary:return false
 var support=value.get("support_targets",{})
 if not support is Dictionary or support.size()>16:return false
 for id in support:
  var bonus=support[id]
  if not id is String or id.is_empty() or not (bonus is int or bonus is float):return false
  if not is_finite(float(bonus)) or float(bonus)!=int(bonus) or bonus<0 or bonus>2000:return false
 for flag in ["reimu_seal","reimu_probe"]:
  if value.has(flag) and not value[flag] is bool:return false
 for field in LIMITS:
  var number=value.get(field)
  if not (number is int or number is float):return false
  if not is_finite(float(number)) or float(number)!=int(number):return false
  if number<LIMITS[field][0] or number>LIMITS[field][1]:return false
 return true

static func library() -> Dictionary:
 if not loaded:
  loaded=true
  if FileAccess.file_exists(PATH):
   var parsed=JSON.parse_string(FileAccess.get_file_as_string(PATH))
   if parsed is Dictionary:cached=parsed
 return cached

static func select(e,who: int,bundle=null) -> Dictionary:
 if bundle==null:bundle=library()
 var context=Matchup.identify(e,who)
 var result={"matchup":context,"source":"generic","reason":"no_counterplay","label":"通用蕾米速攻","category":"通用","policy":DEFAULT_POLICY.duplicate()}
 if context.own_key!="74":result.reason="unsupported_own_leaders";return result
 if context.key.is_empty():result.reason="unknown_opponent";return result
 if not bundle is Dictionary or bundle.get("schema","")!=SCHEMA or not bundle.get("entries") is Dictionary or not valid_policy(bundle.get("generic")):
  result.reason="invalid_library";return result
 result.policy=bundle.generic.duplicate()
 var entry=bundle.entries.get(context.key,{})
 if not entry is Dictionary or entry.is_empty():return result
 if entry.get("own_leaders")!=context.own_leaders or entry.get("opponent_leaders")!=context.opponent_leaders:
  result.reason="mismatched_counterplay";return result
 if not valid_policy(entry.get("policy")) or not entry.get("label") is String or entry.label.is_empty() or not entry.get("plan") is String or entry.plan.is_empty():
  result.reason="invalid_counterplay";return result
 result.source="counterplay";result.reason="known_matchup";result.label=entry.label;result.policy=entry.policy.duplicate()
 var review=entry.get("review",{})
 if review is Dictionary and review.get("category","") is String and not review.get("category","").is_empty():result.category=review.category
 return result

static func record(e,who: int):
 var routing=select(e,who)
 e.ai_memory[who].counterplay_routing=routing

static func live_leaders(e,who: int) -> Array:
 var registered=e.leaders(1-who).map(func(c):return c.uid)
 return e.units(1-who).filter(func(c):return c.uid in registered and e.has_leader_ability(c) and not e.Cat.State.activation_locked(e,c))

static func field_policy(e,who: int) -> Dictionary:
 # Identity selects the entry; only a publicly present core changes priorities.
 if live_leaders(e,who).is_empty():return DEFAULT_POLICY
 return select(e,who).policy

static func target_bonus(e,c: Dictionary) -> int:
 if c.get("owner",-1) not in [0,1] or c.get("zone","")!="field":return 0
 var who=1-c.owner
 var policy=select(e,who).policy
 # Matchup evidence may identify ordinary copies as the engine that rebuilds
 # the opposing board. Only an actually present, controlled unit qualifies.
 if not e.units(1-who).any(func(u):return u.uid==c.uid):return 0
 var bonus=int(policy.get("support_targets",{}).get(c.card_id,0))
 if live_leaders(e,who).any(func(u):return u.uid==c.uid):bonus=maxi(bonus,int(policy.target_bonus))
 return bonus

static func reimu_scope(e,who: int) -> bool:
 # A normal Reimu in Patchouli/other decks enables the very same public
 # Dreams Seal role. Routing identity stays unchanged; the board supplies risk.
 return select(e,who).policy.get("reimu_seal",false) or not reimu_units(e,who).is_empty()

static func reimu_probe_scope(e,who: int) -> bool:
 return select(e,who).policy.get("reimu_probe",false)

static func reimu_units(e,who: int) -> Array:
 return e.units(1-who).filter(func(c):return e.Roster.character_matches(e.cards[c.card_id].character,"博丽灵梦"))

static func reimu_seal_risk(e,who: int) -> bool:
 if not reimu_scope(e,who) or reimu_units(e,who).is_empty():return false
 var enemy=1-who
 if e.Pack.response_locked(e,enemy) or e.players[enemy].hand.is_empty():return false
 var known=Observation.known_hand(e,who)
 if not e.players[enemy].hand.any(func(c):return not known.has(str(c.uid)) or known[str(c.uid)].card_id=="100"):return false
 # Possible Dreams Seal, inferred from public role/mana and an unknown slot.
 # Never read that slot's real identity. Use the spell's actual discounted cost.
 var probe={"card_id":"100","owner":enemy,"uid":-9300,"epoch":0,"zone":"hand","leader":false,"token":false}
 return e.Cat.State.cast_error(e,probe,enemy).is_empty() and e.payment(enemy,e.cast_cost(enemy,probe)).ways>0

static func reimu_night_needed(e,who: int) -> bool:
 if not reimu_scope(e,who) or reimu_units(e,who).is_empty():return false
 if e.Pack.response_locked(e,1-who) or e.players[1-who].hand.is_empty():return false
 return reimu_seal_risk(e,who) or e.source_resources(1-who).size()>=4
