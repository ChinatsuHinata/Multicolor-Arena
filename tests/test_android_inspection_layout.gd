extends "res://tests/support/ui_base.gd"
class RankedSession:
 extends RefCounted
 var room={"ranks":[{"tier":4,"position":1234567},{"tier":3,"level":3,"stars":3}]}
 func latency_text():return "42 ms"
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
 expect(is_equal_approx(panel.size.x,safe.size.x*0.16) and is_equal_approx(panel.position.x,safe.position.x),label+" preview uses the narrow left column")
 for who in [0,1]:
  var life=view.life_widgets[who].button.get_global_rect()
  expect(not panel.intersects(life),label+" preview never covers player "+str(who)+" ID or life bar")
 expect(panel.position.y>=view.responsive.enemy_life.end.y and panel.end.y<=view.responsive.own_life.position.y,label+" preview stays between both IDs")
 expect(view.inspection.z_index>view.hud.z_index,label+" preview floats above the left HUD")
 var title=view.inspection.find_child("InspectionTitle",true,false)
 expect(title!=null and panel.grow(1).encloses(title.get_global_rect()),label+" full card title stays inside the panel")
 if title!=null:
  expect(title.get_visible_line_count()>=title.get_line_count(),label+" all wrapped title lines are actually visible: "+str([title.get_visible_line_count(),title.get_line_count(),title.text]))
 var art=view.inspection.find_child("InspectionImage",true,false) as TextureRect
 var cost=view.inspection.find_child("InspectionCost",true,false) as Control
 expect(art!=null and absf(art.get_global_rect().get_center().x-panel.get_center().x)<1,label+" card image is centered")
 expect(art!=null and title!=null and title.get_global_rect().position.y>=art.get_global_rect().end.y,label+" title is below the card image")
 if cost!=null:
  expect(cost.get_global_rect().position.y>=title.get_global_rect().end.y and absf(cost.get_global_rect().position.x-title.get_global_rect().position.x)<1,label+" color cost is left aligned below the title")
 var text=view.inspection_text
 expect(text.get_global_rect().position.y>=(cost.get_global_rect().end.y if cost!=null else title.get_global_rect().end.y),label+" effects start below the color cost")
 expect(text.get_theme_font_size("normal_font_size")>=18 and text.size.y>=100,label+" effects keep readable text and scrolling height "+str(text.size))
 expect(text.scroll_active and panel.grow(1).encloses(text.get_global_rect()),label+" long effects scroll inside the panel")
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
 var longest_name="53"
 for id in Store.CARDS:
  if str(Store.CARDS[id].get("rules_text","")).length()>str(Store.CARDS[longest].get("rules_text","")).length():longest=id
  if str(Store.CARDS[id].get("name","")).length()>str(Store.CARDS[longest_name].get("name","")).length():longest_name=id
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
   for id in ["53","100","spell-fdn-039","spell-fdf-048",longest,longest_name]:
    await inspect(id);verify_bounds(label+"/"+id)
    expect(view.table.camera_offset.is_equal_approx(saved_offset) and is_equal_approx(view.table.camera_frame_scale,saved_scale),label+" opening preview never shifts or shrinks the battlefield")
    await capture("inspection-wide-"+str(sample.size.x)+"-"+str(sample.dpi)+("-2d" if top_down else "-3d")+"-"+id)
    if id==longest:
     var effects=view.inspection_text
     effects.text=(effects.get_parsed_text()+"\n").repeat(6);await frames()
     var start=effects.get_global_rect().get_center()
     var touch=InputEventScreenTouch.new();touch.index=0;touch.position=start;touch.pressed=true
     root.push_input(touch,true);await process_frame
     var drag=InputEventScreenDrag.new();drag.index=0;drag.position=start-Vector2(0,100);drag.relative=Vector2(0,-100)
     root.push_input(drag,true);await process_frame
     touch=touch.duplicate();touch.position=drag.position;touch.pressed=false;root.push_input(touch,true);await frames()
     expect(effects.get_v_scroll_bar().value>0 and view.camera_touches.is_empty() and view.android_card_touch.finger<0,label+" long preview scroll stays inside overlay without a board gesture "+str([effects.get_v_scroll_bar().value,effects.get_v_scroll_bar().max_value,effects.get_v_scroll_bar().page,view.camera_touches,view.android_card_touch.finger]))
    view.render();await frames()
    expect(view.inspection.visible and view.table.camera_offset.is_equal_approx(saved_offset) and is_equal_approx(view.table.camera_frame_scale,saved_scale),label+" repeated battle renders keep the battlefield unchanged")
    await dismiss()
    expect(not view.inspection.visible,label+" tapping outside closes preview")
    expect(view.table.camera_offset.is_equal_approx(saved_offset) and is_equal_approx(view.table.camera_frame_scale,saved_scale),label+" closing preview restores the original camera")
   view.table.camera_offset+=Vector3(0.8,0,0.4);view.table.camera_frame_scale*=0.92;view.table.set_camera()
   saved_offset=view.table.camera_offset;saved_scale=view.table.camera_frame_scale
   await inspect("53");await dismiss()
   expect(view.table.camera_offset.is_equal_approx(saved_offset) and is_equal_approx(view.table.camera_frame_scale,saved_scale),label+" manual camera pan and zoom survive preview")
  # Ranked names and stars add a second line to the player panels.
  view.network_session=RankedSession.new();view.responsive.measure(view)
  var rank_panel=view.responsive.inspection_rect()
  expect(not rank_panel.intersects(view.responsive.enemy_life) and not rank_panel.intersects(view.responsive.own_life),str(sample.size)+" ranked ID panels remain fully outside preview")
  expect(rank_panel.position.y>=view.responsive.enemy_life.end.y and rank_panel.end.y<=view.responsive.own_life.position.y,str(sample.size)+" ranked IDs constrain preview height")
  view.network_session=null;view.responsive.measure(view)
  app.menu();await frames()
 # The colleague's optional Android board must also retain its geometry under details.
 app.android_experimental_battle_ui=true;app.begin_battle(true);view=app.duel_view;e=view.engine
 view.set_process(false);view.replay_recording.finished=true
 clean();var unit=put("53","field");put("100","palette");put("53","hand")
 view.render();await frames()
 var board_rect=view.android_board.get_global_rect()
 var unit_rect=view.android_board.cards["card_"+str(unit.uid)].get_global_rect()
 await inspect("53");verify_bounds("experimental board")
 expect(view.android_board.get_global_rect()==board_rect and view.android_board.cards["card_"+str(unit.uid)].get_global_rect()==unit_rect,"experimental board and units stay in place beneath preview")
 await capture("inspection-experimental-overlay")
 await dismiss()
 expect(not view.inspection.visible and view.android_board.get_global_rect()==board_rect,"experimental preview outside dismissal does not resize board")
 print("ANDROID INSPECTION LAYOUT ",checks," checks; failures=",failures)
 app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
