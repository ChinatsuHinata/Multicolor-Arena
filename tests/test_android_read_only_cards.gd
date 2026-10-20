extends "res://tests/support/ui_base.gd"
const G=preload("res://scripts/rules/gensokyo_exploration.gd")

func frames(count: int=12):
 for i in range(count):await process_frame

func tap(control: Control):
 var event=InputEventScreenTouch.new();event.index=0;event.position=control.get_global_rect().get_center();event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-read-only-cards/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();app.is_android=true;app.settings_path=Store.Paths.root_override+"/settings.json";app.tutorial_local_directory=Store.Paths.root_override+"/tutorials"
 root.add_child(app);await frames()
 for sample in [{"size":Vector2i(1280,576),"dpi":280.0},{"size":Vector2i(2400,1080),"dpi":640.0}]:
  root.size=sample.size;app.layout_dpi_override=sample.dpi;app.layout_safe_override=Rect2(40,0,sample.size.x-64,sample.size.y-24)
  await frames()
  app.draft=Store.blank("只读卡牌详情测试");app.draft.leader="70";app.editor();await frames()
  var ui=app.editor_ui;var before=app.draft.duplicate(true)
  for id in ["token-fdn-082",G.LEADER,G.RANDOM_LEADER]:
   app.query=id;app.update_library();await frames()
   expect(app.library_rows.has(id),"read-only card remains searchable: "+id)
   if not app.library_rows.has(id):continue
   await tap(app.library_rows[id].row)
   expect(is_instance_valid(ui.details_overlay),"native tap opens read-only details: "+id)
   if not is_instance_valid(ui.details_overlay):continue
   var popup=ui.detail_popup.get_global_rect();var safe=app.ui_metrics.safe.grow(1)
   var art=app.preview.find_child("CardDetailsArt",true,false)
   var actions=app.preview.find_child("CardDetailsActions",true,false)
   var notice=app.preview.find_child("CardDetailsReadOnly",true,false) as Label
   var scroll=app.preview.find_child("CardTextScroll",true,false)
   expect(safe.encloses(popup),"read-only popup fits safe area: %s / %s" % [id,sample.size])
   expect(art!=null and art.texture!=null and popup.grow(1).encloses(art.get_global_rect()) and art.size.x>100 and art.size.y>100,"read-only card art stays visible: "+id)
   expect(actions!=null and actions.get_children().all(func(control):return popup.grow(1).encloses(control.get_global_rect())),"read-only notice stays inside popup: "+id)
   expect(notice!=null and notice.size.x>=notice.get_parent().size.x-1 and notice.get_line_count()<=2,"read-only notice uses the full text column without vertical character wrapping: "+id)
   expect(scroll!=null and scroll.size.y>100,"read-only notice leaves room to read the card rules: "+id)
   expect(find_button(app.preview,"加入主卡组")==null and find_button(app.preview,"加入副卡组")==null and find_button(app.preview,"设为自机")==null,"read-only inspection has no construction actions: "+id)
   if "--render" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://work/android-read-only-%s-%d.png" % [id,sample.dpi])
   await tap(find_button(ui.detail_popup,"关闭"))
   expect(not is_instance_valid(ui.details_overlay) and app.draft==before,"closing read-only details preserves the draft: "+id)
  app.change_deck_rule_set("unrestricted");await frames()
  ui.show_details(G.RANDOM_LEADER);await frames()
  var select_leader=find_button(app.preview,"设为自机")
  expect(select_leader!=null and app.preview.find_child("CardDetailsReadOnly",true,false)==null,"unrestricted random leader details offer construction actions")
  if select_leader!=null:await tap(select_leader)
  expect(app.draft.leader==G.RANDOM_LEADER and not is_instance_valid(ui.details_overlay) and Store.validate(app.draft).is_empty(),"native tap selects the random leader for an unrestricted deck")
 print("ANDROID READ ONLY CARDS: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
