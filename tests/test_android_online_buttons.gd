extends "res://tests/support/ui_base.gd"

class PreviewSession:
 extends RefCounted
 var room={"undo_request":{},"undo_available":true}
 var replay_mode=false
 var read_only=false
 var connected=true
 var paused=false
 var last_action={}
 func ended() -> bool:return false
 func can_act(_in_match: bool=false) -> bool:return room.undo_request.is_empty()
 func latency_text() -> String:return "42 ms"
 func room_action(action: Dictionary):last_action=action

func capture(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/android-online-buttons-"+name+".png")

func run():
 root.size=Vector2i(1280,720)
 root.gui_embed_subwindows=true
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-online-buttons-session/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.is_android=true
 app.layout_dpi_override=240.0
 app.layout_safe_override=Rect2(24,0,1232,696)
 app.refresh_ui_metrics();app.load_legacy_test_decks()
 app.clear_page("battle")
 view=preload("res://scripts/duel_view.gd").new();view.is_android=true
 app.duel_view=view;app.screen.add_child(view)
 view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 view.begin(app,app.decks[app.player_choice],app.decks[app.ai_choice],0,42)
 view.set_process(false)
 var preview=PreviewSession.new()
 var remote=preload("res://net/remote_duel.gd").new()
 remote.session=preview;remote.seat=0
 view.engine=remote;view.table.duel=remote;e=remote
 view.network_session=preview
 clean()
 for id in ["53","100","164","169"]:e.players[0].hand.append(e.make_card(id,0,"hand"))
 for id in ["53","100","164","169"]:e.players[1].hand.append(e.make_card(id,1,"hand"))
 e.player_names=["你","对手"]
 view.render();await process_frame
 var menu=view.hud.get_node("BattleToolbar/BattleTools") as Button
 await click(menu.get_global_rect().get_center());await process_frame
 var popup=view.android_battle_menu_root
 var undo=find_button(popup,"请求悔棋")
 var match_exit=popup.find_child("BattleMenuMatchExit",true,false) as Button
 expect(match_exit!=null and match_exit.text=="投降" and find_button(popup,"离开对战")==null,"active match shows one surrender action")
 expect(match_exit!=null and (match_exit.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.r>0.35,"match exit action is red")
 expect(find_button(popup,"聊天")==null,"online battle menu has no chat entry")
 expect(undo!=null and not undo.disabled,"undo request is available in the unified menu")
 expect(find_button(view.hud,"悔棋")==null,"no loose undo button remains on the right rail")
 expect(view.network_latency_label.get_global_rect().end.x<=view.responsive.safe.end.x,"latency remains inside the safe area")
 if undo!=null:await click(undo.get_global_rect().get_center())
 expect(preview.last_action.get("name")=="undo_request","menu sends the undo request action")
 await capture("active")
 menu.pressed.emit();await process_frame
 await capture("menu")
 view.close_android_battle_menu()
 preview.room.undo_request={"id":123,"from":1-view.local_seat}
 view.render();await process_frame
 var panel=view.hud.get_node_or_null("UndoRequestPanel") as Control
 var accept=find_button(panel,"同意") if panel!=null else null
 var decline=find_button(panel,"拒绝") if panel!=null else null
 expect(panel!=null and view.SIDEBAR.encloses(panel.get_global_rect()),"undo request uses the right sidebar")
 expect(accept!=null and decline!=null and panel.get_global_rect().encloses(accept.get_global_rect()) and panel.get_global_rect().encloses(decline.get_global_rect()),"accept and decline fit inside the request panel")
 expect(accept!=null and not accept.get_global_rect().intersects(view.android_back_button.get_global_rect()),"request buttons leave the persistent back button clear")
 expect(accept!=null and decline!=null and not accept.disabled and not decline.disabled,"both request choices stay enabled while gameplay is locked")
 if accept!=null:
  await click(accept.get_global_rect().get_center())
  expect(preview.last_action.get("name")=="undo_accept" and preview.last_action.get("ticket")==123,"touching agree sends the matching ticket")
 if decline!=null:
  await click(decline.get_global_rect().get_center())
  expect(preview.last_action.get("name")=="undo_decline" and preview.last_action.get("ticket")==123,"touching decline sends the matching ticket")
 menu=view.hud.get_node("BattleToolbar/BattleTools")
 expect(not menu.disabled,"battle menu remains available while an undo request locks gameplay")
 await click(menu.get_global_rect().get_center());await process_frame
 popup=view.android_battle_menu_root
 expect(find_button(popup,"请求悔棋")==null,"pending request has no duplicate request action")
 view.close_android_battle_menu()
 await capture("undo-request")
 preview.room.undo_request={"id":124,"from":view.local_seat}
 view.render();await process_frame
 expect(find_button(view.hud,"取消请求")!=null and find_button(view.hud,"同意")==null,"own request only offers cancellation")
 preview.room.undo_request={}
 preview.read_only=true
 view.render();await process_frame
 await click(view.hud.get_node("BattleToolbar/BattleTools").get_global_rect().get_center());await process_frame
 popup=view.android_battle_menu_root
 match_exit=popup.find_child("BattleMenuMatchExit",true,false) as Button
 expect(match_exit!=null and match_exit.text=="离开对战" and not match_exit.disabled and find_button(popup,"投降")==null,"spectator sees one leave-match action")
 view.close_android_battle_menu()
 print("ANDROID ONLINE BUTTONS: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
