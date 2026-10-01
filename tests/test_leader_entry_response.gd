extends SceneTree
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Store=preload("res://scripts/deck_store.gd")
var failures=[]
var checks=0

func _initialize(): call_deferred("run")

func expect(ok: bool,label: String):
 checks+=1
 if ok: print("PASS: "+label)
 else: failures.append(label);push_error(label)

func fixture(id: String,real_leader: bool=false,grant: bool=false) -> Dictionary:
 var deck=Store.blank("自机入场响应测试")
 deck.leader=id if real_leader else "70"
 for i in range(50): deck.main.append("164")
 var e=Duel.new()
 e.start(deck,deck,0,51)
 for p in e.players:
  p.hand=[];p.palette=[];p.field=[];p.grave=[];p.potato=false
 e.phase="main";e.turn=5;e.active=0;e.priority=0;e.passes=0
 e.players[0].field.append(e.make_card("character-soi-006",0,"field"))
 if grant:e.players[0].field.append(e.make_card("170",0,"field"))
 var victim=e.make_card("character-soi-006",1,"field")
 e.players[1].field.append(victim)
 for i in range(6):e.players[0].palette.append(e.make_card("character-soi-006",0,"palette"))
 var card=e.players[0].leader if real_leader else e.make_card(id,0,"hand")
 if not real_leader:e.players[0].hand.append(card)
 return {"engine":e,"card":card,"victim":victim}

func cast_and_resolve(state: Dictionary) -> String:
 var e=state.engine
 var card=state.card
 var result=e.commit_cast(0,card.uid,{},e.payment(0,e.cast_cost(0,card)).plan)
 if result.is_empty():
  e.pass_priority(1)
  e.pass_priority(0)
 return result

func run():
 for id in ["character-fdn-048","character-ucs-067"]:
  var ordinary=fixture(id)
  expect(not ordinary.engine.has_leader_ability(ordinary.card),id+" ordinary copy has no leader ability")
  expect(cast_and_resolve(ordinary).is_empty(),id+" ordinary copy can be cast")
  expect(ordinary.card.zone=="field" and ordinary.engine.stack.is_empty() and ordinary.engine.triggers.is_empty() and ordinary.engine.pending.is_empty() and ordinary.engine.priority==0,id+" ordinary copy creates no entry response window")
  expect(ordinary.victim.zone=="field",id+" ordinary copy does not demand a sacrifice")
  var leader=fixture(id,true)
  expect(cast_and_resolve(leader).is_empty(),id+" actual leader can be cast")
  expect(leader.engine.stack.size()==1 and leader.engine.stack.back().get("effect","")==id+":self",id+" actual leader creates its sacrifice trigger")
 var granted=fixture("character-fdn-048",false,true)
 expect(cast_and_resolve(granted).is_empty(),"granted Remilia can be cast")
 expect(granted.engine.stack.size()==1 and granted.engine.stack.back().get("effect","")=="character-fdn-048:self","granted leader ability enables Remilia entry trigger")
 for id in ["soi_unit_086","86"]:
  var ordinary=fixture(id)
  expect(cast_and_resolve(ordinary).is_empty(),id+" ordinary copy can be cast")
  expect(ordinary.engine.stack.is_empty() and ordinary.engine.triggers.is_empty() and ordinary.engine.pending.is_empty() and ordinary.engine.priority==0,id+" ordinary copy creates no self-only entry response window")
 var sakuya=fixture("75")
 expect(cast_and_resolve(sakuya).is_empty(),"ordinary Sakuya can be cast")
 expect(sakuya.engine.stack.size()==1 and sakuya.engine.stack.back().get("effect","")=="enter_unblockable","Sakuya's printed ordinary entry ability still creates a response window")
 print("LEADER_ENTRY_RESPONSE: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
