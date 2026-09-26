extends "res://tests/support/rules_base.gd"
const Hints=preload("res://scripts/rules/card_condition_hints.gd")
const View=preload("res://scripts/duel_view.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
var v
func run():
 fresh();v=View.new();v.engine=e
 var hatate=put("character-fdf-105","hand")
 expect(not Hints.active(e,hatate),"Hatate does not qualify with a three-cost deck leader")
 e.players[0].leader=e.make_card("character-fdn-025",0,"leader",true)
 expect(Hints.active(e,hatate) and e.cast_cost(0,hatate).values().reduce(func(a,b):return a+b,0)==3,"Hatate qualifies at leader cost five and the actual cast costs three")
 fresh();v.engine=e
 var rain=put("spell-ucs-050","hand");var ominous=put("spell-fdn-009","hand")
 for i in range(3):put("53","grave")
 expect(not Hints.active(e,ominous),"Ominous is inactive below four grave cards")
 put("53","grave")
 expect(Hints.active(e,ominous),"Ominous qualifies at four grave cards")
 for i in range(5):put("53","grave")
 expect(not Hints.active(e,rain),"Rainbow Drizzle is inactive below ten grave cards")
 put("53","grave")
 expect(Hints.active(e,rain),"Rainbow Drizzle qualifies at ten grave cards")
 fresh();v.engine=e
 var reimu=put("character-rei-001","hand")
 for i in range(3):put("spell-rei-011","palette")
 expect(not Hints.active(e,reimu),"ordinary Reimu stays inactive despite three role spells without her leader ability")
 reimu.leader=true
 expect(Hints.active(e,reimu),"deck leader Reimu qualifies with three role spells")
 reimu.leader=false
 var shrine=put("170")
 expect(Hints.active(e,reimu),"Reimu in hand can preview the leader ability granted on entry by Hakurei Shrine")
 e.enter_field(reimu,0)
 expect(Hints.active(e,reimu) and e.has_haste(reimu),"field Reimu's red condition agrees with her actual shrine-granted haste")
 e.move_to(shrine,"grave")
 expect(not Hints.active(e,reimu) and not e.has_haste(reimu),"removing the shrine clears Reimu's hint and actual conditional haste")
 var ornament=put("item-ucs-013")
 e.Cat.Units.resolve_activation(e,{"owner":0,"source":ornament,"effect":"item-ucs-013","target":{"none":true}})
 expect(Hints.active(e,reimu) and e.has_haste(reimu),"activating the hair ornament enables Reimu's conditional ability this turn")
 e.turn+=1
 expect(not Hints.active(e,reimu),"hair ornament's hint expires with the turn")
 reimu.leader_counters=1
 expect(Hints.active(e,reimu),"a leader counter also enables Reimu's conditional ability")
 e.players[0].palette.pop_back()
 expect(not Hints.active(e,reimu),"Reimu does not qualify with only two palette role spells")
 fresh();v.engine=e
 var murasa=put("character-fdf-100")
 e.players[1].deck=e.players[1].deck.slice(0,21)
 expect(not Hints.active(e,murasa),"Murasa is inactive at twenty-one opposing library cards")
 e.players[1].deck.pop_back()
 expect(Hints.active(e,murasa),"Murasa qualifies at twenty opposing library cards")
 var victim=put("53","field",1)
 e.Cat.Units.resolve(e,{"owner":0,"source":murasa,"effect":"character-fdf-100","target":{"none":true}})
 expect(victim.minus_counters==1,"Murasa's indicated end-step condition produces the actual counter")
 fresh();v.engine=e
 var mokou=put("character-fdn-004","hand")
 e.players[0].life=10
 expect(not Hints.active(e,mokou),"ordinary Mokou without her leader ability is not marked at low life")
 mokou.leader=true;e.players[0].life=11
 expect(not Hints.active(e,mokou),"leader Mokou is inactive above ten life")
 e.players[0].life=10
 expect(Hints.active(e,mokou) and e.cast_cost(0,mokou).values().reduce(func(a,b):return a+b,0)==2,"leader Mokou qualifies at ten life and really receives the cost discount")
 fresh();v.engine=e
 var fairy=put("1","hand");var fairy_leader=put("80","hand");var other=put("53","hand")
 expect(not Hints.active(e,fairy),"a fairy has no first-entry hint without the anthem")
 var anthem=put("spell-lof-006")
 expect(Hints.active(e,fairy) and Hints.active(e,fairy_leader) and not Hints.active(e,other),"anthem marks the next fairy unit or leader but excludes non-fairies")
 e.enter_field(fairy,0)
 expect(not Hints.active(e,fairy_leader),"entering a real fairy consumes the first-entry opportunity")
 e.turn+=1
 expect(Hints.active(e,fairy_leader),"the first-entry opportunity returns next turn")
 e.move_to(anthem,"grave")
 expect(not Hints.active(e,fairy_leader),"removing the anthem clears the opportunity")
 e.players[0].next_fairy_leader=e.turn
 expect(Hints.active(e,fairy_leader) and not Hints.active(e,other),"fairy princess marks only the next fairy leader")
 var ordinary_fairy=put("1","hand")
 expect(not Hints.active(e,ordinary_fairy),"fairy princess does not mark non-leader fairy units")
 e.Cat.Units.on_cast(e,other,0,"hand")
 expect(Hints.active(e,fairy_leader),"a non-leader cast does not consume fairy princess's opportunity")
 var nonfairy_leader=put("character-rei-001","hand")
 e.Cat.Units.on_cast(e,nonfairy_leader,0,"hand")
 expect(not Hints.active(e,fairy_leader),"a non-fairy leader cast consumes the next-leader opportunity under the actual rules")
 fresh();v.engine=e;put("character-lof-002")
 var princess=e.players[0].field[0]
 e.Cat.Units.resolve(e,{"owner":0,"source":princess,"effect":"character-lof-002","target":{"none":true}})
 fairy_leader=put("80","hand")
 expect(princess.owner==1 and Hints.active(e,fairy_leader) and e.cast_cost(0,fairy_leader).is_empty(),"real fairy princess transfer produces the indicated free fairy-leader cast")
 fresh();v.engine=e;e.debug_enabled=true;e.debug_free_payment=true;put("character-fdf-ex02")
 var curse=put("spell-fdf-014","hand")
 expect(Hints.curse_count(e,0)==0 and Hints.curse_count(e,1)==0,"curse warning starts absent for both players")
 expect(e.commit_cast(0,curse.uid,{"none":true},[]).is_empty(),"Yukari curse commits a real cast")
 expect(Hints.curse_count(e,1)==0,"curse warning is absent while the spell has not resolved")
 one()
 expect(Hints.curse_count(e,1)==1 and Hints.curse_count(e,0)==0,"resolved curse marks only the affected opponent")
 e.move_to(curse,"exile")
 expect(Hints.curse_count(e,1)==1,"permanent curse warning survives moving the source out of the grave")
 e.enter_field(put("53","hand",1),1);settle()
 expect(e.players[1].life==18,"curse warning agrees with the actual two-life loss on unit entry")
 for seat in range(2):
  var remote=Remote.new();remote.apply_snapshot(SeatView.build(e,seat))
  expect(Hints.curse_count(remote,1)==1 and Hints.curse_count(remote,0)==0,"network curse warning uses the affected seat "+str(seat))
 var observer=Remote.new();observer.apply_snapshot(Observer.build(e))
 expect(Hints.curse_count(observer,1)==1,"spectator receives the persistent curse state")
 e.players[1].etb_curse=2
 expect(Hints.curse_caption(e,0).contains("4 点"),"stacked curses display the combined incoming life loss")
 fresh();v.engine=e;mana();put("68")
 var moon=put("spell-mar-012","hand");put("spell-mar-012","grave");put("spell-mar-012","grave")
 expect(v.damage_caption(moon).begins_with("预计抽牌：3 张"),"Shoot the Moon previews grave copies plus one")
 var spec=e.targets_for(moon.card_id,0,moon.uid)[0].duplicate(true);spec.erase("selection");spec.picks=[[]]
 var moon_error=e.commit_cast(0,moon.uid,spec,e.payment(0,e.cast_cost(0,moon)).plan)
 expect(moon_error.is_empty(),"Shoot the Moon commits a real cast without a damage target: "+moon_error)
 if not moon_error.is_empty():v.free();quit(1);return
 expect(v.damage_caption(moon).begins_with("预计抽牌：3 张"),"Shoot the Moon on stack does not count itself before resolution")
 put("spell-mar-012","grave")
 expect(v.damage_caption(moon).begins_with("预计抽牌：4 张"),"Shoot the Moon responds to new grave copies during the response window")
 for seat in range(2):
  var remote=Remote.new();remote.apply_snapshot(SeatView.build(e,seat));v.engine=remote
  expect(v.damage_caption(remote.find_card(moon.uid)).begins_with("预计抽牌：4 张"),"network Shoot the Moon preview agrees for seat "+str(seat))
 v.engine=e;one()
 expect(e.players[0].hand.size()==4,"Shoot the Moon draws the exact previewed number before moving itself to grave")
 moon=put("spell-mar-012","hand");e.players[0].deck=e.players[0].deck.slice(0,2)
 expect(v.damage_caption(moon).begins_with("预计抽牌：2 张") and v.damage_caption(moon).contains("需抓 5 张"),"Shoot the Moon labels insufficient library and only promises available draws")
 e.players[0].deck=[]
 expect(v.damage_caption(moon).begins_with("预计抽牌：0 张"),"Shoot the Moon never predicts a successful draw from an empty library")
 var hidden=e.make_card("spell-mar-012",1,"hand");hidden.network_hidden=true
 expect(v.damage_caption(hidden).is_empty() and not Hints.active(e,hidden),"hidden cards reveal neither draw preview nor condition hints")
 v.free()
 print("CARD_CONDITION_HINTS: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
