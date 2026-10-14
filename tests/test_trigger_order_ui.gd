extends "res://tests/support/ui_base.gd"

func frames(count: int=6):
 for i in range(count):await process_frame

func fixture(count: int) -> Array:
 clean();var ids=[]
 for i in range(count):
  var card=put(["53","70","35"][i%3],"field")
  ids.append(card.uid)
  e.triggers.append({"owner":0,"source":card.duplicate(true),"effect":"untap","name":"排序测试 "+str(i),"optional":false,"ability_text":"触发能力 %d：重置来源单位。" % (i+1)})
 e.pump_choices();view.trigger_order_draft_key="";view.render();await frames()
 return ids

func touch_drag(from: Vector2,to: Vector2):
 var echo=InputEventMouseButton.new();echo.device=-1;echo.button_index=MOUSE_BUTTON_LEFT;echo.pressed=true;echo.position=from;echo.global_position=from
 root.push_input(echo,true);await process_frame
 var down=InputEventScreenTouch.new();down.index=4;down.position=from;down.pressed=true
 root.push_input(down,true);await process_frame
 var motion=InputEventScreenDrag.new();motion.index=4;motion.position=from+Vector2(0,18);motion.relative=Vector2(0,18)
 root.push_input(motion,true);await process_frame
 var mouse_motion=InputEventMouseMotion.new();mouse_motion.device=-1;mouse_motion.position=from+Vector2(0,18);mouse_motion.global_position=mouse_motion.position;mouse_motion.button_mask=MOUSE_BUTTON_MASK_LEFT
 root.push_input(mouse_motion,true);await process_frame
 motion=motion.duplicate();motion.relative=to-motion.position;motion.position=to
 root.push_input(motion,true);await process_frame
 await create_timer(1.3).timeout
 await capture("trigger-order-dragging")
 down=down.duplicate();down.position=to;down.pressed=false;root.push_input(down,true);await frames()

func swipe(from: Vector2,to: Vector2):
 var down=InputEventScreenTouch.new();down.index=3;down.position=from;down.pressed=true
 root.push_input(down,true);await process_frame
 var motion=InputEventScreenDrag.new();motion.index=3;motion.position=to;motion.relative=to-from
 root.push_input(motion,true);await process_frame
 down=down.duplicate();down.position=to;down.pressed=false;root.push_input(down,true);await frames()

func check_layout(label: String):
 var panel=view.modal_root.get_child(0) as Control
 var list=view.trigger_order_list
 expect(panel.get_meta("trigger_order",false) and app.ui_metrics.safe.grow(1).encloses(panel.get_global_rect()),label+" trigger popup stays centered inside safe bounds")
 expect(absf(panel.get_global_rect().get_center().x-app.ui_metrics.safe.get_center().x)<1,label+" popup is horizontally centered")
 expect(panel.get_global_rect().encloses(list.scroll.get_global_rect()),label+" list scroll remains inside the popup")
 for i in range(list.rows.size()):
  var row=list.rows[i]
  expect(row.get_global_rect().size.x<=list.scroll.size.x+1,label+" row fits the list width")
  if i>0:expect(row.position.y>=list.rows[i-1].position.y+list.rows[i-1].size.y,label+" triggers form one vertical column")
 var confirm=panel.find_child("ConfirmTriggerOrder",true,false)
 expect(confirm!=null and panel.get_global_rect().encloses(confirm.get_global_rect()),label+" confirmation stays visible outside the scrolling list")
 var hint=panel.find_child("TriggerOrderHint",true,false) as Label
 expect(panel.get_global_rect().encloses(hint.get_global_rect()) and hint.get_visible_line_count()==hint.get_line_count(),label+" ordering instructions fit without clipping")

func check_device(android: bool,label: String,dimensions: Vector2i=Vector2i(1600,900)):
 if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
 root.size=dimensions;app.is_android=android;app.layout_dpi_override=320.0 if android else 0.0
 app.layout_safe_override=Rect2(60,0,dimensions.x-84,dimensions.y-24) if android else Rect2()
 await frames();app.refresh_responsive_layout();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine;await frames()
 var ids=await fixture(3);check_layout(label)
 var list=view.trigger_order_list;var before=snapshot()
 expect(view.trigger_order_draft==[2,1,0],label+" initial list matches default top-to-bottom stack order")
 var from=list.handles[0].get_global_rect().get_center()
 var to=list.scroll.get_global_rect().end-Vector2(100,4)
 if android:await touch_drag(from,to)
 else:await drag(from,to);await frames()
 expect(view.trigger_order_draft==[1,0,2] and snapshot()==before,label+" real drag and edge scrolling update only the draft")
 view.render();await frames()
 expect(view.trigger_order_draft==[1,0,2],label+" rebuilding the dialog preserves the local draft")
 list=view.trigger_order_list
 await drag(list.handles[0].get_global_rect().get_center(),list.scroll.get_global_rect().end-Vector2(100,4),true);await frames()
 expect(view.trigger_order_draft==[1,0,2] and snapshot()==before,label+" canceled drag leaves the draft and duel unchanged")
 await capture("trigger-order-"+label)
 await press("确认顺序");await frames()
 expect(e.pending.is_empty() and e.stack.map(func(entry):return entry.source.uid)==[ids[2],ids[0],ids[1]],label+" confirmation submits the entire displayed order")
 var shown=view.stack_panel.column.get_children().map(func(row):return row.get_meta("stack_id"))
 expect(shown==[e.stack[2].id,e.stack[1].id,e.stack[0].id],label+" stack UI displays exactly the confirmed top-to-bottom order")

 await fixture(20);check_layout(label+" many")
 list=view.trigger_order_list
 if android:
  var start=list.scroll.get_global_rect().get_center()+Vector2(120,100)
  await swipe(start,start-Vector2(0,180))
  expect(list.scroll.scroll_vertical>0 and view.trigger_order_draft==range(20).map(func(i):return 19-i),label+" swiping the row body scrolls without reordering")
 list.scroll.scroll_vertical=100000;await frames()
 expect(list.rows.back().get_global_rect().end.y<=list.scroll.get_global_rect().end.y+1 and list.rows.back().get_global_rect().end.y>list.scroll.get_global_rect().position.y,label+" last item is reachable in a large batch")
 await capture("trigger-order-"+label+"-many")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/trigger-order-ui/"+str(Time.get_ticks_usec()))
 root.size=Vector2i(1600,900)
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();app.tutorial_local_directory="res://work/trigger-order-ui/tutorials";root.add_child(app);await process_frame
 app.load_test_decks()
 await check_device(false,"desktop")
 await check_device(true,"android")
 await check_device(true,"android-small",Vector2i(1280,720))
 print("TRIGGER_ORDER_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
