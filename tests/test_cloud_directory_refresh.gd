extends "res://tests/support/ui_base.gd"

const Directory=preload("res://net/cloud_directory.gd")
const Session=preload("res://net/lan_session.gd")
const Lobby=preload("res://net/lan_lobby.gd")
const ENDPOINT="ws://127.0.0.1:47975"
var fixture="res://work/cloud-directory-refresh/"+str(Time.get_ticks_usec())
var accounts=[]
var host
var session
var snapshots=0

func until(predicate: Callable,seconds: float=8.0) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<deadline:
  if predicate.call():return true
  await process_frame
 return predicate.call()

func contains_host(directory) -> bool:
 return directory.rooms.any(func(room):return room.id==host.relay_code)

func returned_lobby(mobile: bool,role: String):
 session.leave(false)
 session.cloud_mode=true;session.is_host=role=="host";session.read_only=role=="spectator"
 session.seat=0 if session.is_host else 1;session.cloud_slot=1 if session.is_host else 8 if session.read_only else 2
 session.room_id="TEST_ONLY_COMPLETED_ROOM"
 session.series=session.Series.new();session.series.setup(session.Series.BO3,true,"unrestricted")
 session.series.state.status="complete";session.series.state.winner=0
 session.room=session.series.public_state(session.seat)
 app.clear_page("online")
 var lobby=Lobby.new();lobby.cloud_server_url=ENDPOINT
 app.screen.add_child(lobby);lobby.build(app,session)
 var directory=lobby.cloud_directory
 directory.changed.connect(func():snapshots+=1)
 var label=("Android" if mobile else "desktop")+" / "+role
 expect(directory.active and directory.loading and directory.token==app.account_token,label+": returning with a completed room starts its new directory")
 expect(await until(func():return directory.has_snapshot and contains_host(directory)),label+": actual cloud room list arrives while old room remains selected")
 var exit=find_button(lobby.body,"离开观战" if session.read_only else "离开房间")
 expect(exit!=null,label+": room offers a direct exit")
 if exit==null:return
 exit.pressed.emit();await process_frame
 if mobile:lobby.set_cloud_home_view("rooms")
 await process_frame
 expect(session.room_id.is_empty() and directory.active and is_instance_valid(lobby.cloud_rooms_list),label+": leaving opens the connected cloud home")
 expect(contains_host(directory) and lobby.cloud_rooms_list.get_child_count()>0 and lobby.cloud_rooms_list.find_child("CloudRoomsStatus",true,false)==null,label+": public rooms stay populated without returning to the main menu")
 var refresh=lobby.body.find_child("RefreshCloudRooms",true,false) as Button
 expect(refresh!=null,label+": list has a refresh action")
 if refresh==null:return
 var before=snapshots
 refresh.pressed.emit();lobby._process(0)
 expect(directory.loading and refresh.text=="刷新中…",label+": manual refresh shows immediate progress")
 expect(await until(func():return snapshots>before and not directory.loading),label+": manual refresh completes a real server round trip")
 var old_peer=directory.peer
 old_peer.close();directory.retry_at=Time.get_ticks_msec()+60000
 before=snapshots
 refresh.pressed.emit()
 expect(directory.peer!=old_peer and directory.active,label+": refresh immediately reconnects a closed socket")
 expect(contains_host(directory),label+": reconnect keeps the last complete room snapshot visible")
 expect(await until(func():return snapshots>before and not directory.loading and contains_host(directory)),label+": reconnected directory receives a fresh room list")
 directory.peer.close();directory.peer=null;directory.retry_at=Time.get_ticks_msec()+60000
 before=snapshots;refresh.pressed.emit()
 expect(directory.peer!=null and directory.active,label+": refresh also retries a missing socket immediately")
 expect(await until(func():return snapshots>before and not directory.loading and contains_host(directory)),label+": missing socket recovery finishes before the automatic retry delay")
 old_peer=directory.peer;directory.loading=true;directory.last_request=Time.get_ticks_msec()-4000
 before=snapshots;refresh.pressed.emit()
 expect(directory.peer!=old_peer,label+": manual refresh replaces a connected socket whose pending request is stale")
 expect(await until(func():return snapshots>before and not directory.loading and contains_host(directory)),label+": stale connected socket returns a complete fresh snapshot")
 old_peer=directory.peer;directory.loading=true;directory.last_request=Time.get_ticks_msec()-directory.REFRESH_TIMEOUT_MS-1
 before=snapshots;directory._process(0)
 expect(directory.peer!=old_peer,label+": unanswered requests automatically reconnect after their deadline")
 expect(await until(func():return snapshots>before and not directory.loading and contains_host(directory)),label+": automatic request recovery repopulates rooms")
 directory.stop();lobby.refresh_cloud_rooms()
 var status=lobby.cloud_rooms_list.find_child("CloudRoomsStatus",true,false)
 expect(status!=null and status.text.contains("断开"),label+": a stopped directory is not described as an empty server")
 refresh.pressed.emit();lobby._process(0)
 expect(directory.active and directory.loading and refresh.text=="刷新中…",label+": refresh restarts an inactive directory")
 expect(await until(func():return directory.has_snapshot and not directory.loading and contains_host(directory)),label+": restarted directory lists rooms again")
 var peer=directory.peer
 app.menu();await process_frame
 expect(not is_instance_valid(directory) and peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED,label+": leaving the page releases its directory socket")

func stalled_handshake():
 # A real TCP connection that never answers the WebSocket upgrade represents
 # Android keeping CONNECTING after a broken initial connection.
 var server=TCPServer.new();var sockets=[]
 expect(server.listen(47977,"127.0.0.1")==OK,"stalled handshake fixture listens only on loopback")
 var directory=Directory.new();root.add_child(directory);directory.is_android=true
 directory.start("ws://127.0.0.1:47977",accounts[1].token)
 expect(await until(func():return server.is_connection_available()),"initial directory socket reaches the stalled TCP server")
 if server.is_connection_available():sockets.append(server.take_connection())
 expect(directory.peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTING,"unfinished upgrade keeps the directory in CONNECTING")
 var old_peer=directory.peer;directory.connect_started_at=Time.get_ticks_msec()-4000
 directory.refresh()
 expect(directory.peer!=old_peer and directory.active and directory.loading,"manual refresh replaces a stalled CONNECTING socket")
 expect(await until(func():return server.is_connection_available()),"manual retry creates a new actual TCP connection")
 if server.is_connection_available():sockets.append(server.take_connection())
 old_peer=directory.peer;directory.connect_started_at=Time.get_ticks_msec()-directory.REFRESH_TIMEOUT_MS-1
 directory._process(0)
 expect(directory.peer!=old_peer and directory.active,"initial handshake deadline triggers an automatic socket retry")
 directory.notification(Node.NOTIFICATION_APPLICATION_PAUSED);directory.stop();directory.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
 expect(not directory.active and directory.peer==null,"a stopped directory remains stopped on foreground notification")
 for socket in sockets:socket.disconnect_from_host()
 server.stop();directory.queue_free()

func run():
 # Loopback packet fixture supplies test-only identities; no production login.
 for index in range(2):accounts.append({"token":str(index+1).repeat(64),"nickname":"TEST_ONLY_DIRECTORY_"+str(index),"username":"TEST_ONLY_DIRECTORY_"+str(index)})
 host=Session.new();root.add_child(host);host.initialize(fixture+"/host")
 host.cloud_token=accounts[0].token;host.cloud_nickname=accounts[0].nickname
 expect(host.create_relay_room(ENDPOINT,3,true,"unrestricted","TEST_ONLY_DIRECTORY","",1).is_empty(),"reference cloud room starts on loopback")
 expect(await until(func():return host.transport.relay_seat==1),"reference cloud room is registered")
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 app=load("res://main.tscn").instantiate()
 app.settings_path=fixture+"/settings.json";app.account_session_path=fixture+"/account.bin";app.tutorial_local_directory=fixture+"/tutorials";app.lan_storage_directory=fixture+"/lan";app.tournament_server_url=ENDPOINT
 root.add_child(app);await process_frame
 app.account_name=accounts[1].username;app.account_nickname=accounts[1].nickname;app.account_token=accounts[1].token
 app.ensure_lan_session();session=app.lan_session
 session.set_process(false);session.transport.set_process(false);session.discovery.set_process(false)
 for mobile in [false,true]:
  app.menu()
  app.is_android=mobile;app.layout_dpi_override=240 if mobile else 0
  root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
  if mobile:app.screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
  app.refresh_responsive_layout()
  for frame in range(6):await process_frame
  for role in ["host","guest","spectator"]:await returned_lobby(mobile,role)
 # A successful empty response gets different feedback from connecting/disconnected.
 session.leave(false);app.clear_page("online")
 var lobby=Lobby.new();lobby.cloud_server_url=ENDPOINT;lobby.cloud_selected=true;lobby.mode_selected=true;lobby.cloud_home_view="rooms"
 app.screen.add_child(lobby);lobby.build(app,session)
 var directory=lobby.cloud_directory
 expect(await until(func():return directory.has_snapshot),"final directory receives a complete snapshot")
 host.leave(false);await create_timer(0.2).timeout
 lobby.refresh_cloud_directory()
 expect(await until(func():return directory.has_snapshot and not directory.loading and directory.rooms.is_empty()),"a real empty server response replaces its previous room snapshot")
 var status=lobby.cloud_rooms_list.find_child("CloudRoomsStatus",true,false)
 expect(status!=null and status.text.contains("当前没有房间"),"only a confirmed empty snapshot displays the no-rooms message")
 directory.refresh();directory.match_mode="casual";directory.refresh()
 expect(await until(func():return not directory.loading and directory.has_snapshot),"changing queue mode refreshes immediately even while the previous mode request was pending")
 await stalled_handshake()
 session.leave(false);host.leave(false);app.queue_free();host.queue_free();await process_frame
 print("CLOUD DIRECTORY REFRESH: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
