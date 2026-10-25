extends "res://tests/support/ui_base.gd"
## Exercise the actual mailbox controls, including input after a claim response.
class CommunityFixture:
 extends Node
 var entry: Dictionary={}
 var pending: Callable
 var claims=0
 func paths() -> Array:return []
 func request(payload: Dictionary,callback: Callable):
  if payload.action=="announcements":callback.call_deferred({"ok":true,"announcements":[entry]})
  else:claims+=1;pending=callback
 func reply(answer: Dictionary):
  var callback=pending;pending=Callable()
  if callback.is_valid():callback.call(answer)

var community=CommunityFixture.new()
var folder="res://work/announcement-rewards-tests"

func frames(count: int=8):
 for i in range(count):await process_frame

func activate(control: Control):
 var at=control.get_global_rect().get_center()
 if not app.is_android:await click(at);await frames();return
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func dialogs() -> Array:
 return app.get_children().filter(func(node):return node is Window and node.visible)

func verify_claim(mobile: bool,answer: Dictionary):
 app.is_android=mobile;app.refresh_ui_metrics()
 var prefix="Android" if mobile else "Windows"
 var success=answer.get("ok",false)
 community.entry={"id":"TEST_ONLY_reward_"+prefix+str(success),"version":"1.0","date":"2026-10-25","title":"领取测试","body":"公告正文\n".repeat(24),"coins":17}
 app.announcement_store.merge_online([community.entry])
 app.open_announcement_mailbox(community.entry);await frames()
 var popup=app.menu_popup
 var claim=popup.find_child("ClaimAnnouncementCoins",true,false)
 popup.scroll.ensure_control_visible(claim);await frames()
 var scroll_before=popup.scroll.scroll_vertical
 var requests_before=community.claims
 await activate(claim)
 expect(popup.claim_busy and community.claims==requests_before+1,prefix+" actual claim click sends one request")
 var pending_button=popup.find_child("ClaimAnnouncementCoins",true,false)
 expect(pending_button==claim and pending_button.disabled,prefix+" pending claim keeps and disables the clicked button")
 expect(popup.scroll.scroll_vertical==scroll_before,prefix+" pending claim preserves reading position")
 popup.claim_coins(community.entry.id)
 expect(community.claims==requests_before+1,prefix+" repeated click cannot send an overlapping claim")
 community.reply(answer);await frames()
 expect(not popup.claim_busy,prefix+" response releases the pending state")
 expect(dialogs().is_empty(),prefix+" claim response does not create a blocking native dialog")
 var notice=popup.find_child("AnnouncementClaimStatus",true,false)
 expect(notice!=null and notice.text==answer.message,prefix+" response stays visible inside the mailbox")
 expect(notice!=null and popup.scroll.get_global_rect().encloses(notice.get_global_rect()),prefix+" response is in view beside the claimed reward")
 expect(popup.scroll.scroll_vertical==scroll_before,prefix+" response preserves reading position")
 var completed_button=popup.find_child("ClaimAnnouncementCoins",true,false)
 expect(completed_button.disabled==success,prefix+" success disables claiming and errors allow retry")
 if not success:
  await activate(completed_button)
  expect(popup.claim_busy and community.claims==requests_before+2,prefix+" failed claim can be retried with the same button")
  community.reply({"ok":true,"message":"此公告奖励已领取"});await frames()
  expect(popup.find_child("ClaimAnnouncementCoins",true,false).disabled,prefix+" retry recovers an existing server receipt")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(folder.path_join(prefix+("-success" if success else "-error")+".png"))
 await activate(popup.close_button)
 expect(not app.menu_popup_open(),prefix+" mailbox close remains clickable after the claim response")
 # Also let the failing baseline finish without leaving a modal window behind.
 for dialog in dialogs():dialog.hide();dialog.queue_free()
 app.close_menu_popup();await frames()

func verify_logout(mobile: bool):
 app.is_android=mobile;app.refresh_ui_metrics();app.account_token=""
 community.entry=community.entry.duplicate();community.entry.id="TEST_ONLY_guest_"+str(mobile)
 app.announcement_store.merge_online([community.entry]);app.open_announcement_mailbox(community.entry);await frames()
 var popup=app.menu_popup
 var claim=popup.find_child("ClaimAnnouncementCoins",true,false)
 popup.scroll.ensure_control_visible(claim);await frames()
 var requests_before=community.claims
 await activate(claim)
 var notice=popup.find_child("AnnouncementClaimStatus",true,false)
 expect(dialogs().is_empty() and notice!=null and notice.text.contains("请先登录"),"logged-out claim reports login requirement inside the mailbox")
 expect(community.claims==requests_before and not popup.claim_busy,"logged-out claim sends no request")
 await activate(popup.close_button)
 expect(not app.menu_popup_open(),"logged-out mailbox remains closable")
 app.account_token="TEST_ONLY_rewards"

func verify_closed_request():
 community.entry=community.entry.duplicate();community.entry.id="TEST_ONLY_closed_request"
 app.announcement_store.merge_online([community.entry]);app.open_announcement_mailbox(community.entry);await frames()
 var popup=app.menu_popup
 var claim=popup.find_child("ClaimAnnouncementCoins",true,false)
 popup.scroll.ensure_control_visible(claim);await frames();await activate(claim)
 await activate(popup.close_button)
 community.reply({"ok":true,"message":"已领取 17 铜钱"});await frames()
 expect(not app.menu_popup_open() and dialogs().is_empty(),"late claim response cannot reopen or block a closed mailbox")
 expect(app.announcement_store.is_read(community.entry),"claim response after closing still records the receipt and marks the opened announcement read")

func verify_unread_rewards(mobile: bool):
 app.is_android=mobile;app.refresh_ui_metrics()
 app.account_name="TEST_ONLY_rewards";app.account_token="TEST_ONLY_rewards"
 var store=app.announcement_store
 store.set_account(app.account_name);store.claimed_by_account={};store.read_versions=[]
 community.entry={"id":"TEST_ONLY_unread_reward","version":"1.0","title":"未领铜钱公告","body":"领取后才算已读","coins":17}
 var plain={"id":"TEST_ONLY_plain","version":"1.0","title":"普通公告","body":"阅读后即为已读"}
 store.history=[community.entry.duplicate(),plain]
 app.refresh_mailbox_badge();app.open_announcement_mailbox();await frames()
 var popup=app.menu_popup
 var reward_button=popup.entries.find_child("Announcement_TEST_ONLY_unread_reward",false,false)
 expect(reward_button!=null and reward_button.get_meta("has_red_dot",false),"reward announcement has an unread red dot")
 expect(popup.read_tabs[0].get_global_rect().end.x<=popup.scroll.get_global_rect().position.x,"read and unread tabs are on the left")
 expect(app.ui_metrics.safe.grow(2).encloses(popup.panel.get_global_rect()),"mailbox fits the safe area")
 await activate(reward_button)
 expect(not store.is_read(community.entry) and store.unread_count()==2 and app.mailbox_button.unread==2,"opened reward stays unread with mailbox red dot")
 await activate(popup.archive_button)
 expect(popup.entries.find_child("Announcement_TEST_ONLY_unread_reward",false,false)!=null,"opened unclaimed announcement stays in unread tab")
 reward_button=popup.entries.find_child("Announcement_TEST_ONLY_unread_reward",false,false)
 await activate(reward_button);await activate(popup.claim_button)
 community.entry.claimed=true
 community.reply({"ok":true,"message":"已领取 17 铜钱"});await frames()
 expect(store.is_read(community.entry) and store.unread_count()==1 and app.mailbox_button.unread==1,"claiming moves the opened reward to read and clears its red dot")
 await activate(popup.archive_button)
 expect(popup.entries.find_child("Announcement_TEST_ONLY_unread_reward",false,false)==null,"claimed announcement leaves unread tab")
 await activate(popup.read_tabs[1])
 reward_button=popup.entries.find_child("Announcement_TEST_ONLY_unread_reward",false,false)
 expect(reward_button!=null and not reward_button.get_meta("has_red_dot",false),"read tab contains claimed announcement without red dot")
 var reloaded=load("res://scripts/announcement_store.gd").new()
 reloaded.initialize("1.0",store.path,"res://work/TEST_ONLY_missing_announcements.json");reloaded.set_account(app.account_name)
 expect(reloaded.is_read(community.entry),"restart retains this account's claim receipt")
 reloaded.set_account("TEST_ONLY_other")
 expect(not reloaded.is_read(community.entry),"another account's unclaimed reward remains unread")
 await activate(popup.close_button)

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var fixture=folder.path_join(str(Time.get_ticks_usec()))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture.path_join("portable"))
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900)
 root.content_scale_size=Vector2i(1600,900);root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate()
 app.settings_path=fixture.path_join("settings.json");app.account_session_path=fixture.path_join("account.json")
 app.tutorial_local_directory=fixture.path_join("tutorials")
 app.tournament_server_url="ws://127.0.0.1:1";app.task_server_url="ws://127.0.0.1:1"
 app.community_service=community;app.add_child(community)
 root.add_child(app);await frames(20)
 app.account_name="TEST_ONLY_rewards";app.account_token="TEST_ONLY_rewards"
 for mobile in [false,true]:
  await verify_unread_rewards(mobile)
  await verify_claim(mobile,{"ok":true,"message":"已领取 17 铜钱"})
  await verify_claim(mobile,{"ok":false,"message":"社区服务响应超时，请重试"})
  await verify_logout(mobile)
 await verify_closed_request()
 print("ANNOUNCEMENT REWARDS UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
