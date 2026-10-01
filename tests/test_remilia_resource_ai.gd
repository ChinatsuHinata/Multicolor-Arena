extends "res://tests/support/rules_base.gd"
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")

func setup():
 fresh()
 e.players[0].leader=e.make_card(AI.REMILIA,0,"leader",true)
 e.ai_profiles=[AI.PROFILE,""];e.ai_memory=[{},{}]
 e.players[1].life=40
 var leader=e.players[0].leader
 leader.zone="field";leader.entered_turns=0;e.players[0].field.append(leader)

func resources(red: int,black: int):
 for i in range(red):put("165","palette")
 for i in range(black):put("168","palette")

func possession():
 e.phase="possession";e.pending={"kind":"possession","owner":0};e.ai_step(0)

func run():
 for id in AI.EARLY_CURVE:
  setup();resources(2,2)
  var incoming=put(AI.NUE,"palette");var outgoing=put(id,"hand")
  var before=JSON.stringify([e.players[0].field,e.players[0].life,e.players[1].life])
  possession()
  expect(outgoing.zone=="hand" and incoming.zone=="palette","five-resource possession keeps last early curve card: "+id)
  expect(JSON.stringify([e.players[0].field,e.players[0].life,e.players[1].life])==before and e.pending.is_empty(),"declined exchange still finishes possession without board mutation: "+id)
 setup();resources(2,2)
 var incoming=put(AI.NUE,"palette");put(AI.WINGS,"hand");put(AI.WINGS,"hand")
 possession()
 expect(incoming.zone=="hand" and e.players[0].hand.filter(func(c):return c.card_id==AI.WINGS).size()==1,"duplicate Wings can be exchanged while retaining one early copy")
 setup();resources(2,3)
 incoming=put(AI.RED,"palette");var outgoing=put(AI.WINGS,"hand")
 possession()
 expect(outgoing.zone=="palette" and incoming.zone=="hand","six-resource possession may replace Wings with direct damage")
 setup();resources(2,2)
 e.players[1].leader=e.make_card("70",1,"field",true);e.players[1].field.append(e.players[1].leader)
 incoming=put(AI.GUNGNIR,"palette");outgoing=put(AI.WINGS,"hand")
 possession()
 expect(incoming.zone=="hand" and outgoing.zone=="palette","public payable Reimu removal can justify using early Wings for possession")
 setup();resources(0,2)
 incoming=put(AI.AURORA,"palette");outgoing=put(AI.WINGS,"hand");e.players[1].life=3
 possession()
 expect(incoming.zone=="hand" and outgoing.zone=="palette","certified immediate lethal can justify an early curve exchange")
 for id in AI.BIG_UNITS:
  setup();resources(2,1)
  var big=put(id,"palette");big.tapped=true
  var aurora=put(AI.AURORA,"palette");aurora.tapped=true
  var red=put(AI.RED,"palette");red.tapped=true
  put(AI.FAIRY,"hand")
  var before=JSON.stringify([e.players,e.pending,e.revision,e.rng.state])
  var t=AI.crystal_target(e,0,[e.Pack.ref(e,aurora),e.Pack.ref(e,red),e.Pack.ref(e,big)])
  expect(t.is_empty(),"without Aya crystallization preserves heavy unit: "+id)
  expect(JSON.stringify([e.players,e.pending,e.revision,e.rng.state])==before,"crystal selection preserves live state and RNG: "+id)
  put(AI.AYA,"hand")
  expect(AI.crystal_target(e,0,[e.Pack.ref(e,big)]).is_empty(),"Aya cannot justify crystallizing the last heavy copy: "+id)
  var spare=put(id,"hand")
  expect(AI.crystal_target(e,0,[e.Pack.ref(e,big)]).get("uid",-1)==big.uid,"Aya in hand permits crystallizing a duplicate heavy unit: "+id)
  var held_aya=e.players[0].hand.filter(func(c):return c.card_id==AI.AYA)[0]
  e.move_to(held_aya,"grave")
  expect(AI.crystal_target(e,0,[e.Pack.ref(e,big)]).is_empty(),"even duplicate heavy units require accessible Aya: "+id)
  e.move_to(held_aya,"hand")
  var small=put(AI.LILY,"palette");small.tapped=true
  expect(AI.crystal_target(e,0,[e.Pack.ref(e,big),e.Pack.ref(e,small)]).get("uid",-1)==small.uid,"ordinary crystal candidate outranks a spare heavy unit: "+id)
  e.move_to(small,"grave")
  var aya=e.players[0].hand.filter(func(c):return c.card_id==AI.AYA)[0]
  e.move_to(aya,"palette")
  expect(AI.crystal_target(e,0,[e.Pack.ref(e,big)]).get("uid",-1)==big.uid,"Aya in palette also permits a spare heavy crystal: "+id)
  e.move_to(aya,"field")
  expect(AI.crystal_target(e,0,[e.Pack.ref(e,big)]).is_empty(),"Aya on battlefield does not enable heavy crystal: "+id)
  e.move_to(aya,"grave")
  expect(AI.crystal_target(e,0,[e.Pack.ref(e,big)]).is_empty(),"Aya in grave does not enable heavy crystal: "+id)
  expect(spare.zone=="hand","crystal selection preserves the reserved heavy copy: "+id)
 for burn_ids in [[AI.AURORA],[AI.RED],[AI.AURORA,AI.RED]]:
  setup();var burn=[]
  for id in burn_ids:
   var c=put(id,"palette");c.tapped=true;burn.append(c)
  var fairy=put(AI.FAIRY)
  var options=burn.map(func(c):return e.Pack.ref(e,c))
  expect(AI.crystal_target(e,0,options).is_empty(),"burn-only palette declines crystal: "+str(burn_ids))
  e.move_to(fairy,"grave");e.pump_choices()
  expect(e.pending.get("kind","")=="effect_choice","actual Fairy death offers optional crystal choice")
  e.ai_step(0)
  expect(e.pending.is_empty() and e.stack.is_empty() and fairy.zone=="grave" and burn.all(func(c):return c.zone=="palette" and c.tapped),"AI safely declines real crystal without destroying burn or hanging")
 setup()
 var aurora=put(AI.AURORA,"palette");aurora.tapped=true
 var fairy=put(AI.FAIRY)
 var big=put(AI.BIG_REMILIA,"palette");big.tapped=true
 put(AI.BIG_REMILIA,"hand");put(AI.AYA,"hand")
 e.move_to(fairy,"grave");e.pump_choices();e.ai_step(0);settle()
 expect(big.zone=="grave" and aurora.zone=="palette" and fairy.zone=="palette" and not fairy.tapped,"real crystal trades a spare large unit for upright Fairy and preserves Aurora")
 expect(e.players[0].hand.any(func(c):return c.card_id==AI.BIG_REMILIA),"real crystal retains the hand copy for six-mana expansion")
 setup()
 aurora=put(AI.AURORA,"palette");aurora.tapped=true
 var small=put(AI.LILY,"palette");small.tapped=true
 expect(AI.crystal_target(e,0,[e.Pack.ref(e,aurora),e.Pack.ref(e,small)]).get("uid",-1)==small.uid,"nonburn fallback never spends Aurora when no large unit is available")
 print("Remilia possession and crystal: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
