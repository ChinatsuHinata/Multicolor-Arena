extends SceneTree
const Config=preload("res://scripts/tutorial/config.gd")
const Runtime=preload("res://scripts/tutorial/runtime.gd")
const Sequence=preload("res://scripts/tutorial/sequence.gd")
const Store=preload("res://scripts/deck_store.gd")
var failures=[]
var checks=0

func expect(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);push_error(label)

func lesson() -> Dictionary:
 return Config.new().load_file("res://data/tutorial/beginner/t3.json",Store.CARDS)

func check_sequences(data: Dictionary):
 for id in ["a1","a3","a4","a5","a6","a7","a8"]:
  var copy=data.duplicate(true)
  copy.start_step=id
  copy.initial_scenario=copy.steps[id].scenario
  copy.completion={"type":"always"}
  var flow=Runtime.new()
  var reason=flow.start(copy,Store.CARDS)
  expect(reason.is_empty(),id+" starts: "+reason)
  if reason.is_empty():
   for i in range(1000):
    if not flow.playing_sequence():break
    flow.tick(0.1)
   expect(flow.running and not flow.playing_sequence(),id+" resolves: "+flow.last_error)
   if flow.running and not flow.playing_sequence():
    var e=flow.adapter.engine
    match id:
     "a1":expect(flow.adapter.entity("fairy_attacker").zone=="field" and flow.adapter.entity("toki_blocker").zone=="field" and flow.adapter.entity("fairy_attacker").damage==0 and flow.adapter.entity("toki_blocker").damage==0,"a1 both survive and heal at turn end")
     "a3":expect(flow.adapter.entity("cloud_annihilate").zone=="grave" and e.players[1].life<20,"a3 annihilation damages blocker and player")
     "a4":expect(not flow.adapter.entity("brave_titan").tapped,"a4 brave resets Titan")
     "a5":expect(flow.adapter.entity("himekaidou").zone=="field" and e.players[1].life<20,"a5 haste attacks on entry turn")
     "a6":expect(flow.adapter.entity("remilia_attacker").zone=="grave" and flow.adapter.entity("cloud_blocker").damage==0,"a6 first strike kills Remilia before retaliation")
     "a7":expect(e.players[1].life<20,"a7 menace deals player damage without a second blocker")
     "a8":expect(flow.adapter.entity("kosuzu").zone=="grave","a8 human Kosuzu blocks exorcise")
  flow.free()

func check_damage_task(data: Dictionary):
 var copy=data.duplicate(true)
 copy.start_step="r1"
 copy.initial_scenario="damage_task"
 copy.completion={"type":"always"}
 var flow=Runtime.new()
 var reason=flow.start(copy,Store.CARDS)
 expect(reason.is_empty(),"damage task starts: "+reason)
 if reason.is_empty():
  var action={"type":"attack","player":0,"card":{"alias":"titan"}}
  var prepared=Sequence.prepare(flow.adapter,action,0)
  expect(prepared.available,"Titan attack is legal")
  if prepared.available:expect(flow.adapter.submit(0,prepared.command).is_empty(),"Titan attack submits")
  var assigned=false
  for i in range(100):
   if flow.current_step!="r1" or not flow.running:break
   flow.tick()
   var e=flow.adapter.engine
   if e.pending.get("kind","")=="damage_assignment" and not assigned:
    var allocation={str(flow.adapter.entity("cloud").uid):4,str(flow.adapter.entity("larva").uid):1}
    expect(flow.adapter.submit(0,{"name":"combat_damage","args":[allocation]}).is_empty(),"damage assignment submits")
    assigned=true
   elif e.pending.is_empty() and e.priority==0 and not e.combat.is_empty():
    flow.adapter.submit(0,{"name":"pass_priority","args":[]})
  expect(assigned and flow.current_step=="d14" and flow.adapter.entity("cloud").zone=="grave" and flow.adapter.entity("larva").zone=="field","correct allocation completes task")
 flow.free()
 var retry=Runtime.new()
 reason=retry.start(copy,Store.CARDS)
 expect(reason.is_empty(),"damage retry starts: "+reason)
 if reason.is_empty():
  var rejected=[]
  retry.task_failed.connect(func(message):rejected.append(message))
  var move=Sequence.prepare(retry.adapter,{"type":"attack","player":0,"card":{"alias":"titan"}},0)
  if move.available:retry.adapter.submit(0,move.command)
  for i in range(100):
   if not rejected.is_empty() or not retry.running:break
   retry.tick()
   var e=retry.adapter.engine
   if e.pending.get("kind","")=="damage_assignment":
    var wrong={str(retry.adapter.entity("cloud").uid):0,str(retry.adapter.entity("larva").uid):5}
    retry.adapter.submit(0,{"name":"combat_damage","args":[wrong]})
   elif e.pending.is_empty() and e.priority==0 and not e.combat.is_empty():
    retry.adapter.submit(0,{"name":"pass_priority","args":[]})
  expect(not rejected.is_empty() and retry.current_step=="r1" and retry.adapter.entity("cloud").zone=="field" and retry.adapter.entity("larva").zone=="field","wrong allocation resets the task")
 retry.free()

func check_scenarios(data: Dictionary):
 for id in ["damage_task","leader_task","final_puzzle"]:
  var copy=data.duplicate(true)
  var step="r1" if id=="damage_task" else "r2" if id=="leader_task" else "r3"
  copy.start_step=step
  copy.initial_scenario=id
  copy.completion={"type":"always"}
  var flow=Runtime.new()
  var reason=flow.start(copy,Store.CARDS)
  expect(reason.is_empty(),id+" starts: "+reason)
  flow.free()

func check_final_reset(data: Dictionary):
 var copy=data.duplicate(true)
 copy.start_step="r3";copy.initial_scenario="final_puzzle";copy.completion={"type":"always"}
 var flow=Runtime.new()
 var reason=flow.start(copy,Store.CARDS)
 expect(reason.is_empty(),"final puzzle starts for reset: "+reason)
 if reason.is_empty():
  var engine=flow.adapter.engine
  var original_life=engine.players[0].life
  var original_damage=flow.adapter.entity("cute_reimu").damage
  engine.players[0].life=1
  flow.adapter.entity("cute_reimu").damage=original_damage+1
  expect(flow.reset_task(),"final puzzle reset is accepted")
  expect(flow.adapter.engine==engine and flow.current_step=="r3" and flow.adapter.scenario_id=="final_puzzle","final puzzle reset reuses its engine and scene")
  expect(engine.players[0].life==original_life and flow.adapter.entity("cute_reimu").damage==original_damage,"final puzzle reset restores life and unit state")
 flow.free()

func _initialize():
 var loaded=lesson()
 expect(loaded.ok,"T3 validates: "+str(loaded.errors))
 if loaded.ok:
  check_sequences(loaded.data)
  check_scenarios(loaded.data)
  check_damage_task(loaded.data)
  check_final_reset(loaded.data)
 print("TUTORIAL T3: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
