extends SceneTree
const Runtime=preload("res://scripts/tutorial/runtime.gd")
const Store=preload("res://scripts/deck_store.gd")
var failures=[]
var checks=0

func expect(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);push_error(label)

func isolated_lesson() -> Dictionary:
 var source=JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial/beginner/t3.json"))
 var crystal_step=source.steps.a5_crystal.duplicate(true)
 crystal_step.next="$complete"
 return {"schema_version":1,"id":"t3_crystal_only","title":"结晶演示专项","initial_scenario":"crystal","start_step":"a5_crystal","completion":{"type":"always"},"scenarios":{"crystal":source.scenarios.crystal},"steps":{"a5_crystal":crystal_step}}

func finish_sequence(flow):
 for i in range(1000):
  if not flow.playing_sequence():break
  flow.tick(0.1)
 expect(flow.running and not flow.playing_sequence(),"结晶固定动作播放完成："+flow.last_error)
 if not flow.running:return
 var fairy=flow.adapter.entity("crystal_fairy")
 var spent=flow.adapter.entity("spent_black")
 var reserved=flow.adapter.entity("spent_red")
 expect(fairy.zone=="palette" and not fairy.tapped,"妖精竖直进入颜色盘")
 expect(spent.zone=="grave" and reserved.zone=="palette" and reserved.tapped,"仅指定的横置费用进入墓地")

func _initialize():
 var flow=Runtime.new()
 var reason=flow.start(isolated_lesson(),Store.CARDS)
 expect(reason.is_empty(),"结晶演示独立启动："+reason)
 if reason.is_empty():
  finish_sequence(flow)
  expect(flow.can_replay_sequence(),"结晶演示可重新播放")
  if flow.can_replay_sequence():
   flow.replay_sequence()
   finish_sequence(flow)
 flow.free()
 print("T3 CRYSTAL: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
