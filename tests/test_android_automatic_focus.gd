extends "res://tests/support/ui_base.gd"

class ConnectedPreview:
 extends RefCounted
 var connected=true
 var paused=false
 var read_only=false
 var room={"undo_request":{}}
 func ended() -> bool:return false

func frames(count: int=8):
 for i in range(count):await process_frame

func focus_is(who: int,title: String):
 expect(view.android_palette_view and view.android_palette_focus_owner()==who,title)
 var bounds=view.projected_android_focus(view.android_focus_bounds())
 expect(view.responsive.camera_focus_rect().grow(2).encloses(bounds),title+" fits the clear camera area")

func reset_board(top_down: bool=true):
 clean();view.android_card_touch.cancel();view.render();await frames()
 view.android_palette_view=false;view.android_focus_owner=view.local_seat
 view.table.set_top_down_view(top_down);view.reset_camera_view()
 for who in range(2):
  for i in range(6):put("100","palette",who)
 view.render();await settle();await frames()

func leave_choice(original: Transform3D,title: String):
 e.pending={};e.phase="main";view.local={};view.picker.reset();view.render();await frames()
 expect(not view.android_palette_view and view.android_camera_restore.is_empty(),title+" restores battlefield focus")
 expect(view.table.camera.global_transform.is_equal_approx(original),title+" restores the original camera position")

func trigger(source: Dictionary,effect: String,options: Array):
 e.pending={"kind":"effect_choice","owner":view.local_seat,"options":options,"trigger":{"source":source,"owner":view.local_seat,"effect":effect,"optional":true,"continuation":true,"data":{},"name":e.cards[source.card_id].name}}
 view.render();await frames()

func touch(index: int,at: Vector2,pressed: bool):
 var event=InputEventScreenTouch.new();event.index=index;event.position=at;event.pressed=pressed
 root.push_input(event,true);await process_frame

func motion(index: int,at: Vector2):
 var event=InputEventScreenDrag.new();event.index=index;event.position=at
 root.push_input(event,true);await process_frame

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-automatic-focus/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 app.is_android=true;app.layout_dpi_override=240;app.load_legacy_test_decks();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine;await frames()
 var original_phase=e.phase
 var original_active=e.active
 var original_pending=e.pending.duplicate(true)
 app.auto_camera_focus=true
 view.network_session=ConnectedPreview.new()
 e.phase="possession";e.active=1-view.local_seat;e.pending={}
 expect(view.required_camera_focus()==-1,"opponent possession keeps the Android camera unchanged")
 view.network_session=null
 e.phase=original_phase;e.active=original_active;e.pending=original_pending
 app.settings_path=Store.Paths.root_override.path_join("settings.json")
 DirAccess.make_dir_recursive_absolute(Store.Paths.root_override)
 expect(not app.android_manual_camera,"manual Android camera defaults to disabled")
 for top_down in [true,false]:
  await reset_board(top_down)
  var original=view.table.camera.global_transform
  put("100","hand")
  e.phase="possession";e.pending={"kind":"possession","owner":0};view.render();await frames()
  focus_is(0,"possession focuses own palette "+str(top_down))
  await capture("android-auto-possession-"+str(top_down))
  await leave_choice(original,"possession")
  var source=put("53","grave");var resource=e.players[0].palette[0];resource.tapped=true
  await trigger(source,"crystal",[e.ref_target(resource)])
  focus_is(0,"crystal focuses own palette "+str(top_down))
  await leave_choice(original,"crystal")
  var spell=put("53","hand")
  view.request_cast(spell.uid);await frames()
  focus_is(0,"casting with a cost focuses own palette "+str(top_down))
  await capture("android-auto-payment-"+str(top_down))
  view.cancel_cast();await frames()
  expect(not view.android_palette_view and view.table.camera.global_transform.is_equal_approx(original),"cancel payment restores camera")
  for effect in ["enter_palette_replace_choose","death_poverty","cat:poverty_pair"]:
   source=put("49" if effect=="enter_palette_replace_choose" else "38" if effect=="death_poverty" else "spell-fdf-081","grave")
   var options=e.Extra.zone_refs(e,"palette",1) if effect=="enter_palette_replace_choose" else e.Extra.trigger_options(e,{"source":source,"owner":0,"effect":effect,"continuation":true,"data":{}}) if effect=="death_poverty" else e.Cat.pick(e,e.players[1].palette,2,2,"放置贫乏")
   await trigger(source,effect,options)
   focus_is(1,effect+" focuses enemy palette "+str(top_down))
   await capture("android-auto-enemy-"+effect.replace(":","-")+"-"+str(top_down))
   await leave_choice(original,effect)
  for id in ["spell-fdf-007","character-fdf-113"]:
   source=put(id,"hand" if id.begins_with("spell") else "field")
   var options=e.Pack.zone(e,1,"palette")
   await trigger(source,"palette_three_choose" if id.begins_with("spell") else "cat:clown_palette",options)
   focus_is(1,id+" enemy palette resolution choice")
   await leave_choice(original,id)
  source=put("spell-fdn-017","grave")
  var qed={"card":source,"owner":0,"target":{"player":1}}
  e.Cat.Spells.resolve_complex(e,qed);view.render();await settle();view.render();await frames()
  var skips=view.picker.available().filter(func(atom):return atom.kind=="finish_group")
  if not skips.is_empty():view.inline_pick(skips[0])
  skips=view.picker.available().filter(func(atom):return atom.kind=="finish_group")
  if not skips.is_empty():view.inline_pick(skips[0])
  await frames();focus_is(1,"Flandre QED palette stage")
  await leave_choice(original,"Flandre QED")
  source=put("character-fdf-111","grave")
  e.players[0].palette[0].poverty=3;e.players[1].palette[0].poverty=3
  var actions=e.available_actions(0,source.uid,true).filter(func(action):return action.type=="extension" and action.key=="character-fdf-111")
  expect(not actions.is_empty(),"grave counter ability has both player choices")
  if not actions.is_empty():
   view.begin_action(actions[0]);await frames()
   var enemy_spec=-1
   for i in range(view.picker.specs.size()):
    var spec=view.picker.specs[i]
    if spec.selection[0].pool.all(func(ref):return e.find_card(ref.uid).owner==1):enemy_spec=i
   var choice=view.picker.available().filter(func(atom):return atom.get("index",-2)==enemy_spec)
   expect(not choice.is_empty(),"enemy counter owner can be chosen")
   if not choice.is_empty():view.inline_pick(choice[0]);await frames();focus_is(1,"grave ability switches after enemy owner selection")
   await capture("android-auto-grave-enemy-"+str(top_down))
   view.cancel_cast();await frames()
   expect(view.table.camera.global_transform.is_equal_approx(original),"leaving grave ability restores camera")
 # Restore a manually adjusted palette view as well as the default battlefield view.
 await reset_board()
 view.android_palette_view=true;view.reset_camera_view()
 view.table.pan_camera(view.stage_point(view.responsive.camera_focus_rect().get_center()),view.stage_point(view.responsive.camera_focus_rect().get_center()+Vector2(30,10)))
 view.table.zoom_camera(0.9)
 var saved_transform=view.table.camera.global_transform;var saved_size=view.table.top_down_camera_size
 var source=put("49","grave")
 await trigger(source,"enter_palette_replace_choose",e.Extra.zone_refs(e,"palette",1))
 focus_is(1,"enemy ability temporarily leaves the manual own palette view")
 e.pending={};view.render();await frames()
 expect(view.android_palette_view and view.android_palette_focus_owner()==0 and view.table.camera.global_transform.is_equal_approx(saved_transform) and is_equal_approx(view.table.top_down_camera_size,saved_size),"ability exit restores prior palette view including manual pan and zoom")
 await reset_board()
 var at=view.TOUCH_CAMERA_AREA.get_center();var before=view.table.camera.global_transform
 await touch(0,at,true);await create_timer(0.55).timeout;await motion(0,at+Vector2(100,50));await touch(0,at+Vector2(100,50),false)
 expect(view.table.camera.global_transform.is_equal_approx(before),"disabled manual camera ignores drag")
 var size_before=view.table.top_down_camera_size
 await touch(0,at,true);await touch(1,at+Vector2(100,0),true);await motion(1,at+Vector2(180,0));await touch(1,at+Vector2(180,0),false);await touch(0,at,false)
 expect(is_equal_approx(size_before,view.table.top_down_camera_size),"disabled manual camera ignores pinch")
 view.settings_menu();await frames()
 var setting=view.modal_root.find_child("AndroidManualCamera",true,false)
 expect(setting!=null and not setting.button_pressed,"battle settings expose the default-disabled camera toggle")
 await capture("android-manual-camera-settings")
 if setting!=null:setting.button_pressed=true
 expect(app.android_manual_camera and JSON.parse_string(FileAccess.get_file_as_string(app.settings_path)).android_manual_camera,"manual camera setting is persisted")
 view.modal=false;view.render();await frames()
 await touch(0,at,true);await create_timer(0.55).timeout;await motion(0,at+Vector2(100,50));await touch(0,at+Vector2(100,50),false)
 expect(not view.table.camera.global_transform.is_equal_approx(before),"enabled manual camera permits drag")
 await touch(0,at,true);await touch(1,at+Vector2(100,0),true);await motion(1,at+Vector2(180,0));await touch(1,at+Vector2(180,0),false);await touch(0,at,false)
 expect(not is_equal_approx(size_before,view.table.top_down_camera_size),"enabled manual camera permits pinch")
 app.set_android_manual_camera(false);app.settings();await frames()
 setting=app.screen.find_child("AndroidManualCamera",true,false)
 expect(setting!=null and not setting.button_pressed,"main menu settings expose the same saved camera toggle")
 await capture("android-main-camera-settings")
 print("ANDROID AUTOMATIC FOCUS: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
