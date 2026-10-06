extends SceneTree
const Model=preload("res://scripts/tutorial/authoring_model.gd")
const Store=preload("res://scripts/deck_store.gd")
const Runtime=preload("res://scripts/tutorial/runtime.gd")
const OUTPUT="res://work/tutorial-node-rename"
var checks=0
var failures=[]

func expect(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);push_error(label)

func _initialize():call_deferred("run")

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 var model=Model.new();model.fresh()
 model.data.steps.step_1.guide.text="step_2 是说明文字，不是引用。"
 model.data.steps.step_2.task.failure={"type":"not","condition":{"type":"steps_completed","steps":["step_1"]}}
 model.data.steps.step_2.failure="step_2"
 model.data.completion={"type":"all","conditions":[{"type":"steps_completed","steps":["step_1","step_2"]}]}
 model.data.scenarios.scene_1.opponent={"strategy":"rules","rules":[{"id":"step_2","event":"state_changed","when":{"type":"steps_completed","steps":["step_1"]},"action":"pass_priority","max_times":1}]}
 expect(model.validate().ok,"reference-rich rename fixture validates")
 var original=model.data.duplicate(true);model.saved_text=JSON.stringify(original)
 var history=model.undo_stack.size()
 for invalid in ["", "  ", "step_1", "$complete", "bad/name", "bad\\name", "bad.name", "bad:name", "bad@name", "bad%name", "bad\"name", "bad\nname"]:
  expect(not model.rename_step("step_2",invalid).is_empty() and model.data==original and model.undo_stack.size()==history,"invalid name leaves course and history intact: "+invalid)
 expect(not model.rename_step("missing","new").is_empty() and model.data==original,"missing node is rejected")
 expect(model.rename_step("step_2"," step_2 ").is_empty() and not model.dirty() and model.undo_stack.size()==history,"unchanged name produces no edit")
 expect(model.rename_step("step_2"," 战斗练习 ").is_empty(),"Chinese node name trims outer spaces")
 expect(model.ordered_steps()==["step_1","战斗练习"] and model.data.steps.keys()==["step_1","战斗练习"],"renaming retains course and dictionary order")
 expect(model.data.steps.step_1.next=="战斗练习" and model.data.steps["战斗练习"].failure=="战斗练习" and model.data.steps["战斗练习"].next=="$complete","success and self-failure transitions use new name")
 expect(model.data.completion.conditions[0].steps==["step_1","战斗练习"],"nested completion reference uses new name")
 expect(model.data.steps.step_1.guide.text==original.steps.step_1.guide.text and model.data.scenarios.scene_1.opponent.rules[0].id=="step_2","rename preserves guide text and unrelated rule IDs")
 expect(model.rename_step("step_1","课程 开始").is_empty() and model.data.start_step=="课程 开始","renaming start updates entry point and permits internal spaces")
 expect(model.data.steps["战斗练习"].task.failure.condition.steps==["课程 开始"] and model.data.scenarios.scene_1.opponent.rules[0].when.steps==["课程 开始"],"task and opponent conditions update nested step references")
 expect(model.validate().ok and model.dirty() and model.undo_stack.size()==history+2,"valid renames produce one checkpoint each")
 var renamed=model.data.duplicate(true)
 expect(model.undo() and model.data.start_step=="step_1" and model.undo() and model.data==original,"undo restores both names and references")
 expect(model.redo() and model.redo() and model.data==renamed,"redo restores renamed course")
 var path=OUTPUT.path_join("renamed.json")
 expect(model.save_course(path).is_empty(),"renamed course saves")
 var reopened=Model.new()
 expect(reopened.load_course(path).is_empty() and reopened.data==JSON.parse_string(JSON.stringify(renamed)) and not reopened.dirty(),"saved renamed course reopens exactly")
 var runtime=Runtime.new()
 expect(runtime.start(reopened.data,Store.CARDS).is_empty() and runtime.next(),"runtime enters and advances through renamed nodes")
 runtime.free()
 for course in ["t1","t2","t3","t4"]:
  model=Model.new();model.load_course("res://data/tutorial/beginner/"+course+".json")
  for id in model.data.steps.keys():
   if not model.data.steps[id].has("sequence") and not model.data.steps[id].get("task",{}).has("sequence"):continue
   var scene=model.scene_for(id);var before=model.data.steps[id].duplicate(true)
   expect(model.rename_step(id,"录制 "+id).is_empty() and model.scene_for("录制 "+id)==scene,"recorded node retains scene after rename: "+course+"/"+id)
   var node=model.data.steps["录制 "+id]
   expect(node.get("sequence",{})==before.get("sequence",{}) and node.get("task",{}).get("sequence",{})==before.get("task",{}).get("sequence",{}) and node.guide==before.guide,"recorded actions and guides remain unchanged: "+course+"/"+id)
 print("TUTORIAL NODE RENAME: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
