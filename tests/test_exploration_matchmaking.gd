extends "res://tests/support/network_base.gd"
const AccountClient=preload("res://scripts/account_client.gd")
const Directory=preload("res://net/cloud_directory.gd")
const G=preload("res://scripts/rules/gensokyo_exploration.gd")
const Series=preload("res://net/series_controller.gd")
const ENDPOINT="ws://127.0.0.1:48045"
var random_mode="--random" in OS.get_cmdline_user_args()
var mode="exploration_random" if random_mode else "exploration"
var format_value=Series.EXPLORATION_RANDOM if random_mode else Series.EXPLORATION
var preset=G.deck(random_mode)
var accounts=[]
var sessions=[]
var fixture="res://work/exploration-match/network-"+str(Time.get_ticks_usec())

func account(action: String,username: String) -> Dictionary:
 var client=AccountClient.new();root.add_child(client);client.server_url=ENDPOINT
 client.call_deferred("submit",action,username,"password123!")
 var result=await client.finished
 var answer={"ok":result[0],"username":username,"token":client.session_token,"nickname":client.nickname,"elo":client.elo,"rank":client.rank.duplicate(true)}
 client.queue_free();return answer

func make_session(index: int):
 var session=Session.new();root.add_child(session);session.initialize(fixture+"/player"+str(index))
 session.cloud_account=accounts[index].username;session.cloud_token=accounts[index].token;session.cloud_nickname=accounts[index].nickname
 sessions.append(session);return session

func run():
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 var prefix="explore_%s_" % str(Time.get_ticks_usec())
 for index in range(3):
  var username=prefix+str(index)
  check((await account("register",username)).ok,"exploration fixture registers")
  accounts.append(await account("login",username))
 host=make_session(0);guest=make_session(1)
 for host_slot in [1,2]:
  var guest_slot=3-host_slot
  check(host.create_relay_room(ENDPOINT,format_value,true,"unrestricted","固定卡组准备测试","",host_slot).is_empty(),"exploration manual room creates in seat "+str(host_slot))
  check(await until(func():return host.transport.relay_seat==host_slot),"manual exploration host registers")
  guest.join_relay_room(ENDPOINT,host.relay_code,false,guest_slot)
  check(await until(func():return host.can_act() and guest.can_act()),"manual exploration room synchronizes both battle seats")
  check(host.room.own_deck==preset and guest.room.own_deck==preset,"joining preserves the preset for both battle seats")
  var denied=[];guest.error_raised.connect(func(message):denied.append(message),CONNECT_ONE_SHOT)
  var alternate=Series.EXPLORATION if random_mode else Series.EXPLORATION_RANDOM
  guest.room_action({"name":"entertainment_mode","format":alternate})
  check(await until(func():return not denied.is_empty() and host.can_act() and guest.can_act()) and host.room.format==format_value,"guest cannot change the entertainment submode")
  host.room_action({"name":"ready"});await until(func():return host.can_act() and guest.can_act())
  host.room_action({"name":"entertainment_mode","format":alternate})
  check(await until(func():return host.can_act() and guest.can_act() and guest.room.format==alternate) and guest.room.ready==[false,false] and guest.room.own_deck==Series.entertainment_deck(alternate),"host switching synchronizes both presets and resets preparation")
  host.room_action({"name":"entertainment_mode","format":format_value})
  check(await until(func():return host.can_act() and guest.can_act() and guest.room.format==format_value) and guest.room.own_deck==preset,"host can restore the original entertainment submode")
  host.move_cloud_seat(guest_slot,3)
  check(await until(func():return guest.read_only and guest.cloud_slot==3),"player moves to spectator seat")
  host.move_cloud_seat(3,guest_slot)
  check(await until(func():return host.can_act() and guest.can_act() and not guest.read_only),"spectator returns to battle seat and completes synchronization")
  check(guest.room.own_deck==preset,"returning battle player receives the preset without manual deck registration")
  host.room_action({"name":"ready"})
  await until(func():return host.can_act() and guest.can_act() and guest.room.ready[host_slot-1])
  guest.room_action({"name":"ready"})
  check(await until(func():return host.can_act() and guest.can_act() and guest.room.status=="choosing"),"second ready click opens first-player selection for host seat "+str(host_slot))
  host.leave(false);guest.leave(false);await create_timer(0.2).timeout
 if not failures.is_empty():finish();return
 for other_mode in (["ranked","casual","exploration"] if random_mode else ["ranked","casual","exploration_random"]):
  host.start_matchmaking(ENDPOINT,decks[0],true,other_mode);guest.start_matchmaking(ENDPOINT,{},true,mode)
  check(await until(func():return host.match_queued==1 and guest.match_queued==1),"exploration queue is separate from "+other_mode)
  await create_timer(0.4).timeout
  check(host.matchmaking and guest.matchmaking and host.room_id.is_empty() and guest.room_id.is_empty(),"different modes never pair: "+other_mode)
  host.cancel_matchmaking();guest.cancel_matchmaking();await create_timer(0.2).timeout
 host.start_matchmaking(ENDPOINT,{},true,mode);await until(func():return host.match_queued==1)
 guest.start_matchmaking(ENDPOINT,{},true,mode)
 check(await until(func():return host.can_act() and guest.can_act()),"exploration pairs without a selected player deck")
 if not failures.is_empty():finish();return
 check(host.room.status=="choosing" and guest.room.status=="choosing" and host.room.chooser==guest.room.chooser and host.room.ready==guest.room.ready and host.room.ready.all(func(value):return value),"automatic fixed-deck registration immediately gives both clients the same first-player choice")
 if not failures.is_empty():finish();return
 check(host.is_host and host.room.format==format_value and guest.room.format==format_value,"server confirms exploration format on both clients")
 check(host.room.rule_set==Store.RuleSet.UNRESTRICTED and not host.room.ranked and host.room.get("ranks",[]).is_empty(),"exploration is unrated and has no opponent rank")
 check(host.room.own_deck==preset and guest.room.own_deck==preset,"both seats receive the fixed deck")
 var directory=Directory.new();root.add_child(directory);directory.match_mode=mode;directory.start(ENDPOINT,accounts[2].token,host.fingerprint)
 check(await until(func():return directory.rooms.any(func(info):return info.id==host.relay_code and info.name.contains("探索幻想乡") and info.watch_only)),"public entertainment match appears with spectator entry")
 var observer=make_session(2);observer.join_relay_room(ENDPOINT,host.relay_code,false,8)
 check(await until(func():return observer.connected and not observer.room_id.is_empty()),"entertainment match accepts a spectator")
 check(await until(func():return host.can_act() and guest.can_act() and host.room.status=="choosing" and guest.room.status=="choosing"),"fixed decks reach first-player selection")
 if not failures.is_empty():directory.stop();finish();return
 var chooser=host if host.series.state.chooser==0 else guest
 chooser.room_action({"name":"first","first":true})
 check(await until(func():return host.can_act() and guest.can_act() and host.room.status=="playing" and guest.room.status=="playing"),"entertainment starts a real battlefield")
 check(host.authority.players.all(func(p):return p.leader.card_id==preset.leader and (p.deck+p.hand).size()==50),"authority starts both prescribed leaders and 50-card decks")
 if not failures.is_empty():directory.stop();finish();return
 var match_id=host.cloud_match_id;var game_id=host.series.state.game_id
 guest.transport.close();guest.queue_free();await process_frame;guest=make_session(1)
 check(guest.restore_ranked_match(guest.saved_ranked_recovery()).is_empty(),"guest restart requests the saved entertainment match")
 check(await until(func():return host.can_act() and guest.can_act()) and guest.match_mode==mode and guest.room.format==format_value,"guest restart preserves entertainment mode")
 host.transport.close();host.queue_free();await process_frame;host=make_session(0)
 check(host.restore_ranked_match(host.saved_ranked_recovery()).is_empty(),"host restart restores the entertainment engine")
 check(await until(func():return host.can_act() and guest.can_act()) and host.match_mode==mode and host.cloud_match_id==match_id and host.series.state.game_id==game_id,"host restart preserves the battlefield and match identity")
 if not failures.is_empty():directory.stop();finish();return
 var results=[]
 for session in [host,guest]:session.transport.relay_match_settled.connect(func(result):results.append(result))
 sync_views();check(guest.submit({"name":"surrender","args":[]}).is_empty(),"guest submits real surrender")
 check(await until(func():return host.match_settled and guest.match_settled),"entertainment settles through the account backend")
 check(host.room.status=="complete" and guest.room.status=="complete" and host.room.winner==0 and guest.room.winner==0,"single game settlement keeps the correct winner")
 check(results.size()==2 and results.all(func(result):return not result.rated and not result.has("elo") and not result.has("rank")),"settlement never sends rating or rank changes")
 check(host.notice.contains("不影响段位") and guest.notice.contains("不影响段位"),"both clients explain unchanged rank")
 check(await until(func():return observer.room.get("status","")=="complete" and observer.rejected) and observer.room.winner==0,"spectator receives the winner and stops reconnecting")
 check(host.saved_ranked_recovery().is_empty() and guest.saved_ranked_recovery().is_empty(),"settlement clears both recovery records")
 for index in range(2):
  var login=await account("login",accounts[index].username)
  check(login.ok and login.elo==accounts[index].elo and login.rank==accounts[index].rank,"persisted Elo, stars and streak stay unchanged: "+str(index))
 directory.stop();directory.queue_free();finish()

func finish():
 for session in sessions:
  if is_instance_valid(session):session.leave(false)
 print("EXPLORATION MATCHMAKING ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
