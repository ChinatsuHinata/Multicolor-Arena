extends SceneTree
const Model=preload("res://scripts/tutorial/authoring_model.gd")
const Store=preload("res://scripts/deck_store.gd")
const Runtime=preload("res://scripts/tutorial/runtime.gd")
var checks=0
var failures=[]
const OUTPUT="res://work/tutorial-authoring"

func _initialize():call_deferred("run")

func expect(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);push_error(label)

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 # Current courses must survive a no-edit round trip without field loss,
 # including imported sequences, quiz data and explicit resume transitions.
 for name in ["t1","t2","t3","t4"]:
  var path="res://data/tutorial/beginner/"+name+".json"
  var original=JSON.parse_string(FileAccess.get_file_as_string(path))
  var model=Model.new();expect(model.load_course(path).is_empty(),name+" opens")
  expect(model.data==original and not model.dirty(),name+" opens without mutations")
  var copy=OUTPUT.path_join(name+".json")
  expect(model.save_course(copy).is_empty(),name+" saves")
  expect(JSON.parse_string(FileAccess.get_file_as_string(copy))==original,name+" round-trip preserves every field")
  var reopened=Model.new();expect(reopened.load_course(copy).is_empty() and reopened.data==original,name+" reopens")
 var existing=Model.new();existing.load_course("res://data/tutorial/beginner/t1.json")
 existing.remove_step("d2")
 expect(not "d2" in existing.data.completion.steps and existing.validate().ok,"removing a step updates completion prerequisites and incoming edges")
 var model=Model.new();model.fresh()
 expect(model.validate().ok,"new course validates")
 var original=model.data.duplicate(true)
 var added=model.add_card("scene_1",1,"field","53")
 expect(not added.has("error") and added.has("alias"),"real unit placement binds alias")
 var rejected=model.add_card("scene_1",1,"field","96")
 expect(rejected.has("error") and model.data.scenarios.scene_1.players[1].field.size()==1,"invalid placement preserves tableau")
 expect(model.undo() and model.data==original,"undo restores placement")
 expect(model.redo() and model.data.scenarios.scene_1.players[1].field.size()==1,"redo restores placement")
 model.data.scenarios.scene_1.players[1].deck_order=[{"card_id":"53","alias":"library_copy","state":{"tapped":true}}]
 var scene=model.new_scene("step_2","battlefield")
 expect(scene!="scene_1" and model.data.scenarios[scene]==model.data.scenarios.scene_1,"new battlefield clones current tableau")
 model.data.scenarios[scene].players[1].life=5
 expect(model.data.scenarios.scene_1.players[1].life==20,"cloned scenes are independent")
 model.data.steps.step_2.erase("scenario");model.data.steps.step_2.erase("scenario_mode")
 expect(model.scene_for("step_2")=="scene_1","inherit resolves previous scene")
 var deck_scene=model.new_scene("step_2","deck")
 model.data.steps.step_2={"type":"info","guide":{"text":"查看教学卡组。"},"scenario":deck_scene,"next":"$complete"}
 expect(model.validate().ok,"deck scene uses deck conditions")
 var ui_scene=model.new_scene("step_2","in_game")
 model.data.steps.step_2={"type":"task","guide":{"text":"添加一张卡牌。","next_button":"hidden"},"scenario":ui_scene,"task":{"timing":"action","action":{"id":"editor.add"},"success":{"type":"deck_count","zone":"main","op":"ge","value":1}},"next":"$complete"}
 expect(model.data.scenarios[ui_scene].screen=="deck_editor" and model.data.scenarios[ui_scene].deck==model.data.scenarios[deck_scene].deck,"in-game scene carries teaching deck")
 var flow=Runtime.new();expect(flow.start(model.data,Store.CARDS).is_empty(),"authored multi-scene course starts")
 expect(flow.next() and flow.adapter.scene_type=="in_game","runtime switches into authored native editor")
 flow.free()
 # A validation failure must never truncate an existing saved course.
 var copy=OUTPUT.path_join("atomic.json")
 expect(model.save_course(copy).is_empty(),"save valid authored document")
 var before=FileAccess.get_file_as_string(copy)
 model.data.steps.step_2.next="missing"
 expect(not model.save_course(copy).is_empty() and FileAccess.get_file_as_string(copy)==before,"failed validation leaves last save intact")
 print("TUTORIAL AUTHORING: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
