extends "res://tests/support/ui_base.gd"

func reserved(uid: int) -> bool:
 return view.local.get("plan",[]).any(func(entry):return entry.uid==uid)

func activate(at: Vector2,jitter: bool=false):
 if not view.is_android:
  await click(at)
  return
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 if jitter:
  var motion=InputEventScreenDrag.new();motion.index=0;motion.position=at+Vector2(14,0);motion.relative=Vector2(14,0)
  root.push_input(motion,true);await process_frame
  event.position=motion.position
 event=event.duplicate();event.pressed=false;root.push_input(event,true)
 await process_frame;await physics_frame

func check_payment(top_down: bool,wide: bool):
 clean()
 view.table.wide_playmat=wide;view.table.set_top_down_view(top_down)
 var spell=put("164","hand")
 for i in range(8):put("164","palette")
 e.players[0].potato=true;e.players[1].potato=true
 view.render();await settle();view.request_cast(spell.uid);view.start_payment()
 for entry in view.local.plan.duplicate(true):view.reserve_resource(entry.uid)
 var resource=e.players[0].palette[0]
 view.reserve_resource(resource.uid);view.reset_camera_view();await settle()
 var title=("Android" if view.is_android else "Desktop")+(" 2D" if top_down else " 3D")+(" wide" if wide else " normal")
 expect(view.payment_sources().any(func(source):return source.uid==-100),title+" offers potato as the remaining payment")
 var before=snapshot()
 var center=point(-100)
 expect(view.touch_card_at(center)==-100,title+" exact potato hit is preserved")
 if not view.is_android:
  var toggle=view.hud.get_node("HandDisplayToggle")
  expect(not toggle.get_global_rect().intersects(view.projected_card_rect(view.table.visuals["card_-100"]).grow(8)),title+" hand visibility button clears potato and its click margin")
 await activate(center)
 expect(reserved(-100) and view.payment_ready(),title+" exact tap reserves potato")
 if reserved(-100):view.reserve_resource(-100)
 var rect=view.projected_card_rect(view.table.visuals["card_-100"])
 var padding=18.0 if view.is_android else 6.0
 var edge=Vector2(rect.get_center().x,rect.end.y+padding)
 expect(view.table.card_at(view.stage_point(edge))==0,title+" edge point misses the small physics hitbox")
 expect(view.touch_card_at(edge)==-100,title+" near miss selects potato")
 await activate(edge,view.is_android)
 expect(reserved(-100) and view.payment_ready(),title+" edge tap with finger drift reserves potato")
 expect(snapshot()==before,title+" reservations do not spend resources early")
 expect(view.touch_card_at(point(resource.uid))==resource.uid,title+" neighboring palette card keeps exact-hit priority")
 var enemy_rect=view.projected_card_rect(view.table.visuals["card_-101"])
 var enemy_edge=Vector2(enemy_rect.get_center().x,enemy_rect.end.y+padding)
 expect(view.touch_card_at(enemy_edge)!=-101,title+" opponent potato has no payment padding")
 await capture("potato-payment-"+title.replace(" ","-"))
 if reserved(-100):
  view.commit_local()
  expect(not e.players[0].potato and e.players[1].potato and resource.tapped and spell.zone=="stack",title+" confirmation consumes only own potato and chosen card")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/potato-payment-ui/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate()
 app.settings_path=Store.Paths.root_override.path_join("settings.json");app.tutorial_local_directory=Store.Paths.root_override.path_join("tutorials")
 DirAccess.make_dir_recursive_absolute(app.tutorial_local_directory)
 root.add_child(app);await process_frame
 app.is_android=OS.get_cmdline_user_args().has("--android");app.layout_dpi_override=240
 app.load_legacy_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 for top_down in [true,false]:
  for wide in [true,false]:await check_payment(top_down,wide)
 print("POTATO PAYMENT UI: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
