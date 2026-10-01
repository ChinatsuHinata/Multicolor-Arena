extends "res://tests/support/catalogue_rules_base.gd"

const Codec=preload("res://net/state_codec.gd")

func seed_counters(c: Dictionary):
 for i in range(e.Cat.COUNTER_KEYS.size()):c[e.Cat.COUNTER_KEYS[i]]=i+1
 c.color_counters=["红","绿","红"]

func copied_state(copy: Dictionary,source: Dictionary,title: String):
 expect(not copy.is_empty(),title+": copy exists")
 if copy.is_empty():return
 for key in e.Cat.COUNTER_KEYS:expect(int(copy.get(key,0))==int(source.get(key,0)),title+": "+key)
 expect(copy.get("color_counters",[])==source.get("color_counters",[]),title+": colored counters retain colors, order and multiplicity")
 expect(not copy.has("copy_entry_counters"),title+": entry snapshot is consumed")

func run():
 single_and_batch()
 actual_abilities()
 transform()
 entry_and_cleanup()
 spell_copies()
 print("COPY_COUNTERS: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func single_and_batch():
 fresh()
 var source=put("53");seed_counters(source)
 var clone=e.Cat.copy_token(e,0,source)
 copied_state(clone,source,"ordinary token copy")
 var source_colors=source.color_counters.duplicate();clone.color_counters.append("黑")
 clone.minus_counters+=1
 expect(source.color_counters==source_colors and source.minus_counters==3,"copy and source have independent counter state")
 fresh();source=put("53");seed_counters(source)
 var second=put("53");second.minus_counters=1;second.courage=2
 var copies=e.Cat.copy_tokens(e,0,[source,second],"yukari")
 expect(copies.size()==2,"batch copy creates both recipients")
 if copies.size()==2:
  copied_state(copies[0],source,"first batch copy")
  copied_state(copies[1],second,"second batch copy")
  expect(copies.all(func(c):return e.cards[c.card_id].copy_marker=="yukari"),"batch copies retain their effect marker")
 fresh();source=put("53");seed_counters(source);e.move_to(source,"exile")
 e.Cat.Spells.resolve_choice(e,{"owner":0,"effect":"cat:copy_exile","target":{"picks":[[e.Cat.ref(e,source)]]}})
 copies=e.units(0).filter(func(c):return c.get("token",false))
 expect(copies.size()==1 and e.Cat.counter_total(e,copies)==0,"copying an exiled card does not recreate counters already lost on its zone change")

func actual_abilities():
 fresh()
 var source=put("53");seed_counters(source)
 enter("45")
 e.choose_effect(e.ref_target(source));one()
 var copies=e.units(0).filter(func(c):return c.get("token",false))
 if not copies.is_empty():copied_state(copies[0],source,"Keiki entry ability")
 else:expect(false,"Keiki entry ability creates its copy")

 fresh()
 var fairy=put("character-fdn-006");seed_counters(fairy)
 var discard=put("53","hand");put("164","palette")
 var choice=choose_groups(e.activation_options(fairy,"character-fdn-006"),[[e.Cat.ref(e,discard)]])
 expect(e.commit_extension(0,fairy.uid,choice,e.payment(0,{"黄":1}).plan,"character-fdn-006").is_empty(),"mountain fairy actually pays and activates its copy ability")
 one();copies=e.units(0).filter(func(c):return c.get("token",false))
 if not copies.is_empty():copied_state(copies[0],fairy,"mountain fairy activation")
 else:expect(false,"mountain fairy activation creates its copy")
 expect(fairy.tapped and discard.zone=="grave","copying counters does not copy or change the ability's tap and discard costs")

 fresh();fairy=put("character-fdn-006");seed_counters(fairy)
 var snapshot=fairy.duplicate(true);discard=put("53","hand");put("164","palette")
 choice=choose_groups(e.activation_options(fairy,"character-fdn-006"),[[e.Cat.ref(e,discard)]])
 expect(e.commit_extension(0,fairy.uid,choice,e.payment(0,{"黄":1}).plan,"character-fdn-006").is_empty(),"mountain fairy activates before leaving in response")
 e.move_to(fairy,"grave");one();copies=e.units(0).filter(func(c):return c.get("token",false))
 if not copies.is_empty():copied_state(copies[0],snapshot,"copying the departed fairy's last known state")
 else:expect(false,"departed fairy's activation creates its copy")
 expect(e.Cat.counter_total(e,[fairy])==0,"last known copying does not restore counters on the departed original")

 fresh()
 var tokiko=put("character-htk-002");var item=put("164");seed_counters(item)
 expect(e.commit_extension(0,tokiko.uid,e.Cat.ref(e,item),[],"tokiko_copy").is_empty(),"Tokiko actually activates its item-copy ability")
 one();copies=e.players[0].field.filter(func(c):return c.get("token",false))
 if not copies.is_empty():copied_state(copies[0],item,"Tokiko item copy")
 else:expect(false,"Tokiko activation creates its item copy")
 expect(e.delayed.size()==1 and e.delayed[0].effect=="token_sacrifice","Tokiko's copied item retains its delayed sacrifice")

func transform():
 fresh();mana();put("character-fdf-112")
 var source=put("53");seed_counters(source)
 var doll=e.Cat.token(e,0,"人偶",1,1,1,["黄"]);doll.plus_counters=30;doll.scare=50;doll.color_counters=["蓝"]
 var doll_name=e.cards[doll.card_id].name;var epoch=doll.epoch
 var choice=choose_groups(e.targets_for("spell-ucs-057",0),[[e.Cat.ref(e,doll)],[e.Cat.ref(e,source)]])
 cast("spell-ucs-057",choice)
 copied_state(doll,source,"Alice's in-place unit copy")
 expect(e.cards[doll.card_id].name==doll_name and doll.epoch==epoch,"in-place copying keeps the recipient's name and zone identity")
 expect(doll.plus_counters==2 and doll.scare==6 and doll.color_counters==["红","绿","红"],"source counters replace rather than add to the recipient's original counters")
 var empty=put("53")
 e.Cat.copy_unit(e,doll,empty,true,"alice")
 expect(e.Cat.counter_total(e,[doll])==0,"copying a counter-free source removes every original counter type")

func entry_and_cleanup():
 fresh()
 var source=put("character-fdf-ex03");source.plus_counters=3;source.minus_counters=1;source.color_counters=["红"]
 var clone=e.Roster.copy_idol(e,0,source)
 var triggers=e.triggers.filter(func(t):return t.source.uid==clone.uid and t.effect=="byakuren_x")
 expect(triggers.size()==1 and triggers[0].source.plus_counters==3 and triggers[0].source.minus_counters==1 and triggers[0].source.color_counters==["红"],"entry observers capture the copy after all copied counters are present")
 expect(e.stat(clone,"health")==4,"copied counters affect health immediately on entry")
 e.move_to(clone,"grave")
 expect(e.Cat.counter_total(e,[clone])==0 and not clone.has("copy_entry_counters"),"a copy loses counters and its consumed snapshot when it leaves")

 fresh();put("character-lof-003");source=put("53");source.minus_counters=1
 clone=e.Cat.copy_token(e,0,source)
 expect(clone.minus_counters==1,"copying reproduces the original amount even with Sanae present")
 e.Roster.Batch.counter(e,clone,"minus_counters",1,0)
 expect(clone.minus_counters==3,"later counter placement still uses Sanae's normal replacement")

 fresh();source=put("53");source.plus_counters=2;source.minus_counters=2
 clone=e.Cat.copy_token(e,0,source);e.judge()
 expect(clone.zone=="field" and e.stat(clone,"health")==2,"state checks see positive and negative copied counters together")
 fresh();source=put("53");source.minus_counters=2
 clone=e.Cat.copy_token(e,0,source);e.judge()
 expect(clone.zone=="void","a copy with lethal negative counters dies at the next state check")

 fresh();source=put("53");seed_counters(source)
 clone=e.Cat.copy_token(e,0,source);var graph=Codec.capture(e);e=Duel.new();Codec.restore(e,graph)
 copied_state(e.find_card(clone.uid),e.find_card(source.uid),"network state roundtrip")

func spell_copies():
 for path in ["catalogue","dream"]:
  fresh()
  var source=e.make_card("spell-fdn-032",0,"stack");seed_counters(source)
  var original={"id":e.next_stack,"kind":"card","card":source,"owner":0,"target":{"none":true},"name":e.cards[source.card_id].name}
  if path=="catalogue":
   e.Cat.copy_spell(e,original)
   expect(not e.pending.is_empty(),"catalogue spell copying offers its target choice")
   e.choose_effect(e.pending.options[0])
  else:
   e.Roster.New.resolve_trigger(e,{"effect":"n21:copy_finish","owner":0,"source":source.duplicate(true),"target":{"none":true},"data":{"entry":original,"remaining":1}})
  expect(e.stack.size()==1 and e.stack[0].get("copy",false),path+" creates its actual spell copy")
  if e.stack.is_empty():continue
  var clone=e.stack[0].card
  expect(e.Cat.counter_snapshot(clone)==e.Cat.counter_snapshot(source),path+" copies every counter type while on the stack")
  var removed=e.Cat.counter_refs(e,[clone]).filter(func(r):return r.counter in ["minus_counters","timer"] and r.counter_index==0)
  e.Cat.remove_counters(e,removed)
  expect(clone.minus_counters==source.minus_counters-1 and clone.timer==source.timer-1,path+" allows copied counters to be removed independently before entry")
  one()
  expect(clone.zone=="field",path+" spell copy actually resolves onto the battlefield")
  for key in e.Cat.COUNTER_KEYS:
   var expected=int(source.get(key,0))+(int(e.cards[source.card_id].time) if key=="timer" else 0)-(1 if key in ["minus_counters","timer"] else 0)
   expect(int(clone.get(key,0))==expected,path+" retains copied "+key+" while its entry ability adds normal counters")
  expect(clone.color_counters==source.color_counters and not clone.has("copy_entry_counters"),path+" keeps independent colored counters and consumes the entry snapshot")
