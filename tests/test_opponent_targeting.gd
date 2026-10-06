extends "res://tests/support/rules_base.gd"
const Picker=preload("res://scripts/target_picker.gd")
const Gateway=preload("res://net/command_gateway.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")

func board(who: int=0) -> Dictionary:
 fresh();e.active=who;e.priority=who
 for p in e.players:p.deck=[]
 var keine=put("character-fdf-ex05","field",who);keine.leader=true
 return {"keine":keine,"victim":put("53","field",who),"top":put("164","deck",1-who)}

func devour_choice(b: Dictionary) -> Dictionary:
 var picker=Picker.new()
 picker.configure(e.activation_options(b.keine,"keine_devour"),str(e.revision),false,1-b.keine.owner)
 expect(picker.select_target(e.ref_target(b.victim)),"Keine still requires choosing the sacrificed unit")
 expect(picker.ready() and picker.available().is_empty(),"Keine completes without selecting or confirming the opponent group")
 expect(e.Pack.choice_valid(e,e.activation_options(b.keine,"keine_devour"),picker.option()),"automatic opponent forms a legal authoritative declaration")
 return picker.option()

func picker_choices():
 fresh()
 var picker=Picker.new()
 picker.configure([{"player":1}],"sole",false,1)
 expect(picker.ready() and picker.option()=={"player":1} and picker.available_refs().is_empty(),"sole opponent is automatic and retains its target reference")
 expect(not picker.can_reselect(),"automatic opponent has no redundant reset")
 picker.configure([{"player":0},{"player":1}],"players",false,1)
 expect(not picker.ready() and picker.available_refs().size()==2,"choosing either player remains manual")
 picker.select_target({"player":1})
 expect(picker.has_manual_targets() and picker.available_refs().size()==2 and picker.can_reselect(),"manually choosing the opponent preserves player reselection")
 expect(picker.select_target({"player":0}) and picker.option()=={"player":0},"manual opponent selection can be changed to yourself")
 picker.configure(e.Pack.selection([e.Pack.group([{"player":1}],0,1,"可选玩家")],"optional"),"optional",false,1)
 expect(not picker.ready() and picker.available_refs()==[{"player":1}],"optional opponent can still be skipped")
 picker.configure([{"player":1,"mode":"失去生命"},{"player":1,"mode":"牺牲单位"}],"modes",false,1)
 expect(not picker.ready() and picker.available().size()==2,"mode choice remains manual")
 picker.select(picker.available()[0])
 expect(picker.ready() and picker.option().player==1 and picker.available_refs().is_empty(),"opponent is automatic after selecting a mode")
 var unit=put("53")
 picker.configure([e.ref_target(unit)],"unit",false,1)
 expect(not picker.ready() and picker.available_refs()==[e.ref_target(unit)],"sole unit target remains manual")
 var groups=[e.Pack.group([{"player":1}],1,1,"目标对手"),e.Pack.group([e.ref_target(unit)],1,1,"单位")]
 picker.configure(e.Pack.selection(groups,"grouped"),"grouped",false,1)
 expect(picker.available_refs()==[e.ref_target(unit)],"automatic first group advances directly to the unit")
 picker.select_target(e.ref_target(unit))
 expect(picker.option().picks==[[{"player":1}],[e.ref_target(unit)]],"grouped declaration preserves both targets")
 picker.path=[];picker.normalize()
 expect(picker.available_refs()==[e.ref_target(unit)] and not picker.can_reselect(),"reset restores the automatic opponent")
 picker.configure([{"player":1}],"manual")
 expect(not picker.ready(),"picker without a two-player opponent context stays manual")

func keine_rules():
 for who in [0,1]:
  var b=board(who);var target=devour_choice(b)
  expect(e.commit_extension(who,b.keine.uid,target,[],"keine_devour").is_empty(),"Keine activation succeeds from seat "+str(who))
  expect(b.victim.zone=="grave" and e.Pack.declared_targets(e.stack.back())==[{"player":1-who}],"sacrifice is a cost and only the opponent is a target")
  one()
  expect(b.top.zone=="exile" and b.top.get("devour_owner",-1)==who,"Keine exiles the targeted player's top card and records its devour counter owner")

  b=board(who);target=devour_choice(b)
  put("character-ucs-046","field",1-who)
  var before=JSON.stringify([e.players,e.stack,e.pending,e.revision])
  expect(e.activation_options(b.keine,"keine_devour").is_empty() and e.extension_activation_error(who,b.keine,"keine_devour")=="没有合法目标","Nitori disables Keine before sacrifice")
  expect(not Gateway.apply(e,who,{"name":"commit_extension","args":[b.keine.uid,target,[],"keine_devour"]}).is_empty(),"authority rejects an opponent declaration made before Nitori entered")
  expect(JSON.stringify([e.players,e.stack,e.pending,e.revision])==before and b.victim.zone=="field","blocked activation spends no cost and changes no state")
  var remote=Remote.new();remote.seat=who;remote.apply_snapshot(SeatView.build(e,who))
  expect(remote.activation_options(remote.find_card(b.keine.uid),"keine_devour").is_empty(),"remote seat receives no legal Keine target under Nitori")

  b=board(who);target=devour_choice(b)
  expect(e.commit_extension(who,b.keine.uid,target,[],"keine_devour").is_empty(),"Keine can be announced before protection enters")
  put("character-ucs-046","field",1-who);one()
  expect(b.top.zone=="deck" and b.victim.zone=="grave","protection gained in response prevents devour while retaining the paid sacrifice")

  b=board(who);target=devour_choice(b)
  var snapshot=SeatView.build(e,who);remote=Remote.new();remote.seat=who;remote.apply_snapshot(snapshot)
  var options=remote.activation_options(remote.find_card(b.keine.uid),"keine_devour")
  expect(e.Pack.choice_valid(e,options,target),"remote declaration includes the mandatory opponent group")
  expect(Gateway.apply(e,who,{"name":"commit_extension","args":[b.keine.uid,target,[],"keine_devour"]}).is_empty(),"remote Keine activation commits the automatic opponent")
  one();expect(b.top.zone=="exile","remote activation resolves devour")

  b=board(who);target=devour_choice(b);target.picks[1]=[{"player":who}]
  before=JSON.stringify([e.players,e.stack,e.pending,e.revision])
  expect(not e.commit_extension(who,b.keine.uid,target,[],"keine_devour").is_empty(),"Keine cannot forge a self target")
  expect(JSON.stringify([e.players,e.stack,e.pending,e.revision])==before,"forged player target does not sacrifice a unit")

  b=board(who);b.keine.leader=false
  var self_cost={"selection_id":"keine_devour","picks":[[e.ref_target(b.keine)],[{"player":1-who}]]}
  expect(e.commit_extension(who,b.keine.uid,self_cost,[],"keine_devour").is_empty(),"Keine can pay by sacrificing itself")
  one();expect(b.top.zone=="exile" and b.keine.zone=="grave","devour survives its own source leaving as a cost")

func backpack_rules():
 for pay in [false,true]:
  var b=board();put("item-ucs-012","field",1);var resource=put("167","palette")
  var target=devour_choice(b)
  expect(e.commit_extension(0,b.keine.uid,target,[],"keine_devour").is_empty(),"Keine announces against a backpack")
  expect(b.victim.zone=="grave" and e.stack.size()==2 and e.stack.back().effect=="backpack_tax","automatic opponent triggers exactly one backpack ability after sacrifice")
  one()
  expect(e.pending.get("trigger",{}).get("effect","")=="backpack_pay","backpack offers payment on resolution")
  e.choose_effect(e.pending.options.filter(func(option):return option.has("color") if pay else not option.has("color"))[0])
  if pay:
   expect(resource.tapped and e.stack.size()==1,"paying one blue resource keeps the original ability")
   one();expect(b.top.zone=="exile","paid backpack lets Keine devour")
  else:expect(not resource.tapped and e.stack.is_empty() and b.top.zone=="deck","declining backpack counters devour without refunding sacrifice")
 var b=board();put("item-ucs-012","field",1);put("165","palette")
 e.commit_extension(0,b.keine.uid,devour_choice(b),[],"keine_devour");one()
 expect(e.pending.options.any(func(option):return option.get("color","")=="红"),"backpack retains its printed any-color payment")

func triggered_opponents():
 fresh();var source=enter("14")
 expect(e.pending.is_empty() and e.stack.back().target=={"player":1},"mandatory enter-drain automatically targets the opponent")
 one();expect(e.players[1].life==19,"automatic enter-drain resolves")
 fresh();put("character-ucs-046","field",1);source=enter("14")
 expect(e.pending.is_empty() and e.stack.back().get("no_legal_targets",false),"Nitori blocks enter-drain without asking for an impossible target")
 one();expect(e.players[1].life==20,"blocked enter-drain changes no life")
 fresh();put("item-ucs-012","field",1);source=enter("14")
 expect(e.pending.is_empty() and e.stack.size()==2 and e.stack.back().effect=="backpack_tax","automatic enter-drain triggers backpack")
 fresh();source=enter("14");put("character-ucs-046","field",1);one()
 expect(e.players[1].life==20,"enter-drain rechecks player protection on resolution")
 fresh();source=put("49");e.Extra.on_enter(e,source);e.pump_choices()
 var picker=Picker.new();picker.configure(e.pending.options,"optional-enter",false,1)
 expect(e.pending.trigger.optional and picker.ready(),"optional targeted trigger retains its use/decline choice without target clicks")
 e.choose_effect({});expect(e.stack.is_empty(),"declining the optional ability does not announce its target")
 fresh();source=put("49");put("character-ucs-046","field",1);e.Extra.on_enter(e,source);e.pump_choices()
 expect(e.pending.is_empty() and e.stack.back().get("no_legal_targets",false),"protected opponent does not offer an impossible optional activation")
 fresh();source=put("49");var palette=put("164","palette",1);e.Extra.on_enter(e,source);e.pump_choices();e.choose_effect({"player":1})
 put("character-ucs-046","field",1);one()
 expect(e.pending.is_empty() and palette.zone=="palette","protection gained in response cancels a target-only palette trigger safely")
 fresh();var hand=put("164","hand",1);source=enter("character-ucs-036")
 expect(e.pending.is_empty() and e.stack.back().target=={"player":1},"random-discard entry automatically targets the opponent")
 put("character-ucs-046","field",1);one()
 expect(hand.zone=="hand","random discard rechecks player protection without an invalid-player error")
 fresh();source=put("42");e.move_to(source,"grave");e.pump_choices()
 expect(e.pending.is_empty() and e.stack.back().target=={"player":1},"Seiga's death trigger automatically declares the opponent")
 one();expect(e.players[0].life==18,"Seiga resolves safely when the opponent has no unit")
 fresh();source=put("character-ucs-056");e.Cat.Units.on_phase(e,"end");e.pump_choices()
 expect(e.pending.trigger.optional and e.pending.options==[{"player":1}],"Momiji retains the option to choose zero opponents")
 e.choose_effect({});expect(e.stack.is_empty() and e.players[1].get("tengu_watches",[]).is_empty(),"declining Momiji creates no watch on the opponent")

func run():
 picker_choices();keine_rules();backpack_rules();triggered_opponents()
 print("OPPONENT_TARGETING: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
