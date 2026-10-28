extends "res://tests/support/ui_base.gd"
const Library=preload("res://scripts/replay_library.gd")
const Browser=preload("res://scripts/replay_browser.gd")
const Archive=preload("res://scripts/replay_archive.gd")
func frames(count: int=4):
 for i in range(count):await process_frame
func run():
 var fixture="res://work/replay-browser-ui/"+str(Time.get_ticks_usec())
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 app=load("res://main.tscn").instantiate();app.settings_path=fixture+"/settings.json";app.account_session_path=fixture+"/account.json"
 root.size=Vector2i(1600,900);root.gui_embed_subwindows=true;root.add_child(app);await frames()
 app.setup();app.begin_battle(true);view=app.duel_view;e=view.engine
 e.surrender(0);view.reveal_player.reset();view.render();await frames()
 var recording=view.replay_recording
 expect(not recording.history_path.is_empty(),"desktop match automatically enters history")
 app.replays();await frames()
 var scroll=app.screen.get_node("ReplayScroll")
 expect(scroll.get_child(0).get_child_count()==1,"desktop history lists completed match")
 for action in app.screen.find_children("Replay*","Button",true,false):
  expect(scroll.get_global_rect().encloses(action.get_global_rect()),"desktop action fits history list: "+action.name)
 await capture("replay-history-pc")
 app.screen.find_child("ReplayKeep",true,false).pressed.emit();await frames()
 expect(Library.entries().size()==1 and Library.entries(true).size()==1,"desktop keep preserves both history and saved copy")
 find_button(app.screen,"已保留").pressed.emit();await frames()
 app.screen.find_child("ReplayExport",true,false).pressed.emit();await frames()
 var picker=app.find_child("ReplayExportPicker",true,false)
 var export_path=Store.Paths.root().path_join("saved-export.mreply")
 picker.file_selected.emit(export_path);await frames()
 expect(FileAccess.get_file_as_bytes(export_path)==FileAccess.get_file_as_bytes(recording.history_path),"saved tab exports the selected archive verbatim")
 for child in app.get_children():
  if child is AcceptDialog:child.queue_free()
 await frames()
 await capture("replay-saved-pc")
 var legacy=Archive.read(export_path).archive;legacy.metadata.rules="older-game-rules"
 var legacy_path=Store.Paths.root().path_join("legacy.mreply");legacy.save(legacy_path)
 Browser.open(app,legacy_path);await frames()
 var player=app.replay_controller
 expect(player.latest_snapshot==app.duel_view.network_session.latest_snapshot,"old rules open in desktop playback")
 player.seek(player.archive.frames.size()-1);await frames()
 expect(player.room.status=="complete" and app.duel_view.engine.winner in [0,1],"old rules reach the recorded result")
 var original=player.archive.frames[0].bytes
 var errors=[];player.error_raised.connect(func(message):errors.append(message))
 var before=player.index;player.archive.frames[0].bytes=PackedByteArray();player.playing=true;player.seek(0)
 expect(not player.playing and player.index==before and errors.size()==1 and errors[0].contains("第 1 步"),"unreadable step stops playback with an actionable error and retains the last valid state")
 player.archive.frames[0].bytes=original;player.seek(0);await frames()
 expect(player.index==0,"valid steps remain seekable after an error")
 print("REPLAY BROWSER UI: ",checks," checks; ",failures.size()," failures")
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
