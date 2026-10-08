extends "res://tests/support/ui_base.gd"

const Session=preload("res://net/lan_session.gd")
const Sound=preload("res://scripts/room_join_sound.gd")
class CloudSession:
 extends "res://net/lan_session.gd"
 func persist() -> bool:return true
class CapturedTransport:
 extends Node
 func send_to(_id,_message,_heartbeat=false):pass

var fixture=""
var notifications=0
var guest_notifications=0
var cloud_notifications=0

func frames(count: int=4):
 for i in range(count):await process_frame

func until(predicate: Callable,seconds: float=8.0) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<deadline:
  if predicate.call():return true
  await process_frame
 return predicate.call()

func make_app():
 var result=load("res://main.tscn").instantiate()
 result.settings_path=fixture.path_join("settings.json")
 result.account_session_path=fixture.path_join("account.json")
 result.tutorial_local_directory=fixture.path_join("tutorials")
 root.add_child(result)
 return result

func check_settings(mobile: bool):
 app.is_android=mobile
 app.layout_dpi_override=360 if mobile else 0
 app.layout_safe_override=Rect2(40,12,1200,684) if mobile else Rect2()
 root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
 app.settings();await frames()
 var prefix="Android" if mobile else "desktop"
 var slider=app.screen.find_child("RoomJoinVolume",true,false) as HSlider
 var preview_button=app.screen.find_child("PreviewRoomJoinSound",true,false) as Button
 expect(slider!=null and preview_button!=null,prefix+" settings expose volume and preview")
 if slider==null or preview_button==null:return
 expect(slider.min_value==0 and slider.max_value==100 and slider.step==1,prefix+" volume supports 0 to 100 percent")
 slider.value=42
 expect(is_equal_approx(app.room_join_volume,0.42),prefix+" slider changes live volume")
 expect(app.screen.find_child("RoomJoinVolumeValue",true,false).text=="42%",prefix+" percentage updates")
 preview_button.pressed.emit()
 expect(is_instance_valid(app.room_join_sound) and app.room_join_sound.playing,prefix+" preview plays chime")
 expect(is_equal_approx(db_to_linear(app.room_join_sound.volume_db),0.42),prefix+" preview uses selected volume")
 slider.value=0
 preview_button.pressed.emit()
 expect(not app.room_join_sound.playing,prefix+" zero mutes and stops current audio")
 slider.value=42
 var saved=JSON.parse_string(FileAccess.get_file_as_string(app.settings_path))
 expect(is_equal_approx(saved.room_join_volume,0.42) and saved.delay_turn_end==false,prefix+" saving preserves other settings")
 await frames()
 var safe=app.screen.get_global_rect().grow(1)
 expect(safe.encloses(slider.get_global_rect()) and safe.encloses(preview_button.get_global_rect()),prefix+" volume controls fit screen")
 expect(not slider.get_global_rect().intersects(preview_button.get_global_rect()),prefix+" slider and preview do not overlap")
 await capture("room-join-volume-"+prefix.to_lower())

func check_lan():
 app.is_android=false;app.layout_safe_override=Rect2();app.layout_dpi_override=0
 root.size=Vector2i(1600,900)
 app.online()
 var host=app.lan_session
 # Initialize reads the identity only; all subsequent writes use the fixture.
 host.storage=fixture.path_join("host")
 host.identity=host.Identity.load_identity(host.storage.path_join("identity.bin"))
 host.room_joined.connect(func():notifications+=1)
 var guest=Session.new();root.add_child(guest);guest.initialize(fixture.path_join("guest"))
 guest.room_joined.connect(func():guest_notifications+=1)
 app.room_join_sound.stop()
 expect(host.create_room(1,true,48055,"127.0.0.1").is_empty(),"LAN room created")
 host.receive(123,{"type":"hello","version":"incompatible"})
 host.rejected_peers.clear()
 expect(notifications==0 and not app.room_join_sound.playing,"rejected joins stay silent")
 expect(guest.join_room("127.0.0.1",48055).is_empty(),"LAN join requested")
 var application_received=await until(func():return not host.applicant.is_empty())
 expect(application_received,"LAN application reaches host")
 if not application_received:
  print("LAN HOST: ",host.connection_status()," / transport ",host.transport.online," / peers ",host.transport.peers," / suspended ",host.application_suspended)
  print("LAN GUEST: ",guest.connection_status()," / transport ",guest.transport.online," / peers ",guest.transport.peers," / suspended ",guest.application_suspended)
  guest.leave(false);guest.queue_free();host.leave(false);return
 expect(notifications==1 and app.room_join_sound.playing,"host hears join before approving it")
 var hello={"type":"hello","version":host.fingerprint,"installation":guest.identity.installation,"name":guest.identity.nickname}
 host.receive(int(host.applicant.get("peer",0)),hello)
 expect(notifications==1,"repeated join handshake does not replay reminder")
 host.accept_applicant(true)
 expect(await until(func():return host.can_act() and guest.can_act()),"accepted guest synchronizes")
 expect(notifications==1 and guest_notifications==0,"approval does not double reminder or notify guest")
 host.receive(host.remote_peer,{"type":"hello","version":host.fingerprint,"installation":guest.identity.installation,"name":guest.identity.nickname,"resume":guest.identity.resume,"last_sequence":guest.sequence})
 expect(await until(func():return host.can_act() and guest.can_act()),"original guest resumes")
 expect(notifications==1,"original guest recovery stays silent")
 app.menu();app.room_join_sound.stop()
 var watcher=Session.new();root.add_child(watcher);watcher.initialize(fixture.path_join("watcher"))
 expect(watcher.join_spectator("127.0.0.1",48055).is_empty(),"LAN spectator joins")
 expect(await until(func():return notifications==2),"spectator arrival notifies host")
 expect(app.room_join_sound.playing,"notification survives leaving lobby page")
 if not host.spectator_hub.watchers.is_empty():
  host.spectator_hub.receive(host.spectator_hub.watchers.keys()[0],{"type":"watch","version":host.fingerprint})
 expect(notifications==2,"duplicate spectator handshake stays silent")
 app.set_room_join_volume(0)
 var muted_watcher=Session.new();root.add_child(muted_watcher);muted_watcher.initialize(fixture.path_join("muted-watcher"))
 muted_watcher.join_spectator("127.0.0.1",48055)
 expect(await until(func():return notifications==3),"muted host still receives join event")
 expect(not app.room_join_sound.playing,"muted host does not play audio")
 for session in [guest,watcher,muted_watcher]:session.leave(false);session.queue_free()
 host.leave(false);host.is_host=false
 app.set_room_join_volume(0.42);host.room_joined.emit()
 expect(not app.room_join_sound.playing,"non-host never plays room notification")
 app.online();app.online()
 expect(host.get_signal_connection_list("room_joined").size()==2,"reopening lobby does not duplicate sound binding")

func check_cloud():
 var cloud=CloudSession.new();root.add_child(cloud);cloud.set_process(false)
 cloud.transport=CapturedTransport.new();cloud.add_child(cloud.transport)
 cloud.cloud_mode=true;cloud.is_host=true;cloud.cloud_slot=1;cloud.room_id="test-room"
 cloud.series.setup(1,true)
 cloud.room_joined.connect(func():cloud_notifications+=1)
 cloud.on_cloud_seats(["host","","","","","","",""],[1,0,0,0,0,0,0,0])
 expect(cloud_notifications==0,"cloud host's own seat stays silent")
 cloud.on_cloud_seats(["host","guest","","","","","",""],[1,12,0,0,0,0,0,0])
 expect(cloud_notifications==1,"cloud player arrival notifies host")
 cloud.on_cloud_seats(["host","guest","watcher","","","","",""],[1,12,13,0,0,0,0,0])
 expect(cloud_notifications==2,"cloud spectator arrival notifies host")
 cloud.on_cloud_seats(cloud.cloud_seats,cloud.cloud_peer_ids)
 cloud.on_cloud_seats(["host","guest","","watcher","","","",""],[1,12,0,13,0,0,0,0])
 expect(cloud_notifications==2,"cloud seat refresh and spectator move stay silent")
 cloud.on_cloud_seats(["host","watcher","","guest","","","",""],[1,13,0,12,0,0,0,0])
 expect(cloud_notifications==2,"cloud battle-seat swap stays silent")
 var hub=preload("res://net/spectator_hub.gd").new();cloud.add_child(hub);hub.set_process(false);hub.start_cloud(cloud)
 hub.receive(12,{"type":"watch","version":cloud.fingerprint})
 expect(cloud_notifications==2,"cloud watch handshake does not duplicate seat notification")
 cloud.on_cloud_seats(["host","watcher","","","","","",""],[1,13,0,0,0,0,0,0])
 expect(cloud_notifications==2,"cloud departures stay silent")
 cloud.on_cloud_seats(["host","watcher","","guest","","","",""],[1,13,0,14,0,0,0,0])
 expect(cloud_notifications==3,"new cloud peer with same name triggers reminder")
 cloud.is_host=false
 cloud.on_cloud_seats(["host","watcher","","guest","other","","",""],[1,13,0,14,15,0,0,0])
 expect(cloud_notifications==3,"cloud clients never emit host reminders")
 cloud.free()

func check_match_sound():
 var session=app.lan_session
 for role in ["host","guest"]:
  session.leave(false);session.cloud_mode=true;session.cloud_ranked=true;session.matchmaking=true
  app.room_join_sound.stop()
  var info={"match_id":"a".repeat(32),"room":"ABCDEF123456","seat":1 if role=="host" else 2,"role":role}
  session.on_match_found(info)
  expect(app.room_join_sound.playing,"matching "+role+" uses the host reminder sound")
  app.room_join_sound.stop();session.on_match_found(info)
  expect(not app.room_join_sound.playing,"duplicate matching response stays silent for "+role)
  if role=="host":
   session.on_cloud_seats(["host","guest","","","","","",""],[1,12,0,0,0,0,0,0])
   expect(not app.room_join_sound.playing,"matched host seat synchronization does not double the sound")
 session.leave(false);session.cloud_mode=true;session.cloud_ranked=true;session.matchmaking=true
 app.set_room_join_volume(0)
 session.on_match_found({"match_id":"b".repeat(32),"room":"ABCDEF123457","seat":2,"role":"guest"})
 expect(not app.room_join_sound.playing,"matching reminder respects the existing mute setting")
 session.leave(false);app.set_room_join_volume(0.42)

func run():
 fixture="res://work/room-join-sound/fixtures-"+str(Time.get_ticks_usec())
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture.path_join("tutorials")))
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 var file=FileAccess.open(fixture.path_join("settings.json"),FileAccess.WRITE)
 file.store_string('{"room_join_volume":0.35,"delay_turn_end":false}');file.close()
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=make_app();await frames()
 expect(is_equal_approx(app.room_join_volume,0.35),"saved notification volume loads")
 for mobile in [false,true]:await check_settings(mobile)
 await check_lan()
 check_cloud()
 check_match_sound()
 app.queue_free();await frames()
 app=make_app();await frames()
 expect(is_equal_approx(app.room_join_volume,0.42),"notification volume survives restart")
 app.begin_battle(true);view=app.duel_view;await settle()
 view.settings_menu();await frames()
 expect(view.ui.find_child("RoomJoinVolume",true,false)!=null,"battle settings also expose notification volume")
 expect(Sound.normalize_volume(-1)==0 and Sound.normalize_volume(2)==1,"out-of-range volume is clamped")
 expect(Sound.normalize_volume("invalid")==Sound.DEFAULT_VOLUME and Sound.normalize_volume(NAN)==Sound.DEFAULT_VOLUME,"invalid volume uses safe default")
 expect(app.room_join_sound==null,"audio player is created only when needed")
 print("ROOM JOIN SOUND: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
