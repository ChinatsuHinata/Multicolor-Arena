extends "res://tests/support/rules_base.gd"

func fill_slots(n: int):
 e.cards["slot_filler"]=e.cards["roster_token_imp"].duplicate(true);e.cards["slot_filler"].token=false
 for i in range(n):put("slot_filler")

func activity():
 var c=put("113");c.timer=4

func activity_count() -> int:
 return e.triggers.filter(func(t):return t.effect=="activity_draw").size()

func tokens_named(name: String) -> Array:
 return e.units(0).filter(func(c):return c.get("token",false) and e.cards[c.card_id].name.trim_suffix("衍生物")==name)

func resolve_spell(id: String,x: int=0):
 var c=e.make_card(id,0,"stack")
 expect(e.Roster.spell_resolve(e,{"card":c,"owner":0,"target":{"none":true,"x":x}}),"resolve token spell: "+id)
 return c

func dolls():
 var alice=e.units(0).filter(func(c):return c.card_id=="character-fdf-112")[0]
 e.Cat.resolve_activation(e,{"owner":0,"source":alice.duplicate(true),"effect":"character-fdf-112","target":{"none":true,"mode":"创造两个人偶"}})

func run():
 for creator in ["generated","printed","copied"]:
  for shortage in [true,false]:
   fresh();activity();fill_slots(6 if shortage else 5)
   var before=e.field_slots(0);var made={}
   match creator:
    "generated":made=e.Cat.token(e,0,"蝙蝠",1,1,1,["红","黑"])
    "printed":made=e.Cat.printed_token(e,0,"roster_token_bat")
    "copied":
     var template=e.make_card("roster_token_bat",0,"token");template.plus_counters=2
     made=e.Cat.copy_token(e,0,template)
   expect(made.is_empty()==shortage,"single token creation checks capacity before entry: "+creator+" shortage="+str(shortage))
   expect(e.players[0].grave.is_empty() and e.players[0].exile.is_empty(),"failed single tokens do not remain in other zones: "+creator)
   expect(e.field_slots(0)==before+(0 if shortage else 1) and activity_count()==(0 if shortage else 1),"only successful single tokens occupy a slot and trigger entry observers: "+creator)
   if creator=="copied" and not shortage:expect(made.plus_counters==2,"single token copy preserves requested counters")

 for spec in [["129",2,"蝙蝠"],["spell-fdf-037",4,"蝙蝠"],["spell-fdf-058",3,"吸血鬼"],["spell-fdf-062",2,"鬼"]]:
  for shortage in [true,false]:
   fresh();activity();fill_slots(6-int(spec[1])+(1 if shortage else 0))
   var before=e.field_slots(0);var card=resolve_spell(spec[0]);var made=tokens_named(spec[2])
   expect(made.size()==(0 if shortage else int(spec[1])),"token spell creates its whole batch or none: "+str(spec)+" shortage="+str(shortage))
   expect(e.field_slots(0)==before+made.size(),"batch respects remaining slots: "+spec[0])
   expect(activity_count()==0,"same-name spell batch does not trigger Activity: "+spec[0])
   expect(e.players[0].grave.size()==1 and card.zone=="grave","failed tokens do not leave ghost cards in grave: "+spec[0])
   if spec[0]=="129" and not shortage:
    expect(made.all(func(c):return c.card_id=="token-kmo-027" and c.token and e.Pack.colors(e,c)==["红","黑"]),"Wings creates the printed red-black bat tokens")
    expect(made.all(func(c):return e.stat(c,"power")==1 and e.stat(c,"health")==1 and e.stat(c,"spirit")==1 and e.cards[c.card_id].race==["妖怪"]),"Wings bats retain the printed 1/1/1 stats and race")
    expect(made.all(func(c):return e.cards[c.card_id].image=="res://recourse/数据库/token-kmo-027.jpg"),"Wings bats use the correct bat artwork")
   if spec[0] in ["spell-fdf-037","spell-fdf-058"]:
    expect(e.delayed.size()==made.size(),"only entered tokens receive sacrifice delays: "+spec[0])
   elif spec[0]=="spell-fdf-062":
    expect(made.all(func(c):return c.get("imp_growth",false)),"all created oni receive their growth ability")

 for shortage in [true,false]:
  fresh();activity();put("character-fdf-112");fill_slots(4 if shortage else 3)
  dolls()
  expect(tokens_named("人偶").size()==(0 if shortage else 2),"Alice makes two dolls or none, shortage="+str(shortage))
  expect(activity_count()==0,"same-name ability batch does not trigger Activity")

 fresh();activity();put("character-fdf-112");fill_slots(5);e.players[0].dolls_free=true
 dolls()
 expect(tokens_named("人偶").size()==2 and e.field_slots(0)==6,"dolls made slot-free by an effect still enter on a full field")
 expect(activity_count()==0,"slot-free doll batch does not trigger Activity")

 fresh();activity();put("character-fdf-104");fill_slots(5)
 resolve_spell("spell-fdf-037")
 expect(tokens_named("蝙蝠").size()==4 and e.field_slots(0)==6,"token slot exemption applies before testing batch capacity")
 expect(activity_count()==0 and e.delayed.size()==4,"exempt batch keeps delays and avoids Activity")

 fresh();activity();put("character-ucs-053");fill_slots(6)
 resolve_spell("129")
 expect(tokens_named("蝙蝠").size()==2 and e.field_slots(0)==9,"batch honors an increased battlefield limit")

 fresh();activity();fill_slots(6)
 resolve_spell("151",3)
 expect(tokens_named("青蛙").size()==3 and e.field_slots(0)==6,"intrinsically slot-free frog batch enters on a full field")
 expect(activity_count()==0,"same-name slot-free frog batch does not trigger Activity")

 fresh();activity()
 var observer=put("164")
 e.Roster.resolve_trigger(e,{"owner":0,"source":observer.duplicate(true),"effect":"kanako_cast","target":{"none":true}})
 expect(tokens_named("御柱").size()==4 and activity_count()==0,"four pillars from an ability enter simultaneously")

 fresh();activity()
 e.Cat.Units.resolve(e,{"owner":0,"source":e.players[0].leader.duplicate(true),"effect":"character-ucs-023","target":{"none":true}})
 expect(tokens_named("飞头").size()==3 and activity_count()==0,"three flying heads from an ability enter simultaneously")

 fresh();activity()
 e.Cat.token(e,0,"蝙蝠",1,1,1,["红","黑"])
 expect(activity_count()==1,"a single newly named token still triggers Activity")
 e.triggers.clear();e.Cat.token(e,0,"蝙蝠",1,1,1,["红","黑"])
 expect(activity_count()==0,"a later same-name token does not trigger Activity")

 for shortage in [true,false]:
  fresh();activity();fill_slots(5 if shortage else 4)
  var a=put("roster_token_bat","exile");var b=put("roster_token_bat","exile")
  e.Cat.Spells.resolve_choice(e,{"owner":0,"effect":"cat:copy_exile","target":{"picks":[[e.Cat.ref(e,a),e.Cat.ref(e,b)]]}})
  expect(tokens_named("蝙蝠").size()==(0 if shortage else 2),"multiple copied tokens form one batch, shortage="+str(shortage))
  expect(activity_count()==0 and a.zone=="exile" and b.zone=="exile","copy batch leaves originals in exile and does not trigger Activity")

 print("TOKEN_CREATION: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
