extends SceneTree
const Session=preload("res://net/lan_session.gd")
const Remote=preload("res://net/remote_duel.gd")
const Codec=preload("res://net/state_codec.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Store=preload("res://scripts/deck_store.gd")
func _init():call_deferred("run")
func run():
 var e=Session.Duel.new();var decks=Store.load_decks().decks;e.start(decks[0],decks[1],0,123)
 var saved=Codec.capture(e);var restored=Session.Duel.new();Codec.restore(restored,bytes_to_var(var_to_bytes(saved)))
 assert(e.players==restored.players);assert(e.rng.state==restored.rng.state)
 var c=restored.players[0].leader;restored.players[0].field.append(c);restored.players[0].leader.zone="field"
 var cloned=Session.Duel.new();Codec.restore(cloned,Codec.capture(restored));assert(is_same(cloned.players[0].leader,cloned.players[0].field.back()))
 for seat in [0,1]:
  var snap=SeatView.build(e,seat,e.presentation_events);var facade=Remote.new();facade.seat=seat;facade.apply_snapshot(snap)
  assert(facade.players[1-seat].hand.all(func(x):return x.card_id=="back"))
  assert(facade.players[seat].deck.all(func(x):return x.card_id=="back"))
  assert(facade.players[seat].hand==e.players[seat].hand)
 print("V018 core codec/projection PASS")
 quit()
