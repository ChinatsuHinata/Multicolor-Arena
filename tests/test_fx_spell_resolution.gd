extends "res://tests/support/rules_base.gd"
## 符卡特效的触发时点：只有符卡真正结算（未被反制、目标未失效）时，引擎才发出
## 公开事件 spell_resolved；提交进入对抗区时不发。

const DREAM="spell-rei-011"

func resolved_events() -> Array:
 return e.presentation_events.filter(func(event):return event.get("type","")=="spell_resolved")

## 灵梦在场、对方一个单位、颜色盘两张角色符卡，提交梦想妙珠打这个单位。
func cast_dream() -> Dictionary:
 fresh();mana()
 put("70","field",0)
 var foe=put("53","field",1)
 for i in range(2):put(DREAM,"palette",0)
 var spell=put(DREAM,"hand",0)
 var target={}
 for option in e.targets_for(DREAM,0,spell.uid):
  if option.get("uid",-1)==foe.uid:target=option
 expect(not target.is_empty(),"梦想妙珠可以指定对方单位")
 var error=e.commit_cast(0,spell.uid,target,e.payment(0,e.cast_cost(0,spell,target)).plan)
 expect(error.is_empty(),"梦想妙珠提交成功："+error)
 return {"spell":spell,"foe":foe,"stack_id":e.stack.back().id if not e.stack.is_empty() else -1}

func run():
 var cast=cast_dream()
 expect(resolved_events().is_empty(),"提交进入对抗区时不发出符卡结算事件")
 one()
 var events=resolved_events()
 expect(events.size()==1,"符卡结算时发出一次结算事件")
 if events.size()==1:
  var event=events[0]
  expect(event.card.uid==cast.spell.uid and event.owner==0,"事件带上符卡与施放者")
  expect(event.targets.size()==1 and event.targets[0].uid==cast.foe.uid and event.targets[0].owner==1 and event.targets[0].zone=="field","事件记下结算前目标所在的区域")
 expect(e.presentation_events.find(events[0] if not events.is_empty() else {})<e.presentation_events.size()-1,"结算事件排在符卡移入墓地之前")

 cast=cast_dream()
 e.move_to(cast.foe,"grave")
 one()
 expect(resolved_events().is_empty(),"目标失效时符卡不结算，也不发出结算事件")

 cast=cast_dream()
 e.counter_entry(cast.stack_id)
 settle()
 expect(resolved_events().is_empty(),"被反制的符卡不发出结算事件")

 print("FX SPELL RESOLUTION: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
