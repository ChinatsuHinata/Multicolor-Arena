extends "res://tests/support/ui_base.gd"

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/tokiko-discount-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate()
 app.settings_path=Store.Paths.root_override+"/settings.json";app.tutorial_local_directory=Store.Paths.root_override+"/tutorials"
 root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 for color in ["黄","黑"]:
  clean()
  put("character-htk-002","field").leader=true
  var orb=put("new-eto-s001","hand")
  var blue=put("167","field")
  var yellow=put("164","palette")
  var black=put("168","palette")
  view.render();view.request_cast(orb.uid);view.start_payment()
  expect(view.payment_ready() and view.local.plan.size()==1 and view.local.plan[0].color=="蓝","灵异珠默认推荐支付一蓝")
  view.reserve_resource(blue.uid)
  var source=yellow if color=="黄" else black
  expect(view.local.plan.is_empty() and view.payment_sources().any(func(s):return s.uid==source.uid),"撤销推荐后可选择一"+color)
  view.reserve_resource(source.uid)
  expect(view.payment_ready() and view.local.plan.size()==1 and view.local.plan[0].color==color,"改付一%s后允许发动" % color)
  view.commit_local()
  expect(view.local.is_empty() and orb.zone=="stack" and source.tapped and not blue.tapped,"界面以一%s成功使用灵异珠" % color)
 print("TOKIKO_DISCOUNT_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
