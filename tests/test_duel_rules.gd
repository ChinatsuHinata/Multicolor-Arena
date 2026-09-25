extends SceneTree
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Store=preload("res://scripts/deck_store.gd")
var failed=[]
var checks=0
func expect(ok: bool,title: String):
 checks+=1
 if ok: print("PASS: "+title)
 else: failed.append(title); push_error(title)
func _initialize(): call_deferred("run")
func fixture():
 var d=Store.blank("边界测试"); d.leader="70"
 for i in range(50): d.main.append("164")
 var e=Duel.new(); e.start(d,d,0,24)
 for p in e.players:
  p.hand=[]; p.palette=[]; p.field=[]; p.grave=[]; p.potato=false
 e.phase="main"; e.turn=5; e.priority=0; e.active=0
 return e
func put(e,who: int,id: String,zone: String):
 var c=e.make_card(id,who,zone); e.players[who][zone].append(c); return c
func resolve(e): e.pass_priority(e.priority); e.pass_priority(e.priority)
func run():
 var e=fixture()
 for id in ["70","70","70","68","68"]: put(e,0,id,"palette")
 var leader=e.players[0].leader
 expect("颜色约束" in e.cast_error(0,leader.uid),"palette colors do not satisfy leader permanent constraint")
 put(e,0,"165","field"); put(e,0,"164","field")
 leader.timer=1
 expect("计时" in e.cast_error(0,leader.uid),"leader timer forbids use")
 leader.timer=0
 expect(e.cast_error(0,leader.uid).is_empty(),"colored permanents satisfy leader constraint")
 e.commit_cast(0,leader.uid,{},e.payment(0,e.cards["70"].cost).plan); resolve(e)
 expect(leader.zone=="field" and e.has_leader_ability(leader) and not e.can_attack(0,leader.uid),"leader keeps identity and cannot attack on entry turn")
 var duplicate=put(e,0,"70","hand")
 expect("同称号" in e.cast_error(0,duplicate.uid),"same-title unit cannot be cast")
 e.damage_target(e.ref_target(leader),4); e.judge(); e.pump_choices()
 expect(e.pending.get("kind","")=="leader_return","lethal leader offers return choice")
 e.choose_return(true)
 expect(leader.zone=="leader" and leader.timer==2 and not e.players[0].grave.has(leader),"leader returns with two counters instead of grave")
 e.phase="end"; e.cleanup_end()
 expect(leader.timer==1,"own end phase reduces leader timer once")
 e=fixture()
 var reimu=put(e,0,"70","field"); reimu.tapped=true; reimu.attacked=true; reimu.brave_attack_turn=e.turn
 e.advance_phase()
 expect(e.phase=="end" and not reimu.tapped and e.stack.is_empty(),"brave untaps during the end phase")
 expect(e.targets_for("100").is_empty(),"card counter cannot target triggered ability")
 e=fixture()
 var marisa=put(e,0,"68","field")
 expect(not e.has_leader_ability(marisa),"ordinary Marisa does not automatically gain leader ability")
 var shrine=put(e,0,"170","field")
 expect(e.has_leader_ability(marisa),"shrine grants leader ability to ordinary Marisa")
 for i in range(3): put(e,0,"164","palette")
 var fire=put(e,0,"99","hand"); var enemy=put(e,1,"70","field")
 e.commit_cast(0,fire.uid,{"player":1},e.payment(0,{"黄":3}).plan)
 expect(e.pending.get("kind","")=="trigger" and e.stack.size()==2 and e.stack.back().get("awaiting_target",false),"spell use queues a provisional Marisa trigger while choosing its target")
 e.choose_trigger(e.ref_target(enemy))
 expect(e.stack.size()==2 and e.stack.back().kind=="ability","Marisa trigger sits above original spell")
 e.players[0].field.erase(marisa); e.to_grave(marisa)
 resolve(e)
 expect(enemy.damage==1 and e.stack.size()==1,"trigger survives source leaving battlefield")
 resolve(e)
 expect(e.players[1].life==15,"original spell still resolves after trigger")
 e.players[0].field.erase(shrine); e.to_grave(shrine)
 expect(not e.has_leader_ability(marisa),"shrine effect stops after it leaves")
 e=fixture()
 for id in ["165","164","167"]: put(e,0,id,"field")
 for id in ["68","68","68","68"]: put(e,0,id,"palette")
 marisa=put(e,0,"68","hand"); enemy=put(e,1,"70","field")
 e.commit_cast(0,marisa.uid,{},e.payment(0,{"蓝":2,"黄":2}).plan); resolve(e)
 expect(e.pending.get("kind","")=="trigger","Marisa actual entry creates optional three-damage trigger")
 e.choose_trigger(e.ref_target(enemy)); resolve(e)
 expect(enemy.damage==3,"entry trigger uses three damage")
 e=fixture(); marisa=put(e,0,"68","field")
 for i in range(3): put(e,0,"164","palette")
 fire=put(e,0,"99","hand"); enemy=put(e,1,"70","field")
 e.commit_cast(0,fire.uid,e.ref_target(enemy),e.payment(0,{"黄":3}).plan)
 e.players[1].field.erase(enemy); e.shift(enemy,"hand"); e.shift(enemy,"field"); e.players[1].field.append(enemy)
 resolve(e)
 expect(enemy.damage==0 and e.players[0].grave.has(fire),"leave-return object identity invalidates old target")
 e=fixture(); var attacker=put(e,0,"70","field"); var b1=put(e,1,"70","field"); var b2=put(e,1,"68","field")
 e.attack(0,attacker.uid); resolve(e); e.block([b1.uid,b2.uid]); resolve(e)
 expect(e.pending.get("kind","")=="damage_assignment","multiple blockers request attacker allocation")
 e.combat_damage({str(b1.uid):0,str(b2.uid):3})
 expect(e.players[0].grave.has(attacker) and e.players[1].grave.has(b2) and b1.damage==0,"multiple blocking applies allocated and simultaneous damage")
 e=fixture(); attacker=put(e,0,"70","field"); b1=put(e,1,"68","field")
 e.attack(0,attacker.uid); resolve(e); e.block([b1.uid]); e.players[1].field.erase(b1); e.to_grave(b1); resolve(e)
 expect(e.combat.is_empty() and e.players[1].life==20,"losing all declared blockers ends combat without player damage")
 e=fixture(); e.phase="end"
 for i in range(9): put(e,0,"164","hand")
 e.cleanup_end()
 expect(e.pending.get("kind","")=="discard" and e.pending.count==2,"cleanup requires discard to seven")
 e.discard(e.players[0].hand.slice(0,2).map(func(c): return c.uid))
 expect(e.players[0].hand.size()==7 and e.active==1,"discard resumes turn progression")
 e=fixture(); e.players[0].deck=[]; e.start_turn(0)
 expect(e.winner==-2,"empty palette growth is not a failed draw")
 e.draw(0)
 expect(e.winner==1,"empty required draw loses match")
 var db=preload("res://scripts/card_database.gd")
 expect(db.load_cards().size()>=15,"legacy definitions pass schema and image validation")
 var definition=JSON.parse_string(FileAccess.get_file_as_string("res://cards/99.json"))
 var bad=definition.duplicate(true); bad["费用"]["黄"]=-1
 expect(not db.validate_definition(bad,"99").is_empty(),"negative card cost rejected")
 bad=definition.duplicate(true); bad["费用"]["黄"]=1.5
 expect(not db.validate_definition(bad,"99").is_empty(),"fractional card cost rejected")
 bad=definition.duplicate(true); bad["能力绑定"][0]["实现"]="unimplemented"
 expect(not db.validate_definition(bad,"99").is_empty(),"unregistered effects rejected instead of silently ignored")
 bad=definition.duplicate(true); bad["能力绑定"][0]["参数"]["数值"]="5"
 expect(not db.validate_definition(bad,"99").is_empty(),"non-numeric effect parameter rejected")
 bad=definition.duplicate(true); bad["类别"]="道具"
 expect(not db.validate_definition(bad,"99").is_empty(),"incompatible ability category rejected")
 var deck=Store.blank("禁入测试"); deck.leader="70"; deck.main=["99"]
 Store.CARDS["99"].constructible=false
 expect(not Store.validate(deck,false).is_empty(),"test mode still refuses construction-banned card")
 expect(not Store.add_card(deck,"99","main").is_empty(),"editor refuses construction-banned card")
 Store.CARDS["99"].constructible=true
 print("DUEL_RULES_TEST: %d checks; %d failures" % [checks,failed.size()])
 quit(0 if failed.is_empty() else 1)
