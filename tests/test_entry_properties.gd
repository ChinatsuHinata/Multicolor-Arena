extends "res://tests/support/rules_base.gd"

const Codec=preload("res://net/state_codec.gd")
const SeatView=preload("res://net/seat_projection.gd")

func name_choice(name: String):
 return e.pending.options.filter(func(t):return t.get("card_name","")==name)[0]

func run():
 fresh();mana()
 var item=put("164");var name=e.cards[item.card_id].name
 var momiji=put("character-fdf-101","hand")
 expect(e.commit_cast(0,momiji.uid,{},e.payment(0,e.cast_cost(0,momiji)).plan).is_empty(),"cast Momiji normally")
 expect(e.pending.is_empty() and e.stack.size()==1 and e.stack[0].kind=="card","Momiji itself can be responded to before resolving")
 one()
 expect(momiji.zone=="field" and e.pending.get("kind","")=="effect_choice","resolving Momiji asks for its intrinsic entry declaration")
 expect(e.stack.is_empty() and e.triggers.is_empty() and not e.pending.has("stack_id"),"entry declaration creates no ability on the stack")
 expect(e.pending.trigger.get("continuation",false) and e.pending.trigger.get("intrinsic_entry",false) and not e.pending.trigger.optional,"entry declaration is mandatory and resolves directly")
 var before=e.revision
 one();e.choose_effect({})
 expect(e.revision==before and not e.pending.is_empty(),"neither player can pass priority or skip the declaration")
 var own=SeatView.build(e,0);var enemy=SeatView.build(e,1)
 expect(own.state.pending.trigger.intrinsic_entry and enemy.state.pending.kind=="network_wait","network owner chooses while the opponent waits")
 e.choose_effect(name_choice(name))
 expect(momiji.get("locked_name","")==name and e.pending.is_empty() and e.stack.is_empty(),"declaration immediately locks the name without another resolution")
 expect(not e.source_resources(0).any(func(r):return r.uid==item.uid),"named activated resource is prohibited before priority returns")
 e.Roster.New.force_main_triggers(e,0);e.pump_choices()
 expect(e.stack.is_empty() and e.triggers.is_empty() and e.pending.is_empty() and momiji.locked_name==name,"forcing main triggers cannot repeat Momiji's intrinsic declaration")

 for lock in ["silent","night","instant"]:
  fresh()
  if lock=="night":e.players[0].night_lock=e.turn
  else:
   var blocker=put("spell-mar-004" if lock=="silent" else "spell-fdn-008","hand")
   e.detach(blocker);e.shift(blocker,"stack")
   e.stack.append({"id":e.next_stack,"kind":"card","card":blocker,"owner":1,"target":{"none":true},"name":e.cards[blocker.card_id].name});e.next_stack+=1
  momiji=enter("character-fdf-101")
  expect(e.pending.get("trigger",{}).get("intrinsic_entry",false),"trigger suppression cannot suppress entry declaration: "+lock)
  e.choose_effect(name_choice(name))
  expect(momiji.get("locked_name","")==name,"entry property resolves despite trigger suppression: "+lock)

 fresh()
 # A differently titled copy can legally enter in the same batch.
 e.cards["entry_test_momiji"]=e.cards["character-fdf-101"].duplicate(true)
 e.cards["entry_test_momiji"].title="";e.cards["entry_test_momiji"].name="进场选择测试复制品"
 var first_momiji=put("character-fdf-101","hand");var second_momiji=put("entry_test_momiji","hand")
 e.Roster.field_many(e,[first_momiji,second_momiji],0);e.pump_choices()
 expect(e.pending.trigger.source.uid==first_momiji.uid and e.entry_choices.size()==1,"simultaneous entries retain both mandatory declarations")
 var graph=Codec.capture(e);e=Duel.new();Codec.restore(e,graph)
 e.choose_effect(name_choice(name))
 expect(e.find_card(first_momiji.uid).locked_name==name and e.pending.trigger.source.uid==second_momiji.uid,"saved entry queue resumes the second declaration after the first")
 var other_name=e.cards["167"].name
 e.choose_effect(name_choice(other_name))
 expect(e.find_card(second_momiji.uid).locked_name==other_name and e.pending.is_empty() and e.entry_choices.is_empty() and e.stack.is_empty(),"both entry declarations complete without creating triggers")

 fresh();put("113")
 momiji=enter("character-fdf-101")
 expect(e.pending.trigger.get("intrinsic_entry",false) and e.triggers.size()==1 and e.stack.is_empty(),"intrinsic declaration precedes ordinary observers' entry triggers")
 e.choose_effect(name_choice(name))
 expect(momiji.locked_name==name and e.stack.size()==1 and e.stack[0].effect=="activity_draw","ordinary entry trigger enters the stack after the declaration")

 fresh()
 byakuren_observer_test()

 fresh()
 var byakuren=e.make_card("character-fdf-ex03",0,"stack");byakuren.cast_x=3
 e.enter_field(byakuren,0)
 expect(byakuren.plus_counters==3 and e.stat(byakuren,"health")==5,"Byakuren has X counters immediately on entry")
 expect(e.triggers.size()==1 and e.triggers[0].effect=="byakuren_x" and not e.triggers[0].ability_text.contains("于该单位"),"only Byakuren's separate life gain is a triggered ability")
 e.pump_choices()
 expect(e.players[0].life==20 and e.stack.size()==1 and e.stack[0].kind=="ability","life gain waits on the stack while counters are already present")
 one();expect(e.players[0].life==23 and byakuren.plus_counters==3,"Byakuren gains life only when its normal trigger resolves")
 e.Roster.New.force_main_triggers(e,0);e.pump_choices();one()
 expect(e.players[0].life==26 and byakuren.plus_counters==3,"forcing Byakuren's trigger repeats life gain without adding entry counters")

 fresh();e.players[0].night_lock=e.turn
 byakuren=e.make_card("character-fdf-ex03",0,"stack");byakuren.cast_x=2;e.enter_field(byakuren,0);e.pump_choices()
 expect(byakuren.plus_counters==2 and e.stack.is_empty() and e.players[0].life==20,"trigger suppression affects Byakuren's life gain but not its entry counters")
 fresh()
 put("165","palette");var tapped=put("167","palette");tapped.tapped=true
 var suika=enter("new-spx-001")
 expect(suika.plus_counters==2 and e.stack.is_empty() and e.triggers.is_empty(),"Suika enters with untapped palette count plus one counters without a trigger")
 e.Roster.New.force_main_triggers(e,0);e.pump_choices()
 expect(suika.plus_counters==2 and e.stack.is_empty() and e.pending.is_empty(),"forcing main triggers cannot repeat Suika's entry counters")
 print("ENTRY_PROPERTIES: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func byakuren_observer_test():
 var c=e.make_card("character-fdf-ex03",0,"stack");c.cast_x=3;c.top_free_damage=true
 e.enter_field(c,0)
 var damage_trigger=e.triggers.filter(func(t):return t.effect=="cat:top_free_damage")[0]
 expect(damage_trigger.source.plus_counters==3,"entry observers capture Byakuren after intrinsic counters apply")
