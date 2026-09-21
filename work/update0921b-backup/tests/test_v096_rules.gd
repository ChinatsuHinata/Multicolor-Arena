extends "res://tests/test_v09_rules.gd"
func colors(plan: Array) -> Array: return plan.map(func(p): return p.color)
func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 fresh(); var cost=e.cards["soi_unit_086"].cost
 expect(cost.size()==2 and cost.get("红/蓝/绿")==3 and cost.get("黑")==1 and e.cards["soi_unit_086"].colors==["红","蓝","绿","黑"],"Nue has shared RGB cost and four palette colors")
 for combo in [["165","165","165"],["167","167","167"],["166","166","166"],["165","167","166"],["165","165","166"]]:
  fresh(); put("168","palette")
  for id in combo: put(id,"palette")
  var solution=e.payment(0,cost)
  expect(solution.ways==1 and solution.plan.size()==4 and e.payment_valid(0,cost,solution.plan),"hybrid payment accepts "+str(combo))
 fresh(); put("168","palette"); put("165","palette"); put("165","palette"); put("164","palette")
 expect(e.payment(0,cost).ways==0,"yellow cannot pay RGB cost")
 fresh(); var black=put("168","palette"); var red=put("165","palette"); var blue=put("167","palette"); var green=put("166","palette")
 var plan=e.payment(0,cost).plan
 expect(not e.payment_valid(0,cost,plan+[plan[0]]),"overpayment and duplicate resources rejected")
 expect(e.ColorCost.allows(cost,[{"uid":black.uid,"color":"黑"}],"绿") and not e.ColorCost.allows(cost,[{"uid":black.uid,"color":"黑"}],"黑"),"manual selection shares RGB pool and caps black")
 expect(not e.payment_valid(0,cost,[{"uid":red.uid,"color":"红"},{"uid":blue.uid,"color":"蓝"},{"uid":green.uid,"color":"绿"}]),"three flexible points do not replace the required black")
 fresh(); var nue=put("soi_unit_086","palette")
 for color in ["红","蓝","绿","黑"]: expect(e.payment(0,{color:1}).ways>0,"Nue palette produces "+color)
 expect(e.payment(0,{"黄":1}).ways==0,"Nue does not produce yellow")
 # Both sources compute one damage batch before any death or exile.
 fresh(); var a=put("54"); a.modifiers=[{"先制":true}]; var b=[]
 for i in range(3): b.append(put("53","field",1))
 e.attack(0,a.uid); one(); e.block(b.map(func(c): return c.uid)); one()
 expect(e.pending.get("kind")=="damage_assignment","first-strike multi-block opens assignment")
 var allocation={str(b[0].uid):2,str(b[1].uid):2,str(b[2].uid):1}
 e.combat_damage(allocation)
 expect(b[0].zone=="grave" and b[1].zone=="grave" and b[2].zone=="field" and a.damage==0,"first strike removes every lethal blocker before retaliation")
 expect(e.combat.damage_snapshot[b[0].uid].damage==2 and e.combat.damage_snapshot[b[1].uid].damage==2,"damage snapshot includes all simultaneous casualties")
 var batch=e.combat.damage_batch; var hp=b[2].damage
 e.combat_damage(allocation)
 expect(e.combat.damage_batch==batch and b[2].damage==hp,"duplicate damage submit cannot repeat first strike")
 one()
 expect(a.damage==2 and b[2].damage==1 and e.combat.damage_batch>batch,"surviving normal blocker deals damage only in second batch")
 one(); expect(e.combat.is_empty(),"first-strike combat fully completes")
 fresh(); a=put("53"); var first=put("54","field",1); first.modifiers=[{"先制":true}]
 e.attack(0,a.uid); one(); e.block([first.uid]); one()
 expect(a.zone=="grave" and first.damage==0 and e.combat.damage_snapshot[a.uid].display_stats.health==-3,"defensive first strike preserves negative lethal health snapshot")
 one(); expect(e.combat.is_empty() and first.damage==0,"dead attacker never retaliates")
 fresh(); a=put("53"); first=put("53","field",1); a.modifiers=[{"先制":true}]; first.modifiers=[{"先制":true}]
 e.attack(0,a.uid); one(); e.block([first.uid]); one()
 expect(a.zone=="grave" and first.zone=="grave","two first strikers deal simultaneous lethal damage")
 # Okuu presence must not block passing, casting from deck, or later cleanup.
 fresh(); mana(); var okuu=put("78"); var hell=put("162","deck")
 expect(e.legal_casts(0).any(func(c): return c.uid==hell.uid),"Okuu unlocks its role spell in deck")
 var error=e.commit_cast(0,hell.uid,{"player":1},e.payment(0,e.cast_cost(0,hell)).plan); one()
 expect(error.is_empty() and hell.zone=="grave" and e.players[1].life==17,"deck spell resolves normally with Okuu present")
 e.priority=0; one(); expect(e.phase=="end","Okuu does not prevent ending main phase")
 fresh(); okuu=put("78"); var foe=put("54","field",1); e.move_to(okuu,"grave"); e.pump_choices(); settle()
 expect(foe.zone=="grave" and e.pending.is_empty() and e.stack.is_empty(),"Okuu death sweep finishes and does not trap priority")
 # Debug moving to deck always places the physical card on top, without events.
 fresh(); e.debug_enabled=true; a=put("53","hand"); var old_top=e.players[0].deck[0]
 expect(e.debug_move(a.uid,"deck").is_empty() and e.players[0].deck[0].uid==a.uid,"hand-to-deck debug move places card on top")
 e.debug_move(old_top.uid,"deck")
 expect(e.players[0].deck[0].uid==old_top.uid,"deck-to-deck debug move reorders to top")
 e.debug_move(a.uid,"field"); e.debug_move(a.uid,"deck")
 expect(e.players[0].deck[0].uid==a.uid and e.stack.is_empty() and e.triggers.is_empty(),"field-to-deck silent move stays on top")
 expect(not e.debug_move(a.uid,"leader").is_empty(),"ordinary card cannot enter leader zone")
 for id in DB.IDS: expect(ResourceLoader.exists(e.cards[id].image),"current moved image linked: "+id)
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"saved decks unchanged")
 var report="%d checks; %d failures\n%s" % [checks,failures.size(),"\n".join(failures)]
 FileAccess.open("res://work/v096-rules-tests.txt",FileAccess.WRITE).store_string(report)
 print("V096_RULES: "+report); quit(0 if failures.is_empty() else 1)
