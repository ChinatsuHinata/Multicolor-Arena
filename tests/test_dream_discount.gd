extends "res://tests/support/rules_base.gd"

const Gateway=preload("res://net/command_gateway.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const Draft=preload("res://scripts/payment_draft.gd")

func sky_fixture(who: int=0,with_blue: bool=true):
 fresh();e.active=who;e.priority=who
 var duo=put("new-eto-003","field",who);duo.leader=true
 var spell=put("new-eto-008","hand",who)
 var enemy=put("53","field",1-who)
 var target=e.Roster.New.spell_options(e,spell.card_id,who).filter(func(o):return o.n21_modes==1)[0].duplicate(true)
 target.erase("selection");target.picks=[[e.ref_target(enemy)]]
 var yellow=[];var blue=[]
 for i in range(3):yellow.append(put("164","palette",who))
 if with_blue:
  for i in range(2):blue.append(put("167","field",who))
 return {"duo":duo,"spell":spell,"target":target,"yellow":yellow,"blue":blue}

func plan_for(f,yellow_count: int):
 var plan=[]
 for i in range(yellow_count):plan.append({"uid":f.yellow[i].uid,"color":"黄"})
 for i in range(3-yellow_count):plan.append({"uid":f.blue[i].uid,"color":"蓝"})
 return plan

func run():
 var f=sky_fixture()
 var costs=e.cast_cost_options(0,f.spell,f.target)
 expect(costs.size()==3,"梦违减费保留一黄两蓝、两黄一蓝和三黄三种组合")
 expect(e.cast_cost(0,f.spell,f.target).get("蓝",0)==2,"推荐仍优先使用费用较低的产蓝道具")
 for yellow_count in [1,2,3]:
  var plan=plan_for(f,yellow_count)
  expect(e.cast_payment_valid(0,f.spell,f.target,plan),"推荐方案不限制玩家改付 %d 黄" % yellow_count)
 var fixed=plan_for(f,3).slice(0,2)
 var sources=Draft.options_for_costs(e,0,costs,fixed)
 expect(sources.any(func(s):return s.uid==f.yellow[2].uid and s.reservation.color=="黄"),"已选两黄时第三张黄仍可补齐费用")
 expect(Draft.solve_costs(e,0,costs,plan_for(f,3)).ways>0,"三黄可完成支付草案")
 f=sky_fixture(0,false)
 expect(e.cast_error(0,f.spell.uid).is_empty(),"只有三黄且没有蓝色来源也可使用空与海")
 expect(e.payment(0,e.cast_cost(0,f.spell,f.target)).plan==plan_for(f,3),"只有三黄时自动推荐三黄")
 for who in [0,1]:
  for yellow_count in [1,2,3]:
   f=sky_fixture(who)
   var remote=Remote.new();remote.seat=who;remote.apply_snapshot(SeatView.build(e,who))
   var remote_spell=remote.find_card(f.spell.uid)
   var plan=plan_for(f,yellow_count)
   expect(remote.cast_payment_valid(who,remote_spell,f.target,plan),"联机座位 %d 接受 %d 黄的减费方案" % [who,yellow_count])
   fixed=plan_for(f,3).slice(0,2)
   sources=Draft.options_for_costs(remote,who,remote.cast_cost_options(who,remote_spell,f.target),fixed)
   expect(sources.any(func(s):return s.uid==f.yellow[2].uid),"联机座位 %d 允许第三张黄补齐费用" % who)
   var error=Gateway.apply(e,who,{"name":"commit_cast","args":[f.spell.uid,f.target,plan]})
   expect(error.is_empty() and f.spell.zone=="stack","主机按 %d 黄方案实际使用空与海：%s" % [yellow_count,error])
   expect(f.yellow.filter(func(c):return c.tapped).size()==yellow_count and f.blue.filter(func(c):return c.tapped).size()==3-yellow_count,"仅横置玩家选择的资源")
 for invalid in ["short","extra","wrong_color","duplicate","tapped","removed","inactive","opponent"]:
  f=sky_fixture();var plan=plan_for(f,3)
  match invalid:
   "short":plan.pop_back()
   "extra":plan.append({"uid":f.blue[0].uid,"color":"蓝"})
   "wrong_color":plan[0]={"uid":put("165","palette").uid,"color":"红"}
   "duplicate":plan[1].uid=plan[0].uid
   "tapped":f.yellow[0].tapped=true
   "removed":e.move_to(f.duo,"hand")
   "inactive":f.duo.leader=false
   "opponent":e.move_to(f.duo,"hand");put("new-eto-003","field",1).leader=true
  var before=JSON.stringify([e.players,e.stack])
  expect(not e.commit_cast(0,f.spell.uid,f.target,plan).is_empty(),"拒绝不合法的梦违支付："+invalid)
  expect(before==JSON.stringify([e.players,e.stack]),"无效支付保持对局状态："+invalid)
 f=sky_fixture();put("24")
 expect(e.cast_payment_valid(0,f.spell,f.target,plan_for(f,3).slice(0,2)),"八云蓝减蓝与梦违任意两点减费叠加")
 f=sky_fixture();put("new-eto-003").leader=true
 expect(e.cast_payment_valid(0,f.spell,f.target,plan_for(f,3).slice(0,1)),"多个生效的梅莉叠加任意减费")
 put("new-eto-003").leader=true
 expect(e.cast_payment_valid(0,f.spell,f.target,[]),"减费超过原费用时可零费使用")
 f=sky_fixture();var ordinary=put("167","hand")
 expect(e.cast_cost(0,ordinary).get("蓝",0)==2,"梅莉不减免不具有梦违的牌")
 f=sky_fixture();put("spell-ucs-031","field",1)
 expect(not e.cast_payment_valid(0,f.spell,f.target,plan_for(f,3)),"梦违减费不能抵消额外加费")
 var taxed_plan=plan_for(f,3)+[{"uid":f.blue[0].uid,"color":"蓝"}]
 expect(e.commit_cast(0,f.spell.uid,f.target,taxed_plan).is_empty(),"三黄加额外一费可实际使用")
 f=sky_fixture();e.forced_cast={"owner":0,"uid":f.spell.uid,"free":true,"ignore":true,"cost":{}}
 expect(e.cast_payment_valid(0,f.spell,f.target,[]),"免费使用不因任意减费产生费用")
 print("DREAM_DISCOUNT: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
