extends "res://tests/test_v010_ui.gd"
func capture(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v011/"+name+".png")
func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 clean(true);var spell=put("107","hand");var discard_card=put("107","hand");put("164","palette");put("165","palette");put("165","palette")
 view.render();await settle();var before=snapshot();await click(view.hand_nodes[spell.uid].get_global_rect().get_center())
 expect(view.region_picker_needed() and view.region_tiles.has(discard_card.uid) and not view.region_tiles.has(spell.uid),"additional discard shows other hand card, excludes source copy")
 await capture("discard-selection")
 await click(Vector2(320,100),MOUSE_BUTTON_RIGHT);expect(snapshot()==before and view.local.is_empty(),"cancel additional cost leaves all cards and payment private")
 clean(true);spell=put("124","hand");var unit=put("50","field");put("166","palette");for i in range(4):put("164","palette")
 view.render();await settle();await click(view.hand_nodes[spell.uid].get_global_rect().get_center());await press("X = 2");view.choose_target(e.ref_target(unit));await press("发动")
 expect(spell.zone=="stack" and e.players[0].palette.all(func(c):return c.tapped),"UI confirms X two using one green and four yellow")
 resolve();view.render();await settle();expect(unit.plus_counters==2,"UI X spell resolves with two counters")
 clean(true);var alice=put("77","field");alice.leader_counters=1;alice.entered_turns=0;unit=put("50","field");var grave=put("51","grave");put("164","palette");put("165","palette")
 view.render();await settle();var actions=e.available_actions(0,alice.uid);view.execute_action(actions.filter(func(a):return a.get("key")=="alice_recycle")[0]);view.choose_target(e.ref_target(unit));await finish_group();await settle()
 expect(view.region_picker_needed() and view.region_tiles.has(grave.uid),"second Alice ability opens grave selection after sacrifice choice")
 var atom=view.region_atoms().filter(func(a):return a.value.uid==grave.uid)[0];view.select_region_atom(atom);view.confirm_region_atom();await settle();await finish_group();await press("发动")
 expect(not e.stack.is_empty() and e.stack.back().effect=="alice_recycle" and unit.zone=="grave","UI commits chosen second ability and its sacrifice cost")
 resolve();view.render();await settle();expect(grave.zone=="deck","second ability resolves selected grave card to deck bottom")
 clean(true);var satori=put("76","field");satori.leader_counters=1;satori.entered_turns=0;var hidden=put("51","hand",1)
 var act=e.available_actions(0,satori.uid).filter(func(a):return a.get("key")=="satori_discard")[0];view.execute_action(act);view.choose_target({"player":1});await press("发动");resolve();view.render();await settle()
 expect(view.region_picker_needed() and view.region_tiles.has(hidden.uid),"Satori shows opponent hand art only for authorized hand inspection")
 await capture("satori-hand-choice")
 atom=view.region_atoms().filter(func(a):return a.value.uid==hidden.uid)[0];view.select_region_atom(atom);view.confirm_region_atom();await settle();await finish_group();await press("确定");expect(hidden.zone=="grave","Satori UI completes chosen discard")
 clean(true);alice=put("77","field");var token=e.Roster.copy_idol(e,0,alice);view.render();await settle();view.inspect_card(token.card_id,token.uid)
 expect(app.texture(token.card_id)!=null and e.cards[token.card_id].rules_text==e.cards["77"].rules_text,"copied token preserves art and inspectable abilities")
 await capture("copied-unit")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"UI verification preserves saved decks")
 print("V011_UI: %d checks; %d failures" % [checks,failures.size()]);quit(0 if failures.is_empty() else 1)
