extends Node
const Store=preload("res://scripts/deck_store.gd")
var failures=[]
var checks=0
func check(ok: bool,text: String):
 checks+=1
 if not ok: failures.append(text);push_error(text)
func _ready():call_deferred("run")
func run():
 check(not OS.has_feature("editor"),"must run with exported release template")
 check(ProjectSettings.get_setting("application/config/name")=="multicolor:arena" and ProjectSettings.get_setting("application/config/version")=="1.0","1.0 product identity")
 check(OS.get_user_data_dir().replace("\\","/").ends_with("/Godot/app_userdata/极彩 Multicolour"),"preserve prior player save directory")
 check(int(Store.CARDS["spell-fdf-068"].cost["蓝"])==2 and int(Store.CARDS["spell-fdf-068"].cost["绿"])==1,"updated Last Utopia cost exported")
 check(int(Store.CARDS["spell-fdf-042"].cost["蓝"])==2 and int(Store.CARDS["spell-fdf-042"].cost["黑"])==1,"updated Winter cost exported")
 check(Store.CARDS.size()==486,"all registered definitions load")
 for id in Store.CARDS:
  var art=load(Store.CARDS[id].image) as Texture2D
  check(art!=null and art.get_width()>0 and art.get_height()>0,"texture: "+id)
 check(Store.active_save_path()==OS.get_executable_path().get_base_dir().path_join("deck"),"release uses portable deck folder")
 check(not ResourceLoader.exists("res://tests/test_decks.gd"),"test scripts excluded")
 check(not ResourceLoader.exists("res://work/v0152/card-back-and-hand.png"),"work screenshots excluded")
 check(not FileAccess.file_exists("res://saves/decks.json"),"developer saves not loaded directly")
 var bundled=Store.load_decks(Store.BUNDLED_DECKS_PATH)
 check(not bundled.has("error") and bundled.decks.size()==4,"four current saved decks bundled")
 var loaded=Store.load_decks()
 check(not loaded.has("error"),"release player save readable")
 var mode=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "first"
 if mode=="first":
  check(loaded.decks.size()==bundled.decks.size() and loaded.decks.all(func(d):return d in bundled.decks),"first launch seeds exact bundled decks")
  check(Store.scan_files(Store.folder()).size()==4 and DirAccess.dir_exists_absolute(Store.Paths.root().path_join("replay")),"first launch creates four mdeck files and replay folder")
  var edited=loaded.decks.duplicate(true);edited[0].name="发行保存测试"
  check(Store.persist(edited).is_empty(),"release saves edits")
 elif mode=="restart":
  check(loaded.decks.any(func(d):return d.name=="发行保存测试"),"restart preserves player edits")
  for d in loaded.decks:check(Store.delete_file(d.id).is_empty(),"release saves deletion of a deck")
 elif mode=="empty":
  check(loaded.decks.is_empty(),"empty save is not reseeded")
  check(Store.persist(bundled.decks).is_empty(),"restore verification profile")
 var app=load("res://main.tscn").instantiate();get_tree().root.add_child.call_deferred(app);await get_tree().process_frame
 check(app.load_error.is_empty(),"main menu opens without missing-resource alert")
 check(app.settings_path=="user://settings.json","release settings path")
 check(app.texture("back")!=null,"card back loads")
 check(load(app.battlefield_background)!=null,"playmat loads")
 var settings_file=FileAccess.open(app.settings_path,FileAccess.WRITE)
 check(settings_file!=null,"settings are writable")
 if settings_file:settings_file.store_string('{"fullscreen":false}');settings_file.close()
 app.load_test_decks();check(app.decks.size()>=2,"precon templates are included")
 app.begin_battle(true);await get_tree().process_frame
 check(is_instance_valid(app.duel_view) and not app.duel_view.engine.cards.is_empty(),"release battlefield starts")
 if DisplayServer.get_name()!="headless":
  await get_tree().create_timer(1).timeout
  await RenderingServer.frame_post_draw
  get_tree().root.get_texture().get_image().save_png(OS.get_environment("MULTICOLOUR_EXPORT_SCREENSHOT"))
 await check_lan(app)
 print("EXPORT_CHECK: ",mode,"; ",checks," checks; ",failures.size()," failures")
 get_tree().quit(0 if failures.is_empty() else 1)

func wait_for(predicate: Callable) -> bool:
 var deadline=Time.get_ticks_msec()+7000
 while Time.get_ticks_msec()<deadline:
  if predicate.call():return true
  await get_tree().process_frame
 return false
func check_lan(app):
 check(FileAccess.file_exists("res://net/rules_manifest.json"),"rule manifest included")
 check(not FileAccess.file_exists("res://saves/lan/identity.bin"),"local identity never packaged")
 app.online();await get_tree().process_frame
 check(is_instance_valid(app.lan_session),"release LAN menu opens")
 var host=app.lan_session
 var client=preload("res://net/lan_session.gd").new();add_child(client);client.initialize("user://lan-release-guest")
 check(host.fingerprint==client.fingerprint,"release rules fingerprints match")
 check(host.create_room(1,false,47975,"127.0.0.1").is_empty(),"release ENet listener")
 check(client.join_room("127.0.0.1",47975).is_empty(),"release ENet client")
 check(await wait_for(func():return not host.applicant.is_empty()),"release handshake arrives")
 host.accept_applicant(true)
 check(await wait_for(func():return host.can_act() and client.can_act()),"release original seat established")
 check(await wait_for(func():return host.metrics.local_ms>=0 and host.metrics.remote_ms>=0 and client.metrics.local_ms>=0 and client.metrics.remote_ms>=0),"release both-player latency measured")
 for seat in [0,1]:host.handle_room_action(seat,{"name":"deck","deck":app.decks[seat]})
 for seat in [0,1]:host.handle_room_action(seat,{"name":"ready"})
 check(await wait_for(func():return not client.snapshots.is_empty()),"release battle snapshot delivered")
 check(client.room.coin==host.series.state.coin and host.authority.first==client.room.coin.first,"release opening coin synchronized")
 while not client.snapshots.is_empty():client.pop_snapshot()
 check(client.latest_snapshot.projection.state.players[0].hand.all(func(c):return c.card_id=="back"),"release opponent hand masked")
 check(client.submit({"name":"surrender","args":[]}).is_empty(),"release guest command submitted")
 check(await wait_for(func():return host.series.state.status=="complete"),"release result synchronized")
 host.leave(false);client.leave(false);client.queue_free()
