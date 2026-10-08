extends "res://tests/support/rules_base.gd"
const SeatView=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const FLOWER="spell-fdf-031"

func target(unit: Dictionary) -> Dictionary:
 return {"selection_id":FLOWER,"picks":[[{"player":1}],[e.ref_target(unit)]]}

func paid_cast(spell: Dictionary,aim: Dictionary) -> String:
 return e.commit_cast(0,spell.uid,aim,e.payment(0,e.cast_cost(0,spell,aim)).plan)

func run():
 fresh();mana()
 var spell=put(FLOWER,"hand")
 expect(e.targets_for(FLOWER,0,spell.uid).is_empty(),"empty battlefield cannot satisfy the reset selection")
 expect(not paid_cast(spell,{"player":1}).is_empty() and spell.zone=="hand","empty battlefield prevents casting")
 var enemy=put("53","field",1)
 expect(e.targets_for(FLOWER,0,spell.uid).size()==1,"an enemy unit alone supplies a mandatory reset target")
 var yuuka=put("character-soi-018")
 var ally=put("53");var item=put("167")
 var options=e.targets_for(FLOWER,0,spell.uid)
 expect(options.size()==1 and options[0].selection[1].min==1 and options[0].selection[1].max==1,"exactly one reset unit is mandatory")
 var pool=options[0].selection[1].pool
 expect(e.ref_target(yuuka) in pool and e.ref_target(ally) in pool,"upright own Yuuka and other units can be chosen")
 expect(e.ref_target(enemy) in pool and e.ref_target(item) not in pool and not pool.any(func(r):return r.has("player")),"reset includes opposing units and excludes non-units and players")
 var before=JSON.stringify([e.players,e.stack,e.revision])
 for aim in [options[0],{"selection_id":FLOWER,"picks":[[{"player":1}],[]]},target(item),{"selection_id":FLOWER,"picks":[[{"player":1}],[e.ref_target(ally),e.ref_target(yuuka)]]}]:
  expect(not paid_cast(spell,aim).is_empty(),"incomplete, skipped, non-unit or multiple reset selections are rejected")
 expect(JSON.stringify([e.players,e.stack,e.revision])==before,"invalid declarations spend no colors and change no state")
 e.players[0].shroud_turn=e.turn
 e.players[1].shroud_turn=e.turn
 expect(e.targets_for(FLOWER,0,spell.uid).is_empty() and not e.cast_error(0,spell.uid).is_empty(),"protected units cannot satisfy a legal reset target")
 e.players[0].erase("shroud_turn")
 e.players[1].erase("shroud_turn")
 expect(paid_cast(spell,target(ally)).is_empty(),"upright own unit permits a real paid cast")
 e.tap_card(ally)
 expect(ally.tapped and e.players[1].life==20,"responses can tap an upright selected unit before resolution")
 one()
 expect(not ally.tapped and e.players[1].life==16 and spell.zone=="grave","resolution deals four damage and resets the declared unit")

 fresh();mana();put("86");spell=put(FLOWER,"hand");enemy=put("53","field",1);e.tap_card(enemy)
 expect(paid_cast(spell,target(enemy)).is_empty() and enemy.tapped,"enemy unit can be chosen without an early reset")
 one()
 expect(not enemy.tapped and e.players[1].life==16,"resolution resets the selected enemy unit")

 for change in ["none","leave","reenter","control"]:
  fresh();mana();put("86")
  ally=put("53");e.tap_card(ally);spell=put(FLOWER,"hand")
  expect(paid_cast(spell,target(ally)).is_empty() and ally.tapped,"casting leaves a tapped reset target tapped: "+change)
  match change:
   "leave":e.move_to(ally,"grave")
   "reenter":e.move_to(ally,"grave");e.move_to(ally,"field");e.tap_card(ally)
   "control":e.players[0].field.erase(ally);ally.owner=1;e.players[1].field.append(ally)
  var tapped_before=ally.tapped
  one()
  expect(e.players[1].life==16,"a changed reset target does not prevent the valid damage: "+change)
  expect(not ally.tapped if change in ["none","control"] else ally.tapped==tapped_before,"a valid unit resets after control changes but not after changing zones: "+change)

 for yuuka_id in ["character-soi-018","86"]:
  fresh();yuuka=put(yuuka_id);e.tap_card(yuuka);spell=put(FLOWER,"hand")
  e.move_to(spell,"palette");e.pump_choices()
  expect(e.pending.get("trigger",{}).get("effect","")=="cat:flower_cast","palette entry announces Flower Land's trigger with either Yuuka")
  e.choose_effect({"none":true});one()
  expect(e.pending.get("trigger",{}).get("effect","")=="cat:grant" and e.pending.trigger.data.free,"resolved palette trigger offers a free cast")
  if e.pending.get("trigger",{}).get("effect","")!="cat:grant":continue
  e.choose_effect(target(yuuka))
  expect(spell.zone=="stack" and yuuka.tapped and e.players[0].palette.all(func(c):return not c.tapped),"free cast selects a reset unit without resetting or paying early")
  one()
  expect(spell.zone=="grave" and not yuuka.tapped and e.players[1].life==16,"free spell resets only when the spell resolves")

 fresh();ally=put("53");spell=put(FLOWER,"hand")
 e.move_to(spell,"palette");e.pump_choices()
 expect(e.pending.is_empty() and e.triggers.is_empty() and e.stack.is_empty(),"palette entry without Yuuka silently skips the trigger")
 for seat in range(2):
  var remote=Remote.new();remote.apply_snapshot(SeatView.build(e,seat))
  expect(remote.pending.is_empty() and remote.stack.is_empty(),"network seat receives no trigger or choice without Yuuka: "+str(seat))
 var observer=Remote.new();observer.apply_snapshot(Observer.build(e))
 expect(observer.pending.is_empty() and observer.stack.is_empty(),"spectator receives no skipped palette trigger")
 expect(spell.zone=="palette" and not e.log.any(func(line):return line.contains("触发能力") or line.contains("当前无法使用")),"skipped free use keeps the card in palette without trigger messages")
 put("character-soi-018");e.pump_choices()
 expect(e.pending.is_empty() and e.stack.is_empty(),"a later Yuuka does not retroactively trigger the palette card")

 fresh();put("86","field",1);spell=put(FLOWER,"hand")
 e.move_to(spell,"palette");e.pump_choices()
 expect(e.pending.is_empty() and e.triggers.is_empty() and e.stack.is_empty(),"opponent's Yuuka does not enable own palette trigger")

 fresh();yuuka=put("86")
 for i in range(2):e.move_to(put(FLOWER,"hand"),"palette")
 expect(e.triggers.size()==2,"own Yuuka enables simultaneous palette triggers")
 e.move_to(yuuka,"grave");e.pump_choices()
 expect(e.pending.is_empty() and e.triggers.is_empty() and e.stack.is_empty(),"queued triggers are skipped before ordering if Yuuka leaves")

 fresh();spell=put(FLOWER,"hand");e.active=1;e.priority=1
 e.move_to(spell,"palette");e.pump_choices()
 expect(e.pending.is_empty() and e.stack.is_empty(),"entry outside the owner's turn does not trigger free use")
 print("FLOWER_LAND: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
