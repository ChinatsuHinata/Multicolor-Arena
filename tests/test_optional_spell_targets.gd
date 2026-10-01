extends "res://tests/support/rules_base.gd"

func optional_target(c: Dictionary,refs: Array) -> Dictionary:
 var spec=e.targets_for(c.card_id,0,c.uid)[0].duplicate(true)
 spec.erase("selection");spec.picks=[refs]
 return spec
func commit(c: Dictionary,target: Dictionary):
 e.debug_enabled=true;e.debug_free_payment=true
 var error=e.commit_cast(0,c.uid,target,[])
 expect(error.is_empty(),"cast "+c.card_id+" "+error)
func distribute(victim: Dictionary,total: int):
 expect(e.pending.get("kind","")=="effect_choice" and e.pending.options[0].selection.size()==total,"Path distributes the current highest friendly power")
 if e.pending.is_empty():return
 var target=e.pending.options[0].duplicate(true);target.erase("selection");target.picks=[]
 for i in range(total):target.picks.append([e.ref_target(victim)])
 e.choose_effect(target)
func run():
 fresh()
 var c=put("spell-ucs-015","hand")
 expect(e.cards[c.card_id].rules_text.begins_with("至多一个目标单位"),"Path displays its optional buff target")
 expect(e.Pack.choice_valid(e,e.targets_for(c.card_id,0,c.uid),optional_target(c,[])),"Path can choose no target on an empty battlefield")
 commit(c,optional_target(c,[]));one()
 expect(c.zone=="grave" and e.pending.is_empty(),"Path resolves without units or damage to assign")

 fresh()
 var own=put("53");var foe=put("53","field",1);foe.plus_counters=20
 var power=e.stat(own,"power");var health=e.stat(own,"health")
 c=put("spell-ucs-015","hand")
 expect(not e.Pack.choice_valid(e,e.targets_for(c.card_id,0,c.uid),optional_target(c,[e.ref_target(own),e.ref_target(foe)])),"Path rejects two buff targets")
 commit(c,optional_target(c,[]));one();distribute(foe,power)
 expect(e.stat(own,"power")==power and foe.damage==power,"skipping the buff still distributes damage without changing unit stats")

 fresh();own=put("53");foe=put("53","field",1);foe.plus_counters=20
 c=put("spell-ucs-015","hand");commit(c,optional_target(c,[e.ref_target(own)]));one()
 expect(e.stat(own,"power")==power+3 and e.stat(own,"health")==health+3,"Path grants exactly +3/+3 to the selected unit")
 distribute(foe,power+3)
 expect(foe.damage==power+3,"Path calculates damage after applying the buff")
 e.finish_turn()
 expect(e.stat(own,"power")==power and e.stat(own,"health")==health,"Path's buff expires at the end of the turn")

 fresh();own=put("53");foe=put("53","field",1);foe.plus_counters=20
 c=put("spell-ucs-015","hand");commit(c,optional_target(c,[e.ref_target(foe)]));one();distribute(foe,power)
 expect(e.stat(foe,"power")==e.cards[foe.card_id].power+23 and foe.damage==power,"Path may buff an enemy but uses only friendly power for damage")

 for protected_target in [false,true]:
  fresh();own=put("53");foe=put("53","field",1);foe.plus_counters=20
  var lost=put("53","field",1)
  c=put("spell-ucs-015","hand");commit(c,optional_target(c,[e.ref_target(lost)]))
  if protected_target:
   e.players[1].shroud_turn=e.turn
   own.modifiers=[{"血量":20}]
  else:e.move_to(lost,"grave")
  one()
  # A protected opponent's units cannot receive the later damage allocation.
  distribute(own if protected_target else foe,power)
  expect(c.zone=="grave" and (own.damage if protected_target else foe.damage)==power,"Path still distributes damage after its optional target becomes invalid: "+str(protected_target))

 fresh();put("68");foe=put("53","field",1)
 c=put("spell-mar-012","hand");put("spell-mar-012","grave")
 commit(c,optional_target(c,[e.ref_target(foe)]));e.move_to(foe,"grave");one()
 expect(e.players[0].hand.size()==2 and c.zone=="grave","Shoot the Moon still draws when its optional damage target leaves the field")

 fresh();put("59");foe=put("53","field",1)
 for i in range(10):put("53","grave")
 c=put("spell-ucs-050","hand");commit(c,optional_target(c,[e.ref_target(foe)]));e.move_to(foe,"grave");one()
 expect(e.players[0].hand.size()==2 and c.zone=="grave","Rainbow Drizzle still draws when its optional counter target leaves the field")

 fresh();foe=put("53","field",1);put("new-eto-009","grave")
 c=put("new-eto-011","hand");commit(c,optional_target(c,[e.ref_target(foe)]));e.move_to(foe,"grave");one()
 expect(e.players[0].hand.any(func(u):return u.card_id=="new-eto-012") and c.zone=="grave","Ghostly Field Club still creates its card when the optional debuff target leaves")

 fresh();mana();put("6");foe=put("53","field",1)
 c=put("spell-fdf-051","hand")
 var specs=e.targets_for(c.card_id,0,c.uid)
 var target=specs.filter(func(s):return s.selection[0].pool.has(e.ref_target(foe)))[0].duplicate(true)
 target.erase("selection");target.picks=[[e.ref_target(foe)]]
 commit(c,target);e.move_to(foe,"grave");one()
 expect(c.zone=="grave" and e.pending.is_empty() and e.stack.is_empty() and not e.log.any(func(line):return line.contains("目标失效")),"optional destruction resolves without copying when it destroyed no target")

 fresh();put("39");foe=put("53","field",1)
 c=put("spell-fdf-049","hand");commit(c,e.ref_target(foe));e.move_to(foe,"grave");one()
 expect(c.zone=="grave" and e.players[0].hand.is_empty(),"a spell requiring its target still fails rather than drawing when the target leaves")
 print("OPTIONAL_SPELL_TARGETS: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
