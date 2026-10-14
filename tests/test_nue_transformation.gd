extends "res://tests/support/rules_base.gd"

const Codec=preload("res://net/state_codec.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")

func attributes(c: Dictionary) -> Array:
 return [e.stat(c,"power"),e.stat(c,"health"),e.stat(c,"spirit")]

func shou(target: Dictionary):
 var source=put("character-rei-022")
 e.Pack.resolve_trigger(e,{"source":source.duplicate(true),"owner":0,"effect":"shou_shield","target":target})

func transformation():
 fresh()
 var nue=put("character-fdf-117")
 put("33")
 var unit=enter("character-fdn-026")
 unit.plus_counters=2;unit.minus_counters=1;unit.damage=1;unit.tapped=true
 unit.extra_keywords=["英勇"];unit.imp_growth=true;unit.reisen_illusion=true
 e.Cat.buff(e,unit,2,1,1,["防避3","疾行","防止伤害"])
 expect(unit.get("wards",[]).size()==3,"printed and granted wards are present before transformation")
 var ref=e.ref_target(unit);var original_cost=e.cards[unit.card_id].cost.duplicate();var original_colors=e.Pack.colors(e,unit)
 e.Cat.Units.on_phase(e,"end");e.pump_choices()
 expect(e.pending.get("trigger",{}).get("effect","")=="character-fdf-117","Nue's end-step main ability offers its target")
 var choice=e.pending.options[0].duplicate(true);choice.erase("selection");choice.picks=[[ref]]
 e.choose_effect(choice);one()
 expect(e.cards[unit.card_id].name=="不明物体" and e.cards[unit.card_id].kind=="单位","main ability transforms the target into an ordinary unknown unit")
 expect(e.cards[unit.card_id].cost==original_cost and e.Pack.colors(e,unit)==original_colors,"transformation keeps the original cost and colors")
 expect(e.ref_target(unit)==ref and unit.tapped and unit.damage==1,"transformation preserves identity, tapped state and damage")
 expect(attributes(unit)==[6,5,6],"3/3/3 base retains numeric buffs and positive/negative counters")
 expect(unit.get("wards",[]).is_empty(),"losing all abilities removes printed and granted wards")
 expect(e.Extra.keyword(e,unit,"威吓") and not e.Extra.keyword(e,unit,"英勇") and not e.has_haste(unit) and not e.Extra.keyword(e,unit,"防止伤害"),"only the new menace remains after granted keywords are removed")
 expect(not unit.has("imp_growth") and not unit.has("reisen_illusion"),"granted growth and illusion abilities are removed")
 nue.leader=true
 expect(attributes(unit)==[7,6,7],"Nue's self ability buffs transformed menace units")
 e.Cat.unknown(e,nue)
 expect(attributes(unit)==[6,5,6],"transforming Nue also removes its self aura")
 e.Cat.buff(e,unit,0,0,0,["疾行","防避2"])
 expect(e.has_haste(unit) and unit.wards.size()==1,"new abilities can be granted after transformation")
 e.move_to(unit,"hand")
 expect(unit.card_id=="character-fdn-026" and not unit.has("copy_original") and unit.get("wards",[]).is_empty(),"leaving the battlefield restores the original card and clears field abilities")
 fresh();unit=put("character-fdn-027")
 expect(e.available_actions(0,unit.uid,true).any(func(a):return a.type=="extension"),"the original unit exposes its activated ability")
 e.Cat.unknown(e,unit)
 expect(not e.available_actions(0,unit.uid,true).any(func(a):return a.type=="extension"),"transformation removes the original activated ability from available actions")

func habitat_and_tokens():
 fresh()
 var habitat=put("character-fdn-007");put("13");e.judge()
 expect(habitat.has("habitat_base"),"fairy habitat has synchronized inherited abilities")
 e.Cat.unknown(e,habitat);e.judge()
 expect(e.cards[habitat.card_id].name=="不明物体" and not habitat.has("habitat_base") and not habitat.has("inherited_self"),"state checks do not overwrite a transformed habitat")
 expect(habitat.copy_original=="character-fdn-007","habitat records its printed original rather than its generated inheritance definition")
 e.move_to(habitat,"hand")
 expect(habitat.card_id=="character-fdn-007","a transformed habitat restores its printed card when it leaves")
 fresh()
 var frog=e.Cat.token(e,0,"青蛙",4,4,2,["蓝","绿"],["不占战场格"])
 var original=frog.card_id
 expect(e.field_slots(0)==0,"frog initially occupies no battlefield slot")
 e.Cat.unknown(e,frog);e.judge()
 expect(frog.token and e.field_slots(0)==1 and attributes(frog)==[3,3,3],"transformed frog stays a token but loses its no-slot ability and uses 3/3/3")
 e.Cat.unknown(e,frog)
 expect(frog.copy_original==original,"repeated transformation preserves the first original token definition")
 var graph=Codec.capture(e);e=Duel.new();Codec.restore(e,bytes_to_var(var_to_bytes(graph)))
 frog=e.find_card(frog.uid)
 expect(frog.copy_original==original and e.cards[original].name=="青蛙","save restoration retains generated original token information")
 for snapshot in [SeatView.build(e,0),SeatView.build(e,1),Observer.build(e)]:
  expect(snapshot.definitions.has(original),"seat and spectator snapshots include generated original token definitions")
  var remote=Remote.new();remote.apply_snapshot(snapshot)
  expect(remote.cards[remote.find_card(frog.uid).copy_original].power==4,"remote details can read the frog's original attributes")

func damage_prevention():
 fresh()
 var unit=put("53")
 e.Pack.shield(e,e.ref_target(unit),[1,3]);shou(e.ref_target(unit))
 expect(unit.wards.size()==2 and e.Pack.has_next_damage_prevention(e,unit),"Shou's effect is stored independently of wards")
 expect(not e.ward_choice_needed(unit) and e.damage_target(e.ref_target(unit),10000000)==0 and e.pending.is_empty(),"next-damage prevention blocks any amount without a ward-order prompt")
 expect(unit.wards.size()==2 and not e.Pack.has_next_damage_prevention(e,unit),"prevention is used once and does not spend wards")
 shou(e.ref_target(unit));e.Cat.unknown(e,unit)
 expect(unit.get("wards",[]).is_empty() and e.Pack.has_next_damage_prevention(e,unit),"ability loss removes wards while keeping Shou's resolved prevention effect")
 expect(e.combat_hit(unit,e.ref_target(unit),20)==0 and e.damage_target(e.ref_target(unit),1)==1,"transformed unit prevents its next combat hit, then takes later damage")
 fresh();unit=put("53");shou(e.ref_target(unit));e.unpreventable_turn=e.turn
 expect(e.damage_target(e.ref_target(unit),1)==1 and e.Pack.has_next_damage_prevention(e,unit),"unpreventable damage bypasses prevention without spending it")
 e.unpreventable_turn=-1
 expect(e.damage_target(e.ref_target(unit),1)==0,"unspent prevention remains usable during the turn")
 fresh();shou({"player":0})
 expect(e.damage_target({"player":0},10000000)==0 and e.damage_target({"player":0},2)==2 and e.players[0].life==18,"player prevention also blocks exactly the next damage event")
 fresh();unit=put("53");shou(e.ref_target(unit));shou({"player":0});e.finish_turn()
 expect(not unit.has("next_damage_prevention_turn") and not e.players[0].has("next_damage_prevention_turn"),"unused player and unit prevention expires at turn cleanup")
 fresh();unit=put("53");shou(e.ref_target(unit));e.move_to(unit,"hand")
 expect(not unit.has("next_damage_prevention_turn"),"leaving the battlefield removes next-damage prevention")

func combat_preview():
 fresh()
 var attacker=put("53");var target=put("53","field",1)
 e.Pack.shield(e,e.ref_target(target),[2]);e.Pack.prevent_next_damage(e,e.ref_target(target))
 expect(AI.preview_damage(e,attacker,target,5,true)==0,"combat prediction recognizes Shou's independent prevention")
 var copy=target.duplicate(true);AI.preview_hit(e,attacker,copy,5)
 expect(copy.damage==0 and copy.wards.size()==1 and not copy.has("next_damage_prevention_turn") and target.has("next_damage_prevention_turn"),"private combat prediction consumes prevention while preserving wards and live state")
 AI.preview_hit(e,attacker,copy,5)
 expect(copy.damage==3 and copy.wards.is_empty(),"prediction uses remaining wards on the later hit")
 var vulnerable=put("53","field",1)
 var allocation=AI.damage_allocation(e,attacker,[target,vulnerable],2)
 expect(allocation.get(str(target.uid),-1)==0 and allocation.get(str(vulnerable.uid),0)==2,"combat allocation directs damage to a vulnerable blocker rather than a prevented one")

func run():
 transformation();habitat_and_tokens();damage_prevention();combat_preview()
 print("NUE_TRANSFORMATION: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
