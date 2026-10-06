extends "res://tests/support/rules_base.gd"

func has_target(options: Array,c: Dictionary) -> bool:
 for option in options:
  if option.get("uid",-1)==c.uid:return true
  for group in option.get("selection",[]):
   if group.get("pool",[]).any(func(r):return r.get("uid",-1)==c.uid):return true
 return false

func resolve_spell(id: String,target: Dictionary={}) -> void:
 var card=put(id,"hand")
 expect(e.Extra.spell_resolve(e,{"card":card,"owner":0,"target":target}),id+" resolves")

func run():
 classification_and_targets()
 jade()
 unsheathed()
 protection_and_trigger()
 print("PERMANENTS: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func classification_and_targets() -> void:
 fresh()
 var unit=put("53")
 var leader=put("70")
 var item=put("167")
 var field=put("170")
 var time_spell=put("spell-kmo-005")
 var melody=put("spell-ucs-011")
 for c in [unit,leader,item,field]:expect(e.Roster.permanent(e,c),e.cards[c.card_id].kind+" is a permanent")
 for c in [time_spell,melody]:expect(not e.Roster.permanent(e,c),e.cards[c.card_id].spell_type+" is not a permanent")
 for id in ["135","spell-fdf-056"]:
  var options=e.targets_for(id,0)
  for c in [unit,leader,item,field]:expect(has_target(options,c),id+" can target "+e.cards[c.card_id].kind)
  for c in [time_spell,melody]:expect(not has_target(options,c),id+" cannot target field spell")
 mana()
 var x_options=e.targets_for("spell-fdf-051",0)
 expect(has_target(x_options,item) and has_target(x_options,leader),"X destruction includes matching permanents")
 expect(not has_target(x_options,time_spell) and not has_target(x_options,melody),"X destruction excludes field spells")
 var palette_permanent=put("164","palette")
 var palette_spell=put("spell-kmo-005","palette")
 resolve_spell("158",{"none":true})
 var palette_options=e.pending.get("options",[])
 expect(has_target(palette_options,palette_permanent),"palette army includes permanent cards")
 expect(not has_target(palette_options,palette_spell),"palette army excludes time spells")
 fresh()
 unit=put("53")
 leader=put("70")
 item=put("167")
 time_spell=put("spell-kmo-005")
 melody=put("spell-ucs-011")
 var life=e.players[1].life
 resolve_spell("spell-ucs-027",{"player":1})
 expect(e.players[1].life==life-3,"color damage counts only colors on permanents, including the leader")

func jade() -> void:
 for mode in ["保留蓝色","保留绿色"]:
  fresh()
  var blue=put("167")
  var green=put("166")
  var yellow=put("164")
  var unit=put("53")
  var leader=put("70")
  var time_spell=put("spell-kmo-005")
  var melody=put("spell-ucs-011")
  resolve_spell("spell-fdf-034",{"none":true,"mode":mode})
  expect(blue.zone==("field" if mode=="保留蓝色" else "deck"),mode+" handles blue permanent")
  expect(green.zone==("deck" if mode=="保留蓝色" else "field"),mode+" handles green permanent")
  expect(yellow.zone=="deck" and unit.zone=="deck" and leader.zone=="deck",mode+" moves nonmatching permanents including leader")
  expect(time_spell.zone=="field" and melody.zone=="field",mode+" leaves time and melody spells on the field")

func unsheathed() -> void:
 fresh()
 var permanents=[put("53"),put("70"),put("164"),put("170")]
 var time_spell=put("spell-kmo-005")
 time_spell.timer=2
 var melody=put("spell-ucs-011")
 resolve_spell("141",{"none":true})
 expect(permanents.all(func(c):return c.zone=="exile"),"Unsheathed exiles all permanent types")
 expect(time_spell.zone=="field" and melody.zone=="field","Unsheathed leaves time and melody spells on the field")

func protection_and_trigger() -> void:
 fresh()
 var unit=put("53")
 var leader=put("70")
 var time_spell=put("spell-kmo-005")
 var melody=put("spell-ucs-011")
 e.players[0].shroud_turn=e.turn
 expect(e.Roster.protected(e,e.ref_target(unit),1,true) and e.Roster.protected(e,e.ref_target(leader),1,true),"permanent protection covers units and leaders")
 expect(not e.Roster.protected(e,e.Pack.ref(e,time_spell),1,true) and not e.Roster.protected(e,e.Pack.ref(e,melody),1,true),"permanent protection does not cover time or melody spells")
 expect(has_target(e.targets_for("spell-fdf-055",1),time_spell),"a time spell remains targetable while permanent protection is active")
 var untap_options=e.Pack.trigger_options(e,{"effect":"marisa_untap","owner":0})
 expect(has_target(untap_options,unit) and has_target(untap_options,leader),"permanent untap includes units and leaders")
 expect(not has_target(untap_options,time_spell) and not has_target(untap_options,melody),"permanent untap excludes field spells")
 fresh()
 put("character-htk-005")
 time_spell=put("spell-kmo-005")
 e.move_to(time_spell,"exile")
 expect(not e.triggers.any(func(t):return t.effect=="character-htk-005"),"exiling a time spell does not trigger permanent exile")
 var item=put("164")
 e.move_to(item,"exile")
 expect(e.triggers.any(func(t):return t.effect=="character-htk-005"),"exiling a permanent triggers permanent exile")
