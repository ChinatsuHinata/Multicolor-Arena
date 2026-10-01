extends SceneTree
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Store=preload("res://scripts/deck_store.gd")
var failed=0

func _initialize(): call_deferred("run")

func check(ok: bool, label: String):
 if not ok:
  failed+=1
  push_error(label)
 else: print("PASS: "+label)

func run():
 var deck=Store.blank("Lily priority probe")
 deck.leader="70"
 for i in range(50): deck.main.append("character-soi-006")
 var e=Duel.new()
 e.start(deck,deck,0,47)
 for p in e.players:
  p.hand=[]; p.palette=[]; p.field=[]; p.grave=[]
 e.phase="main";e.turn=5;e.active=0;e.priority=0;e.passes=0
 var leader=e.players[0].leader
 var lily=e.make_card("character-soi-006",0,"hand")
 e.players[0].hand.append(lily)
 for i in range(5):
  e.players[0].palette.append(e.make_card("70",0,"palette"))
 check("颜色约束" in e.cast_error(0,leader.uid),"leader unavailable before Lily enters")
 var cast_result=e.commit_cast(0,lily.uid,{},e.payment(0,e.cast_cost(0,lily)).plan)
 check(cast_result.is_empty() and lily.zone=="stack" and e.priority==1,"opponent gets response to Lily's cast")
 e.pass_priority(1)
 check(e.priority==0 and not e.stack.is_empty(),"Lily remains on stack after opponent passes")
 e.pass_priority(0)
 check(lily.zone=="field" and e.stack.is_empty() and e.pending.is_empty() and e.triggers.is_empty(),"Lily resolves without an entry trigger")
 check(e.priority==0 and e.passes==0,"active player has priority immediately after Lily resolves")
 check(e.cast_error(0,leader.uid).is_empty(),"leader can be cast immediately after Lily resolves")
 var leader_result=e.commit_cast(0,leader.uid,{},e.payment(0,e.cast_cost(0,leader)).plan)
 check(leader_result.is_empty() and leader.zone=="stack" and e.priority==1,"opponent gets a response only after leader is cast")
 e=Duel.new()
 e.start(deck,deck,0,48)
 for p in e.players:
  p.hand=[]; p.palette=[]; p.field=[]; p.grave=[]
 e.phase="main";e.turn=5;e.active=0;e.priority=0;e.passes=0
 lily=e.make_card("character-soi-006",0,"field")
 e.players[0].field.append(lily)
 var enemy=e.make_card("character-soi-006",1,"field")
 e.players[1].field.append(enemy)
 var marisa=e.make_card("68",0,"hand")
 e.players[0].hand.append(marisa)
 for i in range(5):
  e.players[0].palette.append(e.make_card("character-soi-006",0,"palette"))
 check(e.commit_cast(0,marisa.uid,{},e.payment(0,e.cast_cost(0,marisa)).plan).is_empty(),"optional entry unit can be cast")
 e.pass_priority(1);e.pass_priority(0)
 check(e.pending.get("kind","")=="trigger" and e.stack.size()==1,"optional entry trigger asks its controller")
 e.choose_trigger({})
 check(e.stack.is_empty() and e.pending.is_empty() and e.priority==0,"declining optional entry trigger returns priority to active player")
 e=Duel.new()
 e.start(deck,deck,0,50)
 for p in e.players:
  p.hand=[]; p.palette=[]; p.field=[]; p.grave=[]
 e.phase="main";e.turn=5;e.active=0;e.priority=0;e.passes=0
 lily=e.make_card("character-soi-006",0,"field")
 e.players[0].field.append(lily)
 e.players[0].deck=[e.make_card("99",0,"deck")]
 var search_marisa=e.make_card("character-mar-ex",0,"hand")
 e.players[0].hand.append(search_marisa)
 for i in range(5):
  e.players[0].palette.append(e.make_card("character-soi-006",0,"palette"))
 check(e.commit_cast(0,search_marisa.uid,{},e.payment(0,e.cast_cost(0,search_marisa)).plan).is_empty(),"optional search entry unit can be cast")
 e.pass_priority(1);e.pass_priority(0)
 check(e.pending.get("kind","")=="effect_choice" and e.stack.size()==1,"optional search entry waits for its controller")
 e.choose_effect({})
 check(e.stack.is_empty() and e.pending.is_empty() and e.priority==0,"declining optional entry choice returns priority to active player")
 e=Duel.new()
 e.start(deck,deck,0,49)
 for p in e.players:
  p.hand=[]; p.palette=[]; p.field=[]; p.grave=[]
 e.phase="main";e.turn=5;e.active=0;e.priority=0;e.passes=0
 marisa=e.make_card("68",0,"field")
 e.players[0].field.append(marisa)
 var shrine=e.make_card("170",0,"field")
 e.players[0].field.append(shrine)
 enemy=e.make_card("character-soi-006",1,"field")
 e.players[1].field.append(enemy)
 for i in range(3):
  e.players[0].palette.append(e.make_card("character-soi-006",0,"palette"))
 var spell=e.make_card("99",0,"hand")
 e.players[0].hand.append(spell)
 check(e.commit_cast(0,spell.uid,e.ref_target(enemy),e.payment(0,e.cast_cost(0,spell)).plan).is_empty(),"spell can be cast with optional cast trigger")
 check(e.pending.get("kind","")=="trigger" and e.stack.size()==2,"optional cast trigger is provisional above the spell")
 e.choose_trigger({})
 check(e.stack.size()==1 and e.stack.back().kind=="card" and e.priority==1,"declining optional cast trigger preserves opponent's response to original spell")
 quit(1 if failed>0 else 0)
