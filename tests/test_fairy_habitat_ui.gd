extends "res://tests/support/ui_base.gd"

func frames():
 for i in range(8):await process_frame
func action_buttons():
 if not is_instance_valid(view.android_choice_panel):return []
 return view.android_choice_panel.get_node("AndroidActionScroll/ActionChoiceGrid").get_children()
func inspect(c):
 view.android_inspection_allowed=true;view.inspect_card(c.card_id,c.uid);view.android_inspection_allowed=false
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/fairy-habitat-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();app.is_android="--android" in OS.get_cmdline_user_args()
 app.settings_path=Store.Paths.root_override.path_join("settings.json");app.tutorial_local_directory=Store.Paths.root_override.path_join("tutorials")
 root.size=Vector2i(1280,720) if app.is_android else Vector2i(1600,900)
 root.add_child(app);await frames()
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);view.fast_mode=true;e=view.engine
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
 inspect(habitat)
 var inherited_text=view.inspection_text.get_parsed_text()
 expect(inherited_text.contains("继承词条：") and inherited_text.contains("疾行") and inherited_text.contains("英勇") and inherited_text.contains("结晶"),"habitat inspection shows inherited fairy keywords")
 view.open_actions(habitat);await frames()
 var actions=e.available_actions(0,habitat.uid)
 expect(mountain.tapped and cirno.tapped and clown.tapped and hell.tapped and actions.any(func(a):return a.get("key","")=="character-fdn-006"),"tapped fairy sources keep habitat copy action visible")
 expect(actions.any(func(a):return a.get("key","")=="character-fdn-006"),"habitat copy activation appears with other actions")
 var panel=view.android_choice_panel
 var scroll=panel.get_node("AndroidActionScroll") as ScrollContainer
 var buttons=action_buttons()
 expect(actions.size()>3 and buttons.size()==e.available_actions(0,habitat.uid,true).size(),"current action grid retains every inherited action")
 for action in actions:
  expect(buttons.any(func(n):return n.tooltip_text.begins_with(action.label)),"action menu retains ability caption: "+action.type+" "+action.get("key",""))
 scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page)
 await frames()
 expect(buttons.back().get_global_rect().intersects(scroll.get_global_rect()),"last habitat action remains reachable")
 for k in ["character-fdn-006","character-fdf-113"]:
  var action=actions.filter(func(a):return a.get("key","")==k)[0]
  var button=buttons.filter(func(n):return n.tooltip_text.begins_with(action.label))[0]
  expect(button.get_global_rect().intersects(scroll.get_global_rect()),"inherited action remains reachable: "+k)
 view.close_overlay()
 var original=view.card_badges.get("card_"+str(mountain.uid),{})
 expect(original.has("root") and not original.get("icons",[]).any(func(icon):return icon.texture.resource_path.ends_with("mountain_fairy.png")),"original mountain fairy has no copy marker")
 var habitat_icons=view.card_badges.get("card_"+str(habitat.uid),{}).get("icons",[])
 expect(not habitat_icons.any(func(icon):return icon.texture.resource_path.ends_with("mountain_fairy.png")),"uncopied habitat has no mountain fairy copy marker")
 var copy=e.Cat.copy_token(e,0,habitat,"mountain_fairy")
 view.table.sync();view.rebuild_badges();await process_frame
 var marked=view.card_badges.get("card_"+str(copy.uid),{})
 expect(marked.has("root") and marked.get("icons",[]).any(func(icon):return icon.texture.resource_path.ends_with("mountain_fairy.png") and icon.size==Vector2(view.CARD_ICON_SIZE,view.CARD_ICON_SIZE)),"habitat copy token displays the matching-size pixel marker")
 e.presentation_events.clear();view.reveal_player.reset()
 view.open_actions(copy);await frames()
 var copy_buttons=action_buttons()
 expect(copy_buttons.any(func(button):return button.tooltip_text.contains("创造一个该单位的复制")),"habitat copy action menu shows the inherited mountain fairy ability")
 view.close_overlay()
 e.players[0].hand.clear();view.open_actions(copy);await frames()
 copy_buttons=action_buttons() if view.action_menu_open else []
 var disabled_copy=e.available_actions(0,copy.uid,true).filter(func(action):return action.get("key","")=="character-fdn-006")
 expect(disabled_copy.size()==1 and not disabled_copy[0].enabled and copy_buttons.any(func(button):return button.disabled and button.tooltip_text.begins_with(disabled_copy[0].label) and button.tooltip_text.ends_with(disabled_copy[0].reason)),"habitat copy shows its disabled ability and reason after the discard card is spent")
 view.close_overlay()
 inspect(copy)
 inherited_text=view.inspection_text.get_parsed_text()
 expect(inherited_text.contains("创造一个该单位的复制") and inherited_text.contains("继承词条：") and inherited_text.contains("结晶"),"habitat copy inspection shows its inherited mountain fairy ability and keyword")
 inspect(habitat)
 e.move_to(clown,"grave");e.move_to(hell,"grave");e.judge();view.update_inspection()
 inherited_text=view.inspection_text.get_parsed_text()
 expect(not inherited_text.contains("疾行") and inherited_text.contains("英勇") and inherited_text.contains("结晶"),"inspection removes inherited haste after both haste fairies leave")
 e.move_to(mountain,"grave");e.judge();inspect(copy)
 inherited_text=view.inspection_text.get_parsed_text()
 expect(not inherited_text.contains("创造一个该单位的复制") and e.cards[copy.card_id].get("copy_marker","")=="mountain_fairy","copy inspection updates when mountain fairy leaves while keeping its marker")
 clean();habitat=put("character-fdn-007","field");mountain=put("character-fdn-006","field");put("character-fdn-006","field")
 e.judge();inspect(habitat)
 inherited_text=view.inspection_text.get_parsed_text()
 expect(inherited_text.contains("结晶（×2）") and inherited_text.contains("创造一个该单位的复制") and inherited_text.contains("（×2）"),"inspection shows counts for identical inherited abilities and keywords")
 view.open_actions(habitat);await frames()
 actions=e.available_actions(0,habitat.uid,true)
 var repeated_action=actions.filter(func(action):return action.get("key","")=="character-fdn-006")
 var repeated_buttons=action_buttons()
 expect(repeated_action.size()==1 and repeated_action[0].label.begins_with("（×2）") and repeated_buttons.any(func(button):return button.text.begins_with("（×2）") and button.tooltip_text.begins_with(repeated_action[0].label)),"action menu displays the count of identical inherited activations")
 view.close_overlay();e.move_to(mountain,"grave");e.judge();view.update_inspection()
 inherited_text=view.inspection_text.get_parsed_text()
 expect(inherited_text.contains("创造一个该单位的复制") and not inherited_text.contains("（×2）"),"inspection updates repeated ability counts after a source leaves")
 print("FAIRY_HABITAT_UI: ",checks," checks; ",failures.size()," failures")
 quit(1 if not failures.is_empty() else 0)
