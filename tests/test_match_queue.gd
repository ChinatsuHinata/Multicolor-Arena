extends SceneTree
const Queue=preload("res://relay/match_queue.gd")
var failures=[]
func _initialize():
 var queue=Queue.new()
 queue.add(1,1,1000,"same",0);queue.add(2,2,1090,"same",0);queue.add(3,3,1010,"same",0)
 check(queue.take_pairs(999)==[[1,3]],"closest pair wins over earlier but more distant request")
 check(queue.entries.has(2),"unpaired player stays queued")
 queue=Queue.new();queue.add(1,1,1000,"same",0);queue.add(2,2,1200,"same",59000)
 check(queue.take_pairs(59999).is_empty(),"range stays 100 before one minute")
 check(queue.take_pairs(60000)==[[1,2]],"one waiting player expands the range at exactly one minute")
 queue=Queue.new();queue.add(1,1,1000,"same",0);queue.add(2,2,1400,"same",0)
 check(queue.take_pairs(179999).is_empty() and queue.take_pairs(180000)==[[1,2]],"range continues expanding each minute")
 queue=Queue.new();queue.add(1,1,1000,"same",0);queue.add(2,1,1000,"same",0);queue.add(3,3,1000,"other",0)
 check(queue.take_pairs(600000).is_empty(),"same account and different versions never pair")
 queue.add(1,1,2000,"same",9000)
 check(queue.entries[1].since==0 and queue.entries[1].elo==1000,"duplicate request cannot reset queue time or rating")
 queue.remove(1);check(not queue.entries.has(1),"cancel removes the queue entry")
 queue=Queue.new();queue.add(1,1,1000,"same",10);queue.add(2,2,1000,"same",20);queue.add(3,3,1000,"same",30);queue.add(4,4,1000,"same",40)
 check(queue.take_pairs(100)==[[1,2],[3,4]],"equal gaps use waiting order and produce disjoint pairs")
 quit(0 if failures.is_empty() else 1)
func check(ok: bool,label: String):
 if ok:print("PASS: ",label)
 else:failures.append(label);push_error(label)
