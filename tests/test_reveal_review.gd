extends "res://tests/support/rules_base.gd"
const Fixture=preload("res://tests/support/reveal_review_fixtures.gd")
const Gateway=preload("res://net/command_gateway.gd")
const Seat=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
const Codec=preload("res://net/state_codec.gd")
const Remote=preload("res://net/remote_duel.gd")

func run():
 for who in [0,1]:
  fresh()
  var fixture=Fixture.ability(e,who)
  Fixture.resolve(e)
  expect(e.pending.get("kind","")=="effect_choice" and e.reveal_resolution.cards.size()==3,"all revealed cards survive until the ability's selection finishes")
  e.presentation_events.clear()
  var recovered=Duel.new();Codec.restore(recovered,bytes_to_var(var_to_bytes(Codec.capture(e))))
  expect(recovered.reveal_resolution.cards.size()==3,"recovery retains the full reveal set during a continuation")
  e=recovered;Fixture.finish(e)
  expect(e.pending.get("kind","")=="reveal_review" and e.pending.owner==1-who,"the effect controller's opponent must confirm")
  if e.pending.get("kind","")!="reveal_review":continue
  expect(e.pending.cards.map(func(c):return c.uid)==fixture.shown.map(func(c):return c.uid),"the review includes every card, including unselected cards")
  expect(e.unresolved_stack_entries().any(func(entry):return entry.id==fixture.stack_id),"the ability remains unresolved while awaiting confirmation")
  var before=Codec.capture(e)
  for seat in [0,1]:
   var projection=Seat.build(e,seat,[])
   expect(projection.state.pending.kind=="reveal_review" and projection.state.pending.cards.size()==3,"both players retain the review after presentation events have been consumed")
   for command in [{"name":"pass_priority","args":[]},{"name":"commit_cast","args":[fixture.shown[0].uid,{},[]]},{"name":"commit_extension","args":[fixture.source.uid,{},[],"character-fdf-041:self"]},{"name":"commit_ability","args":[fixture.source.uid,0,{},[]]}]:
    expect(not Gateway.apply(e,seat,command).is_empty(),"review rejects "+command.name+" for player "+str(seat))
  expect(Codec.capture(e)==before,"rejected actions do not mutate state or advance resolution")
  expect(not Gateway.apply(e,who,{"name":"confirm_revealed","args":[e.pending.serial]}).is_empty(),"the revealing player cannot confirm for the opponent")
  expect(not Gateway.apply(e,1-who,{"name":"confirm_revealed","args":[e.pending.serial+1]}).is_empty(),"a stale or invented confirmation cannot release the lock")
  var serial=e.pending.serial
  expect(Gateway.apply(e,1-who,{"name":"confirm_revealed","args":[serial]}).is_empty(),"only the opponent's matching confirmation ends resolution")
  expect(e.pending.is_empty() and e.unresolved_stack_entries().is_empty(),"confirmation releases the resolution and action lock")
  expect(not Gateway.apply(e,1-who,{"name":"confirm_revealed","args":[serial]}).is_empty(),"duplicate confirmation is rejected")

 fresh()
 var hidden=Fixture.ability(e,0,"character-fdf-119","character-fdf-119:self")
 hidden.shown[0].art_id="reveal-snapshot-art"
 Fixture.resolve(e);Fixture.finish(e)
 expect(e.pending.get("trigger",{}).get("effect","")=="cat:bottom_order" and e.reveal_resolution.cards.size()==3,"the review waits for the second continuation to order every card")
 if e.pending.get("trigger",{}).get("effect","")=="cat:bottom_order":
  var spec=e.pending.options[0]
  e.choose_effect({"selection_id":spec.get("selection_id",""),"picks":[spec.selection[0].pool]})
 expect(e.pending.get("kind","")=="reveal_review" and e.players[0].deck.size()==3,"cards returned to the hidden deck still require review")
 if e.pending.get("kind","")=="reveal_review":
  var projection=Seat.build(e,1,[]);var remote=Remote.new();remote.seat=1;remote.apply_snapshot(projection)
  expect(remote.pending.cards.size()==3 and remote.pending.cards.any(func(c):return c.get("art_id","")=="reveal-snapshot-art"),"remote recovery preserves revealed identities and selected artwork")
  expect(remote.pending.cards.all(func(c):return projection.definitions.has(c.card_id)),"recovery includes definitions for revealed cards that are hidden again")
  expect(remote.players[0].deck.all(func(c):return c.card_id=="back"),"the review does not disclose the remaining library or its order")
  var observer=Observer.build(e,[])
  expect(observer.state.pending.cards.size()==3 and observer.state.pending.cards.all(func(c):return observer.definitions.has(c.card_id)),"spectators retain the public review without any private cards")
  var recovered=Duel.new();Codec.restore(recovered,Codec.capture(e))
  expect(recovered.pending==e.pending,"recovery while reviewing keeps the lock and confirmation token")

 fresh()
 var target=put("character-soi-006","field",1)
 for id in ["spell-fdf-055","character-soi-006","121","164","164"]:put(id,"deck")
 var spell=e.make_card("spell-fdf-015",0,"stack")
 e.stack.append({"id":e.next_stack,"kind":"card","card":spell,"owner":0,"target":e.ref_target(target),"name":e.cards[spell.card_id].name});e.next_stack+=1
 Fixture.resolve(e)
 expect(e.pending.get("trigger",{}).get("effect","")=="cat:heaven" and e.reveal_resolution.cards.size()==5,"a spell retains all five reveals through its follow-up choice")
 if e.pending.get("kind","")=="effect_choice":Fixture.finish(e)
 expect(e.pending.get("kind","")=="reveal_review" and e.pending.cards.size()==5,"spell resolution also waits for review of every shown card")
 if e.pending.get("kind","")=="reveal_review":
  e.ai_step(1)
  expect(e.pending.is_empty(),"an AI opponent acknowledges without stalling the duel")

 fresh()
 var public_card=put("164","hand")
 e.begin_reveal_resolution({"id":999,"kind":"ability","owner":0,"source":public_card,"name":"终局展示"})
 e.reveal_card(public_card);e.lose(1,"生命为零");e.pump_choices()
 expect(e.winner==0 and e.pending.get("kind","")=="reveal_review","a final reveal still awaits confirmation when its resolution ends the game")
 expect(Gateway.apply(e,1,{"name":"confirm_revealed","args":[e.pending.serial]}).is_empty() and e.pending.is_empty(),"the last reveal can be confirmed before match results are presented")

 print("REVEAL REVIEW: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
