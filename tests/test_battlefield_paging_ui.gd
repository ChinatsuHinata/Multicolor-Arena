extends "res://tests/support/ui_base.gd"
const PagingChecks=preload("res://tests/support/battle_paging.gd")

func frames(count: int=6):
 for i in range(count):await process_frame

func shown_units(who: int=0) -> Array:
 return view.table.descriptors.values().filter(func(d):return d.zone=="field" and d.get("group","")=="unit" and d.owner==who).map(func(d):return d.uid)

func capacity() -> String:
 return view.hud.get_node("FieldCapacity/FieldCapacityValue").text

func next_page(who: int=0,group: String="unit"):
 var button=view.zone_pagers[group+str(who)].button
 expect(button.is_visible_in_tree(),"page arrow is visible for "+group+str(who))
 var at=button.get_global_rect().get_center()
 if view.is_android:
  for pressed in [true,false]:
   var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=pressed
   root.push_input(event,true);await process_frame
 else:await click(at)
 await frames()

func verify_palette_cameras(android: bool):
 clean()
 for who in range(2):
  for i in range(21):
   var card=put("164","palette",who);card.tapped=i%3==1
  for i in range(7):put("53","field",who)
  for i in range(6):put("164","hand",who)
 view.render();await settle()
 for seat in range(2):
  view.local_seat=seat;view.table.local_seat=seat
  for top_down in [false,true]:
   view.table.set_top_down_view(top_down)
   for focus in [-1,0,1]:
    if android:view.set_android_camera_focus(focus)
    else:
     view.android_palette_view=focus>=0;view.android_focus_owner=focus
     view.tutorial_camera_view="" if focus<0 else "own_palette" if focus==seat else "enemy_palette"
     view.render()
    await frames();view.reset_camera_view();await settle()
    for offset in [Vector3.ZERO,Vector3(8,0,6),Vector3(-8,0,-6)]:
     view.table.camera_offset=offset
     for zoom in [0.6,1.0,1.6]:
      view.table.camera_frame_scale=zoom;view.table.set_camera();view.update_badge_positions()
      var prefix="%s seat%d %s focus%d pan%s zoom%.1f" % ["android" if android else "desktop",seat,"2D" if top_down else "3D",focus,offset,zoom]
      var pager_rects=[]
      for who in range(2):
       var button=view.zone_pagers["palette"+str(who)].button
       var rect=button.get_global_rect();pager_rects.append(rect)
       expect(button.is_visible_in_tree() and app.ui_metrics.safe.encloses(rect),prefix+" palette%d stays visible inside the safe area" % who)
       expect(PagingChecks.visible_hand_regions(view).all(func(region):return not region.intersects(rect)),prefix+" palette%d leaves actual own cards and scrollbars clear" % who)
       expect(view.enemy_nodes.values().all(func(tile):return not tile.is_visible_in_tree() or not tile.get_global_rect().intersects(rect)),prefix+" palette%d leaves enemy hand clear" % who)
      expect(not pager_rects[0].intersects(pager_rects[1]),prefix+" both palette arrows stay separate")
    view.table.camera_frame_scale=1.0;view.reset_camera_view()
    if seat==0:await capture("palette-"+("android" if android else "desktop")+"-"+("2d" if top_down else "3d")+"-focus"+str(focus))
    await next_page(seat,"palette")
    expect(view.table.zone_pages[seat].palette==1,"palette arrow changes page in "+("android" if android else "desktop")+" "+str(top_down)+" focus"+str(focus))
    view.table.zone_pages[seat].palette=0;view.render();await frames()
 view.local_seat=0;view.table.local_seat=0;view.tutorial_camera_view="";view.android_palette_view=false
 view.table.camera_frame_scale=1.0;view.reset_camera_view()
 for top_down in [false,true]:
  view.table.set_top_down_view(top_down)
  var source=put("49","field")
  e.begin_trigger({"source":source.duplicate(true),"owner":0,"extended":true,"effect":"enter_palette_replace","name":e.cards["49"].name,"optional":true,"data":{}})
  e.choose_effect({"player":1});resolve();view.render();await settle();view.render();await frames()
  for who in range(2):
   var button=view.zone_pagers["palette"+str(who)].button
   expect(button.is_visible_in_tree() and not button.get_global_rect().intersects(view.android_choice_panel.get_global_rect()),"palette%d remains visible beside target confirmation in %s %s" % [who,"android" if android else "desktop",str(top_down)])
  await next_page(1,"palette")
  expect(view.table.zone_pages[1].palette==1,"target confirmation allows enemy palette paging")
  await capture("palette-choice-"+("android" if android else "desktop")+"-"+("2d" if top_down else "3d"))
  view.picker.reset();e.pending={};e.stack=[];e.players[0].field.erase(source)
  view.local={};view.android_camera_restore={};view.android_auto_focus_owner=-1
  view.android_palette_view=false;view.table.zone_pages[1].palette=0;view.render();view.reset_camera_view()

func verify_board(android: bool):
 clean()
 view.table.zone_pages={0:{"unit":0,"palette":0},1:{"unit":0,"palette":0}}
 view.table.unit_order={0:[],1:[]}
 view.render();await frames()
 expect(capacity()=="0/6" and view.field_capacity_badge.is_visible_in_tree(),"empty battlefield shows 0/6")
 var units=[]
 for i in range(6):units.append(put("53","field"))
 view.render();await frames()
 expect(shown_units()==units.map(func(c):return c.uid) and not view.zone_pagers.has("unit0"),"six units fit on one page without a page arrow")
 expect(capacity()=="6/6","full battlefield shows 6/6")
 for i in range(6):
  var free=put("53","field");free.modifiers=[{"不占战场格":true}];units.append(free)
 for i in range(11):put("164","palette")
 var enemy=[]
 for i in range(7):enemy.append(put("53","field",1))
 view.render();await frames()
 expect(shown_units()==units.slice(0,6).map(func(c):return c.uid),"first page displays units one through six")
 expect(capacity()=="6/6","six extra units that do not occupy slots keep the count at 6/6")
 expect(view.zone_pagers.unit0.button.text.begins_with("1/2") and view.zone_pagers.unit1.button.text.begins_with("1/2"),"both unit rows paginate after six units")
 expect(view.table.descriptors.values().filter(func(d):return d.zone=="palette" and d.owner==0 and d.uid>0).size()==10,"color palette still displays ten cards per page")
 await settle();view.update_badge_positions();view.banner.hide()
 expect(view.zone_pagers.values().all(func(parts):return not parts.root.visible or not parts.root.get_global_rect().intersects(view.field_capacity_badge.get_global_rect())),"page controls leave the slot count clear")
 var visible_pagers=view.zone_pagers.values().filter(func(parts):return parts.root.is_visible_in_tree())
 var unit_rects=view.table.descriptors.values().filter(func(d):return d.zone=="field" and d.get("group","")=="unit").map(func(d):return view.projected_card_rect(view.table.visuals[d.key]))
 expect(visible_pagers.all(func(parts):return unit_rects.all(func(rect):return not rect.intersects(parts.root.get_global_rect()))),"page arrows leave every visible unit card clear")
 var palette_rects=view.table.descriptors.values().filter(func(d):return d.zone=="palette").map(func(d):return view.projected_card_rect(view.table.visuals[d.key]))
 expect(visible_pagers.all(func(parts):return palette_rects.all(func(rect):return not rect.intersects(parts.root.get_global_rect()))),"page arrows leave color cards clear")
 for i in range(visible_pagers.size()):
  for j in range(i):expect(not visible_pagers[i].root.get_global_rect().intersects(visible_pagers[j].root.get_global_rect()),"unit and palette page arrows stay separate")
 await capture("battlefield-page-one-"+("android" if android else "desktop"))
 await next_page()
 expect(shown_units()==units.slice(6,12).map(func(c):return c.uid) and capacity()=="6/6","second page displays units seven through twelve with the total slot count")
 await settle();view.update_badge_positions();view.banner.hide();await capture("battlefield-page-two-"+("android" if android else "desktop"))
 await next_page()
 expect(shown_units()==units.slice(0,6).map(func(c):return c.uid),"last page wraps to the first page")
 await next_page(1)
 expect(shown_units(1)==[enemy[6].uid] and shown_units()==units.slice(0,6).map(func(c):return c.uid),"opponent paging is independent of the local page")
 var thirteenth=put("53","field");thirteenth.modifiers=[{"不占战场格":true}]
 view.render();await frames()
 await next_page();await next_page()
 expect(shown_units()==[thirteenth.uid],"thirteenth unit starts a third page")
 e.players[0].field.erase(thirteenth);view.render();await frames()
 expect(shown_units()==units.slice(6,12).map(func(c):return c.uid) and view.zone_pagers.unit0.button.text.begins_with("2/2"),"removing the last page clamps to the remaining second page")
 for free in units.slice(6):e.players[0].field.erase(free)
 view.render();await frames()
 expect(shown_units()==units.slice(0,6).map(func(c):return c.uid) and not view.zone_pagers.has("unit0"),"returning to six units restores a single complete page")
 e.players[0].field.erase(units[0]);view.render();await frames()
 expect(capacity()=="5/6","unit leaving the field frees a slot in the counter")
 var expansion=put("character-ucs-053","field");view.render();await frames()
 expect(capacity()=="6/9","battlefield expansion updates the capacity denominator")
 e.players[0].field.erase(expansion);view.render();await frames()
 expect(capacity()=="5/6","removing battlefield expansion restores the normal limit")
 var before=snapshot()
 view.table.set_top_down_view(true);view.render();await frames()
 expect(view.field_capacity_badge.is_visible_in_tree() and app.ui_metrics.safe.encloses(view.field_capacity_badge.get_global_rect()),"slot count stays visible in the safe area in 2D view")
 view.set_hand_display(false);await frames()
 expect(capacity()=="5/6" and view.field_capacity_badge.is_visible_in_tree(),"hiding hands preserves the slot count")
 expect(snapshot()==before,"paging and display controls do not mutate game state")
 view.local_seat=1;view.table.local_seat=1;view.render();await frames()
 expect(capacity()=="7/6","slot counter follows the local player's seat")
 view.local_seat=0;view.table.local_seat=0;view.render();await frames()
 view.set_hand_display(true)
 if android:
  view.set_android_camera_focus(view.local_seat);await frames()
  expect(not view.field_capacity_badge.visible,"palette focus hides the battlefield counter")
  view.set_android_camera_focus(-1);await frames()
  expect(view.field_capacity_badge.is_visible_in_tree(),"returning to battlefield focus restores the counter")
 await capture("battlefield-capacity-"+("android" if android else "desktop"))

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/battlefield-paging-tests/"+str(Time.get_ticks_usec()))
 root.size=Vector2i(1600,900);root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();app.tutorial_local_directory="res://work/battlefield-paging-tutorials";root.add_child(app);await frames()
 app.load_legacy_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 await verify_board(false)
 await verify_palette_cameras(false)
 app.clear_page("battle");app.is_android=true;app.layout_dpi_override=300;app.refresh_ui_metrics()
 view=preload("res://scripts/duel_view.gd").new();view.is_android=true;app.duel_view=view;app.screen.add_child(view)
 view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 view.begin(app,app.decks[app.player_choice],app.decks[app.ai_choice],0,42);view.set_process(false);e=view.engine
 await verify_board(true)
 await verify_palette_cameras(true)
 root.size=Vector2i(1280,720);app.layout_dpi_override=320
 app.layout_safe_override=Rect2(60,0,1196,696)
 await frames();app.refresh_responsive_layout();await frames()
 await verify_palette_cameras(true)
 print("BATTLEFIELD PAGING UI: %d checks; failures=%d" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
