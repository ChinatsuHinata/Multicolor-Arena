extends "res://tests/test_update0921_cards.gd"
func drain():
 for i in range(80):
  if not e.pending.is_empty():
   if e.pending.kind=="trigger_order":e.choose_trigger_order(0)
   elif e.pending.kind=="leader_return":e.choose_return(false)
   elif e.pending.kind=="effect_choice":
    var spec=e.pending.options[0]
    if spec.has("selection"):
     var groups=[]
     for g in spec.selection:groups.append(g.pool.slice(0,g.min))
     e.choose_effect(picks(spec,groups))
    else:e.choose_effect(spec)
   elif e.pending.kind=="timer":e.choose_timer(0)
   else:break
  elif not e.triggers.is_empty():e.pump_choices()
  elif not e.stack.is_empty():e.pass_priority(e.priority);e.pass_priority(e.priority)
  else:return
 check(false,"resolution did not drain")
func run():
 fresh();var yukari=enter("SPX-005");yukari.leader=true;e.triggers=[]
 var field=add("SPX-007");var target=add("53","field",1)
 var options=e.activation_options(yukari,"n21:SPX-005:self");var spec=options[0]
 var aim=picks(spec,[[e.Pack.ref(e,field)],[e.ref_target(target)]])
 check(e.commit_extension(0,yukari.uid,aim,[],"n21:SPX-005:self").is_empty(),"Yukari sacrifice field activation")
 drain();check(e.stat(target,"spirit")==maxi(0,e.cards[target.card_id].spirit-3),"Yukari minus spirit resolves")
 check(not e.extension_activation_error(0,yukari,"n21:SPX-005:self").is_empty(),"Yukari once per turn")
 e.players[0].turns+=1;N.on_phase(e,"prepare");check(e.stat(target,"spirit")==e.cards[target.card_id].spirit,"spirit adjustment expires at next own preparation")
 fresh();yukari=add("SPX-005");var train=add("SPX-007","grave");var train2=add("SPX-007","grave");var t=entry(yukari,{"none":true,"card_name":e.cards[train.card_id].name},"n21:SPX-005");N.resolve_trigger(e,t)
 check(train.zone=="field" and train2.zone=="field","Yukari returns all named fields simultaneously")
 fresh();var card=add("SPX-007","deck");var resource=add("53","palette");e.cards[resource.card_id].colors=["黄"];var resource2=add("53","palette")
 resolve_spell("SPX-006");spec=e.pending.options[0];e.choose_effect(picks(spec,[[e.Pack.ref(e,card)]]))
 check(card.zone=="field" and e.pending.trigger.effect=="n21:train_pay","train search resolves before copy payment offer")
 var pay=e.pending.options.filter(func(o):return o.get("pay",false))[0];e.choose_effect(pay)
 check(resource.tapped and resource2.tapped and e.pending.trigger.effect=="n21:copy_finish","train copy pays two yellow")
 e.choose_effect(e.pending.options[0]);check(e.stack.any(func(s):return s.get("copy",false) and s.card.card_id==N.id("SPX-006")),"train copy put on stack")
 fresh();resolve_spell("SPX-004");var frog=e.Cat.token(e,0,"青蛙",4,4,2,["蓝","绿"],["不占战场格"]);target=add("53","field",1)
 var trigger=e.triggers.filter(func(v):return v.effect=="n21:frog_fire")[0];trigger.target=e.ref_target(target);N.resolve_trigger(e,trigger)
 check(target.damage==4,"frog arrival fire uses frog power")
 add("SPX-004","deck");e.run_delayed("end");check(e.triggers.any(func(v):return v.effect=="n21:frog_search"),"next own end searches red frog")
 fresh();var god=add("SPX-003");frog=e.Cat.token(e,0,"青蛙",4,4,2,["蓝","绿"],["不占战场格"])
 var hostile=e.make_card("177",1,"stack");e.stack=[{"id":555,"kind":"card","card":hostile,"owner":1,"target":e.ref_target(god),"name":"hostile"}]
 options=e.activation_options(god,"n21:frog_counter");aim=picks(options[0],[[e.Pack.ref(e,frog)],[{"stack_id":555}]])
 check(e.commit_extension(0,god.uid,aim,[],"n21:frog_counter").is_empty(),"frog counter offered for spell targeting own god")
 e.pass_priority(e.priority);e.pass_priority(e.priority)
 check(hostile.zone=="grave" and e.stack.is_empty(),"frog counter actually counters card")
 fresh();var gourd=add("SPX-002");gourd.tapped=true;t=entry(gourd,{"none":true},"n21:gourd_reset");N.resolve_activation(e,t);check(not gourd.tapped,"gourd reset activation resolves")
 fresh();target=add("53","field",1);e.cards[target.card_id].health=9;var ball1=add("ETO-S001","deck");var ball2=add("ETO-S001","deck");resolve_spell("ETO-004",e.ref_target(target))
 check(target.damage==4,"printer gun deals four")
 e.choose_effect(picks(e.pending.options[0],[[e.Pack.ref(e,ball1),e.Pack.ref(e,ball2)]]));check(ball1.zone=="hand" and ball2.zone=="hand","printer gun searches up to two balls")
 fresh();var time=enter("LOC-003");var a=add("53");var b=add("53","field",1)
 t=entry(time,{"picks":[[e.ref_target(a)],[e.ref_target(b)],[e.ref_target(b)]]},"n21:LOC-003");N.resolve_trigger(e,t);check(a.damage==1 and b.damage==2,"Blizzard distributes three damage")
 fresh();var book1=add("ETO-007","deck");var book2=add("ETO-009","deck");var book3=add("ETO-011","deck");var duo=enter("ETO-003");var trigger2=e.triggers.back();spec=N.trigger_options(e,trigger2)[0]
 aim=picks(spec,[[e.Pack.ref(e,book1)],[e.Pack.ref(e,book2)],[e.Pack.ref(e,book3)]])
 check(e.Pack.choice_valid(e,[spec],aim),"three books split among hand grave palette")
 var illegal=picks(spec,[[e.Pack.ref(e,book1)],[e.Pack.ref(e,book1)],[]]);check(not e.Pack.choice_valid(e,[spec],illegal),"same book cannot be selected twice")
 trigger2.target=aim;N.resolve_trigger(e,trigger2)
 check(book1.zone=="hand" and book2.zone=="grave" and book3.zone=="palette" and book3.tapped,"book destinations and tapped palette honored")
 fresh(N.id("ETO-001"));var extra=e.leaders(0)[1];var primary=e.leaders(0)[0];primary.timer=2;extra.timer=1
 trigger2=entry(extra,{"none":true},"n21:ETO-002:self");spec=N.trigger_options(e,trigger2)[0]
 aim=picks(spec,[[spec.selection[0].pool[0],spec.selection[0].pool[-1]]]);trigger2.target=aim;N.resolve_trigger(e,trigger2)
 check(primary.timer==1 and extra.timer==0,"double death removes timers across both leaders")
 fresh();var bomb=add("ETO-002");ball1=add("ETO-S001");ball2=add("ETO-S001");var ball3=add("ETO-S001");var enemy_ball=add("ETO-S001","field",1);target=add("53","field",1)
 ball2.tapped=true
 t=entry(bomb,{"none":true},"n21:ETO-002");options=N.trigger_options(e,t)
 check(options.size()==4 and options.map(func(o):return o.x)==[0,1,2,3] and options.all(func(o):return not o.has("selection") and not o.has("uid")),"double arrival chooses a count across all own occult balls without selecting stack members")
 check(not e.Pack.choice_valid(e,options,{"none":true,"x":4,"mode":"牺牲4个灵异珠"}),"double arrival rejects a count above own field total")
 t.target=options[2];N.resolve_trigger(e,t)
 check(ball1.zone=="grave" and ball2.zone=="grave" and ball3.zone=="field" and enemy_ball.zone=="field" and target.damage==2 and bomb.damage==2 and e.players[1].life==18,"double arrival sacrifices only the chosen number and deals that much damage")
 fresh();var item=add("SPX-002");var other=add("SPX-002","field",1);resolve_spell("LOC-004");e.choose_effect({"none":true,"card_name":e.cards[item.card_id].name,"mode":e.cards[item.card_id].name})
 check(item.zone=="grave" and other.zone=="grave","deer shot destroys both sides named permanents")
 fresh();var kokoro=add("character-htk-001");var mayumi=add("character-fdf-106");resolve_spell("ETO-005")
 check(e.triggers.filter(func(v):return v.source.uid==kokoro.uid).size()==2 and e.triggers.filter(func(v):return v.source.uid==mayumi.uid).size()==2,"dark noh fires both distinct main abilities and doubles Kokoro")
 check(e.players[0].exile.any(func(c):return c.card_id==N.id("ETO-005")),"dark noh exiles itself")
 drain();check(kokoro.get("moods",[]).size()==2 and e.players[0].field.filter(func(c):return c.card_id.begins_with("token-htk-")).size()==2,"both Kokoro mood triggers fully resolve")
 check(e.players[0].life==24 and e.units(0).any(func(c):return c.token and e.cards[c.card_id].power==5),"Mayumi enter and death abilities resolve without actual zone change")
 fresh();var cirno=add("LOC-001");cirno.leader=true;e.add_timer(cirno,1)
 check(e.triggers.any(func(v):return v.effect=="n21:LOC-001:self"),"placing a timer also triggers Cirno self ability")
 fresh();gourd=add("SPX-002");target=add("53");target.drunk_counters=1;target.n21_drunk_triggered=true
 N.resolve_activation(e,entry(gourd,e.ref_target(target),"n21:gourd_counter"));N.on_phase(e,"end")
 check(e.triggers.any(func(v):return v.effect=="n21:drunk_bottom"),"fresh drunk counter grants a new next-end trigger after earlier trigger was countered")
 fresh();add("character-fdf-109");N.force_main_triggers(e,0)
 check(e.triggers.any(func(v):return v.effect=="character-fdf-109"),"dark noh ignores original grave-zone trigger condition")
 fresh();add("character-lof-004");add("character-rei-026");add("character-fdf-101");var marisa=add("68");marisa.leader=true
 N.force_main_triggers(e,0)
 for key in ["character-lof-004","sanae_end","cat:momiji_name"]:check(e.triggers.any(func(v):return v.get("effect","")==key),"dark noh includes main trigger "+key)
 check(e.triggers.filter(func(v):return v.source.uid==marisa.uid).size()==1,"dark noh excludes Marisa self ability even for actual leader")
 print("UPDATE0921 MORE ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
