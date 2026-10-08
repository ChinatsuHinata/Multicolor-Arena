extends SceneTree
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Undo=preload("res://net/undo_history.gd")
const Codec=preload("res://net/state_codec.gd")
var checks=0
var failures=[]
var e

func check(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);push_error(label)

func fresh():
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 e=Duel.new();e.start(decks[0],decks[1],0,123)
 for player in e.players:
  for zone in ["hand","field","palette","grave","exile","deck"]:player[zone]=[]
  player.mulligan_done=true;player.turns=3;player.potato=false
 e.turn=5;e.active=0;e.priority=0;e.phase="possession";e.pending={};e.passes=0
 e.presentation_events=[];e.stack=[];e.triggers=[];e.returns=[]

func put(id: String,zone: String,seat: int=0) -> Dictionary:
 var card=e.make_card(id,seat,zone);card.entered_turns=0
 e.players[seat][zone].append(card)
 return card

func _init():call_deferred("run")
func run():
 fresh();var history=Undo.new()
 for phase in ["prepare","draw","possession","end"]:
  e.phase=phase
  check(not history.can_decide(e),"empty "+phase+" is an automatic window")
 e.phase="main"
 check(history.can_decide(e),"empty main keeps the decision to end the phase")
 e.phase="mulligan"
 check(not history.can_decide(e),"completed mulligans are not a new decision")
 e.players[1].mulligan_done=false
 check(history.can_decide(e),"either player's outstanding mulligan is a decision")
 e.players[1].mulligan_done=true;e.phase="possession"
 for kind in ["possession","discard"]:
  e.pending={"kind":kind,"owner":0,"count":1}
  check(history.can_decide(e),kind+" selection is preserved")
 e.pending={}
 var fast=put("177","hand",1);e.cards["177"].cost={}
 check(not history.can_decide(e),"fast card with no legal target does not retain an empty window")
 var target=put("53","field",1);target.tapped=true
 e.cards["177"].cost={"蓝":1}
 check(not history.can_decide(e),"unaffordable fast card does not retain an empty window")
 e.cards["177"].cost={}
 e.payment_memo={"sentinel":{"ways":1}};e.payment_groups=[["绿","黄"]]
 e.catalogue_target_fast=true;e.paid_cast_uid=fast.uid
 var before=Codec.capture(e);var memo=e.payment_memo.duplicate(true);var groups=e.payment_groups.duplicate(true)
 check(history.can_decide(e),"an opponent-only legal fast response retains the window")
 check(Codec.capture(e)==before and e.payment_memo==memo and e.payment_groups==groups,"probing both seats preserves state, priority, RNG and payment scratch data")
 fresh();put("21","grave")
 check(not history.can_decide(e),"grave ability without its payment cannot retain a window")
 var resource=put("53","palette");resource.token_colors=["红"]
 check(history.can_decide(e),"a payable grave return ability retains the window")

 # Legacy persisted snapshots have no marker; they must use current legality.
 fresh();history=Undo.new();e.phase="main";history.remember(e,"same-game",1)
 e.phase="possession";e.pending={"kind":"possession","owner":0}
 history.remember(e,"same-game",2);var exchange=Codec.capture(e)
 e.pending={};history.remember(e,"same-game",3)
 e.phase="main";history.remember(e,"same-game",4)
 for entry in history.entries:entry.erase("can_decide")
 before=Codec.capture(e)
 check(history.available(e,"same-game") and history.previous(e,"same-game").sequence==2,"legacy history skips the unplayable exchange response window")
 check(Codec.capture(e)==before,"legacy eligibility queries never restore into the live authority")
 check(history.restore_previous(e,"same-game").sequence==2 and Codec.capture(e)==exchange,"legacy recovery restores the actionable snapshot exactly")
 check(history.entries.size()==2,"legacy recovery removes all skipped future snapshots")
 check(history.restore_previous(e,"same-game").sequence==1 and not history.available(e,"same-game"),"a second undo reaches the retained initial boundary")

 # Long runs of passive transitions retain the prior decision within the bound.
 fresh();history=Undo.new();e.phase="main";history.remember(e,"long-game",100);before=Codec.capture(e)
 e.phase="draw"
 for sequence in range(101,101+Undo.LIMIT+5):
  e.revision+=1;history.remember(e,"long-game",sequence)
 check(history.entries.size()==2 and history.available(e,"long-game"),"passive transitions do not evict the last actionable state")
 check(history.previous(e,"long-game").sequence==100,"all passive transitions select the same prior decision")
 check(history.restore_previous(e,"long-game").sequence==100 and Codec.capture(e)==before,"one recovery drops the entire passive branch")
 e.phase="main"
 for sequence in range(Undo.LIMIT+5):e.revision+=1;history.remember(e,"long-game",200+sequence)
 check(history.entries.size()==Undo.LIMIT,"actionable history remains bounded")
 check(not history.available(e,"next-game") and history.restore_previous(e,"next-game").is_empty(),"game identity prevents cross-round recovery")
 for queue in ["entry_choices","damage_queue"]:
  e.set(queue,[{}])
  check(not history.settled(e) and not history.available(e,"long-game"),queue+" must finish before undo is available")
  e.set(queue,[])
 e.reveal_resolution={"cards":[]}
 check(not history.settled(e),"unfinished revealed resolution cannot split a checkpoint")
 print("UNDO CHECKPOINTS: ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
