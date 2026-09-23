extends "res://tests/test_v082.gd"
const Store=preload("res://scripts/deck_store.gd")

func press_q(echoed: bool=false):
 var event=InputEventKey.new()
 event.keycode=KEY_Q
 event.physical_keycode=KEY_Q
 event.unicode=113
 event.pressed=true
 event.echo=echoed
 root.push_input(event,true)
 await process_frame
 event=event.duplicate()
 event.pressed=false
 event.echo=false
 root.push_input(event,true)
 await process_frame

func ready_response(available: bool):
 stack_fixture(available)
 view.reveal_player.reset()
 e.presentation_events.clear()
 view.set_response_mode(view.ResponseMode.ON)
 await process_frame

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/test-response-shortcut/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.load_legacy_test_decks()
 app.begin_battle(true)
 view=app.duel_view
 view.set_process(false)
 view.fast_mode=true
 e=view.engine
 await ready_response(true)
 expect(find_button(view.ui,"不响应 / 继续")!=null,"response pass button is available")
 var before=snapshot()
 var revision=e.revision
 await press_q(true)
 expect(snapshot()==before,"key repeat does not pass priority")
 await press_q()
 expect(e.priority==1 and e.stack.size()==1 and e.revision==revision+1,"Q passes the response once without resolving the stack")

 await ready_response(false)
 expect(find_button(view.ui,"不响应 / 继续")!=null,"full response mode presents an empty response window")
 await press_q()
 expect(e.priority==1,"Q passes an empty full-response window")

 await ready_response(true)
 before=snapshot()
 view.settings_menu()
 await press_q()
 expect(snapshot()==before,"Q does not pass behind a settings dialog")
 view.close_overlay()
 view.render()
 var input=LineEdit.new()
 view.ui.add_child(input)
 input.grab_focus()
 await process_frame
 await press_q()
 expect(snapshot()==before,"Q does not pass while a text field has focus")
 input.queue_free()
 await process_frame
 await press_q()
 expect(e.priority==1,"Q works again after closing the dialog and text field")

 clean()
 e.active=0
 e.priority=0
 view.reveal_player.reset()
 e.presentation_events.clear()
 view.set_response_mode(view.ResponseMode.ON)
 before=snapshot()
 await press_q()
 expect(snapshot()==before and find_button(view.ui,"结束主要阶段")!=null,"Q does not end the active player's main phase")
 print("RESPONSE SHORTCUT: ",checks," checks; failures=",failures.size())
 app.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)
