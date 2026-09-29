extends RefCounted
## Sequential MAIN-DECISION abstraction, with real payments and a frozen policy
## for intermediate response/choice windows. Not a full atomic-rule game adapter.
const Duel=preload("res://scripts/rules/duel_engine.gd")
const State=preload("res://scripts/ai/simulation_state.gd")
const Observation=preload("res://scripts/ai/observation.gd")
const Actions=preload("res://scripts/ai/algorithm_actions.gd")
const Action=preload("res://scripts/ai/action.gd")
const Value=preload("res://scripts/ai/position_evaluator.gd")
const Pressure=preload("res://scripts/ai/pressure_policy.gd")
var engine
var deck_priors=[]
var recall=[[],[]]
var failure=""
var auto_steps=0
var action_limit=256
var cached_revision=-1
var cached_menu={}

func setup(e,priors: Array=[]):
 engine=e;deck_priors=priors.duplicate(true);remember()

func reset(decks: Array,first: int=0,seed_value: int=7) -> Dictionary:
 if decks.size()!=2:return {"error":"Two deck definitions required"}
 engine=Duel.new();engine.start(decks[0],decks[1],first,seed_value)
 deck_priors=decks.map(func(d):return d.main.duplicate());recall=[[],[]];failure="";auto_steps=0;cached_revision=-1
 return advance()

func current_player() -> int:return -1 if is_terminal() else engine.active
func is_terminal() -> bool:return engine.winner!=-2
func returns() -> Array:
 if not is_terminal():return []
 return [0.0,0.0] if engine.winner==-1 else [1.0 if engine.winner==0 else -1.0,1.0 if engine.winner==1 else -1.0]
func observation(who: int) -> Dictionary:return Observation.build(engine,who)
func information_state_string(who: int) -> String:
 return JSON.stringify(Actions.canonical({"recall":recall[who],"observation":observation(who)}))
func features(who: int) -> Dictionary:return Value.strategic_features(engine,who)

func legal_actions() -> Dictionary:
 if cached_revision!=engine.revision:
  # Deck identities are unavailable at a decision. Generate the same menu for
  # all worlds with the same observation; deck casts are outside this abstraction.
  cached_menu=Actions.menu(State.fork(engine,current_player()),current_player(),action_limit) if not is_terminal() else {"actions":[],"truncated":false,"unsupported":[]}
  cached_revision=engine.revision
 return cached_menu.duplicate(true)

func clone():
 var copy=get_script().new();copy.engine=engine.get_script().new(engine.cards);State.restore(copy.engine,State.capture(engine))
 copy.deck_priors=deck_priors.duplicate(true);copy.recall=recall.duplicate(true);copy.failure=failure;copy.auto_steps=auto_steps;copy.action_limit=action_limit
 return copy

func policy_actions() -> Dictionary:
 var menu=legal_actions();var allowed=menu.actions.map(func(a):return a.id)
 if is_terminal() or engine.players[current_player()].leader.card_id!="74":return {"ids":allowed,"guard":"none"}
 var who=current_player()
 var permitted=menu.actions.filter(func(row):return row.action.kind!="cast" or row.action.get("card_id","")!="109" or engine.RemiliaAI.gungnir_target_allowed(engine,who,engine.find_card(row.action.target.get("uid",-1))))
 allowed=permitted.map(func(a):return a.id)
 var reimu_guard="reimu_gungnir_finisher" if permitted.size()!=menu.actions.size() else "none"
 var guns=engine.players[who].hand.filter(func(c):return c.card_id=="109")
 var threat=Pressure.forecast(engine,who)
 if guns.is_empty() or not threat.risk or not engine.cast_error(who,guns[0].uid).is_empty():return {"ids":allowed,"guard":reimu_guard,"forecast":threat}
 allowed=[]
 for row in permitted:
  var a=row.action
  if a.kind=="pass":allowed.append(row.id);continue
  if a.kind=="cast" and a.card_id=="109":
   var target=engine.find_card(a.target.get("uid",-1))
   if not target.is_empty() and Pressure.high_risk(engine,target,who):allowed.append(row.id)
   continue
  var probe=State.fork(engine,who)
  if not Action.apply(probe,who,a):continue
  var gun=probe.find_card(guns[0].uid)
  if gun.zone=="hand" and probe.payment(who,probe.cast_cost(who,gun)).ways>0:allowed.append(row.id)
  else:
   # A real immediate win is permitted to spend the reserved colors.
   if probe.RemiliaAI.settle_sim(probe,who) and probe.winner==who:allowed.append(row.id)
 return {"ids":allowed,"guard":"public_high_risk_gungnir_reserve","forecast":threat}

func apply_action(action_id: int) -> Dictionary:
 if is_terminal():return {"error":"Terminal state"}
 var row=legal_actions().actions.filter(func(a):return a.id==action_id)
 if row.size()!=1:return {"error":"Illegal or stale action id"}
 var backup=State.capture(engine)
 if not Action.apply(engine,current_player(),row[0].action):
  State.restore(engine,backup);cached_revision=-1;return {"error":"Engine rejected enumerated action"}
 cached_revision=-1
 var result=advance();result.action=row[0].action
 return result

func clean() -> bool:
 return engine.phase=="main" and engine.priority==engine.active and engine.pending.is_empty() and engine.entry_choices.is_empty() and engine.stack.is_empty() and engine.combat.is_empty()

func advance(max_steps: int=192) -> Dictionary:
 for i in range(max_steps):
  if is_terminal() or clean():remember();return {"complete":true,"automatic_steps":i,"terminal":is_terminal(),"current_player":current_player(),"returns":returns()}
  var seat=engine.pending.get("owner",engine.priority)
  if engine.phase=="mulligan":seat=0 if not engine.players[0].mulligan_done else 1
  var before=engine.revision
  # Freeze the off-boundary policy and avoid experimental agents recursively.
  var mode=engine.ai_memory[seat].get("decision_mode","");engine.ai_memory[seat].decision_mode="legacy"
  engine.ai_step(seat)
  if mode.is_empty():engine.ai_memory[seat].erase("decision_mode")
  else:engine.ai_memory[seat].decision_mode=mode
  auto_steps+=1
  if before==engine.revision:
   failure="automatic_policy_no_progress";return {"error":failure,"complete":false,"terminal":false}
 failure="automatic_policy_step_limit"
 return {"error":failure,"complete":false,"terminal":false}

func remember():
 for who in [0,1]:
  var seen=Actions.key(observation(who))
  if recall[who].is_empty() or recall[who].back()!=seen:recall[who].append(seen)

func resample_from_infostate(who: int,seed_value: int):
 if deck_priors.size()!=2:return {"error":"Explicit deck-list priors are required for information-set search"}
 var copy=clone();copy.engine=State.fork(engine,who);copy.cached_revision=-1
 var rng=RandomNumberGenerator.new();rng.seed=seed_value
 for seat in [0,1]:
  var pool=deck_priors[seat].duplicate();var p=copy.engine.players[seat];var seen={}
  for zone in ["field","palette","grave","exile","hand"]:
   for c in p[zone]:
    if c.uid==p.leader.uid or c.get("token",false) or c.get("ai_unknown",false) or seen.has(c.uid):continue
    seen[c.uid]=true
    var index=pool.find(c.card_id)
    if index<0:return {"error":"Deck prior inconsistent with observed card: "+c.card_id}
    pool.remove_at(index)
  var hidden=[]
  for c in p.hand+p.deck:
   if c.get("ai_unknown",false):hidden.append(c)
  if hidden.size()!=pool.size():return {"error":"Deck prior count mismatch; generated/transformed hidden cards need a richer belief model"}
  for i in range(pool.size()-1,0,-1):
   var j=rng.randi_range(0,i);var temp=pool[i];pool[i]=pool[j];pool[j]=temp
  for i in range(hidden.size()):
   hidden[i].card_id=pool[i];hidden[i].erase("ai_unknown")
 # Hidden real RNG is never copied as the sampled world's future chance stream.
 copy.engine.rng.seed=rng.randi();copy.recall[1-who]=[]
 copy.remember()
 if copy.observation(who)!=observation(who):return {"error":"Resampling changed the observer's visible information"}
 return {"environment":copy,"seed":seed_value,"policy":"explicit_deck_prior_without_replacement"}
