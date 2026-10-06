extends "res://tests/support/ui_base.gd"
## Production popup geometry and real continuous mouse/touch input.
var output="res://work/battle-choice-hold"

func frames(count: int=6):
 for i in range(count):await process_frame

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))

func pointer(at: Vector2,down: bool,mobile: bool,index: int=0):
 var event: InputEvent
 if mobile:
  event=InputEventScreenTouch.new();event.index=index;event.position=at;event.pressed=down
 else:
  event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=at;event.global_position=at;event.pressed=down
 root.push_input(event,true);await process_frame

func tap_button(button: Button,mobile: bool):
 var at=button.get_global_rect().get_center()
 await pointer(at,true,mobile);await pointer(at,false,mobile);await frames()

func check_menu_setting(prefix: String,mobile: bool):
 app.settings();await frames()
 var toggle=app.screen.find_child("DelayTurnEnd",true,false) as CheckButton
 expect(toggle!=null and toggle.button_pressed,prefix+" settings shows the enabled delay switch")
 if toggle==null:return
 expect(app.ui_metrics.safe.grow(1).encloses(toggle.get_global_rect()),prefix+" delay switch fits inside the settings page")
 await tap_button(toggle,mobile)
 expect(not app.delay_turn_end and JSON.parse_string(FileAccess.get_file_as_string(app.settings_path)).get("delay_turn_end",true)==false,prefix+" disabling the switch saves the preference")
 app.settings();await frames()
 toggle=app.screen.find_child("DelayTurnEnd",true,false) as CheckButton
 expect(toggle!=null and not toggle.button_pressed,prefix+" reopening settings preserves the disabled switch")
 if toggle:await tap_button(toggle,mobile)
 expect(app.delay_turn_end,prefix+" the settings switch can enable the delay again")
 await shot(prefix+"-settings")

func check_battle_setting(prefix: String,mobile: bool):
 clean(false)
 put("53","hand");put("53","field");put("53","field",1)
 view.render();await settle();await frames()
 var button=view.hud.find_child("MainPhaseEnd",true,false)
 var before=snapshot();var at=button.get_global_rect().get_center()
 await pointer(at,true,mobile);await create_timer(0.2).timeout
 view.settings_menu();await frames()
 expect(not button.holding and button.progress==0,prefix+" opening settings cancels an incomplete hold")
 await pointer(at,false,mobile)
 var toggle=view.modal_root.find_child("DelayTurnEnd",true,false) as CheckButton
 expect(toggle!=null and toggle.button_pressed,prefix+" battle settings exposes the enabled delay switch")
 if toggle==null:return
 await shot(prefix+"-battle-settings")
 await tap_button(toggle,mobile)
 expect(not app.delay_turn_end,prefix+" battle settings disables the delay")
 button.hold_completed.emit()
 expect(snapshot()==before,prefix+" changing the delay with settings open does not end the phase")
 await tap_button(find_button(view.modal_root,"继续游戏"),mobile)
 button=view.hud.find_child("MainPhaseEnd",true,false)
 expect(button!=null and button.get_script()!=view.HoldConfirmButton,prefix+" disabling the delay rebuilds an immediate end button")
 if button==null:return
 view.history_open=true;button.pressed.emit()
 expect(snapshot()==before,prefix+" immediate completion is blocked while history is open")
 view.history_open=false
 view.open_tools_menu();await frames();button.pressed.emit()
 expect(snapshot()==before,prefix+" immediate completion is blocked while the tools menu is open")
 app.close_menu_popup();await frames()
 await tap_button(button,mobile)
 expect(e.phase!="main" or e.priority!=0,prefix+" a single tap ends the main phase when delay is disabled")
 clean(false);view.render();await settle();await frames()
 view.settings_menu();await frames()
 toggle=view.modal_root.find_child("DelayTurnEnd",true,false) as CheckButton
 expect(toggle!=null and not toggle.button_pressed,prefix+" battle settings preserves the disabled preference")
 if toggle==null:return
 await tap_button(toggle,mobile)
 await tap_button(find_button(view.modal_root,"继续游戏"),mobile)
 button=view.hud.find_child("MainPhaseEnd",true,false)
 expect(button!=null and button.get_script()==view.HoldConfirmButton and button.hold_seconds==2.0,prefix+" enabling the delay restores the two-second hold")

func check_popup(prefix: String):
 clean(true)
 for id in ["53","53","53","53"]:put(id,"hand")
 var lily=e.make_card("character-fdn-068",0,"hand")
 e.enter_field(lily,0);e.pump_choices();view.render();await settle();view.render();await frames()
 var panel=view.android_choice_panel
 expect(is_instance_valid(panel),prefix+" ability opens an independent popup")
 if not is_instance_valid(panel):return
 expect(panel.get_parent()==view.hud,prefix+" popup remains a floating HUD panel")
 expect(panel.get_global_rect().get_center().distance_to(app.get_viewport_rect().get_center())<1,prefix+" effect choices are centered")
 expect(app.ui_metrics.safe.grow(1).encloses(panel.get_global_rect()),prefix+" popup stays on screen")
 var hide=find_button(panel,"隐藏")
 var scroll=panel.find_child("BattleChoiceScroll",true,false) as ScrollContainer
 expect(hide!=null and hide.position.x==12 and hide.get_rect().end.y<=panel.size.y and hide.position.y>panel.size.y*0.5,prefix+" hide is at popup bottom left")
 expect(scroll!=null and scroll.size.y>=app.ui_metrics.hit,prefix+" choices have a usable scroll viewport")
 var title=panel.get_node("ChoiceTitle") as Label
 expect(title.size.y>=title.get_theme_font("font").get_height(title.get_theme_font_size("font_size")),prefix+" popup title has room to render")
 await create_timer(2.0).timeout
 await shot(prefix+"-ability-popup")
 if scroll:
  scroll.scroll_vertical=roundi(scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page);await frames()
  var black=find_button(panel,"黑")
  expect(black!=null and scroll.get_global_rect().grow(1).encloses(black.get_global_rect()),prefix+" last ability option is reachable")
  await click(black.get_global_rect().get_center());await frames()
  panel=view.android_choice_panel;hide=find_button(panel,"隐藏")
 await click(hide.get_global_rect().get_center());await frames()
 expect(view.android_choice_panel==null and is_instance_valid(view.android_choice_restore),prefix+" hide collapses the popup")
 expect(view.picker.path.size()>0,prefix+" hiding preserves the selected ability")
 await click(view.android_choice_restore.get_global_rect().get_center());await frames()
 expect(is_instance_valid(view.android_choice_panel) and view.picker.path.size()>0,prefix+" expand restores the selected ability")
 var confirm=find_button(view.android_choice_panel,"确定")
 expect(confirm!=null and not confirm.disabled,prefix+" chosen option can be confirmed")
 await click(confirm.get_global_rect().get_center());await frames()
 expect(e.stack.any(func(entry):return entry.get("effect","")=="lily_color" and entry.get("target",{}).get("color","")=="黑"),prefix+" popup submits the actual selected effect")

func check_hold(prefix: String,mobile: bool):
 clean(false)
 for id in ["53","53","53","53"]:put(id,"hand")
 put("53","field");put("53","field",1)
 view.render();await settle();await frames()
 var button=view.hud.find_child("MainPhaseEnd",true,false)
 expect(button!=null,prefix+" main phase has the hold button")
 if button==null:return
 expect(button.hold_seconds==2.0,prefix+" the confirmation requires two seconds")
 var before=snapshot();var at=button.get_global_rect().get_center()
 await pointer(at,true,mobile);await pointer(at,false,mobile)
 expect(snapshot()==before and not button.holding and button.progress==0,prefix+" a tap does not end the main phase")
 await pointer(at,true,mobile);await create_timer(1.1).timeout
 expect(button.holding and button.progress>0 and button.progress<1,prefix+" holding draws a partial circle")
 await pointer(at,false,mobile)
 expect(snapshot()==before and button.progress==0,prefix+" releasing early resets progress")
 await pointer(at,true,mobile);await create_timer(1.3).timeout
 await shot(prefix+"-hold-circle")
 var motion: InputEvent
 if mobile:
  motion=InputEventScreenDrag.new();motion.index=0;motion.position=at-Vector2(350,0)
 else:
  motion=InputEventMouseMotion.new();motion.position=at-Vector2(350,0);motion.button_mask=MOUSE_BUTTON_MASK_LEFT
 root.push_input(motion,true);await frames()
 expect(not button.holding and button.progress==0 and snapshot()==before,prefix+" moving outside cancels the hold")
 await pointer(at,false,mobile)
 await pointer(at,true,mobile);await create_timer(0.2).timeout
 if mobile:
  await pointer(at,false,true,1)
  expect(button.holding,prefix+" another finger cannot complete or cancel the hold")
 view.render();await frames()
 button=view.hud.find_child("MainPhaseEnd",true,false)
 expect(button!=null and not button.holding and snapshot()==before,prefix+" rebuilding the UI discards an incomplete hold")
 await pointer(at,false,mobile)
 await pointer(at,true,mobile);await create_timer(0.2).timeout
 view.history_open=true;await frames()
 expect(button.progress==0 and not button.holding,prefix+" an overlay cancels the hold")
 view.history_open=false;await pointer(at,false,mobile)
 await pointer(at,true,mobile)
 await create_timer(1.7).timeout
 expect(snapshot()==before and button.progress<1,prefix+" less than two continuous seconds cannot end the phase")
 await create_timer(0.5).timeout;await frames()
 expect(e.phase!="main" or e.priority!=0,prefix+" a complete two-second circle ends the main phase")
 var completed=snapshot()
 await pointer(at,false,mobile);await frames()
 expect(snapshot()==completed,prefix+" releasing after completion does not submit twice")
 await shot(prefix+"-phase-ended")

func check_test_mode_end():
 clean(true)
 put("53","hand");put("53","field");put("53","field",1)
 view.render();await settle();await frames()
 var button=view.hud.find_child("MainPhaseEnd",true,false) as Button
 expect(button!=null and button.text=="结束主要阶段","test mode offers immediate main phase completion")
 if button==null:return
 var before=snapshot()
 view.history_open=true;button.pressed.emit()
 expect(snapshot()==before,"test mode phase completion stays blocked while history is open")
 view.history_open=false
 view.open_tools_menu();await frames();button.pressed.emit()
 expect(snapshot()==before,"test mode phase completion stays blocked while the tools menu is open")
 app.close_menu_popup();await frames()
 await click(button.get_global_rect().get_center());await frames()
 expect(e.phase!="main" or e.priority!=0,"one click ends the test mode main phase without a hold")

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures/"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 var settings_file=output.path_join("settings.json")
 var legacy=FileAccess.open(settings_file,FileAccess.WRITE);legacy.store_string("{}");legacy.close()
 app=load("res://main.tscn").instantiate();app.settings_path=settings_file;root.add_child(app);await frames()
 expect(app.delay_turn_end,"older settings without the delay key default to enabled")
 app.set_delay_turn_end(false)
 var restored=load("res://main.tscn").instantiate();restored.settings_path=settings_file;root.add_child(restored);await frames()
 expect(not restored.delay_turn_end,"a fresh application restores the saved disabled preference")
 restored.set_delay_turn_end(true);restored.queue_free();await frames()
 app.delay_turn_end=true;app.load_legacy_test_decks()
 for mobile in [false,true]:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
  app.is_android=mobile;app.layout_dpi_override=240.0 if mobile else 0.0
  app.layout_safe_override=Rect2(60,0,1196,696) if mobile else Rect2()
  await frames();app.refresh_responsive_layout()
  var prefix="android" if mobile else "pc"
  await check_menu_setting(prefix,mobile)
  app.begin_battle(true)
  view=app.duel_view;view.set_process(false);e=view.engine;await frames()
  await check_popup(prefix);await check_battle_setting(prefix,mobile);await check_hold(prefix,mobile)
  if not mobile:await check_test_mode_end()
 print("BATTLE CHOICE HOLD: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
