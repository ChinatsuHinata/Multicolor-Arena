extends "res://tests/support/rules_base.gd"

func cast_kuji(target: Dictionary) -> Dictionary:
 var spell=put("spell-fdf-063","hand")
 var options=e.targets_for(spell.card_id,0,spell.uid)
 expect(target in options and options.all(func(o):return not o.has("selection")),"九字切使用时只指定伤害目标")
 e.debug_enabled=true;e.debug_free_payment=true
 var error=e.commit_cast(0,spell.uid,target,[])
 expect(error.is_empty(),"九字切可以施放："+error)
 return spell

func choose_god(god: Dictionary):
 expect(e.pending.get("kind","")=="effect_choice" and e.pending.get("trigger",{}).get("effect","")=="cat:kuji_god","九字切结算时才选择神")
 if e.pending.is_empty():return
 var choice=e.pending.options[0].duplicate(true)
 choice.erase("selection");choice.picks=[[e.ref_target(god)]]
 expect(e.Pack.choice_valid(e,e.pending.options,choice),"可选择结算时操控的神")
 e.choose_effect(choice)

func run():
 fresh();put("9")
 var spell=cast_kuji({"player":1});one()
 expect(spell.zone=="grave" and e.players[1].life==16 and e.pending.is_empty(),"没有神时仍造成4点伤害")

 fresh();put("9");var god=put("82")
 spell=cast_kuji({"player":1});one()
 expect(e.players[1].life==16 and god.get("plus_counters",0)==0,"使用时不预先放置指示物")
 choose_god(god)
 expect(spell.zone=="grave" and god.plus_counters==4,"结算选择神后放置4个指示物")

 fresh();put("9")
 spell=cast_kuji({"player":1});god=put("82");one()
 choose_god(god)
 expect(spell.zone=="grave" and e.players[1].life==16 and god.plus_counters==4,"使用后才进场的神可以得到指示物")

 fresh();put("9");god=put("82")
 spell=cast_kuji({"player":1});e.move_to(god,"grave");one()
 expect(spell.zone=="grave" and e.players[1].life==16 and e.pending.is_empty(),"神在结算前离场仍可造成伤害")

 fresh();put("9");god=put("82");var victim=put("53","field",1)
 spell=cast_kuji(e.ref_target(victim));e.move_to(victim,"grave");one()
 expect(spell.zone=="grave" and god.get("plus_counters",0)==0 and e.pending.is_empty(),"伤害目标失效时整张九字切不结算，也不放指示物")

 fresh();put("9")
 for i in range(5):put("9","palette")
 spell=cast_kuji({"player":1});one()
 expect(spell.zone=="grave" and e.players[1].life==11,"没有神且满足奇迹门槛时仍造成9点伤害")

 print("KUJI_KIRI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
