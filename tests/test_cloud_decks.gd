extends "res://tests/support/ui_base.gd"
const Cloud=preload("res://scripts/private_cloud_decks.gd")
const Memory=preload("res://scripts/match_deck_memory.gd")
var output="res://work/cloud-decks"

func frames(count: int=5):
 for i in range(count):await process_frame

func idle(store):
 var deadline=Time.get_ticks_msec()+20000
 while store.busy and Time.get_ticks_msec()<deadline:await create_timer(0.02).timeout
 expect(not store.busy,"cloud operation finishes within the timeout")

func activate(button: Button):
 if DisplayServer.get_name()=="headless":button.pressed.emit()
 else:await click(button.get_global_rect().get_center())
 await frames()

func confirmation():
 for child in app.get_children():
  if child is ConfirmationDialog and not child.is_queued_for_deletion():return child
 return null

func run():
 var manifest=JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
 var clients=manifest.clients
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures-"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate()
 app.settings_path=output.path_join("settings.json");app.account_session_path=output.path_join("session.json")
 app.tutorial_local_directory=output.path_join("tutorials");root.add_child(app);await frames()
 app.account_name=clients[0].username;app.account_token=clients[0].token
 var store=app.cloud_decks_store();store.server_url=manifest.endpoint
 app.sync_private_cloud_decks();await idle(store)
 expect(store.decks.is_empty() and store.status.begins_with("已同步"),"login automatically fetches the account's private slots")
 var source=app.RemiliaChallenge.deck();source.id="local_upload_source";source.name="名称保留（副本）"
 expect(Store.save_file(source).is_empty(),"create local upload source")
 app.reload_decks();app.draft=source.duplicate(true);app.dirty=true;app.remember_match_deck(source.id)
 app.draft.name="未保存的改名（副本）";source.name=app.draft.name
 app.editor();app.open_cloud_deck_slots();await idle(store);await frames()
 var empty_gallery=app.deck_picker_ui
 expect(empty_gallery.entries.is_empty() and not empty_gallery.upload_button.disabled,"empty cloud gallery offers upload of the current deck")
 if DisplayServer.get_name()=="headless":empty_gallery.upload_button.pressed.emit()
 else:await click(empty_gallery.upload_button.get_global_rect().get_center())
 await idle(store)
 if store.decks.is_empty():
  expect(false,"cloud upload succeeds: "+store.status)
  quit(1);return
 expect(store.decks.size()==1 and not app.draft.has("cloud_slot") and app.dirty,"gallery upload leaves the local editing draft in place")
 expect(Store.file_paths.has(source.id),"upload preserves the local source file")
 expect(Memory.selected(app.account_name)==source.id,"upload preserves the remembered local matching deck")
 expect(store.decks[0].name==source.name and store.decks[0].art_overrides==source.art_overrides,"sync preserves exact names, card order and alternate art")
 app.close_deck_picker();await frames()
 var local=source.duplicate(true);local.id="local_upload";local.name="保留本地的上传";local.main.pop_back()
 expect(Store.save_file(local).is_empty(),"save local upload source")
 var local_snapshot=Store.read_file(Store.file_paths[local.id]).deck
 app.reload_decks();app.draft=local.duplicate(true);app.draft.name="未保存的上传标题";app.dirty=true
 var upload_snapshot=app.draft.duplicate(true);var answer={}
 app.upload_private_deck(func(result):answer.merge(result,true));await idle(store)
 expect(answer.get("ok",false) and store.decks.size()==2,"upload accepts the current unsaved draft")
 expect(app.draft==upload_snapshot and app.dirty and Store.read_file(Store.file_paths[local.id]).deck==local_snapshot,"upload preserves the local file and unsaved editor draft")
 var uploaded=store.decks.filter(func(deck):return deck.name==upload_snapshot.name)[0]
 answer.clear();store.delete_deck(uploaded,func(result):answer.merge(result,true));await idle(store)
 app.draft=store.decks[0].duplicate(true);app.dirty=false
 var second=Cloud.new();root.add_child(second);second.server_url=manifest.endpoint
 second.set_session(clients[1].username,clients[1].token);await idle(second)
 expect(second.decks==store.decks,"a new device automatically downloads every cloud deck")
 var stale=second.decks[0].duplicate(true)
 app.draft.name="另一台设备的最新卡组";app.dirty=true;app.save_deck();await idle(store)
 expect(not app.dirty and store.decks[0].name=="另一台设备的最新卡组","normal editor save updates the cloud deck")
 answer.clear()
 second.save_deck(stale,func(result):answer.merge(result,true));await idle(second)
 expect(answer.get("conflict",false),"stale device cannot overwrite a newer cloud save")
 second.refresh();await idle(second)
 expect(second.decks==store.decks,"manual sync fetches the newer device revision")
 for i in range(9):
  var deck=source.duplicate(true);deck.name="云端槽位 %d" % (i+2)
  deck.main.resize(source.main.size()-i-2)
  answer.clear();second.save_deck(deck,func(result):answer.merge(result,true));await idle(second)
  expect(answer.get("ok",false),"fill a free private slot")
 answer.clear();second.save_deck(source,func(result):answer.merge(result,true));await idle(second)
 expect(not answer.get("ok",true) and second.decks.size()==10,"eleventh cloud deck is refused without overwriting existing slots")
 store.refresh();await idle(store)
 var rejected=source.duplicate(true);rejected.id="full_upload_source"
 expect(Store.save_file(rejected).is_empty(),"save local source before testing full cloud account")
 app.reload_decks();app.draft=rejected.duplicate(true);app.dirty=true
 answer.clear();app.upload_private_deck(func(result):answer.merge(result,true));await idle(store)
 expect(not answer.get("ok",true) and app.draft==rejected and app.dirty and Store.file_paths.has(rejected.id),"a rejected upload preserves the local file and unsaved draft")
 var duplicate=Store.clean_deck(store.decks[0]);duplicate.id="same_name_cloud_download_fixture"
 expect(Store.save_file(duplicate).is_empty(),"save a local fixture with the cloud deck's name and contents")
 for dialog in app.get_children():
  if dialog is AcceptDialog:dialog.queue_free()
 app.dirty=false;await frames()
 for android in [false,true]:
  root.size=Vector2i(1280,720) if android else Vector2i(1600,900)
  app.is_android=android;app.layout_dpi_override=360 if android else 0
  app.editor();await frames()
  app.open_cloud_deck_slots();await idle(store);await frames()
  var dialog=app.deck_picker_ui
  expect(dialog.entries.size()==10 and dialog.gallery!=null,"both editors open a cloud card gallery")
  expect(dialog.upload_button.disabled,"full account disables uploading another local deck")
  expect(dialog.download_button.disabled and dialog.delete_button.disabled,"cloud actions require a selection")
  var safe=app.screen.get_global_rect().grow(1)
  var controls=[dialog.search,dialog.sort_choice,dialog.upload_button,dialog.refresh_button,dialog.download_button,dialog.delete_button,dialog.previous_button,dialog.next_button,dialog.status_label]
  expect(controls.all(func(control):return safe.encloses(control.get_global_rect())),"cloud gallery controls fit the device safe area")
  var seen={}
  while true:
   for entry in dialog.matches.slice(dialog.page_index*dialog.page_size,(dialog.page_index+1)*dialog.page_size):seen[entry.deck.id]=true
   expect(dialog.gallery.get_global_rect().grow(1).encloses(dialog.grid.get_global_rect()),"each cloud gallery page fits its viewport")
   if dialog.next_button.disabled:break
   dialog.turn_page(1);await frames()
  expect(seen.size()==10,"pagination reaches every cloud deck")
  var chosen=store.decks[0]
  dialog.search.text=chosen.name;dialog.apply_search();await frames()
  expect(dialog.matches.size()==1,"cloud gallery searches by deck name")
  var first=dialog.find_child("CloudDeckSlot_1",true,false)
  if DisplayServer.get_name()=="headless":first.pressed.emit()
  else:await click(first.get_global_rect().get_center())
  await frames()
  expect(dialog.selected_id==chosen.id and not dialog.download_button.disabled and not dialog.delete_button.disabled,"selecting a cloud tile enables management actions")
  var draft_snapshot=app.draft.duplicate(true)
  dialog.download_selected()
  expect(dialog.status_label.text.contains("本地有重复卡组") and app.draft==draft_snapshot,"cloud download refuses the same name and identical local contents and preserves the draft")
  var downloadable=store.decks[2 if android else 1]
  dialog.search.text=downloadable.name;dialog.apply_search();await frames()
  dialog.choose(downloadable.id);dialog.download_selected()
  var downloaded=Store.load_decks().decks.filter(func(deck):return deck.name==downloadable.name)
  expect(downloaded.size()==1 and downloaded[0].id!=downloadable.id and not downloaded[0].has("cloud_slot"),"cloud page downloads an independent local deck")
  expect(dialog.status_label.text.begins_with("已下载") and app.draft==draft_snapshot,"successful download keeps the current editor draft intact")
  dialog.download_selected()
  expect(dialog.status_label.text.contains("本地有重复卡组"),"cloud page refuses a repeated download")
  dialog.reset_search();await frames()
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(output.path_join("slots-android.png" if android else "slots-desktop.png"))
  await activate(dialog.delete_button)
  var confirm=confirmation()
  expect(confirm!=null and store.decks.size()==10,"deleting from the gallery asks before changing the cloud list")
  var cancel=InputEventKey.new();cancel.keycode=KEY_ESCAPE;cancel.pressed=true
  dialog.handle_input(cancel)
  expect(app.deck_picker_ui==dialog,"cancel input leaves the confirmation in charge of the cloud page")
  if DisplayServer.get_name()=="headless":confirm.canceled.emit()
  else:await click(Vector2(confirm.position)+confirm.get_cancel_button().get_global_rect().get_center())
  await frames()
  expect(store.decks.size()==10 and dialog.selected_id==downloadable.id,"canceling deletion keeps the deck selected")
  await activate(dialog.delete_button);confirm=confirmation()
  if DisplayServer.get_name()=="headless":confirm.confirmed.emit()
  else:await click(Vector2(confirm.position)+confirm.get_ok_button().get_global_rect().get_center())
  await idle(store);await frames()
  expect(store.decks.size()==9 and app.deck_picker_ui==dialog and dialog.selected_id.is_empty(),"confirmed deletion refreshes the cloud list and keeps the gallery open")
  expect(app.draft==draft_snapshot and Store.read_file(Store.file_paths[downloaded[0].id]).has("deck"),"cloud deletion preserves the editor draft and downloaded local copy")
  expect(not dialog.upload_button.disabled,"deleting a cloud deck makes room for upload")
  await activate(dialog.upload_button);await idle(store);await frames()
  expect(store.decks.size()==10 and app.draft==draft_snapshot and dialog.upload_button.disabled,"gallery upload fills the released slot and preserves the current deck")
  app.close_deck_picker();await frames()
  expect(not app.deck_picker_open() and app.page=="editor","back returns to the current editing deck")
 var removed=second.decks[0].duplicate(true)
 answer.clear();second.delete_deck(removed,func(result):answer.merge(result,true));await idle(second)
 expect(answer.get("ok",false) and second.decks.size()==9,"release removes one cloud slot")
 store.refresh();await idle(store)
 expect(store.decks.size()==9 and store.decks.all(func(deck):return deck.cloud_slot!=removed.cloud_slot),"deletion synchronizes to the other device")
 app.remember_match_deck(removed.id)
 answer.clear();second.save_deck(source,func(result):answer.merge(result,true));await idle(second)
 store.refresh();await idle(store)
 expect(app.remembered_match_deck_index("official")==-1,"reusing a released slot never selects a different deck as the remembered match deck")
 second.set_session(clients[2].username,clients[2].token);await idle(second)
 expect(second.decks.is_empty(),"switching accounts clears old decks before fetching the new account")
 answer.clear();second.save_deck(removed,func(result):answer.merge(result,true))
 expect(not answer.get("ok",true),"a cloud draft cannot be saved into another account")
 second.set_session("","");expect(second.decks.is_empty() and not second.busy,"logout clears the cloud collection")
 second.queue_free();app.queue_free();await frames();Store.Paths.root_override=""
 print("CLOUD DECKS: ",checks," checks, ",failures.size()," failures")
 quit(1 if failures.size() else 0)
