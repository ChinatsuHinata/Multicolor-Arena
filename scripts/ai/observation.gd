extends RefCounted
const Matchup=preload("res://scripts/ai/matchup.gd")
## Decision input, distinct from the authoritative engine and replay visibility.
static func known_hand(e,who: int) -> Dictionary:
 var result={}
 var remembered=e.ai_memory[who].get("known_hand",{})
 for c in e.players[1-who].hand:
  var record=remembered.get(str(c.uid),{})
  if record.get("epoch",-1)==c.epoch:result[str(c.uid)]=record.duplicate(true)
 return result

static func build(e,who: int) -> Dictionary:
 var known=known_hand(e,who)
 var result={"seat":who,"matchup":Matchup.identify(e,who),"active":e.active,"priority":e.priority,"phase":e.phase,"turn":e.turn,"winner":e.winner,"players":[],"stack":[],"combat":e.combat.duplicate(true),"pending":{"kind":e.pending.get("kind",""),"owner":e.pending.get("owner",-1)}}
 for seat in range(2):
  var p=e.players[seat]
  var view={"life":p.life,"turns":p.turns,"deck_count":p.deck.size(),"hand_count":p.hand.size(),"hand":[],"leaders":e.leaders(seat).duplicate(true),"potato":p.potato}
  for zone in ["field","palette","grave","exile"]:view[zone]=p[zone].duplicate(true)
  if seat==who:view.hand=p.hand.duplicate(true)
  else:
   for uid in known:
    var record=known[uid].duplicate(true);record.uid=int(uid);view.hand.append(record)
  result.players.append(view)
 for entry in e.stack:
  var view={}
  for key in ["id","kind","owner","card","source","target","effect"]:
   if entry.has(key):view[key]=entry[key].duplicate(true) if entry[key] is Dictionary or entry[key] is Array else entry[key]
  result.stack.append(view)
 return result
