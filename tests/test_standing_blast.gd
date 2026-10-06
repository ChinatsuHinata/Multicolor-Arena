extends "res://tests/support/rules_base.gd"

func run():
 for state in ["never_tapped","tapped_now","untapped_again","previous_turn","tapped_in_response"]:
  fresh()
  e.cards["53"]=e.cards["53"].duplicate(true);e.cards["53"].health=10
  var barrier=put("field-rei-004")
  var target=put("53","field",1)
  if state in ["tapped_now","untapped_again"]:e.tap_card(target)
  if state=="untapped_again":target.tapped=false
  if state=="previous_turn":target.tapped=true;target.tapped_turn=e.turn-1
  var before=target.damage
  var option=e.ref_target(target)
  expect(option in e.activation_options(barrier,"standing_blast"),state+" is a legal target")
  expect(e.commit_extension(0,barrier.uid,option,[],"standing_blast").is_empty(),state+" can be announced without a tap restriction")
  expect(barrier.zone=="grave" and e.stack.size()==1,state+" pays the sacrifice and queues the ability")
  if state=="tapped_in_response":e.tap_card(target)
  one()
  var harmful=state in ["tapped_now","untapped_again","tapped_in_response"]
  expect(target.damage-before==(4 if harmful else 0),state+" checks this turn's tap history at resolution")
 # The Reimu bonus remains available even when the untapped target takes no damage.
 fresh()
 var barrier=put("field-rei-004")
 put("70")
 var target=put("53","field",1)
 var resource=put("164","palette")
 expect(e.commit_extension(0,barrier.uid,e.ref_target(target),[],"standing_blast").is_empty(),"Reimu can activate against an untapped unit")
 one()
 expect(target.damage==0 and e.pending.get("trigger",{}).get("effect","")=="standing_palette","an untapped unit still permits Reimu's palette choice")
 var choice={"selection_id":"standing","picks":[[e.Pack.ref(e,resource)]]}
 e.choose_effect(choice);one()
 expect(resource.zone=="hand","Reimu returns the chosen palette card to hand")
 print("STANDING BLAST: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
