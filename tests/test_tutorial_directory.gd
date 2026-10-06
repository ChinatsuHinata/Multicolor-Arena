extends "res://tests/support/ui_base.gd"
const Config=preload("res://scripts/tutorial/config.gd")
const Progress=preload("res://scripts/tutorial/progress.gd")
const Model=preload("res://scripts/tutorial/authoring_model.gd")
const OUTPUT="res://work/tutorial-directory"
var fixtures=""
var course_path=""
var lesson: Dictionary

func frames(count: int=6):
 for i in range(count):await process_frame

func shot(title: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUTPUT.path_join(title+".png"))

func activate(button: Button):
 if button.disabled:return
 var ancestor=button.get_parent()
 while ancestor!=null:
  if ancestor is ScrollContainer:ancestor.ensure_control_visible(button)
  ancestor=ancestor.get_parent()
 await frames()
 var at=button.get_global_rect().get_center()
 if app.is_android:
  var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
  root.push_input(event,true);await process_frame
  event=event.duplicate();event.pressed=false;root.push_input(event,true)
 else:await click(at)
 await frames()

func fixture() -> Dictionary:
 var info=func(next,text):return {"type":"info","guide":{"text":text},"next":next}
 var board=Model.battle()
 board.players[0].leader_on_field=true
 return {"schema_version":1,"id":"directory_fixture","title":"目录与真实局面恢复","category":"beginner","initial_scenario":"deck","start_step":"intro","completion":{"type":"always"},
  "scenarios":{"deck":{"type":"deck","deck":Model.deck()},"editor":{"type":"in_game","screen":"deck_editor","deck":Model.deck()},"battle":board},
  "steps":{
   "result":info.call("board","加入指定卡牌后的真实卡组。"),
   "intro":info.call("add","[b]阅读课程[/b]，然后按顺序完成任务。"),
   "add":{"type":"task","scenario":"editor","guide":{"text":"向主卡组加入樱华ノ月。","next_button":"hidden"},"task":{"timing":"action","action":{"id":"editor.add","args":{"card_id":"96","zone":"main"}},"success":{"type":"deck_count","zone":"main","card_id":"96","op":"eq","value":1}},"next":"result"},
   "board":{"type":"info","scenario":"battle","guide":{"text":"查看初始战场。"},"next":"damage"},
   "damage":{"type":"task","guide":{"text":"让对方生命降至15。","next_button":"hidden"},"task":{"success":{"type":"life","player":1,"value":15,"op":"le"}},"next":"after"},
   "after":info.call("return_deck","查看已发生变化的生命、随机状态与自机。"),
   "return_deck":{"type":"info","scenario":"editor","scenario_mode":"resume","guide":{"text":"回到先前添加了卡牌的教学卡组。"},"next":"$complete"}}}

func new_app():
 app=load("res://main.tscn").instantiate();app.settings_path=fixtures.path_join("settings.json")
 app.account_session_path=fixtures.path_join("account.json");app.tutorial_local_directory=fixtures.path_join("lessons")
 root.add_child(app);await frames()

func flow():
 return app.screen.get_child(0).runtime

func check_geometry(prefix: String):
 var ui=app.tutorial_directory_ui
 var safe=app.screen.get_global_rect().grow(1)
 for control in [ui.heading,ui.summary,ui.scroll,ui.continue_button,ui.find_child("TutorialDirectoryBack",true,false),ui.find_child("TutorialDirectoryRestart",true,false)]:
  expect(safe.encloses(control.get_global_rect()),prefix+" directory fits screen: "+control.name)
 var button=ui.step_buttons.intro
 ui.scroll.ensure_control_visible(button);await frames()
 expect(ui.scroll.get_global_rect().grow(1).encloses(button.get_parent().get_global_rect()),prefix+" entry and read status fit the list width")

func run():
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 fixtures=OUTPUT.path_join("fixtures-"+str(Time.get_ticks_usec()));DirAccess.make_dir_recursive_absolute(fixtures)
 Store.Paths.root_override=ProjectSettings.globalize_path(fixtures)
 DirAccess.make_dir_recursive_absolute(fixtures.path_join("lessons"))
 course_path=fixtures.path_join("lessons/course.json")
 lesson=fixture()
 expect(Config.new().validate(lesson,Store.CARDS).ok,"mixed scene directory fixture validates")
 var file=FileAccess.open(course_path,FileAccess.WRITE);file.store_string(JSON.stringify(lesson));file.close()
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 await new_app()
 expect(Progress.ordered_steps(lesson)==["intro","add","result","board","damage","after","return_deck"],"directory follows the course links rather than JSON key order")
 for mobile in [false,true]:
  app.is_android=mobile;app.is_test_build=true;app.tutorials();await frames()
  expect((app.tutorial_ui.find_child("OpenTutorialEditor",true,false)!=null)==not mobile,"authoring header follows platform gate")
  expect((app.tutorial_ui.find_child("EditTutorialt1",true,false)!=null)==not mobile,"per-course authoring follows platform gate")
  if mobile:
   app.tutorial_editor(course_path);await frames()
   expect(app.page=="tutorials","Android direct authoring request is blocked")
 app.is_android=false;app.is_test_build=false;app.tutorials();await frames()
 expect(app.tutorial_ui.find_child("OpenTutorialEditor",true,false)==null and app.tutorial_ui.find_child("EditTutorialt1",true,false)==null,"release hides both authoring entrances")
 app.tutorial_editor(course_path);await frames();expect(app.page=="tutorials","release direct authoring request is blocked")
 app.is_test_build=true
 for production in app.tutorial_entries.filter(func(item):return str(item.path).begins_with("res://data/tutorial/")):
  app.tutorial_directory(production.path);await frames()
  var directory=app.tutorial_directory_ui
  expect(directory.step_buttons.size()==directory.course.steps.size() and not directory.step_buttons[directory.course.start_step].disabled,"production course opens its full directory: "+production.id)
  expect(app.tutorial_progress.record(directory.course).read.is_empty(),"browsing production directory preserves unread state: "+production.id)
  if production.id=="t4":await shot("desktop-t4-unread")
 var entry=app.tutorial_entries.filter(func(item):return item.id==lesson.id)[0]
 entry.start.call();await frames()
 expect(app.page=="tutorial_directory","course entry opens its directory")
 expect(app.tutorial_progress.record(lesson).read.is_empty(),"opening a directory does not mark a step read")
 var ui=app.tutorial_directory_ui
 expect(not ui.step_buttons.intro.disabled and ui.step_buttons.add.disabled and ui.step_buttons.return_deck.disabled,"new lesson unlocks only its first step")
 await check_geometry("desktop");await shot("desktop-unread")
 app.begin_tutorial(course_path,"return_deck");await frames()
 expect(app.page=="tutorial_directory" and app.tutorial_progress.record(lesson).read.is_empty(),"direct launch cannot bypass the unread gate")
 await activate(ui.continue_button)
 expect(flow().current_step=="intro" and app.tutorial_progress.has_read(lesson,"intro"),"starting marks the entered step read")
 expect(flow().next() and flow().current_step=="add","reading reaches the editor task")
 await frames()
 var native=app.screen.get_child(0).editor_host;native.selected="96";native.add_to("main");await frames()
 expect(flow().current_step=="result" and flow().adapter.ui_deck.main.has("96"),"real editor action advances and checkpoints the changed deck")
 app.screen.get_child(0).tutorial_guide.leave_tutorial();await frames()
 expect(app.page=="tutorial_directory" and app.tutorial_directory_ui.step_buttons.result.get_parent().get_node("TutorialReadStatus").text=="已读","guide returns to a directory with read markers")
 expect(app.tutorial_progress.latest_step(lesson)=="result" and app.tutorial_directory_ui.step_buttons.board.disabled,"only reached steps unlock")
 app.begin_tutorial(course_path,"intro");await frames()
 expect(app.tutorial_progress.latest_step(lesson)=="result","rereading does not shrink the furthest read step")
 app.tutorial_directory(course_path);await frames();await shot("desktop-partial")
 app.queue_free();await frames();await new_app()
 expect(app.tutorial_progress.has_read(lesson,"add") and app.tutorial_progress.latest_step(lesson)=="result","read records survive a new application instance")
 app.begin_tutorial(course_path,"result");await frames()
 expect(flow().current_step=="result" and flow().adapter.ui_deck.main.has("96"),"jump restores the exact editor state across restart")
 expect(flow().can_previous() and flow().previous() and flow().current_step=="add" and not flow().adapter.ui_deck.main.has("96"),"resumed course can step back to its persisted task entrance")
 expect(flow().previous() and flow().current_step=="intro","persisted previous reaches the first step")
 expect(not flow().can_previous(),"first step cannot go further back")
 app.begin_tutorial(course_path,"result");await frames();expect(flow().next() and flow().current_step=="board","read jump can continue to the next new scene")
 await frames();expect(flow().next() and flow().current_step=="damage","battle task enters normally")
 await frames()
 var runtime=flow();var engine=runtime.adapter.engine
 engine.damage_target({"player":1},5);engine.rng.randi();var expected_rng=engine.rng.state
 runtime.observe({"type":"state_changed"});runtime.tick();await frames()
 expect(runtime.current_step=="after" and engine.players[1].life==15,"battle progress checkpoints the actual task result")
 app.queue_free();await frames();await new_app()
 app.begin_tutorial(course_path,"after");await frames();runtime=flow();engine=runtime.adapter.engine
 expect(engine.players[1].life==15 and engine.rng.state==expected_rng,"battle life and RNG survive directory jump across restart")
 expect(is_same(engine.players[0].leader,engine.players[0].field[0]),"serialized checkpoint retains leader identity on the battlefield")
 expect(runtime.next() and runtime.current_step=="return_deck","restored battle advances back to a prior scene")
 await frames()
 expect(runtime.adapter.ui_deck.main.has("96"),"saved inactive scenario retains the prior edited deck")
 expect(runtime.next() and runtime.finished and app.tutorial_completed(lesson.id),"course still completes through its original completion callback")
 for mobile in [false,true]:
  app.is_android=mobile;app.layout_dpi_override=360 if mobile else 0
  root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
  root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND if mobile else Window.CONTENT_SCALE_ASPECT_KEEP
  app.layout_safe_override=Rect2(40,12,1200,684) if mobile else Rect2()
  app.tutorial_directory(course_path);await frames()
  expect(app.tutorial_directory_ui.step_buttons.values().all(func(button):return not button.disabled),"completed directory exposes every read step")
  await check_geometry("android" if mobile else "desktop")
  await shot("android-completed" if mobile else "desktop-completed")
  await activate(app.tutorial_directory_ui.step_buttons.result)
  expect(flow().current_step=="result" and flow().adapter.ui_deck.main.has("96"),"native directory click restores the chosen read step")
  app.tutorial_directory(course_path);await frames()
  if mobile:
   root.size=Vector2i(2340,1080);app.layout_dpi_override=240;app.layout_safe_override=Rect2(30,0,2280,1040)
   app.queue_layout_refresh();await frames(12);await check_geometry("android wide")
   app.tutorial_directory("res://data/tutorial/beginner/t4.json");await frames();await shot("android-t4-unread")
 var progress=Progress.new();progress.directory=app.tutorial_progress.directory
 var good=progress.snapshot(lesson,"result",Store.CARDS)
 file=FileAccess.open_compressed(progress.step_path(lesson,"result"),FileAccess.WRITE,FileAccess.COMPRESSION_ZSTD)
 file.store_var({"version":-1});file.close()
 expect(progress.snapshot(lesson,"result",Store.CARDS).is_empty() and not progress.last_error.is_empty(),"invalid saved checkpoint is rejected without restoring a scene")
 expect(progress.save(lesson,"result",good) and progress.record(lesson).read.size()==7 and progress.snapshot(lesson,"result",Store.CARDS).adapter.ui_deck.main.has("96"),"reading again repairs a damaged checkpoint without duplicate read records")
 var changed=lesson.duplicate(true);changed.steps.intro.guide.text+="课程内容已更新。"
 expect(app.tutorial_progress.record(changed).read.is_empty() and not app.tutorial_progress.can_open(changed,"after"),"changed course content invalidates incompatible checkpoints")
 app.queue_free();await frames()
 print("TUTORIAL DIRECTORY: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
