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
func settle():
 await create_timer(0.6).timeout
 if is_instance_valid(view) and view.has_method("revealing"):
  for i in range(400):
   if not view.revealing():break
   await create_timer(0.05).timeout
 await physics_frame
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
 e.presentation_events.clear();view.reveal_player.reset()
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
 app.load_legacy_test_decks(); app.begin_battle(true); view=app.duel_view; view.set_process(false); e=view.engine
 clean()
 for i in range(22): put("1" if i%2==0 else "164","deck")
 put("53","deck",1)
 var g1=put("53","grave"); var g2=put("1","grave"); put("54","exile")
 view.render(); await settle()
 var before=snapshot()
 await click(pile_point("deck"))
 expect(view.debug_open and view.browser_zone=="deck","clicking normal deck opens right browser")
 expect(view.browser_panel.position.x>1200 and view.browser_cards is GridContainer and view.browser_cards.columns==2,"right-hand two-column pile grid")
 expect(view.browser_cards.get_child_count()==22,"entire deck is represented")
 expect(view.browser_cards.get_children().all(func(n): return n.get_meta("display_id")=="back"),"all normal deck entries are hidden")
 expect(top_art().get_child(0).texture==app.texture("back"),"hidden entries show actual card-back art")
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
 view.close_debug(); view.browse_zone(0,"exile"); await process_frame
 expect(view.browser_zone=="exile" and view.browser_cards.get_child_count()==1,"exile pile opens")
 view.close_debug(); await click(pile_point("deck",1))
 expect(view.browser_owner==1 and view.browser_cards.get_child(0).get_meta("display_id")=="back","opposing deck also hides faces outside debug")
 view.close_debug(); expect(snapshot()==before,"all pile views preserve gameplay state")
 # Keep this historical suite focused on pile privacy and editor layout.
 view.close_debug()
 app.draft=Store.blank("50张展示")
 app.draft.leader="70"
 app.draft.rule_set="test"
 var ids=["1","5","14","15","29","53","54","96","164","170"]
 for i in range(50):app.draft.main.append(ids[i%ids.size()])
 app.editor()
 await process_frame
 await process_frame
 var visible=true
 var overlap=false
 for i in range(50):
  var rect=app.main_card_rect(i)
  visible=visible and Rect2(Vector2.ZERO,app.main_scroll.size).encloses(rect)
  overlap=overlap or rect.intersects(Rect2(4,4,140,195))
  for j in range(i):overlap=overlap or rect.intersects(app.main_card_rect(j))
 expect(visible and not overlap and app.main_scroll.scroll_vertical==0,"all fifty main cards plus leader fit without overlap or scrolling")
 expect(app.main_content.size.y<=app.main_scroll.size.y,"fifty-card page has no hidden extra row")
 for i in range(20):app.draft.main.append("53")
 app.update_deck_rows()
 await process_frame
 await process_frame
 app.main_scroll.scroll_vertical=10000
 await process_frame
 expect(app.main_card_rect(69).end.y-app.main_scroll.scroll_vertical<=app.main_scroll.size.y,"70-card capacity still scrolls to the last card")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"player's saved decks untouched")
 print("V092_TEST: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
