extends "res://tests/support/ui_base.gd"

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-battle-layout/"+str(Time.get_ticks_usec()))
 root.size=Vector2i(1600,900)
 root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.is_android=true
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app.refresh_ui_metrics()
 app.load_legacy_test_decks()
 app.clear_page("battle")
 view=preload("res://scripts/duel_view.gd").new();view.is_android=true
 app.duel_view=view;app.screen.add_child(view)
 view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 view.begin(app,app.decks[app.player_choice],app.decks[app.ai_choice],0,42)
 view.set_process(false);e=view.engine
 clean()
 var battlefield_unit=put("53","field")
 for i in range(4):
  var id=["100","53","164","169"][i]
  var stacked=e.make_card(id,0,"stack")
  e.stack.append({"id":100+i,"kind":"card","card":stacked,"owner":0,"target":{"none":true},"name":e.cards[id].name})
 view.render();await process_frame
 var battlefield_card=view.table.descriptors.get("card_"+str(battlefield_unit.uid),{})
 expect(not battlefield_card.is_empty() and is_equal_approx(battlefield_card.scale.x,view.table.FIELD_SCALE),"battlefield card retains its original size")
 expect(view.stack_panel.column is VBoxContainer and view.stack_panel.tiles.size()==4,"Android stack keeps the desktop vertical card sequence")
 var stack_area=view.stack_panel.scroll.get_global_rect()
 var visible_cards=view.stack_panel.tiles.values().filter(func(entry):return stack_area.encloses(entry.tile.get_global_rect()))
 expect(visible_cards.size()>=1,"an enlarged stack card remains completely visible without scrolling")
 var first=view.stack_panel.column.get_child(0)
 var second=view.stack_panel.column.get_child(1)
 expect(first is VBoxContainer and second is VBoxContainer,"stack cards use the desktop face-above-caption presentation")
 expect(first.get_meta("stack_id")==103 and second.get_meta("stack_id")==102,"stack cards keep an unambiguous top-to-bottom resolution order")
 expect(view.stack_panel.tiles[103].tile.get_global_rect().size.x>=150,"Android stack faces are large enough to inspect")
 var stack_toggle=view.stack_panel.toggle_button
 expect(stack_toggle!=null and stack_toggle.name=="StackToggle" and stack_toggle.is_visible_in_tree(),"stack has a reachable collapse control")
 if stack_toggle!=null:
  await click(stack_toggle.get_global_rect().get_center())
  expect(view.stack_panel.collapsed and view.stack_panel.visible and not view.stack_panel.scroll.visible and stack_toggle.is_visible_in_tree(),"collapsed stack leaves its reopen control available")
  await click(stack_toggle.get_global_rect().get_center())
  expect(not view.stack_panel.collapsed and view.stack_panel.scroll.visible,"stack can expand again without changing game state")
 expect(not view.observe_button.visible,"observation control is hidden on an unobstructed battlefield")
 await capture("android-stack-cards")

 clean()
 for i in range(4):
  e.players[0].hand.append(e.make_card(["53","100","164","169"][i],0,"hand"))
  e.players[1].hand.append(e.make_card(["53","100","164","169"][i],1,"hand"))
 e.active=1;e.priority=0
 view.set_response_mode(view.ResponseMode.ON);await process_frame
 var response=find_button(view.ui,"不响应 / 继续")
 var back=view.android_back_button
 expect(back!=null and back.text=="取消" and not back.visible,"Android cancel action is named and hidden without a selection")
 expect(response!=null and back!=null and is_equal_approx(response.size.x,back.size.x) and is_equal_approx(response.size.y,back.size.y) and is_equal_approx(response.get_global_rect().position.x,back.get_global_rect().position.x),"Android response and cancel buttons share width, height, and alignment")
 await capture("android-response-hand-visible")
 view.android_back();await process_frame
 expect(not view.modal and not is_instance_valid(view.android_battle_menu_root) and not app.menu_popup_open(),"cancel action does not open settings when nothing is selected")
 var menu_button=view.hud.get_node("BattleToolbar/BattleTools") as Button
 var history_button=view.hud.get_node("BattleToolbar/BattleHistory") as Button
 expect(history_button!=null and history_button.text=="对局记录","battle history has its own top-bar action")
 if menu_button!=null:await click(menu_button.get_global_rect().get_center());await process_frame
 var battle_menu=view.android_battle_menu_root.find_child("AndroidBattleMenu",true,false) if is_instance_valid(view.android_battle_menu_root) else null
 expect(battle_menu!=null,"Android battle menu opens as a single combined panel")
 var menu_close=battle_menu.find_child("CloseBattleMenu",true,false) as Button if battle_menu!=null else null
 expect(menu_close!=null and not menu_close.get_global_rect().intersects(view.observe_button.get_global_rect()),"battlefield observation leaves the menu close control clear")
 if menu_close!=null:
  var close_font=menu_close.get_theme_font("font")
  var close_width=close_font.get_string_size(menu_close.text,HORIZONTAL_ALIGNMENT_LEFT,-1,menu_close.get_theme_font_size("font_size")).x
  expect(close_width<=menu_close.size.x-menu_close.get_theme_stylebox("normal").get_minimum_size().x,"close label fits inside its button")
 var navigation=battle_menu.find_child("BattleMenuNavigation",true,false) if battle_menu!=null else null
 var contents=battle_menu.find_child("BattleMenuContents",true,false) if battle_menu!=null else null
 expect(navigation!=null and contents!=null and navigation.get_global_rect().end.x<=contents.get_global_rect().position.x,"battle menu has a left navigation rail and right content")
 expect(navigation!=null and find_button(navigation,"战斗菜单")!=null and find_button(navigation,"对战设置")!=null,"battle menu contains battle and settings tabs")
 expect(contents!=null and find_button(contents,"设置")==null,"battle menu does not duplicate a settings action in the right pane")
 expect(view.observe_button.visible,"observation becomes available when the menu obscures the battlefield")
 if view.observe_button.visible:
  await click(view.observe_button.get_global_rect().get_center());await process_frame
  expect(view.observing and not view.android_battle_menu_root.visible,"observation temporarily reveals the battlefield behind the menu")
  await click(view.observe_button.get_global_rect().get_center());await process_frame
  expect(not view.observing and view.android_battle_menu_root.visible,"observation can return to the same menu")
 if navigation!=null:
  await click(find_button(navigation,"对战设置").get_global_rect().get_center());await process_frame
 contents=view.android_battle_menu_root.find_child("BattleMenuContents",true,false) if is_instance_valid(view.android_battle_menu_root) else null
 var hand_toggles=contents.find_children("*","CheckButton",true,false).filter(func(item):return item.text=="显示手牌") if contents!=null else []
 expect(hand_toggles.size()==1,"Android battle settings expose hand visibility inside the combined menu")
 if contents!=null:
  for button in contents.find_children("*","Button",true,false):
   if button.is_visible_in_tree():
    expect(button.get_global_rect().position.x>=contents.get_global_rect().position.x-1 and button.get_global_rect().end.x<=contents.get_global_rect().end.x+1,"settings button stays within the right pane: "+button.text)
 await capture("android-combined-battle-settings")
 if not hand_toggles.is_empty():await click(hand_toggles[0].get_global_rect().get_center())
 expect(not view.hand_scroll.visible and not view.opponent_layer.visible,"Android battle can hide hand rows")
 await capture("android-response-hand-hidden")
 view.set_hand_display(true);await process_frame
 expect(view.hand_scroll.visible and view.opponent_layer.visible,"Android battle can restore hand rows")
 if is_instance_valid(view.android_battle_menu_root):view.close_android_battle_menu()
 await process_frame
 expect(not view.observe_button.visible,"observation hides after closing the combined menu")
 history_button=view.hud.get_node_or_null("BattleToolbar/BattleHistory") as Button
 if history_button!=null:
  await click(history_button.get_global_rect().get_center());await process_frame
  expect(view.history_open,"top-bar battle history opens the duel record")
  view.close_history();view.refresh_observation();await process_frame

 clean(true)
 var momiji=e.make_card("character-fdf-101",0,"hand")
 e.enter_field(momiji,0);e.pump_choices();view.render();await settle()
 expect(view.modal_root!=null and view.modal_root.get_meta("card_search_topmost",false),"name declaration opens the card search")
 if view.modal_root==null:app.queue_free();await process_frame;quit(1);return
 var confirm=view.modal_root.find_child("ConfirmSelection",true,false) as Button
 expect(confirm!=null and not back.get_global_rect().intersects(confirm.get_global_rect()),"Android back button leaves declaration confirmation clear")
 var selector=view.modal_root.find_child("CardNameSearchPanel",true,false)
 expect(selector!=null and not back.get_global_rect().intersects(selector.get_global_rect()),"Android back button stays outside the card list")
 if selector!=null:
  expect(selector.color_buttons.is_empty() and selector.find_child("KindFilter",true,false)==null and selector.find_child("SortChoice",true,false)==null,"Android name picker omits color, kind, and sort controls")
  var search=selector.find_child("SearchInput",true,false) as LineEdit
  search.text="博丽灵梦";search.text_changed.emit(search.text);await process_frame
  var results=selector.find_child("SearchResults",true,false)
  var choices=results.get_children().filter(func(b):return b is Button and b.visible and "博丽灵梦" in str(b.get_meta("card_name","")))
  expect(not choices.is_empty(),"declared name can be found")
  if not choices.is_empty():
   await click(choices[0].get_global_rect().get_center());await process_frame
   expect(not confirm.disabled,"confirm enables after choosing a name")
   await capture("android-name-confirm")
   await click(confirm.get_global_rect().get_center());await process_frame
   expect(e.pending.is_empty() and not view.modal,"touching confirmation completes the declaration")
 print("ANDROID BATTLE LAYOUT: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
