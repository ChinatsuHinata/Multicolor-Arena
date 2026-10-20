extends "res://tests/support/rules_base.gd"
const Registry=preload("res://scripts/rules/mod_registry.gd")
const Codec=preload("res://net/state_codec.gd")
func setup_pack() -> bool:
 Registry._shared=Registry.new()
 var error=Registry.shared().register_pack("res://examples/testmod")
 expect(error.is_empty(),"scarlet moon pack registers: "+error)
 Store.CARDS=DB.load_cards()
 expect(Store.CARDS.has("testmod/chanting_youka"),"expansion definitions load: "+DB.last_error)
 return Store.CARDS.has("testmod/chanting_youka")
func card(id: String,zone: String="field",who: int=0) -> Dictionary:return put("testmod/"+id,zone,who)
func accept():
 if e.pending.options[0].get("selection_id","")=="hourai_search":
  var option=e.pending.options[0].duplicate(true);var pool=option.selection[0].pool;option.erase("selection");option.picks=[pool.slice(0,1)]
  e.choose_effect(option);return
 e.choose_effect(e.Pack.ai_target(e,e.pending.owner,e.pending.options,"mod:test"))
func reference(c: Dictionary) -> Dictionary:return e.Mods.Context.new(e,{}).ref(c)
func settle():
 for i in range(200):
  if e.winner!=-2:return
  e.pump_choices()
  if not e.pending.is_empty():
   match e.pending.kind:
    "effect_choice":accept()
    "trigger_order":e.choose_trigger_order(0)
    "leader_return":e.choose_return(false)
    "timer":e.choose_timer(0)
    "reveal_review":e.confirm_revealed(e.pending.owner,e.pending.serial)
    "ward_order":e.choose_ward(e.pending.options[0])
    _:return
  elif not e.stack.is_empty() or not e.combat.is_empty():one()
  elif not e.triggers.is_empty() or not e.mod_resolution.is_empty():continue
  else:return
 expect(false,"expansion resolution stays bounded")
func use(c: Dictionary,target: Dictionary={}) -> String:
 e.priority=c.owner;e.debug_enabled=true;e.debug_free_payment=true
 if target.is_empty():
  var options=e.targets_for(c.card_id,c.owner,c.uid)
  if options.is_empty():return "no options"
  target=e.Pack.ai_target(e,c.owner,options,"mod:test")
 return e.commit_cast(c.owner,c.uid,target,[])
func remilia(who: int=0) -> Dictionary:return put("character-fdn-048","field",who)
func kaguya():
 var leader=e.players[0].leader;leader.card_id="85"
func definitions():
 fresh()
 var u=e.cards["testmod/chanting_youka"]
 expect(u.cost.size()==2 and int(u.cost.get("黄",0))==2 and int(u.cost.get("绿",0))==2 and u.power==1 and u.health==6 and u.spirit==1,"chanting youkai uses the corrected 2 yellow 2 green cost and 1/6/1")
 expect(not e.cards["testmod/scarlet_bat"].constructible and e.cards["testmod/scarlet_bat"].token,"bat token cannot enter constructed decks")
func chanting():
 fresh();var target=card("visitor");var source=card("chanting_youka")
 e.Mods.event(e,source,"self_enter");e.pump_choices();settle()
 expect(target.plus_counters==2,"chanting youkai adds two triple-stat counters")
 fresh();target=card("visitor");source=card("chanting_youka")
 e.Mods.event(e,source,"self_enter");e.pump_choices()
 if e.pending.get("kind","")=="effect_choice":
  var option=e.pending.options.filter(func(o):return o.get("chant_mode","")=="bounce")[0]
  var answer=option.duplicate(true);answer.erase("selection");answer.picks=[[e.Mods.Context.new(e,{}).ref(target)]]
  e.choose_effect(answer)
 settle()
 expect(target.zone=="hand" and e.players[0].hand.size()==3,"chanting bounce returns the target and draws two")
 fresh();target=card("visitor");source=card("chanting_youka");e.cards[target.card_id].colors=["黄","绿","蓝"]
 e.Mods.event(e,source,"self_enter");e.pump_choices();settle()
 expect(int(target.get("plus_counters",0))==0,"chanting requires exactly yellow and green rather than a three-color unit")
func damage_and_bats():
 fresh();remilia();var spell=card("scarlet_meister","hand")
 expect(use(spell,{"player":1}).is_empty(),"scarlet meister can target a player");settle()
 var bats=e.units(0).filter(func(c):return c.card_id=="testmod/scarlet_bat")
 expect(e.players[1].life==14 and bats.size()==6,"six actual damage creates six bats")
 expect(bats.all(func(c):return e.has_haste(c) and e.Cat.race(e,c,"妖怪")) and e.field_slots(0)==1,"bats and existing units gain haste without consuming slots")
 fresh();remilia();var target=card("chanting_youka","field",1)
 e.Pack.shield(e,e.ref_target(target),[2],false,false)
 spell=card("scarlet_meister","hand");expect(use(spell,e.ref_target(target)).is_empty(),"scarlet meister can target a warded unit");settle()
 expect(e.units(0).filter(func(c):return c.card_id=="testmod/scarlet_bat").size()==4,"prevented damage does not create bats")
 fresh();remilia();target=card("chanting_youka","field",1)
 e.Pack.shield(e,e.ref_target(target),[1,2],false,false)
 spell=card("scarlet_meister","hand");expect(use(spell,e.ref_target(target)).is_empty(),"damage result can pause for distinct ward ordering");one()
 expect(e.pending.get("kind","")=="ward_order" and not e.mod_resolution.is_empty(),"damage and token creation wait for the ward decision")
 var saved=Codec.capture(e);var restored=Duel.new();expect(Codec.restore(restored,saved).is_empty(),"paused actual-damage continuation restores")
 settle();var final_state=Codec.capture(e);var original=e;e=restored;settle()
 expect(Codec.capture(e)==final_state and e.units(0).filter(func(c):return c.card_id=="testmod/scarlet_bat").size()==3,"restored ward order creates exactly three bats once and preserves exact state")
 e=original
func curse_link():
 fresh();var vamp=put("6","grave");remilia();var spell=card("vlad_curse","hand")
 var error=use(spell,reference(vamp))
 expect(error.is_empty(),"vlad curse casts with a graveyard vampire: "+error);settle()
 expect(spell.zone=="field" and spell.timer==3 and vamp.zone=="field","curse enters with three counters and revives its target")
 var saved=Codec.capture(e);var restored=Duel.new()
 expect(Codec.restore(restored,saved).is_empty(),"linked resurrection survives save restore")
 restored.move_to(restored.find_card(spell.uid),"hand");restored.pump_choices()
 expect(restored.find_card(vamp.uid).zone=="grave","removing the restored curse sacrifices its linked vampire")
 e.move_to(vamp,"hand");e.move_to(vamp,"grave");e.detach(vamp);e.enter_field(vamp,0);settle()
 e.move_to(spell,"grave");settle()
 expect(vamp.zone=="field","a vampire that left and reentered is a new object and is not sacrificed")
 fresh();e.players[0].leader.card_id="74";var dead=put("character-fdn-048","grave");vamp=put("6","grave");spell=card("vlad_curse","hand");mana()
 expect(e.character_constraint_error(spell,0).is_empty(),"deck Remilia plus a graveyard Remilia satisfies the curse's character requirement")
func fruits():
 fresh();put("character-fdf-ex01");var enemy=remilia(1)
 for i in range(3):card("chanting_youka")
 var spell=card("forbidden_fruits","hand");var count=e.players[0].hand.size()
 var error=use(spell,reference(enemy))
 expect(error.is_empty(),"forbidden fruits targets an opposing vampire leader unit: "+error);settle()
 expect(e.players[0].hand.size()==count+2 and e.units(0).size()==1,"draws three then forces the opponent's printed leader trigger three times")
 fresh();put("character-fdf-ex01");enemy=put("character-fdf-ex01","field",1);spell=card("forbidden_fruits","hand");count=e.players[0].hand.size()
 expect(use(spell,reference(enemy)).is_empty(),"fruits may target a vampire without a triggered leader ability");settle()
 expect(e.players[0].hand.size()==count+2,"activated and static leader abilities do not trigger")
 fresh();put("character-fdf-ex01");enemy=put("character-fdn-025","field",1);spell=card("forbidden_fruits","hand")
 expect(use(spell,reference(enemy)).is_empty(),"fruits also targets the vampire sisters")
 one()
 expect(e.pending.get("kind","")=="trigger_order" and e.pending.options.size()==3 and e.pending.options.all(func(t):return t.effect=="character-fdn-025:self" and t.owner==1),"the sisters' printed end-step leader ability triggers three times under their controller")
 settle()
func grave_game():
 fresh();var own=put("character-fdf-ex01");var enemy=card("chanting_youka","field",1);var spell=card("forbidden_game","hand")
 expect(use(spell).is_empty(),"forbidden game declares two combat targets");settle()
 expect(spell.zone=="grave" and e.Roster.mandatory_free_cast(e,spell,0),"resolved forbidden game grants free graveyard use this turn")
 enemy=card("chanting_youka","field",1);e.priority=0
 expect(spell in e.legal_casts(0),"graveyard reuse appears in legal casts")
 expect(use(spell).is_empty(),"forbidden game recasts without colors");settle()
 expect(spell.zone=="grave","graveyard use does not silently exile this reusable spell")
 e.turn+=1
 expect(e.Mods.access(e,spell,0).is_empty(),"graveyard permission expires on the next turn")
func treasures():
 fresh();card("buddha_diamond");card("dragon_jewel");var before=e.players[0].deck.size()
 e.start_turn(0);settle()
 expect(e.mod_prepares_remaining==2 and e.players[0].life==22,"two different treasures schedule two extra preparations and trigger the normal one")
 var mana_count=e.players[0].palette.size()
 e.advance_phase();settle();e.advance_phase();settle()
 expect(e.phase=="prepare" and e.mod_prepares_remaining==0 and e.players[0].life==26,"each extra preparation triggers each treasure again exactly once")
 expect(e.players[0].palette.size()==mana_count,"extra preparations do not repeat reset or palette growth")
 e.advance_phase();settle();expect(e.phase=="draw" or e.phase=="possession","normal phase progression resumes after the finite extra preparations")
 e.phase="main";e.advance_phase();settle()
 expect(e.players[0].life==20,"each treasure deals three damage once at the end step")
 var duplicate=card("buddha_diamond","hand")
 expect(not e.field_error(duplicate,0).is_empty(),"a second same-name treasure cannot enter")
 fresh();card("life_spring");var top=card("chanting_youka","deck");e.players[0].deck.erase(top);e.players[0].deck.push_front(top)
 e.Roster.on_phase(e,"prepare");settle()
 expect(top.zone=="exile" and e.Mods.access(e,top,0).get("discount",0)==2,"life spring grants exactly a two-color discount on its exiled card")
 var discounted=e.cast_cost(0,top);var total=0
 for value in discounted.values():total+=int(value)
 mana()
 expect(total==2 and top in e.legal_casts(0),"spring reduces the total cost by two and exposes the exiled card through ordinary legal casts")
 e.turn+=1;expect(e.Mods.access(e,top,0).is_empty(),"life spring access expires at turn end")
func hourai_and_night():
 fresh();kaguya();var item=card("salamander_shield","hand");var spell=card("hourai_branch","hand")
 expect(use(spell).is_empty(),"Hourai branch has support from the leader zone");settle()
 expect(spell.zone=="field" and spell.timer==3 and e.Pack.chromatic(e,item,0),"Hourai branch has timer three and makes item costs chromatic")
 e.debug_free_payment=false
 expect(int(e.cast_cost(0,item).get("红/蓝/绿/黄/黑",0))==3,"chromatic item payment accepts any three colors through the existing payment system")
 var search=card("buddha_diamond","deck");e.players[0].deck.erase(search);e.players[0].deck.push_front(search);e.Roster.on_phase(e,"prepare");settle()
 expect(search.zone=="hand","Hourai's preparation trigger searches a deck item into hand")
 e.move_to(spell,"grave");expect(not e.Pack.chromatic(e,item,0),"item chromatic permission disappears when Hourai leaves")
 fresh();kaguya();spell=card("eternal_night","hand");mana()
 expect(e.cast_error(0,spell.uid).contains("禁止"),"eternal night cannot cast in the main phase")
 e.phase="prepare";var count=e.players[0].hand.size()
 expect(use(spell).is_empty(),"eternal night casts in its controller's preparation");settle()
 expect(e.active==1 and e.players[0].life==25 and e.players[0].hand.size()==count,"eternal night draws one, gains five and immediately ends the turn")
func run():
 if setup_pack():definitions();chanting();damage_and_bats();curse_link();fruits();grave_game();treasures();hourai_and_night()
 print("SCARLET MOON: %d checks; %d failures" % [checks,failures.size()])
 quit(1 if not failures.is_empty() else 0)
