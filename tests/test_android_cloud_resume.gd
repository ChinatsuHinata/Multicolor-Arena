extends "res://tests/support/network_base.gd"
const Directory=preload("res://net/cloud_directory.gd")
const ENDPOINT="ws://127.0.0.1:47974"
var watcher
var directory
var directory_updates=0

func session(label: String,index: int):
 var result=Session.new();root.add_child(result)
 result.initialize("res://work/android-cloud-resume/"+str(Time.get_ticks_usec())+"-"+label)
 result.is_android=true;result.cloud_token=str(index).repeat(64);result.cloud_nickname="TEST_ONLY_RESUME_"+label
 result.error_raised.connect(func(message):print(label," ERROR: ",message))
 return result

func suspend(client):
 client.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
 client.process_mode=Node.PROCESS_MODE_DISABLED

func resume(client):
 client.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
 client.process_mode=Node.PROCESS_MODE_INHERIT

func prepare_cloud_battle():
 host.room_action({"name":"ready"})
 check(await until(func():return host.can_act() and guest.can_act()),"host ready acknowledged")
 guest.room_action({"name":"ready"})
 check(await until(func():return host.series.state.status=="choosing" and guest.room.get("status","")=="choosing" and host.can_act() and guest.can_act()),"cloud first-player choice synchronized")
 if not failures.is_empty():return
 var selecting=host if host.series.state.chooser==0 else guest
 selecting.room_action({"name":"first","first":true})
 check(await until(func():return host.series.state.status=="playing" and guest.room.get("game_id","")==host.series.state.game_id and host.can_act() and guest.can_act()),"cloud battle started and acknowledged")
 sync_views()

func run():
 host=session("host",1);guest=session("guest",2);watcher=session("watcher",3)
 check(host.transport.process_priority<host.process_priority,"queued packets are polled before heartbeat timeout checks")
 check(host.create_relay_room(ENDPOINT,1,true,"unrestricted","TEST_ONLY_RESUME","secret123",1).is_empty(),"create local password-protected cloud room")
 check(await until(func():return host.transport.relay_seat==1),"host registered on actual WebSocket relay")
 check(guest.join_relay_room(ENDPOINT,host.relay_code,false,2,"secret123").is_empty(),"guest joins battle seat")
 check(await until(func():return host.can_act() and guest.can_act()),"cloud battle seats synchronized")
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 host.room_action({"name":"deck","deck":decks[0]})
 check(await until(func():return host.can_act() and guest.can_act() and not host.room.own_deck.is_empty()),"host deck acknowledged before guest selects")
 guest.room_action({"name":"deck","deck":decks[1]})
 check(await until(func():return host.can_act() and guest.can_act() and host.room.own_deck.size()>0 and guest.room.own_deck.size()>0),"both decks selected")
 if not failures.is_empty():host.leave(false);guest.leave(false);quit(1);return
 await prepare_cloud_battle()
 if not failures.is_empty():host.leave(false);guest.leave(false);quit(1);return
 watcher.join_relay_room(ENDPOINT,host.relay_code,false,8,"secret123")
 check(await until(func():return watcher.connected and not watcher.latest_snapshot.is_empty()),"spectator receives current battle")
 directory=Directory.new();root.add_child(directory);directory.is_android=true
 var directory_errors=[]
 directory.failed.connect(func(message):directory_errors.append(message))
 directory.changed.connect(func():directory_updates+=1)
 directory.start(ENDPOINT,"4".repeat(64))
 check(await until(func():return not directory.rooms.is_empty()),"cloud directory receives room list")
 var frozen=host.Codec.capture(host.authority);var seq=host.sequence;var code=host.relay_code
 # Android resumes with old timestamps before it can drain its packet queue.
 suspend(host)
 var old=Time.get_ticks_msec()-9000
 host.remote_last_seen=old
 for id in host.cloud_peer_seen:host.cloud_peer_seen[id]=old
 host._process(9.0)
 check(host.connected and host.disconnected_at==0,"background session does not time out valid connections")
 resume(host);host._process(0)
 check(host.connected and host.disconnected_at==0 and host.transport.online,"foreground reset avoids disconnecting live battle seats")
 check(await until(func():return host.can_act() and guest.can_act()),"short app switch keeps battle usable")
 # A genuinely closed guest socket must recover the same room and seat.
 suspend(guest);guest.transport.close();guest.on_failure("TEST_ONLY background socket loss")
 check(await until(func():return not host.connected),"host pauses after genuine guest connection loss")
 var deadline=guest.disconnect_deadline_unix
 resume(guest)
 check(guest.joining and guest.disconnect_deadline_unix==deadline,"foreground retries immediately without extending the disconnect deadline")
 check(await until(func():return host.can_act() and guest.can_act(),12),"guest reconnects automatically after switching apps")
 sync_views()
 check(host.Codec.capture(host.authority)==frozen and host.sequence==seq and host.relay_code==code,"guest recovery preserves battlefield, sequence and cloud room")
 # Host socket loss also removes the relay room; recreate and resynchronize it.
 suspend(host);host.transport.close();host.on_failure("TEST_ONLY host background socket loss")
 check(await until(func():return not guest.connected),"guest waits while suspended host is unreachable")
 var host_deadline=host.disconnect_deadline_unix
 resume(host)
 check(host.transport.online and host.disconnect_deadline_unix==host_deadline,"host foreground starts relay recovery without resetting the deadline")
 check(await until(func():return host.can_act() and guest.can_act(),15),"host and guest recover the original battle automatically")
 sync_views()
 check(host.Codec.capture(host.authority)==frozen and host.sequence==seq,"host recovery preserves battle rules and confirmed moves")
 check(await until(func():return watcher.connected,12),"spectator automatically recovers after host reconnects")
 # Password-protected spectator reconnects using its in-memory room password.
 suspend(watcher);watcher.transport.close();watcher.on_failure("TEST_ONLY spectator background socket loss");resume(watcher)
 check(await until(func():return watcher.connected,12) and watcher.cloud_slot==8 and watcher.read_only,"spectator retains password, seat and read-only access")
 var updates=directory_updates
 suspend(directory);directory.peer.close();resume(directory)
 check(await until(func():return directory_updates>updates,12) and directory_errors.is_empty(),"directory reconnects after app switch without a disconnect error dialog")
 directory.stop();directory.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
 check(not directory.active and directory.peer==null,"leaving cloud does not restart the directory")
 watcher.leave(false);guest.leave(false);host.leave(false)
 print("ANDROID CLOUD RESUME: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
