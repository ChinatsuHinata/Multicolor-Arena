extends SceneTree
const Duel=preload("res://scripts/rules/duel_engine.gd")
const DB=preload("res://scripts/card_database.gd")
const Store=preload("res://scripts/deck_store.gd")
var checks=0
var failures=[]
var e
func _initialize(): call_deferred("run")
func expect(ok: bool,title: String):
 checks+=1
 if ok: print("PASS: "+title)
 else: failures.append(title); push_error(title)
func fixture():
 var d=Store.blank("新增卡测试"); d.leader="70"
 for i in range(50): d.main.append("164")
 var duel=Duel.new(); duel.start(d,d,0,26)
 for p in duel.players:
  p.hand=[]; p.palette=[]; p.field=[]; p.grave=[]; p.potato=false; p.mulligan_done=true
 duel.phase="main"; duel.turn=4; duel.priority=0; duel.active=0; duel.pending={}
 return duel
func put(who: int,id: String,zone: String):
 var c=e.make_card(id,who,zone); e.players[who][zone].append(c); return c
func resolve(): e.pass_priority(e.priority); e.pass_priority(e.priority)
func ready_battle():
 resolve()
func run():
 var save_before=FileAccess.get_file_as_string(Store.SAVE_PATH)
 var cards=DB.load_cards()
 expect(cards.size()>=15,"15 cards load with source metadata and valid art")
 expect(int(cards["50"].cost.get("红",0))==4 and cards["50"].cost.size()==1 and cards["50"].power==5 and cards["50"].health==3,"oni stats match supplied image and sheet")
 expect(int(cards["53"].cost.get("黄",0))==1 and cards["57"].power==0,"vanilla units preserve low cost and zero power")
 expect(int(cards["96"].cost.get("红",0))==1 and int(cards["96"].cost.get("黄",0))==1 and cards["96"].fast,"generic two-color damage spell is fast")
 expect(int(cards["112"].cost.get("红",0))==1 and cards["112"].requires_character.is_empty(),"sweet moment is fast non-character spell")
 var deck=Store.blank(); deck.leader="70"
 for id in ["50","53","54","56","57","68","96","99","100","112","164","165","167","170"]: deck.main.append(id)
 expect(Store.validate(deck).is_empty(),"new pool accepted by deck save validation")
 expect(not Store.add_card(deck,"53","leader").is_empty(),"ordinary unit cannot become a leader")
 e=fixture(); var soldier=put(0,"53","hand"); put(0,"164","palette")
 expect(e.cast_error(0,soldier.uid).is_empty(),"ordinary unit has no leader color constraint")
 e.commit_cast(0,soldier.uid,{},e.payment(0,cards["53"].cost).plan); resolve()
 expect(soldier.zone=="field" and not e.can_attack(0,soldier.uid),"ordinary unit enters with summoning sickness")
 put(0,"164","palette"); var second=put(0,"53","hand")
 expect(e.cast_error(0,second.uid).is_empty(),"ordinary names without titles can coexist")
 e.commit_cast(0,second.uid,{},e.payment(0,cards["53"].cost).plan); resolve()
 expect(e.units(0).size()==2,"two copies of ordinary soldier coexist")
 e=fixture(); e.active=1
 var dragon=put(0,"56","hand")
 for i in range(4): put(0,"167","palette")
 expect(e.cast_error(0,dragon.uid).is_empty() and e.has_response(0),"dragon can respond in opponent turn")
 e.commit_cast(0,dragon.uid,{},e.payment(0,cards["56"].cost).plan); resolve()
 expect(dragon.zone=="field" and e.summoning_sick(dragon),"flash unit resolves normally, not haste")
 e=fixture(); var newcomer=e.make_card("53",0,"hand"); e.enter_field(newcomer,0)
 expect(e.summoning_sick(newcomer) and not e.can_attack(0,newcomer.uid),"new unit cannot attack on entry turn")
 e.start_turn(1)
 expect(e.summoning_sick(newcomer),"summoning sickness persists through opponent turn")
 e.start_turn(0)
 expect(not e.summoning_sick(newcomer),"controller reset clears summoning sickness")
 e=fixture(); var fairy=e.make_card("57",0,"hand"); e.enter_field(fairy,0)
 var buff=put(0,"112","hand"); put(0,"165","palette")
 expect({"player":0} not in e.targets_for("112"),"buff cannot target a player")
 e.commit_cast(0,buff.uid,e.ref_target(fairy),e.payment(0,cards["112"].cost).plan)
 expect(e.stat(fairy,"power")==0,"buff does not apply before stack resolution")
 resolve()
 expect(e.stat(fairy,"power")==2 and e.stat(fairy,"health")==3 and e.stat(fairy,"spirit")==2,"sweet moment grants correct temporary stats")
 expect(e.can_attack(0,fairy.uid),"haste permits this-turn attack")
 e.attack(0,fairy.uid); ready_battle(); e.block([]); resolve()
 expect(e.players[1].life==18,"unblocked attack uses temporary spirit")
 resolve(); e.finish_turn()
 expect(e.stat(fairy,"power")==0 and e.stat(fairy,"spirit")==1 and not e.has_haste(fairy),"temporary stats and haste expire at turn end")
 e=fixture(); fairy=put(0,"57","field"); buff=put(0,"112","hand"); put(0,"165","palette")
 e.commit_cast(0,buff.uid,e.ref_target(fairy),e.payment(0,cards["112"].cost).plan)
 e.players[0].field.erase(fairy); e.to_grave(fairy); resolve()
 expect(buff.zone=="grave" and not e.has_haste(fairy),"buff fizzles when target leaves battlefield")
 e=fixture(); var oni=put(0,"50","field"); var blocker=put(1,"53","field")
 e.attack(0,oni.uid); ready_battle(); e.block([blocker.uid]); resolve()
 expect(blocker.zone=="grave" and e.players[1].life==18,"annihilate deals spirit when blocker dies")
 e=fixture(); oni=put(0,"50","field"); var a=put(1,"53","field"); var b=put(1,"53","field")
 e.attack(0,oni.uid); ready_battle(); e.block([a.uid,b.uid]); resolve()
 e.combat_damage({str(a.uid):2,str(b.uid):3})
 expect(e.players[1].life==18 and oni.zone=="grave","annihilate happens once despite multiple kills and simultaneous death")
 e=fixture(); oni=put(0,"50","field"); a=put(1,"56","field"); b=put(1,"56","field")
 e.attack(0,oni.uid); ready_battle(); e.block([a.uid,b.uid]); resolve(); e.combat_damage({str(a.uid):2,str(b.uid):3})
 expect(e.players[1].life==20,"annihilate does not trigger without killing a blocker")
 e=fixture(); a=put(0,"53","field"); oni=put(1,"50","field")
 e.attack(0,a.uid); ready_battle(); e.block([oni.uid]); resolve()
 expect(e.players[0].life==20,"annihilate does not trigger while defending")
 e=fixture(); var titan=put(0,"54","field"); titan.attacked=true; titan.tapped=true; titan.brave_attack_turn=e.turn
 e.advance_phase()
 expect(e.phase=="end" and not titan.tapped and e.stack.is_empty(),"brave resets during end phase without entering stack")
 e=fixture(); var moon=put(0,"96","hand"); put(0,"165","palette"); put(0,"164","palette")
 e.active=1; e.commit_cast(0,moon.uid,{"player":1},e.payment(0,cards["96"].cost).plan); resolve()
 expect(e.players[1].life==18 and moon.zone=="grave","generic fast spell deals actual two damage")
 e=fixture(); moon=put(1,"96","hand"); put(1,"165","palette"); put(1,"164","palette"); e.priority=1; e.players[0].life=2
 e.ai_step(1); expect(e.stack.size()==1,"AI uses new fast damage for lethal response"); resolve()
 expect(e.winner==1,"new AI response can complete match")
 e=fixture(); put(1,"112","hand"); put(1,"165","palette"); e.active=1; e.priority=1
 e.ai_step(1); expect(e.priority==0,"AI passes unusable buff instead of stalling")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==save_before,"user deck save unchanged")
 print("V07_TEST: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
