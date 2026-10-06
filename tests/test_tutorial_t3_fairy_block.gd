extends SceneTree
## Only plays the fairy attack through the opponent's blocking choice.
const Runtime=preload("res://scripts/tutorial/runtime.gd")
const Store=preload("res://scripts/deck_store.gd")

func _initialize():
 var source=JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial/beginner/t3.json"))
 var lesson={"schema_version":1,"id":"t3_fairy_block_only","title":"妖精攻击阻挡专项","initial_scenario":"final_puzzle","start_step":"attack","completion":{"type":"always"},"scenarios":{"final_puzzle":source.scenarios.final_puzzle},"steps":{"attack":{"type":"task","guide":{"text":"宣告攻击。"},"task":{"success":{"type":"life","player":1,"value":0,"op":"le"}},"next":"$complete"}}}
 var flow=Runtime.new()
 var reason=flow.start(lesson,Store.CARDS)
 if reason.is_empty():
  var fairy=flow.adapter.entity("vampire_fairy")
  var seiga=flow.adapter.entity("enemy_seiga")
  reason=flow.adapter.submit(0,{"name":"attack","args":[int(fairy.uid),{},[]]})
  if reason.is_empty():
   for i in range(24):
    flow.tick()
    if flow.adapter.engine.priority==0:break
   if flow.adapter.engine.priority!=0:reason="对手未让过攻击响应"
   else:reason=flow.adapter.submit(0,{"name":"pass_priority","args":[]})
  if reason.is_empty():
   for i in range(24):
    flow.tick()
    if flow.opponent.counts.get("block_vampire_fairy_with_seiga",0)>0:break
   var combat=flow.adapter.engine.combat
   if flow.opponent.counts.get("block_vampire_fairy_with_seiga",0)!=1 or not combat.get("blocked",false) or combat.get("blockers",[])!=[flow.adapter.engine.ref_target(seiga)]:reason="霍青娥没有阻挡吸血鬼妖精"
 print("T3 FAIRY BLOCK: "+("PASS" if reason.is_empty() else "FAIL: "+reason))
 flow.free()
 quit(0 if reason.is_empty() else 1)
