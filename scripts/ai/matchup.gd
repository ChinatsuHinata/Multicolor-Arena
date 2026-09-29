extends RefCounted
## Public registered leaders, independent of zone, control, copying and artwork.
const SCHEMA="multicolor.ai.matchup.v1"
static func leader_ids(leaders: Array,cards: Dictionary={}) -> Array:
 var ids=[]
 for c in leaders:
  if not c is Dictionary:return []
  var id=c.get("copy_original",c.get("habitat_base",c.get("card_id","")))
  id=cards.get(id,{}).get("canonical_id",id)
  if not id is String or id in ["","back"]:return []
  ids.append(id)
 ids.sort()
 return ids
static func context(own: Array,opponent: Array) -> Dictionary:
 var own_key="+".join(own);var opponent_key="+".join(opponent)
 return {"schema":SCHEMA,"own_leaders":own,"opponent_leaders":opponent,"own_key":own_key,"opponent_key":opponent_key,"key":own_key+"::"+opponent_key if not own.is_empty() and not opponent.is_empty() else ""}
static func identify(e,seat: int) -> Dictionary:
 return context(leader_ids(e.leaders(seat),e.cards),leader_ids(e.leaders(1-seat),e.cards))
