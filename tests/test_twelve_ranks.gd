extends SceneTree
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Store=preload("res://scripts/deck_store.gd")
var failed=[]
func _initialize():call_deferred("run")
func expect(ok: bool,title: String):
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
  expect(e.combat.get("direct",false) and attacker.tapped,"marked unit can be attacked")
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
 quit(0 if failed.is_empty() else 1)
