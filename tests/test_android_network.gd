extends "res://tests/support/ui_base.gd"
const Endpoint=preload("res://net/network_endpoint.gd")
const Session=preload("res://net/lan_session.gd")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-network-tests/"+str(Time.get_ticks_usec()))
 root.size=Vector2i(1280,720)
 root.gui_embed_subwindows=true
 expect(Endpoint.parse("192.168.1.8",47861)=={"host":"192.168.1.8","port":47861},"Wi-Fi address uses chosen port")
 expect(Endpoint.parse("udp://tunnel.example:30211",47861)=={"host":"tunnel.example","port":30211},"UDP tunnel hostname and mapped port")
 expect(Endpoint.parse("[2001:db8::1]:30211",47861)=={"host":"2001:db8::1","port":30211},"bracketed IPv6 endpoint")
 expect(Endpoint.parse("http://example.com",47861).has("error"),"web links are rejected")
 expect(Endpoint.parse("example.com:65536",47861).has("error"),"out-of-range port is rejected")
 expect(Endpoint.resolve("127.0.0.1")=="127.0.0.1","IP needs no DNS resolution")
 expect(not Endpoint.resolve("localhost").is_empty(),"hostname resolves to a transport IP")
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.is_android=true
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app.refresh_ui_metrics()
 var session=Session.new();root.add_child(session);session.initialize("res://work/android-network-tests/session")
 app.lan_session=session
 app.online();await process_frame
 var lobby=app.screen.get_children().filter(func(child):return child.get_script()==load("res://net/lan_lobby.gd"))[0]
 expect(lobby.address_input!=null and lobby.address_input.placeholder_text.contains("example.com"),"Android address entry accepts tunnel endpoint")
 expect(find_button(app.screen,"创建房间")!=null and find_button(app.screen,"加入")!=null,"Android room controls render")
 expect(lobby.address_input.get_global_rect().end.x<=app.screen.get_global_rect().end.x+1,"address entry fits safe screen width")
 expect(session.create_room(1,true,48132,"127.0.0.1","test").is_empty(),"Android session can host on UDP")
 await process_frame
 expect(find_button(app.screen,"复制房主地址")!=null and find_button(app.screen,"离开房间")!=null,"Android host room controls render")
 session.leave(false)
 expect(session.join_room("127.0.0.1:48132",47861).is_empty() and session.port==48132,"explicit endpoint port reaches session")
 session.leave(false)
 var host=Session.new();root.add_child(host);host.initialize("res://work/android-network-tests/remote-host")
 expect(host.create_room(1,true,48133,"127.0.0.1","test").is_empty(),"PC-style host listens for Android guest")
 expect(session.join_room("127.0.0.1:48133",47861).is_empty(),"Android-style guest starts UDP connection")
 var deadline=Time.get_ticks_msec()+8000
 while host.applicant.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
 expect(not host.applicant.is_empty(),"host receives Android guest request")
 if not host.applicant.is_empty():host.accept_applicant(true)
 deadline=Time.get_ticks_msec()+8000
 while not session.can_act() and Time.get_ticks_msec()<deadline:await process_frame
 await process_frame
 expect(session.can_act(),"Android guest completes room synchronization")
 expect(find_button(app.screen,"选择此卡组")!=null and find_button(app.screen,"准备")!=null,"Android guest room actions render")
 expect(find_button(app.screen,"聊天")==null,"Android guest room has no chat entry")
 host.leave(false);session.leave(false)
 print("ANDROID NETWORK ",checks," checks; ",failures," failures")
 quit(0 if failures.is_empty() else 1)
