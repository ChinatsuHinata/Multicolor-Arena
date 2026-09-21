extends SceneTree
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Store=preload("res://scripts/deck_store.gd")
const DB=preload("res://scripts/card_database.gd")
var checks=0
var failures=[]
var e
func expect(ok: bool,title: String):
 checks+=1
 if ok: print("PASS: "+title)
 else: failures.append(title); push_error(title)
func _initialize(): call_deferred("run")
func fresh():
 var deck=Store.blank("v09 tests"); deck.leader="70"
 for i in range(50): deck.main.append("164")
 e=Duel.new(); e.start(deck,deck,0,12)
 for p in e.players:
  p.hand=[]; p.field=[]; p.palette=[]; p.grave=[]; p.exile=[]; p.potato=false; p.mulligan_done=true; p.turns=3
 e.presentation_events.clear()
 e.phase="main"; e.active=0; e.priority=0; e.turn=5
func put(id: String,zone: String="field",who: int=0):
 var c=e.make_card(id,who,zone); e.players[who][zone].append(c); c.entered_turns=0; return c
func mana():
 for id in ["165","167","166","164","168"]:
  for i in range(8): put(id,"palette")
func one(): e.pass_priority(e.priority); e.pass_priority(e.priority)
func settle():
 for i in range(80):
  if e.winner!=-2: return
  e.pump_choices()
  if not e.pending.is_empty():
   match e.pending.kind:
    "trigger_order": e.choose_trigger_order(0)
    "effect_choice": e.choose_effect(e.pending.options[0])
    "leader_return": e.choose_return(false)
    "trigger": e.choose_trigger({})
    "timer": e.choose_timer(0)
    _: return
  elif not e.stack.is_empty(): one()
  else: return
 push_error("settle exceeded limit")
func cast(id: String,target: Dictionary={},zone: String="hand"):
 var c=put(id,zone)
 var choices=e.targets_for(id,0)
 if target.is_empty() and e.cards[id].kind=="符卡" and not choices.is_empty(): target=choices[0]
 var error=e.commit_cast(0,c.uid,target,e.payment(0,e.cast_cost(0,c)).plan)
 expect(error.is_empty(),"cast "+id+" "+error)
 settle(); e.priority=0
 return c
func enter(id: String,who: int=0):
 var c=e.make_card(id,who,"hand"); e.enter_field(c,who); e.pump_choices(); return c
func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 expect(DB.load_cards().size()>=65,"registered pool includes four v095 cards: 65 constructible cards")
 var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://work/v09-import-manifest.json"))
 for row in manifest: expect(DB.IDS.has(row.id) and not DB.load_cards()[row.id].rules_text.is_empty(),"import complete: "+row.name)
 var d=Store.blank("sort"); d.leader="70"; d.main=["99","53","96","53","99","68"]; d.side=["164","53","164"]
 var counts={}
 for id in d.main+d.side: counts[id]=counts.get(id,0)+1
 Store.sort_deck(d)
 var after={}
 for id in d.main+d.side: after[id]=after.get(id,0)+1
 expect(counts==after and d.leader=="70" and d.main.find("53")+1==d.main.rfind("53") and d.main.find("99")+1==d.main.rfind("99"),"sort keeps every copy and groups identities")
 var before=d.duplicate(true); Store.sort_deck(d); expect(before==d,"sort is idempotent")
 fresh(); var a=put("53","hand")
 expect(not e.debug_move(a.uid,"field").is_empty(),"debug disabled rejects mutation")
 e.debug_enabled=true; expect(e.debug_move(a.uid,"field").is_empty() and a.zone=="field","debug moves existing instance to field")
 var spell=put("96","hand"); expect(not e.debug_move(spell.uid,"field").is_empty() and spell.zone=="hand","debug rejects ordinary spell remaining on field")
 expect(not e.debug_move(a.uid,"leader").is_empty(),"debug rejects ordinary unit in leader slot")
 for zone in ["exile","grave","deck","palette","hand"]:
  expect(e.debug_move(a.uid,zone).is_empty() and a.zone==zone,"debug move to "+zone)
 var leader=e.players[0].leader
 expect(e.debug_move(leader.uid,"hand").is_empty() and e.debug_move(leader.uid,"leader").is_empty(),"debug chosen leader can return to leader zone")
 fresh(); a=enter("1"); settle(); expect(e.has_haste(a),"Sunny enters and grants haste")
 var crystal=put("164","palette"); crystal.tapped=true
 e.move_to(a,"grave"); settle(); expect(a.zone=="palette" and a.tapped and crystal.zone=="grave","crystal exchanges dead unit with tapped palette")
 fresh(); a=put("5"); e.move_to(a,"grave"); settle(); expect(e.players[0].hand.size()==1 and e.players[0].life==21,"Daiyousei death draw and life")
 fresh(); a=put("11","hand"); enter("14"); settle(); expect(a.zone=="field" and e.players[1].life==19,"autumn enters from hand and Koakuma drains")
 fresh(); a=put("15"); expect(not e.can_possess(a),"Rumia cannot possess"); e.move_to(a,"grave"); settle(); expect(a.zone=="palette" and a.tapped,"Rumia death enters tapped palette")
 fresh(); var dead=put("53","grave"); a=enter("18"); var pick=e.pending.options.filter(func(t): return t.parts[1].get("player",-1)==1)[0]; e.choose_effect(pick); settle()
 expect(dead.zone=="hand" and e.players[1].life==19,"Aya returns grave unit and deals its spirit to declared target")
 fresh(); mana(); a=put("21","grave"); var error=e.commit_extension(0,a.uid,{"none":true},e.payment(0,{"红":1}).plan); settle(); expect(error.is_empty() and a.zone=="hand","Mokou grave activation")
 fresh(); a=put("23"); e.move_to(a,"grave"); settle(); expect(e.players[0].life==21 and e.players[1].life==18,"Parsee death drains")
 fresh(); a=put("53","field",1); enter("28"); settle(); expect(a.damage==1,"Lunasa sweeps opposing units")
 fresh(); a=enter("29"); e.choose_effect(e.pending.options.filter(func(t): return t.color=="红")[0]); settle(); a.entered_turns=0; e.priority=0; var b=put("50","field",1); e.attack(0,a.uid); expect(e.legal_blockers().is_empty(),"Lyrica color evasion")
 fresh(); a=put("53"); enter("30"); settle(); expect(a.zone=="exile","Merlin blink leaves in exile"); e.phase="main"; e.advance_phase(); settle(); expect(a.zone=="field","Merlin returns next own end start")
 fresh(); a=put("33"); e.move_to(a,"grave"); e.pump_choices(); e.choose_effect({"player":1}); settle(); expect(e.players[1].life==18,"Reisen death damage")
 fresh(); a=put("35"); b=put("53","grave",1); error=e.commit_extension(0,a.uid,e.Extra.zone_refs(e,"grave",1)[0],[]); settle(); expect(error.is_empty() and a.tapped and b.zone=="exile" and e.players[1].life==19 and e.players[0].life==21,"Eiki exiles grave unit and drains")
 fresh(); a=put("38"); b=put("164","palette",1); var b2=put("165","palette",1); e.move_to(a,"grave"); e.pump_choices(); e.choose_effect(e.pending.options.filter(func(t): return t.has("parts"))[0]); settle(); expect(not e.can_possess(b) and not e.can_possess(b2),"Tojiko puts poverty on two palette cards")
 fresh(); b=put("50","field",1); a=enter("39"); settle(); expect(e.combat.get("step")=="block_window" and e.combat.blockers[0].uid==b.uid,"Youmu entry creates proper combat response window")
 fresh(); a=put("41"); b=put("53"); e.move_to(b,"grave"); settle(); expect(b.zone=="exile" and e.stat(a,"power")==3,"Yuuma devours and receives lasting counter")
 fresh(); a=put("48"); e.move_to(a,"grave"); settle(); expect(a.zone=="field" and a.get("plus_counters",0)==1,"Yuyuko returns with counter once"); e.move_to(a,"grave"); settle(); expect(a.zone=="grave","undying does not recur with counter")
 fresh(); b=put("164","palette",1); enter("49"); settle(); expect(b.zone=="grave" and e.players[1].palette.size()==1 and not e.can_possess(e.players[1].palette[0]),"Futo replaces palette with impoverished deck top")
 fresh(); mana(); a=put("61","grave"); b=put("53","hand"); error=e.commit_extension(0,a.uid,e.Extra.zone_refs(e,"hand",0)[0],e.payment(0,{"绿":1,"黑":1}).plan); settle(); expect(error.is_empty() and a.zone=="field" and a.tapped and b.zone=="grave","Yoshika pays colors and discards then reanimates tapped")
 fresh(); a=put("64"); e.move_to(a,"exile"); settle(); expect(e.units(0).size()==1 and e.units(0)[0].card_id=="token_ufo","Nue leave creates UFO token"); e.phase="main"; e.advance_phase(); settle(); expect(e.units(0).is_empty() and e.players[0].grave.is_empty(),"token ceases after next end sacrifice")
 fresh(); a=put("71"); a.leader=true; b=put("53"); error=e.commit_extension(0,a.uid,e.ref_target(b),[]); e.pump_choices(); e.choose_effect({"player":1}); settle(); expect(error.is_empty() and e.stat(a,"power")==2 and e.players[1].life==19,"leader Yuyuko sacrifice buff and death trigger")
 for i in range(3): b=put("53"); e.move_to(b,"grave"); settle()
 expect(e.usage_count(a.uid,"death_ping")==2,"Yuyuko leader trigger capped twice per turn")
 fresh(); a=enter("75"); a.leader=true; settle(); a.entered_turns=0; e.priority=0; b=put("53","field",1); e.attack(0,a.uid); expect(e.legal_blockers().is_empty(),"Sakuya cannot be blocked on entry turn")
 e.add_timer(e.players[0].leader,2); e.pump_choices(); expect(e.pending.get("kind")=="timer","Sakuya offers timer replacement"); e.choose_timer(-1); expect(e.players[0].leader.timer==1,"Sakuya decreases timer placement")
 fresh(); a=put("78"); a.leader=true; e.resolving_spell=true; e.damage_target(e.ref_target(a),3); e.judge(); e.resolving_spell=false; settle(); expect(e.delayed.size()==1,"Utsuho spell death schedules rebirth")
 e.start_turn(0); settle(); expect(a.zone=="field","Utsuho returns at next prepare")
 fresh(); a=put("79"); a.leader=true; b=put("53"); error=e.commit_extension(0,a.uid,e.ref_target(b),[]); settle(); expect(error.is_empty() and b.zone=="hand" and not e.extension_activation_error(0,a).is_empty(),"Aya leader bounce once per turn")
 fresh(); a=enter("87"); a.leader=true; settle(); expect(e.units(0).any(func(c): return c.card_id=="token_halfghost") and e.has_haste(a),"Youmu creates hasty first-strike halfghost")
 fresh(); a=put("soi_unit_004"); a.entered_turns=e.players[0].turns; expect(e.can_attack(0,a.uid),"wolf native haste")
 fresh(); a=put("87"); b=put("53","field",1); e.attack(0,a.uid); one(); e.block([b.uid]); one(); expect(a.damage==0 and b.zone=="grave" and e.combat.step=="first_damage_window","first strike kills before retaliation and opens response window")
 fresh(); mana(); a=put("53"); b=put("50","field",1); cast("94",{"uid":b.uid,"epoch":b.epoch,"sacrifice":e.ref_target(a),"sacrifice_value":1}); expect(a.zone=="grave" and b.zone=="grave","sacrifice cost and five damage")
 fresh(); mana(); cast("106"); expect(e.players[0].hand.size()==2,"draw two")
 fresh(); e.phase="prepare"; e.turn=2; a=put("106","deck"); e.players[0].deck.erase(a); e.players[0].deck.push_front(a); e.advance_phase(); expect(e.pending.get("kind")=="effect_choice","first draw miracle offers choice"); settle(); expect(a.zone=="grave" and e.players[0].hand.size()==2,"miracle casts without paying colors")
 fresh(); mana(); a=put("53"); cast("110",{"uid":a.uid,"epoch":a.epoch,"mode":"先制"}); expect(e.Extra.keyword(e,a,"先制"),"choose first strike mode")
 fresh(); mana(); a=put("39"); b=e.make_card("96",1,"stack"); e.stack=[{"id":123,"kind":"card","card":b,"owner":1,"target":e.ref_target(a),"name":"counter target"}]; cast("118",{"stack_id":123}); expect(b.zone=="grave" and e.players[0].life==14,"Youmu zero-cost counter also triggers six damage")
 fresh(); mana(); a=put("48"); var timed=cast("120"); e.players[0].life=-2; e.judge(); expect(e.winner==-2 and timed.zone=="field" and timed.timer==3,"timed butterfly prevents life loss defeat")
 for i in range(3): e.active=0; e.phase="end"; e.cleanup_done=false; e.cleanup_end()
 expect(e.winner==1,"butterfly zero timer loses")
 fresh(); mana(); a=put("6","field",1); cast("130",e.ref_target(a)); expect(a.zone=="grave" and e.players[0].life==18,"destroy high-spirit unit and lose two life")
 fresh(); mana(); a=put("53"); cast("131",{"uid":a.uid,"epoch":a.epoch,"mode":"不会被消灭"}); e.damage_target(e.ref_target(a),20); e.judge(); expect(a.zone=="field","indestructible prevents lethal damage destruction")
 fresh(); mana(); a=put("53","field",1); cast("139",e.ref_target(a)); expect(e.players[0].hand.size()==1 and a.damage==1,"draw then damage equal to remaining hand size")
 fresh(); mana(); a=put("53"); b=put("164","field",1); cast("141"); expect(a.zone=="exile" and b.zone=="exile","exile all permanents")
 fresh(); mana(); a=put("53","grave"); cast("143",{"uid":a.uid,"epoch":a.epoch,"zone":"grave","mode":"移回战场"}); expect(a.zone=="field","Aurora reanimation mode")
 fresh(); mana(); a=put("53"); cast("147",e.ref_target(a)); expect(e.stat(a,"power")==1 and e.stat(a,"health")==1 and e.stat(a,"spirit")==4,"signed stat modifiers")
 fresh(); mana(); put("78"); a=cast("162",{"player":1},"deck"); expect(a.zone=="grave" and e.players[1].life==17,"Hell Tokamak casts legally from deck")
 fresh(); mana(); a=put("50"); b=put("53","grave"); cast("163",{"uid":b.uid,"epoch":b.epoch,"zone":"grave","sacrifice":e.ref_target(a),"sacrifice_value":4}); expect(a.zone=="grave" and b.zone=="field","sacrifice reanimate uses sacrificed mana value")
 fresh(); a=put("53"); b=put("169"); expect(e.stat(a,"spirit")==2,"Scarlet mansion spirit aura"); e.move_to(b,"grave"); expect(e.stat(a,"spirit")==1,"aura ends when enchantment leaves")
 fresh(); put("53"); put("54"); put("57"); a=put("174","hand"); expect(e.cast_cost(0,a).values().all(func(n): return n==0),"unit count reduces colored cost")
 fresh(); mana(); cast("176",{"parts":[{"none":true,"mode":"抓一张牌"},{"none":true,"mode":"抓一张牌"}]}); expect(e.players[0].hand.size()==2,"two modes may repeat")
 fresh(); mana(); a=put("53"); cast("177",e.ref_target(a)); e.damage_target(e.ref_target(a),20); expect(a.damage==0 and e.stat(a,"power")==4 and e.stat(a,"health")==1,"protection buff prevents damage and changes stats")
 fresh(); a=put("87"); a.leader=true; b=put("54","field",1); e.attack(0,a.uid); one(); e.block([b.uid]); one(); settle(); expect(b.zone=="exile","Youmu combat damage exiles surviving damaged unit through its trigger")
 fresh(); mana(); a=put("53","field",1); cast("143",{"player":1,"mode":"牺牲单位"}); expect(a.zone=="grave","Aurora opponent chooses sacrifice")
 fresh(); mana(); cast("143",{"player":1,"mode":"失去生命"}); expect(e.players[1].life==17,"Aurora drain mode")
 fresh(); mana(); a=put("53","grave",1); cast("131",{"player":1,"mode":"移除墓地"}); expect(a.zone=="exile","Divine exiles selected graveyard")
 fresh(); mana(); a=e.make_card("106",1,"stack"); e.stack=[{"id":800,"kind":"card","card":a,"owner":1,"target":{"none":true},"name":"draw two"}]; cast("131",{"stack_id":800,"mode":"反制非符"}); expect(a.zone=="grave" and e.players[1].hand.is_empty(),"Divine counters a non-spell-type card")
 fresh(); a=put("39","field",1); b=put("118","hand",1); var incoming=e.make_card("96",0,"stack"); e.stack=[{"id":900,"kind":"card","card":incoming,"owner":0,"target":e.ref_target(a),"name":"incoming damage"}]; e.priority=1
 e.ai_step(1); expect(b.zone=="stack" and e.stack.back().target.stack_id==900,"AI responds with new Youmu counter")
 fresh(); e.debug_enabled=true
 for i in range(6): put("53")
 a=put("14","hand"); expect(not e.debug_move(a.uid,"field").is_empty() and a.zone=="hand","debug respects six occupied slots")
 a=put("28","hand"); expect(e.debug_move(a.uid,"field").is_empty(),"slot-free Prismriver can enter full field")
 var invalid=JSON.parse_string(FileAccess.get_file_as_string("res://cards/1.json")); invalid["能力绑定"][0]["参数"]["效果"]="unknown"
 expect(not DB.validate_definition(invalid,"1").is_empty(),"schema rejects unknown extension effect")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"user decks unchanged")
 print("V09_RULES: %d checks; %d failures" % [checks,failures.size()]); quit(1 if not failures.is_empty() else 0)
