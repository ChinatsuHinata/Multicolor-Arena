extends "res://tests/support/rules_base.gd"

func run():
 fresh()
 var attacker=put("67")
 var blocker=put("70","field",1)
 var spell=put("112","hand",1)
 put("165","palette",1)

 e.attack(0,attacker.uid)
 one()
 e.block([blocker.uid])
 one()
 expect(e.combat.get("step","")=="first_damage_window" and e.combat.get("strike_round","")=="first","first-strike damage opens its own response window")
 expect(blocker.zone=="field" and blocker.damage==3 and attacker.zone=="field" and attacker.damage==0,"ordinary blocker has not retaliated after first-strike damage")
 expect(e.priority==0 and e.passes==0,"active player receives priority at the first-strike response window")

 e.pass_priority(0)
 expect(e.priority==1 and e.combat.get("step","")=="first_damage_window" and e.has_response(1),"defender can respond before ordinary damage")
 var error=e.commit_cast(1,spell.uid,e.ref_target(blocker),e.payment(1,e.cast_cost(1,spell)).plan)
 expect(error.is_empty() and e.stack.size()==1 and e.combat.get("step","")=="first_damage_window","fast spell enters the stack during the first-strike window")
 one()
 expect(e.stack.is_empty() and e.stat(blocker,"power")==5 and attacker.damage==0 and e.combat.get("step","")=="first_damage_window","response resolves before retaliation")

 one()
 expect(attacker.zone=="grave" and blocker.zone=="field" and e.combat.get("step","")=="damage_window","ordinary blocker retaliates only after both players pass again")
 expect(blocker.damage==3,"first-strike attacker does not deal damage twice")

 print("FIRST_STRIKE_RESPONSE: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
