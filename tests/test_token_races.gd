extends "res://tests/support/rules_base.gd"

const Codec=preload("res://net/state_codec.gd")

func run():
 generated_races()
 keiki_copies()
 race_effects_and_roundtrip()
 print("TOKEN_RACES: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func generated_races():
 for spec in [["蝙蝠","妖怪"],["幻象","幻想"],["人偶","人偶"],["青蛙","青蛙"]]:
  fresh()
  var source=e.Cat.token(e,0,spec[0],1,1,1,["黑"])
  expect(e.cards[source.card_id].race==[spec[1]],"generated "+spec[0]+" has its declared race")
  var clone=e.Cat.copy_token(e,0,source)
  e.cards[clone.card_id].name="妖精"
  expect(e.Cat.race(e,clone,spec[1]) and not e.Cat.race(e,clone,"妖精"),"ordinary copy retains race independently of its name: "+spec[0])
 fresh()
 var bat=e.Roster.create_token(e,0,"bat",1,["红","黑"])
 expect(e.Cat.race(e,bat,"妖怪") and not e.Cat.race(e,bat,"蝙蝠"),"roster bat uses the printed bat's youkai race")

func keiki_copies():
 for kind in ["ordinary","printed","doll","illusion","multiple","haniwa","all","empty"]:
  fresh()
  var source={};var races=[]
  match kind:
   "printed":source=put("token-kmo-027");races=["妖怪"]
   "doll":source=e.Cat.token(e,0,"人偶",1,1,1,["黄"]);races=["人偶"]
   "illusion":source=e.Cat.token(e,0,"幻象",3,3,2,["红","黑"]);races=["幻想"]
   _:
    source=put("53")
    races={"ordinary":["山童"],"multiple":["人类","妖怪"],"haniwa":["埴轮"],"all":["全部"],"empty":[]}[kind]
    e.cards[source.card_id]=e.cards[source.card_id].duplicate(true)
    e.cards[source.card_id].race=races.duplicate()
  enter("45")
  expect(e.pending.get("kind","")=="effect_choice" and e.pending.trigger.effect=="keiki_copy","Keiki offers its real entry choice: "+kind)
  e.choose_effect(e.ref_target(source));one()
  var copies=e.units(0).filter(func(c):return e.cards[c.card_id].get("copy_marker","")=="keiki")
  expect(copies.size()==1,"Keiki creates one copy: "+kind)
  if copies.is_empty():continue
  var idol=copies[0];var info=e.cards[idol.card_id]
  expect(info.name=="偶像" and idol.token,"Keiki keeps the Idol name and token identity: "+kind)
  expect(info.race==races,"Keiki preserves the exact source races without adding or replacing any: "+kind)
  expect(e.Cat.race(e,idol,"埴轮")==e.Cat.race(e,source,"埴轮"),"Keiki grants no extra haniwa race: "+kind)
  expect(e.cards[source.card_id].race==races,"Keiki leaves the source races intact: "+kind)
  info.race.append("测试种族")
  expect(e.cards[source.card_id].race==races,"copy has an independent race array: "+kind)

func race_effects_and_roundtrip():
 fresh()
 var observer=put("character-fdn-013");var source=put("character-fdn-006")
 var before=e.stat(observer,"power");var idol=e.Roster.copy_idol(e,0,source)
 expect(e.stat(observer,"power")==before+1,"Idol's copied fairy race participates in the forest fairy's real race-based bonus")
 var doll=e.Cat.token(e,0,"人偶",1,1,1,["黄"])
 var doll_copy=e.Roster.copy_idol(e,0,doll)
 e.players[0].dolls_free=true
 expect(e.Extra.keyword(e,doll_copy,"不占战场格"),"Idol's copied doll race receives the doll slot exemption")
 var graph=Codec.capture(e);e=Duel.new();Codec.restore(e,graph)
 idol=e.find_card(idol.uid);doll_copy=e.find_card(doll_copy.uid)
 expect(e.cards[idol.card_id].race==["妖精"] and e.cards[doll_copy.card_id].race==["人偶"],"network/save roundtrip preserves copied token races")
 expect(e.stat(e.find_card(observer.uid),"power")==before+1 and e.Extra.keyword(e,doll_copy,"不占战场格"),"race-based effects still apply after restoring state")
