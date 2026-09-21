extends "res://tests/test_v010_ui.gd"
func capture(name:String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v012/"+name+".png")
func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 clean(true);var spell=put("spell-htk-003","hand");put("character-htk-001","field");put("164","field");put("167","field");put("167","palette");put("166","palette");put("164","palette")
 var grave=put("50","grave");view.render();await settle();await click(view.hand_nodes[spell.uid].get_global_rect().get_center())
 expect(view.picker.available().any(func(a):return a.kind=="mode" and a.value=="移回手牌"),"emotion first mode available before choosing target")
 await press("移回手牌");await settle()
 expect(view.region_picker_needed() and view.region_tiles.has(grave.uid),"emotion recovery opens grave art selection")
 var atom=view.region_atoms().filter(func(a):return a.value.uid==grave.uid)[0];view.select_region_atom(atom);view.confirm_region_atom();await settle();await finish_group()
 await press("造成1点伤害");view.choose_target({"player":1});await finish_group();await settle();await capture("emotions-confirm")
 expect(view.picker.ready(),"emotion second mode is independently chosen")
 await press("确定")
 if view.local.get("mode")=="payment_offer":await press("自动支付")
 expect(spell.zone=="stack","mode spell enters stack after confirmation")
 resolve();view.render();await settle();expect(grave.zone=="hand" and e.players[1].life==19,"UI resolves recovery and player damage")
 clean(true);var unit=put("character-lof-001","field");unit.leader_counters=1;unit.courage=3;view.render();await settle();view.inspect_card(unit.card_id,unit.uid)
 expect(view.inspection_text.get_parsed_text().contains("勇气等级：3"),"counter amount visible in inspection")
 expect(e.available_actions(0,unit.uid).filter(func(a):return a.type=="extension").size()==2,"Cirno exposes two separate abilities")
 await capture("courage-preview")
 clean(true);unit=put("87","field");e.Extra.on_enter(e,unit);e.pump_choices();resolve();view.render();await settle()
 var tokens=e.units(0).filter(func(u):return u.card_id=="token_halfghost")
 expect(tokens.size()==1,"Youmu creates actual runtime halfghost")
 if not tokens.is_empty():
  view.inspect_card("token_halfghost",tokens[0].uid);await settle()
  expect(app.texture("token_halfghost")==app.texture("token-ucs-099"),"runtime halfghost uses replaced canonical artwork")
  await capture("halfghost-replaced")
 clean(true);unit=put("character-htk-001","field");unit.leader_counters=1;e.Roster.on_phase(e,"prepare");e.pump_choices();view.render();await settle()
 view.choose_target({"player":1});await press("确定");resolve();view.render();await settle()
 expect(e.pending.get("owner",-1)==0 and view.picker.available().any(func(a):return a.value=="怒"),"Kokoro leader allows player mood choice")
 await press("怒");await press("确定");view.render();await settle()
 expect(e.players[0].field.any(func(c):return c.card_id=="token-htk-032"),"mood UI creates supplied mask token")
 await capture("mask-created")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"UI keeps saved decks unchanged")
 print("V012_UI: %d checks; %d failures" % [checks,failures.size()]);quit(0 if failures.is_empty() else 1)
