extends RefCounted
const Codec=preload("res://net/state_codec.gd")
const Observation=preload("res://scripts/ai/observation.gd")
## Keep tactical memory as well as rules state; omit cached plans and diagnostics.
static func capture(e) -> Dictionary:
 var data={}
 for p in e.get_property_list():
  if not int(p.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE or p.name in ["rng","cards","payment_memo","payment_groups","history","log","presentation_events","ai_memory"]:continue
  var v=e.get(p.name)
  if not v is Object and not v is Callable:data[p.name]=v
 var memory=e.ai_memory.duplicate(true)
 for m in memory:
  for key in ["lethal_plan","pressure_plan","last_pressure_trace","attack_risk_key","attack_risk","queen_key","queen_value"]:m.erase(key)
 return {"graph":Codec.encode(data),"definitions":e.cards.duplicate(),"memory":memory,"rng_state":e.rng.state,"rng_seed":e.rng.seed}

static func restore(e,state: Dictionary):
 var data=Codec.decode(state.graph)
 for k in data:e.set(k,data[k])
 e.cards=state.definitions.duplicate();e.rng.seed=state.rng_seed;e.rng.state=state.rng_state
 e.ai_memory=state.memory.duplicate(true)
 e.payment_memo={};e.payment_groups=[]
 e.log=[];e.history=[];e.presentation_events=[]

static func fork(e,who: int):
 var sim=e.get_script().new(e.cards)
 restore(sim,capture(e))
 var known=Observation.known_hand(e,who)
 for seat in range(2):
  for c in sim.players[seat].deck:mask(c)
  if seat!=who:
   for c in sim.players[seat].hand:
    if known.has(str(c.uid)):c.card_id=known[str(c.uid)].card_id
    else:mask(c)
 return sim

static func mask(c: Dictionary):
 c.card_id="164";c.erase("art_id");c.ai_unknown=true
