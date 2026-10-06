extends "res://tests/support/ui_base.gd"
const Config=preload("res://scripts/tutorial/config.gd")
const COURSE="res://data/tutorial/beginner/t1.json"

func frames(count: int=6):
 for i in range(count):await process_frame

func shot(title: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/tutorial-t1/"+title+".png")

func marked(overview) -> Array:
 return overview.card_frames.filter(func(card):return card.get_meta("tutorial_highlighted",false))

func check_course(mobile: bool):
 app.is_android=mobile;app.layout_dpi_override=360 if mobile else 0
 root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND if mobile else Window.CONTENT_SCALE_ASPECT_KEEP
 app.layout_safe_override=Rect2(40,12,1200,684) if mobile else Rect2()
 app.begin_tutorial(COURSE);await frames()
 var scene=app.screen.get_child(0)
 var flow=scene.runtime
 var guide=scene.tutorial_guide
 var overview=scene.editor_host.deck_overview
 var label="Android" if mobile else "desktop"
 expect(flow.running and flow.current_step=="d1" and flow.adapter.scene_type=="deck",label+" t1 starts in the deck scene")
 expect(flow.adapter.ui_deck.main.size()==50 and flow.adapter.ui_deck.side.size()==2,label+" shows the complete Remilia deck")
 for id in ["d2","d3","d4","d5"]:
  expect(flow.next() and flow.current_step==id,label+" advances to "+id)
  await frames()
 expect(guide.step.guide.targets==[{"card_id":"129","zone":"main"}],label+" highlights all four Wings")
 if not mobile:expect(marked(overview).size()==4,label+" draws four red Wing borders")
 expect(flow.next() and flow.current_step=="d6",label+" advances to restricted spell")
 await frames()
 expect(guide.step.guide.targets==[{"card_id":"spell-fdf-035","zone":"main"}],label+" highlights both restricted spells")
 if not mobile:expect(marked(overview).size()==2,label+" draws two red restricted borders")
 for id in ["d7","d8","d9"]:
  expect(flow.next() and flow.current_step==id,label+" advances to "+id)
  await frames()
 expect(guide.focus_card.visible and guide.focus_card.texture!=null,label+" shows Remilia art beside color explanation")
 await shot(label+"-d9")
 expect(flow.next() and flow.current_step=="d10",label+" advances to color value")
 await frames()
 expect(guide.focus_card.visible,label+" keeps Remilia art for cost explanation")
 expect(flow.next() and flow.current_step=="q1",label+" opens Night King question")
 await frames()
 expect(guide.focus_card.visible and guide.focus_card.texture!=null and guide.answers_scroll.visible,label+" shows Night King art and answers")
 expect(not guide.reset_button.visible and not flow.can_reset_task(),label+" question has no scenario reset")
 expect(app.ui_metrics.safe.grow(1).encloses(guide.panel.get_global_rect()),label+" question fits the safe area")
 expect(guide.answers_scroll.get_global_rect().grow(1).encloses(guide.answer_buttons[0].get_global_rect()),label+" answers remain visible below the card")
 await shot(label+"-q1")
 expect(not flow.submit_answer("3",flow.epoch) and flow.current_step=="q1",label+" wrong answer stays on question")
 expect(flow.submit_answer("5",flow.epoch) and flow.current_step=="d11",label+" accepts color value five")
 await frames()
 expect(flow.next() and flow.finished and app.tutorial_completed("t1"),label+" completes and saves t1")

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://work/tutorial-t1"))
 var loaded=Config.new().load_file(COURSE,Store.CARDS)
 expect(loaded.ok,"t1 validates against the actual card database")
 if not loaded.ok:print(loaded.errors);quit(1);return
 var deck=loaded.data.scenarios.remilia_deck.deck
 expect(deck.main.count("129")==4 and deck.main.count("spell-fdf-035")==2,"t1 uses the exact highlighted copy counts")
 expect(Store.CARDS["74"].cost["红"]+Store.CARDS["74"].cost["黑"]==3,"Remilia cost matches the lesson")
 expect(Store.CARDS["spell-fdn-008"].cost["红"]+Store.CARDS["spell-fdn-008"].cost["黑"]==5,"Night King answer matches the card")
 var fixture="res://work/tutorial-t1/fixtures-"+str(Time.get_ticks_usec())
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 var settings=fixture.path_join("settings.json")
 var file=FileAccess.open(settings,FileAccess.WRITE);file.store_string('{"fullscreen":false}');file.close()
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900)
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate();app.settings_path=settings;app.account_session_path=fixture.path_join("account.json")
 root.add_child(app);await frames()
 for mobile in [false,true]:await check_course(mobile)
 app.queue_free();await frames()
 print("TUTORIAL T1: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
