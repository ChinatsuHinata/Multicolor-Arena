extends "res://tests/support/rules_base.gd"
const Fixture=preload("res://tests/support/reveal_review_fixtures.gd")
const Seat=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
const Codec=preload("res://net/state_codec.gd")
const Replay=preload("res://scripts/replay_archive.gd")

func run():
 for who in [0,1]:
  fresh()
  var fixture=Fixture.ability(e,who)
  var declaration=e.stack.back().history_index
  fixture.shown[0].art_id="recorded-alternate-art"
  Fixture.resolve(e)
  var summaries=e.history.filter(func(entry):return entry.text.ends_with("展示 3 张牌"))
  expect(summaries.size()==1,"one ability creates one complete reveal summary")
  expect(e.history[declaration].revealed_cards.map(func(c):return c.uid)==fixture.shown.map(func(c):return c.uid),"the original ability announcement opens all revealed cards")
  var recovered=Duel.new();Codec.restore(recovered,bytes_to_var(var_to_bytes(Codec.capture(e))))
  e=recovered;Fixture.finish(e)
  var resolved=e.history.filter(func(entry):return entry.text.ends_with("结算") and entry.has("revealed_cards"))
  expect(not resolved.is_empty() and resolved.back().revealed_cards.size()==3,"the resolution entry retains selected and unselected cards after a continuation")
  e.confirm_revealed(1-who,e.pending.serial);e.presentation_events.clear()
  var original=e.history[declaration].revealed_cards.duplicate(true)
  for c in e.players[who].deck+e.players[who].hand:c.card_id="106";c.art_id="changed-art"
  expect(e.history[declaration].revealed_cards==original,"later identity and artwork changes cannot mutate historical snapshots")
  var projection=Seat.build(e,1-who)
  var remote_cards=projection.state.history[declaration].revealed_cards
  expect(remote_cards==original and remote_cards.all(func(c):return projection.definitions.has(c.card_id)),"remote recovery includes definitions for cards that have become hidden or changed")
  var observer=Observer.build(e)
  expect(observer.state.history[declaration].revealed_cards==original and original.all(func(c):return observer.definitions.has(c.card_id)),"spectators can reopen all public reveal snapshots after confirmation")
  var archive=Replay.new()
  archive.record({"game_id":"history-test","sequence":e.revision,"room":{},"projection":observer},-1)
  expect(archive.frame(0).projection.state.history[declaration].revealed_cards==original,"replay frames preserve the complete reveal details")

 fresh()
 var source=put("164","field")
 var first=put("53","hand");var copy=put("53","hand")
 e.begin_reveal_resolution({"id":999,"kind":"ability","owner":0,"source":source,"name":"第一批展示"})
 e.reveal_card(first);e.reveal_card(first);e.reveal_card(copy);e.finish_reveal_resolution()
 var summary=e.history.back().duplicate(true)
 expect(summary.revealed_cards.size()==2 and summary.revealed_cards[0].uid!=summary.revealed_cards[1].uid,"same-name copies remain separate and repeated presentation of the same instance is deduplicated")
 e.confirm_revealed(1,e.pending.serial)
 var second=put("100","hand")
 e.begin_reveal_resolution({"id":1000,"kind":"ability","owner":0,"source":source,"name":"第二批展示"})
 e.reveal_card(second);e.finish_reveal_resolution()
 expect(e.history.any(func(entry):return entry==summary) and e.history.back().revealed_cards.size()==1,"successive abilities retain independent reveal batches")

 fresh()
 var private_card=put("106","hand",1)
 private_card.art_id="private-art"
 e.record_history("未公开的移动",[{"card_id":"106","owner":1,"hidden":true,"art_id":"private-art"}])
 var index=e.history.size()-1
 var opponent=Seat.build(e,0);var watcher=Observer.build(e)
 for projection in [opponent,watcher]:
  var art=projection.state.history[index].art[0]
  expect(art.card_id=="back" and not art.has("art_id") and not projection.definitions.has("106"),"history projection keeps unrevealed cards and artwork private")
 expect(e.history[index].art[0].card_id=="106","projecting history never mutates authoritative snapshots")
 var owner=Seat.build(e,1)
 expect(owner.state.history[index].art[0].card_id=="106" and owner.definitions.has("106"),"the owner can still inspect their own private history artwork")
 print("BATTLE HISTORY: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
