extends RefCounted
const Codec=preload("res://net/state_codec.gd")
const PUBLIC_FIELDS=["active","priority","phase","turn","first","passes","winner","revision","stack","combat","turn_usage","unpreventable_turn","log","history","player_names"]
static func hidden_card(who: int,zone: String,index: int) -> Dictionary:
 return {"card_id":"back","uid":-1000000-who*100000-(10000 if zone=="deck" else 0)-index,"epoch":0,"owner":who,"original_owner":who,"zone":zone,"leader":false,"tapped":false,"damage":0,"timer":0,"entered":0,"attacked":false,"network_hidden":true}
static func collect_refs(v: Variant,refs: Dictionary):
 if v is Dictionary:
  if v.has("uid") and v.has("epoch"):refs[int(v.uid)]=true
  for k in v:collect_refs(v[k],refs)
 elif v is Array:
  for item in v:collect_refs(item,refs)
static func build(e,seat: int,events: Array=[]) -> Dictionary:
 var scratch={}
 for key in ["catalogue_target_fast","catalogue_x_override","catalogue_retargeting","paid_cast_uid","forced_cast","revision"]:scratch[key]=e.get(key)
 var state={};var q={"cast":{},"targets":{},"actions":{},"extra":{},"extension_targets":{},"free":{},"stats":{},"leader":{},"sick":{},"haste":{},"possess":{},"lookup":{}}
 for k in PUBLIC_FIELDS:state[k]=e.get(k).duplicate(true) if e.get(k) is Array or e.get(k) is Dictionary else e.get(k)
 q.resources=e.source_resources(seat).duplicate(true);q.response=e.has_response(seat);q.blockers=e.legal_blockers().map(func(c):return c.uid) if e.pending.get("kind","")=="block" and e.pending.owner==seat else []
 q.ability_targets=e.ability_targets().duplicate(true)
 q.legal=e.legal_casts(seat).map(func(c):return c.uid);q.fast_legal=e.legal_casts(seat,true).map(func(c):return c.uid)
 var allowed={};var all=[]
 q.legal.sort();q.fast_legal.sort()
 state.forced_cast=e.forced_cast.duplicate(true) if e.forced_cast.get("owner",-1)==seat else {}
 q.deck_actions=[]
 for c in e.players[seat].deck:
  if not e.available_actions(seat,c.uid).is_empty():q.deck_actions.append(c.uid)
 q.deck_actions.sort()
 for who in range(2):
  all.append_array(e.players[who].field+e.players[who].palette+e.players[who].grave+e.players[who].exile+e.leaders(who))
  if who==seat:all.append_array(e.players[who].hand)
 for uid in q.legal+q.deck_actions:
  var c=e.find_card(uid)
  if not c.is_empty() and c not in all:all.append(c);allowed[c.uid]=true
 for c in all:
  if c.is_empty():continue
  q.stats[c.uid]={}
  for key in ["power","health","spirit"]:q.stats[c.uid][key]=e.stat(c,key)
  q.leader[c.uid]=e.has_leader_ability(c);q.sick[c.uid]=e.summoning_sick(c);q.haste[c.uid]=e.has_haste(c);q.possess[c.uid]=e.can_possess(c)
  if c.owner!=seat and c.uid not in q.legal:continue
  q.cast[c.uid]=e.cast_error(seat,c.uid);q.free[c.uid]=e.offers_free_cast(seat,c);q.actions[c.uid]=e.available_actions(seat,c.uid,true);q.extra[c.uid]=e.extra_action(c)
  if q.cast[c.uid].is_empty():
   var previous=e.paid_cast_uid
   e.paid_cast_uid=-1;q.targets[str(c.uid)+":free"]=e.targets_for(c.card_id,seat,c.uid).duplicate(true)
   e.paid_cast_uid=c.uid;q.targets[str(c.uid)+":paid"]=e.targets_for(c.card_id,seat,c.uid).duplicate(true)
   e.paid_cast_uid=previous
  for action in q.actions[c.uid]:
   if action.type=="extension" and action.enabled:q.extension_targets[str(c.uid)+":"+action.key]=e.Extra.activation_options(e,c,action.key).duplicate(true)
 state.pending=e.pending.duplicate(true) if e.pending.get("owner",-1)==seat else {"kind":"network_wait","owner":e.pending.owner} if not e.pending.is_empty() else {}
 if state.pending.get("kind","")=="effect_choice" and state.pending.trigger.effect=="cat:grant":
  var saved=e.pending;var paid=e.paid_cast_uid;var revision=e.revision
  q.grant_options={}
  for pay in [false,true]:
   e.pending=saved.duplicate(true);e.set_granted_payment(pay);q.grant_options[str(pay)]=e.pending.options.duplicate(true)
  e.pending=saved;e.paid_cast_uid=paid;e.revision=revision
 collect_refs(q.get("grant_options",{}),allowed)
 collect_refs(q.targets,allowed);collect_refs(q.extension_targets,allowed)
 if state.pending.has("options"):collect_refs(state.pending.options,allowed)
 var granted=state.pending.get("trigger",{}).get("data",{}).get("ref",{})
 collect_refs(granted,allowed)
 for uid in allowed:
  var c=e.find_card(uid)
  if not c.is_empty():q.lookup[uid]=c.duplicate(true)
 # Do not publish the order of a library, even to its owner. Searches use a detached lookup.
 state.players=[]
 for who in range(2):
  var p=e.players[who].duplicate(true)
  p.deck=[]
  for i in range(e.players[who].deck.size()):
   var c=e.players[who].deck[i]
   p.deck.append(c.duplicate(true) if i==0 and who==seat and e.Cat.may_peek(e,who) else hidden_card(who,"deck",i))
  if who!=seat:
   p.hand=[]
   for i in range(e.players[who].hand.size()):p.hand.append(hidden_card(who,"hand",i))
  state.players.append(p)
 state.presentation_events=[]
 for original in events:
  var event=original.duplicate(true)
  if event.type=="move" and event.from in ["hand","deck"] and event.to in ["hand","deck"] and (event.card.owner!=seat or event.from=="deck" and event.to=="deck"):
   event.card=hidden_card(event.card.owner,event.from,0)
  state.presentation_events.append(event)
 for event in state.history:
  for art in event.art:
   if art.get("hidden",false) and art.owner!=seat:art.card_id="back"
 var definitions={}
 for c in all+q.lookup.values():
  if not c.is_empty():definitions[c.card_id]=e.cards[c.card_id]
 for event in state.presentation_events:
  if event.has("card") and e.cards.has(event.card.get("card_id","")):definitions[event.card.card_id]=e.cards[event.card.card_id]
 # Searching an entire library permits seeing its cards, not their shuffled order.
 sort_search_pools(state.pending,e);sort_search_pools(q.targets,e);sort_search_pools(q.extension_targets,e)
 for key in scratch:e.set(key,scratch[key])
 return {"state":state,"queries":q,"definitions":definitions}
static func sort_search_pools(v: Variant,e):
 if v is Dictionary:
  if v.has("pool") and v.pool is Array and ("检索" in str(v.get("title","")) or "搜寻" in str(v.get("title",""))):
   v.pool.sort_custom(func(a,b):return int(a.get("uid",0))<int(b.get("uid",0)))
  for item in v.values():sort_search_pools(item,e)
 elif v is Array:
  for item in v:sort_search_pools(item,e)
