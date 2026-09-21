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
func find_button(node: Node,title: String):
 if node is Button and node.text==title: return node
 for child in node.get_children():
  var found=find_button(child,title)
  if found: return found
 return null
func click(at: Vector2,button: int=MOUSE_BUTTON_LEFT):
 var event=InputEventMouseButton.new(); event.position=at; event.global_position=at; event.pressed=true; event.button_index=button
 root.push_input(event,true); await process_frame
 event=event.duplicate(); event.pressed=false; root.push_input(event,true); await process_frame; await physics_frame
func press(title: String):
 var b=find_button(view.ui,title); expect(b!=null,"button: "+title)
 if b: await click(b.get_global_rect().get_center())
func drag(from: Vector2,to: Vector2,cancel: bool=false):
 var event=InputEventMouseButton.new(); event.position=from; event.global_position=from; event.pressed=true; event.button_index=MOUSE_BUTTON_LEFT
 root.push_input(event,true); await process_frame
 var motion=InputEventMouseMotion.new(); motion.position=from+Vector2(-20,0); motion.global_position=motion.position; motion.button_mask=MOUSE_BUTTON_MASK_LEFT
 root.push_input(motion,true); await process_frame
 motion=motion.duplicate(); motion.position=to; motion.global_position=to
 root.push_input(motion,true); await process_frame
 event=event.duplicate(); event.position=to; event.global_position=to; event.pressed=cancel; event.button_index=MOUSE_BUTTON_RIGHT if cancel else MOUSE_BUTTON_LEFT
 root.push_input(event,true); await process_frame
 if cancel:
  event=event.duplicate(); event.pressed=false; root.push_input(event,true)
  event=event.duplicate(); event.button_index=MOUSE_BUTTON_LEFT; root.push_input(event,true)
 await process_frame; await physics_frame
func settle(): await create_timer(0.6).timeout; await physics_frame
func capture(name: String):
 if DisplayServer.get_name()=="headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v092-"+name+".png")
func put(id: String,zone: String,who: int=0):
 var c=e.make_card(id,who,zone); e.players[who][zone].append(c); return c
func clean(debug: bool=false):
 view.close_debug(); view.close_overlay(); view.local={}; view.selection=[]; view.clear_attack_preview()
 e.start(app.decks[app.player_choice],app.decks[app.ai_choice],0,42)
 for p in e.players:
  for z in ["hand","palette","field","grave","exile","deck"]: p[z]=[]
  p.potato=false; p.mulligan_done=true; p.turns=3
 e.phase="main"; e.turn=6; e.active=0; e.priority=0; e.pending={}; e.combat={}
 view.debug_mode=debug; e.debug_enabled=debug; view.previous_snapshot={}; view.table.last_combat={}
func snapshot(): return JSON.stringify({"players":e.players,"stack":e.stack,"log":e.log,"pending":e.pending,"combat":e.combat,"revision":e.revision})
func point(uid: int) -> Vector2: return view.project(view.table.visuals["card_"+str(uid)].global_position)
func pile_point(zone: String,who: int=0) -> Vector2: return view.project(view.table.zone_position(zone,who))
func top_art(): return view.browser_cards.get_child(0).get_node("PileCard")
func resolve(): e.pass_priority(e.priority); e.pass_priority(e.priority)
func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 app=load("res://main.tscn").instantiate(); root.add_child(app); await process_frame
 app.load_test_decks(); app.begin_battle(true); view=app.duel_view; view.set_process(false); e=view.engine
 clean()
 for i in range(22): put("1" if i%2==0 else "164","deck")
 put("53","deck",1)
 var g1=put("53","grave"); var g2=put("1","grave"); put("54","exile")
 view.render(); await settle()
 var before=snapshot()
 await click(pile_point("deck"))
 expect(view.debug_open and view.browser_zone=="deck","clicking normal deck opens right browser")
 expect(view.browser_panel.position.x>1200 and view.browser_cards is GridContainer and view.browser_cards.columns==3,"right-hand three-column pile grid")
 expect(view.browser_cards.get_child_count()==22,"entire deck is represented")
 expect(view.browser_cards.get_children().all(func(n): return n.get_meta("display_id")=="back"),"all normal deck entries are hidden")
 expect(top_art().get_child(0).texture==load("res://assets/card_back.svg"),"hidden entries show actual card-back art")
 await click(top_art().get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
 expect(view.inspect_id=="back" and view.inspect_uid==0,"right-click cannot reveal hidden deck identities")
 await drag(top_art().get_global_rect().get_center(),view.project(Vector3(0,0,2.7)))
 expect(e.players[0].field.is_empty() and snapshot()==before,"normal mode cannot debug-drag hidden cards")
 await click(view.browser_scroll.get_global_rect().get_center(),MOUSE_BUTTON_WHEEL_DOWN)
 expect(view.browser_scroll.scroll_vertical>0,"mouse wheel scrolls the vertical pile")
 await capture("hidden-deck")
 view.close_debug(); await click(pile_point("grave")); await process_frame
 expect(view.browser_zone=="grave" and view.browser_cards.get_child(0).get_meta("display_id")==g2.card_id,"graveyard lists visible top first")
 expect(e.players[0].grave==[g1,g2],"browsing does not reverse actual graveyard")
 await click(top_art().get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
 expect(view.inspect_uid==g2.uid,"public grave cards can be inspected")
 view.close_debug(); await click(pile_point("exile"))
 expect(view.browser_zone=="exile" and view.browser_cards.get_child_count()==1,"exile pile opens")
 view.close_debug(); await click(pile_point("deck",1))
 expect(view.browser_owner==1 and view.browser_cards.get_child(0).get_meta("display_id")=="back","opposing deck also hides faces outside debug")
 view.close_debug(); expect(snapshot()==before,"all pile views preserve gameplay state")
 # Real mouse debug placement, including invalid and cancelled drops.
 clean(true)
 var artifact=put("164","deck"); var sunny=put("1","deck"); var opponent=put("53","deck",1)
 var resource=put("165","palette")
 view.render(); await settle(); await click(pile_point("deck")); await process_frame
 expect(view.browser_cards.get_child(0).get_meta("display_id")=="164","debug deck shows faces in draw order")
 await drag(top_art().get_global_rect().get_center(),view.project(Vector3(-3,0,3.4)))
 expect(artifact.zone=="field" and not resource.tapped and e.stack.is_empty(),"dragged artifact enters without payment or stack")
 expect(e.pending.is_empty() and e.triggers.is_empty() and e.returns.is_empty(),"debug placement has no event choices")
 expect(view.browser_cards.get_child_count()==1,"source pile updates after drag")
 await drag(top_art().get_global_rect().get_center(),view.project(Vector3(1,0,2.5)))
 expect(sunny.zone=="field" and e.pending.is_empty() and e.triggers.is_empty() and e.stack.is_empty(),"debug Sunny placement does not trigger haste")
 expect(not e.has_haste(sunny),"debug placement does not apply the ETB effect silently either")
 view.browse_zone(0,"field"); await process_frame; await process_frame
 before=snapshot()
 await drag(top_art().get_global_rect().get_center(),view.project(Vector3(0,0,-3)))
 expect(snapshot()==before,"cannot transfer ownership by dropping on opponent field")
 await drag(top_art().get_global_rect().get_center(),pile_point("grave"),true)
 expect(snapshot()==before,"right click cancels debug dragging")
 await drag(top_art().get_global_rect().get_center(),pile_point("grave"))
 expect(artifact.zone=="grave" and e.triggers.is_empty(),"field card can be dragged into graveyard silently")
 view.browse_zone(0,"grave"); await process_frame; await process_frame
 await drag(top_art().get_global_rect().get_center(),Vector2(660,780))
 expect(artifact.zone=="hand","graveyard card can be dragged into hand")
 view.browse_zone(1,"deck"); await process_frame; await process_frame
 await drag(top_art().get_global_rect().get_center(),view.project(Vector3(1,0,-2.5)))
 expect(opponent.zone=="field" and opponent.owner==1,"opposing deck drag stays on opposing side")
 var spell=put("96","deck"); var old=spell.duplicate(true)
 expect(not e.debug_move(spell.uid,"field").is_empty() and spell==old,"ordinary spells cannot be left on battlefield")
 expect(not e.debug_move(spell.uid,"leader").is_empty() and spell==old,"ordinary cards cannot replace the chosen leader")
 expect(e.debug_move(sunny.uid,"grave").is_empty() and e.triggers.is_empty() and e.pending.is_empty(),"debug death does not trigger crystal")
 for i in range(19): put("53","deck")
 var deep=put("165","deck")
 view.render(); view.browse_zone(0,"deck"); await process_frame; await process_frame
 var deep_tile=view.browser_cards.get_child(view.browser_cards.get_child_count()-1)
 view.browser_scroll.scroll_vertical=int(deep_tile.position.y); await process_frame; await process_frame
 expect(view.browser_scroll.scroll_vertical>0,"debug list can reach a card deep in the deck")
 await drag(deep_tile.get_node("PileCard").get_global_rect().get_center(),view.project(Vector3(0,0,3.4)))
 expect(deep.zone=="field" and e.stack.is_empty(),"scrolled card drags the correct instance onto battlefield")
 await settle(); view.browse_zone(0,"grave"); await process_frame; await capture("debug-browser")
 # Normal Sunny play: both controllers' units, including the source, are valid.
 for choice in range(3):
  clean()
  var own=put("53","field"); var enemy=put("54","field",1)
  sunny=put("1","hand"); put("165","palette"); put("164","palette")
  view.render(); await settle(); view.request_cast(sunny.uid); view.confirm_declaration()
  expect(sunny.zone=="stack","normal Sunny casting enters the stack")
  resolve(); view.render(); await settle()
  expect(sunny.zone=="field" and e.pending.get("kind")=="effect_choice","normal Sunny ETB asks for a target")
  expect([sunny.uid,own.uid,enemy.uid].all(func(uid): return uid in view.highlights()),"self, friendly and opposing units are selectable")
  var target=[sunny,own,enemy][choice]
  await click(point(target.uid)); view.confirm_trigger()
  expect(e.pending.is_empty() and e.stack.size()==1 and e.stack[0].target.uid==target.uid,"battlefield click submits the chosen Sunny target")
  resolve(); view.render(); await settle()
  expect(e.has_haste(target),"chosen unit receives haste after response window")
 # Attack stays private until the bottom-left confirmation.
 clean()
 var attacker=put("53","field"); put("54","field",1)
 view.render(); await settle(); before=snapshot()
 await click(point(attacker.uid))
 expect(view.attack_preview_uid==attacker.uid and not view.modal,"single-action unit selects attack without a modal")
 expect(snapshot()==before and not attacker.tapped and e.combat.is_empty(),"preselection changes no public state")
 expect(view.table.descriptors["card_"+str(attacker.uid)].gold and view.combat_marker(attacker.uid)=="sword","preselection shows gold border and private sword")
 var attack_button=find_button(view.ui,"攻击")
 expect(attack_button!=null and attack_button.position.x>1300 and attack_button.position.y>650,"attack confirmation appears at bottom right")
 await capture("attack-preview")
 await press("观察战场")
 await click(point(attacker.uid),MOUSE_BUTTON_RIGHT)
 expect(view.observing and view.attack_preview_uid==attacker.uid and snapshot()==before,"observing keeps attack preselection private and intact")
 await press("返回选择")
 expect(view.attack_preview_uid==attacker.uid and find_button(view.ui,"攻击").visible,"returning restores the uncommitted attack button")
 await click(Vector2(600,560),MOUSE_BUTTON_RIGHT)
 expect(view.attack_preview_uid==0 and view.combat_marker(attacker.uid).is_empty() and snapshot()==before,"right-click elsewhere cancels without declaring")
 await click(point(attacker.uid)); await press("攻击")
 expect(e.combat.get("attacker",{}).get("uid")==attacker.uid and attacker.tapped and e.priority==1,"confirming publishes attack exactly once")
 expect(view.attack_preview_uid==0 and not view.table.descriptors["card_"+str(attacker.uid)].gold,"confirmed attack clears private gold selection")
 # Compact editor guarantees all 50 plus leader in the viewport; 70 remain reachable.
 view.close_debug(); app.draft=Store.blank("50张展示"); app.draft.leader="70"
 var ids=["1","5","14","15","29","53","54","96","164","170"]
 for i in range(50): app.draft.main.append(ids[i%ids.size()])
 app.editor(); await process_frame; await process_frame
 var visible=true; var overlap=false
 for i in range(50):
  var rect=app.main_card_rect(i)
  visible=visible and Rect2(Vector2.ZERO,app.main_scroll.size).encloses(rect)
  overlap=overlap or rect.intersects(Rect2(4,4,140,195))
  for j in range(i): overlap=overlap or rect.intersects(app.main_card_rect(j))
 expect(visible and not overlap and app.main_scroll.scroll_vertical==0,"all fifty main cards plus leader fit without overlap or scrolling")
 expect(app.main_content.size.y<=app.main_scroll.size.y,"fifty-card page has no hidden extra row")
 await capture("editor-50")
 for i in range(20): app.draft.main.append("53")
 app.update_deck_rows(); await process_frame; await process_frame
 app.main_scroll.scroll_vertical=10000; await process_frame
 expect(app.main_card_rect(69).end.y-app.main_scroll.scroll_vertical<=app.main_scroll.size.y,"70-card capacity still scrolls to the last card")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"player's saved decks untouched")
 print("V092_TEST: %d checks; %d failures" % [checks,failures.size()])
 var report=FileAccess.open("res://work/v092-tests.txt",FileAccess.WRITE); report.store_string("%d checks; %d failures\n%s" % [checks,failures.size(),"\n".join(failures)])
 quit(0 if failures.is_empty() else 1)

