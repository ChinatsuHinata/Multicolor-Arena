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
 root.get_texture().get_image().save_png("res://work/test-ui-"+name+".png")
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
