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
 expect(view.stack_panel.column is VBoxContainer and view.stack_panel.tiles.size()==4,"Android stack keeps a single vertical sequence")
 var stack_area=view.stack_panel.scroll.get_global_rect()
 var visible_cards=view.stack_panel.tiles.values().filter(func(entry):return stack_area.encloses(entry.tile.get_global_rect()))
 expect(visible_cards.size()>=2,"multiple complete stack card faces are visible without scrolling")
 var first=view.stack_panel.column.get_child(0)
 var second=view.stack_panel.column.get_child(1)
 expect(first.get_meta("stack_id")==103 and second.get_meta("stack_id")==102 and first.find_child("StackOrder",true,false).text.begins_with("1 · 先结算") and second.find_child("StackOrder",true,false).text.begins_with("2 · 随后结算"),"stack cards show an unambiguous top-to-bottom resolution order")
 await capture("android-stack-cards")

 clean()
 for i in range(4):
  e.players[0].hand.append(e.make_card(["53","100","164","169"][i],0,"hand"))
  e.players[1].hand.append(e.make_card(["53","100","164","169"][i],1,"hand"))
 e.active=1;e.priority=0
 view.set_response_mode(view.ResponseMode.ON);await process_frame
 var response=find_button(view.ui,"不响应 / 继续")
 var back=view.android_back_button
 expect(response!=null and is_equal_approx(response.size.x,back.size.x) and is_equal_approx(response.size.y,back.size.y) and is_equal_approx(response.get_global_rect().position.x,back.get_global_rect().position.x),"Android response and back buttons share width, height, and alignment")
 await capture("android-response-hand-visible")
 view.settings_menu();await process_frame
 var hand_toggles=view.modal_root.find_children("*","CheckButton",true,false).filter(func(item):return item.text=="显示手牌")
 expect(hand_toggles.size()==1,"Android battle settings expose hand visibility")
 if not hand_toggles.is_empty():await click(hand_toggles[0].get_global_rect().get_center())
 expect(not view.hand_scroll.visible and not view.opponent_layer.visible,"Android battle can hide hand rows")
 await capture("android-response-hand-hidden")
 view.set_hand_display(true);await process_frame
 expect(view.hand_scroll.visible and view.opponent_layer.visible,"Android battle can restore hand rows")

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
