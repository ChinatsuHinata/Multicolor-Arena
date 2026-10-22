extends "res://tests/support/ui_base.gd"

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/dream-discount-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate()
 app.settings_path=Store.Paths.root_override+"/settings.json";app.tutorial_local_directory=Store.Paths.root_override+"/tutorials"
 root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 for with_blue in [true,false]:
  clean()
  put("new-eto-003","field").leader=true
  var spell=put("new-eto-008","hand")
  var enemy=put("53","field",1)
  var yellow=[];var blue=[]
  for i in range(3):yellow.append(put("164","palette"))
  if with_blue:
   for i in range(2):blue.append(put("167","field"))
  var target=e.Roster.New.spell_options(e,spell.card_id,0).filter(func(o):return o.n21_modes==1)[0].duplicate(true)
  target.erase("selection");target.picks=[[e.ref_target(enemy)]]
  view.render();view.request_cast(spell.uid)
  view.local.target=target;view.start_payment()
  expect(view.local.get("mode","")=="payment" and view.payment_ready(),"空与海提供合法推荐：有蓝色道具="+str(with_blue))
  if with_blue:expect(view.local.plan.any(func(p):return p.color=="蓝"),"默认推荐优先使用蓝色道具")
  for reservation in view.local.plan.duplicate(true):view.reserve_resource(reservation.uid)
  expect(view.local.plan.is_empty() and not view.payment_ready(),"可以撤销推荐并重新选择减费后的支付资源")
  for resource in yellow:
   expect(view.payment_sources().any(func(s):return s.uid==resource.uid),"黄色资源始终可补齐三黄支付")
   view.reserve_resource(resource.uid)
  expect(view.payment_ready() and view.local.plan.size()==3 and view.local.plan.all(func(p):return p.color=="黄"),"三黄支付完成并允许发动")
  view.commit_local()
  expect(view.local.is_empty() and spell.zone=="stack","界面以三黄成功使用空与海")
  expect(yellow.all(func(c):return c.tapped) and blue.all(func(c):return not c.tapped),"三黄支付仅横置三张黄色资源")
 print("DREAM_DISCOUNT_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
