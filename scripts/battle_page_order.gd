extends RefCounted
## Confirmed public actions retain presentation priority for this zone instance.
## Card arrays stay authoritative; snapshots carry only this lightweight marker.
static func priority(card: Dictionary) -> int:
 var mark=card.get("page_priority",{})
 if mark.get("uid",-1)!=card.uid or mark.get("epoch",-1)!=card.epoch or mark.get("owner",-1)!=card.owner or mark.get("zone","")!=card.zone:return 0
 return int(mark.get("serial",0))

static func move_priority(card: Dictionary) -> int:
 if priority(card)<=0:return 0
 # Old replays used the action serial itself as the movement rank.
 return int(card.page_priority.get("move_serial",card.page_priority.serial))

static func ordered(cards: Array) -> Array:
 var result=cards.duplicate()
 var original_order={}
 for index in range(cards.size()):original_order[cards[index].uid]=index
 result.sort_custom(func(a,b):
  var a_rank=move_priority(a);var b_rank=move_priority(b)
  return a_rank>b_rank if a_rank!=b_rank else original_order[a.uid]<original_order[b.uid])
 return result

static func promote(e,refs: Array):
 var cards=[];var seen={}
 for ref in refs:
  if not ref is Dictionary or not ref.has("uid") or not ref.has("epoch"):continue
  var card=e.find_card(ref.uid)
  if card.is_empty() or card.zone not in ["field","palette"] or card.epoch!=ref.epoch:continue
  if ref.has("zone") and ref.zone!=card.zone or ref.has("owner") and ref.owner!=card.owner:continue
  if seen.has(card.uid):continue
  seen[card.uid]=true;cards.append(card)
 if cards.is_empty():return
 # Evaluate every card against the order BEFORE this declaration. Otherwise
 # an off-page target could push a first-page target back during the same batch.
 var moving={}
 for card in cards:
  var area=e.players[card.owner].palette if card.zone=="palette" else e.players[card.owner].field.filter(func(unit):return e.is_unit(unit))
  var page_size=10 if card.zone=="palette" else 6
  moving[card.uid]=ordered(area).find(card)>=page_size
 e.page_priority_serial+=1
 for card in cards:
  var rank=e.page_priority_serial if moving[card.uid] else move_priority(card)
  card.page_priority={"uid":card.uid,"epoch":card.epoch,"owner":card.owner,"zone":card.zone,"serial":e.page_priority_serial,"move_serial":rank}

static func promote_targets(e,target: Dictionary,entry: Dictionary={}):
 var declaration=entry.duplicate()
 declaration.target=target
 # Counter references are payment choices, even on old spell copies that do
 # not retain the original declaration-time cost specification.
 var refs=e.Pack.declared_targets(declaration).filter(func(ref):return not ref.has("counter"))
 promote(e,refs)
