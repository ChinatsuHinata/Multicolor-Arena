extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Model=preload("res://scripts/tutorial/authoring_model.gd")
const Runtime=preload("res://scripts/tutorial/runtime.gd")
const Config=preload("res://scripts/tutorial/config.gd")
var failures=[]
var checks=0

func expect(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);push_error(label)

func unit(alias: String,spirit: int,power: int=8) -> Dictionary:
 return {"card_id":"roster_token_frog","alias":alias,"token_value":power,"token_spirit":spirit,"token_name":"青蛙衍生物","state":{"entered":0,"entered_turns":0}}

func rank(count: int=1,ties: String="all") -> Dictionary:
 return {"type":"combat_attacker_rank","player":0,"key":"spirit","count":count,"ties":ties}

func dynamic_rank() -> Dictionary:
 return {"type":"combat_attacker_rank","player":0,"key":"spirit","count_player":1,"ties":"field_order"}

func fixture(when: Dictionary,automatic: bool=true,limit: int=5) -> Dictionary:
 var scene=Model.battle()
 scene.players[0].field=[unit("low",1),unit("high",5),unit("second",4),unit("tied",4)]
 scene.players[1].field=[unit("small",1,1),unit("big",1,3)]
 var rule={"id":"rank_block","event":"state_changed","when":when,"action":{"type":"block","priorities":[{"strategy":"largest"}]},"max_times":limit}
 if automatic:rule.otherwise="no_block"
 scene.opponent={"strategy":"rules","rules":[rule]}
 return {"schema_version":1,"id":"attack_rank","title":"灵力排名对策","initial_scenario":"board","start_step":"practice","completion":{"type":"always"},"scenarios":{"board":scene},"steps":{"practice":{"type":"task","guide":{"text":"观察灵力排名对策。","popup":"hidden","next_button":"hidden"},"task":{"success":{"type":"life","player":0,"op":"le","value":0}},"next":"$complete"}}}

func start(when: Dictionary,automatic: bool=true,limit: int=5):
 var flow=Runtime.new();var reason=flow.start(fixture(when,automatic,limit),Store.CARDS)
 expect(reason.is_empty(),"rank fixture starts: "+reason)
 if not reason.is_empty():flow.free();return null
 return flow

func ticks(flow,count: int=12):
 for i in range(count):flow.tick()

func attack(flow,alias: String):
 expect(flow.adapter.submit(0,{"name":"attack","args":[int(flow.adapter.entity(alias).uid),{},[]]}).is_empty(),"ranked unit attacks through gateway: "+alias)

func choice(flow):
 ticks(flow);expect(flow.adapter.engine.priority==0,"shortcut passes attack response for any rank")
 expect(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty(),"player opens real block choice")
 ticks(flow)

func blocked(flow) -> bool:
 return flow.adapter.engine.combat.get("blocked",false)

func finish(flow):
 for i in range(60):
  ticks(flow,1);var e=flow.adapter.engine
  if e.combat.is_empty():return
  if e.pending.is_empty() and e.priority==0:expect(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty(),"player resolves combat after ranked decision")
 expect(false,"ranked combat finishes without a stalled opponent")

func highest_and_ties():
 for alias in ["high","low","second"]:
  var flow=start(rank())
  if flow==null:continue
  expect(not flow.adapter.evaluate(rank(),[]),"rank requires an actual attack")
  attack(flow,alias)
  expect(flow.adapter.evaluate(rank(),[])==(alias=="high"),"highest predicate identifies current attacking unit")
  choice(flow)
  expect(flow.running and blocked(flow)==(alias=="high"),"only highest spirit gets blocked")
  expect(flow.opponent.counts.get("rank_block",0)==(1 if alias=="high" else 0),"declining an outside attack does not consume blocking count")
  finish(flow);flow.free()
 for ties in ["all","field_order"]:
  var flow=start(rank(1,ties))
  if flow==null:continue
  flow.adapter.entity("tied").modifiers=[{"灵力":1}]
  attack(flow,"tied");choice(flow)
  expect(blocked(flow)==(ties=="all"),"equal maximum obeys selected tie policy: "+ties)
  flow.free()

func dynamic_counts():
 for alias in ["high","second","tied","low"]:
  var flow=start(dynamic_rank())
  if flow==null:continue
  attack(flow,alias);choice(flow)
  expect(flow.running and blocked(flow)==(alias in ["high","second"]),"two opposing units block exactly our top two by spirit: "+alias)
  flow.free()
 var flow=start(dynamic_rank())
 if flow==null:return
 var e=flow.adapter.engine
 attack(flow,"tied")
 var added=e.make_card(flow.adapter.entity("small").card_id,1,"field");e.players[1].field.append(added)
 choice(flow);expect(blocked(flow),"new opposing unit expands x before actual block decision")
 flow.free()
 flow=start(dynamic_rank())
 if flow==null:return
 e=flow.adapter.engine;attack(flow,"second");ticks(flow)
 var small=flow.adapter.entity("small");e.players[1].field.erase(small);small.zone="grave";e.players[1].grave.append(small)
 choice(flow);expect(not blocked(flow) and flow.opponent.counts.is_empty(),"opposing unit leaving shrinks x at block time")
 flow.free()
 flow=start(dynamic_rank())
 if flow==null:return
 e=flow.adapter.engine
 e.players[1].field[0].tapped=true
 var item_id=e.cards.keys().filter(func(id):return e.cards[id].kind=="道具")[0]
 var item=e.make_card(item_id,1,"field");e.players[1].field.append(item)
 attack(flow,"tied")
 expect(not flow.adapter.evaluate(dynamic_rank(),[]),"x includes tapped units and excludes nonunit permanents")
 var leader_id=e.cards.keys().filter(func(id):return e.cards[id].kind=="自机")[0]
 e.players[1].field.append(e.make_card(leader_id,1,"field"))
 expect(flow.adapter.evaluate(dynamic_rank(),[]),"x also counts a leader actually on the battlefield")
 e.players[1].field=[]
 expect(not flow.adapter.evaluate(dynamic_rank(),[]),"zero opposing units yields an empty rank range")
 flow.free()

func required_blocking():
 var data=fixture(rank());data.scenarios.board.players[0].field[0]={"card_id":"character-fdf-090","alias":"low","state":{"entered":0,"entered_turns":0}}
 data.scenarios.board.opponent.rules.append({"id":"mandatory","event":"state_changed","when":{"type":"pending","kind":"block","owner":1},"action":{"type":"block","priorities":[{"strategy":"largest"}]},"max_times":1})
 var flow=Runtime.new();var reason=flow.start(data,Store.CARDS)
 expect(reason.is_empty(),"mandatory-block rank scene starts: "+reason)
 if not reason.is_empty():flow.free();return
 flow.adapter.entity("high").modifiers=[{"灵力":50}]
 attack(flow,"low");choice(flow)
 expect(flow.running and blocked(flow) and flow.opponent.counts.get("mandatory")==1 and flow.opponent.counts.get("rank_block",0)==0,"outside-range auto-decline respects mandatory blocking and permits a later legal rule")
 flow.free()

func live_stats_and_instances():
 var flow=start(rank())
 if flow==null:return
 attack(flow,"second");ticks(flow)
 flow.adapter.entity("second").modifiers=[{"灵力":3}]
 choice(flow);expect(blocked(flow),"current spirit buffs are applied at real blocking time")
 var snapshot=flow.capture()
 expect(flow.reset_task() and flow.opponent.counts.is_empty(),"reset restores rank rule and response count")
 expect(flow.restore(snapshot) and blocked(flow),"checkpoint restores chosen ranked response")
 flow.free()
 flow=start(rank())
 if flow==null:return
 var e=flow.adapter.engine
 var generated=e.make_card(flow.adapter.entity("low").card_id,0,"field");generated.entered=0;generated.entered_turns=0;generated.modifiers=[{"灵力":10}];e.players[0].field.append(generated)
 expect(flow.adapter.submit(0,{"name":"attack","args":[int(generated.uid),{},[]]}).is_empty(),"newly created unit attacks through real rules")
 expect(flow.adapter.evaluate(rank(),[]),"ranking includes a generated unit without a scene alias")
 generated.epoch+=1
 expect(not flow.adapter.evaluate(rank(),[]),"stale combat epoch cannot match a returning instance")
 flow.free()
 flow=start(rank())
 if flow==null:return
 attack(flow,"high")
 var opposite=rank();opposite.player=1
 expect(not flow.adapter.evaluate(opposite,[]),"ranking only applies to the chosen attacking side")
 var power=rank();power.key="power"
 expect(flow.adapter.evaluate(power,[]),"rank can compare attack instead of spirit")
 var health=rank();health.key="health";flow.adapter.entity("high").damage=1
 expect(not flow.adapter.evaluate(health,[]),"health ranking uses remaining health after damage")
 flow.adapter.engine.combat.forced=true
 expect(not flow.adapter.evaluate(rank(),[]),"an effect's forced duel is not treated as a declared ranked attack")
 flow.free()

func limits_and_pausing():
 var flow=start(rank(),true,1)
 if flow==null:return
 attack(flow,"low");choice(flow);finish(flow)
 expect(flow.opponent.counts.is_empty(),"earlier low attack leaves later high attack's allowance intact")
 attack(flow,"high");choice(flow);expect(blocked(flow),"remaining allowance blocks the highest unit");finish(flow)
 var high=flow.adapter.entity("high");high.tapped=false
 attack(flow,"high");choice(flow)
 expect(not blocked(flow) and flow.opponent.counts.get("rank_block")==1,"exhausted shortcut lets later attacks pass without consuming extra counts")
 finish(flow);flow.free()
 flow=start(rank(),false)
 if flow==null:return
 attack(flow,"low");ticks(flow)
 expect(flow.adapter.engine.priority==1 and flow.opponent.blocking.is_empty(),"unchecked automatic decline retains explicit waiting behavior")
 flow.free()

func validation():
 for predicate in [rank(),dynamic_rank(),rank(2,"field_order")]:
  var data=fixture(predicate)
  data.steps.practice.task.success=predicate.duplicate(true)
  expect(Config.new().validate(JSON.parse_string(JSON.stringify(data)),Store.CARDS).ok,"rank and automatic decline validate in rules and task conditions")
 var invalids=[]
 for patch in [{"count":0},{"count":1.5},{"player":2},{"key":"cost"},{"ties":"random"},{"count_player":1},{"extra":true}]:
  var predicate=rank();predicate.merge(patch,true);invalids.append(predicate)
 invalids.append({"type":"combat_attacker_rank","player":0,"key":"spirit"})
 var invalid=dynamic_rank();invalid.count_player=2;invalids.append(invalid)
 for predicate in invalids:expect(not Config.new().validate(fixture(predicate),Store.CARDS).ok,"invalid attack ranking is rejected: "+str(predicate))
 for patch in [{"otherwise":"anything"},{"action":"pass_priority"},{"event":"priority_changed"},{"sequence":{"actions":[]}}]:
  var data=fixture(rank());data.scenarios.board.opponent.rules[0].merge(patch,true)
  expect(not Config.new().validate(data,Store.CARDS).ok,"automatic decline accepts only real block presets")
 var config=Config.new();config.check_scene_fields(rank(),"task.success","deck",[])
 expect(not config.errors.is_empty(),"rank conditions cannot be used in a deck scene")

func _initialize():
 validation();highest_and_ties();dynamic_counts();live_stats_and_instances();limits_and_pausing();required_blocking()
 print("TUTORIAL ATTACK RANK: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
