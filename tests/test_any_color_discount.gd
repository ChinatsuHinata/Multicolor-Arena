extends "res://tests/support/rules_base.gd"

const Draft=preload("res://scripts/payment_draft.gd")

func resources():
 for id in ["165","167","166","164","168"]:
  for i in range(3):put(id,"palette")

func role_source(card):
 var required=e.cards[card.card_id].requires_character
 for id in e.cards:
  if e.cards[id].kind=="自机" and e.Roster.character_matches(e.cards[id].character,required):
   put(id);return
 expect(false,"找到角色符卡的对应角色："+required)

func verify(card,expected: Array,title: String,target: Dictionary={}):
 var costs=e.cast_cost_options(0,card,target)
 expect(costs.size()==expected.size(),title+"：保留全部减费分配")
 var plan=[]
 for cost in expected:
  var payment=e.payment(0,cost);plan=payment.plan
  expect(payment.ways>0 and e.cast_payment_valid(0,card,target,plan),title+"：接受 "+str(cost))
  expect(Draft.solve_costs(e,0,costs,plan).ways>0,title+"：草案保留玩家指定的颜色")
 var error=e.commit_cast(0,card.uid,target,plan)
 expect(error.is_empty() and card.zone=="stack",title+"：真实使用成功："+error)

func run():
 fresh();resources();put("53")
 verify(put("174","hand"),[{"红":1,"蓝":1},{"红":1,"绿":1},{"蓝":1,"绿":1}],"有顶ノ天按单位数减费")
 fresh();resources();e.players[0].leader=e.make_card("character-fdn-025",0,"leader",true)
 verify(put("character-fdf-105","hand"),[{"红":3},{"红":2,"绿":1},{"红":1,"绿":2}],"姬海棠果自机费用条件减费")
 fresh();resources();e.players[0].life=10
 var mokou=e.make_card("character-fdn-004",0,"leader",true);e.players[0].leader=mokou
 verify(mokou,[{"红":2},{"红":1,"黄":1},{"黄":2}],"妹红低生命自机减费")
 fresh();resources();var history=put("spell-fdf-010","hand");role_source(history)
 put("53","exile").devour_owner=0;put("53","exile",1).devour_owner=1
 verify(history,[{"红":2},{"红":1,"蓝":1},{"蓝":2}],"幻想乡传说按双方吞食牌数减费",{"none":true})
 for source in ["sisters","wood","mod"]:
  fresh();resources()
  var spell=put("spell-fdf-035","exile")
  if source=="mod":spell.mod_access={"owner":0,"turn":e.turn,"zone":"exile","discount":2,"free":false}
  else:spell.catalogue_access={"owner":0,"discount":2,"support":source=="sisters"}
  if source=="sisters":e.players[0].leader=e.make_card("character-fdn-025",0,"leader",true)
  else:role_source(spell)
  verify(spell,[{"红":1},{"黑":1}],"移除区授权任意减费："+source,{"player":1})
 fresh();resources();put("53")
 var barrier=put("174","hand");barrier.mod_access={"owner":0,"turn":e.turn,"zone":"hand","discount":1,"free":false}
 verify(barrier,[{"红":1},{"蓝":1},{"绿":1}],"单位数减费与模组授权减费叠加")
 print("ANY_COLOR_DISCOUNT: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
