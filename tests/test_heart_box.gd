extends "res://tests/support/rules_base.gd"

const Codec=preload("res://net/state_codec.gd")

func ready(who: int=0):
 fresh();mana();e.active=who;e.priority=who
 if who==1:
  for c in e.players[0].palette.duplicate():
   e.players[0].palette.erase(c);c.owner=1;e.players[1].palette.append(c)

func use_grave(c: Dictionary,who: int=0,target: Dictionary={"player":1}) -> String:
 return e.commit_cast(who,c.uid,target,e.payment(who,e.cast_cost(who,c,target)).plan)

func multiple_boxes():
 for who in [0,1]:
  for amount in [1,2,3]:
   ready(who)
   var boxes=[]
   for i in range(amount):boxes.append(put("173","field",who))
   for i in range(amount):
    var spell=put("96","grave",who)
    expect(e.cast_error(who,spell.uid).is_empty(),"每个心之箱提供一次墓地使用，座位 %d，第 %d/%d 次" % [who,i+1,amount])
    var error=use_grave(spell,who,{"player":1-who})
    expect(error.is_empty() and spell.zone=="stack","第 %d/%d 张墓地符卡成功入堆叠：%s" % [i+1,amount,error])
    if not error.is_empty():break
    expect(boxes.filter(func(box):return e.usage_count(box.uid,"heart_grave")==1).size()==i+1,"每次声明只消耗一个心之箱的次数")
    one();e.priority=who
    expect(spell.zone=="exile","心之箱使用的符卡结算后移除")
   var extra=put("96","grave",who)
   expect(not e.Pack.cast_from(e,extra,who) and not e.legal_casts(who).any(func(option):return option.uid==extra.uid),"所有心之箱用尽后，墓地符卡不再可用")
   expect(not use_grave(extra,who,{"player":1-who}).is_empty() and extra.zone=="grave","不允许超出心之箱总次数")

func declarations_and_restrictions():
 ready();var box=put("173");var spell=put("96","grave")
 expect(not e.commit_cast(0,spell.uid,{"player":1},[]).is_empty(),"费用不足的声明被拒绝")
 expect(not use_grave(spell,0,{"uid":-1,"epoch":0}).is_empty(),"非法目标的声明被拒绝")
 expect(e.cast_error(0,spell.uid).is_empty(),"失败的声明不消耗心之箱次数")
 expect(use_grave(spell).is_empty(),"合法声明消耗第一次数")
 var next=put("96","grave");e.priority=0
 expect(not e.Pack.cast_from(e,next,0),"符卡尚未结算时，次数已经消耗")
 e.counter_entry(e.stack.back().id)
 expect(spell.zone=="exile" and not e.Pack.cast_from(e,next,0),"被反制的墓地符卡仍移除且不返还次数")
 var second=put("173")
 expect(e.cast_error(0,next.uid).is_empty(),"同回合新进场的心之箱立即提供独立次数")
 expect(e.usage_count(box.uid,"heart_grave")==1 and e.usage_count(second.uid,"heart_grave")==0,"新增来源不改变已有来源的记录")

 ready();put("173","field",1);put("173","palette");spell=put("96","grave")
 expect(not e.Pack.cast_from(e,spell,0),"对方及颜色盘中的心之箱不提供权限")
 put("173");var costly=put("106","grave");var unit=put("53","grave");var enemy=put("96","grave",1)
 expect(not e.Pack.cast_from(e,costly,0) and not e.Pack.cast_from(e,unit,0) and not e.Pack.cast_from(e,enemy,0),"心之箱只允许使用自己的低费墓地符卡")
 e.active=1
 expect(not e.Pack.cast_from(e,spell,0),"对方回合不能使用心之箱权限")
 e.active=0;e.phase="end"
 expect(not e.cast_error(0,put("113","grave").uid).is_empty(),"心之箱仍遵守普通符卡使用时机")

func sources_and_restore():
 ready();var first=put("173");var second=put("173");var spell=put("96","grave")
 expect(use_grave(spell).is_empty(),"使用第一个来源")
 one();e.priority=0
 e.move_to(first,"hand")
 var next=put("96","grave")
 expect(e.cast_error(0,next.uid).is_empty(),"已用来源离场不消耗另一个来源的次数")
 var restored=Duel.new();Codec.restore(restored,bytes_to_var(var_to_bytes(Codec.capture(e))));e=restored
 first=e.find_card(first.uid);second=e.find_card(second.uid);next=e.find_card(next.uid)
 expect(e.usage_count(first.uid,"heart_grave")==1 and e.usage_count(second.uid,"heart_grave")==0,"存档恢复保留每个来源的独立次数")
 expect(use_grave(next).is_empty(),"恢复后仍可使用剩余来源")
 one();e.priority=0
 e.enter_field(first,0)
 next=put("96","grave")
 expect(e.cast_error(0,next.uid).is_empty() and use_grave(next).is_empty(),"心之箱重新进场后重新获得一次权限")
 one();e.priority=0
 e.start_turn(1)
 expect(not e.Pack.cast_from(e,put("96","grave"),0),"换到对手回合时不能使用心之箱")
 e.start_turn(0);e.phase="main";e.priority=0
 expect(use_grave(put("96","grave")).is_empty(),"下个自己的回合恢复第一次数")
 one();e.priority=0
 expect(use_grave(put("96","grave")).is_empty(),"下个自己的回合恢复第二次数")

 ready();first=put("173");second=put("173");spell=put("96","grave")
 expect(use_grave(spell).is_empty(),"离场场景先用掉第一个来源")
 one();e.priority=0;e.move_to(second,"hand")
 expect(not e.Pack.cast_from(e,put("96","grave"),0),"未用来源离场后，已用来源不会凭空获得次数")

func timed_and_other_permissions():
 ready();var box=put("173");var timed=put("113","grave")
 expect(use_grave(timed,0,{"none":true}).is_empty(),"心之箱可以使用低费时符")
 one();e.priority=0
 expect(timed.zone=="field" and timed.get("exile_on_grave",false),"时符进场后保留移除替代")
 e.move_to(box,"hand");e.to_grave(timed)
 expect(timed.zone=="exile","心之箱离场后，时符入墓仍改为移除")

 ready();box=put("173");var spell=put("96","grave")
 e.forced_cast={"uid":spell.uid,"owner":0,"free":true,"ignore":true}
 expect(e.commit_cast(0,spell.uid,{"player":1},[]).is_empty(),"其他效果允许从墓地使用符卡")
 expect(e.usage_count(box.uid,"heart_grave")==0 and not spell.get("exile_on_grave",false),"其他效果的使用不消耗心之箱或附加移除")
 one();e.priority=0;e.forced_cast={}
 expect(spell.zone=="grave" and e.cast_error(0,spell.uid).is_empty(),"其他效果结算后仍保留心之箱次数")

 ready();box=put("173");put("91");spell=put("spell-fdf-012","grave")
 var options=e.targets_for(spell.card_id,0,spell.uid)
 var target=options[0].duplicate(true);target.erase("selection");target.picks=[[]]
 var error=use_grave(spell,0,target)
 expect(error.is_empty(),"符卡仍可凭自己的墓地权限使用："+error)
 expect(e.usage_count(box.uid,"heart_grave")==0,"符卡自身的墓地权限不消耗心之箱次数")
 one();e.priority=0
 expect(spell.zone=="exile" and e.cast_error(0,put("96","grave").uid).is_empty(),"符卡自身移除替代保留，心之箱仍可使用")

func run():
 multiple_boxes()
 declarations_and_restrictions()
 sources_and_restore()
 timed_and_other_permissions()
 print("HEART_BOX: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
