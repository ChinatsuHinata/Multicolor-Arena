extends "res://tests/support/rules_base.gd"
const Registry=preload("res://scripts/rules/mod_registry.gd")
const Codec=preload("res://net/state_codec.gd")
const Gateway=preload("res://net/command_gateway.gd")

func setup():
 fresh();var leader=put("testmod/byakuren");leader.leader=true
 put("164","palette");put("166","palette");put("166","palette")

func stacked(id: String,who: int=1,x: int=0) -> Dictionary:
 var card=e.make_card(id,who,"stack");card.cast_x=x
 e.stack.append({"id":e.next_stack,"kind":"card","owner":who,"card":card,"target":{"player":0,"x":x},"name":e.cards[id].name});e.next_stack+=1
 return card

func declare(x: int=2) -> Dictionary:
 var spell=put("spell-fdf-053","hand")
 var spec=e.targets_for(spell.card_id,0,spell.uid).filter(func(o):return o.x==x and o.counter_payment==0)[0].duplicate(true)
 expect(spec.selection.is_empty(),"purple cloud declares X and payment without a counter target")
 spec.erase("selection");spec.picks=[]
 var plan=e.payment(0,e.cast_cost(0,spell,spec)).plan
 expect(plan.size()==x+1,"initial payment uses declared X, before doubling")
 expect(e.commit_cast(0,spell.uid,spec,plan).is_empty(),"purple cloud casts with no matching spell required")
 return spell

func choose_double(yes: bool):
 expect(e.pending.get("trigger",{}).get("mod_replace",false),"Byakuren offers the optional first-X choice after payment")
 var answer=e.pending.options.filter(func(o):return bool(o.get("decline",false))!=yes)[0]
 e.choose_effect(answer)

func run():
 Registry._shared=Registry.new();expect(Registry.shared().register_pack("res://examples/testmod").is_empty(),"register corrected testmod")
 Store.CARDS=DB.load_cards()
 for double_x in [false,true]:
  setup();var two=stacked("testmod/recitation",1,1);var four=stacked("testmod/recitation",1,3)
  var unit=stacked("testmod/byakuren");var item=stacked("testmod/fuel")
  var spell=declare();choose_double(double_x)
  var x=4 if double_x else 2
  expect(spell.cast_x==x and e.players[0].palette.all(func(c):return c.tapped),"doubling changes resolved X while retaining the original three-resource payment")
  one()
  var selected=four if double_x else two;var other=two if double_x else four
  expect(e.pending.get("trigger",{}).get("effect","")=="counter_resolution" and e.pending.options.size()==1,"purple cloud selects a spell only at resolution")
  expect(e.pending.options==[{"stack_id":e.stack.filter(func(s):return s.card.uid==selected.uid)[0].id}],"resolution uses the chosen final X and excludes units/items")
  var saved=Codec.capture(e);var restored=Duel.new();expect(Codec.restore(restored,saved).is_empty(),"resolution target choice saves and restores")
  var answer=e.pending.options[0].duplicate(true)
  expect(not Gateway.apply(e,1,{"name":"choose_effect","args":[answer]}).is_empty(),"opponent cannot choose the countered spell")
  expect(not Gateway.apply(e,0,{"name":"choose_effect","args":[{"stack_id":99999}]}).is_empty(),"forged counter choice is rejected")
  e.choose_effect(answer)
  expect(selected.zone=="grave" and other.zone=="stack" and unit.zone=="stack" and item.zone=="stack" and spell.zone=="grave","only the chosen matching spell is countered")
  var final_state=Codec.capture(e);restored.choose_effect(answer)
  expect(Codec.capture(restored)==final_state,"restored resolution makes the same counter exactly once")
 setup();var spell=declare();choose_double(true);one()
 expect(spell.zone=="grave" and e.pending.is_empty() and e.stack.is_empty(),"no spell with the final X means no effect")
 setup();var original=stacked("testmod/recitation",1,1);spell=declare();choose_double(true);one()
 expect(original.zone=="stack" and spell.zone=="grave" and e.pending.is_empty(),"doubling does not fall back to a spell matching the paid X")
 setup();spell=declare();choose_double(false)
 e.debug_enabled=true;e.debug_free_payment=true;e.catalogue_x_override=2;e.priority=0
 var next=put("spell-fdf-053","hand")
 var next_choice=e.targets_for(next.card_id,0,next.uid).filter(func(o):return o.x==1 and o.counter_payment==0)[0].duplicate(true)
 next_choice.erase("selection");next_choice.picks=[]
 expect(e.commit_cast(0,next.uid,next_choice,[]).is_empty(),"second X card casts")
 expect(next.cast_x==1 and e.pending.is_empty(),"declining still consumes the turn's first-X opportunity")
 setup();e.active=1;spell=declare()
 expect(spell.cast_x==2 and e.pending.is_empty(),"Byakuren does not double X during the opponent's turn")
 print("PURPLE_CLOUD: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
