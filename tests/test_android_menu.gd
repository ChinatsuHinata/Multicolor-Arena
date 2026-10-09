extends "res://tests/support/ui_base.gd"
## Keep every main-menu action reachable on short Android landscape screens.

func frames(count: int=4):
 for i in range(count):await process_frame

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/android-menu-test/"+name+".png")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-menu-test/fixtures")
 root.mode=Window.MODE_WINDOWED
 root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app)
 await frames()
 for case in [
  {"size":Vector2i(1280,720),"dpi":240.0},
  {"size":Vector2i(2340,1080),"dpi":360.0},
  {"size":Vector2i(1024,576),"dpi":192.0},
  {"size":Vector2i(1280,720),"dpi":420.0}]:
  var dimensions: Vector2i=case.size
  root.size=dimensions
  app.is_android=true
  app.layout_dpi_override=case.dpi
  app.layout_safe_override=Rect2(60,0,dimensions.x-84,dimensions.y-24)
  await frames()
  app.menu()
  await frames()
  var prefix="%dx%d dpi %.0f" % [dimensions.x,dimensions.y,case.dpi]
  var safe=app.ui_metrics.safe.grow(2)
  expect(app.screen.find_children("*","ScrollContainer",true,false).is_empty(),prefix+" has no scroll container")
  var captions=["游戏教程","人机对战","联网对战","卡组编辑","玩家账号","对局回放","设置","退出游戏"]
  for title in captions:
   var control=find_button(app.screen,title)
   expect(control!=null,prefix+" has "+title)
   if control:expect(safe.encloses(control.get_global_rect()),prefix+" shows "+title)
  expect(find_button(app.screen,"检查更新")==null,prefix+" hides manual update check")
  expect(find_button(app.screen,"关于")==null,prefix+" moves About into settings")
  var grid=app.screen.find_child("MainMenuActions",true,false)
  expect(grid!=null and grid.get_children().map(func(button):return button.text)==captions,prefix+" orders actions in four rows with exit last")
  var rank=app.screen.find_child("PlayerRank",true,false)
  expect(rank!=null and safe.encloses(rank.get_global_rect()),prefix+" rank and username fit the safe area")
  await shot("menu-%dx%d-dpi%.0f" % [dimensions.x,dimensions.y,case.dpi])
 print("ANDROID MENU: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
