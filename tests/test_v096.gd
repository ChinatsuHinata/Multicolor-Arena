extends "res://tests/test_v092.gd"
func capture(name: String):
 if DisplayServer.get_name()=="headless": return
 view.update_badge_positions(); view.banner.visible=false
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v096-"+name+".png")
func centered(title: String):
 expect(view.modal and view.modal_root.get_child(0).get_global_rect().get_center().distance_to(Vector2(800,450))<1,title)
func tab(zone: String,who: int=0):
 var button=view.hand_zone_tabs.get(str(who)+":"+zone)
 expect(button!=null,"region tab: "+zone)
 if button: await click(button.get_global_rect().get_center()); await settle()
func wait_damage():
 var limit=Time.get_ticks_msec()+4500
 while view.table.combat_animating and not view.table.damage_revealed and Time.get_ticks_msec()<limit: await process_frame
 expect(view.table.damage_revealed,"collision publishes damage numbers before departures")
func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 app=load("res://main.tscn").instantiate(); root.add_child(app); await process_frame
 app.load_legacy_test_decks(); app.begin_battle(true); view=app.duel_view; view.set_process(false); e=view.engine
 expect(not view.inspection.visible and not view.debug_open,"preview and region browser start closed")
 clean(); view.render(); await settle()
 expect(view.hand_zone_tabs.is_empty(),"no region tabs without usable off-hand cards")
 expect(not view.table.piles.pexile.visible and not view.table.piles.aexile.visible,"empty exile zones are hidden")
 for i in range(24): put("53" if i%2==0 else "54","grave")
 for i in range(15): put("53","deck",1)
 var ex=put("54","exile",1)
 view.render(); await settle(); await click(pile_point("grave"))
 expect(view.debug_open and view.browser_cards is GridContainer and view.browser_cards.columns==2,"surface pile opens a two-column grid")
 expect(view.browser_cards.get_child_count()==24 and view.browser_cards.get_child(0).get_child_count()==1,"grid has all cards without duplicate descriptions")
 expect(view.browser_cards.get_child(7).position.y+view.browser_cards.get_child(7).size.y<view.browser_scroll.size.y,"four full rows of two cards fit in sidebar")
 await capture("pile-grid")
 await click(pile_point("deck",1))
 expect(view.browser_owner==1 and view.browser_zone=="deck" and view.browser_cards.get_children().all(func(n): return n.get_meta("display_id")=="back"),"opponent deck pile switches sidebar and hides identities")
 await click(pile_point("exile",1))
 expect(view.browser_zone=="exile" and view.table.piles.aexile.visible,"nonempty opposing exile pile can be inspected")
 expect(view.table.MAT_SLOTS.exile.y>view.table.MAT_SLOTS.leader.y and view.table.MAT_SLOTS.exile.x==view.table.MAT_SLOTS.leader.x,"exile occupies the space below leader")
 await click(Vector2(900,700),MOUSE_BUTTON_RIGHT); expect(not view.debug_open,"outside right click closes region grid")
 # Okuu deck spells live in a cancellable hand tab, not a blocking modal.
 clean(); var okuu=put("78","field"); var spell=put("162","deck")
 for id in ["165","166","168"]: put(id,"palette")
 for who in [0,1]:
  for i in range(12): put("53","deck",who)
 view.render(); await settle(); await tab("deck")
 expect(view.hand_nodes.has(spell.uid) and view.hand_nodes.size()==1 and not view.modal,"deck tab reveals only the usable deck spell")
 var before=snapshot(); await click(view.hand_nodes[spell.uid].get_global_rect().get_center())
 expect(view.local.get("uid")==spell.uid,"deck-tab card starts normal private declaration")
 await click(Vector2(950,700),MOUSE_BUTTON_RIGHT)
 expect(view.local.is_empty() and not view.modal and snapshot()==before,"deck spell can be cancelled without trapping the turn")
 await capture("deck-tab")
 await tab("hand"); await click(pile_point("deck")); await press("结束主要阶段")
 view.fast_mode=true
 for i in range(3): view._process(1)
 expect((e.phase!="main" or e.active!=0) and view.debug_open,"an open deck inspection does not prevent Okuu turn progression: "+e.phase)
 view.close_debug(); e.phase="main"; e.active=0; e.priority=0; e.passes=0; e.pending={}; view.render(); await settle()
 await tab("deck"); await click(view.hand_nodes[spell.uid].get_global_rect().get_center())
 view.choose_target({"player":1}); await press("确定"); resolve(); view.render(); await settle()
 expect(spell.zone=="grave" and e.players[1].life==17 and not view.hand_zone_tabs.has("0:deck"),"Okuu deck spell resolves and exhausted tab disappears")
 expect(view.hand_zones[0]=="hand" and not view.modal,"missing region action automatically restores hand")
 # Grave actions use the same region tab and payment flow.
 clean(); var mokou=put("rec_unit_097","grave"); put("165","palette")
 view.render(); await settle(); await tab("grave"); await click(view.hand_nodes[mokou.uid].get_global_rect().get_center())
 expect(view.local.get("action")=="extension","grave tab can activate a grave ability by clicking its face")
 await press("确定")
 if view.local.get("mode")=="payment_offer": await press("自动支付")
 resolve(); view.render(); await settle()
 expect(mokou.zone=="hand" and not view.hand_zone_tabs.has("0:grave"),"grave ability completes and tab disappears")
 # Manual hybrid payments preserve private rollback.
 clean(); var nue=put("soi_unit_086","hand"); var flexible=put("soi_unit_086","palette"); var mana=[]
 for id in ["165","167","166","168"]: mana.append(put(id,"field"))
 view.auto_pay=false; view.render(); await settle(); before=snapshot()
 await click(view.hand_nodes[nue.uid].get_global_rect().get_center()); await press("确定")
 expect(view.local.get("mode")=="payment","hybrid unit starts manual payment")
 view.reserve_resource(flexible.uid)
 expect(view.local.get("colors")==["红","蓝","绿","黑"],"four-color palette card offers every legal payment color")
 await press("绿"); view.reserve_resource(mana[0].uid); view.reserve_resource(mana[1].uid); view.reserve_resource(mana[3].uid)
 expect(e.payment_valid(0,view.local_cost(),view.local.plan) and "红/蓝/绿 3 / 3" in view.local_prompt(),"manual RGB pool counts mixed payments together")
 await capture("hybrid-payment")
 await click(Vector2(900,700),MOUSE_BUTTON_RIGHT)
 expect(view.local.is_empty() and snapshot()==before,"cancelling hybrid payment restores all private reservations")
 view.auto_pay=true
 # Every choice panel uses the same center, including image selectors.
 clean(); var actor=put("71","field"); actor.leader_counters=1; view.render(); await settle(); view.open_actions(actor); centered("multi-action panel centered")
 view.close_overlay(); var source=put("18","field"); put("53","grave")
 e.Extra.event(e,source,"enter_grave_damage",true); e.pump_choices(); view.render(); centered("region card selector centered"); view.close_overlay()
 clean(); actor=put("53","field"); e.queue_trigger(0,actor,1,"甲"); e.queue_trigger(0,actor,1,"乙"); e.pump_choices(); view.render(); centered("simultaneous trigger choices centered")
 view.close_overlay(); clean(); var a=put("54","field"); var blockers=[put("53","field",1),put("53","field",1),put("53","field",1)]
 e.attack(0,a.uid); resolve(); e.block(blockers.map(func(c): return c.uid)); resolve(); view.render(); centered("multi-block damage allocation centered")
 await capture("damage-allocation-centered")
 view.close_overlay(); clean(); e.surrender(1); view.render(); centered("end-of-game panel centered")
 # Direct debug dragging from actual hand/world meshes, not just browser entries.
 clean(true); var c=put("53","hand"); var top=put("54","deck")
 view.render(); await settle(); await drag(view.hand_nodes[c.uid].get_global_rect().get_center(),pile_point("deck")); await settle()
 expect(c.zone=="deck" and e.players[0].deck[0].uid==c.uid,"direct hand drag puts card on deck top")
 await click(pile_point("deck")); await drag(top_art().get_global_rect().get_center(),Vector2(700,780)); await settle(); view.close_debug()
 expect(c.zone=="hand","deck browser drag adds card to actual hand")
 await drag(view.hand_nodes[c.uid].get_global_rect().get_center(),view.project(Vector3(0,0,2.5))); await settle()
 expect(c.zone=="field" and e.stack.is_empty() and e.triggers.is_empty(),"direct hand-to-field debug drag is silent")
 await drag(point(c.uid),pile_point("deck")); await settle()
 expect(c.zone=="deck" and e.players[0].deck[0].uid==c.uid,"world permanent can be dragged directly to deck top")
 e.debug_move(c.uid,"hand"); view.render(); await settle()
 view.begin_debug_drag(c.uid,view.hand_nodes[c.uid].get_global_rect().get_center())
 var motion=InputEventMouseMotion.new(); motion.position=pile_point("exile"); motion.global_position=motion.position
 view.handle_debug_drag(motion)
 expect(view.debug_dragging and view.debug_drop_hint.position.y<0 and view.debug_drop_hint.text=="放入除外区","debug destination hint is above the moving card")
 await capture("debug-destination")
 view.finish_debug_drag(false); await settle()
 expect(c.zone=="exile" and view.table.piles.pexile.visible,"dragging into empty exile creates its visible zone")
 e.debug_move(c.uid,"hand"); view.render(); expect(not view.table.piles.pexile.visible,"exile zone disappears after its final card leaves")
 # First-strike negative health holds for a full second, then removes every casualty.
 clean(); a=put("53","field"); var first=put("54","field",1); first.modifiers=[{"先制":true}]
 view.table.animation_duration=0.1; view.render(); await settle()
 e.attack(0,a.uid); resolve(); e.block([first.uid]); view.render(); await settle(); resolve(); view.render()
 expect(view.table.combat_animating and view.table.visuals.has("card_"+str(a.uid)),"lethal attacker remains visible for damage presentation")
 await wait_damage()
 expect(view.card_badges["card_"+str(a.uid)].values.health.text=="-3","lethal negative health is displayed without clamping")
 await capture("first-strike-negative-health"); before=snapshot(); view._process(10); await click(Vector2(1450,795))
 expect(snapshot()==before,"damage hold blocks passing and clicks even in fast mode")
 await create_timer(0.6).timeout; expect(view.table.combat_animating and view.table.visuals.has("card_"+str(a.uid)),"damage remains visible after 0.6 seconds")
 await create_timer(0.55).timeout
 expect(not view.table.combat_animating and not view.table.visuals.has("card_"+str(a.uid)) and view.table.visuals.has("card_"+str(first.uid)),"dead attacker leaves after one second and first striker remains")
 resolve(); view.render(); expect(e.combat.is_empty() and first.damage==0,"dead attacker cannot perform a normal strike")
 clean(); a=put("54","field"); a.modifiers=[{"先制":true}]; blockers=[put("53","field",1),put("53","field",1),put("53","field",1)]
 view.render(); await settle(); e.attack(0,a.uid); resolve(); e.block(blockers.map(func(x): return x.uid)); resolve(); view.render()
 e.combat_damage({str(blockers[0].uid):2,str(blockers[1].uid):2,str(blockers[2].uid):1}); view.render(); await wait_damage()
 expect(blockers.slice(0,2).all(func(x): return view.table.visuals.has("card_"+str(x.uid))),"all simultaneous first-strike casualties stay visible during hold")
 await create_timer(1.15).timeout
 expect(blockers.slice(0,2).all(func(x): return not view.table.visuals.has("card_"+str(x.uid))),"all first-strike casualties leave together")
 var batch=e.combat.damage_batch; resolve(); view.render(); await wait_damage()
 expect(e.combat.damage_batch>batch and view.card_badges["card_"+str(a.uid)].values.health.text=="3","surviving normal blocker creates a separate second damage animation")
 await create_timer(1.15).timeout; resolve(); view.render(); expect(e.combat.is_empty(),"both first-strike and normal windows fully finish")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"live saved decks unchanged")
 var report="%d checks; %d failures\n%s" % [checks,failures.size(),"\n".join(failures)]
 FileAccess.open("res://work/v096-ui-tests.txt",FileAccess.WRITE).store_string(report)
 print("V096_UI: "+report); quit(0 if failures.is_empty() else 1)
