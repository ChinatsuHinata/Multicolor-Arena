extends "res://tests/support/ui_base.gd"
const Session=preload("res://net/lan_session.gd")
const Duel=preload("res://scripts/rules/duel_engine.gd")
var output="res://work/network-chat-removed"
func frames(count: int=3):
 for i in range(count):await process_frame
func contains_chat(node: Node) -> bool:
 if str(node.name).to_lower().contains("chat"):return true
 if node is Button and node.text.contains("聊天"):return true
 if node is PopupMenu:
  for i in range(node.item_count):
   if node.get_item_text(i).contains("聊天"):return true
 for child in node.get_children():
  if contains_chat(child):return true
 return false
func shot(label: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(label+".png"))
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures"))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 app.load_legacy_test_decks()
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 for android in [false,true]:
  root.size=Vector2i(1280,720) if android else Vector2i(1600,900)
  app.is_android=android;app.layout_dpi_override=360.0 if android else 0.0
  app.layout_safe_override=Rect2(40,0,1200,690) if android else Rect2()
  app.refresh_ui_metrics()
  for cloud in [false,true]:
   for role in ["host","guest","spectator"]:
    var label=("android" if android else "desktop")+"-"+("cloud" if cloud else "lan")+"-"+role
    var session=Session.new();root.add_child(session)
    session.initialize(output.path_join(label));session.set_process(false)
    session.is_host=role=="host";session.read_only=role=="spectator";session.cloud_mode=cloud
    session.cloud_slot=1 if session.is_host else 3 if session.read_only else 2
    session.seat=0 if session.is_host else 1
    session.room_id="preview-room";session.cloud_room_name="测试房间"
    session.cloud_seats=["房主","玩家","观众","","","","",""]
    session.series.setup(1,true,"test");session.series.state.names=["房主","玩家"]
    session.connected=true;session.paused=false
    session.room=session.series.public_state(-1 if session.read_only else session.seat)
    app.lan_session=session;app.online();await frames()
    expect(not contains_chat(app.screen),label+" room has no chat control or panel")
    expect(find_button(app.screen,"离开观战" if session.read_only and not cloud else "离开房间")!=null,label+" room still has its exit action")
    await shot(label+"-room")
    session.series.state.decks=decks.duplicate(true)
    session.series.state.status="playing";session.series.state.game_id="preview-game";session.series.state.round=1
    session.authority=Duel.new();session.authority.start(decks[0],decks[1],0,42)
    session.room=session.series.public_state(-1 if session.read_only else session.seat);session.sequence=1
    session.latest_snapshot=session.make_host_observer_snapshot([],true) if session.read_only else session.make_snapshot(session.seat,[],true)
    app.return_network_battle();await frames(5)
    expect(is_instance_valid(app.duel_view) and not contains_chat(app.duel_view),label+" battle has no chat control or panel")
    expect(find_button(app.duel_view,"菜单" if android else "更多操作")!=null,label+" battle retains its tools menu")
    await shot(label+"-battle")
    app.menu();await frames();app.lan_session=null
    session.leave(false);session.queue_free();await frames()
 print("NETWORK CHAT REMOVED UI: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
