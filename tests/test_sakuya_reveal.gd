extends "res://tests/support/rules_base.gd"

func run():
 for id in ["121","spell-fdf-040"]:
  fresh()
  var sakuya=put("character-fdf-041")
  sakuya.leader=true
  var instant=e.make_card("spell-fdf-055",0,"deck")
  var unit=e.make_card("character-soi-006",0,"deck")
  var timed=e.make_card(id,0,"deck")
  e.players[0].deck=[instant,unit,timed]
  var trigger={"owner":0,"effect":"character-fdf-041:self","source":sakuya.duplicate(true),"target":{"none":true}}
  e.Cat.Units.resolve(e,trigger)
  expect(e.pending.get("kind","")=="effect_choice" and e.pending.trigger.effect=="cat:unit_reveal","Sakuya offers a reveal choice for "+id)
  if e.pending.is_empty():continue
  var pool=e.pending.options[0].selection[0].pool
  expect(pool.size()==1 and pool[0].uid==timed.uid,"only the time spell is selectable for "+id)
  e.choose_effect({"selection_id":"","picks":[[e.Pack.ref(e,timed)]]})
  expect(timed.zone=="field" and timed.timer==int(e.cards[id].time),"selected time spell keeps its printed timer for "+id)
  expect(instant.zone=="grave" and unit.zone=="grave","unchosen revealed cards go to grave for "+id)
 print("SAKUYA_REVEAL: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
