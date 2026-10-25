extends "res://tests/support/catalogue_rules_base.gd"

const Codec=preload("res://net/state_codec.gd")

func field_leader(who: int) -> Dictionary:
 var c=e.players[who].leader
 e.shift(c,"field");c.entered_turns=0;e.players[who].field.append(c)
 return c

func cast_night(who: int=0) -> Dictionary:
 put("85","field",who)
 for id in ["165","167","166","164","168"]:
  for i in range(4):put(id,"palette",who)
 e.active=who;e.priority=who
 var spell=put("spell-fdf-060","hand",who)
 var error=e.commit_cast(who,spell.uid,{"none":true},e.payment(who,e.cast_cost(who,spell)).plan)
 expect(error.is_empty(),"永夜归还可正常使用："+error)
 one()
 return spell

func restore():
 var restored=Duel.new()
 var error=Codec.restore(restored,Codec.capture(e))
 expect(error.is_empty(),"自机去向与符卡续结算可序列化恢复："+error)
 e=restored

func pool() -> Array:
 if e.pending.get("kind","")!="effect_choice" or e.pending.trigger.effect!="cat:resurrect":
  expect(false,"去向选择后继续符卡的复活选择")
  return []
 return e.pending.options[0].selection[0].pool

func leader_resurrection():
 for who in [0,1]:
  for home in [false,true]:
   fresh()
   var leader=field_leader(who);var uid=leader.uid
   var spell=cast_night(who)
   expect(e.pending.get("kind","")=="leader_return" and e.pending.owner==who,"复活选牌前先由拥有者确认套牌自机去向")
   if e.pending.get("kind","")!="leader_return":continue
   expect(e.return_continuations.size()==1 and e.stack.is_empty(),"符卡续结算等待去向，不产生额外堆叠")
   var before=Codec.capture(e);one()
   expect(Codec.capture(e)==before,"去向确认期间不能让过或推进结算")
   restore();leader=e.find_card(uid)
   e.choose_return(home)
   var candidates=pool()
   expect(candidates.any(func(r):return r.uid==uid)==not home,"只有选择留在墓地的套牌自机进入复活名单")
   expect(e.pending.resolving_entry.card.uid==spell.uid and e.return_continuations.is_empty(),"复活选择保留原符卡且续结算只执行一次")
   if home:
    e.choose_effect(selected(e.pending.options,[[]]))
    expect(leader.zone=="leader" and e.delayed.is_empty(),"返回自机区的自机不会被复活或添加移除效果")
   else:
    expect(candidates[0].epoch==leader.epoch and candidates[0].zone=="grave","复活选项使用确认后的墓地区域标识")
    restore();leader=e.find_card(uid)
    e.choose_effect(selected(e.pending.options,[[e.Pack.ref(e,leader)]]))
    expect(leader.zone=="field" and leader.tapped and leader.owner==who,"套牌自机横置放入施法者战场")
    expect(e.delayed.size()==1 and e.delayed[0].effect=="exile" and e.delayed[0].owner==who,"复活的套牌自机保留施法者下个结束阶段移除效果")
    settle();e.phase="end";e.run_delayed("end");settle()
    expect(leader.zone=="exile" and e.delayed.is_empty(),"下个结束阶段实际移除复活的自机")

func simultaneous_leaders():
 for who in [0,1]:
  for homes in [[false,false],[true,false],[false,true],[true,true]]:
   fresh()
   var first=field_leader(0);var second=field_leader(1)
   cast_night(who)
   for seat in [0,1]:
    expect(e.pending.get("kind","")=="leader_return" and e.pending.owner==seat,"双方自机各自由拥有者选择去向")
    if e.pending.get("kind","")!="leader_return":return
    if seat==1:
     restore();first=e.players[0].leader;second=e.players[1].leader
    e.choose_return(homes[seat])
   var candidates=pool()
   expect(candidates.size()==int(not homes[0])+int(not homes[1]),"等双方去向确认后一次生成完整复活名单")
   for seat in [0,1]:
    var leader=e.players[seat].leader
    expect(candidates.any(func(r):return r.uid==leader.uid)==not homes[seat],"双方自机名单均遵守各自的去向决定")
   var chosen=candidates.filter(func(r):return e.find_card(r.uid).owner==1-who)
   e.choose_effect(selected(e.pending.options,[chosen]))
   var other=second if who==0 else first
   expect(other.zone==("leader" if homes[1-who] else "field"),"对方选择入墓的套牌自机可被施法者拉入战场")
   if not homes[1-who]:
    expect(other.owner==who and other.original_owner==1-who and other.tapped,"拉入对方自机保留拥有者并改变操控方、横置进场")
    expect(not e.has_leader_ability(other),"拉入对方套牌自机遵守现有自机能力归属规则")

func ordinary_and_limits():
 fresh()
 var own=put("53");var enemy=put("50","field",1)
 var old=put("53","grave");var replaced=put("53","field",1);replaced.exile_on_grave=true
 var token=e.Cat.token(e,1,"小鬼",1,1,1,["黑"])
 var spell=cast_night()
 var candidates=pool()
 expect(candidates.size()==2 and candidates.any(func(r):return r.uid==own.uid) and candidates.any(func(r):return r.uid==enemy.uid),"无套牌自机时仍可选择双方以此法入墓的普通单位")
 expect(not candidates.any(func(r):return r.uid in [old.uid,replaced.uid,token.uid]),"原墓地牌、移除替代与已消失衍生物均不进入名单")
 expect(replaced.zone=="exile" and token.zone=="void" and e.units(0).any(func(c):return c.card_id=="85"),"移除替代、衍生物消失与不会被消灭仍生效")
 e.choose_effect(selected(e.pending.options,[candidates]))
 expect(own.zone=="field" and enemy.zone=="field" and own.tapped and enemy.tapped and enemy.owner==0,"可将所选普通单位一起横置放入战场")
 expect(e.delayed.size()==2 and e.delayed.all(func(d):return d.origin_name==e.cards[spell.card_id].name),"每个复活单位各自保留符卡来源与延迟移除")
 fresh();own=put("53");cast_night();pool()
 e.choose_effect(selected(e.pending.options,[[]]))
 expect(own.zone=="grave" and e.delayed.is_empty(),"任意数量允许不复活单位")

 fresh();field_leader(0);own=put("53");cast_night()
 e.move_to(own,"hand");e.move_to(own,"grave");e.choose_return(false)
 candidates=pool()
 expect(not candidates.any(func(r):return r.uid==own.uid),"去向确认期间离墓再入墓的牌不会被误认作原入墓实例")

func controlled_leader():
 for who in [0,1]:
  fresh()
  var leader=field_leader(1-who)
  e.players[1-who].field.erase(leader);leader.owner=who;e.players[who].field.append(leader)
  cast_night(who)
  expect(e.pending.kind=="leader_return" and e.pending.owner==1-who,"被夺取自机消灭后仍由原拥有者选择去向")
  e.choose_return(false)
  expect(pool().any(func(r):return r.uid==leader.uid and r.epoch==leader.epoch),"被夺取自机进入原拥有者墓地后仍在符卡名单中")
  e.choose_effect(selected(e.pending.options,[[e.Pack.ref(e,leader)]]))
  expect(leader.owner==who and leader.original_owner==1-who and leader.tapped,"已夺取自机可再次由施法者横置拉回")

func run():
 leader_resurrection();simultaneous_leaders();ordinary_and_limits();controlled_leader()
 print("ETERNAL_NIGHT_RETURN: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
