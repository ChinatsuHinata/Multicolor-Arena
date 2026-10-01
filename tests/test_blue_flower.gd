extends "res://tests/support/rules_base.gd"

const BLUE_FLOWER = "spell-fdn-069"
const OTHER_SPELL = "spell-fdf-036"

func stack_spell(who: int) -> Dictionary:
 var c=e.make_card(OTHER_SPELL,who,"stack")
 var stack_id=e.next_stack
 e.stack.append({"id":stack_id,"kind":"card","card":c,"owner":who,"name":e.cards[c.card_id].name,"target":{"none":true}})
 e.next_stack+=1
 return {"card":c,"id":stack_id}

func cast_blue_flower() -> Dictionary:
 var c=put(BLUE_FLOWER,"hand")
 var target={"none":true}
 var plan=e.payment(0,e.cast_cost(0,c,target)).plan
 var error=e.commit_cast(0,c.uid,target,plan)
 expect(error.is_empty(),"青花可主动提交使用："+error)
 return c

func has_choice(stack_id: int) -> bool:
 return e.pending.get("options",[]).any(func(option):return option.get("stack_id",-1)==stack_id)

func self_choice() -> Dictionary:
 for option in e.pending.get("options",[]):
  if option.get("self",false):return option
 return {}

func run():
 fresh();mana()
 var blue=put(BLUE_FLOWER,"hand")
 expect(e.cast_error(0,blue.uid).is_empty(),"对抗中没有其他符卡时也可主动使用青花")
 expect(e.targets_for(BLUE_FLOWER,0,blue.uid)==[{"none":true}],"使用青花时不选择符卡")
 var error=e.commit_cast(0,blue.uid,{"none":true},e.payment(0,e.cast_cost(0,blue,{"none":true})).plan)
 expect(error.is_empty(),"单独使用青花提交成功："+error)
 expect(e.pending.is_empty() and e.stack.back().target=={"none":true},"青花声明后仍未选择符卡")
 one()
 expect(e.pending.get("kind","")=="effect_choice" and not self_choice().is_empty(),"结算到青花时才可选择自身")
 e.choose_effect(self_choice())
 expect(blue.zone=="deck" and e.players[0].deck.size()>2 and e.players[0].deck[2].uid==blue.uid,"青花选择自身后进入拥有者牌库顶第3张")
 expect(not e.players[0].grave.has(blue) and e.pending.is_empty(),"选择自身的青花不会再次进入墓地")

 for who in [0,1]:
  fresh();mana()
  var other=stack_spell(who)
  blue=cast_blue_flower()
  expect(e.pending.is_empty() and e.stack.back().target=={"none":true},"使用时不预选%s的符卡" % ["己方" if who==0 else "对方"])
  one()
  expect(e.pending.get("kind","")=="effect_choice" and not self_choice().is_empty() and has_choice(other.id),"青花结算时可选自身及%s符卡" % ["己方" if who==0 else "对方"])
  e.choose_effect({"stack_id":other.id})
  expect(other.card.zone=="deck" and other.card.owner==who and e.players[who].deck.size()>2 and e.players[who].deck[2].uid==other.card.uid,"所选%s符卡进入其拥有者牌库顶第3张" % ["己方" if who==0 else "对方"])
  expect(blue.zone=="grave" and not e.stack.any(func(entry):return entry.id==other.id),"选其他符卡后青花进入墓地且该符卡离开对抗")

 fresh();mana()
 var departed=stack_spell(1)
 blue=cast_blue_flower()
 e.move_to(departed.card,"grave")
 one()
 expect(e.pending.get("kind","")=="effect_choice" and not self_choice().is_empty() and not has_choice(departed.id),"其他符卡在结算前离开时仍可选择青花自身")
 e.choose_effect(self_choice())
 expect(blue.zone=="deck" and e.players[0].deck.size()>2 and e.players[0].deck[2].uid==blue.uid,"其他符卡离开后青花仍可将自身放入牌库顶第3张")

 print("BLUE_FLOWER: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
