extends "res://tests/support/rules_base.gd"

const Gateway=preload("res://net/command_gateway.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")

func setup(who: int=0,resources: int=3,mists: int=1) -> Dictionary:
 fresh()
 var cirno=put("new-loc-001","field",who);cirno.leader=true
 var yuugi=put("character-fdf-110","field",1-who)
 for i in range(mists):put("spell-fdn-015","field",1-who).timer=3
 for i in range(resources):put(["165","167","166","164","168"][i%5],"palette",who)
 e.Roster.Batch.counter(e,cirno,"courage",1,who)
 e.pump_choices()
 expect(e.pending.get("kind","")=="effect_choice" and e.pending.trigger.effect=="n21:LOC-001:self","placing a counter queues Cirno's tap ability")
 return {"cirno":cirno,"yuugi":yuugi}

func tap_target(c: Dictionary) -> Dictionary:
 var target=e.pending.options[0].duplicate(true)
 target.erase("selection");target.picks=[[e.ref_target(c)]]
 return target

func pay_choice() -> Dictionary:
 var choices=e.pending.get("options",[]).filter(func(t):return t.get("pay",false))
 return choices[0] if not choices.is_empty() else {}

func run():
 var board=setup()
 e.choose_effect(tap_target(board.yuugi))
 expect(e.pending.get("trigger",{}).get("effect","")=="trigger_target_payment","protected Yuugi requires an extra payment choice")
 expect(not board.yuugi.tapped and e.stack.back().get("awaiting_target",false),"unpaid tap ability has not been announced or resolved")
 if e.pending.get("trigger",{}).get("effect","")!="trigger_target_payment":
  print("MIST_TARGET_TAX: ",checks," checks; ",failures.size()," failures")
  quit(1);return
 expect(e.pending.trigger.data.cost=={"红/蓝/绿/黄/黑":3},"one mist charges three arbitrary colors")
 var payment=pay_choice().duplicate(true)
 payment.payment=e.payment(0,e.pending.trigger.data.cost).plan
 e.choose_effect(payment)
 expect(e.pending.is_empty() and e.players[0].palette.all(func(c):return c.tapped),"three mixed-color resources are paid before announcement")
 expect(not e.stack.back().target.has("payment") and e.stack.back().get("announced",false),"payment metadata is separate from the announced target")
 one()
 expect(board.yuugi.tapped,"paid Cirno ability taps Yuugi on resolution")

 board=setup(0,2)
 e.choose_effect(tap_target(board.yuugi))
 expect(pay_choice().is_empty(),"two resources cannot pay the three-point tax")
 e.choose_effect(e.pending.options[0])
 expect(e.pending.is_empty() and e.stack.is_empty() and not board.yuugi.tapped,"declining unpaid ability leaves Yuugi upright")
 expect(e.players[0].palette.all(func(c):return not c.tapped),"declining does not spend resources")

 board=setup()
 var target=tap_target(board.yuugi);target.payment=[]
 var before=JSON.stringify([e.players,e.pending,e.stack,e.revision])
 e.choose_effect(target)
 expect(JSON.stringify([e.players,e.pending,e.stack,e.revision])==before,"explicit empty payment cannot bypass the tax")
 target.payment=e.payment(0,{"红/蓝/绿/黄/黑":3}).plan
 e.choose_effect(target)
 expect(e.pending.is_empty() and e.players[0].palette.all(func(c):return c.tapped),"direct declared payment also pays the tax")

 board=setup(0,6,2)
 e.choose_effect(tap_target(board.yuugi))
 expect(e.pending.trigger.data.cost=={"红/蓝/绿/黄/黑":6},"two mist supports add six points once per ability")
 e.choose_effect(pay_choice())
 expect(e.players[0].palette.all(func(c):return c.tapped),"automatic choice pays the full stacked mist cost")

 board=setup(0,0,0)
 e.choose_effect(tap_target(board.yuugi));one()
 expect(board.yuugi.tapped and e.pending.is_empty(),"Yuugi without mist can still be tapped for free")
 board=setup(0,0)
 var fairy=put("53","field",1)
 e.pending.options=e.trigger_options(e.pending.trigger)
 e.choose_effect(tap_target(fairy));one()
 expect(fairy.tapped and e.pending.is_empty(),"mist does not tax a non-oni target")
 board=setup(0,0)
 var own_oni=put("character-fdf-110")
 e.pending.options=e.trigger_options(e.pending.trigger)
 e.choose_effect(tap_target(own_oni));one()
 expect(own_oni.tapped and e.pending.is_empty(),"mist does not tax a friendly oni target")
 board=setup(0,0)
 target=e.pending.options[0].duplicate(true);target.erase("selection");target.picks=[[]]
 e.choose_effect(target);one()
 expect(not board.yuugi.tapped and e.pending.is_empty(),"choosing zero targets has no tax")

 board=setup()
 e.choose_effect(tap_target(board.yuugi))
 payment=pay_choice().duplicate(true);payment.payment=e.payment(0,e.pending.trigger.data.cost).plan
 e.tap_card(e.find_card(payment.payment[0].uid))
 before=JSON.stringify([e.players,e.pending,e.stack,e.revision])
 e.choose_effect(payment)
 expect(JSON.stringify([e.players,e.pending,e.stack,e.revision])==before,"stale reserved resource leaves the payment choice intact")

 board=setup(1)
 var snapshot=SeatView.build(e,1)
 var facade=Remote.new();facade.seat=1;facade.apply_snapshot(snapshot)
 target=tap_target(board.yuugi)
 expect(Gateway.apply(e,1,{"name":"choose_effect","args":[target]}).is_empty(),"remote declaration reaches the payment choice")
 snapshot=SeatView.build(e,1);facade.apply_snapshot(snapshot)
 expect(facade.pending.trigger.data.cost=={"红/蓝/绿/黄/黑":3},"remote seat receives the authoritative payment cost")
 before=JSON.stringify([e.players,e.pending,e.stack,e.revision])
 payment=pay_choice().duplicate(true);payment.payment=[]
 expect(not Gateway.apply(e,1,{"name":"choose_effect","args":[payment]}).is_empty(),"authority rejects an unpaid remote payment choice")
 expect(JSON.stringify([e.players,e.pending,e.stack,e.revision])==before,"invalid remote payment has no side effects")
 payment.payment=facade.payment(1,facade.pending.trigger.data.cost).plan
 expect(Gateway.apply(e,1,{"name":"choose_effect","args":[payment]}).is_empty(),"remote payment commits three colors")
 one()
 expect(board.yuugi.tapped and e.players[1].palette.all(func(c):return c.tapped),"remote paid ability taps the protected oni")

 board=setup(1)
 e.ai_step(1);e.ai_step(1)
 expect(e.pending.is_empty() and e.players[1].palette.all(func(c):return c.tapped),"AI completes the payment step without stalling")
 board=setup(1,0)
 e.ai_step(1);e.ai_step(1)
 expect(e.pending.is_empty() and not board.yuugi.tapped,"AI declines an unaffordable protected target without stalling")

 fresh()
 var cirno=put("character-lof-001");cirno.leader=true;cirno.courage=2
 var yuugi=put("character-fdf-110","field",1);put("spell-fdn-015","field",1).timer=3
 for i in range(3):put("165","palette")
 expect(e.extension_cost(0,cirno,"courage_die",e.ref_target(yuugi))=={"红/蓝/绿/黄/黑":3},"activated Ice Hero ability retains its existing three-point tax")
 expect(not e.commit_extension(0,cirno.uid,e.ref_target(yuugi),[],"courage_die").is_empty() and cirno.courage==2,"activated Ice Hero cannot spend counters without paying the tax")
 expect(e.commit_extension(0,cirno.uid,e.ref_target(yuugi),e.payment(0,e.extension_cost(0,cirno,"courage_die",e.ref_target(yuugi))).plan,"courage_die").is_empty(),"activated Ice Hero also accepts paid targeting")
 expect(cirno.courage==0 and e.players[0].palette.all(func(c):return c.tapped),"activated Ice Hero pays both counters and the extra three colors")

 fresh()
 var source=put("68");yuugi=put("character-fdf-110","field",1)
 put("spell-fdn-015","field",1).timer=3
 for i in range(3):put("165","palette")
 e.queue_trigger(0,source,1,"目标伤害");e.pump_choices()
 expect(e.pending.get("kind","")=="trigger","simple triggered ability uses the ordinary target chooser")
 e.choose_trigger(e.ref_target(yuugi))
 expect(e.pending.trigger.effect=="trigger_target_payment","simple triggered ability also requests mist payment")
 e.choose_effect(pay_choice());one()
 expect(yuugi.damage==1 and e.players[0].palette.all(func(c):return c.tapped),"simple triggered ability pays three before dealing damage")

 print("MIST_TARGET_TAX: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
