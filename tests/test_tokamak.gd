extends "res://tests/support/rules_base.gd"
const Codec=preload("res://net/state_codec.gd")

func prepare(who: int=0):
 fresh();e.active=who;e.priority=who
 put("character-fdn-042","field",who)
 for i in range(3):put("162","palette",who)

func deck_ids(who: int) -> Array:
 return e.players[who].deck.map(func(c):return c.uid)

func run():
 for who in [0,1]:
  prepare(who)
  var spell=put("162","deck",who)
  var before=deck_ids(who);var opponent=deck_ids(1-who);var rng_before=e.rng.state
  var plan=e.payment(who,e.cast_cost(who,spell)).plan
  expect(not e.commit_cast(who,spell.uid,{"player":4},plan).is_empty(),"invalid target rejects Tokamak")
  expect(e.rng.state==rng_before and deck_ids(who)==before,"invalid target leaves deck and random state unchanged")
  expect(not e.commit_cast(who,spell.uid,{"player":1-who},[]).is_empty(),"invalid payment rejects Tokamak")
  expect(e.rng.state==rng_before and deck_ids(who)==before,"invalid payment does not shuffle or remove Tokamak")
  expect(e.commit_cast(who,spell.uid,{"player":1-who},plan).is_empty(),"deck Tokamak commits for player "+str(who))
  expect(spell.zone=="stack" and e.rng.state!=rng_before,"successful declaration removes Tokamak and shuffles immediately")
  var remaining=before.duplicate();remaining.erase(spell.uid);remaining.sort()
  var after=deck_ids(who);var actual=after.duplicate();actual.sort()
  expect(actual==remaining and after!=before.slice(0,-1),"shuffle preserves every remaining card and changes its order")
  expect(deck_ids(1-who)==opponent,"only the casting player's deck is shuffled")
  expect(e.log.back().contains("洗牌"),"shuffle is recorded in the duel log")
  var rng_after=e.rng.state
  var restored=Duel.new();Codec.restore(restored,Codec.capture(e))
  expect(restored.rng.state==rng_after and restored.players[who].deck==e.players[who].deck,"network save and undo state retain the shuffled deck and RNG")
  e.counter_entry(e.stack.back().id)
  expect(spell.zone=="grave" and deck_ids(who)==after and e.rng.state==rng_after,"countering Tokamak keeps the shuffle without shuffling again")

 prepare()
 var hand_spell=put("162","hand");var order=deck_ids(0);var rng_before=e.rng.state
 expect(e.commit_cast(0,hand_spell.uid,{"player":1},e.payment(0,e.cast_cost(0,hand_spell)).plan).is_empty(),"hand Tokamak commits normally")
 expect(deck_ids(0)==order and e.rng.state==rng_before,"using Tokamak from hand does not shuffle")
 for count in [0,1]:
  prepare();e.players[0].deck=[]
  for i in range(count):put("164","deck")
  var spell=put("162","deck")
  expect(e.commit_cast(0,spell.uid,{"player":1},e.payment(0,e.cast_cost(0,spell)).plan).is_empty() and e.players[0].deck.size()==count,"empty and single-card remaining decks shuffle safely: "+str(count))
 print("TOKAMAK: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
