extends "res://tests/test_v09_rules.gd"

func run():
 fresh()
 var hina=put("32")
 var ally=put("50")
 var spell=put("96","hand",1)
 put("165","palette",1)
 put("164","palette",1)
 e.active=1;e.priority=1
 var plan=e.payment(1,e.cast_cost(1,spell)).plan
 var err=e.commit_cast(1,spell.uid,e.ref_target(ally),plan)
 expect(err.is_empty(),"opponent casts a real target spell: "+err)
 expect(e.priority==0 and e.stack.size()==1,"Hina gets priority with enemy spell on stack")
 expect(not e.stack[0].has("target_spec"),"ordinary spell does not enlarge stack with an unused target specification")
 var options=e.Extra.activation_options(e,hina,"hina_redirect")
 expect(not options.is_empty(),"Hina may redirect a real enemy spell onto herself")
 expect(e.available_actions(0,hina.uid).any(func(a):return a.get("key","")=="hina_redirect"),"Hina activation is available in response")
 if not options.is_empty():
  err=e.commit_extension(0,hina.uid,options[0],[],"hina_redirect")
  expect(err.is_empty(),"Hina activates: "+err)
  settle()
  expect(e.players[0].life==18 and hina.zone=="grave" and ally.zone=="field","Hina redirects spell, paying two life and saving ally")
 fresh()
 hina=put("32")
 ally=put("50")
 var fodder=put("51","field",1)
 var old_target={"selection_id":"spell-fdf-012:1","picks":[[e.ref_target(fodder)],[e.ref_target(ally)]]}
 var old_options=e.targets_for("spell-fdf-012",1)
 var old_spec={}
 for option in old_options:
  if e.Pack.choice_valid(e,[option],old_target):old_spec=option.duplicate(true);break
 expect(not old_spec.is_empty(),"one-sacrifice spell has a legal prepayment target specification")
 spell=e.make_card("spell-fdf-012",1,"stack")
 e.stack=[{"id":91,"kind":"card","card":spell,"owner":1,"target":old_target,"target_spec":old_spec,"name":"Cat's Walk"}]
 e.move_to(fodder,"grave")
 expect(e.targets_for("spell-fdf-012",1).all(func(option):return option.get("selection_id","")!="spell-fdf-012:1"),"paid sacrifice removes the live one-sacrifice choice")
 options=e.Extra.activation_options(e,hina,"hina_redirect")
 expect(options.size()==1 and options[0].redirect.uid==ally.uid,"Hina can change the surviving target but cannot change a paid sacrifice")
 fresh()
 hina=put("32")
 ally=put("50")
 put("77","field",1)
 var doll=put("8","field",1)
 spell=put("spell-fdf-025","hand",1)
 put("167","palette",1)
 put("164","palette",1)
 e.active=1;e.priority=1
 var spell_target={"selection_id":"spell-fdf-025","picks":[[e.Pack.ref(e,doll)],[e.ref_target(ally)]]}
 var spell_plan=e.payment(1,e.cast_cost(1,spell,spell_target)).plan
 err=e.commit_cast(1,spell.uid,spell_target,spell_plan)
 expect(err.is_empty() and doll.zone=="deck" and e.stack[0].has("target_spec"),"real spell moves paid doll before response and preserves its target rules: "+err)
 options=e.Extra.activation_options(e,hina,"hina_redirect")
 expect(options.size()==1 and options[0].redirect.uid==ally.uid,"Hina can redirect a real spell after its doll payment")
 if not options.is_empty():
  err=e.commit_extension(0,hina.uid,options[0],[],"hina_redirect")
  expect(err.is_empty(),"Hina responds to a paid spell: "+err)
  settle()
  expect(hina.damage==1 and ally.damage==0,"paid spell damage follows the redirected target")
 fresh()
 hina=put("32")
 ally=put("50")
 var kanako=put("82","field",1)
 kanako.leader_counters=1
 var pillar=e.Roster.create_token(e,1,"pillar",2,["绿"])
 e.priority=1
 var blast=e.Extra.activation_options(e,kanako,"kanako_blast")
 var blast_target={"selection_id":"kanako_blast","picks":[[e.Pack.ref(e,pillar)],[e.ref_target(ally)]]}
 expect(e.Pack.choice_valid(e,blast,blast_target),"Kanako blast can sacrifice a pillar and target another unit")
 err=e.commit_extension(1,kanako.uid,blast_target,[],"kanako_blast")
 expect(err.is_empty() and pillar.zone=="void" and e.stack.size()==1,"Kanako blast pays its pillar before opponents respond: "+err)
 options=e.Extra.activation_options(e,hina,"hina_redirect")
 expect(options.size()==1 and options[0].redirect.uid==ally.uid,"Hina can redirect an activated unit ability after its cost is paid")
 var projected=preload("res://net/seat_projection.gd").build(e,0)
 expect(not projected.state.stack[0].has("target_spec") and not projected.queries.extension_targets.get(str(hina.uid)+":hina_redirect",[]).is_empty(),"network seat receives Hina's legal response without private paid-choice pools")
 var observed=preload("res://net/observer_projection.gd").build(e)
 expect(not observed.state.stack[0].has("target_spec"),"observer and replay omit private paid-choice pools")
 if not options.is_empty():
  err=e.commit_extension(0,hina.uid,options[0],[],"hina_redirect")
  expect(err.is_empty(),"Hina responds to Kanako blast: "+err)
  settle()
  expect(hina.zone=="grave" and ally.zone=="field","Kanako's damage is redirected to Hina")
 fresh()
 hina=put("32")
 ally=put("50")
 spell=e.make_card("spell-fdf-031",1,"stack")
 var doubled={"selection_id":"spell-fdf-031","picks":[[e.ref_target(ally)],[e.ref_target(ally)]]}
 e.stack=[{"id":92,"kind":"card","card":spell,"owner":1,"target":doubled,"name":"双目标符卡"}]
 options=e.Extra.activation_options(e,hina,"hina_redirect")
 expect(options.size()==2 and options[0].redirect_index==0 and options[1].redirect_index==1,"Hina offers separate choices for two identical target slots")
 var picker=preload("res://scripts/target_picker.gd").new()
 picker.configure(options,"hina-double")
 expect(picker.available().size()==2,"two identical targets are distinguishable in the choice UI")
 if options.size()==2:
  err=e.commit_extension(0,hina.uid,options[0],[],"hina_redirect")
  expect(err.is_empty(),"Hina activates for one of two identical targets: "+err)
  one()
  expect(e.stack.size()==1 and e.stack[0].target.picks[0][0].uid==hina.uid and e.stack[0].target.picks[1][0].uid==ally.uid,"Hina changes exactly one selected target")
 fresh()
 expect(e.cards["new-eto-002"].colors==["蓝","黑"] and int(e.cards["new-eto-002"].cost.get("蓝",0))==2 and int(e.cards["new-eto-002"].cost.get("黑",0))==1 and int(e.cards["new-eto-002"].cost.get("黄",0))==0,"Sumireko double has two blue and one black cost")
 print("HINA_V12: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
