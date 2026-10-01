extends "res://tests/support/ui_base.gd"

func deck_tile(node: Node, zone: String):
 if node.get_script()==load("res://scripts/deck_card.gd") and node.source_zone==zone:return node
 for child in node.get_children():
  var found=deck_tile(child,zone)
  if found:return found
 return null

func touch_double(at: Vector2):
 var event=InputEventScreenTouch.new()
 event.position=at
 event.index=0
 event.pressed=true
 event.double_tap=true
 root.push_input(event,true)
 await process_frame
 event=event.duplicate()
 event.pressed=false
 root.push_input(event,true)
 await process_frame

func touch(index: int,at: Vector2,pressed: bool):
 var event=InputEventScreenTouch.new()
 event.index=index
 event.position=at
 event.pressed=pressed
 root.push_input(event,true)
 await process_frame

func touch_drag(index: int,at: Vector2):
 var event=InputEventScreenDrag.new()
 event.index=index
 event.position=at
 root.push_input(event,true)
 await process_frame

func swipe(from: Vector2,to: Vector2):
 await touch(0,from,true)
 for step in range(1,6):await touch_drag(0,from.lerp(to,float(step)/5.0))
 await touch(0,to,false)

func hold(at: Vector2):
 var event=InputEventMouseButton.new()
 event.position=at
 event.global_position=at
 event.button_index=MOUSE_BUTTON_LEFT
 event.pressed=true
 root.push_input(event,true)
 await create_timer(0.65).timeout
 event=event.duplicate()
 event.pressed=false
 root.push_input(event,true)
 await process_frame

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/test-android-controls/"+str(Time.get_ticks_usec()))
 root.size=Vector2i(1600,900)
 root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.is_android=true
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app.refresh_ui_metrics()
 app.debug_mode=true
 app.setup()
 await process_frame
 expect(not app.debug_mode and find_button(app.screen,"测试模式（手动控制双方）")==null and find_button(app.screen,"无需付费")==null,"Android setup hides and disables offline test mode")
 app.settings()
 expect(find_button(app.screen,"测试模式：允许拖动卡牌放入战场")==null,"Android settings hide test-only drag control")

 var deck=Store.blank("安卓控制测试")
 deck.rule_set="test"
 deck.leader="70"
 deck.main=["100","100"]
 app.decks=[deck]
 app.draft=deck
 app.selected="100"
 app.selected_colors=["红"]
 app.filter_kind="符卡"
 app.library_sort_mode="名字"
 app.editor()
 await process_frame
 expect(find_button(app.screen,"排序")!=null,"Android deck sorting remains available")
 expect(app.screen.find_child("LibrarySearch",true,false)!=null,"Android library search remains available")
 expect(app.color_buttons.is_empty() and app.screen.find_child("LibraryKindFilter",true,false)==null and app.screen.find_child("LibrarySortChoice",true,false)==null,"Android library filter and sort controls are removed")
 expect(app.selected_colors.is_empty() and app.filter_kind=="全部" and app.library_sort_mode=="类别","hidden Android library filters and sort choice reset")
 app.query=Store.CARDS["100"].name
 app.update_library()
 await process_frame
 var tile=deck_tile(app.deck_canvas,"main")
 var row=app.library_rows["100"].row
 expect(tile!=null and tile.is_android and row.is_android,"editor cards use Android input")
 var before=deck.main.duplicate()
 app.selected="70"
 await click(tile.get_global_rect().get_center())
 expect(app.draft.main==before and app.selected==tile.card_id,"Android tap previews a deck card without removing it")
 var leader_tile=deck_tile(app.deck_canvas,"leader")
 await click(leader_tile.get_global_rect().get_center())
 expect(app.draft.leader=="70" and app.get_node_or_null("LeaderPicker")!=null,"Android tap opens leader selection without removing the leader")
 app.get_node("LeaderPicker").queue_free()
 await process_frame
 await click(row.get_global_rect().get_center())
 expect(app.draft.main.size()==before.size()+1,"Android tap adds a library card to the deck")
 tile=deck_tile(app.deck_canvas,"main")
 var held_count=app.draft.main.size()
 await hold(tile.get_global_rect().get_center())
 expect(app.get_node_or_null("CardArtPicker")!=null,"Android long press opens alternate art")
 expect(app.draft.main.size()==held_count,"long press does not remove a deck card")
 if app.get_node_or_null("CardArtPicker")!=null:app.get_node("CardArtPicker").queue_free()
 await process_frame
 await drag(row.get_global_rect().get_center(),app.main_content.get_global_rect().position+Vector2(450,55))
 expect(app.draft.main.size()==before.size()+2,"Android library cards can still be added by dragging")
 tile=deck_tile(app.deck_canvas,"main")
 await drag(tile.get_global_rect().get_center(),row.get_global_rect().get_center())
 expect(app.draft.main.size()==before.size()+1,"Android drag to the library still removes a deck card")
 app.query=""
 app.update_library()
 await process_frame
 var library_scroll=app.library.get_parent() as ScrollContainer
 var library_size=app.draft.main.size()
 var library_start=library_scroll.get_global_rect().position+Vector2(110,260)
 await swipe(library_start,library_start+Vector2(0,-170))
 expect(library_scroll.scroll_vertical>0,"Android swipe scrolls the deck builder library")
 expect(app.draft.main.size()==library_size,"swiping the library does not add a card")
 var preview_scroll=app.preview.find_child("CardTextScroll",true,false) as ScrollContainer
 var extra=Label.new()
 extra.text="卡牌说明\n".repeat(40)
 preview_scroll.get_child(0).add_child(extra)
 await process_frame
 var preview_start=preview_scroll.get_global_rect().position+Vector2(100,220)
 await swipe(preview_start,preview_start+Vector2(0,-150))
 expect(preview_scroll.scroll_vertical>0,"Android swipe scrolls card preview text")
 var rich_scroll=RichTextLabel.new()
 rich_scroll.position=Vector2(340,300)
 rich_scroll.size=Vector2(230,180)
 rich_scroll.scroll_active=true
 rich_scroll.text="聊天记录\n".repeat(60)
 app.screen.add_child(rich_scroll)
 await process_frame
 var rich_start=rich_scroll.get_global_rect().get_center()
 await swipe(rich_start,rich_start+Vector2(0,-100))
 expect(rich_scroll.get_v_scroll_bar().value>0,"Android swipe scrolls text logs")
 rich_scroll.queue_free()
 await process_frame
 var horizontal_scroll=ScrollContainer.new()
 horizontal_scroll.position=Vector2(340,300)
 horizontal_scroll.size=Vector2(230,110)
 horizontal_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var wide_content=Control.new()
 wide_content.custom_minimum_size=Vector2(700,100)
 horizontal_scroll.add_child(wide_content)
 app.screen.add_child(horizontal_scroll)
 await process_frame
 var horizontal_start=horizontal_scroll.get_global_rect().get_center()
 await swipe(horizontal_start,horizontal_start+Vector2(-140,0))
 expect(horizontal_scroll.scroll_horizontal>0,"Android swipe scrolls horizontal card strips")
 horizontal_scroll.queue_free()
 await process_frame
 app.show_deck_tutorial()
 await process_frame
 var tutorial=app.get_node("DeckTutorial")
 var tutorial_text=tutorial.get_node("DeckTutorialText") as RichTextLabel
 var tutorial_start=tutorial_text.get_global_rect().get_center()
 await swipe(tutorial_start,tutorial_start+Vector2(0,-130))
 expect(tutorial_text.get_v_scroll_bar().value>0,"Android swipe scrolls dialog instructions")
 tutorial.hide()
 tutorial.queue_free()
 await process_frame

 app.is_android=false
 app.editor()
 await process_frame
 tile=deck_tile(app.deck_canvas,"main")
 var desktop_count=app.draft.main.size()
 await click(tile.get_global_rect().get_center())
 expect(app.draft.main.size()==desktop_count+1,"desktop left click still copies a deck card")
 tile=deck_tile(app.deck_canvas,"main")
 await click(tile.get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
 expect(app.draft.main.size()==desktop_count,"desktop right click still removes a deck card")
 app.is_android=true
 app.editor()
 await process_frame
 while app.draft.main.size()<70:app.draft.main.append("100")
 app.update_deck_rows()
 await process_frame
 var main_start=app.main_scroll.get_global_rect().get_center()
 await swipe(main_start,main_start+Vector2(0,-170))
 expect(app.main_scroll.scroll_vertical>0,"Android swipe scrolls the main deck area")
 app.open_leader_picker()
 await process_frame
 var leader_layer=app.get_node("LeaderPicker")
 var leader_search=leader_layer.find_child("CardNameSearchPanel",true,false)
 var leader_scroll=leader_search.search_results.get_parent() as ScrollContainer
 var leader_start=leader_scroll.get_global_rect().position+Vector2(110,390)
 await swipe(leader_start,leader_start+Vector2(0,-150))
 expect(leader_scroll.scroll_vertical>0,"Android swipe scrolls card search results")
 leader_layer.queue_free()
 await process_frame

 app.load_legacy_test_decks()
 app.clear_page("battle")
 view=preload("res://scripts/duel_view.gd").new()
 view.is_android=true
 app.duel_view=view
 app.screen.add_child(view)
 view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 view.begin(app,app.decks[app.player_choice],app.decks[app.ai_choice],0,42)
 view.set_process(false)
 e=view.engine
 clean()
 for i in range(16):
  var stacked=e.make_card("100",0,"stack")
  e.stack.append({"id":100+i,"kind":"card","card":stacked,"owner":0,"target":{"none":true},"name":e.cards[stacked.card_id].name})
 view.render()
 await process_frame
 var stack_start=view.stack_panel.scroll.get_global_rect().position+Vector2(100,245)
 await swipe(stack_start,stack_start+Vector2(0,-150))
 expect(view.stack_panel.scroll.scroll_vertical>0,"Android swipe scrolls cards in the stack area")
 expect(e.stack.size()==16,"swiping the stack leaves its cards unchanged")
 for i in range(12):e.history.append({"turn":i+1,"phase":"main","art":[],"text":"测试记录"})
 view.open_history()
 await process_frame
 var history_scroll: ScrollContainer
 for child in view.history_panel.get_children():
  if child is ScrollContainer:history_scroll=child
 var history_start=history_scroll.get_global_rect().position+Vector2(220,640)
 await swipe(history_start,history_start+Vector2(0,-160))
 expect(history_scroll.scroll_vertical>0,"Android swipe scrolls duel history")
 view.close_history()
 await process_frame
 clean()
 view.render()
 var back_button=find_button(view.ui,"后退")
 var tools_menu=view.hud.get_node("BattleToolbar/BattleTools") as Button
 tools_menu.pressed.emit();await process_frame
 var popup=app.menu_popup
 var help_index=-1
 for i in range(popup.actions.size()):
  if popup.actions[i].text=="操作说明":help_index=i
 expect(back_button!=null and find_button(view.ui,"测试说明")==null,"Android battle keeps a back button and no debug controls")
 expect(help_index>=0,"Android battle exposes the operation guide in its menu")
 if help_index>=0:popup.actions[help_index].pressed.emit()
 expect(view.modal and find_button(view.modal_root,"返回对局")!=null,"operation guide opens a closeable dialog")
 await click(find_button(view.modal_root,"返回对局").get_global_rect().get_center())
 expect(not view.modal,"operation guide closes back to the battle")
 await click(back_button.get_global_rect().get_center())
 expect(view.modal,"back opens settings when no selection is active")
 back_button=find_button(view.ui,"后退")
 expect(back_button!=null,"back remains available while settings are open")
 if back_button:await click(back_button.get_global_rect().get_center())
 expect(not view.modal,"back closes the settings dialog")
 await touch(0,Vector2(1540,500),true)
 await touch_drag(0,Vector2(1380,505))
 await touch(0,Vector2(1380,505),false)
 expect(view.modal,"swiping left from the right edge uses back to open settings")
 await touch(0,Vector2(1540,500),true)
 await touch_drag(0,Vector2(1380,505))
 await touch(0,Vector2(1380,505),false)
 expect(not view.modal,"swiping left again closes settings")

 clean()
 view.render()
 await settle()
 var initial_offset=view.table.camera_offset
 await touch(0,Vector2(800,400),true)
 view.camera_touch_started_ms=Time.get_ticks_msec()-view.TOUCH_PAN_HOLD_MS
 await touch_drag(0,Vector2(850,400))
 await touch(0,Vector2(850,400),false)
 expect(view.table.camera_offset!=initial_offset,"Android long press and drag pans the battlefield")
 view.reset_camera_view()
 var initial_distance=view.table.camera_distance
 await touch(0,Vector2(650,380),true)
 await touch(1,Vector2(950,380),true)
 await touch_drag(1,Vector2(1100,380))
 await touch(1,Vector2(1100,380),false)
 await touch(0,Vector2(650,380),false)
 expect(view.table.camera_distance<initial_distance,"Android two-finger spread zooms in")
 var zoomed_distance=view.table.camera_distance
 await touch(0,Vector2(650,380),true)
 await touch(1,Vector2(1100,380),true)
 await touch_drag(1,Vector2(950,380))
 await touch(1,Vector2(950,380),false)
 await touch(0,Vector2(650,380),false)
 expect(view.table.camera_distance>zoomed_distance,"Android two-finger pinch zooms out")
 view.reset_camera_view()

 clean()
 var palette_card=put("100","palette")
 var enemy_palette_card=put("100","palette",1)
 var hand_card=put("100","hand")
 e.phase="possession"
 e.pending={"kind":"possession","owner":0}
 view.render()
 await settle()
 var own_palette_toggle=find_button(view.hud,"我方颜色盘")
 var enemy_palette_toggle=find_button(view.hud,"敌方颜色盘")
 expect(own_palette_toggle!=null and enemy_palette_toggle!=null and view.android_palette_owner==0 and is_instance_valid(view.android_palette_panel),"Android possession automatically opens the central own palette")
 expect(view.android_palette_panel.get_global_rect().has_point(Vector2(800,450)) and view.android_palette_tiles.has(palette_card.uid),"the central palette contains a selectable own card")
 e.pending={};view.render()
 expect(view.android_palette_owner==-1,"the automatically opened palette closes when possession ends")
 e.pending={"kind":"possession","owner":0};view.render()
 expect(view.android_palette_owner==0,"a new possession choice opens the palette again")
 enemy_palette_toggle=find_button(view.hud,"敌方颜色盘")
 var enemy_toggle_point=enemy_palette_toggle.get_global_rect().get_center()
 await touch(0,enemy_toggle_point,true)
 await touch(0,enemy_toggle_point,false)
 expect(view.android_palette_owner==1 and view.android_palette_tiles.has(enemy_palette_card.uid) and not view.android_palette_tiles.has(palette_card.uid),"the enemy palette button switches the central contents")
 await click(view.android_palette_tiles[enemy_palette_card.uid].get_global_rect().get_center())
 expect(view.selected_in_zone("palette")==0,"an enemy palette card cannot be chosen for possession")
 own_palette_toggle=find_button(view.hud,"我方颜色盘")
 await click(own_palette_toggle.get_global_rect().get_center())
 var central_palette_point=view.android_palette_tiles[palette_card.uid].get_global_rect().get_center()
 await touch(0,central_palette_point,true)
 await touch(0,central_palette_point,false)
 expect(view.selected_in_zone("palette")==palette_card.uid,"the central palette card selects the possession source")
 expect(not view.inspection.visible,"short palette tap selects without opening details")
 central_palette_point=view.android_palette_tiles[palette_card.uid].get_global_rect().get_center()
 await touch(0,central_palette_point,true)
 await create_timer(0.65).timeout
 expect(view.inspection.visible and view.inspect_uid==palette_card.uid,"long palette press opens card details")
 await touch(0,central_palette_point,false)
 expect(view.selected_in_zone("palette")==palette_card.uid,"long palette press keeps the selected source")
 await click(find_button(view.inspection,"关闭详情").get_global_rect().get_center())
 own_palette_toggle=find_button(view.hud,"我方颜色盘")
 await click(own_palette_toggle.get_global_rect().get_center())
 expect(view.android_palette_owner==-1 and not is_instance_valid(view.android_palette_panel),"tapping the active palette button closes the panel")
 var palette_point=point(palette_card.uid)
 expect(view.table.card_at(palette_point)==palette_card.uid,"palette card is reachable by touch ray")
 expect(view.touch_camera_available(palette_point),"possession palette card remains touchable below the camera pan area")
 await touch(0,palette_point,true)
 await touch(0,palette_point,false)
 expect(view.selected_in_zone("palette")==palette_card.uid,"one Android tap keeps the possession palette card selected")
 await click(find_button(view.inspection,"关闭详情").get_global_rect().get_center())
 await touch(0,palette_point,true)
 await touch(0,palette_point,false)
 expect(view.selected_in_zone("palette")==palette_card.uid,"repeated palette tap does not clear the possession choice")
 await click(find_button(view.inspection,"关闭详情").get_global_rect().get_center())
 view.table.set_top_down_view(true)
 view.render()
 await settle()
 expect(view.touch_camera_available(point(palette_card.uid)),"possession palette card is touchable in top-down view")
 view.table.set_top_down_view(false)
 view.render()
 await settle()
 own_palette_toggle=find_button(view.hud,"我方颜色盘")
 await click(own_palette_toggle.get_global_rect().get_center())
 expect(view.android_palette_owner==0 and view.android_palette_tiles.has(palette_card.uid),"the palette can reopen during possession")
 var hand_point=view.hand_nodes[hand_card.uid].get_global_rect().get_center()
 await click(hand_point)
 expect(view.selected_in_zone("palette")==palette_card.uid and view.selected_in_zone("hand")==hand_card.uid,"possession keeps the palette choice while selecting a hand card")
 var possession_confirm=find_button(view.hud,"确定凭依")
 var possession_skip=find_button(view.hud,"跳过凭依")
 expect(possession_confirm!=null and possession_confirm.get_global_rect().size.x>=218 and not possession_confirm.get_global_rect().intersects(possession_skip.get_global_rect()),"Android possession buttons are large and separate")
 expect(not possession_confirm.disabled,"Android possession confirmation enables after both cards are chosen")
 await click(possession_confirm.get_global_rect().get_center())
 expect(palette_card.zone=="hand" and hand_card.zone=="palette","Android possession exchanges the selected cards")
 expect(view.android_palette_owner==0,"a manually reopened palette remains visible after possession")

 clean()
 view.android_palette_owner=-1
 view.android_palette_auto_open=false
 view.android_palette_was_possession=false
 var payment_card=put("165","palette")
 var payment_spell=put("spell-fdn-029","hand")
 view.render()
 await click(find_button(view.hud,"我方颜色盘").get_global_rect().get_center())
 view.local={"uid":payment_spell.uid,"action":"choice_payment","choice_cost":{"红":1},"mode":"payment","target":{},"plan":[]}
 view.refresh_payment_plan()
 view.render()
 expect(view.payment_sources().any(func(source):return source.uid==payment_card.uid),"the central palette exposes a color payment source")
 expect(view.android_palette_owner==0 and view.android_palette_tiles.has(payment_card.uid),"the palette stays open while preparing payment")
 var before_payment=view.local.plan.size()
 if view.android_palette_tiles.has(payment_card.uid):await click(view.android_palette_tiles[payment_card.uid].get_global_rect().get_center())
 expect(view.local.plan.size()!=before_payment,"tapping the palette card changes the payment reservation")
 view.local={}
 payment_card.tapped=true
 e.pending={"kind":"effect_choice","owner":0,"options":[e.ref_target(payment_card)],"trigger":{"effect":"crystal","optional":false}}
 view.render()
 expect(view.android_palette_tiles.has(payment_card.uid),"the palette remains available for effect targeting")
 if view.android_palette_tiles.has(payment_card.uid):await click(view.android_palette_tiles[payment_card.uid].get_global_rect().get_center())
 expect(view.picker.ready() and view.picker.option().get("uid",0)==payment_card.uid,"an effect such as crystal can select a tapped palette card through the central panel")
 view.local={};e.pending={}
 for i in range(9):put("165","palette")
 view.render()
 await process_frame
 var palette_scroll=view.android_palette_scroll
 expect(palette_scroll.get_h_scroll_bar().max_value>palette_scroll.size.x,"a crowded palette can scroll horizontally")
 var palette_drag_start=palette_scroll.get_global_rect().position+Vector2(minf(760,palette_scroll.size.x-40),palette_scroll.size.y*0.5)
 await touch(0,palette_drag_start,true)
 await touch_drag(0,palette_drag_start+Vector2(-410,0))
 await touch(0,palette_drag_start+Vector2(-410,0),false)
 expect(palette_scroll.scroll_horizontal>0,"Android dragging scrolls the central palette")
 await click(back_button.get_global_rect().get_center())
 expect(view.android_palette_owner==-1,"Android back closes an open palette")
 view.toggle_android_palette(0)
 await touch(0,Vector2(1540,500),true)
 await touch_drag(0,Vector2(1380,505))
 await touch(0,Vector2(1380,505),false)
 expect(view.android_palette_owner==-1 and not view.modal,"Android edge swipe backs out of the open palette")

 clean()
 var choice_source=put("53","field")
 var choices=[]
 for i in range(12):choices.append({"mode":"选项 %d" % i})
 e.pending={"kind":"effect_choice","owner":0,"options":choices,"trigger":{"effect":"android-scroll-layout","optional":true,"source":choice_source}}
 view.render()
 await process_frame
 var choice_panel=view.android_choice_panel
 var choice_scroll=choice_panel.get_node("BattleChoiceScroll")
 var choice_confirm=find_button(view.hud,"确定")
 var choice_decline=find_button(view.hud,"不使用")
 expect(view.host.ui_metrics.safe.grow(1).encloses(choice_panel.get_global_rect()) and choice_panel.get_global_rect().end.x<view.SIDEBAR.position.x,"Android choices use available height and stay outside the right rail")
 expect(choice_scroll.size.y>=170 and not choice_scroll.get_global_rect().intersects(choice_confirm.get_global_rect()),"Android choice list is tall and clear of confirm")
 expect(not choice_confirm.get_global_rect().intersects(choice_decline.get_global_rect()) and not choice_decline.get_global_rect().intersects(back_button.get_global_rect()),"Android choice, decline and back buttons do not overlap")
 await click(find_button(choice_panel,"隐藏").get_global_rect().get_center())
 expect(not is_instance_valid(view.android_choice_panel) and is_instance_valid(view.android_choice_restore),"Android ability menu can be hidden without discarding the choice")
 await click(view.android_choice_restore.get_global_rect().get_center())
 expect(is_instance_valid(view.android_choice_panel),"Android ability menu can be reopened")
 await click(find_button(view.hud,"我方颜色盘").get_global_rect().get_center())
 expect(is_instance_valid(view.android_choice_panel) and is_instance_valid(view.android_palette_panel) and not view.android_choice_panel.get_global_rect().intersects(view.android_palette_panel.get_global_rect()),"ability menu and palette can be open together")
 choice_scroll=view.android_choice_panel.get_node("BattleChoiceScroll")
 var swipe_start=choice_scroll.get_global_rect().position+Vector2(80,135)
 await touch(0,swipe_start,true)
 for step in range(1,5):
  var drag_event=InputEventScreenDrag.new()
  drag_event.index=0
  drag_event.position=swipe_start+Vector2(0,-30*step)
  drag_event.relative=Vector2(0,-30)
  root.push_input(drag_event,true)
  await process_frame
 await touch(0,swipe_start+Vector2(0,-120),false)
 expect(choice_scroll.scroll_vertical>0,"Android swipe scrolls the upper choice menu")

 clean()
 view.android_palette_owner=-1
 var multi_a=put("100","hand")
 var multi_b=put("165","hand")
 e.pending={"kind":"effect_choice","owner":0,"options":[{"selection_id":"android-multi","selection":[{"pool":[e.ref_target(multi_a),e.ref_target(multi_b)],"min":1,"max":2,"title":"选择手牌"}]}],"trigger":{"effect":"android-multi","optional":false}}
 view.render()
 await process_frame
 expect(is_instance_valid(view.android_choice_panel) and view.android_choice_panel.get_meta("region_picker",false),"Android card multiselect uses the upper popup")
 expect(view.host.ui_metrics.safe.grow(1).encloses(view.android_choice_panel.get_global_rect()) and view.android_choice_panel.get_global_rect().end.x<view.SIDEBAR.position.x,"card multiselect fits safe area and leaves right controls clear")
 await click(find_button(view.android_choice_panel,"隐藏").get_global_rect().get_center())
 expect(is_instance_valid(view.android_choice_restore) and e.pending.kind=="effect_choice","card multiselect can be hidden without canceling it")
 await click(find_button(view.hud,"我方颜色盘").get_global_rect().get_center())
 await click(view.android_choice_restore.get_global_rect().get_center())
 expect(is_instance_valid(view.android_choice_panel) and is_instance_valid(view.android_palette_panel),"card multiselect reopens alongside the palette")
 await click(view.region_tiles[multi_a.uid].get_global_rect().get_center())
 await click(view.region_tiles[multi_b.uid].get_global_rect().get_center())
 var region_confirm=view.android_choice_panel.find_child("RegionConfirm",true,false) as Button
 expect(not region_confirm.disabled and view.region_batch.size()==2,"card multiselect tracks two selected cards")
 await click(region_confirm.get_global_rect().get_center())
 expect(view.picker.ready() and view.picker.option().get("picks",[]).size()==1,"card multiselect confirms the batch")

 clean()
 view.android_palette_owner=-1
 var original_card_53=e.cards["53"]
 e.cards["53"]=e.cards["53"].duplicate(true)
 e.cards["53"].abilities.append({"实现":"activated_damage","名称":"测试能力","参数":{"数值":1,"费用":{},"横置":false}})
 var action_unit=put("53","field")
 view.render()
 view.open_actions(action_unit)
 expect(view.action_menu_open and is_instance_valid(view.android_choice_panel) and not view.modal,"Android card abilities open in a nonmodal popup")
 expect(view.android_choice_panel.get_global_rect().end.y<=view.host.ui_metrics.safe.get_center().y+8 and view.android_choice_panel.get_global_rect().end.x<view.SIDEBAR.position.x,"card ability popup stays in the upper area")
 await click(find_button(view.hud,"我方颜色盘").get_global_rect().get_center())
 expect(view.action_menu_open and is_instance_valid(view.android_choice_panel) and is_instance_valid(view.android_palette_panel),"card abilities remain open when the palette opens")
 await click(find_button(view.android_choice_panel,"隐藏").get_global_rect().get_center())
 expect(view.action_menu_open and is_instance_valid(view.android_choice_restore),"card ability popup can be hidden")
 await click(view.android_choice_restore.get_global_rect().get_center())
 expect(is_instance_valid(view.android_choice_panel),"card ability popup can be reopened")
 e.cards["53"]=original_card_53

 clean()
 view.android_palette_owner=-1
 var attacker=put("53","field")
 view.render()
 await settle()
 var attacker_point=point(attacker.uid)
 await touch(0,attacker_point,true)
 await touch(0,attacker_point,false)
 expect(view.attack_preview_uid==attacker.uid,"single tap still previews an attack")
 await click(back_button.get_global_rect().get_center())
 expect(view.attack_preview_uid==0,"back cancels the attack preview")
 await touch_double(point(attacker.uid))
 expect(e.combat.get("attacker",{}).get("uid",0)==attacker.uid,"double tapping an attackable unit declares its attack")

 clean()
 e.active=1
 e.priority=0
 view.response_mode=view.ResponseMode.ON
 view.render()
 var revision=e.revision
 await touch_double(Vector2(700,400))
 expect(e.revision>revision and e.priority==1,"double tapping empty battlefield passes a response window")

 print("ANDROID CONTROLS: ",checks," checks; failures=",failures.size())
 app.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)
