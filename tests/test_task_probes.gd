extends "res://tests/support/rules_base.gd"
const Codec=preload("res://net/state_codec.gd")

func stats(who: int=0) -> Dictionary:return e.task_evidence().players[who]

func prepare():
 fresh();e.debug_enabled=true;e.debug_free_payment=true

func announce(id: String,who: int=0,target: Dictionary={}) -> Dictionary:
 var c=put(id,"hand",who)
 if target.is_empty():
  var choices=e.targets_for(id,who,c.uid)
  if not choices.is_empty():target=choices[0]
 var error=e.commit_cast(who,c.uid,target,[])
 expect(error.is_empty(),"实际宣告 "+id+": "+error)
 return c

func damage_and_life():
 prepare()
 var source=put("spell-ucs-041","hand")
 e.damage_context={"source":source,"combat":false,"single":true}
 e.players[1].wards=[{"amount":3,"turn":e.turn}]
 e.damage_target({"player":1},7)
 expect(stats().player_damage==4 and stats().royal_flare_damage==4,"仅统计防止后的玩家伤害和皇家烈焰来源")
 e.players[1].next_damage_prevention_turn=e.turn
 e.damage_target({"player":1},10)
 expect(stats().player_damage==4,"完全防止的伤害不计数")
 e.gain_life(0,7);e.gain_life(0,-3)
 expect(stats().life_recovered==7,"回复按实际正值累加")
 put("spell-fdn-002","field")
 e.gain_life(0,8)
 expect(stats().life_recovered==7,"被禁止的回复不计数")
 var attacker=put("53","field")
 e.combat_hit(attacker,{"player":1},2)
 expect(stats().unit_combat_player_damage==2 and stats().player_damage==6,"单位战斗打脸与总伤害独立统计")
 e.players[1].life=3;e.damage_context={"source":source,"combat":false,"single":true}
 e.damage_target({"player":1},12);e.judge()
 expect(e.winner==0 and stats().overkill==9 and stats().enemy_final_life==-9,"最终过量伤害记录实际致死伤害")
 var snap=e.task_evidence();snap.players[0].player_damage=99999
 expect(stats().player_damage==18,"证据是独立副本，查询不能修改引擎计数")
 prepare();e.players[1].life=-9;e.judge()
 expect(stats().overkill==0,"纯生命失去不冒充过量伤害")

func destructions():
 prepare()
 var source=put("96","hand")
 e.damage_context={"source":source,"combat":false,"single":true}
 var unit=put("53","field",1)
 e.damage_target(e.ref_target(unit),20);e.damage_context={};e.judge()
 expect(stats().units_destroyed==1 and stats(1).units_lost==1,"致死伤害跨伤害上下文后仍按来源归属")
 e.damage_context={"source":source,"combat":false,"single":true}
 var own=put("53","field");e.destroy(own)
 expect(stats().units_destroyed==2,"自己造成的消灭也符合不限敌我的任务文本")
 var item=put("item-ucs-013","field",1);e.destroy(item)
 var barrier=put("field-smm-004","field",1);e.destroy(barrier)
 expect(stats().items_destroyed==1 and stats().barriers_destroyed==1,"道具与结界分别统计")
 var sacrifice=put("53","field",1);e.sacrifice(sacrifice)
 var exile=put("53","field",1);e.move_to(exile,"exile")
 var bounce=put("53","field",1);e.move_to(bounce,"hand")
 var protected=put("53","field",1);protected.extra_keywords=["不会被消灭"];e.destroy(protected)
 expect(stats().units_destroyed==2,"牺牲、移除、回手和消灭失败都不算消灭")
 var dying=put("5","field",1);e.destroy(dying)
 expect(stats(1).death_triggers==1,"真实死去时效果被触发即统计")
 var suppressed=put("character-ucs-066","field")
 e.destroy(put("5","field",1))
 expect(stats(1).death_triggers==1,"被禁止触发的死去时能力不计数")
 e.move_to(suppressed,"exile")

func permanent_removals():
 for who in range(2):
  prepare()
  var source=put("96","hand",who)
  e.damage_context={"source":source,"combat":false,"single":true}
  e.sacrifice(put("item-ucs-013","field",who))
  e.sacrifice(put("field-smm-004","field",who))
  e.move_to(put("item-ucs-013","field",1-who),"exile")
  e.destroy(put("field-smm-004","field",1-who))
  expect(stats(who).items_barriers_removed==4 and stats(1-who).items_barriers_removed==0,"两种类别三种操作合计四个，仅归属执行玩家")
  var saved=Codec.capture(e)
  var snapshot=e.task_evidence()
  e.sacrifice(put("53","field",who));e.move_to(put("53","field",1-who),"exile");e.destroy(put("53","field",1-who))
  var protected=put("item-ucs-013","field",1-who);protected.extra_keywords=["不会被消灭"];e.destroy(protected)
  e.sacrifice(put("field-smm-004","hand",who))
  e.move_to(put("item-ucs-013","field",1-who),"hand")
  e.move_to(put("field-smm-004","hand",who),"grave")
  e.move_to(put("field-smm-004","field",who),"grave")
  expect(stats(who).items_barriers_removed==4 and protected.zone=="field","单位、回手、弃牌、普通入墓和操作失败不增加合并进度")
  for kind in ["item-ucs-013","field-smm-004"]:
   for action in ["sacrifice","destroy","exile"]:
    var token=put(kind,"field",who);token.token=true
    if action=="exile":e.move_to(token,"exile")
    else:e.call(action,token)
    expect(token.zone=="void","道具或结界衍生物离场后消失")
  expect(stats(who).items_barriers_removed==10,"衍生物的三种离场各计一次")
  for action in ["sacrifice","destroy"]:
   var replaced=put("item-ucs-013","field",who);replaced.exile_on_grave=true
   var before=stats(who).items_barriers_removed
   e.call(action,replaced)
   expect(replaced.zone=="exile" and stats(who).items_barriers_removed==before+1,"入墓替代为移除不会重复计数")
  for zone in ["grave","hand","deck"]:
   var exiled=put("field-smm-004",zone,1-who)
   var before=stats(who).items_barriers_removed
   e.move_to(exiled,"exile");e.move_to(exiled,"exile")
   expect(stats(who).items_barriers_removed==before+1,"其他区域实际移除计一次，重复移除不计")
  var before=stats(who).items_barriers_removed
  var controlled=put("item-ucs-013","field",who);controlled.original_owner=1-who
  e.damage_context={};e.sacrifice(controlled)
  e.move_to(put("field-smm-004","field",who),"exile")
  expect(stats(who).items_barriers_removed==before+2 and stats(1-who).items_barriers_removed==0,"牺牲受控道具及无来源的自身移除归属操控者")
  e.damage_context={"source":source};e.sacrifice(put("field-smm-004","field",1-who))
  expect(stats(1-who).items_barriers_removed==1,"令对方牺牲时由实际牺牲方获得进度")
  expect(Codec.restore(e,saved).is_empty() and e.task_evidence()==snapshot,"存档恢复及悔棋还原合并任务计数")

func casts_and_tokens():
 prepare()
 announce("129");one()
 expect(stats().non_spells==1 and stats().tokens_created==2,"真实非符施放制造两个衍生物")
 e.priority=0
 var card=announce("53");one()
 expect(stats().unit_cards==1 and stats().units_entered==3,"使用单位牌与衍生入场分开计数")
 e.priority=0;announce("96",0,{"player":1});one()
 expect(stats().fast_spells==1 and stats().cast_cards.get("96",0)==1,"高速符卡施放及卡牌ID计数")
 var before=stats().cards_cast
 expect(not e.commit_cast(0,card.uid,{},[]).is_empty() and stats().cards_cast==before,"非法使用不产生探针")
 var saved=Codec.capture(e);var expected=e.task_evidence()
 e.task_probe(0,"player_damage",10)
 expect(Codec.restore(e,saved).is_empty() and e.task_evidence()==expected,"存档恢复与撤销同时恢复任务计数")
 var serialized=JSON.stringify(e.task_evidence())
 expect(not '"hand"' in serialized and not '"deck"' in serialized and not '"target"' in serialized,"公开证据不包含手牌、牌库或目标明细")
 expect(stats().leader_id=="70" and not stats().leader_colors.is_empty(),"记录开局自机身份和颜色")

func counterplay():
 prepare();put("70","field")
 e.priority=1;announce("96",1,{"player":0})
 announce("100");one()
 expect(e.pending.get("trigger",{}).get("effect","")=="counter_resolution","梦想封印结算进入选择")
 if e.pending.has("options"):e.choose_effect(e.pending.options[0])
 expect(stats().spell_counters==1 and stats().direct_counters==1,"真实高速符卡反制符卡只统计一次")
 prepare();put("70","field")
 announce("96",0,{"player":1});e.pass_priority(1)
 announce("100");one()
 if e.pending.has("options"):e.choose_effect(e.pending.options[0])
 expect(stats().spell_counters==1 and e.stack.is_empty(),"真正反制自己的另一张符卡也符合不限敌我的任务文本")
 prepare();var youmu=put("39","field");e.priority=1
 announce("96",1,e.ref_target(youmu));var countered=e.stack.back()
 announce("118",0,{"stack_id":countered.id});one()
 expect(stats().cast_cards.get("118",0)==1 and stats().character_spells==1 and stats().spell_counters==1,"六根清净斩实际宣告和成功反制分别统计")
 for id in ["spell-fdn-066","spell-fdn-069"]:
  prepare();e.priority=1;announce("96",1,{"player":0})
  announce(id);one()
  var target=e.pending.options.filter(func(t):return t.has("stack_id"))[0]
  e.choose_effect(target)
  expect(stats().spell_counters==1 and stats().indirect_counters==1,id+"成功间接反制统计")
 prepare()
 # Select a real Reisen unit, independent of any print's card ID.
 for id in e.cards:
  if e.cards[id].kind in ["单位","自机"] and "铃仙" in e.cards[id].get("character",""):
   put(id,"field");break
 e.priority=1;announce("96",1,{"player":0})
 var entry=e.stack.back()
 announce("spell-fdf-052",0,{"stack_id":entry.id});one()
 expect(e.pending.get("trigger",{}).get("effect","")=="cat:retarget","赤眼催眠请求重新选择目标")
 if e.pending.get("trigger",{}).get("effect","")=="cat:retarget":
  var target=e.pending.options.filter(func(t):return t.get("player",-1)==1)[0]
  e.choose_effect(target)
  expect(stats().spell_counters==1 and entry.target.get("player",-1)==1,"赤眼催眠实际改变对方符卡目标计数")

func royal_kills():
 prepare()
 e.combat_hit(put("53","field"),{"player":1},2)
 e.players[1].life=3;e.players[0].drawn[str(e.turn)]=2
 var info=e.cards["spell-ucs-041"]
 for id in e.cards:
  if e.cards[id].kind in ["单位","自机"] and e.Roster.character_matches(e.cards[id].get("character",""),info.requires_character):
   put(id,"field");break
 announce("spell-ucs-041",0,{"player":1});one()
 expect(e.winner==0 and stats().enemy_final_life==0 and stats().royal_flare_kill,"真实皇家烈焰结算造成致死伤害")
 expect(stats().player_damage==5 and stats().royal_flare_damage==3 and stats().unit_combat_player_damage==2,"皇家烈焰击杀允许此前有其他来源和单位战斗伤害")
 expect(not stats(1).royal_flare_kill,"击杀仅归属伤害来源操控者")
 expect(not "_damage_" in JSON.stringify(e.task_evidence()),"公开摘要不泄漏内部伤害来源标记")
 prepare();var royal=put("spell-ucs-041","hand")
 e.players[1].life=3;e.damage_context={"source":royal,"combat":false}
 e.damage_target({"player":1},1)
 e.damage_context={"source":put("96","hand"),"combat":false}
 e.damage_target({"player":1},2);e.judge()
 expect(e.winner==0 and not stats().royal_flare_kill,"先使用皇家烈焰但由其他牌击杀不算")
 prepare();royal=put("spell-ucs-041","hand")
 e.players[1].life=3;e.damage_context={"source":royal,"combat":false}
 e.damage_target({"player":1},1);e.players[1].life-=2;e.judge()
 expect(e.winner==0 and not stats().royal_flare_kill,"皇家烈焰非致死后因生命失去获胜不算")
 prepare();royal=put("spell-ucs-041","hand")
 e.players[1].life=3;e.damage_context={"source":royal,"combat":false}
 e.damage_target({"player":1},3)
 var saved=Codec.capture(e)
 e.task_stats[1]._damage_card="96"
 expect(Codec.restore(e,saved).is_empty(),"规则存档恢复皇家烈焰伤害来源")
 e.judge()
 expect(e.winner==0 and stats().royal_flare_kill,"恢复后仍可识别皇家烈焰击杀")
 prepare();royal=put("spell-ucs-041","hand",1)
 e.players[1].life=3;e.damage_context={"source":royal,"combat":false}
 e.damage_target({"player":1},3);e.judge()
 expect(e.winner==0 and not stats().royal_flare_kill and not stats(1).royal_flare_kill,"敌方自己对自己造成皇家烈焰致死不计我方击杀")
 prepare();royal=put("spell-ucs-041","hand")
 e.players[0].life=3;e.damage_context={"source":royal,"combat":false}
 e.damage_target({"player":0},3);e.judge()
 expect(e.winner==1 and not stats().royal_flare_kill and not stats(1).royal_flare_kill,"皇家烈焰自伤致死不冒充胜方击杀")
 prepare();royal=put("spell-ucs-041","hand",1)
 e.players[0].life=3;e.damage_context={"source":royal,"combat":false}
 e.damage_target({"player":0},4);e.judge()
 expect(e.winner==1 and stats(1).royal_flare_kill and stats(1).enemy_final_life==-1,"二号玩家皇家烈焰过量击杀同样识别")
 prepare();royal=put("spell-ucs-041","hand")
 e.players[1].life=3;e.damage_context={"source":royal,"combat":false}
 e.players[1].next_damage_prevention_turn=e.turn
 e.damage_target({"player":1},3);e.surrender(1)
 expect(e.winner==0 and not stats().royal_flare_kill,"皇家烈焰伤害被防止后对手投降不算击杀")
 prepare();royal=put("spell-ucs-041","hand")
 e.players[0].life=0;e.players[1].life=3;e.damage_context={"source":royal,"combat":false}
 e.damage_target({"player":1},3);e.judge()
 expect(e.winner==-1 and not stats().royal_flare_kill,"双方生命归零平局不算皇家烈焰击杀获胜")

func final_deck_sizes():
 for who in range(2):
  prepare()
  var own_size=e.players[who].deck.size()
  e.players[1-who].deck=e.players[1-who].deck.slice(0,6)
  var saved=Codec.capture(e);var snapshot=e.task_evidence()
  e.draw(1-who)
  expect(stats(who).enemy_final_deck==5 and stats(1-who).enemy_final_deck==own_size,"双方牌库余量按对手实际剩余张数记录")
  expect(snapshot.players[who].enemy_final_deck==6,"抽牌不会改变已取得的数量快照")
  e.players[1-who].life=1;e.damage_context={"source":put("96","hand",who),"combat":false}
  e.damage_target({"player":1-who},1);e.judge()
  expect(e.winner==who and stats(who).enemy_final_deck==5 and stats(who).win_reason=="normal","普通伤害胜利同样记录对方剩余五张牌")
  expect(Codec.restore(e,saved).is_empty() and stats(who).enemy_final_deck==6,"恢复与悔棋后重新读取实际牌库数量")
  e.players[1-who].deck=[];e.draw(1-who)
  expect(e.winner==who and stats(who).enemy_final_deck==0,"磨空牌库胜利记录零张")

func victories():
 prepare();e.players[1].deck=[];e.draw(1)
 expect(e.winner==0 and stats().win_reason=="mill","磨牌胜因来自真实抓空牌库")
 prepare();var komachi=put("character-kmo-001","field");komachi.leader_counters=1;e.add_coin(1,3)
 expect(e.winner==0 and stats().win_reason=="coin","三个铜钱指示物触发投钱胜利")
 prepare()
 var gate=put("spell-fdf-068","hand")
 for id in e.cards:
  if e.cards[id].kind in ["单位","自机"] and e.Roster.character_matches(e.cards[id].get("character",""),e.cards[gate.card_id].requires_character):
   put(id,"field");break
 e.players[0].deck=[]
 var error=e.commit_cast(0,gate.uid,e.targets_for(gate.card_id,0)[0],[])
 expect(error.is_empty(),"实际使用门符："+error);one()
 expect(e.winner==0 and stats().win_reason=="gate","门符胜因来自真实结算")
 for id in ["121","spell-fdf-008"]:
  prepare()
  var info=e.cards[id]
  for role in e.cards:
   if e.cards[role].kind in ["单位","自机"] and e.Roster.character_matches(e.cards[role].get("character",""),info.requires_character):
    put(role,"field");break
  announce(id)
  expect(stats().cast_cards.get(id,0)==1 and stats().character_spells==1,"指定大符实际宣告即计数："+id)

func run():
 damage_and_life();destructions();permanent_removals();casts_and_tokens();counterplay();royal_kills();final_deck_sizes();victories()
 print("TASK PROBES: %d checks, %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
