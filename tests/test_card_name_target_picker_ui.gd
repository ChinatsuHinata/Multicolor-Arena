extends "res://tests/support/ui_base.gd"

func target_panel() -> Node:
 return view.android_choice_panel if is_instance_valid(view.android_choice_panel) else null

func selected_text(node: Node) -> String:
 if node==null:return ""
 var result=node.text if node is Label else ""
 for child in node.get_children():result+="\n"+selected_text(child)
 return result

func choose_counter(index: int) -> bool:
 for atom in view.picker.available():
  if int(atom.get("value",{}).get("counter_index",-1))==index:
   view.object_clicked(atom.value.uid)
   return view.picker.selected_refs().any(func(ref):return int(ref.get("counter_index",-1))==index)
 return false

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/card-name-target-picker-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.debug_mode=true;app.begin_battle(true);await process_frame
 view=app.duel_view;view.set_process(false);e=view.engine
 clean(true)
 var source=put("character-fdf-111","grave")
 var item=put("164","palette")
 item.poverty=17
 var actions=e.available_actions(0,source.uid,true).filter(func(action):return action.type=="extension" and action.key=="character-fdf-111")
 expect(actions.size()==1 and actions[0].enabled,"Soga no Tojiko grave ability is available with 17 poverty counters")
 if actions.is_empty() or not actions[0].enabled:quit(1);return
 view.begin_action(actions[0])
 var panel=target_panel()
 expect(panel!=null and panel.has_node("BoardTargetPrompt"),"17 real counter targets open the right battlefield selection prompt")
 expect(panel.find_children("ChoiceTile*","Button",true,false).is_empty(),"counter targets are not menu items")
 expect(view.picker.available_refs().size()==17,"all 17 distinct counter references are available on the battlefield")
 if panel==null:quit(1);return
 expect(choose_counter(0),"clicking the palette card selects its first available counter")
 panel=target_panel()
 expect(panel!=null and panel.has_node("BoardTargetPrompt"),"the right prompt remains open for the remaining 16 counters")
 expect(not panel.get_meta("centered",false),"target prompt stays on the right after rerender")
 expect(view.picker.available_refs().size()==16,"the second step offers the remaining 16 distinct counters")
 if panel==null:quit(1);return
 var selected=panel.get_node("BoardTargetPrompt")
 expect(e.cards[item.card_id].name in selected_text(selected),"the selected card is named in the right prompt")
 expect(item.poverty==17,"selecting counter targets does not pay the cost before confirmation")
 expect(choose_counter(1),"the second counter is selectable")
 expect(choose_counter(2),"the third counter is selectable")
 expect(view.picker.dynamic_state().current.size()==3,"the exact three counter references are selected")
 var finish=view.picker.available().filter(func(atom):return atom.kind=="finish_group")
 expect(finish.size()==1,"the counter group can be completed")
 if not finish.is_empty():view.inline_pick(finish[0])
 expect(view.picker.ready(),"the card picker preserves the original three-counter choice")
 view.confirm_declaration()
 expect(item.poverty==14,"activation removes exactly three poverty counters")
 expect(not e.stack.is_empty(),"the original grave ability enters the stack")
 if not e.stack.is_empty():resolve()
 expect(source.zone=="field","the original effect returns Soga no Tojiko to the field")
 print("CARD_NAME_TARGET_PICKER_UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
