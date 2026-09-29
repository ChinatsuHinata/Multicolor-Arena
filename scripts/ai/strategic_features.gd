extends RefCounted
const State=preload("res://scripts/ai/simulation_state.gd")
const Pressure=preload("res://scripts/ai/pressure_policy.gd")
## Own hand and public permanents only. No opponent hand identities or deck order.
const SCHEMA="multicolor.ai.features.v2"
const KEYS=["color_min_sources","color_redundancy","colors_after_one_damage","colors_after_two_damage","leader_health","leader_timer","leader_replay_ready","leader_recovery_ready","recovery_cards","hard_removal_cards","gungnir_cards","gungnir_payable","leader_response_reserve","enemy_core_count","enemy_core_value","enemy_small_bodies","permanent_ready_damage","temporary_ready_damage","castle_count","queen_combo_ready","free_field_slots","hand_playable_count","upcoming_gungnir_threat","required_gungnir_reserve","needless_gungnir_reserve","aura_haste_damage","opponent_life"]
const GUNGNIR="109"
const MIST="spell-ucs-052"
const AUTUMN="94"
const AURORA="143"
const AYA="18"
const CASTLE="169"
const QUEEN="spell-fdf-037"

static func core(e,c: Dictionary) -> bool:
 if not e.is_unit(c):return false
 var info=e.cards[c.card_id]
 return e.has_leader_ability(c) or not e.Extra.activation_kind(info).is_empty() or not e.Roster.key(info,e.Roster.ACTIVATIONS).is_empty() or info.abilities.any(func(a):return a.get("实现","")=="activated_damage")

static func source_counts(e,who: int,damage: int=0) -> Array:
 var leader=e.cards[e.players[who].leader.card_id]
 var requirements=leader.cost.keys() if leader.cost.keys().any(func(k):return "/" in k) else leader.colors
 var counts=[]
 for requirement in requirements:
  var count=0
  for c in e.players[who].field:
   if e.cards[c.card_id].kind=="符卡":continue
   if damage>0 and e.is_unit(c) and e.stat(c,"health")-c.damage<=damage:continue
   if Array(str(requirement).split("/")).any(func(color):return color in e.Pack.colors(e,c)):count+=1
  counts.append(count)
 return counts

static func features(e,who: int) -> Dictionary:
 return calculate(State.fork(e,who),who)

static func calculate(e,who: int) -> Dictionary:
 var f={}
 for key in KEYS:f[key]=0.0
 var own=e.players[who];var leader=own.leader
 # Forecast before normalizing decision timing: preserve the true active turn.
 var threat=Pressure.forecast(e,who)
 f.upcoming_gungnir_threat=1.0 if threat.risk else 0.0
 f.opponent_life=float(e.players[1-who].life)
 var counts=source_counts(e,who)
 f.color_min_sources=float(counts.min()) if not counts.is_empty() else 0.0
 for count in counts:f.color_redundancy+=maxi(0,count-1)
 # These are HP-based stress features, not a prediction of a real sweep (ward,
 # regeneration and death triggers can change its outcome).
 f.colors_after_one_damage=1.0 if source_counts(e,who,1).all(func(n):return n>0) else 0.0
 f.colors_after_two_damage=1.0 if source_counts(e,who,2).all(func(n):return n>0) else 0.0
 f.leader_health=float(maxi(0,e.stat(leader,"health")-leader.damage)) if leader.zone=="field" else 0.0
 f.leader_timer=float(leader.timer) if leader.zone=="leader" else 0.0
 f.free_field_slots=float(maxi(0,e.Cat.field_limit(e,who)-e.field_slots(who)))
 # Normalize timing only; never reset mana, timers, damage or resources. This
 # asks whether a card is usable at a clean main decision with current resources.
 var previous={"active":e.active,"priority":e.priority,"phase":e.phase,"pending":e.pending,"stack":e.stack,"combat":e.combat,"entry_choices":e.entry_choices}
 e.active=who;e.priority=who;e.phase="main";e.pending={};e.stack=[];e.combat={};e.entry_choices=[]
 if leader.zone in ["leader","hand"] and e.cast_error(who,leader.uid).is_empty():f.leader_replay_ready=1.0
 var available={}
 for c in own.hand:
  if c.get("ai_unknown",false) or c.card_id=="back":continue
  if c.card_id in [MIST,AUTUMN]:f.hard_removal_cards+=1
  if c.card_id in [AURORA,AYA]:f.recovery_cards+=1
  if c.card_id==GUNGNIR:f.gungnir_cards+=1
  if not e.cast_error(who,c.uid).is_empty():continue
  available[c.card_id]=c;f.hand_playable_count+=1
  if c.card_id==GUNGNIR:f.gungnir_payable=1.0
  if c.card_id==AURORA and leader.zone=="grave":
   for target in e.targets_for(c.card_id,who,c.uid):
    if target.get("mode","")=="移回战场" and target.get("uid",-1)==leader.uid and e.payment(who,e.cast_cost(who,c,target)).ways>0:f.leader_recovery_ready=1.0
  if c.card_id==AYA and leader.zone=="grave":
   # A legal return-to-hand is recovery access, not proof of a same-turn recast.
   for target in e.Extra.trigger_options(e,{"owner":who,"source":c,"effect":"enter_grave_damage"}):
    if target.get("parts",[]).any(func(t):return t.get("uid",-1)==leader.uid):f.leader_recovery_ready=1.0
 f.leader_response_reserve=f.gungnir_payable if leader.zone=="field" and f.leader_health<=4 else 0.0
 f.required_gungnir_reserve=f.gungnir_payable*f.upcoming_gungnir_threat
 f.needless_gungnir_reserve=f.gungnir_payable*(1.0-f.upcoming_gungnir_threat)
 for c in e.units(1-who):
  if core(e,c):
   f.enemy_core_count+=1;f.enemy_core_value+=e.Extra.cost_value(e,c)+maxi(0,e.stat(c,"spirit"))
  elif e.Extra.cost_value(e,c)<4 and e.stat(c,"power")<5 and e.stat(c,"health")-c.damage<5 and e.stat(c,"spirit")<4:f.enemy_small_bodies+=1
 f.castle_count=float(own.field.filter(func(c):return c.card_id==CASTLE).size())
 for c in own.field:
  if not e.is_unit(c) or c.tapped or e.summoning_sick(c):continue
  if e.delayed.any(func(d):return d.get("effect","")=="token_sacrifice" and d.get("ref",{}).get("uid",-1)==c.uid):
   f.temporary_ready_damage+=maxi(0,e.stat(c,"spirit"))
   if c.get("token",false) and (f.castle_count>0 or leader.zone=="field"):f.aura_haste_damage+=maxi(0,e.stat(c,"spirit"))
  else:f.permanent_ready_damage+=maxi(0,e.stat(c,"spirit"))
 if available.has(QUEEN) and f.free_field_slots>=4:
  if f.castle_count>0:f.queen_combo_ready=1.0
  elif available.has(CASTLE):
   var combined=e.cast_cost(who,available[QUEEN]).duplicate()
   for color in e.cast_cost(who,available[CASTLE]):combined[color]=int(combined.get(color,0))+int(e.cast_cost(who,available[CASTLE])[color])
   if e.payment(who,combined).ways>0:f.queen_combo_ready=1.0
 for key in previous:e.set(key,previous[key])
 return f
