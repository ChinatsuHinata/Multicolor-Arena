extends SceneTree
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Store=preload("res://scripts/deck_store.gd")
var failed=[]

func expect(ok: bool,title: String):
 if ok: print("PASS: "+title)
 else: failed.append(title); push_error(title)

func _initialize(): call_deferred("run")

func fresh():
 var deck=Store.blank("摩多罗颜色约束"); deck.leader="70"
 for i in range(50): deck.main.append("164")
 var e=Duel.new(); e.start(deck,deck,0,24)
 for p in e.players:
  p.hand=[]; p.palette=[]; p.field=[]; p.grave=[]; p.potato=false
 e.phase="main"; e.turn=5; e.priority=0; e.active=0
 return e

func put(e,who: int,id: String,zone: String):
 var c=e.make_card(id,who,zone); e.players[who][zone].append(c); return c

func run():
 for id in ["character-ucs-068","character-fdn-071"]:
  var e=fresh()
  var okina=e.make_card(id,0,"leader",true)
  e.players[0].leader=okina
  e.move_to(okina,"field")
  for i in range(3): put(e,0,"70","palette")
  var hand_leader=put(e,0,"70","hand")
  expect(e.payment(0,e.cards["70"].cost).ways>0,"Reimu cost is payable with "+id)
  expect(e.cast_error(0,hand_leader.uid).is_empty(),"active Okina lets another self card ignore battlefield colors: "+id)
  var cast_result=e.commit_cast(0,hand_leader.uid,{},e.payment(0,e.cast_cost(0,hand_leader)).plan)
  expect(cast_result.is_empty() and hand_leader.zone=="stack","self card can actually be cast under Okina: "+id)
  e=fresh()
  okina=e.make_card(id,0,"leader",true)
  e.players[0].leader=okina
  e.move_to(okina,"field")
  for i in range(3): put(e,0,"70","palette")
  var deck_self=e.make_card("70",0,"deck")
  e.players[0].deck.push_front(deck_self)
  expect(e.cast_error(0,deck_self.uid).is_empty(),"active Okina permits a top-deck self card without battlefield colors: "+id)
  cast_result=e.commit_cast(0,deck_self.uid,{},e.payment(0,e.cast_cost(0,deck_self)).plan)
  expect(cast_result.is_empty() and deck_self.zone=="stack","top-deck self card can actually be cast: "+id)
  e=fresh()
  put(e,0,id,"field")
  for i in range(3): put(e,0,"70","palette")
  hand_leader=put(e,0,"70","hand")
  expect("颜色约束" in e.cast_error(0,hand_leader.uid),"ordinary Okina without self ability does not waive colors: "+id)
  deck_self=e.make_card("70",0,"deck")
  e.players[0].deck.push_front(deck_self)
  expect("颜色约束" in e.cast_error(0,deck_self.uid),"ordinary Okina may use top deck but does not waive colors: "+id)
 print("OKINA_COLOR_BYPASS_TEST: %d failures" % failed.size())
 quit(0 if failed.is_empty() else 1)
