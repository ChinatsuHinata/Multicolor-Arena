extends SceneTree
const Config=preload("res://scripts/tutorial/config.gd")
const Runtime=preload("res://scripts/tutorial/runtime.gd")
const Store=preload("res://scripts/deck_store.gd")
var failures: Array=[]
var checks=0

func expect(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);push_error(label)

func pass_action(player: int) -> Dictionary:
 return {"type":"pass_priority","player":player}

func fixture() -> Dictionary:
 return {"schema_version":1,"id":"sequence","title":"固定演示","initial_scenario":"board","start_step":"demo","completion":{"type":"always"},
  "scenarios":{"board":{"seed":42,"phase":"prepare","players":[
   {"leader":{"card_id":"70"},"deck_order":[{"card_id":"53"}],"hand":[{"card_id":"70","alias":"possess_hand"},{"card_id":"96","alias":"spell0"}],"palette":[{"card_id":"70","alias":"palette0"},{"card_id":"53"}],"field":[{"card_id":"53","alias":"attacker"},{"card_id":"35","alias":"source0"}],"grave":[{"card_id":"53","alias":"grave0"}]},
   {"leader":{"card_id":"70"},"deck_order":[{"card_id":"53"}],"hand":[{"card_id":"96","alias":"spell1"}],"palette":[{"card_id":"70"},{"card_id":"53"}],"field":[{"card_id":"53","alias":"blocker"},{"card_id":"35","alias":"source1"}],"grave":[{"card_id":"53","alias":"grave1"}]}
  ],"opponent":{"strategy":"rules","rules":[{"id":"unwanted","event":"state_changed","when":{"type":"priority","value":1},"action":"pass_priority","max_times":100}]}}},
  "steps":{"demo":{"type":"info","guide":{"text":"观察双方的固定操作。"},"sequence":{"actions":[
   pass_action(0),pass_action(1),{"type":"possession","player":0,"palette":{"alias":"palette0"},"hand":{"alias":"possess_hand"}},pass_action(0),pass_action(1),
   {"type":"cast","player":0,"card":{"alias":"spell0"},"target":{"alias":"source1"}},pass_action(1),pass_action(0),
   pass_action(0),{"type":"cast","player":1,"card":{"alias":"spell1"},"target":{"alias":"source0"}},pass_action(0),pass_action(1),
   {"type":"ability","player":0,"source":{"alias":"source0"},"key":"exile_grave","target":{"alias":"grave1"}},pass_action(1),pass_action(0),
   pass_action(0),{"type":"ability","player":1,"source":{"alias":"source1"},"key":"exile_grave","target":{"alias":"grave0"}},pass_action(0),pass_action(1),
   {"type":"attack","player":0,"card":{"alias":"attacker"}},pass_action(1),pass_action(0),{"type":"block","player":1,"cards":[{"alias":"blocker"}]},pass_action(0),pass_action(1),pass_action(0),pass_action(1)
  ]},"next":"done"},"done":{"type":"info","guide":{"text":"演示完成。"},"next":"$complete"}}
 }

func start(data: Dictionary,cards: Dictionary=Store.CARDS):
 var flow=Runtime.new()
 var reason=flow.start(JSON.parse_string(JSON.stringify(data)),cards)
 expect(reason.is_empty(),"starts: "+reason)
 return flow

func settle(flow):
 for i in range(800):
  if not flow.playing_sequence():break
  flow.tick(0.1)
 expect(flow.running and not flow.playing_sequence(),"sequence completes: "+flow.last_error)

func check_validation():
 var data=fixture()
 expect(Config.new().validate(data,Store.CARDS).ok,"real sequence config validates")
 for value in [null,{},[],{"actions":[]},{"actions":[{"type":"unknown","player":0}]},{"actions":[{"type":"pass_priority","player":0.5}]},{"actions":[{"type":"delay","seconds":-1}]},{"actions":[{"type":"possession","player":0,"hand":{"alias":"possess_hand"}}]},{"actions":[{"type":"attack","player":0,"card":{"alias":"missing"}}]},{"actions":[pass_action(0)],"random_results":[{"type":"d6","value":7}]},{"actions":[pass_action(0)],"random_results":[{"type":"coin","value":2}]},{"actions":[pass_action(0)],"random_results":[{"type":"coin","value":0.5}]},{"actions":[pass_action(0)],"extra":true}]:
  var invalid=data.duplicate(true);invalid.steps.demo.sequence=value
  var checked=Config.new().validate(invalid,Store.CARDS)
  expect(not checked.ok and str(checked.errors).contains("steps.demo.sequence"),"reject malformed sequence "+str(value))
 for guide in [{"text":"自动","next_button":"auto"},{"text":"隐藏","popup":"hidden"}]:
  var invalid=data.duplicate(true);invalid.steps.demo.guide=guide
  expect(not Config.new().validate(invalid,Store.CARDS).ok,"demonstration requires a visible manual dialogue after completion")
 var deck=Config.new().load_file("res://data/tutorial/beginner/t1.json",Store.CARDS).data
 deck.steps[deck.start_step].sequence={"actions":[{"type":"delay","seconds":1}]}
 expect(not Config.new().validate(deck,Store.CARDS).ok,"deck scene rejects battle sequence")

func check_real_sequence():
 var flow=start(fixture())
 if not flow.running:flow.free();return
 var status=[];flow.sequence_changed.connect(func(playing):status.append(playing))
 expect(flow.playing_sequence() and not flow.next() and not flow.can_replay_sequence(),"cannot skip or replay during playback")
 var held=[true];flow.presentation_busy=func():return held[0]
 var revision=flow.adapter.engine.revision
 flow.tick();expect(flow.sequence.index==0 and flow.adapter.engine.revision==revision,"presentation gate holds the first command")
 held[0]=false
 for i in range(80):
  if flow.sequence.index==8:break
  flow.tick(0.1)
 var middle=flow.capture()
 settle(flow)
 var e=flow.adapter.engine
 expect(flow.current_step=="demo" and flow.completed_steps.is_empty() and status==[false],"completion stays on dialogue and reports finished playback")
 expect(flow.adapter.entity("possess_hand").zone=="palette" and flow.adapter.entity("palette0").zone=="hand","real possession swaps the prescribed instances")
 expect(flow.adapter.entity("spell0").zone=="grave" and flow.adapter.entity("spell1").zone=="grave" and flow.adapter.entity("source0").damage==2 and flow.adapter.entity("source1").damage==2,"both seats cast and resolve real targeted spells")
 expect(flow.adapter.entity("grave0").zone=="exile" and flow.adapter.entity("grave1").zone=="exile" and e.players[0].life==20 and e.players[1].life==20,"both activated abilities resolve their specified targets")
 expect(e.combat.is_empty() and flow.adapter.entity("attacker").zone=="grave" and flow.adapter.entity("blocker").zone=="grave","prescribed attack and block resolve real combat")
 expect(flow.opponent.counts.is_empty() and flow.opponent.events.is_empty(),"normal opponent rules do not interleave scripted moves")
 var final_game=flow.adapter.capture().game
 expect(flow.restore(middle) and flow.sequence.index==8,"mid-play checkpoint resumes exact action cursor")
 settle(flow);expect(flow.adapter.capture().game==final_game,"resuming a partial demonstration produces the same final state")
 expect(flow.replay_sequence() and flow.sequence.index==0 and flow.adapter.entity("spell0").zone=="hand" and flow.adapter.entity("attacker").zone=="field","replay restores original entrance instead of partial checkpoint")
 settle(flow);expect(flow.adapter.capture().game==final_game,"replay reproduces all rule state and real costs")
 expect(flow.next() and flow.current_step=="done" and not flow.can_replay_sequence(),"next advances after viewing demonstration")
 expect(flow.previous() and flow.playing_sequence() and flow.sequence.index==0,"previous replays the demonstration from its entrance")
 flow.free()

func random_fixture() -> Dictionary:
 var data=fixture();data.scenarios.board.phase="main"
 data.scenarios.board.players[0].field=[{"card_id":"character-lof-001","alias":"die_source","state":{"courage":2,"leader_counters":1}}]
 data.steps.demo.sequence={"actions":[{"type":"ability","player":0,"source":{"alias":"die_source"},"key":"courage_die","target":{"alias":"blocker"}},pass_action(1),pass_action(0)],"random_results":[{"type":"d6","value":6}]}
 return data

func check_randomness():
 var flow;var data;var final_game
 for die in [1,6]:
  data=random_fixture();data.steps.demo.sequence.random_results[0].value=die
  flow=start(data)
  if not flow.running:flow.free();continue
  var seed_state=flow.adapter.engine.rng.state
  flow.tick();var middle=flow.capture()
  expect(flow.adapter.engine.stack.back().die==die,"prescribed D6 is placed in the actual stack object")
  settle(flow)
  expect(flow.adapter.engine.rng.state==seed_state and flow.adapter.engine.random_cursor==1,"fixed D6 consumes its declared result without consuming RNG")
  expect(flow.adapter.engine.history.any(func(entry):return entry.text=="D6 · %d" % die),"D6 announces the predetermined value")
  final_game=flow.adapter.capture().game
  expect(flow.restore(middle),"checkpoint restores an already-consumed die result")
  settle(flow);expect(flow.adapter.capture().game==final_game,"resuming after D6 preserves the stack outcome and result cursor")
  expect(flow.replay_sequence(),"D6 demonstration can replay")
  settle(flow);expect(flow.adapter.capture().game==final_game,"D6 outcome remains identical on replay")
  flow.free()
 # Main-phase entry creates Koishi's actual mandatory coin trigger.
 for coin in [0,1]:
  data=fixture();data.scenarios.board.players[0].field=[{"card_id":"73","alias":"coin_source"}]
  data.steps.demo.sequence={"actions":[pass_action(0),pass_action(1),{"type":"possession","player":0},pass_action(0),pass_action(1),pass_action(1),pass_action(0)],"random_results":[{"type":"coin","value":coin}]}
  flow=start(data)
  if not flow.running:flow.free();continue
  settle(flow)
  expect(flow.adapter.engine.history.any(func(entry):return entry.text.contains("掷硬币 · "+("正面" if coin==1 else "反面"))),"real trigger receives the prescribed coin face")
  expect(flow.adapter.entity("coin_source").tapped==(coin==0) and flow.adapter.engine.stat(flow.adapter.entity("coin_source"),"spirit")== (3 if coin==1 else 1),"coin result changes the real trigger effect")
  final_game=flow.adapter.capture().game
  expect(flow.replay_sequence(),"coin demonstration can replay")
  settle(flow);expect(flow.adapter.capture().game==final_game,"coin trigger and buff reproduce exactly")
  flow.free()
 for results in [[],[{"type":"coin","value":1}],[{"type":"d6","value":6},{"type":"d6","value":1}]]:
  data=random_fixture();data.steps.demo.sequence.random_results=results
  flow=start(data)
  for i in range(100):
   if not flow.running:break
   flow.tick(0.1)
  expect(not flow.running and flow.last_error.contains("sequence.random_results"),"missing, mismatched and surplus random results fail explicitly")
  flow.free()
 var ordinary=preload("res://scripts/rules/duel_engine.gd").new(Store.CARDS)
 var tutorial_duel=preload("res://scripts/tutorial/scripted_duel.gd").new(Store.CARDS)
 ordinary.rng.seed=777;tutorial_duel.rng.seed=777
 var identical=true
 for i in range(16):
  identical=identical and ordinary.roll_coin()==tutorial_duel.roll_coin() and ordinary.roll_die()==tutorial_duel.roll_die()
 expect(identical and ordinary.rng.state==tutorial_duel.rng.state,"outside playback normal RNG behavior remains unchanged")

func check_entry_choice():
 var data=fixture();data.scenarios.board.phase="main"
 data.scenarios.board.players[0].hand=[{"card_id":"character-fdn-068","alias":"lily"}]
 data.scenarios.board.players[0].palette=[{"card_id":"35"}]
 data.steps.demo.sequence={"actions":[{"type":"cast","player":0,"card":{"alias":"lily"}},pass_action(1),pass_action(0),{"type":"choose_effect","player":0,"target":{"color":"红"}},pass_action(1),pass_action(0)]}
 var flow=start(data)
 if flow.running:
  settle(flow)
  expect(flow.adapter.entity("lily").zone=="field" and "红" in flow.adapter.entity("lily").get("color_counters",[]),"prescribed entry choice uses the real Lily color selection")
  var final_game=flow.adapter.capture().game
  expect(flow.replay_sequence(),"entry choice demonstration resets")
  settle(flow);expect(flow.adapter.capture().game==final_game,"entry choice replays without prompting the player")
 flow.free()

func check_delay_and_illegal_move():
 var paced=fixture();paced.steps.demo.sequence={"actions":[pass_action(0),pass_action(1)]}
 var paced_flow=start(paced);paced_flow.tick(0.1)
 expect(paced_flow.sequence.index==1,"sequence submits the first action")
 paced_flow.tick(0.1)
 expect(paced_flow.sequence.index==1,"sequence leaves a short pause between actions")
 var held=[true];paced_flow.presentation_busy=func():return held[0]
 paced_flow.tick(1.0)
 expect(paced_flow.sequence.index==1 and paced_flow.sequence.delay_remaining>0,"presentation work holds the pause")
 held[0]=false
 paced_flow.tick(0.1);paced_flow.tick(0.1)
 expect(paced_flow.sequence.index==2,"next action resumes after the pause")
 settle(paced_flow);paced_flow.free()
 var data=fixture();data.steps.demo.sequence={"actions":[{"type":"delay","seconds":0.5},pass_action(0)]}
 var flow=start(data);flow.tick(0.1)
 for i in range(3):flow.tick(0.1)
 expect(flow.sequence.index==1 and flow.adapter.engine.priority==0,"delay preserves the board before the next command")
 settle(flow);expect(flow.adapter.engine.priority==1,"prescribed action follows delay")
 flow.free()
 data=fixture();data.steps.demo.sequence={"actions":[{"type":"cast","player":1,"card":{"alias":"spell0"}}]}
 flow=start(data);var revision=flow.adapter.engine.revision;flow.tick()
 expect(not flow.running and flow.last_error.contains("actions.0") and flow.adapter.engine.revision==revision,"illegal seat or timing stops without inventing a move")
 flow.free()

func _initialize():
 check_validation();check_real_sequence();check_randomness();check_entry_choice();check_delay_and_illegal_move()
 print("TUTORIAL SEQUENCE: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
