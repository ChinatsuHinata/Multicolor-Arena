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
func put(who: int,id: String,zone: String):
 var c=e.make_card(id,who,zone); e.players[who][zone].append(c); return c
func clean():
 view.close_overlay(); view.local={}; view.selection=[]; view.drag_uid=0; view.dragging=false
 e.cards=preload("res://scripts/card_database.gd").load_cards()
 e.start(app.decks[app.player_choice],app.decks[app.ai_choice],1,39)
 for p in e.players:
  p.field=[]; p.hand=[]; p.palette=[]; p.grave=[]; p.potato=false; p.mulligan_done=true
 e.phase="main"; e.turn=4; e.active=1; e.priority=1; e.pending={}
 view.response_mode=view.ResponseMode.DEFAULT; view.previous_snapshot={}; view.table.last_combat={}
func find_button(node: Node,title: String):
 if node is Button and node.text==title: return node
 for child in node.get_children():
  var found=find_button(child,title)
  if found: return found
 return null
func tick(): view.clock_time=2; view._process(1)
func snapshot(): return JSON.stringify({"players":e.players,"stack":e.stack,"pending":e.pending,"priority":e.priority,"revision":e.revision,"log":e.log})
func stack_fixture(available: bool) -> Dictionary:
 clean()
 var counter={}
 if available:
  put(0,"70","field"); put(0,"164","palette"); put(0,"164","palette")
  counter=put(0,"100","hand")
 put(1,"165","palette"); put(1,"164","palette")
 var spell=put(1,"96","hand")
 e.commit_cast(1,spell.uid,{"player":0},e.payment(1,{"红":1,"黄":1}).plan)
 return counter
func click_button(title: String):
 var button=find_button(view.ui,title)
 expect(button!=null,"button exists: "+title)
 if button:
  for pressed in [true,false]:
   var event=InputEventMouseButton.new(); event.position=button.get_global_rect().get_center(); event.global_position=event.position
   event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; root.push_input(event,true)
   await process_frame
func capture(name: String):
 if DisplayServer.get_name()=="headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v082-"+name+".png")
func run():
 var save_before=FileAccess.get_file_as_string("res://saves/decks.json")
 app=load("res://main.tscn").instantiate(); root.add_child(app); await process_frame
 app.load_test_decks(); app.begin_battle(true)
 view=app.duel_view; view.set_process(false); view.fast_mode=true; e=view.engine
 expect(view.response_mode==view.ResponseMode.DEFAULT,"new duel starts in default response mode")
 view.table.animation_duration=0.01
 for mode in [view.ResponseMode.ON,view.ResponseMode.DEFAULT,view.ResponseMode.OFF]:
  for available in [false,true]:
   var counter=stack_fixture(available)
   expect(e.has_response(0)==available,"fixture has expected legal response: "+str(available))
   view.set_response_mode(mode)
   var ask=mode==view.ResponseMode.ON or (mode==view.ResponseMode.DEFAULT and available)
   var title=view.RESPONSE_LABELS[mode]+(" with response" if available else " without response")
   expect((find_button(view.ui,"不响应 / 继续")!=null)==ask,title+" prompt visibility")
   if mode==view.ResponseMode.OFF and available:
    var before=snapshot(); view.request_cast(counter.uid); view.hand_clicked(counter.uid)
    expect(view.local.is_empty() and view.selection.is_empty() and snapshot()==before,"off mode blocks response input before automatic pass")
    expect(counter.uid not in view.highlights(),"off mode does not advertise response cards as interactive")
   tick()
   expect(e.priority==(0 if ask else 1),title+" waits or passes correctly")
 # One visible control cycles through all three labels via actual GUI input.
 stack_fixture(false); view.render()
 await click_button("响应：默认")
 expect(view.response_mode==view.ResponseMode.ON,"default cycles to on")
 await capture("on")
 await click_button("响应：开")
 expect(view.response_mode==view.ResponseMode.OFF,"on cycles to off")
 await capture("off")
 await click_button("响应：关")
 expect(view.response_mode==view.ResponseMode.DEFAULT,"off cycles to default")
 await capture("default")
 # Switching while a private response is being paid cancels without a public action.
 var counter=stack_fixture(true); view.auto_pay=false; view.render()
 view.request_cast(counter.uid); view.choose_target({"stack_id":e.stack[0].id})
 view.reserve_resource(e.players[0].palette[0].uid)
 var before=snapshot()
 expect(not view.local.is_empty() and view.local.plan.size()==1,"response payment has a private reservation")
 view.set_response_mode(view.ResponseMode.OFF)
 expect(view.local.is_empty() and snapshot()==before and e.players[0].palette.all(func(c): return not c.tapped),"switching off refunds uncommitted response without public mutation")
 tick(); expect(e.priority==1,"switching off resumes automatic passing")
 # Abilities count as responses even with no hand cards.
 clean(); var source=put(0,"68","field"); put(0,"165","palette"); e.priority=0
 e.cards["68"].abilities.append({"实现":"activated_damage","名称":"测试启动能力","参数":{"数值":1,"费用":{"红":1},"横置":true}})
 view.render(); expect(e.has_response(0) and view.should_ask_response(),"default recognizes legal activated abilities without hand cards")
 view.set_response_mode(view.ResponseMode.OFF); before=snapshot(); view.open_actions(source)
 expect(not view.modal and view.local.is_empty() and snapshot()==before,"off mode suppresses activated response actions")
 # Main phase and required choices are not response prompts.
 clean(); e.active=0; e.priority=0; source=put(0,"53","field"); put(0,"165","palette")
 var buff=put(0,"112","hand"); view.set_response_mode(view.ResponseMode.OFF); before=snapshot(); tick()
 expect(snapshot()==before and find_button(view.ui,"结束主要阶段")!=null,"off mode never automatically ends player's main phase")
 view.request_cast(buff.uid); expect(view.local.get("uid")==buff.uid,"off mode allows normal main-phase casting")
 view.cancel_cast(); view.object_clicked(source.uid); view.confirm_attack()
 expect(e.combat.get("attacker",{}).get("uid")==source.uid,"off mode allows normal main-phase attacks")
 clean(); source=put(1,"53","field"); var defender=put(0,"53","field")
 e.attack(1,source.uid); e.pass_priority(e.priority); e.pass_priority(e.priority)
 view.set_response_mode(view.ResponseMode.OFF); before=snapshot(); tick()
 expect(snapshot()==before and e.pending.get("kind")=="block" and find_button(view.ui,"不阻挡")!=null,"off mode preserves mandatory blocker selection")
 view.object_clicked(defender.uid); expect(defender.uid in view.selection,"off mode allows selecting a legal blocker")
 clean(); var palette=put(0,"165","palette"); var hand=put(0,"53","hand")
 e.active=0; e.priority=0; e.phase="possession"; e.pending={"kind":"possession","owner":0}
 view.set_response_mode(view.ResponseMode.OFF); before=snapshot(); tick()
 view.object_clicked(palette.uid); view.hand_clicked(hand.uid)
 expect(snapshot()==before and view.selection.size()==2,"off mode preserves possession choice and card selection")
 clean(); e.phase="mulligan"; e.players[0].mulligan_done=false; e.players[1].mulligan_done=true
 view.set_response_mode(view.ResponseMode.OFF); before=snapshot(); tick()
 expect(snapshot()==before and find_button(view.ui,"保留")!=null,"off mode preserves mulligan choice")
 # On must also hold an empty-stack phase window with no playable cards.
 clean(); e.phase="prepare"; e.priority=0; view.set_response_mode(view.ResponseMode.ON); before=snapshot(); tick()
 expect(snapshot()==before and find_button(view.ui,"不响应 / 继续")!=null,"on asks even in an empty phase response window")
 expect(FileAccess.get_file_as_string("res://saves/decks.json")==save_before,"player deck file unchanged")
 var file=FileAccess.open("res://work/v082-tests.txt",FileAccess.WRITE)
 file.store_string("%d checks; %d failures\n%s" % [checks,failures.size(),"\n".join(failures)])
 print("V082_TEST: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
