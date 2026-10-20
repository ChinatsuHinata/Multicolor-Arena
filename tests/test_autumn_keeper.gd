extends "res://tests/support/rules_base.gd"

const AUTUMN="new-loc-006"
const Hints=preload("res://scripts/rules/card_condition_hints.gd")
const Codec=preload("res://net/state_codec.gd")
const Seat=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")

func setup_autumn() -> Dictionary:
 fresh();mana()
 e.players[0].leader=e.make_card("74",0,"leader",true)
 var unit=put("54","field",1)
 return {"spell":put(AUTUMN,"hand"),"unit":unit}

func submit(fixture: Dictionary) -> String:
 var target=e.ref_target(fixture.unit)
 return e.commit_cast(0,fixture.spell.uid,target,e.payment(0,e.cast_cost(0,fixture.spell,target)).plan)

func public_state() -> String:
 return JSON.stringify([e.players,e.stack,e.pending,e.history,e.revision])

func run():
 construction()
 cast_conditions()
 targets_and_payment()
 resolution()
 network_and_restore()
 print("AUTUMN_KEEPER: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func construction():
 var f=setup_autumn();var info=e.cards[AUTUMN]
 expect(info.name=="「幻想ノ秋司」" and info.kind=="符卡" and info.colors==["红","黄"] and info.cost.size()==2 and int(info.cost.get("红",0))==1 and int(info.cost.get("黄",0))==1,"卡面名称、类别与红黄各一费用")
 expect(info.fast and info.spell_type=="符卡·高速" and info.landscape and info.time==0 and info.requires_character.is_empty(),"高速横向符卡，没有计时或角色约束")
 expect(DB.validate_definition(JSON.parse_string(FileAccess.get_file_as_string("res://cards/"+AUTUMN+".json")),AUTUMN).is_empty(),"本体卡牌资料通过正式数据库校验")
 var texture=Store.Art.load_texture(info.image)
 expect(texture!=null and texture.get_width()>texture.get_height(),"用户提供的横向卡图可加载")
 for rule in [Store.RuleSet.OFFICIAL,Store.RuleSet.UNRESTRICTED]:
  expect(Store.RuleSet.allowed(AUTUMN,info,rule) and Store.RuleSet.limit(AUTUMN,info,rule)==4,"开放常规构筑，同名至多四张："+rule)
 var deck=Store.blank("秋司官限测试");deck.leader="74"
 for i in range(3):expect(Store.add_card(deck,AUTUMN,"main",Store.RuleSet.OFFICIAL).is_empty(),"官限主卡组加入秋司："+str(i+1))
 expect(Store.add_card(deck,AUTUMN,"side",Store.RuleSet.OFFICIAL).is_empty(),"官限备牌可加入第四张")
 expect(not Store.add_card(deck,AUTUMN,"main",Store.RuleSet.OFFICIAL).is_empty(),"主备合计第五张被拒绝")
 expect(Store.validate(deck,false,Store.RuleSet.OFFICIAL).is_empty(),"含秋司的官限卡组通过构筑校验")
 expect(Hints.actionable(e,f.spell,0),"满足条件、支付及目标时显示可使用提示")

func cast_conditions():
 var f=setup_autumn()
 expect(e.cast_error(0,f.spell.uid).is_empty(),"对手战场和自机区中的人类不阻止使用")
 for who in [0,1]:
  for zone in ["hand","deck","palette","grave","exile"]:put("9",zone,who)
 put("9","field",1)
 e.players[1].extra_leaders=[e.make_card("70",1,"leader",true)]
 expect(e.cast_error(0,f.spell.uid).is_empty() and Hints.active(e,f.spell),"双方其他五区及对方战场、主额外自机区的人类均不阻止使用")
 var human=put("9")
 expect(e.cast_error(0,f.spell.uid).contains("人类") and not Hints.active(e,f.spell),"己方战场人类阻止使用并清除条件提示")
 var before=public_state()
 expect(not submit(f).is_empty() and public_state()==before,"提交重查战场条件，拒绝时不支付或改变状态")
 e.move_to(human,"grave")
 expect(e.cast_error(0,f.spell.uid).is_empty(),"己方人类离场后恢复使用")
 e.players[0].leader=e.make_card("70",0,"leader",true)
 expect(e.cast_error(0,f.spell.uid).contains("人类"),"自机区的人类自机阻止使用")
 e.move_to(e.players[0].leader,"exile")
 expect(e.cast_error(0,f.spell.uid).is_empty(),"人类自机在移除区时不算自机区人类")
 e.players[0].extra_leaders=[e.make_card("70",0,"leader",true)]
 expect(e.cast_error(0,f.spell.uid).contains("人类"),"额外自机区的人类同样阻止使用")
 e.players[0].extra_leaders=[]
 f=setup_autumn()
 e.players[0].leader=e.make_card("70",0,"leader",true)
 e.enter_field(e.players[0].leader,1)
 expect(e.cast_error(0,f.spell.uid).is_empty(),"我方原有人类自机被对方操控后不再阻止使用")
 e.cards["autumn-all-races"]=e.cards["9"].duplicate(true);e.cards["autumn-all-races"].race=["全部"]
 put("autumn-all-races")
 expect(e.cast_error(0,f.spell.uid).contains("人类"),"具全部种族的己方牌也属于人类")
 f=setup_autumn()
 for phase in ["prepare","end"]:
  e.phase=phase
  expect(e.cast_error(0,f.spell.uid).is_empty() and Hints.actionable(e,f.spell,0),"持有执行权时可在该阶段使用高速符卡："+phase)
 e.phase="main";e.active=1
 expect(e.cast_error(0,f.spell.uid).is_empty() and submit(f).is_empty(),"可在对手主要阶段持有执行权时实际使用高速符卡")
 one();expect(f.unit.zone=="hand" and f.spell.zone=="grave","对手回合使用后正常结算回手效果")
 f=setup_autumn();e.priority=1
 expect(not e.cast_error(0,f.spell.uid).is_empty(),"高速符卡仍须等待执行权")

func targets_and_payment():
 var f=setup_autumn();var small=put("53","field",1);var human=put("9","field",1)
 var expensive=put("52","field",1);var item=put("164","field",1)
 expect(e.targets_for(AUTUMN,0,f.spell.uid)==[e.ref_target(f.unit),e.ref_target(small),e.ref_target(human)],"四费边界和低费单位均可指定，目标不限制种族")
 var own=put("54","field",0)
 expect(e.ai_expanded_target(0,f.spell,e.targets_for(AUTUMN,0,f.spell.uid)).uid==f.unit.uid,"AI 优先把对方单位移回手牌")
 e.move_to(own,"hand")
 var before=public_state()
 for target in [{"player":1},e.ref_target(expensive),e.ref_target(item),e.ref_target(e.players[1].leader),{"none":true}]:
  expect(not e.commit_cast(0,f.spell.uid,target,e.payment(0,e.cast_cost(0,f.spell)).plan).is_empty() and public_state()==before,"非法目标不消耗费用或移动卡牌："+str(target))
 expect(not e.commit_cast(0,f.spell.uid,e.ref_target(f.unit),[]).is_empty() and public_state()==before,"无效付款方案不改变状态")
 for c in e.players[0].palette:c.tapped=true
 expect(e.cast_error(0,f.spell.uid).contains("费用") and not Hints.actionable(e,f.spell,0),"费用不足时不能使用")
 f=setup_autumn();e.move_to(f.unit,"grave")
 expect(e.targets_for(AUTUMN,0).is_empty() and e.cast_error(0,f.spell.uid).contains("目标"),"没有合规战场单位时不能无目标使用")
 expect(Hints.active(e,f.spell) and not Hints.actionable(e,f.spell,0),"条件满足但无目标时保留文字、不显示可用红框")
 var zero_cost=put("token-fdn-085","field",1)
 expect(e.Extra.cost_value(e,zero_cost)==0 and e.targets_for(AUTUMN,0)==[e.ref_target(zero_cost)],"零颜色值单位也可指定")
 e.move_to(zero_cost,"grave");put("52","field",1)
 expect(e.cast_error(0,f.spell.uid).contains("目标"),"仅有五费单位时仍然没有合法目标")

func resolution():
 var f=setup_autumn()
 expect(submit(f).is_empty() and f.spell.zone=="stack" and f.unit.zone=="field","支付后入堆叠，等待双方响应后回手")
 expect(e.players[0].palette.filter(func(c):return c.tapped).size()==2,"实际支付红、黄各一费")
 one()
 expect(f.unit.zone=="hand" and e.players[1].hand.has(f.unit) and f.spell.zone=="grave","颜色值为四的单位回拥有者手上，符卡进墓地")
 f=setup_autumn();f.unit=put("9","field",1)
 expect(submit(f).is_empty(),"人类单位也可成为回手目标")
 one();expect(f.unit.zone=="hand" and not e.players[1].grave.has(f.unit),"回手效果不消灭人类单位")
 f=setup_autumn();f.unit=put("53","field",0)
 expect(submit(f).is_empty(),"可指定己方非人类单位")
 one();expect(f.unit.zone=="hand" and e.players[0].hand.has(f.unit),"己方单位回己方手牌")
 f=setup_autumn();f.unit=put("53","field",0);f.unit.original_owner=1
 expect(submit(f).is_empty(),"可指定己方操控但对方拥有的非人类单位")
 one();expect(f.unit.owner==1 and e.players[1].hand.has(f.unit) and not e.players[0].hand.has(f.unit),"改变操控权的单位回实际拥有者手牌")
 f=setup_autumn();submit(f)
 var target=e.ref_target(f.unit);e.move_to(f.unit,"grave");e.enter_field(f.unit,1)
 expect(not e.spell_target_valid(AUTUMN,target),"目标离场再进场后旧区域引用失效")
 one();expect(f.unit.zone=="field" and f.spell.zone=="grave","离场再回场的单位不会被旧目标移回手牌")
 f=setup_autumn();submit(f)
 f.unit.card_id="52"
 expect(not e.spell_target_valid(AUTUMN,e.ref_target(f.unit)),"结算前目标颜色值变为五时失效")
 one();expect(f.unit.zone=="field" and f.spell.zone=="grave","结算时超过四色的单位不被移回手牌")
 f=setup_autumn();submit(f);f.unit.card_id="9"
 one();expect(f.unit.zone=="hand","结算前种族变成人类仍可回手")
 f=setup_autumn();submit(f);put("9")
 one();expect(f.unit.zone=="hand","声明后己方人类进场不会追溯取消已合法使用的符卡")
 f=setup_autumn();submit(f);e.counter_entry(e.stack.back().id)
 expect(f.unit.zone=="field" and f.spell.zone=="grave" and e.stack.is_empty(),"秋司可被反制，反制后目标留在战场")
 for home in [false,true]:
  f=setup_autumn();f.unit=e.players[1].leader;e.enter_field(f.unit,1)
  expect(submit(f).is_empty(),"颜色值合规的战场自机也可指定")
  one();expect(e.pending.get("kind","")=="leader_return","自机回手时保留返回自机区的规则选择")
  e.choose_return(home)
  expect(f.unit.zone==("leader" if home else "hand"),"自机可选择返回自机区或进入拥有者手牌："+str(home))

func network_and_restore():
 var f=setup_autumn();var uid=f.spell.uid;var victim=f.unit.uid
 var remote=Remote.new();remote.seat=0;remote.apply_snapshot(Seat.build(e,0))
 expect(remote.cast_error(0,uid).is_empty() and remote.targets_for(AUTUMN,0,uid)==e.targets_for(AUTUMN,0,uid),"联网玩家快照收到相同使用资格与四色内单位目标")
 put("9");remote.apply_snapshot(Seat.build(e,0))
 expect(remote.cast_error(0,uid).contains("人类"),"联网查询同步己方人类的使用禁止")
 f=setup_autumn();uid=f.spell.uid;victim=f.unit.uid
 submit(f)
 var saved=Codec.capture(e);e=Duel.new();Codec.restore(e,saved)
 one()
 expect(e.find_card(uid).zone=="grave" and e.find_card(victim).zone=="hand" and e.players[1].hand.has(e.find_card(victim)),"存档恢复后保留堆叠来源、目标与回拥有者手牌效果")
