extends "res://tests/support/ui_base.gd"

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/curse-discount-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 for with_ran in [false,true]:
  clean()
  e.players[0].leader=e.make_card("character-fdf-ex02",0,"leader")
  var spell=put("new-spx-006","hand")
  var curse=put("spell-fdf-014","palette")
  var dual=put("114","palette")
  var blue=put("167","palette")
  var yellow=put("164","palette")
  if with_ran:put("24","field")
  view.render();view.request_cast(spell.uid);view.start_payment()
  expect(view.local.get("mode","")=="payment" and view.payment_ready(),"支付界面提供合法自动方案：八云蓝="+str(with_ran))
  for reservation in view.local.plan.duplicate(true):view.reserve_resource(reservation.uid)
  expect(view.local.plan.is_empty() and not view.payment_ready(),"取消自动方案后可以重新选择资源")
  expect(view.payment_sources().any(func(s):return s.uid==dual.uid) and view.payment_sources().any(func(s):return s.uid==blue.uid),"蓝黑牌和单蓝牌都在可选支付资源中")
  view.reserve_resource(blue.uid if with_ran else dual.uid)
  expect(view.local.plan.size()==1 and view.local.plan[0].color=="蓝","点击蓝色资源保留玩家选择")
  if not with_ran:
   expect(not view.payment_ready() and view.payment_sources().any(func(s):return s.uid==blue.uid),"已有一蓝时仍可选择第二张单蓝牌")
   view.reserve_resource(blue.uid)
  expect(view.payment_ready(),"手动蓝色支付方案允许发动")
  view.commit_local()
  expect(view.local.is_empty() and e.stack.any(func(s):return s.get("card",{}).get("uid",0)==spell.uid),"界面发动废线成功")
  expect(blue.tapped and dual.tapped==not with_ran and not curse.tapped and not yellow.tapped,"界面发动只扣除手动选择的资源")
 print("CURSE_DISCOUNT_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
