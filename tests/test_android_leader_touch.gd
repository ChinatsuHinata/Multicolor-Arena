extends "res://tests/support/ui_base.gd"

func touch(at: Vector2):
 var event=InputEventScreenTouch.new()
 event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false
 root.push_input(event,true);await process_frame;await physics_frame

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/test-android-leader-touch/"+str(Time.get_ticks_usec()))
 root.size=Vector2i(1600,900)
 root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.is_android=true
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app.refresh_ui_metrics()
 app.load_legacy_test_decks()
 app.clear_page("battle")
 view=preload("res://scripts/duel_view.gd").new();view.is_android=true
 app.duel_view=view;app.screen.add_child(view)
 view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 view.begin(app,app.decks[app.player_choice],app.decks[app.ai_choice],0,42)
 view.set_process(false);e=view.engine
 clean()
 view.table.set_top_down_view(true)
 view.render();await settle()
 var leader=e.players[0].leader
 var at=point(leader.uid)
 var picked=[]
 view.table.object_selected.connect(func(uid):picked.append(uid))
 expect(view.table.card_at(view.stage_point(at))==leader.uid,"own leader has a 2D touch hitbox")
 expect(view.touch_camera_available(at),"own leader receives touches outside the camera gesture area")
 var enemy_at=point(e.players[1].leader.uid)
 expect(view.touch_camera_available(enemy_at),"enemy leader outside the gesture area receives card detail touches")
 await touch(at)
 expect(leader.uid in picked,"Android 2D tap selects the own leader")
 var cast_error=e.cast_error(0,leader.uid)
 expect(view.local.get("uid",0)==leader.uid if cast_error.is_empty() else view.message==cast_error,"leader tap reaches the cast action")
 view.cancel_cast()
 view.inspect_id="";view.update_inspection()
 await touch(enemy_at)
 expect(view.inspect_uid==e.players[1].leader.uid and view.inspection.visible,"native enemy leader tap opens its card details")
 view.inspect_id="";view.update_inspection()
 var hand_card=put("100","hand")
 view.render();await settle()
 var hand_tile=view.hand_nodes[hand_card.uid]
 hand_tile.position+=at-hand_tile.get_global_rect().get_center()
 expect(hand_tile.get_global_rect().has_point(at) and not view.touch_camera_available(at),"hand card keeps touch priority over an overlapping leader")
 print("ANDROID LEADER TOUCH: ",checks," checks; failures=",failures.size())
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
