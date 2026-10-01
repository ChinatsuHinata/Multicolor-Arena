extends "res://tests/support/ui_base.gd"
## High-density landscape screens must keep gallery and deck controls reachable.

func frames(count: int=12):
 for i in range(count):await process_frame

func touch(at: Vector2,pressed: bool):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=pressed
 root.push_input(event,true);await process_frame

func tap(control: Control):
 var at=control.get_global_rect().get_center()
 await touch(at,true);await touch(at,false);await frames()

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-deck-density-tests/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND;root.gui_embed_subwindows=true
 root.size=Vector2i(1280,576)
 app=load("res://main.tscn").instantiate();app.is_android=true
 app.settings_path=Store.Paths.root_override+"/settings.json"
 root.add_child(app);await frames()
 app.draft=Store.blank("手机底部按钮测试");app.draft.leader="70"
 app.filter_kind="符卡"
 var cases=[
  {"size":Vector2i(1280,720),"dpi":240.0},
  {"size":Vector2i(1280,576),"dpi":280.0},
  {"size":Vector2i(1920,864),"dpi":384.0},
  {"size":Vector2i(2400,1080),"dpi":440.0},
  {"size":Vector2i(2400,1080),"dpi":480.0},
  {"size":Vector2i(2400,1080),"dpi":640.0}
 ]
 if "--render" in OS.get_cmdline_user_args():cases=cases.slice(0,2)
 for sample in cases:
  root.size=sample.size;app.layout_dpi_override=sample.dpi
  app.layout_safe_override=Rect2(40,0,sample.size.x-64,sample.size.y-24)
  await frames();app.android_editor_overview=false;app.set_meta("android_editor_list_zone","main")
  app.editor();await frames()
  var ui=app.editor_ui;var safe=app.ui_metrics.safe.grow(2)
  var tag="%s / %d dpi" % [sample.size,sample.dpi]
  var pagination=app.screen.find_child("LibraryPagination",true,false)
  expect(safe.encloses(ui.editor_root.get_global_rect()) and safe.encloses(ui.columns.get_global_rect()),"editor stays within landscape safe area: "+tag)
  expect(safe.encloses(pagination.get_global_rect()) and safe.encloses(ui.previous_library_page.get_global_rect()) and safe.encloses(ui.next_library_page.get_global_rect()),"both gallery arrows and page number stay visible: "+tag)
  expect(safe.encloses(ui.list_switchers.get_global_rect()) and safe.encloses(app.counts.get_global_rect()),"main/side buttons and counts stay visible: "+tag)
  expect(ui.library_scroll.get_global_rect().grow(1).encloses(app.library.get_global_rect()) and app.library.get_child_count()==3,"three gallery slots fit above the arrows: "+tag)
  expect(app.color_buttons.values().all(func(button):return button.size.y>=app.ui_metrics.hit),"color filters retain full touch target height: "+tag)
  if not safe.encloses(pagination.get_global_rect()) or not safe.encloses(ui.list_switchers.get_global_rect()):continue
  var before=app.draft.duplicate(true);var page_before=ui.library_page
  await tap(ui.next_library_page)
  expect(ui.library_page==page_before+1,"visible next arrow responds to a finger tap: "+tag)
  await tap(ui.previous_library_page)
  expect(ui.library_page==page_before,"visible previous arrow responds to a finger tap: "+tag)
  await tap(ui.list_buttons.side)
  expect(ui.list_zone=="side" and ui.list_buttons.side.button_pressed,"visible side button responds to a finger tap: "+tag)
  await tap(ui.list_buttons.main)
  expect(ui.list_zone=="main" and app.draft==before,"switching back keeps the deck intact: "+tag)
  var colors_scroll=app.screen.find_child("LibraryColorScroll",true,false)
  if colors_scroll!=null and colors_scroll.get_v_scroll_bar().max_value>colors_scroll.get_v_scroll_bar().page+1:
   var at=colors_scroll.get_global_rect().get_center();await touch(at,true)
   var move=InputEventScreenDrag.new();move.index=0;move.relative=Vector2(0,-app.ui_metrics.hit*3);move.position=at+move.relative
   root.push_input(move,true);await process_frame;await touch(move.position,false);await frames()
   expect(colors_scroll.scroll_vertical>0 and app.selected_colors.is_empty() and app.draft==before,"color swipe scrolls without selecting or modifying the deck: "+tag)
   colors_scroll.scroll_vertical=int(colors_scroll.get_v_scroll_bar().max_value);await frames()
   expect(colors_scroll.get_global_rect().grow(1).encloses(app.color_buttons["黑"].get_global_rect()),"last color is reachable without moving the bottom controls: "+tag)
   await tap(app.color_buttons["黑"])
   expect(app.selected_colors==["黑"],"last color remains selectable after scrolling: "+tag)
   app.toggle_color("全部");await frames()
  elif colors_scroll!=null:
   expect(colors_scroll.get_global_rect().grow(1).encloses(app.color_buttons["黑"].get_global_rect()),"all colors fit without scrolling at ordinary density: "+tag)
  ui.show_details(app.draft.leader,"leader",0);await frames()
  var detail_actions=app.preview.find_child("CardDetailsActions",true,false)
  var detail_inventory=app.preview.find_child("CardDetailsRemaining",true,false)
  expect(safe.encloses(ui.detail_popup.get_global_rect()) and detail_actions.get_children().all(func(button):return ui.detail_popup.get_global_rect().encloses(button.get_global_rect())),"leader detail actions fit the high density safe area: "+tag)
  expect(ui.detail_popup.get_global_rect().encloses(detail_inventory.get_global_rect()),"detail inventory remains visible at high density: "+tag)
  ui.close_details();await frames()
  if sample.size==Vector2i(1280,576) and DisplayServer.get_name()!="headless":
   if colors_scroll!=null:colors_scroll.scroll_vertical=0;await frames()
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://work/android-deck-density-fixed.png")
 print("ANDROID DECK DENSITY: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
