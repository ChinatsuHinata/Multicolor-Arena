extends "res://tests/support/ui_base.gd"
const PagingChecks=preload("res://tests/support/battle_paging.gd")

class SpectatorSession:
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

func frames(count: int=4):
 for i in range(count):await process_frame

func shown(who: int,zone: String) -> Array:
 return view.table.descriptors.values().filter(func(d):return d.zone==zone and d.owner==who).map(func(d):return d.uid)

func sync_table():
 view.table.sync([],view.selected_uids(),[],false)

func verify_focus(android: bool,seat: int,spectator: bool):
 clean();view.local_seat=seat;view.table.local_seat=seat
 view.network_session=SpectatorSession.new() if spectator else null
 var units={0:[],1:[]};var palettes={0:[],1:[]}
 for who in range(2):
  for i in range(13):units[who].append(put("53","field",who))
  for i in range(23):palettes[who].append(put("164","palette",who))
 view.table.zone_pages={0:{"unit":2,"palette":2},1:{"unit":2,"palette":2}}
 sync_table()
 var prefix=("Android" if android else "Desktop")+" seat"+str(seat)+(" spectator" if spectator else " player")
 expect(shown(0,"field")==[units[0][12].uid],prefix+" manual third page starts unchanged")
 var attacker=units[0][12];var blocker=units[1][11]
 e.combat={"attacker":e.ref_target(attacker),"blockers":[e.ref_target(blocker)],"target":e.ref_target(blocker),"owner":0,"step":"block_window","blocked":true,"strike_round":"normal"}
 var fighting=snapshot();sync_table()
 expect(view.table.zone_pages[0].unit==0 and shown(0,"field")[0]==attacker.uid,prefix+" off-page attacker moves to first page")
 expect(view.table.zone_pages[1].unit==0 and shown(1,"field")[0]==blocker.uid,prefix+" off-page defender moves to first page")
 expect(snapshot()==fighting,prefix+" combat presentation leaves real field order and engine state untouched")
 if seat==0 and not spectator:
  view.render();await settle();view.update_badge_positions()
  await capture("battle-focus-combat-"+("android" if android else "desktop"))
 view.table.next_zone_page(0,"unit");sync_table()
 expect(view.table.zone_pages[0].unit==1,prefix+" unchanged combat permits manual browsing of another page")
 var second_blocker=units[1][12]
 e.combat.blockers.append(e.ref_target(second_blocker));sync_table()
 expect(view.table.zone_pages[1].unit==0 and shown(1,"field").slice(0,2)==[blocker.uid,second_blocker.uid],prefix+" new blocker returns its row to first page in stable order")
 e.combat={};sync_table()
 expect(shown(0,"field")==units[0].slice(6,12).map(func(c):return c.uid),prefix+" resolving combat restores normal UI order on current page")
 var target=palettes[1][22];var field_target=units[0][12]
 e.stack=[{"id":999,"kind":"ability","source":units[0][0].duplicate(true),"owner":0,"name":"目标展示测试","target":{"parts":[e.ref_target(target),{"picks":[[e.ref_target(field_target)]]}]}}]
 view.table.zone_pages[0].unit=2;view.table.zone_pages[1].palette=2
 var targeting=snapshot();sync_table()
 expect(view.table.zone_pages[1].palette==0 and shown(1,"palette")[0]==target.uid,prefix+" nested stack target moves off-page color card to first page")
 expect(view.table.zone_pages[0].unit==0 and shown(0,"field")[0]==field_target.uid,prefix+" nested stack target moves off-page unit to first page")
 expect(snapshot()==targeting,prefix+" target emphasis never mutates palette order or stack refs")
 view.table.next_zone_page(1,"palette");sync_table()
 expect(view.table.zone_pages[1].palette==1,prefix+" existing target does not trap manual palette paging")
 e.stack[0].target=e.ref_target(palettes[1][21]);sync_table()
 expect(view.table.zone_pages[1].palette==0 and shown(1,"palette")[0]==palettes[1][21].uid,prefix+" changed target returns palette to page one")
 view.table.next_zone_page(1,"palette");sync_table()
 palettes[1][21].epoch+=1;e.stack[0].target=e.ref_target(palettes[1][21]);sync_table()
 expect(view.table.zone_pages[1].palette==0 and shown(1,"palette")[0]==palettes[1][21].uid,prefix+" replay seek to a new epoch of the same UID returns palette to page one")
 e.stack[0].target.epoch+=1;sync_table()
 expect(shown(1,"palette").slice(0,10)==palettes[1].slice(0,10).map(func(c):return c.uid),prefix+" stale epoch target receives no presentation priority")
 e.stack=[];view.selection=[palettes[0][22].uid];sync_table()
 expect(view.table.zone_pages[0].palette==0 and shown(0,"palette")[0]==palettes[0][22].uid,prefix+" selecting an off-page color card immediately shows it first")
 view.selection=[];sync_table()
 expect(shown(0,"palette").slice(0,10)==palettes[0].slice(0,10).map(func(c):return c.uid),prefix+" clearing target restores original color-card order")
 expect(e.players[0].field.map(func(c):return c.uid)==units[0].map(func(c):return c.uid) and e.players[1].palette.map(func(c):return c.uid)==palettes[1].map(func(c):return c.uid),prefix+" real arrays retain their complete original order")
 view.network_session=null

func verify_pagers():
 clean();view.local_seat=0;view.table.local_seat=0
 for who in range(2):
  for i in range(21):put("164","palette",who)
  for i in range(7):put("53","field",who)
 for top_down in [false,true]:
  view.table.set_top_down_view(top_down)
  for focus in [-1,0,1]:
   view.set_android_camera_focus(focus);view.render();await settle();await frames()
   view.update_badge_positions()
   var rects=[]
   for who in range(2):
    var button=view.zone_pagers["palette"+str(who)].button
    var rect=button.get_global_rect();rects.append(rect)
    var prefix="Android "+str(root.size)+" top_down"+str(top_down)+" focus"+str(focus)+" palette"+str(who)
    expect(button.is_visible_in_tree() and app.ui_metrics.safe.encloses(rect),prefix+" arrow remains visible inside safe area")
    expect(PagingChecks.visible_hand_regions(view).all(func(region):return not rect.intersects(region)),prefix+" arrow leaves actual cards and scrollbars clear")
    var blockers=view.palette_pager_obstacles()
    expect(blockers.all(func(blocked):return not rect.intersects(blocked)),prefix+" arrow leaves HUD controls clear")
   expect(not rects[0].intersects(rects[1]),"own and enemy palette arrows remain distinct")
   await capture("page-focus-"+str(root.size.x)+("-2d" if top_down else "-3d")+"-"+str(focus))
 var shortcuts=view.android_zone_shortcuts
 expect(shortcuts.buttons.own_grave.get_node("ZoneIcon").self_modulate==Color("#4b9df5"),"own grave icon uses blue")
 expect(shortcuts.buttons.enemy_grave.get_node("ZoneIcon").self_modulate==Color("#ef5350"),"enemy grave icon uses red")

func verify_sparse_hand_pagers(android: bool):
 for hand_count in [0,2]:
  clean();view.local_seat=0;view.table.local_seat=0;view.table.set_top_down_view(false)
  view.android_palette_view=false;view.android_focus_owner=-1
  for who in range(2):
   for i in range(13):put("53","field",who)
   for i in range(23):put("164","palette",who)
  for i in range(hand_count):put("164","hand")
  view.table.zone_pages={0:{"unit":0,"palette":2},1:{"unit":0,"palette":2}}
  view.render();await settle();view.reset_camera_view();await settle();await frames()
  # Place a sparse hand in one corner to leave the rest of its viewport empty.
  var index=0
  for card in view.hand_nodes.values():
   card.position.x=16+index*(card.size.x+app.ui_metrics.gap);index+=1
  view.update_badge_positions()
  for who in range(2):
   var rect=view.zone_pagers["palette"+str(who)].button.get_global_rect()
   var row=PagingChecks.palette_row(view,who)
   var prefix=("Android" if android else "Desktop")+" hand"+str(hand_count)+" palette"+str(who)
   expect(view.zone_pagers["palette"+str(who)].button.is_visible_in_tree() and app.ui_metrics.safe.encloses(rect),prefix+" stays visible and safe")
   expect(absf(rect.get_center().y-row.get_center().y)<=maxf(rect.size.y,row.size.y)*0.5+app.ui_metrics.gap,prefix+" remains alongside its own palette row")
   expect(PagingChecks.visible_hand_regions(view).all(func(region):return not rect.intersects(region)),prefix+" leaves actual corner cards and scrollbar clear")
  if hand_count==0:
   expect(view.hand_scroll.get_global_rect().intersects(view.zone_pagers.palette0.button.get_global_rect()),("Android" if android else "Desktop")+" empty transparent hand viewport can host its palette arrow")
  await capture("pager-sparse-hand-"+("android" if android else "desktop")+"-"+str(hand_count))
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/battle-page-focus-fixtures/"+str(Time.get_ticks_usec()))
 root.size=Vector2i(1600,900);root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 app.load_legacy_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 for seat in range(2):
  for spectator in [false,true]:await verify_focus(false,seat,spectator)
 await verify_sparse_hand_pagers(false)
 app.clear_page("battle");app.is_android=true;app.layout_dpi_override=280;app.refresh_ui_metrics()
 app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 for seat in range(2):
  for spectator in [false,true]:await verify_focus(true,seat,spectator)
 await verify_sparse_hand_pagers(true)
 await verify_pagers()
 root.size=Vector2i(1280,720);app.layout_dpi_override=320;app.layout_safe_override=Rect2(60,0,1196,696)
 await frames();app.refresh_responsive_layout();await frames();await verify_pagers()
 print("BATTLE PAGE FOCUS: %d checks; failures=%d" % [checks,failures.size()])
 app.queue_free();await frames();quit(0 if failures.is_empty() else 1)