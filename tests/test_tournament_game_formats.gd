extends "res://tests/support/network_base.gd"
const Client=preload("res://scripts/tournament_client.gd")
var fixture: Dictionary
var endpoint="ws://127.0.0.1:48065"
var competition_id=0
var sessions=[]
var admission_checked=false

func api(payload: Dictionary,user: String="bigcake") -> Dictionary:
 var client=Client.new();root.add_child(client);client.server_url=endpoint
 var completion={"answer":{},"done":false}
 client.finished.connect(func(value):completion.answer=value;completion.done=true)
 client.request(payload,fixture.logins[user].token)
 check(await until(func():return completion.done,20),"game format API completes")
 client.queue_free();return completion.answer

func call_action(action: String,user: String="bigcake",extra: Dictionary={}) -> Dictionary:
 var payload={"action":action,"id":competition_id};payload.merge(extra)
 return await api(payload,user)

func make_session(user: String,game_format: int):
 var session=Session.new();root.add_child(session)
 session.initialize(fixture.folder.path_join("format-%d-%s" % [game_format,user]))
 session.cloud_account=user;session.cloud_token=fixture.logins[user].token;session.cloud_nickname=fixture.logins[user].nickname
 sessions.append(session);return session

func choose_game() -> bool:
 if not await until(func():return host.can_act() and guest.can_act()):return false
 if host.room.status in ["sideboarding","between"]:
  if int(host.room.format)==2 and not host.series.state.decks[0].side.is_empty():
   var swapped=host.series.state.decks[0].duplicate(true)
   var card=swapped.main[0];swapped.main[0]=swapped.side[0];swapped.side[0]=card
   host.room_action({"name":"deck","deck":swapped})
   if not await until(func():return host.can_act() and guest.can_act()):return false
   check(Store.same_cards(host.series.state.decks[0],swapped),"submitted deck still supports legal BO1 sideboarding")
   var original=await call_action("detail",host.cloud_account)
   check(Store.same_cards(original.decklist.deck,host.series.state.registered[0]),"sideboarding preserves the server's pre-match list")
  host.room_action({"name":"ready"})
  if not await until(func():return host.can_act() and guest.can_act()):return false
  guest.room_action({"name":"ready"})
 if not await until(func():return host.can_act() and guest.can_act() and host.room.status=="choosing"):return false
 var chooser=host if host.series.state.chooser==0 else guest
 chooser.room_action({"name":"first","first":true})
 if not await until(func():return host.can_act() and guest.can_act() and host.room.status=="playing"):return false
 sync_views();return true

func create_round(game_format: int,with_guest: bool=true):
 var created=await api({"action":"create","title":"对局赛制验证","game_format":game_format,"swiss_rounds":1,"start_at":int(Time.get_unix_time_from_system())+3600})
 check(created.get("ok",false),"creates a competition with format %d" % game_format)
 if not created.get("ok",false):return false
 competition_id=int(created.tournament.id)
 for user in ["first_player","second_player"]:check((await call_action("join",user)).get("ok",false),"players register before the start time")
 await call_action("configure","bigcake",{"game_format":game_format,"swiss_rounds":1,"start_at":int(Time.get_unix_time_from_system())+2})
 await create_timer(2.6).timeout
 for user in ["first_player","second_player"]:check((await call_action("checkin",user)).get("ok",false),"registered players check in at the start time")
 await call_action("close_checkin")
 var started=await call_action("start_round","bigcake",{"expected_round":0})
 check(started.get("ok",false),"organizer starts the assigned round")
 if game_format not in [4,5]:
  check((await call_action("configure_decklist","bigcake",{"round_number":1,"fixed_deck":true,"deadline_at":int(Time.get_unix_time_from_system())+3600})).get("ok",false),"organizer enables fixed decks for this round")
 var assigned=await call_action("detail","first_player")
 var ticket=str(assigned.my_pairing.match_id)
 var first="first_player" if assigned.my_pairing.actor==0 else "second_player"
 var second="second_player" if first=="first_player" else "first_player"
 host=make_session(first,game_format);guest=make_session(second,game_format)
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 if game_format==2:
  for card in decks[1].main:
   var candidate=decks[0].duplicate(true);candidate.side=[card]
   if Store.validate(candidate,true,"unrestricted").is_empty():decks[0]=candidate;break
  check(decks[0].side.size()==1,"sideboarding fixture has a legal reserve card")
 var mode="exploration_random" if game_format==5 else "exploration" if game_format==4 else "casual"
 var probe=game_format==1 and not admission_checked
 if probe:
  check(host.start_matchmaking(endpoint,decks[0],true,mode,ticket,game_format).is_empty(),"unsubmitted client reaches server validation")
  check(await until(func():return not host.matchmaking and host.notice.contains("请先提交本轮比赛牌表"),12),"relay rejects a missing submitted decklist")
  host.leave(false)
 if game_format not in [4,5]:
  for entry in [[first,decks[0]],[second,decks[1]]]:
   var submitted=await call_action("submit_decklist",entry[0],{"round_number":1,"deck":Store.clean_deck(entry[1])})
   check(submitted.get("ok",false) and submitted.decklist.can_submit,"server validates a list and allows replacement before cutoff")
 if probe:
  check(host.start_matchmaking(endpoint,decks[1],true,mode,ticket,game_format).is_empty(),"changed but legal local deck reaches server validation")
  check(await until(func():return not host.matchmaking and host.notice.contains("本地卡组与服务器已交付牌表不一致"),12),"relay rejects a different legal deck even with its valid client hash")
  host.leave(false)
  admission_checked=true
 if game_format not in [4,5]:
  check((await call_action("configure_decklist","bigcake",{"round_number":1,"fixed_deck":true,"deadline_at":int(Time.get_unix_time_from_system())+2})).get("ok",false),"organizer sets round submission cutoff")
  await create_timer(2.6).timeout
 check(host.start_matchmaking(endpoint,decks[0],true,mode,ticket,game_format).is_empty(),"first assigned player enters format %d" % game_format)
 check(await until(func():return host.match_queued==1),"first player waits for the assigned opponent")
 if not with_guest:return true
 check(guest.start_matchmaking(endpoint,decks[1],true,mode,ticket,game_format).is_empty(),"second assigned player enters format %d" % game_format)
 check(await until(func():return host.can_act() and guest.can_act(),15),"both game clients synchronize")
 if not host.can_act() or not guest.can_act():return false
 check(int(host.room.format)==game_format and int(guest.room.format)==game_format,"relay and both clients honor the competition format")
 check(int(host.saved_ranked_recovery().get("competition_format",0))==game_format and int(guest.saved_ranked_recovery().get("competition_format",0))==game_format,"saved recovery preserves the competition format")
 if game_format in [4,5]:
  check(Session.Series.Exploration.fixed_deck(host.series.state.decks[0],game_format==5) and host.series.state.decks[0]==host.series.state.decks[1],"entertainment uses the shared fixed deck")
 return true

func run():
 var args=OS.get_cmdline_user_args()
 for i in range(args.size()-1):
  if args[i]=="--fixture":fixture=JSON.parse_string(FileAccess.get_file_as_string(args[i+1]))
 if fixture.is_empty():quit(1);return
 for game_format in ([] if "--forfeit-only" in args else [1,2,3,4,5,6,7]):
  if not await create_round(game_format):finish();return
  var games=3 if game_format==6 else 2 if game_format in [3,7] else 1
  for game in range(games):
   check(await choose_game(),"format %d starts game %d" % [game_format,game+1])
   if host.room.status!="playing":finish();return
   var surrendering=host if game_format==7 and game==1 else guest
   check(surrendering.submit({"name":"surrender","args":[]}).is_empty(),"real game surrender is submitted")
   check(await until(func():return host.room.status!="playing" and guest.room.status==host.room.status),"single game result synchronizes")
   if game<games-1:
    check(not host.match_settled and host.room.status=="between","BO3 remains active after its first game")
    var unfinished=await call_action("detail")
    check(unfinished.pairings[0].result==null,"BO3 does not fill the match result before two wins")
   sync_views()
  check(await until(func():return host.match_settled and guest.match_settled,15),"full match settles for format %d" % game_format)
  var result=await call_action("detail")
  check(result.pairings[0].result==(-1 if game_format==7 else 0) and result.pairings[0].source=="game","format %d automatically fills the competition result" % game_format)
  check(int(result.pairings[0].scores[0])==(1 if game_format==7 else games) and int(result.pairings[0].scores[1])==(1 if game_format==7 else 0),"actual series score reaches the server: "+str(result.pairings[0].scores))
  host.leave(false);guest.leave(false)
 # A BO2 forfeiture preserves played scores but settles the adjudicated 2:0.
 if await create_round(7):
  check(await choose_game(),"BO2 timeout fixture starts its first game")
  guest.submit({"name":"surrender","args":[]})
  check(await until(func():return host.room.status=="between" and guest.room.status=="between"),"BO2 timeout fixture records the first win")
  sync_views();check(await choose_game(),"BO2 timeout fixture starts its second game")
  var engine=host.authority
  for player in engine.players:player.mulligan_done=true
  engine.phase="prepare";engine.pending={};engine.entry_choices=[];engine.combat={};engine.stack=[];engine.active=1;engine.priority=0;engine.passes=0
  host.publish()
  check(await until(func():return host.can_act() and guest.can_act()),"BO2 response deadline reaches both players")
  host.check_response_timeout(float(engine.response_clock.deadline))
  var settled=await until(func():return host.match_settled and guest.match_settled,15)
  check(settled,"BO2 forfeit settles both clients")
  if not settled:finish();return
  var judged=await call_action("detail")
  check(int(judged.pairings[0].result)==1 and int(judged.pairings[0].scores[0])==0 and int(judged.pairings[0].scores[1])==2,"BO2 forfeit awards canonical 0:2 despite earlier win")
  check(int(host.room.scores[0])==1 and int(host.room.scores[1])==0,"forfeit preserves actual game history")
  host.leave(false);guest.leave(false)
 if "--forfeit-only" in args:finish();return
 # Delete a playing competition and verify both live clients receive cancellation.
 if await create_round(1):
  check(await choose_game(),"deletion fixture starts a real game")
  check((await call_action("delete")).get("ok",false),"owner deletes the active competition")
  check(await until(func():return host.match_settled and guest.match_settled,15),"deletion cancels both live game clients")
  host.leave(false);guest.leave(false)
 if await create_round(1,false):
  check((await call_action("delete")).get("ok",false),"owner deletes a competition while one player waits")
  check(await until(func():return not host.matchmaking,15),"deletion also releases a player waiting for the opponent")
 finish()

func finish():
 for session in sessions:
  if is_instance_valid(session):session.leave(false);session.queue_free()
 print("TOURNAMENT GAME FORMATS: ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
