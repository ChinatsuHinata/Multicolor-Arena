extends "res://tests/support/ui_base.gd"
const Archive=preload("res://scripts/replay_archive.gd")
var fixture="res://work/external-replay-ui/"+str(Time.get_ticks_usec())
class FakeInbox extends Node:
 var acknowledged=[]
 func acknowledge(path: String):acknowledged.append(path)
class BusyRoom extends Node:
 var room_id="TEST_ONLY_ROOM"
 var joining=false
 var matchmaking=false
func frames(count: int=5):
 for i in range(count):await process_frame
func dismiss_dialogs():
 for child in app.get_children():
  if child is AcceptDialog:child.hide();child.queue_free()
 await frames()
func replay_files() -> PackedStringArray:
 return DirAccess.get_files_at(Store.Paths.root().path_join("replay"))
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 Store.Paths.initialize()
 root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate()
 app.settings_path=fixture+"/settings.json";app.account_session_path=fixture+"/account.json";app.tutorial_local_directory=fixture+"/tutorials"
 root.add_child(app);await frames();app.is_android=true;app.load_legacy_test_decks()
 app.begin_battle(true);view=app.duel_view;view.set_process(false);await frames()
 var path=fixture+"/external.mreply"
 expect(view.replay_recording.save(path).has("path"),"external replay fixture saves")
 app.menu();await frames();await dismiss_dialogs()
 var inbox=FakeInbox.new();app.add_child(inbox);app.android_replay_inbox=inbox
 var bad=fixture+"/invalid.mreply";var file=FileAccess.open(bad,FileAccess.WRITE);file.store_string("not a replay");file.close()
 app.receive_external_replay(bad,"invalid.mreply")
 expect(app.page=="menu" and replay_files().is_empty(),"invalid external file cannot replace the screen or enter the replay library")
 expect(inbox.acknowledged.has(bad),"invalid delivery is acknowledged instead of looping at startup")
 await dismiss_dialogs()
 app.receive_external_replay(path,"../../外部回放.mreply");await frames()
 expect(app.page=="battle" and is_instance_valid(app.replay_controller),"file-manager delivery opens replay playback")
 expect(replay_files().size()==1 and replay_files()[0].begins_with("外部回放_"),"imported replay uses a safe basename inside the replay library")
 expect(inbox.acknowledged.has(path),"successful persisted import acknowledges its temporary delivery")
 var imported=Store.Paths.root().path_join("replay").path_join(replay_files()[0])
 expect(Archive.read(imported).has("archive"),"persisted external replay passes the complete archive validator")
 var first_player=app.replay_controller
 app.receive_external_replay(path,"warm.mreply");await frames()
 expect(app.page=="battle" and app.replay_controller!=first_player and replay_files().size()==2,"warm delivery replaces playback and preserves both imports")
 app.replays();await frames()
 expect(not app.replay_history_tab and find_button(app.screen,"已保留").button_pressed,"returning from an external replay selects the saved library")
 var imported_row=app.screen.find_child("ReplayPlay",true,false)
 expect(imported_row!=null,"imported recordings appear in the shared replay browser")
 if imported_row!=null:
  imported_row.pressed.emit();await frames()
  expect(app.page=="battle" and is_instance_valid(app.replay_controller),"saved browser reopens external recordings through the shared player")
 expect(preload("res://scripts/replay_library.gd").entries(true).is_empty(),"importing and viewing replays does not add completed-match history")
 app.menu();await frames();app.dirty=true
 var draft=app.draft.duplicate(true)
 app.receive_external_replay(path,"draft.mreply")
 expect(app.page=="menu" and app.dirty and app.draft==draft,"external replay preserves unsaved deck edits")
 expect(replay_files().size()==3,"busy editor delivery remains available in the replay library")
 app.dirty=false;await dismiss_dialogs()
 app.begin_battle(true);view=app.duel_view;view.set_process(false);await frames()
 app.receive_external_replay(path,"battle.mreply")
 expect(app.duel_view==view and view.get_parent()==app.screen and view.engine.phase!="over","external replay does not replace or surrender the active battle")
 await dismiss_dialogs();app.menu();await frames()
 var room=BusyRoom.new();app.add_child(room);app.lan_session=room
 app.receive_external_replay(path,"room.mreply")
 expect(app.page=="menu" and room.room_id=="TEST_ONLY_ROOM","external replay does not leave an online room")
 app.lan_session=null;room.queue_free();await dismiss_dialogs()
 var before=inbox.acknowledged.size()
 var root_before=Store.Paths.root_override
 var blocked=fixture+"/not-a-directory";file=FileAccess.open(blocked,FileAccess.WRITE);file.store_string("fixture");file.close()
 Store.Paths.root_override=ProjectSettings.globalize_path(blocked)
 app.receive_external_replay(path,"retry.mreply")
 expect(inbox.acknowledged.size()==before and FileAccess.file_exists(path),"failed persistent import retains the delivery for retry")
 Store.Paths.root_override=root_before;await dismiss_dialogs()
 expect(app.open_replay(imported),"shared in-app replay opener accepts an imported archive")
 await frames();expect(app.page=="battle" and is_instance_valid(app.replay_controller),"imported replay can be reopened from the library")
 print("EXTERNAL REPLAY UI ",checks," checks; failures=",failures)
 app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
