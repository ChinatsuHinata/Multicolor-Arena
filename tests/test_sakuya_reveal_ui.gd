extends "res://tests/support/ui_base.gd"

func choice_button(node: Node,uid: int):
 if node is Button and node.has_meta("choice_atom"):
  var atom: Dictionary=node.get_meta("choice_atom")
  if atom.get("kind","")=="target" and atom.get("value",{}).get("uid",-1)==uid:return node
 for child in node.get_children():
  var found=choice_button(child,uid)
  if found!=null:return found
 return null

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/sakuya-reveal-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);await process_frame
 view=app.duel_view;view.set_process(false);e=view.engine
 clean()
 var sakuya=put("character-fdf-041","field");sakuya.leader=true
 var instant=put("spell-fdf-055","deck")
 var unit=put("character-soi-006","deck")
 var timed=put("121","deck")
 var trigger={"owner":0,"effect":"character-fdf-041:self","source":sakuya.duplicate(true),"target":{"none":true}}
 e.Cat.Units.resolve(e,trigger)
 view.render();await settle()
 var row=choice_button(view.ui,timed.uid)
 expect(row!=null,"the revealed World card appears as a selectable choice")
 if row!=null:
  row.pressed.emit()
  expect(view.picker.dynamic_state().current.size()==1,"the deck card can be selected")
  var finish=view.picker.available().filter(func(atom):return atom.kind=="finish_group")
  if not finish.is_empty():view.inline_pick(finish[0])
  expect(view.picker.ready(),"the reveal choice can be confirmed")
  view.confirm_trigger()
  expect(timed.zone=="field" and timed.timer==1,"the selected World remains on the battlefield with one timer")
  expect(instant.zone=="grave" and unit.zone=="grave","the other revealed cards go to grave")
 print("SAKUYA_REVEAL_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
