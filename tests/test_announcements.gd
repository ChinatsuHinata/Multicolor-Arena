extends "res://tests/support/ui_base.gd"
const AnnouncementStore=preload("res://scripts/announcement_store.gd")
const AnnouncementPopup=preload("res://scripts/announcement_popup.gd")
var BODY=""
var reward_body=""
var current_entries: Array=[]
var folder="res://work/announcements-test"
var fixture=""
var version=""
var previous=""
var next=""
var future=""
var background_clicks=0

func frames(count: int=8):
 for i in range(count):await process_frame

func write_json(path: String,value):
 var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close()

func announcement(release: String,value: String) -> Dictionary:
 return {"version":release,"date":"2026-10-13","title":"公告 "+release,"body":value}

func bump(release: String,amount: int) -> String:
 var parts=release.split(".");parts[-1]=str(int(parts[-1])+amount)
 return ".".join(parts)

func check_store():
 var catalogue=fixture.path_join("catalogue.json")
 var storage=fixture.path_join("archive.json")
 write_json(catalogue,{"schema":1,"announcements":[announcement(previous,"过去的公告"),announcement(version,BODY),announcement(future,"未来公告"),{"version":version}]})
 var store=AnnouncementStore.new();store.initialize(version,storage,catalogue)
 expect(store.history.size()==2 and store.find_version(future).is_empty(),"only valid released announcements enter the archive")
 expect(store.pending().body==BODY and store.unread_count()==2,"first effective release has its exact announcement and unread history")
 expect(store.record_opened(version,true),"delivery and read receipt save successfully")
 var restarted=AnnouncementStore.new();restarted.initialize(version,storage,catalogue)
 expect(restarted.pending().is_empty() and restarted.unread_count()==1,"restart preserves receipt and does not push the same release again")
 write_json(catalogue,{"schema":1,"announcements":[announcement(next,"新公告")]})
 restarted.initialize(next,storage,catalogue)
 expect(restarted.pending().body=="新公告" and restarted.history.size()==3,"new release pushes new content and retains snapshots removed from the catalogue")
 expect(restarted.history[0].version==next and restarted.find_version(previous).body=="过去的公告","archive sorts newest first and keeps old content")
 restarted.record_opened(next,true)
 restarted.initialize(future,storage,catalogue)
 expect(restarted.pending().version==future and restarted.pending().body=="新公告","an update reusing content still gets exactly one release receipt")
 restarted.record_opened(future,true);restarted.initialize(future,storage,catalogue)
 expect(restarted.pending().is_empty() and restarted.history.size()==4,"repeated sync neither redelivers nor duplicates release snapshots")
 restarted.initialize(version,storage,catalogue)
 expect(restarted.pending().is_empty(),"returning to an already delivered release does not push again")
 var manual=AnnouncementStore.new();manual.initialize(version,fixture.path_join("manual.json"),AnnouncementStore.CATALOGUE_PATH)
 while not manual.pending().is_empty():manual.record_opened(manual.entry_id(manual.pending()))
 expect(manual.pending().is_empty(),"reading the current announcement manually also prevents a redundant automatic popup")
 write_json(fixture.path_join("damaged.json"),["invalid archive"])
 var recovered=AnnouncementStore.new();recovered.initialize(version,fixture.path_join("damaged.json"),AnnouncementStore.CATALOGUE_PATH)
 expect(recovered.pending().body==BODY,"invalid storage recovers the shipped announcement")

func tap(at: Vector2):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func swipe_up(at: Vector2):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 for i in range(1,7):
  var motion=InputEventScreenDrag.new();motion.index=0
  motion.position=at-Vector2(0,i*20);motion.relative=Vector2(0,-20)
  root.push_input(motion,true);await process_frame
 event=event.duplicate();event.position=at-Vector2(0,120);event.pressed=false
 root.push_input(event,true);await frames()

func activate(button: Button):
 if app.is_android:await tap(button.get_global_rect().get_center())
 else:await click(button.get_global_rect().get_center());await frames()

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder.path_join(name+".png"))

func check_geometry(prefix: String):
 var popup=app.menu_popup
 var safe=app.ui_metrics.safe.grow(2)
 expect(safe.encloses(popup.panel.get_global_rect()),prefix+" announcement panel fits the safe area")
 for control in [popup.close_button,popup.scroll]:
  expect(popup.panel.get_global_rect().grow(1).encloses(control.get_global_rect()),prefix+" reader controls fit inside the panel")
 expect(popup.scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,prefix+" body wraps without horizontal scrolling")

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 fixture=folder.path_join("fixtures-"+str(Time.get_ticks_usec()))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
 version=str(ProjectSettings.get_setting("application/config/version"))
 var shipped=AnnouncementStore.new();shipped.initialize(version,fixture.path_join("shipped.json"))
 BODY=str(shipped.pending().body)
 current_entries=shipped.history.duplicate(true)
 reward_body=str(current_entries[1].body)
 expect(current_entries.size()==2 and current_entries[0].version==version and current_entries[1].version==version,"current release ships exactly two separately identified announcements")
 expect(shipped.entry_id(current_entries[0])!=shipped.entry_id(current_entries[1]),"announcements in one release have independent receipt IDs")
 previous=bump(version,-1);next=bump(version,1);future=bump(version,2)
 check_store()
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture.path_join("decks"))
 write_json(fixture.path_join("settings.json"),{"fullscreen":false})
 write_json(fixture.path_join("announcements.json"),{"schema":1,"history":[announcement(previous,"旧推送一"),announcement(version,"旧推送二")],"pushed_versions":[previous,version],"read_versions":[previous,version]})
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
 app=load("res://main.tscn").instantiate()
 app.settings_path=fixture.path_join("settings.json");app.account_session_path=fixture.path_join("account.json")
 app.tutorial_local_directory=fixture.path_join("tutorials")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(app.tutorial_local_directory))
 app.announcement_push_in_editor=true;root.add_child(app);await frames(20)
 expect(app.menu_popup_open() and app.menu_popup is AnnouncementPopup,"first startup opens the production announcement popup")
 expect(app.menu_popup.entries.get_node("AnnouncementBody").text==BODY,"startup displays the current shipped announcement verbatim")
 expect(app.announcement_store.history.size()==2 and app.announcement_store.find_id(previous).is_empty() and app.announcement_store.find_id(version).is_empty(),"both old saved pushes are removed before the first popup or mailbox can display them")
 expect(app.announcement_store.pending().body==reward_body,"showing the first announcement leaves the second pending")
 var interrupted=AnnouncementStore.new();interrupted.initialize(version,fixture.path_join("announcements.json"))
 expect(interrupted.pending().body==reward_body,"restart between popups resumes only the second announcement")
 check_geometry("desktop");await shot("desktop-push")
 var background=app.button(app.screen,"测试背景",Rect2(24,300,180,70),func():background_clicks+=1)
 await click(background.get_global_rect().get_center());await tap(background.get_global_rect().get_center())
 expect(background_clicks==0 and app.menu_popup_open(),"announcement modal blocks mouse and native touch on background controls")
 await activate(app.menu_popup.close_button)
 expect(app.menu_popup_open() and app.menu_popup.entries.get_node("AnnouncementBody").text==reward_body,"closing the first popup immediately pushes the second announcement")
 check_geometry("desktop reward");await shot("desktop-reward-push")
 expect(app.announcement_store.pending().is_empty(),"both independent delivery receipts are recorded")
 await activate(app.menu_popup.close_button)
 app.menu();await frames()
 expect(not app.menu_popup_open(),"returning to main menu never repeats the same announcement")
 await activate(app.mailbox_button)
 expect(app.menu_popup_open() and app.menu_popup.selected_version.is_empty(),"top-right envelope opens the archive")
 var row=app.menu_popup.entries.find_children("Announcement_*","Button",true,false)[0]
 await activate(row)
 expect(app.menu_popup.entries.get_node("AnnouncementBody").text==BODY,"archived announcement reopens its saved body")
 await activate(app.menu_popup.archive_button)
 expect(app.menu_popup.selected_version.is_empty(),"reader returns to archive")
 await activate(app.menu_popup.close_button)
 var store=AnnouncementStore.new();store.initialize(version,fixture.path_join("announcements.json"))
 expect(store.pending().is_empty() and store.unread_count()==0,"real UI receipt and read status persist across restart")
 # Installing a patch only changes pending_version; its announcement waits for restart.
 app.patch_manager().pending_version=next;app.menu();await frames()
 expect(not app.menu_popup_open() and app.announcement_store.active_version==version,"downloaded pending PCK does not deliver an announcement before activation")
 app.patch_manager().pending_version=""
 var mobile_catalogue=fixture.path_join("mobile-catalogue.json")
 write_json(mobile_catalogue,{"schema":1,"announcements":[current_entries[0],current_entries[1],announcement(next,"新版本公告\n"+BODY)]})
 app.is_android=true;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 root.size=Vector2i(1280,720);app.layout_dpi_override=360;app.layout_safe_override=Rect2(40,12,1200,684)
 app.announcement_store.initialize(version,fixture.path_join("android-sequence.json"))
 app.menu();await frames(20)
 expect(app.menu_popup_open() and app.menu_popup.entries.get_node("AnnouncementBody").text==BODY,"Android first pushes the new tournament announcement")
 check_geometry("android tournament");await shot("android-tournament-push")
 app.android_system_back();await frames()
 expect(app.menu_popup_open() and app.menu_popup.entries.get_node("AnnouncementBody").text==reward_body,"Android back closes the first popup and pushes the second new announcement")
 check_geometry("android reward");await shot("android-reward-push")
 app.android_system_back();await frames()
 expect(not app.menu_popup_open() and app.announcement_store.pending().is_empty(),"Android records both receipts and stops after the two new pushes")
 app.announcement_store.initialize(next,fixture.path_join("announcements.json"),mobile_catalogue)
 app.menu();await frames(20)
 expect(app.menu_popup_open() and app.menu_popup.selected_version==next,"first menu after a new effective version pushes again on Android")
 check_geometry("android");await shot("android-push")
 var same_popup=app.menu_popup
 app.layout_dpi_override=420;app.layout_safe_override=Rect2(60,12,1160,680)
 app.refresh_responsive_layout();await frames()
 expect(app.menu_popup==same_popup and app.menu_popup.selected_version==next,"safe-area refresh preserves the open announcement reader")
 check_geometry("dense android");await shot("android-dense-push")
 app.android_system_back();await frames()
 expect(not app.menu_popup_open(),"Android system back closes the announcement")
 app.menu();await frames()
 var safe=app.ui_metrics.safe.grow(2)
 expect(safe.encloses(app.mailbox_button.get_global_rect()) and app.mailbox_button.size.x>=app.ui_metrics.hit,"Android envelope fits the safe area at the native touch size")
 expect(app.mailbox_button.get_global_rect().position.x>app.ui_metrics.safe.get_center().x,"envelope stays in the upper-right corner")
 await activate(app.mailbox_button)
 expect(app.menu_popup.entries.find_children("Announcement_*","Button",true,false).size()==3,"Android archive keeps both new announcements and the following release")
 await shot("android-archive")
 var scroll=app.menu_popup.scroll
 await swipe_up(scroll.get_global_rect().get_center())
 expect(scroll.scroll_vertical>0,"native Android swipe reaches older archived announcements")
 app.android_system_back();await frames()
 app.announcement_store.initialize(future,fixture.path_join("announcements.json"),mobile_catalogue)
 app.alert("启动提示");app.menu();await frames()
 expect(not app.menu_popup_open() and not app.announcement_store.pending().is_empty(),"automatic announcement waits behind a startup dialog")
 for child in app.get_children():
  if child is AcceptDialog:child.hide();child.queue_free()
 await create_timer(0.6).timeout;await frames()
 expect(app.menu_popup_open() and app.menu_popup.selected_version==future,"announcement resumes after the startup dialog closes")
 app.close_menu_popup();app.queue_free();await frames()
 app=load("res://main.tscn").instantiate()
 app.settings_path=fixture.path_join("settings.json");app.account_session_path=fixture.path_join("account.json")
 app.tutorial_local_directory=fixture.path_join("tutorials");app.announcement_push_in_editor=true
 root.add_child(app);await frames(20)
 expect(not app.menu_popup_open(),"a new game instance reads persisted delivery and does not repeat the announcement")
 expect(app.announcement_store.find_version(next).body.contains(BODY),"a new game instance keeps earlier update snapshots even with a smaller catalogue")
 app.queue_free();await frames()
 print("ANNOUNCEMENTS: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
