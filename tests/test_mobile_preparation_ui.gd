extends "res://tests/support/ui_base.gd"
const Series=preload("res://net/series_controller.gd")
class FixtureSession:
 extends "res://net/lan_session.gd"
 var last_ui_action={}
 func room_action(value: Dictionary):last_ui_action=value

var fixture="res://work/mobile-preparation-ui/"+str(Time.get_ticks_usec())
var session
var lobby

func frames(count: int=6):
 for i in range(count):await process_frame

func in_view(control: Control) -> bool:
 if not app.ui_metrics.safe.grow(2).encloses(control.get_global_rect()):return false
 var ancestor=control.get_parent()
 while ancestor!=null:
  if ancestor is ScrollContainer and not ancestor.get_global_rect().grow(2).encloses(control.get_global_rect()):return false
  ancestor=ancestor.get_parent()
 return true

func stage(status: String,spectator: bool=false):
 app.close_menu_popup()
 for child in app.get_children():
  if child is Window:child.hide();child.queue_free()
 session.series=Series.new();session.series.setup(Series.BO1_SIDEBOARD,true)
 session.series.state.names=["房主名字较长而且包含English123","对方名字同样很长的玩家"]
 session.series.state.decks=[app.decks[0].duplicate(true),app.decks[1].duplicate(true)]
 session.series.state.registered=session.series.state.decks.duplicate(true)
 session.series.state.status=status;session.series.state.chooser=0
 session.series.state.roll={"values":[6,2]};session.series.state.choice_reason="上一局落败"
 session.series.state.winner=0
 session.series.state.end_reason="本场比赛完成"
 session.room=session.series.public_state(0)
 session.room_id="TEST_ONLY_PREPARATION_ROOM";session.cloud_mode=true;session.is_host=true
 session.connected=true;session.paused=false;session.busy=false;session.read_only=spectator
 session.cloud_slot=3 if spectator else 1;session.seat=0
 session.cloud_nickname=session.room.names[0];session.cloud_room_name="手机房间准备界面与较长的房间名称"
 session.cloud_seats=[session.room.names[0],session.room.names[1],"观战玩家三号","观战玩家四号","","","",""]
 session.cloud_ranked=false;session.notice="";session.disconnected_at=0
 app.clear_page("online")
 lobby=preload("res://net/lan_lobby.gd").new();app.screen.add_child(lobby)
 lobby.cloud_server_url="ws://127.0.0.1:1";lobby.build(app,session)
 lobby.cloud_directory.set_process(false)
 await frames(10)

func shot(caption: String):
 if DisplayServer.get_name()=="headless" or "--capture" not in OS.get_cmdline_user_args():return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/mobile-preparation-"+caption+".png")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate()
 app.settings_path=fixture+"/settings.json";app.account_session_path=fixture+"/account.bin";app.tutorial_local_directory=fixture+"/tutorials"
 app.lan_storage_directory=fixture+"/lan"
 root.add_child(app);await frames();app.load_legacy_test_decks()
 app.account_token="a".repeat(64);app.account_nickname="手机测试"
 session=FixtureSession.new();root.add_child(session);session.initialize(fixture+"/session")
 session.set_process(false);session.transport.set_process(false);session.discovery.set_process(false)
 app.lan_session=session
 for dimensions in [Vector2i(1280,720),Vector2i(2340,1080),Vector2i(2670,1200)]:
  root.size=dimensions;app.is_android=true;app.layout_dpi_override=float(dimensions.y)/3
  app.layout_safe_override=Rect2(36,0,dimensions.x-60,dimensions.y-18)
  await frames();app.refresh_ui_metrics()
  for status in ["lobby","choosing","sideboarding","between","complete","aborted"]:
   await stage(status)
   var label="%dx%d / %s" % [dimensions.x,dimensions.y,status]
   var workspace=lobby.body.find_child("MobilePreparation",true,false)
   expect(workspace!=null and in_view(workspace),label+": preparation fills safe content area")
   expect(not lobby.back_button.visible,label+": no ambiguous header return inside a room")
   var leave=lobby.body.find_child("PreparationLeaveRoom",true,false)
   expect(leave!=null and in_view(leave),label+": sole leave action stays visible")
   var footer=lobby.body.find_child("PreparationFooter",true,false)
   var actions=lobby.body.find_child("PreparationActionsScroll",true,false)
   expect(footer!=null and actions!=null and not footer.get_global_rect().intersects(actions.get_global_rect()),label+": footer is clear of scrolling choices")
   if status=="choosing":
    for caption in ["我方先手","我方后手"]:
     var choice=find_button(lobby.body,caption)
     expect(choice!=null and not choice.disabled and in_view(choice),label+": choice immediately reachable: "+caption)
    expect(find_button(lobby.body,"准备")==null,label+": no stale readiness controls")
   elif status in ["lobby","sideboarding","between"]:
    var ready=find_button(lobby.body,"准备")
    expect(ready!=null and not ready.disabled and in_view(ready),label+": readiness immediately reachable")
    if status!="lobby":
     var sideboard=find_button(lobby.body,"调整主副卡组")
     expect(sideboard!=null and not sideboard.disabled and in_view(sideboard),label+": sideboard edit immediately reachable")
   if status=="lobby":
    var seats=lobby.body.find_child("PreparationSeats",true,false)
    expect(seats!=null and seats.get_child_count()==8,label+": all eight seats exist")
    for seat in seats.get_children():expect(seat.size.x>=100 and seat.size.y>=64 and in_view(seat),label+": visible usable seat touch target")
   for button in lobby.body.find_children("*","Button",true,false):
    expect(button.size.y>=64 and button.get_global_rect().end.x<=app.ui_metrics.safe.end.x+2,label+": readable button inside width: "+button.text)
   if dimensions==Vector2i(2670,1200) and status in ["lobby","choosing","sideboarding"]:await shot(status)
   session.last_ui_action={}
   if status=="choosing":
    find_button(lobby.body,"我方先手").pressed.emit()
    expect(session.last_ui_action=={"name":"first","first":true},label+": first choice reaches session after layout build")
    find_button(lobby.body,"我方后手").pressed.emit()
    expect(session.last_ui_action=={"name":"first","first":false},label+": second choice reaches session after layout build")
   elif status in ["lobby","sideboarding","between"]:
    find_button(lobby.body,"准备").pressed.emit()
    expect(session.last_ui_action.get("name")=="ready",label+": readiness reaches session after layout build")
    if status!="lobby":
     find_button(lobby.body,"调整主副卡组").pressed.emit();await frames()
     expect(app.page=="sideboard" and app.sideboard_session==session,label+": sideboard action opens the actual editor")
   elif status=="aborted":
    leave.pressed.emit();await frames()
    expect(session.room_id.is_empty() and app.page=="online",label+": sole leave action reaches cloud home")
   elif status=="complete":
    find_button(lobby.body,"更换卡组，再来一场").pressed.emit()
    expect(session.last_ui_action.get("name")=="rematch",label+": rematch reaches session after layout build")
  await stage("lobby",true)
  var leave=find_button(lobby.body,"离开观战")
  expect(leave!=null and in_view(leave) and find_button(lobby.body,"离开房间")==null,"spectator has one explicit visible exit")
  expect(find_button(lobby.body,"准备")==null,"spectator has no readiness action")
  # A system back uses that same room exit, rather than navigating to an unrelated page.
  var event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=true
  lobby._unhandled_key_input(event);await frames()
  expect(session.room_id.is_empty() and app.page=="online" and lobby.back_button.visible,"system back leaves the room and restores cloud navigation")
 session.leave(false);session.queue_free();app.queue_free();await process_frame
 print("MOBILE PREPARATION UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
