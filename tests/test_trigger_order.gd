extends "res://tests/support/rules_base.gd"
const Gateway=preload("res://net/command_gateway.gd")
const Codec=preload("res://net/state_codec.gd")
const Remote=preload("res://net/remote_duel.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Commands=preload("res://scripts/tutorial/battle_commands.gd")
const Sequence=preload("res://scripts/tutorial/sequence.gd")
const Config=preload("res://scripts/tutorial/config.gd")
const CommandDuel=preload("res://scripts/tutorial/command_duel.gd")

class RequestSession extends RefCounted:
 var e
 var command={}
 func submit(value: Dictionary) -> String:
  command=value;return Gateway.apply(e,0,value)

func batch(who: int,count: int,targeted: bool=false) -> Array:
 var result=[]
 for i in range(count):
  var card=put("53","field",who);card.tapped=true;result.append(card.uid)
  if targeted:e.queue_trigger(who,card,i+1,"排序测试")
  else:e.triggers.append({"owner":who,"source":card.duplicate(true),"effect":"untap","name":"排序测试 "+str(i),"optional":false})
 return result

func run():
 fresh();var ids=batch(0,3);e.pump_choices()
 var before=Codec.capture(e)
 for invalid in [[],[0,0,2],[0,1],[0,1,3],[0,1,-1],[0,1,2.0],[0,1,"2"],true]:
  var reason=Gateway.apply(e,0,{"name":"choose_trigger_order","args":[invalid]})
  expect(not reason.is_empty() and Codec.capture(e)==before,"invalid permutation leaves the complete duel unchanged: "+str(invalid))
 expect(not Gateway.apply(e,1,{"name":"choose_trigger_order","args":[[1,2,0]]}).is_empty(),"opponent cannot submit another player's ordering")
 expect(Gateway.apply(e,0,{"name":"choose_trigger_order","args":[[1,2,0]]}).is_empty(),"complete order is accepted as one network command")
 expect(e.pending.is_empty() and e.stack.map(func(t):return t.source.uid)==[ids[0],ids[2],ids[1]],"top-to-bottom list matches the displayed stack order")
 var top=ids[1]
 e.pass_priority(e.priority);e.pass_priority(e.priority)
 expect(not e.find_card(top).tapped and e.find_card(ids[0]).tapped and e.find_card(ids[2]).tapped,"top row resolves first in the actual rules engine")

 fresh();ids=batch(0,3,true);e.pump_choices();e.choose_trigger_order([1,2,0])
 expect(e.pending.get("kind","")=="trigger" and e.pending.trigger.source.uid==ids[0],"bottom row selects its target before later stack entries")
 var saved=Codec.capture(e);var restored=Duel.new();Codec.restore(restored,saved);e=restored
 e.choose_trigger(e.ref_target(e.find_card(ids[1])))
 expect(e.pending.get("kind","")=="trigger" and e.pending.trigger.source.uid==ids[2],"confirmed order survives save/restore and the first target choice")
 e.choose_trigger({})
 expect(e.pending.get("kind","")=="trigger" and e.pending.trigger.source.uid==ids[1],"declining an optional trigger preserves the rest of the order")
 e.choose_trigger(e.ref_target(e.find_card(ids[0])))
 expect(e.pending.is_empty() and e.trigger_order_queue.is_empty() and e.stack.map(func(t):return t.source.uid)==[ids[0],ids[1]],"remaining triggers stack in the confirmed order without another sorting prompt")

 fresh();var duplicate_source=put("53")
 var first={"owner":0,"source":duplicate_source.duplicate(true),"amount":1,"optional":true,"name":"同一来源的重复能力"}
 var second=first.duplicate(true);e.triggers=[first,second];e.pump_choices();e.choose_trigger_order([1,0])
 expect(e.triggers.size()==1 and is_same(e.triggers[0],second),"equal-looking triggers retain distinct identities after ordering")
 e.choose_trigger({});e.choose_trigger(e.ref_target(duplicate_source))
 expect(e.pending.is_empty() and e.stack.size()==1 and e.triggers.is_empty(),"declining one identical copy still announces the other exactly once")

 fresh();var active_ids=batch(0,2);var other_ids=batch(1,2);e.pump_choices();e.choose_trigger_order([0,1])
 expect(e.pending.get("kind","")=="trigger_order" and e.pending.owner==1,"nonactive player orders after the active player's entire batch")
 e.choose_trigger_order([1,0])
 expect(e.stack.map(func(t):return t.source.uid)==[active_ids[1],active_ids[0],other_ids[0],other_ids[1]],"both players' batches preserve APNAP and their chosen internal orders")

 fresh();ids=batch(0,3);e.pump_choices()
 var remote=Remote.new();remote.apply_snapshot(SeatView.build(e,0))
 var session=RequestSession.new();session.e=e;remote.session=session
 remote.choose_trigger_order([2,0,1])
 expect(session.command.args==[[2,0,1]] and e.stack.map(func(t):return t.source.uid)==[ids[1],ids[0],ids[2]],"remote UI submits the whole permutation to authority without local rule mutation")

 fresh();ids=batch(0,2);e.pump_choices();e.choose_trigger_order(0)
 expect(e.pending.is_empty() and e.stack.map(func(t):return t.source.uid)==ids,"existing single-index AI and tutorial commands retain their behavior")
 fresh();batch(0,2,true);e.pump_choices();e.choose_trigger_order([0,1])
 var reset_deck=Store.blank("reset");reset_deck.leader="70"
 for i in range(50):reset_deck.main.append("164")
 e.start(reset_deck,reset_deck,0,1)
 expect(e.trigger_order_queue.is_empty(),"starting a new duel clears any unannounced confirmed triggers")

 var config=Config.new()
 config.sequence_action({"type":"choose_trigger_order","player":0,"order":[2,0,1]},"order")
 expect(config.errors.is_empty(),"tutorial schema accepts a complete permutation")
 config.sequence_action({"type":"choose_trigger_order","player":0,"order":[0,0]},"invalid")
 expect(not config.errors.is_empty(),"tutorial schema rejects repeated indices")
 fresh();batch(0,3);e.pump_choices()
 var adapter={"engine":e}
 var encoded=Commands.encode(adapter,0,{"name":"choose_trigger_order","args":[[2,0,1]]})
 expect(encoded.get("order")==[2,0,1] and not encoded.has("index"),"tutorial recorder preserves all dragged positions")
 var prepared=Sequence.prepare_intent(adapter,encoded,0)
 expect(prepared.available and prepared.command.args==[[2,0,1]],"tutorial playback reconstructs the same batch command")
 var command_engine=CommandDuel.new();Codec.restore(command_engine,Codec.capture(e))
 var accepted=[];command_engine.command_accepted.connect(func(_seat,command,_action):accepted.append(command))
 command_engine.choose_trigger_order([2,0,1])
 expect(accepted.size()==1 and accepted[0].args==[[2,0,1]],"tutorial engine records one accepted confirmation for the entire batch")
 print("TRIGGER_ORDER: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
