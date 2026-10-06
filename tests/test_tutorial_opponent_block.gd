extends SceneTree
## Conditional blocking uses the real combat choice and survives checkpoints.
const Config=preload("res://scripts/tutorial/config.gd")
const Runtime=preload("res://scripts/tutorial/runtime.gd")
const Store=preload("res://scripts/deck_store.gd")
var failures: Array=[]

func expect(ok: bool,label: String) -> bool:
 if not ok:failures.append(label);print("TUTORIAL BLOCK FAILED: ",label)
 return ok

func ticks(flow,count: int=16):
 for i in range(count):flow.tick()

func fixture(selected: Array=[{"alias":"blocker"}]) -> Dictionary:
 return {"schema_version":1,"id":"conditional_block","title":"条件阻挡","initial_scenario":"board","start_step":"practice","completion":{"type":"always"},
  "scenarios":{"board":{"seed":42,"players":[
   {"leader":{"card_id":"70"},"deck_order":[{"card_id":"53"}],"field":[{"card_id":"53","alias":"attacker"},{"card_id":"53","alias":"second_attacker"}]},
   {"leader":{"card_id":"70"},"deck_order":[{"card_id":"53"}],"field":[{"card_id":"53","alias":"blocker"},{"card_id":"53","alias":"second_blocker"}]}
  ],"opponent":{"strategy":"rules","rules":[
   {"id":"pass","event":"state_changed","when":{"type":"priority","value":1},"action":"pass_priority","max_times":30},
   {"id":"block","event":"state_changed","when":{"type":"all","conditions":[{"type":"pending","kind":"block","owner":1},{"type":"combat_attacker","alias":"attacker"}]},"action":{"type":"block","cards":selected},"max_times":1}
  ]}}},
  "steps":{"practice":{"type":"task","guide":{"text":"攻击后观察人机阻挡。","popup":"hidden","next_button":"hidden"},"task":{"success":{"type":"life","player":0,"value":0,"op":"le"}},"next":"$complete"},
   "dialogue":{"type":"info","guide":{"text":"讲解时暂停对手。"},"next":"practice"}}
 }

func start(data: Dictionary):
 var flow=Runtime.new()
 if not expect(flow.start(data,Store.CARDS).is_empty(),"fixture starts: "+flow.last_error):flow.free();return null
 return flow

func attack_to_choice(flow,alias: String="attacker") -> bool:
 var e=flow.adapter.engine
 if not expect(flow.adapter.submit(0,{"name":"attack","args":[int(flow.adapter.entity(alias).uid),{},[]]}).is_empty(),"real attack accepted"):return false
 ticks(flow)
 if not expect(flow.running and e.priority==0 and e.combat.get("step","")=="attack_window","opponent passes attack response"):return false
 if not expect(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty(),"player resolves attack window"):return false
 return expect(e.pending.get("kind","")=="block" and e.pending.owner==1,"engine offers opponent blocking choice")

func settle(flow):
 for i in range(24):
  ticks(flow)
  var e=flow.adapter.engine
  if e.combat.is_empty() or not flow.running:return
  if e.pending.is_empty() and e.priority==0:expect(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty(),"player passes combat response")

func check_validation():
 var data=fixture()
 expect(Config.new().validate(JSON.parse_string(JSON.stringify(data)),Store.CARDS).ok,"JSON action and conditions validate")
 for action in ["block",{"type":"unknown"},{"type":"block"},{"type":"block","cards":null},{"type":"block","cards":[1]},{"type":"block","cards":[{"uid":1}]},{"type":"block","cards":[{"alias":"missing"}]},{"type":"block","cards":[{"alias":"blocker"},{"alias":"blocker"}]},{"type":"pass_priority","cards":[]},{"type":"block","cards":[],"extra":true}]:
  var invalid=data.duplicate(true);invalid.scenarios.board.opponent.rules[1].action=action
  var checked=Config.new().validate(invalid,Store.CARDS)
  expect(not checked.ok and str(checked.errors).contains("opponent.rules.1.action"),"reject malformed block action "+str(action))
 for condition in [{"type":"pending","kind":"unknown","owner":1},{"type":"pending","kind":"block","owner":0.5},{"type":"combat_attacker","alias":"missing"}]:
  var invalid=data.duplicate(true);invalid.scenarios.board.opponent.rules[1].when=condition
  expect(not Config.new().validate(invalid,Store.CARDS).ok,"reject invalid combat condition "+str(condition))
 var structured=data.duplicate(true);structured.scenarios.board.opponent.rules[0].action={"type":"pass_priority"}
 expect(Config.new().validate(structured,Store.CARDS).ok,"structured pass remains supported")
 var deck=Config.new().load_file("res://data/tutorial/beginner/t1.json",Store.CARDS).data
 for condition in [{"type":"pending","kind":"block","owner":1},{"type":"combat_attacker","alias":"missing"}]:
  var invalid=deck.duplicate(true);invalid.steps[invalid.start_step]={"type":"task","guide":{"text":"非法战场条件"},"task":{"timing":"enter","success":condition},"next":"$complete"}
  expect(not Config.new().validate(invalid,Store.CARDS).ok,"deck scene rejects combat conditions")

func check_block_and_restore():
 var flow=start(fixture())
 if flow==null:return
 if not attack_to_choice(flow):flow.free();return
 var snapshot=flow.capture();var e=flow.adapter.engine
 expect(flow.adapter.evaluate({"type":"pending","kind":"block","owner":1},[]) and not flow.adapter.evaluate({"type":"pending","kind":"block","owner":0},[]),"pending condition distinguishes defender")
 expect(flow.adapter.evaluate({"type":"combat_attacker","alias":"attacker"},[]) and not flow.adapter.evaluate({"type":"combat_attacker","alias":"second_attacker"},[]),"attacker condition uses the named instance")
 ticks(flow)
 expect(flow.running and e.pending.is_empty() and e.combat.blocked and e.combat.blockers==[e.ref_target(flow.adapter.entity("blocker"))],"later block rule runs despite preceding pass rule")
 expect(flow.opponent.counts.get("block",0)==1 and flow.adapter.entity("blocker").tapped,"real block taps the selected defender once")
 settle(flow)
 expect(e.combat.is_empty() and e.players[1].life==20 and flow.adapter.entity("attacker").zone=="grave" and flow.adapter.entity("blocker").zone=="grave","blocking resolves real unit combat without player damage")
 expect(flow.reset_task() and flow.adapter.engine.combat.is_empty() and flow.opponent.counts.get("block",0)==0,"task reset restores the pre-attack board")
 expect(flow.restore(snapshot),"checkpoint restores pending blocking choice")
 expect(flow.opponent.counts.get("block",0)==0 and not flow.adapter.entity("blocker").tapped,"checkpoint restores count and blocker state")
 ticks(flow)
 expect(flow.running and flow.opponent.counts.get("block",0)==1 and flow.adapter.engine.combat.blocked,"restored queued event blocks again")
 flow.free()

func check_multiple_and_decline():
 var flow=start(fixture([{"alias":"blocker"},{"alias":"second_blocker"}]))
 if flow!=null:
  if attack_to_choice(flow):
   ticks(flow)
   expect(flow.running and flow.adapter.engine.combat.blockers.size()==2 and flow.adapter.entity("blocker").tapped and flow.adapter.entity("second_blocker").tapped,"multiple specified units block")
  flow.free()
 var data=fixture([]);data.scenarios.board.opponent.rules[1].when={"type":"pending","kind":"block","owner":1}
 flow=start(data)
 if flow==null:return
 if attack_to_choice(flow):
  ticks(flow)
  expect(flow.running and flow.adapter.engine.pending.is_empty() and not flow.adapter.engine.combat.blocked and flow.opponent.counts.get("block",0)==1,"empty list explicitly declines blocking")
  settle(flow)
  expect(flow.adapter.engine.players[1].life==19,"declined block deals real spirit damage")
  if attack_to_choice(flow,"second_attacker"):
   ticks(flow)
   expect(flow.running and flow.adapter.engine.pending.get("kind","")=="block" and flow.opponent.counts.get("block",0)==1,"max_times prevents repeated block decisions")
 flow.free()

func check_gates_and_errors():
 var flow=start(fixture())
 if flow==null:return
 ticks(flow)
 expect(flow.opponent.counts.get("block",0)==0,"block does not run before combat")
 if attack_to_choice(flow):
  var before=flow.capture()
  flow.enter("dialogue");ticks(flow)
  expect(flow.opponent.counts.get("block",0)==0 and flow.adapter.engine.pending.get("kind","")=="block","dialogue pauses pending opponent block")
  expect(flow.next(),"dialogue resumes practice");ticks(flow)
  expect(flow.opponent.counts.get("block",0)==1,"queued block resumes after dialogue")
  flow.restore(before)
  flow.opponent.config.rules[1].action.cards=[{"alias":"attacker"}]
  var revision=flow.adapter.engine.revision;ticks(flow)
  expect(not flow.running and flow.last_error.contains("opponent.rules.block.action.cards") and flow.adapter.engine.revision==revision and flow.opponent.counts.get("block",0)==0,"illegal opposing unit is rejected without mutation or consuming count")
 flow.free()
 var data=fixture();data.scenarios.board.players[1].field[0].state={"tapped":true}
 flow=start(data)
 if flow!=null:
  if attack_to_choice(flow):
   ticks(flow)
   expect(not flow.running and flow.last_error.contains("blocker 当前不能阻挡") and flow.opponent.counts.get("block",0)==0,"tapped blocker is rejected by real legality")
  flow.free()

func check_condition_and_choice_owner():
 var flow=start(fixture())
 if flow!=null:
  if attack_to_choice(flow,"second_attacker"):
   ticks(flow)
   expect(flow.running and flow.adapter.engine.pending.get("kind","")=="block" and flow.opponent.counts.get("block",0)==0,"nonmatching attacker keeps the blocking choice open")
  flow.free()
 var data=fixture();data.scenarios.board.active=1;data.scenarios.board.priority=1
 data.scenarios.board.opponent.rules=data.scenarios.board.opponent.rules.slice(1)
 data.scenarios.board.opponent.rules[0].when={"type":"always"}
 flow=start(data)
 if flow==null:return
 expect(flow.adapter.submit(1,{"name":"attack","args":[int(flow.adapter.entity("blocker").uid),{},[]]}).is_empty(),"opponent attacks through the real gateway")
 expect(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty(),"defending player passes")
 expect(flow.adapter.submit(1,{"name":"pass_priority","args":[]}).is_empty(),"attacking opponent passes")
 ticks(flow)
 expect(flow.running and flow.adapter.engine.pending.get("kind","")=="block" and flow.adapter.engine.pending.owner==0 and flow.opponent.counts.get("block",0)==0,"opponent cannot submit the player's blocking choice")
 flow.free()
 data=fixture();data.scenarios.board.opponent.rules[0].event="priority_changed";data.scenarios.board.opponent.rules[0].action={"type":"pass_priority"}
 flow=start(data)
 if flow!=null:
  if attack_to_choice(flow):
   ticks(flow)
   expect(flow.running and flow.opponent.counts.get("block",0)==1,"different pass and block events coexist")
  flow.free()

func check_menace_legality():
 var data=fixture();data.scenarios.board.players[0].field[0].card_id="character-fdn-068"
 var flow=start(data)
 if flow!=null:
  if attack_to_choice(flow):
   var revision=flow.adapter.engine.revision;ticks(flow)
   expect(not flow.running and flow.last_error.contains("opponent.rules.block.action") and flow.adapter.engine.revision==revision and flow.opponent.counts.get("block",0)==0,"real engine rejects a single blocker against menace without mutation")
  flow.free()
 data=fixture([{"alias":"blocker"},{"alias":"second_blocker"}]);data.scenarios.board.players[0].field[0].card_id="character-fdn-068"
 flow=start(data)
 if flow!=null:
  if attack_to_choice(flow):
   ticks(flow)
   expect(flow.running and flow.adapter.engine.combat.blockers.size()==2,"two blockers satisfy real menace rules")
  flow.free()

func _initialize():
 check_validation()
 check_block_and_restore()
 check_multiple_and_decline()
 check_gates_and_errors()
 check_condition_and_choice_owner()
 check_menace_legality()
 if failures.is_empty():print("TUTORIAL CONDITIONAL OPPONENT BLOCK PASS")
 quit(0 if failures.is_empty() else 1)
