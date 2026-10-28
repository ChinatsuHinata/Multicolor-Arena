extends "res://tests/support/ui_base.gd"
var folder="res://work/tournament-decklist-ui"

class OfflinePage extends "res://scripts/tournament_page.gd":
 var last_request: Dictionary={}
 var entered: Dictionary={}
 func fetch_list(_index: int=0):can_create=false;show_list()
 func send_request(payload: Dictionary):last_request=payload
 func start_game(deck: Dictionary,_pairing: Dictionary,_game_format: int):entered=deck.duplicate(true)

func frames(count: int=10):
 for i in range(count):await process_frame

func fixture() -> Dictionary:
 var pair={"id":1,"table":1,"names":["alice","bob"],"actor":0,"bye":false,"scores":[null,null],"report_scores":[null,null],"result":null,"reports":[null,null],"revision":0,"source":"","match_id":"a".repeat(32),"game_active":false}
 return {"ok":true,"tournament":{"id":1,"title":"赛前牌表测试","description":"截止前可更改牌表。","owned":false,"phase":"running","round_number":1,"round_stage":"swiss","game_format":3,"start_at":2000000000,"pending_matches":1,"stages":[],"joined":true,"checked_in":true,"in_roster":true,"member_count":2,"checkin_count":2,"roster_count":2},"my_pairing":pair,"pairings":[pair],"decklist":{"round_number":1,"game_format":3,"required":true,"fixed_deck":true,"deadline_at":int(Time.get_unix_time_from_system())+600,"can_submit":true,"can_enter":false,"submitted":false,"deck":{}}}

func activate(button: Button,mobile: bool):
 expect(button!=null and not button.disabled,"action is enabled")
 if mobile:
  var event=InputEventScreenTouch.new();event.index=0;event.position=button.get_global_rect().get_center();event.pressed=true
  root.push_input(event,true);await process_frame;event=event.duplicate();event.pressed=false;root.push_input(event,true)
 else:await click(button.get_global_rect().get_center())
 await frames()

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder.path_join(name+".png"))

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var temporary=folder.path_join(str(Time.get_ticks_usec()))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temporary))
 Store.Paths.root_override=ProjectSettings.globalize_path(temporary)
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900)
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate()
 app.settings_path=temporary.path_join("settings.json");app.account_session_path=temporary.path_join("account.json")
 app.tutorial_local_directory=temporary.path_join("tutorials");app.tournament_server_url="ws://127.0.0.1:1"
 root.add_child(app);await frames(30)
 var source=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 var submitted=Store.clean_deck(source[0]);var other=Store.clean_deck(source[1])
 expect(Store.save_file(submitted).is_empty() and Store.save_file(other).is_empty(),"isolated local decks saved")
 for mobile in [false,true]:
  app.is_android=mobile;root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
  app.layout_dpi_override=360 if mobile else 0
  app.layout_safe_override=Rect2(40,12,1200,684) if mobile else Rect2()
  app.refresh_responsive_layout();app.clear_page("tournaments")
  var ui=OfflinePage.new();ui.app=app;app.tournament_ui=ui;app.screen.add_child(ui);await frames()
  var answer=fixture();ui.receive(answer);await frames()
  var prefix="android" if mobile else "desktop"
  expect(ui.find_child("TournamentDetailScroll",true,false).size.y>=app.ui_metrics.hit*1.5,"deck controls leave readable scrolling space on "+prefix)
  expect(ui.find_child("TournamentEnterGame",true,false).disabled,"missing list disables game entry")
  var submit=ui.find_child("TournamentSubmitDeck",true,false)
  expect(app.screen.get_global_rect().grow(2).encloses(submit.get_global_rect()),"submission control fits "+prefix)
  expect(submit.size.y>=app.ui_metrics.hit,"submission touch target meets metrics")
  await shot(prefix+"-pending")
  await activate(submit,mobile)
  expect(app.deck_picker_open(),"submission opens local deck gallery")
  if not app.deck_picker_open():continue
  app.deck_picker_ui.choose(str(submitted.id));await frames()
  for node in app.get_children():
   if node is ConfirmationDialog and node.visible:node.hide();node.confirmed.emit();break
  await frames()
  expect(ui.last_request.get("action","")=="submit_decklist" and ui.last_request.get("round_number",0)==1,"confirmation sends round-bound submission")
  expect(Store.same_cards(ui.last_request.get("deck",submitted),submitted),"submission sends actual deck cards")
  answer.decklist.submitted=true;answer.decklist.deck=submitted
  ui.receive(answer);await frames();await shot(prefix+"-editable")
  expect(ui.find_child("TournamentSubmitDeck",true,false)!=null,"submitted list keeps replacement control before deadline")
  expect(ui.find_child("TournamentEnterGame",true,false).disabled,"submitted list waits for the deadline before entry")
  for replacement in [other,submitted]:
   await activate(ui.find_child("TournamentSubmitDeck",true,false),mobile)
   expect(app.deck_picker_open(),"replacement opens local deck gallery")
   app.deck_picker_ui.choose(str(replacement.id));await frames()
   for node in app.get_children():
    if node is ConfirmationDialog and node.visible:node.hide();node.confirmed.emit();break
   await frames()
   expect(Store.same_cards(ui.last_request.deck,replacement),"replacement submits newly selected composition")
   answer.decklist.deck=replacement;ui.receive(answer);await frames()
  answer.decklist.can_submit=false;answer.decklist.can_enter=true;answer.decklist.closed=true
  ui.receive(answer);await frames();await shot(prefix+"-locked")
  expect(ui.find_child("TournamentSubmitDeck",true,false)==null,"locked round removes replacement action")
  expect(not ui.find_child("TournamentEnterGame",true,false).disabled,"submitted list enables entry")
  await activate(ui.find_child("TournamentEnterGame",true,false),mobile)
  expect(app.deck_picker_open(),"entry opens locked deck gallery")
  if not app.deck_picker_open():continue
  expect(app.deck_picker_ui.entries.all(func(entry):return Store.same_cards(entry.deck,submitted)),"only submitted composition appears")
  app.deck_picker_ui.choose(str(other.id));expect(app.deck_picker_open() and ui.entered.is_empty(),"direct selection cannot bypass gallery filter")
  await shot(prefix+"-picker")
  app.deck_picker_ui.choose(str(submitted.id));await frames()
  expect(Store.same_cards(ui.entered,submitted),"matching deck enters assigned match")
  # Editing the saved list must remove it from the next entry selection.
  var altered=submitted.duplicate(true);altered.side=[other.main[0]]
  expect(Store.save_file(altered).is_empty(),"test edits a local deck without touching server snapshot")
  ui.enter_game(ui.my_pairing);await frames()
  expect(app.deck_picker_ui.entries.all(func(entry):return str(entry.deck.id)!=str(altered.id) and Store.same_cards(entry.deck,submitted)),"edited local card pool is unavailable; identical restored copies remain allowed")
  app.close_deck_picker();ui.restore_submitted_deck();await frames()
  expect(app.decks.any(func(deck):return Store.same_cards(deck,submitted)),"server snapshot restores an independent local copy")
  expect(Store.save_file(submitted).is_empty(),"fixture restored for next layout")
  for node in app.get_children():
   if node is Window and node.visible:node.hide()
  answer.decklist={"round_number":1,"game_format":3,"required":false,"can_enter":true,"can_submit":false,"submitted":false,"deck":{}}
  ui.receive(answer);await frames();await shot(prefix+"-optional")
  expect(ui.find_child("TournamentSubmitDeck",true,false)==null,"optional round has no submission control")
  expect(not ui.find_child("TournamentEnterGame",true,false).disabled,"optional round allows entry without a list")
  await activate(ui.find_child("TournamentEnterGame",true,false),mobile)
  expect(app.deck_picker_open(),"optional round opens deck gallery")
  if not app.deck_picker_open():continue
  expect(app.deck_picker_ui.entries.any(func(entry):return Store.same_cards(entry.deck,other)),"optional round offers other legal decks")
  app.deck_picker_ui.choose(str(other.id));await frames()
  expect(Store.same_cards(ui.entered,other),"optional round enters with selected legal deck")
  answer.tournament.owned=true
  answer.decklist_rules=[{"round_number":1,"fixed_deck":false,"deadline_at":0},{"round_number":2,"fixed_deck":true,"deadline_at":int(Time.get_unix_time_from_system())+1200}]
  ui.receive(answer);ui.show_decklist_rules();await frames()
  expect(not ui.fixed_deck_input.button_pressed and not ui.decklist_deadline_input.editable,"disabled rule needs no deadline")
  await activate(ui.fixed_deck_input,mobile)
  expect(ui.decklist_deadline_input.editable,"fixed-deck switch enables deadline input")
  ui.decklist_deadline_input.text="bad date";ui.last_request={};ui.submit_decklist_rules()
  expect(ui.last_request.is_empty(),"invalid deadline is rejected locally")
  ui.decklist_deadline_input.text=ui.china_time(int(Time.get_unix_time_from_system())+600)
  ui.decklist_deadline_input.text_changed.emit(ui.decklist_deadline_input.text);await frames()
  ui.find_child("TournamentDecklistRulesScroll",true,false).ensure_control_visible(ui.decklist_deadline_input);await frames()
  expect(ui.find_child("TournamentDecklistRulesScroll",true,false).get_global_rect().encloses(ui.decklist_deadline_input.get_global_rect()),"deadline input can scroll fully into view")
  await shot(prefix+"-rules")
  await activate(ui.find_child("TournamentSaveDecklistRules",true,false),mobile)
  expect(ui.last_request.get("action","")=="configure_decklist" and ui.last_request.get("round_number",0)==1 and ui.last_request.get("fixed_deck",false),"organizer saves round-specific fixed-deck rule")
  expect(ui.last_request.get("deadline_at",0)==ui.parse_china_time(ui.decklist_deadline_input.text),"deadline uses Beijing time conversion")
  ui.decklist_round_input.select(1);ui.decklist_round_input.item_selected.emit(1);await frames()
  expect(ui.fixed_deck_input.button_pressed,"next round loads its own rule")
  ui.submit_decklist_rules()
  expect(ui.last_request.round_number==2 and ui.last_request.deadline_at==answer.decklist_rules[1].deadline_at,"editing next round preserves exact deadline seconds")
 app.queue_free();await frames()
 print("TOURNAMENT DECKLIST UI: ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
