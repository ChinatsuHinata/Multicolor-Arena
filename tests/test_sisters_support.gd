extends "res://tests/support/rules_base.gd"

const Codec=preload("res://net/state_codec.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")

func reserve(id: String) -> Dictionary:
 fresh();mana()
 var sisters=e.make_card("character-fdn-025",0,"leader",true)
 e.players[0].leader=sisters;e.enter_field(sisters,0)
 var spell=put(id,"hand")
 put("53","field",1)
 e.advance_phase()
 expect(e.pending.get("trigger",{}).get("effect","")=="character-fdn-025:self",id+"：结束阶段触发姐妹自机能力")
 if e.pending.get("kind","")!="effect_choice":return {}
 e.choose_effect(e.pending.options[0]);one()
 expect(e.pending.get("trigger",{}).get("effect","")=="cat:sisters_exile",id+"：结算时选择移除手牌")
 if e.pending.get("trigger",{}).get("effect","")!="cat:sisters_exile":return {}
 var choice=e.pending.options[0].duplicate(true);choice.erase("selection");choice.picks=[[e.Pack.ref(e,spell)]]
 e.choose_effect(choice)
 expect(spell.zone=="exile" and spell.get("catalogue_access",{}).get("support",false),id+"：真实效果移除符卡并授予支援")
 e.move_to(sisters,"grave");e.pump_choices();e.choose_return(true)
 expect(sisters.zone=="leader" and e.units(0).is_empty(),id+"：姐妹返回自机区，战场没有对应角色")
 e.phase="main";e.priority=0;e.turn+=2
 return spell

func cost_total(cost: Dictionary) -> int:
 var total=0
 for amount in cost.values():total+=int(amount)
 return total

func run():
 for id in ["spell-fdf-035","104"]:
  var spell=reserve(id)
  if spell.is_empty():continue
  expect("支援" not in e.cards[id].keywords,id+"：测试符卡原本没有支援")
  expect(e.cast_error(0,spell.uid).is_empty(),id+"：姐妹在自机区时可支援使用移除牌")
  expect(e.legal_casts(0).any(func(c):return c.uid==spell.uid),id+"：移除牌进入可用列表")
  expect(cost_total(e.cast_cost(0,spell))==maxi(0,cost_total(e.cards[id].cost)-2),id+"：移除牌仍减少任意两点颜色值")
  var remote=Remote.new();remote.apply_snapshot(SeatView.build(e,0))
  expect(remote.cast_error(0,spell.uid).is_empty() and remote.legal_casts(0).any(func(c):return c.uid==spell.uid),id+"：联网快照允许同样的支援使用")
  expect(cost_total(remote.cast_cost(0,remote.find_card(spell.uid)))==cost_total(e.cast_cost(0,spell)),id+"：联网减费与本地一致")
  var uid=spell.uid;var saved=Codec.capture(e);e=Duel.new();Codec.restore(e,saved);spell=e.find_card(uid)
  expect(e.cast_error(0,uid).is_empty(),id+"：恢复对局后保留移除牌的支援资格")
  var options=e.targets_for(id,0,uid)
  if options.is_empty():expect(false,id+"：存在合法使用目标");continue
  var target={"player":1} if id=="spell-fdf-035" else options[0]
  var error=e.commit_cast(0,uid,target,e.payment(0,e.cast_cost(0,spell,target)).plan)
  expect(error.is_empty() and spell.zone=="stack",id+"：按实际减费支付并从移除区使用："+error)
  if not error.is_empty():continue
  one()
  expect(spell.zone=="grave" and not spell.has("catalogue_access"),id+"：符卡结算后失去移除期间的许可")
  expect(e.players[0].life==23 if id=="spell-fdf-035" else e.players[1].grave.any(func(c):return c.card_id=="53"),id+"：符卡真实效果成功结算")

 var spell=reserve("spell-fdf-035")
 if not spell.is_empty():
  expect(e.cast_cost_options(0,spell).any(func(cost):return cost.get("红",0)==1 and cost.get("黑",0)==0) and e.cast_cost_options(0,spell).any(func(cost):return cost.get("红",0)==0 and cost.get("黑",0)==1),"姐妹减费保留不同颜色分配")
  var sisters=e.players[0].leader
  e.players[0].leader=e.make_card("70",0,"leader",true)
  expect(not e.character_constraint_error(spell,0).is_empty(),"无对应角色的自机不能满足授予的支援")
  e.players[0].extra_leaders=[sisters]
  expect(e.cast_error(0,spell.uid).is_empty(),"额外自机区中的姐妹也满足授予的支援")
  expect(not e.cast_error(1,spell.uid).is_empty(),"对手不能使用姐妹移除的牌")
  var unreserved=put("spell-fdf-035","hand")
  expect(not e.character_constraint_error(unreserved,0).is_empty(),"未被姐妹移除的符卡不获得支援")
  var ordinary_exile=put("spell-fdf-035","exile")
  expect(not e.cast_error(0,ordinary_exile.uid).is_empty(),"普通移除牌不获得使用许可")
  var printed_support=put("spell-fdf-037","hand")
  expect(e.cast_error(0,printed_support.uid).is_empty(),"原生支援仍可由额外自机区中的姐妹满足")
  e.move_to(spell,"hand")
  expect(not spell.has("catalogue_access") and not e.character_constraint_error(spell,0).is_empty(),"移除牌回到手牌后不再具有授予的支援")
  expect(cost_total(e.cast_cost(0,spell))==cost_total(e.cards[spell.card_id].cost),"移除牌回到手牌后恢复原费用")
  e.move_to(spell,"exile")
  expect(not e.cast_error(0,spell.uid).is_empty(),"再次进入移除区不会恢复先前的支援许可")
 print("SISTERS_SUPPORT: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
