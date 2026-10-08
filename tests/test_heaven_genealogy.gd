extends "res://tests/support/catalogue_rules_base.gd"

const HEAVEN="spell-fdf-015"
const Codec=preload("res://net/state_codec.gd")

func run():
 for who in range(2):
  for existing in [0,2]:
   for count in range(3):
    fresh()
    e.players[who].leader.card_id="character-fdf-116"
    put("165","palette",who);put("167","palette",who)
    if existing>0:
     put(HEAVEN,"grave",who);put("152","grave",who)
    put("53","grave",who);put(HEAVEN,"grave",1-who)
    e.players[who].deck=[]
    for id in ["164",HEAVEN,"152","53","164","164"]:put(id,"deck",who)
    var top=e.players[who].deck.slice(0,5)
    var buried=[top[1],top[2]].slice(0,count)
    var tail=e.players[who].deck[5]
    var target=put("50","field",1-who);target.plus_counters=20
    var spell=put(HEAVEN,"hand",who)
    e.active=who;e.priority=who
    var error=e.commit_cast(who,spell.uid,e.ref_target(target),e.payment(who,e.cast_cost(who,spell)).plan)
    expect(error.is_empty(),"Genealogy commits a paid cast for seat "+str(who)+": "+error)
    one()
    expect(e.pending.get("trigger",{}).get("effect","")=="cat:heaven" and spell.zone=="grave","Genealogy waits for its top-five choice after entering grave")
    if e.pending.get("trigger",{}).get("effect","")!="cat:heaven":continue
    if who==1 and existing==2 and count==2:
     var saved=Codec.capture(e)
     e=Duel.new();Codec.restore(e,bytes_to_var(var_to_bytes(saved)))
     spell=e.find_card(spell.uid);target=e.find_card(target.uid)
    e.choose_effect(selected(e.pending.options,[buried.map(func(c):return e.Pack.ref(e,e.find_card(c.uid)))]))
    expect(target.damage==existing+count,"Genealogy counts other grave spells and 0/1/2 milled spells, excluding itself: %d / %d / %d" % [who,existing,count])
    expect(spell.zone=="grave" and e.players[who].grave.any(func(c):return c.uid==spell.uid),"Excluding Genealogy from damage keeps the spell in grave")
    expect(buried.all(func(c):return e.find_card(c.uid).zone=="grave") and e.players[who].deck[0].uid==tail.uid and e.players[who].deck.size()==6-count,"Selected spells reach grave and unchosen top cards go below the remaining library")
    expect(e.pending.is_empty() and e.stack.is_empty(),"Genealogy finishes its complete resolution")

 fresh();e.players[0].deck=[]
 var target=put("50","field",1);target.plus_counters=20
 var spell=resolve_spell(HEAVEN,e.ref_target(target))
 e.choose_effect(selected(e.pending.options,[[]]))
 expect(target.damage==0 and spell.zone=="grave" and e.pending.is_empty(),"An empty library and grave deal zero damage")

 fresh();e.players[0].deck=[]
 put(HEAVEN,"grave")
 target=put("50","field",1);target.plus_counters=20
 var copy=e.make_card(HEAVEN,0,"stack");copy.stack_copy=true;copy.token=true
 expect(Roster.spell_resolve(e,{"card":copy,"owner":0,"target":e.ref_target(target),"kind":"card"}),"A copied Genealogy begins resolution")
 e.choose_effect(selected(e.pending.options,[[]]))
 expect(copy.zone=="void" and target.damage==1,"A disappearing spell copy still counts the other same-name spell in grave")

 print("HEAVEN_GENEALOGY: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
