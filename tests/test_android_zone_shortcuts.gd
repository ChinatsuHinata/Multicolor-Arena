extends "res://tests/support/ui_base.gd"

var output="res://work/android-zone-shortcuts"
var screenshot_size=Vector2i(2340,1080)
var shortcuts

func frames(count: int=8):
 for i in range(count):await process_frame

func shot(title: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var image=root.get_texture().get_image()
 if image.get_size()!=screenshot_size:image.resize(screenshot_size.x,screenshot_size.y,Image.INTERPOLATE_LANCZOS)
 image.save_png(output.path_join(title+".png"))

func touch(at: Vector2,pressed: bool,index: int=0,cancelled: bool=false):
 var event=InputEventScreenTouch.new();event.position=at;event.index=index;event.pressed=pressed;event.canceled=cancelled
 root.push_input(event,true);await frames(2)

func motion(at: Vector2,index: int=0):
 var event=InputEventScreenDrag.new();event.position=at;event.index=index
 root.push_input(event,true);await frames(2)

func tap(button: Control):
 var ancestor=button.get_parent()
 while ancestor!=null:
  if ancestor is ScrollContainer:ancestor.ensure_control_visible(button)
  ancestor=ancestor.get_parent()
 await frames()
 var at=button.get_global_rect().get_center()
 await touch(at,true);await touch(at,false);await frames()

func close_browser():
 view.close_debug();view.inspect_id="";view.update_inspection();await frames()

func fill_board():
 clean()
 for who in range(2):
  for i in range(7):put(["53","100","164","169"][i%4],"palette",who)
  for i in range(3):put("53","field",who)
  for i in range(7):put(["53","100","164","169"][i%4],"hand",who)
  for i in range(3+who):put(["53","100","164"][i%3],"grave",who)
  put("100" if who==0 else "169","exile",who)
 view.render();await settle();await frames()
 view.banner.hide()

func verify_layout(label: String):
 expect(shortcuts.is_visible_in_tree(),label+" shortcuts are visible")
 var rects=[]
 for key in shortcuts.KEYS:
  var rect: Rect2=shortcuts.buttons[key].get_global_rect()
  expect(app.ui_metrics.safe.grow(1).encloses(rect),label+" "+key+" stays inside safe area")
  expect(rect.size.is_equal_approx(Vector2.ONE*app.ui_metrics.hit*1.5),label+" "+key+" uses a 1.5x touch target")
  expect(shortcuts.buttons[key].get_node("ZoneIcon").size.is_equal_approx(Vector2.ONE*app.ui_metrics.hit*0.9),label+" "+key+" icon is enlarged by 1.5x")
  expect(not rect.intersects(view.hand_scroll.get_global_rect()),label+" "+key+" clears own hand")
  expect(view.enemy_nodes.values().all(func(card):return not rect.intersects(card.get_global_rect())),label+" "+key+" clears enemy hand")
  expect(not rect.intersects(view.responsive.hand_toggle_rect),label+" "+key+" clears the hand toggle")
  expect(not rect.intersects(view.responsive.toolbar_rect),label+" "+key+" clears the toolbar")
  for other in rects:expect(not rect.intersects(other),label+" default buttons do not overlap")
  rects.append(rect)
 var own: Rect2=shortcuts.buttons.own_grave.get_global_rect()
 expect(is_equal_approx(own.end.x,view.HAND.end.x) and own.end.y<view.HAND.position.y,label+" own skull sits above the hand's upper right corner")
 var enemy: Rect2=shortcuts.buttons.enemy_grave.get_global_rect()
 if not view.enemy_nodes.is_empty():
  var first: Control=view.enemy_nodes.values()[0]
  expect(enemy.end.x<first.get_global_rect().position.x and is_equal_approx(enemy.position.y,first.get_global_rect().position.y),label+" enemy skull sits at the enemy hand's upper left corner")
 else:
  expect(enemy.end.x<view.STAGE.get_center().x-35 and is_equal_approx(enemy.position.y,view.responsive.log_rect.end.y+8),label+" hidden enemy hand retains its upper-left shortcut")
 var exile: Rect2=shortcuts.buttons.exile.get_global_rect()
 expect(is_equal_approx(exile.end.x,own.position.x-app.ui_metrics.gap) and is_equal_approx(exile.end.y,view.HAND.position.y),label+" exile shortcut touches the hand's upper edge beside the grave shortcut")
 var toggle: Rect2=view.responsive.hand_toggle_rect
 expect(is_equal_approx(toggle.end.y,view.HAND.position.y) and toggle.end.x<view.HAND.position.x,label+" hand toggle touches the hand's upper edge on the left")
 if DisplayServer.get_name()!="headless":
  for player in e.players:
   for card in player.field+[player.leader]:
    var unit: Rect2=view.target_rect(e.ref_target(card))
    expect(not unit.intersects(toggle) and not unit.intersects(exile),label+" hand/exile controls clear battle unit "+str(card.uid))

func verify_browsing():
 var camera=view.table.camera.global_transform
 for key in ["own_grave","enemy_grave","exile"]:
  await tap(shortcuts.buttons[key])
  var who=view.local_seat if key!="enemy_grave" else 1-view.local_seat
  var zone="exile" if key=="exile" else "grave"
  expect(view.debug_open and view.browser_owner==who and view.browser_zone==zone,"native touch opens "+key)
  expect(view.browser_cards.get_child_count()==e.players[who][zone].size(),key+" shows correct cards")
  expect(not shortcuts.is_visible_in_tree(),key+" browser covers shortcuts")
  expect(view.table.camera.global_transform.is_equal_approx(camera),key+" tap does not move the camera")
  if key=="exile":
   var tabs=view.browser_panel.get_node_or_null("ExileOwnerTabs")
   expect(tabs!=null,"one exile shortcut exposes both owners")
   await tap(tabs.get_node("ExileOwner"+str(1-view.local_seat)))
   expect(view.browser_zone=="exile" and view.browser_owner==1-view.local_seat,"enemy exile tab switches owner")
   expect(view.browser_cards.get_child(0).get_meta("display_id")=="169","enemy exile renders its own card")
   await shot("exile")
  await close_browser()
 expect(is_equal_approx(shortcuts.buttons.enemy_grave.get_node("ZoneIcon").rotation,PI),"enemy skull is reversed")
 expect(is_zero_approx(shortcuts.buttons.own_grave.get_node("ZoneIcon").rotation),"own skull is upright")
 view.local_seat=1;await tap(shortcuts.buttons.own_grave)
 expect(view.browser_owner==1,"own shortcut respects network seat 1")
 await close_browser();view.local_seat=0
 await create_timer(0.3).timeout
 await click(shortcuts.buttons.own_grave.get_global_rect().get_center())
 expect(view.debug_open and view.browser_owner==0 and view.browser_zone=="grave","mouse preview tap follows the same shortcut action")
 await close_browser()

func verify_dragging():
 var button: Button=shortcuts.buttons.own_grave
 var original=button.position
 var at=button.get_global_rect().get_center()
 var camera=view.table.camera.global_transform
 app.set_android_manual_camera(true)
 await touch(at,true);await motion(at+Vector2(35,0));await touch(at+Vector2(35,0),false)
 expect(button.position==original and not view.debug_open,"movement before hold neither drags nor opens the grave")
 await touch(at,true);await create_timer(0.55).timeout;await frames(2)
 expect(not shortcuts.held and is_instance_valid(shortcuts.ring) and shortcuts.ring.progress>0.45 and shortcuts.ring.progress<1.0,"one-second progress ring appears before dragging is armed")
 await shot("hold-ring")
 await create_timer(0.6).timeout;await frames(2)
 expect(shortcuts.held,"continuous long press arms dragging")
 expect(not is_instance_valid(shortcuts.ring),"completed circle clears after enabling drag")
 view.render();await frames()
 expect(shortcuts.held and shortcuts.active_key=="own_grave","HUD update during a hold preserves the gesture")
 await motion(at+Vector2(195,-32));await touch(at+Vector2(195,-32),false)
 expect(button.position.is_equal_approx(original+Vector2(195,-32)),"long press moves the button with the finger")
 expect(not view.debug_open,"releasing a drag does not open the grave")
 expect(view.table.camera.global_transform.is_equal_approx(camera) and view.camera_touches.is_empty(),"shortcut drag is isolated from manual camera gestures")
 var saved=JSON.parse_string(FileAccess.get_file_as_string(app.settings_path))
 expect(saved.android_zone_shortcut_positions.has("own_grave"),"drag position is persisted")
 var kept=button.position
 view.render();await frames()
 expect(button.position.is_equal_approx(kept),"HUD rebuild preserves the moved button")
 await shot("dragged")
 at=button.get_global_rect().get_center()
 await touch(at,true);await create_timer(1.1).timeout;await motion(at+Vector2(50,10));await touch(at+Vector2(50,10),false,0,true)
 expect(button.position.is_equal_approx(kept),"cancelled touch restores the position")
 await touch(at,true);await create_timer(1.1).timeout;await touch(at,false)
 expect(not view.debug_open and button.position.is_equal_approx(kept),"long press without movement does not activate")
 await touch(at,true);await touch(at+Vector2(200,0),true,1);await touch(at,false);await touch(at+Vector2(200,0),false,1)
 expect(shortcuts.active_key.is_empty() and not view.debug_open,"second finger cancels the pending hold")
 await touch(at,true);await create_timer(1.1).timeout;await motion(Vector2(-500,2000));await touch(Vector2(-500,2000),false)
 expect(app.ui_metrics.safe.grow(1).encloses(button.get_global_rect()),"drag clamps to the safe screen bounds")
 expect(button.position.is_equal_approx(Vector2(shortcuts.bounds.position.x,shortcuts.bounds.end.y-shortcuts.edge)),"clamp reaches the screen edge")
 # Restore the first drag for the resized/reloaded checks.
 var ratio=(kept-shortcuts.bounds.position)/shortcuts.travel()
 app.set_android_zone_shortcut_position("own_grave",ratio)
 shortcuts.bounds=Rect2();shortcuts.refresh_layout();await frames()
 app.set_android_manual_camera(false)

func verify_touch_targets():
 for key in shortcuts.KEYS:
  var button: Button=shortcuts.buttons[key]
  await create_timer(0.3).timeout
  var at=button.get_global_rect().get_center()
  var first_echo=InputEventMouseButton.new();first_echo.button_index=MOUSE_BUTTON_LEFT;first_echo.pressed=true;first_echo.position=at
  root.push_input(first_echo,true);await frames(2)
  expect(shortcuts.active_key==key and shortcuts.finger==-1,key+" mouse-first Android echo starts the hold")
  await touch(at,true)
  expect(shortcuts.active_key==key and shortcuts.finger==0 and is_instance_valid(shortcuts.ring),key+" native press takes over its earlier mouse echo")
  await touch(at,false)
  expect(view.debug_open,key+" mouse-first touch opens the zone on release")
  await close_browser()
  # A later transparent HUD control used to block native hit detection even
  # when the floating icon was visible over it.
  var cover=Control.new();cover.position=button.position;cover.size=button.size
  cover.mouse_filter=Control.MOUSE_FILTER_STOP;view.hud.add_child(cover)
  await frames()
  at=button.get_global_rect().position+Vector2(4,4)
  await touch(at,true);await touch(at,false)
  expect(view.debug_open and view.browser_zone==("exile" if key=="exile" else "grave"),key+" enlarged edge touch wins over a transparent HUD surface")
  if is_instance_valid(cover):cover.queue_free()
  await close_browser()
  at=button.get_global_rect().get_center()
  await touch(at,true);await motion(at+Vector2(4,3))
  expect(is_instance_valid(shortcuts.ring) and not shortcuts.canceled,key+" tolerates small finger jitter during the circle")
  var echo=InputEventMouseButton.new();echo.button_index=MOUSE_BUTTON_LEFT;echo.pressed=true;echo.position=at+Vector2(90,0)
  root.push_input(echo,true);await frames(2)
  expect(shortcuts.active_key==key and is_instance_valid(shortcuts.ring),key+" ignores emulated mouse events during native touch")
  await create_timer(0.55).timeout
  expect(not shortcuts.held,key+" cannot drag before one second")
  await motion(at+Vector2(40,0));await touch(at+Vector2(40,0),false)
  expect(not is_instance_valid(shortcuts.ring) and not view.debug_open,key+" early swipe cancels the circle without opening the zone")
  var original=button.position
  await touch(at,true);await create_timer(1.1).timeout;await frames(2)
  expect(shortcuts.held and not is_instance_valid(shortcuts.ring),key+" completes its one-second circle")
  var delta=Vector2(50,40)
  await motion(at+delta);await touch(at+delta,false)
  expect(button.position.is_equal_approx(shortcuts.clamp_position(original+delta)) and not view.debug_open,key+" drags only after the completed circle")
  app.android_zone_shortcut_positions.erase(key);shortcuts.refresh_layout();await frames()
  at=button.get_global_rect().get_center()
  await touch(at,true);shortcuts._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT);await frames()
  expect(shortcuts.active_key.is_empty() and not is_instance_valid(shortcuts.ring),key+" focus loss cancels the circle")
  await touch(at,false)

func verify_settings():
 view.settings_menu();await frames()
 var setting=view.modal_root.find_child("AndroidZoneShortcutsSetting",true,false)
 expect(setting is CheckButton and setting.button_pressed,"battle settings exposes an enabled toggle")
 expect(not shortcuts.is_visible_in_tree(),"settings modal blocks shortcuts")
 await shot("battle-settings")
 await tap(setting)
 expect(not app.android_zone_shortcuts,"battle setting disables shortcuts immediately")
 view.close_overlay();await frames()
 expect(not shortcuts.is_visible_in_tree(),"disabled shortcuts stay hidden on the board")
 var saved=JSON.parse_string(FileAccess.get_file_as_string(app.settings_path))
 expect(saved.android_zone_shortcuts==false,"disabled setting is saved")
 app.set_android_zone_shortcuts(true);await frames()
 expect(shortcuts.is_visible_in_tree(),"re-enabling restores the same buttons")
 await touch(shortcuts.buttons.exile.get_global_rect().get_center(),true)
 app.set_android_zone_shortcuts(false);await frames()
 expect(shortcuts.active_key.is_empty(),"disabling during a hold cancels the gesture")
 await touch(shortcuts.buttons.exile.get_global_rect().get_center(),false)
 app.set_android_zone_shortcuts(true)

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures/"+str(Time.get_ticks_usec())))
 DirAccess.make_dir_recursive_absolute(Store.Paths.root_override)
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 root.size=Vector2i(1560,720)
 app=load("res://main.tscn").instantiate()
 app.settings_path=Store.Paths.root_override.path_join("settings.json")
 app.is_android=true;app.layout_dpi_override=280
 app.layout_safe_override=Rect2(40,0,1504,704)
 root.add_child(app);await frames();app.load_legacy_test_decks();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine;shortcuts=view.android_zone_shortcuts
 await fill_board();verify_layout("2340x1080")
 expect(shortcuts.buttons.size()==3 and app.android_zone_shortcuts,"exactly three shortcuts default to enabled")
 await shot("battle-3d")
 view.table.set_top_down_view(true);view.reset_camera_view();await frames();await shot("battle-2d")
 await verify_browsing();await verify_touch_targets();await verify_dragging();await verify_settings()
 root.size=Vector2i(1280,720);screenshot_size=Vector2i(1280,720)
 app.layout_dpi_override=240;app.layout_safe_override=Rect2(32,0,1232,704)
 await frames();app.refresh_responsive_layout();await frames()
 expect(app.ui_metrics.safe.grow(1).encloses(shortcuts.buttons.own_grave.get_global_rect()),"saved position fits resized screen")
 var ratio=app.android_zone_shortcut_positions.own_grave
 expect(shortcuts.buttons.own_grave.position.is_equal_approx(shortcuts.bounds.position+Vector2(ratio[0],ratio[1])*shortcuts.travel()),"resize preserves relative placement")
 await shot("battle-1280")
 var settings_path=app.settings_path
 app.set_android_zone_shortcuts(false)
 view.queue_free();app.duel_view=null;await frames();app.settings();await frames()
 var main_setting=app.screen.find_child("AndroidZoneShortcutsSetting",true,false)
 expect(main_setting is CheckButton and not main_setting.button_pressed,"main settings exposes the saved toggle")
 await tap(main_setting);expect(app.android_zone_shortcuts,"main setting re-enables shortcuts")
 screenshot_size=Vector2i(1280,720);await shot("main-settings")
 app.queue_free();await frames()
 app=load("res://main.tscn").instantiate();app.settings_path=settings_path;app.is_android=true;app.layout_dpi_override=240
 root.add_child(app);await frames();app.load_legacy_test_decks();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);shortcuts=view.android_zone_shortcuts;await frames()
 expect(app.android_zone_shortcuts and app.android_zone_shortcut_positions.has("own_grave"),"restart loads the toggle and positions")
 expect(shortcuts.buttons.own_grave.position.is_equal_approx(shortcuts.bounds.position+Vector2(ratio[0],ratio[1])*shortcuts.travel()),"restart restores the button position")
 e=view.engine;app.android_zone_shortcut_positions={};shortcuts.bounds=Rect2()
 await fill_board();verify_layout("1280x720");await shot("battle-1280")
 for fixture in [{"size":Vector2i(1440,720),"dpi":320.0},{"size":Vector2i(1560,720),"dpi":280.0}]:
  root.size=fixture.size;app.layout_dpi_override=fixture.dpi
  app.refresh_responsive_layout();await settle();await frames();verify_layout(str(fixture.size)+" dpi "+str(fixture.dpi))
 view.queue_free();app.duel_view=null;await frames();app.is_android=false;app.layout_dpi_override=0;app.refresh_ui_metrics();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);await frames()
 expect(view.android_zone_shortcuts==null,"desktop has no floating zone buttons")
 print("ANDROID ZONE SHORTCUTS: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
