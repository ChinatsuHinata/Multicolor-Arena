extends SceneTree
const Model=preload("res://scripts/tutorial/authoring_model.gd")
const Runtime=preload("res://scripts/tutorial/runtime.gd")
const Store=preload("res://scripts/deck_store.gd")
const OUTPUT="res://work/tutorial-order"
var checks=0
var failures=[]

func _initialize():call_deferred("run")

func expect(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);push_error(label)

func run():
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 var model=Model.new();model.fresh()
 var added=model.add_step("step_1")
 expect(model.ordered_steps()==["step_1",added,"step_2"],"new node appears immediately after its anchor rather than at the end of the JSON")
 var original=model.data.duplicate(true);var history=model.undo_stack.size()
 expect(model.move_step(added,-1)!="" and model.move_step("missing",0)!="" and model.data==original and model.undo_stack.size()==history,"invalid moves are atomic")
 expect(model.move_step(added,1).is_empty() and model.data==original and model.undo_stack.size()==history,"same-position move does not create an edit")
 expect(model.reorder_steps(["step_1","step_1","step_2"])!="" and model.data==original,"duplicate order rejects without mutation")
 expect(model.move_step("step_2",0).is_empty() and model.ordered_steps()==["step_2","step_1",added],"moving the last node to the top changes the course start and success route")
 expect(model.data.start_step=="step_2" and model.data.steps[added].next=="$complete" and model.validate().ok,"reordered endpoints form a valid complete course")
 expect(model.undo() and model.data==original,"one undo restores the entire order edit")
 expect(model.redo() and model.data.start_step=="step_2","redo reapplies the entire order edit")
 # Moving any scene boundary in an existing course preserves each node's
 # configured scene, recorded actions, conditions and independent failure edge.
 for name in ["t1","t2","t3","t4"]:
  model=Model.new();model.load_course("res://data/tutorial/beginner/"+name+".json")
  original=model.data.duplicate(true)
  var order=model.ordered_steps();var scenes={}
  for id in order:scenes[id]=model.scene_for(id)
  for id in order:
   var probe=Model.new();probe.data=original.duplicate(true)
   var index=0 if id!=order[0] else order.size()-1
   var reason=probe.move_step(id,index)
   expect(reason.is_empty(),name+" moves "+id+": "+reason)
   expect(probe.validate().ok,name+" reordered document validates: "+id)
   for other in order:
    var before=original.steps[other].duplicate(true);var after=probe.data.steps[other].duplicate(true)
    for key in ["next","scenario","scenario_mode"]:before.erase(key);after.erase(key)
    expect(before==after and probe.scene_for(other)==scenes[other],name+" preserves content and scene: "+id+" / "+other)
  expect(model.move_step(order.back(),0).is_empty(),name+" reorder for round-trip")
  var target=OUTPUT.path_join(name+"-reordered.json")
  expect(model.save_course(target).is_empty(),name+" reordered course saves")
  var reopened=Model.new();expect(reopened.load_course(target).is_empty() and reopened.data==model.data and reopened.ordered_steps()==model.ordered_steps(),name+" order survives save and reopen")
 # Use all-info nodes to verify actual runtime traversal after reordering.
 model=Model.new();model.fresh();model.data.steps.step_2={"type":"info","guide":{"text":"第二步"},"next":"$complete"}
 added=model.add_step("step_1");model.move_step(added,0)
 var flow=Runtime.new();expect(flow.start(model.data,Store.CARDS).is_empty() and flow.current_step==added,"runtime starts at the top of the reordered list")
 expect(flow.next() and flow.current_step=="step_1" and flow.next() and flow.current_step=="step_2","runtime reads each reordered node once in list order")
 flow.free()
 print("TUTORIAL ORDER: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
