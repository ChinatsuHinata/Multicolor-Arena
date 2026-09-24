extends "res://tests/test_v014_ui.gd"
func capture(name:String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v015/"+name+".png")
func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 clean()
 var c=put("50","hand");put("165","palette");put("166","palette");put("167","palette");e.players[0].next_free_unit=e.turn
 view.render();await settle();await click(view.hand_nodes[c.uid].get_global_rect().get_center());await process_frame
 expect(view.local.get("mode")=="free_offer","click eligible card asks paid/free before declaration")
 await capture("payment-choice")
 await press("支付颜色使用");expect(e.paid_cast_uid==c.uid and view.local.mode=="target","paid mode retains target confirmation")
 await click(Vector2(800,20),MOUSE_BUTTON_RIGHT);expect(view.local.is_empty() and e.paid_cast_uid==-1 and c.zone=="hand" and e.players[0].palette.all(func(u):return not u.tapped),"right click cancels paid mode privately")
 view.request_cast(c.uid);await press("不支付颜色使用");view.confirm_declaration();await settle()
 expect(c.zone=="stack" and e.players[0].palette.all(func(u):return not u.tapped),"free choice enters stack without spending colors")
 expect(view.reveal_player.movements.any(func(ev):return ev.uid==c.uid and ev.from=="hand" and ev.to=="stack"),"hand to stack movement presented")
 resolve();view.render();await settle();expect(c.zone=="field" and view.table.visuals["card_"+str(c.uid)].visible,"stack to field restores visible object")
 clean();c=put("50","hand")
 for i in range(4):put("165","palette")
 e.Cat.grant_cast(e,c,0,true);view.render();await settle()
 await press("支付颜色使用");expect(view.picker.ready(),"effect-granted ordinary unit retains confirm target after payment choice")
 await press("确定");expect(view.local.get("action")=="choice_payment","effect grant enters private paid selection")
 view.cancel_cast();expect(e.paid_cast_uid==-1 and not e.pending.trigger.data.has("payment_chosen"),"cancel effect payment restores paid/free prompt")
 await press("不支付颜色使用");await press("确定");await press("发动");await settle()
 expect(c.zone=="stack" and e.players[0].palette.all(func(u):return not u.tapped),"effect-granted ordinary unit free choice commits without colors")
 clean();c=put("3","hand");e.detach(c);e.enter_field(c,0);e.pump_choices();view.render();await settle()
 expect(e.pending.get("kind")=="effect_choice" and e.stack.size()==1,"targetless optional ETB remains on visible stack")
 await capture("optional-trigger-no-target")
 view.confirm_trigger();resolve();view.render();await settle();expect(e.pending.is_empty() and e.stack.is_empty(),"targetless optional confirmation returns to playable state")
 clean();c=put("character-lof-001","field");c.entered_turns=3;view.render();await settle()
 expect(view.table.visuals["card_"+str(c.uid)].get_node("SummoningMist").visible,"new non-haste unit initially shows mist")
 e.apply_turn_buff(e.ref_target(c),{"疾行":true});e.active=1;e.priority=0;view.render();await settle()
 expect(not view.table.visuals["card_"+str(c.uid)].get_node("SummoningMist").visible,"gaining haste immediately removes mist")
 expect(c.uid in view.highlights() and e.has_response(0),"opponent-turn activated ability remains interactive")
 clean();c=put("50","hand",1);var own=put("51","deck");view.render();await settle()
 e.move_to(c,"deck");e.move_to(c,"grave");e.move_to(c,"exile");e.move_to(c,"hand");e.move_to(own,"deck");view.render();await settle()
 var moves=view.reveal_player.movements
 expect(moves.size()==5 and moves[0].hidden and not moves[1].hidden and moves[4].hidden,"all intermediate moves animate and hidden deck/hand paths stay private")
 expect(view.enemy_nodes.is_empty() and view.hud.get_children().any(func(n):return n is Label and n.text=="手牌 1"),"opposing hand count recovers after public move")
 clean();c=put("96","hand",1);view.render();await settle()
 var started=Time.get_ticks_msec();e.reveal_card(c);view.render();await finish_reveals()
 var elapsed=(Time.get_ticks_msec()-started)/1000.0
 expect(view.reveal_player.completed.size()==1 and view.reveal_player.REVEAL_SECONDS==0.5,"half-second flip completes")
 print("REVEAL_WALL_SECONDS: ",elapsed)
 expect(view.enemy_nodes.is_empty() and view.reveal_player.public_uids.is_empty(),"temporary hand reveal returns to count-only display")
 e.flip_coin(0);view.render();await create_timer(0.25).timeout
 expect(view.revealing() and is_instance_valid(view.reveal_player.result_label),"coin result stays visible")
 await capture("coin-result");await settle()
 expect(view.reveal_player.results.size()==1 and e.history.any(func(row):return "掷硬币" in row.text),"result playback completes and history remains")
 expect(saved==FileAccess.get_file_as_string(Store.SAVE_PATH),"UI leaves saved decks unchanged")
 print("V015_UI: ",checks," checks; ",failures," failures");quit(0 if failures.is_empty() else 1)
