extends "res://tests/support/rules_base.gd"
const SeatView=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")

func allocation(options: Array,recipients: Array) -> Dictionary:
 for spec in options:
  if spec.get("selection_id","")=="spell-fdn-003":
   var target=spec.duplicate(true);target.erase("selection");target.picks=[]
   for c in recipients:target.picks.append([e.ref_target(c)])
   return target
 return {}

func commit(who: int,c: Dictionary,target: Dictionary):
 var error=e.commit_cast(who,c.uid,target,e.payment(who,e.cast_cost(who,c,target)).plan)
 expect(error.is_empty(),"使用 "+c.card_id+"："+error)

func phoenix_response():
 fresh();mana();put("21","field",1);put("165","palette",1);put("164","palette",1)
 var melody=put("spell-fdn-032")
 var a=put("53");var b=put("50","field",1);var c=put("74","field",1)
 for unit in [a,b,c]:unit.plus_counters=20
 var spell=put("spell-fdn-003","hand",1)
 var options=e.targets_for(spell.card_id,1,spell.uid)
 var original=allocation(options,[a,a,a,a,a])
 expect(e.Pack.choice_valid(e,options,original),"凤翼天翔在使用时接受完整的5点伤害分配")
 expect(not e.Pack.choice_valid(e,options,allocation(options,[a,a,a,a])),"凤翼天翔拒绝未分配满5点的使用目标")
 var player_target=original.duplicate(true);player_target.picks[0]=[{"player":0}]
 expect(not e.Pack.choice_valid(e,options,player_target),"凤翼天翔只能以单位为伤害目标")
 e.active=1;e.priority=1;commit(1,spell,original)
 expect(e.pending.is_empty() and e.stack.size()==1 and e.stack[0].target==original,"响应前，凤翼天翔已记录目标及伤害分配")
 expect(e.Pack.single_damage_target(e.stack[0]),"五点伤害分配给同一单位时，仍视为单个伤害目标")
 var hypnosis=put("spell-fdf-052","hand")
 var response={"stack_id":e.stack[0].id}
 expect(e.cast_error(0,hypnosis.uid).is_empty() and response in e.targets_for(hypnosis.card_id,0),"铃仙乐章允许赤眼催眠响应凤翼天翔")
 var remote=Remote.new();remote.apply_snapshot(SeatView.build(e,0))
 expect(remote.cast_error(0,hypnosis.uid).is_empty() and response in remote.targets_for(hypnosis.card_id,0,hypnosis.uid),"联机客户端也能响应凤翼天翔")
 commit(0,hypnosis,response);one()
 expect(e.pending.get("trigger",{}).get("effect","")=="cat:retarget","赤眼催眠结算后等待重新选择目标")
 if e.pending.is_empty():return
 var changed=allocation(e.pending.options,[b,b,c,c,c])
 expect(e.Pack.choice_valid(e,e.pending.options,changed),"赤眼催眠可以把一个目标重新选为两个目标并分配伤害")
 e.choose_effect(changed)
 expect(e.stack.size()==1 and e.stack[0].target.picks==changed.picks,"重新选择后，原符卡保存新的目标")
 expect(not e.Pack.single_damage_target(e.stack[0]),"伤害分配给两个单位时，视为多个伤害目标")
 one()
 expect(a.damage==0 and b.damage==2 and c.damage==3,"凤翼天翔按重新选择的目标造成总共5点伤害")
 expect(e.players[1].life==10 and e.pending.is_empty() and spell.zone=="grave","结算直接设置使用者生命为10，不再次选择目标")
 expect(melody.zone=="field","响应没有影响铃仙乐章")

func phoenix_target_lifecycle():
 fresh();mana();put("21")
 var a=put("53","field",1);var b=put("50","field",1)
 a.plus_counters=20;b.plus_counters=20
 var spell=put("spell-fdn-003","hand")
 commit(0,spell,allocation(e.targets_for(spell.card_id,0),[a,a,b,b,b]))
 e.move_to(a,"grave");one()
 expect(b.damage==3 and e.players[0].life==10 and e.pending.is_empty(),"部分目标离场时，只对其余目标造成已分配的伤害")
 fresh();mana();put("21")
 spell=put("spell-fdn-003","hand")
 var none=e.targets_for(spell.card_id,0)[0].duplicate(true);none.erase("selection");none.picks=[[]]
 commit(0,spell,none);one()
 expect(e.players[0].life==10 and e.pending.is_empty(),"凤翼天翔可以选择零个目标并设置生命")

func arbitrary_target_count():
 for count in [0,2,3]:
  fresh();mana();put("33")
  var units=[put("53"),put("50"),put("74")]
  var source=put("character-rec-096")
  var entry={"id":91,"kind":"ability","extended":true,"precon":true,"owner":0,"source":source.duplicate(true),"effect":"tewi_counters","name":"帝的指示物","target":{"selection_id":"tewi_counters","picks":[[e.ref_target(units[0])]]}}
  e.stack=[entry]
  var hypnosis=put("spell-fdf-052","hand")
  commit(0,hypnosis,{"stack_id":entry.id});one()
  expect(not e.pending.is_empty(),"赤眼催眠可响应有目标的能力")
  if e.pending.is_empty():continue
  var target=e.pending.options[0].duplicate(true);target.erase("selection");target.picks=[[]]
  for i in range(count):target.picks[0].append(e.ref_target(units[i]))
  expect(e.Pack.choice_valid(e,e.pending.options,target),"能力可重新选择 %d 个合法目标" % count)
  e.choose_effect(target);one()
  expect(units.filter(func(u):return u.get("plus_counters",0)==1).size()==count,"能力按重新选择的目标数量结算：%d" % count)

func illusions():
 for printed in [true,false]:
  fresh()
  var melody=put("spell-fdn-032")
  var illusion=put("token-fdn-085") if printed else e.Cat.token(e,0,"幻象",3,3,2,["红","黑"],["先制"])
  if not printed:illusion.reisen_illusion=true
  var original_id=illusion.card_id
  e.judge()
  expect(illusion.zone=="field","铃仙乐章让幻象自身具备铃仙名称并存活："+str(printed))
  expect(illusion.card_id==original_id and e.Cat.additional_unit_names(e,illusion)==["铃仙·优昙华院·因幡"],"乐章增加视同名称，保留原卡牌："+str(printed))
  var remote=Remote.new();remote.apply_snapshot(SeatView.build(e,0))
  expect(remote.Cat.additional_unit_names(remote,remote.find_card(illusion.uid))==["铃仙·优昙华院·因幡"],"联机投影保留单位的铃仙视同名称")
  e.move_to(melody,"grave");e.judge()
  expect(illusion.zone in ["exile","void"],"失去乐章且没有铃仙时，幻象离场："+str(printed))
 fresh();put("spell-fdn-032","field",1)
 var illusion=put("token-fdn-085");e.judge()
 expect(illusion.zone in ["exile","void"],"对手的铃仙乐章不能保留自己的幻象")
 fresh();var reisen=put("33");illusion=put("token-fdn-085");e.judge()
 expect(illusion.zone=="field","卡名含铃仙的真实单位仍让幻象存活")
 e.move_to(reisen,"grave");e.judge()
 expect(illusion.zone in ["exile","void"],"真实铃仙离场且没有乐章时，幻象离场")

func make_illusion(printed: bool):
 var illusion=put("token-fdn-085") if printed else e.Cat.token(e,0,"幻象",3,3,2,["红","黑"],["先制"])
 if not printed:illusion.reisen_illusion=true
 return illusion

func boundary_illusions():
 for printed in [true,false]:
  for support in ["none","own_reisen","own_melody","opponent_reisen","both_reisen"]:
   fresh();mana()
   var reisen=put("character-fdf-090")
   var selected=[reisen]
   if support in ["own_reisen","both_reisen"]:
    var other=put("33")
    if support=="both_reisen":selected.append(other)
   elif support=="own_melody":put("spell-fdn-032")
   elif support=="opponent_reisen":put("33","field",1)
   var tokens=[make_illusion(printed),make_illusion(printed)]
   e.judge()
   expect(tokens.all(func(u):return u.zone=="field"),"境界使用前幻象在场："+support+" / "+str(printed))
   var spell=put("114","hand")
   var refs=selected.map(func(u):return e.ref_target(u))
   commit(0,spell,{"selection_id":"blink_two","picks":[refs]});one()
   var retained=support in ["own_reisen","own_melody"]
   expect(tokens.all(func(u):return u.zone==("field" if retained else "void")),"境界短暂除外时按己方剩余铃仙名称清理所有幻象："+support+" / "+str(printed))
   expect(selected.all(func(u):return u.zone=="field"),"境界仍让所选铃仙返回战场："+support)
   expect(e.players[0].grave==[spell] and e.players[0].exile.is_empty(),"消失的幻象不残留墓地或除外区："+support)

  for include_reisen in [true,false]:
   fresh();mana()
   var reisen=put("character-fdf-090")
   var tokens=[make_illusion(printed),make_illusion(printed)]
   var selected=[tokens[0]]
   if include_reisen:selected.append(reisen)
   var spell=put("114","hand")
   commit(0,spell,{"selection_id":"blink_two","picks":[selected.map(func(u):return e.ref_target(u))]});one()
   expect(tokens[0].zone=="void" and tokens[1].zone==("void" if include_reisen else "field"),"境界不能移回衍生物，剩余幻象按铃仙是否离场决定存续："+str(include_reisen)+" / "+str(printed))
   expect(reisen.zone=="field" and e.players[0].grave==[spell] and e.players[0].exile.is_empty(),"境界以幻象为目标时不会留下其他区域残留")

 for return_home in [true,false]:
  fresh();mana()
  var reisen=put("character-fdf-090");reisen.leader=true;e.players[0].leader=reisen
  var tokens=[make_illusion(true),make_illusion(false)]
  var spell=put("114","hand")
  commit(0,spell,{"selection_id":"blink_two","picks":[[e.ref_target(reisen)]]});one()
  expect(e.pending.get("kind","")=="leader_return" and tokens.all(func(u):return u.zone=="void"),"铃仙等待自机返回选择时，幻象已经消失")
  e.choose_return(return_home)
  expect(reisen.zone==("leader" if return_home else "field") and tokens.all(func(u):return u.zone=="void"),"自机返回选择不会恢复已经消失的幻象："+str(return_home))

func illusion_capacity():
 for setup in ["full","last_slot","slot_free","larger_field"]:
  fresh()
  var reisen=put("character-fdf-090");reisen.leader_counters=1
  if setup=="slot_free":put("character-fdf-104")
  elif setup=="larger_field":put("character-ucs-053")
  var limit=e.Cat.field_limit(e,0)
  while e.field_slots(0)<limit-(1 if setup in ["last_slot","larger_field"] else 0):put("53")
  var before=e.field_slots(0)
  e.Cat.Units.on_blocked(e,reisen)
  expect(e.triggers.size()==1 and e.triggers[0].effect=="character-fdf-090:self","被阻挡事件触发铃仙制造幻象能力："+setup)
  settle()
  var made=e.units(0).filter(func(u):return u.get("reisen_illusion",false))
  expect(made.size()==(0 if setup=="full" else 1),"满员无法制造幻象，其余场格规则正常："+setup)
  expect(e.players[0].grave.is_empty() and e.players[0].exile.is_empty(),"制造幻象失败不会产生墓地或除外区残留："+setup)
  expect(e.field_slots(0)==before+(1 if setup in ["last_slot","larger_field"] else 0),"幻象制造遵守战场格数量及豁免："+setup)
  if not made.is_empty():
   var illusion=made[0]
   expect(e.stat(illusion,"power")==3 and e.stat(illusion,"health")==3 and e.stat(illusion,"spirit")==2 and e.Extra.keyword(e,illusion,"先制"),"成功制造的幻象保留3/3/2、先制与存续能力")
   e.move_to(reisen,"exile");e.judge()
   expect(illusion.zone=="void","新制造的幻象在铃仙离场后正常消失："+setup)

func run():
 phoenix_response();phoenix_target_lifecycle();arbitrary_target_count();illusions();boundary_illusions();illusion_capacity()
 print("REISEN: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
