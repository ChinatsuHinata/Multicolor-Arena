extends "res://tests/support/ui_base.gd"

func touch(at: Vector2,pressed: bool):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=pressed
 root.push_input(event,true);await process_frame

func tap(at: Vector2):
 await touch(at,true);await touch(at,false);await physics_frame

func reset_details():
 view.inspect_id="";view.update_inspection()

func history_cards(node: Node) -> Array:
 var result=[]
 if node.has_meta("history_display_id"):result.append(node)
 for child in node.get_children():result.append_array(history_cards(child))
 return result

func shot(name: String):
 await capture(name+("-phone" if OS.get_cmdline_user_args().has("--phone") else ""))

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-card-details/"+str(Time.get_ticks_usec()))
 root.size=Vector2i(1280,720) if OS.get_cmdline_user_args().has("--phone") else Vector2i(1600,900)
 root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.is_android=true;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 if OS.get_cmdline_user_args().has("--phone"):app.layout_dpi_override=240
 app.refresh_ui_metrics();app.load_legacy_test_decks();app.clear_page("battle")
 view=preload("res://scripts/duel_view.gd").new();view.is_android=true
 app.duel_view=view;app.screen.add_child(view);view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 view.begin(app,app.decks[app.player_choice],app.decks[app.ai_choice],0,42)
 view.set_process(false);e=view.engine
 clean();view.table.set_top_down_view(true)
 var hand=put("53","hand")
 put("53","palette")
 view.render();await settle()
 var at=view.hand_nodes[hand.uid].get_global_rect().get_center()
 var before=snapshot()
 await touch(at,true);await create_timer(0.65).timeout
 expect(view.inspection.visible and view.inspect_id==hand.card_id,"native hand long press opens card rules before release")
 expect(snapshot()==before and view.local.is_empty(),"holding a hand card does not play or select it")
 var title=view.inspection.find_child("InspectionTitle",true,false)
 expect(title!=null and title.get_theme_font_size("font_size")>=app.ui_metrics.title,"card details use the larger title font")
 await shot("android-hand-long-press")
 await touch(at,false)
 await click(at)
 expect(snapshot()==before and view.local.is_empty(),"long press release and its mouse echo do not play the hand card")
 reset_details();await create_timer(0.3).timeout
 await tap(at)
 expect(view.local.get("uid",0)==hand.uid and not view.inspection.visible,"short hand tap keeps its play action without opening details")
 view.cancel_cast();reset_details()
 await touch(at,true)
 var cancel=InputEventScreenTouch.new();cancel.index=0;cancel.position=at;cancel.pressed=false;cancel.canceled=true
 root.push_input(cancel,true);await process_frame;await create_timer(0.65).timeout
 expect(not view.inspection.visible and view.local.is_empty(),"an interrupted touch cancels hand play and the delayed details")

 clean();reset_details()
 for i in range(15):put("100","hand")
 view.render();await settle()
 at=view.hand_nodes[e.players[0].hand[0].uid].get_global_rect().get_center()
 await touch(at,true)
 var drag_event=InputEventScreenDrag.new();drag_event.index=0;drag_event.position=at-Vector2(180,0);drag_event.relative=Vector2(-180,0)
 root.push_input(drag_event,true);await process_frame;await create_timer(0.65).timeout
 await touch(drag_event.position,false)
 expect(not view.inspection.visible and view.local.is_empty(),"dragging the hand cancels both long press and play")
 expect(view.hand_scroll.scroll_horizontal>0,"hand swiping still scrolls the card row")

 clean();reset_details()
 var unit=put("53","field")
 var enemy=put("164","field",1)
 view.render();await settle()
 await tap(point(unit.uid))
 expect(view.inspect_uid==unit.uid and view.inspection.visible,"tapping a battlefield unit opens its rules")
 expect(view.attack_preview_uid==unit.uid,"unit tap retains the attack preview")
 view.android_back();reset_details()
 await tap(point(enemy.uid))
 expect(view.inspect_uid==enemy.uid,"tapping an opponent unit opens its rules")

 clean();reset_details()
 var palette=put("165","palette")
 view.android_palette_owner=0;view.render();await process_frame
 at=view.android_palette_tiles[palette.uid].get_global_rect().get_center()
 await tap(at)
 expect(not view.inspection.visible,"short palette tap leaves card details closed")
 await touch(at,true);await create_timer(0.65).timeout
 expect(view.inspect_uid==palette.uid and view.inspection.visible,"long pressing a palette card opens its rules")
 await shot("android-palette-long-press-details")
 await touch(at,false)

 clean();reset_details();view.android_palette_owner=-1
 for i in range(5):
  var card=e.make_card(["100","53","164","169","100"][i],0,"stack")
  e.stack.append({"id":500+i,"kind":"card","card":card,"owner":0,"target":{"none":true},"name":e.cards[card.card_id].name})
 view.render();await process_frame
 var stacked=e.stack.back().card
 await tap(view.stack_panel.entry_rect(504).get_center())
 expect(view.inspect_uid==stacked.uid and view.inspection.visible,"tapping a resolution stack card opens its rules")
 await shot("android-stack-tap-details")
 reset_details()
 var scroll=view.stack_panel.scroll
 at=scroll.get_global_rect().position+Vector2(44,65)
 await touch(at,true)
 drag_event=InputEventScreenDrag.new();drag_event.index=0;drag_event.position=at-Vector2(0,130);drag_event.relative=Vector2(0,-130)
 root.push_input(drag_event,true);await process_frame;await touch(drag_event.position,false)
 expect(scroll.scroll_vertical>0 and not view.inspection.visible,"swiping stack cards scrolls without opening details")

 clean();reset_details()
 var grave=put("53","grave")
 view.render();view.browse_zone(0,"grave");await process_frame
 await tap(top_art().get_global_rect().get_center())
 expect(view.inspect_uid==grave.uid and view.inspection.visible,"tapping a graveyard browser card opens its rules")

 clean();reset_details()
 var history_art=e.make_card("164",0,"grave")
 var hidden_art=e.make_card("53",1,"hand");hidden_art.hidden=true
 e.history=[
  {"turn":3,"phase":"main","text":"人机使用了一张未公开的卡牌。","art":[hidden_art]},
  {"turn":4,"phase":"main","text":"你横置%s，视为支付了1黄。你选择这点颜色支付当前卡牌的费用，并确认剩余费用；人机收到使用声明后选择响应，双方依次完成目标选择、费用支付和响应处理。" % e.cards[history_art.card_id].name,"art":[history_art]},
  {"turn":4,"phase":"end","text":"回合结束，准备进入下一回合。","art":[]}
 ]
 view.render();view.open_history();await process_frame;await process_frame
 var entries=view.history_panel.find_child("HistoryEntries",true,false)
 var cards=history_cards(entries)
 var text=entries.get_child(1).find_child("HistoryText",true,false)
 var shown=cards[0]
 expect(text.get_global_rect().position.x>=shown.get_global_rect().end.x+19,"history text has a clear gap beside the card art")
 expect(entries.get_child(1).get_global_rect().encloses(text.get_global_rect()),"long history text stays inside its expanding row")
 expect(not entries.get_child(1).get_global_rect().intersects(entries.get_child(2).get_global_rect()),"history rows do not overlap")
 expect(app.ui_metrics.safe.encloses(view.history_panel.get_global_rect()),"history panel stays within the Android safe area")
 expect(view.history_panel.find_child("HistoryTitle",true,false).get_theme_font_size("font_size")>=app.ui_metrics.title,"history heading uses the larger title font")
 await shot("android-history-layout")
 await tap(shown.get_global_rect().get_center())
 expect(view.inspection.visible and view.inspect_id==history_art.card_id and view.inspect_uid==0,"history card tap opens the recorded card snapshot")
 expect(view.ui.get_children().find(view.inspection)>view.ui.get_children().find(view.history_root),"history card details appear above the history panel")
 await shot("android-history-tap-details")
 reset_details()
 await tap(cards[1].get_global_rect().get_center())
 expect(view.inspect_id=="back" and "未公开" in view.inspection_text.get_parsed_text(),"hidden history cards expose only their undisclosed state")
 expect(e.cards[hidden_art.card_id].name not in view.inspection_text.get_parsed_text(),"hidden history inspection does not reveal a card identity")
 view.close_history();reset_details()
 clean();reset_details()
 var hidden_hand=put("164","hand",1)
 view.render();await settle()
 at=view.enemy_nodes[hidden_hand.uid].get_global_rect().get_center()
 await touch(at,true);await create_timer(0.65).timeout;await touch(at,false)
 expect(view.inspect_id=="back" and view.inspect_uid==0,"opponent hand long press preserves hidden information")
 print("ANDROID CARD DETAILS: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
