extends "res://tests/support/network_base.gd"
const AccountClient=preload("res://scripts/account_client.gd")
const Directory=preload("res://net/cloud_directory.gd")
const ENDPOINT="ws://127.0.0.1:48045"
var accounts=[]
var sessions=[]
var prefix=""

func account(action: String,index: int) -> Dictionary:
 var client=AccountClient.new();root.add_child(client);client.server_url=ENDPOINT
 client.call_deferred("submit",action,prefix+str(index),"password123!")
 var result=await client.finished
 var answer={"ok":result[0],"token":client.session_token,"nickname":client.nickname,"elo":client.elo}
 client.queue_free();return answer

func make_session(index: int):
 var session=Session.new();root.add_child(session)
 session.initialize(OS.get_environment("MULTICOLOR_TEST_STORAGE").path_join(str(Time.get_ticks_usec())))
 session.cloud_token=accounts[index].token;session.cloud_nickname=accounts[index].nickname
 sessions.append(session);return session

func exercise(managed: bool,decks: Array):
 host=make_session(0);guest=make_session(1)
 var observer=make_session(2)
 if managed:
  host.start_matchmaking(ENDPOINT,decks[0]);guest.start_matchmaking(ENDPOINT,decks[1])
 else:
  check(host.create_relay_room(ENDPOINT,3,true,"unrestricted","超时验证","",2).is_empty(),"custom room authority can play from seat two")
  check(await until(func():return host.transport.relay_seat==2),"custom room registers")
  guest.join_relay_room(ENDPOINT,host.relay_code,false,1)
 check(await until(func():return host.can_act() and guest.can_act()),"both players synchronize before the timeout scenario")
 if not host.can_act() or not guest.can_act():return
 observer.join_relay_room(ENDPOINT,host.relay_code,false,8)
 check(await until(func():return observer.connected and not observer.room_id.is_empty()),"spectator joins the active room")
 if not managed:
  for player in [host,guest]:
   player.room_action({"name":"deck","deck":decks[player.local_actor()]})
   await until(func():return host.can_act() and guest.can_act())
 for player in [host,guest]:
  player.room_action({"name":"ready"})
  await until(func():return host.can_act() and guest.can_act())
 check(host.room.status=="choosing","ready players choose first player")
 var chooser=host if host.local_actor()==host.room.chooser else guest
 chooser.room_action({"name":"first","first":true})
 check(await until(func():return host.can_act() and guest.can_act() and host.authority!=null),"game starts before enforcing its response timer")
 var e=host.authority
 for player in e.players:player.mulligan_done=true
 e.phase="prepare";e.pending={};e.entry_choices=[];e.combat={};e.stack=[];e.active=0;e.priority=1;e.passes=0
 host.publish()
 check(await until(func():return host.can_act() and guest.can_act()),"real response deadline reaches both seats")
 var code=host.relay_code
 host.check_response_timeout(float(e.response_clock.deadline))
 check(await until(func():return guest.room.get("end_cause","")=="response_timeout"),"final timeout state reaches the opponent")
 check(host.room.winner==0 and guest.room.winner==0 and host.room.forfeit==1 and guest.room.forfeit==1,"timed-out seat loses even when it is the room authority")
 check(host.room.scores==[0,0],"entire BO3 forfeit does not fabricate game scores")
 check(await until(func():return not host.transport.online and not guest.transport.online,12),"both cloud player sockets close after result delivery and settlement")
 check(not managed or host.match_settled and guest.match_settled,"managed timeout receives server settlement before socket release")
 check(await until(func():return not observer.transport.online),"spectator socket is released with the ended room")
 check(observer.room.winner==0,"spectator receives the correct final winner")
 var directory=Directory.new();root.add_child(directory);directory.start(ENDPOINT,accounts[2].token)
 var refreshed=[];directory.changed.connect(func():refreshed.append(true))
 check(await until(func():return not refreshed.is_empty()),"directory refreshes after timeout")
 check(directory.rooms.all(func(info):return info.id!=code),"timeout room is removed from the relay directory")
 check(host.identity.resume.is_empty() and guest.identity.resume.is_empty(),"timeout clears stale recovery links")
 if managed:check(host.saved_ranked_recovery().is_empty() and guest.saved_ranked_recovery().is_empty(),"settled timeout cannot restore the old ranked match")
 directory.stop();directory.queue_free()
 for player in [host,guest,observer]:player.leave(false)

func run():
 prefix="timeout_%s_" % str(Time.get_ticks_usec())
 for index in range(3):
  var registered=await account("register",index)
  var logged=await account("login",index)
  check(registered.ok and logged.ok,"timeout test account authenticates")
  if not logged.ok:quit(1);return
  accounts.append(logged)
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 await exercise(false,decks)
 await exercise(true,decks)
 var winner=await account("login",0);var loser=await account("login",1)
 check(winner.elo==1016 and loser.elo==984,"timeout settles ranked Elo once and custom forfeit does not affect it")
 accounts[0]=winner;accounts[1]=loser
 host=make_session(0);guest=make_session(1)
 host.start_matchmaking(ENDPOINT,decks[0]);guest.start_matchmaking(ENDPOINT,decks[1])
 check(await until(func():return host.can_act() and guest.can_act()),"both accounts can match again immediately after timeout")
 for player in sessions:player.leave(false)
 print("CLOUD RESPONSE TIMEOUT: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
