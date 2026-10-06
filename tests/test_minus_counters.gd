extends "res://tests/support/rules_base.gd"

const Codec=preload("res://net/state_codec.gd")

func counter_choice(spec: Dictionary,stack_id: int,counters: Array) -> Dictionary:
 var choice=spec.duplicate(true);choice.erase("selection");choice.picks=[[{"stack_id":stack_id}]]
 for counter in counters:choice.picks.append([counter])
 return choice

func response_fixture(green: int=0) -> Dictionary:
 fresh();put("character-fdf-ex03")
 var victim=put("character-fdf-106")
 var momoyo=put("43","field",1)
 e.combat_hit(momoyo,e.ref_target(victim),3)
 put("164","palette")
 for i in range(green):put("166","palette")
 put("68","field",1)
 for i in range(3):put("164","palette",1)
 e.active=1;e.priority=1
 var spark=put("99","hand",1)
 var error=e.commit_cast(1,spark.uid,{"player":0},e.payment(1,e.cast_cost(1,spark)).plan)
 expect(error.is_empty(),"opponent actually casts the three-cost nonunit spell: "+error)
 return {"victim":victim,"spark":spark,"counterspell":put("spell-fdf-053","hand"),"stack_id":e.stack.back().id}

func payment_spec(c: Dictionary,n: int) -> Dictionary:
 var options=e.targets_for(c.card_id,0,c.uid).filter(func(spec):return spec.x==3 and spec.counter_payment==n)
 expect(not options.is_empty(),"Byakuren offers X=3 with %d counters removed" % n)
 return {} if options.is_empty() else options[0]

func run():
 basic_counters()
 copy_interaction()
 counter_effects()
 byakuren_payment()
 invalid_payments()
 print("MINUS_COUNTERS: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func basic_counters():
 fresh()
 var victim=put("character-fdf-106");var momoyo=put("43","field",1)
 e.combat_hit(momoyo,e.ref_target(victim),2)
 expect(victim.get("minus_counters",0)==2 and victim.damage==0,"Momoyo deals unit damage as real -1/-1 counters")
 expect(e.stat(victim,"power")==3 and e.stat(victim,"health")==3 and e.stat(victim,"spirit")==4,"negative counters lower power and health without lowering spirit")
 var refs=e.Cat.counter_refs(e,[victim])
 expect(refs.size()==2 and refs.all(func(r):return r.counter=="minus_counters"),"generic counter enumeration includes each negative counter")
 expect(refs[0].counter_index==0 and refs[1].counter_index==1,"negative counters have distinct selectable identities")
 e.phase="end";e.cleanup_end()
 expect(victim.zone=="field" and victim.get("minus_counters",0)==2,"negative counters persist across turn cleanup")
 e.move_to(victim,"hand")
 expect(victim.get("minus_counters",0)==0,"negative counters disappear on a zone change")
 e.enter_field(victim,0)
 expect(e.stat(victim,"power")==5 and e.stat(victim,"health")==5,"returning unit has its original stats")
 fresh();victim=put("53")
 e.Roster.Batch.counter(e,victim,"minus_counters",2,1);e.judge()
 expect(victim.zone=="grave","zero health from negative counters causes death")

func copy_interaction():
 fresh()
 var source=put("53");source.plus_counters=2
 e.Roster.Batch.counter(e,source,"minus_counters",1,1)
 source.damage=1;e.apply_turn_buff(e.ref_target(source),{"攻击力":3})
 var keiki=enter("45")
 expect(e.pending.get("kind","")=="effect_choice" and e.pending.trigger.effect=="keiki_copy","Keiki's actual entry ability asks for a copy target")
 e.choose_effect(e.ref_target(source));one()
 var copies=e.units(0).filter(func(c):return c.get("token",false) and e.cards[c.card_id].get("copy_marker","")=="keiki")
 expect(copies.size()==1,"Keiki creates one Idol copy")
 if copies.is_empty():return
 var idol=copies[0]
 expect(e.cards[idol.card_id].name=="偶像" and e.cards[idol.card_id].race==e.cards[source.card_id].race,"Keiki changes the copy's name while retaining the source races")
 expect(idol.get("minus_counters",0)==1 and idol.plus_counters==2,"Keiki copies both negative and positive counters")
 expect(idol.damage==0 and idol.modifiers.is_empty(),"ordinary unit copying carries neither damage nor temporary buffs")
 expect(e.stat(idol,"power")==3 and e.stat(idol,"health")==3 and e.stat(idol,"spirit")==3,"Idol applies its copied counters to the printed stats")
 expect(source.get("minus_counters",0)==1 and source.plus_counters==2,"copying leaves the source's counters intact")
 e.Roster.Batch.counter(e,idol,"minus_counters",1,1)
 expect(idol.get("minus_counters",0)==2 and e.stat(idol,"health")==2,"the created copy can itself receive more normal negative counters")

func counter_effects():
 fresh();mana()
 var victim=put("character-fdf-106")
 e.Roster.Batch.counter(e,victim,"minus_counters",1,1)
 var target=e.ref_target(victim);target.mode="指示物翻倍"
 cast("spell-lof-025",target)
 expect(victim.get("minus_counters",0)==2 and e.stat(victim,"health")==3,"Heavenly Peach doubles negative counters of the same type")
 fresh();put("character-lof-003");victim=put("character-fdf-106")
 e.Roster.Batch.counter(e,victim,"minus_counters",1,0)
 expect(victim.get("minus_counters",0)==2,"Sanae also adds one when you place negative counters on your own unit")
 e.Roster.Batch.counter(e,victim,"minus_counters",1,1)
 expect(victim.get("minus_counters",0)==3,"Sanae does not add counters placed by the opponent")
 fresh();put("spell-fdf-044")
 victim=put("53");e.Roster.Batch.counter(e,victim,"minus_counters",1,1)
 var attacker=put("53","field",1)
 expect(e.can_attack(0,victim.uid) and victim in e.blockers_for(attacker,0),"a negative counter satisfies Holy Pulse's attack and block requirement")
 e.Cat.remove_counters(e,e.Cat.counter_refs(e,[victim]))
 expect(not e.can_attack(0,victim.uid) and victim not in e.blockers_for(attacker,0),"removing the last negative counter removes that combat permission")

func byakuren_payment():
 for n in [3,1,0]:
  var f=response_fixture(3-n);var victim=f.victim;var spell=f.counterspell
  var spec=payment_spec(spell,n)
  if spec.is_empty():continue
  var refs=e.Cat.counter_refs(e,[victim]).slice(0,n)
  var choice=counter_choice(spec,f.stack_id,refs)
  var cost=e.cast_cost(0,spell,choice)
  expect(int(cost.get("黄",0))==1 and int(cost.get("绿",0))==3-n,"each removed negative counter pays exactly one green, n="+str(n))
  var plan=e.payment(0,cost)
  expect(plan.ways>0 and plan.plan.size()==4-n,"negative-counter payment needs only the remaining colored resources, n="+str(n))
  var error=e.commit_cast(0,spell.uid,choice,plan.plan)
  expect(error.is_empty(),"actual X counterspell accepts negative counters, n="+str(n)+": "+error)
  expect(victim.get("minus_counters",0)==3-n and e.stat(victim,"health")==2+n,"payment immediately removes counters and restores health, n="+str(n))
  expect(e.stack.size()==2 and f.spark.zone=="stack","counterspell can be responded to after its counters are paid")
  if n==3:
   var graph=Codec.capture(e);e=Duel.new();Codec.restore(e,graph)
   victim=e.find_card(victim.uid);spell=e.find_card(spell.uid)
   expect(victim.get("minus_counters",0)==0 and e.stack.back().target.counter_payment==3,"state roundtrip preserves paid negative counters and declared X")
  one()
  expect(e.find_card(f.spark.uid).zone=="grave" and spell.zone=="grave" and e.stack.is_empty(),"Byakuren resolves and counters the real spell, n="+str(n))
  expect(e.players[0].life==20,"the countered spell deals no player damage")
 var f=response_fixture();var victim=f.victim;var spell=f.counterspell
 victim.minus_counters=1
 e.Roster.Batch.counter(e,victim,"courage",1,0);e.Roster.Batch.color_counter(e,victim,"绿",0)
 var choice=counter_choice(payment_spec(spell,3),f.stack_id,e.Cat.counter_refs(e,[victim]))
 expect(e.commit_cast(0,spell.uid,choice,e.payment(0,e.cast_cost(0,spell,choice)).plan).is_empty(),"negative counters can be mixed with other counter types in one payment")
 expect(e.Cat.counter_total(e,[victim])==0 and e.stat(victim,"health")==5,"mixed payment removes every chosen counter exactly once")
 one();expect(e.find_card(f.spark.uid).zone=="grave","mixed-counter payment resolves the counterspell")
 f=response_fixture()
 var donor=put("53");donor.plus_counters=4;donor.minus_counters=3
 var idol=e.Roster.copy_idol(e,0,donor);spell=f.counterspell
 var copied_negatives=e.Cat.counter_refs(e,[idol]).filter(func(r):return r.counter=="minus_counters")
 choice=counter_choice(payment_spec(spell,3),f.stack_id,copied_negatives)
 expect(e.commit_cast(0,spell.uid,choice,e.payment(0,e.cast_cost(0,spell,choice)).plan).is_empty(),"Byakuren can pay with negative counters copied by Keiki")
 expect(idol.minus_counters==0 and donor.minus_counters==3 and idol.plus_counters==4,"paying copied negative counters changes only the copy's chosen counters")
 one();expect(e.find_card(f.spark.uid).zone=="grave","Keiki's copied negative counters successfully fund the counterspell")

func invalid_payments():
 for invalid in ["duplicate","opponent","removed","zone_changed","wrong_x","unit_target"]:
  var f=response_fixture();var victim=f.victim;var spell=f.counterspell
  var refs=e.Cat.counter_refs(e,[victim]);var choice=counter_choice(payment_spec(spell,3),f.stack_id,refs)
  match invalid:
   "duplicate":choice.picks[2]=choice.picks[1].duplicate(true)
   "opponent":
    var enemy=put("character-fdf-106","field",1)
    e.Roster.Batch.counter(e,enemy,"minus_counters",1,0)
    choice.picks[1]=[e.Cat.counter_refs(e,[enemy])[0]]
   "removed":victim.minus_counters=2
   "zone_changed":e.move_to(victim,"hand");e.enter_field(victim,0)
   "wrong_x":choice.x=2
   "unit_target":
    var enemy=put("53","hand",1);e.detach(enemy);e.shift(enemy,"stack")
    e.stack[0].card=enemy
  var before=victim.get("minus_counters",0);var yellow=e.players[0].palette[0]
  expect(not e.commit_cast(0,spell.uid,choice,e.payment(0,{"黄":1}).plan).is_empty(),"counter payment rejects invalid selection: "+invalid)
  expect(spell.zone=="hand" and victim.get("minus_counters",0)==before and not yellow.tapped,"rejected payment leaves counters, card and mana unchanged: "+invalid)
