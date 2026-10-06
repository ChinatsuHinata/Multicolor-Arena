extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Model=preload("res://scripts/tutorial/authoring_model.gd")
const Recorder=preload("res://scripts/tutorial/battle_recorder.gd")
const Capture=preload("res://scripts/tutorial/condition_capture.gd")
const Config=preload("res://scripts/tutorial/config.gd")
const Generated=preload("res://tests/support/tutorial_generated_units.gd")
var failures=[]
var checks=0

func expect(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);push_error(label)

func make_recorder():
 var scene=Model.battle();scene.players[0].field=[{"card_id":"53","alias":"attacker","state":{"entered":0,"entered_turns":0}}]
 scene.players[1].field=[{"card_id":"53","alias":"blocker","state":{"entered":0,"entered_turns":0}}]
 var recorder=Recorder.new();expect(recorder.configure(scene,Store.CARDS).is_empty(),"condition capture uses valid battlefield")
 recorder.points=[{"adapter":recorder.adapter.capture(),"random_count":0}];recorder.recording=true;recorder.bind()
 return recorder

func state_conditions():
 var r=make_recorder();var scene=r.scene.duplicate(true);var e=r.adapter.engine
 e.attack(0,int(r.adapter.entity("attacker").uid));e.pass_priority(1);e.pass_priority(0);e.block([]);e.pass_priority(0);e.pass_priority(1);r.finish()
 expect(r.actions.size()==6 and e.players[1].life<20,"real combat produces recorded actions and changed life")
 var focused={"type":"life","player":1,"op":"le","value":0}
 var choices=Capture.candidates(r,focused)
 var selected=choices.filter(func(item):return item.selected)
 expect(selected.size()==1 and selected[0].condition.value==e.players[1].life,"rerecording updates the selected life threshold from actual damage")
 expect(choices.any(func(item):return item.condition=={"type":"entity_state","alias":"attacker","key":"attacked","value":true}),"actual attack flag is an available condition")
 for item in choices:
  var check=Config.new();check.definitions=Store.CARDS;check.condition(item.condition,"condition",{});check.check_aliases(item.condition,"condition",r.adapter.aliases)
  expect(check.errors.is_empty() and r.adapter.evaluate(item.condition,[]),"captured predicate validates and matches the recorded state")
 expect(r.scene==scene,"sampling predicates leaves source tableau unchanged")
 var entity={"type":"entity_state","alias":"attacker","key":"tapped","value":false}
 choices=Capture.candidates(r,entity);selected=choices.filter(func(item):return item.selected)
 expect(selected.size()==1 and selected[0].condition.key=="tapped" and selected[0].condition.value,"sampling selects the intended flag rather than every flag on that card")
 var color={"type":"entity_color_counter","alias":"attacker","color":"红"}
 choices=Capture.candidates(r,color);selected=choices.filter(func(item):return item.selected)
 expect(selected.size()==1 and selected[0].condition=={"type":"not","condition":color},"absent color produces a selected negated predicate")
 var refs=Capture.references({"type":"all","conditions":[{"type":"entity_zone","alias":"attacker","zone":"grave"},{"type":"life","player":1,"op":"le","value":10},{"type":"not","condition":{"type":"phase","value":"main"}}]},r.adapter)
 expect(refs.size()==4 and refs[0].kind=="card" and refs[0].ref.uid==r.adapter.entity("attacker").uid,"nested predicates identify the actual aliased instance")
 expect(refs[1]=={"kind":"zone","player":0,"zone":"grave"} and refs[2]=={"kind":"player","player":1} and refs[3].kind=="phase","arrows include desired zone, player and phase subjects")

func trigger_conditions():
 var r=make_recorder();var e=r.adapter.engine
 e.pass_priority(0);e.pass_priority(1);r.finish()
 var existing={"id":"existing","event":"state_changed","when":{"type":"always"},"action":"pass_priority","max_times":3}
 var before=existing.duplicate(true);var rule=Capture.trigger(r,0,existing)
 expect(existing==before and rule.id==existing.id and rule.max_times==3,"trigger rerecording preserves identity and execution limit privately")
 expect(rule.event=="command_accepted" and rule.on_action=={"type":"pass_priority","player":0},"recorded action becomes an exact accepted-command trigger")
 expect(rule.when.conditions.has({"type":"priority","value":1}) and rule.sequence.actions==[{"type":"pass_priority","player":1}] and not rule.has("action"),"recorded response replaces the old action with real opponent commands")
 var check=Config.new();check.definitions=Store.CARDS;check.opponent({"strategy":"rules","rules":[rule]},"opponent",{})
 expect(check.errors.is_empty(),"recorded trigger conforms to tutorial schema")
 var adapter=preload("res://scripts/tutorial/game_adapter.gd").new();adapter.load_scenario("test",r.scene,Store.CARDS)
 var opponent=preload("res://scripts/tutorial/opponent.gd").new();opponent.configure({"strategy":"rules","rules":[rule]})
 adapter.engine.command_accepted.connect(func(_seat,_command,action):opponent.observe({"type":"command_accepted","action":action}))
 adapter.engine.pass_priority(0)
 for i in range(20):expect(opponent.tick(adapter,[],0.2).is_empty(),"recorded trigger executes without rule errors")
 expect(opponent.counts.get("existing")==1 and adapter.engine.priority==0,"actual runtime executes recorded response once")
 expect(Capture.trigger(r,-1,existing).is_empty() and Capture.trigger(r,5,existing).is_empty(),"invalid trigger selection is rejected")
 var last=Capture.trigger(r,1,existing)
 expect(last.action=="pass_priority" and not last.has("sequence"),"recording without subsequent opponent actions preserves configured response")

func generated_conditions():
 var r=Recorder.new();var reason=r.configure(Generated.scene(),Store.CARDS)
 if reason.is_empty():reason=r.begin_record()
 expect(reason.is_empty(),"generated unit recorder uses a real spell and paid resources: "+reason)
 if not reason.is_empty():return
 var conditions=[{"type":"entity_zone","created":0,"zone":"field"},{"type":"entity_state","created":0,"key":"tapped","value":false},{"type":"entity_count","created":0,"key":"plus_counters","op":"eq","value":0},{"type":"entity_color_counter","created":0,"color":"红"},{"type":"combat_attacker","created":0}]
 for c in conditions:
  var check=Config.new();check.condition(c,"condition",{})
  expect(check.errors.is_empty() and not r.adapter.evaluate(c,[]),"uncreated instance validates but cannot satisfy an atomic condition: "+c.type)
 for ref in [{},{"created":-1},{"created":0.5},{"created":"0"},{"alias":"maker","created":0}]:
  var c={"type":"entity_zone","zone":"field"};c.merge(ref);var check=Config.new();check.condition(c,"condition",{})
  expect(not check.errors.is_empty(),"invalid or ambiguous instance reference is rejected: "+str(ref))
 reason=Generated.cast(r.adapter);expect(reason.is_empty(),"real spell creates two identically named mid-task units: "+reason)
 if not reason.is_empty():return
 r.finish();expect(r.verify().is_empty(),"generated unit actions replay to the same state")
 r.seek(r.actions.size())
 var tokens=r.adapter.card_subjects().filter(func(item):return item.ref.has("created"))
 expect(tokens.size()==2 and tokens[0].card.card_id==tokens[1].card.card_id and tokens[0].ref!=tokens[1].ref,"same-definition tokens retain separate instance references")
 if tokens.size()!=2:return
 var ref=tokens[0].ref;var token=tokens[0].card
 var zone=ref.duplicate(true);zone.merge({"type":"entity_zone","zone":"field"})
 var choices=Capture.candidates(r,zone)
 expect(choices.any(func(item):return item.condition==zone and item.selected),"newly created units appear in captured condition candidates")
 expect(Capture.references(zone,r.adapter)[0].ref.uid==token.uid,"generated condition arrow resolves the exact instance")
 var sampled=ref.duplicate(true);sampled.merge({"type":"entity_state","key":"tapped","value":true})
 expect(Capture.sample(sampled,r.adapter).value==false,"sampling generated unit state preserves its reference")
 for item in choices:
  var check=Config.new();check.definitions=Store.CARDS;check.condition(item.condition,"condition",{});check.check_aliases(item.condition,"condition",r.adapter.aliases)
  expect(check.errors.is_empty() and r.adapter.evaluate(item.condition,[]),"captured generated predicate validates and evaluates")
 token.tapped=true;token.plus_counters=2;token.color_counters=["红"];r.adapter.engine.combat={"attacker":r.adapter.engine.ref_target(token)}
 for c in conditions:
  c.created=ref.created
  if c.type=="entity_state":c.value=true
  if c.type=="entity_count":c.value=2
  expect(r.adapter.evaluate(c,[]),"generated reference supports actual state: "+c.type)
 r.adapter.engine.move_to(token,"grave")
 expect(not r.adapter.evaluate(zone,[]) and r.adapter.resolve_card(ref).is_empty(),"destroyed token does not fall back to the other identical token")
 sampled.value=false
 expect(not r.adapter.evaluate(sampled,[]),"vanished token cannot satisfy an untapped condition")
 expect(r.seek(0) and not r.adapter.evaluate(zone,[]),"rewinding before creation removes the generated instance")
 expect(r.seek(r.actions.size()) and r.adapter.evaluate(zone,[]),"restoring recorded checkpoint retains origin and exact reference")
 var data=Model.new();data.fresh();data.data.scenarios.scene_1=r.scene.duplicate(true);data.data.start_step="step_2";data.data.steps.step_2.task.success=zone
 var parsed=JSON.parse_string(JSON.stringify(data.data));expect(Config.new().validate(parsed,Store.CARDS).ok,"full course JSON round-trip accepts generated conditions")
 var flow=preload("res://scripts/tutorial/runtime.gd").new()
 expect(flow.start(parsed,Store.CARDS).is_empty() and flow.running,"runtime accepts a condition for a future instance")
 expect(Generated.cast(flow.adapter).is_empty() and flow.adapter.evaluate(zone,[]),"runtime resolves created instance after actual generation")
 expect(flow.reset_task() and not flow.adapter.evaluate(zone,[]),"task reset restores pre-generation origin and state")
 expect(Generated.cast(flow.adapter).is_empty() and flow.adapter.evaluate(zone,[]),"regeneration after reset reuses the same portable reference")
 flow.tick(0.1);expect(flow.finished,"generated-instance success advances and completes the task");flow.free()

func _initialize():
 state_conditions();trigger_conditions();generated_conditions()
 print("TUTORIAL CONDITION CAPTURE: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
