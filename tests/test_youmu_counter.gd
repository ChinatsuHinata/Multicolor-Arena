extends "res://tests/support/rules_base.gd"
const Seat=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const Codec=preload("res://net/state_codec.gd")

func setup_board(who: int=0):
 fresh();e.debug_enabled=true;e.debug_free_payment=true
 e.active=1-who;e.priority=1-who
 var youmu=put("39","field",who)
 var counter=put("118","hand",who)
 return {"youmu":youmu,"counter":counter,"who":who}

func pick(spec: Dictionary,groups: Array) -> Dictionary:
 var target=spec.duplicate(true);target.erase("selection");target.picks=groups;return target

func offered(id: String,who: int,entry: Dictionary) -> bool:
 return {"stack_id":entry.id} in e.targets_for(id,who)

func counter_ability(board: Dictionary,entry: Dictionary,label: String):
 expect(e.pending.is_empty() and e.priority==board.who,label+" opens the response window")
 expect(offered("118",board.who,entry),label+" is a legal Six Roots counter target")
 var error=e.commit_cast(board.who,board.counter.uid,{"stack_id":entry.id},[])
 expect(error.is_empty(),label+" can be countered: "+error)
 if not error.is_empty():return
 one()
 expect(not e.stack.any(func(s):return s.id==entry.id),label+" is removed from the stack")
 expect(board.youmu.zone=="field" and board.youmu.damage==0,label+" leaves Youmu unharmed")
 expect(e.pending.get("trigger",{}).get("effect","")=="counter_six",label+" triggers six damage after countering")
 var life=e.players[1-board.who].life
 e.choose_effect({"player":1-board.who});one()
 expect(e.players[1-board.who].life==life-6,label+" deals exactly six damage")

func patchouli_casts():
 for who in [0,1]:
  var board=setup_board(who)
  put("character-fdf-119","field",1-who)
  var other=put("53","field",who);other.plus_counters=10
  var spell=put("spell-fdf-078","hand",1-who)
  expect(e.commit_cast(1-who,spell.uid,e.ref_target(other),[]).is_empty(),"seat %d Patchouli casts a real character spell" % who)
  expect(e.pending.get("trigger",{}).get("effect","")=="character-fdf-119","Patchouli's damage trigger asks for its optional target")
  if e.pending.get("trigger",{}).get("effect","")!="character-fdf-119":continue
  e.choose_effect(pick(e.pending.options[0],[[e.ref_target(board.youmu)]]))
  var entry=e.stack.back().duplicate(true)
  expect(e.cast_error(who,board.counter.uid).is_empty(),"Six Roots is usable against Patchouli from seat %d" % who)
  var remote=Remote.new();remote.seat=who;remote.apply_snapshot(Seat.build(e,who))
  expect(remote.cast_error(who,board.counter.uid).is_empty() and {"stack_id":entry.id} in remote.targets_for("118",who,board.counter.uid),"network seat offers the same counter against Patchouli")
  var restored=Duel.new();Codec.restore(restored,Codec.capture(e))
  expect({"stack_id":entry.id} in restored.targets_for("118",who),"saved grouped target remains counterable after restore")
  counter_ability(board,entry,"seat %d Patchouli damage" % who)
  one()
  expect(other.damage==3 and spell.zone=="grave","countering Patchouli leaves her original character spell to resolve")

func grouped_triggers():
 for effect in ["item-ucs-005","character-fdf-069","spell-fdf-123","cat:murder_dolls","cat:lie_damage"]:
  var board=setup_board()
  var source_id="spell-fdf-017" if effect=="cat:murder_dolls" else "spell-fdf-018" if effect=="cat:lie_damage" else effect
  var source=put(source_id,"field",1)
  e.Cat.events(e,source,effect,false,{"amount":3,"event":"death"});e.pump_choices()
  expect(e.pending.get("kind","")=="effect_choice",effect+" requests grouped targets")
  if e.pending.get("kind","")!="effect_choice":continue
  e.choose_effect(pick(e.pending.options[0],[[e.ref_target(board.youmu)]]))
  counter_ability(board,e.stack.back().duplicate(true),effect)
 var board=setup_board()
 var castle=put("field-smm-004","field",1)
 e.Pack.event(e,castle,"castle_exile",true);e.pump_choices()
 e.choose_effect(pick(e.pending.options[0],[[e.ref_target(board.youmu)]]))
 counter_ability(board,e.stack.back().duplicate(true),"exile castle trigger")

func grouped_activation_and_spells():
 var board=setup_board()
 var kanako=put("82","field",1);kanako.leader_counters=1
 var sacrifice=e.Roster.create_token(e,1,"pillar",2,["绿"])
 var choice=pick(e.activation_options(kanako,"kanako_blast")[0],[[e.ref_target(sacrifice)],[e.ref_target(board.youmu)]])
 var error=e.commit_extension(1,kanako.uid,choice,[],"kanako_blast")
 expect(error.is_empty(),"Kanako announces a real grouped activation: "+error)
 expect(sacrifice.zone=="void","Kanako pays her sacrifice before responses")
 if error.is_empty():counter_ability(board,e.stack.back().duplicate(true),"Kanako damage activation")
 for id in ["spell-fdf-071","spell-fdn-003","176","spell-fdf-078"]:
  board=setup_board()
  if id=="spell-fdf-071":put("character-fdf-117","field",1)
  elif id=="spell-fdn-003":put("21","field",1)
  elif id=="spell-fdf-078":put("character-mar-ex01","field",1)
  var spell=put(id,"hand",1);var ref=e.ref_target(board.youmu)
  var options=e.targets_for(id,1,spell.uid);var target={}
  if id=="spell-fdf-071":target=pick(options[0],[[ref]])
  elif id=="spell-fdn-003":
   for spec in options:
    if spec.get("total",-1)==5 or spec.get("selection",[]).size()==5:
     target=pick(spec,[[ref],[ref],[ref],[ref],[ref]]);break
  elif id=="176":target={"parts":[ref.duplicate(),ref.duplicate()]};target.parts[0].mode="造成2点伤害";target.parts[1].mode="横置"
  else:target=ref
  expect(not target.is_empty() and e.commit_cast(1,spell.uid,target,[]).is_empty(),id+" declares its real spell targets")
  if e.stack.is_empty():continue
  counter_ability(board,e.stack.back().duplicate(true),id)
  expect(spell.zone=="grave",id+" goes to the graveyard when countered")

func target_boundaries():
 var board=setup_board()
 var source=put("68","field",1)
 for id in ["39","token_halfghost","token-ucs-099","53"]:
  var victim=put(id)
  e.queue_trigger(1,source,1,"test damage");e.pump_choices();e.choose_trigger(e.ref_target(victim))
  var entry=e.stack.back()
  expect(offered("118",0,entry)==(id!="53"),"Six Roots recognizes the protected identity: "+id)
  e.stack.clear()
 # A stale reference must not follow a unit that leaves and returns.
 e.queue_trigger(1,source,1,"test damage");e.pump_choices();e.choose_trigger(e.ref_target(board.youmu))
 var entry=e.stack.back()
 e.move_to(board.youmu,"exile");e.move_to(board.youmu,"field")
 expect(not offered("118",0,entry),"a different field epoch is not the original targeted Youmu")
 e.stack.clear()
 for target in [{"picks":[[]]},{"player":0},{"none":true}]:
  e.push_trigger({"owner":1,"source":source,"name":"no unit target","amount":1},target)
  expect(not offered("118",0,e.stack.back()),"no unit target does not enable Six Roots: "+str(target))
  e.stack.clear()
 e.queue_trigger(0,board.youmu,1,"friendly damage");e.pump_choices();e.choose_trigger(e.ref_target(board.youmu))
 expect(not offered("118",0,e.stack.back()),"Six Roots excludes friendly abilities")

func costs_are_not_counter_targets():
 var board=setup_board()
 var source=put("68","field",1)
 # Keep the chosen cost on the field to isolate target semantics from zone validity.
 var cost=e.Cat.group(e,[board.youmu],1,1,"cost",true)
 var entry={"id":e.next_stack,"kind":"ability","owner":1,"source":source,"target":{"picks":[[e.ref_target(board.youmu)]]},"target_spec":{"selection":[cost]},"name":"cost only"}
 e.next_stack+=1;e.stack.append(entry)
 expect(not offered("118",0,entry),"a grouped cost choosing Youmu is not a target")
 expect(not offered("136",0,entry),"Heavenly Rock Boat excludes grouped costs")
 entry.erase("target_spec")
 expect(offered("118",0,entry) and offered("136",0,entry),"both counters still recognize a declared grouped unit target")

func run():
 patchouli_casts();grouped_triggers();grouped_activation_and_spells();target_boundaries();costs_are_not_counter_targets()
 print("YOUMU_COUNTER: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
