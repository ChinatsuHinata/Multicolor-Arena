extends "res://tests/support/ui_base.gd"
const OUTPUT="res://work/tutorial-authoring"
var editor

func frames(count: int=5):
 for i in range(count):await process_frame

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUTPUT.path_join(name+".png"))

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 Store.Paths.root_override=ProjectSettings.globalize_path(OUTPUT.path_join("fixtures-"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.size=Vector2i(1600,900)
 app=load("res://main.tscn").instantiate();app.settings_path=OUTPUT.path_join("missing-settings.json");app.account_session_path=OUTPUT.path_join("missing-account.json")
 root.add_child(app);await frames()
 app.tutorial_editor();await frames();editor=app.screen.get_child(0)
 expect(editor.toolbar.get_child_count()==6,"editor toolbar contains only document controls and recording")
 for caption in ["撤销","重做","流程图","课程","校验","试玩","高级配置（完整 JSON）"]:
  expect(find_button(editor,caption)==null,"removed editor control: "+caption)
 expect(editor.inspector.get_global_rect().end.x<=1600 and editor.inspector.get_global_rect().end.y<=900,"node inspector fits window")
 await click(find_button(editor,"新增节点").get_global_rect().get_center());await frames()
 var added=editor.selected_step
 expect(editor.model.data.steps.size()==3 and editor.model.data.steps.step_1.next==added,"adding a node inserts it in course flow")
 editor.search.text=added;editor.search.text_changed.emit(editor.search.text);await frames()
 expect(editor.nodes_list.get_child_count()==1,"node query filters by stable ID")
 editor.search.text="missing-node";editor.search.text_changed.emit(editor.search.text);await frames()
 expect(editor.nodes_list.get_child(0) is Label,"unmatched query shows empty state")
 editor.search.clear();editor.search.text_changed.emit(editor.search.text);await frames()
 await click(find_button(editor,"删除节点").get_global_rect().get_center());await frames()
 expect(not editor.model.data.steps.has(added) and editor.model.data.steps.step_1.next=="step_2","deleting a node repairs its incoming transition")
 await shot("simplified-nodes")
 for name in ["t1","t2","t3","t4"]:
  var path="res://data/tutorial/beginner/"+name+".json"
  var original=JSON.parse_string(FileAccess.get_file_as_string(path))
  app.tutorial_editor(path);await frames();editor=app.screen.get_child(0)
  expect(editor.model.data==original and not editor.model.dirty(),name+" node editor opens losslessly")
  var guide=editor.find_child("AuthoringGuideText",true,false)
  var expected=original.duplicate(true);expected.steps[editor.selected_step].guide.text+="\n节点编辑检查。"
  guide.text=expected.steps[editor.selected_step].guide.text;guide.text_changed.emit();await frames()
  expect(editor.model.data==expected,name+" node text edit preserves other fields")
  var save_path=OUTPUT.path_join(name+"-node-edited.json")
  expect(editor.model.save_course(save_path).is_empty() and JSON.parse_string(FileAccess.get_file_as_string(save_path))==expected,name+" edited course saves unchanged extra fields")
 app.tutorial_editor();await frames();editor=app.screen.get_child(0)
 editor.change_scene("in_game");await frames()
 expect(editor.model.validate().ok and editor.model.data.steps.step_2.scenario=="scene_1","switching node surface preserves downstream battle tasks")
 editor.change_step_type("task");await frames()
 var condition={"type":"deck_count","zone":"main","card_id":"96","op":"ge","value":1}
 editor.condition_dialog("指定卡牌成功条件",condition,func(value):editor.model.data.steps[editor.selected_step].task.success=value);await frames()
 var fields=editor.dialog_layer.find_children("*","VBoxContainer",true,false).filter(func(node):return node.get_script()==preload("res://scripts/tutorial/condition_form.gd"))[0]
 expect(fields.condition==condition and editor.dialog_layer.find_child("ConditionGraph",true,false)==null,"task predicates use compact form without graph tools")
 await shot("card-condition")
 await click(find_button(editor.dialog_layer,"应用条件").get_global_rect().get_center());await frames()
 expect(editor.model.data.steps[editor.selected_step].task.success==condition,"specified-card condition applies to node")
 app.tutorial_editor();await frames();editor=app.screen.get_child(0);editor.selected_step="step_2";editor.refresh();await frames()
 var original=editor.model.data.duplicate(true)
 editor.open_opponent_rules();await frames()
 var settings=editor.dialog_layer.find_children("*","VBoxContainer",true,false).filter(func(node):return node.get_script()==preload("res://scripts/tutorial/config_form.gd"))[0]
 settings.value={"strategy":"rules","rules":[{"id":"reply","event":"command_accepted","on_action":{"type":"pass_priority","player":0},"when":{"type":"priority","value":1},"action":"pass_priority","max_times":3}]};settings.rebuild()
 expect(editor.model.data==original,"trigger editing stays private until applied")
 await click(find_button(editor.dialog_layer,"应用设置").get_global_rect().get_center());await frames()
 expect(editor.model.data.scenarios.scene_1.opponent.rules[0].on_action.player==0 and editor.model.data.scenarios.scene_1.opponent.rules[0].max_times==3,"existing trigger event, action, condition and limit are editable")
 editor.open_opponent_rules();await frames()
 settings=editor.dialog_layer.find_children("*","VBoxContainer",true,false).filter(func(node):return node.get_script()==preload("res://scripts/tutorial/config_form.gd"))[0]
 expect(settings.value==editor.model.data.scenarios.scene_1.opponent,"saved trigger settings reopen losslessly")
 settings.value.rules[0].max_times=5
 await click(find_button(editor.dialog_layer,"应用设置").get_global_rect().get_center());await frames()
 expect(editor.model.data.scenarios.scene_1.opponent.rules[0].max_times==5 and editor.model.data.steps==original.steps,"changing trigger limit preserves tutorial nodes")
 app.free();await frames()
 print("TUTORIAL AUTHORING UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)

