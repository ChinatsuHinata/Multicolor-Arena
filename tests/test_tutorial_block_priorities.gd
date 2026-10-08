extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Model=preload("res://scripts/tutorial/authoring_model.gd")
const Runtime=preload("res://scripts/tutorial/runtime.gd")
const Config=preload("res://scripts/tutorial/config.gd")
const Presets=preload("res://scripts/tutorial/block_priorities.gd")
var failures=[]
var checks=0

func expect(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);push_error(label)

func unit(alias: String,value: int) -> Dictionary:
 return {"card_id":"roster_token_frog","alias":alias,"token_value":value,"token_spirit":1,"token_name":"青蛙衍生物","state":{"entered":0,"entered_turns":0}}

func fixture(options: Array) -> Dictionary:
 var data={"schema_version":1,"id":"block_priorities","title":"阻挡优先级","completion":{"type":"always"}};var scene=Model.battle()
 scene.players[0].field=[unit("attacker",6),unit("other_attacker",2)]
 scene.players[1].field=[unit("small",1),unit("medium",3),unit("big",4)]
 scene.opponent={"strategy":"rules","rules":[{"id":"block_priority","event":"state_changed","when":{"type":"combat_attacker","alias":"attacker"},"action":{"type":"block","priorities":options},"max_times":1}]}
 data.scenarios={"board":scene};data.initial_scenario="board";data.start_step="practice"
 data.steps={"practice":{"type":"task","guide":{"text":"条件阻挡","popup":"hidden","next_button":"hidden"},"task":{"success":{"type":"life","player":0,"op":"le","value":0}},"next":"$complete"}}
 return data

func ticks(flow,count: int=12):
 for i in range(count):flow.tick()

func start(options: Array):
 var flow=Runtime.new();var reason=flow.start(fixture(options),Store.CARDS)
 expect(reason.is_empty(),"priority fixture starts: "+reason)
 if not reason.is_empty():flow.free();return null
 return flow

func attack_to_choice(flow,alias: String="attacker"):
 var e=flow.adapter.engine
 expect(flow.adapter.submit(0,{"name":"attack","args":[int(flow.adapter.entity(alias).uid),{},[]]}).is_empty(),"attack uses real command")
 ticks(flow)
 expect(e.priority==0 and e.combat.get("step")=="attack_window","preset passes opponent attack response without a separate pass rule")
 expect(flow.opponent.counts.get("block_priority",0)==0,"passing does not consume blocking limit")
 expect(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty(),"player opens blocking choice")
 expect(e.pending.get("kind")=="block","real blocker choice is pending")

func selected_aliases(flow) -> Array:
 var uids=flow.adapter.engine.combat.get("blockers",[]).map(func(ref):return int(ref.uid))
 return ["small","medium","big"].filter(func(alias):return int(flow.adapter.entity(alias).uid) in uids)

func settle(flow):
 for i in range(60):
  ticks(flow)
  var e=flow.adapter.engine
  if e.combat.is_empty():return
  if e.pending.get("kind")=="damage_assignment":
   var allocation=e.RemiliaAI.damage_allocation(e,e.find_card(e.combat.attacker.uid),e.combat.blockers.map(func(ref):return e.find_card(ref.uid)),int(e.pending.total))
   expect(flow.adapter.submit(0,{"name":"combat_damage","args":[allocation]}).is_empty(),"player assigns real joint-block combat damage")
  elif e.pending.is_empty() and e.priority==0:expect(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty(),"player passes combat response")
 expect(false,"combat settles within bounded ticks")

func choices_and_order():
 for strategy in ["largest","smallest","all","lethal"]:
  var flow=start([{"strategy":strategy}])
  if flow==null:continue
  attack_to_choice(flow);var snapshot=flow.capture();ticks(flow)
  var expected={"largest":["big"],"smallest":["small"],"all":["small","medium","big"],"lethal":["medium","big"]}[strategy]
  expect(flow.running and selected_aliases(flow)==expected,"correct preset selection: "+strategy)
  expect(flow.opponent.counts.get("block_priority",0)==1,"one decision consumes one count")
  if strategy=="lethal":
   settle(flow);expect(flow.adapter.entity("attacker").is_empty(),"joint lethal preset kills attacker in real combat")
  expect(flow.reset_task() and flow.opponent.counts.is_empty() and flow.opponent.blocking.is_empty(),"task reset restores counts and combat response tracking")
  expect(flow.restore(snapshot),"blocking checkpoint restores")
  ticks(flow);expect(selected_aliases(flow)==expected and flow.opponent.counts.get("block_priority",0)==1,"restored priorities make the same decision")
  flow.free()
 for options in [[{"strategy":"smallest"},{"strategy":"largest"}],[{"strategy":"largest","enabled":false},{"strategy":"smallest"}]]:
  var flow=start(options)
  if flow==null:continue
  attack_to_choice(flow);ticks(flow)
  expect(selected_aliases(flow)==["small"],"first enabled satisfiable option wins")
  flow.free()

func fallback_and_legality():
 var flow=start([{"strategy":"selected","cards":[{"alias":"big"}]},{"strategy":"smallest"}])
 if flow!=null:
  flow.adapter.entity("big").tapped=true;attack_to_choice(flow);ticks(flow)
  expect(flow.running and selected_aliases(flow)==["small"],"illegal selected unit falls through without stopping tutorial")
  flow.free()
 flow=start([{"strategy":"selected","cards":[{"created":999}]},{"strategy":"all"}])
 if flow!=null:
  attack_to_choice(flow);ticks(flow);expect(selected_aliases(flow).size()==3,"missing created unit falls through to all legal units");flow.free()
 flow=start([{"strategy":"selected","cards":[{"alias":"small"},{"alias":"medium"}]}])
 if flow!=null:
  attack_to_choice(flow);ticks(flow);expect(selected_aliases(flow)==["small","medium"],"creator selection supports multiple specific units");flow.free()
 flow=start([{"strategy":"lethal"},{"strategy":"smallest"}])
 if flow!=null:
  flow.adapter.entity("attacker").plus_counters=20;attack_to_choice(flow);ticks(flow)
  expect(selected_aliases(flow)==["small"],"unreachable lethal falls through to smallest")
  flow.free()
 flow=start([{"strategy":"lethal"}])
 if flow!=null:
  flow.adapter.entity("attacker").plus_counters=20;attack_to_choice(flow);ticks(flow)
  expect(flow.running and flow.adapter.engine.pending.is_empty() and not flow.adapter.engine.combat.blocked,"no matching option declines blocking")
  flow.free()
 var data=fixture([{"strategy":"largest"},{"strategy":"smallest"},{"strategy":"all"}]);data.scenarios.board.players[0].field[0]={"card_id":"character-fdn-068","alias":"attacker","state":{"entered":0,"entered_turns":0}}
 flow=Runtime.new();expect(flow.start(data,Store.CARDS).is_empty(),"menace scene starts")
 attack_to_choice(flow);ticks(flow)
 expect(flow.running and selected_aliases(flow).size()==3,"menace rejects single presets and falls through to joint block")
 flow.free()

func preview_and_gates():
 var flow=start([{"strategy":"lethal"},{"strategy":"smallest"}])
 if flow!=null:
  var e=flow.adapter.engine;var attacker=flow.adapter.entity("attacker")
  attacker.modifiers=[{"先制":true}]
  attack_to_choice(flow);ticks(flow)
  expect(selected_aliases(flow)==["small"],"first strike prevents predicted lethal and selects fallback")
  flow.free()
 for keyword in ["防止伤害","不会被消灭"]:
  flow=start([{"strategy":"lethal"},{"strategy":"all"}])
  if flow==null:continue
  flow.adapter.entity("attacker").modifiers=[{keyword:true}]
  attack_to_choice(flow)
  var before=flow.adapter.capture();var prepared=Presets.prepare(flow.adapter,[{"strategy":"lethal"}])
  expect(prepared.uids.is_empty(),"lethal respects "+keyword)
  expect(flow.adapter.capture()==before,"combat preview does not mutate live state")
  ticks(flow);expect(selected_aliases(flow).size()==3,"nonlethal joint block fallback remains available");flow.free()
 flow=start([{"strategy":"all"}])
 if flow!=null:
  var e=flow.adapter.engine
  expect(flow.adapter.submit(0,{"name":"attack","args":[int(flow.adapter.entity("other_attacker").uid),{},[]]}).is_empty(),"different unit attacks")
  ticks(flow);expect(flow.opponent.counts.is_empty() and e.priority==1 and flow.opponent.blocking.is_empty(),"preset only responds to configured attacker")
  flow.free()

func repeat_limit():
 var flow=start([{"strategy":"largest"}])
 if flow==null:return
 attack_to_choice(flow);ticks(flow)
 var e=flow.adapter.engine
 expect(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty(),"player resolves single-block combat")
 ticks(flow)
 expect(e.combat.get("step")=="damage_window","preset also passes opponent damage response")
 expect(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty(),"player finishes damage window")
 for i in range(24):
  flow.tick()
  if e.combat.is_empty():break
 expect(e.combat.is_empty() and flow.opponent.counts.get("block_priority")==1,"first attack finishes after exactly one decision")
 # A new attack may arrive before an idle tick clears the previous response.
 var attacker=flow.adapter.entity("attacker");attacker.tapped=false
 expect(flow.adapter.submit(0,{"name":"attack","args":[int(attacker.uid),{},[]]}).is_empty(),"surviving refreshed attacker attacks again")
 ticks(flow)
 expect(e.priority==1 and flow.opponent.blocking.is_empty() and flow.opponent.counts.get("block_priority")==1,"exhausted preset cannot keep passing for a later attack by the same instance")
 flow.free()

func validation():
 var data=fixture(Presets.defaults())
 expect(Config.new().validate(JSON.parse_string(JSON.stringify(data)),Store.CARDS).ok,"five-option priorities validate after JSON round trip")
 for options in [[],[{"strategy":"unknown"}],[{"strategy":"largest","enabled":"yes"}],[{"strategy":"largest","enabled":false}],[{"strategy":"largest"},{"strategy":"largest"}],[{"strategy":"all","cards":[]}],[{"strategy":"selected","cards":[{"alias":"absent"}]}],[{"strategy":"selected","cards":[{"alias":"big"},{"alias":"big"}]}]]:
  var invalid=fixture(options);var checked=Config.new().validate(invalid,Store.CARDS)
  expect(not checked.ok,"invalid priorities rejected: "+str(options))
 var invalid=data.duplicate(true);invalid.scenarios.board.opponent.rules[0].action.cards=[]
 expect(not Config.new().validate(invalid,Store.CARDS).ok,"explicit cards and priorities are mutually exclusive")

func spell_responses():
 var data=fixture([{"strategy":"largest"}]);var scene=data.scenarios.board
 scene.turn=8
 scene.players[0].leader={"card_id":"character-fdf-ex04","alias":"attacker"}
 scene.players[0].leader_on_field=true;scene.players[0].field=[]
 scene.players[0].hand=[{"card_id":"spell-ucs-027","alias":"spell"}]
 scene.players[0].palette=[{"card_id":"128"},{"card_id":"128"}]
 var flow=Runtime.new();var reason=flow.start(data,Store.CARDS)
 expect(reason.is_empty(),"Tenshi removal task starts: "+reason)
 if not reason.is_empty():flow.free();return
 var e=flow.adapter.engine;var spell=flow.adapter.entity("spell")
 var target={"player":1};var cost=e.payment(0,e.cast_cost(0,spell,target))
 expect(flow.adapter.submit(0,{"name":"commit_cast","args":[int(spell.uid),target,cost.plan]}).is_empty(),"first Tenshi spell uses real payment and casting")
 expect(e.priority==1 and e.stack.size()==1,"casting hands the unresolved spell to the opponent")
 var snapshot=flow.capture();var revision=e.revision
 ticks(flow)
 expect(e.priority==0 and e.stack.size()==1,"blocking shortcut passes a spell response outside combat")
 expect(flow.opponent.counts.is_empty() and flow.opponent.blocking.is_empty(),"spell response does not consume or start a blocking decision")
 expect(e.revision==revision+1,"shortcut submits exactly one response while waiting for the student")
 if e.priority==0:
  expect(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty(),"student resolves the first spell")
  ticks(flow)
  expect(spell.zone=="grave" and e.players[1].life<20 and e.stack.is_empty(),"first spell deals real damage and finishes")
  revision=e.revision;ticks(flow)
  expect(e.revision==revision and e.phase=="main","shortcut leaves an idle main phase to the student")
 expect(flow.reset_task() and flow.adapter.entity("spell").zone=="hand" and flow.opponent.counts.is_empty(),"task reset restores spell, payment and blocking allowance")
 expect(flow.restore(snapshot),"spell-response checkpoint restores")
 ticks(flow)
 expect(e.priority==0 and flow.opponent.counts.is_empty(),"restored spell response continues without consuming blocking allowance")
 flow.free()

func _initialize():
 validation();choices_and_order();fallback_and_legality();preview_and_gates();repeat_limit();spell_responses()
 print("TUTORIAL BLOCK PRIORITIES: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
