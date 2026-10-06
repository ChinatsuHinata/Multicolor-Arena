extends "res://tests/support/ui_base.gd"
## Real Lily Black choices and crowded stacks at phone sizes and touch densities.
var output="res://work/android-battle-choices"

func frames(count: int=6):
 for i in range(count):await process_frame

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))

func check_lily(prefix: String):
 clean(true)
 var lily=e.make_card("character-fdn-068",0,"hand")
 e.enter_field(lily,0);e.pump_choices();view.render();await settle();view.render();await frames()
 var panel=view.android_choice_panel
 expect(is_instance_valid(panel),prefix+" Lily Black opens a color popup")
 if not is_instance_valid(panel):return
 var scroll=panel.find_child("BattleChoiceScroll",true,false) as ScrollContainer
 var grid=panel.find_child("ChoiceGrid",true,false) as GridContainer
 expect(scroll!=null and grid!=null and grid.get_child_count()==e.COLORS.size(),prefix+" all five colors are offered")
 if scroll==null or grid==null:return
 expect(app.ui_metrics.safe.grow(1).encloses(panel.get_global_rect()),prefix+" popup stays in the safe area")
 expect(panel.get_global_rect().get_center().distance_to(app.get_viewport_rect().get_center())<1,prefix+" effect choices are centered")
 expect(grid.columns>=2,prefix+" effect buttons use multiple equal columns")
 expect(not panel.get_global_rect().intersects(view.android_back_button.get_global_rect()),prefix+" popup leaves back clear")
 scroll.scroll_vertical=roundi(scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page);await frames()
 expect(scroll.get_global_rect().grow(1).encloses(grid.get_child(grid.get_child_count()-1).get_global_rect()),prefix+" last color is reachable by scrolling")
 var confirm=panel.find_child("ChoiceConfirm",true,false) as Button
 expect(confirm!=null and not scroll.get_global_rect().intersects(confirm.get_global_rect()),prefix+" colors leave confirmation clear")
 await shot(prefix+"-lily-colors")
 var black=find_button(grid,"黑")
 if black!=null:
  await click(black.get_global_rect().get_center());await frames()
  confirm=find_button(view.hud,"确定")
  expect(confirm!=null and not confirm.disabled,prefix+" chosen color enables confirmation")
  if confirm!=null:await click(confirm.get_global_rect().get_center());await frames()
  expect(e.stack.any(func(entry):return entry.get("effect","")=="lily_color" and entry.get("target",{}).get("color","")=="黑"),prefix+" confirming black queues Lily Black's selected color")

func check_stack(prefix: String):
 clean(true)
 view.response_mode=view.ResponseMode.ON
 for i in range(6):
  var stacked=e.make_card("53",0,"stack")
  e.stack.append({"id":100+i,"kind":"card","card":stacked,"owner":0,"target":{"none":true},"name":e.cards["53"].name})
 view.render();await settle();view.render();await frames()
 var panel=view.stack_panel
 var rect=panel.get_global_rect()
 var scroll=panel.scroll.get_global_rect()
 expect(panel.visible and rect.grow(1).encloses(scroll),prefix+" stack scroll stays inside its background")
 var actions_top=view.responsive.action_scroll.get_global_rect().position.y if view.responsive.action_column.get_child_count()>0 else view.responsive.back_rect.position.y
 expect(rect.end.y<=actions_top-app.ui_metrics.gap+1,prefix+" stack ends above phase controls")
 expect(not rect.intersects(view.android_back_button.get_global_rect()),prefix+" stack leaves the back button clear")
 expect(scroll.size.y>=panel.ANDROID_CARD_SIZE.y,prefix+" stack shows a complete card")
 await shot(prefix+"-stack")
 # More or taller phase actions must claim space before the stack is placed.
 for i in range(3):
  var action=view.responsive.button(view.hud,"额外操作 %d" % i,func():pass)
  view.responsive.add_phase_action(action)
 view.responsive.position_persistent();await frames()
 rect=panel.get_global_rect()
 expect(not panel.visible or rect.end.y<=view.responsive.action_scroll.get_global_rect().position.y-app.ui_metrics.gap+1,prefix+" extra phase actions cannot overlap the stack")
 expect(view.responsive.action_scroll.get_global_rect().end.y<=view.android_back_button.get_global_rect().position.y-app.ui_metrics.gap+1,prefix+" extra phase actions stay above back")
 if panel.visible:expect(rect.grow(1).encloses(panel.scroll.get_global_rect()),prefix+" shortened stack keeps its scroll clipped")

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures/"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 app.is_android=true;app.load_legacy_test_decks()
 var cases=[{"size":Vector2i(1280,720),"dpi":240.0},{"size":Vector2i(1920,1080),"dpi":360.0},{"size":Vector2i(2340,1080),"dpi":420.0},{"size":Vector2i(2160,1080),"dpi":480.0},{"size":Vector2i(1280,720),"dpi":320.0}]
 for fixture in cases:
  if is_instance_valid(view):
   view.queue_free();app.duel_view=null;await frames();view=null
  root.size=fixture.size
  app.layout_dpi_override=fixture.dpi
  app.layout_safe_override=Rect2(60,0,fixture.size.x-84,fixture.size.y-24)
  await frames();app.refresh_responsive_layout()
  app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine;await frames()
  var prefix="%dx%d-dpi%d" % [fixture.size.x,fixture.size.y,int(fixture.dpi)]
  await check_lily(prefix)
  await check_stack(prefix)
 print("ANDROID BATTLE CHOICES: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
