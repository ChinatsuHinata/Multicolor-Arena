extends RefCounted
## User-directed aggro objective: reserve Gungnir only for a publicly forecast
## dangerous entry. Current threats can still be removed immediately.
const State=preload("res://scripts/ai/simulation_state.gd")
const Observation=preload("res://scripts/ai/observation.gd")
const GUNGNIR="109"
const CLOUD="character-fdf-046"

static func high_risk(e,c: Dictionary,who: int) -> bool:
 var info=e.cards[c.card_id]
 if c.card_id==CLOUD:
  return e.players[who].leader.zone=="field" and (c.get("ichirin_paid",false) or e.payment(c.owner,e.cast_cost(c.owner,c,{"extra_green":true})).ways>0)
 if e.Roster.character_matches(info.character,"博丽灵梦"):return true
 if c.card_id=="39":return true
 if e.Roster.character_matches(info.character,"芙兰朵露·斯卡蕾特"):
  return c.uid==e.players[c.owner].leader.uid or e.has_leader_ability(c)
 # Other commanders with actually enabled sustained/activated abilities.
 return info.kind=="自机" and (e.has_leader_ability(c) or not e.Extra.activation_kind(info).is_empty() or not e.Roster.key(info,e.Roster.ACTIVATIONS).is_empty())

static func forecast(e,who: int) -> Dictionary:
 var sim=State.fork(e,who);var enemy=1-who;var known=Observation.known_hand(e,who)
 var candidates=sim.leaders(enemy).filter(func(c):return c.zone=="leader")
 candidates.append_array(sim.players[enemy].hand.filter(func(c):return known.has(str(c.uid)) and sim.is_unit(c)))
 var incoming=sim.stack.filter(func(s):return s.kind=="card" and s.owner==enemy and sim.is_unit(s.card)).map(func(s):return s.card)
 candidates.append_array(incoming)
 sim.pending={};sim.entry_choices=[];sim.stack=[];sim.combat={};sim.active=enemy;sim.priority=enemy;sim.phase="main";sim.passes=0
 if e.active==who:
  sim.turn+=1;sim.players[enemy].turns+=1;sim.turn_usage={}
  for p in sim.players:
   p.mana=[]
   for c in p.field:c.damage=0;c.modifiers=[];c.wards=c.get("wards",[]).filter(func(w):return w.get("turn",-1)==-1)
  for c in sim.players[enemy].palette+sim.players[enemy].field:
   if sim.Pack.reset_allowed(sim,c):c.tapped=false
  if sim.players[enemy].palette.size()<8 and not sim.players[enemy].deck.is_empty():sim.players[enemy].mana.append({"uid":-9200,"colors":Array(e.COLORS),"weight":1000,"kind":"possible_public_growth"})
 var before=State.capture(sim);var threats=[]
 for original in candidates:
  State.restore(sim,before)
  var c=sim.find_card(original.uid) if original not in incoming else original.duplicate(true)
  if c.is_empty():continue
  if original not in incoming and not sim.cast_error(enemy,c.uid).is_empty():continue
  var fight_paid=c.card_id==CLOUD and (c.get("ichirin_paid",false) or sim.payment(enemy,sim.cast_cost(enemy,c,{"extra_green":true})).ways>0)
  sim.detach(c)
  if not sim.enter_field(c,enemy):continue
  if c.card_id==CLOUD:c.ichirin_paid=fight_paid
  if not high_risk(sim,c,who):continue
  var damage=sim.RemiliaAI.preview_damage(sim,{"card_id":GUNGNIR,"owner":who},c,4,false)
  if not sim.RemiliaAI.dies_to(sim,c,damage):continue
  threats.append({"uid":c.uid,"card_id":c.card_id,"source":"declared" if original in incoming else "public_leader" if original.zone=="leader" else "remembered_hand"})
 return {"risk":not threats.is_empty(),"threats":threats,"growth":"one possible flexible color; not a known deck-top identity"}

static func objective(e,who: int,f: Dictionary,winner: int=-2) -> float:
 # Reward shaping is an explicit user preference, not a learned win probability.
 if winner==who:return 1000000.0
 if winner==1-who:return -1000000.0
 return -float(f.get("opponent_life",e.players[1-who].life))*10.0+float(f.get("ready_damage",0))*3.0+float(f.get("aura_haste_damage",0))*4.0+float(f.get("queen_combo_ready",0))*12.0+float(f.get("castle_count",0))*6.0+float(f.get("board_margin",0))*0.5+float(f.get("role_ready",0))*10.0+float(f.get("required_gungnir_reserve",0))*25.0-float(f.get("needless_gungnir_reserve",0))*3.0
