extends "res://tests/support/ui_base.gd"
## Card inspection must fit independently of the device's reported density.

func frames(count: int=12):
 for i in range(count):await process_frame

func tap(control: Control):
 await tap_at(control.get_global_rect().get_center())

func tap_at(at: Vector2):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-deck-details/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();app.is_android=true
 app.settings_path=Store.Paths.root_override+"/settings.json"
 root.add_child(app);await frames()
 var reported=""
 var longest="";var longest_length=0
 for id in Store.CARDS:
  if "御射山御狩神事" in Store.CARDS[id].name:reported=id
  var length=app.card_description(id).length()
  if length>longest_length:longest=id;longest_length=length
 expect(not reported.is_empty(),"reported landscape card exists")
 if reported.is_empty():quit(1);return
 var cases=[
  {"size":Vector2i(1280,576),"dpi":280.0},
  {"size":Vector2i(1280,720),"dpi":240.0},
  {"size":Vector2i(1920,864),"dpi":384.0},
  {"size":Vector2i(2400,1080),"dpi":480.0},
  {"size":Vector2i(2400,1080),"dpi":640.0},
  {"size":Vector2i(1280,576),"dpi":480.0}
 ]
 if "--render" in OS.get_cmdline_user_args():cases=[cases[0],cases[-1]]
 for sample in cases:
  root.size=sample.size;app.layout_dpi_override=sample.dpi
  app.layout_safe_override=Rect2(40,0,sample.size.x-64,sample.size.y-24)
  await frames()
  app.draft=Store.blank("手机卡牌详情测试");app.draft.rule_set="test";app.draft.leader="70"
  app.draft.main=[reported,"68"];app.dirty=true;app.editor();await frames()
  var ui=app.editor_ui;var before=app.draft.duplicate(true)
  var tag="%s / %d dpi" % [sample.size,sample.dpi]
  for id in [reported,"68","70","100",longest]:
   ui.show_details(id,"leader" if id=="70" else "main",0);await frames()
   var popup=ui.detail_popup.get_global_rect()
   var close=find_button(ui.detail_popup,"关闭")
   var actions=app.preview.find_child("CardDetailsActions",true,false)
   var picture=app.preview.find_child("CardDetailsArt",true,false)
   var inventory=app.preview.find_child("CardDetailsRemaining",true,false)
   expect(app.ui_metrics.safe.grow(1).encloses(popup),"popup stays inside safe area: "+id+" / "+tag)
   expect(close!=null and app.ui_metrics.safe.grow(1).encloses(close.get_global_rect()) and popup.grow(1).encloses(close.get_global_rect()),"close button stays visible: "+id+" / "+tag)
   expect(picture!=null and popup.grow(1).encloses(picture.get_global_rect()) and picture.size.x>100 and picture.size.y>100,"complete art area remains visible: "+id+" / "+tag)
   expect(inventory!=null and picture.get_global_rect().grow(1).encloses(inventory.get_global_rect()),"stock remains on the visible art: "+id+" / "+tag)
   var displayed=picture.texture.get_size()*minf(picture.size.x/picture.texture.get_width(),picture.size.y/picture.texture.get_height())
   expect(absf(inventory.position.y-(picture.size.y-displayed.y)*0.5-ui.detail_metrics.padding)<1 and absf(inventory.get_rect().end.x-(picture.size.x+displayed.x)*0.5+ui.detail_metrics.padding)<1,"stock stays in the art's top right corner: "+id+" / "+tag)
   expect(actions!=null and actions.get_children().all(func(button):return app.ui_metrics.safe.grow(1).encloses(button.get_global_rect()) and popup.grow(1).encloses(button.get_global_rect())),"all deck actions stay inside popup: "+id+" / "+tag)
   var scroll=app.preview.find_child("CardTextScroll",true,false) as ScrollContainer
   if id==longest and scroll.get_v_scroll_bar().max_value>scroll.get_v_scroll_bar().page+1:
    var at=scroll.get_global_rect().get_center()
    var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
    root.push_input(event,true);await process_frame
    var move=InputEventScreenDrag.new();move.index=0;move.position=at-Vector2(0,100);move.relative=Vector2(0,-100)
    root.push_input(move,true);await process_frame
    event=event.duplicate();event.pressed=false;event.position=move.position;root.push_input(event,true);await frames()
    expect(scroll.scroll_vertical>0 and is_instance_valid(ui.details_overlay) and app.draft==before,"finger scroll preserves details and draft: "+tag)
   elif id==longest:
    expect(scroll.get_global_rect().grow(1).encloses(scroll.get_child(0).get_global_rect()),"rules fit completely when scrolling is unnecessary: "+tag)
   if "--render" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://work/android-deck-details-%s-%d.png" % [id,sample.dpi])
   if close!=null and app.ui_metrics.safe.has_point(close.get_global_rect().get_center()):await tap(close)
   expect(not is_instance_valid(ui.details_overlay) and app.draft==before and app.dirty,"finger close returns to unchanged draft: "+id+" / "+tag)
   ui.close_details();await frames()
  ui.show_details(reported);await frames()
  var count=app.draft.main.count(reported)
  await tap(find_button(app.preview,"加入主卡组"))
  expect(app.draft.main.count(reported)==count+1 and is_instance_valid(ui.details_overlay),"visible main action responds to finger input: "+tag)
  count=app.draft.side.count(reported)
  await tap(find_button(app.preview,"加入副卡组"))
  expect(app.draft.side.count(reported)==count+1 and is_instance_valid(ui.details_overlay),"visible side action responds to finger input: "+tag)
  before=app.draft.duplicate(true)
  expect(not quit_on_go_back,"system back is intercepted while details are open: "+tag)
  root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST);await frames()
  expect(not is_instance_valid(ui.details_overlay) and not quit_on_go_back and app.draft==before,"system back closes details, preserves edits and keeps exit disabled: "+tag)
  ui.show_details(reported);await frames()
  var key=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true;root.push_input(key,true);await frames()
  expect(not is_instance_valid(ui.details_overlay) and app.draft==before,"escape closes details without discarding edits: "+tag)
  ui.show_details(reported);await frames()
  await tap_at(app.screen.global_position+Vector2(2,2))
  expect(not is_instance_valid(ui.details_overlay) and app.draft==before,"native background tap closes details without changing the deck: "+tag)
  ui.show_details(reported);await frames();app.editor();await frames()
  expect(not quit_on_go_back and app.draft==before,"layout rebuild keeps exit disabled and preserves edits: "+tag)
 print("ANDROID DECK DETAILS: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
