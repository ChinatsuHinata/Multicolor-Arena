extends "res://tests/support/ui_base.gd"

const Hold=preload("res://scripts/card_preview_hold_settings.gd")

func frames(count: int=4):
 for i in range(count):await process_frame

func run():
 var fixture=ProjectSettings.globalize_path("res://work/android-preview-hold/"+str(Time.get_ticks_usec()))
 DirAccess.make_dir_recursive_absolute(fixture)
 Store.Paths.root_override=fixture
 var settings_file=fixture.path_join("settings.json")
 var file=FileAccess.open(settings_file,FileAccess.WRITE)
 file.store_string('{"android_card_preview_seconds":0.6}');file.close()
 root.size=Vector2i(1280,720)
 root.content_scale_size=Vector2i(1280,720)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate()
 app.settings_path=settings_file
 root.add_child(app);await frames()
 expect(is_equal_approx(app.android_card_preview_seconds,0.6) and is_equal_approx(Hold.seconds,0.6),"saved Android card hold delay is restored")
 app.is_android=true;app.layout_dpi_override=240;app.layout_safe_override=Rect2(40,12,1200,684)
 app.settings();await frames()
 var slider=app.screen.find_child("AndroidCardPreviewDuration",true,false) as HSlider
 var grid=app.screen.find_child("AndroidSettingsSwitches",true,false) as GridContainer
 var footer=app.screen.find_child("AndroidSettingsFooter",true,false) as HBoxContainer
 expect(slider!=null and grid!=null and footer!=null,"Android settings expose delay and compact rows")
 if slider!=null:
  expect(is_equal_approx(slider.value,0.6) and slider.min_value<=0.2 and slider.max_value>=3.0,"delay slider is continuous and loads the saved value")
  slider.value=0.4
  expect(is_equal_approx(app.android_card_preview_seconds,0.4) and is_equal_approx(Hold.seconds,0.4),"slider updates the live inspection threshold")
  var saved=JSON.parse_string(FileAccess.get_file_as_string(settings_file))
  expect(saved is Dictionary and is_equal_approx(float(saved.get("android_card_preview_seconds",0)),0.4),"delay is saved for next launch")
  var touch=preload("res://scripts/android_card_touch.gd").new()
  touch.begin_ring(app.screen,slider.get_global_rect().get_center(),func():pass,func():return true)
  expect(is_instance_valid(touch.ring) and is_equal_approx(touch.ring.duration,0.4),"battle card ring uses the adjusted threshold")
  touch.cancel_ring()
  var card=preload("res://scripts/deck_card.gd").new();card.is_android=true;app.screen.add_child(card);await frames()
  card.begin_touch_hold(Vector2(100,100))
  expect(is_instance_valid(card.hold_ring) and is_equal_approx(card.hold_ring.duration,0.4),"deck card ring uses the same threshold")
  card.cancel_touch_hold()
 if grid!=null and footer!=null:
  expect(grid.columns==2 and grid.get_child_count()==6,"landscape setting switches use two columns")
  var scroll=app.screen.get_child(0).get_child(1) as ScrollContainer
  var content=scroll.get_child(0) as Control if scroll!=null else null
  expect(scroll!=null and content!=null and content.get_combined_minimum_size().y<=scroll.size.y+1,"Android setting contents fit one screen at 1280×720")
  expect(content!=null and content.get_combined_minimum_size().x<=scroll.size.x+1,"1280×720 setting rows have no horizontal overflow")
 root.size=Vector2i(1920,1080)
 app.layout_dpi_override=320;app.layout_safe_override=Rect2(48,16,1824,1048)
 app.settings();await frames()
 var wide_scroll=app.screen.get_child(0).get_child(1) as ScrollContainer
 var wide_content=wide_scroll.get_child(0) as Control
 expect(wide_content.get_combined_minimum_size().x<=wide_scroll.size.x+1 and wide_content.get_combined_minimum_size().y<=wide_scroll.size.y+1,"1920×1080 setting controls fit one screen without horizontal overflow")
 expect(is_equal_approx(Hold.normalize(-5),Hold.MIN_SECONDS) and is_equal_approx(Hold.normalize(9),Hold.MAX_SECONDS) and is_equal_approx(Hold.normalize(NAN),Hold.DEFAULT_SECONDS),"invalid and out-of-range delays are normalized")
 print("ANDROID PREVIEW HOLD: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
