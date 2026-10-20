extends "res://tests/support/rules_base.gd"
const Hints=preload("res://scripts/rules/card_condition_hints.gd")
const View=preload("res://scripts/duel_view.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
var v
func check_actionability():
 fresh()
 var hatate=put("character-fdf-105","hand")
 e.players[0].leader=e.make_card("character-fdn-025",0,"leader",true)
 expect(Hints.active(e,hatate) and not Hints.actionable(e,hatate,0),"a satisfied discount condition cannot mark an unaffordable card")
 mana()
 expect(Hints.actionable(e,hatate,0),"the discounted card becomes actionable when its actual cost can be paid")
 for c in e.players[0].palette:c.tapped=true
 expect(not Hints.actionable(e,hatate,0),"spent resources clear the red-frame eligibility")
 for c in e.players[0].palette:c.tapped=false
 for state in [{"phase":"prepare"},{"phase":"end"},{"phase":"mulligan"},{"active":1},{"priority":1},{"winner":0},{"pending":{"kind":"discard","owner":0}},{"entry_choices":[{}]}]:
  var previous={}
  for key in state:previous[key]=e.get(key);e.set(key,state[key])
  expect(not Hints.actionable(e,hatate,0),"unavailable timing or an unfinished choice suppresses the red frame: "+str(state))
  for key in previous:e.set(key,previous[key])
 e.players[0].night_lock=e.turn
 expect(not Hints.actionable(e,hatate,0),"a current-turn cast prohibition suppresses the red frame")
 e.players[0].night_lock=-1
 var duplicate=put(hatate.card_id)
 expect(not Hints.actionable(e,hatate,0),"an existing same-title unit suppresses the red frame")
 e.move_to(duplicate,"grave")
 for i in range(6):put("53")
 expect(not Hints.actionable(e,hatate,0),"a full battlefield suppresses the red frame")
 e.players[0].field=[]
 e.move_to(hatate,"exile")
 expect(not Hints.actionable(e,hatate,0),"a public card without permission to cast from exile stays unmarked")
 e.move_to(hatate,"hand")
 var before=JSON.stringify([e.players,e.stack,e.pending,e.revision])
 expect(Hints.actionable(e,hatate,0) and JSON.stringify([e.players,e.stack,e.pending,e.revision])==before,"checking red-frame eligibility leaves public game state unchanged")
 expect(e.commit_cast(0,hatate.uid,{"none":true},e.payment(0,e.cast_cost(0,hatate)).plan).is_empty(),"the marked card can actually be cast")
 expect(Hints.active(e,hatate) and not Hints.actionable(e,hatate,0),"a card on the stack keeps its condition caption without a usable-card red frame")
 fresh();mana()
 var ominous=put("spell-fdn-009","hand")
 for i in range(4):put("53","grave")
 expect(Hints.active(e,ominous) and not Hints.actionable(e,ominous,0),"a spell with no legal targets stays unmarked despite meeting its grave condition")
 put("53","field",1)
 expect(Hints.actionable(e,ominous,0),"a legal target restores the spell's red-frame eligibility")
 fresh();mana()
 var rain=put("spell-ucs-050","hand")
 for i in range(10):put("53","grave")
 expect(Hints.active(e,rain) and not Hints.actionable(e,rain,0),"a missing required character suppresses the red frame")
 put("59")
 e.phase="prepare";e.active=1
 expect(Hints.actionable(e,rain,0),"a fast spell can be marked in a legal response window")
 for seat in range(2):
  var remote=Remote.new();remote.seat=seat;remote.apply_snapshot(SeatView.build(e,seat))
  expect(Hints.actionable(remote,remote.find_card(rain.uid),seat)==(seat==0),"network red-frame eligibility follows authoritative actions and hand privacy for seat "+str(seat))
 fresh();mana();put("spell-lof-006")
 var leader=e.make_card("80",0,"leader",true);e.players[0].leader=leader
 expect(not Hints.actionable(e,leader,0),"a free or affordable leader still needs its field color constraints")
 put("166");put("167")
 expect(Hints.actionable(e,leader,0),"satisfied field color constraints enable the leader's red frame")
 leader.timer=1
 expect(not Hints.actionable(e,leader,0),"a leader with remaining timer counters stays unmarked")

func run():
 check_actionability()
 fresh();v=View.new();v.engine=e
 var hatate=put("character-fdf-105","hand")
 expect(not Hints.active(e,hatate),"Hatate does not qualify with a three-cost deck leader")
 e.players[0].leader=e.make_card("character-fdn-025",0,"leader",true)
 expect(Hints.active(e,hatate) and e.cast_cost(0,hatate).values().reduce(func(a,b):return a+b,0)==3,"Hatate qualifies at leader cost five and the actual cast costs three")
 e.enter_field(hatate,0)
 expect(hatate.zone=="field" and not Hints.active(e,hatate),"Hatate's casting discount hint clears on entry despite the qualifying deck leader")
 e.move_to(hatate,"hand")
 expect(Hints.active(e,hatate),"Hatate's casting discount hint returns when she returns to hand")
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
 e.enter_field(mokou,0)
 expect(mokou.zone=="field" and not Hints.active(e,mokou),"Mokou's casting discount hint clears on entry while life remains ten")
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
