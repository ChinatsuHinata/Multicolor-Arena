extends RefCounted
const Store=preload("res://scripts/deck_store.gd")
const Identity=preload("res://net/local_identity.gd")
var state={"match_id":"","game_id":"","format":3,"strict":true,"names":["房主","客机"],"scores":[0,0],"round":0,"status":"lobby","ready":[false,false],"registered":[{},{}],"decks":[{},{}],"first":0,"coin":{},"coin_history":[],"counted":[],"winner":-2}
func setup(format_value: int,strict: bool):
 state.match_id=Identity.token();state.format=3 if format_value==3 else 1;state.strict=strict
func set_deck(seat: int,deck: Dictionary) -> String:
 if state.status not in ["lobby","between"]:return "当前不能换牌"
 var error=sideboard_error(deck,state.registered[seat],state.strict) if state.status=="between" else Store.validate(deck,state.strict)
 if not error.is_empty():return error
 state.decks[seat]=deck.duplicate(true);state.ready[seat]=false
 return ""
static func sideboard_error(deck: Dictionary,original: Dictionary,strict: bool) -> String:
 var error=Store.validate(deck,strict)
 if not error.is_empty():return error
 if original.is_empty():return "缺少登记卡组"
 var pool=original.main+original.side;var next=deck.main+deck.side;pool.sort();next.sort()
 if original.leader!=deck.leader or pool!=next:return "换备牌必须保持自机及登记总牌池不变"
 if deck.main.size()!=original.main.size():return "换备牌后主卡组张数应与登记时一致"
 return ""
func abort():
 if state.status in ["aborted","complete"]:return
 state.status="aborted";state.winner=-2;state.ready=[false,false]
 state.end_reason="连接中断，对局结束"
func forfeit(disconnected_seat: int,local_record: bool=false):
 if state.status in ["complete","aborted"]:return
 state.status="complete";state.winner=1-disconnected_seat;state.ready=[false,false]
 state.forfeit=disconnected_seat;state.local_record=local_record
 state.end_reason=state.names[disconnected_seat]+"掉线超时，整场判负"+("（本地记录）" if local_record else "")
func ready(seat: int) -> String:
 if state.status not in ["lobby","between"]:return "当前不能准备"
 var error=Store.validate(state.decks[seat],state.strict)
 if not error.is_empty():return error
 state.ready[seat]=true
 return ""
func start_game() -> bool:
 if state.status not in ["lobby","between"] or not state.ready.all(func(v):return v):return false
 if state.round==0:state.registered=state.decks.duplicate(true)
 state.round+=1;state.game_id=Identity.token();state.status="playing";state.ready=[false,false]
 # One authoritative opening coin per game, independent of in-game coin abilities.
 state.first=int(Crypto.new().generate_random_bytes(1)[0])%2
 state.coin={"game_id":state.game_id,"round":state.round,"face":"正面" if state.first==0 else "反面","first":state.first}
 state.coin_history.append(state.coin.duplicate(true))
 return true
func coin_text() -> String:
 return "开局硬币 · %s · %s先手" % [state.coin.face,state.names[state.first]] if not state.coin.is_empty() else "双方准备后投硬币决定先后手"
func record_result(winner: int) -> bool:
 if state.game_id in state.counted or state.status!="playing" or winner not in [-1,0,1]:return false
 state.counted.append(state.game_id)
 if winner>=0:state.scores[winner]+=1
 if state.scores.any(func(n):return n>= (2 if state.format==3 else 1)):
  state.status="complete";state.winner=winner
 else:state.status="between"
 return true
func public_state(seat: int) -> Dictionary:
 var result=state.duplicate(true);result.erase("registered");result.erase("decks")
 result.own_deck=state.decks[seat].duplicate(true) if seat in [0,1] else {}
 return result
