extends "res://tests/test_v013_rules.gd"
func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 fresh();var star=enter("3")
 expect(e.stack.size()==1 and e.pending.get("kind")=="effect_choice" and e.pending.get("no_legal_targets",false),"Star enters stack before optional prompt with no item")
 var n=e.next_stack;e.choose_effect({"none":true});one()
 expect(e.stack.is_empty() and e.pending.is_empty() and e.next_stack==n,"accepting targetless optional ability resolves without fabricated target")
 fresh();star=enter("3");e.choose_effect({});expect(e.stack.is_empty() and e.pending.is_empty(),"declining removes announced optional ability")
 fresh();var k=enter("66");expect(e.stack.size()==1 and e.pending.no_legal_targets,"Kyouko still announces with fewer than three grave cards")
 e.choose_effect({"none":true});one();expect(e.players[0].life==20,"Kyouko gains no life when required three targets do not exist")
 fresh();var a=put("50","grave");var b=put("51","grave");var c=put("52","grave");k=enter("66")
 expect(e.stack.size()==1 and not e.pending.no_legal_targets,"Kyouko announces with three legal grave targets")
 e.choose_effect(choose_groups(e.pending.options,[[Pack.ref(e,a),Pack.ref(e,b),Pack.ref(e,c)]]));one()
 expect(e.players[0].life==21 and [a,b,c].all(func(u):return u.zone=="deck"),"Kyouko shuffles three selected cards and gains one life")
 fresh();c=enter("character-fdf-116");expect(e.pending.is_empty() and e.stack.size()==1 and e.stack[0].no_legal_targets,"mandatory Eirin no-target trigger goes onto stack without a selection prompt")
 one();expect(e.stack.is_empty(),"mandatory no-target trigger completes safely")
 fresh();c=enter("68");expect(e.stack.size()==1 and e.pending.kind=="trigger","Marisa effect-entry also creates ETB trigger")
 e.choose_trigger(e.ref_target(c));one();expect(c.damage==3 or c.zone=="grave","Marisa ETB target damage resolves")
 fresh();c=enter("character-fdf-101");expect(e.stack.size()==1 and e.pending.kind=="effect_choice","Momiji naming uses stack")
 var name=e.cards["50"].name;e.choose_effect(e.pending.options.filter(func(t):return t.card_name==name)[0]);one()
 expect(c.locked_name==name and e.history.any(func(row):return "宣言" in row.text and name in row.text),"declaration recorded and applied")
 expect(e.presentation_events.any(func(ev):return ev.type=="result" and name in ev.text),"declaration queued for visible result")
 fresh();var heads=e.flip_coin(1);expect(e.history.back().text==("人机掷硬币 · "+("正面" if heads else "反面")) and e.presentation_events.back().type=="result","coin outcome visible and recorded exactly once")
 fresh();c=put("character-lof-001");c.entered_turns=e.players[0].turns
 expect(e.summoning_sick(c) and e.extension_activation_error(0,c,"courage_ping")=="不能横置","new non-haste unit cannot pay tap cost")
 e.apply_turn_buff(e.ref_target(c),{"疾行":true});e.active=1;e.priority=0
 expect(not e.summoning_sick(c) and e.extension_activation_error(0,c,"courage_ping").is_empty(),"gained haste permits tap activation on opponent turn")
 expect(e.commit_extension(0,c.uid,{"player":1},[],"courage_ping").is_empty(),"opponent-turn haste activation commits")
 one();expect(c.tapped and e.players[1].life==19,"opponent-turn activation actually resolves")
 fresh();c=put("spell-fdf-040");e.add_timer(c,3);e.pump_choices();expect(e.pending.is_empty() and c.timer==3,"time spell gets counters without self adjustment")
 e.choose_timer(1);expect(c.timer==3,"unsolicited time adjustment is rejected")
 var s=put("75");s.leader_counters=1;e.add_timer(c,1);e.pump_choices();expect(e.pending.kind=="timer" and e.pending.change.source.uid==s.uid,"explicit Sakuya replacement retains its source")
 e.choose_timer(-1);expect(c.timer==3,"legal Sakuya replacement adjusts a placement")
 e.add_timer(c,0);e.pump_choices();expect(e.pending.is_empty(),"zero placement cannot create arbitrary adjustment")
 fresh();mana();c=put("50","hand");e.players[0].next_free_unit=e.turn
 expect(e.offers_free_cast(0,c) and e.cast_cost(0,c).values().all(func(x):return x==0),"eligible optional free use detected")
 e.paid_cast_uid=c.uid;var paid=e.cast_cost(0,c);expect(paid.values().any(func(x):return x>0),"paid choice restores normal cost")
 var plan=e.payment(0,paid).plan;expect(e.commit_cast(0,c.uid,{"none":true},plan).is_empty() and not plan.is_empty(),"paid choice actually pays and publishes card")
 fresh();mana();c=put("96","exile");c.free_exile_owner=0
 expect(e.offers_free_cast(0,c),"Seiran exile permission offers payment choice")
 put("spell-ucs-031","field",1);expect(e.cast_cost(0,c).get("红/蓝/绿/黄/黑",0)==1,"free base colors retain extra casting taxes")
 e.paid_cast_uid=c.uid;expect(e.cast_cost(0,c).values().any(func(x):return x>0),"normal payment also works for Seiran exile grant")
 fresh();c=put("50","hand");e.Cat.grant_cast(e,c,0,true);expect(e.pending.kind=="effect_choice","effect-granted free casting creates choice")
 e.set_granted_payment(true);expect(e.paid_cast_uid==c.uid and e.Cat.granted_cost(e,e.pending.trigger,{"none":true}).values().any(func(x):return x>0),"effect-granted cast paid option keeps permission but restores price")
 fresh();c=put("50","hand");for z in ["deck","grave","exile","palette","field","hand"]:e.debug_enabled=true;e.debug_move(c.uid,z)
 expect(e.presentation_events.filter(func(ev):return ev.type=="move").size()==6,"all debug zone changes create motion snapshots")
 expect(e.presentation_events[0].card.zone=="hand" and e.presentation_events[-1].to=="hand","motion retains original and destination zones")
 fresh();c=put("character-ucs-032");a=put("51","field",1);e.Extra.on_enter(e,a)
 expect(e.triggers.any(func(t):return t.source.uid==c.uid and t.effect=="sakuya_timer"),"Sakuya observes other players entering units")
 fresh();resolve_spell("spell-fdf-014");a=put("50");e.Extra.on_enter(e,a)
 expect(e.players[1].life==20 and e.triggers.any(func(t):return t.effect=="cat:etb_curse"),"lasting ETB curse waits on trigger stack")
 settle();expect(e.players[1].life==18,"lasting ETB curse resolves after priority")
 fresh();c=put("50","grave",1);e.Roster.field_many(e,[c],0)
 expect(c.owner==0 and c.zone=="field" and e.presentation_events[0].card.owner==1 and e.presentation_events[0].to_owner==0,"cross-owner reanimation keeps correct source and destination in motion")
 audit_entries();audit_activations()
 expect(saved==FileAccess.get_file_as_string(Store.SAVE_PATH),"saved decks preserved")
 print("V015_RULES: ",checks," checks; ",failures," failures");quit(0 if failures.is_empty() else 1)
func audit_entries():
 fresh();var ids=e.cards.keys();var rows=[]
 for id in ids:
  var info=e.cards[id];var text=info.rules_text.replace("进入战场","进战场")
  if info.kind=="符卡" and "时符" not in info.spell_type:continue
  if not ["该单位进战场","该牌进战场","该结界进战场","当单位进战场"].any(func(s):return s in text):continue
  fresh();mana();e.active=1
  put("character-fdf-112");put("50");put("51","field",1);put("164");put("50","grave");put("51","grave");put("52","grave")
  var c=put(id);c.leader_counters=1;c.ichirin_paid=true
  e.Extra.on_enter(e,c)
  var own=e.triggers.filter(func(t):return t.source.uid==c.uid)
  var ok=not own.is_empty()
  expect(ok,"ETB event registered "+id+" "+info.name)
  # Exercise the same ETB on an otherwise empty board, including every no-target path.
  fresh();e.active=1;c=put(id);c.leader_counters=1;c.ichirin_paid=true
  e.Extra.on_enter(e,c);settle()
  expect(e.pending.is_empty() and e.stack.is_empty(),"empty-board ETB finishes "+id)
  rows.append({"id":id,"name":info.name,"events":own.map(func(t):return t.get("effect","marisa_enter")),"passed":ok})
 FileAccess.open("res://work/v015/etb-audit.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
func audit_activations():
 fresh();var ids=e.cards.keys();var rows=[]
 for id in ids:
  if e.Extra.activation_kind(e.cards[id]).is_empty() and not e.cards[id].abilities.any(func(a):return a.get("实现")=="activated_damage"):continue
  fresh();mana();var c=put(id);c.leader_counters=1;c.timer=4;c.courage=5;c.plus_counters=3;c.entered_turns=0
  put("50");put("51","field",1);put("7");put("character-fdf-094");put("50","hand");put("51","hand");put("96","hand")
  for z in ["grave","exile"]:
   for other in ["50","51","96","97","98"]:put(other,z)
  for other in ["2","18","70","164","character-smm01","token_halfghost"]:put(other)
  put("166","hand");put("spell-fdf-049","hand");put("99","grave")
  e.Roster.create_token(e,0,"pillar",2,["绿"],["不占战场格"])
  for p in e.players[0].palette:p.poverty=3
  var actions=e.available_actions(0,c.uid,true).filter(func(a):return a.type in ["ability","extension"])
  for action in actions:
   var key=action.get("key","")
   if key in ["grave_return","grave_reanimate","spell-fdf-059","character-fdf-111"]:e.players[0].field.erase(c);c.zone="grave";e.players[0].grave.append(c)
   e.stack=[]
   if key=="watch_counter":e.stack.append({"id":987,"kind":"ability","activation":true,"effect":"courage_ping","source":c.duplicate(true),"owner":1,"target":{"player":0},"name":"启动异能"})
   if key=="hina_redirect":stacked("96",1,{"player":0})
   e.active=0;e.phase="main";e.priority=0
   var own=e.activation_error(0,c.uid,action.index) if action.type=="ability" else e.extension_activation_error(0,c,key)
   e.active=1
   var foe=e.activation_error(0,c.uid,action.index) if action.type=="ability" else e.extension_activation_error(0,c,key)
   var restricted=key in ["kaguya_end","item-fdf-096","character-fdn-006"] or e.Roster.has(e.cards[id],"toyohime_lock")
   expect(own.is_empty(),"legal activation fixture "+id+" "+key+" "+own)
   expect(restricted or own==foe,"opponent-turn activation timing "+id+" "+key)
   if not restricted:
    for phase in ["prepare","draw","end"]:
     e.phase=phase
     var reason=e.activation_error(0,c.uid,action.index) if action.type=="ability" else e.extension_activation_error(0,c,key)
     expect(reason.is_empty(),"priority-window activation "+id+" "+key+" "+phase)
    e.phase="main";e.combat={"step":"attack_window","owner":1,"attacker":e.ref_target(e.units(1)[0]),"blockers":[]}
    if e.stack.is_empty():stacked("96",1,{"player":0})
    var response=e.activation_error(0,c.uid,action.index) if action.type=="ability" else e.extension_activation_error(0,c,key)
    expect(response.is_empty(),"combat/stack response activation "+id+" "+key)
   rows.append({"id":id,"key":key,"own":own,"opponent":foe,"explicit_restriction":restricted})
 FileAccess.open("res://work/v015/activation-audit.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
