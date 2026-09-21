extends SceneTree
const Duel=preload("res://scripts/rules/duel_engine.gd")
const DB=preload("res://scripts/card_database.gd")
const Store=preload("res://scripts/deck_store.gd")
var checks=0
var failures=[]
var app
var view
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
 expect(e.pending.get("kind")=="block","attack offers block selection")
func click(point: Vector2):
 var event=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
 root.push_input(event,true); await process_frame
 event=event.duplicate(); event.pressed=false; root.push_input(event,true); await process_frame
func point(uid: int) -> Vector2: return view.project(view.table.visuals["card_"+str(uid)].global_position)
func settle(time: float=0.5): await create_timer(time).timeout; await physics_frame
func find_button(node: Node,title: String):
 if node is Button and node.text==title: return node
 for child in node.get_children():
  var result=find_button(child,title)
  if result: return result
 return null
func capture(name: String):
 if DisplayServer.get_name()=="headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v07-"+name+".png")
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
 e=fixture(); var titan=put(0,"54","field"); titan.attacked=true; titan.tapped=true
 e.advance_phase(); expect(e.stack.size()==1,"titan brave creates end-phase trigger"); resolve()
 expect(not titan.tapped,"titan brave untaps on resolution")
 e=fixture(); var moon=put(0,"96","hand"); put(0,"165","palette"); put(0,"164","palette")
 e.active=1; e.commit_cast(0,moon.uid,{"player":1},e.payment(0,cards["96"].cost).plan); resolve()
 expect(e.players[1].life==18 and moon.zone=="grave","generic fast spell deals actual two damage")
 e=fixture(); moon=put(1,"96","hand"); put(1,"165","palette"); put(1,"164","palette"); e.priority=1; e.players[0].life=2
 e.ai_step(1); expect(e.stack.size()==1,"AI uses new fast damage for lethal response"); resolve()
 expect(e.winner==1,"new AI response can complete match")
 e=fixture(); put(1,"112","hand"); put(1,"165","palette"); e.active=1; e.priority=1
 e.ai_step(1); expect(e.priority==0,"AI passes unusable buff instead of stalling")
 # Real UI: selection stays local until the explicit confirmation button.
 app=load("res://main.tscn").instantiate(); root.add_child(app); await process_frame
 app.load_legacy_test_decks(); app.begin_battle(true); view=app.duel_view; view.set_process(false); e=view.engine
 for who in range(2):
  var p=e.players[who]; p.hand=[]; p.palette=[]; p.field=[]; p.grave=[]; p.potato=false; p.mulligan_done=true
  for id in ["50","53","54","56","57","68"]: put(who,id,"field")
  for id in ["164","165","167"]: put(who,id,"field")
  for id in ["50","53","54","56","57","70","96","112"]: put(who,id,"palette")
 var palette=e.players[0].palette[1]; var tapped=e.players[0].palette[2]; tapped.tapped=true
 var hand=put(0,"112","hand"); put(0,"96","hand"); put(0,"56","hand"); put(0,"50","hand")
 for id in ["50","53","56","96"]: put(1,id,"hand")
 e.phase="possession"; e.turn=6; e.active=0; e.priority=0; e.pending={"kind":"possession","owner":0}
 view.render(); await settle(0.6); await capture("possession-blue")
 var outline=view.table.visuals["card_"+str(palette.uid)].get_node("Outline")
 expect(outline.visible and outline.material_override.albedo_color==Color("#359bff"),"untapped palette shows blue possession border")
 expect(not view.table.visuals["card_"+str(tapped.uid)].get_node("Outline").visible,"tapped palette cannot be possessed")
 expect(view.banner.get_child_count()==1 and view.banner.get_child(0) is Label,"phase banner contains text only")
 expect(find_button(view.ui,"确定凭依").disabled,"confirm disabled before both selections")
 await click(point(palette.uid)); await settle()
 expect(palette.uid in view.selection and outline.material_override.albedo_color==Color("#ffd65c"),"clicked palette becomes gold")
 await click(point(palette.uid)); await settle()
 expect(view.selection.is_empty() and outline.material_override.albedo_color==Color("#359bff"),"clicking selected palette cancels to blue")
 await click(point(palette.uid)); await settle()
 var before=JSON.stringify({"players":e.players,"log":e.log,"revision":e.revision})
 await click(view.hand_nodes[hand.uid].get_global_rect().get_center()); await settle()
 expect(view.selection.size()==2 and hand.uid in view.selection,"hand card can be selected after palette")
 expect(view.hand_nodes[hand.uid].get_theme_stylebox("panel").border_width_left==5,"selected hand gold border is visibly thick")
 expect(JSON.stringify({"players":e.players,"log":e.log,"revision":e.revision})==before,"selecting both cards does not exchange or reveal action")
 expect(not find_button(view.ui,"确定凭依").disabled,"both selections enable confirmation")
 await capture("possession-gold")
 await click(view.hand_nodes[hand.uid].get_global_rect().get_center())
 expect(view.selection.size()==1 and find_button(view.ui,"确定凭依").disabled,"selected hand can be toggled off")
 await click(view.hand_nodes[hand.uid].get_global_rect().get_center())
 await click(find_button(view.ui,"确定凭依").get_global_rect().get_center()); await settle()
 expect(palette.zone=="hand" and hand.zone=="palette" and e.pending.is_empty(),"only confirm exchanges cards")
 expect(view.selection.is_empty(),"confirmation clears both local selections")
 expect(view.hand_nodes.values().all(func(n): return n.get_child_count()==1),"no separate hand color or cost chips")
 expect(view.card_badges.values().all(func(badge): return not badge.has("cost") and not badge.has("palette")),"no extra battlefield color elements")
 var table=view.table
 expect(is_equal_approx(table.zone_position("deck",0).z,2.786667) and is_equal_approx(table.zone_position("grave",0).z,5.693333),"deck and grave match printed mat centers")
 expect(table.piles.pdeck.get_node("Top").mesh.size==table.CARD_SIZE*table.SLOT_SCALE,"pile footprint fits printed slot")
 expect(is_equal_approx(table.descriptors["card_"+str(e.players[0].leader.uid)].scale.x,table.SLOT_SCALE),"leader footprint matches printed slot scale")
 expect(is_equal_approx(table.pile_height(50)/table.pile_height(30),5.0/3.0) and table.pile_height(50)<0.7,"piles stay proportional while resting closer to mat")
 for who in range(2):
  for unit in e.units(who):
   var at=table.descriptors["card_"+str(unit.uid)].at
   expect(absf(at.z)+1.36*0.95<3.2,"six units remain in battlefield rather than palette")
 e.phase="main"; e.pending={}; e.priority=0; view.render(); await settle(1.2); view.inspect_card("50",e.units(0)[0].uid); await capture("table")
 e.phase="end"; view.render(); await settle(0.2); await capture("phase")
 app.editor(); app.filter_kind="单位"; app.update_library(); app.selected="50"; app.update_preview(); await settle(0.3); await capture("editor")
 expect(Store.CARDS.has("112") and Store.CARDS.has("50"),"editor shares expanded card database")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==save_before,"user deck save unchanged")
 var file=FileAccess.open("res://work/v07-tests.txt",FileAccess.WRITE)
 file.store_string("%d checks; %d failures\n%s" % [checks,failures.size(),"\n".join(failures)])
 print("V07_TEST: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
