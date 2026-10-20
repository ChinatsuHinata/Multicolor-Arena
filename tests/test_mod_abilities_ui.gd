extends "res://tests/support/ui_base.gd"
const Registry=preload("res://scripts/rules/mod_registry.gd")
const Codec=preload("res://net/state_codec.gd")

func refresh():
 e.presentation_events.clear();view.reveal_player.reset();view.render();await process_frame

func surface(android: bool):
 app.is_android=android;app.refresh_ui_metrics();clean(true)
 var label="Android" if android else "PC"
 var c=put("example.cards/grave_blast","field");c.entered_turns=0
 var hand=put("164","hand");put("165","palette")
 var action=e.available_actions(0,c.uid).filter(func(a):return a.get("key","").begins_with("mod:"))[0]
 var before=Codec.capture(e)
 view.begin_action(action);await refresh()
 expect(view.picker.available_refs().any(func(ref):return ref.get("uid",-1)==hand.uid),label+" common picker offers discard cost")
 expect(view.payment_excluded().has(c.uid),label+" payment UI excludes source reserved for tap cost")
 view.local={};view.picker.reset();view.close_overlay();await refresh()
 expect(Codec.capture(e)==before,label+" cancelling action draft preserves complete game state")
 view.begin_action(action);await refresh()
 expect(view.picker.select_target({"uid":hand.uid,"epoch":hand.epoch,"zone":"hand"}),label+" select cost card")
 view.render()
 for atom in view.picker.available():
  if atom.kind=="finish_group":view.inline_pick(atom);break
 view.picker.select_target({"player":1});view.render()
 expect(view.picker.ready(),label+" common target specification reaches confirmation")
 view.confirm_declaration();await refresh()
 expect(e.stack.size()==1 and c.tapped and hand.zone=="grave",label+" UI commits cost and ability")
 resolve();await refresh();expect(e.players[1].life==18,label+" UI activation resolves")
 clean(true)
 c=put("example.cards/top_three","hand")
 for id in ["164","165","166"]:put(id,"deck")
 expect(e.commit_cast(0,c.uid,{"none":true},[]).is_empty(),label+" cast multistep spell")
 resolve();await refresh()
 expect(view.picker.available_refs().size()==3,label+" private top-three choice rendered by common picker")
 var selected=e.pending.options[0].duplicate(true)
 view.picker.select_target(selected);view.render();view.confirm_trigger();await refresh()
 expect(e.find_card(selected.uid).zone=="hand" and e.pending.options.size()==2,label+" UI resumes into ordering step")
 view.picker.select_target(e.pending.options.back());view.render();view.confirm_trigger();await refresh()
 expect(e.mod_resolution.is_empty() and e.find_card(c.uid).zone=="grave",label+" UI completes resumed spell")

func run():
 Registry._shared=Registry.new()
 expect(Registry.shared().register_pack("res://mods/example.cards").is_empty(),"load example pack")
 Store.CARDS=Store.Database.load_cards()
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/mod-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();app.tutorial_local_directory=Store.Paths.root_override.path_join("tutorials");root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 await surface(false);await surface(true)
 print("MOD_ABILITIES_UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
