extends "res://tests/support/ui_base.gd"

func frames(count: int=3):
 for i in range(count):await process_frame

func reserved(uid: int) -> bool:
 return view.local.get("plan",[]).any(func(entry):return entry.uid==uid)

func offered(uid: int) -> bool:
 return view.payment_sources().any(func(source):return source.uid==uid)

func check_reselection(mode: String):
 clean();e.debug_free_payment=false
 e.cards=e.cards.duplicate(true);e.cards["164"].cost={"红":1,"蓝":1,"黄":1}
 var replacement=put("165","palette");replacement.token_colors=["红","绿"]
 var flexible=put("165","palette");flexible.token_colors=["红","蓝"]
 var blue=put("167","palette");var yellow=put("164","palette")
 var green=put("166","palette");var tapped=put("165","palette");tapped.tapped=true
 var spell=put("164","hand")
 view.render();view.request_cast(spell.uid)
 if mode=="payment":view.start_payment()
 var prefix=("Android" if view.is_android else "Desktop")+" "+mode
 expect(view.local.get("mode","")==mode and view.payment_ready(),prefix+" starts with a complete payment")
 if view.local.is_empty():return
 expect(reserved(flexible.uid) and reserved(blue.uid) and reserved(yellow.uid),prefix+" initial plan selects the flexible, blue and yellow sources")
 expect(view.local.plan.any(func(p):return p.uid==flexible.uid and p.color=="红"),prefix+" flexible source initially pays red")
 var before=snapshot()
 view.object_clicked(blue.uid)
 expect(not reserved(blue.uid) and view.local.plan.size()==2 and not view.payment_ready(),prefix+" deselecting leaves the other two cards selected without refilling")
 expect(offered(replacement.uid),prefix+" replacement is offered by reassigning the selected flexible card to blue")
 view.object_clicked(yellow.uid)
 expect(view.local.plan.size()==1 and reserved(flexible.uid),prefix+" multiple deselections preserve only the remaining selected card")
 expect(offered(replacement.uid) and offered(blue.uid) and offered(yellow.uid),prefix+" all feasible completions remain available after multiple deselections")
 expect(not offered(green.uid) and not offered(tapped.uid),prefix+" incompatible and tapped cards remain unavailable")
 view.object_clicked(replacement.uid)
 expect(reserved(replacement.uid) and reserved(flexible.uid) and view.local.plan.size()==2,prefix+" selecting a replacement preserves the previously selected card")
 expect(view.local.plan.any(func(p):return p.uid==flexible.uid and p.color=="蓝"),prefix+" selected flexible card is reassigned to blue")
 expect(not view.payment_ready() and offered(yellow.uid),prefix+" incomplete payment still requires yellow")
 view.object_clicked(yellow.uid)
 expect(view.payment_ready() and view.local.plan.size()==3,prefix+" replacement combination is a valid complete payment")
 expect(not offered(blue.uid) and not offered(green.uid),prefix+" full payment cannot add another resource")
 view.render();view.refresh_payment_plan()
 expect(reserved(replacement.uid) and not reserved(blue.uid) and view.payment_ready(),prefix+" redraw preserves the replacement plan")
 expect(snapshot()==before,prefix+" editing the payment does not mutate the duel")
 if view.payment_ready():
  if mode=="target":view.confirm_declaration()
  else:view.commit_local()
  expect(spell.zone=="stack" and flexible.tapped and replacement.tapped and yellow.tapped and not blue.tapped,prefix+" confirmation pays only the chosen resources")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/payment-reselection-ui/"+str(Time.get_ticks_usec()))
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate()
 app.settings_path=Store.Paths.root_override.path_join("settings.json");app.tutorial_local_directory=Store.Paths.root_override.path_join("tutorials")
 DirAccess.make_dir_recursive_absolute(app.tutorial_local_directory)
 root.add_child(app);await frames();app.load_test_decks()
 for android in [false,true]:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  root.size=Vector2i(1280,720) if android else Vector2i(1600,900)
  app.is_android=android;app.layout_dpi_override=320.0 if android else 0.0
  app.layout_safe_override=Rect2(36,0,1220,696) if android else Rect2()
  await frames();app.refresh_responsive_layout();app.begin_battle(true)
  view=app.duel_view;view.set_process(false);e=view.engine;await frames()
  for mode in ["target","payment"]:check_reselection(mode)
 print("PAYMENT_RESELECTION_UI: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
