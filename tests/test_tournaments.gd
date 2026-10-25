extends "res://tests/support/ui_base.gd"
const Client=preload("res://scripts/tournament_client.gd")
const PlazaClient=preload("res://scripts/deck_plaza_client.gd")
const AccountClient=preload("res://scripts/account_client.gd")
var fixture: Dictionary
var server="ws://127.0.0.1:48065"
var tournament_id=0
var answer: Dictionary={}
var received=false
var snapshots="res://work/tournament-tests"

func frames(count: int=8):
 for i in range(count):await process_frame

func wait_page():
 await frames()
 var deadline=Time.get_ticks_msec()+20000
 while is_instance_valid(app.tournament_ui) and app.tournament_ui.busy and Time.get_ticks_msec()<deadline:await process_frame
 await frames()
 expect(app.page=="account" or (is_instance_valid(app.tournament_ui) and not app.tournament_ui.busy),"competition request completes")

func api(payload: Dictionary,user: String,plaza: bool=false) -> Dictionary:
 var client=PlazaClient.new() if plaza else Client.new();root.add_child(client);client.server_url=server;received=false;answer={}
 client.finished.connect(func(value):answer=value;received=true)
 client.request(payload,fixture.logins[user].token)
 var deadline=Time.get_ticks_msec()+20000
 while not received and Time.get_ticks_msec()<deadline:await process_frame
 client.queue_free();await frames()
 expect(received,"encrypted competition API replies")
 return answer

func login_as(user: String):
 app.account_name=user;app.account_nickname=fixture.logins[user].nickname;app.account_token=fixture.logins[user].token
 app.open_tournaments();await wait_page()

func press_node(name: String):
 var button=app.screen.find_child(name,true,false)
 expect(button is Button and not button.disabled,"available action: "+name)
 if button is Button and not button.disabled:button.pressed.emit();await wait_page()

func geometry(label: String):
 var area=app.screen.get_global_rect().grow(2)
 for name in ["TournamentBack","TournamentRefresh","TournamentJoin","TournamentCheckin","TournamentOpenCheckin","TournamentCloseCheckin"]:
  var button=app.screen.find_child(name,true,false)
  if button is Button and button.is_visible_in_tree():
   expect(area.encloses(button.get_global_rect()),label+" button fits: "+name)
   if app.is_android:expect(button.size.y>=app.ui_metrics.hit,label+" touch target: "+name)

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(snapshots.path_join(name+".png"))

func run():
 var args=OS.get_cmdline_user_args()
 for i in range(args.size()-1):
  if args[i]=="--fixture":fixture=JSON.parse_string(FileAccess.get_file_as_string(args[i+1]))
 if fixture.is_empty():push_error("Run through tests/run_tournaments.py");quit(1);return
 root.size=Vector2i(1600,900)
 app=load("res://main.tscn").instantiate()
 app.settings_path=fixture.folder.path_join("settings.json");app.account_session_path=fixture.folder.path_join("account.json")
 app.tutorial_local_directory=fixture.folder.path_join("tutorials");app.tournament_server_url=server
 app.lan_storage_directory=fixture.folder.path_join("lan")
 root.add_child(app);await frames(25)
 expect(app.tournament_button.get_global_rect().position.x>root.size.x*0.8,"trophy opens from the upper-right corner")
 expect(not app.tournament_button.get_global_rect().intersects(app.mailbox_button.get_global_rect()),"trophy and mailbox do not overlap")
 await shot("desktop-menu")
 app.tournament_button.pressed.emit();await frames()
 expect(app.page=="account" and app.tournament_account_return,"logged-out competition entry opens login")
 app.return_from_account();await frames()
 expect(app.page=="menu" and not app.tournament_account_return,"cancel login returns to the main menu")
 app.tournament_button.pressed.emit();await frames()
 app.account_client=AccountClient.new();app.add_child(app.account_client)
 app.account_client.session_token=fixture.logins.bigcake.token
 app.account_client.nickname=fixture.logins.bigcake.nickname
 app.account_client.remember_token="f".repeat(64)
 app.account_action="login";app.account_request_finished(true,"测试登录成功","bigcake")
 await wait_page()
 expect(app.page=="tournaments" and not app.tournament_account_return,"successful login returns to the competition page")
 expect(app.tournament_ui.can_create and app.tournament_ui.create_button.visible,"server enables creation for bigcake")
 expect(app.tournament_ui.tournaments.is_empty(),"no competitions are seeded")
 await press_node("TournamentCreate")
 var ui=app.tournament_ui
 expect(ui.submit_button.disabled,"empty competition name cannot be submitted")
 ui.title_input.text="群组与签到测试";ui.title_input.text_changed.emit(ui.title_input.text)
 ui.description_input.text="请在主办方开启签到后完成赛前签到。"
 expect(ui.game_format_input.item_count==7,"creation exposes all game formats including BO5 and BO2")
 expect(ui.format_input.item_count==5,"creation offers Swiss and 2/4/8/16-player knockout cuts")
 for index in range(5):
  ui.format_input.select(index)
  expect(ui.settings_payload().format==["swiss","swiss_top2","swiss_top4","swiss_top8","swiss_top16"][index],"creation submits the selected knockout size")
 ui.format_input.select(0)
 ui.game_format_input.select(ui.game_format_input.get_item_index(3))
 ui.start_time_input.text=""
 await press_node("TournamentSubmit")
 expect(app.tournament_ui.mode=="create","creation requires a specific competition time")
 ui.start_time_input.text=ui.china_time(int(Time.get_unix_time_from_system())+3600)
 await shot("desktop-create-settings")
 expect(not ui.submit_button.disabled,"valid competition name enables creation")
 await press_node("TournamentSubmit")
 tournament_id=int(app.tournament_ui.current.id)
 expect(app.tournament_ui.mode=="detail" and app.tournament_ui.current.owned,"owner-created competition opens its group")
 expect(app.tournament_ui.current.phase=="registration","group creation starts without check-in")
 expect(int(app.tournament_ui.current.game_format)==3,"selected BO3 format persists")
 await press_node("TournamentTab_manage")
 await press_node("TournamentEditDescription")
 await shot("desktop-edit-description")
 app.tournament_ui.description_input.text="BO3 比赛规则\n比赛时间到达后请签到。"
 await press_node("TournamentSaveDescription")
 await press_node("TournamentTab_group")
 expect(app.tournament_ui.current.description.begins_with("BO3"),"owner edits the saved competition description")
 geometry("desktop owner");await shot("desktop-owner-group")
 await login_as("first_player")
 expect(not app.tournament_ui.can_create and not app.tournament_ui.create_button.visible,"players have no create action")
 var denied=await api({"action":"create","title":"伪造主办方","username":"bigcake"},"first_player")
 expect(not denied.get("ok",false),"server denies forged player creation")
 await press_node("TournamentEntry_"+str(tournament_id))
 expect(not app.tournament_ui.current.joined,"viewing competition details does not join")
 expect(app.screen.find_child("TournamentDescriptionDisplay",true,false).text.begins_with("BO3"),"player reads the edited description before joining")
 expect(app.screen.find_child("TournamentGameFormatDisplay",true,false).text.contains("BO3"),"player sees the selected game format")
 expect(app.screen.find_child("TournamentEditDescription",true,false)==null and app.screen.find_child("TournamentDelete",true,false)==null,"player has no administration controls")
 await press_node("TournamentDeclineJoin")
 expect(app.tournament_ui.mode=="list","player can decline joining and return to list")
 await press_node("TournamentEntry_"+str(tournament_id))
 await press_node("TournamentJoin")
 expect(app.tournament_ui.current.joined and not app.tournament_ui.current.checked_in,"joining a group does not check in")
 expect(app.screen.find_child("TournamentCheckin",true,false)==null,"check-in unavailable until opened")
 var second=await api({"action":"join","id":tournament_id},"second_player")
 expect(second.get("ok",false),"second player joins the same shared group")
 await login_as("bigcake");await press_node("TournamentEntry_"+str(tournament_id))
 var rescheduled=await api({"action":"configure","id":tournament_id,"start_at":int(Time.get_unix_time_from_system())+2},"bigcake")
 expect(rescheduled.get("ok",false),"owner sets the upcoming registration deadline")
 await create_timer(2.6).timeout
 app.tournament_ui.refresh();await wait_page()
 expect(app.tournament_ui.current.phase=="checkin","owner opens pre-match check-in")
 await press_node("TournamentTab_manage");await press_node("TournamentSettings")
 expect(not app.tournament_ui.start_time_input.editable,"competition time locks after the deadline")
 await press_node("TournamentSaveSettings")
 expect(app.tournament_ui.mode=="detail","owner can save unchanged time after the deadline")
 var late=await api({"action":"join","id":tournament_id},"third_player")
 expect(not late.get("ok",false),"late arrivals cannot join after the competition time")
 # The Android instance uses the same account and server-backed membership.
 app.is_android=true;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND;root.size=Vector2i(1280,720)
 app.layout_dpi_override=360;app.layout_safe_override=Rect2(40,12,1200,684)
 await login_as("first_player");await press_node("TournamentEntry_"+str(tournament_id))
 geometry("Android check-in");await shot("android-checkin")
 var checkin=app.screen.find_child("TournamentCheckin",true,false)
 if checkin is Button:
  var touch=InputEventScreenTouch.new();touch.index=0;touch.position=checkin.get_global_rect().get_center();touch.pressed=true
  root.push_input(touch,true);await process_frame
  touch=touch.duplicate();touch.pressed=false;root.push_input(touch,true);await wait_page()
 expect(app.tournament_ui.current.checked_in and not app.tournament_ui.current.in_roster,"Android touch records check-in before roster finalization")
 var same=app.tournament_ui
 app.layout_dpi_override=420;app.layout_safe_override=Rect2(60,12,1160,680);app.refresh_responsive_layout();await frames(12)
 expect(app.tournament_ui==same and app.tournament_ui.current.checked_in,"safe-area resize retains group and check-in")
 geometry("dense Android");await shot("android-checked-in")
 await login_as("bigcake");await press_node("TournamentEntry_"+str(tournament_id))
 await press_node("TournamentCloseCheckin")
 var dialog
 for node in app.get_children():
  if node is ConfirmationDialog and node.visible:dialog=node
 expect(dialog!=null,"roster finalization requires owner confirmation")
 if dialog!=null:dialog.confirmed.emit();await wait_page()
 expect(app.tournament_ui.current.phase=="locked" and app.tournament_ui.current.roster_count==1,"only the checked-in player enters the roster")
 await press_node("TournamentRosterToggle")
 expect(app.tournament_ui.roster_only and app.tournament_ui.members.size()==1,"roster view excludes un-checked members")
 await shot("android-roster")
 await login_as("second_player");await press_node("TournamentEntry_"+str(tournament_id))
 expect(not app.tournament_ui.current.in_roster and app.tournament_ui.current.joined,"un-checked player remains a group member")
 expect(app.screen.find_child("TournamentCheckin",true,false)==null,"closed check-in has no late sign-in action")
 app.android_system_back();await wait_page()
 expect(app.tournament_ui.mode=="list","Android back returns from group to list")
 app.android_system_back();await frames()
 expect(app.page=="menu","Android back returns from list to menu")
 expect(app.ui_metrics.safe.grow(2).encloses(app.tournament_button.get_global_rect()),"Android trophy fits the safe area")
 await shot("android-menu")
 var invalid=await api({"action":"list"},"first_player")
 expect(invalid.get("ok",false),"session remains valid through competition operations")
 var decks=await api({"action":"list"},"first_player",true)
 expect(decks.get("ok",false) and decks.has("decks") and not decks.has("tournaments"),"shared transport keeps the existing deck plaza protocol separate")
 await login_as("bigcake");await press_node("TournamentEntry_"+str(tournament_id))
 await press_node("TournamentTab_manage");await press_node("TournamentDelete")
 var deletion_dialog
 for node in app.get_children():
  if node is ConfirmationDialog and node.visible:deletion_dialog=node
 expect(deletion_dialog!=null,"deleting a competition requires confirmation")
 if deletion_dialog!=null:deletion_dialog.confirmed.emit();await wait_page()
 expect(app.tournament_ui.mode=="list" and app.tournament_ui.tournaments.is_empty(),"confirmed deletion returns to the refreshed list")
 var vanished=await api({"action":"detail","id":tournament_id},"first_player")
 expect(vanished.get("tournament_missing",false),"deleted competition is unavailable to stale players")
 await login_as("first_player")
 app.tournament_ui.fetch_detail(tournament_id);await wait_page()
 expect(app.tournament_ui.mode=="list","stale competition detail returns to the list")
 app.account_token="invalid-session";app.open_tournaments();await wait_page()
 expect(app.page=="account" and app.tournament_account_return,"expired session returns to competition login flow")
 app.queue_free();await frames()
 print("TOURNAMENTS: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
