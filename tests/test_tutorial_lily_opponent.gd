extends SceneTree
## The T2 opponent must wait for Lily Black's color choice before passing.
const Config=preload("res://scripts/tutorial/config.gd")
const Runtime=preload("res://scripts/tutorial/runtime.gd")
const Store=preload("res://scripts/deck_store.gd")

func check(ok: bool,label: String) -> bool:
 if ok:return true
 print("T2 LILY OPPONENT FAILED: ",label)
 quit(1)
 return false

func ticks(flow,count: int=10):
 for i in range(count):flow.tick()

func _initialize():
 var loaded=Config.new().load_file("res://data/tutorial/beginner/t2.json",Store.CARDS)
 if not check(loaded.ok,"course validates"):return
 var flow=Runtime.new()
 if not check(flow.start(loaded.data,Store.CARDS).is_empty(),"course starts"):return
 flow.enter("d7")
 if not check(flow.next() and flow.current_step=="r2","reaches Lily task"):return
 var e=flow.adapter.engine
 var lily=flow.adapter.entity("lily_black")
 var plan=e.payment(0,e.cast_cost(0,lily)).plan
 if not check(flow.adapter.submit(0,{"name":"commit_cast","args":[lily.uid,{},plan]}).is_empty(),"casts Lily"):return
 ticks(flow)
 if not check(flow.running and e.priority==0 and e.stack.size()==1 and flow.opponent.counts.get("pass_responses",0)==1,"opponent passes first response"):return
 if not check(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty(),"resolves Lily"):return
 if not check(e.pending.get("kind","")=="effect_choice" and e.pending.get("owner",-1)==0 and e.pending.get("trigger",{}).get("effect","")=="lily_color","player receives color choice"):return
 ticks(flow)
 if not check(flow.running and flow.last_error.is_empty() and flow.opponent.counts.get("pass_responses",0)==1 and e.pending.get("kind","")=="effect_choice","opponent waits without consuming response"):return
 var errors=[]
 flow.task_failed.connect(func(message):errors.append(message))
 var revision_before=e.revision
 if not check(not flow.submit_effect_choice({"color":"蓝","mode":"蓝"}) and e.revision==revision_before and e.pending.get("kind","")=="effect_choice" and flow.current_step=="r2" and not errors.is_empty(),"rejects non-red choice before applying it"):return
 if not check(flow.submit_effect_choice({"color":"红","mode":"红"}),"selects red"):return
 ticks(flow)
 if not check(flow.running and e.priority==0 and e.pending.is_empty() and flow.opponent.counts.get("pass_responses",0)==2,"opponent passes after choice"):return
 if not check(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty(),"resolves color trigger"):return
 ticks(flow)
 if not check(flow.running and flow.current_step=="d8" and lily.zone=="field" and "红" in lily.get("color_counters",[]) and flow.last_error.is_empty(),"continues tutorial after red Lily enters"):return
 print("T2 LILY OPPONENT PASS VALID")
 flow.free()
 quit()
