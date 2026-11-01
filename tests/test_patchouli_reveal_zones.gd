extends "res://tests/support/rules_base.gd"
const Caption=preload("res://scripts/rules/ability_caption.gd")
const Gateway=preload("res://net/command_gateway.gd")
const Seat=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
const Codec=preload("res://net/state_codec.gd")
const ELEMENTS=["spell-fdf-075","spell-fdf-076","spell-fdf-077","spell-fdf-078","spell-fdf-079"]

func board(who: int):
 fresh();e.active=who;e.priority=who
 for p in e.players:p.deck=[]
 put("character-mar-021","field",who)
 var target=put("53","field",1-who);target.plus_counters=10
 for id in ["165","167","166","164","168"]:
  for i in range(2):put(id,"palette",who)

func reveal(id: String,zone: String,who: int) -> Dictionary:
 board(who)
 var spell=put(id,"deck",who);put("164","deck",who)
 e.Cat.reveal(e,[spell])
 if zone=="hand":e.move_to(spell,"hand")
 e.pump_choices()
 expect(e.pending.get("trigger",{}).get("effect","")=="cat:element_reveal","revealed element offers its exile ability")
 return spell

func accept(who: int):
 var error=Gateway.apply(e,who,{"name":"choose_effect","args":[{"none":true}]})
 expect(error.is_empty(),"controller accepts the reveal ability: "+error)

func check_caption(trigger: Dictionary,zone: String,label: String):
 var caption=Caption.text(trigger)
 expect(("已加入手牌" in caption and "从手牌移除" in caption) if zone=="hand" else ("未加入手牌" in caption and "从牌库移除" in caption),label+" identifies the removal zone")

func element_zones():
 for who in [0,1]:
  for id in ELEMENTS:
   for zone in ["deck","hand"]:
    var spell=reveal(id,zone,who)
    var label="seat %d %s %s: " % [who,id,zone]
    expect(e.pending.trigger.data.removal_ref==e.Cat.ref(e,spell),label+"announcement remembers the current zone instance")
    check_caption(e.pending.trigger,zone,label+"choice")
    accept(who)
    check_caption(e.stack.back(),zone,label+"stack")
    e.presentation_events.clear();one()
    expect(spell.zone=="exile",label+"exiles the revealed card")
    expect(e.presentation_events.any(func(event):return event.type=="move" and event.card.uid==spell.uid and event.from==zone and event.to=="exile"),label+"moves from the announced zone")
    expect(e.pending.get("trigger",{}).get("effect","")=="cat:grant",label+"offers casting only after exile")
    if e.pending.get("trigger",{}).get("effect","")=="cat:grant":e.choose_effect({})
    expect(spell.zone=="exile" and e.pending.is_empty(),label+"declining casting leaves it exiled")

func patchouli_selection():
 for who in [0,1]:
  board(who)
  var patchouli=put("character-fdf-119","field",who);patchouli.leader=true
  var hand=put("spell-fdf-077","deck",who)
  var library=put("spell-fdf-078","deck",who)
  var other=put("164","deck",who)
  e.Cat.events(e,patchouli,"character-fdf-119:self");e.pump_choices();one()
  expect(e.pending.get("trigger",{}).get("effect","")=="cat:unit_reveal","Patchouli finishes revealing before element triggers are announced")
  if e.pending.get("trigger",{}).get("effect","")!="cat:unit_reveal":continue
  var spec=e.pending.options[0]
  e.choose_effect({"selection_id":spec.get("selection_id",""),"picks":[[e.Cat.ref(e,hand)]]})
  expect(hand.zone=="hand" and e.pending.get("trigger",{}).get("effect","")=="cat:bottom_order","selected role spell enters hand before ordering the rest")
  if e.pending.get("trigger",{}).get("effect","")!="cat:bottom_order":continue
  spec=e.pending.options[0]
  e.choose_effect({"selection_id":spec.get("selection_id",""),"picks":[spec.selection[0].pool]})
  expect(e.pending.get("kind","")=="reveal_review","the original reveal completes before any element ability")
  if e.pending.get("kind","")!="reveal_review":continue
  expect(Gateway.apply(e,1-who,{"name":"confirm_revealed","args":[e.pending.serial]}).is_empty(),"opponent confirms all revealed cards")
  expect(e.pending.get("kind","")=="trigger_order" and e.pending.options.size()==2,"both element abilities can be ordered together")
  if e.pending.get("kind","")!="trigger_order":continue
  for trigger in e.pending.options:
   var spell=hand if trigger.source.uid==hand.uid else library
   check_caption(trigger,spell.zone,"trigger order")
   expect(trigger.data.removal_ref==e.Cat.ref(e,spell) and trigger.data.ref.epoch!=spell.epoch,"capture the final instance after hand selection or bottom ordering")
  e.choose_trigger_order([0,1]);accept(who);accept(who)
  expect(e.stack.size()==2,"both optional abilities are on the stack")
  for i in range(2):
   one()
   expect(e.pending.get("trigger",{}).get("effect","")=="cat:grant","each actual exile offers its own cast")
   if e.pending.get("trigger",{}).get("effect","")=="cat:grant":e.choose_effect({})
  expect(hand.zone=="exile" and library.zone=="exile" and other.zone=="deck","both hand and unselected library spells exile without moving unrelated cards")

func moved_responses():
 for who in [0,1]:
  for origin in ["deck","hand"]:
   for path in [["grave"],["grave",origin],["hand" if origin=="deck" else "deck"],["hand" if origin=="deck" else "deck",origin]]:
    var spell=reveal("spell-fdf-077",origin,who)
    var another=put(spell.card_id,origin,who)
    accept(who)
    var recorded=e.stack.back().data.removal_ref.duplicate(true)
    for zone in path:e.move_to(spell,zone)
    e.pump_choices()
    expect(e.stack.back().data.removal_ref==recorded,"responses cannot replace the remembered zone instance")
    e.presentation_events.clear();one()
    expect(spell.zone==path.back() and another.zone==origin,"old ability cannot exile a moved or returned card or another copy")
    expect(e.pending.is_empty() and not e.presentation_events.any(func(event):return event.type=="move" and event.to=="exile"),"failed exile grants no casting choice")

func network_and_restore():
 for who in [0,1]:
  for zone in ["deck","hand"]:
   var spell=reveal("spell-fdf-077",zone,who)
   var ref=e.Cat.ref(e,spell)
   var seat=Seat.build(e,who)
   expect(seat.state.pending.trigger.data.removal_ref==ref,"owner snapshot retains the exact zone instance")
   check_caption(seat.state.pending.trigger,zone,"owner snapshot")
   var recovered=Duel.new()
   expect(Codec.restore(recovered,bytes_to_var(var_to_bytes(Codec.capture(e)))).is_empty(),"restore a pending reveal ability")
   e=recovered;accept(who)
   for perspective in [0,1]:
    var snapshot=Seat.build(e,perspective)
    expect(snapshot.state.stack.back().data.removal_ref==ref,"both seats receive the same removal zone")
    check_caption(snapshot.state.stack.back(),zone,"seat stack")
    if perspective!=who:expect(snapshot.state.players[who].hand.all(func(c):return c.card_id=="back"),"zone caption preserves hidden hand contents")
   var observer=Observer.build(e)
   check_caption(observer.state.stack.back(),zone,"spectator stack")
   expect(observer.state.players[who].deck.all(func(c):return c.card_id=="back"),"zone caption preserves hidden library order")
   recovered=Duel.new()
   expect(Codec.restore(recovered,Codec.capture(e)).is_empty(),"restore an announced reveal ability")
   e=recovered;one()
   expect(e.find_card(spell.uid).zone=="exile" and e.pending.get("trigger",{}).get("effect","")=="cat:grant","restored ability still exiles and offers casting from its remembered zone")

func run():
 element_zones();patchouli_selection();moved_responses();network_and_restore()
 print("PATCHOULI_REVEAL_ZONES: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
