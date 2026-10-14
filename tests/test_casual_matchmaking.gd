extends "res://tests/support/network_base.gd"
const AccountClient=preload("res://scripts/account_client.gd")
const Directory=preload("res://net/cloud_directory.gd")
const ENDPOINT="ws://127.0.0.1:48045"
var accounts=[]
var sessions=[]
var fixture="res://work/casual-match/network-"+str(Time.get_ticks_usec())

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
 var prefix="casual_%s_" % str(Time.get_ticks_usec())
 for index in range(3):
  var username=prefix+str(index)
  check((await account("register",username)).ok,"casual fixture account registers")
  accounts.append(await account("login",username))
 host=make_session(0);guest=make_session(1)
 var casual_deck=decks[0].duplicate(true);casual_deck.side=["new-spx-001"]
 check(not Store.validate(casual_deck,true,Store.RuleSet.OFFICIAL).is_empty() and Store.validate(casual_deck,true,Store.RuleSet.UNRESTRICTED).is_empty(),"casual fixture requires unrestricted rules")
 host.start_matchmaking(ENDPOINT,decks[0]);guest.start_matchmaking(ENDPOINT,casual_deck,true,"casual")
 check(await until(func():return host.match_queued==1 and guest.match_queued==1),"ranked and casual requests wait in distinct one-player queues")
 await create_timer(1.2).timeout
 check(host.matchmaking and guest.matchmaking and host.room_id.is_empty() and guest.room_id.is_empty(),"different modes cannot pair through the real relay")
 host.cancel_matchmaking();guest.cancel_matchmaking();await create_timer(0.2).timeout
 host.start_matchmaking(ENDPOINT,casual_deck,true,"casual");await until(func():return host.match_queued==1)
 guest.start_matchmaking(ENDPOINT,decks[1],true,"casual")
 check(await until(func():return host.can_act() and guest.can_act()),"real casual clients register decks and reach sideboarding")
 if not failures.is_empty():finish();return
 check(host.room.status=="sideboarding" and guest.room.status=="sideboarding" and host.room.ready==guest.room.ready,"initial casual handshake immediately synchronizes both preparation views")
 check(host.is_host and host.room.rule_set==Store.RuleSet.UNRESTRICTED and guest.room.rule_set==Store.RuleSet.UNRESTRICTED and not host.room.ranked,"both casual clients use confirmed unrestricted rules")
 check(host.room.get("ranks",[]).is_empty() and guest.room.get("ranks",[]).is_empty(),"casual room does not display ranked opponent data")
 var directory=Directory.new();root.add_child(directory);directory.match_mode="casual";directory.start(ENDPOINT,accounts[2].token,host.fingerprint)
 check(await until(func():return directory.rooms.any(func(info):return info.id==host.relay_code)),"public casual match appears in the directory")
 check(directory.rooms.any(func(info):return info.name.contains("休闲") and info.rule_set==Store.RuleSet.UNRESTRICTED and info.watch_only),"casual directory shows the mode, unrestricted rules and spectator entry")
 var observer=make_session(2);observer.join_relay_room(ENDPOINT,host.relay_code,false,8)
 check(await until(func():return observer.connected and not observer.room_id.is_empty()),"casual match accepts a spectator")
 var sideboard=casual_deck.duplicate(true);sideboard.main[0]="new-spx-001";sideboard.side=[casual_deck.main[0]]
 host.room_action({"name":"deck","deck":sideboard})
 check(await until(func():return host.can_act() and guest.can_act()) and host.series.state.decks[0]==Store.clean_deck(sideboard),"casual sideboarding can swap in an unrestricted card")
 host.room_action({"name":"ready"})
 check(await until(func():return host.can_act() and guest.can_act() and host.room.ready[0]),"host confirms casual sideboard readiness")
 guest.room_action({"name":"ready"})
 check(await until(func():return host.can_act() and guest.can_act() and host.room.status=="choosing" and guest.room.status=="choosing"),"both casual players reach first-player selection")
 if not failures.is_empty():directory.stop();finish();return
 var chooser=host if host.series.state.chooser==0 else guest
 chooser.room_action({"name":"first","first":true})
 check(await until(func():return host.can_act() and guest.can_act() and host.room.status=="playing" and guest.room.status=="playing"),"casual first-player choice starts the battlefield")
 if not failures.is_empty():directory.stop();finish();return
 var match_id=host.cloud_match_id;var game_id=host.series.state.game_id
 guest.transport.close();guest.queue_free();await process_frame
 guest=make_session(1)
 check(guest.restore_ranked_match(guest.saved_ranked_recovery()).is_empty(),"restarted casual guest requests its saved match")
 check(await until(func():return host.can_act() and guest.can_act()) and guest.match_mode=="casual" and guest.room.rule_set==Store.RuleSet.UNRESTRICTED,"guest restart preserves casual mode and unrestricted rules")
 host.transport.close();host.queue_free();await process_frame
 host=make_session(0)
 check(host.restore_ranked_match(host.saved_ranked_recovery()).is_empty(),"restarted casual host restores its saved engine")
 check(await until(func():return host.can_act() and guest.can_act()) and host.match_mode=="casual" and host.cloud_match_id==match_id and host.series.state.game_id==game_id,"host restart preserves the casual battlefield and match identity")
 if not failures.is_empty():directory.stop();finish();return
 var rating_updates=[];var rank_updates=[];var results=[]
 for session in [host,guest]:
  session.rating_updated.connect(func(elo):rating_updates.append(elo));session.rank_updated.connect(func(rank):rank_updates.append(rank))
  session.transport.relay_match_settled.connect(func(result):results.append(result))
 sync_views()
 check(guest.submit({"name":"surrender","args":[]}).is_empty(),"casual guest submits a real surrender")
 check(await until(func():return host.match_settled and guest.match_settled),"casual match finishes through persistent server settlement")
 check(host.room.status=="complete" and guest.room.status=="complete" and host.room.winner==0 and guest.room.winner==0,"unrated settlement preserves the real winner on both clients")
 check(results.size()==2 and results.all(func(result):return not result.rated and not result.has("elo") and not result.has("rank")),"casual settlement responses contain no Elo or rank updates")
 check(rating_updates.all(func(elo):return elo==accounts[0].elo) and rank_updates.all(func(rank):return rank==accounts[0].rank),"periodic authentication keeps the original casual ratings and ranks")
 check(host.notice.contains("不影响段位") and guest.notice.contains("不影响段位"),"both casual result notices explain unchanged rank")
 check(await until(func():return observer.room.get("status","")=="complete" and observer.rejected) and observer.room.winner==0,"casual spectator receives the winner and stops reconnecting")
 check(host.saved_ranked_recovery().is_empty() and guest.saved_ranked_recovery().is_empty(),"casual completion clears both recovery records")
 for index in range(2):
  var login=await account("login",accounts[index].username)
  check(login.ok and login.elo==accounts[index].elo and login.rank==accounts[index].rank,"casual winner and loser retain persisted Elo and rank: "+str(index))
 directory.stop();directory.queue_free();finish()

func finish():
 for session in sessions:
  if is_instance_valid(session):session.leave(false)
 print("CASUAL MATCHMAKING ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
