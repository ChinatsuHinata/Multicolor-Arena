extends "res://tests/support/ui_base.gd"
const Config=preload("res://scripts/tutorial/config.gd")
const Runtime=preload("res://scripts/tutorial/runtime.gd")
var output="res://work/tutorial-battle-presentation"

func frames(count: int=6):
 for i in range(count):await process_frame

func shot(title: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(title+".png"))

func info(next_id: String,camera: String="",zone: Dictionary={},targets: Array=[]) -> Dictionary:
 var step={"type":"info","guide":{"text":"查看指定视角、区域和红框卡牌。","targets":targets},"next":next_id}
 if not camera.is_empty():step.camera_view=camera
 if not zone.is_empty():step.open_zone=zone
 return step

func fixture() -> Dictionary:
 var players=[]
 for who in range(2):
  players.append({"leader":{"card_id":"70","alias":"leader"+str(who)},"deck_order":[{"card_id":"53"}],"field":[{"card_id":"53","alias":"unit"+str(who)},{"card_id":"164","alias":"book"+str(who)},{"card_id":"164","alias":"copy"+str(who)}],"palette":[{"card_id":"70","alias":"resource"+str(who)}],"grave":[{"card_id":"53"},{"card_id":"100"}],"exile":[{"card_id":"164"}]})
 return {"schema_version":1,"id":"battle_presentation","title":"战场步骤呈现","initial_scenario":"board","start_step":"board","completion":{"type":"always"},"scenarios":{"board":{"seed":42,"players":players}},"steps":{
  "board":info("own","battlefield",{},[{"alias":"unit0"},{"alias":"book0"}]),
  "own":info("enemy","own_palette",{},[{"alias":"resource0"}]),
  "enemy":info("own_grave","enemy_palette",{},[{"alias":"resource1"}]),
  "own_grave":info("enemy_grave","",{"player":0,"zone":"grave"},[{"alias":"unit1"}]),
  "enemy_grave":info("own_exile","",{"player":1,"zone":"grave"}),
  "own_exile":info("enemy_exile","",{"player":0,"zone":"exile"}),
  "enemy_exile":info("task","",{"player":1,"zone":"exile"}),
  "task":{"type":"task","camera_view":"battlefield","guide":{"text":"等待卡牌离场，可重置局面。","popup":"hidden","next_button":"hidden","targets":[{"alias":"unit0"}]},"task":{"success":{"type":"entity_zone","alias":"unit0","zone":"exile"}},"next":"$complete"}
 }}

func check_validation():
 var data=fixture()
 expect(Config.new().validate(data,Store.CARDS).ok,"battle presentation fixture validates")
 for value in ["unknown",0,true,{}]:
  var invalid=data.duplicate(true);invalid.steps.board.camera_view=value
  var checked=Config.new().validate(invalid,Store.CARDS)
  expect(not checked.ok and str(checked.errors).contains("steps.board.camera_view"),"invalid camera reports the step field "+str(value))
 for value in [{"player":2,"zone":"grave"},{"player":0.5,"zone":"grave"},{"player":0,"zone":"hand"},{"zone":"exile"},[],{"player":0,"zone":"grave","extra":true}]:
  var invalid=data.duplicate(true);invalid.steps.board.open_zone=value
  var checked=Config.new().validate(invalid,Store.CARDS)
  expect(not checked.ok and str(checked.errors).contains("steps.board.open_zone"),"invalid zone reports the step field "+str(value))
 var deck=Config.new().load_file("res://data/tutorial/beginner/t1.json",Store.CARDS).data
 for key in ["camera_view","open_zone"]:
  var invalid=deck.duplicate(true);invalid.steps[invalid.start_step][key]="battlefield" if key=="camera_view" else {"player":0,"zone":"grave"}
  expect(not Config.new().validate(invalid,Store.CARDS).ok,"deck scene rejects battlefield-only "+key)
 var invalid=data.duplicate(true);invalid.steps.board.guide.targets=[{"alias":"missing"}]
 expect(not Config.new().validate(invalid,Store.CARDS).ok,"red frames require an existing scene alias")

func check_scene_restore():
 var data=fixture()
 data.scenarios.second=data.scenarios.board.duplicate(true)
 data.steps={
  "board":info("second","enemy_palette",{"player":1,"zone":"grave"}),
  "second":info("resume","own_palette"),
  "resume":info("reset"),"reset":info("$complete")
 }
 data.steps.second.scenario="second"
 data.steps.resume.scenario="board";data.steps.resume.scenario_mode="resume"
 data.steps.reset.scenario="board"
 var flow=Runtime.new();expect(flow.start(data,Store.CARDS).is_empty(),"scene camera restore fixture validates")
 expect(flow.next() and flow.presentation.camera_view=="own_palette","new scenario applies its step camera")
 expect(flow.next() and flow.presentation.camera_view=="enemy_palette" and flow.presentation.open_zone.is_empty(),"resumed scenario retains its camera and clears the prior step browser")
 expect(flow.next() and flow.presentation.camera_view.is_empty(),"reset scenario restores default camera behavior")
 flow.free()

func red(uid: int) -> bool:
 var visual=view.table.visuals.get("card_"+str(uid))
 return is_instance_valid(visual) and visual.get_meta("tutorial_highlighted",false) and visual.get_node("Outline").visible and visual.get_node("Outline").material_override.albedo_color.is_equal_approx(Color("#ff4545"))

func check_course(mobile: bool,external: bool,top_down: bool):
 app.clear_page("tutorial_scene" if external else "battle");await frames()
 app.is_android=mobile;app.layout_dpi_override=360 if mobile else 0
 app.layout_safe_override=Rect2(40,12,1200,684) if mobile else Rect2()
 root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
 app.top_down_view=top_down;app.refresh_responsive_layout();await frames()
 var data=fixture();data.steps.board.guide.focus={"alias":"unit0"}
 var flow=Runtime.new();expect(flow.start(data,Store.CARDS).is_empty(),"runtime accepts battle presentation")
 flow.set_process(false)
 var scene
 if external:
  scene=preload("res://scripts/tutorial/scene_view.gd").new();app.screen.add_child(scene);scene.begin(app,flow);view=scene.surface
 else:
  view=preload("res://scripts/duel_view.gd").new();view.tutorial_runtime=flow;app.screen.add_child(view);view.begin(app,{},{},0);scene=view
 view.set_process(false);e=view.engine;await frames()
 var guide=scene.tutorial_guide
 var prefix=("android" if mobile else "desktop")+("-external" if external else "-direct")+("-2d" if top_down else "-3d")
 var unit=flow.adapter.entity("unit0");var book=flow.adapter.entity("book0")
 var copy=flow.adapter.entity("copy0")
 expect(red(unit.uid) and red(book.uid),prefix+" marks the requested field instances red")
 expect(not red(copy.uid) and view.table.visuals.has("card_"+str(copy.uid)),prefix+" marked stackable copy stays distinct from the unmarked copy")
 expect(view.table.camera.projection==(Camera3D.PROJECTION_ORTHOGONAL if top_down else Camera3D.PROJECTION_PERSPECTIVE),prefix+" step camera preserves projection")
 expect(not view.tutorial_controls_enabled and guide.blocker.visible,prefix+" visible dialogue blocks battle controls")
 if mobile:
  var at=guide.focus_card.get_global_rect().get_center();var revision=e.revision;var generation=flow.epoch
  var touch=InputEventScreenTouch.new();touch.index=0;touch.position=at;touch.pressed=true
  root.push_input(touch,true);await create_timer(1.12).timeout
  expect(guide.inspection_id==unit.card_id and is_instance_valid(guide.inspection_overlay),prefix+" alias focus-card hold opens tutorial details")
  touch=touch.duplicate();touch.pressed=false;root.push_input(touch,true);await frames()
  expect(e.revision==revision and flow.current_step=="board" and flow.epoch==generation and view.local.is_empty(),prefix+" focus details keep the battlefield and tutorial progress")
  var close=guide.find_child("TutorialCloseCardDetails",true,false)
  await click(close.get_global_rect().get_center());await frames()
  expect(guide.inspection_id.is_empty() and guide.popup_open,prefix+" closing focus details restores the battlefield guide")
 guide.set_popup(false);await frames()
 expect(red(unit.uid),prefix+" hiding the guide retains red frames")
 expect(not view.tutorial_controls_enabled and guide.blocker.visible,prefix+" hidden dialogue keeps battle controls blocked")
 var frozen_revision=e.revision
 var unit_point=view.project(view.table.visuals["card_"+str(unit.uid)].global_position)
 await click(unit_point)
 expect(e.revision==frozen_revision and view.local.is_empty(),prefix+" battlefield click cannot act during dialogue")
 var phase_button=view.ui.find_child("MainPhaseEnd",true,false)
 expect(phase_button!=null,prefix+" battlefield exposes its native phase button")
 if phase_button!=null:
  await click(phase_button.get_global_rect().get_center())
  expect(e.revision==frozen_revision,prefix+" native phase button cannot advance during dialogue")
 if mobile:
  var hold=InputEventScreenTouch.new();hold.index=0;hold.position=unit_point;hold.pressed=true
  root.push_input(hold,true)
  await create_timer(1.12).timeout
  hold=hold.duplicate();hold.pressed=false;root.push_input(hold,true);await frames()
  expect(view.inspect_uid==unit.uid and view.inspection.visible and view.inspection.z_index==202 and e.revision==frozen_revision,prefix+" battlefield long press shows details without acting")
 else:
  await click(unit_point,MOUSE_BUTTON_RIGHT)
  expect(view.inspect_uid==unit.uid and view.inspection.visible and view.inspection.z_index==202,prefix+" battlefield right click still shows card details")
 flow.opponent.events.append({"type":"priority_changed"})
 flow.tick()
 expect(e.revision==frozen_revision and flow.opponent.events.size()==1,prefix+" dialogue pauses queued opponent moves")
 flow.opponent.events.clear()
 await shot(prefix+"-battlefield")
 var battlefield=view.table.camera.global_transform
 expect(flow.next(),prefix+" advances to own palette");await frames()
 expect(view.android_palette_view and view.android_palette_focus_owner()==view.local_seat,prefix+" focuses own palette")
 expect(view.table.camera.global_transform!=battlefield,prefix+" camera actually moves to own palette")
 expect(red(flow.adapter.entity("resource0").uid) and not red(unit.uid),prefix+" changes red frames with the step")
 expect(view.responsive.camera_focus_rect().grow(2).encloses(view.projected_android_focus(view.android_focus_bounds())),prefix+" own palette fits the clear camera area")
 guide.set_popup(false);await shot(prefix+"-own-palette")
 expect(flow.next(),prefix+" advances to enemy palette");await frames()
 expect(view.android_palette_focus_owner()==1-view.local_seat and red(flow.adapter.entity("resource1").uid),prefix+" focuses and marks enemy palette")
 view.render();await frames()
 expect(view.android_palette_focus_owner()==1-view.local_seat,prefix+" ordinary render keeps the configured camera")
 guide.set_popup(false);await shot(prefix+"-enemy-palette")
 for zone_step in ["own_grave","enemy_grave","own_exile","enemy_exile"]:
  expect(flow.next() and flow.current_step==zone_step,prefix+" enters "+zone_step);await frames()
  var configured=flow.presentation.open_zone
  expect(view.debug_open and view.browser_owner==int(configured.player) and view.browser_zone==configured.zone,prefix+" opens the configured "+zone_step)
  expect(view.browser_cards.get_child_count()==e.players[int(configured.player)][configured.zone].size(),prefix+" browser shows the real zone cards")
  expect(not guide.panel.get_global_rect().intersects(view.browser_panel.get_global_rect()),prefix+" guide leaves the zone browser clear")
  expect(app.ui_metrics.safe.grow(2).encloses(view.browser_panel.get_global_rect()),prefix+" zone browser stays in the safe area")
  expect(view.android_palette_focus_owner()==1-view.local_seat,prefix+" omitted camera retains the last focus")
  var revision=e.revision
  view.browse_card_action(e.players[int(configured.player)][configured.zone][0])
  expect(e.revision==revision and view.local.is_empty(),prefix+" viewing a card under the guide cannot submit a move")
  if mobile and zone_step=="own_grave":
   for i in range(30):
    var card=e.make_card("53",0,"grave");e.players[0].grave.append(card)
   view.render();await frames()
   var at=view.browser_scroll.get_global_rect().get_center()
   var touch=InputEventScreenTouch.new();touch.position=at;touch.pressed=true;root.push_input(touch,true);await process_frame
   var motion=InputEventScreenDrag.new();motion.position=at-Vector2(0,130);motion.relative=Vector2(0,-130);root.push_input(motion,true);await process_frame
   touch=touch.duplicate();touch.position=motion.position;touch.pressed=false;root.push_input(touch,true);await frames()
   expect(view.browser_scroll.scroll_vertical>0 and not view.tutorial_controls_enabled,prefix+" native touch scroll reads the list while battlefield actions remain blocked")
  if zone_step=="own_grave":await shot(prefix+"-own-grave")
 expect(flow.previous() and flow.current_step=="own_exile",prefix+" previous returns to the preceding zone step");await frames()
 if external:view=scene.surface;guide=scene.tutorial_guide;view.set_process(false)
 e=view.engine
 expect(view.browser_owner==0 and view.browser_zone=="exile" and view.android_palette_focus_owner()==1-view.local_seat,prefix+" previous restores the zone and inherited camera")
 expect(flow.next() and flow.next() and flow.current_step=="task",prefix+" reaches the battlefield task");await frames()
 e=view.engine;unit=flow.adapter.entity("unit0")
 expect(not view.debug_open and not view.android_palette_view and red(unit.uid),prefix+" next step closes the list and restores battlefield focus")
 e.players[0].field.erase(unit);unit.zone="grave";e.players[0].grave.append(unit);view.render();await frames()
 expect(not view.table.tutorial_highlights.has(unit.uid),prefix+" leaving the board removes its tutorial red frame")
 expect(flow.reset_task(),prefix+" resets the task checkpoint");await frames()
 if external:view=scene.surface;guide=scene.tutorial_guide;view.set_process(false)
 e=view.engine;unit=flow.adapter.entity("unit0")
 expect(unit.zone=="field" and red(unit.uid) and not view.debug_open,prefix+" reset restores the board and red frame")
 e.players[0].field.erase(unit);unit.zone="exile";e.players[0].exile.append(unit);e.revision+=1
 flow.tick();await frames()
 expect(flow.finished and view.table.tutorial_highlights.is_empty(),prefix+" completion clears tutorial frames")
 scene.queue_free();await frames();view=null

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures-"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate();app.settings_path=output.path_join("missing-settings.json");app.account_session_path=output.path_join("missing-account.json")
 root.add_child(app);await frames();check_validation();check_scene_restore()
 for mobile in [false,true]:
  for external in [false,true]:
   for top_down in [false,true]:await check_course(mobile,external,top_down)
 print("TUTORIAL BATTLE PRESENTATION: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
