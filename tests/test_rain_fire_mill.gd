extends "res://tests/support/catalogue_rules_base.gd"

func fire(who: int=0):
 mana()
 if who==1:
  for id in ["167","168"]:
   for i in range(3):put(id,"palette",1)
 e.priority=who
 var spell=put("152","hand",who)
 var error=e.commit_cast(who,spell.uid,{"none":true},e.payment(who,e.cast_cost(who,spell)).plan)
 expect(error.is_empty(),"Fire commits for player "+str(who)+": "+error)
 one()
 expect(e.pending.get("kind","")=="effect_choice" and e.pending.trigger.effect=="scry_grave","Fire waits for top-card grave selection")
 return spell

func rain_choices(target: Dictionary,amount: int,count: int=1):
 var resolved=0
 for i in range(20):
  if e.pending.get("kind","")=="trigger_order":e.choose_trigger_order(0)
  elif e.pending.get("kind","")=="effect_choice":
   expect(e.pending.trigger.effect=="spell-fdf-123" and e.pending.trigger.data.amount==amount,"Rain trigger retains the complete mill count")
   e.choose_effect(selected(e.pending.options,[[target]]))
  elif not e.stack.is_empty():one();resolved+=1
  else:break
 expect(resolved==count,"Rain resolves once per batch and observer: "+str(resolved))

func run():
 for who in range(2):
  for picks in [[],[0],[1],[1,0]]:
   fresh()
   var rain=put("spell-fdf-123");rain.timer=3
   var unit=put("50","field",1)
   var top=e.players[who].deck.slice(0,3)
   var spell=fire(who)
   var refs=picks.map(func(i):return e.Pack.ref(e,top[i]))
   e.choose_effect(selected(e.pending.options,[refs]))
   if picks.is_empty():
    expect(e.pending.trigger.effect=="scry_order" and e.triggers.is_empty(),"Keeping both cards waits for ordering without triggering Rain")
    e.choose_effect(selected(e.pending.options,[[e.Pack.ref(e,top[1]),e.Pack.ref(e,top[0])]]))
    expect(top[1].zone=="hand" and e.players[who].deck[0].uid==top[0].uid,"Fire draws the chosen first card and leaves the second on top")
   else:
    var drawn=top[2] if picks.size()==2 else top[1] if picks[0]==0 else top[0]
    expect(drawn.zone=="hand" and e.players[who].hand.size()==1,"Fire draws only after the selected top cards move to grave")
    for index in picks:expect(top[index].zone=="grave","Selected top card reaches grave: "+str(index))
    rain_choices(e.Pack.ref(e,unit),picks.size())
   expect(unit.get("scare",0)==picks.size(),"Rain places exactly one scare counter per card sent to grave")
   expect(spell.zone=="grave" and e.pending.is_empty() and e.stack.is_empty(),"Fire and Rain finish their complete resolution")

 fresh()
 var rain=put("spell-fdf-123");rain.timer=3
 e.Cat.mill(e,1,2);e.Cat.mill(e,1,1)
 expect(e.triggers.size()==2 and e.triggers[0].data.amount==2 and e.triggers[1].data.amount==1,"Separate mill instructions produce separate Rain triggers")

 fresh();rain=put("spell-fdf-123");rain.timer=3
 put("character-fdf-041")
 var unit=put("50","field",1)
 var top=e.players[0].deck.slice(0,2)
 fire();e.choose_effect(selected(e.pending.options,[[e.Pack.ref(e,top[1])]]))
 rain_choices(e.Pack.ref(e,unit),1,2)
 expect(unit.get("scare",0)==2,"Sakuya duplicates the full Rain trigger for Fire's second card")

 fresh();rain=put("spell-fdf-123");rain.timer=3
 var replaced=put("new-loc-002","deck");e.Roster.to_top(e,replaced)
 e.Cat.mill(e,0,1)
 expect(replaced.zone=="exile" and e.triggers.is_empty(),"A grave-to-exile replacement does not count as a milled card")

 fresh();rain=put("spell-fdf-123");rain.timer=3
 var satori=put("76");unit=put("50","field",1)
 top=e.players[1].deck.slice(0,3)
 roster_trigger(satori,"satori_scry",{"player":1})
 e.choose_effect(selected(e.pending.options,[[e.Pack.ref(e,top[2])]]))
 expect(e.pending.trigger.effect=="scry_order" and e.triggers.size()==1,"Rain waits for Satori to finish ordering the remaining top cards")
 e.choose_effect(selected(e.pending.options,[[e.Pack.ref(e,top[1]),e.Pack.ref(e,top[0])]]))
 rain_choices(e.Pack.ref(e,unit),1)
 expect(e.players[1].deck[0].uid==top[1].uid and e.players[1].hand.is_empty() and unit.get("scare",0)==1,"Satori mills the third inspected card, reorders without drawing, and triggers Rain")

 fresh();rain=put("spell-fdf-123");rain.timer=3
 unit=put("50","field",1)
 e.players[0].deck=e.players[0].deck.slice(0,1)
 top=e.players[0].deck.duplicate()
 fire();e.choose_effect(selected(e.pending.options,[[]]))
 expect(top[0].zone=="hand" and e.triggers.is_empty() and e.pending.is_empty(),"Fire with a one-card library keeps and draws its only card")

 fresh();rain=put("spell-fdf-123");rain.timer=3
 unit=put("50","field",1)
 var first=e.players[0].deck[0]
 var buried=put("152","deck");e.players[0].deck.erase(buried);e.players[0].deck.insert(1,buried)
 resolve_spell("spell-fdf-015",e.ref_target(unit))
 e.choose_effect(selected(e.pending.options,[[e.Pack.ref(e,buried)]]))
 expect(buried.zone=="grave" and e.pending.trigger.effect=="spell-fdf-123" and e.pending.trigger.data.amount==1,"Choosing a later spell among the top five also triggers Rain")
 rain_choices(e.Pack.ref(e,unit),1)
 expect(unit.get("scare",0)==1 and first.zone=="deck","Top-five grave selection keeps the unchosen cards in the library")

 print("RAIN_FIRE_MILL: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
