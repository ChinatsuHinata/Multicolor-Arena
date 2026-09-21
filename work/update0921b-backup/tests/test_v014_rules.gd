extends "res://tests/test_v013_rules.gd"
func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 fresh();var songs=e.cards.keys().filter(func(id):return "乐章" in e.cards[id].get("spell_type",""))
 expect(songs.size()==13,"all thirteen registered melodies included")
 for id in songs:
  fresh();var old=put("spell-fdf-ex05","field",1);old.modifiers=[{"keywords":["不会被消灭"],"until":-1}]
  var c=e.make_card(id,0,"stack");var n=e.stack.size()
  expect(e.enter_field(c,0),"melody enters "+id)
  expect(old.zone=="grave" and e.players[1].grave.has(old) and e.players[0].field.has(c),"opposing melody replaced into owner's grave "+id)
  expect(e.stack.size()==n and e.history.any(func(row):return row.get("rule_action",false)),"replacement is immediate recorded rule action "+id)
 fresh();var old=put("spell-ucs-011");old.original_owner=1
 var c=e.make_card("spell-fdf-042",0,"stack");e.enter_field(c,0)
 expect(old.owner==1 and e.players[1].grave.has(old),"stolen melody returns to original owner")
 fresh();old=put("spell-fdf-042");var incoming=stacked("spell-ucs-033",1,{"none":true});e.counter_entry(incoming.id)
 expect(old.zone=="field" and incoming.card.zone=="grave","countered melody never replaces existing melody")
 fresh();old=put("spell-fdf-042");c=put("spell-ucs-033","hand",1);e.Roster.field_many(e,[c],1)
 expect(old.zone=="grave" and c.zone=="field","effect entry uses same global melody rule")
 fresh();old=put("spell-fdf-042");c=put("spell-ucs-033","hand",1);e.debug_enabled=true
 expect(e.debug_move(c.uid,"field").is_empty() and old.zone=="grave" and c.zone=="field","debug entry preserves legal single melody")
 expect(e.stack.is_empty() and e.triggers.is_empty(),"debug melody replacement has no effect triggers")
 fresh();c=put("96","hand",1);var original=c.duplicate(true);e.reveal_card(c);e.reveal_card(c)
 expect(e.presentation_events.size()==2 and e.presentation_events[0].serial!=e.presentation_events[1].serial,"repeated reveals each create a presentation")
 expect(c==original and c.zone=="hand","reveal does not mutate card or grant permanent visibility")
 e.move_to(c,"grave");expect(e.presentation_events[0].card.zone=="hand","presentation retains source zone after immediate movement")
 fresh();c=put("spell-fdf-078","deck");e.Cat.reveal(e,[c]);expect(e.presentation_events[0].edge=="top" and e.triggers.any(func(t):return t.effect=="cat:element_reveal"),"top reveal keeps element trigger and animation")
 e.presentation_events.clear();e.triggers.clear();e.Cat.reveal(e,[c],false,"bottom")
 expect(e.presentation_events[0].edge=="bottom" and e.triggers.is_empty(),"bottom reveal does not grant top-only trigger")
 fresh();c=put("character-fdf-092");cat_trigger(c,c.card_id);expect(e.presentation_events.size()==3 and e.presentation_events.all(func(a):return a.edge=="bottom"),"bottom-three ability queues each card")
 expect(e.presentation_events[0].card.uid==e.players[0].deck.back().uid,"bottom reveal starts with actual bottom card")
 fresh();c=put("character-mar-ex");trigger(c,"patch_topthree")
 expect(e.presentation_events.size()==3 and not e.pending.is_empty(),"older top-three ability queues reveals before selection")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"saved decks unchanged")
 print("V014_RULES: ",checks," checks; ",failures," failures");quit(0 if failures.is_empty() else 1)
