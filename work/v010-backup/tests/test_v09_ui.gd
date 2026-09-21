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
func find_button(node: Node,title: String):
 if node is Button and node.text==title: return node
 for child in node.get_children():
  var found=find_button(child,title)
  if found: return found
 return null
func click(title: String):
 var b=find_button(app,title); expect(b!=null,"button exists: "+title)
 if b==null: return
 var at=b.get_global_rect().get_center()
 var event=InputEventMouseButton.new(); event.position=at; event.global_position=at; event.pressed=true; event.button_index=MOUSE_BUTTON_LEFT
 root.push_input(event,true); await process_frame
 event=event.duplicate(); event.pressed=false; root.push_input(event,true); await process_frame
func key(text: String):
 for letter in text:
  var event=InputEventKey.new(); event.pressed=true; event.unicode=letter.unicode_at(0); event.keycode=letter.unicode_at(0)
  root.push_input(event,true); await process_frame
func click_pile(who: int):
 var at=view.project(view.table.zone_position("deck",who))
 var event=InputEventMouseButton.new(); event.position=at; event.global_position=at; event.pressed=true; event.button_index=MOUSE_BUTTON_LEFT
 root.push_input(event,true); await process_frame
 event=event.duplicate(); event.pressed=false; root.push_input(event,true); await process_frame
func capture(name: String):
 if DisplayServer.get_name()=="headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v09-"+name+".png")
func put(id: String,zone: String,who: int):
 var c=e.make_card(id,who,zone); e.players[who][zone].append(c); return c
func run():
 var saved=FileAccess.get_file_as_string("res://saves/decks.json")
 app=load("res://main.tscn").instantiate(); root.add_child(app); await process_frame
 await click("关于")
 expect(app.page=="about" and not app.debug_mode,"about page opens without debug")
 var centered=true; var exact=false
 for node in app.screen.get_children():
  if node is Label:
   centered=centered and node.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER
   if node.text=="这是测试文字": exact=true
 expect(centered and exact,"about text is exact and centered")
 await capture("about")
 await key("multicolo"); expect(not app.debug_mode,"partial secret does not unlock")
 await key("r"); expect(app.debug_mode,"typing multicolor unlocks debug")
 await click("返回"); app.load_test_decks(); app.begin_battle(true); view=app.duel_view; view.set_process(false); view.fast_mode=true; e=view.engine
 expect(view.debug_mode and e.debug_enabled,"debug is passed to new match")
 expect(view.enemy_nodes.values().all(func(n): return not n.hidden_card),"every opposing hand card is face up")
 expect(view.acting_player()==0,"human controls own mulligan first")
 e.mulligan(0,[]); view.render(); expect(view.acting_player()==1,"human then controls opponent mulligan")
 var before=e.revision; view._process(1.0); expect(e.revision==before and not e.players[1].mulligan_done,"AI does not auto mulligan in debug")
 await click("保留"); expect(e.players[1].mulligan_done,"opponent mulligan GUI submits for player 1")
 e.pending={}; e.stack=[]; e.triggers=[]; e.phase="main"; e.active=1; e.priority=1
 for p in e.players: p.field=[]; p.hand=[]; p.palette=[]; p.potato=false
 var bot=put("53","hand",1); put("164","palette",1)
 put("21","grave",1); put("29","hand",1); put("1","hand",1); put("96","hand",0); put("165","palette",0); put("164","palette",0)
 view.render(); expect(view.acting_player()==1,"opponent main turn is player controlled")
 before=e.revision; view._process(1.0); expect(e.revision==before and bot.zone=="hand","debug AI never plays or ends main automatically")
 view.hand_clicked(bot.uid); expect(bot.uid in view.selected_uids() and view.local.get("uid")==bot.uid,"opponent hand click prepares a private declaration")
 view.table.busy_until=0; view.request_cast(bot.uid); view.confirm_declaration()
 expect(bot.zone=="stack" and e.stack.back().owner==1,"opponent hand casts using opponent resources")
 expect(e.players[1].palette[0].tapped and not e.players[0].palette[0].tapped,"opponent payment never taps player's palette")
 var has_neutral=view.table.descriptors.values().filter(func(d): return d.zone=="stack").all(func(d): return not d.gold and not d.blue)
 expect(has_neutral,"new debug stack remains border neutral")
 view.render(); await create_timer(0.6).timeout; await capture("debug-battle")
 e.pending={"kind":"possession","owner":1}; view.render(); view.selection=[e.players[1].palette[0].uid]
 var state=JSON.stringify(e.pending); var selection=view.selection.duplicate()
 await click_pile(0); expect(view.debug_open and JSON.stringify(e.pending)==state,"deck inspector opens during required choice")
 await capture("deck-inspection")
 view.close_debug(); expect(view.selection==selection and JSON.stringify(e.pending)==state,"deck inspector preserves interrupted choice")
 await click_pile(1); expect(view.debug_open,"opposing entire deck inspector opens")
 view.toggle_observation(); expect(view.observing and not view.debug_root.visible,"inspector supports observe battlefield")
 view.toggle_observation(); expect(not view.observing and view.debug_root.visible,"return from observing restores inspector")
 view.close_debug(); e.pending={}; e.stack=[]; e.priority=1; view.render()
 await click("调试"); expect(view.debug_open and view.debug_root!=null,"debug panel opens")
 await capture("debug-move")
 view.close_debug(); var card=put("5","hand",1)
 var err=e.debug_move(card.uid,"field"); expect(err.is_empty() and card.zone=="field" and card.owner==1,"debug move preserves ownership")
 expect(view.hand_area(1).has_point(Vector2(780,120)) and not view.hand_area(1).has_point(Vector2(780,350)),"opponent hand has correct drag release area")
 var low=app.texture("soi_unit_004"); var normal=app.texture("29")
 expect(low.get_size()==Vector2(1200,1676) and normal.get_size()==low.get_size(),"low-resolution art normalized to same display resolution")
 app.editor(); app.draft.main=["99","53","99","53","96"]; app.draft.side=["164","164"]; app.draft.leader="70"; app.dirty=false; app.update_deck_rows()
 await click("排序卡组"); expect(app.draft.main==["53","53","96","99","99"] and app.draft.side.size()==2 and app.dirty,"sort button groups every copy and marks unsaved")
 app.selected="29"; app.update_preview(); await capture("editor")
 app.menu(); app.about(); await click("退出调试模式"); expect(not app.debug_mode,"debug can be disabled for next match")
 app.begin_battle(true); view=app.duel_view; view.set_process(false)
 expect(not view.debug_mode and view.enemy_nodes.values().all(func(n): return n.hidden_card) and find_button(view.ui,"调试")==null,"normal match restores hidden information and removes debug controls")
 expect(FileAccess.get_file_as_string("res://saves/decks.json")==saved,"all UI tests preserve saved decks")
 print("V09_UI: %d checks; %d failures" % [checks,failures.size()]); quit(1 if not failures.is_empty() else 0)
