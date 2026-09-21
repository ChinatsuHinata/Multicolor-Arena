extends SceneTree
var app
var view
var e
var checks=0
var failures=[]
func _initialize(): call_deferred("run")
func expect(ok: bool,title: String):
 checks+=1
 if ok: print("PASS: "+title)
 else: failures.append(title); push_error(title)
func clean():
 e.start(app.decks[app.player_choice],app.decks[app.ai_choice],1,29)
 for p in e.players:
  p.field=[]; p.hand=[]; p.palette=[]; p.grave=[]; p.potato=false; p.mulligan_done=true
 e.phase="main"; e.turn=4; e.active=1; e.priority=1; e.pending={}
 view.local={}; view.selection=[]; view.previous_snapshot={}; view.table.last_combat={}
func put(who: int,id: String,zone: String):
 var c=e.make_card(id,who,zone); e.players[who][zone].append(c); return c
func resolve(): e.pass_priority(e.priority); e.pass_priority(e.priority)
func find_button(node: Node,title: String):
 if node is Button and node.text==title: return node
 for child in node.get_children():
  var found=find_button(child,title)
  if found: return found
 return null
func run():
 var save_before=FileAccess.get_file_as_string("res://saves/decks.json")
 app=load("res://main.tscn").instantiate(); root.add_child(app); await process_frame
 app.load_test_decks(); app.begin_battle(true)
 view=app.duel_view; view.set_process(false); e=view.engine
 clean(); var attacker=put(1,"53","field")
 e.attack(1,attacker.uid)
 expect(e.combat.step=="attack_window" and e.priority==0 and e.pending.is_empty(),"attack response window exists before checking blockers")
 resolve()
 expect(e.pending.is_empty() and e.combat.step=="block_window" and not e.combat.blocked,"empty defending field automatically declares no blockers")
 expect(e.players[0].life==20,"skipping blocker choice does not skip damage response window")
 resolve(); expect(e.players[0].life==19,"unblocked attack deals actual spirit damage")
 clean(); attacker=put(1,"53","field"); var defender=put(0,"53","field"); defender.tapped=true
 put(0,"164","field"); e.attack(1,attacker.uid); resolve()
 expect(e.pending.is_empty() and e.combat.step=="block_window","tapped unit and artifact are not legal blockers")
 clean(); attacker=put(1,"70","field"); put(1,"170","field"); put(0,"57","field")
 e.attack(1,attacker.uid); resolve()
 expect(e.pending.is_empty() and e.combat.step=="block_window","blocking restrictions also skip an impossible choice")
 clean(); attacker=put(1,"53","field"); defender=put(0,"53","field")
 e.attack(1,attacker.uid); resolve()
 expect(e.pending.get("kind")=="block" and e.pending.owner==0,"one legal blocker still waits for player choice")
 view.render()
 expect(find_button(view.ui,"不阻挡")!=null,"legal blocker keeps manual blocking controls")
 e.block([defender.uid]); resolve()
 expect(attacker.zone=="grave" and defender.zone=="grave" and e.players[0].life==20,"manual blocking still resolves simultaneous combat")
 clean(); attacker=put(1,"53","field"); defender=e.make_card("53",0,"hand"); e.enter_field(defender,0)
 e.attack(1,attacker.uid); resolve()
 expect(e.summoning_sick(defender) and e.pending.get("kind")=="block","newly entered untapped unit can still block")
 # A response unit must get its chance to enter before the blocker query.
 clean(); attacker=put(1,"53","field"); var flash=put(0,"56","hand")
 for i in range(4): put(0,"167","palette")
 e.attack(1,attacker.uid)
 expect(e.has_response(0),"no blockers does not suppress a playable response unit")
 var error=e.commit_cast(0,flash.uid,{},e.payment(0,{"蓝":4}).plan)
 expect(error.is_empty(),"defender can cast response unit during attack window")
 resolve(); resolve()
 expect(flash.zone=="field" and e.pending.get("kind")=="block" and flash in e.legal_blockers(),"blocker query includes the unit that entered during response")
 # The response toggle remains independent of the empty block selection.
 clean(); attacker=put(1,"53","field"); e.attack(1,attacker.uid); resolve(); e.pass_priority(1)
 view.response_mode=view.ResponseMode.ON; view.fast_mode=true; view.render()
 expect(find_button(view.ui,"不阻挡")==null,"empty blocker prompt never reaches the UI")
 expect(find_button(view.ui,"不响应 / 继续")!=null,"enabled full response still offers legal response window")
 var revision=e.revision; view.clock_time=2; view._process(1)
 expect(e.revision==revision and e.priority==0,"full response waits without inventing a blocker choice")
 view.response_mode=view.ResponseMode.DEFAULT; view.render(); view.clock_time=2; view._process(1)
 expect(e.players[0].life==19 and e.pending.is_empty(),"default response automatically reaches unblocked damage")
 while view.table.combat_animating: await process_frame
 # Ability stack copies must also ignore the source's selection outline.
 clean(); var source=put(0,"68","field")
 e.stack.append({"id":900,"kind":"ability","owner":0,"source":source.duplicate(true),"target":{"player":1},"amount":1,"name":"测试异能"})
 view.selection=[source.uid]; view.render(); await process_frame
 var visual=view.table.visuals["ability_900"]
 expect(not visual.get_node("Outline").visible and not visual.get_node("Halo").visible,"ability stack copy has no selection outline or glow")
 expect(view.table.visuals["card_"+str(source.uid)].get_node("Outline").visible,"source permanent selection remains independent of stack")
 expect(FileAccess.get_file_as_string("res://saves/decks.json")==save_before,"player deck file unchanged")
 var file=FileAccess.open("res://work/v081-tests.txt",FileAccess.WRITE)
 file.store_string("%d checks; %d failures\n%s" % [checks,failures.size(),"\n".join(failures)])
 print("V081_TEST: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
