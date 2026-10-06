extends SceneTree
## Scripted cards and activated abilities retain real timing, targets and costs.
const Config=preload("res://scripts/tutorial/config.gd")
const Runtime=preload("res://scripts/tutorial/runtime.gd")
const Store=preload("res://scripts/deck_store.gd")
var failures: Array=[]

func expect(ok: bool,label: String) -> bool:
 if not ok:failures.append(label);print("TUTORIAL ACTION FAILED: ",label)
 return ok

func ticks(flow,count: int=12):
 for i in range(count):flow.tick()

func fixture(action: Dictionary={"type":"cast","card":{"alias":"enemy_spell"},"target":{"alias":"student_target"}}) -> Dictionary:
 return {"schema_version":1,"id":"opponent_actions","title":"条件出牌与能力","initial_scenario":"board","start_step":"practice","completion":{"type":"always"},
  "scenarios":{"board":{"seed":42,"active":0,"priority":1,"players":[
   {"leader":{"card_id":"70"},"deck_order":[{"card_id":"53"},{"card_id":"53"}],"field":[{"card_id":"35","alias":"student_target"},{"card_id":"53","alias":"other_target"}],"grave":[{"card_id":"53","alias":"student_grave"}]},
   {"leader":{"card_id":"70"},"deck_order":[{"card_id":"53"},{"card_id":"53"}],"hand":[{"card_id":"96","alias":"enemy_spell"},{"card_id":"96","alias":"duplicate_spell"},{"card_id":"53","alias":"hand_unit"}],"field":[{"card_id":"35","alias":"enemy_source"},{"card_id":"53","alias":"enemy_unit"}],"palette":[{"card_id":"70","alias":"red_resource"},{"card_id":"53","alias":"yellow_resource"}],"grave":[{"card_id":"21","alias":"grave_source"}]}
  ],"opponent":{"strategy":"rules","rules":[{"id":"scripted","event":"step_entered","when":{"type":"priority","value":1},"action":action,"max_times":1}]}}},
  "steps":{"practice":{"type":"task","guide":{"text":"等待对手动作。","popup":"hidden","next_button":"hidden"},"task":{"success":{"type":"life","player":0,"value":0,"op":"le"}},"next":"$complete"},"dialogue":{"type":"info","guide":{"text":"讲解暂停对手。"},"next":"practice"}}
 }

func start(data: Dictionary,cards: Dictionary=Store.CARDS):
 var flow=Runtime.new()
 if not expect(flow.start(JSON.parse_string(JSON.stringify(data)),cards).is_empty(),"fixture starts: "+flow.last_error):flow.free();return null
 return flow

func resolve_one(flow):
 var e=flow.adapter.engine
 expect(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty(),"player passes response")
 expect(flow.adapter.submit(1,{"name":"pass_priority","args":[]}).is_empty(),"opponent resolves through gateway")

func check_validation():
 var data=fixture()
 expect(Config.new().validate(JSON.parse_string(JSON.stringify(data)),Store.CARDS).ok,"JSON cast configuration validates")
 for action in [{"type":"cast"},{"type":"cast","card":{"alias":"missing"}},{"type":"cast","card":{"card_id":"missing"}},{"type":"cast","card":{"alias":"enemy_spell","card_id":"96"}},{"type":"cast","card":{"uid":1}},{"type":"ability","source":{"alias":"enemy_source"}},{"type":"ability","source":{"alias":"enemy_source"},"index":0.5},{"type":"ability","source":{"alias":"enemy_source"},"index":-1},{"type":"ability","source":{"alias":"enemy_source"},"key":""},{"type":"ability","source":{"alias":"enemy_source"},"key":"exile_grave","index":0},{"type":"ability","source":{"card_id":"35"},"key":"exile_grave"}]:
  var invalid=data.duplicate(true);invalid.scenarios.board.opponent.rules[0].action=action
  var checked=Config.new().validate(invalid,Store.CARDS)
  expect(not checked.ok and str(checked.errors).contains("opponent.rules.0.action"),"reject malformed action "+str(action))
 for target in [{"alias":"missing"},{"uid":1,"epoch":1},{"alias":"student_target","player":0},{"player":0.5},{"none":false},{"none":1},{"x":0.5},{"stack":{"alias":"missing"}},{"picks":[1]},{"picks":[[{"alias":"missing"}]]},{"parts":[]},{"parts":[{"uid":1}]},{"sacrifice":{"alias":"missing"}}]:
  var invalid=data.duplicate(true);invalid.scenarios.board.opponent.rules[0].action.target=target
  var checked=Config.new().validate(invalid,Store.CARDS)
  expect(not checked.ok and str(checked.errors).contains(".action.target"),"reject malformed target "+str(target))

func check_cast_and_checkpoint():
 var flow=start(fixture())
 if flow==null:return
 var initial=flow.capture();var e=flow.adapter.engine
 ticks(flow)
 expect(flow.running and e.stack.size()==1 and e.stack[0].kind=="card" and e.stack[0].target==e.ref_target(flow.adapter.entity("student_target")),"casts exact hand instance at exact unit")
 expect(flow.adapter.entity("enemy_spell").zone=="stack" and flow.adapter.entity("duplicate_spell").zone=="hand" and flow.opponent.counts.get("scripted",0)==1,"same-card duplicate is not substituted and success counted once")
 expect(flow.adapter.entity("red_resource").tapped and flow.adapter.entity("yellow_resource").tapped,"real color payment is spent")
 resolve_one(flow)
 expect(flow.adapter.entity("student_target").damage==2 and flow.adapter.entity("other_target").damage==0 and flow.adapter.entity("enemy_spell").zone=="grave","real spell resolves on selected target")
 expect(flow.reset_task() and flow.adapter.entity("enemy_spell").zone=="hand" and not flow.adapter.entity("red_resource").tapped and flow.opponent.counts.get("scripted",0)==0,"reset restores card, resources and rule count")
 ticks(flow)
 expect(flow.opponent.counts.get("scripted",0)==1,"restored step event casts again")
 flow.restore(initial);ticks(flow)
 expect(flow.running and flow.opponent.counts.get("scripted",0)==1,"explicit checkpoint replays original action")
 flow.free()
 flow=start(fixture({"type":"cast","card":{"card_id":"96"},"target":{"player":0}}))
 if flow!=null:
  ticks(flow);expect(flow.adapter.entity("enemy_spell").zone=="stack" and flow.adapter.entity("duplicate_spell").zone=="hand","definition selector deterministically uses first matching hand card")
  resolve_one(flow);expect(flow.adapter.engine.players[0].life==18,"player target uses real damage")
  flow.adapter.engine.start_turn(1);flow.enter("practice");ticks(flow)
  expect(flow.adapter.entity("duplicate_spell").zone=="hand" and flow.opponent.counts.get("scripted",0)==1,"max_times prevents an affordable duplicate from being used")
  flow.free()
 var data=fixture({"type":"cast","card":{"alias":"hand_unit"}});data.scenarios.board.active=1
 flow=start(data)
 if flow!=null:
  ticks(flow);expect(flow.running and flow.adapter.entity("hand_unit").zone=="stack","targetless unit casts during opponent main phase")
  resolve_one(flow);expect(flow.adapter.entity("hand_unit").zone=="field","targetless unit enters through real resolution")
  flow.free()

func check_unaffordable_and_retry():
 var data=fixture();data.scenarios.board.players[1].palette[0].state={"tapped":true}
 var flow=start(data)
 if flow==null:return
 var e=flow.adapter.engine;var revision=e.revision;ticks(flow)
 expect(flow.running and e.revision==revision and e.stack.is_empty() and flow.opponent.counts.get("scripted",0)==0 and not flow.adapter.entity("yellow_resource").tapped,"unaffordable spell is skipped without mutation or consuming count")
 # A real new turn resets resources; entering the task supplies a retry event.
 e.start_turn(1);flow.enter("practice");ticks(flow)
 expect(flow.running and flow.adapter.entity("enemy_spell").zone=="stack" and flow.opponent.counts.get("scripted",0)==1,"future event can retry an affordable action")
 flow.free()
 data=fixture();data.scenarios.board.players[1].palette[0].state={"tapped":true}
 data.scenarios.board.phase="prepare"
 data.scenarios.board.opponent.rules.append({"id":"fallback","event":"step_entered","when":{"type":"priority","value":1},"action":"pass_priority","max_times":1})
 flow=start(data)
 if flow!=null:
  ticks(flow);expect(flow.running and flow.opponent.counts.get("scripted",0)==0 and flow.opponent.counts.get("fallback",0)==1 and flow.adapter.engine.priority==0,"unaffordable action permits a later pass rule")
  flow.free()

func check_availability_and_pause():
 for change in ["wrong_owner","wrong_zone","wrong_timing","unavailable_target","false_condition"]:
  var data=fixture()
  match change:
   "wrong_owner":data.scenarios.board.opponent.rules[0].action.card={"alias":"student_target"}
   "wrong_zone":data.scenarios.board.opponent.rules[0].action.card={"alias":"grave_source"}
   "wrong_timing":data.scenarios.board.opponent.rules[0].action.card={"alias":"hand_unit"}
   "unavailable_target":data.scenarios.board.opponent.rules[0].action.target={"alias":"student_grave"}
   "false_condition":data.scenarios.board.opponent.rules[0].when={"type":"life","player":0,"value":5,"op":"le"}
  var flow=start(data)
  if flow!=null:
   var revision=flow.adapter.engine.revision;ticks(flow)
   expect(flow.running and flow.adapter.engine.revision==revision and flow.opponent.counts.get("scripted",0)==0,"unavailable action stays idle: "+change)
   flow.free()
 var data=fixture();data.start_step="dialogue"
 var flow=start(data)
 if flow!=null:
  ticks(flow);expect(flow.adapter.engine.stack.is_empty() and flow.opponent.counts.is_empty(),"dialogue holds queued cast")
  flow.next();ticks(flow);expect(flow.opponent.counts.get("scripted",0)==1,"cast resumes when practice opens")
  flow.free()

func check_extension_abilities():
 var flow=start(fixture({"type":"ability","source":{"alias":"enemy_source"},"key":"exile_grave","target":{"alias":"student_grave"}}))
 if flow!=null:
  ticks(flow)
  expect(flow.running and flow.adapter.entity("enemy_source").tapped and flow.adapter.engine.stack.size()==1 and flow.adapter.engine.stack[0].effect=="exile_grave","specific extension ability really activates and taps source")
  resolve_one(flow)
  expect(flow.adapter.entity("student_grave").zone=="exile" and flow.adapter.engine.players[0].life==19 and flow.adapter.engine.players[1].life==21,"specified grave target resolves real ability")
  flow.free()
 for affordable in [false,true]:
  var data=fixture({"type":"ability","source":{"alias":"grave_source"},"key":"grave_return"})
  if not affordable:data.scenarios.board.players[1].palette[0].state={"tapped":true}
  flow=start(data)
  if flow!=null:
   var revision=flow.adapter.engine.revision;ticks(flow)
   if affordable:
    expect(flow.running and flow.adapter.engine.stack.size()==1,"grave ability uses its registered activation zone")
    resolve_one(flow);expect(flow.adapter.entity("grave_source").zone=="hand","targetless paid extension resolves")
   else:expect(flow.running and flow.adapter.engine.revision==revision and flow.opponent.counts.get("scripted",0)==0,"unaffordable ability skips without consuming count")
   flow.free()
 flow=start(fixture({"type":"ability","source":{"alias":"enemy_source"},"key":"grave_return"}))
 if flow!=null:
  ticks(flow);expect(flow.running and flow.opponent.counts.get("scripted",0)==0,"ability outside required zone is skipped")
  flow.free()
 flow=start(fixture({"type":"ability","source":{"alias":"enemy_source"},"key":"sacrifice_buff","target":{"alias":"enemy_unit"}}))
 if flow!=null:
  ticks(flow);expect(not flow.running and flow.last_error.contains("key：指定来源没有该启动能力") and flow.opponent.counts.get("scripted",0)==0,"cannot invoke another card's extension key")
  flow.free()

func check_indexed_abilities():
 var cards=Store.CARDS.duplicate(true)
 cards["53"].abilities=[{"实现":"activated_damage","参数":{"数值":1,"费用":{},"横置":false}},{"实现":"activated_damage","参数":{"数值":3,"费用":{"黄":1},"横置":true}}]
 for affordable in [false,true]:
  var data=fixture({"type":"ability","source":{"alias":"enemy_unit"},"index":1,"target":{"player":0}})
  if not affordable:
   for card in data.scenarios.board.players[1].palette:card.state={"tapped":true}
  var flow=start(data,cards)
  if flow==null:continue
  var revision=flow.adapter.engine.revision;ticks(flow)
  if affordable:
   expect(flow.running and flow.adapter.entity("enemy_unit").tapped and flow.adapter.engine.stack.size()==1 and flow.adapter.engine.stack[0].amount==3,"selects the exact indexed ability and pays its activation")
   resolve_one(flow);expect(flow.adapter.engine.players[0].life==17,"indexed ability resolves on the specified player")
  else:expect(flow.running and flow.adapter.engine.revision==revision and flow.opponent.counts.get("scripted",0)==0 and not flow.adapter.entity("enemy_unit").tapped,"unaffordable indexed ability leaves source untouched")
  flow.free()

func check_grouped_targets():
 var data=fixture({"type":"ability","source":{"alias":"enemy_source"},"key":"item-fdn-044","target":{"picks":[[{"alias":"grave_source"}]]}})
 data.scenarios.board.players[1].field[0].card_id="item-fdn-044"
 var flow=start(data)
 if flow!=null:
  ticks(flow)
  var picked=flow.adapter.engine.stack[0].target.picks[0][0]
  expect(flow.running and flow.opponent.counts.get("scripted",0)==1 and picked.uid==flow.adapter.entity("grave_source").uid and picked.epoch==flow.adapter.entity("grave_source").epoch,"grouped targets preserve the real selection specification")
  resolve_one(flow);expect(flow.adapter.entity("grave_source").zone=="deck" and flow.adapter.engine.players[1].life==21,"specified grouped ability target resolves")
  flow.free()

func check_modes_parts_and_epoch():
 var data=fixture({"type":"ability","source":{"alias":"enemy_source"},"key":"item-lof-009","target":{"picks":[[{"alias":"fairy_cost"}],[{"alias":"enemy_unit","mode":"重置"}]]}})
 data.scenarios.board.players[1].field[0].card_id="item-lof-009"
 data.scenarios.board.players[1].field[1].state={"tapped":true}
 data.scenarios.board.players[1].field.append({"card_id":"character-fdn-068","alias":"fairy_cost"})
 var flow=start(data)
 if flow!=null:
  ticks(flow)
  expect(flow.running and flow.opponent.counts.get("scripted",0)==1 and flow.adapter.entity("fairy_cost").zone=="grave","selected ability pays its specified sacrifice")
  resolve_one(flow);expect(not flow.adapter.entity("enemy_unit").tapped and flow.adapter.entity("enemy_source").tapped,"selected ability mode resets only its specified target")
  flow.free()
 data=fixture({"type":"cast","card":{"alias":"enemy_spell"},"target":{"parts":[{"alias":"enemy_unit"},{"alias":"other_target"}]}})
 data.scenarios.board.players[1].hand[0].card_id="98"
 data.scenarios.board.players[1].palette=[{"card_id":"167"},{"card_id":"164"}]
 flow=start(data)
 if flow!=null:
  ticks(flow);expect(flow.running and flow.opponent.counts.get("scripted",0)==1,"specific paired spell targets compile against real options")
  resolve_one(flow);expect(flow.adapter.entity("enemy_unit").zone=="hand" and flow.adapter.entity("other_target").zone=="hand" and flow.adapter.entity("student_target").zone=="field","paired targets resolve without choosing other units")
  flow.free()
 flow=start(fixture())
 if flow!=null:
  var card=flow.adapter.entity("student_target");var old_epoch=card.epoch
  flow.adapter.engine.move_to(card,"grave",false);flow.adapter.engine.move_to(card,"field",false)
  ticks(flow)
  expect(flow.running and card.epoch>old_epoch and flow.adapter.engine.stack[0].target==flow.adapter.engine.ref_target(card),"alias targeting uses current epoch after real zone changes")
  flow.free()

func check_variable_payment_and_ambiguity():
 for affordable in [false,true]:
  var data=fixture({"type":"cast","card":{"alias":"enemy_spell"},"target":{"player":0,"x":2}})
  data.scenarios.board.active=1;data.scenarios.board.players[1].hand[0].card_id="111"
  data.scenarios.board.players[1].palette=[{"card_id":"167"},{"card_id":"167"},{"card_id":"164"}]
  if affordable:data.scenarios.board.players[1].palette.append({"card_id":"164"})
  var flow=start(data)
  if flow==null:continue
  var revision=flow.adapter.engine.revision;ticks(flow)
  if affordable:
   expect(flow.running and flow.opponent.counts.get("scripted",0)==1 and flow.adapter.engine.stack[0].target.x==2,"declared X is normalized from JSON and paid in full")
   resolve_one(flow);expect(flow.adapter.engine.players[0].hand.size()==2,"declared X spell resolves for the selected player")
  else:expect(flow.running and flow.adapter.engine.revision==revision and flow.opponent.counts.get("scripted",0)==0 and flow.adapter.engine.players[1].palette.all(func(c):return not c.tapped),"cannot afford declared X even when minimum cost is affordable")
  flow.free()
 var data=fixture({"type":"cast","card":{"alias":"enemy_spell"},"target":{"player":0}})
 data.scenarios.board.active=1;data.scenarios.board.players[1].hand[0].card_id="111"
 data.scenarios.board.players[1].palette=[{"card_id":"167"},{"card_id":"167"},{"card_id":"164"},{"card_id":"164"}]
 var flow=start(data)
 if flow!=null:
  ticks(flow);expect(not flow.running and flow.last_error.contains("target：目标存在多种选择") and flow.opponent.counts.get("scripted",0)==0,"ambiguous X does not choose another declaration automatically")
  flow.free()

func check_stack_targets_and_deferred_choices():
 var data=fixture({"type":"cast","card":{"alias":"enemy_spell"},"target":{"stack":{"alias":"student_target"}}})
 data.scenarios.board.priority=0;data.scenarios.board.players[1].hand[0].card_id="123"
 data.scenarios.board.opponent.rules[0].event="state_changed"
 var flow=start(data)
 if flow!=null:
  var source=flow.adapter.entity("student_target")
  var options=flow.adapter.engine.activation_options(source,"exile_grave").filter(func(option):return option.get("uid",-1)==flow.adapter.entity("grave_source").uid)
  if not expect(not options.is_empty(),"player ability has the intended legal grave target"):flow.free();return
  var reason=flow.adapter.submit(0,{"name":"commit_extension","args":[int(source.uid),options[0],[],"exile_grave"]})
  if not expect(reason.is_empty(),"player declares a real ability to counter: "+reason):flow.free();return
  var stack_id=flow.adapter.engine.stack[0].id;ticks(flow)
  expect(flow.running and flow.opponent.counts.get("scripted",0)==1 and flow.adapter.engine.stack.back().target=={"stack_id":stack_id},"stack alias selects an ability from its exact source")
  resolve_one(flow);expect(flow.adapter.engine.stack.is_empty() and flow.adapter.entity("grave_source").zone=="grave","specified ability is countered before resolving")
  flow.free()
 data=fixture({"type":"cast","card":{"alias":"enemy_spell"},"target":{"stack":{"alias":"student_spell"}}})
 data.scenarios.board.priority=0;data.scenarios.board.players[1].hand[0].card_id="136"
 data.scenarios.board.players[1].palette=[{"card_id":"166"},{"card_id":"164"}]
 data.scenarios.board.players[0].hand=[{"card_id":"96","alias":"student_spell"}]
 data.scenarios.board.players[0].palette=[{"card_id":"70"},{"card_id":"53"}]
 data.scenarios.board.opponent.rules[0].event="state_changed"
 flow=start(data)
 if flow!=null:
  var e=flow.adapter.engine;var card=flow.adapter.entity("student_spell")
  expect(flow.adapter.submit(0,{"name":"commit_cast","args":[int(card.uid),e.ref_target(flow.adapter.entity("enemy_unit")),e.payment(0,e.cast_cost(0,card)).plan]}).is_empty(),"player casts a real targeted spell to counter")
  var stack_id=e.stack[0].id;ticks(flow)
  expect(flow.running and flow.opponent.counts.get("scripted",0)==1 and e.stack.back().target=={"stack_id":stack_id},"stack alias selects the specified card use")
  resolve_one(flow);expect(e.stack.is_empty() and flow.adapter.entity("enemy_unit").damage==0,"specified spell is countered before damaging its target")
  flow.free()
 data=fixture();data.scenarios.board.active=1
 flow=start(data)
 if flow!=null:
  var e=flow.adapter.engine
  expect(flow.adapter.submit(1,{"name":"attack","args":[int(flow.adapter.entity("enemy_unit").uid),{},[]]}).is_empty(),"opponent declares a real attack")
  expect(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty() and flow.adapter.submit(1,{"name":"pass_priority","args":[]}).is_empty(),"attack window reaches player-owned block choice")
  ticks(flow)
  expect(flow.running and e.pending.get("owner",-1)==0 and e.stack.is_empty() and flow.opponent.counts.get("scripted",0)==0,"cast waits for a player's mandatory choice")
  expect(flow.adapter.submit(0,{"name":"block","args":[[]]}).is_empty(),"player completes block choice")
  ticks(flow);expect(flow.running and flow.opponent.counts.get("scripted",0)==1 and flow.adapter.entity("enemy_spell").zone=="stack","deferred cast resumes after the choice")
  flow.free()

func _initialize():
 check_validation()
 check_cast_and_checkpoint()
 check_unaffordable_and_retry()
 check_availability_and_pause()
 check_extension_abilities()
 check_indexed_abilities()
 check_grouped_targets()
 check_modes_parts_and_epoch()
 check_variable_payment_and_ambiguity()
 check_stack_targets_and_deferred_choices()
 if failures.is_empty():print("TUTORIAL CONDITIONAL CAST AND ABILITY PASS")
 quit(0 if failures.is_empty() else 1)
