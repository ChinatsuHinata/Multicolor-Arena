extends "res://tests/support/ui_base.gd"
const Hold=preload("res://scripts/card_preview_hold_settings.gd")

func frames(count: int=6):
 for i in range(count):await process_frame

func capture_history(name: String):
 if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name()=="headless":return
 var directory="res://.godot-toolchain/logs/history-fast-scroll"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
 await RenderingServer.frame_post_draw
 expect(root.get_texture().get_image().save_png(directory.path_join(name+".png"))==OK,"captured "+name)

func touch(at: Vector2,pressed: bool,index: int=0,canceled: bool=false):
 var event=InputEventScreenTouch.new();event.index=index;event.position=at;event.pressed=pressed;event.canceled=canceled
 root.push_input(event,true);await process_frame

func touch_drag(at: Vector2,index: int=0):
 var event=InputEventScreenDrag.new();event.index=index;event.position=at
 root.push_input(event,true);await process_frame

func mouse(at: Vector2,pressed: bool,device: int=0):
 var event=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
 event.device=device
 root.push_input(event,true);await process_frame

func mouse_drag(at: Vector2,mask: int=MOUSE_BUTTON_MASK_LEFT):
 var event=InputEventMouseMotion.new();event.position=at;event.global_position=at;event.button_mask=mask
 root.push_input(event,true);await process_frame

func tap_track(fast: Control,fraction: float,touch_mode: bool):
 var at=fast.get_global_rect().position+Vector2(fast.size.x/2,clampf(fast.size.y*fraction,1,fast.size.y-1))
 if touch_mode:await touch(at,true);await touch(at,false)
 else:await mouse(at,true);await mouse(at,false)
 await frames()

func check_scroll(panel: Control,scroll_name: String,touch_mode: bool,prefix: String):
 var scroll=panel.get_node(scroll_name) as ScrollContainer
 var fast=panel.get_node("HistoryFastScroll")
 var bar=scroll.get_v_scroll_bar()
 expect(fast.visible and bar.max_value>bar.page,prefix+" long content has a visible fast scrollbar")
 expect(not bar.visible and panel.get_global_rect().encloses(fast.get_global_rect()),prefix+" wide fast scrollbar fits the panel without a duplicate native scrollbar")
 expect(not fast.get_global_rect().intersects(scroll.get_global_rect()),prefix+" scrollbar has a separate hit area outside cards and text")
 if touch_mode:expect(fast.size.x>=48 and fast.thumb_rect().size.y>=64,prefix+" touch track and thumb remain large even with many records")
 var before=snapshot()
 await tap_track(fast,0.0,touch_mode)
 expect(is_zero_approx(bar.value),prefix+" track top jumps directly to the start")
 await tap_track(fast,0.78,touch_mode)
 expect(bar.value/(bar.max_value-bar.page)>0.7,prefix+" a distant track press jumps most of the entire range immediately")
 if touch_mode:
  var echo_point=fast.get_global_rect().position+Vector2(fast.size.x/2,fast.size.y*0.78)
  var saved=bar.value
  await mouse(echo_point,true,-1);await mouse_drag(fast.get_global_rect().position);await mouse(echo_point,false,-1)
  expect(is_equal_approx(bar.value,saved) and not fast.mouse_dragging,prefix+" native touch mouse echoes do not capture or move the scrollbar twice")
 await tap_track(fast,1.0,touch_mode)
 expect(absf(bar.value-(bar.max_value-bar.page))<2,prefix+" track bottom jumps directly to the oldest content")
 var thumb=fast.thumb_rect()
 var at=fast.get_global_rect().position+thumb.position+Vector2(thumb.size.x/2,thumb.size.y*0.3)
 if touch_mode:await touch(at,true)
 else:await mouse(at,true)
 var value_before=bar.value
 expect(absf(value_before-(bar.max_value-bar.page))<2,prefix+" grabbing the thumb away from its center preserves the scroll position")
 if not touch_mode:
  await mouse_drag(fast.get_global_rect().position,0)
  expect(is_equal_approx(bar.value,value_before) and fast.mouse_dragging,prefix+" native window hover motion cannot move a captured thumb")
 var destination=Vector2(at.x,fast.get_global_rect().position.y+fast.grab_offset)
 if touch_mode:await touch_drag(destination)
 else:await mouse_drag(destination)
 expect(bar.value<2,prefix+" dragging the thumb traverses the complete list")
 destination=fast.get_global_rect().end+Vector2(80,80)
 if touch_mode:await touch_drag(destination);await touch(destination,false,0,true)
 else:await mouse_drag(destination);await mouse(destination,false)
 expect(absf(bar.value-(bar.max_value-bar.page))<2 and fast.finger==-1 and not fast.mouse_dragging,prefix+" dragging beyond the panel clamps to the end and releasing clears capture")
 expect(not is_instance_valid(view.history_detail_panel) or scroll_name=="HistoryDetailScroll",prefix+" dragging the track does not activate a history row")
 expect(view.inspect_id.is_empty() and view.android_card_touch.finger==-1,prefix+" scrollbar gestures do not start a card long press")
 expect(snapshot()==before,prefix+" scrollbar navigation leaves duel state unchanged")

func check_mode(android: bool):
 var prefix="android" if android else "desktop"
 if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
 root.size=Vector2i(1280,720) if android else Vector2i(1600,900)
 app.is_android=android;app.layout_dpi_override=240.0 if android else 0.0
 app.layout_safe_override=Rect2(60,0,1196,696) if android else Rect2()
 await frames();app.refresh_responsive_layout();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine;await frames();clean()
 e.history=[]
 for i in range(120):
  e.history.append({"turn":i,"phase":"main","text":"流程记录 %d：测试快速定位、滑块和卡牌触摸。"%i,"art":[{"card_id":"121","owner":0,"hidden":false}]})
 view.render();view.open_history();await frames()
 await capture_history(prefix+"-list")
 await check_scroll(view.history_panel,"HistoryScroll",android,prefix+" list")
 var fast=view.history_panel.get_node("HistoryFastScroll")
 await tap_track(fast,0.0,android)
 if not android:
  var scroll=view.history_panel.get_node("HistoryScroll")
  var wheel=InputEventMouseButton.new();wheel.position=scroll.get_global_rect().get_center();wheel.global_position=wheel.position;wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true
  root.push_input(wheel,true);await frames()
  expect(scroll.scroll_vertical>0,"desktop mouse wheel continues to scroll the history list")
 if android:
  var scroll=view.history_panel.get_node("HistoryScroll")
  var at=scroll.get_global_rect().get_center()
  await touch(at,true);await touch_drag(at-Vector2(0,150));await touch(at-Vector2(0,150),false);await frames()
  expect(scroll.scroll_vertical>50 and not is_instance_valid(view.history_detail_panel),"android list still supports normal finger scrolling without opening an entry")
  await tap_track(fast,0.0,true)
  var card=view.history_panel.find_child("HistoryEntries",true,false).get_child(0).find_child("HistoryText",true,false).get_parent().get_child(0)
  var hold_seconds=Hold.seconds;Hold.seconds=0.2
  await touch(card.get_global_rect().get_center(),true);await create_timer(0.3).timeout;await touch(card.get_global_rect().get_center(),false);await frames()
  expect(view.inspect_id=="121","android record card long press remains available next to the fast scrollbar")
  Hold.seconds=hold_seconds;view.inspect_id="";view.update_inspection();await frames()
 var revealed=[]
 for i in range(30):revealed.append({"card_id":"121","owner":0,"hidden":false})
 view.open_history_entry({"turn":5,"phase":"main","text":"大量展示","art":[],"revealed_cards":revealed});await frames()
 await capture_history(prefix+"-detail")
 await check_scroll(view.history_detail_panel,"HistoryDetailScroll",android,prefix+" detail")
 view.close_history();await frames()
 e.history=[];view.open_history();await frames()
 expect(not view.history_panel.get_node("HistoryFastScroll").visible,prefix+" empty history hides the unnecessary scrollbar")
 view.close_history();await frames()

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/history-fast-scroll/fixtures/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames();app.load_legacy_test_decks()
 await check_mode(false);await check_mode(true)
 print("HISTORY FAST SCROLL: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
