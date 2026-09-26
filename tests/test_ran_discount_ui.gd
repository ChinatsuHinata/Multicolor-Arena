extends "res://tests/support/ui_base.gd"

func action_tile(node: Node,kind: String):
 if node.get_meta("action_type","")==kind:return node
 for child in node.get_children():
  var found=action_tile(child,kind)
  if found:return found
 return null

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/ran-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 app.set_show_card_inspection(true)
 clean()
 var ran=put("24","field");ran.entered_turns=0
 var spell=put("167","hand");put("167","palette")
 var enemy=put("24","field",1)
 for top_down in [false,true]:
  view.table.set_top_down_view(top_down);view.render();await settle()
  await click(point(ran.uid))
  expect(view.action_menu_open and action_tile(view.modal_root,"ran_discount")!=null,"click Ran offers a switch in "+str(top_down))
  expect(action_tile(view.modal_root,"attack")!=null,"Ran retains its attack action")
  expect(view.inspection_text.get_parsed_text().begins_with("常驻减费：已开启"),"click displays the enabled state")
  await click(action_tile(view.modal_root,"ran_discount").get_global_rect().get_center())
  expect(ran.get("ran_discount_disabled",false) and not view.modal and view.local.is_empty(),"menu click disables without starting a payment")
  expect(view.inspection_text.get_parsed_text().begins_with("常驻减费：已关闭") and e.cast_cost(0,spell).get("蓝",0)==2,"disabled state and cost refresh immediately")
  await settle();await click(point(ran.uid))
  await click(action_tile(view.modal_root,"ran_discount").get_global_rect().get_center())
  expect(not ran.get("ran_discount_disabled",false) and e.cast_cost(0,spell).get("蓝",0)==1,"second menu click re-enables the discount")
  expect(e.stack.is_empty() and not ran.tapped,"switch does not tap Ran or create a stack object")
  await settle();await click(point(enemy.uid))
  expect(not view.action_menu_open and view.inspect_uid==enemy.uid,"opposing Ran is inspectable without a switch menu")
 view.request_cast(spell.uid)
 expect(view.local.get("plan",[]).size()==1,"payment draft uses the enabled discount")
 view.right_cancel();view.object_clicked(ran.uid)
 expect(view.shortcut_attack() and e.combat.get("attacker",{}).get("uid",0)==ran.uid and ran.tapped,"attack shortcut still works from Ran's menu")
 e.move_to(ran,"hand");e.presentation_events.clear();view.render()
 expect(not view.card_context_caption(ran).contains("常驻减费"),"off-field Ran does not display an active switch")
 print("RAN_DISCOUNT_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
