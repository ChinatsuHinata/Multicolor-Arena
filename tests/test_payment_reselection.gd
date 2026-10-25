extends "res://tests/support/rules_base.gd"

const Draft=preload("res://scripts/payment_draft.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")

func check_chain(who: int):
 fresh();e.active=who;e.priority=who
 var first=put("165","palette",who);first.token_colors=["红","蓝"]
 var second=put("167","palette",who);second.token_colors=["蓝","黄"]
 var red=put("165","palette",who)
 var cost={"红":1,"蓝":1,"黄":1}
 var selected=[{"uid":first.uid,"color":"红"},{"uid":second.uid,"color":"蓝"}]
 var original=selected.duplicate(true)
 var remote=Remote.new();remote.seat=who;remote.apply_snapshot(SeatView.build(e,who))
 for model in [e,remote]:
  var prefix=("Local" if model==e else "Remote")+" seat "+str(who)
  var options=Draft.options(model,who,cost,selected)
  expect(options.any(func(s):return s.uid==red.uid),prefix+" replacement can reassign two previously selected colors")
  var solution=Draft.solve_selected_costs(model,who,[cost],selected+[{"uid":red.uid}])
  expect(solution.ways>0 and e.payment_valid(who,cost,solution.plan),prefix+" reassigned plan passes authoritative validation")
  expect(solution.plan==[{"uid":first.uid,"color":"蓝"},{"uid":second.uid,"color":"黄"},{"uid":red.uid,"color":"红"}],prefix+" chained reassignment keeps every selected source")
  expect(selected==original,prefix+" solving does not mutate the input draft")
  expect(Draft.solve(model,who,cost,selected).ways==0,prefix+" explicit fixed-color solver still respects fixed colors")
  expect(Draft.solve_selected_costs(model,who,[cost],selected,[red.uid]).ways==0,prefix+" excluded completion cannot be spent")
  expect(not Draft.options(model,who,cost,selected,[red.uid]).any(func(s):return s.uid==red.uid),prefix+" excluded source is not offered")
  expect(Draft.solve_selected_costs(model,who,[cost],selected,[first.uid]).ways==0,prefix+" selected excluded source is rejected")
  expect(Draft.solve_selected_costs(model,who,[cost],selected+selected.slice(0,1)).ways==0,prefix+" duplicate selection is rejected")
  expect(Draft.solve_selected_costs(model,who,[cost],[{"uid":999999}]).ways==0,prefix+" missing source is rejected")
 first.tapped=true
 expect(Draft.solve_selected_costs(e,who,[cost],selected).ways==0,"tapped selected source is rejected")

func check_cost_options():
 fresh()
 var flexible=put("165","palette");flexible.token_colors=["红","蓝"]
 var yellow=put("164","palette")
 var selected=[{"uid":flexible.uid,"color":"红"}]
 var costs=[{"红":1,"蓝":1},{"蓝":1,"黄":1}]
 expect(Draft.options_for_costs(e,0,costs,selected).any(func(s):return s.uid==yellow.uid),"alternative costs can change the selected card's payment color")
 var solution=Draft.solve_selected_costs(e,0,costs,selected+[{"uid":yellow.uid}])
 expect(solution.ways>0 and e.payment_valid(0,costs[1],solution.plan),"alternative cost produces a valid reassigned plan")
 var mixed={"红/蓝":1,"红":1}
 var red=put("165","palette")
 solution=Draft.solve_selected_costs(e,0,[mixed],selected+[{"uid":red.uid}])
 expect(solution.ways>0 and e.payment_valid(0,mixed,solution.plan),"shared color pools still assign a valid complete payment")
 expect(Draft.solve_selected_costs(e,0,[{}],selected).ways==0,"zero cost cannot consume an extra selected source")
 expect(Draft.solve_selected_costs(e,0,[mixed],selected+[{"uid":red.uid},{"uid":yellow.uid}]).ways==0,"overpayment remains invalid")

func check_pair_and_potato():
 fresh()
 var pair=put("character-fdf-098")
 var flexible=put("165","palette");flexible.token_colors=["红","黄"]
 var red=put("165","palette")
 var selected=[{"uid":pair.uid,"color":"黄/绿"},{"uid":flexible.uid,"color":"红"}]
 var cost={"黄":2,"绿":1,"红":1}
 var solution=Draft.solve_selected_costs(e,0,[cost],selected+[{"uid":red.uid}])
 expect(solution.ways>0 and e.payment_valid(0,cost,solution.plan),"paired yellow/green payment permits another selected card to change color")
 expect(solution.plan.count({"uid":pair.uid,"color":"黄/绿"})==1 and solution.plan.size()==3,"paired resource remains one indivisible reservation")
 expect(Draft.solve_selected_costs(e,0,[{"黄":1}],[{"uid":pair.uid}]).ways==0,"paired resource cannot pay only half its output")
 fresh();e.players[0].potato=true
 red=put("165","palette")
 cost={"红":1,"蓝":1}
 selected=[{"uid":-100,"color":"红"}]
 expect(Draft.options(e,0,cost,selected).any(func(s):return s.uid==red.uid),"selected potato can change colors to accept a red card")
 solution=Draft.solve_selected_costs(e,0,[cost],selected+[{"uid":red.uid}])
 expect(solution.ways>0 and e.payment_valid(0,cost,solution.plan) and solution.plan[0].color=="蓝","potato is reassigned to blue without being consumed")

func check_keep_colors():
 fresh()
 var selected=[{"uid":put("164","palette").uid,"color":"黄"}]
 var blue=put("167","palette");var red=put("165","palette")
 var cost={"黄":1,"红/蓝":1}
 var solution=Draft.solve_selected_costs(e,0,[cost],selected,[],["红"])
 expect(solution.plan.any(func(p):return p.uid==blue.uid) and not solution.plan.any(func(p):return p.uid==red.uid),"remaining auto-completion respects keep-color preferences")
 solution=Draft.solve_selected_costs(e,0,[cost],selected+[{"uid":red.uid}],[],["红"])
 expect(solution.ways>0 and e.payment_valid(0,cost,solution.plan) and solution.plan.any(func(p):return p.uid==red.uid),"manual selection remains usable even when its color is preferred for keeping")

func run():
 for who in [0,1]:check_chain(who)
 check_cost_options();check_pair_and_potato();check_keep_colors()
 print("PAYMENT_RESELECTION: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
