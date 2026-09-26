extends "res://tests/support/ui_base.gd"
const Session=preload("res://net/lan_session.gd")
func capture(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/portable-"+name+".png")
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/portable-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 expect(app.decks.size()==4,"four presets visible on first launch")
 await capture("menu")
 app.editor();await process_frame
 var incoming=Store.blank("朋友发来的卡组");incoming.leader=app.decks[0].leader;incoming.main=app.decks[0].main.duplicate()
 Store.save_file(incoming,Store.folder().path_join("朋友的卡组.mdeck"))
 app.menu();app.editor();await process_frame
 expect(app.decks.size()==5 and app.saved_select.item_count==6,"editor re-entry refreshes copied files and selector")
 app.draft=incoming.duplicate(true);app.draft.name="已编辑的分享牌组";app.dirty=true;app.save_deck()
 expect(Store.read_file(Store.folder().path_join("朋友的卡组.mdeck")).deck.name==app.draft.name and not app.dirty,"editor save writes selected portable file")
 app.delete_current_deck()
 expect(app.decks.size()==4 and not FileAccess.file_exists(Store.folder().path_join("朋友的卡组.mdeck")),"editor delete removes file from active library")
 app.setup();app.begin_battle(true);view=app.duel_view;e=view.engine
 await settle()
 expect(view.replay_recording.frames.size()>0,"offline game records initial and AI states")
 e.surrender(0);view.render();await process_frame
 var dialogs=app.get_children().filter(func(n):return n is ConfirmationDialog and n.title=="保存回放")
 expect(dialogs.size()==1,"offline finish prompts save once")
 view.render();await process_frame
 expect(app.get_children().filter(func(n):return n is ConfirmationDialog and n.title=="保存回放").size()==1,"redraw cannot duplicate save prompt")
 var archive=view.replay_recording
 dialogs[0].confirmed.emit();await process_frame
 expect(DirAccess.get_files_at(Store.Paths.root().path_join("replay")).size()==1,"accept creates one mreply file")
 for child in app.get_children():
  if child is AcceptDialog:child.queue_free()
 app.replays();await process_frame
 var filename=DirAccess.get_files_at(Store.Paths.root().path_join("replay"))[0]
 var open_button=find_button(app.screen,filename)
 expect(open_button!=null,"replay file discovered in replay menu")
 open_button.pressed.emit();await process_frame
 var player=app.replay_controller;view=app.duel_view
 expect(view.network_locked() and view.network_session.replay_mode,"playback is read only")
 expect(view.engine.players==archive.frame(0).projection.state.players,"initial replay state exactly matches recording")
 await settle();await capture("replay")
 player.seek(archive.frames.size()-1);view=app.duel_view;await process_frame
 expect(view.engine.winner==1 and not view.modal,"seeking final frame restores recorded winner without play dialog")
 expect(player.index==archive.frames.size()-1 and not player.playing,"manual seek pauses playback")
 player.seek(0);view=app.duel_view;player.speed=4;player.playing=true
 await create_timer(3).timeout
 expect(player.index>0,"play advances through recorded states")
 player.playing=false
 player.seek(0);view=app.duel_view
 var uid=view.engine.players[0].hand[0].uid;view.hand_clicked(uid)
 expect(view.selection.is_empty() and view.local.is_empty(),"replay clicks cannot cast or choose mulligan")
 view.browse_zone(1,"deck");await process_frame
 expect(view.browser_cards.get_children().all(func(n):return n.get_meta("display_id")=="back"),"replay preserves hidden library")
 expect(view.browser_panel.get_global_rect().end.y<646,"replay pile browser leaves playback controls clear")
 view.close_debug();view.open_history();await process_frame
 expect(not player.controls.visible,"history remains above replay controls")
 view.close_history();await process_frame
 expect(player.controls.visible,"closing history restores replay controls")
 view.close_debug();await capture("replay-final")
 app.replays();await process_frame
 expect(app.page=="replays","playback can return to list")
 # A public snapshot uses the same real battlefield, with neither hand exposed.
 var engine=Session.Duel.new();engine.start(app.decks[0],app.decks[1],0,42)
 var public_view=preload("res://net/observer_projection.gd").build(engine)
 var observer=Session.new();app.add_child(observer);observer.initialize(Store.Paths.root().path_join("observer"));observer.read_only=true;observer.connected=true;observer.paused=false;observer.remote_last_seen=Time.get_ticks_msec()
 var series=Session.Series.new();series.setup(3,false);series.state.status="playing";series.state.game_id="visual"
 observer.room=series.public_state(-1);observer.room_id="visual"
 observer.enqueue_snapshot({"game_id":"visual","sequence":1,"room":observer.room,"projection":public_view})
 app.lan_session=observer;app.return_network_battle();view=app.duel_view;await settle()
 expect(view.network_locked() and view.engine.players.all(func(p):return p.hand.all(func(c):return c.card_id=="back")),"spectator UI hides both hands and disables interactions")
 expect(find_button(view.ui,"返回联机房间")!=null and find_button(view.ui,"保留")==null,"spectator has navigation without decision buttons")
 await capture("spectator")
 observer.leave(false)
 print("PORTABLE UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
