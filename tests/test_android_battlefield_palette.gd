extends "res://tests/support/ui_base.gd"
## Battlefield focus must keep the own palette row on screen and clear of the
## hand row, so paying for a card never needs the palette camera toggle.
var output="res://work/android-battlefield-palette"
var screenshot_size=Vector2i()

func frames(count: int=8):
 for i in range(count):await process_frame

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var image=root.get_texture().get_image()
 if image.get_size()!=screenshot_size:image.resize(screenshot_size.x,screenshot_size.y,Image.INTERPOLATE_LANCZOS)
 image.save_png(output.path_join(name+".png"))

func fill_board():
 clean()
 view.android_palette_owner=-1;view.android_palette_auto_open=false
 for who in range(2):
  for i in range(10):
   var card=put(["53","100","164","169"][i%4],"palette",who)
   card.tapped=i%3==1
  for i in range(4):put("53","field",who)
  for i in range(8):put(["53","100","164","169"][i%4],"hand",who)
 view.render();await settle();await frames()

func palette_rects(who: int) -> Array:
 var rects=[]
 for card in e.players[who].palette:
  var node=view.table.visuals.get("card_"+str(card.uid))
  if node!=null and node.visible:rects.append(view.projected_card_rect(node))
 return rects

func hand_tiles(prefix: String,who: int,count: int):
 for i in range(count):put("53","hand",who)
 view.render();await settle();await frames()
 expect(view.hand_nodes.size()>=count,prefix+" the own hand row draws "+str(count)+" tiles")

func check_battlefield(prefix: String,wide: bool,top_down: bool):
 view.table.wide_playmat=wide
 view.table.set_top_down_view(top_down)
 view.android_palette_view=false;view.android_palette_owner=-1
 view.reset_camera_view();view.render();await settle();await frames()
 var area=view.responsive.camera_focus_rect()
 var hand=view.hand_scroll.get_global_rect()
 expect(not view.android_palette_view,prefix+" battlefield focus needs no palette toggle")
 var own=palette_rects(view.local_seat)
 expect(own.size()==10,prefix+" own palette keeps all ten cards")
 var covered=own.filter(func(rect):return rect.intersects(hand))
 expect(covered.is_empty(),prefix+" own hand leaves every own palette card clear")
 var outside=own.filter(func(rect):return not area.grow(2).encloses(rect))
 expect(outside.is_empty(),prefix+" own palette stays inside the battlefield frame")
 var prompt_hits=own.filter(func(rect):return rect.intersects(view.PROMPT))
 expect(prompt_hits.is_empty(),prefix+" status text leaves the own palette clear")
 var notice_hits=own.filter(func(rect):return rect.intersects(view.NOTICE))
 expect(notice_hits.is_empty(),prefix+" transient notice leaves the own palette clear")
 var unit=Vector2.ZERO
 for card in e.players[view.local_seat].field:
  if e.is_unit(card):
   unit=view.projected_card_rect(view.table.visuals["card_"+str(card.uid)]).size
   break
 expect(unit.x>=38 and unit.y>=52,prefix+" battlefield frame still keeps units readable (%.1fx%.1f)" % [unit.x,unit.y])
 var enemy=palette_rects(1-view.local_seat)
 var enemy_outside=enemy.filter(func(rect):return not area.grow(2).encloses(rect))
 expect(enemy_outside.is_empty(),prefix+" widest enemy palette still fits the frame")
 var enemy_hidden=enemy.filter(func(rect):return rect.intersects(hand))
 expect(enemy_hidden.is_empty() or not view.hand_display_enabled,prefix+" own hand leaves the enemy palette clear")
 for card in e.players[view.local_seat].palette:
  expect(view.table.card_at(view.stage_point(point(card.uid)))==card.uid,prefix+" palette card "+str(card.uid)+" is still touchable")
 await shot(prefix+"-battlefield")

func check_hand_growth(prefix: String):
 view.android_palette_view=false;view.android_palette_owner=-1
 view.reset_camera_view();view.render();await settle();await frames()
 var before=palette_rects(view.local_seat)
 for count in [1,4,8]:
  for who in range(2):
   e.players[who].hand=e.players[who].hand.slice(0,0)
  hand_tiles(prefix+" x"+str(count),view.local_seat,count)
  var hand=view.hand_scroll.get_global_rect()
  var covered=palette_rects(view.local_seat).filter(func(rect):return rect.intersects(hand))
  expect(covered.is_empty(),prefix+" "+str(count)+" hand cards leave the own palette clear")
  var area=view.responsive.camera_focus_rect()
  var outside=palette_rects(view.local_seat).filter(func(rect):return not area.grow(2).encloses(rect))
  expect(outside.is_empty(),prefix+" "+str(count)+" hand cards keep the palette framed")
 expect(before.size()==palette_rects(view.local_seat).size(),prefix+" hand growth keeps the palette row intact")

func check_prompt_row(prefix: String):
 # The status strip shares the toolbar row with the log instead of sitting on the mat.
 var log=view.responsive.log_rect
 var text=view.responsive.log_text_rect
 expect(text.has_area() and text.position.x>=view.PROMPT.end.x,prefix+" status text and duel log share their row without overlap")
 expect(not view.PROMPT.intersects(text),prefix+" status text leaves room for the duel log")
 expect(view.PROMPT.position.y<view.HAND.position.y,prefix+" status text sits above the hand row")
 expect(view.NOTICE.is_equal_approx(text),prefix+" transient notices reuse the log slot")
 expect(view.TOUCH_CAMERA_AREA.position.y>=log.end.y,prefix+" camera drag area starts below the status row")
 expect(not view.PROMPT.intersects(view.HAND),prefix+" status text leaves the hand row clear")

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
  var preview_scale=minf(1.0,minf(1600.0/fixture.size.x,900.0/fixture.size.y))
  screenshot_size=fixture.size
  root.size=Vector2i(Vector2(fixture.size)*preview_scale)
  app.is_android=true;app.layout_dpi_override=fixture.dpi*preview_scale
  app.layout_safe_override=Rect2(60*preview_scale,0,(fixture.size.x-84)*preview_scale,(fixture.size.y-24)*preview_scale)
  await frames();app.refresh_responsive_layout();app.begin_battle(true)
  view=app.duel_view;view.set_process(false);e=view.engine;await frames();await fill_board()
  for wide in [false,true]:
   for top_down in [true,false]:
    var prefix="%dx%d-dpi%d-%s-%s-battlefield" % [fixture.size.x,fixture.size.y,int(fixture.dpi),"2d" if top_down else "3d","wide" if wide else "normal"]
    await check_battlefield(prefix,wide,top_down)
   var hand_prefix="%dx%d-dpi%d-%s-hand" % [fixture.size.x,fixture.size.y,int(fixture.dpi),"wide" if wide else "normal"]
   await check_hand_growth(hand_prefix)
  view.table.wide_playmat=false
  await check_prompt_row("%dx%d-dpi%d-prompt" % [fixture.size.x,fixture.size.y,int(fixture.dpi)])
 print("ANDROID BATTLEFIELD PALETTE: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
