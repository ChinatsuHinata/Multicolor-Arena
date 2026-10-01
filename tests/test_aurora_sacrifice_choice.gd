extends "res://tests/support/rules_base.gd"

func cast_sacrifice():
 e.debug_enabled=true; e.debug_free_payment=true
 var spell=put("143","hand")
 var error=e.commit_cast(0,spell.uid,{"player":1,"mode":"牺牲单位"},[])
 expect(error.is_empty(),"Aurora sacrifice mode can be cast: "+error)
 expect(e.stack.size()==1 and e.priority==1,"opponent can respond to Aurora before it resolves")
 e.pass_priority(1)
 expect(e.stack.size()==1 and e.priority==0,"Aurora remains on the stack after one pass")
 e.pass_priority(0)

func run():
 fresh()
 var victim=put("53","field",1)
 cast_sacrifice()
 expect(e.stack.is_empty() and e.pending.get("kind","")=="effect_choice" and e.pending.owner==1,"resolving Aurora asks its target player to choose a sacrifice without another stack object")
 e.choose_effect(e.ref_target(victim))
 expect(victim.zone=="grave" and e.pending.is_empty() and e.stack.is_empty(),"chosen unit is sacrificed immediately")
 expect(e.priority==0 and e.passes==0,"no response window opens after the sacrifice choice")

 fresh()
 cast_sacrifice()
 expect(e.pending.is_empty() and e.stack.is_empty() and e.priority==0,"Aurora with no opposing units finishes without a choice or response window")

 fresh()
 victim=put("64","field",1)
 cast_sacrifice()
 e.choose_effect(e.ref_target(victim))
 expect(victim.zone=="grave","sacrifice occurs before any death related trigger")
 expect(e.stack.size()==1 and e.stack[0].get("effect","")=="leave_ufo","the sacrificed unit's leave trigger still enters the stack")
 print("AURORA_SACRIFICE_CHOICE: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
