extends "res://tests/support/rules_base.gd"

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
  e.move_to(role,"grave")
  e.choose_effect(e.pending.options[0])
  expect(legal.zone=="hand" and e.stack.is_empty(),"stale Miracle choice rechecks character: "+id)

 fresh();put("9")
 var spell=draw_miracle("105")
 e.choose_effect(e.pending.options[0])
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
  expect(e.pending.get("trigger",{}).get("effect","")=="miracle" and e.pending.options.size()==1,"legal pair offers Miracle target: "+id)
  var pair=e.pending.options[0]
  e.choose_effect(pair)
  expect(paired.zone=="stack" and e.stack[0].target==pair,"Miracle announces selected pair: "+id)
  one()
  expect(paired.zone=="grave","targeted Miracle resolves: "+id)
  fresh();put("9");var ally=put("67")
  var stale=draw_miracle(id);var old_pair=e.pending.options[0]
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
  expect(e.pending.get("trigger",{}).get("effect","")=="miracle" and e.stack.is_empty(),"legal Miracle retains its private choice: "+zone)
  e.choose_effect(e.pending.options[0]);one()
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

 print("MIRACLE: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
