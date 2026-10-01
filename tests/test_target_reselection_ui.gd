extends "res://tests/support/ui_base.gd"

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/castle-reselect-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);await process_frame
 view=app.duel_view;view.set_process(false);e=view.engine
 clean()
 var castle=put("field-smm-004","field")
 var unit=put("character-soi-006","field",1)
 var trigger={"owner":0,"effect":"castle_exile","source":castle.duplicate(true),"extended":true,"optional":false,"name":e.cards[castle.card_id].name}
 e.pending={"kind":"effect_choice","owner":0,"trigger":trigger,"options":e.Pack.trigger_options(e,trigger)}
 view.render();await settle()
 view.object_clicked(unit.uid)
 expect(view.picker.selected_refs().size()==1,"castle target is selected")
 var reset=find_button(view.ui,"重选")
 expect(reset!=null,"the reset button is available")
 if reset!=null:reset.pressed.emit()
 expect(view.picker.selected_refs().is_empty(),"reset clears the selected target")
 view.object_clicked(unit.uid)
 var confirm=find_button(view.ui,"确定")
 expect(view.picker.selected_refs().size()==1 and view.picker.selected_refs()[0].uid==unit.uid,"the same unit can be selected again")
 expect(confirm!=null and not confirm.disabled,"the reselected target can be confirmed")
 var target=view.picker.option()
 expect(e.Pack.choice_valid(e,e.pending.options,target) and target.picks[0][0].uid==unit.uid,"the reselected choice is legal for the castle")
 if confirm!=null and not confirm.disabled:confirm.pressed.emit()
 expect(e.pending.is_empty() and e.stack.any(func(entry):return entry.target.get("picks",[]).size()==1 and entry.target.picks[0][0].uid==unit.uid),"confirm submits the reselected target")

 clean()
 var own_units=[put("character-soi-006","field"),put("53","field"),put("74","field")]
 var tewi=put("character-rec-096","field")
 trigger={"owner":0,"effect":"tewi_counters","source":tewi.duplicate(true),"extended":true,"optional":false,"name":e.cards[tewi.card_id].name}
 e.pending={"kind":"effect_choice","owner":0,"trigger":trigger,"options":e.Pack.trigger_options(e,trigger)}
 view.render();await settle()
 for chosen in own_units:view.object_clicked(chosen.uid)
 confirm=find_button(view.ui,"确定")
 expect(confirm!=null and not confirm.disabled,"a full three-target selection can be confirmed")
 reset=find_button(view.ui,"重选")
 if reset!=null:reset.pressed.emit()
 for chosen in own_units:view.object_clicked(chosen.uid)
 confirm=find_button(view.ui,"确定")
 expect(confirm!=null and not confirm.disabled and view.picker.option().picks[0].size()==3,"three targets remain confirmable after reset")
 print("TARGET_RESELECTION_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
