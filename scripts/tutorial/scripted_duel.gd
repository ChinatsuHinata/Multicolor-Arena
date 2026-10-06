extends "res://scripts/rules/duel_engine.gd"
## Tutorial-only match settlement and scripted random results.
var scripted_random=false
var random_results: Array=[]
var random_cursor=0
var random_error=""
var advance_random_rng=false

func settle_match(_result: int,_message: String):
 # Keep the actual rule effects (life, deck, counters) for task checks, but
 # let the tutorial runtime decide when the lesson ends.
 pass

func begin_random(results: Array,advance_rng: bool=false):
 scripted_random=true;random_results=results.duplicate(true);random_cursor=0;random_error=""
 advance_random_rng=advance_rng

func fixed_result(kind: String) -> int:
 if random_cursor>=random_results.size():
  random_error="random_results.%d：缺少预设的 %s 结果" % [random_cursor,kind]
  return 0 if kind=="coin" else 1
 var result=random_results[random_cursor]
 if result.type!=kind:
  random_error="random_results.%d：预设为 %s，实际需要 %s" % [random_cursor,result.type,kind]
  return 0 if kind=="coin" else 1
 random_cursor+=1
 return int(result.value)

func roll_coin() -> bool:
 if scripted_random and advance_random_rng:super.roll_coin()
 return fixed_result("coin")==1 if scripted_random else super.roll_coin()

func roll_die() -> int:
 if scripted_random and advance_random_rng:super.roll_die()
 return fixed_result("d6") if scripted_random else super.roll_die()
