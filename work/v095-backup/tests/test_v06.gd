extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
var app
var view
var e
var failures=[]
var checks=0
func expect(ok: bool,title: String):
 checks+=1
 if ok: print("PASS: "+title)
 else: failures.append(title); push_error(title)
func _initialize(): call_deferred("run")
func put(who: int,id: String,zone: String):
 var c=e.make_card(id,who,zone); e.players[who][zone].append(c); return c
func snapshot(): return JSON.stringify({"players":e.players,"stack":e.stack,"priority":e.priority,"revision":e.revision,"log":e.log})
func settle(seconds: float=0.5):
 await create_timer(seconds).timeout
 await physics_frame
 view.update_badge_positions()
func capture(name: String):
 if DisplayServer.get_name()=="headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v06-"+name+".png")
func motion(point: Vector2,held: bool=false):
 var event=InputEventMouseMotion.new(); event.position=point; event.global_position=point
 event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0; event.relative=Vector2(20,0)
 root.push_input(event,true)
func mouse(point: Vector2,button: int,pressed: bool):
 var event=InputEventMouseButton.new(); event.position=point; event.global_position=point
 event.button_index=button; event.pressed=pressed
 root.push_input(event,true)
func click(point: Vector2,button: int=MOUSE_BUTTON_LEFT):
 motion(point); mouse(point,button,true); await process_frame
 mouse(point,button,false); await process_frame; await physics_frame
func drag(from: Vector2,to: Vector2):
 motion(from); mouse(from,MOUSE_BUTTON_LEFT,true); await process_frame
 motion(from+Vector2(20,0),true); await process_frame
 motion(to,true); await process_frame
 mouse(to,MOUSE_BUTTON_LEFT,false); await process_frame
func point(uid: int) -> Vector2:
 return view.project(view.table.visuals["card_"+str(uid)].global_position)
func find_button(node: Node,title: String):
 if node is Button and node.text==title: return node
 for child in node.get_children():
  var found=find_button(child,title)
  if found: return found
 return null
func press(title: String):
 var b=find_button(view.ui,title)
 expect(b!=null,"button exists: "+title)
 if b: await click(b.get_global_rect().get_center())
func resolve(): e.pass_priority(e.priority); e.pass_priority(e.priority)
func run():
 var save_before=FileAccess.get_file_as_string(Store.SAVE_PATH)
 app=load("res://main.tscn").instantiate(); root.add_child(app); await process_frame
 app.load_test_decks(); app.begin_battle(true)
 view=app.duel_view; view.set_process(false); e=view.engine
 for who in range(2):
  var p=e.players[who]; p.hand=[]; p.palette=[]; p.field=[]; p.grave=[]; p.potato=false; p.mulligan_done=true
  put(who,"68","field"); put(who,"70","field")
  put(who,"164","field"); put(who,"165","field"); put(who,"167","field")
  for id in ["164","165","167","170","68","70","99","100"]: put(who,id,"palette")
 e.phase="main"; e.active=0; e.priority=0; e.turn=4; e.pending={}
 e.players[0].potato=true
 var fire=put(0,"99","hand"); var own_counter=put(0,"100","hand")
 put(0,"165","hand"); put(0,"170","hand"); put(0,"68","hand")
 for id in ["100","99","164","167","170","68"]: put(1,id,"hand")
 var dead=put(0,"165","grave")
 view.render(); await settle(1.2)
 expect(view.hand_nodes[fire.uid].size.x>=140,"hand cards enlarged")
 expect(view.enemy_nodes.size()==e.players[1].hand.size(),"one opponent card back per hand card")
 expect(view.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"persistent world renders continuously")
 expect(view.hand_nodes[fire.uid].get_theme_stylebox("panel").border_color==Color("#359bff"),"playable hand card has blue border")
 var hand_point=view.hand_nodes[fire.uid].get_global_rect().get_center()
 await click(hand_point,MOUSE_BUTTON_RIGHT)
 expect(view.inspect_id=="99" and view.inspect_uid==fire.uid,"right click hand inspects correct card")
 await click(point(e.players[0].palette[5].uid),MOUSE_BUTTON_RIGHT)
 expect(view.inspect_id=="70","right click palette inspects card")
 await click(view.project(view.table.piles.pgrave.position+Vector3(0,0.08,0)),MOUSE_BUTTON_RIGHT)
 expect(view.inspect_uid==dead.uid,"right click grave inspects visible top")
 var enemy_uid=e.players[1].hand.back().uid
 await click(view.enemy_nodes[enemy_uid].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
 expect(view.inspect_id=="back" and view.inspect_uid==0,"opponent hand inspection does not reveal identity")
 await click(view.project(view.table.piles.pdeck.position+Vector3(0,1.3,0)),MOUSE_BUTTON_RIGHT)
 expect(view.inspect_id=="back","deck inspection does not leak hidden top card")
 view.inspect_card("68",e.units(0)[0].uid)
 await capture("table")
 var before=snapshot()
 await click(hand_point)
 expect(view.local.is_empty() and snapshot()==before,"plain hand click does not cast")
 await drag(hand_point,hand_point+Vector2(50,-10))
 expect(view.local.is_empty() and snapshot()==before,"drag release inside hand cancels")
 await drag(hand_point,Vector2(790,400))
 expect(view.local.get("uid",-1)==fire.uid and view.local.get("mode","")=="target","drag out of hand prepares card")
 expect(snapshot()==before,"drag preview does not change public game")
 view.auto_pay=false; view.choose_target({"player":1}); view.confirm_declaration()
 view.reserve_resource(e.players[0].palette[0].uid)
 expect(snapshot()==before,"manual reservation remains private")
 await capture("payment")
 view.cancel_cast()
 expect(snapshot()==before,"cancel returns card and all reserved costs")
 # Animation from hand to stack, then reaction card over it.
 view.request_cast(fire.uid); view.choose_target({"player":1}); view.confirm_declaration()
 view.local.plan=e.payment(0,{"黄":3}).plan; view.commit_local()
 await settle()
 expect(view.table.visuals.has("card_"+str(fire.uid)),"committed hand card appears in 3D stack")
 expect(view.table.descriptors["card_"+str(fire.uid)].scale.x>1.8,"stack card enlarged")
 var enemy_counter=e.players[1].hand[0]
 e.commit_cast(1,enemy_counter.uid,{"stack_id":e.stack[0].id},e.payment(1,{"黄":2}).plan)
 view.render(); await settle()
 await click(point(enemy_counter.uid),MOUSE_BUTTON_RIGHT)
 expect(view.inspect_id=="100","right click stack inspects response")
 await capture("stack")
 resolve(); view.render(); await settle()
 expect(e.stack.is_empty() and e.players[1].life==20,"response resolves correctly after animated presentation")
 var unit=e.units(0)[0]; unit.entered=0; unit.tapped=false
 e.priority=0
 view.render(); await settle()
 await click(point(unit.uid))
 expect(not view.action_menu_open and not view.modal,"single attack action has no redundant popup")
 expect(e.combat.is_empty() and view.attack_preview_uid==unit.uid,"unit click privately selects its only attack")
 view.confirm_attack()
 await capture("actions")
 resolve(); e.block([]); resolve(); resolve(); view.render(); await settle()
 expect(view.table.animation_count>5,"draw cast tap attack and resolution use animation tracks")
 # Response default hides empty windows even during opponent main phase.
 e.players[0].hand=[]; e.priority=0; e.active=1; e.phase="main"; e.combat={}; e.stack=[]; e.pending={}
 view.response_mode=view.ResponseMode.DEFAULT; view.render()
 expect(find_button(view.ui,"不响应 / 继续")==null,"no response button when no legal response")
 view.fast_mode=true; view.clock_time=2; view._process(1)
 expect(e.priority==1,"empty opponent-main response auto passes")
 view.response_mode=view.ResponseMode.ON; e.priority=0; view.render()
 expect(find_button(view.ui,"不响应 / 继续")!=null,"full response forces button without playable cards")
 # Mark actual summoning sickness until controller's next reset.
 e.active=0; e.priority=0; e.phase="main"; e.players[0].field=[]
 var newcomer=e.make_card("68",0,"hand"); e.enter_field(newcomer,0)
 expect(e.summoning_sick(newcomer) and not e.can_attack(0,newcomer.uid),"new unit is summoning sick")
 view.render(); await settle(); view.inspect_card("68",newcomer.uid); await capture("summoning")
 e.start_turn(1)
 expect(e.summoning_sick(newcomer),"summoning sickness persists through opponent turn")
 e.start_turn(0); e.phase="main"; e.priority=0; e.pending={}
 expect(not e.summoning_sick(newcomer),"controller reset clears summoning sickness")
 # Synthetic ability fixture; none of the eight published card texts is changed.
 e.cards["68"].abilities.append({"实现":"activated_damage","名称":"对目标造成1点伤害","参数":{"数值":1,"费用":{"红":1},"横置":true}})
 for c in e.players[0].palette: c.tapped=false
 e.players[0].potato=true
 var actions=e.available_actions(0,newcomer.uid)
 expect(actions.size()==2,"attack and activated ability offered separately")
 view.render(); view.open_actions(newcomer); await capture("multiple-actions")
 view.execute_action(actions[1]); view.choose_target({"player":1}); view.confirm_declaration()
 var action_before=snapshot(); view.reserve_resource(e.players[0].palette[1].uid); view.cancel_cast()
 expect(snapshot()==action_before and not newcomer.tapped,"cancel activated ability refunds all costs")
 view.execute_action(actions[1]); view.choose_target({"player":1}); view.confirm_declaration()
 view.local.plan=e.payment(0,{"红":1},[newcomer.uid]).plan; view.commit_local()
 expect(newcomer.zone=="field" and newcomer.tapped and e.stack.back().kind=="ability","ability stacks while permanent stays in battlefield")
 var life=e.players[1].life; resolve()
 expect(e.players[1].life==life-1,"activated ability resolves independently")
 e.phase="end"; e.revision+=1; view.render()
 expect(view.banner_until>Time.get_ticks_msec(),"phase transition displays center banner")
 await settle(0.18); await capture("phase")
 # Repeated complete state updates must preserve the rendering world and resources.
 var viewport_id=view.viewport.get_instance_id(); var table_id=view.table.get_instance_id()
 e.cards=preload("res://scripts/card_database.gd").load_cards()
 e.start(app.decks[app.player_choice],app.decks[app.ai_choice],0,2)
 e.mulligan(0,[]); e.mulligan(1,[])
 view.table.animation_duration=0.015; view.response_mode=view.ResponseMode.DEFAULT
 var frames=0
 for action in range(1000):
  if e.winner!=-2: break
  e.ai_step(e.pending.get("owner",e.priority))
  view.render(); frames+=1
  await process_frame
 expect(e.winner!=-2,"long animated match reaches game result")
 expect(view.viewport.get_instance_id()==viewport_id and view.table.get_instance_id()==table_id,"same world survives every action and turn")
 await settle(0.8)
 expect(view.table.get_child_count()<140,"scene node count remains bounded")
 expect(view.table.materials.size()<20,"material cache remains bounded")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  var image=view.viewport.get_texture().get_image()
  var brightest=0.0; var darkest=1.0
  for y in range(50,image.get_height()-50,47):
   for x in range(150,image.get_width()-150,53):
    var l=image.get_pixel(x,y).get_luminance(); brightest=maxf(brightest,l); darkest=minf(darkest,l)
  expect(brightest-darkest>0.3,"world image is neither black nor white after full match")
 await capture("long-match")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==save_before,"player deck file unchanged")
 var f=FileAccess.open("res://work/v06-test.txt",FileAccess.WRITE)
 f.store_string("%d checks; %d failures; %d rendered actions; %d turns\n%s" % [checks,failures.size(),frames,e.turn,"\n".join(failures)])
 print("V06_TEST: %d checks; %d failures; %d actions; %d turns" % [checks,failures.size(),frames,e.turn])
 quit(0 if failures.is_empty() else 1)
