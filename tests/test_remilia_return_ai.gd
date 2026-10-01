extends "res://tests/support/rules_base.gd"
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")

func remilia(who: int,specialized: bool) -> Dictionary:
 fresh()
 var c=e.make_card(AI.REMILIA,who,"field",true)
 c.entered_turns=0;e.players[who].leader=c;e.players[who].field.append(c)
 e.ai_profiles[who]=AI.PROFILE if specialized else ""
 return c

func run():
 for specialized in [true,false]:
  for who in [0,1]:
   var label=("specialized" if specialized else "generic")+" seat "+str(who)
   var c=remilia(who,specialized)
   var opponent=1-who;e.active=opponent;e.priority=opponent
   put("165","palette",opponent);put("167","palette",opponent)
   var spell=put("138","hand",opponent)
   var error=e.commit_cast(opponent,spell.uid,e.ref_target(c),e.payment(opponent,e.cast_cost(opponent,spell)).plan)
   expect(error.is_empty(),"opponent legally casts bounce on small Remilia: "+label)
   one()
   expect(e.pending.get("kind","")=="leader_return" and e.pending.get("owner",-1)==who,"real bounce offers owner a return choice: "+label)
   e.ai_step(who)
   expect(c.zone=="hand" and c in e.players[who].hand and c not in e.players[who].field,"AI keeps bounced Remilia in hand: "+label)
   expect(c.timer==0 and e.timer_changes.is_empty() and not e.ai_memory[who].get("leader_died",false),"bounce adds no home countdown or death memory: "+label)
   expect(is_same(c,e.players[who].leader) and c.leader,"bounce preserves original leader identity: "+label)
   # Replay the same physical leader directly without waiting for a home timer.
   e.active=who;e.priority=who
   put("165","palette",who);put("165","palette",who);put("168","palette",who)
   var lily=put(AI.LILY,"field",who);lily.color_counters=["红"]
   error=e.commit_cast(who,c.uid,{"none":true},e.payment(who,e.cast_cost(who,c)).plan)
   expect(error.is_empty(),"bounced Remilia can be paid and replayed directly: "+label)
   settle()
   expect(c.zone=="field" and is_same(c,e.players[who].leader),"replayed Remilia returns to field with leader identity: "+label)
   c=remilia(who,specialized)
   e.move_to(c,"grave",false);e.pump_choices()
   e.move_to(c,"hand");e.pump_choices();e.ai_step(who)
   expect(c.zone=="hand","grave recovery also keeps small Remilia in hand: "+label)
   c=remilia(who,specialized)
   e.damage_target(e.ref_target(c),3);e.pump_choices();e.ai_step(who)
   expect(c.zone=="leader","death without recovery still returns small Remilia home: "+label)
 for who in [0,1]:
  # A bounced leader should be the first nonlethal play next main phase,
  # even when a larger unit is also affordable.
  var c=remilia(who,true)
  var opponent=1-who;e.active=opponent;e.priority=opponent
  put("165","palette",opponent);put("167","palette",opponent)
  var bounce=put("138","hand",opponent)
  var error=e.commit_cast(opponent,bounce.uid,e.ref_target(c),e.payment(opponent,e.cast_cost(opponent,bounce)).plan)
  expect(error.is_empty(),"recast setup bounces Remilia: seat "+str(who))
  one();e.ai_step(who)
  expect(c.zone=="hand","recast setup keeps Remilia in hand: seat "+str(who))
  e.active=who;e.priority=who
  for i in range(4):put("165","palette",who)
  for i in range(2):put("168","palette",who)
  var support=put(AI.LILY,"field",who);support.color_counters=["红"]
  put(AI.BIG_REMILIA,"hand",who)
  expect(e.cast_error(who,c.uid).is_empty(),"bounced Remilia is legal to replay: seat "+str(who))
  e.ai_step(who)
  expect(e.stack.any(func(entry):return entry.get("kind","")=="card" and entry.card.uid==c.uid),"AI immediately replays bounced Remilia ahead of expansion: seat "+str(who))
 # A nonlethal removal opening must not spend the only mana for replay.
 var c=remilia(0,true)
 e.active=1;e.priority=1
 put("165","palette",1);put("167","palette",1)
 var bounce=put("138","hand",1)
 var error=e.commit_cast(1,bounce.uid,e.ref_target(c),e.payment(1,e.cast_cost(1,bounce)).plan)
 expect(error.is_empty(),"removal setup bounces Remilia")
 one();e.ai_step(0)
 var enemy=e.players[1].leader
 enemy.zone="field";enemy.entered_turns=0;e.players[1].field.append(enemy)
 e.active=0;e.priority=0
 put("165","palette");put("165","palette")
 for i in range(3):put("168","palette")
 var lily=put(AI.LILY);lily.color_counters=["红"]
 put(AI.AURORA,"hand")
 expect(e.cast_error(0,c.uid).is_empty(),"Remilia is legal while Aurora can remove Reimu")
 e.ai_step(0)
 expect(e.stack.any(func(entry):return entry.get("kind","")=="card" and entry.card.uid==c.uid),"AI replays bounced Remilia before nonlethal Aurora")
 # With no red/black permanent, build the leader's color constraint first.
 c=remilia(0,true)
 e.active=1;e.priority=1
 put("165","palette",1);put("167","palette",1)
 bounce=put("138","hand",1)
 error=e.commit_cast(1,bounce.uid,e.ref_target(c),e.payment(1,e.cast_cost(1,bounce)).plan)
 expect(error.is_empty(),"color-source setup bounces Remilia")
 one();e.ai_step(0)
 enemy=e.players[1].leader
 enemy.zone="field";enemy.entered_turns=0;e.players[1].field.append(enemy)
 e.active=0;e.priority=0
 put("165","palette");put("165","palette")
 for i in range(3):put("168","palette")
 lily=put(AI.LILY,"hand")
 put(AI.AURORA,"hand")
 expect(e.cast_error(0,c.uid)=="战场永久物尚未满足自机颜色约束","replay initially lacks both field colors")
 e.ai_step(0)
 expect(e.stack.any(func(entry):return entry.get("kind","")=="card" and entry.card.uid==lily.uid),"AI plays Lily for Remilia colors before Aurora")
 expect(AI.settle_sim(e,0),"color source resolves")
 expect("红" in e.Pack.colors(e,lily) and "黑" in e.Pack.colors(e,lily),"Lily chooses red and supplies both colors")
 expect(e.cast_error(0,c.uid).is_empty(),"Remilia is legal after Lily supplies colors")
 e.ai_step(0)
 expect(e.stack.any(func(entry):return entry.get("kind","")=="card" and entry.card.uid==c.uid),"AI replays Remilia immediately after supplying colors")
 # Wings also supplies both colors when Lily is unavailable.
 c=remilia(0,true);e.move_to(c,"hand",false)
 for i in range(3):put("165","palette")
 for i in range(2):put("168","palette")
 var wings=put(AI.WINGS,"hand")
 e.ai_step(0)
 expect(e.stack.any(func(entry):return entry.get("kind","")=="card" and entry.card.uid==wings.uid),"AI uses Wings to build missing colors")
 expect(AI.settle_sim(e,0) and e.cast_error(0,c.uid).is_empty(),"Wings bats make Remilia replay legal")
 e.ai_step(0)
 expect(e.stack.any(func(entry):return entry.get("kind","")=="card" and entry.card.uid==c.uid),"AI replays Remilia after Wings")
 # A field card can supply the same constraint without a unit.
 c=remilia(0,true);e.move_to(c,"hand",false)
 for i in range(3):put("165","palette")
 for i in range(2):put("168","palette")
 var castle=put(AI.CASTLE,"hand")
 e.ai_step(0)
 expect(e.stack.any(func(entry):return entry.get("kind","")=="card" and entry.card.uid==castle.uid),"AI uses Scarlet Mansion to build missing colors")
 expect(AI.settle_sim(e,0) and e.cast_error(0,c.uid).is_empty(),"Scarlet Mansion makes Remilia replay legal")
 e.ai_step(0)
 expect(e.stack.any(func(entry):return entry.get("kind","")=="card" and entry.card.uid==c.uid),"AI replays Remilia after Scarlet Mansion")
 # A verified immediate win retains priority over the replay.
 c=remilia(0,true);e.move_to(c,"hand",false)
 for i in range(2):put("165","palette")
 for i in range(3):put("168","palette")
 lily=put(AI.LILY);lily.color_counters=["红"]
 var aurora=put(AI.AURORA,"hand")
 e.players[1].life=3
 e.ai_step(0)
 expect(e.stack.any(func(entry):return entry.get("kind","")=="card" and entry.card.uid==aurora.uid),"immediate Aurora win precedes Remilia replay")
 # Possession may fetch a color source, but must never exchange the leader.
 c=remilia(0,true);e.move_to(c,"hand",false)
 var color_source=put(AI.CASTLE,"palette")
 e.phase="possession";e.pending={"kind":"possession","owner":0}
 e.ai_step(0)
 expect(c.zone=="hand" and color_source.zone=="palette","AI never puts sole hand Remilia into palette")
 c=remilia(0,false);e.move_to(c,"hand",false)
 color_source=put(AI.CASTLE,"palette")
 e.phase="possession";e.pending={"kind":"possession","owner":0}
 e.ai_step(0)
 expect(c.zone=="hand" and color_source.zone=="palette","generic AI also keeps sole hand Remilia out of palette")
 c=remilia(0,true);e.move_to(c,"hand",false)
 for i in range(3):put("165","palette")
 for i in range(2):put("168","palette")
 color_source=put(AI.CASTLE,"palette")
 var filler=put("164","hand")
 e.phase="possession";e.pending={"kind":"possession","owner":0}
 e.ai_step(0)
 expect(c.zone=="hand" and color_source.zone=="hand" and filler.zone=="palette","AI fetches color source with another card while keeping Remilia")
 e.phase="main";e.priority=0
 e.ai_step(0)
 expect(e.stack.any(func(entry):return entry.get("kind","")=="card" and entry.card.uid==color_source.uid),"AI plays fetched color source")
 expect(AI.settle_sim(e,0),"fetched color source resolves")
 e.ai_step(0)
 expect(e.stack.any(func(entry):return entry.get("kind","")=="card" and entry.card.uid==c.uid),"AI replays Remilia after fetching its colors")
 fresh();var other=e.players[0].leader
 other.zone="field";other.entered_turns=0;e.players[0].field.append(other)
 e.move_to(other,"hand");e.pump_choices();e.ai_step(0)
 expect(other.zone=="leader","other leaders keep their existing return decision")
 print("Remilia return AI: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
