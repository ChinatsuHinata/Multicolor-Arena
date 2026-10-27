extends "res://tests/support/ui_base.gd"
var fixture="res://work/android-inspection-layout/"+str(Time.get_ticks_usec())
func frames(count: int=6):
 for i in range(count):await process_frame
func inspect(id: String):
 view.android_inspection_allowed=true;view.inspect_card(id);view.android_inspection_allowed=false
 await frames()
func dismiss():
 await create_timer(0.28).timeout
 var point=app.ui_metrics.safe.end-Vector2(4,4)
 var event=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
func verify_bounds(label: String):
 var panel=view.inspection.get_global_rect()
 var safe=app.ui_metrics.safe
 expect(safe.grow(1).encloses(panel),label+" wide preview stays inside safe screen bounds")
 expect(panel.size.x>=minf(380,safe.size.x*0.24),label+" preview restores useful reading width "+str(panel.size.x))
 for rect in [view.responsive.enemy_life,view.responsive.own_life,view.responsive.toolbar_rect,view.responsive.log_rect,view.HAND,view.responsive.action_rect]:
  expect(not panel.intersects(rect),label+" preview leaves status, hand and action regions clear "+str(rect))
 for node in view.ui.find_children("*","Button",true,false):
  if node.is_visible_in_tree():expect(not panel.intersects(node.get_global_rect()),label+" preview does not cover button "+str(node.name))
 var title=view.inspection.find_child("InspectionTitle",true,false)
 expect(title!=null and panel.grow(1).encloses(title.get_global_rect()),label+" full card title stays inside the panel")
 var text=view.inspection_text
 expect(text.get_theme_font_size("normal_font_size")>=18 and text.size.y>=100,label+" effects keep readable text and scrolling height "+str(text.size))
 expect(text.scroll_active and panel.grow(1).encloses(text.get_global_rect()),label+" long effects scroll inside the panel")
 var board=view.projected_android_focus(view.android_focus_bounds())
 expect(board.position.x>=panel.end.x-2,label+" battlefield remains to the right of the preview")
 expect(find_button(view.inspection,"关闭详情")==null,label+" outside-tap dismissal keeps the preview free of a close button")
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture+"/tutorials"))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();app.is_android=true
 app.settings_path=fixture+"/settings.json";app.account_session_path=fixture+"/account.json";app.tutorial_local_directory=fixture+"/tutorials"
 root.add_child(app);await frames();app.load_legacy_test_decks()
 var longest="53"
 for id in Store.CARDS:
  if str(Store.CARDS[id].get("rules_text","")).length()>str(Store.CARDS[longest].get("rules_text","")).length():longest=id
 var cases=[{"size":Vector2i(1280,720),"dpi":240},{"size":Vector2i(1280,576),"dpi":280},{"size":Vector2i(2400,1080),"dpi":480},{"size":Vector2i(1280,720),"dpi":320}]
 if OS.get_cmdline_user_args().has("--render"):cases=[cases[0],cases[-1]]
 for sample in cases:
  root.size=sample.size;app.layout_dpi_override=sample.dpi
  app.layout_safe_override=Rect2(40,0,sample.size.x-64,sample.size.y-24)
  await frames();app.refresh_responsive_layout();app.begin_battle(true)
  view=app.duel_view;view.set_process(false);e=view.engine;view.replay_recording.finished=true
  clean()
  for i in range(7):put("53","field");put("53","field",1)
  for i in range(12):put("100","palette")
  for i in range(5):put("53","hand")
  for top_down in [false,true]:
   view.table.set_top_down_view(top_down);view.render();view.focus_android_camera(false);await settle()
   var label=str(sample.size)+"/"+str(sample.dpi)+("/2d" if top_down else "/3d")
   var saved_offset=view.table.camera_offset;var saved_scale=view.table.camera_frame_scale
   for id in ["53","100",longest]:
    await inspect(id);verify_bounds(label+"/"+id)
    await capture("inspection-wide-"+str(sample.size.x)+"-"+str(sample.dpi)+("-2d" if top_down else "-3d")+"-"+id)
    view.render();await frames()
    expect(view.inspection.visible and view.responsive.camera_focus_rect().position.x>view.inspection.get_global_rect().end.x,label+" repeated battle renders preserve the preview lane")
    await dismiss()
    expect(not view.inspection.visible and view.android_inspection_camera_restore.is_empty(),label+" tapping outside closes preview")
    expect(view.table.camera_offset.is_equal_approx(saved_offset) and is_equal_approx(view.table.camera_frame_scale,saved_scale),label+" closing preview restores the original camera")
   view.table.camera_offset+=Vector3(0.8,0,0.4);view.table.camera_frame_scale*=0.92;view.table.set_camera()
   saved_offset=view.table.camera_offset;saved_scale=view.table.camera_frame_scale
   await inspect("53");await dismiss()
   expect(view.table.camera_offset.is_equal_approx(saved_offset) and is_equal_approx(view.table.camera_frame_scale,saved_scale),label+" manual camera pan and zoom survive preview")
  app.menu();await frames()
 print("ANDROID INSPECTION LAYOUT ",checks," checks; failures=",failures)
 app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
