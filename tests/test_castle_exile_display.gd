extends "res://tests/support/ui_base.gd"
const SeatProjection=preload("res://net/seat_projection.gd")
const ObserverProjection=preload("res://net/observer_projection.gd")
const Remote=preload("res://net/remote_duel.gd")

func frames(count: int=5):
 for i in range(count):await process_frame

func shoot(name: String):
 if DisplayServer.get_name()=="headless" or not OS.get_cmdline_user_args().has("--capture"):return
 var folder="res://.godot-toolchain/logs/castle-exile-display"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await RenderingServer.frame_post_draw
 expect(root.get_texture().get_image().save_png(folder.path_join(name+".png"))==OK,"captured "+name)

func exile_with_castle(source: Dictionary,unit: Dictionary):
 e.Pack.resolve_trigger(e,{"owner":source.owner,"source":source.duplicate(true),"effect":"castle_exile","target":{"picks":[[e.ref_target(unit)]]}})

func check_under(source: Dictionary,unit: Dictionary,prefix: String):
 var key="card_"+str(unit.uid)
 var front=view.table.descriptors["card_"+str(source.uid)]
 expect(view.table.descriptors.has(key),prefix+" temporarily exiled unit has an underlay")
 if not view.table.descriptors.has(key):return
 var under=view.table.descriptors[key]
 expect(under.zone=="exile" and under.castle_uid==source.uid,prefix+" display links the real exile to the correct castle")
 expect(is_zero_approx(under.rotation.y) and is_equal_approx(absf(front.rotation.y),PI/2),prefix+" unit is upright underneath the horizontal castle")
 expect(under.at.y<front.at.y and absf(under.at.x-front.at.x)<0.001,prefix+" castle is visibly above its aligned exiled unit")
 expect(not view.card_badges.has(key),prefix+" underlay has no battlefield unit statistics")
 var hit=view.table.visuals[key].get_node("Hit")
 expect(hit.get_meta("uid")==unit.uid and not str(hit.get_meta("caption","")).is_empty(),prefix+" exposed underlay retains its inspectable card identity")
 expect(unit.zone=="exile" and e.players[unit.owner].exile.has(unit),prefix+" actual card remains in its owner's exile zone")

func check_mode(android: bool):
 if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
 root.size=Vector2i(1280,720) if android else Vector2i(1600,900)
 app.is_android=android;app.layout_dpi_override=240.0 if android else 0.0
 app.layout_safe_override=Rect2(24,0,1232,696) if android else Rect2()
 app.refresh_ui_metrics();app.begin_battle(true);await frames()
 view=app.duel_view;view.set_process(false);e=view.engine;clean()
 var castle=put("field-smm-004","field")
 var unit=put("character-soi-006","field",1)
 var second=put("field-smm-004","field",1)
 var other=put("character-soi-006","field")
 var unrelated=put("169","exile",1)
 exile_with_castle(castle,unit);exile_with_castle(second,other)
 e.presentation_events.clear();view.reveal_player.reset();view.render();await frames()
 var prefix="android" if android else "desktop"
 var before=snapshot()
 check_under(castle,unit,prefix+" own castle")
 check_under(second,other,prefix+" opponent castle")
 expect(not view.table.descriptors.has("card_"+str(unrelated.uid)),prefix+" unrelated exiled cards remain solely in the exile pile")
 expect(view.table.piles.aexile.get_meta("count")==2,prefix+" exile count includes the card shown under a castle")
 await shoot(prefix+"-castles")
 for who in range(2):
  view.browse_zone(who,"exile");await frames()
  var expected=unit.uid if who==1 else other.uid
  expect(view.browser_cards.get_children().any(func(tile):return int(tile.get_node("PileCard").get_meta("browser_uid",-1))==expected),prefix+" exile browser still contains the linked card for seat "+str(who))
  view.close_debug();await frames()
 expect(snapshot()==before,prefix+" rendering and browsing do not mutate the duel")
 var authority=e
 for perspective in [0,1,-1]:
  var projection=ObserverProjection.build(authority) if perspective==-1 else SeatProjection.build(authority,perspective)
  var remote=Remote.new();remote.apply_snapshot(projection)
  view.table.duel=remote
  var projected=view.table.layout()
  expect(projected.has("card_"+str(unit.uid)) and projected["card_"+str(unit.uid)].castle_uid==castle.uid,prefix+" public castle link survives network perspective "+str(perspective))
 view.table.duel=authority
 e.move_to(castle,"grave");e.presentation_events.clear();view.render();await frames()
 expect(unit.zone=="field" and not view.table.descriptors["card_"+str(unit.uid)].has("castle_uid"),prefix+" castle leaving returns the unit and removes its underlay")
 clean()
 castle=put("field-smm-004","field");unit=put("character-soi-006","field",1)
 exile_with_castle(castle,unit)
 e.move_to(unit,"hand");e.move_to(unit,"exile")
 e.presentation_events.clear();view.render();await frames()
 expect(not view.table.descriptors.has("card_"+str(unit.uid)),prefix+" leaving and reentering exile invalidates the old instance link")
 clean()
 castle=put("field-rei-013","field");unit=put("character-soi-006","exile",1)
 castle.catalogue_castle=[e.Pack.ref(e,unit)]
 e.presentation_events.clear();view.render();await frames()
 check_under(castle,unit,prefix+" legacy castle link")
 castle.castle_exiles=castle.catalogue_castle.duplicate(true)
 view.render();await frames()
 expect(view.table.descriptors.values().filter(func(d):return d.uid==unit.uid).size()==1,prefix+" duplicate legacy and current links render one underlay")
 castle.catalogue_castle=[];castle.castle_exiles=[]
 view.render();await frames()
 expect(not view.table.visuals.has("card_"+str(unit.uid)),prefix+" unlinking removes the stale visual immediately")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/castle-exile-display/"+str(Time.get_ticks_usec()))
 root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames();app.load_legacy_test_decks()
 await check_mode(false);await check_mode(true)
 print("CASTLE EXILE DISPLAY: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
