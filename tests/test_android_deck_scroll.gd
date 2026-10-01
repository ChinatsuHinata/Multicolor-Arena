extends "res://tests/support/ui_base.gd"
## Native finger input on the production Android deck list.

func frames(count: int=6):
 for i in range(count):await process_frame

func touch(at: Vector2,pressed: bool,canceled: bool=false):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=pressed;event.canceled=canceled
 root.push_input(event,true);await process_frame

func finger_drag(at: Vector2,delta: Vector2):
 var event=InputEventScreenDrag.new();event.index=0;event.position=at;event.relative=delta
 root.push_input(event,true);await process_frame

func swipe(from: Vector2,deltas: Array) -> Dictionary:
 var scroll=app.main_scroll
 var before=scroll.scroll_vertical;var at=from;var distance=0.0;var error=0.0;var dragged=false
 await touch(at,true)
 for delta in deltas:
  at+=delta;distance-=delta.y
  await finger_drag(at,delta)
  if absf(distance)>=12:
   var expected=clampf(before+distance,0,scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page)
   error=maxf(error,absf(scroll.scroll_vertical-expected))
  dragged=dragged or root.gui_is_dragging()
 await touch(at,false);await frames()
 return {"distance":app.main_scroll.scroll_vertical-before,"error":error,"dragged":dragged}

func row_at_scroll_center() -> Vector2:
 var area=app.main_scroll.get_global_rect().grow(-10)
 var tiles=app.main_content.find_children("*","Panel",true,false)
 for tile in tiles:
  if tile.get_script()==preload("res://scripts/deck_card.gd") and tile.source_zone=="main" and area.encloses(tile.get_global_rect()):
   if tile.get_global_rect().get_center().y>area.position.y+area.size.y*0.4:return tile.get_global_rect().get_center()
 return area.get_center()

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/android-deck-scroll-"+name+".png")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-deck-scroll-tests/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720)
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND;root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 app.is_android=true;app.layout_dpi_override=240
 var ids=[]
 for id in Store.CARDS:
  if Store.CARDS[id].kind!="自机" and app.RuleSet.allowed(id,Store.CARDS[id],"test"):ids.append(id)
 for dimensions in [Vector2i(1280,720),Vector2i(2400,1080)]:
  root.size=dimensions;app.layout_dpi_override=float(dimensions.y)/3.0;await frames()
  for count in [50,70]:
   app.draft=Store.blank("主卡组滑动测试");app.draft.rule_set="test";app.draft.leader="70"
   app.draft.main=ids.slice(0,count);app.draft.side=ids.slice(count,count+10)
   var textures_before=app.textures.keys()
   app.android_editor_overview=false;app.set_meta("android_editor_list_zone","main");app.editor();await frames(12)
   var ui=app.editor_ui;var scroll=app.main_scroll
   var tag="%d cards at %s" % [count,dimensions]
   var before=app.draft.duplicate(true);var dirty=app.dirty
   expect(scroll.get_v_scroll_bar().max_value>scroll.get_v_scroll_bar().page+1,"main list is scrollable: "+tag)
   expect(app.textures.keys()==textures_before,"building text-only deck rows does not load full card textures: "+tag)
   var deltas=[]
   for i in range(10):deltas.append(Vector2(0,-18))
   var result=await swipe(row_at_scroll_center(),deltas)
   expect(result.distance==180 and result.error<=1 and not result.dragged,"upward row swipe tracks every finger step: "+tag)
   deltas.clear()
   for i in range(10):deltas.append(Vector2(0,18))
   result=await swipe(row_at_scroll_center(),deltas)
   expect(result.distance==-180 and result.error<=1 and not result.dragged,"downward row swipe tracks every finger step: "+tag)
   var gap_start=row_at_scroll_center()-Vector2(0,ui.list_height*0.5+ui.deck_gap*0.5)
   result=await swipe(gap_start,[Vector2(13,-9),Vector2(0,-24),Vector2(0,-24)])
   expect(result.distance==57 and not result.dragged,"a swipe starting between rows also scrolls the main list: "+tag)
   app.main_scroll.scroll_vertical=200;await frames()
   deltas=[Vector2(0,-16)]
   for i in range(64):deltas.append(Vector2(0,-0.25))
   result=await swipe(row_at_scroll_center(),deltas)
   print("SLOW SWIPE ",tag," ",result)
   expect(absf(result.distance-32)<=1 and result.error<=1 and not result.dragged,"slow fractional movement accumulates without stalling: "+tag)
   app.main_scroll.scroll_vertical=200;await frames()
   deltas=[Vector2(13,-9)]
   for i in range(8):deltas.append(Vector2(1,-18))
   result=await swipe(row_at_scroll_center(),deltas)
   print("DIAGONAL SWIPE ",tag," ",result)
   expect(absf(result.distance-153)<=1 and result.error<=1 and not result.dragged,"a slightly diagonal swipe stays in the list without starting a card drag: "+tag)
   expect(app.draft==before and app.dirty==dirty and not is_instance_valid(ui.details_overlay) and not root.gui_is_dragging(),"swipes neither inspect nor modify the deck: "+tag)
   scroll=app.main_scroll
   scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value);await frames()
   var bottom=scroll.scroll_vertical
   result=await swipe(row_at_scroll_center(),[Vector2(0,-24),Vector2(0,-24)])
   expect(scroll.scroll_vertical==bottom and not result.dragged,"bottom edge clamps scrolling without dragging a card: "+tag)
   result=await swipe(row_at_scroll_center(),[Vector2(0,24),Vector2(0,24)])
   expect(result.distance==-48 and not result.dragged,"downward swipe immediately moves away from the bottom edge: "+tag)
   await shot("bottom-%d-%d" % [count,dimensions.x])
   scroll.scroll_vertical=0;await frames()
   result=await swipe(row_at_scroll_center(),[Vector2(0,24),Vector2(0,24)])
   expect(scroll.scroll_vertical==0 and not result.dragged,"top edge clamps scrolling without dragging a card: "+tag)
   var at=row_at_scroll_center();await touch(at,true)
   await finger_drag(at+Vector2(0,-80),Vector2(0,-80));await touch(at+Vector2(0,-80),false,true)
   result=await swipe(row_at_scroll_center(),[Vector2(0,-24),Vector2(0,-24)])
   expect(result.distance==48 and not result.dragged,"a canceled swipe does not block the next gesture: "+tag)
   var remembered=scroll.scroll_vertical
   ui.list_buttons.side.pressed.emit();await frames();ui.list_buttons.main.pressed.emit();await frames()
   expect(app.main_scroll.scroll_vertical==remembered,"main/side switching preserves the main list scroll position: "+tag)
   expect(app.draft==before and app.dirty==dirty,"all scrolling leaves deck contents and dirty state unchanged: "+tag)
   await shot("main-%d-%d" % [count,dimensions.x])
 root.size=Vector2i(1280,720);app.layout_dpi_override=240;await frames()
 app.draft=Store.blank("短列表滑动测试");app.draft.rule_set="test";app.draft.leader="70";app.draft.main=ids.slice(0,2)
 app.android_editor_overview=false;app.set_meta("android_editor_list_zone","main");app.editor();await frames(12)
 var ui=app.editor_ui;var before=app.draft.duplicate(true)
 expect(app.main_scroll.get_v_scroll_bar().max_value<=app.main_scroll.get_v_scroll_bar().page+1,"short main list fits without scrolling")
 var at=ui.list_sections.main.get_global_rect().position+Vector2(80,ui.list_height*0.5)
 var result=await swipe(at,[Vector2(13,-9),Vector2(0,-24),Vector2(0,-24)])
 expect(result.distance==0 and not result.dragged and app.draft==before and not is_instance_valid(ui.details_overlay),"swiping a short main list cannot accidentally drag, reorder or inspect a card")
 await touch(at,true);await create_timer(1.1).timeout
 expect(not root.gui_is_dragging() and app.draft.main.size()==before.main.size()-1,"intentional long press removes exactly one card after a short-list swipe")
 await touch(at,false);await frames()
 expect(not root.gui_is_dragging() and app.draft.main.size()==before.main.size()-1,"releasing the removed row does not start dragging or remove another card")
 await touch(at,true);await touch(at,false);await frames()
 expect(is_instance_valid(ui.details_overlay),"a normal tap still opens card details after scrolling")
 ui.close_details();await frames()
 print("ANDROID DECK SCROLL: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
