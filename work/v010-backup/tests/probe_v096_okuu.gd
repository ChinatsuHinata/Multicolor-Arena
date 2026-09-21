extends "res://tests/test_v092.gd"
func run():
 app=load("res://main.tscn").instantiate(); root.add_child(app); await process_frame
 app.load_test_decks(); app.begin_battle(true); view=app.duel_view; view.set_process(false); e=view.engine
 for debug in [false,true]:
  clean(debug); var okuu=put("78","field"); put("162","deck")
  for i in range(12): put("53","deck"); put("53","deck",1)
  for id in ["165","166","168"]: put(id,"palette")
  var at=Time.get_ticks_msec(); view.render(); await settle()
  print("OKUU render ms=",Time.get_ticks_msec()-at," debug=",debug," modal=",view.modal," browser=",view.debug_open," local=",view.local," priority=",e.priority)
  await press("结束主要阶段")
  view.fast_mode=true
  for i in range(8): view._process(1); await process_frame
  print("AFTER PASS phase=",e.phase," pending=",e.pending," priority=",e.priority," revision=",e.revision)
  expect(e.phase!="main" or e.active!=0,"Okuu alone does not block ending main phase")
 print("OKUU_PROBE ",checks," failures ",failures)
 quit(0 if failures.is_empty() else 1)
