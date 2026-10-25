extends "res://tests/support/rules_base.gd"

const CASTLES=["field-smm-004","field-rei-013"]

func imprison(id: String,who: int=0,unit_owner: int=-1,unit_id: String="53") -> Dictionary:
 var unit=put(unit_id,"field",1-who if unit_owner<0 else unit_owner)
 var castle=enter(id,who)
 expect(e.pending.get("kind","")=="effect_choice",id+"进场后选择要关押的单位")
 if e.pending.get("kind","")!="effect_choice":return {"castle":castle,"unit":unit}
 var choice=e.pending.options[0].duplicate(true)
 choice.erase("selection");choice.picks=[[e.ref_target(unit)]]
 e.choose_effect(choice);one()
 expect(unit.zone=="exile",id+"通过实际进场能力关押单位")
 return {"castle":castle,"unit":unit}

func cast_unsheathed(who: int=0):
 var spell=put("141","hand",who)
 e.active=who;e.priority=who;e.debug_enabled=true;e.debug_free_payment=true
 var error=e.commit_cast(who,spell.uid,{"none":true},[])
 expect(error.is_empty(),"实际使用出鞘："+error)
 one()
 expect(spell.zone=="grave" and e.stack.is_empty() and e.pending.is_empty(),"出鞘正常完成结算")

func unsheathed():
 for id in CASTLES:
  for who in [0,1]:
   for unit_owner in [0,1]:
    fresh()
    var state=imprison(id,who,unit_owner)
    var epoch=state.unit.epoch
    var original=put("53","field",unit_owner)
    var unrelated=put("53","exile",unit_owner)
    cast_unsheathed(unit_owner)
    expect(state.castle.zone=="exile","出鞘移除席位%d的%s" % [who,id])
    expect(state.unit.zone=="field" and e.players[unit_owner].field.has(state.unit),"出鞘后席位%d的%s释放席位%d的单位" % [who,id,unit_owner])
    expect(state.unit.epoch==epoch+1,"被关单位只经历一次移回战场，不再被出鞘移除")
    expect(original.zone=="exile" and unrelated.zone=="exile","原在场永久物被移除，其他移除区单位保持原位")

func multiple_castles():
 fresh()
 var first=imprison(CASTLES[0],0)
 var second=imprison(CASTLES[1],1)
 cast_unsheathed()
 expect(first.castle.zone=="exile" and second.castle.zone=="exile","出鞘同时移除双方不同版本的城堡")
 expect(first.unit.zone=="field" and second.unit.zone=="field","双方城堡原先关押的单位都留在战场")

func stale_links():
 for id in CASTLES:
  fresh()
  var state=imprison(id)
  e.move_to(state.unit,"hand");e.move_to(state.unit,"exile")
  var epoch=state.unit.epoch
  cast_unsheathed()
  expect(state.castle.zone=="exile" and state.unit.zone=="exile" and state.unit.epoch==epoch,"出鞘不释放已脱离原关押关系的单位："+id)

func full_battlefield():
 for id in CASTLES:
  for who in [0,1]:
   fresh()
   var state=imprison(id,who)
   var original=[]
   for i in range(e.Cat.field_limit(e,1-who)):original.append(put("53","field",1-who))
   cast_unsheathed()
   expect(original.all(func(c):return c.zone=="exile"),"出鞘移除原先占满战场的单位")
   expect(state.unit.zone=="field","清场先腾出战场格，再释放被关单位："+id+str(who))

func ordinary_departures():
 for id in CASTLES:
  for destination in ["grave","exile","hand"]:
   fresh()
   var state=imprison(id,0,1,"character-fdf-065")
   e.move_to(state.castle,destination)
   expect(state.castle.zone==destination and state.unit.zone=="field","单独离场仍释放单位："+id+destination)
   expect(e.triggers.any(func(t):return t.source.uid==state.unit.uid and t.effect=="character-fdf-065"),"释放的单位正常触发进场能力")

func run():
 full_battlefield()
 unsheathed()
 multiple_castles()
 stale_links()
 ordinary_departures()
 print("CASTLE RELEASE: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
