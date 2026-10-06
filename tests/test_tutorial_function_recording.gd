extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Model=preload("res://scripts/tutorial/authoring_model.gd")
const Recorder=preload("res://scripts/tutorial/function_recorder.gd")
const Runtime=preload("res://scripts/tutorial/runtime.gd")
const Config=preload("res://scripts/tutorial/config.gd")
var checks=0
var failures=[]

func expect(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);push_error(label)

func course(r) -> Dictionary:
 var steps={}
 for i in range(r.nodes.size()):
  var node=r.nodes[i].duplicate(true);node.next="step_"+str(i+1) if i+1<r.nodes.size() else "$complete"
  steps["step_"+str(i)]=node
 return {"schema_version":1,"id":"recorded_function","title":"组卡功能指导","initial_scenario":"scene","start_step":"step_0","completion":{"type":"always"},"scenarios":{"scene":r.scene.duplicate(true)},"steps":steps}

func _initialize():
 var scene={"type":"in_game","screen":"deck_editor","deck":Model.deck()};var before=scene.duplicate(true)
 var r=Recorder.new()
 expect(r.configure(scene,Store.CARDS).is_empty(),"function recorder loads isolated deck")
 r.adapter.ui_deck.main.append("35")
 expect(r.begin_record().is_empty(),"setup deck is captured as recording baseline")
 r.adapter.ui_deck.main.append("96");r.accepted("editor.add",{"card_id":"96","zone":"main","source_zone":"library","source_index":8})
 r.accepted("editor.search",{"value":"夜王"})
 expect(r.nodes.size()==2 and r.nodes[0].task.success.card_id=="96","each accepted function has its own prescribed-card condition")
 expect(r.nodes[0].task.action.args=={"card_id":"96","zone":"main"},"card addition guidance accepts equivalent native input paths")
 expect(scene==before,"recording does not change source scenario")
 r.accepted("editor.search",{"value":"夜王 新"})
 expect(r.nodes.size()==2 and r.nodes[1].task.action.args.value=="夜王 新","search typing coalesces to its final instruction")
 expect(r.undo() and r.nodes.size()==1 and r.adapter.ui_deck.main==["53","35","96"],"undo restores draft and recorded node cursor")
 r.accepted("editor.inspect",{"card_id":"96"});r.finish()
 expect(r.verify().is_empty(),"functional nodes validate")
 var data=course(r);expect(Config.new().validate(JSON.parse_string(JSON.stringify(data)),Store.CARDS).ok,"functional JSON round trips")
 var flow=Runtime.new();expect(flow.start(data,Store.CARDS).is_empty(),"recorded tutorial starts")
 flow.adapter.ui_deck.main.append("35");flow.ui_action_applied("editor.add",{"card_id":"35","zone":"main"});flow.tick()
 expect(flow.current_step=="step_0","another card cannot complete prescribed-card task")
 flow.adapter.ui_deck.side.append("96");flow.ui_action_applied("editor.add",{"card_id":"96","zone":"side"});flow.tick()
 expect(flow.current_step=="step_0","same card in another zone cannot complete task")
 flow.adapter.ui_deck.main.append("96");flow.ui_action_applied("editor.add",{"card_id":"96","zone":"main"});flow.tick()
 expect(flow.current_step=="step_1" and not flow.finished,"accepted addition completes exactly one step")
 flow.ui_action_applied("editor.inspect",{"card_id":"35"});flow.tick()
 expect(not flow.finished,"inspect task requires specified card")
 flow.ui_action_applied("editor.inspect",{"card_id":"96"});flow.tick()
 expect(flow.finished,"specified card inspection completes next task")
 flow.free()
 data=course(r);data.steps.step_0.task.failure={"type":"ui_action","action":{"id":"editor.add","args":{"card_id":"35"}}};data.steps.step_0.failure="step_0";data.steps.step_0.restore_on_failure=true
 flow=Runtime.new();flow.start(data,Store.CARDS)
 var notices=[];flow.task_failed.connect(func(detail):notices.append(detail))
 flow.adapter.ui_deck.main.append("35");flow.ui_action_applied("editor.add",{"card_id":"35","zone":"main"});flow.tick()
 expect(notices.size()==1 and flow.adapter.ui_deck.main==["53","35"],"failure on a different allowed action restores task baseline")
 data.steps.step_0.task.failure={"type":"deck_count","zone":"main","card_id":"96","op":"ge","value":1}
 flow.start(data,Store.CARDS);flow.adapter.ui_deck.main.append("96");flow.ui_action_applied("editor.add",{"card_id":"96","zone":"main"});flow.tick()
 expect(flow.current_step=="step_0" and flow.completed_steps.is_empty(),"failure has priority over simultaneous success")
 flow.free()
 r.reset_setup();expect(r.nodes.is_empty() and r.adapter.ui_deck.main==["53","35"],"reset restores recording setup")
 r=Recorder.new();scene={"type":"deck","deck":Model.deck()};r.configure(scene,Store.CARDS);r.begin_record();r.accepted("editor.inspect",{"card_id":"53"});r.finish()
 data=course(r);expect(Config.new().validate(data,Store.CARDS).ok,"read-only deck guidance permits inspection tasks")
 flow=Runtime.new();flow.start(data,Store.CARDS);flow.ui_action_applied("editor.inspect",{"card_id":"53"});flow.tick()
 expect(flow.finished and flow.adapter.ui_deck.main==["53"],"deck guide completes from inspection without changing cards")
 flow.free()
 data.steps.step_0.task.action.id="editor.add";expect(not Config.new().validate(data,Store.CARDS).ok,"read-only deck rejects mutation tasks")
 data.scenarios.scene.type="battlefield";data.scenarios.scene=Model.battle()
 expect(not Config.new().validate(data,Store.CARDS).ok,"UI predicates cannot silently run in battlefield")
 print("TUTORIAL FUNCTION RECORDING: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
