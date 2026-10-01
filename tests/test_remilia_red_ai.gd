extends "res://tests/support/rules_base.gd"
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")
var serial=0

func board(red: int=2,black: int=1):
 fresh();e.ai_profiles=[AI.PROFILE,""]
 var rem=e.make_card(AI.REMILIA,0,"field",true)
 rem.entered_turns=0;rem.tapped=true;e.players[0].leader=rem;e.players[0].field.append(rem)
 for i in range(red):put("165","palette")
 for i in range(black):put("168","palette")
 return rem
func body(who: int,power: int,health: int,spirit: int):
 serial+=1;var id="red_fixture_"+str(serial)
 e.cards[id]=e.cards["164"].duplicate(true)
 e.cards[id].merge({"kind":"单位","title":"","character":"测试单位","race":[],"colors":["红"],"cost":{},"abilities":[],"power":power,"health":health,"spirit":spirit,"keywords":[]},true)
 return put(id,"field",who)
func played() -> Dictionary:
 var entries=e.stack.filter(func(s):return s.kind=="card")
 return entries[0] if not entries.is_empty() else {}
func finish_turn():
 for i in range(12):
  if e.winner!=-2:return
  e.priority=0;e.ai_step(0)
  expect(AI.settle_sim(e,0),"chosen RED route resolves")

func run():
 lifesteal_setup()
 reimu_coordination()
 board();var enemy=body(1,5,3,1);var red=put(AI.RED,"hand");put(AI.WINGS,"hand")
 e.ai_step(0)
 expect(played().get("card",{}).get("card_id","")==AI.WINGS,"ordinary blocker no longer makes RED precede expansion")
 expect(AI.settle_sim(e,0) and e.units(0).size()==3 and red.zone=="hand","expansion keeps RED for future player damage")
 board();enemy=body(1,5,3,1);red=put(AI.RED,"hand")
 e.ai_step(0)
 expect(played().get("card",{}).get("card_id","")==AI.RED and played().target.get("uid",-1)==enemy.uid,"RED can still remove an ordinary threat when no better action remains")
 expect(AI.settle_sim(e,0) and enemy.zone=="grave","deferred RED still pays and kills the target")
 board();enemy=e.make_card(AI.REMILIA,1,"field",true)
 enemy.entered_turns=0;e.players[1].leader=enemy;e.players[1].field.append(enemy)
 put(AI.RED,"hand");put(AI.WINGS,"hand");e.ai_step(0)
 expect(played().get("card",{}).get("card_id","")==AI.RED and played().target.get("uid",-1)==enemy.uid,"live opposing core still permits immediate RED removal")
 board();enemy=body(1,5,3,1);red=put(AI.RED,"hand")
 var with_target=AI.position_score(e,0);e.players[0].hand.erase(red)
 var benefit=with_target-AI.position_score(e,0)
 e.players[0].hand.append(red);enemy.base_override={"health":4}
 var without_target=AI.position_score(e,0);e.players[0].hand.erase(red)
 var normal=without_target-AI.position_score(e,0)
 expect(benefit>normal and benefit-normal<1000,"RED possession gains a modest removal bonus instead of a full removal-card bonus")
 board();enemy=body(1,5,3,1);put(AI.RED,"hand");e.players[1].life=3
 e.ai_step(0)
 expect(played().get("card",{}).get("card_id","")==AI.RED and played().target.get("player",-1)==1,"immediate lethal casts RED at player despite a killable unit")
 expect(AI.settle_sim(e,0) and e.winner==0 and enemy.zone=="field","direct RED damage wins without spending damage on the unit")
 # A tapped blocker makes clearing it pointless; lifesteal creates the burn win.
 board();enemy=body(1,5,3,1);enemy.tapped=true
 body(0,1,3,2);put(AI.RED,"hand");e.players[1].life=6
 e.ai_step(0)
 expect(not e.combat.is_empty() and played().is_empty(),"lethal turn attacks for lifesteal before RED removal")
 expect(AI.settle_sim(e,0),"lifesteal attack resolves")
 e.priority=0;e.ai_step(0)
 expect(played().target.get("player",-1)==1,"post-lifesteal RED sends its increased damage to the player")
 expect(AI.settle_sim(e,0) and e.winner==0 and enemy.zone=="field","lifesteal plus player RED completes a real lethal")
 # Removal remains a searched option when burning face alone cannot win.
 board();enemy=body(1,5,3,1);body(0,1,3,5)
 put(AI.RED,"hand");e.players[1].life=5
 var action=AI.lethal_action(e,0)
 expect(action.get("card_id","")==AI.RED and action.target.get("uid",-1)==enemy.uid,"necessary RED blocker removal is still a certified lethal option")
 expect(AI.execute(e,0,action) and AI.settle_sim(e,0),"necessary removal pays its real cost and resolves")
 finish_turn();expect(e.winner==0,"necessary blocker removal still leads to the winning attack")
 print("Remilia RED AI: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func block_with(blocker: Dictionary):
 for i in range(12):
  e.pump_choices()
  if e.pending.get("kind","")=="block":break
  e.pass_priority(e.priority)
 expect(e.pending.get("kind","")=="block","setup attack reaches a real block decision")
 e.block([blocker.uid]);expect(AI.settle_sim(e,0),"chosen block and lifesteal resolve")

func lifesteal_setup():
 var rem=board();rem.tapped=false
 var small=body(0,1,1,1);var red=put(AI.RED,"hand");e.players[1].life=40
 var before=AI.position_key(e,0)
 expect(AI.red_setup_choice(e,0).get("uid",-1)==small.uid and AI.position_key(e,0)==before,"RED preparation chooses small lifestealer without mutating the position")
 expect(not AI.cast(e,0,red,{"player":1}) and not AI.pressure_execute(e,0,{"kind":"cast","uid":red.uid,"card_id":AI.RED,"target":{"player":1}}),"ordinary and pressure casts defer RED until useful small attacks")
 expect(not AI.cast(e,0,red,{"player":1},false),"waiving Gungnir reservation does not waive RED preparation")
 var attacks=AI.search_actions(e,0).filter(func(a):return a.kind=="attack")
 expect(not attacks.is_empty() and attacks[0].uid==small.uid,"lethal search tries the small lifestealer before Remilia")
 e.ai_step(0)
 expect(e.combat.get("attacker",{}).get("uid",-1)==small.uid and red.zone=="hand","release AI attacks with small unit while keeping RED")
 expect(AI.settle_sim(e,0) and AI.red_damage(e,0)==4,"real one-point lifesteal raises RED to four")
 board();small=body(0,1,1,1);red=put(AI.RED,"hand");e.players[1].life=3
 e.ai_step(0)
 expect(played().get("target",{}).get("player",-1)==1 and e.combat.is_empty(),"immediate RED lethal does not waste a setup attack")
 expect(AI.settle_sim(e,0) and e.winner==0,"immediate RED still really wins")
 board();small=body(0,1,1,1);put(AI.RED,"hand");small.tapped=true
 expect(AI.red_setup_choice(e,0).is_empty(),"tapped small unit cannot prepare RED")
 small.tapped=false;small.entered_turns=e.players[0].turns
 expect(AI.red_setup_choice(e,0).is_empty(),"summoning sickness prevents RED preparation")
 board();small=body(0,1,1,1);e.cards[small.card_id].colors=["黄"];put(AI.RED,"hand")
 expect(AI.red_setup_choice(e,0).is_empty(),"nonred unit without lifesteal does not inflate RED")
 board(1,1);body(0,1,1,1);put(AI.RED,"hand")
 expect(AI.red_setup_choice(e,0).is_empty(),"unpayable RED does not justify sacrificing a small unit")
 board();body(0,1,1,1);put(AI.RED,"hand");put("spell-ucs-031","field",1)
 expect(AI.red_setup_choice(e,0).is_empty(),"attack tax cannot spend RED's remaining payment")
 for keyword in ["先制","防止伤害"]:
  board();body(0,1,1,1);put(AI.RED,"hand")
  var blocker=body(1,5,5,1);e.cards[blocker.card_id].keywords=[keyword]
  expect(AI.red_setup_choice(e,0).is_empty(),"no imagined healing through "+keyword)
 board();small=body(0,1,1,1);red=put(AI.RED,"hand")
 e.players[1].wards=[{"amount":1,"turn":-1}]
 expect(AI.red_setup_choice(e,0).is_empty(),"fully prevented player damage yields no lifesteal")
 e.players[1].wards=[]
 expect(AI.red_setup_choice(e,0).get("uid",-1)==small.uid,"player ward changes invalidate cached setup failure")
 board();small=body(0,1,1,1);put(AI.RED,"hand")
 rem=e.players[0].leader;e.players[0].field.erase(rem);rem.zone="grave";e.players[0].grave.append(rem)
 expect(AI.red_setup_choice(e,0).is_empty(),"absent Remilia cannot supply the lifesteal setup")

func reimu_coordination():
 for id in ["70","character-rei-001"]:
  board();var enemy=e.make_card(id,1,"field",true)
  enemy.entered_turns=0;enemy.base_override={"power":8,"health":6}
  e.players[1].leader=enemy;e.players[1].field.append(enemy);e.players[1].life=40
  var first=body(0,1,1,1);var second=body(0,1,1,1);var spare=body(0,1,1,1)
  var red=put(AI.RED,"hand")
  expect(AI.removal_target(e,0,red,[enemy]).is_empty(),"base RED cannot kill six-health Reimu: "+id)
  e.ai_step(0)
  expect(e.combat.get("attacker",{}).get("uid",-1)==first.uid and red.zone=="hand","Reimu opening prepares RED with the cheapest small unit: "+id)
  block_with(enemy)
  expect(enemy.damage==1 and AI.red_damage(e,0)==4 and first.zone=="grave","blocked small unit earns real life even when it dies: "+id)
  e.ai_step(0)
  expect(e.combat.get("attacker",{}).get("uid",-1)==second.uid and red.zone=="hand","still-short RED keeps gaining life instead of wasting damage: "+id)
  # Blocking taps Reimu; the next small attack goes through and earns the
  # second point of life without inventing another point of damage on Reimu.
  expect(AI.settle_sim(e,0) and enemy.damage==1 and AI.red_damage(e,0)==5,"unblocked second attack raises RED to remaining core health: "+id)
  e.ai_step(0)
  expect(played().get("card",{}).get("card_id","")==AI.RED and played().target.get("uid",-1)==enemy.uid and not spare.tapped,"at real kill threshold RED finishes core before another sacrifice: "+id)
  expect(AI.settle_sim(e,0) and enemy.zone!="field" and e.players[0].leader.zone=="field","boosted RED really removes Reimu and preserves our aura: "+id)
  board();enemy=e.make_card(id,1,"field",true);enemy.entered_turns=0
  e.players[1].leader=enemy;e.players[1].field.append(enemy);enemy.damage=e.stat(enemy,"health")-3
  red=put(AI.RED,"hand");put(AI.WINGS,"hand");e.players[1].life=40
  e.ai_step(0)
  expect(played().get("card",{}).get("card_id","")==AI.WINGS and red.zone=="hand","base RED removal of Reimu yields to development: "+id)
  board();enemy=e.make_card(id,1,"field",true);enemy.entered_turns=0
  e.players[1].leader=enemy;e.players[1].field.append(enemy);enemy.damage=e.stat(enemy,"health")-3
  body(0,1,1,1);red=put(AI.RED,"hand");e.players[1].life=3
  e.ai_step(0)
  expect(played().get("target",{}).get("player",-1)==1,"Reimu library does not steal RED from an immediate player lethal: "+id)
  expect(AI.settle_sim(e,0) and e.winner==0 and enemy.zone=="field","player lethal takes precedence over RED core removal: "+id)
