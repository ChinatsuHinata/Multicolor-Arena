extends "res://tests/support/rules_base.gd"
const Spells=preload("res://scripts/rules/catalogue_spells.gd")

func sweep(who: int,first: bool,with_yachie: bool):
 fresh()
 var blocker={}
 if first and with_yachie:blocker=put("character-ucs-066","field",who)
 var victim=put("5","field",who)
 if not first and with_yachie:blocker=put("character-ucs-066","field",who)
 var spell=put("spell-fdf-085","hand",0)
 Spells.resolve(e,{"card":spell,"owner":0,"target":{}})
 expect(victim.zone=="grave","sweep kills death trigger unit")
 if with_yachie:
  expect(blocker.zone=="grave","sweep kills Yachie")
  expect(e.triggers.is_empty(),"Yachie suppresses same batch regardless of order and side")
 else:expect(not e.triggers.is_empty(),"ordinary simultaneous death still triggers")
 expect(e.death_observers.is_empty(),"snapshot restored after batch")

func damage_sweep():
 fresh()
 var blocker=put("character-ucs-066")
 var victim=put("5","field",1)
 blocker.damage=99;victim.damage=99;e.judge()
 expect(blocker.zone=="grave" and victim.zone=="grave" and e.triggers.is_empty(),"simultaneous lethal damage suppresses death trigger")

func later_death():
 fresh()
 var blocker=put("character-ucs-066")
 e.destroy(blocker)
 var victim=put("5","field",1);e.destroy(victim)
 expect(not e.triggers.is_empty(),"death in a later event is not suppressed")

func complex_sweep():
 fresh()
 var blocker=put("character-ucs-066")
 var victim=put("5","field",1)
 var spell=put("spell-fdf-060","hand")
 Spells.resolve_complex(e,{"card":spell,"owner":0,"target":{}})
 expect(blocker.zone=="grave" and victim.zone=="grave" and e.triggers.is_empty(),"return-from-grave sweep suppresses concurrent death trigger")

func leader_return():
 fresh()
 var blocker=put("character-ucs-066")
 var leader=put("71","field",1);leader.leader=true
 e.destroy_batch([blocker,leader]);e.pump_choices()
 expect(e.pending.get("kind","")=="leader_return","leader death waits for return choice")
 if e.pending.get("kind","")=="leader_return":e.choose_return(false)
 expect(e.triggers.is_empty() and not e.stack.any(func(t):return t.get("effect","")=="leader_death_damage"),"delayed leader death retains suppressor snapshot")

func run():
 for who in [0,1]:
  for first in [true,false]:sweep(who,first,true)
 sweep(0,true,false)
 damage_sweep();later_death();complex_sweep();leader_return()
 print("checks: ",checks," failures: ",failures.size())
 quit(0 if failures.is_empty() else 1)
