extends "res://tests/support/rules_base.gd"

const Gateway=preload("res://net/command_gateway.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const Observer=preload("res://net/observer_projection.gd")
const Codec=preload("res://net/state_codec.gd")
class RecordingSession:
 extends RefCounted
 var command={}
 func submit(value: Dictionary) -> String:
  command=value;return ""

func run():
 fresh()
 var ran=put("24");var spell=put("167","hand")
 var blue=put("167","palette")
 expect(e.cast_cost(0,spell).get("蓝",0)==1 and e.cast_error(0,spell.uid).is_empty(),"Ran starts enabled and reduces actual cast cost")
 var stale=e.payment(0,e.cast_cost(0,spell)).plan
 var action=e.available_actions(0,ran.uid).filter(func(a):return a.type=="ran_discount")
 expect(action.size()==1 and action[0].label.contains("关闭"),"own Ran offers the disable action")
 var priority=e.priority;var passes=e.passes;var revision=e.revision
 expect(Gateway.apply(e,0,{"name":"toggle_ran_discount","args":[ran.uid]}).is_empty(),"gateway accepts the owner's toggle")
 expect(e.cast_cost(0,spell).get("蓝",0)==2 and not e.cast_error(0,spell.uid).is_empty(),"disabled discount updates cast affordability immediately")
 expect(not e.payment_valid(0,e.cast_cost(0,spell),stale),"old discounted payment becomes invalid")
 expect(e.stack.is_empty() and not ran.tapped and not blue.tapped and e.priority==priority and e.passes==passes and e.revision>revision,"toggle consumes no resources and does not enter the stack or pass priority")
 var saved=Codec.capture(e)
 var restored=Duel.new();Codec.restore(restored,saved)
 expect(restored.find_card(ran.uid).get("ran_discount_disabled",false) and restored.cast_cost(0,restored.find_card(spell.uid)).get("蓝",0)==2,"saved state restores the disabled cost")
 for seat in [0,1]:
  var projection=SeatView.build(e,seat)
  expect(projection.state.players[0].field.any(func(c):return c.uid==ran.uid and c.get("ran_discount_disabled",false)),"seat "+str(seat)+" sees the disabled state")
  if seat==0:expect(projection.queries.actions[ran.uid].any(func(a):return a.type=="ran_discount" and a.label.contains("开启")),"projection offers the enable action")
 expect(Observer.build(e).state.players[0].field.any(func(c):return c.uid==ran.uid and c.get("ran_discount_disabled",false)),"spectator sees the disabled state")
 var remote=Remote.new();remote.seat=0;remote.apply_snapshot(SeatView.build(e,0));remote.session=RecordingSession.new()
 expect(remote.cast_cost(0,remote.find_card(spell.uid)).get("蓝",0)==2,"remote cost calculation respects disabled state")
 remote.toggle_ran_discount(0,ran.uid)
 expect(remote.session.command.name=="toggle_ran_discount" and remote.session.command.args==[ran.uid] and remote.find_card(ran.uid).get("ran_discount_disabled",false),"remote toggle sends a request without mutating local state")
 expect(not Gateway.apply(e,1,{"name":"toggle_ran_discount","args":[ran.uid]}).is_empty(),"opponent cannot switch your Ran")
 expect(not Gateway.apply(e,0,{"name":"toggle_ran_discount","args":[str(ran.uid)]}).is_empty(),"gateway rejects malformed toggle")
 ran.tapped=true;ran.entered_turns=e.players[0].turns
 expect(e.toggle_ran_discount(0,ran.uid).is_empty() and e.cast_cost(0,spell).get("蓝",0)==1,"tapped and newly entered Ran can re-enable the static discount")
 expect(e.commit_cast(0,spell.uid,{},stale).is_empty() and spell.zone=="stack" and blue.tapped,"re-enabled discount pays the actual cast")
 fresh();ran=put("24");var second=put("24");spell=put("167","hand")
 put("24","field",1)
 expect(e.cast_cost(0,spell).get("蓝",0)==0,"two enabled copies stack without going below zero")
 e.toggle_ran_discount(0,ran.uid)
 expect(e.cast_cost(0,spell).get("蓝",0)==1 and not second.get("ran_discount_disabled",false),"each copy has an independent switch")
 e.toggle_ran_discount(0,second.uid)
 expect(e.cast_cost(0,spell).get("蓝",0)==2,"opponent's Ran does not reduce your costs")
 e.move_to(ran,"hand")
 expect(not ran.has("ran_discount_disabled") and not e.toggle_ran_discount(0,ran.uid).is_empty(),"leaving clears the switch and prevents off-field toggles")
 e.detach(ran);e.shift(ran,"field");e.players[0].field.append(ran)
 expect(e.cast_cost(0,spell).get("蓝",0)==1,"returning Ran starts enabled")
 expect(e.cast_cost(0,put("54","hand")).get("黄",0)==4,"switch does not alter non-blue cost")
 e.pending={"kind":"block","owner":0}
 expect(not e.toggle_ran_discount(0,ran.uid).is_empty(),"pending choices prevent toggling")
 e.pending={};e.priority=1
 expect(not e.toggle_ran_discount(0,ran.uid).is_empty(),"toggle requires priority")
 var enemy=e.players[1].field[0]
 expect(Gateway.apply(e,1,{"name":"toggle_ran_discount","args":[enemy.uid]}).is_empty() and enemy.get("ran_discount_disabled",false),"second seat can switch its own Ran")
 e.priority=0;e.winner=0
 expect(not e.toggle_ran_discount(0,ran.uid).is_empty(),"finished game prevents toggling")
 print("RAN_DISCOUNT: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
