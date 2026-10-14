extends SceneTree
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Store=preload("res://scripts/deck_store.gd")
var failed=[]
var checks=0
func _initialize():call_deferred("run")
func expect(ok: bool,title: String):
 checks+=1
 if ok:print("PASS: "+title)
 else:failed.append(title);push_error(title)
func fixture():
 var d=Store.blank("十二阶测试");d.leader="70"
 for i in range(50):d.main.append("164")
 var e=Duel.new();e.start(d,d,0,24)
 for p in e.players:
  p.hand=[];p.palette=[];p.field=[];p.grave=[];p.potato=false
 e.phase="main";e.turn=5;e.priority=0;e.active=0
 return e
func put(e,who: int,id: String):
 var c=e.make_card(id,who,"field");e.players[who].field.append(c);return c
func run():
 for flandre in [false,true]:
  var e=fixture()
  var attacker=put(e,0,"character-fdf-ex01" if flandre else "70")
  if flandre:attacker.leader=true
  var target=put(e,1,"70")
  e.Cat.Spells.resolve(e,{"card":e.make_card("spell-fdf-002",0,"stack"),"owner":0,"target":e.ref_target(target)})
  expect(target.has("rank_target"),"Twelve Ranks marks the target")
  e.attack(0,attacker.uid,e.ref_target(target))
  expect(e.combat.get("target",{}).get("uid",-1)==target.uid and not e.combat.get("direct",false) and attacker.tapped,"marked unit can be attacked through the blocking stage")
  expect(e.combat.blockers==[e.ref_target(target)] and e.combat.blocked,"marked target joins combat immediately")
  expect(not attacker.get("skip_reset",false),"Twelve Ranks attack has no reset penalty")
  e.combat={};e.start_turn(0)
  expect(not attacker.tapped,"Twelve Ranks attacker resets next turn")
 var e=fixture();var attacker=put(e,0,"character-fdf-ex01");attacker.leader=true
 var target=put(e,1,"70")
 expect(e.Pack.direct_attack(e,attacker),"Flandre has her own direct attack permission")
 e.attack(0,attacker.uid,e.ref_target(target))
 expect(attacker.get("skip_reset",false),"Flandre attack still skips next reset")
 e.combat={};e.start_turn(0)
 expect(attacker.tapped and not attacker.get("skip_reset",false),"Flandre skips exactly one reset")
 e.start_turn(0);expect(not attacker.tapped,"Flandre resets on subsequent turn")
 blocking_cases()
 combat_edges()
 print("TWELVE_RANKS: ",checks," checks; ",failed.size()," failures")
 quit(0 if failed.is_empty() else 1)

func mark(e,target):
 var spell=e.make_card("spell-fdf-002",0,"stack")
 e.Cat.Spells.resolve(e,{"card":spell,"owner":0,"target":e.ref_target(target)})
 # Isolate blocking from the spell's separate graveyard attack-return trigger.
 e.move_to(spell,"exile")

func one(e):e.pass_priority(e.priority);e.pass_priority(e.priority)

func durable(_e,c,power: int,health: int):
 c.base_override={"power":power,"health":health,"spirit":9}

func blocking_cases():
 for count in [0,1,2]:
  var e=fixture();var attacker=put(e,0,"70");var target=put(e,1,"53")
  durable(e,attacker,4,20);durable(e,target,1,20)
  var blockers=[]
  for i in range(2):
   var c=put(e,1,"roster_token_bat");durable(e,c,1,20);blockers.append(c)
  mark(e,target);e.attack(0,attacker.uid,e.ref_target(target));one(e)
  expect(e.pending.get("kind","")=="block" and e.pending.get("owner",-1)==1,"Twelve Ranks offers the defender a blocking choice: "+str(count))
  expect(target not in e.legal_blockers() and blockers.all(func(c):return c in e.legal_blockers()),"other units can block the attack on the marked target")
  e.block(blockers.slice(0,count).map(func(c):return c.uid));one(e)
  expect(e.combat.blockers.size()==count+1 and e.combat.blockers[0].uid==target.uid,"the marked unit stays in the joint defender group: "+str(count))
  if count>0:
   expect(e.pending.get("kind","")=="damage_assignment","multiple blockers require real damage allocation")
   var allocation={str(target.uid):1,str(blockers[0].uid):3 if count==1 else 1}
   if count==2:allocation[str(blockers[1].uid)]=2
   e.combat_damage(allocation)
  expect(target.damage==(4 if count==0 else 1),"rank target receives its share of the combat damage: "+str(count))
  expect(not target.tapped and attacker.damage==count+1,"the target and all additional blockers retaliate together: "+str(count))
  expect(e.players[1].life==20,"rank unit combat uses attack power and does not damage the player")
  if count>0:expect(blockers[0].tapped and blockers[0].damage==(3 if count==1 else 1),"declared blockers tap and receive their allocated attack damage")

 # Flandre's ordinary unit attack still goes straight to combat with its target.
 var e=fixture();var attacker=put(e,0,"character-fdf-ex01");attacker.leader=true
 var target=put(e,1,"53");put(e,1,"70")
 e.attack(0,attacker.uid,e.ref_target(target));one(e)
 expect(e.pending.is_empty() and e.combat.get("direct",false) and e.combat.get("step","")=="block_window","Flandre still skips other units' blocking declarations")

func combat_edges():
 var e=fixture();var attacker=put(e,0,"70");var target=put(e,1,"53")
 mark(e,target);e.attack(0,attacker.uid,e.ref_target(target))
 var newcomer=put(e,1,"roster_token_bat")
 one(e)
 expect(e.pending.get("kind","")=="block" and newcomer in e.legal_blockers(),"units entering during attack responses can protect the marked target")

 e=fixture();attacker=put(e,0,"70");target=put(e,1,"53");target.tapped=true
 mark(e,target);e.attack(0,attacker.uid,e.ref_target(target));one(e)
 expect(e.pending.is_empty() and e.combat.get("step","")=="block_window","no legal other blockers automatically advances to the marked unit combat")
 one(e);one(e)
 expect(e.players[1].life==17 and target.zone=="grave","unblocked marked-unit death resolves its three-life penalty")

 e=fixture();attacker=put(e,0,"70");target=put(e,1,"53")
 mark(e,target);e.attack(0,attacker.uid,e.ref_target(target));e.move_to(target,"hand");one(e)
 expect(e.combat.is_empty() and e.pending.is_empty() and e.players[1].life==20,"target leaving before the blocking stage cancels the attack without redirecting to the player")

 e=fixture();attacker=put(e,0,"70");target=put(e,1,"53")
 durable(e,target,1,20)
 var blocker=put(e,1,"roster_token_bat")
 mark(e,target);e.attack(0,attacker.uid,e.ref_target(target));one(e);e.block([blocker.uid])
 e.move_to(blocker,"hand");one(e)
 expect(e.combat.get("step","")=="damage_window" and target.damage==3 and attacker.damage==1,"extra blockers leaving does not remove the mandatory target from combat")

 for count in [1,2]:
  e=fixture();attacker=put(e,0,"70");attacker.extra_keywords=["威吓"]
  target=put(e,1,"53");var blockers=[]
  for i in range(count):blockers.append(put(e,1,"roster_token_bat"))
  mark(e,target);e.attack(0,attacker.uid,e.ref_target(target));one(e)
  expect(e.pending.get("kind","")=="block","menace counts the mandatory target when offering extra blockers: "+str(count))
  e.block([blockers[0].uid])
  expect(e.pending.is_empty() and e.combat.blockers.size()==2,"one extra blocker plus the mandatory target satisfies menace")

 e=fixture();attacker=put(e,0,"67");target=put(e,1,"53")
 blocker=put(e,1,"70")
 mark(e,target);e.attack(0,attacker.uid,e.ref_target(target));one(e);e.block([blocker.uid]);one(e)
 expect(e.pending.get("kind","")=="damage_assignment","first-strike damage is allocated across the mandatory target and blocker")
 e.combat_damage({str(target.uid):0,str(blocker.uid):3})
 expect(e.combat.get("step","")=="first_damage_window" and blocker.damage==3 and attacker.damage==0 and target.damage==0,"first-strike damage follows its allocation and offers responses")
 one(e)
 expect(attacker.zone=="grave" and target.damage==0,"the ordinary blocker retaliates after the first-strike response window")

 e=fixture();attacker=put(e,0,"70");target=put(e,1,"53");blocker=put(e,1,"70")
 mark(e,target);e.attack(0,attacker.uid,e.ref_target(target));one(e)
 var codec=load("res://net/state_codec.gd");var graph=codec.capture(e);e=Duel.new();codec.restore(e,graph)
 expect(e.pending.get("kind","")=="block" and e.combat.get("target",{}).get("uid",-1)==target.uid,"save/network roundtrip preserves the rank target and blocking choice")
 e.block([blocker.uid]);one(e)
 expect(e.pending.get("kind","")=="damage_assignment" and e.combat.blockers.size()==2,"restored rank attack retains its target in the joint defender group")
 e.combat_damage({str(target.uid):1,str(blocker.uid):2})
 expect(e.find_card(target.uid).damage==1,"restored rank target receives allocated combat damage")

 e=fixture();attacker=put(e,0,"70");target=put(e,1,"53");blocker=put(e,1,"roster_token_bat")
 durable(e,attacker,3,3);durable(e,target,2,20);durable(e,blocker,1,20)
 mark(e,target);e.attack(0,attacker.uid,e.ref_target(target));one(e)
 var groups=e.RemiliaAI.groups(e,attacker)
 expect(groups.size()==1 and groups[0].size()==1 and groups[0][0].uid==blocker.uid,"AI blocker choices exclude the target that already participates")
 expect(e.RemiliaAI.fight(e,attacker,[blocker]).attacker_dead and not e.RemiliaAI.fight(e,attacker,[]).attacker_dead,"AI previews include the target's retaliation with extra blockers")

 e=fixture();attacker=put(e,0,"70");target=put(e,1,"53");blocker=put(e,1,"70")
 mark(e,target);e.attack(0,attacker.uid,e.ref_target(target));one(e);e.block([blocker.uid])
 e.move_to(target,"hand");one(e)
 expect(e.combat.get("step","")=="damage_window" and blocker.damage==3,"target leaving after declarations preserves combat with the remaining blocker")

 e=fixture();attacker=put(e,0,"53");target=put(e,1,"character-fdf-065")
 mark(e,target);e.attack(0,attacker.uid,e.ref_target(target));one(e)
 expect(e.stack.is_empty() and e.pending.is_empty() and not target.tapped,"an unblocked attacked unit does not declare blocking or trigger its blocking ability")

 # Replay training must retain a unit attack's target before blockers are declared.
 e=fixture();attacker=put(e,0,"53");target=put(e,1,"70");mark(e,target)
 var original=codec.capture(e)
 var archive=load("res://scripts/replay_archive.gd").new()
 var observer=load("res://net/observer_projection.gd")
 var room={"status":"playing","names":["甲","乙"],"scores":[0,0],"format":1,"round":1}
 archive.record({"game_id":"rank-test","sequence":e.revision,"room":room,"projection":observer.build(e,[],0,true)},0)
 e.attack(0,attacker.uid,e.ref_target(target))
 archive.record({"game_id":"rank-test","sequence":e.revision,"room":room,"projection":observer.build(e,[],0,true)},0)
 var before=Duel.new();codec.restore(before,original)
 var training=load("res://scripts/ai/replay_training.gd").new();training.archive=archive
 var action=training.recorded_action(0,0,before).get("action",{})
 expect(action.get("kind","")=="attack" and action.get("target",{}).get("uid",-1)==target.uid,"replay training recovers the rank unit attack with its target")
