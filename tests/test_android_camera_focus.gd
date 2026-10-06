extends "res://tests/support/ui_base.gd"

var output="res://work/android-camera-focus"
var screenshot_size=Vector2i()

func frames(count: int=8):
 for i in range(count):await process_frame

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var image=root.get_texture().get_image()
 if image.get_size()!=screenshot_size:image.resize(screenshot_size.x,screenshot_size.y,Image.INTERPOLATE_LANCZOS)
 image.save_png(output.path_join(name+".png"))

func tap(control: Control):
 await tap_point(control.get_global_rect().get_center())

func tap_point(at: Vector2):
 var event=InputEventScreenTouch.new();event.index=0
 event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true)
 await settle();await frames()

func fill_board():
 clean()
 view.android_palette_owner=-1;view.android_palette_auto_open=false
 for who in range(2):
  for i in range(10):
   var card=put(["53","100","164","169"][i%4],"palette",who)
   card.tapped=i%3==1
  for i in range(4):put("53","field",who)
  for i in range(12):put(["53","100","164","169"][i%4],"hand",who)
 view.render();await settle();await frames()

func check_palette(prefix: String):
 var area=view.responsive.camera_focus_rect()
 var bounds=view.projected_android_focus(view.android_focus_bounds())
 expect(area.grow(2).encloses(bounds),prefix+" own palette is framed above the hand")
 for card in e.players[view.local_seat].palette:
  var node=view.table.visuals["card_"+str(card.uid)]
  var rect=view.projected_card_rect(node)
  expect(not rect.intersects(view.hand_scroll.get_global_rect()),prefix+" hand leaves palette card clear "+str(card.uid))
  expect(app.ui_metrics.safe.grow(2).encloses(rect),prefix+" palette card remains in the safe area "+str(card.uid))
 var last=e.players[view.local_seat].palette.back()
 expect(view.table.card_at(view.stage_point(point(last.uid)))==last.uid,prefix+" own palette remains selectable on the board")

func check_projection(prefix: String,top_down: bool):
 view.table.set_top_down_view(top_down)
 view.android_palette_view=false;view.reset_camera_view();view.render()
 await settle();await frames()
 var toggle=view.hud.get_node_or_null("AndroidCameraFocusToggle")
 expect(toggle!=null and toggle.text=="战场视角",prefix+" second rail button shows battlefield focus")
 expect(view.hud.get_node_or_null("AndroidPaletteToggle"+str(1-view.local_seat))==null,prefix+" the enemy palette button is replaced")
 expect(find_button(view.hud,"我方颜色盘")==null,prefix+" the own palette button is removed")
 var area=view.responsive.camera_focus_rect()
 expect(area.grow(2).encloses(view.projected_android_focus(view.android_focus_bounds())),prefix+" battlefield and enemy region fit the clear area")
 var last=e.players[1-view.local_seat].palette.back()
 var enemy_rect=view.projected_card_rect(view.table.visuals["card_"+str(last.uid)])
 expect(area.grow(2).encloses(enemy_rect) and not enemy_rect.intersects(view.hand_scroll.get_global_rect()),prefix+" enemy palette stays visible in battlefield focus")
 expect(view.table.card_at(view.stage_point(point(last.uid)))==last.uid,prefix+" enemy palette stays selectable")
 if not top_down:
  for card in e.players[1-view.local_seat].palette:
   var rect=view.projected_card_rect(view.table.visuals["card_"+str(card.uid)])
   expect(view.enemy_nodes.values().all(func(tile):return not rect.intersects(tile.get_global_rect())),prefix+" opponent hand leaves enemy palette card clear "+str(card.uid))
   expect(view.hand_nodes.values().all(func(tile):return not rect.intersects(tile.get_global_rect())),prefix+" own hand leaves enemy palette card clear "+str(card.uid))
 expect(view.responsive.tools_actions().any(func(action):return action[0]=="敌方颜色盘"),prefix+" menu retains enemy palette browsing")
 var initial=view.table.camera.global_transform
 await shot(prefix+"-battlefield")
 await tap(toggle)
 expect(view.android_palette_view and view.hud.get_node("AndroidCameraFocusToggle").text=="颜色盘视角",prefix+" touch changes to own palette focus exactly once")
 expect(view.table.camera.global_transform!=initial,prefix+" focus toggle moves the camera")
 expect(view.table.camera.projection==(Camera3D.PROJECTION_ORTHOGONAL if top_down else Camera3D.PROJECTION_PERSPECTIVE),prefix+" focus toggle preserves the chosen 2D or 3D projection")
 check_palette(prefix)
 await shot(prefix+"-palette")
 view.table.pan_camera(view.stage_point(area.get_center()),view.stage_point(area.get_center()+Vector2(50,20)))
 view.table.zoom_camera(0.9)
 view.reset_camera_view();await frames()
 check_palette(prefix+" reset")
 expect(view.android_palette_view,prefix+" reset retains the selected focus")
 view.toggle_android_palette(view.local_seat);await frames()
 expect(view.android_palette_panel!=null and not view.android_palette_panel.get_global_rect().intersects(view.hand_scroll.get_global_rect()),prefix+" own palette popup also leaves the hand clear")
 view.toggle_android_palette(view.local_seat);await frames()
 await tap(view.hud.get_node("AndroidCameraFocusToggle"))
 expect(not view.android_palette_view and view.table.camera.global_transform.is_equal_approx(initial),prefix+" toggle returns to battlefield focus")

func check_possession_and_modes():
 clean()
 var source=put("100","palette",view.local_seat)
 var enemy=put("100","palette",1-view.local_seat)
 put("100","hand",view.local_seat)
 e.phase="possession";e.pending={"kind":"possession","owner":view.local_seat}
 view.render();await settle();await frames()
 expect(view.android_palette_view and view.android_palette_focus_owner()==view.local_seat and not is_instance_valid(view.android_palette_panel),"possession automatically focuses the own palette on the board")
 await tap_point(point(source.uid))
 expect(view.selected_in_zone("palette")==source.uid,"own palette can be selected for possession through the focused camera")
 view.open_tools_menu();await frames()
 var enemy_action=find_button(app.menu_popup,"敌方颜色盘")
 expect(enemy_action!=null,"enemy palette menu action opens")
 if enemy_action!=null:await tap(enemy_action)
 expect(view.android_palette_owner==1-view.local_seat and view.android_palette_tiles.has(enemy.uid),"enemy palette menu displays enemy cards")
 expect(not view.android_palette_panel.get_global_rect().intersects(view.hand_scroll.get_global_rect()),"enemy palette list also leaves the hand clear")
 view.toggle_android_palette(1-view.local_seat)
 for top_down in [true,false]:
  view.set_card_view(top_down);await frames()
  expect(view.android_palette_view and view.table.top_down_view==top_down,"settings preserve palette focus when changing projection")
  view.modal=false;view.render();await settle();await frames()
  check_palette("settings "+str(top_down))
  expect(view.selected_in_zone("palette")==source.uid,"projection change retains the possession selection")
 e.pending={};e.phase="main";view.render();await frames()
 expect(not view.android_palette_view and view.android_camera_restore.is_empty(),"leaving possession restores the original battlefield focus")

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures/"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames();app.load_legacy_test_decks()
 var cases=[{"size":Vector2i(1280,720),"dpi":240.0},{"size":Vector2i(1920,1080),"dpi":360.0},{"size":Vector2i(2340,1080),"dpi":420.0},{"size":Vector2i(2160,1080),"dpi":480.0},{"size":Vector2i(1280,720),"dpi":320.0}]
 if "--quick" in OS.get_cmdline_user_args():cases=[cases[0]]
 for fixture in cases:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  # Fit the preview window on the desktop while preserving phone aspect and dp sizes.
  var preview_scale=minf(1.0,minf(1600.0/fixture.size.x,900.0/fixture.size.y))
  screenshot_size=fixture.size
  root.size=Vector2i(Vector2(fixture.size)*preview_scale)
  app.is_android=true;app.layout_dpi_override=fixture.dpi*preview_scale
  app.layout_safe_override=Rect2(60*preview_scale,0,(fixture.size.x-84)*preview_scale,(fixture.size.y-24)*preview_scale)
  await frames();app.refresh_responsive_layout();app.begin_battle(true)
  view=app.duel_view;view.set_process(false);e=view.engine;await frames();await fill_board()
  for top_down in [true,false]:
   var prefix="%dx%d-dpi%d-%s" % [fixture.size.x,fixture.size.y,int(fixture.dpi),"2d" if top_down else "3d"]
   await check_projection(prefix,top_down)
 await check_possession_and_modes()
 # Shared table framing stays neutral on desktop.
 view.queue_free();app.duel_view=null;await frames()
 root.size=Vector2i(1600,900);app.is_android=false;app.layout_dpi_override=0;app.layout_safe_override=Rect2()
 await frames();app.refresh_responsive_layout();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);await frames()
 expect(view.hud.get_node_or_null("AndroidCameraFocusToggle")==null and is_equal_approx(view.table.camera_frame_scale,1.0),"desktop has no Android camera focus changes")
 expect(view.table.camera_offset==Vector3.ZERO,"desktop keeps its original camera center")
 print("ANDROID CAMERA FOCUS: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
