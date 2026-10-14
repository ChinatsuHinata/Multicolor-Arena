extends "res://tests/support/rules_base.gd"

const SKYFIRE="character-fdf-065"

func skyfire(event: String,who: int,target: Dictionary) -> Dictionary:
 var source
 if event=="enter":source=enter(SKYFIRE,who)
 else:
  source=put(SKYFIRE,"field",who)
  if event=="death":e.destroy(source);e.pump_choices()
  elif event=="attack":e.active=who;e.priority=who;e.attack(who,source.uid)
  else:
   var attacker=put("53","field",1-who)
   e.active=1-who;e.priority=1-who;e.attack(1-who,attacker.uid);one()
   expect(e.pending.get("kind","")=="block","天火人阻挡前进入真实阻挡窗口")
   e.block([source.uid])
 expect(e.pending.get("trigger",{}).get("effect","")==SKYFIRE and e.pending.owner==who,"天火人%s由实际事件触发并选择目标" % event)
 e.choose_effect(target)
 expect(e.pending.is_empty() and e.stack.size()==1 and e.stack.back().target==target,"天火人%s声明目标后允许响应" % event)
 return source

func skyfire_unit_targets():
 for who in [0,1]:
  for event in ["enter","death","attack","block"]:
   for response in ["none","grave","hand","exile","palette","blink","shroud","source_leave","prevent","ward","control"]:
    fresh()
    var victim=put("53","field",1-who);victim.plus_counters=20
    var source=skyfire(event,who,e.ref_target(victim))
    var lost=response in ["grave","hand","exile","palette","blink","shroud"]
    if response in ["grave","hand","exile","palette"]:e.move_to(victim,response)
    elif response=="blink":e.move_to(victim,"exile");e.detach(victim);e.enter_field(victim,1-who)
    elif response=="shroud":e.players[1-who].shroud_turn=e.turn
    elif response=="source_leave" and source.zone=="field":e.move_to(source,"exile")
    elif response=="prevent":victim.modifiers=[{"防止伤害":true}]
    elif response=="ward":e.Pack.shield(e,e.ref_target(victim),[2])
    elif response=="control":e.players[1-who].field.erase(victim);victim.owner=who;e.players[who].field.append(victim)
    one()
    var label="席位%d / %s / %s" % [who,event,response]
    expect(e.players[who].life==(20 if lost else 22),label+"：仅目标失效取消整项能力，防伤与来源离场仍回血")
    expect(victim.damage==(2 if response in ["none","source_leave","control"] else 0),label+"：只伤害结算时仍合法的目标")
    expect(e.players[who].get("life_gained",{}).get(str(e.turn),0)==(0 if lost else 2),label+"：回血统计不记录失效能力")
    expect(e.stack.is_empty() and e.pending.is_empty(),label+"：结算正常结束")
    if lost:expect(e.log.any(func(line):return line.contains("目标失效") and line.contains("不结算")),label+"：日志解释能力未结算")

func skyfire_player_targets():
 for who in [0,1]:
  for target_who in [0,1]:
   for protected_target in [false,true]:
    fresh();skyfire("enter",who,{"player":target_who})
    if protected_target:put("character-ucs-046","field",1-who)
    one()
    for player in [0,1]:
     var expected=20 if protected_target else 20+2*int(player==who)-2*int(player==target_who)
     expect(e.players[player].life==expected,"天火人玩家目标（来源%d，目标%d，保护%s）：伤害与回血一起重新检查目标" % [who,target_who,str(protected_target)])
 fresh()
 var victim=put("53","field",1);victim.plus_counters=20
 skyfire("enter",0,e.ref_target(victim));put("spell-fdn-002");one()
 expect(victim.damage==2 and e.players[0].life==20,"禁止获得生命时仍造成伤害，但不回血")
 fresh();put("character-ucs-046");e.players[0].shroud_turn=e.turn;e.players[1].shroud_turn=e.turn
 enter(SKYFIRE)
 expect(e.pending.is_empty() and e.stack.back().get("no_legal_targets",false),"没有合法目标的天火人触发不会要求无效选择")
 one();expect(e.players[0].life==20 and e.stack.is_empty(),"没有合法目标时天火人不回血")
 fresh();victim=put("53","field",1);victim.plus_counters=20
 skyfire("enter",0,e.ref_target(victim));e.Pack.shield(e,e.ref_target(victim),[1,2]);one()
 expect(e.pending.get("kind","")=="ward_order" and e.players[0].life==22,"防避排序推迟伤害时，合法能力仍获得固定2点生命")
 if e.pending.get("kind","")=="ward_order":e.choose_ward(0)
 expect(victim.damage==0 and e.pending.is_empty() and e.players[0].life==22,"防避排序结束后不重复回血")

func related_life_abilities():
 for removed in [0,1,2,3]:
  fresh()
  var graves=[put("164","grave"),put("165","grave"),put("166","grave")]
  enter("66")
  var choice=e.pending.options[0].duplicate(true);choice.erase("selection");choice.picks=[e.Pack.refs(e,graves)]
  e.choose_effect(choice)
  for i in range(removed):e.move_to(graves[i],"exile")
  one()
  expect(e.players[0].life==(20 if removed==3 else 21),"响子：%d个墓地目标失效时，只在仍有合法目标时回血" % removed)
  for i in range(graves.size()):expect(graves[i].zone==("exile" if i<removed else "deck"),"响子只洗回仍合法的墓地目标")
 for mode in ["none","valid","lost"]:
  fresh();e.debug_enabled=true;e.debug_free_payment=true
  var carrot=put("item-fdn-044");var grave=put("164","grave")
  var choice=e.activation_options(carrot,"item-fdn-044")[0].duplicate(true);choice.erase("selection")
  choice.picks=[[] if mode=="none" else [e.Pack.ref(e,grave)]]
  expect(e.commit_extension(0,carrot.uid,choice,[],"item-fdn-044").is_empty(),"幸运萝卜声明可选目标："+mode)
  if mode=="lost":e.move_to(grave,"exile")
  one()
  expect(e.players[0].life==21,"幸运萝卜：至多一个目标丢失不影响回血："+mode)
  expect(not e.log.any(func(line):return line.contains("目标失效")),"幸运萝卜的可选目标丢失不取消结算："+mode)

func optional_triggers():
 for family in ["roster","precon"]:
  for response in ["leave","shroud"]:
   fresh()
   var source=put("field-rei-013" if family=="roster" else "field-smm-004")
   var victim=put("53","field",1)
   var effect="field-rei-013" if family=="roster" else "castle_exile"
   var trigger={"owner":0,"source":source.duplicate(true),"effect":effect,"extended":true,"optional":true,"name":e.cards[source.card_id].name}
   trigger[family]=true;e.begin_trigger(trigger)
   var choice=e.pending.options[0].duplicate(true);choice.erase("selection");choice.picks=[[e.ref_target(victim)]]
   e.choose_effect(choice)
   expect(e.stack.back().get("optional_single_target",false),family+"触发记录至多一个目标规则")
   if response=="leave":e.move_to(victim,"hand")
   else:e.players[1].shroud_turn=e.turn
   one()
   expect(victim.zone==("hand" if response=="leave" else "field"),family+"可选目标失效时不作用于失效对象")
   expect(e.stack.is_empty() and e.pending.is_empty() and not e.log.any(func(line):return line.contains("目标失效")),family+"至多一个目标失效仍完成结算")

func costs_are_not_targets():
 fresh();e.debug_enabled=true;e.debug_free_payment=true
 var source=put("item-ucs-017");var victim=put("53")
 var choice=e.activation_options(source,"item-ucs-017")[0].duplicate(true);choice.erase("selection");choice.picks=[[e.ref_target(victim)]]
 expect(e.commit_extension(0,source.uid,choice,[],"item-ucs-017").is_empty() and victim.zone=="grave","牺牲费用先支付")
 one();expect(e.players[0].hand.size()==1,"费用中的单位离场不取消无目标抓牌能力")
 fresh();e.debug_enabled=true;e.debug_free_payment=true
 source=put("61","grave");var discard=put("164","hand")
 expect(e.commit_extension(0,source.uid,e.Pack.ref(e,discard),[],"grave_reanimate").is_empty() and discard.zone=="grave","芳香支付弃牌费用")
 e.move_to(discard,"exile");one()
 expect(source.zone=="field" and source.tapped,"芳香的弃牌费用不是目标，弃牌再换区不阻止复活")
 fresh();e.debug_enabled=true;e.debug_free_payment=true
 source=put("71");victim=put("53");var power=e.stat(source,"power")
 expect(e.commit_extension(0,source.uid,e.ref_target(victim),[],"sacrifice_buff").is_empty() and victim.zone=="grave","幽幽子支付牺牲费用")
 one();expect(e.stat(source,"power")==power+1,"幽幽子的牺牲费用不是目标，单位离场不取消强化")

func run():
 skyfire_unit_targets();skyfire_player_targets();related_life_abilities();optional_triggers();costs_are_not_targets()
 print("ABILITY_TARGET_VALIDITY: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
