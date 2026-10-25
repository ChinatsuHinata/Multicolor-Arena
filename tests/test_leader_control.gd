extends "res://tests/support/rules_base.gd"

const Codec=preload("res://net/state_codec.gd")

func leader(id: String,who: int) -> Dictionary:
 var c=e.make_card(id,who,"leader",true);e.players[who].leader=c
 e.enter_field(c,who)
 return c

func steal(c: Dictionary,who: int):
 for id in ["165","165","167","167"]:put(id,"palette",who)
 e.active=who;e.priority=who
 var spell=put("140","hand",who)
 var error=e.commit_cast(who,spell.uid,e.ref_target(c),e.payment(who,e.cast_cost(who,spell)).plan)
 expect(error.is_empty(),"审ノ视真实使用："+error)
 one()
 expect(c.owner==who and c.get("original_owner",who)==1-who and c.zone=="field","审ノ视只改变操控权")
 expect(not c.tapped and e.has_haste(c),"审ノ视仍重置目标并给予疾行")

func leader_authorization():
 for who in [0,1]:
  fresh()
  var remilia=leader("74",1-who);remilia.tapped=true
  var ally=put("53","field",who);e.cards[ally.card_id].colors=["黑"]
  var power=e.stat(ally,"power")
  expect(e.has_leader_ability(remilia),"自己的套牌自机具有自机能力")
  steal(remilia,who)
  expect(not e.has_leader_ability(remilia) and e.stat(ally,"power")==power,"夺取对方套牌自机不会启用自机能力或光环")
  var restored=Duel.new();expect(Codec.restore(restored,Codec.capture(e)).is_empty(),"受控自机可保存恢复")
  e=restored;remilia=e.find_card(remilia.uid);ally=e.find_card(ally.uid)
  expect(not e.has_leader_ability(remilia) and e.stat(ally,"power")==power,"保存恢复后仍按当前操控方判断自机能力")
  var shrine=put("170","field",who)
  expect(e.has_leader_ability(remilia) and e.stat(ally,"power")==power+1,"操控方的博丽神社仍可明确授予自机能力")
  e.move_to(shrine,"exile")
  expect(not e.has_leader_ability(remilia),"神社离场后受控自机失去授予的能力")
  remilia.leader_counters=1
  expect(e.has_leader_ability(remilia),"自机指示物仍可明确授予能力")
  remilia.leader_counters=0
  e.phase="end";e.cleanup_end()
  expect(remilia.owner==1-who and remilia in e.players[1-who].field and e.has_leader_ability(remilia),"回合结束归还操控权后恢复套牌自机能力")
  fresh();var aya=leader("79",1-who);var target=put("53","field",who);steal(aya,who)
  expect(not e.available_actions(who,aya.uid).any(func(a):return a.get("key","")=="leader_bounce"),"受控对方文不显示自机启动能力")
  expect(not e.commit_extension(who,aya.uid,e.ref_target(target),[],"leader_bounce").is_empty(),"直接提交也不能绕过受控自机能力限制")
  fresh();var yuyuko=leader("71",1-who);target=put("53","field",who);steal(yuyuko,who)
  power=e.stat(yuyuko,"power")
  expect(e.commit_extension(who,yuyuko.uid,e.ref_target(target),[],"sacrifice_buff").is_empty(),"受控幽幽子仍可发动普通牺牲能力")
  expect(death_events().is_empty() and e.stack.size()==1,"受控幽幽子牺牲单位不会触发其自机能力")
  one();expect(e.stat(yuyuko,"power")==power+1,"受控幽幽子的普通牺牲强化仍结算")

func grant_chain():
 for who in [0,1]:
  fresh();var sisters=leader("character-fdn-026",1-who)
  var satori=put("76","field",who)
  steal(sisters,who)
  expect(not e.has_leader_ability(sisters) and not e.has_leader_ability(satori),"夺取觉恋套牌自机不会向其他觉恋传递自机能力")
  sisters.leader_counters=1
  expect(e.has_leader_ability(satori),"觉恋得到自机指示物后仍正常授予其他觉恋能力")
  fresh();var traveler=leader(e.Exploration.LEADER,1-who);steal(traveler,who)
  expect(not e.has_leader_ability(traveler) and not e.character_matches(traveler,"博丽灵梦"),"受控对方探索自机不会获得角色通配能力")
  put("170","field",who)
  expect(e.character_matches(traveler,"博丽灵梦"),"神社明确授予后探索角色通配能力仍生效")

func death_events() -> Array:
 return e.triggers.filter(func(t):return t.get("effect","")=="leader_death_damage")

func yuyuko_controller():
 for who in [0,1]:
  for original in [0,1]:
   for controller in [0,1]:
    for id in ["53","token_halfghost"]:
     fresh();var yuyuko=leader("71",who)
     var victim=e.make_card(id,original,"field");victim.token=id=="token_halfghost";victim.owner=controller;e.players[controller].field.append(victim)
     e.destroy(victim)
     var events=death_events();var expected=int(controller==who)
     expect(events.size()==expected,"幽幽子仅观察死亡前操控的单位：席位%d / 拥有%d / 操控%d / %s" % [who,original,controller,id])
     if not events.is_empty():expect(events[0].owner==who and events[0].source.uid==yuyuko.uid,"幽幽子触发归属于自身操控方")
     expect(victim.zone==("void" if id=="token_halfghost" else "grave"),"受控单位仍正常死亡并进入相应区域")
 for who in [0,1]:
  for home in [false,true]:
   fresh();leader("71",who)
   var victim=leader("70",1-who);steal(victim,who)
   e.destroy(victim);e.pump_choices()
   expect(e.pending.get("kind","")=="leader_return" and e.pending.owner==1-who,"受控自机死亡仍由拥有者选择去向")
   var restored=Duel.new();expect(Codec.restore(restored,Codec.capture(e)).is_empty(),"自机死亡选择可保存恢复")
   e=restored;victim=e.find_card(victim.uid);e.choose_return(home)
   expect(victim.zone==("leader" if home else "grave") and victim.owner==1-who,"返回选择保留拥有者与正确去向")
   expect(e.stack.filter(func(t):return t.get("effect","")=="leader_death_damage").size()==1,"受控自机死亡按死亡前操控方触发幽幽子，含返回自机区")
   e.choose_effect({"player":1-who});one()
   expect(e.players[1-who].life==19,"幽幽子死亡触发真实结算造成一点伤害")

func simultaneous_and_limits():
 for who in [0,1]:
  fresh();var yuyuko=leader("71",who);var victim=put("53","field",1-who)
  e.players[1-who].field.erase(victim);victim.owner=who;e.players[who].field.append(victim)
  yuyuko.damage=e.stat(yuyuko,"health");victim.damage=e.stat(victim,"health")
  e.judge()
  expect(death_events().size()==1,"幽幽子与受控单位同时死亡仍观察该单位死亡："+str(death_events().size()))
  e.pump_choices();e.choose_return(true)
  var queued=death_events().size()+e.stack.filter(func(t):return t.get("effect","")=="leader_death_damage").size()
  expect(queued==2,"幽幽子同时死亡也观察自身，且每次死亡只触发一次："+str(queued))
  fresh();yuyuko=leader("71",who)
  for i in range(3):
   e.destroy(put("53","field",who));e.pump_choices()
   if i<2:e.choose_effect({"player":1-who})
   one()
  expect(e.players[1-who].life==18 and e.pending.is_empty() and e.stack.is_empty(),"幽幽子每回合至多两次伤害的限制保留")

func run():
 leader_authorization();grant_chain();yuyuko_controller();simultaneous_and_limits()
 print("LEADER_CONTROL: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
