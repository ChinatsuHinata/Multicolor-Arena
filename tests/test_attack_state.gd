extends "res://tests/support/rules_base.gd"

func run():
 fresh()
 var duelist=put("53")
 var opponent=put("53","field",1)
 put("64","field",1)
 var cloud=put("178","hand",1)
 var umbrella=put("59","hand",1)
 put("165","palette",1);put("167","palette",1)
 duelist.attacked=true # Earlier attacks this turn do not make a later duel an attack.
 e.Cat.forced_battle(e,e.ref_target(duelist),e.ref_target(opponent))
 e.pump_choices();e.priority=1
 expect(e.combat.get("forced",false) and e.attacking_unit_ref().is_empty(),"forced duel has no declared attacker")
 expect(e.targets_for("178",1).is_empty() and "没有合法目标" in e.cast_error(1,cloud.uid),"Black Cloud cannot target a duelist")
 expect(not e.Roster.target_survives(e,"178",e.ref_target(duelist)),"Black Cloud rejects a surviving duelist at resolution")
 expect(not e.Roster.fast(e,umbrella,1) and "只能在自己主要阶段" in e.cast_error(1,umbrella.uid),"Kogasa cannot enter at attack speed during a duel")
 expect(not e.commit_cast(1,cloud.uid,e.ref_target(duelist),[]).is_empty() and duelist.zone=="field","illegal Black Cloud does not destroy a duelist")

 fresh()
 var attacker=put("53")
 put("64","field",1)
 cloud=put("178","hand",1)
 umbrella=put("59","hand",1)
 put("165","palette",1);put("167","palette",1)
 e.attack(0,attacker.uid)
 expect(e.is_attacking_unit(e.ref_target(attacker)) and e.targets_for("178",1).has(e.ref_target(attacker)),"declared attack provides Black Cloud's target")
 expect(e.Roster.fast(e,umbrella,1) and e.cast_error(1,umbrella.uid).is_empty(),"Kogasa can enter during an opponent's declared attack")
 var target=e.ref_target(attacker)
 var error=e.commit_cast(1,cloud.uid,target,[])
 expect(error.is_empty(),"Black Cloud can be cast against the declared attacker: "+error)
 if error.is_empty():
  one()
  expect(attacker.zone=="grave" and cloud.zone=="grave","Black Cloud destroys the declared attacker")
  expect(not e.Roster.target_survives(e,"178",target),"Black Cloud target stops being an attacker after destruction")

 fresh()
 attacker=put("53")
 e.attack(0,attacker.uid)
 target=e.ref_target(attacker)
 e.end_combat()
 expect(attacker.zone=="field" and not e.Roster.target_survives(e,"178",target),"Black Cloud cannot destroy a unit after its attack ends")

 print("ATTACK_STATE: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
