extends "res://tests/support/ui_base.gd"
const PagingChecks=preload("res://tests/support/battle_paging.gd")
const Codec=preload("res://net/state_codec.gd")
const SeatProjection=preload("res://net/seat_projection.gd")
const ObserverProjection=preload("res://net/observer_projection.gd")
const Remote=preload("res://net/remote_duel.gd")

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
 var original_model=e.cards["53"]
 var model=original_model.duplicate(true);model.health=20
 model.abilities=[{"实现":"activated_damage","名称":"对目标造成1点伤害","参数":{"横置":false,"费用":{},"数值":1}}]
 e.cards["53"]=model
 var units={0:[],1:[]};var palettes={0:[],1:[]}
 for who in range(2):
  for i in range(13):units[who].append(put("53","field",who))
  for i in range(23):palettes[who].append(put("164","palette",who))
 view.table.zone_pages={0:{"unit":2,"palette":2},1:{"unit":2,"palette":2}}
 sync_table()
 var prefix=("Android" if android else "Desktop")+" seat"+str(seat)+(" spectator" if spectator else " player")
 expect(shown(0,"field")==[units[0][12].uid],prefix+" manual third page starts unchanged")
 var attacker=units[0][12];var blocker=units[1][11]
 view.selection=[attacker.uid,palettes[0][22].uid]
 view.local={"mode":"target","uid":attacker.uid,"target":e.ref_target(blocker)}
 var preview=snapshot();sync_table()
 expect(view.table.zone_pages[0].unit==2 and view.table.zone_pages[0].palette==2,prefix+" unconfirmed selection and target preview never promote cards")
 expect(snapshot()==preview,prefix+" preview leaves the duel unchanged")
 view.selection=[];view.local={};sync_table()
 e.attack(1,blocker.uid)
 expect(not e.commit_ability(0,attacker.uid,99,e.ref_target(blocker),[]).is_empty(),prefix+" invalid ability is rejected")
 sync_table()
 expect(view.table.zone_pages[0].unit==2 and view.table.zone_pages[1].unit==2,prefix+" rejected attack and ability never promote cards")
 e.attack(0,attacker.uid)
 expect(not e.combat.is_empty(),prefix+" attack is actually declared")
 var fighting=snapshot();sync_table()
 expect(view.table.zone_pages[0].unit==0 and shown(0,"field")[0]==attacker.uid,prefix+" successful attack moves its source to the first page")
 expect(view.table.zone_pages[1].unit==2,prefix+" an undeclared blocker stays on its current page")
 expect(snapshot()==fighting,prefix+" combat rendering does not mutate engine state")
 resolve()
 expect(e.pending.get("kind","")=="block",prefix+" real combat reaches the blocker choice")
 e.block([blocker.uid]);sync_table()
 expect(view.table.zone_pages[1].unit==0 and shown(1,"field")[0]==blocker.uid,prefix+" confirmed block promotes its defender")
 if seat==0 and not spectator:
  view.render();await settle();view.update_badge_positions()
  await capture("battle-focus-combat-"+("android" if android else "desktop"))
 view.table.next_zone_page(0,"unit");view.table.next_zone_page(1,"unit");sync_table()
 expect(view.table.zone_pages[0].unit==1 and view.table.zone_pages[1].unit==1,prefix+" committed combat permits manual paging")
 for i in range(6):
  if e.combat.is_empty():break
  e.pass_priority(e.priority)
 sync_table()
 expect(e.combat.is_empty() and attacker.zone=="field" and blocker.zone=="field",prefix+" real combat finishes with both units remaining")
 expect(view.table.zone_pages[0].unit==1 and view.table.zone_pages[1].unit==1,prefix+" ending combat preserves manual browsing")
 view.table.zone_pages[0].unit=0;view.table.zone_pages[1].unit=0;sync_table()
 expect(shown(0,"field")[0]==attacker.uid and shown(1,"field")[0]==blocker.uid,prefix+" resolved attack and block keep their first-page positions")
 var source=units[0][11];var target=units[1][12]
 var before_ability=Codec.capture(e)
 view.table.zone_pages[0].unit=2;view.table.zone_pages[1].unit=2
 view.selection=[source.uid];view.local={"mode":"target","uid":source.uid,"target":e.ref_target(target)};sync_table()
 expect(view.table.zone_pages[0].unit==2 and view.table.zone_pages[1].unit==2,prefix+" choosing ability source and target waits for confirmation")
 e.priority=0
 expect(e.commit_ability(0,source.uid,0,e.ref_target(target),[]).is_empty(),prefix+" source ability is actually announced")
 sync_table()
 expect(view.table.zone_pages[0].unit==0 and shown(0,"field").slice(0,2)==[source.uid,attacker.uid],prefix+" newest successful ability source precedes earlier attacker")
 expect(view.table.zone_pages[1].unit==0 and shown(1,"field").slice(0,2)==[target.uid,blocker.uid],prefix+" confirmed ability target precedes earlier blocker")
 view.selection=[];view.local={};resolve();sync_table()
 expect(e.stack.is_empty() and shown(0,"field")[0]==source.uid and shown(1,"field")[0]==target.uid,prefix+" resolved ability keeps source and target first after highlights clear")
 var after_ability=Codec.capture(e)
 var stable_own=shown(0,"field");var stable_enemy=shown(1,"field")
 e.priority=0
 expect(e.commit_ability(0,attacker.uid,0,e.ref_target(blocker),[]).is_empty(),prefix+" first-page permanents can confirm another ability")
 sync_table()
 expect(shown(0,"field")==stable_own and shown(1,"field")==stable_enemy,prefix+" already-first-page source and target keep all six positions")
 resolve();sync_table()
 view.table.next_zone_page(0,"unit");view.table.next_zone_page(1,"unit");sync_table()
 expect(view.table.zone_pages[0].unit==1 and view.table.zone_pages[1].unit==1,prefix+" old confirmed ability does not trap manual paging")
 e.priority=0
 var invalid=e.ref_target(target);invalid.epoch+=1
 expect(not e.commit_ability(0,source.uid,0,invalid,[]).is_empty(),prefix+" stale target rejects the ability")
 sync_table()
 expect(view.table.zone_pages[0].unit==1 and view.table.zone_pages[1].unit==1,prefix+" failed reactivation does not reset either page")
 expect(e.commit_ability(0,source.uid,0,e.ref_target(target),[]).is_empty(),prefix+" same source can announce another real ability")
 sync_table()
 expect(view.table.zone_pages[0].unit==0 and view.table.zone_pages[1].unit==0,prefix+" a new action by the same permanent returns its rows to page one")
 resolve();sync_table()
 var palette_target=palettes[1][22];var own_palette_target=palettes[0][22]
 view.table.zone_pages[0].palette=2;view.table.zone_pages[1].palette=2
 var nested={"parts":[e.ref_target(palette_target),{"picks":[[e.ref_target(own_palette_target)]]}]}
 e.Roster.New.on_target(e,nested);sync_table()
 expect(view.table.zone_pages[1].palette==0 and shown(1,"palette")[0]==palette_target.uid,prefix+" accepted nested target event promotes the enemy color card")
 expect(view.table.zone_pages[0].palette==0 and shown(0,"palette")[0]==own_palette_target.uid,prefix+" accepted nested target event promotes the own color card")
 view.table.next_zone_page(1,"palette");sync_table()
 expect(view.table.zone_pages[1].palette==1,prefix+" persistent target priority permits palette browsing")
 var cost_pick=palettes[1][21]
 e.Roster.New.on_target(e,{"picks":[[e.ref_target(cost_pick)],[e.ref_target(palette_target)]]},{"target_spec":{"selection":[{"cost":true},{}]}});sync_table()
 expect(not cost_pick.has("page_priority") and shown(1,"palette")[0]==palette_target.uid,prefix+" cost choices do not become targets or displace actual targets")
 var plus_cost=units[0][8];var color_cost=units[0][9]
 plus_cost.plus_counters=1;color_cost.color_counters=["黄"]
 var plus_ref=e.ref_target(plus_cost);plus_ref.counter="plus_counters"
 var color_ref=e.ref_target(color_cost);color_ref.counter="color_counters";color_ref.counter_index=0
 var copy_card=e.make_card("spell-fdf-053",0,"stack");copy_card.stack_copy=true
 var copied_entry={"kind":"card","card":copy_card,"owner":0}
 view.table.zone_pages[0].unit=1
 e.Roster.New.on_target(e,{"picks":[[plus_ref,color_ref],[e.ref_target(palette_target)]]},copied_entry);sync_table()
 expect(not plus_cost.has("page_priority") and not color_cost.has("page_priority") and view.table.zone_pages[0].unit==1,prefix+" copied counter-payment references remain costs without a target specification")
 expect(shown(1,"palette")[0]==palette_target.uid,prefix+" copied spell still promotes its actual target when counter costs are excluded")
 e.priority=0
 var spell=put("101","hand");var mana=palettes[0][21]
 expect(e.commit_cast(0,spell.uid,e.ref_target(units[0][10]),[{"uid":mana.uid,"color":"黄"}]).is_empty(),prefix+" real spell consumes an explicitly chosen off-page mana source")
 sync_table()
 expect(mana.tapped and shown(0,"palette")[0]==mana.uid,prefix+" a successfully used mana ability also promotes its color card")
 resolve();sync_table()
 expect(shown(0,"palette")[0]==mana.uid and shown(1,"palette")[0]==palette_target.uid,prefix+" completed actions leave palette priorities intact")
 expect(e.players[0].field.map(func(c):return c.uid)==units[0].map(func(c):return c.uid) and e.players[1].palette.map(func(c):return c.uid)==palettes[1].map(func(c):return c.uid),prefix+" presentation priority never reorders real zone arrays")
 var authority=e
 for perspective in [0,1,-1]:
  var projection=ObserverProjection.build(authority) if perspective==-1 else SeatProjection.build(authority,perspective)
  var remote=Remote.new();remote.apply_snapshot(projection);view.table.duel=remote
  view.table.zone_focus={0:{"unit":[],"palette":[]},1:{"unit":[],"palette":[]}}
  view.table.zone_pages={0:{"unit":2,"palette":2},1:{"unit":2,"palette":2}};sync_table()
  expect(shown(0,"field")[0]==units[0][10].uid and shown(1,"field")[0]==target.uid,prefix+" cold-join perspective "+str(perspective)+" retains resolved field priority")
  expect(shown(0,"palette")[0]==mana.uid and shown(1,"palette")[0]==palette_target.uid,prefix+" cold-join perspective "+str(perspective)+" retains resolved palette priority")
 view.table.duel=authority
 expect(Codec.restore(e,before_ability).is_empty(),prefix+" undo restores the earlier state graph")
 view.table.zone_pages[0].unit=0;view.table.zone_pages[1].unit=0;sync_table()
 expect(shown(0,"field")[0]==attacker.uid and shown(1,"field")[0]==blocker.uid,prefix+" undo removes later ability priorities while retaining declared combat")
 expect(Codec.restore(e,after_ability).is_empty(),prefix+" replay restores the resolved ability state graph")
 sync_table()
 expect(shown(0,"field")[0]==source.uid and shown(1,"field")[0]==target.uid,prefix+" replay restores the resolved ability order")
 var returning=e.find_card(source.uid)
 e.move_to(returning,"grave");e.move_to(returning,"field");sync_table()
 expect(not returning.has("page_priority") and shown(0,"field")[0]==attacker.uid,prefix+" leaving and returning to the same area clears the old instance priority")
 var stale=e.find_card(target.uid);stale.epoch+=1;sync_table()
 expect(shown(1,"field")[0]==blocker.uid,prefix+" stale metadata cannot prioritize a new epoch of the same UID")
 var first_token=put("token-fdf-127","field");var second_token=put("token-fdf-127","field")
 e.Roster.New.on_target(e,e.ref_target(first_token))
 var token_members=e.stackable_members(first_token).map(func(card):return card.uid)
 expect(first_token.has("page_priority") and not second_token.has("page_priority") and token_members.has(first_token.uid) and token_members.has(second_token.uid),prefix+" display priority never separates otherwise identical stackable permanents")
 e.cards["53"]=original_model;view.network_session=null

func verify_stable_first_page():
 clean();view.local_seat=0;view.table.local_seat=0
 view.table.unit_order={0:[],1:[]};view.table.zone_focus={0:{"unit":[],"palette":[]},1:{"unit":[],"palette":[]}}
 var units=[]
 for index in range(13):units.append(put("53","field"))
 view.table.zone_pages={0:{"unit":0,"palette":0},1:{"unit":0,"palette":0}};sync_table()
 var first=shown(0,"field")
 e.Roster.New.on_target(e,e.ref_target(units[1]));sync_table()
 expect(shown(0,"field")==first,"unmarked first-page target preserves original six-card order")
 e.Roster.New.on_target(e,{"parts":[e.ref_target(units[8]),e.ref_target(units[5])]});sync_table()
 expect(shown(0,"field")==[units[8].uid]+first.slice(0,5),"batch classifies original first-page targets before inserting an off-page target")
 for index in range(6,13):e.Roster.New.on_target(e,e.ref_target(units[index]))
 sync_table()
 expect(units[8].uid not in shown(0,"field"),"later moves can displace an earlier promoted unit")
 e.Roster.New.on_target(e,e.ref_target(units[8]));sync_table()
 expect(shown(0,"field")[0]==units[8].uid,"displaced promoted unit can move to page one again")
 var expected=shown(0,"field");var state=Codec.capture(e)
 view.table.zone_pages[0].unit=2;sync_table()
 expect(Codec.restore(e,state).is_empty(),"stable movement ranks round-trip through a snapshot")
 view.table.zone_focus={0:{"unit":[],"palette":[]},1:{"unit":[],"palette":[]}};sync_table()
 expect(shown(0,"field")==expected,"snapshot retains stable movement order")

func verify_manual_page_order():
 clean();view.local_seat=0;view.table.local_seat=0
 view.table.unit_order={0:[],1:[]};view.table.manual_page_order={}
 var units=[]
 for index in range(13):units.append(put("53","field"))
 var sorted=units.duplicate();sorted.reverse()
 view.table.unit_order[0]=sorted.map(func(card):return card.uid)
 view.table.remember_unit_page_order(0,sorted)
 view.table.zone_pages={0:{"unit":0,"palette":0},1:{"unit":0,"palette":0}};sync_table()
 var original=shown(0,"field")
 expect(original==sorted.slice(0,6).map(func(card):return card.uid),"manual unit order determines the actual first page")
 e.Roster.New.on_target(e,e.ref_target(units[9]));sync_table()
 expect(shown(0,"field")==original,"manually placed first-page target does not jump even when authority considers it off-page")
 e.Roster.New.on_target(e,e.ref_target(units[0]));sync_table()
 expect(shown(0,"field")[0]==units[0].uid,"manual off-page target moves forward even when authority considers it already first-page")
 var stable=shown(0,"field")
 e.Roster.New.on_target(e,e.ref_target(units[11]));sync_table()
 expect(shown(0,"field")==stable,"a second manual first-page action preserves all visible positions")
 var before_sort=Codec.capture(e)
 view.table.auto_sort_units();sync_table()
 var auto_first=shown(0,"field")
 e.Roster.New.on_target(e,e.ref_target(units[2]));sync_table()
 expect(shown(0,"field")==auto_first,"automatic sorting also preserves first-page target position")
 expect(Codec.restore(e,before_sort).is_empty(),"manual order test can undo the last target action")
 sync_table()
 expect(not view.table.manual_page_order.has(0),"undo invalidates private page history and restores snapshot ordering")

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
   expect(absf(rect.get_center().y-row.get_center().y)<=maxf(rect.size.y,row.size.y)*0.5+rect.size.y*0.5+app.ui_metrics.gap,prefix+" remains alongside its own palette row")
   expect(PagingChecks.visible_hand_regions(view).all(func(region):return not rect.intersects(region)),prefix+" leaves actual corner cards and scrollbar clear")
  if hand_count==0:
   # The battlefield camera now keeps the palette above the hand. Verify the
   # empty viewport remains usable without requiring the default arrow there.
   var viewport=view.hand_scroll.get_global_rect().intersection(app.ui_metrics.safe)
   var dimensions=view.zone_pagers.palette0.root.size
   var preferred=viewport.get_center()-dimensions*0.5
   var free=view.clear_palette_pager_position(preferred,dimensions,viewport,view.palette_pager_obstacles())
   expect(free.is_finite() and viewport.encloses(Rect2(free,dimensions)),("Android" if android else "Desktop")+" empty transparent hand viewport can host its palette arrow")
  await capture("pager-sparse-hand-"+("android" if android else "desktop")+"-"+str(hand_count))
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/battle-page-focus-fixtures/"+str(Time.get_ticks_usec()))
 root.size=Vector2i(1600,900);root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();app.settings_path=Store.Paths.root_override.path_join("settings.json");app.account_session_path=Store.Paths.root_override.path_join("account.json");root.add_child(app);await frames()
 app.load_legacy_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 verify_stable_first_page()
 verify_manual_page_order()
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
