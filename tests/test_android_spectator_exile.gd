extends "res://tests/support/ui_base.gd"

class PreviewSession:
 extends RefCounted
 var room={"undo_request":{},"status":"playing"}
 var read_only=true
 var replay_mode=false
 var connected=true
 var paused=false
 func ended() -> bool:return false
 func can_act(_in_match: bool=false) -> bool:return false
 func latency_text() -> String:return "42 ms"
 func connection_status() -> String:return "观战 · 公开视角"

func frames(count: int=3):
 for i in range(count):await process_frame

func tap(button: Control):
 var at=button.get_global_rect().get_center()
 var press=InputEventScreenTouch.new();press.position=at;press.pressed=true
 root.push_input(press,true);await frames()
 press=press.duplicate();press.pressed=false
 root.push_input(press,true);await frames()

func run():
 root.size=Vector2i(1280,720);root.gui_embed_subwindows=true
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-spectator-exile/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 app.is_android=true;app.layout_dpi_override=240.0
 app.layout_safe_override=Rect2(24,0,1232,696)
 app.refresh_ui_metrics();app.load_legacy_test_decks();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine
 for who in range(2):
  e.players[who].exile.clear()
  put("100" if who==0 else "169","exile",who)
 e.phase="main";e.turn=6;e.active=0;e.priority=0;e.pending={};e.combat={}
 e.presentation_events.clear();view.reveal_player.reset()
 view.modal=false
 var projection=preload("res://net/observer_projection.gd").build(e)
 var remote=preload("res://net/remote_duel.gd").new()
 remote.apply_snapshot(projection);remote.seat=1
 e=remote;view.engine=remote;view.table.duel=remote
 view.network_session=PreviewSession.new();remote.session=view.network_session
 view.local_seat=1;view.table.local_seat=1
 view.inspect_id="";view.update_inspection()
 view.render();await frames()
 var shortcut=view.android_zone_shortcuts.buttons.exile
 expect(shortcut.is_visible_in_tree() and not shortcut.disabled,"spectator can open exile shortcut")
 await tap(shortcut)
 expect(view.debug_open and view.browser_zone=="exile" and view.browser_owner==1,"spectator exile opens the nearby seat")
 var tabs=view.browser_panel.get_node_or_null("ExileOwnerTabs") if view.browser_panel!=null else null
 expect(tabs!=null and tabs.get_node_or_null("ExileOwner0")!=null,"spectator sees the other seat's exile tab")
 if tabs!=null:
  expect(not tabs.get_node("ExileOwner0").disabled,"opponent exile tab remains enabled for read-only spectators")
  await tap(tabs.get_node("ExileOwner0"))
  expect(view.debug_open and view.browser_owner==0 and view.browser_zone=="exile","spectator switches to the opponent's exile")
  expect(view.browser_cards.get_child_count()==1 and view.browser_cards.get_child(0).get_meta("display_id")=="100","opponent exile card is visible by identity")
 view.close_debug();view.local_seat=0;view.table.local_seat=0;remote.seat=0
 view.render();await frames()
 await tap(view.android_zone_shortcuts.buttons.exile)
 tabs=view.browser_panel.get_node_or_null("ExileOwnerTabs") if view.browser_panel!=null else null
 expect(tabs!=null and tabs.get_node_or_null("ExileOwner1")!=null and not tabs.get_node("ExileOwner1").disabled,"LAN spectator can select the opposite seat")
 if tabs!=null:
  await tap(tabs.get_node("ExileOwner1"))
  expect(view.browser_owner==1 and view.browser_cards.get_child_count()==1 and view.browser_cards.get_child(0).get_meta("display_id")=="169","LAN spectator sees the opponent's public exile card")
 print("ANDROID SPECTATOR EXILE: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
