extends "res://tests/support/ui_base.gd"

func frames(count: int=6):
 for i in range(count):await process_frame

func tap(at: Vector2):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true)
 await process_frame;await physics_frame

func check_stack_side(label: String):
 var panel=view.android_choice_panel
 expect(is_instance_valid(panel),label+" panel exists")
 if not is_instance_valid(panel):return
 expect(panel.get_meta("avoid_stack",false) and is_equal_approx(panel.position.x,view.responsive.stack_choice_rect().position.x),label+" sits in the counter-card stack-side slot")
 expect(view.stack_panel.visible and not panel.get_global_rect().intersects(view.stack_panel.get_global_rect()),label+" keeps stack cards visible and clickable")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/hina-cloud-ui/fixtures/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.size=Vector2i(1280,720)
 root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 app.load_legacy_test_decks();app.begin_battle(true);await frames()
 view=app.duel_view;view.set_process(false);e=view.engine
 clean()
 var hina=put("32","field")
 var ally=put("50","field")
 var cloud=put("character-fdf-046","hand",1)
 for id in ["167","167","166","166"]:put(id,"palette",1)
 e.active=1;e.priority=1
 view.set_response_mode(view.ResponseMode.ON)
 var payment={"none":true,"mode":"额外支付1绿","extra_green":true}
 var error=e.commit_cast(1,cloud.uid,payment,e.payment(1,e.cast_cost(1,cloud,payment)).plan)
 expect(error.is_empty(),"Cloud duel cast: "+error)
 if error.is_empty():
  resolve()
  expect(e.pending.get("kind","")=="effect_choice","Cloud target choice is open")
  e.choose_effect(e.ref_target(ally))
  view.render();await frames()
  var action=e.available_actions(0,hina.uid).filter(func(a):return a.get("key","")=="hina_redirect")
  expect(action.size()==1,"Hina response action exists")
  if not action.is_empty():
   view.execute_action(action[0]);await settle();view.render();await frames()
   expect(view.local.get("action","")=="extension" and view.picker_active(),"Hina target picker opens")
   check_stack_side("desktop Hina initial choice")
   var stack_ref=view.picker.available_refs().filter(func(r):return r.has("stack_id"))
   expect(stack_ref.size()==1,"first step selects the Cloud ability on stack")
   if not stack_ref.is_empty() and view.stack_panel.tiles.has(stack_ref[0].stack_id):
    await click(view.stack_panel.tiles[stack_ref[0].stack_id].tile.get_global_rect().get_center());await frames()
   var target_refs=view.picker.available_refs()
   expect(target_refs.any(func(r):return r.get("uid",-1)==ally.uid),"second step offers the teammate as a battlefield target")
   check_stack_side("desktop Hina original-target choice")
   var prompt=view.android_choice_panel.get_node("BoardTargetPrompt") if is_instance_valid(view.android_choice_panel) else null
   expect(prompt!=null and "原目标" in prompt.tooltip_text and "自动成为键山雏" in prompt.tooltip_text,"Hina prompt explains which card to select")
   await click(view.target_rect(e.ref_target(hina)).get_center());await frames()
   expect(not view.picker.ready(),"clicking Hina herself does not choose the original target")
   if target_refs.any(func(r):return r.get("uid",-1)==ally.uid):
    await click(view.target_rect(e.ref_target(ally)).get_center());await frames()
   expect(view.picker.ready() and view.picker.selected_refs().any(func(r):return r.get("uid",-1)==ally.uid),"mouse click selects the actual teammate")
   var submit=find_button(view.android_choice_panel,"发动") if is_instance_valid(view.android_choice_panel) else null
   expect(submit!=null and not submit.disabled,"Hina's button becomes enabled")
   if submit!=null and not submit.disabled:
    await click(submit.get_global_rect().get_center());await frames()
    expect(e.stack.size()==2 and e.stack.back().get("effect","")=="hina_redirect","UI sends Hina response to the engine")
 clean(true)
 hina=put("32","field")
 ally=put("50","field")
 for id in ["53","54","56"]:put(id,"field")
 cloud=put("character-fdf-046","hand",1)
 for id in ["167","167","166","166"]:put(id,"palette",1)
 e.active=1;e.priority=1
 error=e.commit_cast(1,cloud.uid,payment,e.payment(1,e.cast_cost(1,cloud,payment)).plan)
 expect(error.is_empty(),"crowded Cloud cast: "+error)
 if error.is_empty():
  resolve();view.render();await settle();view.render();await frames()
  expect(view.acting_player()==1 and e.pending.get("kind","")=="effect_choice","Cloud's controller is choosing among opposing units")
  expect(view.picker.available_refs().size()>=5,"crowded field offers all legal target units")
  await click(view.target_rect(e.ref_target(ally)).get_center());await frames()
  expect(view.picker.ready() and view.picker.selected_refs().any(func(r):return r.get("uid",-1)==ally.uid),"mouse click selects Cloud's target in a crowded field")
  var cloud_submit=find_button(view.android_choice_panel,"确定") if is_instance_valid(view.android_choice_panel) else null
  expect(cloud_submit!=null and not cloud_submit.disabled,"Cloud target can be confirmed")
 app.queue_free();await frames()
 root.size=Vector2i(2340,1080)
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 app.is_android=true;app.layout_dpi_override=420.0
 app.layout_safe_override=Rect2(60,0,2256,1056)
 app.refresh_responsive_layout();app.load_legacy_test_decks();app.begin_battle(true);await frames()
 view=app.duel_view;view.set_process(false);e=view.engine
 clean(true)
 hina=put("32","field")
 ally=put("50","field")
 for id in ["53","54","56"]:put(id,"field")
 cloud=put("character-fdf-046","hand",1)
 for id in ["167","167","166","166"]:put(id,"palette",1)
 e.active=1;e.priority=1
 error=e.commit_cast(1,cloud.uid,payment,e.payment(1,e.cast_cost(1,cloud,payment)).plan)
 expect(error.is_empty(),"phone Cloud duel cast: "+error)
 if error.is_empty():
  resolve();view.render();await settle();view.render();await frames()
  expect(view.is_android and view.picker.available_refs().size()>=5,"phone displays Cloud's battlefield targets")
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://work/hina-cloud-ui"))
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://work/hina-cloud-ui/phone-cloud-target.png")
  await tap(view.target_rect(e.ref_target(ally)).get_center());await frames()
  expect(view.picker.ready() and view.picker.selected_refs().any(func(r):return r.get("uid",-1)==ally.uid),"phone touch selects Cloud's target")
  var phone_submit=find_button(view.android_choice_panel,"确定") if is_instance_valid(view.android_choice_panel) else null
  expect(phone_submit!=null and not phone_submit.disabled,"phone target can be confirmed")
  if phone_submit!=null and not phone_submit.disabled:
   await tap(phone_submit.get_global_rect().get_center());await settle();view.render();await frames()
   var phone_action=e.available_actions(0,hina.uid).filter(func(a):return a.get("key","")=="hina_redirect")
   expect(e.pending.is_empty() and phone_action.size()==1,"phone opens Hina's response window after Cloud target confirmation")
   if not phone_action.is_empty():
    view.execute_action(phone_action[0]);await settle();view.render();await frames()
    check_stack_side("phone Hina initial choice")
    var phone_stack=view.picker.available_refs().filter(func(r):return r.has("stack_id"))
    expect(phone_stack.size()==1,"phone Hina picker offers Cloud's stack ability")
    if not phone_stack.is_empty() and view.stack_panel.tiles.has(phone_stack[0].stack_id):
     await tap(view.stack_panel.tiles[phone_stack[0].stack_id].tile.get_global_rect().get_center());await frames()
     check_stack_side("phone Hina original-target choice")
     await RenderingServer.frame_post_draw
     root.get_texture().get_image().save_png("res://work/hina-cloud-ui/phone-hina-stack-side.png")
     await tap(view.target_rect(e.ref_target(hina)).get_center());await frames()
     expect(not view.picker.ready(),"phone tap on Hina does not choose the original target")
     await tap(view.target_rect(e.ref_target(ally)).get_center());await frames()
     expect(view.picker.ready(),"phone tap on teammate selects the original target")
     var hina_submit=find_button(view.android_choice_panel,"发动") if is_instance_valid(view.android_choice_panel) else null
     expect(hina_submit!=null and not hina_submit.disabled,"phone Hina response can be submitted")
 print("HINA CLOUD UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
