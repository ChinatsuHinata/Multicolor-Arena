extends "res://tests/support/rules_base.gd"
const SeatView=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
const Codec=preload("res://net/state_codec.gd")

func confirm_review():
 if e.pending.get("kind","")!="reveal_review":return
 expect(not e.pending.cards.is_empty(),"resolved Miracle keeps the revealed card until opponent confirmation")
 e.confirm_revealed(e.pending.owner,e.pending.serial)

func one():
 confirm_review()
 super.one()
 confirm_review()

func draw_miracle(id: String):
 var c=put(id,"deck")
 e.players[0].deck.erase(c);e.players[0].deck.push_front(c)
 e.phase="prepare";e.advance_phase()
 return c

func run():
 for id in ["105","spell-rec-055"]:
  fresh()
  var blocked=draw_miracle(id)
  expect(blocked.zone=="hand" and e.pending.is_empty() and e.triggers.is_empty(),"Miracle respects missing character: "+id)
  fresh();put("9","field",1)
  blocked=draw_miracle(id)
  expect(e.pending.is_empty(),"opponent character does not satisfy Miracle: "+id)
  fresh();var role=put("9")
  if id=="spell-rec-055":put("67")
  var legal=draw_miracle(id)
  expect(e.pending.get("trigger",{}).get("effect","")=="miracle","matching character allows Miracle: "+id)
  e.choose_effect(e.pending.options[0])
  e.move_to(role,"grave")
  one()
  expect(legal.zone=="hand" and e.stack.is_empty(),"stale Miracle choice rechecks character: "+id)

 fresh();put("9")
 var spell=draw_miracle("105")
 e.choose_effect(e.pending.options[0]);one();e.choose_effect(e.pending.options[0])
 expect(spell.zone=="stack","legal character-constrained Miracle casts without color payment")

 for id in ["spell-rec-055","spell-smm-003"]:
  fresh();put("9")
  var no_target=draw_miracle(id)
  expect(no_target.zone=="hand" and e.pending.is_empty() and e.triggers.is_empty() and e.stack.is_empty(),"Miracle with no legal pair never starts a choice or stack: "+id)
  e.Extra.event(e,no_target,"miracle",true);e.pump_choices()
  expect(e.pending.is_empty() and e.triggers.is_empty() and e.stack.is_empty(),"manually queued targetless Miracle is blocked: "+id)
  fresh();put("9");put("67","field",1)
  no_target=draw_miracle(id)
  expect(no_target.zone=="hand" and e.pending.is_empty() and e.stack.is_empty(),"one unit per player is not a legal pair: "+id)
  fresh();put("9");put("67")
  var paired=draw_miracle(id)
  e.choose_effect(e.pending.options[0]);one()
  expect(e.pending.get("trigger",{}).get("continuation",false) and e.pending.options.size()==1,"legal pair is chosen when Miracle resolves: "+id)
  var pair=e.pending.options[0]
  e.choose_effect(pair)
  expect(paired.zone=="stack" and e.stack[0].target==pair,"Miracle announces selected pair: "+id)
  one()
  expect(paired.zone=="grave","targeted Miracle resolves: "+id)
  fresh();put("9");var ally=put("67")
  var stale=draw_miracle(id)
  e.choose_effect(e.pending.options[0]);one();var old_pair=e.pending.options[0]
  e.move_to(ally,"grave");e.choose_effect(old_pair)
  expect(stale.zone=="hand" and e.stack.is_empty(),"Miracle rechecks pair before entering stack: "+id)

 for id in ["9","67","character-rei-ex01"]:
  fresh();put(id)
  var drawn=draw_miracle(id)
  expect(drawn.zone=="hand" and e.players[0].hand.has(drawn),"duplicate Miracle stays in hand: "+id)
  expect(e.pending.is_empty() and e.triggers.is_empty() and e.stack.is_empty(),"duplicate Miracle has no prompt or stack object: "+id)
  expect(not e.log.any(func(line):return str(line).contains("奇迹")),"ignored Miracle has no announcement: "+id)

 fresh()
 e.cards["miracle_title_variant"]=e.cards["9"].duplicate(true)
 e.cards["miracle_title_variant"].name="祈风之人「前缀测试单位」"
 put("miracle_title_variant")
 draw_miracle("9")
 expect(e.pending.is_empty() and e.triggers.is_empty(),"shared title suppresses Miracle even with a different full name")

 for zone in ["opponent","palette","different_title"]:
  fresh()
  if zone=="different_title":
   e.cards["miracle_other_title"]=e.cards["9"].duplicate(true)
   e.cards["miracle_other_title"].title="另一个前缀";put("miracle_other_title")
  else:put("9","field" if zone=="opponent" else zone,1 if zone=="opponent" else 0)
  var drawn=draw_miracle("9")
  expect(e.pending.get("trigger",{}).get("effect","")=="miracle" and e.stack.is_empty(),"legal Miracle offers a private reveal choice: "+zone)
  e.choose_effect(e.pending.options[0]);one();e.choose_effect(e.pending.options[0]);one()
  expect(drawn.zone=="field","legal Miracle can still enter: "+zone)

 fresh()
 var drawn=draw_miracle("9");var before=e.log.size()
 e.choose_effect({})
 expect(drawn.zone=="hand" and e.pending.is_empty() and e.log.size()==before,"declining a legal Miracle stays silent")

 fresh()
 drawn=put("9","hand")
 var queued={"extended":true,"owner":0,"source":drawn.duplicate(true),"effect":"miracle","optional":true,"name":e.cards[drawn.card_id].name}
 e.triggers.append(queued)
 var blocker=put("9");blocker.tapped=true
 e.triggers.append({"owner":0,"source":blocker.duplicate(true),"effect":"untap","name":"重置"})
 e.pump_choices()
 expect(e.pending.is_empty() and e.stack.size()==1 and e.stack[0].effect=="untap","queued blocked Miracle is removed before trigger ordering")
 e.begin_trigger(queued)
 expect(e.pending.is_empty(),"restored blocked Miracle cannot reopen its prompt")
 queued.target={"none":true};e.Extra.resolve_trigger(e,queued)
 expect(drawn.zone=="hand" and e.stack.size()==1,"blocked Miracle cannot cast through a stale choice")

 # Revealing announces an ability, with its card still in hand and no cast event.
 fresh();var sanae=put("character-lof-003");sanae.leader=true
 drawn=draw_miracle("106")
 for projection in [SeatView.build(e,1,e.presentation_events),Observer.build(e,e.presentation_events)]:
  expect(projection.state.stack.is_empty() and not projection.definitions.has("106") and not JSON.stringify(projection.state.history).contains(e.cards["106"].name),"draw remains private before the reveal decision")
 e.choose_effect({"none":true})
 expect(drawn.zone=="hand" and e.players[0].hand.has(drawn) and e.pending.is_empty() and e.stack.size()==1 and e.stack[0].kind=="ability" and e.stack[0].effect=="miracle","revealed Miracle opens a response window while the card stays in hand")
 expect(e.priority==1 and e.passes==0 and e.presentation_events.any(func(event):return event.type=="reveal" and event.card.uid==drawn.uid),"opponent receives priority after the public reveal")
 expect(not e.triggers.any(func(t):return t.effect=="sanae_miracle"),"revealing Miracle does not count as casting it")
 for projection in [SeatView.build(e,1,e.presentation_events),Observer.build(e,e.presentation_events)]:
  expect(projection.definitions.has("106") and projection.state.stack[0].source.uid==drawn.uid and projection.state.stack[0].source.zone=="hand","opponent and spectator see the revealed ability and its hand source")
 var restored=Duel.new();Codec.restore(restored,Codec.capture(e));e=restored;drawn=e.find_card(drawn.uid)
 one()
 expect(drawn.zone=="hand" and e.pending.get("trigger",{}).get("continuation",false) and e.pending.has("resolving_entry"),"restored Miracle waits for both passes, then offers the cast choice")
 e.choose_effect({"none":true})
 confirm_review()
 expect(drawn.zone=="stack" and e.stack.any(func(entry):return entry.get("effect","")=="sanae_miracle"),"actual Miracle casting triggers Sanae after the response window")

 # Even a fast Miracle cannot be used as a normal response while it waits.
 fresh();mana();e.cards["106"].fast=true
 drawn=draw_miracle("106");e.choose_effect({"none":true});e.pass_priority(1)
 expect(e.cast_error(0,drawn.uid)=="请等待奇迹能力结算后使用该牌" and not e.legal_casts(0,true).has(drawn),"waiting Miracle is unavailable even when it is fast and affordable")
 expect(not e.commit_cast(0,drawn.uid,{"none":true},[]).is_empty() and drawn.zone=="hand","manual casting cannot bypass the Miracle window")
 var other=put("106","hand")
 expect(e.cast_error(0,other.uid).is_empty(),"the waiting restriction only affects the revealed instance")
 one();e.choose_effect({})
 confirm_review()
 e.phase="main";e.priority=0
 expect(drawn.zone=="hand" and e.cast_error(0,drawn.uid).is_empty(),"declining the resolved Miracle releases the waiting restriction")

 # A real response can discard the revealed card before Miracle resolves.
 fresh();var satori=put("76","field",1);satori.leader=true
 drawn=draw_miracle("106");e.choose_effect({"none":true})
 var error=e.commit_extension(1,satori.uid,{"player":0},[],"satori_discard")
 expect(error.is_empty() and e.stack.size()==2,"Satori can respond to the revealed Miracle")
 if e.pending.get("kind","")=="leader_return":e.choose_return(false)
 one()
 expect(e.pending.get("trigger",{}).get("effect","")=="satori_discard_choice","discard response resolves before Miracle")
 e.choose_effect({"picks":[[e.Pack.ref(e,drawn)]]})
 expect(drawn.zone=="grave" and e.stack.size()==1,"discard response removes the Miracle card from hand")
 one()
 expect(e.pending.is_empty() and e.stack.is_empty() and drawn.zone=="grave","discarded Miracle cannot subsequently be used")

 # Leaving and re-entering hand does not restore the original draw's permission.
 fresh();drawn=draw_miracle("106");e.choose_effect({"none":true})
 e.move_to(drawn,"grave");e.move_to(drawn,"hand");one()
 expect(drawn.zone=="hand" and e.pending.is_empty() and e.stack.is_empty(),"returned card has a new epoch and cannot use the old Miracle")

 fresh();put("165","palette",1);put("164","palette",1)
 drawn=draw_miracle("106");e.choose_effect({"none":true})
 var miracle_id=e.stack[0].id;var counter=put("123","hand",1)
 error=e.commit_cast(1,counter.uid,{"stack_id":miracle_id},e.payment(1,e.cast_cost(1,counter)).plan)
 expect(error.is_empty(),"Miracle ability can be countered during the response window")
 one()
 expect(drawn.zone=="hand" and e.pending.is_empty() and e.stack.is_empty() and not e.miracle_waiting(drawn),"countered Miracle remains in hand and releases its waiting restriction")

 print("MIRACLE: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
