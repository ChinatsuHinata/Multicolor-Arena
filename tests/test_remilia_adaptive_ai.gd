extends "res://tests/support/rules_base.gd"
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")
const Counterplay=preload("res://scripts/ai/release_counterplay.gd")

func setup(opponent: String="76"):
 fresh()
 e.players[0].leader=e.make_card(AI.REMILIA,0,"leader",true)
 e.players[1].leader=e.make_card(opponent,1,"leader",true)
 e.ai_profiles=[AI.PROFILE,""];e.ai_memory=[{},{}];e.players[1].life=40

func resources(red: int,black: int):
 for i in range(red):put("165","palette")
 for i in range(black):put("168","palette")

func leader(who: int=0):
 var c=e.players[who].leader;c.zone="field";c.entered_turns=0;e.players[who].field.append(c)
 return c

func possession():
 e.phase="possession";e.pending={"kind":"possession","owner":0};e.ai_step(0)

func run():
 resource_regressions()
 public_counterplay()
 collateral_regressions()
 survival_regressions()
 print("Remilia adaptive decisions: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func resource_regressions():
 setup();resources(3,2);e.players[0].leader.timer=2
 var big=put(AI.BIG_REMILIA,"palette");var source=put(AI.FAIRY,"palette");var nue=put(AI.NUE,"hand")
 possession()
 expect(source.zone=="hand" and big.zone=="palette" and nue.zone=="palette","after a wipe possession replaces color-locked Nue with playable Fairy rather than another locked leader")
 e.phase="main";e.priority=0;e.ai_step(0)
 expect(not e.stack.is_empty() and e.stack.back().card.uid==source.uid,"seven-mana empty board deploys the recovered color source")
 setup();resources(3,3)
 var fairy=put(AI.FAIRY,"palette");big=put(AI.BIG_REMILIA,"hand")
 possession()
 expect(fairy.zone=="hand" and big.zone=="palette","possession recovers Fairy to rebuild missing leader colors")
 e.phase="main";e.priority=0;e.ai_step(0);settle();e.priority=0;e.ai_step(0)
 expect(e.stack.any(func(s):return s.get("card",{}).get("uid",-1)==e.players[0].leader.uid),"rebuilding colors leads to an actual legal Remilia cast")
 setup();resources(3,3);leader()
 put(AI.BIG_REMILIA);big=put(AI.BIG_REMILIA,"hand")
 var held=AI.position_score(e,0);e.move_to(big,"grave")
 expect(held==AI.position_score(e,0),"duplicate title receives no castable body score")
 setup();resources(3,3);e.players[0].leader.zone="grave";e.players[0].grave.append(e.players[0].leader)
 var queen=put(AI.QUEEN,"hand");var score=AI.position_score(e,0);e.move_to(queen,"grave")
 expect(score==AI.position_score(e,0),"unavailable support character receives no castable spell score")
 setup();resources(2,2);put(AI.FAIRY,"hand");put(AI.BIG_REMILIA,"palette")
 e.phase="possession";e.pending={"kind":"possession","owner":0}
 var state=AI.capture_sim(e);var before=JSON.stringify([e.players,e.pending,e.revision,e.rng.state])
 var value=AI.position_score(e,0)
 expect(before==JSON.stringify([e.players,e.pending,e.revision,e.rng.state]),"possession scoring preserves zones aliases pending state and RNG")
 put("100","hand",1);var one_score=AI.position_score(e,0)
 e.players[1].hand[0].card_id="96"
 expect(one_score==AI.position_score(e,0),"possession does not read an unknown opposing hand identity")
 AI.restore_sim(e,state)
 expect(value==AI.position_score(e,0),"restoring the same decision yields the same score")

func public_counterplay():
 setup()
 for key in Counterplay.library().entries:
  var entry=Counterplay.library().entries[key]
  for id in entry.policy.get("support_targets",{}):expect(e.cards.has(id),"support target exists in current card catalogue: "+id)
  if not entry.has("review"):continue
  var review=entry.review
  expect(not review.category.is_empty() and not review.observed_traits.is_empty() and not review.responses.is_empty(),"reviewed matchup keeps category observations and responses: "+key)
  expect(review.evidence.all(func(row):return row.sha256.length()==64 and row.file.ends_with(".mreply")),"review keeps identifiable source evidence: "+key)
 setup("character-fdf-119");leader()
 var reimu=put("70","field",1)
 put("164","palette",1);put("164","palette",1);put("100","hand",1)
 resources(3,3)
 expect(Counterplay.select(e,0).matchup.opponent_key=="character-fdf-119","normal Reimu does not change Patchouli matchup identity")
 expect(Counterplay.select(e,0).category=="防避控制／角色符连动","reviewed matchup category reaches runtime decision diagnostics")
 expect(Counterplay.reimu_seal_risk(e,0),"normal Reimu publicly enables Seal risk in Patchouli deck")
 var big=put(AI.BIG_REMILIA,"hand")
 expect(not AI.cast(e,0,big,{"none":true}),"expensive deployment respects the ordinary Reimu response window")
 var gun=put(AI.GUNGNIR,"hand");e.ai_step(0)
 expect(not e.stack.is_empty() and e.stack.back().card.uid==gun.uid and e.stack.back().target.uid==reimu.uid,"remove the visible Seal role before committing expensive mana")
 settle();expect(not Counterplay.reimu_seal_risk(e,0),"Seal risk disappears when ordinary Reimu leaves")
 setup("character-fdf-119");put("70","field",1);put("164","palette",1);put("168","palette",1);put("100","hand",1)
 expect(not Counterplay.reimu_seal_risk(e,0),"one yellow plus black is not a payable Seal")
 setup("character-fdf-119");put("70","field",1);put("164","palette",1);put("164","palette",1)
 var revealed=put("96","hand",1);AI.observe_reveal(e,revealed)
 expect(not Counterplay.reimu_seal_risk(e,0),"fully known non-counter hand does not imply Seal")
 setup("character-fdn-036")
 var hatate=put("25","field",1)
 expect(Counterplay.target_bonus(e,hatate)>0,"Aya matchup identifies publicly present Hatate bounce support")
 expect(AI.removal_enemies(e,0).any(func(c):return c.uid==hatate.uid),"a support priority participates in actual removal candidate selection")
 e.move_to(hatate,"hand")
 expect(Counterplay.target_bonus(e,hatate)==0,"support bonuses never apply to hidden or absent cards")
 setup("character-fdf-119");hatate=put("25","field",1)
 expect(Counterplay.target_bonus(e,hatate)==0,"support priorities remain scoped to the full matchup")
 var bundle=Counterplay.library().duplicate(true);bundle.entries["74::character-fdf-119"].policy.support_targets={"70":NAN}
 expect(Counterplay.select(e,0,bundle).reason=="invalid_counterplay","corrupt support priority falls back safely")

func collateral_regressions():
 setup("character-kmo-001");resources(3,3);var rem=leader();put(AI.FAIRY);put(AI.LILY)
 var okuu=put("78","field",1);var gun=put(AI.GUNGNIR,"hand");var target=e.ref_target(okuu)
 var before=JSON.stringify([e.players,e.pending,e.rng.state,e.revision])
 expect(not AI.removal_collateral_safe(e,0,gun,target),"do not trade our whole aura board for isolated Okuu death sweep")
 expect(before==JSON.stringify([e.players,e.pending,e.rng.state,e.revision]),"collateral simulation does not mutate the actual board or RNG")
 expect(not AI.cast(e,0,gun,target) and e.stack.is_empty(),"ordinary removal refuses the harmful death sweep")
 e.players[1].night_lock=e.turn
 expect(AI.cast(e,0,gun,target),"Night's active death lock permits the same removal")
 settle();expect(rem.zone=="field" and okuu.zone=="grave","actual locked sweep kills Okuu and preserves Remilia")
 setup();resources(1,1);rem=leader();e.move_to(rem,"grave")
 var big=put(AI.BIG_REMILIA);okuu=put("78","field",1);put("78","field",1)
 gun=put(AI.MIST,"hand");resources(2,2)
 expect(AI.removal_collateral_safe(e,0,gun,e.ref_target(okuu)),"favorable public sweep remains available")
 setup();resources(1,1);rem=leader();var ordinary=put("70","field",1);gun=put(AI.GUNGNIR,"hand")
 expect(AI.cast(e,0,gun,e.ref_target(ordinary)),"ordinary core removal retains its existing behavior")

func begin_defense(attacker: Dictionary):
 e.active=1;e.priority=1;e.attack(1,attacker.uid);one()
 expect(e.pending.get("kind","")=="block","actual combat reaches blocker choice")

func survival_regressions():
 setup();var small=put(AI.LILY);var attacker=put(AI.BIG_REMILIA,"field",1);e.players[0].life=4
 begin_defense(attacker)
 var before=JSON.stringify([e.players,e.pending,e.combat,e.rng.state,e.revision]);var blocks=AI.defensive_blocks(e)
 expect(blocks==[small.uid],"sacrifice a cheap blocker rather than lose to a lethal spirit hit")
 expect(before==JSON.stringify([e.players,e.pending,e.combat,e.rng.state,e.revision]),"survival search preserves live combat and randomness")
 e.block(blocks);AI.settle_sim(e,1)
 expect(e.winner==-2 and e.players[0].life>0,"chosen emergency block actually survives")
 setup();small=put(AI.LILY);attacker=put(AI.BIG_REMILIA,"field",1);e.players[0].life=20
 begin_defense(attacker)
 expect(AI.defensive_blocks(e).is_empty(),"healthy board keeps the normal no-bad-trades policy")
 setup();small=put(AI.LILY);attacker=put(AI.BIG_REMILIA,"field",1);attacker.modifiers=[{"歼灭":true}];e.players[0].life=4
 begin_defense(attacker)
 expect(AI.survival_blocks(e,attacker).is_empty(),"annihilate prevents claiming a dying chump is a rescue")
 setup("character-kmo-001");small=put(AI.LILY);attacker=leader(1);e.players[0].coins=2
 begin_defense(attacker);blocks=AI.defensive_blocks(e)
 expect(blocks==[small.uid],"two coins trigger emergency defense even at full life")
 e.block(blocks);AI.settle_sim(e,1)
 expect(e.winner==-2 and int(e.players[0].coins)==2,"real Komachi combat avoids the third coin")
