extends SceneTree
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Codec=preload("res://net/state_codec.gd")
const Seat=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
var failures=[]
var checks=0
func _initialize():call_deferred("run")
func check(value: bool,label: String):
 checks+=1
 if value:print("PASS: ",label)
 else:failures.append(label);push_error(label)
func fixture():
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 var e=Duel.new();e.start(decks[0],decks[1],0,45);e.presentation_events.clear()
 return e
func zones(e) -> Array:
 return e.players.map(func(p):return [p.hand.duplicate(true),p.deck.duplicate(true)])
func run():
 for first_submit in [0,1]:
  var e=fixture();var other=1-first_submit
  var original=zones(e);var rng_before=e.rng.state
  var choices=e.players.map(func(p):return [p.hand[0].uid,p.hand[1].uid])
  e.mulligan(first_submit,choices[first_submit])
  check(zones(e)==original and e.rng.state==rng_before and e.presentation_events.is_empty(),"first submission leaves both hands, libraries, RNG and animations untouched")
  check(e.phase=="mulligan" and e.turn==0 and e.players[first_submit].mulligan_done,"first submission locks choice and waits")
  var locked=Codec.capture(e)
  e.mulligan(first_submit,[])
  check(Codec.capture(e)==locked,"repeat submission cannot replace a locked choice")
  for projection in [Seat.build(e,other),Observer.build(e)]:
   check(not projection.state.has("mulligan_choices"),"pending private selections are hidden from peers and observers")
  var restored=Duel.new();Codec.restore(restored,locked)
  restored.mulligan(other,choices[other])
  e.mulligan(other,choices[other])
  check(Codec.capture(restored)==Codec.capture(e),"checkpoint restoration preserves staged choices and resolves once")
  check(e.phase!="mulligan" and e.turn==1 and e.mulligan_choices.is_empty(),"second submission resolves both choices and starts exactly one turn")
  for actor in [0,1]:
   check(e.players[actor].hand.size()==4 and e.players[actor].hand.all(func(c):return c.uid not in choices[actor]),"both players receive replacement cards together")
  var reversed=fixture()
  reversed.mulligan(other,choices[other]);reversed.mulligan(first_submit,choices[first_submit])
  check(zones(reversed)==zones(e) and reversed.rng.state==e.rng.state,"submission order does not change replacement cards")
 var invalid=fixture();var before=Codec.capture(invalid);var uid=invalid.players[0].hand[0].uid
 invalid.mulligan(0,[uid,uid]);invalid.mulligan(0,[-999]);invalid.mulligan(-1,[])
 check(Codec.capture(invalid)==before,"invalid selections cannot lock a hand or advance the game")
 var keep=fixture();var hands=keep.players.map(func(p):return p.hand.map(func(c):return c.uid))
 keep.mulligan(0,[]);keep.mulligan(1,[])
 check(keep.players.map(func(p):return p.hand.map(func(c):return c.uid))==hands,"both keep submissions preserve both original hands")
 print("MULLIGAN ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
