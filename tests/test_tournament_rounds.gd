extends "res://tests/support/network_base.gd"
const Client=preload("res://scripts/tournament_client.gd")
var fixture: Dictionary
var endpoint="ws://127.0.0.1:48065"
var competition_id=0
var app
var sessions=[]
var current_user="bigcake"

func api(payload: Dictionary,user: String="bigcake") -> Dictionary:
 var client=Client.new();root.add_child(client);client.server_url=endpoint
 var completion={"answer":{},"done":false}
 client.finished.connect(func(value):completion.answer=value;completion.done=true)
 client.request(payload,fixture.logins[user].token)
 check(await until(func():return completion.done,20),"competition API completes")
 client.queue_free();return completion.answer

func call_action(action: String,user: String="bigcake",extra: Dictionary={}) -> Dictionary:
 var payload={"action":action,"id":competition_id};payload.merge(extra)
 return await api(payload,user)

func idle():
 await process_frame;await process_frame
 check(await until(func():return not app.tournament_ui.busy,20),"competition UI settles")
 for i in range(8):await process_frame

func show_user(user: String):
 current_user=user;app.account_name=user;app.account_nickname=fixture.logins[user].nickname;app.account_token=fixture.logins[user].token
 app.open_tournaments();await idle()
 app.tournament_ui.fetch_detail(competition_id);await idle()

func press_node(name: String):
 var button=app.screen.find_child(name,true,false)
 check(button is Button and not button.disabled,"available competition control: "+name)
 if button is Button and not button.disabled:button.pressed.emit();await idle()

func confirm_dialog():
 for node in app.get_children():
  if node is ConfirmationDialog and node.visible:node.confirmed.emit();await idle();return
 check(false,"competition confirmation dialog exists")

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/tournament-tests/"+name+".png")

func make_session(user: String):
 var session=Session.new();root.add_child(session);session.initialize(fixture.folder.path_join("round-"+user))
 session.cloud_account=user;session.cloud_token=fixture.logins[user].token;session.cloud_nickname=fixture.logins[user].nickname
 sessions.append(session);return session

func user_for_name(value: String) -> String:
 for user in fixture.logins:
  if fixture.logins[user].nickname==value:return user
 return ""

func settings_choices(label: String):
 var choices=["swiss","swiss_top2","swiss_top4","swiss_top8","swiss_top16"]
 for index in range(choices.size()):
  app.tournament_ui.show_settings()
  var ui=app.tournament_ui
  check(ui.format_input.item_count==5,label+" exposes all knockout sizes")
  ui.format_input.select(index)
  await press_node("TournamentSaveSettings")
  check(ui.current.format==choices[index],label+" saves selected schedule: "+choices[index])
  ui.show_settings()
  check(ui.format_input.selected==index,label+" restores the saved knockout size")
 var ui=app.tournament_ui
 var scroll=ui.find_child("TournamentSettingsScroll",true,false)
 for i in range(8):await process_frame
 scroll.ensure_control_visible(ui.format_input)
 for i in range(8):await process_frame
 check(app.screen.get_global_rect().grow(2).encloses(ui.format_input.get_global_rect()),label+" schedule selector fits the screen")
 check(ui.format_input.size.y>=app.ui_metrics.hit,label+" schedule selector has a full touch target")
 await shot(label+"-knockout-settings")
 ui.format_input.select(2)
 await press_node("TournamentSaveSettings")

func round_labels():
 var ui=app.tournament_ui
 var saved=ui.current.duplicate(true)
 var cases=[["swiss_top2",1,"final"],["swiss_top4",2,"semifinal"],["swiss_top8",3,"quarterfinal"],["swiss_top16",4,"round_of_16"]]
 for entry in cases:
  ui.current={"phase":"running","format":entry[0],"total_swiss_rounds":1,"round_number":1,"pending_matches":0,"round_stage":entry[2]}
  check(ui.advance_caption()=="开始下一轮","Swiss completion enters the selected knockout stage")
  check(not ui.round_caption().begins_with(" ·"),"knockout opening stage has a readable caption")
  ui.current.round_number=int(entry[1])+1
  check(ui.advance_caption()=="结束比赛","competition ends after the selected number of knockout rounds")
 ui.current=saved

func run():
 var args=OS.get_cmdline_user_args()
 for i in range(args.size()-1):
  if args[i]=="--fixture":fixture=JSON.parse_string(FileAccess.get_file_as_string(args[i+1]))
 if fixture.is_empty():quit(1);return
 var created=await api({"action":"create","title":"瑞士轮加四强测试","format":"swiss_top4","swiss_rounds":1,"start_at":int(Time.get_unix_time_from_system())+3600})
 check(created.get("ok",false),"owner creates Swiss plus top-four competition")
 competition_id=int(created.tournament.id)
 for user in ["first_player","second_player","third_player","fourth_player"]:
  await call_action("join",user)
 await call_action("configure","bigcake",{"format":"swiss_top4","swiss_rounds":1,"start_at":int(Time.get_unix_time_from_system())+2})
 await create_timer(2.6).timeout
 for user in ["first_player","second_player","third_player","fourth_player"]:
  await call_action("checkin",user)
 await call_action("close_checkin")
 root.size=Vector2i(1600,900)
 app=load("res://main.tscn").instantiate();app.settings_path=fixture.folder.path_join("round-settings.json")
 app.account_session_path=fixture.folder.path_join("round-account.json");app.lan_storage_directory=fixture.folder.path_join("round-lan")
 app.tutorial_local_directory=fixture.folder.path_join("round-tutorials");app.tournament_server_url=endpoint
 root.add_child(app);await process_frame
 await show_user("bigcake")
 await settings_choices("desktop")
 round_labels()
 await press_node("TournamentAdvanceRound");await confirm_dialog()
 var ui=app.tournament_ui
 check(ui.current.round_number==1 and ui.current.round_stage=="swiss" and ui.pairings.size()==2,"manual round starts and exposes all Swiss pairings")
 await shot("desktop-swiss-pairings")
 var first=ui.pairings[0].duplicate(true);var second=ui.pairings[1].duplicate(true)
 var first_user=user_for_name(first.names[0]);var other_user=user_for_name(first.names[1])
 await show_user(first_user);app.tournament_ui.detail_tab="pairings";app.tournament_ui.show_detail()
 await press_node("TournamentReportResult")
 check(app.tournament_ui.mode=="result","player opens the real result form")
 await press_node("TournamentResultSubmit")
 check(app.tournament_ui.my_pairing.result==null and app.tournament_ui.my_pairing.reports[0]==0,"a single player report does not award a win")
 app.is_android=true;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND;root.size=Vector2i(1280,720)
 app.layout_dpi_override=360;app.layout_safe_override=Rect2(40,12,1200,684)
 await show_user("bigcake")
 app.tournament_ui.show_settings()
 check(app.tournament_ui.format_input.selected==2 and app.tournament_ui.format_input.disabled,"Android restores and locks the active four-player knockout schedule")
 var android_settings=app.tournament_ui.find_child("TournamentSettingsScroll",true,false)
 for i in range(8):await process_frame
 android_settings.ensure_control_visible(app.tournament_ui.format_input)
 for i in range(8):await process_frame
 check(app.screen.get_global_rect().grow(2).encloses(app.tournament_ui.format_input.get_global_rect()),"Android knockout selector fits the safe area")
 await shot("android-knockout-settings")
 await show_user(other_user);app.tournament_ui.detail_tab="pairings";app.tournament_ui.show_detail()
 await shot("android-result-confirmation")
 check(app.screen.get_global_rect().grow(2).encloses(app.tournament_ui.heading.get_global_rect()),"competition heading fits the Android safe area")
 await press_node("TournamentConfirmResult");await confirm_dialog()
 check(app.tournament_ui.my_pairing.result==0 and app.tournament_ui.my_pairing.source=="agreement","opponent confirmation records the agreed result")
 # Assigned opponents enter a real BO1 and use the existing room/duel engine.
 var assigned=await call_action("detail",user_for_name(second.names[0]))
 second=assigned.my_pairing
 host=make_session(user_for_name(second.names[0]));guest=make_session(user_for_name(second.names[1]))
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 check(host.start_matchmaking(endpoint,decks[0],true,"casual",str(second.match_id)).is_empty(),"first assigned player enters the competition game")
 check(await until(func():return host.match_queued==1),"first player waits for the assigned opponent")
 var outsider=make_session("bigcake")
 outsider.start_matchmaking(endpoint,decks[0],true,"casual",str(second.match_id))
 check(await until(func():return not outsider.matchmaking),"unassigned account cannot enter another table")
 check(guest.start_matchmaking(endpoint,decks[1],true,"casual",str(second.match_id)).is_empty(),"second assigned player enters the competition game")
 check(await until(func():return host.can_act() and guest.can_act(),15),"competition clients register their decks and synchronize sideboarding")
 if not host.can_act() or not guest.can_act():print(host.notice," / ",guest.notice);finish();return
 check(host.is_host and not guest.is_host and host.cloud_match_id==str(second.match_id),"server preserves pairing order and its persistent match ID")
 host.room_action({"name":"ready"});await until(func():return host.can_act() and guest.can_act())
 guest.room_action({"name":"ready"});await until(func():return host.can_act() and guest.can_act() and host.room.status=="choosing")
 var chooser=host if host.series.state.chooser==0 else guest
 chooser.room_action({"name":"first","first":true})
 check(await until(func():return host.can_act() and guest.can_act() and host.room.status=="playing"),"competition BO1 reaches the battlefield")
 sync_views();check(guest.submit({"name":"surrender","args":[]}).is_empty(),"competition player submits a real surrender")
 check(await until(func():return host.match_settled and guest.match_settled,15),"game result settles through the cloud account service")
 var result=await call_action("detail")
 check(result.pairings[1].result==0 and result.pairings[1].source=="game","finished game automatically fills the competition results")
 await show_user("bigcake")
 await press_node("TournamentAdvanceRound");await confirm_dialog()
 check(app.tournament_ui.current.round_stage=="semifinal" and app.tournament_ui.pairings.size()==2,"Swiss standings generate seeded top-four semifinals")
 app.tournament_ui.detail_tab="manage";app.tournament_ui.show_detail()
 await press_node("TournamentSchedule")
 check(app.tournament_ui.mode=="schedule" and app.tournament_ui.time_input.text.length()==16,"owner schedule form displays Beijing time")
 # Seconds-level scheduling through the API verifies idle server execution.
 var scheduled=await call_action("schedule","bigcake",{"task":"start_round","due_at":int(Time.get_unix_time_from_system())+2,"expected_round":2})
 check(scheduled.ok,"owner persists a timed next-round task")
 await create_timer(2.6).timeout
 var waiting=await call_action("detail")
 check(waiting.schedules[0].status=="waiting" and waiting.tournament.round_number==2,"elapsed timer waits for organizer adjudication")
 await show_user("bigcake");app.tournament_ui.detail_tab="pairings";app.tournament_ui.show_detail()
 var pair=app.tournament_ui.pairings[0]
 await press_node("TournamentJudge_"+str(int(pair.id)))
 check(app.tournament_ui.mode=="judge","owner opens adjudication for the unplayed semifinal")
 await press_node("TournamentResultSubmit");await confirm_dialog()
 var remaining=app.tournament_ui.pairings[1]
 await call_action("judge_result","bigcake",{"pairing_id":int(remaining.id),"result":1,"revision":int(remaining.revision)})
 await create_timer(0.8).timeout
 var final=await call_action("detail")
 check(final.tournament.round_stage=="final" and final.tournament.round_number==3 and final.pairings.size()==1,"server timer starts the final after both organizer rulings")
 await call_action("judge_result","bigcake",{"pairing_id":int(final.pairings[0].id),"result":0,"revision":int(final.pairings[0].revision)})
 await call_action("start_round","bigcake",{"expected_round":3})
 await show_user("bigcake");app.tournament_ui.detail_tab="standings";app.tournament_ui.show_detail()
 check(app.tournament_ui.current.phase=="complete" and app.tournament_ui.standings.any(func(entry):return entry.get("placement",0)==1),"completed competition displays the champion")
 await shot("android-final-standings")
 finish()

func finish():
 for session in sessions:
  if is_instance_valid(session):session.leave(false);session.queue_free()
 if is_instance_valid(app):app.queue_free()
 print("TOURNAMENT ROUNDS: ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
