extends "res://tests/support/ui_base.gd"
## Palette resolution choices must remain touchable beside their ability panel.
var output="res://work/android-palette-targets"

func frames(count: int=8):
 for i in range(count):await process_frame

func tap(at: Vector2):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true)
 await process_frame;await physics_frame;await frames()

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))

func check_clear(prefix: String):
 var panel=view.android_choice_panel
 expect(is_instance_valid(panel),prefix+" ability panel stays open")
 if not is_instance_valid(panel):return
 expect(app.ui_metrics.safe.grow(1).encloses(panel.get_global_rect()),prefix+" panel stays inside the safe area")
 var blocked=[]
 for card in e.players[1].palette:
  var node=view.table.visuals.get("card_"+str(card.uid))
  if node==null or not node.visible:continue
  var rect=view.projected_card_rect(node)
  if rect.intersects(panel.get_global_rect()):blocked.append(card.uid)
 expect(blocked.is_empty(),prefix+" ability panel leaves all enemy palette cards clear: "+str(blocked))
 expect(view.responsive.camera_focus_rect().grow(2).encloses(view.projected_android_focus(view.android_focus_bounds())),prefix+" palette fits the clear focus area")

func check_clownpiece(prefix: String,top_down: bool,id: String):
 clean(true);view.android_card_touch.cancel();view.render();await frames()
 view.table.set_top_down_view(top_down);view.android_palette_view=false;view.reset_camera_view()
 for who in range(2):
  for i in range(10):
   var resource=put("164","palette",who);resource.tapped=i%3==1
  for i in range(8):put("53","hand",who)
 var replacement=put("164","deck",1)
 view.render();await settle();await frames()
 var original=view.table.camera.global_transform
 var source=put(id,"field")
 if id=="character-fdf-113":
  e.debug_free_payment=true
  expect(e.commit_extension(0,source.uid,{"player":1},[],id).is_empty(),prefix+" Clownpiece activation succeeds")
 else:
  e.begin_trigger({"source":source.duplicate(true),"owner":0,"extended":true,"effect":"enter_palette_replace","name":e.cards[id].name,"optional":true,"data":{}})
  e.choose_effect({"player":1})
 resolve();view.render();await settle();view.render();await frames()
 expect(e.pending.get("trigger",{}).get("effect","") in ["cat:clown_palette","enter_palette_replace_choose"],prefix+" real resolution requests enemy palette selection")
 expect(view.android_palette_view and view.android_palette_focus_owner()==1,prefix+" resolution focuses enemy palette")
 check_clear(prefix+" before selection");await shot(prefix+"-before")
 var target=e.players[1].palette.back()
 await tap(point(target.uid))
 expect(view.picker.selected_refs().any(func(ref):return ref.get("uid",0)==target.uid),prefix+" native touch selects the last palette card")
 check_clear(prefix+" after selection");await shot(prefix+"-selected")
 var reset=find_button(view.android_choice_panel,"重选")
 if reset!=null:await tap(reset.get_global_rect().get_center())
 expect(view.picker.selected_refs().is_empty(),prefix+" reselect clears the target")
 var hide=view.android_choice_panel.get_node("AndroidChoiceHide")
 await tap(hide.get_global_rect().get_center())
 expect(not is_instance_valid(view.android_choice_panel) and is_instance_valid(view.android_choice_restore),prefix+" panel can be hidden")
 await tap(view.android_choice_restore.get_global_rect().get_center())
 check_clear(prefix+" reopened")
 await tap(point(target.uid))
 var confirm=find_button(view.android_choice_panel,"确定")
 expect(confirm!=null and not confirm.disabled,prefix+" selected target enables confirmation")
 if confirm!=null and not confirm.disabled:await tap(confirm.get_global_rect().get_center())
 await settle();view.render();await frames()
 expect(target.zone=="grave" and replacement.zone=="palette",prefix+" touch confirmation resolves the palette replacement")
 expect(not view.android_palette_view and view.android_camera_restore.is_empty() and view.table.camera.global_transform.is_equal_approx(original),prefix+" resolution restores the battlefield camera")

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures/"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();app.tutorial_local_directory=output.path_join("tutorials");root.add_child(app);await frames()
 app.is_android=true;app.auto_camera_focus=true;app.load_legacy_test_decks()
 var cases=[{"size":Vector2i(1280,720),"dpi":240.0},{"size":Vector2i(1920,1080),"dpi":360.0},{"size":Vector2i(2340,1080),"dpi":420.0},{"size":Vector2i(2160,1080),"dpi":480.0},{"size":Vector2i(1280,720),"dpi":320.0}]
 if "--quick" in OS.get_cmdline_user_args():cases=[cases.back()]
 for fixture in cases:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  var preview_scale=minf(1.0,minf(1600.0/fixture.size.x,900.0/fixture.size.y))
  root.size=Vector2i(Vector2(fixture.size)*preview_scale)
  app.layout_dpi_override=fixture.dpi*preview_scale
  app.layout_safe_override=Rect2(60*preview_scale,0,(fixture.size.x-84)*preview_scale,(fixture.size.y-24)*preview_scale)
  await frames();app.refresh_responsive_layout();app.begin_battle(true)
  view=app.duel_view;view.set_process(false);e=view.engine;await frames()
  for top_down in [true,false]:
   for id in ["49","character-fdf-113"]:
    var prefix="%dx%d-dpi%d-%s-%s" % [fixture.size.x,fixture.size.y,int(fixture.dpi),"2d" if top_down else "3d",id]
    await check_clownpiece(prefix,top_down,id)
 print("ANDROID PALETTE TARGETS: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
