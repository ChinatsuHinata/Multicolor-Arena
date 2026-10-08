extends "res://tests/support/ui_base.gd"
const OUTPUT="res://work/tutorial-conditions"
var editor
var workspace
const Generated=preload("res://tests/support/tutorial_generated_units.gd")

func frames(count: int=6):
 for i in range(count):await process_frame

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUTPUT.path_join(name+".png"))

func fresh(mobile: bool=false):
 app.is_android=mobile;app.layout_dpi_override=240 if mobile else 0
 app.layout_safe_override=Rect2(32,12,1216,696) if mobile else Rect2()
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND if mobile else Window.CONTENT_SCALE_ASPECT_KEEP
 app.tutorial_editor();await frames();editor=app.screen.get_child(0);editor.selected_step="step_2"
 var scene=editor.model.data.scenarios.scene_1
 scene.players[0].field=[{"card_id":"53","alias":"a","state":{"entered":0,"entered_turns":0}}]
 scene.players[1].field=[{"card_id":"53","alias":"b","state":{"entered":0,"entered_turns":0}}]
 editor.refresh();await frames()

func press_named(name: String):
 var button=editor.find_child(name,true,false)
 expect(button!=null and button.is_visible_in_tree(),"visible condition control: "+name)
 if button:
  var parent=button.get_parent()
  while parent!=editor:
   if parent is ScrollContainer:parent.ensure_control_visible(button)
   parent=parent.get_parent()
  await frames();await click(button.get_global_rect().get_center());await frames()

func conditions(mobile: bool):
 await fresh(mobile);var original=editor.model.data.duplicate(true)
 await press_named("OpenConditionEditor");workspace=editor.condition_workspace
 expect(workspace!=null and workspace.graph_editor!=null,"task opens graphical condition editor on battlefield")
 if workspace==null:return
 expect(workspace.condition_arrows().size()==1 and workspace.reference_rect({"kind":"player","player":1}).has_area(),"life condition arrow points to the selected player's battlefield badge")
 expect(workspace.player_buttons[1].get_global_rect().grow(10).has_point(workspace.condition_arrows()[0].to+workspace.global_position),"arrow coordinates follow player badge inside safe inset")
 expect(workspace.dock.get_global_rect().end.y<=workspace.safe_rect().end.y+1 and workspace.dock.get_global_rect().end.x<=workspace.safe_rect().end.x,"condition dock fits safe window")
 expect(workspace.recorder.adapter.engine!=editor.recorder and editor.model.data==original,"preview uses an independent draft")
 await click(workspace.player_buttons[0].get_global_rect().get_center());await frames()
 expect(workspace.graph_editor.condition.player==0,"clicking player changes the selected condition graph")
 workspace.graph_editor.condition={"type":"all","conditions":[{"type":"entity_state","alias":"a","key":"attacked","value":true},{"type":"life","player":1,"op":"le","value":0}]};workspace.graph_editor.selected_condition={};workspace.graph_editor.rebuild();await frames()
 var first=workspace.graph_editor.condition.conditions[0]
 workspace.graph_editor.select_condition(first);await frames()
 expect(workspace.condition_arrows().size()==1,"selecting child shows only that child's subject arrow")
 var uid=int(workspace.recorder.adapter.entity("b").uid)
 var at=workspace.battle.target_rect(workspace.battle.engine.ref_target(workspace.battle.engine.find_card(uid))).get_center()
 if mobile:
  var touch=InputEventScreenTouch.new();touch.index=0;touch.pressed=true;touch.position=at;root.push_input(touch,true);await frames()
  touch=touch.duplicate();touch.pressed=false;root.push_input(touch,true);await frames()
 else:await click(at);await frames()
 expect(first.get("alias")=="b" and workspace.graph_editor.condition.conditions[1].player==1,"battlefield click rebinds selected card condition and preserves sibling")
 workspace.graph_editor.select_condition(workspace.graph_editor.condition.conditions[1]);await frames()
 await shot("android-condition-graph" if mobile else "condition-graph")
 await press_named("RecordCondition");expect(workspace.capturing and not workspace.dock.visible,"recording exposes native battle actions")
 view=workspace.battle;e=view.engine
 e.attack(0,int(workspace.recorder.adapter.entity("a").uid));e.pass_priority(1);e.pass_priority(0);e.block([]);e.pass_priority(0);e.pass_priority(1)
 await press_named("FinishConditionRecording")
 expect(workspace.recorder.actions.size()==6 and not workspace.capturing,"condition recorder captures real combat")
 expect(workspace.dock.get_global_rect().end.y<=workspace.safe_rect().end.y+1,"recorded choices remain within safe window")
 await shot("android-condition-recorded" if mobile else "condition-recorded")
 # Choice list may scroll; activate its concrete button after scrolling it into view.
 var use=workspace.find_child("UseConditionRecording",true,false);workspace.results.get_parent().ensure_control_visible(use);await frames()
 await click(use.get_global_rect().get_center());await frames()
 expect(workspace.graph_editor.condition.conditions[1].value==e.players[1].life and e.players[1].life<20,"recorded damage replaces only the selected life predicate")
 expect(editor.model.data==original,"recorded condition remains private until applied")
 await press_named("ApplyBattleCondition")
 expect(editor.condition_workspace==null and editor.model.data.steps.step_2.task.success.conditions[1].value<20,"applying graph updates current task condition")
 expect(editor.model.validate().ok,"updated battlefield condition and generated aliases validate together")
 var saved=editor.model.data.duplicate(true)
 await press_named("OpenConditionEditor");workspace=editor.condition_workspace;workspace.pick_player(0)
 await press_named("CancelBattleCondition")
 expect(editor.model.data==saved,"cancelled graph edit keeps saved course")

func triggers(mobile: bool=false):
 await fresh(mobile)
 var rule={"id":"reply","event":"command_accepted","on_action":{"type":"pass_priority","player":0},"when":{"type":"priority","value":1},"action":"pass_priority","max_times":3}
 editor.model.data.scenarios.scene_1.opponent={"strategy":"rules","rules":[rule]};var original=editor.model.data.duplicate(true)
 editor.open_opponent_rules();await frames();await press_named("OpenTriggerConditionGraph");workspace=editor.condition_workspace
 expect(workspace.rule.id=="reply" and workspace.rule.max_times==3,"existing trigger opens graph with original identity and limit")
 workspace.find_child("TriggerExecutionLimit",true,false).value=5
 await press_named("RecordCondition");view=workspace.battle
 var end=find_button(view.ui,"结束主要阶段")
 expect(end!=null,"native recording offers main-phase action")
 if end:await click(end.get_global_rect().get_center());await frames()
 expect(workspace.recorder.actions.size()==1 and workspace.recorder.actions[0].player==0,"native action button records selected trigger")
 workspace.battle.engine.pass_priority(1)
 await press_named("FinishConditionRecording")
 var use=workspace.find_child("UseConditionRecording",true,false);workspace.results.get_parent().ensure_control_visible(use);await frames();await click(use.get_global_rect().get_center());await frames()
 expect(workspace.rule.has("sequence") and workspace.rule.sequence.actions[0].player==1,"recording replaces trigger action and opponent response")
 expect(workspace.dock.get_global_rect().end.y<=workspace.safe_rect().end.y+1,"trigger recording dock fits safe window")
 await shot("android-trigger-recorded" if mobile else "trigger-recorded")
 await press_named("ApplyBattleCondition")
 expect(editor.condition_workspace==null and editor.model.data==original,"child graph application preserves outer draft isolation")
 await press_named("ApplyTutorialSettings")
 var applied=editor.model.data.scenarios.scene_1.opponent.rules[0]
 expect(applied.id=="reply" and applied.max_times==5 and applied.has("sequence") and editor.model.validate().ok,"outer settings apply complete recorded trigger")
 var saved=editor.model.data.duplicate(true)
 editor.open_opponent_rules();await frames();await press_named("OpenTriggerConditionGraph");workspace=editor.condition_workspace
 workspace.pick_player(0);await press_named("CancelBattleCondition");editor.close_dialog();await frames()
 expect(editor.model.data==saved,"cancelled trigger graph leaves original settings intact")
 editor.open_opponent_rules();await frames();await click(find_button(editor.dialog_layer,"新增触发器").get_global_rect().get_center());await frames()
 await press_named("CancelBattleCondition");await press_named("ApplyTutorialSettings")
 expect(editor.model.data==saved,"cancelled new trigger is not added to the outer draft")

func block_presets():
 await fresh();var original=editor.model.data.duplicate(true)
 editor.open_opponent_rules();await frames();await press_named("OpenTriggerConditionGraph");workspace=editor.condition_workspace
 await press_named("QuickAttackBlock")
 expect(workspace.has_block_presets() and workspace.rule.action.priorities.size()==5 and workspace.graph_editor.condition.alias=="a","quick setting builds five choices for our battlefield attacker")
 expect(workspace.rule.event=="state_changed" and not workspace.rule.has("on_action") and not workspace.rule.has("sequence"),"quick trigger waits for real blocking time")
 expect(workspace.find_child("BlockMoveUp_largest",true,false).disabled,"highest priority cannot move further up")
 await press_named("BlockPriority_largest");await press_named("BlockPriority_selected");await press_named("BlockPriority_all")
 for i in range(4):await press_named("BlockMoveUp_selected")
 expect(workspace.rule.action.priorities[0].strategy=="selected" and workspace.rule.action.priorities[0].enabled,"creator can enable and promote selected blockers")
 await press_named("PickPresetBlockers")
 workspace.pick_card(int(workspace.recorder.adapter.entity("b").uid));await frames()
 expect(workspace.rule.action.priorities[0].cards==[{"alias":"b"}] and workspace.graph_editor.condition.alias=="a","battlefield pick sets blocking target and preserves attacker")
 await press_named("PickPresetBlockers")
 expect(workspace.dock.get_global_rect().end.y<=workspace.safe_rect().end.y+1,"five-option settings fit condition editor height")
 await press_named("TriggerConditionTab")
 workspace.block_scroll.scroll_vertical=0;await frames()
 expect(workspace.graph_editor.selected_node.get_global_rect().intersection(workspace.graph_editor.get_global_rect()).size.y>=80,"preset condition node remains visible below quick settings")
 await shot("trigger-block-priorities")
 await press_named("ApplyBattleCondition")
 expect(editor.model.data==original,"priority changes remain in outer draft until applied")
 await press_named("ApplyTutorialSettings")
 var saved=editor.model.data.duplicate(true);var applied=saved.scenarios.scene_1.opponent.rules[0]
 expect(applied.action.priorities[0].strategy=="selected" and applied.action.priorities[0].cards==[{"alias":"b"}] and editor.model.validate().ok,"priority order and creator targets apply to valid course")
 var path=OUTPUT.path_join("block-priorities-course.json")
 expect(editor.model.save_course(path).is_empty(),"priority course saves")
 var loaded=preload("res://scripts/tutorial/authoring_model.gd").new()
 expect(loaded.load_course(path).is_empty() and loaded.data.scenarios.scene_1.opponent.rules[0]==JSON.parse_string(JSON.stringify(applied)),"saved priority trigger reopens unchanged")
 editor.open_opponent_rules();await frames();await press_named("OpenTriggerConditionGraph");workspace=editor.condition_workspace
 await press_named("TriggerResponseTab")
 expect(workspace.has_block_presets() and workspace.rule.action.priorities[0].strategy=="selected" and workspace.find_child("PresetBlockTarget_b",true,false).button_pressed,"reopened graph restores priority and selected target controls")
 await press_named("BlockMoveDown_selected");await press_named("CancelBattleCondition");editor.close_dialog();await frames()
 expect(editor.model.data==saved,"cancelling priority changes preserves saved course")

func rank_presets():
 await fresh();var original=editor.model.data.duplicate(true)
 editor.open_opponent_rules();await frames();await press_named("OpenTriggerConditionGraph");workspace=editor.condition_workspace
 await press_named("QuickAttackBlock")
 var mode=workspace.find_child("BlockAttackMode",true,false);mode.select(1);mode.item_selected.emit(1);await frames()
 expect(workspace.graph_editor.condition=={"type":"combat_attacker_rank","player":0,"key":"spirit","count":1,"ties":"all"} and workspace.rule.get("otherwise")=="no_block","highest-spirit shortcut uses a live predicate with automatic decline")
 expect(workspace.rule.max_times>1 and workspace.find_child("TriggerExecutionLimit",true,false).value==workspace.rule.max_times,"rank shortcut can respond to multiple attackers instead of stopping after the first block")
 expect(workspace.find_child("BlockUnmatchedPass",true,false).button_pressed and workspace.find_child("BlockAttackSubject",true,false)==null,"rank shortcut exposes auto-decline instead of a fixed card binding")
 mode=workspace.find_child("BlockAttackMode",true,false);mode.select(2);mode.item_selected.emit(2);await frames()
 var ranked={"type":"combat_attacker_rank","player":0,"key":"spirit","count_player":1,"ties":"field_order"}
 expect(workspace.graph_editor.condition==ranked,"top-x shortcut stores opposing unit count rather than current preview count")
 await press_named("TriggerConditionTab")
 expect(workspace.condition_arrows().size()==2,"rank condition links both attacking player and count source battlefield")
 workspace.pick_card(int(workspace.recorder.adapter.entity("a").uid));await frames()
 expect(workspace.graph_editor.condition==ranked,"battlefield pick retains dynamic rank selection")
 var source=workspace.graph_editor.find_child("AttackRankCountSource",true,false);source.select(0);source.item_selected.emit(0);await frames()
 workspace.graph_editor.find_child("AttackRankCount",true,false).value=2
 var ties=workspace.graph_editor.find_child("AttackRankTies",true,false);ties.select(1);ties.item_selected.emit(1);await frames()
 expect(workspace.graph_editor.condition.get("count")==2 and not workspace.graph_editor.condition.has("count_player"),"graph changes dynamic range to fixed top two without conflicting fields")
 await press_named("TriggerResponseTab")
 expect(workspace.find_child("BlockAttackMode",true,false).selected==3,"response controls follow a custom rank changed in the condition graph")
 mode=workspace.find_child("BlockAttackMode",true,false);mode.select(2);mode.item_selected.emit(2);await frames()
 expect(workspace.safe_rect().encloses(workspace.find_child("ApplyBattleCondition",true,false).get_global_rect()),"rank presets keep apply button within viewport")
 await shot("trigger-spirit-rank")
 await press_named("ApplyBattleCondition");expect(editor.model.data==original,"rank edit remains private before outer application")
 await press_named("ApplyTutorialSettings")
 var saved=editor.model.data.duplicate(true);var applied=saved.scenarios.scene_1.opponent.rules[0]
 expect(applied.when==ranked and applied.otherwise=="no_block" and editor.model.validate().ok,"rank and automatic decline apply as a valid course")
 var path=OUTPUT.path_join("attack-rank-course.json")
 expect(editor.model.save_course(path).is_empty(),"rank course saves")
 var loaded=preload("res://scripts/tutorial/authoring_model.gd").new()
 expect(loaded.load_course(path).is_empty() and loaded.data.scenarios.scene_1.opponent.rules[0]==JSON.parse_string(JSON.stringify(applied)),"saved rank rule reopens with dynamic count and tie handling")
 editor.open_opponent_rules();await frames();await press_named("OpenTriggerConditionGraph");workspace=editor.condition_workspace
 await press_named("TriggerResponseTab")
 expect(workspace.find_child("BlockAttackMode",true,false).selected==2 and workspace.find_child("BlockUnmatchedPass",true,false).button_pressed,"reopened rank shortcut restores selected mode and decline checkbox")
 mode=workspace.find_child("BlockAttackMode",true,false);mode.select(0);mode.item_selected.emit(0);await frames()
 expect(workspace.graph_editor.condition.type=="combat_attacker" and not workspace.rule.has("otherwise"),"switching back to specific attacker removes rank fallback")
 await press_named("CancelBattleCondition");editor.close_dialog();await frames()
 expect(editor.model.data==saved,"cancelled rank changes preserve applied course")
 await fresh();editor.model.data.scenarios.scene_1.players[0].field=[]
 editor.open_opponent_rules();await frames();await press_named("OpenTriggerConditionGraph");workspace=editor.condition_workspace
 await press_named("QuickAttackBlock")
 expect(workspace.graph_editor.condition.type=="combat_attacker_rank" and workspace.has_block_presets(),"empty initial field can still configure a shortcut for future units")
 await press_named("CancelBattleCondition");editor.close_dialog();await frames()

func trigger_controls():
 await fresh();editor.model.data.scenarios.scene_1.players[1].hand=[{"card_id":"96","alias":"reply_card"}]
 var original=editor.model.data.duplicate(true)
 editor.open_opponent_rules();await frames();await press_named("OpenTriggerConditionGraph");workspace=editor.condition_workspace
 await press_named("TriggerTimingTab")
 workspace.find_child("TriggerName",true,false).text="攻击后响应";await frames()
 var event=workspace.find_child("TriggerEvent",true,false)
 event.select(1);event.item_selected.emit(1);await frames()
 expect(workspace.rule.event=="phase_changed" and not workspace.rule.has("on_action"),"event selector removes command filter for phase events")
 event.select(3);event.item_selected.emit(3);await frames()
 expect(workspace.rule.on_action.type=="pass_priority" and workspace.rule.on_action.player==0,"returning to operation events restores the previous filter")
 var filter=workspace.find_child("TriggerActionFilter",true,false)
 filter.item_selected.emit(2);await frames()
 var source=workspace.find_child("TriggerActionCard",true,false)
 for i in range(source.item_count):
  if source.get_item_text(i)==workspace.subject_caption({"alias":"a"}):source.select(i);source.item_selected.emit(i);break
 expect(workspace.rule.on_action.type=="attack" and workspace.rule.on_action.card.alias=="a","operation filter selects a concrete battlefield card without field editing")
 await press_named("TriggerResponseTab")
 workspace.find_child("TriggerResponseType",true,false).item_selected.emit(1);await frames()
 await press_named("TriggerBlockTarget_b")
 expect(workspace.rule.action.type=="block" and workspace.rule.action.cards==[{"alias":"b"}],"response selector directly configures explicit blocking units")
 workspace.find_child("TriggerResponseType",true,false).item_selected.emit(3);await frames()
 expect(workspace.rule.action.type=="cast" and workspace.rule.action.card.alias=="reply_card" and not workspace.rule.has("sequence"),"card response starts with an opponent hand card and replaces previous response")
 var target=workspace.find_child("TriggerResponseTarget",true,false);target.select(1);target.item_selected.emit(1);await frames()
 expect(workspace.rule.action.target=={"player":0},"response target selector uses portable player references")
 await shot("trigger-response-settings")
 await press_named("ApplyBattleCondition");expect(editor.model.data==original,"direct response edits remain private in the outer trigger list")
 await press_named("ApplyTutorialSettings")
 var saved=editor.model.data.duplicate(true)
 expect(saved.scenarios.scene_1.opponent.rules[0].action=={"type":"cast","card":{"alias":"reply_card"},"target":{"player":0}} and editor.model.validate().ok,"direct response fields apply together as a valid scene rule")
 editor.open_opponent_rules();await frames();await shot("trigger-rule-list");await press_named("OpenTriggerConditionGraph");workspace=editor.condition_workspace
 await press_named("TriggerResponseTab")
 expect(workspace.rule==saved.scenarios.scene_1.opponent.rules[0],"reopened trigger preserves source, filter, target and response")
 workspace.find_child("TriggerResponseType",true,false).item_selected.emit(4);await frames()
 workspace.find_child("TriggerAbilitySelector",true,false).item_selected.emit(1);await frames()
 expect(workspace.rule.action.type=="ability" and workspace.rule.action.has("key") and not workspace.rule.action.has("index"),"ability selector switches cleanly between index and key")
 workspace.find_child("TriggerResponseType",true,false).item_selected.emit(2);await frames()
 expect(workspace.has_block_presets() and workspace.rule.event=="state_changed" and not workspace.rule.has("on_action") and workspace.graph_editor.condition.type=="combat_attacker","automatic-block response configures the attack condition and real blocking event together")
 await press_named("CancelBattleCondition");editor.close_dialog();await frames()
 expect(editor.model.data==saved,"cancelling direct response changes preserves the entire course")

func recording_context():
 await fresh();editor.open_recording();await frames();editor.begin_recording();await frames()
 editor.record_view.engine.attack(0,int(editor.recorder.adapter.entity("a").uid));editor.recorder.finish();await frames()
 var actions=editor.recorder.actions.duplicate(true);var position=editor.recorder.cursor;var snapshot=editor.recorder.adapter.capture();var document=editor.model.data.duplicate(true)
 editor.condition_dialog("已有录制的条件",{"type":"priority","value":1},func(_value):pass);await frames();workspace=editor.condition_workspace
 expect(workspace.recorder.adapter.engine.priority==1 and workspace.recorder.adapter.entity("a").attacked,"condition editor starts at the current recorded battlefield boundary")
 await press_named("RecordCondition");workspace.battle.engine.pass_priority(1);await press_named("FinishConditionRecording");await press_named("CancelBattleCondition")
 expect(editor.recorder.actions==actions and editor.recorder.cursor==position and editor.recorder.adapter.capture()==snapshot and editor.model.data==document,"condition rerecording preserves outer history and document")
 expect(editor.record_view.visible and editor.record_tools.visible,"closing condition draft restores historical recording controls")
 editor.close_recording();await frames()

func condition_layout():
 for dimensions in [Vector2i(1600,900),Vector2i(1280,720),Vector2i(1280,600)]:
  root.content_scale_size=dimensions;root.size=dimensions;await frames()
  await fresh()
  editor.open_opponent_rules();await frames();await press_named("OpenTriggerConditionGraph");workspace=editor.condition_workspace
  var observe=workspace.battle.observe_button
  expect(not observe.is_visible_in_tree(),"condition editor omits redundant observation button at %s" % dimensions)
  workspace.battle.render();await frames()
  expect(not observe.is_visible_in_tree(),"condition redraw keeps observation button hidden at %s" % dimensions)
  await shot("condition-editor-%dx%d" % [dimensions.x,dimensions.y])
  await press_named("QuickAttackBlock")
  await press_named("TriggerConditionTab")
  for name in ["ApplyBattleCondition","CancelBattleCondition"]:
   var button=workspace.find_child(name,true,false)
   expect(workspace.safe_rect().encloses(button.get_global_rect()),"condition footer fits viewport %s: %s" % [dimensions,name])
   var graph_rect=workspace.graph_editor.get_global_rect().intersection(workspace.dock_scroll.get_global_rect())
   expect(not graph_rect.intersects(button.get_global_rect()),"visible condition graph clears footer %s: %s" % [dimensions,name])
  await press_named("TriggerResponseTab");await press_named("PickPresetBlockers")
  expect(workspace.picking_blockers,"blocker picker remains clickable at %s" % dimensions)
  await shot("condition-layout-%dx%d" % [dimensions.x,dimensions.y])
  var mode=workspace.find_child("BlockAttackMode",true,false);mode.select(2);mode.item_selected.emit(2);await frames()
  expect(workspace.safe_rect().encloses(workspace.find_child("BlockAttackMode",true,false).get_global_rect()) and workspace.safe_rect().encloses(workspace.find_child("ApplyBattleCondition",true,false).get_global_rect()),"spirit rank controls and apply button fit viewport %s" % dimensions)
  await shot("rank-layout-%dx%d" % [dimensions.x,dimensions.y])
  await press_named("RecordCondition")
  expect(not observe.is_visible_in_tree() and workspace.capturing,"condition recording omits redundant observation button at %s" % dimensions)
  await press_named("DiscardConditionRecording")
  await press_named("CancelBattleCondition")
  expect(editor.condition_workspace==null,"condition cancel remains clickable at %s" % dimensions)
  editor.close_dialog();await frames()
 root.content_scale_size=Vector2i(1600,900);root.size=Vector2i(1600,900);await frames()

func generated_subjects():
 await fresh();editor.model.data.scenarios.scene_1=Generated.scene();editor.refresh();await frames()
 var original=editor.model.data.duplicate(true)
 await press_named("OpenConditionEditor");workspace=editor.condition_workspace
 await press_named("RecordCondition");expect(Generated.cast(workspace.recorder.adapter).is_empty(),"condition recording generates real token instances")
 await press_named("FinishConditionRecording")
 var subjects=workspace.recorder.adapter.card_subjects().filter(func(item):return item.ref.has("created"))
 expect(subjects.size()==2 and workspace.graph_editor.created_names.size()==2,"finished recording lists both new instances in graph and subject strip")
 if subjects.size()!=2:return
 var ref=subjects[0].ref;var uid=int(subjects[0].card.uid)
 workspace.graph_editor.condition={"type":"entity_state","alias":"maker","key":"tapped","value":false};workspace.graph_editor.selected_condition={};workspace.graph_editor.rebuild();await frames()
 var button=workspace.card_buttons[uid];workspace.cards_scroll.ensure_control_visible(button);await frames();await click(button.get_global_rect().get_center());await frames()
 expect(workspace.current_condition().get("created")==ref.created and not workspace.current_condition().has("alias"),"clicking generated subject replaces alias with portable reference")
 expect(workspace.condition_arrows().size()==1 and workspace.recorder.adapter.evaluate(workspace.current_condition(),[]),"generated subject has a resolved arrow and matching real state")
 var kind=workspace.graph_editor.selected_node.find_child("ConditionType",true,false)
 kind.item_selected.emit(workspace.graph_editor.TYPES.keys().find("entity_zone"));await frames()
 expect(workspace.current_condition().type=="entity_zone" and workspace.current_condition().get("created")==ref.created,"changing predicate type retains generated subject")
 workspace.current_condition().zone="field";workspace.graph_editor.changed(workspace.current_condition());workspace.graph_editor.rebuild();await frames()
 await shot("generated-condition-selected")
 expect(editor.model.data==original,"generated condition recording stays private until application")
 await press_named("ApplyBattleCondition")
 var saved=editor.model.data.steps.step_2.task.success.duplicate(true)
 expect(saved.get("created")==ref.created and not saved.has("alias") and editor.model.validate().ok,"applying generated condition validates the whole course")
 var path=OUTPUT.path_join("generated-course.json")
 expect(editor.model.save_course(path).is_empty(),"generated condition course saves")
 var loaded=preload("res://scripts/tutorial/authoring_model.gd").new()
 var reason=loaded.load_course(path)
 expect(reason.is_empty(),"saved course reopens: "+reason)
 if not reason.is_empty():return
 var reopened=loaded.data.steps.step_2.task.success
 expect(int(reopened.get("created",-1))==int(saved.created) and reopened.type==saved.type and reopened.zone==saved.zone and not reopened.has("alias"),"saved course reopens with the generated instance reference")
 editor.model=loaded;saved=reopened.duplicate(true);editor.refresh();await frames()
 await press_named("OpenConditionEditor");workspace=editor.condition_workspace
 expect(workspace.current_condition()==saved and not workspace.recorder.adapter.evaluate(saved,[]),"reopening preserves future reference before its instance is generated")
 await press_named("RecordCondition");expect(Generated.cast(workspace.recorder.adapter).is_empty(),"reopened course can regenerate selected subject")
 await press_named("FinishConditionRecording")
 expect(workspace.recorder.adapter.evaluate(saved,[]) and workspace.graph_editor.created_names.has(int(ref.created)),"regenerated instance matches saved reference")
 workspace.discard_capture();await frames()
 expect(workspace.graph_editor.created_names.is_empty() and not workspace.recorder.adapter.evaluate(saved,[]),"discard removes temporary subjects and preserves saved reference")
 await press_named("CancelBattleCondition")
 editor.open_recording();await frames();editor.begin_recording();await frames()
 expect(Generated.cast(editor.recorder.adapter).is_empty(),"outer recording generates its own subjects");editor.recorder.finish();await frames()
 var snapshot=editor.recorder.adapter.capture();var actions=editor.recorder.actions.duplicate(true)
 editor.condition_dialog("已有生成实例",saved,func(_value):pass);await frames();workspace=editor.condition_workspace
 expect(workspace.recorder.adapter.evaluate(saved,[]) and workspace.graph_editor.created_names.has(int(ref.created)),"opening from an existing recording retains scene creation origin")
 await press_named("CancelBattleCondition")
 expect(editor.recorder.adapter.capture()==snapshot and editor.recorder.actions==actions,"editing existing generated subjects keeps outer recording intact")
 editor.close_recording();await frames()

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 Store.Paths.root_override=ProjectSettings.globalize_path(OUTPUT.path_join("fixtures-"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.size=Vector2i(1600,900)
 app=load("res://main.tscn").instantiate();app.settings_path=OUTPUT.path_join("missing-settings.json");app.account_session_path=OUTPUT.path_join("missing-account.json")
 root.add_child(app);await frames()
 if "--layout-only" in OS.get_cmdline_user_args():await condition_layout()
 elif "--block-presets-only" in OS.get_cmdline_user_args():await block_presets()
 elif "--attack-rank-only" in OS.get_cmdline_user_args():await rank_presets()
 else:await conditions(false);await triggers();await trigger_controls();await block_presets();await rank_presets();await recording_context();await generated_subjects();await condition_layout()
 app.free();await frames()
 print("TUTORIAL CONDITION EDITOR UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
