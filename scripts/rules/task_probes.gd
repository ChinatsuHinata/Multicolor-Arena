extends RefCounted
## Public, aggregate battle facts. Never contains hands, deck order, targets or secrets.
## Persisted by the normal rules codec, including rollback and reconnect.
const COUNTERS=["player_damage","units_destroyed","items_destroyed","barriers_destroyed","fast_spells","non_spells","character_spells","unit_cards","tokens_created","spell_counters","death_triggers","life_recovered","unit_combat_player_damage","royal_flare_damage","cards_drawn","cards_milled","attacks","blocks","abilities_used","cards_cast","units_entered","damage_received","unit_damage","units_lost","sacrifices","cards_discarded","cards_exiled","cards_returned","spells_resolved","spells_fizzled","direct_counters","indirect_counters"]

static func start(e,decks: Array):
 e.task_stats=[];e.task_win_reason="normal"
 for deck in decks:
  var stats={"cast_cards":{},"leader_id":str(deck.leader)}
  var info=e.cards.get(deck.leader,{})
  stats.leader_colors=info.get("colors",[]).duplicate();stats.leader_character=info.get("character","")
  for key in COUNTERS:stats[key]=0
  e.task_stats.append(stats)

static func count(e,who: int,event: String,amount: int=1):
 if who not in [0,1] or e.task_stats.size()!=2 or event not in COUNTERS or amount<=0:return
 e.task_stats[who][event]=int(e.task_stats[who].get(event,0))+amount

static func canonical(e,c: Dictionary) -> String:
 return str(e.cards.get(c.get("card_id",""),{}).get("canonical_id",c.get("card_id","")))

static func cast(e,who: int,c: Dictionary):
 if e.task_stats.size()!=2:return
 var info=e.cards[c.card_id];var stats=e.task_stats[who];var id=canonical(e,c)
 stats.cast_cards[id]=int(stats.cast_cards.get(id,0))+1
 count(e,who,"cards_cast")
 if e.is_unit(c):count(e,who,"unit_cards")
 if info.kind!="符卡":return
 if info.fast:count(e,who,"fast_spells")
 if "非符" in info.get("spell_type",""):count(e,who,"non_spells")
 if not info.get("requires_character","").is_empty() or "角色" in info.get("spell_type",""):count(e,who,"character_spells")

static func moved(e,c: Dictionary,old: String,destination: String):
 if old==destination:return
 if old=="hand" and destination=="grave":count(e,c.owner,"cards_discarded")
 if destination=="exile":count(e,c.owner,"cards_exiled")
 if old=="field" and destination=="hand":count(e,c.owner,"cards_returned")
 if destination=="field":
  if e.is_unit(c):count(e,c.owner,"units_entered")
  if c.get("token",false) and old=="token":count(e,c.owner,"tokens_created")

static func damage(e,target: Dictionary,amount: int):
 var source=e.damage_context.get("source",{});var owner=int(source.get("owner",-1))
 if target.has("player"):
  var victim=int(target.player)
  count(e,victim,"damage_received",amount)
  if e.task_stats.size()==2:
   e.task_stats[victim]._damage_life=int(e.players[victim].life)
   e.task_stats[victim]._damage_overkill=maxi(0,-int(e.players[victim].life))
   e.task_stats[victim]._damage_card=canonical(e,source)
   e.task_stats[victim]._damage_owner=owner
  if owner not in [0,1] or victim==owner:return
  count(e,owner,"player_damage",amount)
  if canonical(e,source)=="spell-ucs-041":count(e,owner,"royal_flare_damage",amount)
  if e.damage_context.get("combat",false) and not source.is_empty() and e.is_unit(source):count(e,owner,"unit_combat_player_damage",amount)
 else:
  var victim=e.find_card(target.get("uid",-1))
  if not victim.is_empty():victim.task_damage_owner=owner
  if owner in [0,1] and not victim.is_empty() and victim.owner!=owner:count(e,owner,"unit_damage",amount)

static func destroyed(e,c: Dictionary,owner: int=-1):
 if c.is_empty() or c.get("zone","")!="field":return
 if owner<0:owner=int(e.damage_context.get("source",{}).get("owner",-1))
 if owner not in [0,1]:return
 var kind=e.cards[c.card_id].kind
 count(e,owner,"units_destroyed" if e.is_unit(c) else "items_destroyed" if kind=="道具" else "barriers_destroyed" if kind=="结界" else "")

static func counter(e,entry: Dictionary,source: Dictionary,indirect: bool=false):
 var owner=int(source.get("owner",-1))
 if owner not in [0,1]:return
 count(e,owner,"indirect_counters" if indirect else "direct_counters")
 if entry.get("kind","")!="card" or e.cards.get(entry.card.card_id,{}).get("kind","")!="符卡":return
 if e.cards.get(source.get("card_id",""),{}).get("fast",false):count(e,owner,"spell_counters")

static func evidence(e) -> Dictionary:
 if e.task_stats.size()!=2 or e.players.size()!=2:return {}
 var result=e.task_stats.duplicate(true)
 for who in range(2):
  var stats=result[who];var enemy=e.task_stats[1-who]
  stats.final_life=int(e.players[who].life);stats.enemy_final_life=int(e.players[1-who].life)
  stats.overkill=int(enemy.get("_damage_overkill",0)) if int(enemy.get("_damage_life",1))==stats.enemy_final_life else 0
  stats.royal_flare_kill=e.winner==who and e.task_win_reason=="normal" and stats.enemy_final_life<=0 and int(enemy.get("_damage_life",1))==stats.enemy_final_life and enemy.get("_damage_card","")=="spell-ucs-041" and int(enemy.get("_damage_owner",-1))==who
  stats.win_reason=e.task_win_reason
  for key in ["_damage_life","_damage_overkill","_damage_card","_damage_owner"]:stats.erase(key)
 return {"version":1,"players":result}
