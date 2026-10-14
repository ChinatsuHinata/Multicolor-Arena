extends "res://tests/support/rules_base.gd"

const Codec=preload("res://net/state_codec.gd")

func swarm(who: int=0) -> Dictionary:
 var source=e.make_card("character-fdf-104",who,"grave")
 e.Cat.Units.resolve(e,{"owner":who,"source":source,"effect":"character-fdf-104","target":{"none":true}})
 return e.units(who).filter(func(c):return e.cards[c.card_id].name=="虫群").back()

func named_impostor() -> Dictionary:
 var c=e.Cat.token(e,0,"人偶",1,1,1,["黄"])
 e.cards[c.card_id].name="御柱";e.cards[c.card_id].character="御柱"
 return c

func blast_choice(cost: Dictionary,target: Dictionary) -> Dictionary:
 return {"selection_id":"kanako_blast","picks":[[e.Pack.ref(e,cost)],[e.ref_target(target)]]}

func run():
 kanako_sacrifice()
 kanako_damage()
 divine_radiance()
 print("PILLAR_EFFECTS: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func kanako_sacrifice():
 fresh()
 var kanako=put("82");kanako.leader_counters=1
 var bug=swarm();var pillar=e.Roster.create_token(e,0,"pillar",2,["绿"])
 var idol=e.Roster.copy_idol(e,0,pillar);var impostor=named_impostor()
 var enemy=swarm(1);var victim=put("50","field",1)
 var options=e.activation_options(kanako,"kanako_blast")
 for cost in [bug,pillar,idol]:
  expect(e.Pack.choice_valid(e,options,blast_choice(cost,victim)),"Kanako accepts the pillar race regardless of name: "+e.cards[cost.card_id].name)
 for cost in [impostor,enemy]:
  var legal=e.Pack.choice_valid(e,options,blast_choice(cost,victim))
  expect(not legal,"Kanako excludes a named non-pillar or an opponent's swarm from its costs")
  if legal:continue
  var error=e.commit_extension(0,kanako.uid,blast_choice(cost,victim),[],"kanako_blast")
  expect(not error.is_empty() and cost.zone=="field" and e.stack.is_empty(),"Kanako rejects a named non-pillar or an opponent's swarm")
 var error=e.commit_extension(0,kanako.uid,blast_choice(bug,victim),[],"kanako_blast")
 expect(error.is_empty(),"Kanako can activate by sacrificing Wriggle's swarm: "+error)
 if not error.is_empty():return
 expect(bug.zone=="void" and victim.damage==0 and e.stack.size()==1,"the swarm is sacrificed before the opponent can respond to Kanako")
 one()
 expect(victim.damage==2 and e.stack.is_empty(),"Kanako's swarm-paid ability deals two damage to an undamaged unit")
 e.priority=0
 error=e.commit_extension(0,kanako.uid,blast_choice(idol,enemy),[],"kanako_blast")
 expect(error.is_empty() and idol.zone=="void","a copied pillar can also pay Kanako's sacrifice cost: "+error)
 if error.is_empty():
  one()
  expect(enemy.zone=="void","the copied-pillar ability resolves after its cost leaves the field")

func kanako_damage():
 fresh()
 var kanako=put("82");kanako.leader_counters=1
 var bug=swarm();var victim=put("50","field",1);victim.damage=1
 var error=e.commit_extension(0,kanako.uid,blast_choice(bug,victim),[],"kanako_blast")
 expect(error.is_empty(),"Kanako still permits targeting an injured unit with a swarm: "+error)
 if error.is_empty():
  one()
  expect(victim.damage==1,"Kanako's ability deals no damage when its target is already injured")

func divine_radiance():
 fresh()
 put("82");mana()
 var bug=swarm();bug.entered_turns=0
 var pillar=e.Roster.create_token(e,0,"pillar",2,["绿"])
 var idol=e.Roster.copy_idol(e,0,pillar);var impostor=named_impostor();var enemy=swarm(1)
 expect(not e.Extra.keyword(e,bug,"追击"),"the swarm has no pursuit before Divine Radiance resolves")
 var aura=cast("spell-ucs-033")
 expect(aura.zone=="field","Divine Radiance resolves as a battlefield melody")
 for c in [bug,pillar,idol]:
  expect(e.Extra.keyword(e,c,"追击"),"Divine Radiance grants pursuit by god or pillar race: "+e.cards[c.card_id].name)
 expect(not e.Extra.keyword(e,impostor,"追击") and not e.Extra.keyword(e,enemy,"追击"),"Divine Radiance excludes a named non-pillar and the opponent's swarm")
 var life=e.players[1].life
 e.attack(0,bug.uid);one();e.block([]);one()
 expect(e.players[1].life==life-1 and e.stack.any(func(t):return t.get("effect","")=="chase"),"the swarm's real combat damage triggers its granted pursuit")
 settle()
 expect(not bug.tapped and e.usage_count(bug.uid,"chase")==1,"the swarm's pursuit resolves and readies it for another attack")
 var graph=Codec.capture(e);e=Duel.new();Codec.restore(e,graph)
 bug=e.find_card(bug.uid);idol=e.find_card(idol.uid);aura=e.find_card(aura.uid)
 expect(e.Extra.keyword(e,bug,"追击") and e.Extra.keyword(e,idol,"追击"),"save/network restoration preserves pursuit for the swarm and copied pillar")
 e.move_to(aura,"grave")
 expect(not e.Extra.keyword(e,bug,"追击") and not e.Extra.keyword(e,idol,"追击"),"granted pursuit ends when Divine Radiance leaves the battlefield")
