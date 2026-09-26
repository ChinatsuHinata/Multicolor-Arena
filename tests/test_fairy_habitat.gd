extends "res://tests/support/rules_base.gd"

const DuelView=preload("res://scripts/duel_view.gd")

func run():
 fresh()
 var habitat=put("character-fdn-007")
 var mountain=put("character-fdn-006")
 var fairy_ids=[]
 for id in e.cards:
  var info=e.cards[id]
  if info.kind in ["单位","自机"] and "妖精" in info.race and id!="character-fdn-006":fairy_ids.append(id)
 fairy_ids.sort()
 var tap_sources=[mountain]
 for id in fairy_ids:
  var fairy=put(id)
  if id in ["character-lof-001","34","character-fdf-113"]:tap_sources.append(fairy)
 for fairy in tap_sources:e.tap_card(fairy)
 e.players[0].leader=e.make_card("character-fdn-007",0,"leader",true)
 mana()
 var discard=put("50","hand")
 e.judge()
 expect(fairy_ids.size()>=18,"all printed fairies placed beside habitat")
 expect(e.field_slots(0)==1,"habitat leader exempts all fairies from battlefield slots")
 var inherited=[]
 for k in e.Roster.ACTIVATIONS:
  if e.Roster.has(e.cards[habitat.card_id],k):inherited.append(k)
 var actions=e.available_actions(0,habitat.uid,true)
 expect(tap_sources.all(func(fairy):return fairy.tapped) and not habitat.tapped,"all tap-activation fairy sources are tapped while habitat is untapped")
 var tap_keys={"character-fdn-006":"character-fdn-006","character-lof-001":"courage_ping","34":"clown_sweep","character-fdf-113":"character-fdf-113"}
 for fairy in tap_sources:
  var key=tap_keys[fairy.card_id]
  expect(not e.available_actions(0,fairy.uid).any(func(a):return a.type=="extension" and a.key==key),"tapped source cannot pay its own tap cost: "+key)
 for k in inherited:
  expect(actions.any(func(a):return a.type=="extension" and a.key==k),"habitat action menu retains "+k)
 for k in ["character-fdn-006","courage_ping","clown_sweep","character-fdf-113"]:
  expect(e.available_actions(0,habitat.uid).any(func(a):return a.type=="extension" and a.key==k),"tapped fairy still grants usable habitat activation: "+k)
 expect("character-fdn-006" in inherited and "courage_ping" in inherited and "clown_sweep" in inherited,"habitat has multiple fairy activations")
 var mountain_action=actions.filter(func(a):return a.type=="extension" and a.key=="character-fdn-006")
 expect(mountain_action.size()==1 and mountain_action[0].enabled,"habitat can activate mountain fairy copy")
 var choices=e.activation_options(habitat,"character-fdn-006")
 var target={"selection_id":choices[0].selection_id,"picks":[[e.Pack.ref(e,discard)]]}
 var payment=e.payment(0,e.extension_cost(0,habitat,"character-fdn-006",target)).plan
 var error=e.commit_extension(0,habitat.uid,target,payment,"character-fdn-006")
 expect(error.is_empty(),"habitat copy ability commits: "+error)
 expect(habitat.tapped and discard.zone=="grave","habitat pays tap and unit discard costs")
 settle()
 var copies=e.units(0).filter(func(c):return c.get("token",false) and e.cards[c.card_id].get("copy_marker","")=="mountain_fairy")
 expect(copies.size()==1 and e.cards[copies[0].card_id].name==e.cards[habitat.card_id].name and e.stat(copies[0],"health")==e.stat(habitat,"health"),"habitat copies itself and marks the token")
 var habitat_copy=copies[0]
 expect(e.Roster.has(e.cards[habitat_copy.card_id],"character-fdn-006"),"habitat copy retains the inherited mountain fairy ability")
 expect(e.available_actions(0,habitat_copy.uid,true).any(func(a):return a.type=="extension" and a.key=="character-fdn-006"),"habitat copy lists the mountain fairy activation")
 discard=put("50","hand");e.judge()
 expect(e.available_actions(0,habitat_copy.uid).any(func(a):return a.type=="extension" and a.key=="character-fdn-006"),"habitat copy can activate the mountain fairy ability")
 choices=e.activation_options(habitat_copy,"character-fdn-006")
 target={"selection_id":choices[0].selection_id,"picks":[[e.Pack.ref(e,discard)]]}
 error=e.commit_extension(0,habitat_copy.uid,target,e.payment(0,e.extension_cost(0,habitat_copy,"character-fdn-006",target)).plan,"character-fdn-006")
 expect(error.is_empty(),"habitat copy activates the inherited mountain fairy ability: "+error)
 if error.is_empty():settle()
 e.move_to(mountain,"grave");e.judge()
 expect(not e.Roster.has(e.cards[habitat_copy.card_id],"character-fdn-006") and e.cards[habitat_copy.card_id].get("copy_marker","")=="mountain_fairy","habitat copy loses the borrowed ability but keeps its copy marker when mountain fairy leaves")
 fresh();mountain=put("character-fdn-006");mountain.plus_counters=2;mana();discard=put("50","hand")
 e.judge()
 choices=e.activation_options(mountain,"character-fdn-006")
 target={"selection_id":choices[0].selection_id,"picks":[[e.Pack.ref(e,discard)]]}
 error=e.commit_extension(0,mountain.uid,target,e.payment(0,e.extension_cost(0,mountain,"character-fdn-006",target)).plan,"character-fdn-006")
 expect(error.is_empty(),"mountain fairy copy ability commits: "+error)
 settle()
 copies=e.units(0).filter(func(c):return c.get("token",false) and e.cards[c.card_id].get("copy_marker","")=="mountain_fairy")
 expect(copies.size()==1 and copies[0].plus_counters==2,"mountain fairy token is marked and retains its counters")
 # The copied fairy alone must continue to supply its printed ability.
 e.move_to(mountain,"grave")
 var fairy_copy=copies[0]
 e.tap_card(fairy_copy)
 habitat=put("character-fdn-007");discard=put("50","hand")
 e.judge()
 expect(e.units(0).filter(func(c):return e.Cat.race(e,c,"妖精")).size()==1 and mountain.zone=="grave" and fairy_copy.zone=="field","only the tapped mountain fairy copy remains on the battlefield")
 expect(e.Cat.has(e,habitat,"character-fdn-006") and e.available_actions(0,habitat.uid).any(func(a):return a.type=="extension" and a.key=="character-fdn-006"),"habitat inherits copy activation from the token without the original")
 choices=e.activation_options(habitat,"character-fdn-006")
 target={"selection_id":choices[0].selection_id,"picks":[[e.Pack.ref(e,discard)]]}
 error=e.commit_extension(0,habitat.uid,target,e.payment(0,e.extension_cost(0,habitat,"character-fdn-006",target)).plan,"character-fdn-006")
 expect(error.is_empty(),"habitat activates the copied fairy's ability: "+error)
 if error.is_empty():
  settle()
  expect(e.units(0).any(func(c):return c.get("token",false) and c.uid!=fairy_copy.uid and e.cards[c.card_id].get("copy_marker","")=="mountain_fairy" and e.cards[c.card_id].name==e.cards[habitat.card_id].name),"habitat creates its own marked copy from the token-granted ability")
 for k in ["character-fdn-006","courage_ping","courage_die","clown_sweep","character-fdf-113"]:
  fresh();habitat=put("character-fdn-007");mountain=put("character-fdn-006")
  tap_sources=[mountain]
  for id in fairy_ids:
   var fairy=put(id)
   if id in ["character-lof-001","34","character-fdf-113"]:tap_sources.append(fairy)
  for fairy in tap_sources:e.tap_card(fairy)
  e.players[0].leader=e.make_card("character-fdn-007",0,"leader",true)
  mana();var enemy=put("50","field",1);put("164","palette",1);discard=put("50","hand")
  habitat.courage=2;e.judge()
  choices=e.activation_options(habitat,k)
  target={"selection_id":choices[0].selection_id,"picks":[[e.Pack.ref(e,discard)]]} if k=="character-fdn-006" else {"none":true} if k=="clown_sweep" else {"player":1} if k=="courage_ping" else e.ref_target(enemy) if k=="courage_die" else e.Pack.ref(e,e.players[1].palette[0])
  var enabled=e.available_actions(0,habitat.uid).any(func(action):return action.type=="extension" and action.key==k)
  expect(enabled and e.Pack.choice_valid(e,choices,target),"habitat inherited activation can be selected: "+k)
  error=e.commit_extension(0,habitat.uid,target,e.payment(0,e.extension_cost(0,habitat,k,target)).plan,k)
  expect(error.is_empty(),"habitat inherited activation commits: "+k+" "+error)
  if error.is_empty():
   settle()
   expect(e.stack.is_empty() and e.pending.is_empty(),"habitat inherited activation resolves: "+k)
 fresh();e.turn=1;e.players[0].turns=1;e.players[1].turns=1
 habitat=e.make_card("character-fdn-007",0,"hand");e.enter_field(habitat,0)
 mana();discard=put("50","hand");e.judge()
 expect(e.summoning_sick(habitat),"newly entered habitat is summoning sick on turn one")
 var haste_fairy=e.make_card("34",0,"hand");e.enter_field(haste_fairy,0);e.judge()
 expect(e.has_haste(habitat) and not e.summoning_sick(habitat),"haste fairy removes habitat's first-turn summoning sickness")
 mountain=e.make_card("character-fdn-006",0,"hand");e.enter_field(mountain,0);e.judge()
 expect(e.Roster.has(e.cards[habitat.card_id],"character-fdn-006") and e.available_actions(0,habitat.uid).any(func(a):return a.type=="extension" and a.key=="character-fdn-006"),"first-turn habitat can select the mountain fairy copy activation")
 choices=e.activation_options(habitat,"character-fdn-006")
 target={"selection_id":choices[0].selection_id,"picks":[[e.Pack.ref(e,discard)]]}
 error=e.commit_extension(0,habitat.uid,target,e.payment(0,e.extension_cost(0,habitat,"character-fdn-006",target)).plan,"character-fdn-006")
 expect(error.is_empty() and habitat.tapped and discard.zone=="grave","first-turn habitat pays the mountain fairy activation costs: "+error)
 if error.is_empty():
  settle()
  expect(e.units(0).any(func(c):return c.get("token",false) and e.cards[c.card_id].get("copy_marker","")=="mountain_fairy" and e.cards[c.card_id].name==e.cards[habitat.card_id].name),"first-turn habitat creates its marked copy")
 print("FAIRY_HABITAT: ",checks," checks; ",failures.size()," failures")
 quit(1 if not failures.is_empty() else 0)
