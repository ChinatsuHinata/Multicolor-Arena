extends "res://tests/support/rules_base.gd"
const ELEMENTS=["spell-fdf-075","spell-fdf-076","spell-fdf-077","spell-fdf-078","spell-fdf-079"]

func setup(who: int):
 fresh();e.active=who;e.priority=who
 for p in e.players:p.deck=[]

func acknowledge(who: int):
 if e.pending.get("kind","")=="reveal_review":e.confirm_revealed(1-who,e.pending.serial)

func door(who: int):
 setup(who)
 var shown=[]
 for id in ELEMENTS:shown.append(put(id,"deck",who))
 put("70","deck",who)
 var card=e.make_card("149",who,"stack")
 e.stack.append({"id":e.next_stack,"kind":"card","card":card,"owner":who,"target":{"none":true},"name":e.cards[card.card_id].name});e.next_stack+=1
 one();acknowledge(who)
 expect(e.pending.get("kind","")=="trigger_order" and e.pending.options.size()==5,"door offers all five revealed element abilities, seat "+str(who))
 if e.pending.get("kind","")!="trigger_order":return
 e.choose_trigger_order([0,1,2,3,4])
 for i in range(5):
  expect(e.pending.get("trigger",{}).get("effect","")=="cat:element_reveal","door announces element ability "+str(i))
  if e.pending.get("trigger",{}).get("effect","")!="cat:element_reveal":return
  e.choose_effect({"none":true})
 expect(e.stack.size()==5,"all five optional abilities are available for the stack")
 for i in range(5):
  one()
  if e.pending.get("trigger",{}).get("effect","")=="cat:grant":e.choose_effect({})
 expect(shown.all(func(c):return c.zone=="exile"),"every chosen element is exiled after door resolution")

func top_effect(who: int,kind: String,id: String,source_id: String):
 setup(who)
 var element=put(id,"deck",who);put("164","deck",who);put("165","deck",who);put("166","deck",who)
 var source=put(source_id,"field",who)
 if kind=="patch_topthree":e.Pack.event(e,source,kind,false)
 else:e.Roster.event(e,source,kind,false)
 e.pump_choices();one()
 if e.pending.get("kind","")=="effect_choice":
  var spec=e.pending.options[0]
  if spec.has("selection"):e.choose_effect({"selection_id":spec.get("selection_id",""),"picks":[[]]})
 acknowledge(who)
 expect(e.pending.get("trigger",{}).get("effect","")=="cat:element_reveal",kind+" announces the revealed top card")
 if e.pending.get("trigger",{}).get("effect","")=="cat:element_reveal":
  e.choose_effect({"none":true});one()
  expect(element.zone=="exile",kind+" allows exiling the revealed element")
  if e.pending.get("trigger",{}).get("effect","")=="cat:grant":e.choose_effect({})

func patch_hand(who: int,id: String):
 setup(who)
 var element=put(id,"deck",who);put("164","deck",who);put("165","deck",who)
 var source=put("character-mar-ex01","field",who)
 e.Pack.event(e,source,"patch_topthree",false);e.pump_choices();one()
 expect(e.pending.get("kind","")=="effect_choice","small Patchouli offers its revealed-card selection")
 if e.pending.get("kind","")!="effect_choice":return
 var spec=e.pending.options[0]
 e.choose_effect({"selection_id":spec.get("selection_id",""),"picks":[[e.Cat.ref(e,element)]]})
 acknowledge(who)
 expect(element.zone=="hand" and e.pending.get("trigger",{}).get("effect","")=="cat:element_reveal","a chosen element still triggers from its new hand instance")
 if e.pending.get("trigger",{}).get("effect","")=="cat:element_reveal":
  expect(e.pending.trigger.data.removal_ref==e.Cat.ref(e,element),"the hand instance is captured after the revealing effect")
  e.choose_effect({"none":true});one()
  expect(element.zone=="exile","the selected element may be exiled from hand")
  if e.pending.get("trigger",{}).get("effect","")=="cat:grant":e.choose_effect({})

func philosopher(who: int,id: String):
 setup(who)
 var element=put(id,"deck",who);put("164","deck",who)
 var card=e.make_card("128",who,"stack")
 e.stack.append({"id":e.next_stack,"kind":"card","card":card,"owner":who,"target":{"none":true},"name":e.cards[card.card_id].name});e.next_stack+=1
 one();acknowledge(who)
 expect(element.zone=="exile" and e.pending.get("trigger",{}).get("effect","")=="cat:element_reveal","philosopher reveals and already exiles the element before its trigger")
 if e.pending.get("trigger",{}).get("effect","")=="cat:element_reveal":
  expect(e.pending.trigger.data.removal_ref.is_empty(),"an already exiled element cannot be exiled again")
  e.choose_effect({"none":true});one()
  expect(element.zone=="exile" and e.pending.is_empty(),"already exiled card gains no duplicate casting offer")

func run():
 for who in [0,1]:
  door(who)
  for id in ELEMENTS:patch_hand(who,id);philosopher(who,id)
  for effect in [["mist_lake","172"],["suwako_top","93"],["patch_topthree","character-mar-ex01"]]:
   for id in ELEMENTS:top_effect(who,effect[0],id,effect[1])
 print("REVEALED ELEMENT EFFECTS: %d checks; %d failures" % [checks,failures.size()]);quit(0 if failures.is_empty() else 1)
