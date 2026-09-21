extends "res://tests/test_v092.gd"
func capture(name: String):
 if DisplayServer.get_name()=="headless": return
 view.update_badge_positions(); view.banner.visible=false
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v095-"+name+".png")
func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 app=load("res://main.tscn").instantiate(); root.add_child(app); await process_frame
 app.load_legacy_test_decks(); app.begin_battle(true); view=app.duel_view; view.set_process(false); e=view.engine
 clean(); var unit=put("53","hand"); var yellow=put("164","palette")
 var leader=put("71","field"); put("170","palette"); put("78","field",1)
 for i in range(9): put(["53","54","91","rec_unit_097"][i%4],"grave")
 for i in range(3): put("53","exile",1)
 view.render(); await settle(); var before=snapshot()
 await click(view.hand_nodes[unit.uid].get_global_rect().get_center())
 expect(view.local.get("uid")==unit.uid and view.local.get("mode")=="target" and unit.uid in view.selected_uids(),"single hand click opens a gold private declaration without dragging")
 expect(snapshot()==before and not yellow.tapped,"single click does not pay or publish")
 await click(Vector2(1000,700),MOUSE_BUTTON_RIGHT)
 expect(view.local.is_empty() and snapshot()==before,"right click cancels click declaration without spending resources")
 await click(view.hand_nodes[unit.uid].get_global_rect().get_center()); await press("确定")
 expect(unit.zone=="stack" and yellow.tapped,"confirmed click declaration pays and enters stack")
 resolve(); view.render(); await settle(); view.inspect_card("71",leader.uid)
 expect(not view.inspection_text.get_meta("leader_enabled"),"ordinary copy of leader card has grey leader ability")
 var shrine=put("170","field"); view.render()
 expect(view.inspection_text.get_meta("leader_enabled"),"shrine enables the preview's leader ability color")
 e.move_to(shrine,"grave"); view.render()
 expect(not view.inspection_text.get_meta("leader_enabled"),"removing shrine greys the ability again")
 leader.leader_counters=1; view.render()
 expect(e.has_leader_ability(leader) and view.inspection_text.get_meta("leader_enabled"),"leader counter enables rules and preview together")
 var hexes=view.table.visuals["card_"+str(leader.uid)].get_node("ColorHexes")
 expect(hexes.get_child_count()==e.cards[leader.card_id].colors.size(),"field permanent has one hex per printed color")
 var palette=e.players[0].palette.back()
 expect(view.table.visuals["card_"+str(palette.uid)].get_node("ColorHexes").get_child_count()==2,"palette multicolor card shows both colors")
 expect(view.STAGE.position.x>=view.inspection.position.x+view.inspection.size.x and view.STAGE.end.x<view.SIDEBAR.position.x,"battlefield fits between compressed preview and dedicated sidebar")
 await settle(); view.update_badge_positions()
 expect(not view.card_badges["card_"+str(unit.uid)].stats.get_global_rect().intersects(view.card_badges["card_"+str(leader.uid)].stats.get_global_rect()),"adjacent unit stat labels do not overlap in compressed battlefield")
 await capture("centered-field")
 view.settings_menu(); var panel=view.modal_root.get_child(0)
 expect(panel.get_global_rect().get_center().distance_to(Vector2(800,450))<1,"settings dialog is centered")
 await capture("settings-centered"); await press("继续游戏")
 await click(pile_point("grave")); await process_frame
 expect(view.debug_open and view.browser_zone=="grave" and view.browser_cards.get_child_count()>=9,"grave pile opens the compact side panel")
 expect(view.browser_cards.get_child(0).custom_minimum_size.y<=120,"sidebar presents several cards and text in one screen")
 await capture("grave-sidebar")
 await click(pile_point("exile",1)); await process_frame
 expect(view.browser_zone=="exile" and view.browser_owner==1,"clicking a different pile switches the same sidebar")
 await click(Vector2(1010,696),MOUSE_BUTTON_RIGHT)
 expect(not view.debug_open,"right click outside dismisses sidebar")
 # Topmost log pauses the complete flow, including private casting and pending choices.
 before=snapshot(); view.open_history(); await process_frame
 expect(view.history_open and view.ui.get_child(view.ui.get_child_count()-1)==view.history_root,"history is above all other UI")
 await click(Vector2(1450,795)); view._process(5)
 expect(view.history_open and snapshot()==before,"clicking outside the log cannot advance the duel")
 await capture("history")
 await click(Vector2(1010,690),MOUSE_BUTTON_RIGHT)
 expect(not view.history_open and snapshot()==before,"outside right click closes log without changing duel")
 # Grave recovery selects a card image and confirms that region choice first.
 clean(); var source=put("18","field"); var dead=put("53","grave"); put("54","grave")
 e.Extra.event(e,source,"enter_grave_damage",true); e.pump_choices(); view.render(); await settle()
 expect(view.modal and view.modal_root.get_child(0).has_meta("region_picker"),"grave target automatically opens a card-image region window")
 expect(view.region_tiles.size()==2 and not view.picker.ready(),"region selector includes each legal physical card")
 before=snapshot(); await click(view.region_tiles[dead.uid].get_global_rect().get_center())
 expect(view.region_selected.value.uid==dead.uid and snapshot()==before,"region card selection is private and does not resolve effect")
 await capture("grave-target-window")
 var confirm=view.modal_root.find_child("RegionConfirm",true,false); await click(confirm.get_global_rect().get_center())
 expect(not view.modal and view.picker.selected_refs()[0].uid==dead.uid,"region confirm advances to the on-field target step")
 view.choose_target({"player":1}); await press("确定"); resolve()
 expect(dead.zone=="hand" and e.players[1].life==19,"compound grave recovery keeps correct selected card and player damage")
 # An own grave activation also begins by clicking the card, with no separate button.
 clean(); var mokou=put("rec_unit_097","grave"); put("165","palette")
 view.render(); view.browse_zone(0,"grave"); await process_frame
 await click(top_art().get_global_rect().get_center())
 expect(view.local.get("action")=="extension" and view.local.uid==mokou.uid,"clicking a legal grave card opens ability declaration")
 expect(view.debug_open and top_art().get_theme_stylebox("panel").border_color==Color("#ffd65c"),"clicked grave ability source stays visibly selected in gold")
 await press("确定"); resolve(); expect(mokou.zone=="hand","new Mokou grave ability returns itself to hand")
 # Hidden draws stay unnamed and face down in the opponent's normal-mode history.
 clean(); var hidden=put("91","deck",1); e.draw(1); view.render(); view.open_history(); await process_frame
 var tiles=view.history_root.find_children("*","Control",true,false).filter(func(n): return n.has_meta("history_display_id"))
 expect(tiles.any(func(n): return n.get_meta("history_display_id")=="back") and not tiles.any(func(n): return n.get_meta("history_display_id")=="91"),"normal history hides opponent draw identities")
 view.close_history()
 for i in range(180): e.note("记录测试 %d" % i)
 expect(e.history.size()>180 and e.log.size()==160,"full history is retained separately from the short status log")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"player deck file unchanged")
 var report="%d checks; %d failures\n%s" % [checks,failures.size(),"\n".join(failures)]
 FileAccess.open("res://work/v095-tests.txt",FileAccess.WRITE).store_string(report)
 print("V095_TEST: "+report); quit(0 if failures.is_empty() else 1)
