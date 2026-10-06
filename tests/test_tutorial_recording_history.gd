extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Model=preload("res://scripts/tutorial/authoring_model.gd")
const Recorder=preload("res://scripts/tutorial/battle_recorder.gd")
const Sequence=preload("res://scripts/tutorial/sequence.gd")
var failures=[]
var checks=0

func expect(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);push_error(label)

func battle_history():
 var scene=Model.battle();scene.players[0].field=[{"card_id":"53","alias":"attacker"}]
 scene.players[1].field=[{"card_id":"53","alias":"blocker"}]
 var r=Recorder.new();expect(r.configure(scene,Store.CARDS).is_empty() and r.begin_record().is_empty(),"history starts in an isolated battle")
 r.adapter.engine.attack(0,r.adapter.entity("attacker").uid)
 r.adapter.engine.pass_priority(1);r.adapter.engine.pass_priority(0);r.adapter.engine.block([])
 r.adapter.engine.pass_priority(0);r.adapter.engine.pass_priority(1)
 r.finish();var config=r.sequence_config();var before=config.duplicate(true);var final=r.final_facts.duplicate(true)
 var reopened=Recorder.new();reopened.configure(r.scene,Store.CARDS)
 expect(reopened.load_sequence(config).is_empty(),"saved recording reconstructs each real action boundary")
 expect(reopened.cursor==0 and not reopened.recording and reopened.points.size()==config.actions.size()+1,"reopened recording starts at the first action with a full stepper")
 expect(reopened.seek(3) and reopened.adapter.engine.pending.get("kind")=="block","seeking restores the true block choice")
 expect(reopened.seek(1) and reopened.adapter.engine.priority==1 and reopened.adapter.entity("attacker").attacked,"backward seek restores attack and execution priority")
 expect(reopened.actions==before.actions and config==before,"seeking leaves recorded actions and source JSON intact")
 expect(reopened.seek(config.actions.size()) and Recorder.facts(reopened.adapter.engine)==final,"final step restores the original final rule state")
 reopened.seek(2);expect(reopened.start_replay().is_empty(),"playback resumes at the selected boundary")
 for i in range(80):reopened.tick(0.3,false)
 expect(not reopened.replaying and reopened.cursor==config.actions.size(),"animation playback finishes on the final boundary")
 reopened.seek(1);reopened.start_replay();reopened.tick(0.3,false);reopened.pause_replay()
 expect(not reopened.replaying and not reopened.recording and reopened.cursor==2,"pause retains playback position without starting a recording")
 expect(reopened.resume_record(1) and reopened.actions.size()==1 and reopened.points.size()==2,"rerecord keeps the prefix and replaces the selected action onwards")
 reopened.adapter.engine.pass_priority(1);reopened.finish()
 expect(reopened.verify().is_empty() and reopened.actions==before.actions.slice(0,2),"replacement suffix replays correctly with original prefix")
 expect(config==before,"rerecording is private until the editor applies it")
 var invalid=before.duplicate(true);invalid.actions[0].card={"alias":"missing"}
 var kept=reopened.sequence_config();var point=reopened.cursor
 expect(not reopened.load_sequence(invalid).is_empty() and reopened.sequence_config()==kept and reopened.cursor==point,"failed restoration leaves current timeline untouched")

func random_history():
 var scene=Model.battle();scene.players[0].field=[{"card_id":"character-lof-001","alias":"die","state":{"courage":2,"leader_counters":1}}]
 scene.players[1].field=[{"card_id":"53","alias":"target"}]
 var r=Recorder.new();r.configure(scene,Store.CARDS);r.begin_record()
 var action={"type":"ability","player":0,"source":{"alias":"die"},"key":"courage_die","target":{"alias":"target"}}
 var prepared=Sequence.prepare(r.adapter,action,0)
 expect(prepared.available,"random history uses a legal native die ability")
 if not prepared.available:return
 r.adapter.submit(0,prepared.command);r.adapter.engine.pass_priority(1);r.adapter.engine.pass_priority(0);r.finish()
 var saved=r.sequence_config();var reopened=Recorder.new();reopened.configure(r.scene,Store.CARDS)
 expect(reopened.load_sequence(saved).is_empty(),"reopening preserves recorded die results and RNG advancement")
 expect(reopened.points[1].random_count==1 and reopened.points[0].random_count==0,"every step remembers consumed random outcomes")
 reopened.resume_record(0)
 expect(reopened.random_results.is_empty(),"rerecording before a random action removes its discarded result")
 prepared=Sequence.prepare(reopened.adapter,action,0);reopened.adapter.submit(0,prepared.command)
 reopened.adapter.engine.pass_priority(1);reopened.adapter.engine.pass_priority(0);reopened.finish()
 expect(reopened.verify().is_empty() and reopened.random_results==saved.random_results,"new die recording continues from the restored RNG origin")
 # Existing tutorials may contain delays and omit advance_rng.
 var delayed=saved.duplicate(true);delayed.actions.insert(1,{"type":"delay","seconds":2.5})
 expect(reopened.load_sequence(delayed).is_empty() and reopened.points.size()==delayed.actions.size()+1,"delay actions also have individually seekable boundaries")
 var legacy=saved.duplicate(true);legacy.erase("advance_rng")
 expect(reopened.load_sequence(legacy).is_empty() and not reopened.advance_rng,"legacy recordings preserve their random progression policy")
 reopened.resume_record(0);prepared=Sequence.prepare(reopened.adapter,action,0);reopened.adapter.submit(0,prepared.command)
 reopened.adapter.engine.pass_priority(1);reopened.adapter.engine.pass_priority(0);reopened.finish()
 expect(reopened.verify().is_empty(),"rerecording a legacy die action preserves its random progression policy")

func native_history():
 var r=preload("res://scripts/tutorial/function_recorder.gd").new();var scene={"type":"in_game","screen":"deck_editor","deck":Model.deck()}
 r.configure(scene,Store.CARDS);r.begin_record();r.adapter.ui_deck.main.append("96");r.accepted("editor.add",{"card_id":"96","zone":"main"});r.accepted("editor.inspect",{"card_id":"96"});r.finish()
 var nodes=r.nodes.duplicate(true);nodes[0].guide.text="保留的指引";nodes[0].task.failure={"type":"ui_action","action":{"id":"editor.remove"}};nodes[0].failure="$complete"
 var reopened=preload("res://scripts/tutorial/function_recorder.gd").new();reopened.configure(scene,Store.CARDS)
 var reason=reopened.load_nodes(nodes,func(action):
  if action.id=="editor.add":reopened.adapter.ui_deck[action.args.zone].append(action.args.card_id)
  reopened.adapter.last_ui_action=action.duplicate(true);return "")
 expect(reason.is_empty() and reopened.nodes==nodes,"native task history keeps guides and existing conditions")
 reopened.seek(1);expect(reopened.adapter.ui_deck.main==["53","96"],"native history restores deck after prescribed addition")
 reopened.seek(0);expect(reopened.adapter.ui_deck.main==["53"] and reopened.actions.size()==2,"native backward seek keeps later actions")
 reopened.start_replay();reopened.tick(1);reopened.tick(1)
 expect(reopened.cursor==2 and not reopened.replaying,"native history plays each restored step")
 reopened.resume_record(1);reopened.accepted("editor.inspect",{"card_id":"53"});reopened.finish()
 expect(reopened.nodes[0]==nodes[0] and reopened.nodes[1].task.action.args.card_id=="53","native rerecord preserves prefix settings and replaces suffix")

func existing_courses():
 for name in ["t3","t4"]:
  var model=Model.new();model.load_course("res://data/tutorial/beginner/"+name+".json")
  var before=model.data.duplicate(true)
  for id in model.data.steps:
   var step=model.data.steps[id]
   if not step.has("sequence"):continue
   var r=Recorder.new();var reason=r.configure(model.data.scenarios[model.scene_for(id)],Store.CARDS)
   if reason.is_empty():reason=r.load_sequence(step.sequence)
   expect(reason.is_empty(),name+" existing animation reopens: "+id+" "+reason)
  expect(model.data==before,name+" reopening existing animations preserves source course")

func _initialize():
 battle_history();random_history();native_history();existing_courses()
 print("TUTORIAL RECORDING HISTORY: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
