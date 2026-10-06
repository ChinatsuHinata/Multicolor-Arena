extends "res://tests/support/rules_base.gd"

func run():
 for who in [0,1]:
  fresh();e.active=who;e.priority=who
  var gourd=put("new-spx-002","field",who)
  var unit=put("53","field",who)
  var other=put("token-fdf-128","field",who);other.tapped=true
  var red=put("165","palette",who);red.tapped=true
  var green=put("166","palette",who);green.tapped=true
  var palette_gourd=put("new-spx-002","palette",who);palette_gourd.tapped=true
  expect(e.commit_extension(who,gourd.uid,e.ref_target(unit),[],"n21:gourd_counter").is_empty(),"gourd taps to put a drunk counter from seat "+str(who))
  one()
  expect(gourd.tapped and unit.get("drunk_counters",0)==1,"counter resolves without resetting the gourd")
  e.start_turn(1-who)
  expect(gourd.tapped and palette_gourd.tapped,"opponent's turn does not reset the owner's gourd")
  e.start_turn(who)
  expect(not gourd.tapped,"gourd automatically resets at the start of its owner's turn")
  expect(not other.tapped and not red.tapped and not green.tapped,"other items and palette cards still reset")
  expect(not palette_gourd.tapped,"a gourd used as a palette card still resets normally")
  e.phase="main";e.priority=who
  expect(e.commit_extension(who,gourd.uid,e.ref_target(unit),[],"n21:gourd_counter").is_empty(),"gourd can tap again after automatic reset")
  one();e.priority=who
  expect(gourd.tapped and unit.get("drunk_counters",0)==2,"automatic reset allows another drunk counter without payment")
  var plan=e.payment(who,{"红":1,"绿":1}).plan
  expect(e.commit_extension(who,gourd.uid,{"none":true},plan,"n21:gourd_reset").is_empty(),"paying red 1 green 1 activates gourd reset")
  expect(gourd.tapped and red.tapped and green.tapped,"paid reset waits for resolution and spends both colors")
  one()
  expect(not gourd.tapped,"paid reset untaps the gourd on resolution")
  e.priority=who
  expect(e.commit_extension(who,gourd.uid,e.ref_target(unit),[],"n21:gourd_counter").is_empty(),"gourd can tap again after paid reset")
  one();e.priority=who
  var before=JSON.stringify([e.players,e.stack,e.revision])
  expect(not e.commit_extension(who,gourd.uid,{"none":true},[],"n21:gourd_reset").is_empty(),"gourd reset requires its printed payment")
  expect(JSON.stringify([e.players,e.stack,e.revision])==before and gourd.tapped,"unpaid reset leaves the duel unchanged")
  e.start_turn(who)
  expect(not gourd.tapped,"gourd automatically resets on subsequent owner turns")
 print("IBUKI_GOURD: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
