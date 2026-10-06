extends "res://tests/support/ui_base.gd"
var output="res://work/main-menu-tutorial"
var settings_fixture=""
var started=[]

func frames(count: int=6):
 for i in range(count):await process_frame

func shot(title: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(title+".png"))

func activate(button: Button):
 if button==null:expect(false,"action exists");return
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

func add_lessons():
 app.tutorial_entries=[]
 for i in range(24):
  var id="lesson_%02d" % i
  app.tutorial_entries.append({"id":id,"title":"测试教程 %02d" % i,"start":func():
   started.append(id)
   app.complete_tutorial(id)})

func check_list_geometry(prefix: String):
 var ui=app.tutorial_ui
 var safe=app.screen.get_global_rect().grow(1)
 for control in [ui.previous_button,ui.next_button,ui.page_label,ui.find_child("TutorialBack",true,false),ui.list_area]:
  expect(safe.encloses(control.get_global_rect()),prefix+" tutorial controls fit inside safe area")
 var previous_category=null
 for id in ui.CATEGORIES:
  var button=ui.category_buttons[id]
  expect(safe.encloses(button.get_global_rect()) and button.get_global_rect().end.x<=ui.list_area.get_global_rect().position.x,prefix+" category stays on the left inside the safe area")
  if previous_category!=null:expect(previous_category.get_global_rect().end.y<button.get_global_rect().position.y,prefix+" categories follow top/middle/bottom order")
  previous_category=button
 expect(ui.previous_button.get_global_rect().end.y<ui.next_button.get_global_rect().position.y,prefix+" page arrows are stacked vertically")
 expect(ui.rows.get_child_count()<=ui.page_size,prefix+" tutorial rows respect page capacity")
 for row in ui.rows.get_children():
  var button=row.get_child(0)
  var completion=row.get_node("TutorialCompletion")
  expect(ui.list_area.get_global_rect().grow(1).encloses(row.get_global_rect()),prefix+" tutorial row fits list area")
  expect(completion.get_global_rect().position.x>=button.get_global_rect().end.x,prefix+" completion status is on the right")

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 var fixtures=output.path_join("fixtures-"+str(Time.get_ticks_usec()))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixtures))
 Store.Paths.root_override=ProjectSettings.globalize_path(fixtures)
 settings_fixture=fixtures.path_join("settings.json")
 var file=FileAccess.open(settings_fixture,FileAccess.WRITE);file.store_string('{"fullscreen":false}');file.close()
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate();app.settings_path=settings_fixture
 app.account_session_path=fixtures.path_join("account.json")
 root.add_child(app);await frames()
 for mobile in [false,true]:
  var prefix="android" if mobile else "desktop"
  root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
  root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND if mobile else Window.CONTENT_SCALE_ASPECT_KEEP
  app.is_android=mobile;app.layout_dpi_override=360 if mobile else 0
  app.layout_safe_override=Rect2(40,12,1200,684) if mobile else Rect2()
  app.tutorial_entries=[];app.menu();await frames()
  var captions=["游戏教程","人机对战","联网对战","卡组编辑","玩家账号","对局回放","设置","退出游戏"]
  var previous_y=-1.0
  for i in range(0,captions.size(),2):
   var left=find_button(app.screen,captions[i]);var right=find_button(app.screen,captions[i+1])
   expect(left!=null and right!=null,prefix+" menu action pair exists")
   if left==null or right==null:continue
   expect(is_equal_approx(left.get_global_rect().position.y,right.get_global_rect().position.y) and left.get_global_rect().end.x<right.get_global_rect().position.x,prefix+" menu actions share their requested row")
   expect(left.get_global_rect().position.y>previous_y,prefix+" menu rows follow requested order")
   previous_y=left.get_global_rect().position.y
  expect(find_button(app.screen,"关于")==null,prefix+" About is inside settings")
  await shot(prefix+"-menu")
  await activate(find_button(app.screen,"设置"))
  expect(app.page=="settings",prefix+" settings opens from main menu")
  await activate(find_button(app.screen,"关于"))
  expect(app.page=="about",prefix+" About opens from settings")
  if mobile:
   expect(app.screen.find_children("*","Label",true,false).all(func(label):return app.screen.get_global_rect().grow(1).encloses(label.get_global_rect())),prefix+" About text fits the safe area")
   await shot(prefix+"-about")
  await activate(find_button(app.screen,"返回"))
  expect(app.page=="settings",prefix+" About returns to settings")
  await activate(find_button(app.screen,"返回"))
  await activate(find_button(app.screen,"游戏教程"))
  expect(app.page=="tutorials" and app.tutorial_ui.rows.get_child_count()==0,prefix+" tutorial entry opens an empty list")
  expect(app.tutorial_ui.empty.visible and app.tutorial_ui.previous_button.disabled and app.tutorial_ui.next_button.disabled,prefix+" empty tutorial list disables both page arrows")
  check_list_geometry(prefix);await shot(prefix+"-tutorial-empty")
  for id in ["advanced","leader","beginner"]:
   await activate(app.tutorial_ui.category_buttons[id])
   expect(app.tutorial_ui.category==id and app.tutorial_ui.empty.visible,prefix+" empty category is selectable")
  add_lessons();app.tutorials();await frames()
  var ui=app.tutorial_ui
  expect(ui.pages()>1 and ui.previous_button.disabled and not ui.next_button.disabled,prefix+" authored lessons can paginate")
  await activate(ui.next_button)
  expect(ui.page_index==1 and ui.rows.get_child(0).get_meta("tutorial_id")=="lesson_%02d" % ui.page_size,prefix+" down arrow reaches the next lessons")
  check_list_geometry(prefix)
  await activate(ui.previous_button)
  expect(ui.page_index==0,prefix+" up arrow returns to first lessons")
  if not mobile:
   expect(ui.rows.get_child(0).get_node("TutorialCompletion").text.is_empty(),prefix+" unfinished lesson has no completed label")
   await activate(ui.rows.get_child(0).get_child(0))
   expect(started==["lesson_00"] and app.tutorial_completed("lesson_00"),prefix+" completion callback saves completed lesson")
  expect(ui.rows.get_child(0).get_node("TutorialCompletion").text=="已完成",prefix+" completed lesson shows status on its right")
  expect(not app.complete_tutorial("missing_lesson") and not app.completed_tutorials.has("missing_lesson"),prefix+" unknown lessons cannot be marked complete")
  ui.turn_page(100);await frames()
  expect(ui.page_index==ui.pages()-1 and ui.next_button.disabled,prefix+" final page disables down arrow")
  ui.turn_page(-100);await frames()
  expect(ui.page_index==0 and ui.previous_button.disabled,prefix+" first page disables up arrow")
  app.tutorial_entries.append({"id":"advanced_sample","title":"进阶样例","category":"advanced","start":func():started.append("advanced_sample")})
  app.tutorial_entries.append({"id":"leader_sample","title":"自机样例","category":"leader","start":func():started.append("leader_sample")})
  await activate(ui.category_buttons.advanced)
  expect(ui.rows.get_child_count()==1 and ui.rows.get_child(0).get_meta("tutorial_id")=="advanced_sample" and ui.page_index==0,prefix+" advanced category filters and resets pagination")
  await activate(ui.rows.get_child(0).get_child(0))
  expect(started.back()=="advanced_sample",prefix+" filtered lesson launches its own callback")
  await activate(ui.category_buttons.leader)
  expect(ui.rows.get_child_count()==1 and ui.rows.get_child(0).get_meta("tutorial_id")=="leader_sample",prefix+" leader category filters lessons")
  await activate(ui.category_buttons.beginner)
  expect(ui.rows.get_child(0).get_node("TutorialCompletion").text=="已完成" and ui.category_buttons.beginner.button_pressed,prefix+" switching back preserves completion and selected state")
  await shot(prefix+"-tutorial-completed")
  if mobile:
   await activate(ui.next_button)
   var first_id=ui.rows.get_child(0).get_meta("tutorial_id")
   root.size=Vector2i(2340,1080);app.layout_dpi_override=240;app.layout_safe_override=Rect2(30,0,2280,1040)
   app.queue_layout_refresh();await frames(12)
   expect(app.tutorial_ui==ui and ui.rows.get_children().any(func(row):return row.get_meta("tutorial_id")==first_id),prefix+" resizing retains the current lesson in view")
   check_list_geometry(prefix+" wide")
  await activate(ui.find_child("TutorialBack",true,false))
  expect(app.page=="menu",prefix+" tutorial return opens main menu")
 var saved=JSON.parse_string(FileAccess.get_file_as_string(settings_fixture))
 expect(saved.get("completed_tutorials",{}).get("lesson_00",false)==true and saved.get("delay_turn_end",false)==true,"completion persists alongside existing settings")
 app.queue_free();await frames()
 app=load("res://main.tscn").instantiate();app.settings_path=settings_fixture;app.account_session_path=fixtures.path_join("account.json")
 root.add_child(app);await frames()
 expect(app.tutorial_completed("lesson_00"),"completed tutorial survives a new game instance")
 expect(app.tutorial_catalog_errors.is_empty() and app.tutorial_entries.size()==JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial/catalog.json")).lessons.size() and app.tutorial_entries[0].id=="t1","only configured production lessons populate a new instance")
 app.queue_free();await frames()
 print("MAIN MENU TUTORIAL: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
