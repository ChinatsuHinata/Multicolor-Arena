extends "res://tests/support/ui_base.gd"
const Client=preload("res://scripts/tournament_client.gd")
const Unread=preload("res://scripts/tournament_unread.gd")
var fixture: Dictionary={}
var endpoint="ws://127.0.0.1:48065"
var ids: Array=[]

func frames(count: int=8):
 for i in range(count):await process_frame

func api(payload: Dictionary) -> Dictionary:
 var client=Client.new();client.server_url=endpoint;root.add_child(client)
 var response: Dictionary={}
 client.finished.connect(func(answer):response.merge(answer))
 client.request(payload,fixture.logins.bigcake.token)
 var deadline=Time.get_ticks_msec()+20000
 while response.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
 client.queue_free();await frames()
 expect(response.get("ok",false),"isolated competition service accepts "+str(payload.action))
 return response

func wait_poll(store):
 var deadline=Time.get_ticks_msec()+20000
 while is_instance_valid(store.client) and Time.get_ticks_msec()<deadline:await process_frame
 await frames()
 expect(not is_instance_valid(store.client),"unread list request completes")

func poll():
 app.check_tournament_unread();await wait_poll(app.tournament_unread)

func wait_page():
 await frames()
 var deadline=Time.get_ticks_msec()+20000
 while is_instance_valid(app.tournament_ui) and app.tournament_ui.busy and Time.get_ticks_msec()<deadline:await process_frame
 await frames()
 expect(is_instance_valid(app.tournament_ui) and not app.tournament_ui.busy,"competition page request completes")

func login_as(username: String):
 app.account_name=username;app.account_token=fixture.logins[username].token
 app.account_nickname=fixture.logins[username].nickname
 app.menu();await poll()

func shot(caption: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/tournament-tests/"+caption+".png")

func tap(at: Vector2):
 var touch=InputEventScreenTouch.new();touch.index=0;touch.position=at;touch.pressed=true
 root.push_input(touch,true);await process_frame
 touch=touch.duplicate();touch.pressed=false;root.push_input(touch,true);await frames()

func run():
 var args=OS.get_cmdline_user_args()
 for i in range(args.size()-1):
  if args[i]=="--fixture":fixture=JSON.parse_string(FileAccess.get_file_as_string(args[i+1]))
 if fixture.is_empty():push_error("Run through tests/run_tournaments.py --unread-only");quit(1);return
 root.size=Vector2i(1600,900)
 app=load("res://main.tscn").instantiate()
 app.settings_path=fixture.folder.path_join("unread-settings.json")
 app.account_session_path=fixture.folder.path_join("unread-account.json")
 app.tutorial_local_directory=fixture.folder.path_join("unread-tutorials")
 app.tournament_server_url=endpoint
 root.add_child(app);await frames(25)
 expect(app.tournament_button.unread==0 and not is_instance_valid(app.tournament_unread.client),"logged-out menu has no badge or background request")
 await login_as("first_player")
 expect(app.tournament_button.unread==0,"empty competition list has no unread badge")
 for i in range(7):
  var answer=await api({"action":"create","title":"未读比赛 "+str(i),"start_at":int(Time.get_unix_time_from_system())+3600})
  if answer.has("tournament"):ids.append(int(answer.tournament.id))
 await poll()
 expect(app.tournament_button.unread==7,"new competitions across all list pages light the trophy badge")
 expect(app.tournament_button.tooltip_text.contains("7 场未读"),"trophy tooltip exposes the unread count")
 await shot("desktop-tournament-unread")
 await click(app.tournament_button.get_global_rect().get_center());await wait_page()
 expect(app.tournament_unread.unread_count()==7,"opening the list leaves unseen details unread")
 app.tournament_ui.fetch_detail(int(ids[-1]));await wait_page()
 expect(app.tournament_unread.unread_count()==6,"successful detail view reads only that competition")
 app.menu();await poll()
 expect(app.tournament_button.unread==6,"menu rebuild keeps other competitions unread")
 var restarted=Unread.new();root.add_child(restarted)
 restarted.initialize(app.tournament_unread.path)
 restarted.set_session("FIRST_PLAYER",fixture.logins.first_player.token,endpoint)
 restarted.refresh();await wait_poll(restarted)
 expect(restarted.unread_count()==6,"restart and account casing preserve the saved read receipt")
 restarted.queue_free();await frames()
 # A failed authenticated poll must retain the last complete list and its read state.
 app.account_token="invalid-test-session";await poll()
 expect(app.tournament_button.unread==6,"authentication failure does not clear unread competitions")
 app.account_token=fixture.logins.first_player.token
 await login_as("second_player")
 expect(app.tournament_button.unread==7,"another account has independent read receipts")
 await login_as("first_player")
 expect(app.tournament_button.unread==6,"switching back restores this account's read status")
 # An in-flight response for the previous account is cancelled on logout.
 app.tournament_unread.refresh()
 app.account_name="";app.account_token="";app.check_tournament_unread();await frames(20)
 expect(app.tournament_button.unread==0 and not is_instance_valid(app.tournament_unread.client),"logout cancels pending requests and clears the badge")
 await login_as("first_player")
 app.is_android=true;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND;root.size=Vector2i(1280,720)
 app.layout_dpi_override=360;app.layout_safe_override=Rect2(40,12,1200,684)
 app.menu();await poll()
 expect(app.tournament_button.unread==6 and app.ui_metrics.safe.grow(2).encloses(app.tournament_button.get_global_rect()),"Android unread trophy stays within the safe area")
 await shot("android-tournament-unread")
 await tap(app.tournament_button.get_global_rect().get_center());await wait_page()
 expect(app.page=="tournaments","native Android tap opens the unread trophy")
 app.tournament_ui.fetch_detail(int(ids[0]));await wait_page()
 expect(app.tournament_unread.unread_count()==5,"Android detail view records an unread competition from the next list page")
 for i in range(1,6):
  app.tournament_ui.fetch_detail(int(ids[i]));await wait_page()
 app.menu();await poll()
 expect(app.tournament_button.unread==0 and app.tournament_button.tooltip_text=="比赛","reading every competition clears the badge and tooltip count")
 await shot("android-tournament-read")
 var new_match=await api({"action":"create","title":"新的未读比赛","start_at":int(Time.get_unix_time_from_system())+3600})
 app.get_node("TournamentUnreadTimer").timeout.emit();await wait_poll(app.tournament_unread)
 expect(app.tournament_button.unread==1,"periodic menu refresh detects a newly created competition")
 await api({"action":"delete","id":int(new_match.tournament.id)})
 await poll()
 expect(app.tournament_button.unread==0,"deleted unread competitions stop contributing to the badge")
 for id in ids:await api({"action":"delete","id":id})
 print("Tournament unread checks: ",checks,"; failures: ",failures.size())
 app.queue_free();await frames();quit(1 if not failures.is_empty() else 0)
