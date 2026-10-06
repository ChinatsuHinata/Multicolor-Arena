extends "res://tests/support/rules_base.gd"
const SeatView=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")

func selection(options: Array,groups: Array) -> Dictionary:
 var choice=options[0].duplicate(true);choice.erase("selection");choice.picks=groups
 return choice

func announce(source: Dictionary,effect: String,family: String="roster",target: Dictionary={},data: Dictionary={}):
 var trigger={"source":source.duplicate(true),"owner":source.owner,"extended":true,"effect":effect,"name":e.cards[source.card_id].name,"optional":true,"data":data}
 if family!="extension":trigger[family]=true
 e.begin_trigger(trigger)
 e.choose_effect(e.pending.options[0] if target.is_empty() else target)
 expect(e.pending.is_empty() and e.stack.size()==1,effect+" allows responses before resolution")

func activate(source: Dictionary,key: String,target: Dictionary):
 e.debug_enabled=true;e.debug_free_payment=true
 var error=e.commit_extension(0,source.uid,target,[],key)
 expect(error.is_empty(),key+" activates: "+error)
 expect(e.pending.is_empty() and not e.stack.is_empty(),key+" allows responses before resolution")

func pending_effect(effect: String):
 expect(e.pending.get("trigger",{}).get("effect","")==effect and e.pending.trigger.get("continuation",false),effect+" is a resolution choice")
 var remote=Remote.new();remote.apply_snapshot(SeatView.build(e,0))
 expect(remote.pending.get("options",[])==e.pending.options,effect+" choices reach the controlling client")
 var observed=Observer.build(e).state.pending
 expect(observed.get("kind","")=="network_wait" and observed.has("resolving_entry"),effect+" keeps spectators waiting on the resolving entry")

func crystal():
 fresh()
 var fairy=put("2");e.move_to(fairy,"grave");e.pump_choices()
 expect(e.pending.options==[{"none":true}],"crystal announces even without tapped palette cards")
 e.choose_effect({"none":true})
 expect(e.Pack.flatten(e.stack.back().target).is_empty(),"crystal declares no palette target")
 var resource=put("164","palette");resource.tapped=true
 one();pending_effect("crystal")
 expect(e.Pack.ref(e,resource) in e.pending.options,"crystal uses the palette at resolution")
 e.choose_effect(e.Pack.ref(e,resource))
 expect(fairy.zone=="palette" and not fairy.tapped and resource.zone=="grave","crystal exchanges the selected card immediately")
 expect(e.stack.is_empty() and e.pending.is_empty(),"crystal choice creates no response window")
 fresh();fairy=put("2");e.move_to(fairy,"grave");e.pump_choices();e.choose_effect({"none":true});one()
 expect(e.pending.is_empty() and fairy.zone=="grave","crystal finishes safely without a tapped card")
 fresh();fairy=put("2");e.move_to(fairy,"grave");e.pump_choices();e.choose_effect({"none":true})
 resource=put("164","palette");resource.tapped=true;e.move_to(fairy,"exile");one()
 expect(e.pending.is_empty() and resource.zone=="palette","crystal stops if its graveyard card was removed in response")

func palette_triggers():
 fresh()
 var source=put("38","grave")
 announce(source,"death_poverty","extension")
 var resource=put("164","palette",1)
 one();pending_effect("death_poverty");e.choose_effect(e.Pack.ref(e,resource))
 expect(resource.get("poverty",0)==1,"non-target poverty chooses a newly added palette card")
 for effect in ["enter_palette_replace","character-fdf-093"]:
  fresh();source=put("49" if effect=="enter_palette_replace" else "character-fdf-093")
  announce(source,effect,"extension" if effect=="enter_palette_replace" else "roster")
  expect(e.stack.back().target=={"player":1},effect+" declares only the opponent")
  resource=put("164","palette",1);one()
  pending_effect("enter_palette_replace_choose" if effect=="enter_palette_replace" else "cat:futo_palette")
  e.choose_effect(e.Pack.ref(e,resource))
  expect(resource.zone=="grave" if effect=="enter_palette_replace" else resource.get("poverty",0)==1,effect+" selects its card during resolution")

func palette_activations():
 fresh();var source=put("character-rei-023")
 activate(source,"minoriko_untap",{"none":true})
 var resource=put("164","palette");resource.tapped=true
 one();pending_effect("palette_reset")
 e.choose_effect(selection(e.pending.options,[[e.Pack.ref(e,resource)]]))
 expect(not resource.tapped,"Minoriko resets a card added during responses")
 fresh();source=put("spell-fdn-019");source.timer=2
 var victim=put("53")
 activate(source,"spell-fdn-019",selection(e.activation_options(source,"spell-fdn-019"),[[e.ref_target(victim)]]))
 expect(victim.zone=="grave","Price of Life pays its sacrifice before responses")
 expect(e.Pack.declared_targets(e.stack.back()).is_empty() and e.targets_for("spell-fdf-052",1).is_empty(),"Price of Life's paid sacrifice is not a target for hypnosis")
 resource=put("164","palette");resource.tapped=true
 one();pending_effect("cat:palette_reset");e.choose_effect(e.Pack.ref(e,resource))
 expect(not resource.tapped,"Price of Life selects its reset card during resolution")
 fresh();source=put("character-fdf-113")
 expect(e.Pack.ai_target(e,0,e.activation_options(source,"character-fdf-113"),"character-fdf-113")=={"player":1},"Clownpiece AI chooses the opposing player before selecting a palette card")
 activate(source,"character-fdf-113",{"player":1})
 expect(source.zone=="grave" and e.stack.back().target=={"player":1},"Clownpiece pays its sacrifice and declares only a player")
 resource=put("164","palette",1);one();pending_effect("cat:clown_palette");e.choose_effect(e.Pack.ref(e,resource))
 expect(resource.zone=="grave" and e.players[1].palette.back().tapped,"Clownpiece replaces the card selected during resolution")
 fresh();source=put("token-htk-033")
 expect(e.Pack.ai_target(e,0,e.activation_options(source,"mask_sorrow"),"mask_sorrow")=={"player":1},"Sorrow AI chooses the opposing player before selecting palette cards")
 activate(source,"mask_sorrow",{"player":1});resource=put("164","palette",1)
 one();pending_effect("mask_sorrow_choose")
 e.choose_effect(selection(e.pending.options,[[e.Pack.ref(e,resource)]]))
 expect(resource.tapped and e.players[0].hand.size()==1,"Sorrow selects cards during resolution and then draws")

func palette_spell_and_branch():
 fresh();e.debug_enabled=true;e.debug_free_payment=true;put("character-rei-001")
 var spell=put("spell-fdf-007","hand")
 expect(e.commit_cast(0,spell.uid,{"player":1},[]).is_empty(),"Eightfold Binding declares only its opponent even with an empty palette")
 var resources=[put("164","palette",1),put("165","palette",1)]
 one();pending_effect("palette_three_choose")
 e.choose_effect(selection(e.pending.options,[e.Pack.refs(e,resources)]))
 expect(resources.all(func(c):return c.zone=="grave"),"Binding moves all available cards when fewer than three remain")
 fresh();var source=put("character-mar-020")
 announce(source,"marisa_untap","precon",{"none":true,"mode":"重置颜色盘"})
 var resource=put("164","palette");resource.tapped=true
 one();pending_effect("palette_reset")
 e.choose_effect(selection(e.pending.options,[[e.Pack.ref(e,resource)]]))
 expect(not resource.tapped,"Marisa's palette branch chooses on resolution")
 fresh();source=put("character-mar-020");var unit=put("53")
 var options=e.trigger_options({"precon":true,"extended":true,"owner":0,"source":source,"effect":"marisa_untap"})
 expect(options[0].selection[0].pool.has(e.ref_target(unit)),"Marisa's permanent branch retains its printed targets")

func sacrifices_and_ward():
 fresh();var alice=put("character-fdf-112")
 var doll=put("7")
 activate(alice,"character-fdf-112",{"none":true,"mode":"牺牲人偶并检索"})
 expect(doll.zone=="field","Alice's effect sacrifice is not an activation cost")
 e.move_to(doll,"grave");doll=put("7")
 one();pending_effect("cat:alice_sacrifice")
 e.choose_effect(selection(e.pending.options,[[e.ref_target(doll)]]))
 expect(doll.zone=="grave","Alice sacrifices the doll chosen from the current battlefield")
 fresh();e.debug_enabled=true;e.debug_free_payment=true
 e.players[0].leader=e.make_card("character-fdf-117",0,"leader",true)
 var spell=put("spell-fdf-072","hand")
 expect(e.commit_cast(0,spell.uid,{"none":true,"mode":"牺牲并放入封兽鵺"},[]).is_empty(),"Nightmare sacrifice mode can be cast before an unknown exists")
 var unknown=put("token-fdf-131");one();pending_effect("cat:nightmare_sacrifice")
 e.choose_effect(e.ref_target(unknown))
 expect(unknown.zone!="field","Nightmare sacrifices on resolution")
 fresh();var road=put("new-loc-005")
 announce(road,"n21:LOC-005","roster",{"none":true,"mode":"防避2"})
 var unit=put("53");unit.modifiers=[{"不可被指定":true}]
 e.players[0].shroud_turn=e.turn
 one();pending_effect("n21:road_shield")
 expect(e.ref_target(unit) in e.pending.options,"non-target ward choice includes protected units")
 e.choose_effect(e.ref_target(unit))
 expect(unit.get("wards",[]).size()==1 and unit.wards[0].amount==2,"Road grants ward to its resolution choice")
 fresh();var bomb=put("new-eto-002")
 announce(bomb,"n21:ETO-002")
 var ball=put("new-eto-s001");var other=put("new-eto-s001")
 one();pending_effect("n21:ball_sacrifice")
 e.choose_effect(selection(e.pending.options,[[e.Pack.ref(e,other)]]))
 expect(other.zone!="field" and ball.zone=="field" and e.players[1].life==19,"Double's resolution selects specific balls and uses the actual sacrifice count")

func non_target_distribution():
 fresh();e.debug_enabled=true;e.debug_free_payment=true
 var spell=put("spell-ucs-015","hand")
 var options=e.targets_for(spell.card_id,0)
 expect(e.commit_cast(0,spell.uid,selection(options,[[]]),[]).is_empty(),"God's Path declares only its optional buff target")
 var unit=put("53","field",1);unit.plus_counters=10
 var own=put("53");own.plus_counters=1
 e.players[1].shroud_turn=e.turn
 one();pending_effect("cat:distribution")
 expect(e.pending.options[0].selection.size()==3,"non-target damage uses the maximum power at resolution")
 var groups=[]
 for i in range(3):groups.append([e.ref_target(unit)])
 e.choose_effect(selection(e.pending.options,groups))
 expect(unit.damage==3 and e.pending.is_empty(),"non-target distribution damages a protected unit without another response window")
 fresh();put("21")
 options=e.targets_for("spell-fdn-003",0)
 expect(options.any(func(o):return o.get("selection_id","")=="spell-fdn-003"),"Phoenix's explicitly targeted damage retains declaration-time target selection")

func run():
 crystal();palette_triggers();palette_activations();palette_spell_and_branch();sacrifices_and_ward();non_target_distribution()
 fresh()
 var counter=put("100","palette",1);e.move_to(counter,"hand");put("70","field",1)
 put("164","palette",1);put("164","palette",1)
 expect(AI.counter_mana(e,1),"AI recognizes a known counter that chooses its stack object during resolution")
 e.cards["100"]=e.cards["100"].duplicate(true);e.cards["100"].cost={}
 for c in e.players[1].palette:c.tapped=true
 expect(AI.counter_mana(e,1),"AI recognizes a free resolution-choice counter with no remaining mana")
 print("RESOLUTION_CHOICES: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
