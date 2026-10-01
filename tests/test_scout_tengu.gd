extends "res://tests/support/rules_base.gd"

func choose_damage(targets: Array):
 expect(e.pending.get("kind","")=="effect_choice","scout damage chooses targets when the trigger is announced")
 var option=e.pending.options[0]
 expect(option.get("selection_id","")=="distribution" and option.selection.size()==3,"trigger offers three damage allocation steps")
 var choice={"selection_id":"distribution","picks":[]}
 for target in targets:choice.picks.append([target])
 expect(e.Pack.choice_valid(e,e.pending.options,choice),"chosen damage allocation is legal")
 e.choose_effect(choice)
 expect(e.pending.is_empty() and e.stack.size()==1,"chosen targets are stored on the stack")
 expect(e.stack[0].target.get("picks",[])==choice.picks,"stack keeps the announced allocation")

func run():
 fresh()
 var scout=put("character-fdn-038")
 var victim=put("54","field",1)
 var victim_ref=e.ref_target(victim)
 e.move_to(scout,"hand");e.pump_choices()
 choose_damage([victim_ref,victim_ref,{"player":1}])
 expect(victim.damage==0 and e.players[1].life==20,"damage waits for stack resolution")
 one()
 expect(victim.damage==2 and e.players[1].life==19,"two damage to a unit and one to a player resolve as announced")
 expect(e.pending.is_empty(),"resolution does not ask for a second allocation")

 fresh()
 scout=put("character-fdn-038")
 victim=put("54","field",1)
 victim_ref=e.ref_target(victim)
 e.move_to(scout,"hand");e.pump_choices()
 choose_damage([victim_ref,victim_ref,{"player":1}])
 e.move_to(victim,"hand")
 one()
 expect(e.players[1].life==19,"a legal target still receives its assigned damage after another target leaves")
 expect(victim.damage==0,"a target that left the battlefield receives no damage")

 fresh()
 scout=put("character-fdn-038")
 e.move_to(scout,"hand");e.pump_choices()
 choose_damage([{"player":1},{"player":1},{"player":1}])
 one()
 expect(e.players[1].life==17,"all three points may be assigned to one player")

 fresh()
 mana()
 scout=put("character-fdn-038")
 var key="character-fdn-038"
 var activation={"none":true}
 var plan=e.payment(0,e.extension_cost(0,scout,key,activation)).plan
 expect(e.commit_extension(0,scout.uid,activation,plan,key).is_empty(),"scout can activate its paid return ability")
 one()
 expect(scout.zone=="hand","paid ability returns the scout before its damage trigger")
 choose_damage([{"player":1},{"player":1},{"player":1}])
 one()
 expect(e.players[1].life==17,"paid return uses the announced damage allocation")
 print("SCOUT TENGU: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
