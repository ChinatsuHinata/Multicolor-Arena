extends "res://tests/support/rules_base.gd"
const N=preload("res://scripts/rules/new0921_cards.gd")
const Seat=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")

func setup_books(codes: Array):
 fresh();e.players[0].deck=[]
 for code in codes:put(N.id(code),"deck")
 var source=put(N.id("ETO-003"))
 N.event(e,source,"ETO-003");e.pump_choices();one()
 expect(e.pending.get("trigger",{}).get("effect","")=="n21:three_books_search","entry resolves before searching for books")
 return e.pending.options[0]

func pick(spec: Dictionary,groups: Array) -> Dictionary:
 var result=spec.duplicate(true);result.erase("selection");result.picks=groups;return result

func run():
 var spec=setup_books(["ETO-007","ETO-007","ETO-009","ETO-009","ETO-011","ETO-011"])
 var pool=spec.selection[0].pool
 expect(spec.selection[0].min==3 and spec.selection[0].max==3,"ABC requires exactly three books")
 var original=JSON.stringify(e.pending)
 e.choose_effect(pick(spec,[[pool[0],pool[1],pool[2]]]))
 expect(JSON.stringify(e.pending)==original,"engine rejects two copies of A and a missing C")
 e.choose_effect(pick(spec,[[pool[0],pool[2]]]))
 expect(JSON.stringify(e.pending)==original,"engine rejects an incomplete mandatory search")
 e.choose_effect(pick(spec,[[]]))
 expect(JSON.stringify(e.pending)==original,"mandatory search cannot be skipped")
 var chosen=[pool[1],pool[3],pool[5]]
 var projection=Seat.build(e,0)
 var remote=Remote.new();remote.seat=0;remote.apply_snapshot(projection)
 expect(remote.pending.options[0].selection[0].min==3 and remote.pending.options[0].selection[0].distinct_names,"network projection preserves the mandatory search constraints")
 expect(chosen.all(func(r):return not remote.find_card(r.uid).is_empty()),"searchable book identities are available to the choosing client")
 e.choose_effect(pick(spec,[chosen]))
 expect(e.pending.trigger.effect=="n21:three_books" and e.pending.options[0].selection.size()==3,"completed search opens three destination choices")
 var destinations=e.pending.options[0]
 chosen=chosen.map(func(r):return destinations.selection[0].pool.filter(func(p):return p.uid==r.uid)[0])
 expect(destinations.selection.all(func(g):return g.min==0 and g.max==1 and g.exclude_previous and g.pool.size()==3),"each destination is optional and only offers the three searched copies")
 expect(e.presentation_events.filter(func(event):return event.type=="reveal").size()==3,"each searched book is revealed once")
 original=JSON.stringify(e.pending)
 e.choose_effect(pick(destinations,[[chosen[0]],[chosen[0]],[]]))
 expect(JSON.stringify(e.pending)==original,"engine rejects sending a book to two destinations")
 e.choose_effect(pick(destinations,[[chosen[0],chosen[1]],[],[]]))
 expect(JSON.stringify(e.pending)==original,"each destination accepts at most one book")
 e.choose_effect(pick(destinations,[[pool[0]],[],[]]))
 expect(JSON.stringify(e.pending)==original,"unsearched duplicate copies cannot be assigned")
 e.choose_effect(pick(destinations,[[chosen[2]],[chosen[0]],[chosen[1]]]))
 expect(e.find_card(chosen[2].uid).zone=="hand" and e.find_card(chosen[0].uid).zone=="grave" and e.find_card(chosen[1].uid).zone=="palette" and e.find_card(chosen[1].uid).tapped,"player decides which book goes to hand, grave and tapped palette")
 expect(e.players[0].deck.size()==3,"unselected duplicate copies remain in the library")

 for codes in [["ETO-009","ETO-009","ETO-011"],["ETO-007"],[]]:
  spec=setup_books(codes);pool=spec.selection[0].pool
  var names=[];chosen=[]
  for r in pool:
   if r.choice_name not in names:names.append(r.choice_name);chosen.append(r)
  expect(spec.selection[0].min==names.size() and spec.selection[0].max==names.size(),"missing species reduces mandatory search to the available species")
  e.choose_effect(pick(spec,[chosen]))
  destinations=e.pending.options[0]
  var before_rng=e.rng.state
  e.choose_effect(pick(destinations,[[],[],[]]))
  expect(e.pending.is_empty() and e.players[0].deck.size()==codes.size() and e.players[0].hand.is_empty() and e.players[0].grave.is_empty() and e.players[0].palette.is_empty(),"all destinations can be skipped, leaving every book in the library")
  if codes.size()>1:expect(e.rng.state!=before_rng,"remaining books are shuffled after all destinations are skipped")
 print("SONG COLLECTION: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
