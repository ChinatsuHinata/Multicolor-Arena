extends "res://tests/support/rules_base.gd"

func run():
 fresh()
 var sakuya=put("75");sakuya.leader=true
 var doll=put("spell-fdf-017");doll.timer=2
 var time_spell=e.make_card("102",0,"stack")
 var victim=put("27","field",1)
 e.Extra.spell_resolve(e,{"card":time_spell,"owner":0,"target":{"none":true}});e.pump_choices()
 expect(e.pending.get("kind","")=="timer","单色时符进场计时可由咲夜选择")
 e.choose_timer(1)
 expect(time_spell.timer==3,"咲夜加一后计时为三")
 expect(e.triggers.any(func(t):return t.get("effect","")=="cat:murder_dolls" and t.get("data",{}).get("amount",0)==3) or e.stack.any(func(t):return t.get("effect","")=="cat:murder_dolls" and t.get("data",{}).get("amount",0)==3),"杀人玩偶按改变后的计时计算伤害")
 if e.pending.get("kind","")=="effect_choice":
  var hit=e.pending.options[0].duplicate(true);hit.erase("selection");hit.picks=[[e.Pack.ref(e,victim)]]
  e.choose_effect(hit);one()
 expect(victim.zone=="grave","杀人玩偶实际造成改变后的三点伤害")

 fresh();sakuya=put("75");sakuya.leader=true
 time_spell=e.make_card("102",0,"stack")
 e.Extra.spell_resolve(e,{"card":time_spell,"owner":0,"target":{"none":true}});e.pump_choices()
 e.choose_timer(-1)
 expect(time_spell.timer==1,"咲夜可将单色时符进场计时减一")

 fresh()
 var branch=put("item-fdf-096")
 var reserve=put("78","palette")
 var target=put("79","palette")
 expect(e.activation_options(branch,"item-fdf-096")==[{"none":true}],"玉枝启动时不选择自机")
 expect(e.commit_extension(0,branch.uid,{"none":true},[],"item-fdf-096").is_empty(),"玉枝可无目标启动")
 e.move_to(reserve,"grave")
 one()
 expect(e.pending.get("kind","")=="effect_choice" and e.pending.trigger.effect=="cat:jade_branch","玉枝结算时选择自机")
 e.choose_effect(e.pending.options.filter(func(option):return option.uid==target.uid)[0])
 expect(target.zone=="field" and e.delayed.size()==1,"玉枝记录延迟牺牲")
 e.Roster.end_now(e)
 expect(e.delayed.size()==1 and target.zone=="field","跳过结束阶段后玉枝牺牲仍待触发")
 e.active=1;e.phase="main";e.advance_phase()
 expect(e.delayed.is_empty() and (e.triggers.any(func(t):return t.get("effect","")=="cat:delayed") or e.stack.any(func(t):return t.get("effect","")=="cat:delayed") or e.pending.get("trigger",{}).get("effect","")=="cat:delayed"),"对方结束阶段触发玉枝牺牲")

 for id in ["100","spell-rei-012"]:
  fresh();mana();put("70")
  var incoming=e.make_card("27",1,"stack")
  e.stack.append({"id":e.next_stack,"kind":"card","card":incoming,"owner":1,"target":{"none":true},"name":"待反制的牌"});e.next_stack+=1
  var counter=put(id,"hand")
  expect(e.targets_for(id,0)==[{"none":true}],id+"使用时不指定反制牌")
  var cast_error=e.commit_cast(0,counter.uid,{"none":true},e.payment(0,e.cast_cost(0,counter)).plan)
  expect(cast_error.is_empty(),id+"可以无目标使用")
  one()
  expect(e.pending.get("kind","")=="effect_choice" and e.pending.trigger.effect=="counter_resolution",id+"结算时才选择反制牌")
  if e.pending.get("kind","")=="effect_choice":
   var choice=e.pending.options[0]
   e.choose_effect(choice)
   expect(incoming.zone=="grave",id+"反制所选的牌")

 fresh();mana();put("70")
 var expensive=e.make_card("spell-fdf-017",1,"stack")
 e.stack.append({"id":e.next_stack,"kind":"card","card":expensive,"owner":1,"target":{"none":true},"name":"高费符卡"});e.next_stack+=1
 expect(e.targets_for("spell-rei-012",0).is_empty(),"小梦想封印不能用于只有高费牌的堆叠")
 var cheap=e.make_card("27",1,"stack")
 e.stack.append({"id":e.next_stack,"kind":"card","card":cheap,"owner":1,"target":{"none":true},"name":"低费单位"});e.next_stack+=1
 var small=put("spell-rei-012","hand")
 expect(e.commit_cast(0,small.uid,{"none":true},e.payment(0,e.cast_cost(0,small)).plan).is_empty(),"小梦想封印无目标使用时堆叠可同时有高低费牌")
 one()
 expect(e.pending.options.size()==1 and e.pending.options[0].stack_id==e.stack.back().id,"小梦想封印结算时只提供低费牌")
 e.choose_effect(e.pending.options[0])
 expect(cheap.zone=="grave" and expensive.zone=="stack","小梦想封印只反制所选低费牌")

 for id in ["spell-fdf-075","spell-fdf-076","spell-fdf-077","spell-fdf-078","spell-fdf-079"]:
  fresh();mana();put("character-mar-021");put("27","field",1)
  var revealed=put(id,"deck")
  e.players[0].deck.erase(revealed);e.players[0].deck.push_front(revealed)
  e.Cat.reveal(e,[revealed]);e.pump_choices()
  expect(e.pending.get("kind","")=="effect_choice",id+"展示后可选择移除")
  if e.pending.get("kind","")=="effect_choice":e.choose_effect(e.pending.options[0])
  if not e.stack.is_empty():one()
  expect(revealed.zone=="exile",id+"展示后被移除")
  expect(e.pending.get("kind","")=="effect_choice" and e.pending.trigger.effect=="cat:grant",id+"移除后可选择使用")
  if e.pending.get("kind","")=="effect_choice":e.choose_effect(e.pending.options[0])
  expect(revealed.zone=="stack",id+"可从移除区使用")

 fresh();mana();put("character-mar-021")
 var moved=put("spell-fdf-077","deck")
 e.players[0].deck.erase(moved);e.players[0].deck.push_front(moved)
 e.Cat.reveal(e,[moved]);e.move_to(moved,"hand");e.pump_choices()
 if e.pending.get("kind","")=="effect_choice":e.choose_effect(e.pending.options[0])
 if not e.stack.is_empty():one()
 expect(moved.zone=="exile" and e.pending.get("trigger",{}).get("effect","")=="cat:grant","展示后先进入手牌的五行符卡仍可移除并使用")
 if e.pending.get("kind","")=="effect_choice":e.choose_effect(e.pending.options[0])
 expect(moved.zone=="stack","展示后移动的五行符卡完成使用")

 print("CARD TIMING ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
