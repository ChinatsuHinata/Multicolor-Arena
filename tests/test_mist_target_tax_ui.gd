extends "res://tests/support/ui_base.gd"

func setup_trigger(id: String,resources: int=3) -> Dictionary:
 clean()
 var enemy=put("character-fdf-110","field",1)
 put("spell-fdn-015","field",1).timer=3
 for i in range(resources):put(["164","166","165"][i%3],"palette")
 var source=put(id,"field")
 if id=="new-loc-001":
  source.leader=true;e.Roster.Batch.counter(e,source,"courage",1,0)
 else:e.Extra.on_enter(e,source)
 e.pump_choices()
 e.presentation_events.clear();view.reveal_player.reset();view.render()
 return {"source":source,"enemy":enemy}

func select_payment():
 var options=view.picker.available().filter(func(atom):return atom.get("value","")=="支付费用")
 expect(not options.is_empty(),"payment mode is offered")
 if not options.is_empty():view.inline_pick(options[0]);view.confirm_trigger()

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/mist-target-tax-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);view.fast_mode=true;e=view.engine
 for id in ["new-loc-001","character-ucs-038","39"]:
  var board=setup_trigger(id)
  view.choose_target(e.ref_target(board.enemy));view.confirm_trigger()
  expect(e.pending.trigger.effect=="trigger_target_payment" and e.stack.back().get("awaiting_target",false),"UI target confirmation requests mist payment: "+id)
  select_payment()
  expect(view.local.get("action","")=="choice_payment" and view.local_cost()=={"红/蓝/绿/黄/黑":3} and view.local.plan.size()==3,"UI reserves exactly three extra colors: "+id)
  expect(e.players[0].palette.all(func(c):return not c.tapped),"UI reservation has not spent resources: "+id)
  view.cancel_cast()
  expect(e.pending.trigger.effect=="trigger_target_payment" and not e.stack.back().get("announced",false),"cancelling reservation keeps the unpaid ability pending: "+id)
  select_payment();view.commit_local()
  expect(e.pending.is_empty() and e.players[0].palette.all(func(c):return c.tapped) and e.stack.back().get("announced",false),"UI commits payment before announcing ability: "+id)
  expect(not board.enemy.tapped and board.enemy.zone=="field" and e.combat.is_empty(),"UI payment waits for ordinary ability resolution: "+id)

 var board=setup_trigger("new-loc-001",2)
 view.choose_target(e.ref_target(board.enemy));view.confirm_trigger()
 expect(not view.picker.available().any(func(atom):return atom.get("value","")=="支付费用"),"UI offers no payable mode with only two colors")
 view.confirm_trigger()
 expect(e.pending.is_empty() and e.stack.is_empty() and not board.enemy.tapped,"UI unpaid choice leaves Yuugi upright")

 print("MIST_TARGET_TAX_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
