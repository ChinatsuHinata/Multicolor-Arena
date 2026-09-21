extends SceneTree
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Store=preload("res://scripts/deck_store.gd")
var failed=[]
var checks=0
func expect(ok: bool, title: String):
 checks+=1
 if ok: print("PASS: "+title)
 else: failed.append(title); push_error(title)
func _initialize(): call_deferred("run")
func sample(leader: String) -> Dictionary:
 var d=Store.blank("测试")
 d.leader=leader
 for i in range(5): d.main.append_array(["164","164","165","165","167","68","70","99","100","170"])
 return d
func put(e,who: int,id: String,zone: String):
 var c=e.make_card(id,who,zone)
 e.players[who][zone].append(c)
 return c
func clean() -> RefCounted:
 var e=Duel.new(); e.start(sample("70"),sample("68"),0,73)
 for p in e.players:
  p.field=[]; p.hand=[]; p.palette=[]; p.grave=[]; p.potato=false
 e.phase="main"; e.turn=3; e.priority=0; e.active=0; e.pending={}; e.stack=[]
 return e
func resolve(e):
 e.pass_priority(e.priority); e.pass_priority(e.priority)
func run():
 var e=Duel.new(); e.start(sample("70"),sample("68"),0,42)
 expect(e.players[0].hand.size()==4 and e.players[1].hand.size()==4,"opening hands are four")
 expect(not e.players[0].potato and e.players[1].potato and e.players[1].palette.is_empty(),"second player bonus outside palette count")
 e.mulligan(0,[e.players[0].hand[0].uid]); e.mulligan(1,[])
 expect(e.phase=="prepare" and e.players[0].palette.size()==1,"reset grows palette before first turn")
 resolve(e)
 expect(e.phase=="possession" and e.players[0].hand.size()==4,"first turn skips draw and retains possession")
 e=clean()
 put(e,0,"70","palette"); put(e,0,"70","palette")
 var pay=e.payment(0,{"红":1,"黄":1})
 expect(pay.ways==2 and e.payment_valid(0,{"红":1,"黄":1},pay.plan),"multicolor assignment is feasible and exact")
 e=clean(); var r=put(e,0,"165","palette"); var y=put(e,0,"164","palette")
 pay=e.payment(0,{"红":1,"黄":1})
 expect(pay.ways==1,"only legal colored sources produce unique payment")
 e.players[0].potato=true
 pay=e.payment(0,{"红":1,"黄":1})
 expect(pay.plan.all(func(x): return x.uid>0),"optimizer preserves one-use potato")
 e=clean()
 put(e,0,"68","field"); put(e,1,"70","field")
 for i in range(3): put(e,0,"164","palette")
 for i in range(2): put(e,1,"164","palette")
 var fire=put(e,0,"99","hand"); var counter=put(e,1,"100","hand")
 var error=e.commit_cast(0,fire.uid,{"player":1},e.payment(0,{"黄":3}).plan)
 expect(error.is_empty() and e.stack.size()==1 and e.players[1].life==20,"spell waits on stack without applying damage")
 var id=e.stack[0].id
 error=e.commit_cast(1,counter.uid,{"stack_id":id},e.payment(1,{"黄":2}).plan)
 expect(error.is_empty() and e.stack.size()==2,"fast spell can respond on opponent turn")
 resolve(e)
 expect(e.stack.is_empty() and e.players[0].grave.size()==1 and e.players[1].grave.size()==1 and e.players[1].life==20,"counter resolves first and prevents original damage")
 e=clean(); put(e,0,"68","field")
 for i in range(3): put(e,0,"164","palette")
 fire=put(e,0,"99","hand")
 e.commit_cast(0,fire.uid,{"player":1},e.payment(0,{"黄":3}).plan); resolve(e)
 expect(e.players[1].life==15 and e.players[0].grave.size()==1,"unanswered spell uses actual five damage")
 e=clean(); var attacker=put(e,0,"68","field"); attacker.entered=1
 var blocker=put(e,1,"70","field"); blocker.entered=2
 e.attack(0,attacker.uid); resolve(e)
 expect(e.pending.get("kind","")=="block","attack opens blocker choice after response window")
 e.block([blocker.uid]); resolve(e)
 expect(e.players[0].grave.size()==1 and blocker.damage==3 and e.players[1].life==20,"blockers exchange simultaneous attack damage")
 e=clean(); attacker=put(e,0,"70","field"); attacker.entered=1
 e.attack(0,attacker.uid); resolve(e); e.block([]); resolve(e)
 expect(e.players[1].life==18,"unblocked attack uses spirit")
 e=clean(); e.players[0].potato=true
 var mana=put(e,0,"164","palette"); var item=put(e,0,"164","hand")
 error=e.commit_cast(0,item.uid,{},[{"uid":mana.uid,"color":"黄"},{"uid":-100,"color":"黄"}])
 resolve(e)
 expect(error.is_empty() and not e.players[0].potato and e.players[0].palette.size()==1 and e.players[0].field.size()==1,"potato pays once, disappears, is not a palette card")
 e=clean(); item=put(e,0,"164","hand")
 expect(not e.commit_cast(0,item.uid,{},[]).is_empty() and item.zone=="hand" and e.stack.is_empty(),"invalid payment cannot mutate public state")
 var covered={"attack":false,"block":false,"spell":false,"counter":false}
 var finished=0
 var complete_coverage=0
 var summaries=[]
 for seed_value in range(1,9):
  var game_coverage={"attack":false,"block":false,"spell":false,"counter":false}
  e=Duel.new(); e.start(sample("70"),sample("68"),seed_value%2,seed_value)
  e.mulligan(0,[]); e.mulligan(1,[])
  for action in range(1800):
   if e.winner!=-2: break
   var who=e.pending.get("owner",e.priority)
   e.ai_step(who)
   for line in e.log:
    if "宣言攻击" in line: covered.attack=true; game_coverage.attack=true
    if "宣言阻挡" in line: covered.block=true; game_coverage.block=true
    if "极限火花" in line and "使用" in line: covered.spell=true; game_coverage.spell=true
    if "被反制" in line: covered.counter=true; game_coverage.counter=true
  if e.winner!=-2:
   finished+=1
   if game_coverage.values().all(func(value): return value): complete_coverage+=1
   summaries.append({"seed":seed_value,"turns":e.turn,"winner":e.winner,"result":e.log.back(),"coverage":game_coverage})
  else: print("STUCK ",seed_value," ",e.phase," ",e.pending," ",e.turn)
 expect(finished==8,"eight complete deterministic matches terminate")
 expect(covered.attack and covered.block and covered.spell and covered.counter,"full matches include combat, block, spells and counters")
 expect(complete_coverage>0,"a single complete match includes all four requested interactions")
 var replay_report=FileAccess.open("res://work/full-match-results.json",FileAccess.WRITE)
 replay_report.store_string(JSON.stringify(summaries,"  "))
 var f=FileAccess.open("res://work/duel-test.txt",FileAccess.WRITE)
 f.store_string("%d checks; %d failures\n%s\nCoverage %s" % [checks,failed.size(),"\n".join(failed),str(covered)])
 print("DUEL_TEST: %d checks; %d failures" % [checks,failed.size()])
 quit(0 if failed.is_empty() else 1)
