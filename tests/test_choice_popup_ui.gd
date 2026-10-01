extends "res://tests/support/ui_base.gd"

func frames():
 for i in range(5):await process_frame

func setup_choice(android: bool):
 root.size=Vector2i(1600,900)
 root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 app.is_android=android
 app.refresh_ui_metrics()
 app.load_test_decks();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine
 clean(true)
 e.debug_free_payment=true
 e.players[0].leader=e.make_card("character-fdf-117",0,"leader",true)
 put("token-fdf-131","field")
 put("53","field")
 put("53","field",1)
 var spell=put("spell-fdf-072","hand")
 view.local={"uid":spell.uid,"mode":"target"}
 view.render();await frames()

func capture_choice(filename: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/"+filename)

func check_choice(android: bool):
 var panel=view.hud.find_child("AndroidChoicePanel" if android else "DesktopChoicePanel",true,false)
 expect(panel!=null,"choice opens as a floating panel")
 if panel==null:return
 var grid=panel.find_child("ChoiceGrid",true,false)
 expect(grid!=null and grid.columns>=2,"choices use a multi-column card grid")
 var first=grid.get_child(0) as Button
 var second=grid.get_child(1) as Button
 expect(first.size.y>=100 and second.get_global_rect().position.x>first.get_global_rect().position.x,"choices are tall side-by-side tiles")
 var confirm=panel.find_child("ChoiceConfirm",true,false) as Button
 expect(confirm!=null and panel.get_global_rect().encloses(confirm.get_global_rect()),"confirmation stays inside the popup")
 await capture_choice("choice-popup-android.png" if android else "choice-popup-desktop.png")
 await click(first.get_global_rect().get_center())
 expect(view.picker.path.size()>0,"clicking a popup choice advances the selection")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/choice-popup-fixture/")
 await setup_choice(false)
 var tengu=e.cards["spell-fdn-039"]
 expect(tengu.cost.size()==1 and int(tengu.cost.get("红/黑",0))==1 and tengu.colors==["红","黑"],"Tengu waterfall costs one red or black and has both colors")
 e.debug_free_payment=false
 var source=put("64","palette")
 expect(e.payment_valid(0,tengu.cost,[{"uid":source.uid,"color":"红"}]) and e.payment_valid(0,tengu.cost,[{"uid":source.uid,"color":"黑"}]),"either red or black resource pays the spell's single cost")
 e.players[0].palette.erase(source)
 await check_choice(false)
 app.queue_free();await frames()
 await setup_choice(true)
 await check_choice(true)
 print("CHOICE POPUP UI: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
