extends "res://tests/support/rules_base.gd"
const Mask=preload("res://scripts/rules/mask_abilities.gd")

func fixture(who: int,id: String="82",slots: int=6) -> Array:
 fresh();e.active=who;e.priority=who;e.phase="main";e.passes=0
 var source=put(id,"field",who);var fillers=[]
 for i in range(slots-1):fillers.append(put("53","field",who))
 return [source,fillers]

func announce(who: int,effect: String):
 one()
 expect(e.phase=="end" and e.pending.get("trigger",{}).get("effect","")==effect,"end ability is offered even when full, seat "+str(who)+" "+effect)
 if e.pending.get("trigger",{}).get("effect","")!=effect:return
 e.choose_effect({"none":true})
 expect(e.stack.size()==1 and e.stack.back().get("effect","")==effect,"accepted ability enters stack before checking capacity")

func tokens(who: int,kind: String) -> Array:
 return e.units(who).filter(func(c):return c.get("token",false) and e.Roster.race(e,c,kind))

func phase_case(who: int,mode: String):
 var slots=5 if mode in ["space","fill"] else 6
 var scene=fixture(who,"82",slots);var fillers=scene[1]
 announce(who,"kanako_pillar")
 if e.stack.is_empty():return
 if mode=="fill":put("53","field",who)
 if mode=="free":e.move_to(fillers[0],"hand")
 var graves=e.players[who].grave.duplicate(true)
 one()
 var allowed=mode in ["space","free"]
 expect(tokens(who,"御柱").size()==(1 if allowed else 0),mode+" produces pillar exactly when a slot exists, seat "+str(who))
 expect(e.players[who].grave==graves,mode+" leaves grave untouched by attempted creation")
 expect(not e.stack.any(func(t):return str(t.get("effect","")).contains("death")) and not e.triggers.any(func(t):return str(t.get("effect","")).contains("death")),mode+" does not generate a death trigger")
 if allowed:
  var token=tokens(who,"御柱")[0]
  expect(e.stat(token,"power")==2 and e.stat(token,"health")==2 and e.stat(token,"spirit")==1 and e.Extra.keyword(e,token,"英勇"),"created pillar matches printed values")
 else:expect(e.field_slots(who)==6,mode+" leaves six occupied slots")

func exempt_and_extra():
 for who in [0,1]:
  fixture(who,"82",5)
  var ghost=e.Roster.create_token(e,who,"ghost",1,["黄"])
  expect(not ghost.is_empty() and e.field_slots(who)==5,"slot-free unit does not fill the remaining space")
  announce(who,"kanako_pillar");one()
  expect(tokens(who,"御柱").size()==1 and e.field_slots(who)==6,"pillar uses the still-free slot")
  fresh();e.active=who;e.priority=who
  put("82","field",who);put("character-ucs-053","field",who)
  for i in range(6):put("53","field",who)
  expect(e.field_slots(who)==8 and e.Cat.field_limit(e,who)==9,"slot expansion permits nine units")
  announce(who,"kanako_pillar");one()
  expect(tokens(who,"御柱").size()==1 and e.field_slots(who)==9,"pillar respects increased capacity")

func other_end_ability():
 for who in [0,1]:
  fixture(who,"62",6);announce(who,"seiga_imp")
  var before=e.players[who].grave.duplicate(true);one()
  expect(tokens(who,"小鬼").is_empty() and e.players[who].grave==before,"Seiga's imp at capacity never goes to grave")

func direct_entry_paths():
 for who in [0,1]:
  for path in ["roster","idol","precon","extension","mask"]:
   for full in [true,false]:
    fixture(who,"82",6 if full else 5)
    var before=e.players[who].grave.duplicate(true);var fields=e.players[who].field.size()
    match path:
     "roster":e.Roster.create_token(e,who,"pillar",2,["绿"])
     "idol":e.Roster.copy_idol(e,who,e.players[who].field[1])
     "precon":e.Pack.token(e,who,"token-ucs-099")
     "extension":e.Extra.create_token(e,who,"token_ufo")
     "mask":Mask.mask(e,who,"031")
    var is_item=path=="mask"
    expect(e.players[who].grave==before,path+" does not put a failed token in grave")
    expect(e.players[who].field.size()==fields+(1 if not full or is_item else 0),path+" obeys capacity by token type")
    expect(not e.triggers.any(func(t):return str(t.get("effect","")).contains("death")),path+" does not create death triggers")

func roster_batch():
 for who in [0,1]:
  for enough in [false,true]:
   fixture(who,"82",3 if enough else 4)
   var before=e.players[who].grave.duplicate(true)
   var made=e.Roster.create_tokens(e,who,3,"pillar",2,["绿"])
   expect(made.size()==(3 if enough else 0),"pillar batch creates all or none according to capacity")
   expect(tokens(who,"御柱").size()==made.size() and e.players[who].grave==before,"failed batch leaves no grave cards")
  fixture(who,"82",6)
  var free=e.Roster.create_tokens(e,who,3,"ghost",1,["黄"])
  expect(free.size()==3 and e.field_slots(who)==6,"batch of slot-free units enters when full")

func non_token_entry_stays_unchanged():
 for who in [0,1]:
  fixture(who,"82",6)
  var card=put("53","hand",who)
  expect(not e.enter_field(card,who) and card.zone=="grave" and card in e.players[who].grave,"a non-token card that cannot enter still goes to grave")

func run():
 for who in [0,1]:
  for mode in ["full","space","fill","free"]:phase_case(who,mode)
 exempt_and_extra();other_end_ability();direct_entry_paths();roster_batch();non_token_entry_stays_unchanged()
 print("PILLAR FULL FIELD: %d checks; %d failures" % [checks,failures.size()]);quit(0 if failures.is_empty() else 1)
