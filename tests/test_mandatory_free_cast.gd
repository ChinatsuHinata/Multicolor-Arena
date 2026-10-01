extends "res://tests/support/rules_base.gd"

func run():
 fresh()
 var youmu=put("character-fdf-102")
 youmu.leader=true
 var palette_spell=put("spell-fdf-049","palette")
 mana()
 expect(e.Roster.mandatory_free_cast(e,palette_spell,0),"Youmu's palette permission requires a free cast")
 expect(not e.offers_free_cast(0,palette_spell),"Youmu's palette cast skips the payment choice")
 e.paid_cast_uid=palette_spell.uid
 expect(e.cast_cost(0,palette_spell).is_empty(),"paid preference cannot override Youmu's free palette cast")
 e.paid_cast_uid=-1

 for access in ["history","philosopher","seiran","exile_free"]:
  fresh()
  var spell=put("99","exile")
  match access:
   "history":spell.excel_access={"owner":0,"turn":e.turn,"ignore":false}
   "philosopher":spell.excel_access={"owner":0,"turn":e.turn,"ignore":true}
   "seiran":spell.free_exile_owner=0
   "exile_free":e.players[0].exile_free={"turn":e.turn,"remaining":1}
  expect(e.Roster.mandatory_free_cast(e,spell,0),access+" marks exile use as mandatory free")
  expect(not e.offers_free_cast(0,spell),access+" hides the paid option")
  e.paid_cast_uid=spell.uid
  expect(e.cast_cost(0,spell).is_empty(),access+" stays free under a paid preference")
  mana()
  var paid_plan=e.payment(0,e.cards[spell.card_id].cost).plan
  expect(not e.cast_payment_valid(0,spell,{},paid_plan),access+" rejects a normal-cost payment plan")

 fresh()
 var unit=put("53","hand")
 e.players[0].next_free_unit=e.turn
 expect(e.Roster.mandatory_free_cast(e,unit,0) and not e.offers_free_cast(0,unit),"next unit free cast is mandatory")
 e.paid_cast_uid=unit.uid
 expect(e.cast_cost(0,unit).is_empty(),"next unit stays free under a paid preference")

 fresh()
 unit=put("53","hand")
 put("spell-ucs-019")
 expect(not e.Roster.mandatory_free_cast(e,unit,0) and e.offers_free_cast(0,unit),"free anthem retains its optional payment choice")
 e.paid_cast_uid=unit.uid
 expect(not e.cast_cost(0,unit).is_empty(),"optional free anthem can use normal cost")

 fresh()
 var granted=put("spell-ucs-035","hand")
 e.forced_cast={"owner":0,"uid":granted.uid,"free":true}
 expect(e.Roster.mandatory_free_cast(e,granted,0) and not e.offers_free_cast(0,granted),"immediate free grant does not offer payment")
 e.paid_cast_uid=granted.uid
 expect(e.cast_cost(0,granted).is_empty(),"immediate free grant ignores paid preference")
 e.forced_cast.optional_payment=true
 expect(not e.Roster.mandatory_free_cast(e,granted,0) and e.offers_free_cast(0,granted),"explicit optional free grant still offers payment")
 expect(not e.cast_cost(0,granted).is_empty(),"explicit optional grant can use normal cost")

 fresh()
 put("53")
 granted=put("112","hand")
 e.Cat.grant_cast(e,granted,0,true)
 expect(e.pending.get("kind","")=="effect_choice" and e.pending.trigger.data.get("free",false) and not e.pending.trigger.data.get("optional_payment",false),"grant keeps the mandatory free instruction")
 if not e.pending.is_empty():
  e.set_granted_payment(true)
  expect(e.paid_cast_uid<0 and not e.pending.trigger.data.get("payment_chosen",false),"mandatory grant rejects a paid choice")

 fresh()
 put("53")
 granted=put("112","hand")
 e.Cat.grant_cast(e,granted,0,true,{},true)
 expect(e.pending.get("kind","")=="effect_choice" and e.pending.trigger.data.get("optional_payment",false),"optional grant records its payment choice")
 if not e.pending.is_empty():
  e.set_granted_payment(true)
  expect(e.paid_cast_uid==granted.uid and e.pending.trigger.data.get("payment_chosen",false),"optional grant permits the paid choice")

 fresh()
 var palette=put("53","palette")
 e.players[0].palette_access=e.turn
 expect(not e.Roster.mandatory_free_cast(e,palette,0) and not e.cast_cost(0,palette).is_empty(),"palette access without free wording retains normal cost")

 print("MANDATORY_FREE_CAST: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
