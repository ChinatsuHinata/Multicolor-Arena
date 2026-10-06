extends "res://tests/support/ui_base.gd"

func frames(count: int=8):
 for i in range(count):await process_frame

func tap(button: Control):
 var at=button.get_global_rect().get_center()
 var event=InputEventScreenTouch.new();event.position=at;event.index=0;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func check_clear_controls(title: String):
 var controls=view.hand_zone_tabs.values()
 var selector=view.hud.get_node_or_null("AndroidHandZoneSelector")
 if selector!=null:controls.append(selector)
 for control in controls:
  var rect=control.get_global_rect()
  expect(app.ui_metrics.safe.encloses(rect),title+" source control stays in the safe area")
  expect(not rect.intersects(view.responsive.camera_focus_rect()),title+" source control clears camera focus")
  expect(not rect.intersects(view.hand_scroll.get_global_rect()),title+" source control clears the card row")
  expect(not rect.intersects(view.responsive.hand_toggle_rect),title+" source control clears hand visibility toggle")
  expect(not rect.intersects(view.responsive.own_life),title+" source control clears life display")
  expect(not rect.intersects(view.hud.get_node("AndroidCameraFocusToggle").get_global_rect()),title+" source control clears camera toggle")
  for card in e.players[0].field+e.players[1].field:
   var node=view.table.visuals.get("card_"+str(card.uid))
   if node!=null:expect(not rect.intersects(view.projected_card_rect(node)),title+" source control clears unit "+str(card.uid))

func fixture(top_down: bool):
 clean();view.hand_zones={0:"hand",1:"hand"}
 view.android_palette_view=false;view.android_focus_owner=0
 view.table.set_top_down_view(top_down)
 for who in range(2):
  for i in range(6):put(["100","164","169"][i%3],"palette",who)
  put("53","field",who);put("53","hand",who)
 view.render();await settle();view.reset_camera_view();await frames()
 var camera=view.table.camera.global_transform
 var area=view.responsive.camera_focus_rect()
 var keine=e.make_card("character-fdf-ex05",0,"field",true)
 e.players[0].leader=keine;e.players[0].field.append(keine)
 put("character-ucs-068","field")
 put("53","deck");put("21","grave")
 var eaten=put("53","exile",1);eaten.devour_owner=0
 e.players[0].palette_access=e.turn
 view.render();await settle();await frames()
 expect(view.available_hand_zones(0)==["hand","grave","exile","deck","palette"],"real permissions expose all five casting regions")
 expect(view.responsive.camera_focus_rect()==area and view.table.camera.global_transform.is_equal_approx(camera),"region permissions preserve battlefield framing "+str(top_down))
 check_clear_controls("battlefield "+str(top_down))
 for owner in [0,1,-1]:
  await tap(view.hud.get_node("AndroidCameraFocusToggle"));await settle();await frames()
  expect(view.android_palette_view==(owner>=0) and (owner<0 or view.android_palette_focus_owner()==owner),"native camera cycle works with region permissions "+str(owner))
  expect(view.responsive.camera_focus_rect().size.y>=150,"region controls leave useful camera height "+str(owner))
  expect(view.responsive.camera_focus_rect().grow(2).encloses(view.projected_android_focus(view.android_focus_bounds())),"region controls preserve focus bounds "+str(owner))
  check_clear_controls("focus "+str(owner))
 var selector=view.hud.get_node_or_null("AndroidHandZoneSelector")
 expect(selector!=null,"Android has a compact source selector")
 if selector==null:return
 camera=view.table.camera.global_transform
 await tap(selector)
 expect(app.menu_popup_open(),"native source tap opens region selection")
 if not app.menu_popup_open():return
 expect(app.menu_popup.actions.size()==5,"all usable regions can be selected")
 var original_menu=app.menu_popup
 for menu_button in app.menu_popup.actions:
  expect(app.ui_metrics.safe.encloses(menu_button.get_global_rect()),"region menu option stays in safe area: "+menu_button.text)
 await tap(selector)
 expect(app.menu_popup==original_menu,"open region menu blocks background selector touches")
 await click(find_button(app.menu_popup,"除外区").get_global_rect().get_center());await settle()
 expect(not app.menu_popup_open() and view.hand_zones[0]=="exile" and view.hand_nodes.has(eaten.uid),"exile selection shows Keine's consumed opposing card")
 expect(view.table.camera.global_transform.is_equal_approx(camera),"changing casting region preserves camera transform")
 await tap(view.hand_nodes[eaten.uid]);await frames()
 expect(view.local.get("uid",0)==eaten.uid and view.android_palette_view,"consumed card starts payment and automatic palette focus")
 view.cancel_cast();await frames()
 expect(not view.android_palette_view and view.table.camera.global_transform.is_equal_approx(camera),"cancelling consumed card restores the battlefield camera")
 for zone in ["grave","deck","palette","hand"]:
  await tap(view.hud.get_node("AndroidHandZoneSelector"))
  await click(find_button(app.menu_popup,view.ZONE_NAMES[zone]).get_global_rect().get_center());await frames()
  expect(view.hand_zones[0]==zone and view.hand_nodes.keys()==view.displayed_hand_cards(0).map(func(card):return card.uid),"region selector displays correct source cards: "+zone)
  expect(view.table.camera.global_transform.is_equal_approx(camera),"region selection keeps camera position: "+zone)
 view.set_hand_display(false);await frames()
 expect(view.hud.get_node_or_null("AndroidHandZoneSelector")==null,"hiding cards also hides the source selector")
 view.set_hand_display(true);await frames()
 expect(view.hud.get_node_or_null("AndroidHandZoneSelector")!=null,"showing cards restores the source selector")
 await capture("android-cast-zones-"+str(top_down)+"-dpi"+str(app.layout_dpi_override))

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-cast-zones/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 app.is_android=true;app.load_legacy_test_decks()
 var densities=[240.0,320.0,360.0]
 if "--quick" in OS.get_cmdline_user_args():densities=[360.0]
 for dpi in densities:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  app.layout_dpi_override=dpi;app.refresh_ui_metrics();app.begin_battle(true)
  view=app.duel_view;view.set_process(false);e=view.engine;await frames()
  for top_down in [true,false]:await fixture(top_down)
 view.queue_free();app.duel_view=null;await frames()
 app.is_android=false;app.layout_dpi_override=0;app.refresh_ui_metrics();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine;await frames();clean()
 put("21","grave");put("169","palette");view.render();await frames()
 expect(view.hud.get_node_or_null("AndroidHandZoneSelector")==null and view.hand_zone_tabs.has("0:grave"),"desktop retains its original source tabs")
 print("ANDROID CAST ZONES: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
