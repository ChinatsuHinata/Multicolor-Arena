extends "res://tests/support/rules_base.gd"
const Registry=preload("res://scripts/rules/mod_registry.gd")
const Codec=preload("res://net/state_codec.gd")
const Seat=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
const Gateway=preload("res://net/command_gateway.gd")
const Series=preload("res://net/series_controller.gd")

func setup_pack() -> bool:
 Registry._shared=Registry.new()
 var error=Registry.shared().register_pack("res://examples/testmod")
 expect(error.is_empty(),"testmod registers: "+error)
 Store.CARDS=DB.load_cards()
 expect(Store.CARDS.has("testmod/utsuho"),"external definitions load: "+DB.last_error)
 return Store.CARDS.has("testmod/utsuho")
func modcard(id: String,zone: String="field",who: int=0) -> Dictionary:return put("testmod/"+id,zone,who)
func accept():
 var a=e.Pack.ai_target(e,e.pending.owner,e.pending.options,"mod:test")
 e.choose_effect(a)
func settle():
 for i in range(90):
  if e.winner!=-2:return
  if not e.pending.is_empty():
   match e.pending.kind:
    "effect_choice":accept()
    "trigger_order":e.choose_trigger_order(0)
    "leader_return":e.choose_return(false)
    "timer":e.choose_timer(0)
    "reveal_review":e.confirm_revealed(e.pending.owner,e.pending.serial)
    _:return
  elif not e.stack.is_empty():one()
  elif not e.triggers.is_empty() or not e.mod_resolution.is_empty():e.pump_choices()
  else:return
 expect(false,"resolution completes within bounded steps")
func cast_mod(c: Dictionary,x: int=0,target: Dictionary={}) -> String:
 e.priority=c.owner;e.debug_enabled=true;e.debug_free_payment=true;e.catalogue_x_override=20
 if target.is_empty():
  var options=e.targets_for(c.card_id,c.owner,c.uid)
  if options.is_empty():options=[{"none":true}]
  target=options.filter(func(o):return int(o.get("x",0))==x)[0]
 return e.commit_cast(c.owner,c.uid,target,[])
func static_rules():
 fresh();e.players[0].deck.resize(8)
 var u=modcard("utsuho");var v=modcard("visitor")
 expect(e.stat(u,"power")==10 and e.stat(u,"health")==10 and e.has_haste(u),"Utsuho continuously subtracts library size and grants haste")
 e.draw(0,2);expect(e.stat(u,"health")==12,"library change immediately recomputes stats")
 var aura=modcard("resonance");aura.timer=3
 expect(e.stat(v,"spirit")==3 and e.stat(u,"health")==15,"timer aura stacks with independent library modifier")
 aura.timer=2;expect(e.stat(v,"power")==3,"timer query is live")
 var b=modcard("byakuren");b.leader=true
 expect(not e.Roster.protected(e,e.ref_target(b),1,false) and not e.Roster.protected(e,e.ref_target(b),1,true) and e.Cat.target_tax(e,1,e.ref_target(b))==2 and e.Cat.target_tax(e,0,e.ref_target(b))==0,"Byakuren taxes opponent targets by two without prohibiting them")
 expect(e.Extra.keyword(e,b,"英勇"),"static keyword is visible to combat")
 var before=Codec.capture(e)
 for i in range(2):Seat.build(e,0);Observer.build(e);e.stat(u,"health")
 expect(Codec.capture(e)==before,"static and projection queries never mutate saved state")
 e.move_to(aura,"grave");expect(e.stat(v,"power")==1,"aura ceases after departure")

func visitor_names_and_copies():
 fresh()
 var definition=e.cards["testmod/visitor"]
 expect(definition.name=="「人里的参拜者」" and definition.character=="人里的参拜者" and definition.title.is_empty(),"visitor has a bracketed name and no title")
 var first=modcard("visitor")
 var second=modcard("visitor","hand")
 mana()
 expect(e.cast_error(0,second.uid).is_empty(),"another visitor on the battlefield does not prevent casting")
 expect(cast_mod(second).is_empty(),"second visitor can be cast normally")
 settle()
 var third=modcard("visitor","hand")
 expect(e.field_error(third,0).is_empty() and not e.miracle_blocked(third,0),"visitor copies also pass effect-entry and miracle checks")
 e.detach(third);e.enter_field(third,0);e.pump_choices();settle()
 expect([first,second,third].all(func(c):return c.zone=="field") and e.units(0).size()==3,"three visitor copies remain together after state checks")
 var count=e.players[0].hand.size()
 e.Mods.targeted(e,e.ref_target(second),1);e.pump_choices();settle()
 expect(e.players[0].life==21 and e.players[0].hand.size()==count+1,"only the targeted visitor copy draws and gains life")

func furnace_rules():
 fresh();var f=modcard("furnace","exile");mana()
 expect(not e.cast_error(0,f.uid).is_empty() and f not in e.legal_casts(0),"furnace has no unconditional exile cast permission")
 var fuel=modcard("fuel","exile");var control=modcard("control","exile");var spare=modcard("fuel","exile")
 var foreign=modcard("control","exile");foreign.original_owner=1
 var opponent=modcard("fuel","exile",1);var unrelated=put("164","exile")
 e.move_to(f,"hand");expect(cast_mod(f).is_empty(),"furnace casts normally from hand");one();one()
 expect(e.pending.get("trigger",{}).get("mod_resume",false),"furnace entry opens rod recovery selection")
 var spec=e.pending.options[0];var pool=spec.selection[0].pool
 expect(spec.selection[0].min==0 and spec.selection[0].max==2 and pool.size()==3,"furnace offers zero to two owned exiled rods")
 var saved=Codec.capture(e);var answer=spec.duplicate(true);answer.erase("selection")
 var ctx=e.Mods.Context.new(e,{})
 answer.picks=[[ctx.ref(fuel),ctx.ref(control)]]
 for picks in [[ctx.ref(fuel),ctx.ref(fuel)],[ctx.ref(fuel),ctx.ref(control),ctx.ref(spare)],[ctx.ref(foreign)],[ctx.ref(opponent)],[ctx.ref(unrelated)]]:
  var forged=answer.duplicate(true);forged.picks=[picks]
  expect(not Gateway.apply(e,0,{"name":"choose_effect","args":[forged]}).is_empty() and Codec.capture(e)==saved,"invalid furnace selection cannot move cards")
 expect(not Gateway.apply(e,1,{"name":"choose_effect","args":[answer]}).is_empty(),"opponent cannot submit furnace recovery")
 e.choose_effect(answer);settle()
 expect(fuel.zone=="deck" and control.zone=="deck" and spare.zone=="exile" and foreign.zone=="exile","only chosen owned rods are shuffled into library")
 var final_state=Codec.capture(e);var restored=Duel.new()
 expect(Codec.restore(restored,saved).is_empty(),"paused furnace selection restores")
 var original=e;e=restored;e.choose_effect(answer);settle()
 expect(Codec.capture(e)==final_state,"furnace recovery restores exact card movements and shuffle RNG");e=original
 for count in [0,1,2]:
  fresh();var rods=[]
  for i in range(3):rods.append(modcard("fuel","exile"))
  f=modcard("furnace","hand");e.detach(f);e.enter_field(f,0);e.pump_choices();one()
  answer=e.pending.options[0].duplicate(true);answer.erase("selection");answer.picks=[rods.slice(0,count).map(func(c):return ctx.ref(c))]
  var rng_before=e.rng.state;e.choose_effect(answer);settle()
  expect(rods.filter(func(c):return c.zone=="deck").size()==count,"furnace can choose %d rods" % count)
  if count==0:expect(e.rng.state==rng_before,"choosing zero does not shuffle")
 for use_card in [false,true]:
  fresh();f=modcard("furnace","deck");e.active=1;e.priority=1;e.phase="end"
  var lower=modcard("fuel","hand",1);e.detach(lower);e.shift(lower,"stack")
  e.stack.append({"id":99,"kind":"card","card":lower,"owner":1,"target":{},"name":"underneath"})
  e.move_to(f,"exile");e.pump_choices();one()
  expect(e.pending.get("trigger",{}).get("effect","")=="cat:grant" and e.pending.trigger.data.free,"deck-exiled furnace offers immediate free use even outside normal timing")
  saved=Codec.capture(e);restored=Duel.new();expect(Codec.restore(restored,saved).is_empty(),"free furnace choice restores")
  if use_card:e.choose_effect(e.pending.options[0])
  else:e.choose_effect({})
  expect(f.zone==("stack" if use_card else "exile"),"furnace use is optional and uses the stack")
  expect(e.players[0].palette.is_empty(),"free furnace uses no color resources")
  if not use_card:
   e.stack.clear();e.active=0;e.phase="main";e.priority=0
   expect(not e.cast_error(0,f.uid).is_empty(),"declining does not grant later exile use")
 fresh();e.players[0].deck.clear();fuel=modcard("fuel","exile");modcard("control","exile");e.draw(0)
 expect(e.winner==1 and fuel.zone=="exile" and e.pending.is_empty(),"rods no longer replace an empty-library draw")

func rod_rules():
 for kind in ["fuel","control"]:
  fresh();e.players[0].deck.clear()
  var drawn=modcard("control","deck");var fuel=modcard("fuel","deck");var control=modcard("control","deck");var last=put("164","deck")
  var victim=put("character-fdf-106","field",1);var item=modcard(kind,"hand")
  expect(cast_mod(item).is_empty(),kind+" casts");settle()
  var pillars=e.units(0).filter(func(c):return c.card_id=="testmod/pillar")
  expect(drawn.zone=="hand" and fuel.zone=="exile" and control.zone=="exile" and last.zone=="deck",kind+" draws before exiling the next two cards")
  expect(pillars.size()==1 and e.players[0].life==20,"exiled control creates one pillar instead of gaining life")
  if not pillars.is_empty():
   var pillar=pillars[0]
   expect(e.stat(pillar,"power")==3 and e.stat(pillar,"health")==3 and e.stat(pillar,"spirit")==2 and e.Pack.colors(e,pillar)==["红","绿"] and e.Cat.race(e,pillar,"御柱"),"pillar has exact red-green 3/3/2 stats and race")
   expect(not e.Extra.keyword(e,pillar,"英勇") and not e.Extra.keyword(e,pillar,"不占战场格"),"pillar receives no unprinted keywords")
 for owner in [0,1]:
  fresh();var victim=put("character-fdf-106","field",owner);var other=put("character-fdf-106","field",1-owner)
  var fuel=modcard("fuel","deck");e.move_to(fuel,"exile");e.pump_choices()
  expect(e.pending.options.any(func(o):return o.get("uid",-1)==victim.uid),"fuel can target either player's unit")
  e.choose_effect(e.Mods.Context.new(e,{}).ref(victim));one()
  expect(victim.damage==3 and other.damage==0,"fuel deals damage to the chosen unit without randomness")
 fresh();var fuel=modcard("fuel","hand");e.move_to(fuel,"exile");var control=modcard("control","grave");e.move_to(control,"exile");e.pump_choices()
 expect(e.stack.is_empty() and e.pending.is_empty() and e.triggers.is_empty(),"rod exile triggers only fire from the library")
 fresh();e.players[0].deck.clear();var only=put("164","deck");var item=modcard("fuel","hand");cast_mod(item);settle()
 expect(only.zone=="hand" and e.players[0].exile.is_empty() and e.winner==-2,"rod with one library card draws it and exiles nothing")
 fresh();e.players[0].deck.clear();item=modcard("control","hand");cast_mod(item);settle()
 expect(e.winner==1,"rod draw from empty library loses normally")

func mod_names():
 expect(DB.mod_display_name("魔人经卷")=="「魔人经卷」" and DB.mod_display_name("【星莲の船】")=="「星莲ノ船」","all unprefixed mod names use Japanese brackets and katakana no")
 expect(DB.mod_display_name("光热【high tenSion blade】")=="光热「high tenSion blade」" and DB.mod_display_name("大魔法「魔神复诵」")=="大魔法「魔神复诵」","prefixed mod names preserve their prefixes with Japanese brackets")
 for id in Store.CARDS:
  var definition=Store.CARDS[id]
  if definition.get("mod_namespace","").is_empty():continue
  expect("「" in definition.name and "」" in definition.name and "【" not in definition.name and "の" not in definition.name,"mod library name normalized: "+id)
 var utsuho=Store.CARDS["testmod/utsuho"]
 expect("(-X/-X/-X)" not in utsuho.rules_text and "-X/-X/-X" in utsuho.rules_text,"Utsuho stat penalty has no outer parentheses")

func spells_and_events():
 fresh();e.players[0].deck.resize(10)
 var u=modcard("utsuho");u.leader=true
 var blade=modcard("blade","hand");var victim=put("70","field",1)
 expect(cast_mod(blade,0,e.Mods.Context.new(e,{"source":blade,"owner":0}).ref(victim)).is_empty(),"blade accepts unit target")
 one();expect(e.pending.get("trigger",{}).get("mod_resume",false),"blade inspects top four after damage")
 var shown=e.players[0].deck.slice(0,4).map(func(c):return c.uid)
 expect(Seat.build(e,0).queries.lookup.has(shown[0]) and not Seat.build(e,1).queries.lookup.has(shown[0]),"inspection remains private")
 settle();expect(e.players[0].exile.size()==3 and e.players[0].deck.back().uid in shown,"blade exiles three and bottoms remainder")
 fresh();e.players[0].deck.resize(10);u=modcard("utsuho");u.leader=true
 var ten=modcard("ten_stars","hand");expect(cast_mod(ten).is_empty(),"ten stars can be cast");settle()
 expect(e.players[0].hand.size()==2 and e.players[0].palette.size()==2 and e.players[0].palette.all(func(c):return c.tapped) and e.players[0].exile.size()==6,"ten stars allocates 2 hand / 2 tapped palette / 6 exile")
 fresh();var visitor=modcard("visitor");var count=e.players[0].hand.size()
 e.Mods.targeted(e,e.ref_target(visitor),1);e.pump_choices();settle()
 expect(e.players[0].life==21 and e.players[0].hand.size()==count+1,"opponent target trigger draws and gains life")
 fresh();e.players[0].deck.resize(5);var recover=modcard("blade","exile");u=modcard("utsuho","hand");u.leader=true
 e.detach(u);e.enter_field(u,0);e.pump_choices();settle()
 expect(e.players[0].deck.size()==3 and recover.zone=="deck","Utsuho enters, exiles three and returns owned character spell")
 fresh();e.players[0].deck.resize(5);recover=modcard("blade","exile");u=modcard("utsuho","hand");u.leader=true
 e.detach(u);e.enter_field(u,0);e.pump_choices();accept();one()
 e.choose_effect(e.pending.options.filter(func(o):return o.get("exile",true)==false)[0]);settle()
 expect(e.players[0].deck.size()==6 and recover.zone=="deck","Utsuho may skip exile and still choose recovery")

func x_cards():
 fresh();var b=modcard("byakuren");b.leader=true
 var sutra=modcard("sutra");var palette=[]
 for i in range(6):var c=put("164","palette");c.tapped=true;palette.append(c)
 var aura=modcard("resonance","hand")
 var cost=e.cast_cost(0,aura,{"x":2})
 expect(cost.get("绿",0)==1 and cost.get("黄",0)==2 and cost.get("黑",0)==2,"shared X pays both yellow and black")
 expect(cast_mod(aura,2).is_empty(),"resonance cast")
 expect(e.pending.get("trigger",{}).get("mod_replace",false),"first X offers an optional doubling choice")
 accept()
 expect(aura.cast_x==4 and e.stack[0].target.x==4,"first X is doubled after payment before cast observers")
 settle();expect(aura.zone=="field" and aura.timer==4,"ordinary timed spell enters with modified X timers")
 expect(palette.filter(func(c):return not c.tapped).size()==4,"sutra sees modified X and untaps that many")
 expect(e.stat(b,"power")==6,"timed static aura modifies units")
 var recite=modcard("recitation","hand");expect(cast_mod(recite,2).is_empty(),"character timed spell casts")
 expect(recite.cast_x==2,"second X in same turn is not doubled")
 settle();expect(recite.timer==2,"recitation gets X timers")
 e.Mods.broadcast(e,"phase",{"phase":"end","active":0});e.pump_choices();settle()
 expect(b.get("plus_counters",0)==2,"end phase trigger places timer-count counters")
 expect(palette.filter(func(c):return not c.tapped).size()==4,"sutra uses once per turn")
 var ship=modcard("ship","hand");expect(cast_mod(ship,3).is_empty(),"X enchantment declares X without card-specific UI");settle()
 expect(b.get("plus_counters",0)==5,"ship enter trigger uses cast X")
 fresh();e.players[0].leader.card_id="testmod/byakuren"
 var superhuman=modcard("superhuman","hand");expect(cast_mod(superhuman,11).is_empty(),"support allows leader-zone Byakuren")
 settle();b=e.players[0].leader
 expect(b.zone=="field" and b.get("plus_counters",0)==11 and e.has_haste(b),"superhuman brings leader in, adds three-stat counters and grants haste")

func room_boundary():
 var series=Series.new();series.setup(Series.BO1,false,"unrestricted")
 var deck=Store.blank();deck.leader="testmod/byakuren"
 expect(not series.set_deck(0,deck).is_empty(),"ordinary room rejects mod decks")
 series.setup(Series.BO3,false,Store.RuleSet.MOD)
 expect(series.state.mods==Registry.shared().manifest(),"mod room locks exact content manifest")
 expect(series.set_deck(0,deck).is_empty(),"mod room accepts selected pack cards")
 var base=Duel.new();base.configure_mods(false)
 expect(base.mod_registry.manifest().is_empty() and not base.cards.has("testmod/utsuho"),"ordinary authority excludes mod definitions")


func layers():
 expect(Registry.shared().register_pack("res://tests/support/mod_layers").is_empty(),"independent layer fixture registers")
 fresh();var target=put("70");target.plus_counters=2
 var definition=e.cards["164"].duplicate(true);definition.abilities=[];e.cards["layer_source"]=definition
 var source=e.make_card("164",0,"field");source.card_id="layer_source";e.players[0].field.append(source)
 var modifier=func(id,layer,operation,value,depends=[],from_current=false):return {"实现":"mod","实例键":id,"参数":{"能力":"layers.test/layer","id":id,"layer":layer,"operation":operation,"value":value,"depends_on":depends,"from_current":from_current}}
 definition.abilities=[modifier.call("dependent",30,"set",1,["layers.test/layer/add"],true),modifier.call("add",30,"add",3),modifier.call("base",10,"set",5),modifier.call("multiply",40,"multiply",2)]
 expect(e.stat(target,"power")==22,"base set precedes counters; dependency re-evaluates using current value; multiplication last")
 definition.abilities.reverse();expect(e.stat(target,"power")==22,"registration/binding order cannot change dependency result")
 definition.abilities=[modifier.call("a",30,"set",2,["layers.test/layer/b"]),modifier.call("b",30,"add",4,["layers.test/layer/a"])]
 expect(e.stat(target,"power")==6,"dependency cycle breaks deterministically by timestamp and instance key")
 definition.abilities.reverse();expect(e.stat(target,"power")==6,"cycle is independent of loading order")
 definition.abilities=[modifier.call("set",10,"set",2)]
 var other=e.make_card("164",0,"field");other.card_id="layer_other";e.players[0].field.append(other)
 e.cards.layer_other=e.cards["164"].duplicate(true);e.cards.layer_other.abilities=[modifier.call("set",10,"set",8)]
 source.mod_timestamp=10;other.mod_timestamp=11
 expect(e.stat(target,"power")==10,"same-layer overriding uses later source timestamp")
 source.mod_timestamp=12;expect(e.stat(target,"power")==4,"new source timestamp changes override order")
 e.players[0].field.erase(other)
 var emergent=modifier.call("emergent",30,"add",10,["layers.test/layer/add"]);emergent["参数"].threshold=8
 definition.abilities=[emergent,modifier.call("add",30,"add",3)]
 expect(e.stat(target,"power")==18,"recheck finds newly applicable dependent modifiers")
 var lock=modifier.call("lock",30,"set",0);lock["参数"].query="action_lock";definition.abilities=[lock]
 var c=modcard("fuel","hand");mana()
 expect(e.cast_error(0,c.uid).contains("禁止") and not e.can_attack(0,target.uid),"common static restrictions block casts and attacks")
 var discount=modifier.call("discount",30,"add",-1);discount["参数"].query="cost";definition.abilities=[discount]
 expect(e.cast_cost(0,c).get("红",0)==0 and e.cast_cost(0,c).get("黑",0)==1,"static color cost adjustment applies exactly once")
 fresh();e.players[0].deck.clear()
 var leader=e.players[0].leader;leader.zone="field";e.players[0].field.append(leader)
 var replacement=e.cards[leader.card_id].duplicate(true);replacement.abilities=[{"实现":"mod","实例键":"return","参数":{"能力":"layers.test/replacement"}}]
 e.cards[leader.card_id]=replacement
 e.draw(0);e.pump_choices()
 expect(e.pending.kind=="leader_return" and e.players[0].life==20,"replacement operations pause before life gain at leader return decision")
 var saved=Codec.capture(e);var restored=Duel.new()
 expect(Codec.restore(restored,saved).is_empty(),"replacement operation cursor restores")
 restored.choose_return(false)
 expect(restored.players[0].life==23 and restored.mod_changes.is_empty(),"restored replacement continues after intrinsic choice exactly once")

func run():
 if setup_pack():mod_names();static_rules();visitor_names_and_copies();furnace_rules();rod_rules();spells_and_events();x_cards();room_boundary();layers()
 print("TESTMOD: %d checks; %d failures" % [checks,failures.size()])
 quit(1 if not failures.is_empty() else 0)
