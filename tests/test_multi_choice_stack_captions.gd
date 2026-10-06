extends "res://tests/support/rules_base.gd"
const StackPanel=preload("res://scripts/duel_stack.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")

func caption_seen_by_opponent() -> String:
 var remote=Remote.new()
 remote.apply_snapshot(SeatView.build(e,1))
 var panel=StackPanel.new()
 var caption=panel.chosen_mode(remote.stack.back())
 panel.free()
 return caption

func run():
 fresh();e.debug_enabled=true;e.debug_free_payment=true
 var ally=put("53")
 var spell=put("176","hand")
 var options=e.targets_for(spell.card_id,0,spell.uid)
 var twice=options.filter(func(option):return option.get("parts",[]).size()==2 and option.parts.all(func(part):return part.get("mode","")=="造成2点伤害" and part.get("uid",-1)==ally.uid))
 expect(not twice.is_empty(),"Alien Barrage offers the same damage choice twice")
 if not twice.is_empty():
  expect(e.commit_cast(0,spell.uid,twice[0],[]).is_empty(),"Alien Barrage enters the stack")
  expect(caption_seen_by_opponent()=="已选择：造成2点伤害 ×2","opponent sees both repeated Alien Barrage choices")

 fresh();e.debug_enabled=true;e.debug_free_payment=true
 put("character-ucs-038")
 var grave_unit=put("53","grave")
 spell=put("161","hand")
 options=e.targets_for(spell.card_id,0,spell.uid)
 var wheel=options.filter(func(option):return option.get("parts",[]).size()==2 and option.parts[0].get("mode","")=="全体强化" and option.parts[1].get("mode","")=="回收单位" and option.parts[1].get("uid",-1)==grave_unit.uid)
 expect(not wheel.is_empty(),"Cat Wheel offers its two distinct choices")
 if not wheel.is_empty():
  expect(e.commit_cast(0,spell.uid,wheel[0],[]).is_empty(),"Cat Wheel enters the stack")
  expect(caption_seen_by_opponent()=="已选择：己方单位获得+1/+0与+1、将目标墓地单位移回手上","opponent sees both Cat Wheel choices")

 fresh();e.debug_enabled=true;e.debug_free_payment=true
 put("character-htk-001")
 for i in range(4):put("164")
 var returned=put("53","grave")
 var other=e.make_card("106",1,"stack")
 e.stack.append({"id":100,"kind":"card","owner":1,"card":other,"target":{"none":true},"name":e.cards[other.card_id].name})
 e.next_stack=101
 spell=put("spell-htk-003","hand")
 options=e.targets_for(spell.card_id,0,spell.uid)
 expect(options.size()==1 and options[0].has("selection") and options[0].selection.size()==4,"Kokoro has four choice groups for four items")
 if not options.is_empty():
  var pool=options[0].selection[0].pool
  var damage=pool.filter(func(choice):return choice.get("mode","")=="造成1点伤害" and choice.get("player",-1)==1)
  var tax=pool.filter(func(choice):return choice.get("mode","")=="反制，除非支付1点" and choice.get("stack_id",-1)==100)
  var bounce=pool.filter(func(choice):return choice.get("mode","")=="移回手牌" and choice.get("uid",-1)==returned.uid)
  expect(not damage.is_empty() and not tax.is_empty() and not bounce.is_empty(),"Kokoro can choose damage, tax, and grave return")
  if not damage.is_empty() and not tax.is_empty() and not bounce.is_empty():
   var target={"selection_id":"emotions","picks":[[damage[0]],[damage[0]],[tax[0]],[bounce[0]]]}
   expect(e.commit_cast(0,spell.uid,target,[]).is_empty(),"Kokoro enters the stack with four choices")
   expect(caption_seen_by_opponent()=="（造成2点伤害，对手需要多支付1费，将1张目标道具或单位移回手上）","opponent sees Kokoro's compact counts")
 print("MULTI_CHOICE_STACK_CAPTIONS: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
