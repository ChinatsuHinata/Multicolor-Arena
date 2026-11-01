extends "res://tests/support/ui_base.gd"
## Large Android deck lists must switch lists and decks without a rebuild storm.

var rebuilds=0

func frames(count: int=6):
 for i in range(count):await process_frame

func timed(label: String,callable: Callable,limit_ms: int=1500):
 rebuilds=0
 var started=Time.get_ticks_msec()
 callable.call();await frames(10)
 var elapsed=Time.get_ticks_msec()-started
 print(label," rebuilds=",rebuilds," ms=",elapsed)
 expect(rebuilds<=6,"%s settles after %d rebuilds" % [label,rebuilds])
 expect(elapsed<limit_ms,"%s finishes in %d ms" % [label,elapsed])

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-deck-switch-tests/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720)
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND;root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 app.is_android=true;app.layout_dpi_override=240
 var ids=[]
 for id in Store.CARDS:
  if Store.CARDS[id].kind!="自机" and app.RuleSet.allowed(id,Store.CARDS[id],"test"):ids.append(id)
 for dimensions in [Vector2i(1280,720),Vector2i(2400,1080),Vector2i(1600,720),Vector2i(1920,1080),Vector2i(2340,1080)]:
  root.size=dimensions;app.layout_dpi_override=float(dimensions.y)/3.0;await frames()
  var large=Store.blank("大卡组A");large.rule_set="test";large.leader="70";large.main=ids.slice(0,50);large.side=ids.slice(50,60)
  var other=Store.blank("大卡组B");other.rule_set="test";other.leader="70";other.main=ids.slice(60,110);other.side=ids.slice(110,120)
  app.draft=large;app.android_editor_overview=false;app.set_meta("android_editor_list_zone","main")
  app.editor();await frames(12)
  var ui=app.editor_ui
  var count_hook=func():rebuilds+=1
  var tag=" at %s" % dimensions
  # Count every Android deck rebuild through the canvas child churn.
  app.deck_canvas.child_entered_tree.connect(func(_n):count_hook.call())
  await timed("switch to side list"+tag,func():ui.set_list_zone("side"))
  await timed("switch to main list"+tag,func():ui.set_list_zone("main"))
  await timed("switch to overview"+tag,func():ui.set_overview(true))
  var missing=-1
  for attempt in range(120):
   missing=0
   for art in app.main_content.find_child("MainCardGrid",true,false).find_children("*","TextureRect",true,false):missing+=int(art.texture==null)
   if missing==0:break
   await process_frame
  expect(missing==0,"overview art finishes loading progressively"+tag)
  await timed("switch back to list"+tag,func():ui.set_overview(false))
  await timed("switch deck"+tag,func():app.draft=other.duplicate(true);app.dirty=false;app.editor();app.deck_canvas.child_entered_tree.connect(func(_n):count_hook.call()))
  await timed("switch to side list after deck change"+tag,func():app.editor_ui.set_list_zone("side"))
  app.editor_ui.set_list_zone("main");await frames()
 print("ANDROID DECK LIST SWITCH: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
