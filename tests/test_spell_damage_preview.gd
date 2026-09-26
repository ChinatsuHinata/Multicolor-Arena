extends "res://tests/support/rules_base.gd"

const View=preload("res://scripts/duel_view.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const Observer=preload("res://net/observer_projection.gd")
var v

func run():
 fresh();v=View.new();v.engine=e
 var noon=put("spell-fdn-029","hand")
 var red=put("165","palette");var green=put("166","palette")
 put("164","palette");put("167","palette");put("168","palette").tapped=true
 var foe=put("50","field",1);foe.plus_counters=20
 put("164","palette",1)
 var before=JSON.stringify([e.players,e.stack,e.revision])
 expect(v.damage_caption(noon).begins_with("预计伤害：2 点") and v.damage_caption(noon).contains("模拟支付费用后"),"Noon simulates payment before starting a cast")
 expect(JSON.stringify([e.players,e.stack,e.revision])==before,"simulated payment leaves all game state unchanged")
 var plan=[{"uid":red.uid,"color":"红"},{"uid":green.uid,"color":"绿"}]
 v.local={"uid":noon.uid,"mode":"target","plan":plan}
 expect(v.damage_caption(noon).begins_with("预计伤害：2 点"),"Noon preview subtracts selected palette payment before committing")
 expect(e.commit_cast(0,noon.uid,e.ref_target(foe),plan).is_empty(),"Noon commits a real paid cast")
 v.local={}
 expect(v.damage_caption(noon).begins_with("预计伤害：2 点"),"stack preview does not subtract already paid palette a second time")
 var ready=put("166","palette");ready.tapped=true
 ready.tapped=false
 expect(v.damage_caption(noon).begins_with("预计伤害：3 点"),"stack preview follows palette changes during the response window")
 one();expect(foe.damage==3,"Noon resolves for the displayed damage after payment and responses")
 fresh();v.engine=e
 noon=put("spell-fdn-029","hand");put("165","palette");put("166","palette")
 var item=put("165");var item_green=put("166")
 v.local={}
 expect(v.damage_caption(noon).begins_with("预计伤害：2 点") and e.payment(0,e.cast_cost(0,noon)).plan.all(func(r):return r.uid in [item.uid,item_green.uid]),"Noon automatically prioritizes field items and preserves palette damage")
 item_green.tapped=true
 expect(v.damage_caption(noon).begins_with("预计伤害：1 点"),"mixed payment uses an item first and only one palette card")
 item_green.tapped=false
 v.local={"uid":noon.uid,"mode":"payment","plan":[{"uid":item.uid,"color":"红"},{"uid":item_green.uid,"color":"绿"}]}
 expect(v.damage_caption(noon).begins_with("预计伤害：2 点"),"paying with field items does not reduce Noon's palette damage")
 v.local={"uid":noon.uid,"mode":"target","plan":[]}
 expect(v.damage_caption(noon).begins_with("预计伤害：2 点"),"free casting leaves all upright palette in the preview")
 fresh();v.engine=e;v.local={}
 noon=put("spell-fdn-029","hand");put("165","palette")
 expect(v.damage_caption(noon).contains("费用不足"),"unpayable Noon explicitly labels the incomplete simulation")
 e.debug_enabled=true;e.debug_free_payment=true
 expect(v.damage_caption(noon).begins_with("预计伤害：1 点") and v.damage_caption(noon).contains("模拟支付费用后"),"free casting does not consume simulated palette resources")
 fresh();v.engine=e;v.local={};mana();put("70")
 var orbs=put("spell-rei-011","hand")
 var own_role=put("spell-rei-011","palette");own_role.tapped=true
 put("spell-ucs-041","palette",1)
 put("spell-fdn-029","palette");put("53","palette",1)
 foe=put("50","field",1);foe.plus_counters=20
 expect(v.damage_caption(orbs).begins_with("预计伤害：4 点"),"Dream Orbs counts both palettes' role spells including tapped ones, excluding other cards")
 expect(v.damage_caption(own_role).begins_with("预计伤害：2 点"),"Dream Orbs cast from palette excludes itself from the role count")
 expect(e.commit_cast(0,orbs.uid,e.ref_target(foe),e.payment(0,e.cast_cost(0,orbs)).plan).is_empty(),"Dream Orbs commits a real cast")
 e.move_to(own_role,"grave")
 expect(v.damage_caption(orbs).begins_with("预计伤害：2 点"),"Dream Orbs refreshes after a role card leaves the palette")
 one();expect(foe.damage==2,"Dream Orbs resolves for the previewed damage")
 fresh();v.engine=e;v.local={};mana()
 var lake=put("126","hand");put("53","grave");put("54","grave")
 foe=put("50","field",1);foe.plus_counters=20
 expect(v.damage_caption(lake).begins_with("预计伤害：2～3 点") and v.damage_caption(lake).contains("磨牌对手：2 点") and v.damage_caption(lake).contains("磨牌自己：3 点"),"Lake displays both milling scenarios before choosing a target")
 v.local={"uid":lake.uid,"mode":"target","target":{"parts":[{"player":0},e.ref_target(foe)]}}
 expect(v.damage_caption(lake).begins_with("预计伤害：3 点"),"Lake includes its own mill when targeting its controller")
 v.local.target.parts[0].player=1
 expect(v.damage_caption(lake).begins_with("预计伤害：2 点") and v.damage_caption(lake).contains("磨牌自己：3 点"),"Lake selecting the opponent preserves both scenario hints")
 v.local.target.parts[0].player=0
 expect(e.commit_cast(0,lake.uid,v.local.target,e.payment(0,e.cast_cost(0,lake)).plan).is_empty(),"Lake commits a real self-mill cast")
 v.local={}
 expect(v.damage_caption(lake).begins_with("预计伤害：3 点"),"Lake reads the milling player from its stack target")
 one();expect(foe.damage==3 and e.players[0].grave.size()==4,"Lake resolution matches the preview and counts the spell in grave only afterwards")
 e.players[0].deck=[]
 expect(v.damage_caption(lake).contains("磨牌对手：4 点") and v.damage_caption(lake).contains("磨牌自己：4 点") and v.damage_caption(lake).contains("无法磨牌"),"empty library makes both Lake scenarios equal")
 fresh();v.engine=e;v.local={};mana()
 var unknown=put("139","hand");put("53","hand");put("54","hand")
 foe=put("53","field",1);foe.plus_counters=20
 expect(v.damage_caption(unknown).begins_with("预计伤害：3 点") and v.damage_caption(unknown).contains("使用此牌 −1 张"),"Unknown Identity accounts for leaving hand before drawing")
 expect(e.commit_cast(0,unknown.uid,e.ref_target(foe),e.payment(0,e.cast_cost(0,unknown)).plan).is_empty(),"Unknown Identity commits a real cast")
 expect(v.damage_caption(unknown).begins_with("预计伤害：3 点") and not v.damage_caption(unknown).contains("使用此牌 −1 张"),"stack preview does not remove Unknown Identity from hand twice")
 e.draw(0)
 expect(v.damage_caption(unknown).begins_with("预计伤害：4 点"),"Unknown Identity follows hand changes during responses")
 one();expect(foe.damage==4,"Unknown Identity resolves for the displayed damage")
 fresh();v.engine=e;v.local={}
 unknown=put("139","hand");put("53","hand");e.players[0].deck=[]
 expect(v.damage_caption(unknown).begins_with("预计伤害：1 点") and v.damage_caption(unknown).contains("无法抓牌"),"Unknown Identity never counts an impossible draw")
 fresh();v.engine=e;v.local={};mana();put("character-fdf-ex04")
 var heaven=put("spell-fdf-086","hand")
 put("53");put("token-fdf-129");put("165")
 foe=put("50","field",1);foe.plus_counters=30
 expect(v.damage_caption(heaven).begins_with("预计伤害：3 点"),"Heaven counts friendly units and barriers, excluding items")
 var song=put("spell-fdn-010")
 expect(v.damage_caption(heaven).begins_with("预计伤害：12 点") and v.damage_caption(heaven).contains("幼心乐章要石：+9"),"Heaven adds nine future keystones when the childhood anthem is present")
 before=JSON.stringify([e.players,e.stack,e.triggers,e.revision])
 v.damage_caption(heaven)
 expect(JSON.stringify([e.players,e.stack,e.triggers,e.revision])==before,"anthem preview neither generates keystones nor queues triggers")
 expect(e.commit_cast(0,heaven.uid,{"none":true},e.payment(0,e.cast_cost(0,heaven)).plan).is_empty(),"Heaven commits a real cast with its anthem trigger")
 expect(v.damage_caption(heaven).begins_with("预计伤害：12 点"),"stack preview includes unresolved anthem triggers")
 e.move_to(song,"grave")
 expect(v.damage_caption(heaven).begins_with("预计伤害：12 点"),"removing the anthem does not erase its already announced keystone trigger")
 one()
 expect(v.damage_caption(heaven).begins_with("预计伤害：12 点") and not v.damage_caption(heaven).contains("待结算"),"resolved keystones are counted once without adding the bonus again")
 one();expect(e.players[1].life==8 and foe.damage==12,"Heaven deals previewed damage to both opponent and their units")
 fresh();v.engine=e;v.local={}
 heaven=e.make_card("spell-fdf-086",0,"stack")
 e.stack=[{"id":100,"kind":"card","card":heaven,"owner":0,"target":{"none":true}}]
 put("53");put("spell-fdn-010")
 expect(v.damage_caption(heaven).begins_with("预计伤害：1 点"),"a stack copy without a cast trigger receives no imaginary anthem bonus")
 e.triggers=[{"owner":0,"effect":"spell-fdn-010","data":{"value":9}}]
 expect(v.damage_caption(heaven).begins_with("预计伤害：10 点"),"Heaven includes queued keystones before trigger ordering")
 for seat in range(2):
  var remote=Remote.new();remote.apply_snapshot(SeatView.build(e,seat));v.engine=remote
  expect(v.damage_caption(remote.find_card(heaven.uid)).begins_with("预计伤害：10 点"),"network Heaven includes private queued trigger counts for seat "+str(seat))
 var observer=Remote.new();observer.apply_snapshot(Observer.build(e));v.engine=observer
 expect(v.damage_caption(observer.find_card(heaven.uid)).begins_with("预计伤害：10 点"),"spectator Heaven includes queued keystones without accessing trigger pools")
 fresh();v.engine=e;v.local={};mana();put("48")
 var cherry=put("spell-fdf-048","hand")
 var fuel=[]
 for id in ["53","54","55","56"]:fuel.append(put(id,"hand"))
 put("53","hand",1);put("54","hand",1)
 expect(v.damage_caption(cherry).begins_with("预计伤害：8 点") and v.damage_caption(cherry).contains("己方移除：4 张 × 3 = 12 点") and v.damage_caption(cherry).contains("防止 4 点"),"Cherry Blossom defaults to both players exiling all hands except the casting spell")
 before=JSON.stringify([e.players,e.stack,e.revision])
 v.damage_caption(cherry)
 expect(JSON.stringify([e.players,e.stack,e.revision])==before,"Cherry Blossom preview never exiles either hand")
 var spec=e.targets_for(cherry.card_id,0,cherry.uid)[0].duplicate(true)
 var paid_refs=spec.selection[1].pool.slice(0,2)
 spec.erase("selection");spec.picks=[[{"player":1}],paid_refs]
 v.local={"uid":cherry.uid,"mode":"target","target":spec}
 expect(v.damage_caption(cherry).begins_with("预计伤害：2 点"),"Cherry Blossom follows the actual selected exile cost")
 var cherry_error=e.commit_cast(0,cherry.uid,spec,e.payment(0,e.cast_cost(0,cherry)).plan)
 expect(cherry_error.is_empty(),"Cherry Blossom commits a real cast with two exiled cards: "+cherry_error)
 if not cherry_error.is_empty():v.free();quit(1);return
 v.local={}
 expect(v.damage_caption(cherry).begins_with("预计伤害：2 点") and v.damage_caption(cherry).contains("己方移除：2 张"),"stack preview uses the stored exile cost rather than the remaining hand")
 one()
 expect(e.pending.get("kind","")=="effect_choice" and e.pending.owner==1,"Cherry Blossom waits for opposing prevention")
 var prevention=e.pending.options[0].duplicate(true);var prevention_refs=prevention.selection[0].pool.duplicate(true);prevention.erase("selection")
 prevention.picks=[prevention_refs]
 e.choose_effect(prevention)
 expect(e.players[1].life==18 and e.players[1].hand.is_empty(),"Cherry Blossom's fully prevented damage matches the displayed estimate")
 fresh();v.engine=e;v.local={}
 cherry=put("spell-fdf-048","hand");put("53","hand");put("53","hand",1);put("54","hand",1)
 expect(v.damage_caption(cherry).begins_with("预计伤害：0 点"),"Cherry Blossom damage is clamped to zero when prevention exceeds damage")
 e.players[1].hand=[]
 expect(v.damage_caption(cherry).begins_with("预计伤害：3 点"),"Cherry Blossom refreshes when the opponent runs out of hand cards")
 for seat in range(2):
  var remote=Remote.new();remote.apply_snapshot(SeatView.build(e,seat));v.engine=remote
  var projected=remote.find_card(cherry.uid)
  expect(v.damage_caption(projected).begins_with("预计伤害：3 点") if seat==0 else projected.is_empty(),"network Cherry Blossom uses hand counts without revealing the opposing hand to seat "+str(seat))
 fresh();v.engine=e;v.local={};mana();put("character-mar-021")
 var royal=put("spell-ucs-041","hand")
 e.draw(0,3)
 expect(v.damage_caption(royal).begins_with("预计伤害：4 点") and v.damage_caption(royal).contains("本回合已抓：3 张"),"Royal Flare includes the card's own draw")
 expect(e.commit_cast(0,royal.uid,{"player":1},e.payment(0,e.cast_cost(0,royal)).plan).is_empty(),"Royal Flare commits a real cast to a player")
 e.draw(0,2)
 expect(v.damage_caption(royal).begins_with("预计伤害：6 点"),"Royal Flare follows additional draws while on the stack")
 one();expect(e.players[1].life==14 and int(e.players[0].drawn[str(e.turn)])==6,"Royal Flare resolution matches the preview including its own draw")
 e.turn+=1
 expect(v.damage_caption(royal).begins_with("预计伤害：1 点"),"Royal Flare uses the current turn's draw count")
 e.players[0].deck=[]
 expect(v.damage_caption(royal).begins_with("预计伤害：0 点") and v.damage_caption(royal).contains("无法抓牌"),"empty library does not promise a successful extra draw")
 fresh();v.engine=e;v.local={}
 var enemy=put("spell-ucs-041","grave",1)
 e.draw(1,2);e.draw(0,4)
 expect(v.damage_caption(enemy).begins_with("预计伤害：3 点"),"opponent preview uses the opponent's draws")
 for seat in range(2):
  var remote=Remote.new();remote.apply_snapshot(SeatView.build(e,seat))
  v.engine=remote
  expect(v.damage_caption(remote.find_card(enemy.uid)).begins_with("预计伤害：3 点"),"network projection provides the same public damage count to seat "+str(seat))
  expect(v.damage_caption(remote.players[1-seat].hand[0]).is_empty(),"network hidden hand reveals no calculation")
 v.engine=e
 var hidden=e.make_card("spell-ucs-041",1,"hand");hidden.network_hidden=true
 expect(v.damage_caption(hidden).is_empty(),"hidden cards cannot expose a damage preview")
 fresh();v.engine=e;mana();put("character-htk-001")
 var mask_spell=put("spell-fdf-083","hand")
 var target=put("50","field",1)
 target.plus_counters=10
 var own=put("53")
 item=put("164","field",1)
 var targets=e.targets_for(mask_spell.card_id,0,mask_spell.uid)
 expect(not targets.any(func(t):return t.has("player")) and e.ref_target(target) in targets and e.ref_target(own) in targets and e.ref_target(item) not in targets,"Angry Mask targets either side's units only")
 expect(e.cards[mask_spell.card_id].rules_text.contains("对目标单位造成"),"Angry Mask rules text specifies a target unit")
 var state=JSON.stringify([e.players,e.stack,e.revision])
 for seat in range(2):
  expect(not e.commit_cast(0,mask_spell.uid,{"player":seat},e.payment(0,e.cast_cost(0,mask_spell)).plan).is_empty(),"Angry Mask rejects player target "+str(seat))
  expect(not e.spell_target_valid(mask_spell.card_id,{"player":seat}),"Angry Mask rejects player target at resolution "+str(seat))
 expect(JSON.stringify([e.players,e.stack,e.revision])==state,"rejected player targets do not pay costs or mutate game state")
 expect(e.commit_cast(0,mask_spell.uid,e.ref_target(target),e.payment(0,e.cast_cost(0,mask_spell)).plan).is_empty(),"Angry Mask accepts a real cast targeting a unit")
 one()
 expect(target.damage==4 and e.players[0].life==20 and e.players[1].life==20 and e.players[0].field.filter(func(c):return c.card_id=="token-htk-032").size()==2,"Angry Mask with Kokoro creates two masks and doubles item damage to the unit")
 var mask=e.players[0].field.filter(func(c):return c.card_id=="token-htk-032")[0]
 expect(not e.activation_options(mask,"mask_anger").any(func(t):return t.has("player")),"created Hannya Mask's ability targets units only")
 fresh();mana()
 e.players[0].leader.card_id="character-htk-001"
 mask_spell=put("spell-fdf-083","hand");item=put("164")
 expect(e.targets_for(mask_spell.card_id,0,mask_spell.uid).is_empty(),"Angry Mask has no legal targets when there are no units")
 target=put("50","field",1);target.plus_counters=10
 expect(e.commit_cast(0,mask_spell.uid,e.ref_target(target),e.payment(0,e.cast_cost(0,mask_spell)).plan).is_empty(),"Angry Mask support can cast with Kokoro in the leader zone")
 one()
 expect(target.damage==2 and e.players[0].field.filter(func(c):return c.card_id=="token-htk-032").size()==1,"Angry Mask without Kokoro on the field creates one mask and counts existing items")
 fresh();mana();put("character-htk-001")
 mask_spell=put("spell-fdf-083","hand");target=put("50","field",1)
 expect(e.commit_cast(0,mask_spell.uid,e.ref_target(target),e.payment(0,e.cast_cost(0,mask_spell)).plan).is_empty(),"Angry Mask declares a unit before it leaves the field")
 e.move_to(target,"grave")
 one()
 expect(mask_spell.zone=="grave" and not e.players[0].field.any(func(c):return c.card_id=="token-htk-032"),"Angry Mask with an invalidated unit target does not resolve or create masks")
 v.free()
 print("SPELL_DAMAGE_PREVIEW: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
