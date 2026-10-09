extends "res://tests/support/network_base.gd"
const AccountClient=preload("res://scripts/account_client.gd")
const Directory=preload("res://net/cloud_directory.gd")
const Series=preload("res://net/series_controller.gd")
const ENDPOINT="ws://127.0.0.1:48045"
var accounts=[]
var sessions=[]
var ratings=[-1,-1]

func account(action: String,username: String) -> Dictionary:
 var client=AccountClient.new();root.add_child(client);client.server_url=ENDPOINT
 client.call_deferred("submit",action,username,"password123!")
 var result=await client.finished
 var answer={"ok":result[0],"message":result[1],"token":client.session_token,"nickname":client.nickname,"elo":client.elo}
 client.queue_free();return answer

func make_session(index: int):
 var session=Session.new();root.add_child(session)
 session.initialize("res://work/cloud-matchmaking/%s-%d" % [str(Time.get_ticks_usec()),index])
 session.cloud_token=accounts[index].token;session.cloud_nickname=accounts[index].nickname
 sessions.append(session);return session

func ready_pair():
 host.room_action({"name":"ready"});await until(func():return host.can_act() and guest.can_act())
 guest.room_action({"name":"ready"});await until(func():return host.can_act() and guest.can_act())

func run():
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 var prefix="match_%s_" % str(Time.get_ticks_usec())
 for index in range(3):
  var username=prefix+str(index)
  var registered=await account("register",username)
  var logged=await account("login",username)
  check(registered.ok and logged.ok,"match account %d logs in" % index)
  if not registered.ok or not logged.ok:print(registered.message," / ",logged.message);quit(1);return
  accounts.append(logged)
 host=make_session(0);guest=make_session(1)
 var waiting=make_session(2)
 waiting.start_matchmaking(ENDPOINT,decks[0])
 check(await until(func():return waiting.notice.contains("正在自动匹配")),"request enters server queue")
 check(waiting.match_queued==1,"queue count includes the waiting player")
 waiting.cancel_matchmaking();check(not waiting.matchmaking and not waiting.transport.online,"cancel closes the queue connection")
 await create_timer(0.2).timeout
 check(host.start_matchmaking(ENDPOINT,decks[0]).is_empty(),"first player queues")
 check(await until(func():return host.notice.contains("正在自动匹配")),"first player awaits an opponent")
 var duplicate=Session.new();root.add_child(duplicate);duplicate.initialize("res://work/cloud-matchmaking/duplicate");duplicate.cloud_token=accounts[0].token
 duplicate.error_raised.connect(func(_message):pass)
 duplicate.start_matchmaking(ENDPOINT,decks[0])
 check(await until(func():return not duplicate.matchmaking),"same account cannot queue twice")
 duplicate.leave(false);duplicate.queue_free()
 guest.start_matchmaking(ENDPOINT,decks[1])
 check(await until(func():return host.can_act() and guest.can_act()),"server assigns paired host and guest without a room application")
 if not host.can_act() or not guest.can_act():print("HOST ",host.notice," GUEST ",guest.notice);cleanup();quit(1);return
 check(host.is_host and not guest.is_host and host.cloud_ranked and guest.cloud_ranked,"automatic pairing assigns fixed battle seats")
 check(host.room.format==Series.BO1_SIDEBOARD and guest.room.format==Series.BO1_SIDEBOARD and host.room.strict,"ranked format is strict BO1 sideboarding")
 check(host.room.rule_set==Store.RuleSet.OFFICIAL and guest.room.rule_set==Store.RuleSet.OFFICIAL,"both matched clients use the fixed official rule set")
 check(not host.can_move_cloud_seats(),"matchmaking disables moving seats")
 var own_ratings=[];var other_ratings=[];var own_ranks=[]
 host.rank_updated.connect(func(rank):own_ranks.append(rank))
 host.rating_updated.connect(func(elo):own_ratings.append(elo))
 guest.rating_updated.connect(func(elo):other_ratings.append(elo))
 var directory=Directory.new();root.add_child(directory);directory.start(ENDPOINT,accounts[2].token)
 var snapshots=[];directory.changed.connect(func():snapshots.append(true))
 check(await until(func():return not snapshots.is_empty()),"authenticated observer gets directory")
 check(directory.queued==0,"directory reports no players after the pair leaves the queue")
 check(directory.rooms.any(func(info):return info.id==host.relay_code and info.watch_only),"matchmaking room appears with a spectator-only entry")
 check(directory.rooms.any(func(info):return info.id==host.relay_code and info.rule_set==Store.RuleSet.OFFICIAL),"directory publishes official matching rules")
 var outsider=make_session(2);outsider.join_relay_room(ENDPOINT,host.relay_code,false,8)
 check(await until(func():return outsider.connected and not outsider.room_id.is_empty()),"observer joins the matchmaking room during registration")
 check(outsider.read_only and not outsider.can_act() and host.spectator_hub.watchers.size()==1,"matched observer has no battle actions")
 check(outsider.room.rule_set==Store.RuleSet.OFFICIAL,"observer receives the official rule set")
 for index in range(2):
  check(Store.validate(decks[index],true,Store.RuleSet.OFFICIAL).is_empty(),"match deck %d passes official validation" % index)
 var errors=[]
 host.error_raised.connect(func(message):errors.append(message))
 guest.error_raised.connect(func(message):errors.append(message))
 for id in ["new-spx-001"]+Store.RuleSet.OFFICIAL_TWO:
  var illegal=decks[1].duplicate(true);illegal.rule_set=Store.RuleSet.TEST;illegal.side=[id]
  if id in Store.RuleSet.OFFICIAL_TWO:illegal.main[0]=id;illegal.main[1]=id
  check(Store.validate(illegal,true,Store.RuleSet.UNRESTRICTED).is_empty(),"rejected match deck is legal under unrestricted rules: "+id)
  errors.clear();guest.room_action({"name":"deck","deck":illegal})
  check(await until(func():return not errors.is_empty() and guest.can_act()),"guest deck rejection is synchronized: "+id)
  check(not errors.is_empty() and str(errors[0]).contains("官限") and host.series.state.decks[1]==Store.clean_deck(decks[1]),"official matching rejects banned or excess cards despite the deck's test tag: "+id)
 check(host.room.status=="sideboarding" and guest.room.status=="sideboarding" and guest.room.has("leaders"),"prematched decks automatically register and expose leaders for sideboarding")
 check(host.room.rule_set==Store.RuleSet.OFFICIAL and guest.room.rule_set==Store.RuleSet.OFFICIAL,"sideboarding retains the official rule set")
 var illegal_sideboard=decks[0].duplicate(true);illegal_sideboard.rule_set=Store.RuleSet.TEST;illegal_sideboard.main[0]="new-spx-001"
 errors.clear();host.room_action({"name":"deck","deck":illegal_sideboard})
 check(not errors.is_empty() and str(errors[0]).contains("官限") and host.series.state.decks[0]==Store.clean_deck(decks[0]),"host sideboarding rejects banned cards without changing the registered deck")
 check(await until(func():return outsider.room.get("status","")=="sideboarding" and outsider.room.has("leader_arts")),"observer receives public leaders during sideboarding")
 await ready_pair()
 check(host.room.status=="choosing" and guest.room.status=="choosing","second ready opens first-player choice")
 var chooser=host if host.series.state.chooser==0 else guest
 chooser.room_action({"name":"first","first":true})
 check(await until(func():return host.can_act() and guest.can_act() and guest.room.status=="playing"),"ranked battle starts")
 check(await until(func():return not outsider.latest_snapshot.is_empty()),"matched observer receives the battle projection")
 sync_views()
 check(not host.room.has("timed") and not guest.room.has("timed") and not outsider.room.has("timed"),"players and observers have no timed room mode")
 var original=host.authority.players.map(func(p):return p.hand.map(func(c):return c.uid))
 var first_choice=[original[0][0]];var second_choice=[original[1][0]]
 var opening_sequence=host.sequence
 check(host.submit({"name":"mulligan","args":[first_choice]}).is_empty(),"host submits a locked opening choice")
 check(await until(func():return host.can_act() and guest.can_act() and host.authority.players[0].mulligan_done),"first opening submission is acknowledged")
 sync_views()
 check(host.authority.players.map(func(p):return p.hand.map(func(c):return c.uid))==original and host.authority.phase=="mulligan","first submission does not exchange either player's cards")
 await create_timer(10.3).timeout
 check(host.authority.phase=="mulligan" and not host.authority.players[1].mulligan_done,"waiting past the former opening deadline does not submit a default")
 var opening=host.Codec.capture(host.authority)
 # Exercise guest reconnection while a private opening choice is staged.
 guest.transport.close();guest.on_disconnect(1)
 check(await until(func():return not host.connected),"ranked connection loss pauses the host")
 guest.retry_connection(Time.get_ticks_msec(),true)
 check(await until(func():return host.can_act() and guest.can_act()),"original player resumes its reserved match")
 check(host.room.rule_set==Store.RuleSet.OFFICIAL and guest.room.rule_set==Store.RuleSet.OFFICIAL,"reconnection preserves official matching rules")
 check(host.Codec.capture(host.authority)==opening,"reconnection preserves both original hands and the staged choice")
 sync_views()
 # Both clients may have submitted against the same opening sequence.
 var second_id="TEST_ONLY_CONCURRENT_MULLIGAN"
 guest.busy=true;guest.inflight={"id":second_id}
 host.handle_command(1,{"id":second_id,"room_id":host.room_id,"game_id":host.series.state.game_id,"expected":opening_sequence,"command":{"name":"mulligan","args":[second_choice]}})
 check(await until(func():return host.can_act() and guest.can_act() and host.authority.phase!="mulligan"),"second concurrent submission resolves both hands and acknowledges the guest")
 check(host.authority.players[0].hand.all(func(c):return c.uid not in first_choice) and host.authority.players[1].hand.all(func(c):return c.uid not in second_choice),"both selected cards are replaced only after both submissions")
 var resolved_sequence=host.sequence
 host.handle_command(1,{"id":second_id,"room_id":host.room_id,"game_id":host.series.state.game_id,"expected":opening_sequence,"command":{"name":"mulligan","args":[second_choice]}})
 check(host.sequence==resolved_sequence,"duplicate opening submission cannot exchange cards twice")
 check(await until(func():return host.can_act() and guest.can_act()),"duplicate receipt resynchronizes both players")
 sync_views()
 check(guest.submit({"name":"surrender","args":[]}).is_empty(),"ranked surrender submitted")
 var surrender_packet=guest.inflight.duplicate(true)
 check(await until(func():return host.series.state.status=="complete" and guest.room.get("status","")=="complete"),"completed result reaches both players")
 var final_sequence=host.sequence;var scores=host.series.state.scores.duplicate()
 host.handle_command(1,surrender_packet)
 check(host.sequence==final_sequence and host.series.state.scores==scores,"duplicate surrender does not award another win")
 check(await until(func():return host.match_settled and guest.match_settled,12),"both final reports settle the match")
 check(own_ratings.has(1016) and other_ratings.has(984),"winner gains Elo and loser loses Elo privately")
 check(not own_ranks.is_empty() and own_ranks.back().stars==1,"settlement updates the winner rank exactly once")
 check(not host.connected and not guest.connected and host.paused and guest.paused,"settlement stops battle heartbeats after the room is removed")
 check(await until(func():return outsider.room.get("status","")=="complete" and outsider.rejected),"observer receives the result and stops reconnecting to the closed room")
 snapshots.clear();directory.refresh()
 check(await until(func():return not snapshots.is_empty()) and directory.rooms.all(func(info):return info.id!=host.relay_code),"settled match disappears while both players remain on the result screen")
 check(not host.room.has("elo") and not guest.room.has("elo") and not JSON.stringify(directory.rooms).contains("elo"),"room state and directory contain no ratings")
 host.transport.relay_result(host.cloud_match_id,0);guest.transport.relay_result(guest.cloud_match_id,0)
 await create_timer(1.3).timeout
 var login=await account("login",prefix+"0")
 check(login.ok and login.elo==1016,"duplicate settlement cannot change persisted rating")
 directory.stop();directory.queue_free();cleanup()
 print("CLOUD MATCHMAKING ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)

func cleanup():
 for session in sessions:session.leave(false)
