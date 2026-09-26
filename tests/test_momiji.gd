extends "res://tests/support/rules_base.gd"

const Draft=preload("res://scripts/payment_draft.gd")
const SeatView=preload("res://net/seat_projection.gd")

func run():
 fresh()
 var own=put("164");var enemy=put("164","field",1)
 var other=put("167");var palette=put("164","palette")
 var stale=[{"uid":own.uid,"color":"黄"}]
 expect(e.payment_valid(0,{"黄":1},stale),"item can pay before Momiji declares it")
 var momiji=enter("character-fdf-101")
 expect(e.pending.get("kind","")=="effect_choice","Momiji enters through the real naming trigger")
 var name=e.cards[own.card_id].name
 e.choose_effect(e.pending.options.filter(func(t):return t.card_name==name)[0]);one()
 expect(momiji.get("locked_name","")==name,"naming trigger stores the declared item name")
 for who in range(2):
  var item=own if who==0 else enemy
  expect(not e.source_resources(who).any(func(s):return s.uid==item.uid),"named item excluded for player "+str(who))
  expect(not e.payment_valid(who,{"黄":1},[{"uid":item.uid,"color":"黄"}]),"manual item reservation rejected for player "+str(who))
  var projected=SeatView.build(e,who)
  expect(not projected.queries.resources.any(func(s):return s.uid==item.uid),"network resources also exclude named item for player "+str(who))
  expect(projected.state.players[0].field.any(func(c):return c.uid==momiji.uid and c.get("locked_name","")==name),"network public field retains declaration for player "+str(who))
 expect(e.source_resources(0).any(func(s):return s.uid==other.uid),"differently named mana item remains usable")
 expect(e.source_resources(0).any(func(s):return s.uid==palette.uid),"same name in palette remains a normal palette resource")
 expect(e.payment(0,{"黄":1}).plan==[{"uid":palette.uid,"color":"黄"}],"automatic payment uses palette instead of locked item")
 expect(Draft.solve(e,0,{"黄":1},stale).ways==0,"payment draft rejects a reservation made before declaration")
 var unit=put("53","hand")
 e.priority=0
 var before=JSON.stringify({"players":e.players,"stack":e.stack})
 expect(e.commit_cast(0,unit.uid,{},stale)=="支付方案已失效","casting cannot commit a stale named-item payment")
 expect(JSON.stringify({"players":e.players,"stack":e.stack})==before,"invalid payment neither taps nor moves any card")
 var second=put("character-fdf-101","field",1);second.locked_name=name
 e.move_to(momiji,"hand")
 expect(not e.source_resources(0).any(func(s):return s.uid==own.uid),"second Momiji keeps the same name locked")
 e.move_to(second,"grave")
 expect(e.source_resources(0).any(func(s):return s.uid==own.uid) and e.source_resources(1).any(func(s):return s.uid==enemy.uid),"both players' mana items return when the last locking Momiji leaves")
 expect(not momiji.has("locked_name"),"declaration clears when its permanent leaves the field")
 for id in ["164","165","166","167","168"]:
  fresh();var item=put(id);var watcher=put("character-fdf-101","field",1)
  watcher.locked_name=e.cards[id].name
  expect(not e.source_resources(0).any(func(s):return s.uid==item.uid) and e.payment(0,e.cards[id].colors.reduce(func(cost,color):cost[color]=1;return cost,{})).ways==0,"Momiji prohibits the mana item: "+e.cards[id].name)
 print("MOMIJI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
