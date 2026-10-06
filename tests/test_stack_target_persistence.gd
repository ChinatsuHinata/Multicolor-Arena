extends "res://tests/support/ui_base.gd"
const N=preload("res://scripts/rules/new0921_cards.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const Codec=preload("res://net/state_codec.gd")

func frames(count: int=8):
 for i in range(count):await process_frame

func refresh():
 e.presentation_events.clear();view.reveal_player.reset();view.render();await frames()

func arrows_for(id: int) -> Array:
 return view.stack_target_arrows().filter(func(arrow):return arrow.entry==id)

func screenshot(label: String):
 if DisplayServer.get_name()=="headless":return
 await create_timer(0.6).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/stack-target-persistence/"+label+".png")

func frogs(label: String):
 clean(true);e.debug_free_payment=true
 put(N.id("SPX-003"),"field")
 var red=put(N.id("SPX-004"),"hand")
 expect(e.commit_cast(0,red.uid,{"none":true},[]).is_empty(),label+" Red Frog is cast")
 resolve();e.priority=0
 var green=e.DB.IDS.filter(func(id):return e.cards[id].colors==["绿"])[0]
 var blue=e.DB.IDS.filter(func(id):return e.cards[id].colors==["蓝"])[0]
 for i in range(4):put(green,"palette")
 put(blue,"palette")
 var spell=put("151","hand")
 var options=e.targets_for(spell.card_id,0,spell.uid).filter(func(option):return option.get("x",-1)==2)
 expect(not options.is_empty(),label+" frog spell offers X = 2")
 if options.is_empty():return
 var error=e.commit_cast(0,spell.uid,options[0],[])
 expect(error.is_empty(),label+" two frogs are created by one spell: "+error)
 resolve()
 var batch=e.units(0).filter(func(c):return c.token and e.Cat.race(e,c,"青蛙"))
 expect(batch.size()==2 and e.pending.get("kind","")=="trigger_order",label+" both frog arrivals trigger together")
 if batch.size()!=2 or e.pending.get("kind","")!="trigger_order":return
 e.choose_trigger_order(0)
 var first_id=e.pending.stack_id
 var first_source=e.pending.trigger.source.uid
 var first_target=batch.filter(func(c):return c.uid!=first_source)[0]
 e.choose_effect(e.ref_target(first_target))
 await refresh()
 expect(e.stack.size()==2 and e.pending.get("stack_id",-1)!=first_id,label+" second trigger is announced while the first remains stacked")
 expect(arrows_for(first_id).size()==1,label+" first arrow survives the next target choice")
 var second_id=e.pending.stack_id
 var second_source=e.pending.trigger.source.uid
 var second_target=batch.filter(func(c):return c.uid!=second_source)[0]
 e.choose_effect(e.ref_target(second_target));await refresh()
 expect(view.stack_target_arrows().size()==2,label+" mutual frog targets have two persistent arrows")
 expect(batch.all(func(c):return c.uid in view.selected_uids()),label+" both targets remain highlighted without an active picker")
 view.stack_panel.scroll.scroll_vertical=10000;await frames()
 expect(view.stack_target_arrows().size()==2,label+" scrolling to the lower entry preserves both arrows")
 view.stack_panel.scroll.scroll_vertical=0;await frames()
 expect(view.stack_target_arrows().size()==2,label+" scrolling to the upper entry preserves both arrows")
 await screenshot(label+"-frogs")
 resolve();await refresh()
 expect(e.stack.size()==1 and arrows_for(first_id).size()==1 and arrows_for(second_id).is_empty(),label+" resolving one frog ability removes only its arrow")
 resolve();await refresh()
 expect(e.stack.is_empty() and view.stack_target_arrows().is_empty(),label+" the last frog resolution clears the remaining arrow")

func komachi(label: String,same_target: bool=false):
 clean(true);e.debug_free_payment=true
 var price=put("spell-fdn-019","field");price.timer=2
 var first=put("spell-fdf-056","grave")
 var copy=put("spell-fdf-056","grave")
 var second=put("spell-fdf-045","grave")
 var source=put("character-fdf-029","field");source.leader_counters=1
 e.destroy(source);e.pump_choices()
 expect(e.pending.get("kind","")=="trigger_order" and e.pending.options.size()==2,label+" Price of Life doubles Komachi's death ability")
 if e.pending.get("kind","")!="trigger_order":return
 e.choose_trigger_order(0)
 var first_id=e.pending.stack_id
 e.choose_effect(e.Pack.ref(e,first));await refresh()
 expect(e.stack.size()==2 and arrows_for(first_id).size()==1,label+" grave arrow remains during the second death target choice")
 view.region_picker();await frames()
 expect(view.region_tiles.has(first.uid) and view.region_tiles.has(copy.uid),label+" second search includes both copies")
 if not view.region_tiles.has(first.uid):return
 expect(view.region_tiles[first.uid].get_meta("stack_target_count",0)==1 and view.region_tiles[copy.uid].get_meta("stack_target_count",0)==0,label+" only the exact previously targeted grave card is marked")
 expect(not view.region_tiles[first.uid].get_meta("region_selected",true) and view.region_tiles[first.uid].get_meta("region_legal",false),label+" persistent marking does not select or exclude the prior target")
 expect(view.region_tiles[first.uid].has_node("StackTargetMarker"),label+" prior target has a visible search badge")
 var arrow=arrows_for(first_id)
 expect(arrow.size()==1 and view.region_tiles[first.uid].get_global_rect().grow(8).has_point(arrow[0].to),label+" grave arrow follows the card into the search popup")
 await screenshot(label+"-komachi-search")
 if same_target:
  e.choose_effect(e.Pack.ref(e,first));await refresh()
  expect(view.grave_target_tiles[first.uid].get_meta("stack_target_count",0)==2 and view.stack_target_arrows().size()==2,label+" both death entries can target the same exact grave card")
  resolve();await refresh()
  var remaining=arrows_for(first_id)
  expect(first.zone=="hand" and remaining.size()==1 and not remaining[0].valid,label+" the lower death arrow remains marked invalid after its target leaves the grave")
  expect(first.uid not in view.selected_uids(),label+" invalid grave target does not mark the new hand object")
  await screenshot(label+"-invalid-grave-target")
  resolve();await refresh()
  expect(e.players[0].life==18 and view.stack_target_arrows().is_empty(),label+" invalid death ability finishes without a second recovery or life loss")
  return
 e.choose_effect(e.Pack.ref(e,second));await refresh()
 expect(view.grave_target_tiles[first.uid].get_meta("stack_target_count",0)==1 and view.grave_target_tiles[second.uid].get_meta("stack_target_count",0)==1,label+" separate targets retain separate markers")
 view.browse_zone(0,"grave");await frames()
 var marked=0
 for row in view.browser_cards.get_children():
  if row.get_node("PileCard").get_meta("stack_target_count",0)>0:marked+=1
 expect(marked==2,label+" grave browsing also marks both declared targets")
 view.close_debug();resolve();await refresh()
 expect(second.zone=="hand" and first.zone=="grave" and arrows_for(first_id).size()==1,label+" upper death resolution leaves the lower arrow and target intact")
 expect(second.uid not in view.selected_uids(),label+" a resolved target does not carry a stale marker into hand")
 resolve();await refresh()
 expect(first.zone=="hand" and e.players[0].life==16 and view.stack_target_arrows().is_empty(),label+" both death effects finish and clear their arrows")

func counter(label: String):
 clean(true)
 var spell=e.make_card("164",1,"stack")
 e.stack=[{"id":100,"kind":"card","card":spell,"owner":1,"target":{},"name":e.cards[spell.card_id].name}]
 var response=put("53","field")
 e.push_trigger({"owner":0,"source":response,"name":"响应测试","amount":1,"optional":false},{"stack_id":100})
 await refresh()
 expect(100 in view.table.selected_stacks and view.stack_panel.tiles[100].tile.get_meta("stack_target_count",0)==1,label+" an already responded-to stack card stays marked")
 expect(view.stack_target_sources(e.ref_target(spell)).size()==1,label+" stack and card references identify the same responded-to card")
 e.push_trigger({"owner":0,"source":response,"name":"第二次响应测试","amount":1,"optional":false},{"stack_id":100});await refresh()
 expect(view.stack_panel.tiles[100].tile.get_meta("stack_target_count",0)==2 and view.stack_target_arrows().size()==2,label+" the same card records both unresolved responses")
 view.stack_panel.scroll.scroll_vertical=10000;await frames()
 expect(view.stack_target_arrows().size()==2,label+" an offscreen stack target keeps both response arrows")

func continuation(label: String):
 clean(true)
 var orin=e.DB.IDS.filter(func(key):return e.Roster.has(e.cards[key],"orin_discard"))[0]
 var source=put(orin,"field")
 var target=put("53","field",1)
 put("53","hand")
 var id=e.push_trigger({"owner":0,"source":source,"name":e.cards[orin].name,"ability_text":e.Roster.text(e.cards[orin],"orin_discard"),"effect":"orin_discard","extended":true,"roster":true,"optional":false},e.ref_target(target))
 resolve();await refresh()
 expect(e.stack.is_empty() and e.pending.get("trigger",{}).get("effect","")=="orin_kill",label+" resolution is waiting for its follow-up discard")
 expect(e.unresolved_stack_entries().size()==1 and view.stack_panel.tiles.has(id) and arrows_for(id).size()==1,label+" resolving entry and original arrow remain until the follow-up finishes")
 var row=view.stack_panel.tiles[id].tile.get_parent()
 expect(row.get_child(1).get_node("StackOrder").text=="正在结算" if view.is_android else view.stack_panel.tiles[id].caption.text.begins_with("正在结算"),label+" retained entry is visibly resolving")
 var saved=Codec.capture(e);var restored=e.get_script().new();Codec.restore(restored,saved)
 expect(restored.unresolved_stack_entries().size()==1,label+" save and restore preserve the resolving entry")
 for seat in [0,1]:
  var projection=SeatView.build(e,seat)
  var remote=Remote.new();remote.seat=seat;remote.apply_snapshot(projection)
  expect(remote.unresolved_stack_entries().size()==1 and not remote.pending.resolving_entry.has("target_spec"),label+" network seat %d sees public resolving targets" % seat)
 var observer=Remote.new();observer.apply_snapshot(Observer.build(e))
 expect(observer.unresolved_stack_entries().size()==1 and not observer.pending.has("options"),label+" spectators see the resolving entry without private choices")
 await screenshot(label+"-resolving")
 e.choose_effect({});await refresh()
 expect(e.pending.is_empty() and e.unresolved_stack_entries().is_empty() and arrows_for(id).is_empty(),label+" declining the follow-up completes resolution and clears its arrow")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/stack-target-persistence/"+str(Time.get_ticks_usec()))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://work/stack-target-persistence"))
 root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames();app.load_legacy_test_decks()
 for fixture in [{"size":Vector2i(1600,900),"dpi":0},{"size":Vector2i(1280,720),"dpi":320}]:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  app.is_android=fixture.dpi>0;app.layout_dpi_override=fixture.dpi;root.size=fixture.size
  app.layout_safe_override=Rect2(40,12,fixture.size.x-80,fixture.size.y-36) if app.is_android else Rect2()
  await frames();app.refresh_responsive_layout();app.begin_battle(true);await frames()
  view=app.duel_view;view.set_process(false);e=view.engine
  var label="android" if app.is_android else "desktop"
  await frogs(label);await komachi(label);await komachi(label+"-same",true);await counter(label);await continuation(label)
 app.queue_free();await frames()
 print("STACK TARGET PERSISTENCE: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
