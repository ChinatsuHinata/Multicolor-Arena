extends "res://tests/support/rules_base.gd"

const Gateway=preload("res://net/command_gateway.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const Draft=preload("res://scripts/payment_draft.gd")

func train_fixture(who: int=0):
 fresh();e.active=who;e.priority=who
 e.players[who].leader=e.make_card("character-fdf-ex02",who,"leader")
 var spell=put("new-spx-006","hand",who)
 var curse=put("spell-fdf-014","palette",who)
 var dual=put("114","palette",who)
 var blue=put("167","palette",who)
 var yellow=put("164","palette",who)
 return {"spell":spell,"curse":curse,"dual":dual,"blue":blue,"yellow":yellow}

func run():
 for colors in [["蓝","蓝"],["蓝","黄"],["黄","黄"]]:
  var f=train_fixture()
  var plan=[{"uid":f.curse.uid,"color":colors[0]},{"uid":f.yellow.uid if colors[1]=="黄" else f.dual.uid,"color":colors[1]}]
  expect(e.cast_error(0,f.spell.uid).is_empty(),"废线满足使用条件")
  var error=e.commit_cast(0,f.spell.uid,{"none":true},plan)
  expect(error.is_empty(),"单诅咒允许减费后支付 "+str(colors)+"："+error)
  expect(e.stack.any(func(s):return s.get("card",{}).get("uid",0)==f.spell.uid),"合法方案实际将废线放上堆叠")
 var f=train_fixture()
 f.curse.tapped=true
 var plan=[{"uid":f.dual.uid,"color":"蓝"},{"uid":f.blue.uid,"color":"蓝"}]
 expect(e.commit_cast(0,f.spell.uid,{"none":true},plan).is_empty(),"横置的诅咒仍允许用蓝黑牌和单蓝牌各产一蓝支付")
 expect(f.dual.tapped and f.blue.tapped and not f.yellow.tapped,"只横置玩家选择的蓝色资源")
 f=train_fixture();put("24")
 expect(e.commit_cast(0,f.spell.uid,{"none":true},[{"uid":f.blue.uid,"color":"蓝"}]).is_empty(),"诅咒与八云蓝叠加后允许支付单蓝")
 f=train_fixture();put("spell-fdf-014","palette")
 expect(e.commit_cast(0,f.spell.uid,{"none":true},[]).is_empty(),"两张诅咒将废线减至零费")
 for invalid in ["black","short","duplicate","tapped","removed"]:
  f=train_fixture()
  plan=[{"uid":f.dual.uid,"color":"蓝"},{"uid":f.blue.uid,"color":"蓝"}]
  match invalid:
   "black":plan[0].color="黑"
   "short":plan.pop_back()
   "duplicate":plan[1].uid=f.dual.uid
   "tapped":f.dual.tapped=true
   "removed":e.move_to(f.curse,"grave")
  var before=JSON.stringify([e.players,e.stack])
  expect(not e.commit_cast(0,f.spell.uid,{"none":true},plan).is_empty(),"拒绝不合法方案："+invalid)
  expect(before==JSON.stringify([e.players,e.stack]),"失败支付不改变公开状态："+invalid)
 f=train_fixture();e.move_to(f.curse,"grave");put("spell-fdf-014","palette",1)
 expect(not e.commit_cast(0,f.spell.uid,{"none":true},[{"uid":f.dual.uid,"color":"蓝"},{"uid":f.blue.uid,"color":"蓝"}]).is_empty(),"对手颜色盘的诅咒不提供减费")
 f=train_fixture();var item=put("167","hand")
 expect(not e.commit_cast(0,item.uid,{},[]).is_empty(),"诅咒不会给非八云紫角色符卡减费")
 f=train_fixture();put("spell-ucs-031","field",1)
 plan=[{"uid":f.dual.uid,"color":"蓝"},{"uid":f.blue.uid,"color":"蓝"}]
 expect(not e.commit_cast(0,f.spell.uid,{"none":true},plan).is_empty(),"诅咒不能抵消额外加费")
 plan.append({"uid":f.yellow.uid,"color":"黄"})
 expect(e.commit_cast(0,f.spell.uid,{"none":true},plan).is_empty(),"减去两黄并支付额外加费的方案合法")
 for who in [0,1]:
  f=train_fixture(who)
  var remote=Remote.new();remote.seat=who;remote.apply_snapshot(SeatView.build(e,who))
  var remote_spell=remote.find_card(f.spell.uid)
  var costs=remote.cast_cost_options(who,remote_spell)
  var fixed=[{"uid":f.dual.uid,"color":"蓝"}]
  var sources=Draft.options_for_costs(remote,who,costs,fixed)
  expect(sources.any(func(s):return s.uid==f.blue.uid and s.get("reservation",{}).get("color","")=="蓝"),"联机座位 %d 可在已选蓝黑牌后继续选单蓝牌" % who)
  plan=fixed+[{"uid":f.blue.uid,"color":"蓝"}]
  expect(remote.cast_payment_valid(who,remote_spell,{"none":true},plan),"联机座位 %d 的本地费用校验接受两蓝" % who)
  expect(e.payment_valid(who,e.cast_cost(who,f.spell),e.payment(who,e.cast_cost(who,f.spell)).plan),"自动支付方案仍然合法")
  var error=Gateway.apply(e,who,{"name":"commit_cast","args":[f.spell.uid,{"none":true},plan]})
  expect(error.is_empty() and f.dual.tapped and f.blue.tapped and not f.curse.tapped and not f.yellow.tapped,"联机座位 %d 的主机按玩家两蓝方案扣费：%s" % [who,error])
 print("CURSE_DISCOUNT: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
