extends "res://tests/support/ui_base.gd"
## Real viewport input against the production board, including projected online views.
const Session=preload("res://net/lan_session.gd")
const Remote=preload("res://net/remote_duel.gd")
const Observer=preload("res://net/observer_projection.gd")
const Seat=preload("res://net/seat_projection.gd")
const GROUPS=["leader","melody","item","barrier","time"]
var board
var authority
var session
var remote
var fixture="res://work/battle-region-clickability/"+str(Time.get_ticks_usec())
var input_kind="touch"
var context=""

func frames(count: int=3):
 for i in range(count):await process_frame

func redraw():
 view.render();await frames();view.banner.hide()

func tap(node: Control):
 expect(is_instance_valid(node) and node.is_visible_in_tree(),context+" visible click target")
 if not is_instance_valid(node) or not node.is_visible_in_tree():return
 await tap_at(node.get_global_rect().get_center())

func tap_at(at: Vector2):
 if input_kind=="mouse":
  var motion=InputEventMouseMotion.new();motion.position=at;motion.global_position=at
  root.push_input(motion,true);await frames(1)
 for pressed in [true,false]:
  var event
  if input_kind=="touch":
   event=InputEventScreenTouch.new();event.index=0
  else:
   event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.global_position=at
  event.position=at;event.pressed=pressed;root.push_input(event,true);await frames(2)
 await frames()

func back():
 var event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=true
 root.push_input(event,true);await frames()
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func reset_ui():
 view.inspect_id="";view.update_inspection();view.close_debug();view.close_overlay()
 view.local={};view.selection=[];view.picker.reset();view.android_action_uid=0;view.clear_attack_preview()
 board.opened={};view.android_palette_view=false;view.android_focus_owner=view.local_seat
 view.android_camera_restore={};view.android_auto_focus_owner=-1;view.android_manual_focus_override=-1
 await redraw()

func fill():
 clean();view.debug_mode=false;view.replay_recording.finished=true
 for who in range(2):
  put("53","field",who).entered_turns=0
  for kind in ["乐章","道具","结界","时符"]:
   for id in e.cards:
    var info=e.cards[id]
    if info.kind==kind or kind in ["乐章","时符"] and kind in info.get("spell_type",""):
     put(id,"field",who);break
  for zone in ["palette","grave","exile","hand","deck"]:
   for i in range(2):put("164" if zone=="palette" else "53",zone,who)
 e.presentation_events.clear();view.reveal_player.reset()
 authority=e

func check_region(who: int,group: String,empty: bool=false):
 await reset_ui()
 var label=context+" owner="+str(who)+" "+group+(" empty" if empty else "")
 var entry=board.tiles["band-%d-%s" % [who,group]]
 await tap(entry)
 expect(board.sheet.visible and board.opened=={"who":who,"group":group},label+" opens corresponding region")
 if not board.sheet.visible:return
 var list=board.groups[who][group]
 expect(list.is_empty()==empty,label+" expected contents")
 expect(board.sheet.get_node("Title").text.contains(board.LABELS[group]),label+" title matches region")
 expect(board.rows.perm.pages[0].size()==list.size(),label+" shows all region cards")
 if not empty:
  var rect=board.cards["card_"+str(list[0].uid)].home
  expect(rect.size.y>=app.ui_metrics.hit and rect.size.x>=app.ui_metrics.hit-1,label+" expanded cards remain readable on short screens")
 if empty:expect(board.sheet.get_node("Empty").visible,label+" empty state remains browsable")
 await tap(board.tiles["perm-close"])
 expect(not board.sheet.visible and board.opened.is_empty(),label+" close button dismisses region")
 await tap(entry);await back()
 expect(not board.sheet.visible and board.opened.is_empty(),label+" Android back dismisses region")
 if input_kind=="mouse":
  await tap(entry)
  await click(board.sheet_rect.get_center(),MOUSE_BUTTON_RIGHT);await frames()
  expect(not board.sheet.visible,label+" right click dismisses region")
 if group=="item":
  await tap(entry);await tap_at(board.get_global_rect().position+Vector2.ONE)
  expect(not board.sheet.visible,label+" outside press dismisses region")

func check_browser(who: int,zone: String):
 await reset_ui()
 var label=context+" owner="+str(who)+" "+zone
 if zone in ["hand","deck"] or board.left_compact:
  await tap(board.tiles["summary-"+str(who)])
  expect(board.palette.visible and view.android_palette_focus_owner()==who,label+" summary selects correct owner")
  var entry=board.tiles.get("palette-"+zone)
  expect(is_instance_valid(entry),label+" has zone entry")
  if not is_instance_valid(entry):return
  await tap(entry)
 else:await tap(board.tiles["zone-%d-%s" % [who,zone]])
 expect(view.debug_open and is_instance_valid(view.browser_panel) and view.browser_owner==who and view.browser_zone==zone,label+" opens corresponding browser")
 if not is_instance_valid(view.browser_panel):return
 expect(view.browser_cards.get_child_count()==e.players[who][zone].size(),label+" browser card count matches")
 var hidden=zone=="deck" or zone=="hand" and (session.read_only or who!=view.local_seat)
 for tile in view.browser_cards.get_children():
  expect(tile.get_meta("display_id")=="back" if hidden else tile.get_meta("display_id")!="back",label+" respects hidden information")
 await tap(view.browser_panel.get_node("ClosePileBrowser"))
 expect(not view.debug_open and not is_instance_valid(view.browser_panel),label+" browser close button works")
 # Closing a nested pile returns to the palette; back then dismisses that layer.
 if board.palette.visible:
  await back();expect(not board.palette.visible,label+" back dismisses underlying palette")

func check_palette(who: int):
 await reset_ui()
 var label=context+" palette owner="+str(who)
 await tap(board.tiles["summary-"+str(who)])
 expect(board.palette.visible and view.android_palette_focus_owner()==who,label+" opens correct palette")
 expect(board.cards.values().filter(func(node):return node.visible and node.card.zone=="palette").all(func(node):return node.card.owner==who),label+" only requested owner's palette is visible")
 await tap(board.tiles["palette-close"])
 expect(not board.palette.visible and not view.android_palette_view,label+" close button works")
 await tap(board.tiles["summary-"+str(who)]);await back()
 expect(not board.palette.visible,label+" Android back works")
 if input_kind=="mouse":
  await tap(board.tiles["summary-"+str(who)])
  await click(board.palette_rect.get_center(),MOUSE_BUTTON_RIGHT);await frames()
  expect(not board.palette.visible,label+" right click works")

func check_player_actions():
 view.network_session=null;view.engine=authority;view.table.duel=authority;e=authority
 view.local_seat=0;view.table.local_seat=0;await reset_ui()
 e.players[0].leader.timer=0
 for color in e.COLORS:
  for id in e.cards:
   if e.cards[id].kind=="道具" and color in e.cards[id].colors:
    put(id,"field");break
 for i in range(20):
  var resource=put(["164","165","166","167","168"][i%5],"palette")
  resource.tapped=false
 var before=e.revision
 await redraw();await tap(board.tiles["band-0-leader"])
 expect(board.sheet.visible and e.revision==before and view.local.is_empty(),"player leader region opens without casting")
 await create_timer(0.35).timeout
 var leader=e.players[0].leader
 var error=e.cast_error(0,leader.uid)
 expect(error.is_empty(),"player leader fixture is castable: "+error)
 await tap(board.cards["card_"+str(leader.uid)])
 expect(not view.local.is_empty() or e.revision!=before,"player can still cast a leader from its region")
 view.local={};view.close_overlay();e.pending={};view.picker.reset();await reset_ui()

func check_spectator_cards():
 await reset_ui()
 var before=JSON.stringify({"players":remote.players,"revision":remote.revision,"pending":remote.pending})
 for who in range(2):
  await tap(board.tiles["band-%d-leader" % who])
  if not board.sheet.visible:continue
  # Wait for the normal card placement tween before clicking its visible center.
  await create_timer(0.35).timeout
  var leader=remote.players[who].leader
  await tap(board.cards["card_"+str(leader.uid)])
  expect(view.inspection.visible and view.inspect_uid==leader.uid,context+" spectator tap opens leader details "+str(who))
  await back()
  expect(not view.inspection.visible and board.sheet.visible,context+" details back preserves region "+str(who))
  await back()
  expect(not board.sheet.visible,context+" region back works after details "+str(who))
  var unit=remote.players[who].field.filter(func(c):return remote.is_unit(c))[0]
  await tap(board.cards["card_"+str(unit.uid)])
  expect(view.inspection.visible and view.inspect_uid==unit.uid,context+" spectator tap opens unit details "+str(who))
  await back()
  await tap(board.tiles["summary-"+str(who)])
  await create_timer(0.35).timeout
  var resource=remote.players[who].palette[0]
  await tap(board.cards["card_"+str(resource.uid)])
  expect(view.inspection.visible and view.inspect_uid==resource.uid,context+" spectator tap opens palette card details "+str(who))
  await back()
  expect(not view.inspection.visible and board.palette.visible,context+" details back preserves palette "+str(who))
  await back()
 expect(JSON.stringify({"players":remote.players,"revision":remote.revision,"pending":remote.pending})==before,context+" spectator browsing cannot mutate game state")
 expect(view.local.is_empty() and view.selection.is_empty() and view.android_action_uid==0,context+" spectator browsing cannot start actions")

func check_mode(spectator: bool,seat: int):
 session.read_only=spectator;session.seat=seat;remote.seat=seat
 remote.apply_snapshot((Observer.build(authority) if spectator else Seat.build(authority,seat)).duplicate(true))
 e=remote;view.engine=remote;view.network_session=session;view.table.duel=remote
 view.local_seat=seat;view.table.local_seat=seat
 await reset_ui()
 var initial=context;context+=(" spectator" if spectator else " player")+" seat="+str(seat)
 for who in range(2):
  for group in GROUPS:await check_region(who,group)
  await check_palette(who)
  for zone in ["grave","exile","hand","deck"]:await check_browser(who,zone)
 if spectator:await check_spectator_cards()
 # Empty permanent regions are still inspection destinations.
 # Rebuild queries with the empty state, as a real server snapshot does.
 var saved_players=authority.players
 authority.players=authority.players.duplicate(true)
 for player in authority.players:
  player.field=[];player.leader.zone="exile"
  for zone in ["palette","grave","exile","hand","deck"]:player[zone]=[]
 remote.apply_snapshot((Observer.build(authority) if spectator else Seat.build(authority,seat)).duplicate(true))
 authority.players=saved_players
 for who in range(2):
  for group in GROUPS:await check_region(who,group,true)
  await check_palette(who)
  for zone in ["grave","exile","hand","deck"]:await check_browser(who,zone)
 context=initial

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(fixture.path_join(name+".png"))

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture.path_join("fixtures"))
 DirAccess.make_dir_recursive_absolute(Store.Paths.root_override)
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND;root.size=Vector2i(1920,1080)
 app=load("res://main.tscn").instantiate();app.is_android=true;app.layout_dpi_override=320
 app.settings_path=Store.Paths.root_override.path_join("settings.json")
 root.add_child(app);await frames(8);app.load_legacy_test_decks();app.android_experimental_battle_ui=true;app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine;board=view.android_board;await frames(8);fill()
 Engine.max_fps=240
 session=Session.new();root.add_child(session);session.initialize(fixture.path_join("session"));session.set_process(false)
 session.connected=true;session.paused=false;session.series.setup(1,true,"test")
 session.series.state.status="playing";session.series.state.game_id="region-clickability"
 session.room=session.series.public_state(-1);session.local_game_id=session.room.game_id
 remote=Remote.new();remote.session=session
 if "--actions-only" in OS.get_cmdline_user_args():
  input_kind="touch";await check_player_actions()
  print("BATTLE REGION ACTIONS: %d checks; %d failures" % [checks,failures.size()])
  view.network_session=null;session.leave(false);session.queue_free();app.queue_free();await frames();quit(0 if failures.is_empty() else 1);return
 for device in [[1920,1080,320],[1280,480,280]]:
  root.size=Vector2i(device[0],device[1]);app.layout_dpi_override=device[2]
  app.layout_safe_override=Rect2(0,0,device[0],device[1]);app.refresh_responsive_layout();await frames(8)
  for kind in (["touch"] if "--visual-only" in OS.get_cmdline_user_args() else ["mouse","touch"]):
   input_kind=kind;context="%dx%d %s" % [device[0],device[1],kind]
   for spectator in [false,true]:
    for seat in ([0] if "--visual-only" in OS.get_cmdline_user_args() else [0,1]):await check_mode(spectator,seat)
  remote.apply_snapshot(Observer.build(authority).duplicate(true))
  await reset_ui();await tap(board.tiles["band-0-leader"]);await create_timer(0.35).timeout;await shot("leader-"+str(device[1]))
  await reset_ui();await tap(board.tiles["summary-0"]);await create_timer(0.35).timeout;await shot("palette-"+str(device[1]))
 await check_player_actions()
 view.network_session=null;view.engine=authority;view.table.duel=authority;e=authority
 session.leave(false);session.queue_free();app.queue_free();await frames()
 print("BATTLE REGION CLICKABILITY: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
