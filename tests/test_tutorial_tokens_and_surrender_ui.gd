extends "res://tests/support/ui_base.gd"
const Runtime=preload("res://scripts/tutorial/runtime.gd")
var output="res://work/tutorial-token-art"

func frames(count: int=6):
 for i in range(count):await process_frame

func fixture() -> Dictionary:
 var source=JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial/beginner/t3.json"))
 var puzzle=source.steps.r3.duplicate(true);puzzle.next="$complete"
 return {"schema_version":1,"id":"t3_token_art_only","title":"衍生物显示专项","initial_scenario":"intro_empty","start_step":"board","completion":{"type":"always"},"scenarios":{"intro_empty":source.scenarios.intro_empty,"final_puzzle":source.scenarios.final_puzzle},"steps":{"board":{"type":"info","guide":{"text":"打开最后一题的初始局面。"},"next":"r3"},"r3":puzzle}}

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixture"))
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
 app=load("res://main.tscn").instantiate();app.settings_path=output.path_join("missing-settings.json");app.account_session_path=output.path_join("missing-account.json")
 root.add_child(app);await frames()
 app.clear_page("tutorial_scene");await frames()
 var flow=Runtime.new()
 var reason=flow.start(fixture(),Store.CARDS)
 expect(reason.is_empty(),"display fixture starts: "+reason)
 if not reason.is_empty():flow.free();app.queue_free();quit(1);return
 flow.set_process(false)
 var scene=preload("res://scripts/tutorial/scene_view.gd").new();app.screen.add_child(scene);scene.begin(app,flow)
 view=scene.surface;view.set_process(false);await frames()
 expect(app.duel_view==view,"embedded battlefield registers its art context")
 expect(flow.next(),"display switches to dynamic frogs")
 view=scene.surface;view.set_process(false);e=view.engine;await frames()
 scene.tutorial_guide.set_popup(false);await frames()
 expect(app.duel_view==view,"art context follows the replacement battlefield")
 var art=app.texture("token-ucs-098")
 expect(art!=null,"UCS-098 source art is available")
 for alias in ["frog_one","frog_two","frog_three"]:
  var frog=flow.adapter.entity(alias)
  var face=view.table.visuals["card_"+str(frog.uid)].get_node("Face").material_override
  expect(face.albedo_texture!=null and face.albedo_texture==art,alias+" renders the UCS-098 card art")
 await create_timer(1.3).timeout
 await shot("final-puzzle")
 var frog=flow.adapter.entity("frog_one")
 view.inspect_card(frog.card_id,frog.uid);await frames()
 expect(view.inspection.get_child(0).get_child(0).texture==art,"dynamic frog inspection renders the same art")
 await shot("frogs")
 for mobile in [false,true]:
  view.is_android=mobile
  view.open_tools_menu();await frames()
  var surrender=find_button(app.menu_popup,"本局投降")
  expect(surrender!=null and surrender.disabled,"tutorial surrender button is disabled on "+("Android" if mobile else "desktop"))
  if not mobile:await shot("disabled-surrender")
  app.close_menu_popup()
 var revision=e.revision
 view.confirm_surrender();await frames()
 expect(e.revision==revision and e.winner==-2 and not app.get_children().any(func(child):return child is ConfirmationDialog and child.visible),"tutorial cannot invoke surrender directly")
 view.tutorial_runtime=null
 expect(view.responsive.tools_actions().any(func(action):return action[0]=="本局投降" and not action[2]),"ordinary battles retain surrender")
 view.tutorial_runtime=flow
 scene.queue_free();await frames()
 expect(app.duel_view==null,"removing the tutorial clears its art context")
 print("TUTORIAL TOKEN ART AND SURRENDER: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
