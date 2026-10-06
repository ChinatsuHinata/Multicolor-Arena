extends SceneTree
const Config = preload("res://scripts/tutorial/config.gd")
const Runtime = preload("res://scripts/tutorial/runtime.gd")
const Store = preload("res://scripts/deck_store.gd")

func settle(e):
 for i in range(30):
  if e.stack.is_empty() and e.combat.is_empty():return
  if not e.pending.is_empty():return
  e.pass_priority(e.priority)

func check_possession_task(flow,notices: Array,scenario: String,step: String,palette_alias: String,hand_alias: String,expected_step: String,should_fail: bool) -> String:
 var reason=flow.load_scenario(scenario)
 if not reason.is_empty():return reason
 var e=flow.adapter.engine
 for i in range(8):
  if e.phase=="possession":break
  e.pass_priority(e.priority)
 if e.phase!="possession" or e.pending.get("kind","")!="possession":return "T2 POSSESSION PHASE NOT REACHED: "+scenario
 flow.adapter.reset_observation()
 flow.enter(step)
 if flow.current_step!=step:return "T2 POSSESSION TASK DID NOT START: "+step
 notices.clear()
 var palette=flow.adapter.entity(palette_alias)
 var hand=e.players[0].hand.back() if hand_alias=="@drawn_aurora" else flow.adapter.entity(hand_alias)
 if hand_alias=="@drawn_aurora" and hand.card_id!="143":return "T2 DRAWN AURORA MISSING: "+scenario
 reason=flow.adapter.submit(0,{"name":"possession","args":[palette.uid,hand.uid]})
 if not reason.is_empty():return "T2 POSSESSION REJECTED: "+reason
 flow.tick()
 if should_fail:
  if notices.size()!=1 or flow.current_step!=step:return "T2 WRONG POSSESSION DID NOT FAIL: "+step+" / "+hand_alias
  if flow.adapter.entity(palette_alias).zone!="palette" or e.find_card(hand.uid).zone!="hand" or e.players[0].possession_count!=0 or not e.tutorial_turn_end_blocked:
   return "T2 WRONG POSSESSION DID NOT RESTORE: "+step+" / "+hand_alias
 else:
  if not notices.is_empty() or flow.current_step!=expected_step or e.tutorial_turn_end_blocked:return "T2 CORRECT POSSESSION DID NOT ADVANCE: "+step
 return ""

func _initialize():
 var loaded=Config.new().load_file("res://data/tutorial/beginner/t2.json",Store.CARDS)
 if not loaded.ok:
  for item in loaded.errors:print(item)
  quit(1)
  return
 print("T2 CONFIG VALID")
 var flow=Runtime.new()
 var reason=flow.start(loaded.data,Store.CARDS)
 if not reason.is_empty():
  print(reason)
  quit(1)
  return
 print("T2 START VALID: "+flow.current_step)
 var allowed_course=loaded.data.duplicate(true)
 allowed_course.steps.r2.task.allow_turn_end=true
 var allowed_flow=Runtime.new()
 var permission_reason=allowed_flow.start(allowed_course,Store.CARDS)
 if permission_reason.is_empty():permission_reason=allowed_flow.load_scenario("first_main")
 if not permission_reason.is_empty():
  print("T2 TURN END OVERRIDE INVALID: "+permission_reason)
  quit(1)
  return
 allowed_flow.enter("r2")
 var allowed_engine=allowed_flow.adapter.engine
 if not allowed_flow.allows_turn_end() or allowed_engine.tutorial_turn_end_blocked:
  print("T2 EXPLICIT TURN END OVERRIDE WAS NOT APPLIED")
  quit(1)
  return
 allowed_engine.pass_priority(0)
 allowed_engine.pass_priority(1)
 if allowed_engine.phase!="end":
  print("T2 EXPLICIT TURN END OVERRIDE DID NOT ADVANCE THE PHASE")
  quit(1)
  return
 allowed_flow.free()
 for id in ["d2","r1"]:
  if not flow.next() or flow.current_step!=id:
   print("T2 STEP ERROR: "+id)
   quit(1)
   return
 var night=flow.adapter.entity("night_king")
 var fire=flow.adapter.entity("fire_person")
 var wing_before=flow.adapter.entity("wing")
 var opening=flow.adapter.engine
 if flow.submit_mulligan_selection([night.uid,wing_before.uid]) or flow.current_step!="r1" or opening.phase!="mulligan":
  print("T2 WRONG SELECTION CHANGED THE OPENING")
  quit(1)
  return
 if not flow.submit_mulligan_selection([fire.uid,night.uid]) or flow.current_step!="d3" or opening.phase!="prepare" or not opening.players[0].mulligan_done:
  print("T2 CORRECT MULLIGAN FAILED: "+flow.last_error)
  quit(1)
  return
 if flow.adapter.entity("night_king").zone!="deck" or flow.adapter.entity("fire_person").zone!="deck" or opening.players[0].hand.size()!=4:
  print("T2 MULLIGAN DID NOT REPLACE TWO CARDS")
  quit(1)
  return
 print("T2 REAL MULLIGAN COMPLETED")
 for id in ["d4","d6","d7"]:
  if not flow.next() or flow.current_step!=id:
   print("T2 OPENING STEP FAILED: "+id)
   quit(1)
   return
 print("T2 FIRST MAIN: "+flow.current_step+" / "+flow.adapter.scenario_id)
 var first=flow.adapter.engine
 var lily=flow.adapter.entity("lily_black")
 if not first.cast_error(0,lily.uid).is_empty():
  print("T2 LILY NOT CASTABLE: "+first.cast_error(0,lily.uid))
  quit(1)
  return
 var red_check=loaded.data.steps.r2.task.success
 if flow.adapter.evaluate(red_check,[]):
  print("T2 COLOR TASK PASSED BEFORE PLAY")
  quit(1)
  return
 var notices=[]
 flow.task_failed.connect(func(message):notices.append(message))
 for check in [
  ["second_main","r3","black_resource","wing","d12",true],
  ["second_main","r3","black_resource","@drawn_aurora","d12",true],
  ["second_main","r3","black_resource","remilia_one","d12",false],
  ["third_main","r5","new_resource","@drawn_aurora","d16",true],
  ["third_main","r5","remilia_one","remilia_two","d16",true],
  ["third_main","r5","new_resource","remilia_two","d16",false]
 ]:
  reason=check_possession_task(flow,notices,check[0],check[1],check[2],check[3],check[4],check[5])
  if not reason.is_empty():
   print(reason)
   quit(1)
   return
 print("T2 WRONG POSSESSION FAILS AND RESTORES IMMEDIATELY")
 for id in ["second_main","third_main"]:
  reason=flow.load_scenario(id)
  if not reason.is_empty():
   print(reason)
   quit(1)
   return
  print("T2 SCENARIO VALID: "+id)
  if id=="second_main":
   var second=flow.adapter.engine
   if not flow.adapter.evaluate(red_check,[]):
    print("T2 RED COLOR COUNTER NOT RESTORED")
    quit(1)
    return
   var wing=flow.adapter.entity("wing")
   if second.cast_error(0,wing.uid).is_empty():
    print("T2 WING CASTABLE BEFORE RED RESOURCE")
    quit(1)
    return
   var red=flow.adapter.entity("remilia_one")
   var black=flow.adapter.entity("black_resource")
   second.pending={"kind":"possession","owner":0}
   second.possession(black.uid,red.uid)
   second.phase="main"
   if not second.cast_error(0,wing.uid).is_empty():
    print("T2 WING NOT CASTABLE AFTER POSSESSION: "+second.cast_error(0,wing.uid))
    quit(1)
    return
   print("T2 WING CASTABLE AFTER POSSESSION")
   var wing_plan=second.payment(0,second.cast_cost(0,wing)).plan
   var wing_target=second.targets_for(wing.card_id,0,wing.uid)[0]
   var wing_reason=second.commit_cast(0,wing.uid,wing_target,wing_plan)
   if not wing_reason.is_empty():
    print("T2 WING CAST FAILED: "+wing_reason)
    quit(1)
    return
   settle(second)
   if flow.adapter.entity("wing").zone!="grave" or second.players[0].field.size()!=3:
    print("T2 WING DID NOT CREATE THE TWO BATS")
    quit(1)
    return
   var lily_attacker=flow.adapter.entity("lily_black")
   if not second.can_attack(0,lily_attacker.uid):
    print("T2 LILY CANNOT ATTACK ON SECOND TURN")
    quit(1)
    return
   second.attack(0,lily_attacker.uid)
   settle(second)
   if second.players[1].life>19:
    print("T2 SECOND TURN ATTACK DID NOT LAND")
    quit(1)
    return
   print("T2 SECOND TURN ATTACK LANDED")
 var e=flow.adapter.engine
 var remilia=flow.adapter.entity("remilia_two")
 var resource=flow.adapter.entity("new_resource")
 e.pending={"kind":"possession","owner":0}
 e.possession(resource.uid,remilia.uid)
 e.phase="main"
 if e.cast_error(0,flow.adapter.entity("remilia_leader").uid)!="":
  print("T2 REMILIA NOT CASTABLE: "+e.cast_error(0,flow.adapter.entity("remilia_leader").uid))
  quit(1)
  return
 print("T2 REMILIA CASTABLE")
 var leader=flow.adapter.entity("remilia_leader")
 var cast_plan=e.payment(0,e.cast_cost(0,leader)).plan
 var cast_reason=e.commit_cast(0,leader.uid,{},cast_plan)
 if not cast_reason.is_empty():
  print("T2 REMILIA CAST FAILED: "+cast_reason)
  quit(1)
  return
 settle(e)
 if flow.adapter.entity("remilia_leader").zone!="field":
  print("T2 REMILIA DID NOT ENTER FIELD")
  quit(1)
  return
 for alias in ["lily_black","bat_one","bat_two"]:
  var attacker=flow.adapter.entity(alias)
  if not e.can_attack(0,attacker.uid):
   print("T2 ATTACKER CANNOT ATTACK: "+alias)
   quit(1)
   return
  e.attack(0,attacker.uid)
  settle(e)
 if e.players[1].life>13:
  print("T2 ATTACK TARGET NOT MET: "+str(e.players[1].life))
  quit(1)
  return
 print("T2 ATTACK TARGET MET: "+str(e.players[1].life))
 flow.free()
 quit()
