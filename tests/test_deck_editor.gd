extends "res://tests/support/ui_base.gd"

func dialogs() -> Array:
 return app.get_children().filter(func(node):return node is AcceptDialog and not node.is_queued_for_deletion())

func write_fixture(path: String):
 var file=FileAccess.open(path,FileAccess.WRITE)
 file.store_string("fixture")
 file.close()

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/deck-editor-tests/"+str(Time.get_ticks_usec()))
 root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.editor()
 await process_frame
 expect(find_button(app.screen,"打开 deck 文件夹")!=null,"PC deck folder button is present")
 expect(app.DeckImage.folder()==Store.folder().path_join("image"),"folder button and capture use the same screenshot directory")
 var timer=app.get_node("DeletedDeckCleanupTimer")
 expect(not timer.is_stopped() and timer.wait_time==3600,"legacy deleted file cleanup runs every hour")
 app.is_android=true
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app.refresh_ui_metrics()
 app.editor()
 await process_frame

 var original=app.decks[0].duplicate(true)
 app.editor_ui.set_overview(true)
 var clipboard=""
 if DisplayServer.get_name()!="headless":
  clipboard=DisplayServer.clipboard_get()
  app.draft=app.decks[0].duplicate(true)
  app.dirty=false
  app.editor_ui.tools_menu.pressed.emit()
  app.menu_popup.actions[0].pressed.emit()
  await process_frame
  var code=DisplayServer.clipboard_get()
  expect(code==Store.encode(app.draft),"export copies the current deck code to the clipboard")
  expect(dialogs().is_empty(),"successful export opens no dialog")
  original=app.draft.duplicate(true)
  app.editor_ui.tools_menu.pressed.emit()
  app.menu_popup.actions[1].pressed.emit()
  await process_frame
  expect(app.draft.id!=original.id and app.draft.main==original.main and app.draft.side==original.side and app.dirty,"import creates an unsaved copy from the clipboard")
  expect(dialogs().is_empty(),"successful import opens no text dialog")
  original=app.draft.duplicate(true)
  DisplayServer.clipboard_set("invalid deck code")
  app.import_deck()
  await process_frame
  expect(app.draft==original and app.dirty,"invalid clipboard input preserves unsaved edits")
  expect(dialogs().size()==1 and dialogs()[0].title=="导入失败","invalid input shows an error")
  for dialog in dialogs():dialog.queue_free()
  await process_frame
  DisplayServer.clipboard_set(code)
  app.import_deck()
  await process_frame
  expect(app.draft==original and dialogs().size()==1 and dialogs()[0].title=="确认操作","import asks before replacing unsaved edits")
  dialogs()[0].canceled.emit()
  await process_frame
  expect(app.draft==original and app.dirty,"cancel keeps the edited deck")
  app.import_deck()
  await process_frame
  dialogs()[0].confirmed.emit()
  await process_frame
  expect(app.draft.id!=original.id and app.dirty and dialogs().is_empty(),"confirmed import replaces the draft without a text dialog")

 app.rename_dialog()
 await process_frame
 await process_frame
 var rename=dialogs()[0]
 var entry=rename.find_child("DeckNameEntry",true,false)
 expect(entry is LineEdit and entry.size.y>=entry.get_combined_minimum_size().y and entry.size.y<=app.ui_metrics.hit+8,"rename input fits the shared touch height")
 entry.text="单行名称"
 entry.text_submitted.emit(entry.text)
 await process_frame
 expect(app.draft.name=="单行名称" and dialogs().is_empty(),"Enter applies the new deck name")

 var incoming=Store.blank("直接删除测试")
 incoming.leader=original.leader
 expect(Store.save_file(incoming).is_empty(),"deletion fixture is saved")
 var path=Store.file_paths[incoming.id]
 expect(Store.delete_file(incoming.id).is_empty() and not FileAccess.file_exists(path),"delete removes the selected deck file")
 expect(Array(DirAccess.get_files_at(Store.folder())).all(func(name):return not name.ends_with(".deleted")),"delete creates no deleted files")
 expect(not Store.load_decks().decks.any(func(deck):return deck.id==incoming.id),"deleted deck remains absent after reload")
 var nested=Store.folder().path_join("子目录")
 DirAccess.make_dir_recursive_absolute(nested)
 var legacy=nested.path_join("旧卡组.mdeck.deleted")
 var timestamped=nested.path_join("旧卡组.mdeck.1234567890.deleted")
 var backup=path+".bak"
 var unrelated=nested.path_join("图片.png.deleted")
 for fixture in [legacy,timestamped,backup,unrelated]:write_fixture(fixture)
 var active=Store.scan_files(Store.folder())
 timer.timeout.emit()
 expect(not FileAccess.file_exists(legacy) and not FileAccess.file_exists(timestamped),"timer removes nested legacy deleted deck files")
 expect(FileAccess.file_exists(backup) and FileAccess.file_exists(unrelated) and Store.scan_files(Store.folder())==active,"cleanup preserves active decks, backups and unrelated files")
 write_fixture(legacy)
 Store.load_decks()
 expect(not FileAccess.file_exists(legacy),"deck reload also cleans legacy deleted files")
 if DisplayServer.get_name()!="headless":DisplayServer.clipboard_set(clipboard)
 print("DECK EDITOR: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
