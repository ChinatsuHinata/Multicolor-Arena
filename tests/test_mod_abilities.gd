extends "res://tests/support/rules_base.gd"
const Registry=preload("res://scripts/rules/mod_registry.gd")
const Codec=preload("res://net/state_codec.gd")
const Seat=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
const Gateway=preload("res://net/command_gateway.gd")
const Remote=preload("res://net/remote_duel.gd")
const Inventory=preload("res://scripts/rules/trigger_inventory.gd")
const RuleSet=preload("res://scripts/deck_rule_set.gd")
const TOP="example.cards/top_three"
const BLAST="example.cards/grave_blast"
const LEAVE="example.cards/last_word"

func setup_mods() -> bool:
 Registry._shared=Registry.new()
 var error=Registry.shared().register_pack("res://mods/example.cards")
 expect(error.is_empty(),"register trusted example pack: "+error)
 var cards=DB.load_cards()
 Store.CARDS=cards
 expect(cards.has(TOP) and cards.has(BLAST) and cards.has(LEAVE),"mod JSON cards load: "+DB.last_error)
 if not cards.has(TOP):return false
 for rule_set in RuleSet.IDS:
  expect(RuleSet.allowed(TOP,cards[TOP],rule_set)==(rule_set==RuleSet.MOD),"mod cards require mod construction rules: "+rule_set)
 var deck=Store.blank("模组构筑");deck.leader="70";deck.rule_set=RuleSet.MOD
 expect(Store.add_card(deck,TOP,"main",RuleSet.MOD).is_empty() and Store.validate(deck,false,RuleSet.MOD).is_empty(),"existing deck editor add / validate accepts loaded mod card")
 var decoded=Store.decode(Store.encode(deck))
 expect(decoded.has("deck") and decoded.deck.rule_set==RuleSet.MOD and decoded.deck.main==deck.main,"deck code preserves mod rule and cards")
 expect(Store.prune_for_rule(deck,RuleSet.UNRESTRICTED)==1 and deck.main.is_empty(),"switching away from mod rules removes mod cards")
 expect(not Registry.shared().register_pack("res://mods/example.cards").is_empty(),"duplicate namespace rejected atomically")
 var bad={"实现":"mod","实例键":"x","参数":{"能力":BLAST,"伤害倍率":-1}}
 expect(not Registry.shared().validate_binding(bad,"单位").is_empty(),"parameters checked by registered validator")
 return true

func multi_step():
 fresh()
 var c=put(TOP,"hand");var tops=e.players[0].deck.slice(0,3).map(func(card):return e.ref_target(card))
 var before=Codec.capture(e)
 for i in range(3):e.targets_for(TOP,0,c.uid);e.available_actions(0,c.uid);Seat.build(e,0)
 expect(Codec.capture(e)==before,"repeated action / projection queries do not mutate game state")
 expect(e.commit_cast(0,c.uid,{"none":true},[]).is_empty(),"mod spell uses normal cast path")
 one()
 expect(e.pending.get("trigger",{}).get("mod_resume",false) and e.pending.options.size()==3,"spell suspends at private top-three choice")
 if e.mod_resolution.is_empty():return
 var saved=Codec.capture(e);var first=e.pending.options[0].duplicate(true)
 var own=Seat.build(e,0);var other=Seat.build(e,1);var observer=Observer.build(e)
 expect(own.queries.lookup.has(tops[0].uid) and not other.queries.lookup.has(tops[0].uid),"only chooser receives inspected card lookup")
 expect(not own.state.pending.has("mod_frame") and not str(other).contains("remaining") and not str(observer).contains("remaining"),"continuation data hidden from both public projections")
 expect(not own.state.mod_state.is_empty() and other.state.mod_state.is_empty() and observer.state.mod_state.is_empty(),"owner state visibility enforced")
 expect(not Gateway.apply(e,1,{"name":"choose_effect","args":[first]}).is_empty(),"opponent cannot answer private choice")
 expect(not Gateway.apply(e,0,{"name":"choose_effect","args":[{"uid":-99,"epoch":0}]}).is_empty(),"forged answer rejected")
 expect(e.pending.options[0]==first,"failed answers preserve choice")
 expect(Gateway.apply(e,0,{"name":"choose_effect","args":[first]}).is_empty(),"authority accepts owner choice")
 expect(e.find_card(first.uid).zone=="hand" and not e.mod_resolution.is_empty(),"first step moves card and waits for ordering")
 var second_save=Codec.capture(e);var order=e.pending.options.back().duplicate(true)
 expect(Gateway.apply(e,0,{"name":"choose_effect","args":[order]}).is_empty(),"order choice completes")
 var final_state=Codec.capture(e)
 var restored=Duel.new();expect(Codec.restore(restored,second_save).is_empty(),"restore second choice")
 Gateway.apply(restored,0,{"name":"choose_effect","args":[order]})
 expect(Codec.capture(restored)==final_state,"restored resolution matches uninterrupted run exactly")
 expect(e.mod_resolution.is_empty() and e.find_card(c.uid).zone=="grave" and e.players[0].deck[0].uid==order.uid,"spell finishes in grave with chosen top order")
 var mismatched=Codec.decode(saved);mismatched.mod_manifest[0].hash="different"
 var wrong=Codec.encode(mismatched);wrong.definitions=saved.definitions;wrong.plain=saved.plain
 expect(not Codec.restore(restored,wrong).is_empty() and Codec.capture(restored)==final_state,"mismatched mod hash refuses restore before mutation")

func activation():
 fresh();mana()
 var c=put(BLAST);var discard=put("164","hand")
 var actions=e.available_actions(0,c.uid).filter(func(a):return a.get("key","").begins_with("mod:"))
 expect(actions.size()==1,"one action per binding")
 if actions.is_empty():return
 var key=actions[0].key;var opts=e.activation_options(c,key)
 var target={"selection_id":"discard_and_damage","picks":[[e.Mods.Context.new(e,e.Mods.frame_for(e,c,e.cards[BLAST].abilities[0],0)).ref(discard)],[{"player":1}]]}
 var payment=e.payment(0,e.extension_cost(0,c,key,target)).plan
 var before=Codec.capture(e)
 expect(not e.commit_extension(0,c.uid,{"selection_id":"discard_and_damage","picks":[[],[{"player":1}]]},payment,key).is_empty(),"missing extra cost rejected")
 expect(not e.commit_extension(0,c.uid,target,[],key).is_empty(),"missing color payment rejected")
 expect(Codec.capture(e)==before,"failed declarations and cancelled draft spend nothing")
 var remote=Remote.new();remote.seat=0;remote.apply_snapshot(Seat.build(e,0))
 expect(remote.activation_options(remote.find_card(c.uid),key)==opts and remote.extension_cost(0,remote.find_card(c.uid),key,target)==e.extension_cost(0,c,key,target),"remote UI receives common choice and payment specifications")
 expect(Gateway.apply(e,0,{"name":"commit_extension","args":[c.uid,target,payment,key]}).is_empty(),"gateway accepts registered instance, choices and payment")
 expect(c.tapped and discard.zone=="grave" and e.stack.size()==1,"all costs paid before stack response")
 one();expect(e.players[1].life==18,"activated mod effect resolves through engine damage")
 fresh();mana();c=put(BLAST);discard=put("164","hand");key=e.Mods.key_for(c,e.cards[BLAST].abilities[0])
 target.picks[0]=[{"uid":discard.uid,"epoch":discard.epoch,"zone":"hand"}]
 payment=e.payment(0,e.extension_cost(0,c,key,target)).plan
 e.commit_extension(0,c.uid,target,payment,key);e.counter_entry(e.stack.back().id)
 expect(c.tapped and discard.zone=="grave" and e.players[1].life==20,"counter prevents effect without refunding costs")
 e.move_to(c,"hand");e.detach(c);e.enter_field(c,0);c.entered_turns=0;e.priority=0
 expect(not e.commit_extension(0,c.uid,target,[],key).is_empty(),"old ability instance rejected after leave and return")

func leave_and_force():
 fresh()
 var c=put(LEAVE);var original=e.ref_target(c)
 e.move_to(c,"grave");e.pump_choices()
 expect(e.pending.get("kind","")=="effect_choice" and e.pending.trigger.source.epoch==original.epoch,"leave trigger retains original source epoch")
 e.choose_effect({"player":1})
 e.detach(c);e.enter_field(c,0)
 one();expect(e.players[1].life==18,"leave trigger resolves after source returns as new incarnation")
 Inventory.force(e,0);e.pump_choices()
 expect(not e.stack.is_empty() and e.stack.back().has("mod_frame"),"forced main trigger inventory includes mod descriptors")
 e.choose_effect({"player":1});one();expect(e.players[1].life==16,"explicit empty-event policy permits forced trigger")
 fresh();c=put(LEAVE)
 var second=e.cards[LEAVE].abilities[0].duplicate(true);second["实例键"]="main_2";e.cards[LEAVE].abilities.append(second)
 e.move_to(c,"grave");e.pump_choices()
 expect(e.pending.get("kind","")=="trigger_order" and e.pending.options.size()==2,"duplicate bindings keep independent trigger identities and use existing ordering")

func second_pack_and_compatibility():
 expect(Registry.shared().register_pack("res://tests/support/mod_second").is_empty(),"second pack registers without engine changes")
 fresh()
 var card=put("second.cards/draw","hand");var size=e.players[0].hand.size()
 expect(e.commit_cast(0,card.uid,{"none":true},[]).is_empty(),"second pack spell casts through same API")
 one();expect(e.players[0].hand.size()==size+1 and card.zone=="grave","second pack draw effect resolves")
 fresh();card=put("second.cards/draw","hand")
 var binding=e.cards[card.card_id].abilities[0];binding["参数"].after_damage=3
 var leader=e.players[0].leader;e.shift(leader,"deck");e.players[0].deck.push_front(leader)
 e.commit_cast(0,card.uid,{"none":true},[]);one()
 expect(e.pending.get("kind","")=="leader_return" and e.players[1].life==20 and not e.mod_resolution.is_empty(),"engine return decision interrupts operations before later damage")
 var paused=Codec.capture(e);var restored=Duel.new();Codec.restore(restored,paused)
 e.choose_return(true);restored.choose_return(true)
 expect(e.players[1].life==17 and e.mod_resolution.is_empty() and Codec.capture(restored)==Codec.capture(e),"engine choice resumes saved operation cursor exactly once")
 fresh();card=put("second.cards/draw","hand");binding=e.cards[card.card_id].abilities[0]
 var frame=e.Mods.frame_for(e,card,binding,0)
 var context=e.Mods.Context.new(e,frame);var before=Codec.capture(e)
 expect(not context.draw(0) and Codec.capture(e)==before,"query context rejects mutation commands")
 e.Mods.write_state(e,frame,"turn_count",2);e.Mods.write_state(e,frame,"source_cache",{"value":3});e.Mods.write_state(e,frame,"secret",{"value":4})
 expect(e.Mods.projected_state(e,-1)["second.cards"].size()==1 and e.Mods.projected_state(e,0)["second.cards"].size()==2,"public owner and authority state have distinct projections")
 e.turn+=1;e.move_to(card,"grave")
 expect(e.Mods.read_state(e,frame,"turn_count")==null and e.Mods.read_state(e,frame,"source_cache")==null and e.Mods.projected_state(e,0).is_empty(),"turn and source state reset at their declared boundaries")
 fresh();mana();var source=put(BLAST);var discard=put("164","hand")
 var target={"selection_id":"discard_and_damage","picks":[[{"uid":discard.uid,"epoch":discard.epoch,"zone":"hand"}],[{"player":1}]]}
 var key=e.Mods.key_for(source,e.cards[BLAST].abilities[0])
 e.commit_extension(0,source.uid,target,e.payment(0,{"红":1}).plan,key)
 var retarget=e.Cat.retarget_options(e,e.stack.back())
 expect(not retarget.is_empty() and retarget[0].selection.size()==1,"retargeting mod activation excludes already paid discard even with empty hand")
 var copy=e.stack.back().duplicate(true);copy.id=e.next_stack;e.next_stack+=1;e.stack.append(copy)
 one();one();expect(e.players[1].life==16,"copied mod ability resolves independently without repaying costs")
 fresh();source=put(LEAVE);source.plus_counters=3;e.move_to(source,"grave");e.pump_choices();e.choose_effect({"player":1});one()
 expect(e.players[1].life==15,"leave snapshot captures modified power before zone reset")
 fresh();mana();source=put(BLAST);put("164","hand")
 e.cards[BLAST].abilities.append(e.cards[BLAST].abilities[0].duplicate(true))
 var actions=e.available_actions(0,source.uid).filter(func(a):return a.get("key","").begins_with("mod:"))
 expect(actions.size()==2 and actions[0].key!=actions[1].key,"granted duplicate binding occurrences receive distinct identities")
 expect(e.ai_extended_ability(0),"AI finds and pays a legal mod action from common specification")
 fresh();source=put(LEAVE);var copied=put("164")
 e.Cat.copy_unit(e,copied,source);e.move_to(copied,"grave");e.pump_choices()
 expect(e.pending.get("trigger",{}).get("mod_frame",{}).get("ability_id","")==LEAVE,"existing unit-copy effect inherits mod trigger")
 fresh();card=put(TOP,"hand");e.commit_cast(0,card.uid,{"none":true},[]);e.counter_entry(e.stack.back().id)
 expect(card.zone=="grave" and e.mod_resolution.is_empty() and e.mod_state.is_empty(),"countered mod spell never starts private resolution")
 fresh()
 expect(e.Cat.name_options(e).any(func(option):return option.card_name==e.cards[BLAST].name),"existing name-based prohibition can name a mod card")
 e.cards[BLAST].abilities=[{"实现":"mod","实例键":"self_1","参数":{"能力":"second.cards/leader_draw"}}]
 source=put(BLAST)
 expect(e.Mods.actions(e,source,0,false).is_empty(),"leader-only descriptor requires existing leader authorization")
 source.leader_counters=1
 expect(e.Mods.actions(e,source,0,false).size()==1,"existing leader counter grants mod leader ability")
 var lock=put("character-fdf-101", "field",1);lock.locked_name=e.Cat.canonical_name(e,BLAST)
 expect(e.Mods.actions(e,source,0,false).is_empty(),"existing name-based activation lock blocks mod action")
 fresh();mana();e.cards[BLAST].abilities=[{"实现":"mod","实例键":"hand_1","参数":{"能力":"second.cards/hand_draw"}}]
 source=put(BLAST,"hand");e.active=1
 expect(e.has_response(0),"hand-zone mod activation keeps response window open")
 var hand_action=e.Mods.actions(e,source,0,false)[0]
 size=e.players[0].hand.size()
 expect(e.commit_extension(0,source.uid,{"none":true},e.payment(0,{"红":1}).plan,hand_action.key).is_empty(),"hand-zone mod action uses same declaration path")
 one();expect(e.players[0].hand.size()==size+1 and source.zone=="hand","hand-zone action resolves without moving its source")

func run():
 if setup_mods():
  multi_step();activation();leave_and_force();second_pack_and_compatibility()
 print("MOD_ABILITIES: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
