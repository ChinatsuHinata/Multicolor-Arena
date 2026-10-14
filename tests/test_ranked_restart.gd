extends "res://tests/support/network_base.gd"
const AccountClient=preload("res://scripts/account_client.gd")
const ENDPOINT="ws://127.0.0.1:48045"
var accounts=[]
var apps=[]
var fixture="res://work/ranked-restart/"+str(Time.get_ticks_usec())

func account(action: String,username: String) -> Dictionary:
 var client=AccountClient.new();root.add_child(client);client.server_url=ENDPOINT
 client.call_deferred("submit",action,username,"password123!")
 var result=await client.finished
 var answer={"ok":result[0],"token":client.session_token,"remember":client.remember_token,"username":username,"nickname":client.nickname}
 client.queue_free();return answer

func make_session(index: int):
 var session=Session.new();root.add_child(session);session.initialize(fixture+"/player"+str(index))
 session.cloud_account=accounts[index].username;session.cloud_token=accounts[index].token;session.cloud_nickname=accounts[index].nickname
 return session

func restart_app(index: int):
 var app=load("res://main.tscn").instantiate()
 app.settings_path=fixture+"/settings"+str(index)+".json"
 app.account_session_path=fixture+"/account"+str(index)+".bin"
 app.lan_storage_directory=fixture+"/player"+str(index)
 root.add_child(app);apps.append(app);await process_frame
 var client=AccountClient.new();root.add_child(client);client.server_url=ENDPOINT
 app.account_action="resume";app.account_pending=true;app.account_client=client
 client.finished.connect(app.account_request_finished)
 client.call_deferred("resume",accounts[index].remember)
 check(await until(func():return not app.account_pending),"restarted player %d automatically logs in" % index)
 check(app.page=="online" or app.page=="battle","successful startup login automatically enters the saved match for player %d" % index)
 # Both simulated processes share a test viewport; suppress their replay dialogs.
 for connection in app.lan_session.replay_finished.get_connections():app.lan_session.replay_finished.disconnect(connection.callable)
 return app

func run():
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 for index in range(2):
  var username="restart_%s_%d" % [str(Time.get_ticks_usec()),index]
  check((await account("register",username)).ok,"restart fixture account registers")
  accounts.append(await account("login",username))
 host=make_session(0);guest=make_session(1)
 var early_saved={}
 host.match_found.connect(func():early_saved.host=host.saved_ranked_recovery())
 guest.match_found.connect(func():early_saved.guest=guest.saved_ranked_recovery())
 guest.identity.resume={"room_id":"TEST_ONLY_PREVIOUS_ROOM","cloud_match_id":"TEST_ONLY_PREVIOUS_MATCH"}
 host.start_matchmaking(ENDPOINT,decks[0]);await until(func():return host.notice.contains("正在自动匹配"))
 guest.start_matchmaking(ENDPOINT,decks[1])
 check(await until(func():return host.can_act() and guest.can_act()),"restart fixture synchronizes an actual ranked match")
 if not failures.is_empty():finish();return
 var match_id=host.cloud_match_id
 check(not host.saved_ranked_recovery().is_empty() and not guest.saved_ranked_recovery().is_empty(),"both assigned roles persist their pending ranked match")
 check(not early_saved.get("host",{}).is_empty() and not early_saved.get("guest",{}).is_empty() and early_saved.guest.get("room_id","").is_empty() and not early_saved.guest.match_deck.is_empty(),"assignment persists both roles before the guest's first welcome")
 check(guest.identity.resume.get("cloud_match_id","")==match_id,"a new assignment replaces stale guest recovery from a previous match")
 host.room_action({"name":"ready"})
 check(await until(func():return host.can_act() and guest.can_act()),"authority acknowledges sideboard readiness")
 guest.room_action({"name":"ready"})
 check(await until(func():return host.can_act() and guest.can_act() and host.series.state.status=="choosing"),"ranked sideboard readiness opens first-player choice")
 if not failures.is_empty():finish();return
 var selecting=host if host.series.state.chooser==0 else guest
 selecting.room_action({"name":"first","first":true})
 check(await until(func():return host.can_act() and guest.can_act() and not guest.latest_snapshot.is_empty()),"ranked match reaches an acknowledged battlefield")
 sync_views()
 if not failures.is_empty():finish();return
 var game_id=host.series.state.game_id
 var original_room_id=guest.room_id
 guest.on_failure("TEST_ONLY network fluctuation")
 guest.stop_waiting();guest.end_disconnected_match()
 check(guest.room_id==original_room_id and not guest.saved_ranked_recovery().is_empty(),"abandon-wait callbacks preserve a disconnected ranked match")
 guest.check_reconnect_timeout(guest.disconnected_at+30000)
 check(not guest.wait_choice_pending and guest.ranked_match_pending(),"ranked reconnect keeps running without a local 30-second wait choice")
 guest.transport.close();guest.queue_free();await process_frame
 var guest_app=await restart_app(1);guest=guest_app.lan_session
 check(await until(func():return host.can_act() and guest.can_act()),"restarted guest rejoins the original battle after automatic login")
 check(guest.cloud_match_id==match_id and guest.room_id==original_room_id and guest.latest_snapshot.get("game_id","")==game_id,"guest restart preserves match identity and the existing battlefield")
 if not failures.is_empty():finish();return
 host.transport.close();host.queue_free();await process_frame
 var host_app=await restart_app(0);host=host_app.lan_session
 check(await until(func():return host.can_act() and guest.can_act()),"restarted authority restores its saved battle and synchronizes the guest")
 check(host.cloud_match_id==match_id and host.series.state.game_id==game_id and host.authority!=null,"host restart keeps the authoritative engine and original match")
 if not failures.is_empty():finish();return
 sync_views()
 check(guest.submit({"name":"surrender","args":[]}).is_empty(),"restored guest can submit a real battle command")
 check(await until(func():return host.match_settled and guest.match_settled),"restored match reaches server settlement")
 check(host.saved_ranked_recovery().is_empty() and guest.saved_ranked_recovery().is_empty(),"server settlement clears forced recovery for both players")
 check(not guest_app.restore_pending_ranked_match(),"successful login with a settled record has no forced recovery")
 var settled=make_session(1)
 check(settled.saved_ranked_recovery().is_empty(),"a subsequent process does not recover an already settled match")
 settled.leave(false);settled.queue_free()
 var saved=host.identity.get("ranked_resume",{})
 host.identity.ranked_resume={"account":"TEST_ONLY_OTHER_ACCOUNT","cloud_slot":1,"room_id":"other","cloud_match_id":"other"}
 check(host.saved_ranked_recovery().is_empty(),"automatic recovery excludes a different signed-in account")
 host.identity.ranked_resume=saved
 guest.match_settled=false;guest.cloud_match_id="TEST_ONLY_EXPIRED_MATCH"
 guest.room.status="playing";guest.room.erase("forfeit");guest.rejected=false;guest.disconnected_at=0
 guest.identity.ranked_resume={"account":guest.cloud_account,"cloud_slot":2,"room_id":"expired","cloud_match_id":guest.cloud_match_id}
 guest.on_failure("TEST_ONLY temporary outage")
 check(guest.ranked_match_pending() and not guest.rejected and not guest.saved_ranked_recovery().is_empty(),"a transient network error retains forced recovery instead of ending the match")
 guest.on_failure("匹配房间已失效，请返回云端重新匹配")
 check(guest.match_settled and guest.saved_ranked_recovery().is_empty() and not guest.joining,"closed server match terminates recovery without starting a new room")
 finish()

func finish():
 for session in [host,guest]:
  if is_instance_valid(session):session.leave(false)
 for app in apps:
  if is_instance_valid(app):app.queue_free()
 print("RANKED RESTART ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
