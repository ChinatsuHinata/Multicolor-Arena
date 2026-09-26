extends "res://tests/support/ui_base.gd"

func hover(at: Vector2):
 var event=InputEventMouseMotion.new();event.position=at;event.global_position=at
 root.push_input(event,true);await process_frame;await physics_frame

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/momiji-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 clean()
 var momiji=put("character-fdf-101","field");momiji.entered_turns=0;momiji.locked_name=e.cards["164"].name
 var enemy=put("character-fdf-101","field",1);enemy.locked_name=e.cards["167"].name
 var own_item=put("164","field");put("164","field",1)
 var palette=put("164","palette");var unit=put("53","hand")
 for top_down in [false,true]:
  view.table.set_top_down_view(top_down);view.render();await settle()
  await hover(point(momiji.uid))
  expect(view.stage.tooltip_text.contains("宣称："+momiji.locked_name),"hover shows own Momiji declaration in "+str(top_down))
  await click(point(momiji.uid))
  expect(view.inspection.visible and view.inspect_uid==momiji.uid and view.inspection_text.get_parsed_text().begins_with("宣称："+momiji.locked_name),"click displays declaration at the top of the explanation board in "+str(top_down))
  expect(view.inspection.position.x==view.INSPECTION.position.x and view.inspection.position.x<view.STAGE.size.x/2,"declaration is on the left explanation board")
  expect(view.inspection_text.get_parsed_text().contains(e.cards[momiji.card_id].rules_text),"declaration shares the board with the card's rules")
  expect(view.attack_preview_uid==momiji.uid,"click retains the normal attack preview")
  await hover(point(enemy.uid))
  expect(view.stage.tooltip_text.contains("宣称："+enemy.locked_name) and not view.stage.tooltip_text.contains(momiji.locked_name),"hover reads each Momiji's own declaration")
  expect(view.inspect_uid==momiji.uid and view.inspection_text.get_parsed_text().contains("宣称："+momiji.locked_name),"hover does not overwrite the clicked declaration")
  await click(point(enemy.uid))
  expect(view.inspect_uid==enemy.uid and view.inspection_text.get_parsed_text().begins_with("宣称："+enemy.locked_name),"opponent Momiji is also inspectable by left click")
  await hover(point(own_item.uid))
  expect(view.stage.tooltip_text.is_empty(),"hovering another card clears the declaration tooltip")
  view.right_cancel()
 view.object_clicked(momiji.uid)
 await capture("momiji-declaration")
 view.clear_attack_preview();view.render();view.request_cast(unit.uid)
 expect(view.local.plan==[{"uid":palette.uid,"color":"黄"}],"UI recommends palette instead of the prohibited item")
 expect(not view.payment_sources().any(func(s):return s.uid==own_item.uid),"prohibited item cannot be picked as a payment source")
 await press("发动");await settle()
 expect(unit.zone=="stack" and palette.tapped and not own_item.tapped,"UI commits only the permitted palette payment")
 resolve();e.presentation_events.clear();view.render();await settle()
 view.object_clicked(momiji.uid);momiji.locked_name=e.cards["168"].name;view.render()
 expect(view.inspection_text.get_parsed_text().begins_with("宣称："+momiji.locked_name),"explanation board refreshes when the declaration changes")
 e.move_to(momiji,"hand");e.presentation_events.clear();view.render()
 expect(not view.inspection_text.get_parsed_text().contains("宣称："),"explanation board clears the old permanent's declaration after it leaves")
 e.shift(momiji,"field");e.players[0].hand.erase(momiji);e.players[0].field.append(momiji);e.presentation_events.clear();view.render()
 expect(view.inspection_text.get_parsed_text().begins_with("宣称：尚未宣称"),"returning permanent has no previous declared name")
 view.object_clicked(momiji.uid)
 expect(view.inspection_text.get_parsed_text().begins_with("宣称：尚未宣称"),"new permanent has no stale declared name")
 print("MOMIJI_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
