extends "res://tests/support/network_base.gd"
const AccountClient=preload("res://scripts/account_client.gd")

func login(server_url: String,index: int) -> Dictionary:
 var username="relay_%s_%d" % [str(Time.get_unix_time_from_system()).replace(".",""),index]
 var client=AccountClient.new();root.add_child(client);client.server_url=server_url
 client.call_deferred("submit","register",username,"password123!")
 await client.finished
 client.call_deferred("submit","login",username,"password123!")
 var result=await client.finished
 var answer={"ok":result[0],"token":client.session_token,"nickname":client.nickname}
 client.queue_free();return answer

func run():
 var port=47872
 var server="127.0.0.1"
 var args=OS.get_cmdline_user_args()
 for i in range(args.size()-1):
  if args[i]=="--port" and args[i+1].is_valid_int():port=int(args[i+1])
  if args[i]=="--server":server=args[i+1]
 var endpoint=server+":"+str(port)
 var account_url=endpoint if endpoint.begins_with("ws://") else "ws://"+endpoint
 var host_account=await login(account_url,0)
 var guest_account=await login(account_url,1)
 check(host_account.ok and guest_account.ok,"both players log in before cloud entry")
 if not host_account.ok or not guest_account.ok:quit(1);return
 host=Session.new();guest=Session.new();root.add_child(host);root.add_child(guest)
 host.initialize("res://work/relay-test-host");guest.initialize("res://work/relay-test-guest")
 host.cloud_token=host_account.token;host.cloud_nickname=host_account.nickname
 guest.cloud_token=guest_account.token;guest.cloud_nickname=guest_account.nickname
 host.error_raised.connect(func(message):print("HOST ERROR ",message))
 guest.error_raised.connect(func(message):print("GUEST ERROR ",message))
 check(host.create_relay_room(endpoint,1,true).is_empty(),"host creates relay room")
 check(host.cloud_mode and host.relay_code.length()==12 and host.authority==null,"relay room has an internal id and no server-side rules")
 check(await until(func():return host.notice.contains("已就绪"),6),"relay registers host room")
 if not host.notice.contains("已就绪"):quit(1);return
 check(guest.join_relay_room(endpoint,host.relay_code).is_empty(),"guest selects an open battle seat")
 check(await until(func():return not host.applicant.is_empty()),"relay forwards guest join request")
 if host.applicant.is_empty():quit(1);return
 host.accept_applicant(true)
 check(await until(func():return host.can_act() and guest.can_act()),"relay carries room synchronization")
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 host.room_action({"name":"deck","deck":decks[0]})
 guest.room_action({"name":"deck","deck":decks[1]})
 check(await until(func():return host.room.own_deck.size()>0 and guest.room.own_deck.size()>0),"host accepts both deck selections over relay")
 check(host.authority==null and guest.authority==null,"lobby does not run rules on relay")
 guest.transport.close();guest.on_disconnect(1)
 check(await until(func():return not host.connected),"guest departure pauses the host")
 check(guest.resume_guest().is_empty(),"guest reconnects with saved relay code")
 var rejoined=await until(func():return host.can_act() and guest.can_act(),15)
 check(rejoined,"rejoined guest recovers the room")
 if not rejoined:quit(1);return
 host.transport.close();host.on_failure("test relay interruption")
 guest.transport.close();guest.on_disconnect(1)
 check(await until(func():return host.can_act() and guest.can_act(),15),"both clients recover when the host relay connection is lost")
 await prepare()
 check(host.authority!=null and guest.authority==null,"duel rules run only on the local host")
 await concede(1)
 check(host.series.state.scores[0]==1 and guest.room.scores[0]==1,"local result reaches guest through relay")
 guest.leave(false);host.leave(false)
 print("RELAY: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
