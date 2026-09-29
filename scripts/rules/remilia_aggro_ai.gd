extends RefCounted
## Deck-specific decisions using our hand, public resources and remembered reveals.
const PROFILE="remilia_aggro"
const Observation=preload("res://scripts/ai/observation.gd")
const SimState=preload("res://scripts/ai/simulation_state.gd")
const Action=preload("res://scripts/ai/action.gd")
const BeamPlanner=preload("res://scripts/ai/beam_planner.gd")
const DecisionAgent=preload("res://scripts/ai/decision_agent.gd")
const Evaluator=preload("res://scripts/ai/position_evaluator.gd")
const Counterplay=preload("res://scripts/ai/release_counterplay.gd")
const LILY="character-fdn-068"
const WINGS="129"
const FAIRY="character-fdn-014"
const REMILIA="74"
const BIG_REMILIA="character-fdn-048"
const NUE="soi_unit_086"
const CASTLE="169"
const GUNGNIR="109"
const MIST="spell-ucs-052"
const AUTUMN="94"
const DRAW="spell-fdf-038"
const RED="spell-fdf-035"
const QUEEN="spell-fdf-037"
const NIGHT="spell-fdn-008"
const AURORA="143"
const CLOUD="character-fdf-046"
const AYA="18"
const HINA="32"
const PARSEE="23"
const BLOCK_RESPONSES=["114","character-rei-022","character-fdf-069"]
const BIG_UNITS=[BIG_REMILIA,"character-fdf-065"]
const EARLY_CURVE=[LILY,WINGS,FAIRY,HINA,CASTLE]
const REIMU_PRIORITY=100000
const ENGINE_PRIORITY=20000
const COLOR_RESPONSES=["96",GUNGNIR,"112","177"]
const RESPONSE_NODES=96
const SEARCH_CARDS=[NIGHT,AURORA,RED,GUNGNIR,MIST,AUTUMN,QUEEN,CASTLE,BIG_REMILIA,NUE,FAIRY,REMILIA,WINGS,LILY,AYA,"character-fdf-065"]
const SEARCH_NODES=1800
const SEARCH_MSEC=650
const PRESSURE_MSEC=350
const PRESSURE_WIDTH=4
const PRESSURE_DEPTH=3
const THINK_LIMIT_MSEC=30000

static func profile(deck: Dictionary) -> String:
 if deck.get("leader","")!=REMILIA:return ""
 var main=deck.get("main",[])
 if deck.get("name","") in ["蕾米速攻","蕾米速攻（ai）"]:return PROFILE
 # Also recognize renamed/exported copies of this list.
 return PROFILE if [LILY,WINGS,FAIRY,BIG_REMILIA,NIGHT,AURORA].all(func(id):return id in main) else ""

static func step(e,who: int) -> bool:
 var memory=e.ai_memory[who]
 var previous_deadline=memory.get("_think_deadline",-1)
 var new_deadline=Time.get_ticks_msec()+THINK_LIMIT_MSEC
 memory._think_deadline=mini(int(previous_deadline),new_deadline) if previous_deadline>=0 else new_deadline
 var handled=step_decision(e,who)
 if previous_deadline<0:memory.erase("_think_deadline")
 else:memory._think_deadline=previous_deadline
 return handled

static func think_deadline(e,who: int,deadline: int=-1) -> int:
 var limit=int(e.ai_memory[who].get("_think_deadline",-1))
 if limit<0:return deadline
 return mini(limit,deadline) if deadline>=0 else limit

static func think_expired(e,who: int) -> bool:
 var deadline=think_deadline(e,who)
 return deadline>=0 and Time.get_ticks_msec()>=deadline

static func step_decision(e,who: int) -> bool:
 if e.ai_memory[who].get("decision_mode","")!="public_round":Counterplay.record(e,who)
 if e.phase=="mulligan":
  e.mulligan(who,mulligan_uids(e,who))
  return true
 if not e.pending.is_empty():
  if e.pending.owner!=who:return true
  match e.pending.kind:
   "effect_choice":e.choose_effect(effect_target(e,who,e.pending.options,e.pending.trigger));return true
   "block":e.block(defensive_blocks(e));return true
   "damage_assignment":
    var attacker=e.find_card(e.combat.attacker.uid)
    var blockers=e.combat.blockers.map(func(t):return e.find_card(t.uid))
    e.combat_damage(damage_allocation(e,attacker,blockers,e.pending.total));return true
   "leader_return":
    var c=e.pending.card
    if c.card_id==REMILIA and c.get("return_destination","")=="grave":
     e.ai_memory[who].leader_died=true
     e.ai_memory[who].death_turns=e.players[who].turns
    e.choose_return(not keep_remilia_in_hand(c) and not grave_recovery(e,who,c));return true
   "discard":
    var hand=e.players[who].hand.duplicate()
    hand.sort_custom(func(a,b):return card_priority(e,who,a)<card_priority(e,who,b))
    e.discard(hand.slice(0,e.pending.count).map(func(c):return c.uid));return true
  return false
 if e.priority!=who:return true
 if not e.stack.is_empty() or not e.combat.is_empty():
  if protect_remilia(e,who):return true
  # Do not let generic fast casting spend Night King or removal on a poor target.
  if combat_response(e,who):return true
  if fast_removal(e,who):return true
  e.pass_priority(who);return true
 if e.active!=who or e.phase!="main":
  if e.active==who and e.phase=="possession" and reimu_night(e,who):return true
  if fast_removal(e,who):return true
  e.pass_priority(who);return true
 var choices=e.legal_casts(who)
 # Queen's bats expire at the next end phase. Send every legal one into combat
 # before another nonlethal cast or a planned pass can strand it.
 var queen_bat=queen_bat_attacker(e,who)
 if not queen_bat.is_empty():e.attack(who,queen_bat.uid);return true
 var revival=remilia_aurora(e,who,choices)
 if not revival.is_empty() and cast(e,who,revival.card,revival.target):return true
 # After a bounce, restore the role before nonlethal removal or expansion
 # consumes the colors needed to replay it. A certified win still comes first.
 var leader=e.players[who].leader
 if leader.card_id==REMILIA and leader.zone=="hand" and choices.any(func(c):return c.uid==leader.uid):
  var winning=lethal_action(e,who)
  if not winning.is_empty() and execute(e,who,winning):return true
  if cast(e,who,leader,{"none":true}):return true
 elif leader.card_id==REMILIA and leader.zone=="hand" and replay_color_source(e,who,choices):return true
 # Authored release opening happens before any cached/search plan.
 if e.ai_memory[who].get("decision_mode","")!="public_round":
  if bound_autumn(e,who,choices) or reimu_opening(e,who,choices):return true
 var action=lethal_action(e,who)
 if not action.is_empty() and execute(e,who,action):return true
 if think_expired(e,who):e.pass_priority(who);return true
 # Learned agents remain opt-in; the default uses authored release tactics.
 if e.ai_memory[who].get("decision_mode","")=="public_round":
  e.ai_memory[who].decision_mode="legacy"
  DecisionAgent.step(e,who,load("res://scripts/rules/remilia_aggro_ai.gd"),e.ai_memory[who].get("value_weights",{}),true)
  e.ai_memory[who].decision_mode="public_round"
  return true
 # On the draw, spend the potato to establish the role/aura as soon as legal.
 if who!=e.first and e.players[who].potato:
  for c in choices:
   if c.uid==e.players[who].leader.uid and cast(e,who,c,{"none":true}):return true
 choices.sort_custom(func(a,b):return card_priority(e,who,a)>card_priority(e,who,b))
 # Silence reserved responses/death triggers before removal when a useful
 # Night opening is the best pressure route. Other routes keep core removal.
 if night_priority(e,who)>0 and choices.any(func(c):return c.card_id==NIGHT):
  action=pressure_action(e,who)
  if not action.is_empty():
   if action.get("card_id","")==NIGHT and pressure_execute(e,who,action):return true
   e.ai_memory[who].pressure_plan.push_front(action)
 if think_expired(e,who):e.pass_priority(who);return true
 # Strip a live opposing engine before spending the turn's mana on expansion.
 # A missing role source is still played first through the normal leader curve.
 for c in choices:
  if c.card_id!=AURORA:continue
  var sacrifice_target=aurora_sacrifice_target(e,who,choices)
  if not sacrifice_target.is_empty() and cast(e,who,c,sacrifice_target,false):return true
 if establish_gungnir(e,who,choices):return true
 if remove_blocker(e,who,choices):return true
 if think_expired(e,who):e.pass_priority(who);return true
 # Recheck actual core health after each probe. Once earned lifesteal makes
 # RED lethal to the core, remove_blocker can finish before losing more bodies.
 if Counterplay.reimu_probe_scope(e,who):
  var probe=red_setup_choice(e,who)
  if probe.is_empty():probe=reimu_probe_choice(e,who)
  if not probe.is_empty() and execute(e,who,{"kind":"attack","uid":probe.uid}):return true
 # On the four-resource turn, establish Hina before ordinary expansion.
 # Certified lethal and core removal still retain their existing priority.
 if e.players[who].palette.size()==4 and e.players[who].leader.card_id==REMILIA and e.players[who].leader.zone=="field":
  for c in choices:
   if c.card_id==HINA and cast(e,who,c,{"none":true}):return true
 # Establish/recover the role before planning sustained high-mana pressure.
 for c in choices:
  if c.uid!=e.players[who].leader.uid and not (c.card_id in [AURORA,AYA] and e.players[who].leader.zone=="grave"):continue
  var t=spell_target(e,who,c)
  if not t.is_empty() and cast(e,who,c,t):return true
 action=pressure_action(e,who)
 if not action.is_empty() and pressure_execute(e,who,action):return true
 if think_expired(e,who):e.pass_priority(who);return true
 # Keep the early curve and a fallback when bounded planning finds no route.
 for c in choices:
  if card_priority(e,who,c)<800:continue
  var t=spell_target(e,who,c)
  if not t.is_empty() and cast(e,who,c,t):return true
 for c in choices:
  var t=spell_target(e,who,c)
  if not t.is_empty() and cast(e,who,c,t):return true
 var attacker=attack_choice(e,who)
 if not attacker.is_empty():e.attack(who,attacker.uid);return true
 # Reconsider lesser removal only after attacks and the reserved opportunities.
 if remove_blocker(e,who,choices,true):return true
 e.pass_priority(who);return true

static func cast(e,who: int,c: Dictionary,t: Dictionary,preserve_gun: bool=true,prepare_red: bool=true) -> bool:
 if c.card_id==GUNGNIR and not gungnir_target_allowed(e,who,e.find_card(t.get("uid",-1))):return false
 if c.card_id==AYA and aya_target(e,who).is_empty():return false
 if c.card_id==AURORA and t.get("mode","")=="移回战场" and grave_removal_ready(e,who,e.find_card(t.get("uid",-1))):return false
 if prepare_red and c.card_id in [GUNGNIR,MIST,AUTUMN,RED] and not removal_collateral_safe(e,who,c,t):return false
 var cost=e.cast_cost(who,c,t);var payment=e.payment(who,cost)
 if payment.ways==0:return false
 # Ordinary play and pressure plans build RED with small lifesteal attacks.
 # Lethal search may still need RED first to clear a blocker. That exception
 # is separate from Gungnir reservation and verifies the whole winning route.
 if prepare_red and c.card_id==RED and not red_setup_choice(e,who).is_empty():return false
 if e.active==who and e.phase=="main" and c.card_id not in [GUNGNIR,NIGHT] and cost.values().reduce(func(n,v):return n+int(v),0)>=4 and Counterplay.reimu_seal_risk(e,who) and not effective_removal(e,who,c,t):return false
 if preserve_gun and e.active==who and e.players[who].hand.any(func(u):return u.card_id==GUNGNIR) and c.card_id in [MIST,AUTUMN,RED] and t.has("uid"):
  var target=e.find_card(t.uid)
  if not target.is_empty() and target.owner!=who and not removal_target(e,who,c,[target]).is_empty() and upcoming_gungnir_value(e,who)==0 and not e.units(1-who).any(func(u):return u.uid!=target.uid and e.stat(u,"health")-u.damage+ward_amount(e,u)>4):preserve_gun=false
 if preserve_gun and c.card_id!=GUNGNIR and e.active==who and e.phase=="main" and remilia_present(e,who) and gungnir_reserve_score(e,who)>0:
  var gun=e.players[who].hand.filter(func(u):return u.card_id==GUNGNIR)
  if not gun.is_empty():
   var gun_cost=e.cast_cost(who,gun[0])
   if e.payment(who,gun_cost).ways>0 and e.payment(who,gun_cost,payment.plan.map(func(r):return r.uid)).ways==0:
    var combined=cost.duplicate()
    for color in gun_cost:combined[color]=int(combined.get(color,0))+int(gun_cost[color])
    var together=e.payment(who,combined)
    if together.ways==0:return false
    var reserved=together.plan.duplicate();var plan=[]
    for color in gun_cost:
     for i in range(int(gun_cost[color])):
      var matches=reserved.filter(func(r):return r.color in color.split("/"))
      if matches.is_empty():return false
      var index=reserved.find(matches[0])
      reserved.remove_at(index)
    plan=reserved
    if not e.payment_valid(who,cost,plan):return false
    payment.plan=plan
 return e.commit_cast(who,c.uid,t,payment.plan).is_empty()

static func mulligan_uids(e,who: int) -> Array:
 var hand=e.players[who].hand
 var have_lily=hand.any(func(c):return c.card_id==LILY)
 var have_wings=hand.any(func(c):return c.card_id==WINGS)
 var keep=[WINGS,LILY]
 if have_lily and have_wings:keep.append(GUNGNIR)
 var seen=[];var replace=[]
 for c in hand:
  if c.card_id in keep and c.card_id not in seen:seen.append(c.card_id)
  else:replace.append(c.uid)
 return replace

static func observe_move(e,c: Dictionary,old: String,destination: String):
 if c.owner not in [0,1]:return
 var memory=e.ai_memory[1-c.owner]
 var known=memory.get("known_hand",{})
 if destination=="hand" and (old in ["palette","field","grave","exile","stack","leader","return_pending"] or known.has(str(c.uid)) and old=="hand"):
  known[str(c.uid)]={"card_id":c.card_id,"epoch":c.epoch+1}
 else:known.erase(str(c.uid))
 memory.known_hand=known

static func observe_reveal(e,c: Dictionary):
 if c.get("zone","")!="hand" or c.owner not in [0,1]:return
 var memory=e.ai_memory[1-c.owner]
 if not memory.has("known_hand"):memory.known_hand={}
 memory.known_hand[str(c.uid)]={"card_id":c.card_id,"epoch":c.epoch}

static func known_hand(e,who: int) -> Dictionary:
 return Observation.known_hand(e,who)

static func observe_block(e,who: int,uids: Array):
 var recent=e.ai_memory[who].get("recent_blocks",[])
 recent.append(not uids.is_empty())
 e.ai_memory[who].recent_blocks=recent.slice(maxi(0,recent.size()-6))

static func frequent_blocks(e,who: int) -> bool:
 var recent=e.ai_memory[who].get("recent_blocks",[])
 return recent.size()>=3 and recent.filter(func(blocked):return blocked).size()*4>=recent.size()*3

static func castle_priority(e,who: int) -> int:
 var base=990 if e.players[who].palette.size()==4 and e.players[who].leader.zone=="field" else 690 if not e.units(who).is_empty() else 200
 if (e.players[who].hand+e.players[who].palette).any(func(c):return c.card_id==QUEEN):base+=450
 var ready=ready_units(e,who)
 if ready.size()>=2 and ready.size()>projected_blockers(e,who):base+=250+ready.size()*50
 if e.players[who].palette.size()>=6 and ready.size()>=2 and ready.size()>projected_blockers(e,who):base+=int(Counterplay.field_policy(e,who).castle_bonus)
 return base

static func card_priority(e,who: int,c: Dictionary) -> int:
 var size=e.players[who].palette.size()
 var leader=e.players[who].leader
 if c.card_id==WINGS and e.Cat.field_limit(e,who)-e.field_slots(who)<2:return 0
 if c.uid==leader.uid and c.zone=="leader":
  return 1200 if e.ai_memory[who].get("leader_died",false) else 1100 if size==3 else 950
 if c.card_id==BIG_REMILIA:return 1150 if size>=6 else 80
 if c.card_id=="character-fdf-065":return 1250 if size>=7 else 60
 if c.card_id==AURORA and leader.zone=="grave":return 1080
 # Aurora revival remains ahead of Aya, including the three/four/five fallback.
 if c.card_id==AYA:return 1070 if leader.zone=="grave" else 900 if not aya_target(e,who).is_empty() else 0
 if c.card_id==HINA and size==4 and leader.card_id==REMILIA and leader.zone=="field":return 1120
 if c.card_id==CASTLE:return castle_priority(e,who)
 if size<=2:
  if size==1 and c.card_id==LILY:return 1050
  if c.card_id==WINGS:return 1040
  if size==2 and c.card_id==HINA:return 1035
  if c.card_id==FAIRY:return 1030
  if c.card_id==LILY:return 1020
  if c.card_id==PARSEE:return 600
 if size==4 and leader.zone=="field":
  if c.card_id==NUE:return 1000
  if e.is_unit(c):return 980
 if c.card_id==NUE:return 700
 if c.card_id==FAIRY:return 650
 if c.card_id==WINGS:return 180 if size>=6 else 640
 if c.card_id==LILY:return 630
 if e.is_unit(c):return 600
 if c.card_id==DRAW:return 500 if e.players[who].hand.size()<=2 else 100
 if c.card_id==QUEEN:return queen_priority(e,who,c)
 return 100

static func queen_priority(e,who: int,c: Dictionary) -> int:
 if e.Cat.field_limit(e,who)-e.field_slots(who)<4:return 400
 var legal=e.cast_error(who,c.uid).is_empty()
 if e.phase=="possession" and e.active==who and c.owner==who and e.players[who].hand.any(func(u):return u.uid==c.uid) and e.stack.is_empty() and e.combat.is_empty():
  # Score the hand after a possession exchange for the upcoming main phase.
  var role=remilia_present(e,who) or e.Cat.State.role_present(e,c,who) or e.leaders(who).any(func(u):return u.zone=="leader" and e.Roster.character_matches(e.cards[u.card_id].character,"蕾米莉亚")) or e.Roster.bypass(e,c,who)
  legal=role and e.Cat.State.cast_error(e,c,who).is_empty() and e.payment(who,e.cast_cost(who,c)).ways>0
 if not legal:return 400
 var aura=e.units(who).filter(func(u):return e.Roster.has(e.cards[u.card_id],"remilia_aura") and e.has_leader_ability(u)).size()
 var castles=e.players[who].field.filter(func(u):return u.card_id==CASTLE).size()
 if aura+castles==0:return 180
 var blockers=projected_blockers(e,who)
 # Four haste attackers pressure a thin board; both auras increase the burst.
 if blockers>2:return 180
 var score=1200+aura*180+castles*140-blockers*60
 if e.players[who].palette.size()>=6:score+=int(Counterplay.field_policy(e,who).queen_bonus)
 return maxi(180,score-1100) if frequent_blocks(e,who) else score

static func blocker_count(e,who: int) -> int:
 return e.units(1-who).filter(func(c):return not c.tapped and e.Cat.State.can_combat(e,c)).size()

static func projected_blockers(e,who: int) -> int:
 var count=blocker_count(e,who)
 if not known_hand(e,who).values().any(func(c):return c.card_id in BLOCK_RESPONSES):return count
 var key=position_key(e,who);var memory=e.ai_memory[who]
 if memory.get("blocker_key","")==key:return memory.blocker_count
 # Known flash bodies and Boundary actually enter/reset the copied field,
 # spending shared colors and respecting titles, slots, locks and triggers.
 var sim=simulation(e,who)
 sim.pending={};sim.stack=[];sim.combat={};sim.phase="main";sim.active=who;sim.priority=1-who
 for i in range(6):
  var before=capture_sim(sim);var best={};var best_count=blocker_count(sim,who)
  var actions=response_actions(sim,who,{}).filter(func(a):return a.card_id in BLOCK_RESPONSES)
  for action in actions:
   restore_sim(sim,before)
   if not commit_response(sim,who,action) or not settle_response(sim):continue
   var possible=blocker_count(sim,who)
   if possible>best_count:best_count=possible;best=capture_sim(sim)
  if best.is_empty():restore_sim(sim,before);break
  restore_sim(sim,best);sim.priority=1-who
 count=blocker_count(sim,who)
 memory.blocker_key=key;memory.blocker_count=count
 return count

static func remilia_present(e,who: int) -> bool:
 return e.units(who).any(func(c):return e.Roster.character_matches(e.cards[c.card_id].character,"蕾米莉亚"))

static func missing_leader_colors(e,who: int) -> Array:
 var leader=e.players[who].leader
 var provided=[]
 for permanent in e.players[who].field:
  if e.cards[permanent.card_id].kind!="符卡":provided.append_array(e.Pack.colors(e,permanent))
 return e.cards[leader.card_id].colors.filter(func(color):return color not in provided)

static func replay_source_colors(e,who: int,c: Dictionary) -> Array:
 if e.cards[c.card_id].kind!="符卡":
  var colors=e.Pack.colors(e,c).duplicate()
  if c.card_id==LILY:colors.append("红") # Its entry choice supplies red.
  if c.card_id==FAIRY:colors=e.COLORS.duplicate() # Vampire leader bypass.
  return colors
 if c.card_id==WINGS and e.Cat.field_limit(e,who)-e.field_slots(who)>=2:return ["红","黑"]
 return []

static func replay_color_source(e,who: int,choices: Array) -> bool:
 var missing=missing_leader_colors(e,who)
 if missing.is_empty():return false
 var best={};var best_score=-1
 for c in choices:
  var colors=replay_source_colors(e,who,c)
  var gained=missing.filter(func(color):return color in colors).size()
  if gained==0:continue
  var target=spell_target(e,who,c)
  if target.is_empty():continue
  var cost=e.cast_cost(who,c,target).values().reduce(func(n,v):return n+int(v),0)
  var score=gained*1000-cost*10+(5 if c.card_id==LILY else 0)
  if score>best_score:best={"card":c,"target":target};best_score=score
 return not best.is_empty() and cast(e,who,best.card,best.target)

static func keep_remilia_in_hand(c: Dictionary) -> bool:
 # Bounce and grave recovery both preserve a directly replayable leader.
 return c.card_id==REMILIA and c.get("return_destination","")=="hand"

static func grave_recovery(e,who: int,c: Dictionary) -> bool:
 if c.card_id!=REMILIA or c.get("return_destination","")!="grave":return false
 if grave_removal_ready(e,who,c,true):return false
 var aurora=e.players[who].hand.any(func(u):return u.card_id==AURORA) and not counter_mana(e,1-who)
 var recovery=aurora or aya_recovery_possible(e,who,c)
 if not recovery:return false
 if e.players[who].palette.size()<6 or not aurora:return true
 if think_expired(e,who):return true
 return death_recovery_better(e,who)

static func death_branch(e,who: int,home: bool):
 var sim=simulation(e,who)
 sim.choose_return(home)
 if not settle_sim(sim,who):return null
 return sim

static func death_recovery_better(e,who: int) -> bool:
 if think_expired(e,who):return true
 # Support Queen remains legal while Remilia is counting down at home.
 # Resolve the real return choice and pending effects before comparing routes.
 var home=death_branch(e,who,true)
 if home==null:return false
 if home.winner==who:return false
 if home.active==who and home.phase=="main" and not lethal_route(home,who).is_empty():return false
 var grave=death_branch(e,who,false)
 if grave==null:return false
 var home_score=death_next_damage(home,who,false)
 if think_expired(e,who):return true
 if home_score.score>=1000000:return false
 var grave_score=death_next_damage(grave,who,true)
 if think_expired(e,who):return true
 if grave_score.score<=-1000000:return false
 if not home_score.queen:return true
 return grave_score.score>=home_score.score

static func death_next_damage(e,who: int,recover: bool) -> Dictionary:
 var result={"score":-1000000,"queen":false}
 if think_expired(e,who):return result
 if e.winner!=-2:
  result.score=1000000 if e.winner==who else -1000000
  return result
 var previous_active=e.active
 if not pressure_next_round(e,who):return result
 if previous_active!=who:e.turn-=1
 e.active=who
 if e.winner!=-2:
  result.score=1000000 if e.winner==who else -1000000
  return result
 var life=e.players[1-who].life;var own_life=e.players[who].life
 if recover:
  # Charge the actual recovery payment before planning Queen or other damage.
  var restored=false
  for id in [AURORA,AYA]:
   var offered=e.legal_casts(who).filter(func(c):return c.card_id==id)
   for c in offered:
    var t={"none":true}
    if id==AURORA:
     t={}
     for option in e.targets_for(id,who,c.uid):
      if option.get("mode","")=="移回战场" and option.get("uid",-1)==e.players[who].leader.uid:t=option;break
    if t.is_empty() or not cast(e,who,c,t) or not settle_sim(e,who):continue
    if id==AYA and e.players[who].leader.zone=="hand":
     if not cast(e,who,e.players[who].leader,{"none":true}) or not settle_sim(e,who):return result
    if e.winner==who:result.score=1000000;return result
    restored=e.players[who].leader.zone=="field"
    break
   if restored:break
  if not restored:return result
 var action=pressure_action(e,who)
 var route=[] if action.is_empty() else [action]+e.ai_memory[who].get("pressure_plan",[])
 for planned in route:
  if think_expired(e,who):break
  if not pressure_execute(e,who,planned) or not settle_sim(e,who):break
  if planned.get("card_id","")==QUEEN:result.queen=true
  if e.winner!=-2:break
 pressure_finish(e,who,[])
 if e.winner!=-2:
  result.score=1000000 if e.winner==who else -1000000
  return result
 var score=(life-e.players[1-who].life)*100+clampi(e.players[who].life-own_life,-20,10)*5
 for c in e.units(who):
  if not c.get("token",false):score+=e.Extra.cost_value(e,c)*8+e.stat(c,"spirit")*4
 for c in e.players[who].hand:score+=e.Extra.cost_value(e,c)*5
 result.score=score
 return result

static func grave_removal_ready(e,who: int,card: Dictionary={},before_next_turn: bool=false) -> bool:
 var enemy=1-who
 if card.get("return_destination","")=="grave" and not e.Pack.trigger_locked(e) and card.get("return_death_observers",e.units(enemy)).any(func(u):return u.owner==enemy and e.Extra.has(e.cards[u.card_id],"death_devour")):return true
 var removers=e.units(enemy).filter(func(u):return e.Extra.activation_kind(e.cards[u.card_id]) in ["exile_grave","character-fdn-043"])
 if removers.is_empty():return false
 # Probe real activation restrictions with a grave target, including locks,
 # sacrifice restrictions and summoning sickness. Never change the live game.
 var sim=simulation(e,who);sim.pending={};sim.phase="main";sim.priority=enemy
 var target=sim.find_card(card.get("uid",-1))
 if target.is_empty():
  target=sim.make_card(REMILIA,who,"grave");sim.players[who].grave.append(target)
 elif target.zone!="grave":
  sim.detach(target);target.zone="grave";sim.players[who].grave.append(target)
 for u in removers:
  var source=sim.find_card(u.uid);var key=sim.Extra.activation_kind(sim.cards[source.card_id])
  if sim.extension_activation_error(enemy,source,key).is_empty():return true
 if not before_next_turn:return false
 sim.stack=[];sim.combat={};sim.turn+=1
 sim.active=enemy if e.active==who else who
 if e.active==who:
  sim.players[enemy].turns+=1
  for u in sim.players[enemy].field:
   if sim.Pack.reset_allowed(sim,u):u.tapped=false
 for u in removers:
  var source=sim.find_card(u.uid);var key=sim.Extra.activation_kind(sim.cards[source.card_id])
  if sim.extension_activation_error(enemy,source,key).is_empty():return true
 return false

static func forecast_main(e,who: int,rounds: int):
 # Curve estimate only: future palette cards are unknown. Flexible red/black
 # slots estimate growth without reading deck order or proving a lethal route.
 var sim=simulation(e,who);sim.pending={};sim.stack=[];sim.combat={};sim.triggers=[]
 sim.active=who;sim.priority=who;sim.phase="main";sim.turn+=2*rounds;sim.players[who].turns+=rounds
 sim.players[who].mana=[];sim.players[who].wine=[];sim.players[who].potato=false
 for u in sim.players[who].field+sim.players[who].palette:
  if sim.Pack.reset_allowed(sim,u):u.tapped=false
 var growth=mini(rounds,mini(8-sim.players[who].palette.size(),sim.players[who].deck.size()))
 for i in range(maxi(0,growth)):
  sim.players[who].mana.append({"uid":-9000-i,"colors":["红","黑"],"weight":1000,"kind":"forecast"})
 return sim

static func aya_recovery_possible(e,who: int,c: Dictionary) -> bool:
 var offered=e.players[who].hand.filter(func(u):return u.card_id==AYA)
 if offered.is_empty():return false
 var sim=forecast_main(e,who,1);var aya=sim.find_card(offered[0].uid);var rem=sim.find_card(c.uid)
 if not sim.cast_error(who,aya.uid).is_empty():return false
 var cost=sim.cast_cost(who,aya)
 var early=e.players[who].palette.size()==3 and sim.source_resources(who).size()==4
 sim.detach(aya);aya.zone="field";sim.players[who].field.append(aya)
 sim.detach(rem);rem.zone="hand";sim.players[who].hand.append(rem)
 if not sim.field_error(rem,who).is_empty():return false
 var rem_cost=sim.cast_cost(who,rem)
 var combined=cost.duplicate()
 for color in rem_cost:combined[color]=int(combined.get(color,0))+int(rem_cost[color])
 if sim.payment(who,combined).ways>0 and sim.cast_error(who,rem.uid).is_empty():return true
 if not early:return false
 # Three-mana death: spend four on Aya, then replay Remilia at five.
 var later=forecast_main(e,who,2)
 var later_aya=later.find_card(aya.uid);var later_rem=later.find_card(rem.uid)
 later.detach(later_aya);later_aya.zone="field";later.players[who].field.append(later_aya)
 later.detach(later_rem);later_rem.zone="hand";later.players[who].hand.append(later_rem)
 return later.cast_error(who,later.players[who].leader.uid).is_empty()

static func aya_target(e,who: int) -> Dictionary:
 var dead=e.players[who].grave.filter(func(u):return e.is_unit(u))
 if dead.is_empty() or grave_removal_ready(e,who):return {}
 dead.sort_custom(func(a,b):
  var a_win=preview_damage(e,a,{"player":1-who},e.stat(a,"spirit"),false)>=e.players[1-who].life
  var b_win=preview_damage(e,b,{"player":1-who},e.stat(b,"spirit"),false)>=e.players[1-who].life
  if a_win!=b_win:return a_win
  if (a.uid==e.players[who].leader.uid)!=(b.uid==e.players[who].leader.uid):return a.uid==e.players[who].leader.uid
  return e.stat(a,"spirit")>e.stat(b,"spirit"))
 var target=e.ref_target(dead[0]);target.zone="grave"
 return {"parts":[target,{"player":1-who}]}

static func crystal_target(e,who: int,options: Array) -> Dictionary:
 var available=e.players[who].hand+e.players[who].palette
 var recovery=available.any(func(c):return c.card_id==AYA)
 var large=[];var other=[]
 for t in options:
  var c=e.find_card(t.get("uid",-1))
  if c.is_empty() or c.uid==e.players[who].leader.uid or direct_damage_card(e,c):continue
  if not e.is_unit(c) or c.card_id not in BIG_UNITS and e.Extra.cost_value(e,c)<4 and e.stat(c,"spirit")<4:other.append(t);continue
  # Keep one accessible copy of each heavy body for its six/seven-mana curve.
  # Recovery only justifies crystallizing a spare, never the final copy.
  if not recovery or available.filter(func(u):return u.card_id==c.card_id).size()<2:continue
  large.append({"target":t,"spirit":e.stat(c,"spirit"),"cost":e.Extra.cost_value(e,c)})
 # Ordinary candidates precede heavy bodies; burn remains protected.
 if not other.is_empty():return e.Pack.ai_target(e,who,other,"crystal")
 large.sort_custom(func(a,b):
  if a.spirit!=b.spirit:return a.spirit>b.spirit
  return a.cost>b.cost)
 return large[0].target if not large.is_empty() else {}

static func direct_damage_card(e,c: Dictionary) -> bool:
 return e.cards[c.card_id].kind=="符卡" and (c.card_id in [AURORA,RED] or e.DB.has_ability(e.cards[c.card_id],"damage"))

static func possession_exchange_allowed(e,who: int,incoming: Dictionary,outgoing: Dictionary) -> bool:
 # Called on the prospective hand/palette arrays, before committing an exchange.
 # The last early curve copy stays in hand; duplicates and late Wings can move.
 if outgoing.uid==e.players[who].leader.uid and outgoing.card_id==REMILIA:return false
 if e.players[who].palette.size()>=6 or outgoing.card_id not in EARLY_CURVE:return true
 if e.players[who].hand.any(func(c):return c.card_id==outgoing.card_id):return true
 # Public, payable interaction or recovery may justify giving up a curve card.
 if incoming.card_id in [GUNGNIR,MIST,AUTUMN,RED]:
  var target=removal_target(e,who,incoming,removal_enemies(e,who))
  if not target.is_empty() and role_removal_ready(e,who,incoming,target):return true
 if incoming.card_id==NIGHT and not reimu_night_target(e,who,incoming).is_empty() and e.payment(who,e.cast_cost(who,incoming)).ways>0:return true
 if incoming.card_id==AURORA and e.players[who].leader.zone=="grave" and e.payment(who,e.cast_cost(who,incoming)).ways>0:
  return not spell_target(e,who,incoming).is_empty()
 return false

static func counter_mana(e,who: int) -> bool:
 # Known counters can use mixed colors or be free. Test their real stack targets.
 var own=1-who
 var sim=simulation(e,own)
 var leader=sim.players[own].leader
 var probe=sim.make_card(AURORA,own,"stack")
 sim.stack=[{"kind":"card","id":sim.next_stack,"card":probe,"owner":own,"target":{"uid":leader.uid,"epoch":leader.epoch,"mode":"移回战场"},"name":sim.cards[AURORA].name}]
 sim.next_stack+=1;sim.priority=who;sim.pending={}
 var probe_id=sim.stack[0].id
 var before=capture_sim(sim)
 for action in response_actions(sim,own,{},false,true):
  restore_sim(sim,before)
  if commit_response(sim,own,action) and settle_response(sim,probe_id) and not sim.stack.any(func(entry):return entry.id==probe_id):return true
 return e.payment(who,{"蓝":2}).ways>0 or e.payment(who,{"绿":2}).ways>0

static func strength(e,c: Dictionary) -> int:
 return e.stat(c,"spirit")*10000+e.stat(c,"power")*100+maxi(0,e.stat(c,"health")-c.damage)+(50 if c.get("leader",false) else 0)

static func weakest(e,who: int) -> Dictionary:
 var units=e.units(who).filter(func(c):return e.can_sacrifice(c))
 units.sort_custom(func(a,b):return strength(e,a)<strength(e,b))
 return units[0] if not units.is_empty() else {}

static func draw_target(e,who: int,c: Dictionary) -> Dictionary:
 var hand_size=e.players[who].hand.size()
 if not remilia_present(e,who) or hand_size>=7 or e.players[who].deck.is_empty():return {}
 if hand_size>2:
  # Spend otherwise idle mana even with a stocked but currently unplayable hand.
  # Expansion, recovery and useful removal retain priority over extra cards.
  for other in e.legal_casts(who):
   if other.card_id==DRAW:continue
   if not spell_target(e,who,other).is_empty():return {}
   if other.card_id in [GUNGNIR,MIST,AUTUMN,RED] and not removal_target(e,who,other,removal_enemies(e,who)).is_empty():return {}
 var danger=e.units(1-who).filter(func(u):return e.Cat.State.can_combat(e,u)).reduce(func(n,u):return n+maxi(0,e.stat(u,"spirit")),0)
 var reserve=maxi(5,danger+1)
 var extra=mini(3,maxi(0,int((e.players[who].life-reserve)/4)))
 extra=mini(extra,maxi(0,7-hand_size))
 extra=mini(extra,maxi(0,e.players[who].deck.size()-1))
 for t in e.targets_for(c.card_id,who,c.uid):
  if t.get("extra",-1)==extra and e.players[who].deck.size()>0:return t
 return {}

static func autumn_sacrifice(e,who: int,enemy: Dictionary) -> Dictionary:
 if enemy.is_empty():return {}
 var units=e.units(who).filter(func(u):return e.can_sacrifice(u))
 # A bound, tapped body cannot resume attacking or blocking next turn.
 var bound=func(u):return u.tapped and u.get("lock_sources",[]).any(func(r):return e.Extra.valid(e,r))
 units.sort_custom(func(a,b):
  if bound.call(a)!=bound.call(b):return bound.call(a)
  return strength(e,a)<strength(e,b))
 for unit in units:
  # Keep the role and its aura instead of losing our own engine for removal.
  if e.Roster.character_matches(e.cards[unit.card_id].character,"蕾米莉亚"):continue
  if e.units(who).size()>=4:return unit
  if not battlefield_engine(e,enemy) and not e.Roster.character_matches(e.cards[enemy.card_id].character,"博丽灵梦"):continue
  if bound.call(unit) or e.Extra.cost_value(e,unit)<=2 and strength(e,unit)<strength(e,enemy):return unit
 return {}

static func bound_unit(e,c: Dictionary) -> bool:
 return c.get("tapped",false) and c.get("lock_sources",[]).any(func(r):return e.Extra.valid(e,r) and e.Pack.has(e.cards[e.find_card(r.uid).card_id],"bind_field"))

static func effective_removal(e,who: int,c: Dictionary,t: Dictionary) -> bool:
 if c.card_id not in [GUNGNIR,MIST,AUTUMN,RED] or not t.has("uid"):return false
 var target=e.find_card(t.uid)
 if target.is_empty() or target.owner==who or target.zone!="field":return false
 return not removal_target(e,who,c,[target]).is_empty()

static func bound_autumn_target(e,who: int,c: Dictionary) -> Dictionary:
 var cores=removal_enemies(e,who).filter(func(u):return battlefield_engine(e,u) and e.stat(u,"health")-u.damage in [4,5])
 for core in cores:
  var t=removal_target(e,who,c,[core])
  if not t.is_empty() and bound_unit(e,e.find_card(t.get("sacrifice",{}).get("uid",-1))):return t
 return {}

static func bound_autumn(e,who: int,choices: Array) -> bool:
 for c in choices:
  if c.card_id!=AUTUMN:continue
  var t=bound_autumn_target(e,who,c)
  if not t.is_empty() and cast(e,who,c,t,false):return true
 return false

static func reimu_opening(e,who: int,choices: Array) -> bool:
 if not Counterplay.reimu_scope(e,who):return false
 var reimu=Counterplay.reimu_units(e,who)
 if reimu.is_empty():return false
 reimu.sort_custom(func(a,b):return gungnir_value(e,a)>gungnir_value(e,b))
 # RED is a finisher, not a compulsory Reimu opener. Let lethal search and
 # small lifesteal attacks run before spending it on this core.
 for id in [GUNGNIR,MIST,AUTUMN]:
  for c in choices:
   if c.card_id!=id:continue
   var t=removal_target(e,who,c,reimu)
   if not t.is_empty() and cast(e,who,c,t,false):return true
 if establish_gungnir(e,who,choices):return true
 # The opponent chooses sacrifice; only use it when every offered body is a core.
 for c in choices:
  if c.card_id!=AURORA:continue
  var t=aurora_sacrifice_target(e,who,choices)
  if not t.is_empty() and cast(e,who,c,t,false):return true
 return reimu_night(e,who)

static func reimu_probe_choice(e,who: int) -> Dictionary:
 if not Counterplay.reimu_probe_scope(e,who):return {}
 var large=Counterplay.reimu_units(e,who).filter(func(c):return not c.tapped and e.stat(c,"health")-c.damage>4)
 if large.is_empty():return {}
 var small=e.units(who).filter(func(c):return e.can_attack(who,c.uid) and e.stat(c,"power")>0 and e.Extra.cost_value(e,c)<=3 and not e.Roster.character_matches(e.cards[c.card_id].character,"蕾米莉亚") and attack_allowed(e,c))
 small=small.filter(func(c):return e.blockers_for(c).any(func(b):return large.any(func(r):return r.uid==b.uid)))
 small.sort_custom(func(a,b):return strength(e,a)<strength(e,b))
 return small[0] if not small.is_empty() else {}

static func gungnir_target_allowed(e,who: int,enemy: Dictionary) -> bool:
 if enemy.is_empty():return false
 if not e.Roster.character_matches(e.cards[enemy.card_id].character,"博丽灵梦"):return true
 # The role priority never licenses a partial hit. Combat damage may open a
 # real four-damage finish; wards and indestructibility still have to pass.
 return e.stat(enemy,"health")-enemy.damage<=4 and dies_to(e,enemy,preview_damage(e,{"card_id":GUNGNIR,"owner":who},enemy,4,false))

static func reimu_night_target(e,who: int,c: Dictionary) -> Dictionary:
 if not Counterplay.reimu_night_needed(e,who):return {}
 var targets=e.targets_for(c.card_id,who,c.uid)
 for u in e.units(who):
  if not e.Roster.character_matches(e.cards[u.card_id].character,"蕾米莉亚"):continue
  for t in targets:
   if t.get("uid",-1)==u.uid:return t
 return {}

static func reimu_night(e,who: int) -> bool:
 for c in e.legal_casts(who,true):
  if c.card_id!=NIGHT:continue
  var t=reimu_night_target(e,who,c)
  if not t.is_empty() and cast(e,who,c,t,false):return true
 return false

static func spell_target(e,who: int,c: Dictionary) -> Dictionary:
 if c.card_id==AYA:return {"none":true} if not aya_target(e,who).is_empty() else {}
 if e.is_unit(c) or c.card_id==CASTLE:return {"none":true}
 var options=e.targets_for(c.card_id,who,c.uid)
 if options.is_empty():return {}
 match c.card_id:
  WINGS:
   return options[0] if e.Cat.field_limit(e,who)-e.field_slots(who)>=2 else {}
  DRAW:return draw_target(e,who,c)
  AURORA:
   var revival=remilia_aurora_target(e,who,options)
   if not revival.is_empty():return revival
   if e.players[1-who].life<=3:return {"player":1-who,"mode":"失去生命"}
   var sacrifice_target=aurora_sacrifice_target(e,who)
   if not sacrifice_target.is_empty():return sacrifice_target
   return aurora_pressure_target(e,who)
  QUEEN:
   # Temporary bats need a useful attack this turn; otherwise keep the support spell.
   if e.Cat.field_limit(e,who)-e.field_slots(who)>=4 and (queen_priority(e,who,c)>400 or e.units(1-who).filter(func(u):return not u.tapped).is_empty()):return options[0]
  RED:
   if e.players[1-who].life<=red_damage(e,who):return {"player":1-who}
 return {}

static func remilia_aurora_target(e,who: int,options: Array) -> Dictionary:
 var leader=e.players[who].leader
 if leader.card_id!=REMILIA or leader.zone!="grave":return {}
 if e.players[who].turns<=e.ai_memory[who].get("death_turns",-1):return {}
 if not e.field_error(leader,who).is_empty() or grave_removal_ready(e,who,leader):return {}
 for t in options:
  if t.get("mode","")=="移回战场" and t.get("uid",-1)==leader.uid:return t
 return {}

static func remilia_aurora(e,who: int,choices: Array) -> Dictionary:
 if e.players[who].leader.zone!="grave":return {}
 for c in choices:
  if c.card_id!=AURORA:continue
  var target=remilia_aurora_target(e,who,e.targets_for(AURORA,who,c.uid))
  if not target.is_empty() and e.payment(who,e.cast_cost(who,c,target)).ways>0:
   return {"card":c,"target":target}
 return {}

static func queen_bat_attacker(e,who: int) -> Dictionary:
 for c in e.units(who):
  if c.get("queen_midnight_bat",false) and e.can_attack(who,c.uid):return c
 return {}

static func red_damage(e,who: int) -> int:
 return int(e.players[who].get("life_gained",{}).get(str(e.turn),0))+3

static func red_setup_choice(e,who: int) -> Dictionary:
 # Only existing, payable REDs justify spending a small body to gain life.
 # Simulate real combat: first strike, prevention, known responses and attack
 # taxes can all invalidate the apparent setup. Never count forecast healing
 # as damage already available to the live RED/removal target selector.
 if e.active!=who or e.priority!=who or e.phase!="main" or not e.pending.is_empty() or not e.stack.is_empty() or not e.combat.is_empty():return {}
 if not e.units(who).any(func(c):return c.card_id==REMILIA and e.Roster.has(e.cards[c.card_id],"remilia_lifelink")):return {}
 var reds=e.legal_casts(who).filter(func(c):return c.card_id==RED)
 if reds.is_empty():return {}
 if reds.any(func(c):return preview_damage(e,c,{"player":1-who},red_damage(e,who),false)>=e.players[1-who].life):return {}
 # Stop feeding bodies once earned life reaches a real core-removal threshold.
 if red_damage(e,who)>3:
  var cores=removal_enemies(e,who).filter(func(c):return battlefield_engine(e,c) or e.Roster.character_matches(e.cards[c.card_id].character,"博丽灵梦"))
  if reds.any(func(c):return not removal_target(e,who,c,cores).is_empty()):return {}
 var key=position_key(e,who);var memory=e.ai_memory[who]
 if memory.get("red_setup_key","")==key:return e.find_card(memory.get("red_setup_uid",-1))
 memory.red_setup_key=key;memory.red_setup_uid=-1
 var small=e.units(who).filter(func(c):return e.can_attack(who,c.uid) and e.Roster.lifesteal(e,c)>0 and e.Extra.cost_value(e,c)<=3 and not e.Roster.character_matches(e.cards[c.card_id].character,"蕾米莉亚") and attack_allowed(e,c))
 small.sort_custom(func(a,b):return strength(e,a)<strength(e,b))
 if small.is_empty():return {}
 var sim=simulation(e,who);var before=capture_sim(sim);var gained=red_damage(e,who)
 for c in small:
  restore_sim(sim,before)
  if not execute(sim,who,{"kind":"attack","uid":c.uid}) or not settle_sim(sim,who):continue
  if sim.winner!=-2 or red_damage(sim,who)<=gained:continue
  if not sim.units(who).any(func(u):return u.card_id==REMILIA):continue
  if not sim.legal_casts(who).any(func(u):return u.card_id==RED):continue
  memory.red_setup_uid=c.uid
  return c
 return {}

static func high_value_enemy(e,c: Dictionary) -> bool:
 return e.Roster.character_matches(e.cards[c.card_id].character,"博丽灵梦") or c.card_id==CLOUD or e.Extra.has(e.cards[c.card_id],"enter_fight") or e.Extra.cost_value(e,c)>=4 or e.stat(c,"power")>=5 or e.stat(c,"health")-c.damage>=5 or e.stat(c,"spirit")>=4 or battlefield_engine(e,c) or Counterplay.target_bonus(e,c)>0

static func battlefield_engine(e,c: Dictionary) -> bool:
 var info=e.cards[c.card_id]
 if info.kind!="自机":return false
 # Leader abilities sustain the board; independent activations remain threats
 # on non-leader copies too (including Yuyuko's sacrifice and Keine's devour).
 return e.has_leader_ability(c) or not e.Extra.activation_kind(info).is_empty() or not e.Roster.key(info,e.Roster.ACTIVATIONS).is_empty() or info.abilities.any(func(a):return a.get("实现","")=="activated_damage")

static func gungnir_engine(e,c: Dictionary) -> bool:
 return battlefield_engine(e,c) and e.stat(c,"health")-c.damage<=4 and dies_to(e,c,preview_damage(e,{"card_id":GUNGNIR,"owner":1-c.owner},c,4,false))

static func gungnir_value(e,c: Dictionary) -> int:
 var score=threat_score(e,c)
 if e.Roster.character_matches(e.cards[c.card_id].character,"博丽灵梦"):
  score+=REIMU_PRIORITY if e.stat(c,"health")-c.damage+ward_amount(e,c)<=4 else 3000
 elif gungnir_engine(e,c):score+=ENGINE_PRIORITY
 elif c.card_id==CLOUD:score+=2200
 return score

static func upcoming_gungnir_value(e,who: int) -> int:
 var sim=simulation(e,who);var enemy=1-who;var known=known_hand(e,who)
 var offered=sim.leaders(enemy).filter(func(c):return c.zone=="leader")
 offered.append_array(sim.players[enemy].hand.filter(func(c):return known.has(str(c.uid)) and sim.is_unit(c)))
 var incoming=sim.stack.filter(func(s):return s.kind=="card" and s.owner==enemy and sim.is_unit(s.card)).map(func(s):return s.card)
 offered.append_array(incoming)
 sim.pending={};sim.stack=[];sim.combat={};sim.active=enemy;sim.priority=enemy;sim.phase="main";sim.passes=0
 if e.active==who:
  sim.turn+=1;sim.players[enemy].turns+=1;sim.turn_usage={}
  for p in sim.players:
   p.mana=[]
   for c in p.field:c.damage=0;c.modifiers=[];c.wards=c.get("wards",[]).filter(func(w):return w.get("turn",-1)==-1)
  for c in sim.players[enemy].palette+sim.players[enemy].field:
   if sim.Pack.reset_allowed(sim,c):c.tapped=false
  # The next palette growth can supply one missing color. This is a possible
  # public threat, not knowledge of the hidden top card or a guaranteed cast.
  if sim.players[enemy].palette.size()<8 and not sim.players[enemy].deck.is_empty():
   sim.players[enemy].mana.append({"uid":-9100,"colors":Array(e.COLORS),"weight":1000,"kind":"possible_growth"})
 var before=capture_sim(sim);var best=0
 for candidate in offered:
  restore_sim(sim,before)
  var c=sim.find_card(candidate.uid) if candidate not in incoming else candidate.duplicate(true)
  if c.is_empty():continue
  if candidate not in incoming and not sim.cast_error(enemy,c.uid).is_empty():continue
  var fight_paid=c.card_id==CLOUD and (c.get("ichirin_paid",false) or sim.payment(enemy,sim.cast_cost(enemy,c,{"extra_green":true})).ways>0)
  sim.detach(c)
  if not sim.enter_field(c,enemy):continue
  var source={"card_id":GUNGNIR,"owner":who}
  if not dies_to(sim,c,preview_damage(sim,source,c,4,false)):continue
  if not high_value_enemy(sim,c):continue
  var value=gungnir_value(sim,c)
  if fight_paid and remilia_present(sim,who):value+=1000
  best=maxi(best,value)
 return best

static func gungnir_reserve_score(e,who: int) -> int:
 if not e.players[who].hand.any(func(c):return c.card_id==GUNGNIR):return 0
 var key=position_key(e,who)+JSON.stringify(e.stack)
 var memory=e.ai_memory[who]
 if memory.get("gun_reserve_key","")==key:return memory.gun_reserve_score
 var score=upcoming_gungnir_value(e,who)
 for c in e.units(1-who):
  if e.stat(c,"health")-c.damage+ward_amount(e,c)>4:score=maxi(score,maxi(2000,gungnir_value(e,c)))
  elif e.Roster.character_matches(e.cards[c.card_id].character,"博丽灵梦") or gungnir_engine(e,c):score=maxi(score,gungnir_value(e,c))
 memory.gun_reserve_key=key;memory.gun_reserve_score=score
 return score

static func use_gungnir(e,who: int,enemy: Dictionary,last: bool=false,rescue: bool=false) -> bool:
 if not gungnir_target_allowed(e,who,enemy):return false
 if rescue:return true
 var reserved=gungnir_reserve_score(e,who)
 if reserved==0:return true
 # A combat-damaged blocker is the opportunity the reserved gun was waiting for.
 if enemy.damage>0 and not e.combat.is_empty() and e.combat.blockers.any(func(t):return t.uid==enemy.uid):
  return (reserved<REIMU_PRIORITY or gungnir_value(e,enemy)>=reserved) and gungnir_value(e,enemy)>=upcoming_gungnir_value(e,who)
 if high_value_enemy(e,enemy) and gungnir_value(e,enemy)>=reserved:return true
 # Finishing the attack sequence does not cancel a still-useful reservation.
 return last and upcoming_gungnir_value(e,who)==0 and not e.units(1-who).any(func(c):return e.stat(c,"health")-c.damage+ward_amount(e,c)>4)

static func threat_score(e,c: Dictionary) -> int:
 var score=e.Extra.cost_value(e,c)*100+e.stat(c,"power")*30+e.stat(c,"spirit")*80
 score+=Counterplay.target_bonus(e,c)
 if e.cards[c.card_id].kind=="自机" and e.has_leader_ability(c):score+=1000
 if e.Roster.enabled(e,c,"remilia_aura"):
  score+=e.units(c.owner).filter(func(u):return u.uid!=c.uid and "黑" in e.Pack.colors(e,u)).size()*240
 if e.Roster.has(e.cards[c.card_id],"remilia_lifelink"):
  score+=e.units(c.owner).filter(func(u):return "红" in e.Pack.colors(e,u)).size()*160
 return score

static func removal_enemies(e,who: int) -> Array:
 var dangers=dangerous_blockers(e,who)
 var enemies=e.units(1-who).filter(func(c):return high_value_enemy(e,c) or dangers.any(func(b):return b.uid==c.uid))
 enemies.sort_custom(func(a,b):return threat_score(e,a)>threat_score(e,b))
 return enemies

static func aurora_sacrifice_target(e,who: int,choices: Array=[]) -> Dictionary:
 if e.players[1-who].life<=3:return {}
 var enemies=e.units(1-who)
 # The opponent chooses what dies: every available sacrifice must be worthwhile.
 if enemies.is_empty() or enemies.size()>2 or not enemies.all(func(c):return high_value_enemy(e,c) and e.can_sacrifice(c)):return {}
 if choices.is_empty():choices=e.legal_casts(who)
 for c in choices:
  if c.card_id not in [GUNGNIR,MIST,AUTUMN,RED]:continue
  var t=removal_target(e,who,c,enemies)
  if t.is_empty() or not role_removal_ready(e,who,c,t):continue
  if c.card_id==GUNGNIR and not use_gungnir(e,who,e.find_card(t.uid)):continue
  # Keep cheaper effective removal; a four-mana Mist should not displace
  # a three-mana sacrifice, especially against one isolated large body.
  if e.cast_cost(who,c,t).values().reduce(func(n,v):return n+int(v),0)<=3:return {}
 return {"player":1-who,"mode":"牺牲单位"}

static func aurora_pressure_target(e,who: int) -> Dictionary:
 # Spend spare mana on life loss while closing the game, without abandoning
 # a leader already waiting for recovery or burning it early through blockers.
 if e.players[who].leader.zone=="grave":return {}
 if e.players[1-who].life<=int(Counterplay.field_policy(e,who).life_loss_threshold) or remilia_present(e,who) and e.units(1-who).all(func(c):return c.tapped):
  return {"player":1-who,"mode":"失去生命"}
 return {}

static func groups(e,attacker: Dictionary) -> Array:
 var available=e.blockers_for(attacker)
 var result=[]
 var minimum=2 if e.Extra.keyword(e,attacker,"威吓") else 1
 for mask in range(1,1<<available.size()):
  var group=[]
  for i in range(available.size()):
   if mask&(1<<i):group.append(available[i])
  if group.size()>=minimum:result.append(group)
 return result

static func preview_damage(e,source: Dictionary,target: Dictionary,amount: int,combat: bool) -> int:
 if not combat and not source.is_empty() and (e.is_unit(source) or e.Pack.role(e.cards[source.card_id])):
  amount+=e.players[source.owner].field.filter(func(c):return e.Pack.has(e.cards[c.card_id],"furnace")).size()
 if e.unpreventable_turn==e.turn:return amount
 if target.has("player"):
  for ward in e.players[target.player].get("wards",[]):
   if ward.get("turn",e.turn) in [-1,e.turn]:amount=maxi(0,amount-int(ward.amount))
  return amount
 if e.Extra.keyword(e,target,"防止伤害"):return 0
 if not combat and (e.Roster.has(e.cards[target.card_id],"sannyo_prevent") or e.cards[target.card_id].kind=="自机" and e.players[target.owner].field.any(func(u):return e.Pack.has(e.cards[u.card_id],"paranoid"))):return 0
 for ward in target.get("wards",[]):
  if ward.get("turn",e.turn) in [-1,e.turn]:amount=maxi(0,amount-int(ward.amount))
 return amount

static func dies_to(e,c: Dictionary,damage: int) -> bool:
 return e.stat(c,"health")<=0 or damage>=e.stat(c,"health")-c.damage and not e.Extra.keyword(e,c,"不会被消灭")

static func fight(e,attacker: Dictionary,blockers: Array) -> Dictionary:
 # Preview both strike rounds on private fighter copies, consuming their wards.
 var a=attacker.duplicate(true);var remaining=blockers.duplicate(true)
 var dead=[];var attacker_dead=false
 var first=e.Extra.keyword(e,a,"先制") or remaining.any(func(b):return e.Extra.keyword(e,b,"先制"))
 for stage in (["first","second"] if first else ["normal"]):
  if attacker_dead or remaining.is_empty():break
  var strikes=func(c):return stage=="normal" or e.Extra.keyword(e,c,"先制")== (stage=="first")
  var power=e.stat(a,"power") if strikes.call(a) else 0
  var allocation=damage_allocation(e,a,remaining,power)
  var retaliation={}
  for b in remaining:retaliation[b.uid]=e.stat(b,"power") if strikes.call(b) else 0
  # Damage is simultaneous within each round, including retaliation by dying bodies.
  for b in remaining:
   preview_hit(e,a,b,int(allocation.get(str(b.uid),0)))
   preview_hit(e,b,a,retaliation[b.uid])
  attacker_dead=dies_to(e,a,0)
  for b in remaining.duplicate():
   if dies_to(e,b,0):dead.append(b.uid);remaining.erase(b)
 return {"attacker_dead":attacker_dead,"dead":dead,"alive":remaining.map(func(b):return b.uid)}

static func ward_amount(e,c: Dictionary) -> int:
 if e.unpreventable_turn==e.turn:return 0
 return c.get("wards",[]).filter(func(w):return w.get("turn",e.turn) in [-1,e.turn]).reduce(func(n,w):return n+int(w.amount),0)

static func damage_allocation(e,attacker: Dictionary,blockers: Array,total: int) -> Dictionary:
 var allocation={};var left=total;var ordered=blockers.duplicate()
 var needed=func(b):return maxi(0,e.stat(b,"health")-b.damage)+ward_amount(e,b)
 ordered.sort_custom(func(a,b):
  if night_empowered(e,attacker):
   var a_core=night_core(e,a) and needed.call(a)<=total and not e.Extra.keyword(e,a,"防止伤害") and not e.Extra.keyword(e,a,"不会被消灭")
   var b_core=night_core(e,b) and needed.call(b)<=total and not e.Extra.keyword(e,b,"防止伤害") and not e.Extra.keyword(e,b,"不会被消灭")
   if a_core!=b_core:return a_core
  return needed.call(a)<needed.call(b))
 for b in ordered:
  var amount=mini(left,needed.call(b))
  if e.Extra.keyword(e,b,"防止伤害") or e.Extra.keyword(e,b,"不会被消灭"):amount=0
  allocation[str(b.uid)]=amount;left-=amount
 if left>0 and not ordered.is_empty():allocation[str(ordered[0].uid)]+=left
 return allocation

static func preview_hit(e,source: Dictionary,target: Dictionary,amount: int):
 if amount<=0:return
 var dealt=preview_damage(e,source,target,amount,true)
 if e.unpreventable_turn!=e.turn and not e.Extra.keyword(e,target,"防止伤害"):
  for w in target.get("wards",[]).duplicate():
   if amount<=0:break
   target.wards.erase(w)
   if w.get("turn",e.turn) in [-1,e.turn]:amount=maxi(0,amount-int(w.amount))
 if e.Roster.has(e.cards[source.card_id],"momoyo_wither"):target.minus_counters=int(target.get("minus_counters",0))+dealt
 else:target.damage+=dealt

static func dangerous_blockers(e,who: int,attackers: Array=[]) -> Array:
 if attackers.is_empty():attackers=ready_units(e,who)
 var result=[]
 for a in attackers:
  if night_trade_allowed(e,a):continue
  for group in groups(e,a):
   var outcome=fight(e,a,group)
   if outcome.attacker_dead and (outcome.dead.is_empty() or e.Roster.character_matches(e.cards[a.card_id].character,"蕾米莉亚")):
    for b in group:
     if not result.any(func(c):return c.uid==b.uid):result.append(b)
 result.sort_custom(func(a,b):return strength(e,a)>strength(e,b))
 return result

static func ready_units(e,who: int) -> Array:
 return e.units(who).filter(func(c):return not c.tapped and (not e.summoning_sick(c) or e.has_haste(c)) and e.Cat.State.can_combat(e,c))

static func defensive_blocks(e) -> Array:
 var attacker=e.find_card(e.combat.attacker.uid)
 var best=[];var score=2147483647
 for group in groups(e,attacker):
  var outcome=fight(e,attacker,group)
  if not outcome.attacker_dead or not outcome.dead.is_empty():continue
  var value=group.reduce(func(n,c):return n+strength(e,c),0)
  if value<score:score=value;best=group.map(func(c):return c.uid)
 # Preserving bodies is meaningless when the current unblocked hit loses the
 # game. Check real combat/death triggers before accepting a costly rescue.
 var hit=preview_damage(e,attacker,{"player":1-attacker.owner},e.stat(attacker,"spirit"),true)
 var coins=hit>0 and e.Roster.enabled(e,attacker,"komachi_coins") and int(e.players[1-attacker.owner].get("coins",0))>=2
 if best.is_empty() and (hit>=e.players[1-attacker.owner].life or coins):
  best=survival_blocks(e,attacker)
 # Some opponents impose a mandatory block; use the cheapest legal group then.
 if best.is_empty() and e.Cat.has(e,attacker,"character-fdf-090"):
  for group in groups(e,attacker):
   var value=group.reduce(func(n,c):return n+strength(e,c),0)
   if value<score:score=value;best=group.map(func(c):return c.uid)
 return best

static func survival_blocks(e,attacker: Dictionary) -> Array:
 if e.pending.get("kind","")!="block":return []
 var who=1-attacker.owner;var sim=simulation(e,who);var start=capture_sim(sim)
 var candidates=groups(e,attacker);var best=[];var best_score=-INF
 for group in candidates:
  restore_sim(sim,start)
  var uids=group.map(func(c):return c.uid)
  sim.block(uids)
  if sim.pending.get("kind","")=="block" or not settle_sim(sim,attacker.owner):continue
  # Annihilate and death damage can make an apparent chump block still fatal.
  if sim.winner==attacker.owner or sim.players[who].life<=0:continue
  var loss=0
  for c in group:
   var remaining=sim.find_card(c.uid)
   if remaining.is_empty() or remaining.zone!="field":loss+=strength(e,c)+(100000 if c.uid==e.players[who].leader.uid else 0)
  var value=(1000000 if sim.winner==who else 0)+sim.players[who].life*100-loss-uids.size()
  if value>best_score:best_score=value;best=uids
 return best

static func removal_target(e,who: int,c: Dictionary,enemies: Array) -> Dictionary:
 var options=e.targets_for(c.card_id,who,c.uid)
 for enemy in enemies:
  var sacrifice=autumn_sacrifice(e,who,enemy) if c.card_id==AUTUMN else {}
  if c.card_id==AUTUMN and sacrifice.is_empty():continue
  if c.card_id==MIST:
   if e.Extra.keyword(e,enemy,"不会被消灭"):continue
  elif c.card_id in [GUNGNIR,AUTUMN,RED]:
   var amount=4 if c.card_id==GUNGNIR else 5 if c.card_id==AUTUMN else red_damage(e,who)
   if not dies_to(e,enemy,preview_damage(e,c,enemy,amount,false)):continue
  else:continue
  for t in options:
   if t.get("uid",-1)!=enemy.uid:continue
   if c.card_id==AUTUMN and t.get("sacrifice",{}).get("uid",-1)!=sacrifice.uid:continue
   if e.payment(who,e.cast_cost(who,c,t)).ways>0:return t
 return {}

static func removal_collateral_safe(e,who: int,c: Dictionary,t: Dictionary) -> bool:
 var target=e.find_card(t.get("uid",-1))
 if target.is_empty() or target.owner==who or not e.Extra.has(e.cards[target.card_id],"death_six"):return true
 if e.players[target.owner].get("night_lock",-1)==e.turn:return true
 # Okuu's public death sweep can destroy our aura and every attacker. Settle
 # the actual removal (including prevention and death triggers) on a copy.
 var sim=simulation(e,who);var card=sim.find_card(c.uid)
 var payment=sim.payment(who,sim.cast_cost(who,card,t))
 if payment.ways==0 or not sim.commit_cast(who,card.uid,t,payment.plan).is_empty():return false
 if not settle_sim(sim,who):return false
 if sim.winner==who:return true
 if sim.winner==1-who:return false
 var losses=[0,0]
 for seat in [who,1-who]:
  for unit in e.units(seat):
   var after=sim.find_card(unit.uid)
   if not after.is_empty() and after.zone=="field" and after.owner==seat:continue
   losses[seat]+=e.Extra.cost_value(e,unit)*10+e.stat(unit,"spirit")*5
   if unit.uid==e.players[seat].leader.uid:losses[seat]+=80
 return losses[who]<=losses[1-who]

static func remove_blocker(e,who: int,choices: Array,last: bool=false) -> bool:
 var enemies=removal_enemies(e,who)
 if enemies.is_empty():return false
 if choices.any(func(c):return c.card_id==GUNGNIR):enemies.sort_custom(func(a,b):return gungnir_value(e,a)>gungnir_value(e,b))
 for enemy in enemies:
  for id in [GUNGNIR,MIST,AUTUMN,RED]:
   if last and id not in [GUNGNIR,RED]:continue
   # Reimu's matchup bonus does not promote RED ahead of attacks/expansion.
   # Other live engines retain removal priority when no lifesteal setup exists.
   if id==RED and not last and not battlefield_engine(e,enemy):continue
   if id==RED and not last and red_damage(e,who)<=3 and e.Roster.character_matches(e.cards[enemy.card_id].character,"博丽灵梦"):continue
   for c in choices:
    if c.card_id!=id:continue
    if id==GUNGNIR and not use_gungnir(e,who,enemy,last):continue
    var t=removal_target(e,who,c,[enemy])
    if not t.is_empty() and cast(e,who,c,t):return true
 return false

static func establish_gungnir(e,who: int,choices: Array) -> bool:
 if remilia_present(e,who):return false
 var leader=e.players[who].leader
 if not choices.any(func(c):return c.uid==leader.uid):return false
 var enemies=removal_enemies(e,who).filter(func(c):return gungnir_engine(e,c))
 enemies.sort_custom(func(a,b):return gungnir_value(e,a)>gungnir_value(e,b))
 for gun in e.players[who].hand:
  if gun.card_id!=GUNGNIR:continue
  for enemy in enemies:
   if not use_gungnir(e,who,enemy):continue
   var t=removal_target(e,who,gun,[enemy])
   if t.is_empty() or not role_removal_ready(e,who,gun,t):continue
   # Pay for the leader while reserving the actual red/black gun sources.
   var cost=e.cast_cost(who,leader,{"none":true});var gun_cost=e.cast_cost(who,gun,t)
   var combined=cost.duplicate()
   for color in gun_cost:combined[color]=int(combined.get(color,0))+int(gun_cost[color])
   var together=e.payment(who,combined)
   if together.ways==0:continue
   var plan=together.plan.duplicate()
   for color in gun_cost:
    for i in range(int(gun_cost[color])):
     var matches=plan.filter(func(r):return r.color in color.split("/"))
     if matches.is_empty():return false
     plan.remove_at(plan.find(matches[0]))
   if e.payment_valid(who,cost,plan):return e.commit_cast(who,leader.uid,{"none":true},plan).is_empty()
 return false

static func fast_removal(e,who: int) -> bool:
 # Gungnir also removes tapped leaders, before their next attack/entry trigger.
 # Combat rescue has priority; outside combat, only spend on public core threats.
 if e.active==who:return false
 return remove_blocker(e,who,e.legal_casts(who,true).filter(func(c):return c.card_id==GUNGNIR))

static func attack_choice(e,who: int) -> Dictionary:
 var queen_bat=queen_bat_attacker(e,who)
 if not queen_bat.is_empty():return queen_bat
 var setup=red_setup_choice(e,who)
 if not setup.is_empty():return setup
 var probe=reimu_probe_choice(e,who)
 if not probe.is_empty():return probe
 var available=e.units(who).filter(func(c):return e.can_attack(who,c.uid))
 available.sort_custom(func(a,b):return strength(e,a)<strength(e,b))
 var eligible=available.filter(func(c):return attack_allowed(e,c))
 var dangers=dangerous_blockers(e,who,available)
 if dangers.is_empty():return eligible[0] if not eligible.is_empty() else {}
 var memory=e.ai_memory[who]
 if available.size()>=dangers.size()+2:memory.swarm_turn=e.turn
 if memory.get("swarm_turn",-1)==e.turn and available.size()>dangers.size() and not eligible.is_empty():return eligible[0]
 for c in eligible:
  if c.card_id in BIG_UNITS or dangerous_blockers(e,who,[c]).is_empty():return c
 return {}

static func attack_allowed(e,c: Dictionary) -> bool:
 # Protect the aura unless a real Night King exchange removes an enemy core.
 if c.is_empty():return false
 if c.get("queen_midnight_bat",false):return true
 # These finishers keep attacking through fatal blocks for lifesteal or triggers.
 # Small Remilia's persistent aura still requires survival.
 if c.card_id in BIG_UNITS:return true
 if e.Roster.character_matches(e.cards[c.card_id].character,"蕾米莉亚"):
  if groups(e,c).any(func(group):return fight(e,c,group).attacker_dead):return night_trade_allowed(e,c)
  return not response_can_kill(e,c)
 # Do not trade a costly pressure unit for one cheap member of a multi-block.
 if e.Extra.cost_value(e,c)>=4:
  for group in groups(e,c):
   var outcome=fight(e,c,group)
   if outcome.attacker_dead and group.filter(func(b):return b.uid in outcome.dead).reduce(func(n,b):return n+threat_score(e,b),0)<threat_score(e,c):return false
 return true

static func night_empowered(e,c: Dictionary) -> bool:
 return not c.is_empty() and e.active==c.owner and e.players[1-c.owner].get("night_lock",-1)==e.turn and c.get("modifiers",[]).any(func(m):return m.get("攻击力",0)==4 and m.get("血量",0)==4 and m.get("灵力",0)==3 and m.get("歼灭",false))

static func night_core(e,c: Dictionary) -> bool:
 return e.Roster.character_matches(e.cards[c.card_id].character,"博丽灵梦") or battlefield_engine(e,c)

static func night_trade_allowed(e,c: Dictionary) -> bool:
 if not night_empowered(e,c) or not e.Roster.character_matches(e.cards[c.card_id].character,"蕾米莉亚"):return false
 var trades=false
 for group in groups(e,c):
  var outcome=fight(e,c,group)
  if not outcome.attacker_dead:continue
  trades=true
  # Every block that kills Remilia must actually lose an opposing core.
  if not group.any(func(b):return b.uid in outcome.dead and night_core(e,b)):return false
 return trades

static func protect_remilia(e,who: int) -> bool:
 var leader=e.players[who].leader
 if leader.card_id!=REMILIA or leader.zone!="field" or e.players[who].life<=2:return false
 for hina in e.units(who):
  if hina.card_id!=HINA or not e.extension_activation_error(who,hina,"hina_redirect").is_empty():continue
  var options=e.Extra.activation_options(e,hina,"hina_redirect")
  options.sort_custom(func(a,b):return a.stack_id>b.stack_id)
  for target in options:
   if target.redirect.get("uid",-1)!=leader.uid:continue
   var threat=e.stack.filter(func(s):return s.id==target.stack_id and s.owner!=who)
   if threat.is_empty():continue
   # The original target remains unchanged until our activation resolves.
   # Do not pay again for the same pending target slot, even with several Hinas.
   var covered=e.stack.any(func(s):return s.owner==who and s.get("effect","")=="hina_redirect" and s.target.get("stack_id",-1)==target.stack_id and s.target.get("redirect",{})==target.redirect and s.target.get("redirect_index",0)==target.get("redirect_index",0))
   if covered:continue
   var pay=e.payment(who,e.extension_cost(who,hina,"hina_redirect",target))
   if pay.ways>0 and e.commit_extension(who,hina.uid,target,pay.plan,"hina_redirect").is_empty():return true
 return false

static func combat_response(e,who: int) -> bool:
 if e.combat.is_empty():return false
 var attacker=e.find_card(e.combat.attacker.uid)
 var enemies=[];var rescue=false
 if e.combat.owner==who:
  enemies=e.combat.blockers.map(func(t):return e.find_card(t.uid)).filter(func(c):return not c.is_empty())
  if e.combat.get("step","") not in ["first_damage_window","damage_window"]:
   rescue=not attacker.is_empty() and fight(e,attacker,enemies).attacker_dead
   if not rescue:return false
 else:
  if attacker.is_empty():return false
  var blockers=e.combat.blockers.map(func(t):return e.find_card(t.uid)).filter(func(c):return not c.is_empty())
  if not blockers.is_empty() and not fight(e,attacker,blockers).dead.is_empty():enemies=[attacker];rescue=true
 enemies=enemies.filter(func(c):return use_gungnir(e,who,c,false,rescue))
 enemies.sort_custom(func(a,b):return gungnir_value(e,a)>gungnir_value(e,b))
 for c in e.legal_casts(who,true):
  if c.card_id!=GUNGNIR:continue
  var t=removal_target(e,who,c,enemies)
  if not t.is_empty() and cast(e,who,c,t):return true
 return false

static func effect_target(e,who: int,options: Array,trigger: Dictionary) -> Dictionary:
 if options.is_empty():return {}
 var effect=trigger.get("effect","")
 if effect=="crystal" and e.ai_profiles[who]==PROFILE:return crystal_target(e,who,options)
 if effect=="lily_color":
  for t in options:
   if t.get("color","")=="红":return t
 if effect=="sacrifice_choice":
  var c=weakest(e,who)
  for t in options:
   if t.get("uid",-1)==c.get("uid",-2):return t
 if effect=="leader_enter_modes":
  var enemies=dangerous_blockers(e,who)
  for mode in ["造成2点伤害","横置"]:
   for enemy in enemies:
    if mode=="造成2点伤害" and not dies_to(e,enemy,preview_damage(e,trigger.source,enemy,2,false)):continue
    for t in options:
     if t.get("uid",-1)==enemy.uid and t.get("mode","")==mode:return t
  for t in options:
   if t.get("mode","")=="抓一张牌":return t
 if effect=="enter_grave_damage":
  var best=aya_target(e,who)
  return best if best in options else {}
 if effect=="character-fdf-065":
  for t in options:
   if t.get("player",-1)==1-who:return t
 if effect=="character-fdf-069":
  var attacker=e.find_card(e.combat.get("attacker",{}).get("uid",-1))
  if not attacker.is_empty() and attacker.owner!=who:
   for option in options:
    if not option.has("selection"):continue
    var target=option.duplicate(true);target.erase("selection");target.picks=[]
    for group in option.selection:target.picks.append(group.pool.filter(func(r):return r.get("uid",-1)==attacker.uid).slice(0,1))
    if e.Pack.choice_valid(e,options,target) and not e.Pack.flatten(target).is_empty():return target
  return e.Pack.ai_target(e,who,options,"spread_damage")
 return e.Pack.ai_target(e,who,options,effect)

static func position_score(e,who: int) -> int:
 # Possession compares prospective arrays whose card zones still describe the
 # pre-exchange state. Normalize a private main-phase copy before asking the
 # rules engine which cards actually work, including roles, titles and colors.
 if e.phase=="possession":
  var sim=simulation(e,who)
  for c in sim.players[who].hand:c.zone="hand"
  for c in sim.players[who].palette:c.zone="palette"
  sim.pending={};sim.phase="main";sim.active=who;sim.priority=who
  return position_score(sim,who)
 var score=e.ai_position_score(who)
 var offered=e.players[who].hand.duplicate()
 offered.append(e.players[who].leader)
 var seen=[]
 var enemies=removal_enemies(e,who)
 for c in offered:
  if c.card_id in seen:continue
  seen.append(c.card_id)
  if c.zone=="leader" and c.timer>0:continue
  # Affordable is not playable: after a wipe a six-mana Remilia may lack
  # battlefield colors, or a support spell may lack its character entirely.
  var playable=e.cast_error(who,c.uid).is_empty()
  if playable:score+=card_priority(e,who,c)
  if c.card_id==AURORA and e.payment(who,e.cast_cost(who,c)).ways>0:
   if e.players[1-who].life<=3:score+=10000
   elif not aurora_sacrifice_target(e,who,offered).is_empty():
    score+=2800+e.units(1-who).map(func(u):return threat_score(e,u)).min()
   elif not aurora_pressure_target(e,who).is_empty():score+=1200
  if c.card_id in [GUNGNIR,MIST,AUTUMN,RED]:
   var t=removal_target(e,who,c,enemies)
   if not t.is_empty() and role_removal_ready(e,who,c,t) and removal_collateral_safe(e,who,c,t):
    var removal_bonus=1800+threat_score(e,e.find_card(t.uid))
    score+=int(removal_bonus/4) if c.card_id==RED else removal_bonus
   if c.card_id==AUTUMN and not bound_autumn_target(e,who,c).is_empty():score+=10000
  # Early possession preserves cheap interaction over an unreachable seven-
  # mana body of the same colors, even before the role can use the spell.
  if c.card_id==GUNGNIR:score+=200
  if c.card_id==GUNGNIR and Counterplay.reimu_scope(e,who):
   var reimu_target=removal_target(e,who,c,Counterplay.reimu_units(e,who))
   if not reimu_target.is_empty() and role_removal_ready(e,who,c,reimu_target):score+=7000
  if c.card_id==GUNGNIR and remilia_present(e,who) and e.payment(who,e.cast_cost(who,c)).ways>0 and gungnir_reserve_score(e,who)>0:score+=2000
  if c.card_id==RED and playable:score+=1100+red_damage(e,who)*60
  if c.card_id==QUEEN and queen_priority(e,who,c)>400:score+=queen_priority(e,who,c)
  if c.card_id==NIGHT and remilia_present(e,who) and e.payment(who,e.cast_cost(who,c)).ways>0:
   score+=night_priority(e,who)*3
   if not reimu_night_target(e,who,c).is_empty():score+=5000
 if e.players[who].leader.card_id==REMILIA and e.players[who].leader.zone=="hand":
  var missing=missing_leader_colors(e,who)
  var reachable=[]
  for c in e.players[who].hand:
   if c.uid==e.players[who].leader.uid or not e.cast_error(who,c.uid).is_empty():continue
   for color in replay_source_colors(e,who,c):
    if color in missing and color not in reachable:reachable.append(color)
  score+=reachable.size()*5000
 # Maintain access to both core colors even when the current hand is expensive.
 for cost in [{"红":1},{"黑":1},{"红":1,"黑":1},{"红":2,"黑":1},{"黑":3}]:
  if e.payment(who,cost).ways>0:score+=40
 return score

static func night_priority(e,who: int) -> int:
 if e.players[1-who].get("night_lock",-1)==e.turn:return 0
 var score=120 if e.COLORS.any(func(color):return e.payment(1-who,{color:1}).ways>0) else 0
 score+=int(Counterplay.field_policy(e,who).night_bonus)
 for c in e.units(1-who):
  var info=e.cards[c.card_id]
  var death_keys=["death_draw_life","death_drain","death_palette","death_damage","death_poverty","death_six","death_undying","death_devour","leader_death_damage","larva_draw","shanghai_draw","seiga_death","character-fdn-024","character-fdf-106","character-fdf-069","character-fdn-021","character-fdn-004","character-fdf-105","character-fdf-065","character-fdn-034","character-fdf-029:self","character-fdn-042","n21:ETO-002:self"]
  if info.abilities.any(func(a):return a.get("参数",{}).get("效果",a.get("实现","")) in death_keys) or c.has("rank_target") or not c.get("medicine",[]).is_empty():score+=100
 return mini(score,420)

static func lethal_threshold(e,who: int,include_palette: bool=false) -> int:
 # This is an optimistic search gate, never proof of a kill. Actual routes
 # still pay combined colors and resolve blockers, wards and known responses.
 var attackers=ready_units(e,who)
 var damage=0;var gained=0
 for c in attackers:
  damage+=maxi(0,e.stat(c,"spirit"))
  gained+=e.Roster.lifesteal(e,c)
  if e.Cat.has(e,c,"character-fdf-065"):damage+=2;gained+=2
 var hand=e.players[who].hand.duplicate()
 if include_palette:hand.append_array(e.players[who].palette.filter(func(c):return not c.tapped and e.can_possess(c)))
 var aura=e.units(who).filter(func(c):return e.Roster.has(e.cards[c.card_id],"remilia_aura") and e.has_leader_ability(c)).size()
 var castles=e.players[who].field.filter(func(c):return c.card_id==CASTLE).size()
 var slots=e.Cat.field_limit(e,who)-e.field_slots(who)
 var queen=hand.filter(func(c):return c.card_id==QUEEN and e.payment(who,e.cast_cost(who,c)).ways>0)
 var queen_role=remilia_present(e,who) or e.leaders(who).any(func(c):return c.zone=="leader" and e.Roster.character_matches(e.cards[c.card_id].character,"蕾米莉亚"))
 if queen_role and slots>=4 and not queen.is_empty():
  damage+=4*(1+aura+castles)
  gained+=4*e.units(who).filter(func(c):return e.Roster.has(e.cards[c.card_id],"remilia_lifelink")).size()
 if remilia_present(e,who):
  var reds=hand.filter(func(c):return c.card_id==RED and e.payment(who,e.cast_cost(who,c)).ways>0)
  for i in range(reds.size()):damage+=red_damage(e,who)+gained+3*i
 damage+=3*hand.filter(func(c):return c.card_id==AURORA and e.payment(who,e.cast_cost(who,c)).ways>0).size()
 if hand.any(func(c):return c.card_id==NIGHT and e.payment(who,e.cast_cost(who,c)).ways>0):damage+=3
 return maxi(12,damage)

static func role_removal_ready(e,who: int,c: Dictionary,t: Dictionary) -> bool:
 if e.cards[c.card_id].requires_character.is_empty() or remilia_present(e,who):return true
 var leader=e.players[who].leader
 if leader.zone!="leader" or leader.timer>0 or not e.field_error(leader,who).is_empty():return false
 var provided=[]
 for u in e.players[who].field:
  if e.cards[u.card_id].kind!="符卡":provided.append_array(e.Pack.colors(e,u))
 if not e.units(who).any(func(u):return e.Cat.has(e,u,FAIRY)) and not e.cards[leader.card_id].colors.all(func(color):return color in provided):return false
 var combined=e.cast_cost(who,leader).duplicate()
 var removal_cost=e.cast_cost(who,c,t)
 for color in removal_cost:combined[color]=int(combined.get(color,0))+int(removal_cost[color])
 return e.payment(who,combined).ways>0

# Evaluate real fast spell effects and payments on a copy. Unknown hand slots may
# contain common color threats or spells seen in public opposing zones; they are
# possibilities, never observations of the actual hidden cards.
static func response_ids(e,who: int) -> Array:
 var ids=COLOR_RESPONSES.duplicate()
 for c in e.players[1-who].palette+e.players[1-who].grave+e.players[1-who].exile:
  if e.cards[c.card_id].kind=="符卡" and c.card_id not in ids:ids.append(c.card_id)
 return ids

static func response_targets(e,c: Dictionary,focus: Array) -> Array:
 if e.is_unit(c):return [{"none":true}]
 var result=[]
 for spec in e.targets_for(c.card_id,c.owner,c.uid):
  if not spec.has("selection"):
   if spec.has("none") or e.Pack.flatten(spec).any(func(r):return focus.any(func(f):return r.get("uid",-1)==f.get("uid",-2) or r.get("stack_id",-1)==f.get("stack_id",-2) or r.get("player",-1)==f.get("player",-2))):result.append(spec)
   continue
  var choices=[[]]
  for group in spec.selection:
   var pool=group.pool.filter(func(r):return focus.any(func(f):return r.get("uid",-1)==f.get("uid",-2) or r.get("stack_id",-1)==f.get("stack_id",-2) or r.get("player",-1)==f.get("player",-2)))
   if c.card_id=="114":pool.sort_custom(func(a,b):return e.find_card(a.get("uid",-1)).get("tapped",false) and not e.find_card(b.get("uid",-1)).get("tapped",false))
   var picks=[]
   if group.min<=1 and group.max>=1:
    for r in pool:picks.append([r])
   if c.card_id=="114" and group.max>=2:
    for i in range(pool.size()):
     for j in range(i+1,pool.size()):picks.append([pool[i],pool[j]])
   # Cost/reveal groups need their own legal choices even when not combat targets.
   if picks.is_empty() and group.pool.size()>=group.min:picks.append(group.pool.slice(0,group.min))
   var next=[]
   for prior in choices:
    for pick in picks:
     if next.size()<16:next.append(prior+[pick])
   choices=next
  for picks in choices:
   var target=spec.duplicate(true);target.erase("selection");target.picks=picks
   if e.Pack.choice_valid(e,[spec],target):result.append(target)
 return result

static func response_priority(e,action: Dictionary,attacker: Dictionary) -> int:
 var info=e.cards[action.card_id]
 var buff=e.DB.has_ability(info,"turn_buff") or action.card_id in ["177","110","131","spell-ucs-015"]
 var score=0 if action.inferred else 100
 for r in e.Pack.flatten(action.target):
  if r.has("stack_id"):score+=1000
  elif r.has("uid"):
   var target=e.find_card(r.uid)
   if (buff and target.owner!=attacker.get("owner",-1)) or (not buff and r.uid==attacker.get("uid",-1)):score+=500
 return score

static func response_actions(e,who: int,attacker: Dictionary,infer: bool=false,counters_only: bool=false) -> Array:
 var enemy=1-who;var actions=[];var focus=[]
 if not counters_only:
  if not attacker.is_empty():focus.append(e.ref_target(attacker))
  for c in (e.blockers_for(attacker) if not attacker.is_empty() else e.units(enemy)):focus.append(e.ref_target(c))
  focus.append({"player":enemy})
 for entry in e.stack:
  if entry.owner==who:focus.append({"stack_id":entry.id})
 var known=known_hand(e,who);var offered=[];var unknown={}
 for c in e.players[enemy].hand:
  if known.has(str(c.uid)):offered.append({"card":c,"inferred":false})
  elif unknown.is_empty():unknown=c
 if infer and not unknown.is_empty():
  for id in response_ids(e,who):
   var candidate=unknown.duplicate(true);candidate.card_id=id
   offered.append({"card":candidate,"inferred":true})
 for offer in offered:
  var c=offer.card
  if not e.Pack.fast(e,c,enemy) or e.cards[c.card_id].kind!="符卡" and not e.is_unit(c):continue
  var actual=e.find_card(c.uid);var original=actual.card_id
  actual.card_id=c.card_id
  var error=e.cast_error(enemy,c.uid)
  if error.is_empty():
   var targets=focus.duplicate()
   if c.card_id=="114":
    for u in e.units(enemy):targets.append(e.ref_target(u))
   for target in response_targets(e,c,targets):
    if counters_only and not e.Pack.flatten(target).any(func(r):return r.has("stack_id")):continue
    if e.payment(enemy,e.cast_cost(enemy,c,target)).ways>0:actions.append({"uid":c.uid,"card_id":c.card_id,"target":target,"inferred":offer.inferred})
  actual.card_id=original
 actions.sort_custom(func(a,b):return response_priority(e,a,attacker)>response_priority(e,b,attacker))
 return actions

static func commit_response(e,who: int,action: Dictionary) -> bool:
 var c=e.find_card(action.uid);c.card_id=action.card_id
 return cast(e,1-who,c,action.target)

static func settle_response(e,stop_stack: int=-1) -> bool:
 # Stop before continuing combat or resolving the friendly card under a response.
 for i in range(100):
  if e.winner!=-2:return true
  e.pump_choices()
  if not e.pending.is_empty():
   match e.pending.kind:
    "trigger_order":e.choose_trigger_order(0)
    "effect_choice":e.choose_effect(effect_target(e,e.pending.owner,e.pending.options,e.pending.trigger))
    "leader_return":e.choose_return(false)
    "timer":e.choose_timer(0)
    "grave_replacement":e.choose_grave_replacement(true)
    "ward_order":e.choose_ward(e.pending.options[0])
    "trigger":e.choose_trigger(e.pending.options[0] if not e.pending.options.is_empty() else {})
    _:return false
  elif e.stack.is_empty() or stop_stack>=0 and e.stack.back().id==stop_stack:return true
  else:e.pass_priority(e.priority)
 return false

static func response_can_kill(e,c: Dictionary) -> bool:
 var who=c.owner
 if e.players[1-who].hand.is_empty() and not e.units(1-who).any(func(u):return u.card_id=="character-fdf-069"):return false
 var key=position_key(e,who)+str(c.uid)
 var memory=e.ai_memory[who]
 if memory.get("attack_risk_key","")==key:return memory.attack_risk
 var sim=simulation(e,who);var attacker=sim.find_card(c.uid)
 attacker.tapped=true
 sim.combat={"attacker":sim.ref_target(attacker),"owner":who,"blockers":[],"blocked":false,"step":"attack_window"}
 sim.pending={};sim.stack=[];sim.priority=1-who;sim.passes=0
 var risk=response_kill_search(sim,who,c.uid,{"nodes":0,"seen":{}},0)
 memory.attack_risk_key=key;memory.attack_risk=risk
 return risk

static func response_kill_search(e,who: int,uid: int,ctx: Dictionary,depth: int) -> bool:
 var attacker=e.find_card(uid)
 if attacker.is_empty() or attacker.zone!="field" or attacker.owner!=who:return true
 if dies_to(e,attacker,0) or groups(e,attacker).any(func(group):return fight(e,attacker,group).attacker_dead):return true
 if kyouko_block_kills(e,who,attacker):return true
 var key=position_key(e,who)+str(e.players[1-who].hand)
 if ctx.seen.has(key):return false
 ctx.seen[key]=true;ctx.nodes+=1;e.priority=1-who
 var actions=response_actions(e,who,attacker,true)
 if actions.is_empty():return false
 # An exhausted risk budget does not certify the unexamined branches as safe.
 if depth>=7 or ctx.nodes>=RESPONSE_NODES:return true
 var before=capture_sim(e)
 for action in actions:
  restore_sim(e,before);e.priority=1-who
  if not commit_response(e,who,action) or not settle_response(e):continue
  if response_kill_search(e,who,uid,ctx,depth+1):return true
 return false

static func kyouko_block_kills(e,who: int,attacker: Dictionary) -> bool:
 # Combat preview alone misses Kyouko dying and then damaging the survivor.
 var candidates=groups(e,attacker).filter(func(group):return group.any(func(c):return c.card_id=="character-fdf-069" and c.uid in fight(e,attacker,group).dead))
 if candidates.is_empty():return false
 var before=capture_sim(e);var trial=e.get_script().new(e.cards)
 for group in candidates:
  restore_sim(trial,before)
  for i in range(8):
   trial.pump_choices()
   if not trial.pending.is_empty() or trial.combat.is_empty():break
   trial.pass_priority(trial.priority)
  if trial.pending.get("kind","")!="block":continue
  trial.block(group.map(func(c):return c.uid))
  if not settle_sim(trial,who):continue
  var survivor=trial.find_card(attacker.uid)
  if survivor.is_empty() or survivor.zone!="field":return true
 return false

static func response_value(e,who: int,attacker_uid: int,stack_id: int) -> int:
 var score=(e.players[1-who].life-e.players[who].life)*100
 for seat in [who,1-who]:
  for c in e.units(seat):
   var value=100+e.stat(c,"power")*10+maxi(0,e.stat(c,"health")-c.damage)*10+e.stat(c,"spirit")*20
   if e.Extra.keyword(e,c,"防止伤害"):value+=150
   score+=value if seat!=who else -value
 if stack_id>=0 and not e.stack.any(func(entry):return entry.id==stack_id):score+=10000
 if attacker_uid>=0:
  var attacker=e.find_card(attacker_uid)
  if attacker.is_empty() or attacker.zone!="field":score+=20000
  elif groups(e,attacker).any(func(group):return fight(e,attacker,group).attacker_dead):score+=10000
  elif not groups(e,attacker).is_empty():score+=maxi(0,e.stat(attacker,"spirit"))*100
 return score

static func opposing_response(e,who: int) -> bool:
 if e.priority!=1-who:return false
 var attacker=e.find_card(e.combat.get("attacker",{}).get("uid",-1))
 var stack_id=-1
 if not e.stack.is_empty() and e.stack.back().owner==who:stack_id=e.stack.back().id
 var actions=response_actions(e,who,attacker,false,attacker.is_empty())
 if actions.is_empty():return false
 var attacker_uid=attacker.get("uid",-1)
 var value=response_value(e,who,attacker_uid,stack_id);var best={}
 var trial=e.get_script().new(e.cards);var before=capture_sim(e)
 for action in actions:
  restore_sim(trial,before)
  if not commit_response(trial,who,action) or not settle_response(trial,stack_id):continue
  var score=response_value(trial,who,attacker_uid,stack_id)
  if score>value:value=score;best=action
 return not best.is_empty() and commit_response(e,who,best)

# Lethal search executes real rules on isolated copies, preserving only remembered
# opposing hand identities. Opponents use known counters and combat responses.
static func simulation(e,who: int):
 return SimState.fork(e,who)

static func capture_sim(e) -> Dictionary:
 return SimState.capture(e)

static func restore_sim(e,state: Dictionary):
 SimState.restore(e,state)

static func position_key(e,who: int) -> String:
 var state=[e.active,e.phase,e.turn,e.players[who].life,e.players[1-who].life,e.players[who].get("life_gained",{}),e.turn_usage,e.players[who].get("night_lock",-1),e.players[1-who].get("night_lock",-1),e.unpreventable_turn]
 state.append(Counterplay.Matchup.identify(e,who).key)
 for seat in [who,1-who]:
  state.append(e.players[seat].get("wards",[]))
  state.append(e.players[seat].field)
  state.append(e.players[seat].palette)
  state.append(e.players[seat].get("mana",[]));state.append(e.players[seat].potato)
 state.append(e.players[who].hand);state.append(e.players[who].grave);state.append(e.players[who].leader)
 state.append(known_hand(e,who));state.append(e.players[1-who].hand.size())
 state.append(e.ai_memory[who].get("recent_blocks",[]))
 state.append(e.players[1-who].grave);state.append(e.players[1-who].exile);state.append(e.players[1-who].leader)
 return JSON.stringify(state)

static func execute(e,who: int,action: Dictionary) -> bool:
 if action.get("kind","")=="attack" and not attack_allowed(e,e.find_card(action.get("uid",-1))):return false
 return Action.apply(e,who,action,func(engine,seat,c,target):return cast(engine,seat,c,target,false,false))

static func pressure_execute(e,who: int,action: Dictionary) -> bool:
 # Only a proven lethal may spend colors reserved for Gungnir.
 if action.kind=="attack":return execute(e,who,action)
 var c=e.find_card(action.uid)
 if not c.is_empty() and c.card_id==GUNGNIR:
  var enemy=e.find_card(action.target.get("uid",-1))
  if enemy.is_empty() or not use_gungnir(e,who,enemy):return false
 return not c.is_empty() and cast(e,who,c,action.target)

static func pressure_action(e,who: int,deadline: int=-1) -> Dictionary:
 return BeamPlanner.select(e,who,load("res://scripts/rules/remilia_aggro_ai.gd"),think_deadline(e,who,deadline))

static func pressure_finish(e,who: int,route: Array) -> Array:
 # Real combat comes before RED so this turn's lifesteal contributes damage.
 var result=route.duplicate(true)
 for i in range(24):
  if think_expired(e,who):break
  if e.winner!=-2:break
  var attacker=attack_choice(e,who)
  if attacker.is_empty():break
  var action={"kind":"attack","uid":attacker.uid,"expected":position_key(e,who)}
  if not pressure_execute(e,who,action) or not settle_sim(e,who):return result
  result.append(action)
 for i in range(8):
  if think_expired(e,who):break
  if e.winner!=-2:break
  var action={}
  for c in e.legal_casts(who):
   if c.card_id not in [RED,AURORA]:continue
   var t={"player":1-who}
   if c.card_id==AURORA:t.mode="失去生命"
   var trial={"kind":"cast","uid":c.uid,"card_id":c.card_id,"target":t,"expected":position_key(e,who)}
   if pressure_execute(e,who,trial):action=trial;break
  if action.is_empty():break
  if not settle_sim(e,who):break
  result.append(action)
 return result

static func pressure_next_round(e,who: int) -> bool:
 # A conditional outlook using the surviving public board and our remaining
 # hand. No opponent turn, draw, palette growth or hidden card is invented.
 e.run_delayed("end")
 if not settle_sim(e,who):return false
 if e.winner!=-2:return true
 e.Roster.cleanup(e)
 e.turn+=2;e.players[who].turns+=1;e.turn_usage={};e.death_trigger_events={}
 e.players[who].potato=false
 for p in e.players:
  p.mana=[];p.wine=[];p.wards=p.get("wards",[]).filter(func(w):return w.get("turn",-1)==-1)
  for c in p.field:
   c.damage=0;c.modifiers=[];c.spell_damage=false;c.base_override={};c.medicine=[]
   c.wards=c.get("wards",[]).filter(func(w):return w.get("turn",-1)==-1)
  for c in p.field+p.palette:
   if e.Pack.reset_allowed(e,c):c.tapped=false
   c.attacked=false
 e.phase="main";e.priority=who;e.passes=0
 return true

static func pressure_evaluate(e,who: int,route: Array,life: int,own_life: int,night_risk: int=0) -> Dictionary:
 var result=Evaluator.legacy_pressure(e,who,load("res://scripts/rules/remilia_aggro_ai.gd"),route,life,own_life,night_risk)
 # Prefer player damage in ordinary pressure plans, while retaining every
 # certified lethal, including one that must spend RED on a blocker.
 if absf(result.score)<900000:
  result.score-=route.filter(func(a):return a.get("card_id","")==RED and a.get("target",{}).has("uid")).size()*150
  # Reward establishing the recurring drain body on a high-mana turn.
  # Count only bodies still present after the simulated pressure rounds.
  if e.players[who].palette.size()>=7:
   for action in result.route:
    if action.kind!="cast" or action.get("card_id","")!="character-fdf-065":continue
    var body=e.find_card(action.uid)
    if not body.is_empty() and body.zone=="field" and body.owner==who:result.score+=180
 return result

static func finish_possession_sim(e,who: int,palette_uid: int=-1,hand_uid: int=-1) -> bool:
 e.possession(palette_uid,hand_uid)
 if e.pending.get("kind","")=="possession":e.possession()
 if not settle_sim(e,who):return false
 if e.phase=="possession":
  e.pass_priority(who);e.pass_priority(1-who)
 return settle_sim(e,who) and e.phase=="main" and e.active==who

static func lethal_possession(e,who: int) -> bool:
 if e.phase!="possession" or e.pending.get("kind","")!="possession" or e.pending.owner!=who:return false
 # First retrieve interaction/sealing rather than assume an unopposed burn line.
 if Counterplay.reimu_scope(e,who) and not Counterplay.reimu_units(e,who).is_empty():return false
 if e.players[1-who].life>lethal_threshold(e,who,true):return false
 var sim=simulation(e,who);var before=capture_sim(sim)
 var deadline=think_deadline(e,who,Time.get_ticks_msec()+SEARCH_MSEC*2)
 if finish_possession_sim(sim,who):
  var route=lethal_route(sim,who,deadline)
  if not route.is_empty():
   e.ai_memory[who].lethal_plan=route;e.possession();return true
 # Try real exchanges, including changed zones, epochs and palette effects.
 # All alternatives share a time budget rather than starting a full search
 # for every hand/palette pair. The unchanged winning hand always comes first.
 var candidates=[]
 for p in e.players[who].palette:
  if p.tapped or not e.can_possess(p):continue
  for h in e.players[who].hand:
   if h.uid==e.players[who].leader.uid and h.card_id==REMILIA:continue
   if not e.can_possess(h) or Time.get_ticks_msec()>=deadline:continue
   restore_sim(sim,before)
   if finish_possession_sim(sim,who,p.uid,h.uid):candidates.append({"palette":p.uid,"hand":h.uid,"score":position_score(sim,who)})
 candidates.sort_custom(func(a,b):return a.score>b.score)
 for candidate in candidates:
  if Time.get_ticks_msec()>=deadline:break
  restore_sim(sim,before)
  if not finish_possession_sim(sim,who,candidate.palette,candidate.hand):continue
  var route=lethal_route(sim,who,mini(deadline,Time.get_ticks_msec()+150))
  if not route.is_empty():
   e.ai_memory[who].lethal_plan=route;e.possession(candidate.palette,candidate.hand);return true
 return false

static func lethal_action(e,who: int) -> Dictionary:
 var memory=e.ai_memory[who]
 var plan=memory.get("lethal_plan",[])
 if not plan.is_empty():
  if plan[0].expected==position_key(e,who) and (plan[0].kind!="attack" or attack_allowed(e,e.find_card(plan[0].uid))):return plan.pop_front()
  memory.erase("lethal_plan")
 var route=lethal_route(e,who)
 if route.is_empty():return {}
 # Simulated expected positions may differ after opponent choices; replan then.
 memory.lethal_plan=route
 return memory.lethal_plan.pop_front()

static func lethal_route(e,who: int,deadline: int=-1) -> Array:
 if e.players[1-who].life>lethal_threshold(e,who):return []
 if deadline<0:deadline=Time.get_ticks_msec()+int(SEARCH_MSEC*1.5)
 deadline=think_deadline(e,who,deadline)
 if Time.get_ticks_msec()>=deadline:return []
 var sim=simulation(e,who)
 # Above the ordinary gate, reach the burst line directly before enumerating
 # every cast/attack permutation. Verify the entire line as a current win;
 # next-round pressure estimates can never certify lethal.
 if e.players[1-who].life>12 and e.players[who].hand.any(func(c):return c.card_id in [QUEEN,RED]):
  var initial=capture_sim(sim)
  var first=pressure_action(sim,who,deadline)
  if not first.is_empty():
   var burst=[first]+sim.ai_memory[who].get("pressure_plan",[])
   var verified=replay_lethal(sim,who,burst)
   if not verified.is_empty():return prune_lethal_route(e,who,verified)
  restore_sim(sim,initial)
 # A single Aurora wins immediately; validate known counters before spending
 # the search budget on a Night King combination or any board expansion.
 if e.players[1-who].life<=3 and remilia_aurora(sim,who,sim.legal_casts(who)).is_empty():
  var before=capture_sim(sim)
  for c in sim.legal_casts(who):
   if c.card_id!=AURORA:continue
   restore_sim(sim,before)
   var immediate=replay_lethal(sim,who,[{"kind":"cast","uid":c.uid,"card_id":AURORA,"target":{"player":1-who,"mode":"失去生命"}}])
   if not immediate.is_empty():return immediate
  restore_sim(sim,before)
 var ctx={"nodes":0,"deadline":Time.get_ticks_msec()+SEARCH_MSEC,"seen":{},"require_night":true}
 var route=[]
 if e.players[who].hand.any(func(c):return c.card_id==NIGHT):
  ctx.deadline=mini(deadline,Time.get_ticks_msec()+int(SEARCH_MSEC/2))
  route=search(sim,who,ctx,[],false)
 if route.is_empty():
  ctx.seen={};ctx.require_night=false;ctx.nodes=0;ctx.deadline=mini(deadline,Time.get_ticks_msec()+SEARCH_MSEC)
  route=search(sim,who,ctx,[],false)
 return prune_lethal_route(e,who,route) if not route.is_empty() else []

static func prune_lethal_route(e,who: int,route: Array) -> Array:
 # Drop every redundant action, including Wings and routine expansion, by
 # replaying the remaining win with real payments, responses and protection.
 var sim=simulation(e,who);var before=capture_sim(sim)
 var result=route.duplicate(true);var index=0
 while index<result.size():
  if think_expired(e,who):break
  var trial=result.duplicate(true);trial.remove_at(index)
  restore_sim(sim,before)
  var replayed=replay_lethal(sim,who,trial)
  if replayed.is_empty():index+=1
  else:result=replayed
 return result

static func replay_lethal(e,who: int,route: Array) -> Array:
 var result=[]
 for original in route:
  if think_expired(e,who):return []
  var action=original.duplicate(true);action.expected=position_key(e,who)
  if not execute(e,who,action) or not settle_sim(e,who):return []
  result.append(action)
  if e.winner==who:return result
  if e.winner!=-2 or e.phase!="main" or e.active!=who:return []
 return []

static func search(e,who: int,ctx: Dictionary,route: Array,used_night: bool) -> Array:
 if e.winner==who:return route if used_night or not ctx.require_night else []
 if e.winner!=-2 or ctx.nodes>=SEARCH_NODES or Time.get_ticks_msec()>=ctx.deadline:return []
 ctx.nodes+=1
 if not settle_sim(e,who):return []
 if e.winner==who:return route if used_night or not ctx.require_night else []
 if e.winner!=-2 or e.phase!="main" or e.active!=who:return []
 var key=position_key(e,who)+str(used_night)
 if ctx.seen.has(key):return []
 ctx.seen[key]=true
 var actions=search_actions(e,who)
 var before=capture_sim(e)
 for action in actions:
  restore_sim(e,before)
  var night=used_night or action.get("card_id","")==NIGHT
  action.expected=position_key(e,who)
  if not execute(e,who,action):continue
  var result=search(e,who,ctx,route+[action],night)
  if not result.is_empty():return result
 restore_sim(e,before)
 return []

static func search_actions(e,who: int) -> Array:
 var actions=[];var revivals=[];var finishers=[];var red_removals=[];var seen=[]
 var casts=e.legal_casts(who)
 casts.sort_custom(func(a,b):return SEARCH_CARDS.find(a.card_id)<SEARCH_CARDS.find(b.card_id))
 for c in casts:
  if c.card_id not in SEARCH_CARDS:continue
  var id=c.card_id
  if id==WINGS and e.Cat.field_limit(e,who)-e.field_slots(who)<2:continue
  if id==AYA and aya_target(e,who).is_empty():continue
  if id==QUEEN and e.Cat.field_limit(e,who)-e.field_slots(who)<4:continue
  if id in seen:continue
  seen.append(id)
  var options=[{"none":true}] if e.is_unit(c) or id==CASTLE else e.targets_for(id,who,c.uid)
  var preferred_revival=remilia_aurora_target(e,who,options) if id==AURORA else {}
  if id==GUNGNIR:options.sort_custom(func(a,b):return gungnir_value(e,e.find_card(a.uid))>gungnir_value(e,e.find_card(b.uid)))
  if id==AURORA:options.sort_custom(func(a,b):return aurora_search_value(e,who,a)>aurora_search_value(e,who,b))
  for t in options:
   if id==AURORA and not preferred_revival.is_empty() and t!=preferred_revival:continue
   if t.has("uid"):
    var target=e.find_card(t.uid)
    if id==NIGHT:
     if target.owner!=who:continue
     if Counterplay.reimu_night_needed(e,who):
      if not e.Roster.character_matches(e.cards[target.card_id].character,"蕾米莉亚"):continue
     elif target.tapped or e.summoning_sick(target):continue
    elif id in [GUNGNIR,MIST,AUTUMN,RED]:
     if target.owner==who:continue
     if id==GUNGNIR and not gungnir_target_allowed(e,who,target):continue
    elif id==AURORA:
     if t.get("mode","")!="移回战场" or not e.field_error(target,who).is_empty() or grave_removal_ready(e,who,target):continue
   if t.get("player",-1)==who:continue
   if id==AUTUMN:
    var w=autumn_sacrifice(e,who,e.find_card(t.get("uid",-1)))
    if w.is_empty() or t.get("sacrifice",{}).get("uid",-1)!=w.uid:continue
   if e.payment(who,e.cast_cost(who,c,t)).ways==0:continue
   var action={"kind":"cast","uid":c.uid,"card_id":id,"target":t}
   if id==AURORA and t.get("mode","")=="移回战场" and not useful_revival(e,who,e.find_card(t.uid)):revivals.append(action)
   elif id==RED and t.has("uid"):red_removals.append(action)
   elif id==RED and t.get("player",-1)==1-who and e.players[1-who].life>red_damage(e,who):finishers.append(action)
   else:actions.append(action)
 var attackers=e.units(who).filter(func(c):return e.can_attack(who,c.uid) and attack_allowed(e,c))
 var setup=red_setup_choice(e,who)
 attackers.sort_custom(func(a,b):
  if a.uid==setup.get("uid",-1) or b.uid==setup.get("uid",-1):return a.uid==setup.get("uid",-1)
  return e.stat(a,"spirit")>e.stat(b,"spirit"))
 var signatures=[]
 for c in attackers:
  var info=e.cards[c.card_id]
  var identity=[info.name,info.race,info.keywords,info.abilities] if c.get("token",false) else c.card_id
  var signature=JSON.stringify([identity,e.stat(c,"power"),e.stat(c,"health"),e.stat(c,"spirit"),c.damage,c.get("modifiers",[]),c.get("wards",[])])
  if signature in signatures:continue
  signatures.append(signature)
  actions.append({"kind":"attack","uid":c.uid})
 actions.append_array(finishers)
 # Attack lifesteal and player burn are explored before RED removal. Keep the
 # latter legal so a necessary blocker kill can still produce a proven win.
 actions.append_array(red_removals)
 actions.append_array(revivals)
 return actions

static func aurora_search_value(e,who: int,t: Dictionary) -> int:
 if t.get("mode","")=="失去生命":return 10000 if e.players[1-who].life<=3 else 3000
 if t.get("mode","")=="牺牲单位":
  var enemies=e.units(1-who)
  return 2500 if enemies.size()==1 and high_value_enemy(e,enemies[0]) and e.can_sacrifice(enemies[0]) else 1000
 if t.get("mode","")!="移回战场":return 1000
 var c=e.find_card(t.get("uid",-1))
 if c.is_empty():return 0
 # Try an aura that adds more attack damage than the three-life mode early,
 # keeping bounded search from spending its budget on plain attack permutations.
 if c.card_id==REMILIA and useful_revival(e,who,c):
  return ready_units(e,who).filter(func(u):return "黑" in e.Pack.colors(e,u)).size()*1000
 return 2000 if useful_revival(e,who,c) else 0

static func useful_revival(e,who: int,c: Dictionary) -> bool:
 # Reach useful revival branches before enumerating every plain attack order.
 if e.has_haste(c) or e.Extra.has(e.cards[c.card_id],"enter_grave_damage"):return true
 if c.card_id==REMILIA:
  return ready_units(e,who).any(func(u):return "黑" in e.Pack.colors(e,u))
 return false

static func simulated_blocks(e,who: int) -> Array:
 var current=e.find_card(e.combat.attacker.uid)
 # Do not reserve a blocker for a future attack our own protection rules
 # forbid. Otherwise Aurora + a bat can falsely look lethal while the enemy
 # "waits for Remilia", even though Remilia will never attack that blocker.
 var attackers=ready_units(e,who).filter(func(c):return attack_allowed(e,c))+[current]
 attackers.sort_custom(func(a,b):
  var lethal_a=a.uid==current.uid and e.stat(a,"spirit")>=e.players[1-who].life
  var lethal_b=b.uid==current.uid and e.stat(b,"spirit")>=e.players[1-who].life
  if lethal_a!=lethal_b:return lethal_a
  return e.stat(a,"spirit")>e.stat(b,"spirit"))
 var reserved=[]
 for a in attackers:
  var best=[];var score=-2147483647
  for group in groups(e,a):
   if group.any(func(b):return b.uid in reserved):continue
   var outcome=fight(e,a,group)
   var annihilate=e.Extra.keyword(e,a,"歼灭") and not outcome.dead.is_empty()
   var value=(0 if annihilate else e.stat(a,"spirit")*10000)+ (1000 if outcome.attacker_dead else 0)-group.reduce(func(n,b):return n+(strength(e,b) if b.uid in outcome.dead else 1),0)
   if value>score:score=value;best=group.map(func(b):return b.uid)
  if a.uid==current.uid:return best
  reserved.append_array(best)
 return []

static func settle_sim(e,who: int) -> bool:
 for i in range(180):
  if e.winner!=-2:return true
  e.pump_choices()
  if not e.pending.is_empty():
   match e.pending.kind:
    "block":e.block(simulated_blocks(e,who))
    "trigger_order":e.choose_trigger_order(0)
    "effect_choice":e.choose_effect(effect_target(e,e.pending.owner,e.pending.options,e.pending.trigger))
    "trigger":
     var options=e.pending.options
     var enemies=options.filter(func(t):return e.find_card(t.get("uid",-1)).get("owner",-1)!=e.pending.owner)
     e.choose_trigger(enemies[0] if not enemies.is_empty() else {})
    "leader_return":e.choose_return(false)
    "timer":e.choose_timer(0)
    "grave_replacement":e.choose_grave_replacement(true)
    "ward_order":e.choose_ward(e.pending.options[0])
    "damage_assignment":
     var attacker=e.find_card(e.combat.attacker.uid)
     var blockers=e.combat.blockers.map(func(t):return e.find_card(t.uid))
     e.combat_damage(damage_allocation(e,attacker,blockers,e.pending.total))
    _:return false
  elif e.stack.is_empty() and e.combat.is_empty():
   e.priority=who;return true
  else:
   if not opposing_response(e,who):e.pass_priority(e.priority)
 return false
