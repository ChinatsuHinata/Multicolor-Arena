extends "res://tests/test_v092.gd"

func run():
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 clean()
 var habitat=put("character-fdn-007","field")
 var mountain=put("character-fdn-006","field")
 var cirno=put("character-lof-001","field")
 var clown=put("34","field")
 var hell=put("character-fdf-113","field")
 put("50","hand")
 put("167","palette")
 put("165","palette")
 put("164","palette")
 habitat.entered_turns=0;mountain.entered_turns=0;habitat.courage=2
 for fairy in [mountain,cirno,clown,hell]:e.tap_card(fairy)
 e.judge();view.render();await process_frame
 view.inspect_card(habitat.card_id,habitat.uid)
 var inherited_text=view.inspection_text.get_parsed_text()
 expect(inherited_text.contains("继承词条：") and inherited_text.contains("疾行") and inherited_text.contains("英勇") and inherited_text.contains("结晶"),"habitat inspection shows inherited fairy keywords")
 view.open_actions(habitat);await process_frame
 var actions=e.available_actions(0,habitat.uid)
 expect(mountain.tapped and cirno.tapped and clown.tapped and hell.tapped and actions.any(func(a):return a.get("key","")=="character-fdn-006"),"tapped fairy sources keep habitat copy action visible")
 expect(actions.any(func(a):return a.get("key","")=="character-fdn-006"),"habitat copy activation appears with other actions")
 var panel=view.modal_root.get_child(0)
 var scroll=panel.find_children("*","ScrollContainer",true,false)[0] as ScrollContainer
 var content=scroll.get_child(0)
 var labels=content.get_children().filter(func(n):return n is Label)
 expect(actions.size()>3 and content.custom_minimum_size.y>scroll.size.y,"multiple habitat actions have a scrollable menu")
 for action in actions:
  expect(labels.any(func(n):return n.text==action.label),"action menu retains visible label: "+action.type+" "+action.get("key",""))
 scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page)
 await process_frame
 var last_label=labels.back()
 expect(last_label.get_global_rect().intersects(scroll.get_global_rect()),"last habitat action is reachable by scrolling")
 for k in ["character-fdn-006","character-fdf-113"]:
  var action=actions.filter(func(a):return a.get("key","")==k)[0]
  var label=labels.filter(func(n):return n.text==action.label)[0]
  expect(label.get_global_rect().intersects(scroll.get_global_rect()),"lower-row inherited action is reachable by scrolling: "+k)
 view.close_overlay()
 var original=view.card_badges.get("card_"+str(mountain.uid),{})
 expect(original.has("root") and not original.get("icons",[]).any(func(icon):return icon.texture.resource_path.ends_with("mountain_fairy.png")),"original mountain fairy has no copy marker")
 var habitat_icons=view.card_badges.get("card_"+str(habitat.uid),{}).get("icons",[])
 expect(not habitat_icons.any(func(icon):return icon.texture.resource_path.ends_with("mountain_fairy.png")),"uncopied habitat has no mountain fairy copy marker")
 var copy=e.Cat.copy_token(e,0,habitat,true,"mountain_fairy")
 view.table.sync();view.rebuild_badges();await process_frame
 var marked=view.card_badges.get("card_"+str(copy.uid),{})
 expect(marked.has("root") and marked.get("icons",[]).any(func(icon):return icon.texture.resource_path.ends_with("mountain_fairy.png") and icon.size==Vector2(view.CARD_ICON_SIZE,view.CARD_ICON_SIZE)),"habitat copy token displays the matching-size pixel marker")
 view.open_actions(copy);await process_frame
 var copy_labels=view.modal_root.get_child(0).find_children("*","Label",true,false)
 expect(copy_labels.any(func(label):return label.text.contains("创造一个该单位的复制")),"habitat copy action menu shows the inherited mountain fairy ability")
 view.close_overlay()
 e.players[0].hand.clear();view.open_actions(copy);await process_frame
 copy_labels=view.modal_root.get_child(0).find_children("*","Label",true,false) if view.action_menu_open else []
 var disabled_copy=e.available_actions(0,copy.uid,true).filter(func(action):return action.get("key","")=="character-fdn-006")
 expect(disabled_copy.size()==1 and not disabled_copy[0].enabled and copy_labels.any(func(label):return label.text.contains("创造一个该单位的复制") and label.tooltip_text==disabled_copy[0].reason),"habitat copy shows its disabled ability and reason after the discard card is spent")
 view.close_overlay()
 view.inspect_card(copy.card_id,copy.uid)
 inherited_text=view.inspection_text.get_parsed_text()
 expect(inherited_text.contains("创造一个该单位的复制") and inherited_text.contains("继承词条：") and inherited_text.contains("结晶"),"habitat copy inspection shows its inherited mountain fairy ability and keyword")
 view.inspect_card(habitat.card_id,habitat.uid)
 e.move_to(clown,"grave");e.move_to(hell,"grave");e.judge();view.update_inspection()
 inherited_text=view.inspection_text.get_parsed_text()
 expect(not inherited_text.contains("疾行") and inherited_text.contains("英勇") and inherited_text.contains("结晶"),"inspection removes inherited haste after both haste fairies leave")
 e.move_to(mountain,"grave");e.judge();view.inspect_card(copy.card_id,copy.uid)
 inherited_text=view.inspection_text.get_parsed_text()
 expect(not inherited_text.contains("创造一个该单位的复制") and e.cards[copy.card_id].get("copy_marker","")=="mountain_fairy","copy inspection updates when mountain fairy leaves while keeping its marker")
 print("FAIRY_HABITAT_UI: ",checks," checks; ",failures.size()," failures")
 quit(1 if not failures.is_empty() else 0)
