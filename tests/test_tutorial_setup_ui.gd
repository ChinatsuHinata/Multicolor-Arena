extends "res://tests/support/ui_base.gd"
const OUTPUT="res://work/tutorial-setup-ui"
const Adapter=preload("res://scripts/tutorial/game_adapter.gd")
var editor

func frames(count: int=5):
 for i in range(count):await process_frame

func quiet():
 if not is_instance_valid(view) or not view.has_method("revealing"):return
 for i in range(240):
  await process_frame
  if not view.revealing() and not view.table.is_animating():break
  await create_timer(0.015).timeout

func key(code: int,options: Dictionary={}):
 var event=InputEventKey.new();event.keycode=code;event.pressed=true
 for name in options:event.set(name,options[name])
 root.push_input(event,true);await frames(2)
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames(2)

func select_browser_card(who: int,zone: String,uid: int):
 await quiet();view.browse_zone(who,zone);await frames()
 var art=view.browser_cards.get_children().map(func(row):return row.get_node("PileCard")).filter(func(card):return card.get_meta("browser_uid")==uid)[0]
 await click(art.get_global_rect().get_center());await frames();await quiet()

func open_board():
 var button=editor.find_child("EditTutorialInitialBoard",true,false)
 var scroll=editor.form.get_parent();scroll.ensure_control_visible(button);await frames()
 await click(button.get_global_rect().get_center());await frames();view=editor.record_view;await quiet()

func battle_setup():
 app.tutorial_editor();await frames();editor=app.screen.get_child(0);editor.selected_step="step_2"
 var scene=editor.model.data.scenarios.scene_1
 for who in range(2):
  for zone in ["deck_order","hand","field","palette","grave","exile"]:
   scene.players[who][zone]=[{"card_id":"53","alias":zone+str(who),"state":{"plus_counters":2}}]
 editor.model.saved_text=JSON.stringify(editor.model.data);editor.refresh();await frames()
 var before=editor.model.data.duplicate(true);var decks=app.decks.duplicate(true)
 await open_board()
 expect(editor.editing_initial_board and editor.record_tools.find_child("BeginRecording",true,false)==null,"each node opens a dedicated scene setup without a recording timeline")
 expect(editor.record_status.text.contains("按 D 删除 / C 复制"),"setup explains both card shortcuts")
 expect(editor.record_status.text.contains("按 P 切换已过一回合"),"setup explains the individual unit readiness shortcut")
 await key(KEY_P)
 expect(view.selection.is_empty(),"P without a selected unit does nothing")
 for who in range(2):
  for zone in ["deck","hand","field","palette","grave","exile"]:
   var alias=("deck_order" if zone=="deck" else zone)+str(who);var original=editor.recorder.adapter.entity(alias);var uid=int(original.uid)
   if zone=="hand":
    view.close_debug();view.hand_zones[who]="hand";view.render();await frames();await create_timer(0.5).timeout
    var art=view.hand_nodes[uid] if who==0 else view.enemy_nodes[uid]
    await click(art.get_global_rect().get_center());await frames();await quiet()
   elif zone in ["field","palette"]:
    view.close_debug();await frames()
    if zone=="palette":view.apply_tutorial_presentation({"camera_view":"own_palette" if who==0 else "enemy_palette"});await frames();await quiet()
    await click(point(uid));await frames();await quiet()
   else:await select_browser_card(who,zone,uid)
   expect(view.selection==[uid] and view.local.is_empty(),"actual click selects setup card: "+zone+str(who))
   var previous_age=[original.entered,original.get("entered_turns")]
   await key(KEY_P)
   if zone=="field":
    expect(view.engine.summoning_sick(original) and view.selection==[uid],"P makes the clicked battlefield unit fresh: "+str(who))
    expect(view.table.visuals["card_"+str(uid)].get_node("SummoningMist").visible,"P immediately shows summoning mist: "+str(who))
    await key(KEY_P)
    expect(not view.engine.summoning_sick(original) and not view.table.visuals["card_"+str(uid)].get_node("SummoningMist").visible,"P restores readiness and clears summoning mist: "+str(who))
    if who==0:await key(KEY_P)
   else:expect([original.entered,original.get("entered_turns")]==previous_age,"P ignores the clicked unit outside the battlefield: "+zone+str(who))
   await key(KEY_C)
   var copy_uid=int(view.selection[0]) if view.selection.size()==1 else 0;var copy=view.engine.find_card(copy_uid)
   expect(copy_uid!=uid and copy.get("zone")==zone and copy.get("owner")==who and copy.get("plus_counters")==2,"C copies within the selected region: "+zone+str(who))
   await quiet();await key(KEY_D)
   expect(view.engine.find_card(copy_uid).is_empty() and not view.engine.find_card(uid).is_empty(),"D deletes the copy and keeps the original: "+zone+str(who))
   if zone=="palette":view.apply_tutorial_presentation({"camera_view":"battlefield"});await frames();await quiet()
 view.close_debug();await frames();await quiet()
 var leader=int(view.engine.players[0].leader.uid)
 await select_browser_card(0,"leader",leader);await key(KEY_D)
 expect(view.selection==[leader] and not view.engine.find_card(leader).is_empty(),"D protects the actual deck leader")
 await key(KEY_C);await quiet()
 expect(view.engine.leaders(0).size()==2,"C also works in the leader zone")
 view.close_debug();await frames()
 for who in range(2):
  await quiet();await click(view.life_widgets[who].button.get_global_rect().get_center(),MOUSE_BUTTON_RIGHT);await frames()
  expect(editor.dialog_layer!=null,"both player life badges are reachable beside setup tools")
  if editor.dialog_layer==null:return
  var input=editor.dialog_layer.find_child("TutorialInitialLife",true,false)
  expect(input!=null and input.value==20,"right-click player opens initial life input")
  input.value=13+who
  await click(editor.find_child("ApplyTutorialInitialLife",true,false).get_global_rect().get_center());await frames()
  expect(view.engine.players[who].life==13+who and editor.dialog_layer==null,"life confirmation updates only the chosen player")
 await quiet();await click(view.life_widgets[0].button.get_global_rect().get_center(),MOUSE_BUTTON_RIGHT);await frames()
 editor.dialog_layer.find_child("TutorialInitialLife",true,false).value=99
 await click(editor.find_child("CancelTutorialInitialLife",true,false).get_global_rect().get_center());await frames()
 expect(view.engine.players[0].life==13,"cancelling life input leaves setup intact")
 var hand=int(editor.recorder.adapter.entity("hand0").uid);view.selection=[hand]
 var typing=TextEdit.new();editor.add_child(typing);typing.grab_focus();await frames();await key(KEY_C);await key(KEY_D)
 expect(view.engine.players[0].hand.size()==1,"typing C or D cannot edit a selected card")
 typing.release_focus();typing.free();await frames()
 var field=editor.recorder.adapter.entity("field0");view.selection=[int(field.uid)]
 var field_age=[field.entered,field.get("entered_turns")]
 typing=TextEdit.new();editor.add_child(typing);typing.grab_focus();await frames();await key(KEY_P)
 expect([field.entered,field.get("entered_turns")]==field_age,"typing P cannot change selected unit readiness")
 typing.release_focus();typing.free();await frames()
 await key(KEY_P,{"ctrl_pressed":true});await key(KEY_P,{"echo":true})
 expect([field.entered,field.get("entered_turns")]==field_age,"modified and repeated P cannot change readiness")
 view.selection=[hand]
 await key(KEY_C,{"ctrl_pressed":true});await key(KEY_C,{"echo":true})
 expect(view.engine.players[0].hand.size()==1,"modified and repeated C do not copy")
 expect(editor.model.data==before and app.decks==decks and editor.recorder.actions.is_empty(),"initial scene edits stay private and generate no recording actions")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUTPUT.path_join("scene-setup.png"))
 await quiet();await click(editor.find_child("ApplyTutorialInitialBoard",true,false).get_global_rect().get_center());await frames()
 expect(editor.record_view==null and editor.model.dirty(),"scene apply closes setup and marks the course modified")
 var target=editor.model.data.steps.step_2.scenario;var value=editor.model.data.scenarios[target]
 expect(target!="scene_1" and editor.model.data.scenarios.scene_1==before.scenarios.scene_1 and editor.model.data.steps.step_1==before.steps.step_1,"apply assigns a private scene to the selected node and preserves the shared source")
 expect(editor.model.data.steps.step_2.task==before.steps.step_2.task and editor.model.data.steps.step_2.scenario_mode=="reset","initial scene edit retains task conditions and starts from the applied tableau")
 var path=OUTPUT.path_join("initial-board.json")
 expect(editor.model.save_course(path).is_empty() and editor.model.load_course(path).is_empty(),"initial board with life and leader copies saves and reopens")
 var adapter=Adapter.new();expect(adapter.load_scenario(target,value,Store.CARDS).is_empty(),"runtime accepts the saved tableau")
 expect(adapter.engine.players[0].life==13 and adapter.engine.players[1].life==14 and adapter.engine.leaders(0).size()==2,"saved tableau restores both players' life and leader-zone copy")
 expect(adapter.engine.summoning_sick(adapter.entity("field0")) and not adapter.engine.summoning_sick(adapter.entity("field1")),"saved scene retains the two players' independent P settings")
 var saved=editor.model.data.duplicate(true);editor.refresh();await frames();await open_board()
 expect(view.engine.players[0].life==13 and view.engine.leaders(0).size()==2,"reopening the same node presents its configured initial scene")
 expect(view.engine.summoning_sick(editor.recorder.adapter.entity("field0")) and not view.engine.summoning_sick(editor.recorder.adapter.entity("field1")),"reopening the setup retains each unit's P setting")
 var checkpoint_count=editor.model.undo_stack.size()
 editor.apply_initial_board();await frames()
 expect(editor.model.data==saved and editor.model.undo_stack.size()==checkpoint_count,"applying an unchanged tableau creates no new scene or undo point")
 await open_board();editor.recorder.set_setup_life(0,7);editor.close_recording();await frames()
 expect(editor.model.data==saved,"cancelling scene setup discards its edits")
 await open_board();view.selection=[int(view.engine.players[0].leader.uid)];await key(KEY_D)
 expect(not view.engine.find_card(int(view.selection[0])).is_empty(),"saved deck leader remains protected")
 editor.close_recording();await frames()
 expect(app.decks==decks,"all node setup operations preserve player decks")

func tenshi_readiness_setup():
 app.tutorial_editor("res://data/tutorial/beginner/t4.json");await frames();editor=app.screen.get_child(0)
 editor.selected_step="step_1";editor.refresh();await frames()
 var source=editor.model.data.scenarios[editor.scene_id]
 source.players[0].leader.state.entered=int(source.turn)
 source.players[0].leader.state.entered_turns=int(source.players[0].state.turns)
 editor.model.saved_text=JSON.stringify(editor.model.data)
 var original=editor.model.data.duplicate(true);var original_scene=editor.scene_id
 await open_board()
 var tenshi=view.engine.players[0].leader;var alias=source.players[0].leader.alias
 expect(tenshi.card_id=="character-fdf-ex04" and view.engine.summoning_sick(tenshi),"nonspell task starts with fresh battlefield Tenshi for the save regression")
 view.selection=[int(tenshi.uid)];await key(KEY_P)
 expect(view.engine.can_attack(0,int(tenshi.uid)),"P alone makes the nonspell task's Tenshi able to attack")
 await quiet();await click(editor.find_child("ApplyTutorialInitialBoard",true,false).get_global_rect().get_center());await frames()
 var target=editor.model.data.steps.step_1.scenario
 expect(target!=original_scene and editor.model.dirty() and editor.model.data.scenarios[original_scene]==original.scenarios[original_scene],"readiness-only apply saves a private scene and leaves the shared source intact")
 var path=OUTPUT.path_join("tenshi-ready.json")
 expect(editor.model.save_course(path).is_empty(),"Tenshi readiness-only edit saves the course")
 app.tutorial_editor(path);await frames();editor=app.screen.get_child(0);editor.selected_step="step_1";editor.refresh();await frames()
 await open_board();tenshi=editor.recorder.adapter.entity(alias)
 expect(view.engine.can_attack(0,int(tenshi.uid)),"closing and reopening the saved course keeps Tenshi able to attack in setup")
 var saved=editor.model.data.duplicate(true);var undo_count=editor.model.undo_stack.size()
 editor.apply_initial_board();await frames()
 expect(editor.model.data==saved and editor.model.undo_stack.size()==undo_count,"reapplying saved readiness leaves the course unchanged")
 editor.test_course();await frames();var flow=editor.playtest.runtime;flow.set_process(false)
 tenshi=flow.adapter.entity(alias)
 expect(flow.current_step=="step_1" and flow.adapter.engine.can_attack(0,int(tenshi.uid)),"saved Tenshi is also able to attack when previewing the actual task")
 flow.adapter.engine.attack(0,int(tenshi.uid));flow.tick();await frames()
 expect(tenshi.attacked,"saved Tenshi can submit a real attack in the task")
 expect(flow.reset_task() and flow.adapter.engine.can_attack(0,int(flow.adapter.entity(alias).uid)),"task reset restores Tenshi's saved attack readiness")
 editor.stop_test();await frames()

func leader_zone_setup():
 for zone in ["grave","palette","exile"]:
  app.tutorial_editor();await frames();editor=app.screen.get_child(0);editor.selected_step="step_2"
  editor.model.data.scenarios.scene_1.players[0].leader_on_field=true
  var before=editor.model.data.duplicate(true);editor.refresh();await frames();await open_board()
  for who in range(2):
   var leader=view.engine.players[who].leader
   expect(view.engine.debug_move(int(leader.uid),zone).is_empty(),"setup moves either player's actual leader: "+zone+str(who))
   leader.leader_counters=2+who
  view.render();await frames();await quiet()
  await click(editor.find_child("ApplyTutorialInitialBoard",true,false).get_global_rect().get_center());await frames()
  var target=editor.model.data.steps.step_2.scenario
  expect(editor.record_view==null and target!="scene_1" and editor.model.data.scenarios.scene_1==before.scenarios.scene_1,"apply saves placed leaders in the selected node's private scene: "+zone)
  var path=OUTPUT.path_join("initial-leader-"+zone+".json")
  expect(editor.model.save_course(path).is_empty() and editor.model.load_course(path).is_empty(),"course with placed leaders saves and reopens: "+zone)
  var adapter=Adapter.new();expect(adapter.load_scenario(target,editor.model.data.scenarios[target],Store.CARDS).is_empty(),"runtime loads saved leader placement: "+zone)
  for who in range(2):
   var leader=adapter.entity("student_leader" if who==0 else "enemy_leader")
   expect(is_same(leader,adapter.engine.players[who].leader) and leader.zone==zone and adapter.engine.players[who][zone].count(leader)==1 and leader.leader_counters==2+who,"saved leader retains identity, zone and counters: "+zone+str(who))
  editor.refresh();await frames();await open_board()
  for who in range(2):expect(view.engine.players[who].leader.zone==zone,"reopening initial scene keeps leader placement: "+zone+str(who))
  var saved=editor.model.data.duplicate(true);var undo_count=editor.model.undo_stack.size()
  editor.apply_initial_board();await frames()
  expect(editor.model.data==saved and editor.model.undo_stack.size()==undo_count,"reapplying unchanged leader placement creates no new scene: "+zone)

func deck_setup():
 for kind in ["in_game","deck"]:
  app.tutorial_editor();await frames();editor=app.screen.get_child(0);editor.change_scene(kind);await frames()
  var before=editor.model.data.duplicate(true);await open_board()
  if kind=="deck":
   editor.edit_record_deck();await frames()
   var deck_view=editor.dialog_layer.get_children().filter(func(node):return node.get_script()==preload("res://scripts/tutorial/authoring_deck.gd"))[0]
   deck_view.selected="35";deck_view.add_to("main");await frames();deck_view.on_apply.call(deck_view.draft);await frames()
  else:
   editor.record_view.editor_host.selected="35";editor.record_view.editor_host.add_to("main");await frames()
  editor.apply_initial_board();await frames()
  var target=editor.model.data.steps.step_1.scenario
  expect(editor.model.data.scenarios[target].deck.main==["53","35"] and editor.model.validate().ok,kind+" node applies a separately configured initial deck")
  expect(editor.model.data.scenarios[before.steps.step_1.scenario]==before.scenarios[before.steps.step_1.scenario],kind+" setup preserves the previous scene")

func recorded_and_mulligan_setup():
 app.tutorial_editor();await frames();editor=app.screen.get_child(0)
 var step=editor.model.data.steps.step_1
 step.sequence={"actions":[{"type":"pass_priority","player":0}]}
 editor.refresh();await frames();await open_board()
 expect(not editor.record_loaded and editor.recorder.points.is_empty() and editor.recorder.actions.is_empty(),"initial scene editing skips existing recording playback")
 editor.recorder.set_setup_life(0,9);editor.apply_initial_board();await frames()
 expect(editor.model.data.steps.step_1.sequence==step.sequence,"applying a new initial scene preserves the existing recorded actions")
 app.tutorial_editor();await frames();editor=app.screen.get_child(0);editor.selected_step="step_2"
 var scene=editor.model.data.scenarios.scene_1;scene.phase="mulligan";scene.turn=0
 scene.players[0].state={"mulligan_done":false};scene.players[1].state={"mulligan_done":true}
 scene.players[0].hand=[{"card_id":"53","alias":"opening_hand"}]
 editor.refresh();await frames();await open_board()
 var uid=int(editor.recorder.adapter.entity("opening_hand").uid)
 await create_timer(0.5).timeout;await click(view.hand_nodes[uid].get_global_rect().get_center());await frames();await key(KEY_C)
 expect(view.engine.players[0].hand.size()==2 and editor.recorder.actions.is_empty(),"opening-hand nodes also allow setup copying before mulligan play")
 editor.apply_initial_board();await frames()
 expect(editor.record_view==null and editor.model.validate().ok,"opening-hand initial scene applies with its mulligan state intact")

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 Store.Paths.root_override=ProjectSettings.globalize_path(OUTPUT.path_join("fixtures-"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.size=Vector2i(1600,900)
 app=load("res://main.tscn").instantiate();app.settings_path=OUTPUT.path_join("missing-settings.json");app.account_session_path=OUTPUT.path_join("missing-account.json")
 root.add_child(app);await frames();await battle_setup();await tenshi_readiness_setup();await leader_zone_setup();await deck_setup();await recorded_and_mulligan_setup()
 app.free();await frames()
 print("TUTORIAL SETUP UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
