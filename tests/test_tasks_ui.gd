extends "res://tests/support/ui_base.gd"
const TaskPopup=preload("res://scripts/task_popup.gd")
var fixture: Dictionary={}
var endpoint="ws://127.0.0.1:48071"

func frames(count: int=8):
 for i in range(count):await process_frame

func wait_sync(expect_ok: bool=true):
 var deadline=Time.get_ticks_msec()+20000
 while is_instance_valid(app.task_service.client) and Time.get_ticks_msec()<deadline:await process_frame
 await frames()
 expect(not is_instance_valid(app.task_service.client),"task snapshot request completes")
 expect(app.task_service.error.is_empty()==expect_ok,"encrypted task request has expected result on real loopback relay")

func shot(caption: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/task-tests/"+caption+".png")

func verify_wallet():
 var rank=app.screen.find_child("PlayerRank",true,false)
 var row=app.task_balance.get_parent()
 var icon=row.get_node_or_null("CoinIcon")
 expect(icon!=null and icon.size.x>0 and icon.size.y>0,"wallet includes a visible coin icon")
 var rect=row.get_global_rect()
 var rank_rect=rank.get_global_rect()
 var caption=rank.find_child("RankCaption",false,false)
 var text_width=caption.get_theme_font("font").get_string_size(caption.text,HORIZONTAL_ALIGNMENT_LEFT,-1,caption.get_theme_font_size("font_size")).x
 expect(absf(rect.position.x-caption.global_position.x-text_width-app.ui_metrics.gap*0.25)<1.0,"wallet follows the rank caption")
 expect(absf(rect.get_center().y-rank_rect.get_center().y)<1.0,"wallet is vertically centered beside the rank")
 for entry in [app.task_button,app.mailbox_button,app.tournament_button]:
  expect(not rect.intersects(entry.get_global_rect()),"wallet avoids toolbar entry "+entry.name)

func verify_popup():
 var popup=app.menu_popup
 expect(popup is TaskPopup,"exclamation mark opens task popup")
 expect(popup.tabs.size()==3,"task popup offers three switchable categories")
 for slot in range(3):expect(popup.find_child("DailyTask"+str(slot),true,false)!=null,"daily tab shows server task slot "+str(slot))
 expect(popup.balance.text=="0","completion leaves copper pending until claimed")
 var wallet_icon=popup.balance.get_parent().get_node_or_null("CoinIcon")
 expect(wallet_icon!=null and wallet_icon.size.x>0 and wallet_icon.size.y>0,"task balance uses a visible copper icon beside the amount")
 for slot in range(3):
  var reward=popup.find_child("DailyTask"+str(slot),true,false).find_child("TaskReward",true,false)
  expect(reward!=null and reward.get_node("CoinIcon").size.x>0,"daily task reward uses copper icon "+str(slot))
 expect(popup.find_child("DailyTask0",true,false).find_child("TaskProgress",true,false).text.contains("累计 40 / 40"),"cumulative task displays actual completed quantity")
 expect(popup.find_child("DailyTask2",true,false).find_child("TaskProgress",true,false).text.contains("单场最高 31 / 32"),"one-match task displays current maximum")
 await click(popup.tabs[1].get_global_rect().get_center());await frames()
 expect(popup.selected==1 and popup.find_child("DailyTask0",true,false)==null,"season tab replaces daily content")
 for amount in [30,40,60,80]:expect(popup.find_child("SeasonReward"+str(amount),true,false)!=null,"season reward tier: "+str(amount))
 var end=popup.find_child("SeasonEndTime",true,false)
 expect(end!=null and end.text.contains("2026-12-01 00:00:00"),"season deadline displays Beijing midnight")
 await shot("season-desktop")
 await click(popup.tabs[2].get_global_rect().get_center());await frames()
 expect(popup.selected==2 and popup.find_child("EmptyAchievements",true,false)!=null,"achievement tab stays empty")
 expect(popup.find_child("SeasonReward80",true,false)==null,"switching to achievements removes season rows")
 await click(popup.tabs[0].get_global_rect().get_center());await frames()
 expect(popup.selected==0 and popup.find_child("DailyTask0",true,false)!=null,"daily tab can be selected again")

func verify_mutations():
 var popup=app.menu_popup
 var original=app.task_service.snapshot.daily.tasks[0].duplicate(true)
 expect(app.task_button.has_reward,"completed unclaimed task lights the menu red dot")
 var claim=popup.find_child("ClaimTask0",true,false)
 expect(claim!=null and not claim.disabled,"completed task offers manual claim")
 expect(claim.icon!=null and not claim.text.contains("铜钱"),"claim button replaces currency words with the shared coin icon")
 await click(claim.get_global_rect().get_center());await wait_sync()
 expect(popup.balance.text=="1" and app.task_balance.text=="铜钱：1","claim updates panel and menu balance from server")
 expect(not app.task_button.has_reward and popup.find_child("ClaimTask0",true,false)==null,"claim clears red dot and claim button")
 expect(popup.find_child("RerollTask0",true,false).disabled,"claimed task cannot be rerolled")
 app.task_service.claim(original);await wait_sync()
 expect(app.task_balance.text=="铜钱：1","repeat claim cannot double the copper reward")
 var old=app.task_service.snapshot.daily.tasks[1].duplicate(true)
 await click(popup.find_child("RerollTask1",true,false).get_global_rect().get_center());await wait_sync()
 var replacement=app.task_service.snapshot.daily.tasks[1]
 expect(replacement.id!=old.id and replacement.group!=old.group,"refresh draws a different outer task group")
 expect(replacement.rerolled and replacement.progress==0,"replacement starts at zero and consumes one refresh")
 expect(popup.find_child("RerollTask1",true,false).disabled,"single task refresh becomes disabled after use")
 app.task_service.reroll(old);await wait_sync()
 expect(app.task_service.snapshot.daily.tasks[1].id==replacement.id,"retrying a refresh returns the same replacement without drawing again")
 app.task_service.reroll(replacement);await wait_sync(false)
 expect(app.task_service.snapshot.daily.tasks[1].id==replacement.id,"second refresh is refused and returns authoritative current tasks")
 app.refresh_tasks();await wait_sync()
 app.task_service.rollover_at_ms=Time.get_ticks_msec()-1
 expect(app.task_service.daily_expired() and not app.task_service.has_claimable(),"server-relative deadline expires tasks without device wall clock")
 await frames(2);await wait_sync()
 expect(not app.task_service.daily_expired(),"daily deadline triggers automatic synchronization")

func click_card_name(label: RichTextLabel,full_name: String):
 var text=label.get_parsed_text()
 var index=text.find(full_name)
 expect(index>=0,"task text includes full card name "+full_name)
 if index<0:return
 var line=label.get_character_line(index)
 var start=index
 while start>0 and label.get_character_line(start-1)==line:start-=1
 var font=label.get_theme_font("normal_font")
 var font_size=label.get_theme_font_size("normal_font_size")
 var x=font.get_string_size(text.substr(start,index-start),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
 x+=font.get_string_size(text.substr(index,1),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*0.5
 await click(label.global_position+Vector2(x,label.get_line_offset(line)+label.get_line_height(line)*0.5))

func verify_card_links():
 app.account_name="TEST_ONLY_cards";app.account_token=fixture.logins.TEST_ONLY_cards
 app.refresh_tasks();await wait_sync();app.open_tasks();await wait_sync()
 var popup=app.menu_popup
 var tasks=app.task_service.snapshot.daily.tasks
 var detail=popup.find_child("DailyTask0",true,false).find_child("TaskDetail",true,false)
 expect(detail is RichTextLabel and tasks[0].card_refs.size()==3,"counter task receives three real card-name hyperlinks")
 expect(tasks[0].card_refs.any(func(ref):return ref.id=="spell-fdn-069" and ref.name==Store.CARDS[ref.id].name),"blue flower links to the correct two-blue spell with its canonical full name")
 expect(popup.find_child("DailyTask1",true,false).find_child("TaskTitle",true,false) is Label,"ordinary task words stay plain text")
 for ref in tasks[0].card_refs:
  popup.scroll.ensure_control_visible(detail);await frames()
  var saved_scroll=popup.scroll.scroll_vertical
  await click_card_name(detail,ref.name);await frames()
  expect(popup.inspected_card==ref.id and is_instance_valid(popup.card_overlay),"clicking full card name opens matching card "+ref.id)
  if not is_instance_valid(popup.card_overlay):continue
  var rules=popup.card_overlay.find_child("CardInspectionRules",true,false)
  expect(rules!=null and rules.get_parsed_text()==app.card_description(ref.id),"card hyperlink shows shared complete card rules")
  await click(popup.card_overlay.find_child("CloseTaskCardDetails",true,false).get_global_rect().get_center());await frames()
  expect(app.menu_popup==popup and popup.selected==0 and popup.scroll.scroll_vertical==saved_scroll,"return from card details preserves task page and scroll")
 var title=popup.find_child("DailyTask2",true,false).find_child("TaskTitle",true,false)
 var spell=tasks[2].card_refs.filter(func(ref):return ref.id=="121")[0]
 popup.scroll.ensure_control_visible(title);await frames()
 await click_card_name(title,spell.name);await frames()
 expect(popup.inspected_card=="121","advanced signature task card name opens the world card")
 await shot("task-card-detail-desktop")
 var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
 root.push_input(escape,true);await frames()
 expect(not is_instance_valid(popup.card_overlay) and app.menu_popup==popup,"Escape closes card details while keeping task panel")
 popup.scroll.scroll_vertical=0;await frames();await shot("task-card-links-desktop")
 app.close_menu_popup()
 app.account_name="TEST_ONLY_tasks";app.account_token=fixture.logins.TEST_ONLY_tasks
 app.refresh_tasks();await wait_sync()

func verify_coin_victory_link():
 app.account_name="TEST_ONLY_coin";app.account_token=fixture.logins.TEST_ONLY_coin
 app.refresh_tasks();await wait_sync();app.open_tasks();await wait_sync()
 var popup=app.menu_popup
 var title=popup.find_child("DailyTask2",true,false).find_child("TaskTitle",true,false)
 expect(title is RichTextLabel and title.get_parsed_text().contains("投钱胜利") and title.get_parsed_text().contains("玩家任选一"),"special victory offers all player choices with a clickable 投钱")
 var card=Store.CARDS["character-kmo-001"]
 var cost=0
 for amount in card.cost.values():cost+=int(amount)
 expect(card.kind=="自机" and cost==5,"coin victory target is the five-cost Komachi leader")
 popup.scroll.ensure_control_visible(title);await frames()
 await click_card_name(title,"投钱");await frames()
 expect(popup.inspected_card=="character-kmo-001","clicking 投钱 opens the five-cost Komachi leader instead of the coin spell")
 await shot("task-komachi-detail-"+("android" if app.is_android else "desktop"))
 await click(popup.card_overlay.find_child("CloseTaskCardDetails",true,false).get_global_rect().get_center());await frames()
 expect(app.menu_popup==popup and popup.inspected_card.is_empty(),"Komachi details return to the original task panel")
 await shot("task-coin-icons-"+("android" if app.is_android else "desktop"))
 app.close_menu_popup()
 app.account_name="TEST_ONLY_tasks";app.account_token=fixture.logins.TEST_ONLY_tasks
 app.refresh_tasks();await wait_sync()

func run():
 var args=OS.get_cmdline_user_args()
 for i in range(args.size()-1):
  if args[i]=="--fixture":fixture=JSON.parse_string(FileAccess.get_file_as_string(args[i+1]))
 if fixture.is_empty():push_error("Run through tests/run_tasks.py");quit(1);return
 Store.Paths.root_override=fixture.folder.path_join("portable")
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900)
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate()
 app.settings_path=fixture.folder.path_join("settings.json");app.account_session_path=fixture.folder.path_join("account.json")
 app.tutorial_local_directory=fixture.folder.path_join("tutorials")
 app.task_server_url=endpoint;app.tournament_server_url=endpoint
 root.add_child(app);await frames(25)
 expect(not is_instance_valid(app.task_service.client) and app.task_balance.text=="铜钱：—","logged-out menu does not invent a wallet or send requests")
 verify_wallet()
 await click(app.task_button.get_global_rect().get_center());await frames()
 expect(find_button(app.menu_popup.backdrop,"登录账号")!=null,"logged-out tasks offer account login")
 app.close_menu_popup()
 app.account_name="TEST_ONLY_tasks";app.account_token=fixture.logins.TEST_ONLY_tasks
 app.account_nickname="任务测试";app.menu();await frames();await wait_sync()
 expect(app.task_balance.text=="铜钱：0" and app.task_button.has_reward,"menu shows unclaimed completion without auto-paying copper")
 verify_wallet()
 expect(app.task_button.get_global_rect().position.x>app.screen.size.x*0.5,"task exclamation mark is in the top-right corner")
 for other in [app.mailbox_button,app.tournament_button,app.task_balance]:expect(not app.task_button.get_global_rect().intersects(other.get_global_rect()),"task entry has no toolbar overlap with "+other.name)
 await shot("menu-desktop")
 await click(app.task_button.get_global_rect().get_center());await frames();await wait_sync()
 await verify_popup();await shot("daily-desktop")
 await verify_mutations();await shot("daily-claimed-desktop")
 # Rebuild preserves an open task panel and its selected tab.
 app.menu_popup.select_tab(2);var retained=app.menu_popup;app.menu();await frames()
 expect(app.menu_popup==retained and app.menu_popup.selected==2,"menu rebuild preserves open task category")
 app.close_menu_popup()
 # Simulate CE changing only memory: the next authoritative fetch restores it.
 app.task_service.snapshot.coins=999999;app.refresh_task_balance()
 expect(app.task_balance.text=="铜钱：999999","fixture changes local display memory")
 app.refresh_tasks();await wait_sync()
 expect(app.task_balance.text=="铜钱：1","refresh replaces forged local copper with server balance")
 # Another account cannot see or inherit the previous player's money.
 app.account_name="TEST_ONLY_opponent";app.account_token=fixture.logins.TEST_ONLY_opponent;app.sync_tasks()
 expect(app.task_service.snapshot.is_empty() and app.task_balance.text=="铜钱：—","account switch immediately clears cached copper")
 app.refresh_tasks();await wait_sync();expect(app.task_balance.text=="铜钱：0","other account has its own server wallet")
 app.account_name="TEST_ONLY_tasks";app.account_token=fixture.logins.TEST_ONLY_tasks;app.refresh_tasks();await wait_sync()
 await verify_card_links()
 await verify_coin_victory_link()
 app.is_android=true;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 for case in [{"size":Vector2i(1280,720),"dpi":240.0},{"size":Vector2i(2340,1080),"dpi":360.0},{"size":Vector2i(1024,576),"dpi":192.0},{"size":Vector2i(1280,720),"dpi":420.0}]:
  root.size=case.size;app.layout_dpi_override=case.dpi
  app.layout_safe_override=Rect2(60,0,case.size.x-84,case.size.y-24)
  await frames();app.menu();await frames()
  var safe=app.ui_metrics.safe.grow(2)
  expect(safe.encloses(app.task_button.get_global_rect()),"Android task entry fits safe area "+str(case.size)+" dpi "+str(case.dpi))
  expect(safe.encloses(app.task_balance.get_global_rect()),"Android wallet fits safe area "+str(case.size)+" dpi "+str(case.dpi))
  verify_wallet()
  await shot("menu-android-%dx%d-dpi%d" % [case.size.x,case.size.y,case.dpi])
  await click(app.task_button.get_global_rect().get_center());await frames();await wait_sync()
  var popup=app.menu_popup
  expect(popup is TaskPopup and safe.encloses(popup.panel.get_global_rect()),"Android task popup fits safe area")
  for tab in popup.tabs:expect(safe.encloses(tab.get_global_rect()) and tab.size.y>=app.ui_metrics.hit,"Android category has a full touch target")
  for slot in range(3):
   var task=popup.find_child("DailyTask"+str(slot),true,false)
   var refresh=popup.find_child("RerollTask"+str(slot),true,false)
   expect(task.get_global_rect().end.x<=popup.panel.get_global_rect().end.x and refresh.size.x>=app.ui_metrics.hit and refresh.size.y>=app.ui_metrics.hit,"Android task row wraps and keeps refresh touch target")
  await shot("daily-android-%dx%d-dpi%d" % [case.size.x,case.size.y,case.dpi])
  popup.find_child("DailyTask2",true,false).find_child("RerollTask2",true,false).grab_focus();await frames()
  expect(popup.scroll.get_global_rect().intersects(popup.find_child("RerollTask2",true,false).get_global_rect()),"Android focus scroll reaches the final daily task")
  await click(popup.tabs[1].get_global_rect().get_center());await frames()
  expect(popup.selected==1 and popup.scroll.size.y>=app.ui_metrics.hit*2,"Android season tasks keep a useful scroll area")
  popup.scroll.scroll_vertical=int(popup.scroll.get_v_scroll_bar().max_value);await frames()
  var last=popup.find_child("SeasonReward80",true,false)
  expect(last!=null and popup.scroll.get_global_rect().intersects(last.get_global_rect()),"Android scroll reaches the final reward tier")
  popup.scroll.scroll_vertical=0;await frames()
  await shot("season-android-%dx%d-dpi%d" % [case.size.x,case.size.y,case.dpi])
  app.queue_layout_refresh();await frames();expect(app.menu_popup==popup and popup.selected==1,"Android relayout preserves task tab")
  await click(popup.tabs[2].get_global_rect().get_center());await frames()
  expect(popup.find_child("EmptyAchievements",true,false)!=null,"Android achievement tab remains empty")
  popup.close();await frames()
 # Card hyperlinks and their detail layer also work in the densest mobile case.
 app.account_name="TEST_ONLY_cards";app.account_token=fixture.logins.TEST_ONLY_cards
 app.refresh_tasks();await wait_sync();app.open_tasks();await wait_sync()
 var linked_popup=app.menu_popup
 var linked_title=linked_popup.find_child("DailyTask2",true,false).find_child("TaskTitle",true,false)
 linked_popup.scroll.ensure_control_visible(linked_title);await frames()
 await click_card_name(linked_title,Store.CARDS["121"].name);await frames()
 expect(linked_popup.inspected_card=="121","Android card-name link opens the correct card")
 expect(app.ui_metrics.safe.grow(2).encloses(linked_popup.card_panel.get_global_rect()),"Android card details fit the safe area")
 await shot("task-card-detail-android")
 var back=InputEventKey.new();back.keycode=KEY_BACK;back.pressed=true;root.push_input(back,true);await frames()
 expect(not is_instance_valid(linked_popup.card_overlay) and app.menu_popup==linked_popup,"Android back returns from card details to daily tasks")
 app.close_menu_popup()
 # Logout also cancels an in-flight request and prevents stale responses.
 await verify_coin_victory_link()
 app.refresh_tasks();app.account_name="";app.account_token="";app.sync_tasks();await frames(25)
 expect(app.task_service.snapshot.is_empty() and not is_instance_valid(app.task_service.client) and app.task_balance.text=="铜钱：—","logout cancels requests and clears server snapshot")
 print("TASK UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
