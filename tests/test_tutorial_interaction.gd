extends "res://tests/support/ui_base.gd"
const Config=preload("res://scripts/tutorial/config.gd")
const Runtime=preload("res://scripts/tutorial/runtime.gd")
const COURSE="res://data/tutorial/beginner/t1.json"

func frames(count: int=6):
 for i in range(count):await process_frame

func touch(at: Vector2,pressed: bool):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=pressed
 root.push_input(event,true);await frames(2)

func shot(title: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/tutorial-interaction/"+title+".png")

func check_deck(mobile: bool):
 app.is_android=mobile;app.layout_dpi_override=240 if mobile else 0
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND if mobile else Window.CONTENT_SCALE_ASPECT_KEEP
 app.layout_safe_override=Rect2(40,12,1200,684) if mobile else Rect2()
 app.begin_tutorial(COURSE);await frames(12)
 var scene=app.screen.get_child(0);var flow=scene.runtime;var guide=scene.tutorial_guide
 var overview=scene.editor_host.deck_overview
 var label="Android" if mobile else "desktop"
 var before=flow.adapter.ui_deck.duplicate(true);var generation=flow.epoch
 expect(not flow.adapter.components.interaction.enabled,label+" fixture disables task operations")
 expect(guide.next_button.visible and not guide.reset_button.visible and not guide.answers_scroll.visible,label+" ordinary dialogue has next without a required task")
 for zone in ["leader","main","side"]:
  var card=overview.card_frames.filter(func(frame):return frame.source_zone==zone)[-1 if zone=="side" else 0]
  var at=card.get_global_rect().get_center()
  if mobile:
   await touch(at,true);await touch(at,false);await frames()
   expect(guide.inspection_id.is_empty(),label+" short tap does not inspect "+zone)
   await touch(at,true)
   expect(is_instance_valid(card.hold_ring),label+" native touch starts the hold ring for "+zone)
   await create_timer(1.12).timeout;await touch(at,false)
  else:await click(at,MOUSE_BUTTON_RIGHT)
  await frames()
  expect(guide.inspection_id==card.card_id and guide.inspection_art!=null,label+" inspects "+zone+" despite disabled task operations")
  expect(flow.current_step=="d1" and flow.epoch==generation and flow.completed_steps.is_empty() and flow.action_failures.is_empty(),label+" inspection does not evaluate or advance ordinary dialogue")
  expect(flow.adapter.ui_deck==before and scene.editor_host.draft==before,label+" inspection keeps the teaching deck unchanged")
  if zone in ["main","side"]:await shot(label+"-"+zone+"-details")
  var close=guide.find_child("TutorialCloseCardDetails",true,false)
  expect(close!=null,label+" details include a close button")
  if close!=null:await click(close.get_global_rect().get_center())
  await frames()
  expect(guide.inspection_id.is_empty() and guide.middle.visible,label+" closing details restores the dialogue")
 if mobile:
  var card=overview.card_frames.filter(func(frame):return frame.source_zone=="main")[0]
  var at=card.get_global_rect().get_center()
  await touch(at,true)
  var drag_event=InputEventScreenDrag.new();drag_event.index=0;drag_event.position=at+Vector2(30,0);drag_event.relative=Vector2(30,0)
  root.push_input(drag_event,true);await create_timer(1.12).timeout;await touch(drag_event.position,false)
  expect(guide.inspection_id.is_empty(),label+" moving the finger cancels inspection")
 else:
  var card=overview.card_frames[0]
  await click(card.get_global_rect().get_center());await frames()
  expect(guide.inspection_id==card.card_id,"desktop keeps left-click inspection available")
  guide.close_card_details()
 expect(flow.next() and flow.current_step=="d2",label+" ordinary dialogue advances without performing an operation")
 await frames()
 while flow.current_step!="q1":flow.next()
 await frames()
 expect(not flow.authorize_ui_action("editor.inspect",{"card_id":"74"}),label+" answer dialogue blocks background deck input")
 expect(flow.current_step=="q1" and flow.action_failures.is_empty(),label+" blocked quiz background input is not a task failure")

func check_dialogue(data: Dictionary):
 var fixture=data.duplicate(true);fixture.id="dialogue_interaction"
 var scene=fixture.scenarios.remilia_deck
 scene.type="in_game";scene.screen="deck_editor";scene.components.interaction.enabled=true
 scene.components.erase("deck_surface");scene.components.editor_surface={"visible":true}
 fixture.start_step="info";fixture.completion={"type":"steps_completed","steps":["info","sort","done"]}
 fixture.steps={
  "info":{"type":"info","guide":{"text":"普通讲解"},"next":"sort"},
  "sort":{"type":"task","guide":{"text":"排序卡组"},"task":{"timing":"action","action":{"id":"editor.sort"},"allowed_actions":["editor.inspect"],"success":{"type":"always"}},"next":"done"},
  "done":{"type":"info","guide":{"text":"完成"},"next":"$complete"}
 }
 var flow=Runtime.new()
 var reason=flow.start(fixture,Store.CARDS)
 expect(reason.is_empty(),"editor dialogue fixture validates and starts")
 if not reason.is_empty():print(reason);flow.free();return
 var rejected=[];flow.task_failed.connect(func(reason):rejected.append(reason))
 expect(flow.authorize_ui_action("editor.inspect",{}),"ordinary dialogue permits card details")
 for id in ["editor.search","editor.add","editor.sort","editor.view"]:
  expect(not flow.authorize_ui_action(id,{}),"ordinary dialogue blocks "+id)
 expect(flow.current_step=="info" and flow.completed_steps.is_empty(),"blocked actions cannot complete ordinary dialogue")
 flow.adapter.components.interaction.enabled=false
 expect(not flow.authorize_ui_action("editor.add",{}),"scene operation switch still disables editor changes")
 expect(flow.authorize_ui_action("editor.inspect",{}),"card details remain available with interaction disabled")
 flow.reject_ui_action("editor.save",{});flow.reject_ui_action("editor.return_menu",{})
 expect(rejected.is_empty() and flow.action_failures.is_empty(),"ordinary dialogue never reports an unfinished or wrong task")
 flow.adapter.components.interaction.enabled=true
 expect(flow.next() and flow.current_step=="sort","ordinary dialogue advances directly to the explicit task")
 expect(not flow.next(),"explicit task cannot be skipped with next")
 expect(not flow.authorize_ui_action("editor.remove",{}) and rejected.size()==1,"explicit task still rejects an unrelated operation")
 expect(flow.authorize_ui_action("editor.inspect",{}),"explicit task permits configured optional inspection")
 flow.ui_action_applied("editor.inspect",{});flow.tick()
 expect(flow.current_step=="sort","optional task inspection does not complete sorting")
 expect(flow.authorize_ui_action("editor.sort",{}),"explicit task accepts its required operation")
 flow.ui_action_applied("editor.sort",{});flow.tick()
 expect(flow.current_step=="done" and flow.next() and flow.finished,"required operation advances the task and completion dialogue")
 flow.free()
 var invalid=fixture.duplicate(true);invalid.steps.info.task={"success":{"type":"always"}}
 expect(not Config.new().validate(invalid,Store.CARDS).ok,"ordinary dialogue schema rejects required task fields")

func run():
 var loaded=Config.new().load_file(COURSE,Store.CARDS)
 expect(loaded.ok,"interaction tests use the current validated course")
 if not loaded.ok:quit(1);return
 check_dialogue(loaded.data)
 var fixture="res://work/tutorial-interaction/fixtures-"+str(Time.get_ticks_usec())
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 var settings=fixture.path_join("settings.json")
 var file=FileAccess.open(settings,FileAccess.WRITE);file.store_string('{"fullscreen":false}');file.close()
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900)
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate();app.settings_path=settings;app.account_session_path=fixture.path_join("account.json")
 root.add_child(app);await frames()
 for mobile in [false,true]:await check_deck(mobile)
 app.queue_free();await frames()
 print("TUTORIAL INTERACTION: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
