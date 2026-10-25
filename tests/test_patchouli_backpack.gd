extends "res://tests/support/rules_base.gd"
const Gateway=preload("res://net/command_gateway.gd")
const Seat=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const Codec=preload("res://net/state_codec.gd")

func board(who: int=0) -> Dictionary:
 fresh();e.active=who;e.priority=who
 var patchouli=put("character-fdf-119","field",who);patchouli.leader=true
 var own=put("53","field",who);own.plus_counters=10
 var victim=put("53","field",1-who);victim.plus_counters=10
 var backpack=put("item-ucs-012","field",1-who)
 for i in range(2):put("165","palette",who)
 var spell=put("spell-fdf-078","hand",who)
 var target=e.ref_target(victim)
 var error=e.commit_cast(who,spell.uid,target,e.payment(who,e.cast_cost(who,spell,target)).plan)
 expect(error.is_empty(),"Patchouli casts her character spell with real payment: "+error)
 expect(e.pending.get("trigger",{}).get("effect","")=="character-fdf-119","casting requests Patchouli's optional damage target")
 return {"patchouli":patchouli,"own":own,"victim":victim,"spell":spell,"backpack":backpack}

func choose_damage(who: int,refs: Array):
 var target=e.pending.options[0].duplicate(true)
 target.erase("selection");target.picks=[refs]
 expect(Gateway.apply(e,who,{"name":"choose_effect","args":[target]}).is_empty(),"authority accepts Patchouli's grouped damage target")

func protected_targets():
 for who in [0,1]:
  for kind in ["player","unit"]:
   for pay in [false,true]:
    var b=board(who)
    var resource=put("167","palette",who)
    var target={"player":1-who} if kind=="player" else e.ref_target(b.victim)
    var label="seat %d %s pay=%s: " % [who,kind,str(pay)]
    expect(e.stack.size()==2 and not e.stack.any(func(s):return s.get("effect","")=="backpack_tax"),label+"the character spell itself does not trigger Backpack")
    choose_damage(who,[target])
    expect(e.pending.is_empty() and e.stack.size()==3 and e.stack.back().effect=="backpack_tax",label+"Backpack triggers exactly once after target declaration")
    var ability=e.stack[1]
    expect(e.Pack.declared_targets(ability)==[target] and e.stack.back().data.id==ability.id and e.stack.back().source.uid==b.backpack.uid,label+"Backpack tracks the damage ability and its grouped target")
    one()
    expect(e.pending.get("trigger",{}).get("effect","")=="backpack_pay" and e.pending.owner==who,label+"the damage controller chooses whether to pay")
    if e.pending.get("trigger",{}).get("effect","")!="backpack_pay":continue
    expect(e.players[1-who].life==20 and b.victim.damage==0,label+"payment is requested before any damage")
    var remote=Remote.new();remote.seat=who;remote.apply_snapshot(Seat.build(e,who))
    expect(remote.pending.get("trigger",{}).get("effect","")=="backpack_pay" and remote.pending.owner==who,label+"remote seat receives the payment choice")
    var revision=e.revision
    expect(not Gateway.apply(e,1-who,{"name":"choose_effect","args":[{"none":true,"mode":"不支付"}]}).is_empty() and e.revision==revision,label+"the protected player cannot answer for the payer")
    var options=e.pending.options.filter(func(o):return o.get("uid",-1)==resource.uid and o.get("color","")=="蓝" if pay else not o.has("color"))
    expect(not options.is_empty(),label+"the requested payment decision is available")
    if options.is_empty():continue
    expect(Gateway.apply(e,who,{"name":"choose_effect","args":[options[0]]}).is_empty(),label+"authority accepts the payment decision")
    expect(resource.tapped==pay and e.stack.size()==(2 if pay else 1),label+"paying retains the ability; declining counters only the ability")
    expect(e.usage_count(b.patchouli.uid,"character-fdf-119")==1,label+"the once-per-turn use remains spent")
    if pay:
     one()
     expect(e.players[1-who].life==(17 if kind=="player" else 20) and b.victim.damage==(3 if kind=="unit" else 0),label+"paid ability deals exactly three damage")
    else:expect(e.players[1-who].life==20 and b.victim.damage==0,label+"countered ability deals no damage")
    one()
    expect(e.stack.is_empty() and b.spell.zone=="grave" and b.victim.damage==(6 if pay and kind=="unit" else 3),label+"the original character spell still resolves normally")

func payment_colors():
 for id in ["165","167","166","164","168"]:
  var b=board();var resource=put(id,"palette")
  choose_damage(0,[{"player":1}]);one()
  var options=e.pending.options.filter(func(o):return o.get("uid",-1)==resource.uid and o.has("color"))
  expect(not options.is_empty(),id+" can pay Backpack's any-color cost")
  if options.is_empty():continue
  e.choose_effect(options[0]);one()
  expect(resource.tapped and e.players[1].life==17 and b.victim.damage==0,id+" payment allows three damage to the player")

func no_protected_target():
 for who in [0,1]:
  for kind in ["none","player","unit"]:
   var b=board(who)
   var own=b.own
   var refs=[] if kind=="none" else [{"player":who}] if kind=="player" else [e.ref_target(own)]
   choose_damage(who,refs)
   expect(e.pending.is_empty() and e.stack.size()==2,"Backpack ignores zero targets and the ability controller's own player or unit")
   one()
   expect(e.players[who].life==(17 if kind=="player" else 20) and own.damage==(3 if kind=="unit" else 0) and b.victim.damage==0,"unprotected or zero-target damage resolves without a Backpack payment")

func restored_payment():
 for who in [0,1]:
  var b=board(who)
  choose_damage(who,[e.ref_target(b.victim)]);one()
  var restored=Duel.new()
  expect(Codec.restore(restored,Codec.capture(e)).is_empty(),"restore Backpack's pending payment")
  e=restored
  expect(e.pending.get("trigger",{}).get("effect","")=="backpack_pay" and e.pending.owner==who and not e.pending.options.any(func(o):return o.has("color")),"restored exhausted payer can only decline")
  e.choose_effect(e.pending.options[0])
  expect(e.stack.size()==1 and e.stack[0].kind=="card" and e.find_card(b.victim.uid).damage==0,"declining after restore counters Patchouli damage without touching the original spell")

func untargeted_spell(free_payment: bool):
 for who in [0,1]:
  for kind in ["player","unit"]:
   fresh();e.active=who;e.priority=who;e.debug_enabled=free_payment;e.debug_free_payment=free_payment
   var patchouli=put("character-fdf-119","field",who)
   var victim=put("53","field",1-who);victim.plus_counters=10
   put("item-ucs-012","field",1-who);put("167","palette",who)
   var spell=put("spell-fdf-077","hand",who);var target={"none":true}
   expect(e.commit_cast(who,spell.uid,target,e.payment(who,e.cast_cost(who,spell,target)).plan).is_empty(),"cast an untargeted draw spell; free payment="+str(free_payment))
   expect(e.Pack.declared_targets(e.stack[0]).is_empty(),"the character spell itself has no target")
   choose_damage(who,[{"player":1-who} if kind=="player" else e.ref_target(victim)]);one()
   expect(e.pending.get("trigger",{}).get("effect","")=="backpack_pay","untargeted spell still allows Backpack to tax the damage ability")
   if e.pending.get("trigger",{}).get("effect","")!="backpack_pay":continue
   var decline=e.pending.options.filter(func(o):return not o.has("color"))[0]
   expect(Gateway.apply(e,who,{"name":"choose_effect","args":[decline]}).is_empty(),"submit an explicit refusal even with free payment enabled")
   expect(e.stack.size()==1 and e.stack[0].kind=="card","refusal counters the damage ability even with free payment enabled")
   settle()
   expect(e.players[1-who].life==20 and victim.damage==0 and spell.zone=="grave","refusal prevents all damage while the untargeted spell finishes")
   expect(e.usage_count(patchouli.uid,"character-fdf-119")==1,"refusal still consumes Patchouli's once-per-turn use")

func run():
 if "--untargeted-only" not in OS.get_cmdline_user_args():
  protected_targets();payment_colors();no_protected_target();restored_payment()
 untargeted_spell(false);untargeted_spell(true)
 print("PATCHOULI_BACKPACK: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
