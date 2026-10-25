extends "res://tests/support/ui_base.gd"
const Preview=preload("res://scripts/shop_preview.gd")
const Fixture=preload("res://tests/support/fx_registry_fixture.gd")

class OfflineTasks extends "res://scripts/task_service.gd":
 func refresh():pass

func frames(count: int=6):
 for i in range(count):await process_frame

func click(at: Vector2,button: int=MOUSE_BUTTON_LEFT):
 var motion=InputEventMouseMotion.new();motion.position=at;motion.global_position=at
 root.push_input(motion,true);await process_frame
 await super.click(at,button)

func key(code: int):
 var event=InputEventKey.new();event.keycode=code;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func tap(at: Vector2):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func battle_snapshot(preview) -> String:
 var model=preview.engine
 return JSON.stringify([model.players,model.turn,model.phase,model.winner,model.revision,model.stack,model.pending,model.emote_ready_at,model.task_stats])

func check_layout(preview):
 var safe=app.ui_metrics.safe.grow(2)
 expect(safe.encloses(preview.exit_button.get_global_rect()),"exit fits safe area")
 expect(safe.encloses(preview.surface.get_global_rect()) and preview.surface.size.y>150,"preview has a visible battlefield")
 for button in preview.emote_bar.get_children():
  expect(safe.encloses(button.get_global_rect()) and button.size.y>=app.ui_metrics.hit,"emote touch target fits: "+button.name)
  expect(not preview.surface.get_global_rect().intersects(button.get_global_rect()),"emote control does not cover battlefield")

func check_spell_placement(preview):
 for card in preview.engine.players[0].palette:
  var node=preview.table.visuals["card_"+str(card.uid)]
  var screen=preview.table.camera.unproject_position(node.global_position)
  expect(is_equal_approx(node.rotation.y,PI/2),"spell preview card lies sideways")
  expect(screen.x>preview.viewport.size.x*0.5 and Rect2(Vector2.ZERO,Vector2(preview.viewport.size)).has_point(screen),"spell preview card sits visibly on the right")

func check_entrance_flight(preview):
 preview.set_process(false);preview.play_effect()
 var node=preview.subject_node();var module=preview.stage.active[0]
 expect(preview.entrance_flying and module.owns_flight() and not node.visible,"entrance starts with a flying proxy and no stationary duplicate")
 expect(module.in_flight() and is_equal_approx(module.flight_seconds(),preview.entrance_duration),"front half of the effect shares the preview flight duration")
 var start=module.proxy.global_transform
 preview.advance_effects(preview.entrance_duration*0.5)
 expect(preview.entrance_flying and module.proxy.global_position.distance_to(start.origin)>0.1 and not module.proxy.global_position.is_equal_approx(preview.entrance_landing.origin),"card flies toward the battlefield while the front half plays")
 await capture("shop-preview-entrance-flight")
 preview.advance_effects(preview.entrance_duration*0.5+0.01)
 expect(not preview.entrance_flying and node.visible and node.global_transform.is_equal_approx(preview.entrance_landing),"real card appears exactly at its landing")
 expect(module.landed and not module.proxy.visible and module.playing and preview.stage.active==[module],"landing hides the proxy and continues the same effect's back half")
 preview.advance_effects(0.2)
 await capture("shop-preview-entrance-landed")
 preview.advance_effects(module.budget)
 preview._process(Preview.LOOP_GAP+0.01)
 expect(preview.entrance_flying and not node.visible and preview.stage.active.size()==1 and preview.stage.active[0]!=module,"every loop starts a new flight before landing")
 preview.set_process(true)

func run():
 var folder="res://work/shop-preview/"+str(Time.get_ticks_usec())
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 Store.Paths.root_override=ProjectSettings.globalize_path(folder)
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900)
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate()
 app.settings_path=folder.path_join("settings.json");app.account_session_path=folder.path_join("account.json")
 app.tutorial_local_directory=folder.path_join("tutorials");app.tournament_server_url="ws://127.0.0.1:1"
 app.task_service.free();app.task_service=OfflineTasks.new()
 root.add_child(app);await frames(25)
 app.open_shop();await frames()
 var popup=app.menu_popup
 popup.select_category(1);await frames()
 var inventory_before=JSON.stringify([app.shop_inventory.preferences,app.shop_inventory.purchased_ids,app.task_service.snapshot])
 var entry=popup.find_child("PreviewProduct_emotes_reimu",true,false)
 expect(entry!=null and not entry.disabled,"unowned dialogue can be previewed while signed out")
 await click(entry.get_global_rect().get_center());await frames()
 var preview=popup.preview
 if not is_instance_valid(preview):expect(false,"preview opens from desktop button");finish();return
 expect(not popup.panel.visible and app.page=="menu" and not is_instance_valid(app.duel_view),"preview hides shop without starting a match")
 expect(preview.subject.card_id=="character-rei-001" and preview.subject.zone=="field","selected leader stands on battlefield")
 check_layout(preview)
 var before=battle_snapshot(preview)
 for kind in Preview.KINDS:
  await click(preview.emote_bar.get_node("PreviewEmote_"+kind).get_global_rect().get_center())
  expect(is_instance_valid(preview.bubble) and preview.bubble.kind==kind,"all six emotes work without cooldown: "+kind)
 expect(battle_snapshot(preview)==before,"emotes including surrender never change match state")
 await click(preview.surface.get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
 await drag(preview.surface.get_global_rect().get_center(),preview.surface.get_global_rect().get_center()+Vector2(150,100))
 for code in [KEY_SPACE,KEY_H,KEY_D,KEY_F1,KEY_F2,KEY_BACKSPACE]:await key(code)
 for i in range(10):
  await key(KEY_TAB)
  expect(preview.is_ancestor_of(root.gui_get_focus_owner()),"keyboard focus stays inside preview")
 expect(battle_snapshot(preview)==before and app.menu_popup==popup,"battle clicks, dragging and shortcuts cannot perform actions")
 await capture("shop-preview-desktop")
 await key(KEY_ESCAPE)
 expect(not is_instance_valid(popup.preview) and popup.panel.visible and popup.selected==1,"Escape returns to original category")
 expect(root.gui_get_focus_owner()==entry,"desktop preview restores button focus")
 popup.open_preview(app.shop_inventory.product("emotes_reimu"));await frames()
 preview=popup.preview;app.menu();await frames()
 expect(app.menu_popup==popup and popup.preview==preview and not preview.closing,"menu refresh preserves active preview")
 preview.show_emote("greeting");expect(is_instance_valid(preview.bubble),"preview still responds after menu refresh")
 popup.close_preview();await frames()
 # Every shipped leader uses its own dialogue, including dual-speaker styling.
 for product in app.shop_inventory.catalogue:
  if product.category!="emotes":continue
  popup.open_preview(product);await frames(2);preview=popup.preview
  preview.show_emote("threat")
  expect(preview.bubble.message==Preview.Profiles.PROFILES[product.leader_id].lines.threat,"product-specific dialogue: "+product.id)
  if product.id=="emotes_satori_koishi":
   expect(preview.bubble.distort_reply and preview.bubble.red_reply,"dual speaker preview retains the battle text effect")
  popup.close_preview();await frames(2)
 # Shipped free effects can be previewed before claiming, with a real caster
 # and target for the character spell.
 for product in app.shop_inventory.catalogue:
  if product.category not in ["entrance","spell"]:continue
  popup.open_preview(product);await frames(2);preview=popup.preview
  expect(preview.effect_available and preview.stage.active.size()==1 and preview.stage.active[0].id==product.fx,"unowned free effect previews its bound module: "+product.id)
  if product.category=="spell" and not preview.stage.active.is_empty():
   var module=preview.stage.active[0]
   expect(module.has_origin() and module.destinations().size()==1 and module.palette_character_spells()==1,"dream orbs preview has Reimu, a target and one character spell")
   check_spell_placement(preview)
  elif product.category=="entrance":await check_entrance_flight(preview)
  await capture("shop-preview-"+product.category)
  popup.close_preview();await frames(2)
 # Exercise both binding forms with memory-only fixtures, excluding unrelated
 # free effects. No fake products or effects enter the shipped catalogue.
 for category in ["entrance","spell"]:
  var product={"id":"TEST_ONLY_"+category,"category":category,"name":"测试特效","price":1}
  var registry=Fixture.create()
  if category=="entrance":product.fx="probe_entrance"
  else:registry.definitions.probe_spell.shop_product=product.id
  var unrelated=registry.definitions["probe_"+category].duplicate(true);unrelated.id="unrelated";unrelated.erase("shop_product")
  registry.definitions.unrelated=unrelated
  popup.catalogue.append(product);popup.select_category(2 if category=="entrance" else 3);await frames()
  var effect_entry=popup.find_child("PreviewProduct_"+product.id,true,false)
  expect(effect_entry!=null,"effect category has a preview entry: "+category)
  await click(effect_entry.get_global_rect().get_center());await frames();preview=popup.preview
  expect(not preview.effect_available and preview.hint.text.contains("暂不可"),"missing effect is reported without unrelated playback")
  preview.configure_effect(registry);await frames(2)
  if category=="entrance":
   expect(preview.entrance_flying and preview.stage.active.is_empty(),"after-only entrance still flies in before its effect starts")
   preview.advance_effects(preview.entrance_duration+0.01)
  expect(preview.stage.active.size()==1 and preview.stage.active[0].id=="probe_"+category,"preview plays only the selected effect")
  expect(preview.emote_bar.get_child_count()==0,"effect preview only exposes exit")
  app.menu();await frames()
  expect(not preview.closing and preview.is_processing(),"menu refresh keeps effect loop running")
  before=battle_snapshot(preview)
  for i in range(4):
   var module=preview.stage.active[0]
   expect(module.holder.get_parent()==(preview.subject_node() if category=="entrance" else preview.stage.layer("spell")),"effect uses correct battle attachment")
   module.advance(module.budget+0.01)
   preview._process(Preview.LOOP_GAP+0.01);await frames(2)
   if category=="entrance":preview.advance_effects(preview.entrance_duration+0.01)
   expect(preview.stage.active.size()==1 and preview.stage.active[0]!=module,"effect restarts after completion")
  expect(preview.stage.get_child_count()<=2,"loop releases completed modules")
  expect(battle_snapshot(preview)==before,"effect loops never advance the battle")
  var old_stage=weakref(preview.stage)
  await click(preview.exit_button.get_global_rect().get_center());await frames()
  expect(old_stage.get_ref()==null,"exiting destroys effect stage and loops")
  popup.catalogue.erase(product)
 app.close_menu_popup();await frames()
 app.is_android=true
 for case in [{"size":Vector2i(1280,720),"dpi":240.0},{"size":Vector2i(2340,1080),"dpi":360.0},{"size":Vector2i(1280,720),"dpi":420.0}]:
  root.size=case.size;app.layout_dpi_override=case.dpi
  app.layout_safe_override=Rect2(60,0,case.size.x-84,case.size.y-24)
  await frames();app.menu();await frames();app.open_shop();await frames()
  popup=app.menu_popup;popup.select_category(1);await frames()
  expect(popup.grid.find_child("PreviewProduct_*",true,false)==null,"Android keeps preview off the compact product tile")
  popup.show_product_details(app.shop_inventory.product("emotes_reimu"));await frames()
  entry=popup.detail_panel.find_child("PreviewProduct_emotes_reimu",true,false)
  expect(entry!=null and popup.detail_panel.get_global_rect().encloses(entry.get_global_rect()),"Android details contain preview button")
  await click(entry.get_global_rect().get_center());await frames();preview=popup.preview
  check_layout(preview)
  var threat=preview.emote_bar.get_node("PreviewEmote_threat")
  await tap(threat.get_global_rect().get_center())
  expect(is_instance_valid(preview.bubble) and preview.bubble.kind=="threat","native Android touch sends dialogue")
  expect(app.ui_metrics.safe.encloses(Rect2(preview.bubble.position,preview.bubble.size*preview.bubble.scale)),"scaled dialogue bubble fits Android safe area")
  await capture("shop-preview-android-%d" % int(case.dpi))
  var details=popup.detail_overlay
  await tap(preview.exit_button.get_global_rect().get_center())
  expect(not is_instance_valid(popup.preview) and popup.detail_overlay==details and details.visible,"native touch exit restores Android details")
  var mouse=InputEventMouseButton.new();mouse.device=-1;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;mouse.position=entry.get_global_rect().get_center()
  root.push_input(mouse,true);mouse=mouse.duplicate();mouse.pressed=false;root.push_input(mouse,true);await frames()
  expect(not is_instance_valid(popup.preview),"synthetic touch mouse cannot reopen preview")
  popup.open_preview(app.shop_inventory.product("emotes_reimu"));await frames()
  await key(KEY_BACK)
  expect(not is_instance_valid(popup.preview) and popup.detail_overlay==details,"Android Back exits preview before details")
  popup.open_preview(app.shop_inventory.product("spell_reimu_dream_orbs"));await frames(2)
  check_layout(popup.preview);check_spell_placement(popup.preview)
  await capture("shop-preview-spell-android-%d" % int(case.dpi))
  popup.close_preview();await frames(2)
  app.close_menu_popup();await frames()
 expect(JSON.stringify([app.shop_inventory.preferences,app.shop_inventory.purchased_ids,app.task_service.snapshot])==inventory_before,"preview never writes ownership, equipment, wallet or task progress")
 finish()

func finish():
 print("SHOP PREVIEW: ",checks," checks; ",failures.size()," failures")
 if is_instance_valid(app):app.queue_free();await frames()
 quit(0 if failures.is_empty() else 1)
