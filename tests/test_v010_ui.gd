extends "res://tests/test_v092.gd"
func capture(name: String):
 if DisplayServer.get_name()=="headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v010-"+name+".png")
func finish_group():
 var choices=view.picker.available().filter(func(a): return a.kind=="finish_group")
 expect(not choices.is_empty(),"dynamic group can be finished")
 if not choices.is_empty():
  var modal_confirm=view.modal_root.find_child("RegionConfirm",true,false) if is_instance_valid(view.modal_root) else null
  if modal_confirm and view.region_selected.is_empty(): await click(modal_confirm.get_global_rect().get_center())
  else: await press(choices[0].value)
func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 app=load("res://main.tscn").instantiate(); root.add_child(app); await process_frame
 expect(app.decks[app.player_choice].id=="precon_reimu_v1" and app.decks[app.ai_choice].id=="precon_marisa_v1","saved precons are selected after a fresh launch")
 app.load_test_decks()
 expect(app.decks[app.player_choice].name=="预组-灵梦" and app.decks[app.ai_choice].name=="预组-魔理沙","test loader selects the two photo precons")
 expect(Store.validate(app.decks[app.player_choice],true,str(app.decks[app.player_choice].rule_set)).is_empty() and app.decks[app.player_choice].main.size()==50,"test precons use normal strict deck validation")
 app.draft=app.decks[app.player_choice].duplicate(true); app.selected=app.draft.leader; app.dirty=false; app.editor(); await settle()
 expect(app.library_ids().has("token-ucs-099") and app.library.get_children().all(func(n):return Store.CARDS[n.card_id].constructible or not n.draggable),"tokens visible but read-only in normal editor library")
 expect(app.textures.size()<=48,"editor does not preload all 132 oversized textures")
 expect(app.counts.text.contains("50"),"Reimu precon displays all fifty main cards")
 await capture("precon-reimu")
 app.draft=app.decks[app.ai_choice].duplicate(true); app.selected=app.draft.leader; app.editor(); await settle(); await capture("precon-marisa")
 app.begin_battle(true); view=app.duel_view; view.set_process(false); e=view.engine
 expect(e.players[0].deck.size()==46 and e.players[1].deck.size()==46,"both precons start with four cards and 46 in library")
 expect(not view.debug_open and view.inspect_id.is_empty(),"new precon starts with pile browser and preview closed")
 await settle(); await capture("precon-opening")
 # Ordered multi-target selection and cancellation stay private until payment.
 clean(true); put("character-rei-001","field"); put("170","field"); put("field-rei-003","field")
 var spell=put("spell-rei-002","hand"); var enemy=put("54","field",1)
 var red=put("165","palette"); put("165","palette"); put("164","palette")
 view.render(); await settle(); var before=snapshot()
 await click(view.hand_nodes[spell.uid].get_global_rect().get_center())
 expect(view.local.get("mode")=="target" and not view.picker.ready(),"Spread starts ordered target choice")
 view.choose_target({"player":1}); view.choose_target(e.ref_target(enemy)); await settle(); await finish_group()
 expect(view.picker.ready() and e.stack.is_empty() and not red.tapped,"two chosen targets are still private")
 await click(Vector2(330,100),MOUSE_BUTTON_RIGHT)
 expect(view.local.is_empty() and snapshot()==before,"right click cancels multi-target declaration without mutation")
 await click(view.hand_nodes[spell.uid].get_global_rect().get_center())
 view.choose_target({"player":1}); view.choose_target(e.ref_target(enemy)); await finish_group(); await press("发动")
 expect(spell.zone=="stack" and e.stack.back().target.picks[0].size()==2,"confirm publishes selected targets and pays once")
 await settle(); expect(view.stack_target_arrows().size()==2,"stack draws arrows to both declared targets")
 await capture("spread-stack"); resolve(); view.render(); await settle()
 expect(e.players[1].life==19 and enemy.damage==2,"selected target order controls actual damage")
 # A search is a card-art region choice and can choose zero cards without trapping input.
 clean(true); var search=put("spell-mar-002","deck"); put("99","deck"); var actor=put("character-mar-ex","field")
 e.Pack.event(e,actor,"marisa_search",true); e.pump_choices(); view.render(); await settle(); await press("确定")
 resolve(); view.render(); await settle()
 expect(e.pending.get("kind")=="effect_choice" and e.pending.trigger.get("continuation",false) and view.region_picker_needed(),"search opens region window during resolution")
 expect(view.region_tiles.has(search.uid),"Master Spark alias appears as a valid search result")
 await capture("search-cards")
 var atom=view.region_atoms().filter(func(a): return a.value.uid==search.uid)[0]
 view.select_region_atom(atom); view.confirm_region_atom(); await settle()
 expect(not e.pending.is_empty() and search.zone=="deck","selection still awaits complete group confirmation")
 await press("完成选择（1）"); await press("确定"); view.render(); await settle()
 expect(search.zone=="hand" and e.pending.is_empty(),"region search choice fully resolves and returns control")
 e.Pack.event(e,actor,"marisa_search",true); e.pump_choices(); view.render(); await settle(); await press("确定")
 resolve(); view.render(); await settle(); await finish_group(); await press("确定")
 expect(e.pending.is_empty(),"optional search can finish with zero cards")
 # X choice uses the same private cost flow and is cancellable.
 clean(true); put("character-soi-006","field"); spell=put("character-fdf-ex03","hand")
 for id in ["166","166","164","164"]: put(id,"palette")
 view.render(); await settle(); await click(view.hand_nodes[spell.uid].get_global_rect().get_center()); await press("X = 2")
 expect(view.picker.ready() and view.picker.option().x==2,"Byakuren X is an explicit player choice")
 await press("发动"); expect(spell.zone=="stack" and spell.cast_x==2,"X payment is committed with the card")
 resolve(); view.render(); await settle(); resolve(); view.render(); await settle()
 expect(spell.zone=="field" and spell.plus_counters==2 and e.players[0].life==22,"X enters with counters and its life trigger resolves")
 # Opposing exile access appears in own hand-area exile tab.
 clean(true); actor=put("character-fdf-ex05","field"); actor.leader_counters=1
 spell=put("164","exile",1); spell.devour_owner=0; put("164","palette"); put("164","palette")
 view.render(); await settle(); expect("exile" in view.available_hand_zones(0),"Keine access creates own exile action tab")
 view.hand_zones[0]="exile"; view.render(); await settle()
 expect(view.hand_nodes.has(spell.uid),"opponent-owned devoured card is selectable from own action row")
 await click(view.hand_nodes[spell.uid].get_global_rect().get_center()); await press("发动")
 expect(spell.zone=="stack" and spell.owner==0,"borrowed card follows ordinary confirmation flow")
 # Multiple field actions include direct attack instead of forcing player attack.
 clean(true); actor=put("character-fdf-ex01","field"); actor.leader_counters=1; actor.entered_turns=0
 enemy=put("54","field",1); view.render(); await settle()
 var actions=e.available_actions(0,actor.uid)
 expect(actions.any(func(a): return a.type=="direct_attack") and actions.any(func(a): return a.type=="attack"),"Flandre offers both player and unit attack")
 view.execute_action(actions.filter(func(a): return a.type=="direct_attack")[0]); view.choose_target(e.ref_target(enemy)); await press("发动")
 expect(e.combat.get("direct",false) and e.combat.blockers[0].uid==enemy.uid,"unit attack target is committed through battlefield selection")
 await capture("direct-attack")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"UI verification leaves saved decks unchanged")
 print("V010_UI: %d checks; %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
