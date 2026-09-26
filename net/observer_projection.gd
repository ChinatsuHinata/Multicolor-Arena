extends RefCounted
const SeatView=preload("res://net/seat_projection.gd")
## Cheap read-only projection: never calculates legal actions or exposes private choices.
static func build(e,events: Array=[],perspective: int=-1) -> Dictionary:
 var state={};var q={"stats":{},"leader":{},"sick":{},"haste":{}}
 q.pending_keystones=SeatView.SpellDamagePreview.public_keystone_estimates(e)
 for key in SeatView.PUBLIC_FIELDS:
  var v=e.get(key);state[key]=v.duplicate(true) if v is Array or v is Dictionary else v
 state.stack=SeatView.public_stack(state.stack)
 state.pending={"kind":"network_wait","owner":e.pending.get("owner",e.priority)} if not e.pending.is_empty() else {}
 state.forced_cast={};state.players=[];state.presentation_events=[]
 var definitions={}
 for who in range(2):
  var p=e.players[who].duplicate(true)
  p.deck=[]
  for i in range(e.players[who].deck.size()):p.deck.append(SeatView.hidden_card(who,"deck",i))
  if who!=perspective:
   p.hand=[]
   for i in range(e.players[who].hand.size()):p.hand.append(SeatView.hidden_card(who,"hand",i))
  state.players.append(p)
  for c in p.field+p.palette+p.grave+p.exile+p.hand+e.leaders(p.leader.owner):
   if c.is_empty() or c.card_id=="back":continue
   definitions[c.card_id]=e.cards[c.card_id];q.stats[c.uid]={}
   for key in ["power","health","spirit"]:q.stats[c.uid][key]=e.stat(c,key)
   q.leader[c.uid]=e.has_leader_ability(c);q.sick[c.uid]=e.summoning_sick(c);q.haste[c.uid]=e.has_haste(c)
 for original in events:
  var event=original.duplicate(true)
  if event.type=="move" and event.from in ["hand","deck"] and event.to in ["hand","deck"] and (event.card.owner!=perspective or event.from=="deck" and event.to=="deck"):
   event.card=SeatView.hidden_card(event.card.owner,event.from,0)
  state.presentation_events.append(event)
  var id=event.get("card",{}).get("card_id","")
  if e.cards.has(id):definitions[id]=e.cards[id]
 for entry in state.history:
  for art in entry.art:
   if art.get("hidden",false) and art.owner!=perspective:art.card_id="back";art.erase("art_id")
 collect_definitions(state.stack,e,definitions)
 return {"state":state,"queries":q,"definitions":definitions}

static func collect_definitions(value: Variant,e,definitions: Dictionary):
 if value is Dictionary:
  if value.has("card_id") and e.cards.has(value.card_id):definitions[value.card_id]=e.cards[value.card_id]
  for child in value.values():collect_definitions(child,e,definitions)
 elif value is Array:
  for child in value:collect_definitions(child,e,definitions)
