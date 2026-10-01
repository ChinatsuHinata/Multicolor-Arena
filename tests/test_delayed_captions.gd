extends "res://tests/support/rules_base.gd"
const Caption=preload("res://scripts/rules/ability_caption.gd")

func run():
 fresh()
 var actions={
  "sacrifice":"牺牲",
  "hand":"移回手牌",
  "exile":"移除",
  "return":"移回战场",
  "youmu_fight":"战斗判定",
  "token_sacrifice":"牺牲",
  "return_grave":"从墓地移回战场",
  "return_exile":"从除外区移回战场"
 }
 for op in actions:
  var caption=e.Cat.delay_caption({"origin_name":"来源牌","target_name":"目标牌","op":op})
  expect("来源：来源牌" in caption and "目标牌" in caption and actions[op] in caption,"delayed caption describes "+op)

 fresh()
 var origin=put("39")
 var target=put("53")
 e.Cat.delay(e,target,"sacrifice",0,"end",{},origin)
 e.run_delayed("end")
 expect(e.triggers.size()==1,"catalogue delay creates one trigger")
 if not e.triggers.is_empty():
  var caption=Caption.text(e.triggers[0])
  expect(e.cards[origin.card_id].name in caption and e.cards[target.card_id].name in caption and "牺牲" in caption,"catalogue stack caption retains origin and target")

 fresh()
 origin=put("39")
 target=put("53","exile")
 e.delayed.append({"owner":0,"phase":"end","effect":"return_exile","ref":e.ref_target(target),"zone":"exile","origin_name":e.cards[origin.card_id].name})
 e.run_delayed("end")
 expect(e.triggers.size()==1,"legacy delay creates one trigger")
 if not e.triggers.is_empty():
  var caption=Caption.text(e.triggers[0])
  expect(e.cards[origin.card_id].name in caption and e.cards[target.card_id].name in caption and "除外区" in caption,"legacy stack caption retains origin and target")

 fresh()
 origin=put("39")
 target=put("53")
 e.delayed.append({"owner":0,"phase":"end","effect":"token_sacrifice","ref":e.ref_target(target),"zone":"field","origin_name":e.cards[origin.card_id].name})
 e.run_delayed("end")
 expect(e.triggers.size()==1 and "牺牲" in Caption.text(e.triggers[0]),"legacy token sacrifice caption describes action")

 fresh()
 origin=put("39")
 e.delayed.append({"roster":true,"owner":0,"phase":"end","effect":"fairy_return","source":origin.duplicate(true)})
 e.run_delayed("end")
 expect(e.triggers.size()==1 and "来源："+e.cards[origin.card_id].name in Caption.text(e.triggers[0]) and "妖精单位移回手牌" in Caption.text(e.triggers[0]),"roster delay describes only its deferred effect")

 fresh()
 mana()
 var youmu=put("39")
 var spell=cast("spell-fdf-050",e.ref_target(youmu))
 expect(e.delayed.any(func(d):return d.get("effect","")=="youmu_fight" and d.get("origin_name","")==e.cards[spell.card_id].name),"real spell records the delayed effect source")
 e.advance_phase()
 expect(not e.stack.is_empty() and e.cards[spell.card_id].name in Caption.text(e.stack.back()) and "战斗判定" in Caption.text(e.stack.back()),"real spell stack caption shows its source and deferred fight")
 print("DELAYED_CAPTIONS: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
