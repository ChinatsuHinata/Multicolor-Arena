extends RefCounted
# Only the eight registered demo cards are supported in this ruleset.
const DB=preload("res://scripts/card_database.gd")
static func resolved(engine, entry: Dictionary):
 var card=engine.cards[entry.card.card_id]
 if card.kind!="符卡":
  var entered=engine.enter_field(entry.card,entry.owner)
  if entered and DB.has_ability(card,"marisa_enter"):
   engine.queue_trigger(entry.owner,entry.card,int(DB.ability(card,"marisa_enter")["数值"]),"进战场能力")
  return
 for binding in card.abilities:
  match binding["实现"]:
   "damage": engine.damage_target(entry.target,int(binding["参数"]["数值"]))
   "counter_card": engine.counter_entry(int(entry.target.get("stack_id",-1)))
 engine.to_grave(entry.card)
static func spell_used(engine, owner: int):
 for unit in engine.players[owner].field:
  if DB.has_ability(engine.cards[unit.card_id],"marisa_spell") and engine.has_leader_ability(unit):
   engine.queue_trigger(owner,unit,int(DB.ability(engine.cards[unit.card_id],"marisa_spell")["数值"]),"使用符卡能力")
