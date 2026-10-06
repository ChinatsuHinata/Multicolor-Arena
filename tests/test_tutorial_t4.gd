extends SceneTree
const Config=preload("res://scripts/tutorial/config.gd")
const Runtime=preload("res://scripts/tutorial/runtime.gd")
const Store=preload("res://scripts/deck_store.gd")

var failures: Array=[]
var checks=0

func expect(ok: bool,label: String):
 checks+=1
 if not ok:
  failures.append(label)
  push_error(label)

func check_demo(data: Dictionary,id: String):
 var copy=data.duplicate(true)
 copy.start_step=id
 copy.initial_scenario=copy.steps[id].scenario
 copy.completion={"type":"always"}
 var flow=Runtime.new()
 var reason=flow.start(copy,Store.CARDS)
 expect(reason.is_empty(),id+" starts: "+reason)
 if reason.is_empty():
  var checked_flower_blast=false
  var checked_ghost_sacrifice=false
  var checked_ghost_response=false
  var engine_at_start=flow.adapter.engine
  if id=="a_feather":
   var target=flow.adapter.entity("target")
   expect(target.uid==engine_at_start.players[1].leader.uid and target.card_id=="character-rei-001" and target.zone=="field",id+" starts with the opponent's four-cost deck leader Reimu")
  elif id=="a_day_drink":
   var target=flow.adapter.entity("target")
   expect(target.uid==engine_at_start.players[1].leader.uid and target.card_id=="character-ucs-067" and target.zone=="field",id+" starts with six-cost leader Remilia")
  elif id=="a_unsheathe":
   expect(engine_at_start.players[0].field.is_empty() and flow.adapter.entity("own_yuyuko").zone=="leader",id+" starts with an empty friendly battlefield and uncast Yuyuko")
  elif id=="a_blood":
   expect(flow.adapter.entity("own_eirin").uid==engine_at_start.players[0].leader.uid and flow.adapter.entity("own_eirin").zone=="field",id+" starts with deck leader Eirin on the battlefield")
   expect(flow.adapter.entity("enemy_leader_tenshi").uid==engine_at_start.players[1].leader.uid and flow.adapter.entity("enemy_big").zone=="field" and flow.adapter.entity("enemy_captain").zone=="field",id+" starts with five-cost deck leader Tenshi, seven-cost Tenshi and the captain")
  for i in range(300):
   if not flow.playing_sequence():break
   flow.tick(0.1)
   if id=="a_flower" and flow.sequence.index==3 and not checked_flower_blast:
    checked_flower_blast=true
    var reimu=flow.adapter.entity("enemy_reimu")
    expect(reimu.zone=="field" and reimu.damage==3 and not reimu.tapped,id+" leaves four-health Reimu standing at one health")
    expect(flow.adapter.entity("enemy_flandre").zone=="grave" and flow.adapter.entity("enemy_momiji").zone=="grave",id+" removes Flandre and two-cost Momiji")
   if id=="a_ghost":
    var engine=flow.adapter.engine
    var sacrifice=engine.stack.any(func(entry):return entry.get("effect","")=="token_sacrifice")
    var response=engine.stack.any(func(entry):return entry.get("effect","")=="kaguya_end")
    if sacrifice and not response and not checked_ghost_sacrifice:
     checked_ghost_sacrifice=true
     expect(engine.phase=="end" and engine.delayed.is_empty(),id+" puts the sacrifice ability on the stack at the end step")
    if sacrifice and response and not checked_ghost_response:
     checked_ghost_response=true
     expect(flow.adapter.entity("kaguya").tapped and engine.stack.back().get("effect","")=="kaguya_end",id+" taps Kaguya in response above the sacrifice ability")
  expect(flow.running and not flow.playing_sequence(),id+" finishes: "+flow.last_error)
  if flow.running and not flow.playing_sequence():
   var engine=flow.adapter.engine
   expect(engine.pending.is_empty(),id+" clears every required choice")
   expect(flow.adapter.entity("spell").zone in ["grave","exile"],id+" resolves its spell")
   match id:
    "a_wings":
     var bats=engine.players[0].field.filter(func(c):return c.card_id=="token-kmo-027")
     expect(bats.size()==2,id+" creates two bats")
     if bats.size()==2:expect(engine.stat(bats[0],"power")==2,id+" bats receive Remilia's bonus")
    "a_door":expect(flow.adapter.entity("seven_tenshi").zone=="field",id+" puts seven-cost Tenshi on the battlefield")
    "a_ghost":
     var imps=engine.players[0].field.filter(func(c):return c.card_id.begins_with("roster_token_imp"))
     expect(imps.size()==1,id+" leaves the imp after Kaguya ends the turn")
     if imps.size()==1:expect(engine.stat(imps[0],"power")==7,id+" creates a 7/7/7 imp")
     expect(checked_ghost_sacrifice and checked_ghost_response,id+" demonstrates the end-step response timing")
     expect(engine.delayed.is_empty() and engine.stack.is_empty(),id+" removes the sacrifice ability without postponing it")
    "a_feather":expect(flow.adapter.entity("target").zone=="hand",id+" chooses hand instead of the leader zone after Reimu leaves")
    "a_day_drink":expect(flow.adapter.entity("target").zone=="leader",id+" destroys six-cost Remilia and completes her return choice")
    "a_unsheathe":
     var targets=["enemy_big_tenshi","enemy_small_tenshi","enemy_element_bottle","enemy_gohei","enemy_larva"]
     expect(targets.all(func(alias):return flow.adapter.entity(alias).zone=="exile"),id+" exiles the complete enemy battlefield")
     for i in range(6):expect(flow.adapter.entity("enemy_keystone_"+str(i)).is_empty(),id+" removes the exiled keystone token "+str(i))
     expect(flow.adapter.entity("own_yuyuko").zone=="leader" and engine.players[0].field.is_empty(),id+" leaves uncast Yuyuko in the leader zone")
    "a_blood":
     expect(flow.adapter.entity("own_blue").zone=="field" and flow.adapter.entity("own_eirin").zone=="field",id+" keeps Ran and revives Eirin")
     expect(flow.adapter.entity("hourai_medicine").is_empty() and flow.adapter.entity("blue_flower").zone=="hand",id+" sacrifices Hourai medicine and retrieves Blue Flower on Eirin's entry")
     expect(flow.adapter.entity("enemy_big").zone=="field" and flow.adapter.entity("enemy_leader_tenshi").zone=="leader" and flow.adapter.entity("enemy_captain").zone=="grave",id+" keeps seven-cost Tenshi and resolves the other sacrifices")
    "a_unknown":expect(flow.adapter.entity("target").zone=="grave",id+" removes its target with hand-size damage")
    "a_flower":
     expect(checked_flower_blast,id+" checked the board after Flower")
     expect(flow.adapter.entity("enemy_reimu").zone=="leader",id+" taps and deals the final point to Reimu")
     expect(flow.adapter.entity("own_tenshi").zone=="field" and flow.adapter.entity("own_tenshi").attacked,id+" attacks with five-cost Tenshi")
     expect(engine.combat.is_empty() and engine.players[1].life==17,id+" finishes the attack")
    "a_divine_play":expect(engine.players[0].palette.size()==3,id+" adds one palette card")
    "a_stream":expect(engine.players[0].palette.size()==6,id+" adds two palette cards")
  flow.free()

func check_course(data: Dictionary):
 var flow=Runtime.new()
 var reason=flow.start(data,Store.CARDS)
 expect(reason.is_empty(),"course starts from its catalog entry: "+reason)
 if reason.is_empty():
  var stalled=0
  for i in range(1000):
   if flow.finished or not flow.running:break
   var before=flow.current_step+":"+str(flow.sequence.index)
   if flow.playing_sequence():flow.tick(0.1)
   elif flow.answering():flow.submit_answer("mist",flow.epoch)
   else:flow.next()
   if before==flow.current_step+":"+str(flow.sequence.index):stalled+=1
   else:stalled=0
   if stalled>40:
    failures.append("course stuck at "+flow.current_step+" sequence="+str(flow.sequence.index)+" error="+flow.last_error)
    break
  expect(flow.finished and flow.last_error.is_empty(),"complete course walkthrough: "+flow.last_error)
  expect(flow.completed_steps.size()==data.steps.size(),"walkthrough visits every lesson step")
 flow.free()

func _initialize():
 var loaded=Config.new().load_file("res://data/tutorial/beginner/t4.json",Store.CARDS)
 expect(loaded.ok,"T4 validates: "+str(loaded.errors))
 if loaded.ok:
  for id in loaded.data.steps:
   if loaded.data.steps[id].has("sequence"):check_demo(loaded.data,id)
  check_course(loaded.data)
 print("TUTORIAL T4: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
