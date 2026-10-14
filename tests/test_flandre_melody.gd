extends "res://tests/support/rules_base.gd"

const MELODY="spell-fdn-005"
const Codec=preload("res://net/state_codec.gd")

func stats(c: Dictionary) -> Array:
 return [e.stat(c,"power"),e.stat(c,"health"),e.stat(c,"spirit")]

func setup() -> Dictionary:
 fresh()
 put(MELODY)
 var flandre=put("character-fdf-ex01")
 flandre.leader=true;e.players[0].leader=flandre
 var allies=[flandre,put("53")]
 var victim=e.players[1].leader
 e.enter_field(victim,1)
 var bystander=put("53","field",1)
 return {"allies":allies.map(func(c):return c.uid),"before":allies.map(stats),"victim":victim.uid,"bystander":bystander.uid,"enemy_before":stats(bystander)}

func expect_boost(context: Dictionary,amount: int,label: String):
 for i in range(context.allies.size()):
  var before=context.before[i]
  expect(stats(e.find_card(context.allies[i]))==[before[0]+amount,before[1],before[2]+amount],label+"：己方单位获得正确攻击力／血量／灵力")
 expect(stats(e.find_card(context.bystander))==context.enemy_before,label+"：对手其他单位不获得加成")

func expect_melody_on_stack(count: int,label: String):
 var entries=e.stack.filter(func(t):return t.get("effect","")==MELODY)
 expect(entries.size()==count and entries.all(func(t):return t.owner==0 and not t.get("optional",true)),label+"：乐章强制触发正确次数")

func leader_events():
 for mode in ["destroy","lethal","exile"]:
  for home in [false,true]:
   var context=setup();var victim=e.find_card(context.victim)
   var label=mode+" / 返回自机区="+str(home)
   if mode=="destroy":e.destroy(victim)
   elif mode=="lethal":e.damage_target(e.ref_target(victim),e.stat(victim,"health"))
   else:e.move_to(victim,"exile")
   e.pump_choices()
   expect(e.pending.get("kind","")=="leader_return","对方自机离场后选择去向："+label)
   expect_boost(context,0,"选择与结算前没有提前加成："+label)
   if home:
    var saved=Codec.capture(e);e=Duel.new();Codec.restore(e,saved)
    victim=e.find_card(context.victim)
   e.choose_return(home)
   expect(victim.zone==("leader" if home else "exile" if mode=="exile" else "grave"),"自机按所选去向移动："+label)
   expect_melody_on_stack(1,label)
   one()
   expect_boost(context,1,"乐章实际结算："+label)
   expect(e.stack.is_empty() and e.triggers.is_empty(),"同一次离场没有重复触发："+label)
   e.finish_turn()
   expect_boost(context,0,"乐章加成在回合结束清除："+label)

func direct_combat():
 for home in [false,true]:
  var context=setup();var flandre=e.find_card(context.allies[0]);var victim=e.find_card(context.victim)
  flandre.plus_counters=2;context.before[0]=stats(flandre)
  e.attack(0,flandre.uid,e.ref_target(victim));one();one()
  expect(e.pending.get("kind","")=="leader_return","芙兰先制直接攻击消灭对方自机后选择去向")
  expect(e.players[1].life==20-context.before[0][2],"歼灭使用本次战斗时的灵力")
  e.choose_return(home)
  expect_melody_on_stack(1,"先制直接攻击 / "+str(home))
  one()
  expect_boost(context,1,"战斗击杀后乐章结算 / "+str(home))

func simultaneous_deaths():
 var context=setup();var victim=e.find_card(context.victim);var bystander=e.find_card(context.bystander)
 victim.damage=e.stat(victim,"health");bystander.damage=e.stat(bystander,"health")
 e.pump_choices();e.choose_return(true)
 expect(e.pending.get("kind","")=="trigger_order" and e.pending.options.size()==2,"对方自机与普通单位同时死亡各产生一次乐章触发")
 e.choose_trigger_order([0,1])
 expect_melody_on_stack(2,"同时死亡")
 one();one()
 for i in range(context.allies.size()):
  var before=context.before[i]
  expect(stats(e.find_card(context.allies[i]))==[before[0]+2,before[1],before[2]+2],"同时死亡的两次乐章加成叠加")

func controller_and_non_death_moves():
 for controller in [0,1]:
  var context=setup();var victim=e.find_card(context.victim)
  e.players[1].field.erase(victim)
  victim.owner=controller;e.players[controller].field.append(victim)
  e.destroy(victim);e.pump_choices();e.choose_return(true)
  expect_melody_on_stack(controller,"按离场前操控者判定 / "+str(controller))
  if controller==1:one()
  expect_boost(context,controller,"操控者决定是否强化 / "+str(controller))
 for destination in ["hand","deck","palette"]:
  var context=setup();var victim=e.find_card(context.victim)
  e.move_to(victim,destination);e.pump_choices();e.choose_return(true)
  expect_melody_on_stack(0,"非消灭或移除的自机返回 / "+destination)
  expect_boost(context,0,"非消灭或移除不强化 / "+destination)

func run():
 leader_events()
 direct_combat()
 simultaneous_deaths()
 controller_and_non_death_moves()
 print("FLANDRE_MELODY: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
