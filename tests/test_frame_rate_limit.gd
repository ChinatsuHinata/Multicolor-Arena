extends "res://tests/support/ui_base.gd"

var fixture=""

func frames(count: int=4):
 for i in range(count):await process_frame

func make_app():
 var result=load("res://main.tscn").instantiate()
 result.settings_path=fixture.path_join("settings.json")
 result.account_session_path=fixture.path_join("account.json")
 result.tutorial_local_directory=fixture.path_join("tutorials")
 root.add_child(result)
 return result

func saved_settings() -> Dictionary:
 return JSON.parse_string(FileAccess.get_file_as_string(app.settings_path))

func select_preset(control: OptionButton,index: int):
 control.select(index);control.item_selected.emit(index);await frames()

func enter_limit(input: LineEdit,value):
 input.grab_focus();input.edit();input.text=str(value)
 var event=InputEventKey.new();event.keycode=KEY_ENTER;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true)
 await frames()

func check_settings(mobile: bool):
 var prefix="Android" if mobile else "desktop"
 root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
 root.content_scale_size=root.size
 app.is_android=mobile;app.layout_dpi_override=240 if mobile else 0
 app.layout_safe_override=Rect2(40,12,1200,684) if mobile else Rect2()
 app.settings();await frames()
 var control=app.screen.find_child("FrameRateLimit",true,false) as LineEdit
 var preset=app.screen.find_child("FrameRatePreset",true,false) as OptionButton
 expect(control!=null and preset!=null,prefix+" settings expose presets and a text input")
 if control==null or preset==null:return
 expect(preset.item_count==3 and app.screen.find_children("*","SpinBox",true,false).is_empty(),prefix+" frame rate has three presets and no increment or decrement buttons")
 expect(app.ui_metrics.safe.grow(1).encloses(control.get_global_rect()) and app.ui_metrics.safe.grow(1).encloses(preset.get_global_rect()),prefix+" frame rate controls fit the safe area")
 await select_preset(preset,0)
 expect(not control.editable and control.text=="60" and app.frame_rate_limit==60 and Engine.max_fps==60,prefix+" 60 FPS preset applies and locks text entry")
 control.text_submitted.emit("90")
 expect(app.frame_rate_limit==60,prefix+" preset ignores custom text submission")
 await select_preset(preset,1)
 expect(not control.editable and control.text=="120" and app.frame_rate_limit==120 and Engine.max_fps==120,prefix+" 120 FPS preset applies and locks text entry")
 await select_preset(preset,2)
 expect(control.editable,prefix+" custom preset enables text entry")
 await enter_limit(control,144)
 expect(app.frame_rate_limit==144 and Engine.max_fps==144,prefix+" typed limit applies immediately")
 expect(int(saved_settings().get("frame_rate_limit",-1))==144 and saved_settings().get("delay_turn_end",true)==false,prefix+" limit saves without changing other preferences")
 await capture("frame-rate-limit-"+prefix)
 app.menu();app.settings();await frames()
 control=app.screen.find_child("FrameRateLimit",true,false) as LineEdit
 preset=app.screen.find_child("FrameRatePreset",true,false) as OptionButton
 expect(control!=null and control.editable and control.text=="144" and preset.selected==2 and Engine.max_fps==144,prefix+" reopening settings keeps the custom cap and mode")
 if control!=null and preset!=null:
  await select_preset(preset,0);await select_preset(preset,2)
  expect(control.editable and control.text=="144" and Engine.max_fps==144,prefix+" switching back to custom restores its previous value")
  await enter_limit(control,"oops")
  expect(control.text=="144" and Engine.max_fps==144,prefix+" invalid custom text restores the active value")
  await enter_limit(control,9999)
  expect(control.text==str(app.MAX_FRAME_RATE_LIMIT) and Engine.max_fps==app.MAX_FRAME_RATE_LIMIT,prefix+" out-of-range custom input is clamped")
  control.grab_focus();control.text="90";control.release_focus();await frames()
  expect(app.frame_rate_limit==90 and Engine.max_fps==90,prefix+" leaving custom text input applies the value")
  await enter_limit(control,0)
  expect(app.frame_rate_limit==0 and Engine.max_fps==0 and int(saved_settings().frame_rate_limit)==0,prefix+" zero removes and saves the cap")
 app.begin_battle(true);view=app.duel_view;await settle();await frames()
 view.set_process(false);view.settings_menu();await frames()
 control=view.ui.find_child("FrameRateLimit",true,false) as LineEdit
 preset=view.ui.find_child("FrameRatePreset",true,false) as OptionButton
 expect(control!=null and preset!=null,prefix+" battle settings expose the same presets and custom input")
 if control!=null and preset!=null:
  expect(app.ui_metrics.safe.grow(1).encloses(control.get_global_rect()),prefix+" battle frame rate control fits the safe area")
  await select_preset(preset,0)
  expect(not control.editable and Engine.max_fps==60,prefix+" battle preset applies and locks text entry")
  await select_preset(preset,2)
  await enter_limit(control,120)
  expect(app.frame_rate_limit==120 and Engine.max_fps==120 and int(saved_settings().frame_rate_limit)==120,prefix+" battle edits update and save the global cap")
 await capture("frame-rate-limit-battle-"+prefix)

func run():
 var previous_cap=Engine.max_fps
 fixture="res://work/frame-rate-limit/"+str(Time.get_ticks_usec())
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture.path_join("tutorials")))
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 var file=FileAccess.open(fixture.path_join("settings.json"),FileAccess.WRITE)
 file.store_string('{"delay_turn_end":false}');file.close()
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=make_app();await frames()
 expect(app.frame_rate_limit==0 and Engine.max_fps==0,"existing settings without a cap keep the default unlimited rate")
 expect(app.normalize_frame_rate_limit(-5)==0 and app.normalize_frame_rate_limit(9999)==app.MAX_FRAME_RATE_LIMIT,"out-of-range caps are clamped")
 expect(app.normalize_frame_rate_limit("invalid")==0 and app.normalize_frame_rate_limit(NAN)==0,"invalid caps fall back to unlimited")
 for mobile in [false,true]:await check_settings(mobile)
 app.queue_free();view=null;await frames()
 app=make_app();await frames()
 expect(app.frame_rate_limit==120 and app.frame_rate_preset=="custom" and Engine.max_fps==120,"custom 120 FPS remains custom on restart")
 app.set_frame_rate_limit(60);app.set_frame_rate_preset("120")
 app.queue_free();await frames();app=make_app();await frames()
 expect(app.frame_rate_preset=="120" and app.frame_rate_limit==120 and app.custom_frame_rate_limit==60 and Engine.max_fps==120,"fixed preset and remembered custom value survive restart")
 app.set_frame_rate_preset("custom")
 expect(app.frame_rate_limit==60 and Engine.max_fps==60,"returning to custom after restart restores its saved value")
 app.set_frame_rate_limit(0);app.queue_free();await frames()
 app=make_app();await frames()
 expect(app.frame_rate_limit==0 and Engine.max_fps==0,"unlimited choice survives restart")
 app.queue_free();await frames()
 file=FileAccess.open(fixture.path_join("settings.json"),FileAccess.WRITE)
 file.store_string('{"frame_rate_limit":60}');file.close()
 app=make_app();await frames()
 expect(app.frame_rate_preset=="60" and Engine.max_fps==60,"saved numeric 60 FPS automatically selects the matching preset")
 app.queue_free();await frames();Engine.max_fps=previous_cap
 print("FRAME RATE LIMIT: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
