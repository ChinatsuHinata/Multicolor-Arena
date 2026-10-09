extends RefCounted
const Store=preload("res://scripts/deck_store.gd")
const RuleSet=preload("res://scripts/deck_rule_set.gd")
const Identity=preload("res://net/local_identity.gd")
const BO1=1
const BO1_SIDEBOARD=2
const BO3=3
const SIDEBOARD_LIMIT=3
static func format_label(format_value: int) -> String:
 return "BO1 换备牌" if format_value==BO1_SIDEBOARD else "BO%d" % format_value
static func sideboard_limit(room: Dictionary) -> int:
 return SIDEBOARD_LIMIT if int(room.get("format",BO3))==BO1_SIDEBOARD else -1
var state={"match_id":"","game_id":"","format":3,"strict":true,"rule_set":RuleSet.UNRESTRICTED,"names":["房主","客机"],"scores":[0,0],"round":0,"status":"lobby","ready":[false,false],"registered":[{},{}],"decks":[{},{}],"first":0,"chooser":-1,"first_chosen":false,"choice_reason":"","roll":{},"roll_history":[],"choice_history":[],"last_winner":-2,"counted":[],"winner":-2}
func setup(format_value: int,strict: bool,rule_set: String=RuleSet.UNRESTRICTED):
 state.match_id=Identity.token();state.format=format_value if format_value in [BO1,BO1_SIDEBOARD,BO3] else BO1;state.strict=strict;state.rule_set=rule_set
func rematch() -> String:
 if state.status!="complete" or state.has("forfeit"):return "当前不能开始新的一场"
 var old=state
 state={"match_id":"","game_id":"","format":3,"strict":true,"rule_set":RuleSet.UNRESTRICTED,"names":old.names.duplicate(true),"scores":[0,0],"round":0,"status":"lobby","ready":[false,false],"registered":[{},{}],"decks":old.decks.duplicate(true),"first":0,"chooser":-1,"first_chosen":false,"choice_reason":"","roll":{},"roll_history":[],"choice_history":[],"last_winner":-2,"counted":[],"winner":-2,"rematch":true}
 setup(old.format,old.strict,old.rule_set)
 return ""
func set_deck(seat: int,deck: Dictionary) -> String:
 if state.status not in ["lobby","sideboarding","between"]:return "当前不能换牌"
 if state.status=="sideboarding" and state.ready[seat]:return "请先取消准备再换备牌"
 var error=sideboard_error(deck,state.registered[seat],state.strict,state.rule_set,sideboard_limit(state)) if state.status!="lobby" else Store.validate(deck,state.strict,state.rule_set)
 if not error.is_empty():return error
 state.decks[seat]=Store.clean_deck(deck);state.ready[seat]=false
 return ""
static func sideboard_additions(deck: Dictionary,original: Dictionary) -> int:
 # Count extra copies in main, so repeated submissions and sorting cannot reset the limit.
 var remaining=original.get("main",[]).duplicate()
 var added=0
 for id in deck.get("main",[]):
  var index=remaining.find(id)
  if index>=0:remaining.remove_at(index)
  else:added+=1
 return added
static func sideboard_error(deck: Dictionary,original: Dictionary,strict: bool,rule_set: String=RuleSet.UNRESTRICTED,max_additions: int=-1) -> String:
 var error=Store.validate(deck,strict,rule_set)
 if not error.is_empty():return error
 if original.is_empty():return "缺少登记卡组"
 var pool=original.main+original.side;var next=deck.main+deck.side;pool.sort();next.sort()
 if original.leader!=deck.leader or pool!=next:return "换备牌必须保持自机及登记总牌池不变"
 if deck.main.size()!=original.main.size():return "换备牌后主卡组张数应与登记时一致"
 if max_additions>=0 and sideboard_additions(deck,original)>max_additions:return "BO1 换备牌最多从备牌换入 %d 张牌" % max_additions
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
 if state.status not in ["lobby","sideboarding","between"]:return "当前不能准备"
 var error=sideboard_error(state.decks[seat],state.registered[seat],state.strict,state.rule_set,sideboard_limit(state)) if state.status=="sideboarding" else Store.validate(state.decks[seat],state.strict,state.rule_set)
 if not error.is_empty():return error
 state.ready[seat]=true
 return ""
func roll_die() -> int:
 var value=256
 while value>=252:value=int(Crypto.new().generate_random_bytes(1)[0])
 return value%6+1
func prepare_choice() -> bool:
 if state.status not in ["lobby","sideboarding","between"] or not state.ready.all(func(v):return v):return false
 if state.status=="lobby" and state.format==BO1_SIDEBOARD:
  state.registered=state.decks.duplicate(true)
  state.status="sideboarding";state.ready=[false,false]
  return true
 state.first_chosen=false
 if state.round==0:
  var host_roll=roll_die();var guest_roll=roll_die();var ties=0
  while host_roll==guest_roll:
   ties+=1;host_roll=roll_die();guest_roll=roll_die()
  state.chooser=0 if host_roll>guest_roll else 1
  state.roll={"round":1,"values":[host_roll,guest_roll],"ties":ties,"chooser":state.chooser}
  state.roll_history.append(state.roll.duplicate(true))
  state.choice_reason="投点获胜"
 else:
  state.roll={}
  if state.last_winner in [0,1]:
   state.chooser=1-state.last_winner
   state.choice_reason="上一局落败"
  else:state.choice_reason="上一局平局，沿用选择权"
 state.status="choosing"
 return true
func choose_first(seat: int,wants_first: bool) -> String:
 if state.status!="choosing" or state.first_chosen:return "当前不能选择先后手"
 if seat!=state.chooser:return "只能由取得选择权的玩家决定先后手"
 state.first=seat if wants_first else 1-seat
 state.first_chosen=true
 return ""
func start_game() -> bool:
 if state.status!="choosing" or not state.first_chosen:return false
 if state.round==0 and state.format!=BO1_SIDEBOARD:state.registered=state.decks.duplicate(true)
 state.round+=1;state.game_id=Identity.token();state.status="playing";state.ready=[false,false]
 state.choice_history.append({"game_id":state.game_id,"round":state.round,"chooser":state.chooser,"first":state.first,"reason":state.choice_reason})
 return true
func opening_text() -> String:
 var reason="投点 %s %d : %d %s · " % [state.names[0],state.roll["values"][0],state.roll["values"][1],state.names[1]] if state.round==1 else state.choice_reason+" · "
 return reason+state.names[state.chooser]+"选择 · "+state.names[state.first]+"先手"
func record_result(winner: int) -> bool:
 if state.game_id in state.counted or state.status!="playing" or winner not in [-1,0,1]:return false
 state.counted.append(state.game_id)
 state.last_winner=winner
 if winner>=0:state.scores[winner]+=1
 if state.scores.any(func(n):return n>= (2 if state.format==3 else 1)):
  state.status="complete";state.winner=winner
 else:state.status="between"
 return true
func public_state(seat: int) -> Dictionary:
 var result=state.duplicate(true);result.erase("registered");result.erase("decks")
 result.erase("deck_hashes")
 result.own_deck=state.decks[seat].duplicate(true) if seat in [0,1] else {}
 if state.format==BO1_SIDEBOARD and not state.registered[0].is_empty() and not state.registered[1].is_empty():
  result.leaders=[state.registered[0].leader,state.registered[1].leader]
  result.leader_arts=[]
  for deck in state.registered:result.leader_arts.append(Store.Art.selected(deck,deck.leader,Store.CARDS))
  if seat in [0,1] and state.status in ["sideboarding","between"]:result.own_registered=state.registered[seat].duplicate(true)
 return result
