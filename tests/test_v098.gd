extends "res://tests/test_v092.gd"
func capture(name: String):
 if DisplayServer.get_name()=="headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v098-"+name+".png")
func escape():
 var event=InputEventKey.new(); event.keycode=KEY_ESCAPE; event.pressed=true
 root.push_input(event,true); await process_frame
 event=event.duplicate(); event.pressed=false; root.push_input(event,true); await process_frame
func closed(title: String):
 expect(not view.debug_open and not view.observing and not is_instance_valid(view.debug_root) and not view.debug_button.button_pressed,title)
func wait_combat():
 var limit=Time.get_ticks_msec()+6000
 while view.table.combat_animating and Time.get_ticks_msec()<limit: await process_frame
 expect(not view.table.combat_animating,"combat presentation completes")
func youmu():
 var c=e.players[0].leader; c.card_id="87"; e.shift(c,"field"); e.players[0].field.append(c); c.entered_turns=0
 return c
func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 app=load("res://main.tscn").instantiate(); root.add_child(app); await process_frame
 app.load_legacy_test_decks(); app.debug_mode=true; app.begin_battle(true); view=app.duel_view; view.set_process(false); e=view.engine
 clean(true); put("53","hand"); put("54","deck"); put("53","deck",1)
 view.render(); await settle(); var before=snapshot()
 expect(is_instance_valid(view.debug_button) and not view.debug_button.button_pressed,"debug button exists and starts unpressed")
 for i in range(3):
  await press("调试")
  expect(view.debug_open and view.debug_button.button_pressed,"debug click opens and highlights toggle")
  await press("调试"); closed("second click returns to duel")
 expect(snapshot()==before,"repeated debug toggles never mutate duel state")
 await press("调试"); await capture("debug-open"); await press("×"); closed("explicit close returns to duel")
 await press("调试"); await escape(); closed("Escape returns to duel")
 await press("调试"); await press("观察战场")
 expect(view.observing and not view.debug_root.visible,"debug browser can be temporarily observed")
 await press("调试"); closed("debug button remains clickable during observation")
 expect(snapshot()==before,"observation toggle does not advance priority")
 # Closing the browser restores an unfinished private declaration.
 clean(true); var card=put("53","hand"); var resource=put("164","palette");
 view.render(); await settle(); await click(view.hand_nodes[card.uid].get_global_rect().get_center())
 expect(view.local.get("mode")=="target" and view.payment_ready(),"normal click prepares a payable declaration in debug mode")
 view.render(); before=snapshot(); var private_before=view.local.duplicate(true)
 await press("调试"); await press("观察战场"); await press("调试"); closed("close from observation restores payment controls")
 expect(view.local==private_before and snapshot()==before and not resource.tapped,"recommended payment survives closing debug and remains private")
 var confirm=find_button(view.ui,"发动")
 expect(confirm!=null and confirm.is_visible_in_tree(),"activation is visible after returning")
 await press("发动"); expect(card.zone=="stack" and resource.tapped,"normal payment completes after debug exit")
 resolve(); view.render(); await settle(); expect(card.zone=="field" and e.stack.is_empty(),"normal card resolves after debug exit")
 # Mandatory target selection cannot be skipped or discarded by the toggle.
 clean(true); var sunny=put("1","field"); e.Extra.event(e,sunny,"enter_haste",false); e.pump_choices(); view.render(); await settle()
 before=snapshot(); await press("调试"); await press("观察战场"); await press("调试"); closed("close debug restores mandatory targeting")
 expect(snapshot()==before and e.stack.size()==1 and e.stack[0].get("awaiting_target",false),"mandatory effect and pending target are preserved")
 view.choose_target(e.ref_target(sunny)); await press("确定"); resolve(); view.render(); await settle()
 expect(e.has_haste(sunny) and e.pending.is_empty() and e.stack.is_empty(),"mandatory target can complete after debug exit")
 # Modal choices remain required and can be continued after closing debug.
 clean(true); var actor=put("71","field"); actor.entered_turns=0; actor.leader_counters=1; put("53","field")
 view.render(); await settle(); view.open_actions(actor)
 expect(view.modal,"multi-action dialog is open")
 await press("调试"); await press("观察战场"); await press("调试"); closed("close debug restores modal actions")
 expect(view.modal and is_instance_valid(view.modal_root) and view.modal_root.visible,"modal choice is visible and not silently cancelled")
 view.close_overlay(); view.render(); await settle()
 # Both manually controlled sides can advance normal phases after the toggle.
 clean(true)
 for who in [0,1]:
  for i in range(8): put("53","deck",who)
 view.fast_mode=true; view.render(); await settle(); await press("调试"); await press("调试"); await press("结束主要阶段")
 view._process(1)
 expect(e.phase=="end" and not view.debug_open,"player can end main phase after closing debug")
 for i in range(4): view._process(1)
 expect(e.active==1 and view.acting_player()==1,"next player's debug turn remains playable")
 await press("调试"); await press("调试"); closed("opposing turn debug browser also toggles closed")
 expect(view.debug_mode and e.debug_enabled,"closing browser preserves manual control of both players")
 await capture("returned-to-duel")
 # Visual timing uses the same real engine ordering as the rule tests.
 clean(true); var a=youmu(); var b=put("54","field",1); view.render(); await settle()
 e.attack(0,a.uid); resolve(); e.block([b.uid]); view.render(); await settle(); resolve(); view.render()
 expect(view.table.combat_animating and b.damage==2 and a.damage==0,"Youmu first strike starts its own damage presentation")
 await wait_combat(); await capture("youmu-exile-stack")
 expect(e.stack.size()==1 and e.stack[0].effect=="combat_exile_target" and view.table.visuals.has("card_"+str(b.uid)),"surviving defender remains visible while exile is on the stack")
 resolve(); view.render(); await settle(); resolve(); view.render(); await settle()
 expect(b.zone=="exile" and not view.table.visuals.has("card_"+str(b.uid)) and a.damage==0 and e.combat.is_empty(),"resolved exile removes defender and ends combat without retaliation")
 clean(true); a=youmu(); b=put("23","field",1); view.render(); await settle()
 e.attack(0,a.uid); resolve(); e.block([b.uid]); view.render(); await settle(); resolve(); view.render()
 expect(b.zone=="grave" and view.table.combat_animating,"lethal hit is judged before the death presentation finishes")
 await wait_combat(); await capture("youmu-death-trigger")
 expect(e.stack.size()==2 and not view.table.visuals.has("card_"+str(b.uid)),"dead defender leaves visually with its death trigger queued")
 resolve(); view.render(); await settle(); resolve(); view.render(); await settle(); resolve(); view.render()
 expect(b.zone=="grave" and e.players[0].life==18 and e.players[1].life==21 and e.combat.is_empty(),"death ability resolves and graveyard victim is never exiled")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"live saved decks unchanged")
 print("V098_UI: ",checks," checks; ",failures," failures"); quit(0 if failures.is_empty() else 1)
