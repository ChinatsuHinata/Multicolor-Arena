extends SceneTree
var app
var view
var engine
var failures=[]
var checks=0
func expect(ok: bool,title: String):
 checks+=1
 if ok: print("PASS: "+title)
 else: failures.append(title); push_error(title)
func _initialize(): call_deferred("run")
func put(who: int,id: String,zone: String):
 var c=engine.make_card(id,who,zone)
 engine.players[who][zone].append(c)
 return c
func snapshot(): return JSON.stringify({"players":engine.players,"stack":engine.stack,"priority":engine.priority,"log":engine.log,"revision":engine.revision})
func capture(name: String):
 await create_timer(0.5).timeout; view.update_badge_positions()
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://work/duel-"+name+".png")
func mouse_click(point: Vector2):
 var move=InputEventMouseMotion.new(); move.position=point; move.global_position=point
 root.push_input(move,true)
 for pressed in [true,false]:
  var event=InputEventMouseButton.new(); event.position=point; event.global_position=point
  event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
  root.push_input(event,true)
  await process_frame
 await process_frame
 await physics_frame
func find_button(node: Node,title: String):
 if node is Button and node.text==title: return node
 for child in node.get_children():
  var found=find_button(child,title)
  if found: return found
 return null
func press(title: String):
 var button=find_button(view.ui,title)
 expect(button!=null,"button exists: "+title)
 if button: await mouse_click(button.get_global_rect().get_center())
func drag(from: Vector2,to: Vector2):
 var move=InputEventMouseMotion.new(); move.position=from; move.global_position=from
 root.push_input(move,true)
 var down=InputEventMouseButton.new(); down.position=from; down.global_position=from; down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true
 root.push_input(down,true); await process_frame
 move=InputEventMouseMotion.new(); move.position=to; move.global_position=to; move.relative=to-from; move.button_mask=MOUSE_BUTTON_MASK_LEFT
 root.push_input(move,true); await process_frame
 var up=InputEventMouseButton.new(); up.position=to; up.global_position=to; up.button_index=MOUSE_BUTTON_LEFT; up.pressed=false
 root.push_input(up,true); await process_frame
func pick_card(uid: int):
 await create_timer(0.5).timeout; await physics_frame
 await mouse_click(view.project(view.table.visuals["card_"+str(uid)].global_position))
func run():
 var save_before=FileAccess.get_file_as_string("res://saves/decks.json")
 app=load("res://main.tscn").instantiate(); root.add_child(app)
 await process_frame
 app.load_test_decks()
 expect(app.skip_check and app.decks[app.player_choice].main.size()==50,"test decks available without editing saved decks")
 app.begin_battle(true)
 view=app.duel_view; view.set_process(false); engine=view.engine
 expect(view.auto_pay and not view.full_response,"payment defaults on and full response defaults off")
 for who in range(2):
  var p=engine.players[who]; p.hand=[]; p.palette=[]; p.field=[]; p.potato=false; p.mulligan_done=true
  put(who,"68","field"); put(who,"70","field")
  for id in ["164","165","167","170","68","70","99","100"]: put(who,id,"palette")
 engine.players[0].potato=true
 engine.phase="main"; engine.active=0; engine.priority=0; engine.turn=4; engine.pending={}
 var fire=put(0,"99","hand"); var own_counter=put(0,"100","hand"); put(0,"165","hand")
 var enemy_counter=put(1,"100","hand")
 view.render(); await capture("table")
 view.auto_pay=false
 var before=snapshot()
 view.request_cast(fire.uid); view.choose_target({"player":1})
 var source=engine.players[0].palette[0]
 view.reserve_resource(source.uid)
 expect(snapshot()==before,"manual payment reservation produces no public action")
 expect(view.local.plan.size()==1 and not source.tapped,"manual reservation previews tap without changing engine")
 await capture("manual-payment")
 view.cancel_cast()
 expect(snapshot()==before and view.local.is_empty(),"cancel restores all reservations without opponent-visible changes")
 view.auto_pay=true
 view.request_cast(fire.uid); view.choose_target({"player":1})
 expect(view.modal and view.local.mode=="payment","ambiguous automatic payment asks first")
 view.cancel_cast()
 view.auto_pay=false
 view.request_cast(fire.uid); view.choose_target({"player":1})
 view.local.plan=engine.payment(0,engine.cards["99"].cost).plan
 view.commit_local()
 expect(engine.stack.size()==1 and engine.players[1].life==20,"UI commits spell onto visible stack")
 await capture("stack-one")
 engine.commit_cast(1,enemy_counter.uid,{"stack_id":engine.stack[0].id},engine.payment(1,{"黄":2}).plan)
 view.render(); await capture("stack-response")
 expect(engine.stack.size()==2,"response creates second stack card")
 view.request_cast(own_counter.uid)
 await physics_frame; await physics_frame
 await create_timer(0.5).timeout
 await mouse_click(view.project(view.table.visuals["card_"+str(enemy_counter.uid)].global_position))
 expect(view.local.get("target",{}).get("stack_id",-1)==engine.stack.back().id,"mouse picks opposing stack card as counter target")
 view.cancel_cast()
 engine.pass_priority(engine.priority); engine.pass_priority(engine.priority)
 expect(engine.stack.is_empty() and engine.players[1].life==20,"UI battle counter chain resolves correctly")
 view.render(); view.settings_menu(); await capture("settings")
 expect(view.modal,"surrender is inside battle settings")
 view.modal=false; view.render()
 engine.phase="prepare"; engine.priority=0; engine.players[0].hand=[]
 view.fast_mode=true; view.full_response=true; view.clock_time=2
 var rev=engine.revision
 view._process(1)
 expect(engine.revision==rev and engine.priority==0,"full response holds even without playable card")
 view.full_response=false; view.clock_time=2; view._process(1)
 expect(engine.priority==1,"default response auto-passes empty response window")
 # Drive actual Control and 3D mouse input, not only method calls.
 engine.phase="main"; engine.priority=0; engine.active=0; engine.passes=0
 engine.pending={}; engine.combat={}; engine.stack=[]; engine.players[0].hand=[]
 for c in engine.players[0].palette: c.tapped=false
 var shrine=put(0,"170","hand")
 view.auto_pay=false; view.render()
 await process_frame; await process_frame
 await create_timer(0.5).timeout
 await drag(view.hand_nodes[shrine.uid].get_global_rect().get_center(),Vector2(800,410))
 expect(view.local.get("uid",-1)==shrine.uid,"mouse hand drag enters payment selection")
 var multicolor=engine.players[0].palette[5]
 await pick_card(multicolor.uid)
 expect(view.modal,"mouse click on multicolor palette opens color choice")
 await press("黄")
 expect(view.local.plan.size()==1 and view.local.plan[0].color=="黄","mouse color choice reserves chosen color")
 await press("取消使用")
 expect(view.local.is_empty() and not multicolor.tapped,"mouse cancel returns reserved color")
 var unit=engine.units(0)[0]; unit.entered=1; unit.tapped=false
 await pick_card(unit.uid)
 expect(not view.action_menu_open and not view.modal,"only enabled attack needs no action popup")
 expect(not engine.combat.is_empty() and engine.combat.attacker.uid==unit.uid,"root mouse input picks 3D unit to attack")
 engine.pass_priority(engine.priority); engine.pass_priority(engine.priority)
 engine.block([]); engine.pass_priority(engine.priority); engine.pass_priority(engine.priority)
 engine.pass_priority(engine.priority); engine.pass_priority(engine.priority)
 view.render()
 # A single legal payment commits without a modal.
 engine.priority=0; engine.players[0].hand=[]; engine.players[0].palette=[]; engine.players[0].potato=false
 for c in engine.players[0].field: c.tapped=true
 put(0,"165","palette"); put(0,"165","palette")
 var candle=put(0,"165","hand"); view.auto_pay=true
 view.request_cast(candle.uid)
 expect(engine.stack.size()==1 and not view.modal and view.local.is_empty(),"only legal payment commits directly")
 view.settings_menu(); await press("投降"); await press("投降")
 expect(engine.winner==1,"settings submenu surrender ends current match")
 await press("返回对局准备")
 expect(app.page=="setup","result returns to match preparation")
 expect(FileAccess.get_file_as_string("res://saves/decks.json")==save_before,"player saves unchanged")
 var f=FileAccess.open("res://work/duel-ui-test.txt",FileAccess.WRITE)
 f.store_string("%d checks; %d failures\n%s" % [checks,failures.size(),"\n".join(failures)])
 print("DUEL_UI_TEST: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
