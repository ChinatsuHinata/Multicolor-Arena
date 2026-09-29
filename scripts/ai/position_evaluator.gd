extends RefCounted
## Versioned, exportable features. Weights may be fitted offline, never in a match.
const SCHEMA="multicolor.ai.value.v1"
const STRATEGIC_SCHEMA="multicolor.ai.value.v2"
const Strategic=preload("res://scripts/ai/strategic_features.gd")
const DEFAULT_WEIGHTS={"life_margin":12.0,"board_margin":2.0,"hand_margin":6.0,"role_ready":35.0,"color_sources":12.0,"ready_damage":10.0,"incoming_damage":-18.0,"fragile_units":-5.0,"mana":1.0}

static func features(e,who: int) -> Dictionary:
 var f={"life_margin":float(e.players[who].life-e.players[1-who].life),"board_margin":0.0,"hand_margin":float(e.players[who].hand.size()-e.players[1-who].hand.size()),"role_ready":0.0,"color_sources":0.0,"ready_damage":0.0,"incoming_damage":0.0,"fragile_units":0.0,"mana":float(e.source_resources(who).size())}
 var colors=[]
 for seat in range(2):
  for c in e.units(seat):
   var value=maxi(0,e.stat(c,"power"))+maxi(0,e.stat(c,"health")-c.damage)+maxi(0,e.stat(c,"spirit"))
   f.board_margin+=value if seat==who else -value
   if seat==who:
    if e.stat(c,"health")-c.damage<=1:f.fragile_units+=1
    for color in e.Pack.colors(e,c):
     if color not in colors:colors.append(color)
    if c.uid==e.players[who].leader.uid:f.role_ready=1.0
    if not c.tapped and not e.summoning_sick(c):f.ready_damage+=maxi(0,e.stat(c,"spirit"))
   elif not c.tapped and not e.summoning_sick(c):f.incoming_damage+=maxi(0,e.stat(c,"spirit"))
 # Persistent items/fields can also supply a leader's color requirements.
 for c in e.players[who].field:
  if e.cards[c.card_id].kind=="符卡":continue
  for color in e.Pack.colors(e,c):
   if color not in colors:colors.append(color)
 var requirements=e.cards[e.players[who].leader.card_id].colors
 if requirements.all(func(color):return color in colors):f.color_sources=1.0
 return f

static func score_features(f: Dictionary,weights: Dictionary={}) -> float:
 var w=DEFAULT_WEIGHTS if weights.is_empty() else weights
 var score=0.0
 for key in DEFAULT_WEIGHTS:score+=float(f.get(key,0.0))*float(w.get(key,DEFAULT_WEIGHTS[key]))
 for key in Strategic.KEYS:score+=float(f.get(key,0.0))*float(w.get(key,0.0))
 return score

static func strategic_features(e,who: int) -> Dictionary:
 var f=features(e,who)
 f.merge(Strategic.features(e,who))
 return f

static func value(e,who: int,weights: Dictionary={}) -> float:
 if e.winner==who:return 1000000.0
 if e.winner==1-who:return -1000000.0
 if e.winner!=-2:return 0.0
 return score_features(strategic_features(e,who) if weights.has(Strategic.KEYS[0]) else features(e,who),weights)

static func legacy_pressure(e,who: int,tactics,route: Array,life: int,own_life: int,night_risk: int=0) -> Dictionary:
 # Compatibility evaluation for the currently deployed beam policy. Keep it
 # available as a frozen comparator while training the separate outcome model.
 var result=tactics.pressure_finish(e,who,route)
 if e.winner==who:return {"score":1000000-result.size(),"route":result}
 if e.winner!=-2:return {"score":-1000000,"route":[]}
 if not e.pending.is_empty() or not e.stack.is_empty() or not e.combat.is_empty():return {"score":-1000000,"route":[]}
 var score=(life-e.players[1-who].life)*100+clampi(e.players[who].life-own_life,-20,10)*5-result.size()
 if result.any(func(a):return a.get("card_id","")==tactics.NIGHT) and result.any(func(a):return a.kind=="attack"):score+=night_risk
 var remaining_life=e.players[1-who].life
 if tactics.pressure_next_round(e,who):
  tactics.pressure_finish(e,who,[])
  score+=clampi(remaining_life-e.players[1-who].life,0,remaining_life)*45
 for c in e.units(who):score+=e.Extra.cost_value(e,c)*8+e.stat(c,"spirit")*4
 for c in e.players[who].hand:score+=e.Extra.cost_value(e,c)*5
 return {"score":score,"route":result}

static func load_weights(path: String) -> Dictionary:
 var data=JSON.parse_string(FileAccess.get_file_as_string(path))
 return validate_weights(data)

static func validate_weights(data: Variant) -> Dictionary:
 if not data is Dictionary or data.get("schema","") not in [SCHEMA,STRATEGIC_SCHEMA] or not data.get("weights") is Dictionary:return {}
 var keys=DEFAULT_WEIGHTS.keys()
 if data.schema==STRATEGIC_SCHEMA:keys.append_array(Strategic.KEYS)
 for key in keys:
  var v=data.weights.get(key)
  if not v is float and not v is int:return {}
  if not is_finite(float(v)) or absf(float(v))>10000.0:return {}
 return data.weights.duplicate(true)
