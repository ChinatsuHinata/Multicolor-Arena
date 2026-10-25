extends "res://tests/support/ui_base.gd"
var folder="res://work/limitless-ui"

class OfflinePage extends "res://scripts/tournament_page.gd":
 var last_request: Dictionary={}
 func fetch_list(_index: int=0):
  can_create=true;show_list()
 func send_request(payload: Dictionary):
  last_request=payload

func frames(count: int=12):
 for i in range(count):await process_frame

func pair(number: int=1) -> Dictionary:
 return {"id":number,"table":number,"names":["alice","bob"],"actor":0,"bye":false,"scores":[null,null],"report_scores":[null,null],"result":null,"reports":[null,null],"revision":0,"source":"limitless","match_id":"TEST_ONLY","game_active":false,"external_match":"T4-1"}

func fixture() -> Dictionary:
 return {"ok":true,"tournament":{"id":1,"title":"Limitless 测试比赛","description":"仅用于布局与交互验证","owned":true,"phase":"running","round_number":2,"round_stage":"swiss","game_format":3,"start_at":2000000000,"pending_matches":1,"stages":[],"joined":true,"checked_in":true,"in_roster":true,"member_count":4,"checkin_count":4,"roster_count":4,"pairing_source":"limitless"},"pairing_round":2,"round_info":{"number":2,"stage":"swiss","stage_index":-1,"stage_round":2},"my_pairing":pair(),"pairings":[pair()],"standings":[],"limitless":{"url":"https://play.limitlesstcg.com/tournament/636bf4efa527ff22cbbd82ae","title":"来源赛事","synced_at":int(Time.get_unix_time_from_system()),"auto_sync":true,"syncing":false,"error":"","mapping":"alice=alice\nbob=bob","external_players":["alice","bob"],"view":"pairings","rounds":[{"phase":1,"round":1},{"phase":1,"round":2}],"phase":1,"round":2,"page":0,"pages":1,"entries":[{"phase":1,"round":2,"table":1,"match":"T4-1","players":["alice","bob"],"names":["Alice","Bob"],"result":"double_loss"}]}}

func shot(caption: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder.path_join(caption+".png"))

func check_scroll(ui,caption: String):
 await frames()
 var scroll=ui.find_child("TournamentDetailScroll",true,false)
 expect(scroll is ScrollContainer,caption+" has a scroll container")
 if not scroll is ScrollContainer:return
 expect(scroll.get_h_scroll_bar().max_value<=scroll.size.x+1,caption+" fits without horizontal scrolling")
 expect(app.screen.get_global_rect().grow(1).encloses(scroll.get_global_rect()),caption+" stays inside screen")
 await shot(caption)

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 folder=folder.path_join(str(Time.get_ticks_usec()))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 Store.Paths.root_override=ProjectSettings.globalize_path(folder)
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900)
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate()
 app.settings_path=folder.path_join("settings.json");app.account_session_path=folder.path_join("account.json");app.tutorial_local_directory=folder.path_join("tutorials")
 app.tournament_server_url="ws://127.0.0.1:1";root.add_child(app);await frames(30)
 app.clear_page("tournaments")
 var ui=OfflinePage.new();ui.app=app;app.tournament_ui=ui;app.screen.add_child(ui);await frames()
 ui.receive(fixture());await frames()
 expect(ui.find_child("TournamentReportResult",true,false)==null,"Limitless results cannot be manually reported")
 expect(ui.find_child("TournamentEnterGame",true,false)!=null,"published opponents can enter the game")
 ui.detail_tab="limitless";ui.show_detail();await check_scroll(ui,"desktop-source-pairings")
 expect(ui.find_child("TournamentLimitlessRound",true,false)!=null,"source rounds can be selected")
 var answer=fixture();answer.limitless.view="standings";answer.limitless.entries=[{"name":"Alice","placing":1,"wins":3,"ties":0,"losses":1,"drop":false}]
 ui.external_view="standings";ui.receive(answer);await check_scroll(ui,"desktop-source-standings")
 ui.detail_tab="pairings";ui.pairing_round=1;ui.receive(fixture());ui.viewed_round=1;ui.show_detail();await frames()
 expect(ui.find_child("TournamentJudge_1",true,false)==null,"historical Limitless pairings cannot be adjudicated")
 var history=ui.find_child("TournamentRoundHistory",true,false)
 history.item_selected.emit(0)
 expect(ui.last_request.pairing_round==0,"history can follow the latest round")
 answer=fixture();answer.my_pairing.source="awaiting_limitless";ui.receive(answer);await frames()
 expect(ui.find_child("TournamentEnterGame",true,false)==null,"completed games wait for source results")
 var automatic_loss=pair();automatic_loss.bye=true;automatic_loss.result=-2
 expect(ui.result_caption(automatic_loss,-2)=="自动判负","source inactivity loss is distinct from a bye win")
 ui.current.phase="locked";ui.current.round_number=0;ui.detail_tab="manage";ui.show_detail();await check_scroll(ui,"desktop-source-management")
 expect(ui.find_child("TournamentLimitlessMapping",true,false)!=null,"organizer can map source usernames to game accounts")
 var mapping=ui.find_child("TournamentLimitlessMapping",true,false);mapping.text="alice=alice"
 ui.find_child("TournamentLimitlessSaveMapping",true,false).pressed.emit()
 expect(ui.last_request.action=="map_limitless" and ui.last_request.mapping=="alice=alice","mapping submission preserves usernames")
 root.size=Vector2i(1280,720);app.is_android=true;app.layout_dpi_override=420;app.layout_safe_override=Rect2(60,12,1160,680);app.refresh_responsive_layout();await frames()
 ui.show_detail();await check_scroll(ui,"android-source-management")
 ui.current.phase="running";ui.current.round_number=2;ui.detail_tab="limitless";ui.external_view="pairings";ui.limitless=fixture().limitless;ui.show_detail();await check_scroll(ui,"android-source-pairings")
 for android in [false,true]:
  app.is_android=android;app.refresh_responsive_layout();await frames()
  ui.can_create=true;ui.show_limitless_create();await frames()
  expect(ui.find_child("TournamentImportSubmit",true,false).disabled,"empty import cannot submit")
  ui.find_child("TournamentImportExample",true,false).pressed.emit()
  ui.find_child("TournamentImportSubmit",true,false).pressed.emit()
  expect(ui.last_request.action=="create_limitless" and ui.last_request.url.ends_with("6aba47b9783097f8dcb72660/details"),"example URL imports through the quick-create action")
  answer=fixture();answer.tournament.joined=false;answer.tournament.owned=false;answer.tournament.in_roster=false;answer.my_pairing={}
  answer.tournament.limitless_admission={"started":true,"can_join":false,"account_id":"","status":"","reason":"请填写 Limitless 账号 ID"}
  ui.detail_tab="group";ui.receive(answer);await frames()
  expect(ui.find_child("TournamentJoin",true,false).disabled,"unbound player cannot click join after source start")
  answer.tournament.limitless_admission={"started":true,"can_join":true,"account_id":"doctorblack","status":"","reason":""}
  ui.receive(answer);await frames()
  ui.find_child("TournamentJoin",true,false).pressed.emit()
  expect(ui.last_request.action=="join","eligible player can submit admission request")
  answer.tournament.limitless_admission.can_join=false;answer.tournament.limitless_admission.status="pending"
  ui.receive(answer);await frames()
  expect(ui.find_child("TournamentJoin",true,false).disabled and ui.find_child("TournamentCheckin",true,false)==null,"pending applicant cannot join again or check in")
  ui.find_child("TournamentWithdrawJoin",true,false).pressed.emit()
  expect(ui.last_request.action=="leave","pending request can be withdrawn")
  answer.tournament.owned=true;answer.join_requests={"entries":[{"player_id":2,"username":"alice","nickname":"游戏玩家","external_player":"doctorblack","revision":3}],"total":1,"page":0,"pages":1}
  ui.receive(answer);ui.detail_tab="manage";ui.show_detail();await check_scroll(ui,"admission-management-"+str(android))
  expect(ui.find_child("TournamentApprove_2",true,false)!=null,"organizer has identity approval action")
  ui.find_child("TournamentReject_2",true,false).pressed.emit()
  expect(ui.last_request.action=="review_limitless_join" and ui.last_request.revision==3 and not ui.last_request.approve,"rejection includes the current application revision")
 app.queue_free();await frames()
 print("LIMITLESS UI: ",checks," checks; ",failures.size()," failures; snapshots: ",folder)
 quit(0 if failures.is_empty() else 1)
