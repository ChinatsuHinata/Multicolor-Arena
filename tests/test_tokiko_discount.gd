extends "res://tests/support/rules_base.gd"

const Gateway=preload("res://net/command_gateway.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const Draft=preload("res://scripts/payment_draft.gd")

func fixture(who: int=0):
 fresh();e.active=who;e.priority=who
 var tokiko=put("character-htk-002","field",who);tokiko.leader=true
 var orb=put("new-eto-s001","hand",who)
 var blue=put("167","field",who)
 var yellow=put("164","palette",who)
 var black=put("168","palette",who)
 return {"tokiko":tokiko,"orb":orb,"blue":blue,"yellow":yellow,"black":black}

func run():
 var f=fixture()
 expect(e.cast_cost_options(0,f.orb).size()==3,"朱鹭子保留灵异珠减费后的一蓝、一黄、一黑")
 expect(e.cast_cost(0,f.orb).get("蓝",0)==1,"推荐优先使用蓝色道具")
 for who in [0,1]:
  for color in ["蓝","黄","黑"]:
   f=fixture(who)
   var source=f.blue if color=="蓝" else f.yellow if color=="黄" else f.black
   var plan=[{"uid":source.uid,"color":color}]
   var remote=Remote.new();remote.seat=who;remote.apply_snapshot(SeatView.build(e,who))
   var remote_orb=remote.find_card(f.orb.uid)
   expect(remote.cast_payment_valid(who,remote_orb,{},plan),"联机座位 %d 可改付一%s" % [who,color])
   expect(Draft.options_for_costs(remote,who,remote.cast_cost_options(who,remote_orb),[]).any(func(s):return s.uid==source.uid),"草案可选择一%s" % color)
   var error=Gateway.apply(e,who,{"name":"commit_cast","args":[f.orb.uid,{},plan]})
   expect(error.is_empty() and f.orb.zone=="stack" and source.tapped,"实际以一%s使用灵异珠：%s" % [color,error])
   expect([f.blue,f.yellow,f.black].filter(func(c):return c.tapped).size()==1,"仅扣除选择的一个资源")
   expect(e.players[who].get("item_cast_turn",-1)==e.turn,"首张道具成功使用后记录本回合次数")
 for state in ["used","inactive","opponent_turn","removed","opponent"]:
  f=fixture()
  match state:
   "used":e.players[0].item_cast_turn=e.turn
   "inactive":f.tokiko.leader=false
   "opponent_turn":e.active=1
   "removed":e.move_to(f.tokiko,"hand")
   "opponent":e.move_to(f.tokiko,"hand");put("character-htk-002","field",1).leader=true
  expect(not e.cast_payment_valid(0,f.orb,{},[{"uid":f.yellow.uid,"color":"黄"}]),"朱鹭子减费条件仍生效："+state)
 f=fixture();var ordinary=put("new-eto-008","hand")
 expect(e.cast_cost(0,ordinary).get("黄",0)==3 and e.cast_cost(0,ordinary).get("蓝",0)==2,"首张道具减费不影响符卡")
 f=fixture();put("24")
 expect(e.cast_payment_valid(0,f.orb,{},[]),"朱鹭子与八云蓝减费叠加至零费")
 f=fixture();put("new-eto-003").leader=true
 expect(e.cast_payment_valid(0,f.orb,{},[]),"朱鹭子与梦违减费共同生效")
 f=fixture();put("character-htk-002").leader=true
 expect(e.cast_payment_valid(0,f.orb,{},[]),"多张生效的朱鹭子可将费用减至零")
 f=fixture();put("spell-ucs-031","field",1)
 expect(not e.cast_payment_valid(0,f.orb,{},[{"uid":f.yellow.uid,"color":"黄"}]),"任意减费后仍需支付额外加费")
 var plan=[{"uid":f.yellow.uid,"color":"黄"},{"uid":f.black.uid,"color":"黑"}]
 expect(e.commit_cast(0,f.orb.uid,{},plan).is_empty(),"可以减掉一蓝并支付一黄及额外一黑")
 f=fixture();var invalid=[{"uid":f.yellow.uid,"color":"黄"},{"uid":f.black.uid,"color":"黑"}]
 var before=JSON.stringify([e.players,e.stack])
 expect(not e.commit_cast(0,f.orb.uid,{},invalid).is_empty() and JSON.stringify([e.players,e.stack])==before,"错误支付不消耗资源及首张道具减费")
 expect(e.commit_cast(0,f.orb.uid,{},[{"uid":f.yellow.uid,"color":"黄"}]).is_empty(),"失败后仍可按正确方案使用首张道具")
 var second=put("new-eto-s001","hand");e.priority=0
 expect(not e.cast_payment_valid(0,second,{},[{"uid":f.black.uid,"color":"黑"}]),"同回合第二张道具不再减费")
 e.turn+=2;e.stack.clear()
 expect(e.cast_payment_valid(0,second,{},[{"uid":f.black.uid,"color":"黑"}]),"下次自己的回合恢复首张道具减费")
 print("TOKIKO_DISCOUNT: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
