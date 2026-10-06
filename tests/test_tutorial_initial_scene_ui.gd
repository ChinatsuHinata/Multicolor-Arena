extends "res://tests/support/ui_base.gd"
const OUTPUT="res://work/tutorial-initial-scene"
const Form=preload("res://scripts/tutorial/initial_scene_form.gd")
const Adapter=preload("res://scripts/tutorial/game_adapter.gd")
var editor
var output=""

func frames(count: int=5):
 for i in range(count):await process_frame

func fields():
 return editor.dialog_layer.find_child("TutorialInitialSceneForm",true,false)

func shot(caption: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(caption+".png"))

func run():
 output=OUTPUT.path_join("headless" if DisplayServer.get_name()=="headless" else "rendered")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures-"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.size=Vector2i(1600,900)
 app=load("res://main.tscn").instantiate();app.settings_path=output.path_join("missing-settings.json");app.account_session_path=output.path_join("missing-account.json")
 root.add_child(app);await frames();app.tutorial_editor();await frames();editor=app.screen.get_child(0)
 var source={"id":"private_source","name":"初始场景测试卡组","leader":"70","main":["53","53","35"],"side":["96"],"rule_set":"official"}
 app.decks=[source.duplicate(true)]
 var other_leader=Store.CARDS.keys().filter(func(id):return id!="70" and Store.CARDS[id].kind=="自机" and Store.CARDS[id].get("canonical_id",id)==id)[0]
 var scene=editor.model.data.scenarios.scene_1
 scene.players[0].leader.state={"leader_counters":2}
 scene.players[0].deck_order=[{"card_id":"53","alias":"first","state":{"plus_counters":1}},{"card_id":"35","alias":"second"},{"card_id":"53","alias":"third"}]
 scene.players[0].hand=[{"card_id":"35","alias":"starting_hand"}]
 scene.players[0].field=[{"card_id":"53","alias":"starting_field"}]
 editor.model.data.steps.step_2.task.success={"type":"entity_zone","alias":"first","zone":"deck"}
 editor.model.saved_text=JSON.stringify(editor.model.data);editor.refresh();await frames()
 var before=editor.model.data.duplicate(true)
 var saved_decks=app.decks.duplicate(true)
 await click(editor.find_child("EditTutorialInitialScene",true,false).get_global_rect().get_center());await frames()
 var form=fields()
 expect(form!=null and form.scene==scene,"node inspector opens the effective scene's initial configuration")
 expect(not editor.model.dirty() and editor.model.data==before,"opening initial configuration is lossless")
 form.selector.search_input.text="53";form.selector.search_input.text_changed.emit("53");await frames()
 expect(form.selector.visible_entries().any(func(entry):return entry.id=="53"),"initial deck search accepts card IDs")
 form.selector.select_id("35");form.quantity.value=2
 await click(form.choose.get_global_rect().get_center());await frames()
 expect(form.scene.players[0].deck_order.size()==5 and form.scene.players[1]==before.scenarios.scene_1.players[1],"batch adding cards edits only the chosen side")
 var up=form.move_up.get_global_rect().get_center();await click(up);await frames()
 expect(form.selected_index==3 and form.scene.players[0].deck_order[0]==before.scenarios.scene_1.players[0].deck_order[0],"deck reorder keeps configured card instances intact")
 await click(form.remove.get_global_rect().get_center());await frames()
 expect(form.scene.players[0].deck_order.size()==4,"selected deck copy can be removed")
 form.change_zone("leader");await frames()
 expect(form.selector.entries.all(func(entry):return Store.CARDS[entry.id].kind=="自机") and not form.quantity.visible,"leader search only offers leaders")
 expect(form.selector.query.is_empty() and not form.selector.visible_entries().is_empty(),"switching to leader selection clears incompatible search filters")
 form.selector.select_id(other_leader);await click(form.choose.get_global_rect().get_center());await frames()
 expect(form.scene.players[0].leader=={"card_id":other_leader,"alias":"student_leader","state":{"leader_counters":2}},"changing leader preserves its alias and initial state")
 var player_choice=form.find_child("InitialScenePlayer",true,false)
 player_choice.select(1);player_choice.item_selected.emit(1);form.selector.select_id(other_leader)
 await click(form.choose.get_global_rect().get_center());await frames()
 expect(form.scene.players[1].leader.card_id==other_leader and form.scene.players[0].leader.card_id==other_leader,"opponent leader has an independent selector")
 await shot("battle-leaders")
 await click(editor.find_child("CancelTutorialInitialScene",true,false).get_global_rect().get_center());await frames()
 expect(editor.model.data==before and not editor.model.dirty() and app.decks==saved_decks,"cancelling discards both sides' draft without changing saved decks")
 editor.selected_step="step_2";editor.refresh();await frames();editor.open_initial_scene();await frames();form=fields()
 expect(editor.scene_id=="scene_1" and form.scene==before.scenarios.scene_1,"inherited nodes edit their effective scene")
 form.import_leader.set_pressed_no_signal(false)
 await click(form.find_child("ImportInitialSceneDeck",true,false).get_global_rect().get_center());await frames()
 expect(form.scene.players[0].deck_order==[before.scenarios.scene_1.players[0].deck_order[0],before.scenarios.scene_1.players[0].deck_order[2],before.scenarios.scene_1.players[0].deck_order[1]],"import follows main-deck order and retains metadata by occurrence")
 expect(form.scene.players[0].hand==before.scenarios.scene_1.players[0].hand and form.scene.players[0].field==before.scenarios.scene_1.players[0].field,"import preserves initial hand and battlefield")
 var ordered=form.scene.players[0].deck_order.duplicate(true)
 form.selector.select_id("35");form.quantity.value=50
 await click(form.choose.get_global_rect().get_center());await frames()
 expect(form.card_list.get_v_scroll_bar().value>0 and form.selected_index==52,"batch addition scrolls to the last new copy in a long initial deck")
 form.scene.players[0].deck_order=ordered;form.quantity.value=1;form.selected_index=-1;form.refresh_cards();await frames()
 form.change_zone("leader");form.selector.select_id(other_leader);await click(form.choose.get_global_rect().get_center());await frames()
 form.change_zone("deck_order");await frames()
 await shot("battle-deck")
 expect(editor.model.data==before,"editing initial setup remains private until applied")
 var expected=form.scene.duplicate(true)
 await click(editor.find_child("ApplyTutorialInitialScene",true,false).get_global_rect().get_center());await frames()
 expect(editor.dialog_layer==null and editor.model.data.scenarios.scene_1==expected and editor.model.data.steps==before.steps,"apply replaces only the scene and preserves node conditions")
 var undo_count=editor.model.undo_stack.size()
 editor.open_initial_scene();await frames();await click(editor.find_child("ApplyTutorialInitialScene",true,false).get_global_rect().get_center());await frames()
 expect(editor.model.undo_stack.size()==undo_count,"applying unchanged initial configuration creates no checkpoint")
 var save_path=output.path_join("battle.json")
 expect(editor.model.save_course(save_path).is_empty(),"edited initial battle configuration saves")
 var reloaded=preload("res://scripts/tutorial/authoring_model.gd").new()
 expect(reloaded.load_course(save_path).is_empty() and reloaded.data==JSON.parse_string(JSON.stringify(editor.model.data)),"initial setup round-trips through course JSON")
 var adapter=Adapter.new();expect(adapter.load_scenario("scene_1",expected,Store.CARDS).is_empty(),"runtime accepts edited initial setup")
 expect(adapter.engine.players[0].leader.card_id==other_leader and adapter.engine.players[0].deck.map(func(card):return card.card_id)==["53","53","35"],"runtime receives chosen leader and ordered deck")
 editor.open_recording();await frames()
 expect(editor.recorder.scene.players[0].leader.card_id==other_leader and editor.recorder.scene.players[0].deck_order==expected.players[0].deck_order,"recording starts from edited initial configuration")
 editor.close_recording();await frames()
 editor.open_initial_scene();await frames();form=fields();form.selected_index=0;form.remove_card()
 await click(editor.find_child("ApplyTutorialInitialScene",true,false).get_global_rect().get_center());await frames()
 expect(editor.dialog_layer!=null and form.error_label.visible and "first" in form.error_label.text and editor.model.data.scenarios.scene_1==expected,"removing an alias referenced by a task is rejected without partial changes")
 editor.close_dialog();await frames()
 expect(editor.model.undo() and editor.model.data==before,"initial configuration edit can be undone atomically")
 for kind in ["deck","in_game"]:
  app.tutorial_editor();await frames();editor=app.screen.get_child(0);editor.change_scene(kind);await frames()
  editor.open_initial_scene();await frames();form=fields()
  var original=editor.model.data.duplicate(true)
  var imported=source.duplicate(true);imported.rule_set="test";form.import_deck(imported)
  expect(form.scene.deck.rule_set=="test" and form.rule_choice.get_item_text(form.rule_choice.selected)=="测试卡组",kind+" import updates the visible rule set")
  form.change_zone("side");form.selector.select_id("35");form.quantity.value=1
  await click(form.choose.get_global_rect().get_center());await frames()
  expect(form.scene.deck.side==["96","35"] and editor.model.data==original,kind+" supports private main/side deck setup")
  await shot(kind+"-deck")
  var target=editor.scene_id;var deck=form.scene.deck.duplicate(true)
  await click(editor.find_child("ApplyTutorialInitialScene",true,false).get_global_rect().get_center());await frames()
  expect(editor.model.data.scenarios[target].deck==deck and editor.model.validate().ok,kind+" applies validated initial leader and main/side decks")
  expect(editor.model.save_course(output.path_join(kind+".json")).is_empty(),kind+" initial deck can be saved")
  editor.open_initial_scene();await frames();form=fields()
  expect(form.scene.deck==deck,kind+" initial deck reopens unchanged")
  if kind=="deck":
   var unchanged=editor.model.data.duplicate(true)
   await click(form.clear_cards.get_global_rect().get_center());await frames()
   expect(form.scene.deck.main.is_empty() and form.scene.deck.side==deck.side and editor.model.data==unchanged,"clearing a deck zone only affects that zone's private draft")
   editor.close_dialog();await frames();editor.open_initial_scene();await frames();form=fields()
  await frames();expect(form.get_global_rect().end.x<=1600 and form.get_global_rect().end.y<=900,kind+" initial configuration fits desktop window")
  if kind=="in_game":
   root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720);await frames(12)
   expect(form.get_global_rect().end.x<=1280 and form.get_global_rect().end.y<=720 and form.card_list.size.y>=100,"initial configuration fits a smaller desktop window")
   await shot("compact-deck")
  editor.close_dialog();await frames()
 root.content_scale_size=Vector2i(1600,900);root.size=Vector2i(1600,900);await frames()
 for lesson in ["t1","t2","t3","t4"]:
  app.tutorial_editor("res://data/tutorial/beginner/"+lesson+".json");await frames();editor=app.screen.get_child(0)
  var original=editor.model.data.duplicate(true)
  editor.open_initial_scene();await frames()
  await click(editor.find_child("ApplyTutorialInitialScene",true,false).get_global_rect().get_center());await frames()
  expect(editor.model.data==original and not editor.model.dirty(),lesson+" initial configuration opens and applies unchanged without losing fields")
 expect(app.decks==saved_decks,"all initial setup operations leave saved player decks unchanged")
 app.free();await frames()
 print("TUTORIAL INITIAL SCENE UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
