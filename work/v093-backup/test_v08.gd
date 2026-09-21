extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
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
 view.close_overlay(); view.local={}; view.selection=[]; view.damage_signature=""
 e.start(app.decks[app.player_choice],app.decks[app.ai_choice],0,19)
 for p in e.players:
  p.hand=[]; p.palette=[]; p.field=[]; p.grave=[]; p.potato=false; p.mulligan_done=true
 e.phase="main"; e.turn=4; e.active=0; e.priority=0; e.pending={}
 view.table.last_combat={}; view.previous_snapshot={}
func resolve(): e.pass_priority(e.priority); e.pass_priority(e.priority)
func settle(seconds: float=0.5): await create_timer(seconds).timeout; await physics_frame
func find_button(node: Node,title: String):
 if node is Button and node.text==title: return node
 for child in node.get_children():
  var found=find_button(child,title)
  if found: return found
 return null
func click(point: Vector2,button: int=MOUSE_BUTTON_LEFT):
 var event=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=button; event.pressed=true
 root.push_input(event,true); await process_frame
 event=event.duplicate(); event.pressed=false; root.push_input(event,true); await process_frame; await physics_frame
func press(text: String):
 var button=find_button(view.ui,text)
 expect(button!=null and button.is_visible_in_tree(),"visible button: "+text)
 if button: await click(button.get_global_rect().get_center())
func point(uid: int) -> Vector2: return view.project(view.table.visuals["card_"+str(uid)].global_position)
func text_content(node: Node) -> String:
 var text=node.text if node is Label else ""
 for child in node.get_children(): text+=text_content(child)
 return text
func capture(name: String):
 if DisplayServer.get_name()=="headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v08-"+name+".png")
func snapshot(): return JSON.stringify({"players":e.players,"stack":e.stack,"log":e.log,"pending":e.pending,"revision":e.revision})
func run():
 var save_before=FileAccess.get_file_as_string(Store.SAVE_PATH)
 app=load("res://main.tscn").instantiate(); root.add_child(app); await process_frame
 app.load_test_decks(); app.begin_battle(true); view=app.duel_view; view.set_process(false); e=view.engine
 expect(e.cards["50"].rules_text=="歼灭。" and e.cards["54"].rules_text=="英勇。","keyword descriptions omit explanatory definitions")
 expect(not "疾行：" in e.cards["112"].rules_text and e.cards["53"].rules_text.is_empty(),"original buff text retained and vanilla description blank")
 clean()
 var unit=put(0,"68","field"); var other=put(0,"68","field")
 var red=put(0,"165","palette"); var dual=put(0,"170","palette"); put(0,"167","palette")
 var buff=put(0,"112","hand"); put(0,"96","hand")
 view.render(); await settle()
 expect(view.hand_nodes[buff.uid].get_theme_stylebox("panel").border_color==Color("#359bff"),"playable hand starts blue")
 expect(view.table.visuals["card_"+str(unit.uid)].get_node("Outline").material_override.albedo_color==Color("#359bff"),"attackable permanent starts blue")
 await click(view.hand_nodes[buff.uid].get_global_rect().get_center())
 expect(view.hand_nodes[buff.uid].get_theme_stylebox("panel").border_color==Color("#ffd65c") and e.stack.is_empty(),"selecting hand becomes yellow without casting")
 await click(view.hand_nodes[buff.uid].get_global_rect().get_center())
 expect(view.selection.is_empty(),"click selected hand deselects")
 e.apply_turn_buff(e.ref_target(unit),{"攻击力":2,"血量":2,"灵力":1}); unit.damage=4
 unit.tapped=true; red.tapped=true
 view.render(); await settle()
 var values=view.card_badges["card_"+str(unit.uid)].values
 expect(values.power.get_theme_color("font_color")==Color("#69e59a") and values.spirit.get_theme_color("font_color")==Color("#69e59a"),"power and spirit above base are green")
 expect(values.health.get_theme_color("font_color")==Color("#ff737b") and values.health.text=="1","remaining health below base is red")
 expect(view.stat_color(1,2)==Color("#ff737b") and view.stat_color(2,2)==app.WHITE,"all stat comparisons use below-base red and neutral equality")
 var dark=view.table.visuals["card_"+str(unit.uid)].get_node("Face").material_override
 var bright=view.table.visuals["card_"+str(other.uid)].get_node("Face").material_override
 expect(dark.albedo_color.get_luminance()<0.55 and bright.albedo_color==Color.WHITE,"tapping darkens only that permanent instance")
 expect(view.table.visuals["card_"+str(red.uid)].get_node("Face").material_override.albedo_color.get_luminance()<0.55,"tapped palette also darkens")
 var sick=e.make_card("53",0,"hand"); e.enter_field(sick,0)
 view.render(); view.inspect_card("53",sick.uid)
 expect(e.summoning_sick(sick) and not "召唤失调" in text_content(view.ui),"summoning rule retained without UI text indicator")
 await capture("colors")
 red.tapped=false; unit.tapped=false; view.render(); await settle()
 expect(dark.albedo_color==Color.WHITE,"untapping restores original brightness")
 # All local choices can be hidden, inspected and resumed without resetting selection.
 view.auto_pay=true; view.request_cast(buff.uid); view.choose_target(e.ref_target(other))
 expect(view.modal and view.observe_button.visible,"payment decision includes observation toggle")
 var before=snapshot(); var local_before=view.local.duplicate(true); var root_id=view.modal_root.get_instance_id()
 await press("观察战场")
 expect(view.observing and not view.modal_root.visible,"observation hides payment panel and backdrop")
 await click(point(other.uid),MOUSE_BUTTON_RIGHT)
 view._process(3)
 expect(view.inspect_uid==other.uid and snapshot()==before,"inspect battlefield while observing without advancing game")
 await press("返回选择")
 expect(view.modal_root.get_instance_id()==root_id and view.local==local_before and view.modal_root.visible,"same payment choice is restored with local data")
 await press("手动选择")
 view.reserve_resource(red.uid)
 before=snapshot(); local_before=view.local.duplicate(true)
 await press("观察战场"); await press("返回选择")
 expect(view.local==local_before and snapshot()==before,"manual payment reservations survive observation")
 view.commit_local(); await settle()
 var stack_face=view.table.visuals["card_"+str(buff.uid)]
 expect(not stack_face.get_node("Outline").visible and not stack_face.get_node("Halo").visible,"committed stack card clears selection border")
 await capture("stack-neutral")
 resolve(); view.render(); await settle()
 # Multiple-action choice remains only when there are distinct enabled actions.
 e.cards["68"].abilities.append({"实现":"activated_damage","名称":"对目标造成1点伤害","参数":{"数值":1,"费用":{"红":1},"横置":true}})
 red.tapped=false; dual.tapped=false; other.tapped=false; e.priority=0
 view.render(); view.object_clicked(other.uid)
 expect(view.action_menu_open,"unit with attack and ability retains action choice")
 root_id=view.modal_root.get_instance_id()
 await press("观察战场"); await click(point(unit.uid),MOUSE_BUTTON_RIGHT); await press("返回选择")
 expect(view.action_menu_open and view.modal_root.get_instance_id()==root_id,"ability action menu survives observation")
 view.execute_action(e.available_actions(0,other.uid)[1])
 expect(view.observe_button.visible and not view.modal,"target selection also offers battlefield observation")
 before=snapshot(); await press("观察战场"); await click(point(other.uid)); await press("返回选择")
 expect(snapshot()==before and view.local.mode=="target","observation click does not commit target or lose ability")
 view.cancel_cast(); e.cards=preload("res://scripts/card_database.gd").load_cards()
 # Three blockers: two frameless card images with integer allocation; remainder implicit.
 clean(); var attacker=put(0,"50","field"); var blockers=[]
 for i in range(3): blockers.append(put(1,"53","field"))
 view.render(); await settle()
 await click(point(attacker.uid)); await settle()
 expect(not view.modal and view.attack_preview_uid==attacker.uid and e.combat.is_empty(),"single attack action selects privately without popup")
 await press("攻击"); await settle()
 expect(view.card_badges["card_"+str(attacker.uid)].marker.get_meta("combat_role")=="sword","declared attacker displays sword")
 resolve(); e.block(blockers.map(func(c): return c.uid)); view.render(); await settle()
 expect(blockers.all(func(c): return view.card_badges["card_"+str(c.uid)].marker.get_meta("combat_role")=="shield"),"each declared blocker displays shield")
 for key in view.table.descriptors:
  var d=view.table.descriptors[key]
  expect(view.table.visuals[key].get_node("Face").material_override.albedo_texture==app.texture(d.card_id),"reused visual shows correct card art: "+key)
 await capture("combat-markers")
 resolve(); view.render(); await process_frame
 expect(e.pending.get("kind")=="damage_assignment" and view.modal,"multi-block damage choice opens at resolution")
 var panel=view.modal_root.get_child(0)
 expect(panel.get_theme_stylebox("panel") is StyleBoxEmpty and panel.get_children().filter(func(c): return c is TextureRect and c.has_meta("damage_card")).size()==2,"three blockers display exactly two frameless card faces")
 var key0=str(blockers[0].uid); var key1=str(blockers[1].uid)
 await click(view.damage_controls[key0].plus.get_global_rect().get_center())
 await click(view.damage_controls[key0].plus.get_global_rect().get_center())
 await click(view.damage_controls[key1].plus.get_global_rect().get_center())
 expect(view.damage_values[key0]==2 and view.damage_values[key1]==1 and view.damage_remaining()==2,"damage buttons assign first two and calculate last remainder")
 view.change_damage(key1,1); view.change_damage(key1,1); view.change_damage(key1,1)
 expect(view.damage_remaining()==0 and view.damage_controls[key0].plus.disabled,"allocation cannot exceed attack total")
 view.change_damage(key1,-1); view.change_damage(key1,-1)
 var allocation_before=view.damage_values.duplicate(); before=snapshot(); root_id=view.modal_root.get_instance_id()
 await capture("damage-choice")
 await press("观察战场"); await click(point(blockers[1].uid),MOUSE_BUTTON_RIGHT); await capture("observe-battle")
 await press("返回选择")
 expect(view.damage_values==allocation_before and snapshot()==before and view.modal_root.get_instance_id()==root_id,"damage allocation and original dialog survive observation")
 var home=view.table.visuals["card_"+str(attacker.uid)].position
 var block_home=view.table.visuals["card_"+str(blockers[0].uid)].position
 var old_collision_count=view.table.collision_count
 await press("确定分配")
 expect(view.table.combat_animating,"damage starts collision animation")
 expect(attacker.zone=="grave" and view.table.visuals.has("card_"+str(attacker.uid)),"lethal attacker mesh stays visible until collision completes")
 await settle(0.13)
 expect(view.table.visuals["card_"+str(attacker.uid)].position.distance_to(home)>0.15 and view.table.visuals["card_"+str(blockers[0].uid)].position.distance_to(block_home)>0.15,"attacker and blocker both move toward collision")
 await capture("collision")
 await settle(2.0)
 expect(not view.table.combat_animating and view.table.collision_count-old_collision_count==3,"three blockers receive three visible impacts")
 expect(view.table.last_collision_targets==blockers.map(func(c): return c.uid),"collision sequence uses every assigned blocker")
 expect(not view.table.visuals.has("card_"+str(attacker.uid)) and blockers[0].zone=="grave" and blockers[1].zone=="field" and blockers[1].damage==1 and blockers[2].zone=="grave","post-animation scene matches actual damage allocation")
 # An unblocked attack moves forward to the opponent, then returns.
 clean(); attacker=put(0,"53","field"); view.render(); await settle()
 view.object_clicked(attacker.uid); view.confirm_attack(); view.render(); await settle(); resolve(); e.block([]); view.render(); await settle()
 home=view.table.visuals["card_"+str(attacker.uid)].position
 resolve(); view.render(); await settle(0.13)
 expect(view.table.combat_animating and view.table.visuals["card_"+str(attacker.uid)].position.z<home.z-0.5,"unblocked attacker lunges straight toward opposite side")
 await capture("unblocked")
 await settle(0.9)
 expect(view.table.last_collision_targets==[0] and e.players[1].life==19,"unblocked animation preserves spirit damage")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==save_before,"player deck file unchanged")
 var file=FileAccess.open("res://work/v08-tests.txt",FileAccess.WRITE)
 file.store_string("%d checks; %d failures\n%s" % [checks,failures.size(),"\n".join(failures)])
 print("V08_TEST: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
