extends "res://tests/test_v09_rules.gd"
func plain(who=0,power=1,health=1):
 var id="test_plain_"+str(e.next_uid)
 e.cards[id]=e.cards["27"].duplicate(true)
 e.cards[id].name=id;e.cards[id].kind="单位";e.cards[id].title="";e.cards[id].character="测试";e.cards[id].power=power;e.cards[id].health=health;e.cards[id].spirit=1;e.cards[id].abilities=[];e.cards[id].keywords=[]
 return put(id,"field",who)
func colored(colors,who=0):
 var c=plain(who);e.cards[c.card_id].colors=colors;return c
func many_mana(who):
 for id in ["165","167","166","164","168"]:
  for i in range(8):put(id,"palette",who)
func use(id,target,who=0):
 var c=put(id,"hand",who);e.priority=who
 var error=e.commit_cast(who,c.uid,target,e.payment(who,e.cast_cost(who,c,target)).plan)
 expect(error.is_empty(),"实际使用 "+id+" "+error)
 return c
func run():
 fresh()
 var corrections={"character-mar-023":{"红":1,"蓝":1},"character-fdn-026":{"蓝":1,"绿":1,"黑":1},"spell-fdf-021":{"绿":1,"黑":1},"spell-fdf-036":{"蓝":2,"黄":2},"spell-fdn-010":{"红":3,"蓝":2,"绿":1}}
 for id in corrections:
  expect(e.cards[id].cost.keys()==corrections[id].keys() and corrections[id].keys().all(func(k):return int(e.cards[id].cost[k])==corrections[id][k]),"费用勘误 "+id)
  expect(e.cards[id].colors==corrections[id].keys(),"颜色与筛选勘误 "+id)
 expect(e.cards["90"].spirit==2,"百鬼夜行灵力2")
 expect(e.cards["spell-rec-056"].canonical_id=="spell-kmo-003" and e.cards["spell-rec-056"].name==e.cards["spell-kmo-003"].name,"照国旧ID兼容且归为同一张牌")
 for id in ["79","character-fdn-036"]:
  fresh();many_mana(0);colored(["红","蓝","绿","黄","黑"])
  var c=put(id,"hand");c.leader=true;e.active=1;e.phase="prepare";e.priority=0
  expect(e.cast_error(0,c.uid).is_empty(),"射命丸文可在对手准备阶段使用 "+id)
  if id=="character-fdn-036":
   c.leader=false
   expect(not e.cast_error(0,c.uid).is_empty(),"传统记者非自机仍遵守使用时机")
  e.detach(c);e.enter_field(c,0);c.leader=true;e.pending={};e.triggers=[];e.priority=0
  var target=put("18")
  var k="leader_bounce" if id=="79" else "character-fdn-036:self"
  expect(e.extension_activation_error(0,c,k).is_empty(),"文启动式自机能力可在对手回合使用 "+id)
  expect(e.commit_extension(0,c.uid,e.ref_target(target),[],k).is_empty(),"文提交异能 "+id)
  one();expect(target.zone=="hand","文异能正确结算 "+id)
 for id in ["soi_unit_086","character-fdf-117"]:
  for color in ["红","蓝","绿"]:
   fresh();many_mana(0);colored(["黑",color]);var nue=put(id,"hand")
   expect(e.cast_error(0,nue.uid).is_empty(),"鵺黑+单一混色可使用 "+id+color)
  fresh();many_mana(0);colored(["黑"]);var nue=put(id,"hand")
  expect(not e.cast_error(0,nue.uid).is_empty(),"鵺仍要求至少一种红蓝绿 "+id)
 fresh();many_mana(0);colored(["黑","红","绿"]);var nue=put("character-fdf-117","hand")
 var reserved=[]
 for color in ["黑","红","绿","蓝","蓝"]:
  var resource=e.source_resources(0).filter(func(r):return color in r.colors and not reserved.any(func(x):return x.uid==r.uid))[0]
  reserved.append({"uid":resource.uid,"color":color})
 expect(e.payment_valid(0,e.cast_cost(0,nue),reserved),"平安鵺1黑+4点红蓝绿混合支付")
 expect(e.commit_cast(0,nue.uid,{},reserved).is_empty(),"平安鵺实际混合付费提交")
 fresh();var stairs=put("field-ucs-064");var a=put("79");var b=put("90")
 e.Cat.Units.on_enter(e,a);e.Cat.Units.on_enter(e,b)
 var stairs_triggers=e.triggers.filter(func(t):return t.effect=="field-ucs-064")
 expect(stairs_triggers.size()==2,"两个自机进場产生独立阶梯触发")
 expect(stairs_triggers[0].ability_text!=stairs_triggers[1].ability_text and e.cards[a.card_id].name in stairs_triggers[0].ability_text,"阶梯触发写明进场自机")
 fresh();var sanae=put("character-rei-026");sanae.leader=true;var another=put("character-smm07");another.leader=true
 e.Roster.pay_activation(e,sanae,"sanae_search",{"picks":[[]]})
 expect(not e.Roster.activation_error(e,sanae,"sanae_search").is_empty(),"早苗同一单位每局一次")
 expect(e.Roster.activation_error(e,another,"sanae_search").is_empty(),"另一实例早苗仍能使用每局一次能力")
 fresh();var stolen=plain(1);e.players[1].field.erase(stolen);stolen.owner=0;e.players[0].field.append(stolen)
 e.damage_target(e.ref_target(stolen),1);e.pump_choices()
 expect(stolen.zone=="grave" and stolen in e.players[1].grave and stolen not in e.players[0].grave,"受控单位死亡进入拥有者墓地")
 for go_home in [false,true]:
  fresh();var leader=e.players[1].leader;e.enter_field(leader,1);e.triggers=[];e.pending={}
  e.players[1].field.erase(leader);leader.owner=0;e.players[0].field.append(leader);e.to_grave(leader);e.pump_choices()
  expect(e.pending.kind=="leader_return" and e.pending.owner==1,"审视中的敌方自机由拥有者选择")
  e.choose_return(go_home)
  expect(leader.owner==1 and leader.zone==("leader" if go_home else "grave"),"审视自机选择后的区域/拥有者正确")
 fresh();var victim=plain();victim.plus_counters=3;e.damage_target(e.ref_target(victim),1);e.pump_choices()
 expect(victim.zone=="field" and e.stat(victim,"health")-victim.damage==3,"1/1加3指示物受伤仍存活")
 var receiver=put("90");receiver.leader=true;many_mana(0)
 use("137",e.ref_target(receiver));one()
 expect(victim.zone=="grave" and receiver.plus_counters==3,"百万鬼夜行移除指示物后立即死亡且转移完整")
 fresh();victim=plain();victim.plus_counters=1;victim.damage=1;victim.plus_counters=0;e.pump_choices()
 expect(victim.zone=="grave","选择/付费边界执行状态动作，不等下一次伤害")
 fresh();var branch=put("item-fdf-096");var leader=e.players[0].leader
 var entry={"effect":"item-fdf-096","source":branch.duplicate(true),"owner":0,"target":e.Pack.ref(e,leader)}
 e.Cat.resolve_activation(e,entry);expect(leader.zone=="field" and e.delayed.size()==1,"玉枝进场并登记结束牺牲")
 e.Roster.end_now(e);expect(e.delayed.is_empty() and leader.zone=="field","辉夜跳过结束时消费玉枝牺牲，不延期")
 e.pending={};e.triggers=[];e.run_delayed("end");expect(not e.triggers.any(func(t):return t.effect=="cat:delayed"),"下个结束阶段不补触发玉枝")
 fresh();many_mana(0);var reset=put("spell-ucs-014","hand");e.cards[reset.card_id].requires_character=""
 expect(e.targets_for(reset.card_id,0)==[{"none":true}],"一条归桥付款前不选重置对象")
 var plan=e.payment(0,e.cast_cost(0,reset)).plan;var paid_uids=plan.map(func(r):return r.uid)
 expect(e.commit_cast(0,reset.uid,{"none":true},plan).is_empty(),"一条归桥提交")
 one();expect(e.pending.kind=="effect_choice" and e.pending.trigger.effect=="reset_four_choose","一条归桥在结算时开启选择")
 var picks=paid_uids.map(func(uid):return e.Pack.ref(e,e.find_card(uid)))
 var choice=e.pending.options[0].duplicate(true);choice.erase("selection");choice.picks=[picks]
 e.choose_effect(choice);expect(paid_uids.all(func(uid):return not e.find_card(uid).tapped),"可重置刚用于支付一条归桥的资源")
 fresh();var blinker=plain();e.Pack.blink(e,blinker,0);e.active=0;e.phase="prepare";e.run_delayed("prepare");e.pump_choices()
 expect(e.stack.size()==1 and e.stack[0].effect=="delayed_return","八云紫回场作为延迟触发进入堆叠")
 expect(e.targets_for("123",1).any(func(t):return t.get("stack_id")==e.stack[0].id),"天狗防御能够选择回场触发")
 var trigger_id=e.stack[0].id;many_mana(1);put("79","field",1);use("123",{"stack_id":trigger_id},1);one()
 expect(e.stack.is_empty() and blinker.zone=="exile","反制紫回场触发后单位留在除外")
 for kind in ["时符","乐章"]:
  fresh();var timed=e.make_card("spell-fdf-017" if kind=="时符" else "spell-fdf-036",0,"stack");e.cards[timed.card_id].spell_type=kind
  e.stack.append({"id":e.next_stack,"kind":"card","card":timed,"owner":0,"name":e.cards[timed.card_id].name,"target":{"none":true},"rewritten_fairy":true});e.next_stack+=1
  one();expect(timed.zone=="field" and e.units(0).any(func(c):return e.cards[c.card_id].character=="妖精"),"巡礼改写后"+kind+"进场并造妖精")
 fresh();many_mana(0);put("78");var target=plain(1,5,8);var reaction=put("spell-fdf-018","field",1);e.cards["109"].requires_character="";var gungnir=use("109",e.ref_target(target));many_mana(1)
 var opponent=put("79","field",1);opponent.leader=true;var response=put("100","hand",1)
 expect(not e.cast_error(1,response.uid).is_empty() and not e.extension_activation_error(1,opponent,"leader_bounce").is_empty(),"冈格尼尔锁住对手使用牌与启动能力")
 expect(not e.triggers.any(func(t):return t.source.uid==reaction.uid) and not e.stack.any(func(t):return t.get("source",{}).get("uid")==reaction.uid),"冈格尼尔实际使用不让在场的测谎仪响应进入堆叠")
 for early in [false,true]:
  fresh();var brave=plain(0,2,4)
  if early:e.apply_turn_buff(e.ref_target(brave),{"英勇":true})
  e.attack(0,brave.uid)
  if not early:e.apply_turn_buff(e.ref_target(brave),{"英勇":true})
  e.combat={};e.triggers=[];e.pending={};e.stack=[];e.phase="main";e.active=0;e.advance_phase()
  expect(brave.tapped!=early,"仅宣攻时已有英勇才重置 "+str(early))
  expect(not e.stack.any(func(s):return s.get("effect")=="untap") and not e.triggers.any(func(s):return s.get("effect")=="untap"),"英勇重置不使用堆叠")
 fresh();var new_sanae=put("character-lof-003");new_sanae.leader=true;var miracle=put("106","hand")
 e.Extra.event(e,miracle,"miracle",true);e.pump_choices();e.choose_effect({"none":true});one()
 expect(e.stack.any(func(s):return s.get("effect")=="sanae_miracle"),"奇迹使用彼岸神想触发新早苗自机效果")
 fresh();var fairy=put("character-fdn-006");fairy.plus_counters=3;var copy=e.Cat.copy_token(e,0,fairy,true)
 expect(copy.plus_counters==3 and e.stat(copy,"health")==e.stat(fairy,"health"),"妖怪山妖精复制保留111指示物")
 var ordinary=e.Cat.copy_token(e,0,fairy)
 expect(ordinary.plus_counters==0,"其他复制效果没有擅自新增复制指示物规则")
 var loaded=JSON.parse_string(FileAccess.get_file_as_string(Store.SAVE_PATH))
 for deck in loaded.decks:
  expect(Store.validate(deck,true).is_empty(),"50+1自组卡组严格检查 "+deck.name)
 var d=loaded.decks[0].duplicate(true);d.main.pop_back();expect(not Store.validate(d,true).is_empty(),"49+1不能当作50主牌")
 d.main.append(d.leader);expect(not Store.validate(d,true).is_empty(),"保留自机同名禁入主牌规则")
 print("BUGS0921 RULES ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
