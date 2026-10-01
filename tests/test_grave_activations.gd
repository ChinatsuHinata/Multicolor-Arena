extends "res://tests/support/rules_base.gd"

func run():
 for id in ["21","61","rec_unit_097","character-fdf-111","spell-fdf-059"]:
  fresh();mana()
  var c=put(id)
  var key=e.Extra.activation_kind(e.cards[id])
  expect(e.extension_activation_zone(key)=="grave","grave activation zone: "+id)
  for zone in ["field","hand","palette","exile","grave"]:
   e.detach(c);e.shift(c,zone);e.players[0][zone].append(c)
   var actions=e.available_actions(0,c.uid,true).filter(func(a):return a.type=="extension" and a.key==key)
   expect(actions.size()==(1 if zone=="grave" else 0),"menu exposes grave ability only in grave: "+id+" / "+zone)
   if zone!="grave":
    expect(not e.commit_extension(0,c.uid,{},[],key).is_empty(),"off-zone activation rejected: "+id+" / "+zone)
 fresh();mana()
 var returning=put("21","grave")
 expect(e.available_actions(0,returning.uid).any(func(a):return a.type=="extension" and a.key=="grave_return"),"affordable grave return remains enabled")
 var target=e.activation_options(returning,"grave_return")[0]
 var error=e.commit_extension(0,returning.uid,target,e.payment(0,e.extension_cost(0,returning,"grave_return",target)).plan,"grave_return")
 expect(error.is_empty(),"grave return can be activated from grave: "+error)
 settle()
 expect(returning.zone=="hand","grave return resolves into hand")
 print("Grave activations: %d checks, %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
