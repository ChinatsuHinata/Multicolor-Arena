extends "res://tests/support/ui_base.gd"

func frames(count: int=8):
 for i in range(count):await process_frame

func refresh():
 e.presentation_events.clear();view.reveal_player.reset();view.render();await frames()
 view.update_badge_positions()

func shot(label: String):
 if DisplayServer.get_name()=="headless":return
 await create_timer(0.25).timeout;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/pile-target-layout/"+label+".png")

func scenario(label: String,top_down: bool):
 clean(true);e.stack=[];view.picker.reset();view.inspect_id="";view.update_inspection()
 view.android_palette_view=false;view.table.set_top_down_view(top_down);view.reset_camera_view()
 var source=put("53","field")
 var all=[];var groups=[]
 for who in range(2):
  for zone in ["grave","exile"]:
   put("54",zone,who)
   var cards=[]
   for index in range(3 if zone=="grave" else 1):cards.append(put(str(53+index),zone,who))
   groups.append(cards);all.append_array(cards)
 await refresh();await create_timer(0.3).timeout
 var camera_before=view.table.camera.global_transform
 var order_before=[]
 for who in range(2):
  for zone in ["grave","exile"]:order_before.append(e.players[who][zone].map(func(c):return c.uid))
 var first=groups[0][2]
 var old_id=e.push_trigger({"owner":0,"source":source,"name":"先前墓地目标","optional":false},e.ref_target(first))
 await refresh()
 var toggle_before=view.stack_panel.toggle_button.get_global_rect() if app.is_android else Rect2()
 var newer_refs=[e.ref_target(first)]
 newer_refs.append_array(all.filter(func(c):return c.uid!=first.uid).map(func(c):return e.ref_target(c)))
 var new_id=e.push_trigger({"owner":1,"source":source,"name":"响应：共享墓地与除外目标","optional":false},{"parts":newer_refs})
 await refresh()
 if app.is_android:
  var toggle=view.stack_panel.toggle_button.get_global_rect()
  expect(toggle==toggle_before,label+" target count never moves the stack toggle")
  expect(app.ui_metrics.safe.encloses(toggle) and not toggle.intersects(view.responsive.toolbar_rect) and not toggle.intersects(view.OPPONENT_HAND_COUNT),label+" stack toggle stays in safe space beside the hand count and below toolbar")
  for target in view.table.pile_target_visuals.values():
   expect(not toggle.intersects(view.projected_card_rect(target)),label+" stack toggle leaves exposed target "+str(target.get_meta("uid",0))+" clear")
 expect(view.grave_target_tiles.size()==all.size(),label+" shares repeated physical targets")
 expect(view.grave_target_tiles[first.uid].get_meta("stack_target_count")==2,label+" identifies both stack references")
 expect(view.table.pile_target_visuals.size()==all.size(),label+" one borderless world card per target")
 expect(view.table.camera.global_transform.is_equal_approx(camera_before),label+" target cards do not move or shrink the camera")
 var order_after=[]
 for who in range(2):
  for zone in ["grave","exile"]:
   order_after.append(e.players[who][zone].map(func(c):return c.uid))
   var key=("p" if who==0 else "a")+zone
   expect(view.table.piles[key].get_meta("count")==e.players[who][zone].size(),label+" "+key+" includes exposed cards in count")
   expect(not view.grave_target_tiles.has(view.table.piles[key].get_node("Hit").get_meta("uid")),label+" "+key+" does not duplicate the exposed top card")
 expect(order_before==order_after,label+" preserves real zones and card order")
 for c in all:
  var tile=view.grave_target_tiles[c.uid]
  expect(tile is Node3D and tile.has_node("Face") and not tile.has_node("Outline") and not tile.has_node("Halo"),label+" target "+str(c.uid)+" is a borderless 3D card")
  expect(view.target_rect(e.ref_target(c))==view.projected_card_rect(tile),label+" arrow points to world target "+str(c.uid))
  await physics_frame
  expect(view.table.card_at(view.stage_point(view.project(tile.global_position)))==c.uid,label+" target "+str(c.uid)+" uses table hit detection")
 expect(view.grave_target_tiles[first.uid].position.z<view.grave_target_tiles[groups[0][0].uid].position.z,label+" repeated target moves to top of newest declaration")
 var arrows=view.stack_target_arrows()
 expect(arrows.filter(func(a):return a.entry==old_id).size()==1 and arrows.filter(func(a):return a.entry==new_id).size()==all.size(),label+" all unresolved stack arrows retain destinations")
 var exposed=view.table.pile_target_visuals[first.uid]
 var original_position=exposed.position
 view.table.camera_offset+=Vector3(0.25,0,0.25);view.table.set_camera();view.update_badge_positions()
 expect(exposed.position==original_position,label+" panning never changes target world placement")
 view.table.camera_offset-=Vector3(0.25,0,0.25);view.table.set_camera();view.update_badge_positions()
 await shot(label)
 if app.is_android:
  var card=groups[2 if view.local_seat==0 else 0][0]
  var point=view.project(view.table.pile_target_visuals[card.uid].global_position)
  expect(view.touch_camera_available(point),label+" exposed grave card supports native touch")
  var touch=InputEventScreenTouch.new();touch.index=0;touch.position=point;touch.pressed=true
  root.push_input(touch,true)
  await create_timer(preload("res://scripts/card_preview_hold_settings.gd").seconds+0.25).timeout
  expect(view.inspection.visible and view.inspect_uid==card.uid,label+" native long press previews the exposed card")
  touch=touch.duplicate();touch.pressed=false;root.push_input(touch,true);await frames()
  view.inspect_id="";view.update_inspection();view.android_card_touch.cancel()
 else:
  var card=groups[2 if view.local_seat==0 else 0][0]
  var point=view.project(view.table.pile_target_visuals[card.uid].global_position)
  await click(point,MOUSE_BUTTON_RIGHT);await frames()
  expect(view.inspect_uid==card.uid,label+" desktop right click previews exposed card")
  view.inspect_id="";view.update_inspection()
 var old_epoch=first.epoch
 first.epoch+=1
 await refresh()
 expect(not view.grave_target_tiles.has(first.uid),label+" stale epoch removes exposed card")
 expect(view.stack_target_arrows().filter(func(a):return a.entry==old_id).all(func(a):return not a.valid),label+" stale epoch keeps invalid reference distinct")
 first.epoch=old_epoch;e.stack=e.stack.filter(func(entry):return entry.id==old_id)
 await refresh()
 expect(view.grave_target_tiles.size()==1 and view.grave_target_tiles.has(first.uid),label+" resolving response retains only earlier target")
 e.stack=[];await refresh()
 expect(view.grave_target_tiles.is_empty() and view.stack_target_arrows().is_empty(),label+" clear stack restores normal piles")
 expect(view.table.piles.pgrave.get_node("Hit").get_meta("uid")==groups[0].back().uid,label+" top card restored after targets clear")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/pile-target-layout/"+str(Time.get_ticks_usec()))
 DirAccess.make_dir_recursive_absolute(Store.Paths.root_override)
 root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(1600,900);root.gui_embed_subwindows=true
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate()
 app.settings_path=Store.Paths.root_override.path_join("settings.json");app.account_session_path=Store.Paths.root_override.path_join("account.json");app.tutorial_local_directory=Store.Paths.root_override.path_join("tutorials")
 root.add_child(app);await frames();app.load_legacy_test_decks()
 for android in [false,true]:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  app.is_android=android;app.layout_dpi_override=320 if android else 0;root.size=Vector2i(1280,720) if android else Vector2i(1600,900)
  app.layout_safe_override=Rect2(40,12,1200,684) if android else Rect2()
  await frames();app.refresh_responsive_layout();app.begin_battle(true);await frames()
  view=app.duel_view;view.set_process(false);e=view.engine
  for seat in range(2):
   view.local_seat=seat;view.table.local_seat=seat
   for top_down in [false,true]:
    await scenario(("android" if android else "desktop")+("-2d" if top_down else "-3d")+("-seat1" if seat==1 else ""),top_down)
 app.queue_free();await frames()
 print("PILE TARGET LAYOUT: %d checks; %d failures" % [checks,failures.size()]);quit(0 if failures.is_empty() else 1)
