extends "res://tests/support/ui_base.gd"
## Actual ability selection, then target selection, in both production layouts.
var output="res://work/battle-choice-placement"

func frames(count: int=8):
 for i in range(count):await process_frame

func tap_target(at: Vector2):
 if not view.is_android:await click(at);return
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await process_frame
 await physics_frame

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))

func check_center(panel: Panel,grid: GridContainer,label: String):
 expect(panel.get_meta("centered",false),label+" uses the central popup")
 expect(panel.get_global_rect().get_center().distance_to(app.get_viewport_rect().get_center())<1,label+" is at the screen center")
 expect(app.ui_metrics.safe.grow(1).encloses(panel.get_global_rect()),label+" stays in the safe area")
 expect(grid.columns>=2,label+" uses multiple columns")
 var scroll=grid.get_parent() as ScrollContainer
 if scroll==null:scroll=grid.get_parent().get_parent() as ScrollContainer
 expect(scroll!=null and not scroll.get_v_scroll_bar().visible,label+" fits without scrolling")
 var first=grid.get_child(0) as Button
 for button in grid.get_children():
  expect(absf(button.size.x-first.size.x)<=1 and absf(button.size.y-first.size.y)<=1,label+" buttons have equal width and height")
  expect(button.size.x<panel.size.x*0.7 and button.size.y<=maxf(90,app.ui_metrics.hit*1.5),label+" buttons remain compact")
  expect(panel.get_global_rect().encloses(button.get_global_rect()),label+" button remains inside the popup")

func check_flow(prefix: String):
 clean()
 e.cards["53"]=e.cards["53"].duplicate(true)
 for caption in ["能力甲","能力乙","能力丙"]:
  e.cards["53"].abilities.append({"实现":"activated_damage","名称":caption,"参数":{"数值":1,"费用":{},"横置":false}})
 var unit=put("53","field")
 var enemy=put("53","field",1)
 for i in range(4):put("53","hand")
 view.render();await frames();view.open_actions(unit);await frames()
 var panel=view.android_choice_panel
 expect(is_instance_valid(panel),prefix+" multi-ability popup opens")
 if not is_instance_valid(panel):return
 var grid=panel.get_node("AndroidActionScroll/ActionChoiceGrid") as GridContainer
 check_center(panel,grid,prefix+" abilities")
 await create_timer(1.5).timeout;await shot(prefix+"-abilities-center")
 var ability=grid.get_children().filter(func(button):return button.get_meta("action_type","")=="ability")[0]
 await click(ability.get_global_rect().get_center());await frames()
 panel=view.android_choice_panel
 expect(is_instance_valid(panel),prefix+" choosing an ability opens the target popup")
 if not is_instance_valid(panel):return
 expect(not panel.get_meta("centered",false) and is_equal_approx(panel.position.x,view.responsive.choice_rect.position.x),prefix+" targets move to the right stack region")
 expect(panel.get_global_rect().size.x==view.responsive.choice_rect.size.x,prefix+" target popup remains a narrow sidebar popup")
 expect(panel.has_node("BoardTargetPrompt") and panel.find_children("ChoiceTile*","Button",true,false).is_empty(),prefix+" targets are prompted without menu items")
 expect(view.picker.selected_refs().is_empty() and not view.picker.ready(),prefix+" choosing the ability waits for the player to choose a target")
 await click(view.life_widgets[1].button.get_global_rect().get_center());await frames()
 expect(view.picker.selected_refs().any(func(ref):return ref.get("player",-1)==1),prefix+" the player life area selects a player target")
 var reset=find_button(view.android_choice_panel,"重选")
 if reset!=null:await click(reset.get_global_rect().get_center());await frames()
 expect(view.picker.selected_refs().is_empty(),prefix+" reselect clears the target")
 await tap_target(view.target_rect(e.ref_target(enemy)).get_center());await frames()
 expect(view.picker.ready() and view.picker.selected_refs().any(func(ref):return ref.get("uid",0)==enemy.uid),prefix+" the actual opposing unit is chosen on the battlefield")
 if view.is_android:expect(not view.inspection.visible,prefix+" tapping a target keeps card details closed")
 expect(not view.android_choice_panel.get_meta("centered",false),prefix+" selected target stays in the right popup")
 await shot(prefix+"-target-right")
 var hide=find_button(view.android_choice_panel,"隐藏")
 expect(view.android_choice_panel.get_global_rect().encloses(hide.get_global_rect()),prefix+" target hide button stays inside its popup")
 await click(hide.get_global_rect().get_center());await frames()
 expect(not is_instance_valid(view.android_choice_panel) and is_instance_valid(view.android_choice_restore),prefix+" battlefield target prompt can be hidden")
 await click(view.android_choice_restore.get_global_rect().get_center());await frames()
 expect(view.picker.ready() and view.picker.selected_refs().any(func(ref):return ref.get("uid",0)==enemy.uid),prefix+" restoring the target prompt preserves the chosen target")
 var confirm=find_button(view.android_choice_panel,"发动")
 expect(confirm!=null and not confirm.disabled,prefix+" selected target can be submitted")
 if confirm!=null and not confirm.disabled:
  await click(confirm.get_global_rect().get_center());await frames()
  if not view.local.is_empty():
   confirm=find_button(view.hud,"发动")
   if confirm!=null and not confirm.disabled:await click(confirm.get_global_rect().get_center());await frames()
 expect(e.stack.any(func(entry):return entry.get("kind","")=="ability" and entry.get("source",{}).get("uid",0)==unit.uid and entry.get("target",{}).get("uid",0)==enemy.uid),prefix+" the actual ability is queued with the chosen target")

func check_modes(prefix: String):
 clean()
 var source=put("53","field");var enemy=put("53","field",1)
 var options=[]
 for caption in ["效果甲","效果乙","效果丙","效果丁"]:
  var option=e.ref_target(enemy);option.mode=caption;options.append(option)
 e.pending={"kind":"effect_choice","owner":0,"options":options,"trigger":{"effect":"capacity","optional":false,"source":source}}
 view.render();await frames()
 var panel=view.android_choice_panel
 var grid=panel.get_node("BattleChoiceScroll").find_child("ChoiceGrid",true,false) as GridContainer
 var scroll=panel.get_node("BattleChoiceScroll") as ScrollContainer
 expect(not scroll.get_v_scroll_bar().visible,prefix+" four effects fit without scrolling")
 check_center(panel,grid,prefix+" effect modes")
 expect(grid.columns==2,prefix+" four effects use a balanced two-by-two layout")
 await click(grid.get_child(0).get_global_rect().get_center());await frames()
 expect(is_instance_valid(view.android_choice_panel) and not view.android_choice_panel.get_meta("centered",false),prefix+" choosing a mode switches the next target step to the right")

func check_long_modes(prefix: String):
 clean()
 var source=put("53","field")
 var options=[]
 for i in range(6):options.append({"mode":"效果 %d：选择一个单位作为目标，随后处理本次能力并检查所有额外条件和持续效果" % i})
 e.pending={"kind":"effect_choice","owner":0,"options":options,"trigger":{"effect":"capacity","optional":true,"source":source}}
 view.render();await frames()
 var panel=view.android_choice_panel
 var grid=panel.get_node("BattleChoiceScroll").find_child("ChoiceGrid",true,false) as GridContainer
 var scroll=panel.get_node("BattleChoiceScroll") as ScrollContainer
 expect(not scroll.get_v_scroll_bar().visible,prefix+" six long effects fit without scrolling")
 for button in grid.get_children():
  expect(button.size.y<=app.ui_metrics.hit*1.5+1,prefix+" long effect text does not create oversized buttons")
  expect(button.tooltip_text.begins_with(button.text.get_slice("\n",0)) and button.tooltip_text.length()>button.text.length(),prefix+" long effect tooltip keeps the full description")
 if prefix.begins_with("1280x720"):await shot(prefix+"-long-effects")

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures/"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames();app.load_legacy_test_decks()
 var cases=[{"size":Vector2i(1600,900),"dpi":0.0},{"size":Vector2i(1280,720),"dpi":240.0},{"size":Vector2i(1920,1080),"dpi":360.0},{"size":Vector2i(2340,1080),"dpi":420.0},{"size":Vector2i(2160,1080),"dpi":480.0},{"size":Vector2i(1280,720),"dpi":320.0}]
 if "--quick" in OS.get_cmdline_user_args():cases=[cases[0],cases[1]]
 for fixture in cases:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  root.size=fixture.size;app.is_android=fixture.dpi>0;app.layout_dpi_override=fixture.dpi
  app.layout_safe_override=Rect2(60,0,fixture.size.x-84,fixture.size.y-24) if app.is_android else Rect2()
  await frames();app.refresh_responsive_layout();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine;await frames()
  var prefix="%dx%d-dpi%d" % [fixture.size.x,fixture.size.y,int(fixture.dpi)]
  await check_flow(prefix);await check_modes(prefix);await check_long_modes(prefix)
 print("BATTLE CHOICE PLACEMENT: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
