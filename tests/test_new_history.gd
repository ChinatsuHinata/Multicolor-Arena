extends "res://tests/support/rules_base.gd"

const HISTORY="spell-fdf-009"
const KEINE="character-fdf-ex05"

func bonus(remaining: int=2):
 e.players[0].exile_free={"turn":e.turn,"remaining":remaining}

func denied(c: Dictionary,title: String):
 expect(not e.Pack.cast_from(e,c,0),title+"：没有移除区使用资格")
 expect(e.cast_error(0,c.uid)=="无法从该区域使用",title+"：先检查使用资格")
 expect(not e.legal_casts(0).any(func(option):return option.uid==c.uid),title+"：不出现在可用牌列表")

func history_and_devour():
 fresh();mana()
 var teacher=put(KEINE)
 var consumed=[]
 for id in ["78","99","53"]:consumed.append(put(id,"deck",1))
 for c in consumed:e.players[1].deck.erase(c)
 e.players[1].deck=consumed+e.players[1].deck
 cast(HISTORY,{"player":1})
 expect(consumed.all(func(c):return c.zone=="exile" and c.get("devour_owner",-1)==0),"现代史移除对手前三张牌并放置自己的吞食指示物")
 expect(e.players[0].exile_free.remaining==2,"现代史给予本回合前两张的豁免")
 for c in consumed:denied(c,"慧音没有自机能力 "+c.card_id)
 teacher.leader=true
 for owner in [0,1]:
  var ordinary=put("53","exile",owner)
  denied(ordinary,"无其他授权的移除牌，所属玩家 "+str(owner))
  ordinary.devour_owner=1
  denied(ordinary,"对方放置的吞食指示物，所属玩家 "+str(owner))
 var error=e.commit_cast(0,e.players[0].exile[0].uid,{"none":true},[])
 expect(not error.is_empty() and e.stack.is_empty() and e.players[0].exile_free.remaining==2,"拒绝非法使用时不消耗豁免次数或移动牌")
 if error.is_empty():return

 var self_card=consumed[0]
 expect(e.cast_error(0,self_card.uid).is_empty(),"慧音在场且具有自机能力时，吞食牌获得使用资格并豁免自机颜色约束")
 expect(e.cast_cost(0,self_card).values().all(func(amount):return int(amount)==0),"合法的移除区自机无需支付颜色值")
 error=e.commit_cast(0,self_card.uid,{"none":true},[])
 expect(error.is_empty() and self_card.zone=="stack" and self_card.owner==0,"可以使用具有自己吞食指示物的对方自机："+error)
 settle();e.priority=0
 expect(self_card.zone=="field" and e.players[0].exile_free.remaining==1,"第一张合法移除牌消耗一次豁免")
 var role_spell=consumed[1]
 expect(e.cast_error(0,role_spell.uid).is_empty() and e.character_constraint_error(role_spell,0).is_empty(),"第二张合法移除区角色符豁免对应角色单位约束")
 error=e.commit_cast(0,role_spell.uid,{"player":1},[])
 expect(error.is_empty() and role_spell.zone=="stack" and e.players[0].exile_free.remaining==0,"第二张角色符免费使用并用尽豁免："+error)
 settle();e.priority=0
 expect(role_spell.zone=="grave" and e.players[1].life==15,"免费角色符仍正常结算")
 expect(not e.cast_cost(0,consumed[2]).is_empty(),"前两张之后，仍有使用资格的牌恢复颜色费用")
 var later=put("99","exile",1);later.devour_owner=0
 expect(e.Pack.cast_from(e,later,0) and e.cast_error(0,later.uid)=="需要操控雾雨魔理沙","前两张之后，仍有使用资格的角色符恢复单位约束")

func recheck_teacher():
 fresh()
 var teacher=put(KEINE);teacher.leader=true
 var spell=put("99","exile",1);spell.devour_owner=0;bonus()
 expect(e.cast_error(0,spell.uid).is_empty(),"确认前，慧音允许使用自己的吞食牌")
 e.move_to(teacher,"exile")
 denied(spell,"确认时慧音已经离场")
 var error=e.commit_cast(0,spell.uid,{"player":1},[])
 expect(not error.is_empty() and spell.zone=="exile" and e.players[0].exile_free.remaining==2,"提交使用时重新检查慧音资格，失败保留豁免")

 fresh();mana()
 teacher=put(KEINE);teacher.leader=true
 spell=put("78","exile",1);spell.devour_owner=0;bonus()
 e.phase="end"
 expect(e.cast_error(0,spell.uid)=="只能在自己主要阶段的空对抗时使用","现代史不豁免使用时机")
 e.phase="main";e.turn+=1
 expect(e.Pack.cast_from(e,spell,0) and e.cast_error(0,spell.uid)=="战场永久物尚未满足自机颜色约束","跨回合保留吞食使用资格，但颜色豁免到期")

func other_permissions():
 fresh();mana();put("character-mar-021")
 var reserved=put(HISTORY,"hand")
 var wood=put("spell-fdf-079","hand")
 var error=e.commit_cast(0,wood.uid,{"none":true},e.payment(0,e.cast_cost(0,wood)).plan)
 expect(error.is_empty(),"使用帕秋莉木符："+error)
 one()
 expect(e.pending.get("trigger",{}).get("effect","")=="cat:wood","木符结算时选择移除角色符")
 if e.pending.get("trigger",{}).get("effect","")!="cat:wood":return
 e.choose_effect(e.Pack.ref(e,reserved));e.priority=0
 expect(reserved.zone=="exile" and reserved.get("catalogue_access",{}).get("owner",-1)==0,"木符实际移除角色符并给予使用资格")
 expect(e.cast_error(0,reserved.uid)=="需要操控上白泽慧音","木符单独提供资格仍要求对应角色单位")
 bonus()
 expect(e.cast_error(0,reserved.uid).is_empty() and e.cast_cost(0,reserved).is_empty(),"现代史对木符授权的牌豁免角色单位并免费")
 error=e.commit_cast(0,reserved.uid,{"player":1},[])
 expect(error.is_empty() and reserved.zone=="stack" and e.players[0].exile_free.remaining==1,"木符移除的角色符可以消耗现代史豁免使用："+error)

 fresh()
 var seiran=put("character-mar-022")
 var moon=put("spell-fdf-024","hand")
 e.Pack.resolve_trigger(e,{"source":seiran,"effect":"seiran_exile","owner":0,"target":{"none":true},"data":{}})
 expect(e.pending.get("trigger",{}).get("effect","")=="seiran_resolve","清兰选择移除蓝色符卡")
 if e.pending.get("trigger",{}).get("effect","")!="seiran_resolve":return
 var target=e.pending.options[0].duplicate(true);target.erase("selection");target.picks=[[e.Pack.ref(e,moon)]]
 e.choose_effect(target);e.priority=0
 expect(moon.zone=="exile" and moon.get("free_exile_owner",-1)==0,"清兰实际移除符卡并给予使用资格")
 expect(e.cast_error(0,moon.uid)=="需要操控帕秋莉·诺蕾姬","清兰免费使用的角色符仍要求对应角色单位")
 bonus()
 expect(e.cast_error(0,moon.uid).is_empty() and e.cast_cost(0,moon).is_empty(),"现代史对清兰授权的牌豁免角色单位")
 var choices=e.targets_for(moon.card_id,0,moon.uid)
 expect(not choices.is_empty() and choices.all(func(option):return int(option.get("x",0))==0),"不支付颜色值使用时X仍为0")
 if choices.is_empty():return
 error=e.commit_cast(0,moon.uid,choices[0],[])
 expect(error.is_empty() and moon.zone=="stack" and e.players[0].exile_free.remaining==1,"清兰移除的角色符可以消耗现代史豁免使用："+error)

func run():
 history_and_devour()
 recheck_teacher()
 other_permissions()
 print("NEW_HISTORY: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
