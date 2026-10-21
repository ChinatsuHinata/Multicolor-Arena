extends RefCounted
## Confirmed public actions retain presentation priority for this zone instance.
## Card arrays stay authoritative; snapshots carry only this lightweight marker.
static func priority(card: Dictionary) -> int:
 var mark=card.get("page_priority",{})
 if mark.get("uid",-1)!=card.uid or mark.get("epoch",-1)!=card.epoch or mark.get("owner",-1)!=card.owner or mark.get("zone","")!=card.zone:return 0
 return int(mark.get("serial",0))

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
 e.page_priority_serial+=1
 for card in cards:
  card.page_priority={"uid":card.uid,"epoch":card.epoch,"owner":card.owner,"zone":card.zone,"serial":e.page_priority_serial}

static func promote_targets(e,target: Dictionary,entry: Dictionary={}):
 var declaration=entry.duplicate()
 declaration.target=target
 # Counter references are payment choices, even on old spell copies that do
 # not retain the original declaration-time cost specification.
 var refs=e.Pack.declared_targets(declaration).filter(func(ref):return not ref.has("counter"))
 promote(e,refs)
