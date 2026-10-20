extends "res://tests/support/rules_base.gd"
const Registry=preload("res://scripts/rules/mod_registry.gd")

func check_tax():
 fresh();var b=put("testmod/byakuren","field",1);b.plus_counters=5
 var cirno=put("character-lof-001");cirno.leader=true;cirno.courage=2
 for id in ["165","167"]:put(id,"palette")
 var target=e.ref_target(b);var cost=e.extension_cost(0,cirno,"courage_die",target)
 expect(cost=={"红/蓝/绿/黄/黑":2},"Byakuren adds two arbitrary colors to opponent activated abilities")
 expect(not e.commit_extension(0,cirno.uid,target,[],"courage_die").is_empty() and cirno.courage==2,"unpaid tax rejects activation before spending counters")
 expect(e.commit_extension(0,cirno.uid,target,e.payment(0,cost).plan,"courage_die").is_empty(),"mixed-color tax payment allows targeting Byakuren")
 expect(cirno.courage==0 and e.players[0].palette.all(func(c):return c.tapped),"activation pays the two extra colors")
 fresh();b=put("testmod/byakuren","field",1);b.plus_counters=5
 var source=put("68")
 for id in ["165","167"]:put(id,"palette")
 e.queue_trigger(0,source,1,"目标伤害");e.pump_choices();e.choose_trigger(e.ref_target(b))
 expect(e.pending.get("trigger",{}).get("effect","")=="trigger_target_payment" and e.pending.trigger.data.cost=={"红/蓝/绿/黄/黑":2},"opponent triggered abilities also pay two before announcement")
 e.choose_effect(e.pending.options.filter(func(o):return o.get("pay",false))[0]);one()
 expect(b.damage==1 and e.players[0].palette.all(func(c):return c.tapped),"paid triggered ability resolves against Byakuren")
 fresh();b=put("testmod/byakuren","field",1)
 var spell=put("124","hand")
 expect(e.cast_cost(0,spell,{"uid":b.uid,"epoch":b.epoch,"x":0}).get("红/蓝/绿/黄/黑",0)==2,"opponent spells include Byakuren's tax in their payment")
 var duplicate={"parts":[e.ref_target(b),e.ref_target(b)]}
 expect(e.Cat.target_tax(e,0,duplicate)==2,"targeting the same Byakuren twice charges the tax once")
 var second=put("testmod/byakuren","field",1)
 expect(e.Cat.target_tax(e,0,{"parts":[e.ref_target(b),e.ref_target(second)]})==4,"distinct targeted Byakuren instances each add two")
 e.move_to(b,"grave");e.move_to(second,"grave")
 expect(e.Cat.target_tax(e,0,duplicate)==0,"Byakuren's tax ends when she leaves the battlefield")

func run():
 Registry._shared=Registry.new();expect(Registry.shared().register_pack("res://examples/testmod").is_empty(),"register corrected testmod")
 Store.CARDS=DB.load_cards();check_tax()
 print("BYAKUREN_TARGET_TAX: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
