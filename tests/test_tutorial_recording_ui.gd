extends "res://tests/support/ui_base.gd"
const OUTPUT="res://work/tutorial-recording"
var editor

func frames(count: int=5):
 for i in range(count):await process_frame

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUTPUT.path_join(name+".png"))

func quiet():
 for i in range(400):
  await process_frame
  if not view.revealing() and not view.table.is_animating() and view.engine.presentation_events.is_empty():return
  await create_timer(0.015).timeout

func native():
 return editor.record_view.editor_host

func deck_recording(mobile: bool):
 app.is_android=mobile;app.layout_dpi_override=240 if mobile else 0
 app.layout_safe_override=Rect2(32,12,1216,696) if mobile else Rect2()
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND if mobile else Window.CONTENT_SCALE_ASPECT_KEEP
 app.tutorial_editor();await frames();editor=app.screen.get_child(0)
 editor.change_scene("in_game");await frames()
 var before=editor.model.data.duplicate(true);var player_deck=app.draft.duplicate(true)
 editor.open_recording();await frames()
 expect(native().draft.main==["53"],"private native deck opens for function recording")
 native().selected="35";native().add_to("main");await frames()
 expect(editor.recorder.actions.is_empty(),"setup card additions are not recorded")
 editor.begin_recording();await frames()
 native().selected="96";native().add_to("main");await frames()
 expect(editor.recorder.actions.size()==1 and editor.recorder.nodes[0].task.action.args.card_id=="96","real native add records required card")
 expect(editor.recorder.nodes[0].task.success.card_id=="96" and editor.recorder.nodes[0].task.success.value==1,"recorded success counts the prescribed card")
 native().perform("editor.inspect",{"card_id":"96"},func():pass);await frames()
 expect(editor.recorder.actions.size()==2,"native inspection becomes its own functional step")
 expect(not native().perform("editor.export",{},func():failures.append("export ran")),"function recording rejects external deck operations")
 editor.finish_recording();await frames()
 expect(editor.dialog_layer!=null and editor.record_rows.size()==2,"recording results expose one row per functional step")
 editor.record_rows[0].guide.text="向主卡组加入红符。"
 editor.record_rows[0].task.failure={"type":"ui_action","action":{"id":"editor.add","args":{"card_id":"35"}}}
 await shot("android-function-result" if mobile else "function-result")
 editor.apply_recording();await frames()
 var first=editor.model.data.steps.step_1;var second=editor.model.data.steps[first.next]
 expect(first.type=="task" and first.failure=="step_1" and first.restore_on_failure,"functional recording applies success and failure to its node")
 expect(second.task.action.id=="editor.inspect" and second.next=="step_2","generated nodes preserve downstream course")
 expect(editor.model.data.scenarios[first.scenario].deck.main==["53","35"],"tutorial baseline uses setup rather than final recording deck")
 expect(app.draft==player_deck,"function recording keeps player draft unchanged")
 var path=OUTPUT.path_join("android-function.json" if mobile else "function.json")
 expect(editor.model.save_course(path).is_empty(),"functional lesson saves validated JSON")
 var saved=JSON.parse_string(JSON.stringify(editor.model.data))
 expect(editor.model.load_course(path).is_empty() and editor.model.data==saved,"functional lesson reopens with conditions intact")
 editor.refresh();editor.test_course();await frames()
 var flow=editor.playtest.runtime;flow.set_process(false);var deck_host=editor.playtest.editor_host
 deck_host.selected="35";deck_host.add_to("main");flow.tick();await frames()
 expect(flow.current_step=="step_1" and editor.playtest.editor_host.draft.main==["53","35"],"wrong native addition fails and restores visible draft")
 deck_host=editor.playtest.editor_host;deck_host.selected="96";deck_host.add_to("main");flow.tick();await frames()
 expect(flow.current_step==first.next,"prescribed native addition advances tutorial")
 editor.playtest.editor_host.perform("editor.inspect",{"card_id":"96"},func():pass);flow.tick();await frames()
 expect(flow.current_step=="step_2" and flow.adapter.scene_type=="battlefield","functional tutorial reaches preserved battle scene")
 editor.stop_test();await frames()
 editor.open_recording();await frames()
 expect(editor.recorder!=null and editor.record_loaded and editor.recorder.actions.size()==2,"existing native recording reopens with its full timeline")
 if editor.recorder==null:return
 expect(editor.recorder.cursor==0 and native().draft.main==["53","35"],"existing native recording begins at saved setup")
 editor.seek_recording(1);await frames()
 expect(native().draft.main==["53","35","96"] and editor.recorder.actions.size()==2,"stepper restores native deck without deleting future steps")
 expect(editor.record_tools.get_global_rect().end.x<=root.size.x and editor.record_tools.get_global_rect().end.y<root.size.y,"recording controls fit native window")
 await shot("android-function-history" if mobile else "function-history")
 editor.resume_recording();await frames()
 native().perform("editor.inspect",{"card_id":"53"},func():pass);editor.finish_recording();await frames()
 expect(editor.record_rows[0].guide.text==first.guide.text and editor.record_rows[0].task.failure==first.task.failure,"rerecord retains prefix guide and failure settings")
 expect(editor.record_rows[1].task.action.args.card_id=="53","rerecord replaces only actions after the selected boundary")
 editor.close_recording();await frames()
 expect(editor.model.data==saved,"cancelled function recording preserves course")
 editor.open_recording();await frames();editor.finish_recording();await frames()
 var edited_guide=editor.record_rows[0].guide.text+"\n历史步骤编辑。";editor.record_rows[0].guide.text=edited_guide
 editor.close_dialog();editor.finish_recording();await frames()
 expect(editor.record_rows[0].guide.text==edited_guide,"closing result panel retains edited prefix guidance for further tracing")
 editor.apply_recording();await frames()
 expect(editor.model.data.steps.size()==saved.steps.size() and editor.model.data.steps.step_1.next==first.next,"editing existing recording reuses node IDs without duplicating steps")
 expect(editor.model.data.steps.step_1.task==saved.steps.step_1.task,"applying existing recording preserves task conditions")
 expect(editor.model.data.steps[first.next].next=="step_2","applying existing recording preserves downstream transition")
 editor.selected_step=first.next;editor.refresh();editor.open_recording();await frames()
 expect(editor.record_anchor=="step_1" and editor.recorder.cursor==1,"opening a later native recording node traces its prefix and selects that step")
 editor.resume_recording();editor.finish_recording();await frames();editor.apply_recording();await frames()
 expect(not editor.model.data.steps.has(first.next) and editor.model.data.steps.step_1.next=="step_2" and editor.model.validate().ok,"shortening existing recording removes discarded nodes and repairs the continuation")
 expect(before.scenarios[before.steps.step_1.scenario].deck.main==["53"],"source scene remains unchanged through recording")

func readonly_deck():
 app.is_android=false;app.layout_dpi_override=0;app.layout_safe_override=Rect2();root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
 app.tutorial_editor();await frames();editor=app.screen.get_child(0);editor.change_scene("deck");await frames()
 editor.open_recording();await frames()
 editor.edit_record_deck();await frames()
 var setup=editor.dialog_layer.get_children().filter(func(node):return node.get_script()==preload("res://scripts/tutorial/authoring_deck.gd"))[0]
 setup.selected="35";setup.add_to("main");await frames();setup.on_apply.call(setup.draft);await frames()
 expect(native().draft.main==["53","35"] and editor.recorder.actions.is_empty(),"read-only deck can be prepared in private native builder before recording")
 editor.begin_recording();await frames()
 var overview=native().deck_overview
 var card=overview.card_frames.filter(func(item):return item.source_zone=="main")[0]
 await click(card.get_global_rect().get_center(),MOUSE_BUTTON_RIGHT);await frames()
 expect(editor.recorder.actions.size()==1 and editor.recorder.actions[0].id=="editor.inspect","read-only deck right-click records inspection")
 editor.finish_recording();await frames();editor.apply_recording();await frames()
 editor.test_course();await frames()
 overview=editor.playtest.editor_host.deck_overview;card=overview.card_frames.filter(func(item):return item.source_zone=="main")[0]
 var flow=editor.playtest.runtime;flow.set_process(false)
 await click(card.get_global_rect().get_center(),MOUSE_BUTTON_RIGHT);flow.tick();await frames()
 expect(flow.current_step=="step_2","real deck inspection completes recorded guidance task")
 editor.stop_test();await frames()

func delete_key(options: Dictionary={}):
 var event=InputEventKey.new();event.keycode=KEY_D;event.pressed=true
 for key in options:event.set(key,options[key])
 root.push_input(event,true);await frames(2)
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames(2)

func setup_hand_deletion():
 app.tutorial_editor();await frames();editor=app.screen.get_child(0);editor.selected_step="step_2"
 var scene=editor.model.data.scenarios.scene_1
 scene.players[0].hand=[{"card_id":"53","alias":"remove"},{"card_id":"53","alias":"keep"}]
 scene.players[1].hand=[{"card_id":"96","alias":"enemy"},{"card_id":"96","alias":"enemy_copy"}]
 var before=editor.model.data.duplicate(true);var decks=app.decks.duplicate(true)
 editor.refresh();editor.open_recording();await frames();view=editor.record_view;await quiet();await create_timer(0.5).timeout
 var uid=int(editor.recorder.adapter.entity("remove").uid);var keep=int(editor.recorder.adapter.entity("keep").uid)
 expect(editor.record_status.text.contains("按 D 删除"),"setup shows the hand deletion shortcut")
 await delete_key();expect(view.engine.players[0].hand.size()==2,"D without a selected hand card does nothing")
 await click(view.hand_nodes[uid].get_global_rect().get_center());await frames()
 expect(view.selection==[uid] and view.local.is_empty(),"real setup click selects an unplayable hand card without starting a cast")
 await delete_key({"ctrl_pressed":true});await delete_key({"echo":true})
 expect(view.engine.players[0].hand.size()==2,"modified D and repeated key events cannot delete")
 var input=LineEdit.new();editor.add_child(input);input.grab_focus();await frames();await delete_key()
 expect(view.engine.players[0].hand.size()==2,"typing D in a focused text field cannot delete selected hand")
 input.release_focus();input.free();await frames()
 editor.modal("删除快捷键隔离");await delete_key();expect(view.engine.players[0].hand.size()==2,"editor dialogs block hand deletion")
 editor.close_dialog();await frames();await delete_key()
 expect(view.engine.find_card(uid).is_empty() and view.engine.players[0].hand[0].uid==keep and view.selection.is_empty(),"D deletes only the clicked copy and clears its selection")
 var enemy=int(editor.recorder.adapter.entity("enemy").uid)
 var enemy_copy=int(editor.recorder.adapter.entity("enemy_copy").uid)
 expect(editor.record_tools.is_visible_in_tree() and not editor.record_tools.get_global_rect().intersects(view.enemy_nodes[enemy].get_global_rect()),"visible recording tools leave opponent hand cards accessible")
 await click(view.enemy_nodes[enemy].get_global_rect().get_center());await frames()
 expect(view.selection==[enemy] and view.local.is_empty(),"opponent hand can be selected while recording tools remain visible")
 await delete_key()
 expect(view.engine.players[1].hand.size()==1 and view.engine.players[1].hand[0].uid==enemy_copy and view.engine.players[0].hand[0].uid==keep,"D deletes only the selected opponent copy with recording tools visible")
 editor.record_tools.hide();editor.record_restore.show();await frames()
 expect(is_zero_approx(view.opponent_layer.position.y),"hiding recording tools restores the native opponent hand position")
 await create_timer(0.5).timeout
 await click(view.enemy_nodes[enemy_copy].get_global_rect().get_center());await frames();await delete_key()
 expect(view.engine.players[1].hand.is_empty(),"opponent hand click and D also work with recording tools hidden")
 editor.record_tools.show();editor.record_restore.hide();await frames()
 expect(editor.recorder.actions.is_empty() and editor.model.data==before and app.decks==decks,"setup deletion stays private and records no action")
 editor.begin_recording();await frames();await quiet()
 expect(editor.recorder.scene.players[0].hand.size()==1 and editor.recorder.scene.players[1].hand.is_empty() and not editor.record_status.text.contains("按 D 删除"),"recording captures the edited setup and hides its shortcut hint")
 keep=int(editor.recorder.adapter.entity("keep").uid);view.selection=[keep];await delete_key()
 expect(view.engine.players[0].hand.size()==1,"D is disabled once recording has started")
 view.selection=[];view.engine.pass_priority(0);editor.finish_recording();await frames()
 editor.record_mode="demo";editor.apply_recording();await frames()
 var applied=editor.model.data.scenarios[editor.model.scene_for("step_2")]
 expect(editor.record_view==null and applied.players[0].hand.size()==1 and applied.players[1].hand.is_empty(),"applying recording saves the edited hand baseline")
 var path=OUTPUT.path_join("hand-deletion.json")
 expect(editor.model.save_course(path).is_empty() and editor.model.load_course(path).is_empty(),"recording with deleted setup cards saves and reopens")
 editor.refresh();editor.open_recording();await frames();view=editor.record_view;await quiet()
 expect(editor.record_loaded and editor.recorder.actions.size()==1 and view.engine.players[0].hand.size()==1,"saved recording restores the remaining hand and full timeline")
 keep=int(editor.recorder.adapter.entity("keep").uid);view.selection=[keep];await delete_key()
 expect(view.engine.players[0].hand.size()==1,"D cannot edit a restored recording's first boundary")
 editor.close_recording();await frames()

func battle_recording():
 app.tutorial_editor();await frames();editor=app.screen.get_child(0);editor.selected_step="step_2"
 var scene=editor.model.data.scenarios.scene_1
 scene.players[0].field=[{"card_id":"53","alias":"a"}];scene.players[1].field=[{"card_id":"53","alias":"b"}]
 for who in range(2):scene.players[who].deck_order=[{"card_id":"53"},{"card_id":"35"}]
 editor.refresh();editor.open_recording();await frames();view=editor.record_view
 editor.begin_recording();e=view.engine
 e.attack(0,int(editor.recorder.adapter.entity("a").uid));e.pass_priority(1);e.pass_priority(0);e.block([int(editor.recorder.adapter.entity("b").uid)])
 e.pass_priority(0);e.pass_priority(1);e.pass_priority(0);e.pass_priority(1)
 await quiet();editor.finish_recording();await frames()
 expect(editor.record_config.actions.size()==8,"battle recording captures both sides through real engine")
 editor.record_failure={"type":"life","player":0,"op":"le","value":0};editor.apply_recording();await frames()
 var task=editor.model.data.steps.step_2
 expect(task.task.sequence.actions.size()==8 and task.failure=="step_2","battle function recording applies guidance and failure predicate")
 expect(editor.model.save_course(OUTPUT.path_join("battle-function.json")).is_empty(),"battle function recording saves validated JSON")
 editor.test_course();await frames();view=editor.playtest.surface
 var flow=editor.playtest.runtime;flow.set_process(false);editor.playtest.tutorial_guide.set_popup(false)
 flow.next();await frames();view=editor.playtest.surface;editor.playtest.tutorial_guide.set_popup(false)
 for i in range(600):
  if flow.finished or not flow.running:break
  if flow.practice.waiting_student(task.task.sequence):
   var prepared=preload("res://scripts/tutorial/sequence.gd").prepare(flow.adapter,task.task.sequence.actions[flow.practice.index],0)
   if prepared.available:flow.adapter.submit(0,prepared.command)
  flow.tick(0.1);await process_frame
  if view.tutorial_presentation_busy():await create_timer(0.015).timeout
 expect(flow.finished and flow.adapter.entity("b").zone=="grave","battle tutorial runs recorded enemy actions and completes actual task")
 editor.stop_test();await frames()
 var saved=editor.model.data.duplicate(true)
 editor.open_recording();await frames();view=editor.record_view
 expect(editor.record_loaded and editor.recorder.actions.size()==8 and editor.recorder.cursor==0,"existing battle task reopens with eight prescribed steps")
 expect(view.get_node_or_null("RecordedFlowArrows")!=null and not view.recorded_action_arrows().is_empty(),"recorded attack has a visible prescribed-flow arrow")
 editor.seek_recording(3);await frames()
 expect(view.engine.pending.get("kind")=="block" and editor.recorder.actions.size()==8,"battle stepper restores actual block prompt without erasing later actions")
 await shot("battle-history")
 editor.resume_recording();view.engine.block([]);editor.finish_recording();await frames()
 expect(editor.record_config.actions.size()==4 and editor.record_config.actions[3].cards.is_empty(),"battle rerecord retains attack prefix and replaces block suffix")
 expect(editor.record_failure==task.task.failure,"existing battle failure condition survives rerecord")
 editor.close_recording();await frames();expect(editor.model.data==saved,"cancelled battle rerecord leaves saved course untouched")

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 Store.Paths.root_override=ProjectSettings.globalize_path(OUTPUT.path_join("fixtures-"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.size=Vector2i(1600,900)
 app=load("res://main.tscn").instantiate();app.settings_path=OUTPUT.path_join("missing-settings.json");app.account_session_path=OUTPUT.path_join("missing-account.json")
 root.add_child(app);await frames()
 await deck_recording(false);await readonly_deck();await setup_hand_deletion();await battle_recording()
 app.free();await frames()
 print("TUTORIAL RECORDING UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
