extends "res://tests/support/ui_base.gd"
const Client=preload("res://scripts/community_client.gd")
var fixture: Dictionary
var endpoint="ws://127.0.0.1:48065"

func frames(count: int=8):
 for i in range(count):await process_frame

func until(callback: Callable,seconds: int=20) -> bool:
 var deadline=Time.get_ticks_msec()+seconds*1000
 while Time.get_ticks_msec()<deadline:
  if callback.call():return true
  await process_frame
 return false

func api(payload: Dictionary,user: String="bigcake") -> Dictionary:
 var client=Client.new();root.add_child(client);client.server_url=endpoint
 var result={"done":false,"answer":{}}
 client.finished.connect(func(answer):result.answer=answer;result.done=true)
 client.request(payload,str(fixture.logins.get(user,{}).get("token","")))
 expect(await until(func():return result.done),"encrypted community request completes: "+str(payload.action))
 client.queue_free();return result.answer

func login(user: String):
 app.account_name=user;app.account_token=str(fixture.logins.get(user,{}).get("token",""));app.account_nickname=user

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/tournament-tests/"+name+".png")

func activate(control: Control):
 var at=control.get_global_rect().get_center()
 if not app.is_android:await click(at);await frames();return
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func management(user: String):
 login(user);app.tutorials()
 expect(await until(func():return not app.online_community().syncing),"group permissions synchronize for "+user)
 app.community_management();await frames()
 var page=app.screen.get_child(0)
 expect(await until(func():return not page.busy),"group management finishes loading for "+user)
 return page

func verify_coin_grants():
 var page=await management("first_player")
 expect(find_button(page,"赠予铜钱")==null,"ordinary tutorial members cannot see the coin grant tab")
 var forged={"action":"grant_coins","target_username":"first_player","coins":23,"request_id":"11111111111111111111111111111111","username":"bigcake","super_admin":true}
 expect(not (await api(forged,"first_player")).get("ok",false),"payload cannot impersonate a super administrator")
 expect(not (await api(forged,"")).get("ok",false),"anonymous users cannot grant coins")
 expect(not (await api({"action":"set_role","username":"bigcake","role":"super_admin","enabled":false})).get("ok",false),"bigcake remains bound to the super administrator group")
 expect(not (await api({"action":"set_role","username":"second_player","role":"super_admin","enabled":true})).get("ok",false),"group management cannot add another account to the bound super administrator group")
 var roles=await api({"action":"roles"})
 expect(roles.get("roles",[]).any(func(entry):return entry.username=="bigcake" and entry.role=="super_admin"),"group roster includes bigcake's persistent super administrator membership")
 for mobile in [false,true]:
  app.is_android=mobile;app.refresh_ui_metrics()
  page=await management("bigcake")
  var tab_button=find_button(page,"赠予铜钱")
  expect(tab_button!=null,"super administrator group exposes the coin grant tab")
  if tab_button==null:continue
  await activate(tab_button)
  var target_kind=page.find_child("CoinGrantTargetKind",true,false)
  var target=page.find_child("CoinGrantTarget",true,false)
  var amount=page.find_child("CoinGrantAmount",true,false)
  var submit=page.find_child("GrantCoins",true,false)
  expect(target_kind!=null and target!=null and amount!=null and submit!=null,"coin grant form exposes target, amount and submit controls")
  if target_kind==null or target==null or amount==null or submit==null:continue
  expect(amount.min_value==1 and amount.max_value==1000000,"coin grant amount has positive integer bounds")
  if mobile:
   target_kind.select(1);target_kind.item_selected.emit(1);await frames()
   target=page.find_child("CoinGrantTarget",true,false)
   amount=page.find_child("CoinGrantAmount",true,false)
   submit=page.find_child("GrantCoins",true,false)
   expect(target!=null and amount!=null and submit!=null,"changing target mode rebuilds a usable coin grant form")
   if target==null or amount==null or submit==null:continue
  target.text=str(int(fixture.logins.first_player.player_id)) if mobile else "first_player"
  target.text_changed.emit(target.text)
  amount.value=5 if mobile else 23
  var scroll=page.rows.get_parent() as ScrollContainer
  scroll.ensure_control_visible(submit);await frames()
  expect(root.get_visible_rect().encloses(submit.get_global_rect()),"coin grant submit fits the viewport")
  expect(submit.size.y>=app.ui_metrics.hit,"coin grant submit keeps the required touch size")
  await shot("coin-grant-android" if mobile else "coin-grant-desktop")
  await activate(submit)
  expect(await until(func():return not page.busy),"coin grant over encrypted transport finishes")
  expect(page.notice.text.contains("first_player") and page.notice.text.contains(str(5 if mobile else 23)),"coin grant reports the recipient and amount: "+page.notice.text)
  target=page.find_child("CoinGrantTarget",true,false)
  expect(target!=null and target.text.is_empty(),"successful coin grant clears the target to prevent an accidental second grant")
  page=await management("first_player")
  expect(find_button(page,"赠予铜钱")==null,"switching back to a tutorial member removes the coin grant controls")
  login("first_player");app.refresh_tasks()
  expect(await until(func():return not is_instance_valid(app.task_service.client)),"recipient refreshes the authoritative wallet")
  expect(app.task_service.snapshot.get("coins",-1)==(45 if mobile else 40),"gift adds to the existing wallet without an unauthorized extra grant")
 app.is_android=false;app.refresh_ui_metrics()
 await verify_coin_grant_resume()
 login("first_player")

func verify_coin_grant_resume():
 var page=await management("bigcake")
 var tab_button=find_button(page,"赠予铜钱")
 expect(tab_button!=null,"super administrator can reopen the coin grant form")
 if tab_button==null:return
 await activate(tab_button)
 var target=page.find_child("CoinGrantTarget",true,false)
 var amount=page.find_child("CoinGrantAmount",true,false)
 var submit=page.find_child("GrantCoins",true,false)
 expect(target!=null and amount!=null and submit!=null,"coin grant retry form is available")
 if target==null or amount==null or submit==null:return
 target.text="missing_player";target.text_changed.emit(target.text);amount.value=7
 var scroll=page.rows.get_parent() as ScrollContainer
 scroll.ensure_control_visible(submit);await frames();await activate(submit)
 expect(await until(func():return not page.busy),"nonexistent recipient receives a response")
 expect(page.notice.text.contains("不存在") and target.text=="missing_player" and not submit.disabled,"recipient error preserves editable inputs for correction")
 var community=app.online_community()
 var failed_request_id=str(community.pending_coin_grant().get("request_id",""))
 target.text="first_player";target.text_changed.emit(target.text)
 page.submit_coin_grant()
 var request_id=str(community.pending_coin_grant().get("request_id",""))
 expect(not request_id.is_empty() and request_id!=failed_request_id,"correcting the recipient creates a distinct pending gift request")
 app.tutorials()
 expect(await until(func():return not community.syncing and community.get_child_count()==0),"gift and tutorial sync finish after leaving the management page")
 expect(str(community.pending_coin_grant().get("request_id",""))==request_id,"leaving before the reply retains the gift request identifier")
 login("first_player");app.refresh_tasks()
 expect(community.pending_coin_grant().is_empty(),"another account cannot see the administrator's pending gift")
 expect(await until(func():return not is_instance_valid(app.task_service.client)),"recipient refreshes after the interrupted gift flow")
 expect(app.task_service.snapshot.get("coins",-1)==52,"gift reaches the wallet even when the administrator leaves before the reply")
 page=await management("bigcake")
 target=page.find_child("CoinGrantTarget",true,false)
 amount=page.find_child("CoinGrantAmount",true,false)
 submit=page.find_child("GrantCoins",true,false)
 expect(target!=null and amount!=null and submit!=null,"reopened management restores the pending gift tab")
 if target==null or amount==null or submit==null:return
 expect(target.text=="first_player" and amount.value==7,"reopened gift form restores the original recipient and amount")
 expect(str(community.pending_coin_grant().get("request_id",""))==request_id,"reopened gift form reuses the original request identifier")
 scroll=page.rows.get_parent() as ScrollContainer
 scroll.ensure_control_visible(submit);await frames();await activate(submit)
 expect(await until(func():return not page.busy),"retrying an interrupted gift receives its receipt")
 expect(community.pending_coin_grant().is_empty(),"successful retry clears the unconfirmed gift")
 target=page.find_child("CoinGrantTarget",true,false)
 expect(target!=null and target.text.is_empty(),"successful retry clears the restored target input")
 login("first_player");app.refresh_tasks()
 expect(await until(func():return not is_instance_valid(app.task_service.client)),"recipient refreshes after the gift retry")
 expect(app.task_service.snapshot.get("coins",-1)==52,"retry after leaving the page cannot grant the same seven coins twice")

func run():
 var args=OS.get_cmdline_user_args()
 for i in range(args.size()-1):
  if args[i]=="--fixture":fixture=JSON.parse_string(FileAccess.get_file_as_string(args[i+1]))
 if fixture.is_empty():quit(1);return
 Store.Paths.root_override=fixture.folder.path_join("decks")
 root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
 app=load("res://main.tscn").instantiate()
 app.settings_path=fixture.folder.path_join("community-settings.json");app.account_session_path=fixture.folder.path_join("community-account.json")
 app.tutorial_local_directory=fixture.folder.path_join("community-drafts")
 app.tournament_server_url=endpoint;app.task_server_url=endpoint;app.lan_storage_directory=fixture.folder.path_join("lan-community")
 root.add_child(app);await frames(20)
 app.tutorials();await frames()
 expect(await until(func():return not app.online_community().syncing),"anonymous player completes online tutorial sync")
 expect(app.online_community().manifest.size()==4,"all four approved bundled lessons downloaded, including large t4")
 expect(app.tutorial_catalog_errors.is_empty(),"downloaded lessons pass the actual tutorial schema")
 expect(not app.tutorial_editor_available() and not app.tutorial_ui.editor_button.visible,"anonymous player has no editor entry")
 var granted=await api({"action":"set_role","username":"first_player","role":"tutorial_editor","enabled":true})
 expect(granted.get("ok",false),"bigcake grants tutorial group membership over encrypted transport")
 login("first_player");app.tutorials();await until(func():return not app.online_community().syncing);await frames()
 expect(app.tutorial_editor_available(),"membership enables editor in normal client")
 app.tutorial_editor("res://data/tutorial/beginner/t4.json");await frames()
 var editor=app.screen.get_child(0)
 expect(editor.get_script()==preload("res://scripts/tutorial/authoring_editor.gd"),"group member opens real authoring editor")
 if editor.get_script()!=preload("res://scripts/tutorial/authoring_editor.gd"):finish();return
 editor.model.data.title="线上待审核教程";editor.save()
 expect(FileAccess.file_exists(app.tutorial_local_directory.path_join("t4.json")),"first save creates a private local draft")
 expect(FileAccess.file_exists(app.tutorial_local_directory.path_join("t4.json.revision")),"draft retains the reviewed base revision")
 editor.submit_online()
 expect(await until(func():return not editor.online_busy),"large tutorial is submitted for review")
 expect("已推送" in editor.status_label.text,"submission response: "+editor.status_label.text)
 var submissions=await api({"action":"submissions"})
 expect(submissions.get("submissions",[]).size()==1,"bigcake receives the pending proposal")
 if submissions.get("submissions",[]).is_empty():finish();return
 var id=int(submissions.submissions[0].id)
 var original=await api({"action":"lesson","id":"t4"},"")
 expect(JSON.parse_string(original.document_text).title!="线上待审核教程","unapproved edit is invisible to public readers")
 expect(not (await api({"action":"review_lesson","id":id,"approve":true},"first_player")).get("ok",false),"editor cannot approve their own submission")
 login("bigcake");app.tutorials();await until(func():return not app.online_community().syncing)
 var proposal=await api({"action":"submission","id":id})
 app.tutorial_review(proposal.document,id,int(proposal.base_revision));await frames()
 editor=app.screen.get_child(0)
 expect(find_button(editor,"批准发布")!=null,"bigcake has review approval control")
 await shot("tutorial-review-desktop")
 editor.review_online(true);await frames()
 expect(await until(func():return app.page=="community"),"approval publishes and returns to group")
 await frames();await shot("community-admin-desktop")
 login("");app.tutorials();await until(func():return not app.online_community().syncing);await frames()
 expect(app.tutorial_entries.any(func(entry):return entry.id=="t4" and entry.title=="线上待审核教程"),"anonymous player syncs the approved revision")
 expect(app.online_community().revision("t4")==2,"cached revision advances only after successful package validation")
 var announcement={"id":"community-coins","title":"领取测试","version":"1.0","body":"领取 17 铜钱"}
 expect((await api({"action":"publish_announcement","entry":announcement,"coins":17})).get("ok",false),"bigcake publishes configurable announcement money")
 login("first_player")
 app.open_announcement_mailbox()
 var mail=app.menu_popup
 expect(await until(func():return not app.announcement_store.find_id("community-coins").is_empty()),"mailbox discovers the online announcement")
 mail.show_entry(app.announcement_store.find_id("community-coins"));await frames()
 expect(mail.find_child("ClaimAnnouncementCoins",true,false)!=null,"announcement exposes coin claim button")
 await click(mail.find_child("ClaimAnnouncementCoins",true,false).get_global_rect().get_center())
 expect(await until(func():return not mail.claim_busy),"clicked announcement claim finishes")
 expect(app.announcement_store.is_claimed("community-coins") and mail.find_child("ClaimAnnouncementCoins",true,false).disabled,"coin receipt disables duplicate claims")
 expect(mail.find_child("AnnouncementClaimStatus",true,false).text.contains("已领取"),"real encrypted claim reports its result inside the mailbox")
 expect(not app.get_children().any(func(node):return node is Window and node.visible),"real claim does not leave an input-blocking dialog")
 expect(await until(func():return app.task_service.snapshot.get("coins",0)==17),"announcement claim synchronizes the authoritative wallet")
 await click(mail.close_button.get_global_rect().get_center());await frames()
 expect(not app.menu_popup_open(),"mailbox remains closable after the real encrypted claim")
 expect((await api({"action":"claim_announcement","id":"community-coins"},"first_player")).get("ok",false),"retry is safe and returns existing receipt")
 await verify_coin_grants()
 await api({"action":"set_role","username":"first_player","role":"tutorial_editor","enabled":false})
 app.tutorials();await until(func():return not app.online_community().syncing)
 expect(not app.tutorial_editor_available(),"revoked membership removes editor entry")
 login("bigcake");app.tutorials();await until(func():return not app.online_community().syncing)
 for mobile in [false,true]:
  app.is_android=mobile;app.refresh_ui_metrics()
  app.open_tournaments();await frames()
  expect(await until(func():return is_instance_valid(app.tournament_ui) and not app.tournament_ui.busy and app.tournament_ui.can_create),"organizer competition page finishes loading")
  var page=app.tournament_ui
  page.show_create();await frames()
  page.custom_stages.button_pressed=true;await frames()
  expect(page.stage_form.visible,"stage editor is visible on "+("Android" if mobile else "desktop"))
  expect(page.stage_form.capture() and page.stage_form.stages[0].points.win==3,"native stage controls generate valid scoring config")
  var scroll=page.find_child("TournamentCreateScroll",true,false)
  scroll.ensure_control_visible(page.stage_form.fields[0].kind);await frames()
  await shot("stages-android" if mobile else "stages-desktop")
  app.tutorial_editor();await frames()
  editor=app.screen.get_child(0)
  expect(editor.inspector.get_global_rect().end.x<=root.size.x,"tutorial editor fits horizontal viewport")
  await shot("tutorial-editor-android" if mobile else "tutorial-editor-desktop")
 finish()

func finish():
 print("COMMUNITY ONLINE: ",checks," checks; failures=",failures)
 if is_instance_valid(app):app.queue_free();await frames(2)
 quit(0 if failures.is_empty() else 1)
