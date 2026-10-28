extends "res://tests/support/ui_base.gd"

func refresh():
 e.presentation_events.clear();view.reveal_player.reset();view.render()
 await process_frame

func choose_palette(c: Dictionary,label: String):
 expect(view.picker.available_refs().any(func(r):return r.get("uid",-1)==c.uid),label+" offers the current palette card")
 view.object_clicked(c.uid)
 var finish=view.picker.available().filter(func(atom):return atom.kind=="finish_group")
 if not finish.is_empty():view.inline_pick(finish[0])
 expect(view.picker.ready(),label+" completes its card selection")
 view.confirm_trigger()

func check_surface(android: bool):
 app.is_android=android;app.refresh_ui_metrics()
 clean(true);e.debug_free_payment=true
 var label="Android" if android else "PC"
 var source=put("character-rei-023","field");source.entered_turns=0
 var resource=put("164","palette");resource.tapped=true
 var action=e.available_actions(0,source.uid).filter(func(a):return a.get("key","")=="minoriko_untap")[0]
 view.begin_action(action)
 expect(view.picker.ready() and view.picker.available_refs().is_empty(),label+" Minoriko requires no palette selection before activation")
 view.confirm_declaration();await refresh()
 expect(e.pending.is_empty() and e.stack.size()==1 and resource.tapped,label+" activation permits responses before reset")
 resolve();await refresh()
 expect(e.pending.get("trigger",{}).get("effect","")=="palette_reset",label+" opens the palette choice during resolution")
 choose_palette(resource,label+" Minoriko")
 expect(not resource.tapped and e.pending.is_empty() and e.stack.is_empty(),label+" reset completes with no extra stack object")
 clean(true)
 var fairy=put("2","field");resource=put("164","palette");resource.tapped=true
 e.move_to(fairy,"grave");e.pump_choices();await refresh()
 expect(view.picker.available_refs().is_empty(),label+" crystal initially asks only whether to announce")
 view.confirm_trigger();resolve();await refresh()
 expect(e.pending.trigger.get("continuation",false),label+" crystal selection is part of resolution")
 choose_palette(resource,label+" crystal")
 expect(fairy.zone=="palette" and resource.zone=="grave",label+" crystal exchanges the selected palette card")
 clean(true)
 fairy=put("2","field",1);e.detach(fairy);fairy.owner=0;e.players[0].field.append(fairy)
 resource=put("164","palette");resource.tapped=true
 var enemy_resource=put("164","palette",1);enemy_resource.tapped=true
 e.destroy(fairy);e.pump_choices();await refresh()
 expect(view.picker.ready() and view.picker.available_refs().is_empty(),label+" nonowner can still announce crystal")
 view.confirm_trigger()
 expect(e.pending.is_empty() and e.stack.size()==1,label+" nonowner crystal permits the normal response window")
 resolve();await refresh()
 expect(e.pending.is_empty() and e.stack.is_empty(),label+" nonowner crystal finishes without palette selection")
 expect(fairy.zone=="grave" and fairy in e.players[1].grave,label+" nonowner crystal leaves the card in its owner's graveyard")
 expect(resource.zone=="palette" and resource.tapped and enemy_resource.zone=="palette" and enemy_resource.tapped,label+" nonowner crystal preserves both palettes")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/resolution-choices-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 await check_surface(false);await check_surface(true)
 print("RESOLUTION_CHOICES_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
