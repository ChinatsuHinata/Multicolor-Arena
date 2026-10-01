extends "res://tests/support/ui_base.gd"
const Caption=preload("res://scripts/rules/ability_caption.gd")

func run():
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 clean()
 var origin=put("39","field")
 var target=put("53","field")
 e.Cat.delay(e,target,"sacrifice",0,"end",{},origin)
 e.run_delayed("end")
 e.pump_choices()
 expect(e.stack.size()==1,"delayed effect enters the stack")
 if not e.stack.is_empty():
  view.render();await process_frame
  var entry=e.stack[0]
  var expected=Caption.text(entry)
  var shown=view.stack_panel.tiles.get(entry.id,{})
  expect(shown.has("caption") and shown.caption.text==expected,"stack hint displays source and precise delayed effect")
  expect(shown.has("tile") and expected in shown.tile.tooltip_text,"stack card tooltip contains the full hint")
 print("DELAYED_CAPTIONS_UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
