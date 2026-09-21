extends RefCounted
const Store=preload("res://scripts/deck_store.gd")
const Identity=preload("res://net/local_identity.gd")
var state={"match_id":"","game_id":"","format":3,"strict":true,"names":["房主","客机"],"scores":[0,0],"round":0,"status":"lobby","ready":[false,false],"registered":[{},{}],"decks":[{},{}],"chooser":0,"first":0,"first_chosen":false,"counted":[],"winner":-2}
func setup(format_value: int,strict: bool):
 state.match_id=Identity.token();state.format=3 if format_value==3 else 1;state.strict=strict
func set_deck(seat: int,deck: Dictionary) -> String:
 if state.status not in ["lobby","between"]:return "当前不能换牌"
 var error=Store.validate(deck,state.strict)
 if not error.is_empty():return error
 if state.status=="between":
  var original=state.registered[seat]
  var pool=original.main+original.side;var next=deck.main+deck.side;pool.sort();next.sort()
  if original.leader!=deck.leader or pool!=next:return "换备牌必须保持自机及登记总牌池不变"
  if deck.main.size()!=original.main.size():return "换备牌后主卡组张数应与登记时一致"
 state.decks[seat]=deck.duplicate(true);state.ready[seat]=false
 return ""
func ready(seat: int) -> String:
 if state.status not in ["lobby","between"]:return "当前不能准备"
 if not state.first_chosen:return "等待选择先后手"
 var error=Store.validate(state.decks[seat],state.strict)
 if not error.is_empty():return error
 state.ready[seat]=true
 return ""
func start_game() -> bool:
 if state.status not in ["lobby","between"] or not state.ready.all(func(v):return v):return false
 if state.round==0:state.registered=state.decks.duplicate(true)
 state.round+=1;state.game_id=Identity.token();state.status="playing";state.ready=[false,false]
 return true
func record_result(winner: int) -> bool:
 if state.game_id in state.counted or state.status!="playing" or winner not in [-1,0,1]:return false
 state.counted.append(state.game_id)
 if winner>=0:state.scores[winner]+=1;state.chooser=1-winner;state.first=1-winner
 if state.scores.any(func(n):return n>= (2 if state.format==3 else 1)):
  state.status="complete";state.winner=winner
 else:state.status="between";state.first_chosen=false
 return true
func public_state(seat: int) -> Dictionary:
 var result=state.duplicate(true);result.erase("registered");result.erase("decks")
 result.own_deck=state.decks[seat].duplicate(true)
 return result
