extends "res://tests/support/ui_base.gd"
const COURSE="res://data/tutorial/beginner/t2.json"

func frames(count: int=6):
 for i in range(count):await process_frame

func check_selection(mobile: bool):
 app.is_android=mobile
 app.layout_dpi_override=360 if mobile else 0
 app.layout_safe_override=Rect2(40,12,1200,684) if mobile else Rect2()
 root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND if mobile else Window.CONTENT_SCALE_ASPECT_KEEP
 app.begin_tutorial(COURSE)
 await frames(12)
 var scene=app.screen.get_child(0)
 var flow=scene.runtime
 view=scene.surface
 var label="Android" if mobile else "desktop"
 expect(flow.running and flow.current_step=="d1" and flow.adapter.engine.phase=="mulligan",label+" opens real mulligan")
 expect(flow.next() and flow.next() and flow.current_step=="r1",label+" reaches card selection")
 await frames()
 expect(scene.tutorial_guide.side_layout() and view.tutorial_controls_enabled,label+" keeps hand selection enabled")
 var night=flow.adapter.entity("night_king")
 var fire=flow.adapter.entity("fire_person")
 var wing=flow.adapter.entity("wing")
 view.hand_clicked(night.uid)
 view.hand_clicked(wing.uid)
 var confirm=find_button(view.hud,"调度 2 张")
 expect(confirm!=null and view.selection.has(night.uid) and view.selection.has(wing.uid),label+" selects two hand cards")
 if confirm!=null:confirm.pressed.emit()
 await frames()
 expect(flow.current_step=="r1" and flow.adapter.engine.phase=="mulligan" and not flow.adapter.engine.players[0].mulligan_done,label+" wrong pair stays in task")
 view.hand_clicked(night.uid)
 view.hand_clicked(fire.uid)
 confirm=find_button(view.hud,"调度 2 张")
 if confirm!=null:confirm.pressed.emit()
 await frames()
 expect(flow.current_step=="d3" and flow.adapter.engine.phase=="prepare" and flow.adapter.engine.players[0].mulligan_done,label+" correct pair performs mulligan")
 expect(flow.adapter.entity("night_king").zone=="deck" and flow.adapter.entity("fire_person").zone=="deck" and flow.adapter.engine.players[0].hand.size()==4,label+" replaced cards return to deck and hand refills")

func run():
 var fixture="res://work/tutorial-mulligan-fixture-"+str(Time.get_ticks_usec())
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 var settings=fixture.path_join("settings.json")
 var file=FileAccess.open(settings,FileAccess.WRITE)
 file.store_string('{"fullscreen":false}')
 file.close()
 root.mode=Window.MODE_WINDOWED
 root.size=Vector2i(1600,900)
 root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate()
 app.settings_path=settings
 app.account_session_path=fixture.path_join("account.json")
 root.add_child(app)
 await frames()
 for mobile in [false,true]:await check_selection(mobile)
 app.queue_free()
 await frames()
 print("TUTORIAL MULLIGAN SELECTION: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
