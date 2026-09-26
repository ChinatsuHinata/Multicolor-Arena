extends "res://tests/support/catalogue_rules_base.gd"

func option_for(options: Array,color: String) -> int:
 for i in range(options.size()):
  if options[i].get("ignore_color","")==color:return i
 return -1

func run():
 fresh();mana();put("character-fdf-ex02")
 var first=put("50","field",1);var second=put("51","field",1)
 var old=put("52","exile",1)
 var spell=put("spell-fdf-082","hand")
 var options=e.targets_for(spell.card_id,0,spell.uid)
 expect(options.size()==3,"FDF-082 offers no ignored color, blue, and yellow")
 var no=choose_groups(options,[[e.ref_target(first),e.ref_target(second)]],option_for(options,"无"))
 expect(e.cast_cost(0,spell,no).get("蓝",0)==8 and e.cast_cost(0,spell,no).get("黄",0)==7,"no ignored color keeps both costs")
 expect(e.commit_cast(0,spell.uid,no,e.payment(0,e.cast_cost(0,spell,no)).plan).is_empty(),"FDF-082 casts without ignoring a color")
 one()
 expect(first.zone=="exile" and second.zone=="exile" and e.pending.get("kind","")=="effect_choice","no ignored color exiles two targets and offers copies")
 var copy=choose_groups(e.pending.options,[[Pack.ref(e,first),Pack.ref(e,old)]])
 e.choose_effect(copy);settle()
 expect(e.units(0).filter(func(u):return u.token).size()==2 and e.units(0).any(func(u):return u.token and e.cards[u.card_id].get("copy_source_id","")==old.card_id),"no ignored color creates chosen copies from the exile zone")

 fresh();mana();put("character-fdf-ex02")
 var victim=put("50","field",1);old=put("52","exile",1)
 var spell_blue=put("spell-fdf-082","hand")
 options=e.targets_for(spell_blue.card_id,0,spell_blue.uid)
 var blue=choose_groups(options,[[]],option_for(options,"蓝"))
 expect(e.cast_cost(0,spell_blue,blue).get("蓝",-1)==-1 and e.cast_cost(0,spell_blue,blue).get("黄",0)==7,"ignoring blue removes only the blue cost")
 expect(e.commit_cast(0,spell_blue.uid,blue,e.payment(0,e.cast_cost(0,spell_blue,blue)).plan).is_empty(),"FDF-082 casts while ignoring blue")
 one()
 expect(victim.zone=="field" and e.pending.get("kind","")=="effect_choice","ignoring blue leaves units in play and offers copies")
 copy=choose_groups(e.pending.options,[[Pack.ref(e,old)]])
 e.choose_effect(copy);settle()
 expect(e.units(0).any(func(u):return u.token and e.cards[u.card_id].get("copy_source_id","")==old.card_id),"ignoring blue creates a copy from the exile zone")

 fresh();mana();put("character-fdf-ex02")
 first=put("50","field",1);second=put("51","field",1)
 var spell_yellow=put("spell-fdf-082","hand")
 options=e.targets_for(spell_yellow.card_id,0,spell_yellow.uid)
 var yellow=choose_groups(options,[[e.ref_target(first),e.ref_target(second)]],option_for(options,"黄"))
 expect(e.cast_cost(0,spell_yellow,yellow).get("黄",-1)==-1 and e.cast_cost(0,spell_yellow,yellow).get("蓝",0)==8,"ignoring yellow removes only the yellow cost")
 expect(e.commit_cast(0,spell_yellow.uid,yellow,e.payment(0,e.cast_cost(0,spell_yellow,yellow)).plan).is_empty(),"FDF-082 casts while ignoring yellow")
 settle()
 expect(first.zone=="exile" and second.zone=="exile" and e.units(0).filter(func(u):return u.token).is_empty(),"ignoring yellow exiles targets without creating copies")
 print("FDF082: ",checks," checks; ",failures," failures")
 quit(1 if failures else 0)
