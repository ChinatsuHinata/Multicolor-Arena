extends "res://tests/support/rules_base.gd"

const Codec=preload("res://net/state_codec.gd")

func swarm(who: int=0) -> Dictionary:
 var source=e.make_card("character-fdf-104",who,"grave")
 e.Cat.Units.resolve(e,{"owner":who,"source":source,"effect":"character-fdf-104","target":{"none":true}})
 var made=e.units(who).filter(func(c):return e.cards[c.card_id].name=="虫群")
 return made.back() if not made.is_empty() else {}

func contains_uid(options: Array,uid: int) -> bool:
 return options.any(func(r):return r.get("uid",-1)==uid)

func run():
 entry_observers()
 auras_and_protection()
 race_choices()
 capacity_and_restore()
 print("WRIGGLE_SWARM: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func entry_observers():
 fresh()
 put("character-fdf-104");var shinmy=put("character-smm01");shinmy.leader=true
 e.phase="end";e.Roster.on_phase(e,"end");e.pump_choices();one()
 expect(e.pending.get("trigger",{}).get("effect","")=="shinmy_counter","Wriggle's real end-step trigger creates a swarm with the kobito entry effect")
 fresh()
 shinmy=put("character-smm01");shinmy.leader=true
 var bug=swarm()
 e.pump_choices()
 expect(e.pending.get("trigger",{}).get("effect","")=="shinmy_counter","swarm entry offers Shinmyoumaru's kobito trigger")
 if e.pending.get("kind","")=="effect_choice":
  e.choose_effect(e.ref_target(bug));one()
 expect(bug.get("plus_counters",0)==1 and e.stat(bug,"health")==2,"Shinmyoumaru's actual trigger puts a counter on the swarm")
 expect(not e.triggers.any(func(t):return t.effect=="shinmy_cast") and not e.stack.any(func(t):return t.get("effect","")=="shinmy_cast"),"creating a swarm is not casting a unit")
 fresh()
 shinmy=put("character-smm01","field",1);shinmy.leader=true
 swarm()
 expect(e.triggers.is_empty(),"opponent's Shinmyoumaru does not observe your swarm")

 fresh()
 put("spell-lof-006");put("character-fdn-006","palette")
 bug=swarm();e.pump_choices();one()
 expect(e.stat(bug,"power")==2 and e.stat(bug,"spirit")==2 and e.has_haste(bug),"fairy ensemble grants its actual first-fairy entry bonus to the swarm")
 var second=swarm()
 expect(e.players[0].get("fairy_enter_turn",-1)==e.turn and e.triggers.is_empty() and e.stat(second,"power")==1,"the swarm consumes the first-fairy entry for the turn")

 fresh()
 var gun=e.make_card("new-spx-004",0,"stack")
 e.Roster.New.spell_resolve(e,{"owner":0,"card":gun,"target":{"none":true}})
 var enemy=put("70","field",1)
 bug=swarm();e.pump_choices()
 expect(e.pending.get("trigger",{}).get("effect","")=="n21:frog_fire","Red Frog observes swarm entry as a frog")
 if e.pending.get("kind","")=="effect_choice":
  e.choose_effect(e.ref_target(enemy));one()
 expect(enemy.damage==1,"Red Frog's actual entry trigger deals the swarm's attack damage")

func auras_and_protection():
 fresh()
 var forest=put("character-fdn-013")
 put("80");var news=put("token-fdn-082");news.news_health=true
 var france=put("character-ucs-048");put("77")
 var before=e.stat(forest,"power")
 var dolls_before=e.stat(france,"power")
 var bug=swarm()
 expect(e.stat(forest,"power")==before+1,"forest fairy counts the swarm as a fairy")
 expect(e.stat(bug,"power")==2 and e.stat(bug,"health")==2 and e.stat(bug,"spirit")==3,"Cirno and news material grant their fairy and tengu bonuses to the swarm")
 expect(e.stat(france,"power")==dolls_before+1,"French doll counts the swarm as a doll")
 put("spell-ucs-033")
 expect(e.Extra.keyword(e,bug,"追击"),"god pursuit applies to the swarm")
 e.players[0].dolls_indestructible=e.turn
 expect(e.Extra.keyword(e,bug,"不会被消灭"),"doll protection applies to the swarm")
 e.players[0].dolls_free=true
 expect(e.Extra.keyword(e,bug,"不占战场格"),"doll slot exemption applies to the swarm")

 fresh()
 var attacker=put("70","field",1);attacker.extra_keywords=["退治"]
 bug=swarm()
 expect(bug in e.blockers_for(attacker,0),"the swarm's human race allows it to block extermination")
 expect(not contains_uid(e.Cat.Spells.options(e,"spell-fdf-066",0),bug.uid),"anti-human/god removal excludes the swarm")
 var luna=put("2");var life=e.players[0].life
 e.Roster.resolve_trigger(e,{"owner":0,"source":luna,"effect":"luna_life","target":{"none":true}})
 expect(e.players[0].life==life+2,"Luna's fairy life gain counts herself and the swarm")

func race_choices():
 fresh()
 var bug=swarm()
 expect(contains_uid(e.Cat.Spells.options(e,"spell-fdn-008",0),bug.uid),"vampire targeting includes the swarm")
 put("7");put("8")
 for id in ["spell-fdn-039","spell-ucs-057","spell-fdf-025","spell-fdn-046"]:
  var options=e.Cat.Spells.options(e,id,0)
  expect(not options.is_empty() and contains_uid(options[0].selection[0].pool,bug.uid),"race-filtered spell choice includes the swarm: "+id)
 for id in ["item-lof-009","spell-fdf-059"]:
  var source=put(id);var options=e.Cat.activation_options(e,source,id)
  expect(not options.is_empty() and contains_uid(options[0].selection[0].pool,bug.uid),"fairy/kobito sacrifice choice includes the swarm: "+id)
 var tengu=put("character-fdn-036");tengu.leader=true
 expect(contains_uid(e.Cat.activation_options(e,tengu,"character-fdn-036:self"),bug.uid),"tengu return choice includes the swarm")
 var larva=put("character-lof-017")
 expect(contains_uid(e.Roster.Batch.trigger_options(e,{"owner":0,"source":larva,"effect":"larva_sacrifice"}),bug.uid),"Larva's fairy sacrifice trigger includes the swarm")
 var youmu=put("character-fdf-102");put("spell-fdf-050","hand")
 var ghosts=e.Cat.activation_options(e,youmu,"character-fdf-102")
 expect(contains_uid(ghosts[0].selection[1].pool,bug.uid),"ghost/half-phantom reset choice includes the swarm")

 fresh()
 bug=swarm();var frog=put("new-spx-003")
 var hostile=e.make_card("spell-fdf-032",1,"stack")
 e.stack.append({"id":e.next_stack,"kind":"card","owner":1,"card":hostile,"target":e.ref_target(bug)});e.next_stack+=1
 var options=e.Roster.New.activation_options(e,frog,"n21:frog_counter")
 expect(not options.is_empty() and contains_uid(options[0].selection[0].pool,bug.uid) and not options[0].selection[1].pool.is_empty(),"frog sacrifice can counter an effect targeting the swarm as a god")

 fresh()
 bug=swarm()
 # Unlike tokens, an ordinary all-race unit can remain in the graveyard.
 e.cards["swarm_race_unit"]=e.cards[bug.card_id].duplicate(true);e.cards["swarm_race_unit"].token=false
 var copy=put("swarm_race_unit","grave")
 var anthem=put("spell-fdf-ex05")
 options=e.Pack.trigger_options(e,{"owner":0,"source":anthem,"effect":"scarlet_anthem"})
 expect(contains_uid(options,copy.uid),"Scarlet Anthem accepts an all-race unit as human/vampire")

func capacity_and_restore():
 fresh()
 e.players[0].leader=e.make_card("character-fdn-007",0,"leader",true)
 for i in range(6):put("70")
 var bug=swarm()
 expect(not bug.is_empty() and e.units(0).size()==7 and e.field_slots(0)==6,"fairy habitat recognizes swarm race before checking a full battlefield")
 if bug.is_empty():return
 var copied=e.Cat.copy_token(e,0,bug)
 var idol=e.Roster.copy_idol(e,0,bug)
 expect(not copied.is_empty() and not idol.is_empty(),"swarm copies retain the fairy slot exemption before entry")
 var graph=Codec.capture(e);e=Duel.new();Codec.restore(e,graph)
 for uid in [bug.uid,copied.get("uid",-1),idol.get("uid",-1)]:
  var restored=e.find_card(uid)
  expect(not restored.is_empty() and e.Cat.race(e,restored,"小人") and e.Cat.race(e,restored,"青蛙") and e.Extra.keyword(e,restored,"不占战场格"),"save/network restoration preserves swarm races and effects: "+str(uid))
