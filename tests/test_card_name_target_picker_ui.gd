extends "res://tests/support/ui_base.gd"

func target_panel() -> Node:
 if not is_instance_valid(view.modal_root):return null
 return view.modal_root.find_child("CardNameSearchPanel",true,false)

func target_rows() -> Array:
 var panel=target_panel()
 if panel==null:return []
 var results=panel.find_child("SearchResults",true,false)
 if results==null:return []
 return results.get_children().filter(func(child):return child is Button)

func selected_text(node: Node) -> String:
 if node==null:return ""
 var result=node.text if node is Label else ""
 for child in node.get_children():result+="\n"+selected_text(child)
 return result

func choose_counter(index: int) -> bool:
 for row in target_rows():
  var entry: Dictionary=row.get_meta("entry",{})
  var atom: Dictionary=entry.get("payload",{})
  if int(atom.get("value",{}).get("counter_index",-1))==index:
   row.pressed.emit()
   return true
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
 expect(panel!=null,"17 real counter targets open the shared three-column card search")
 expect(view.ui.get_child(view.ui.get_child_count()-1)==view.observe_button and view.ui.get_child(view.ui.get_child_count()-2)==view.modal_root and view.observe_button.z_index>view.modal_root.z_index and view.modal_root.z_index>view.debug_controls.z_index,"only observe battlefield stays above target search")
 expect(target_rows().size()==17,"all 17 distinct counter references are offered")
 if panel==null:quit(1);return
 expect(choose_counter(0),"the first counter is selectable through the search warehouse")
 panel=target_panel()
 expect(panel!=null,"the three-column picker remains open for the remaining 16 counters")
 expect(view.ui.get_child(view.ui.get_child_count()-1)==view.observe_button and view.ui.get_child(view.ui.get_child_count()-2)==view.modal_root,"target search remains above other controls after rerender")
 expect(target_rows().size()==16,"the second step offers the remaining 16 distinct counters")
 if panel==null:quit(1);return
 var selected=panel.find_child("SelectedCard",true,false)
 expect(selected!=null and e.cards[item.card_id].name in selected_text(selected),"the selected card is shown in the center")
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
