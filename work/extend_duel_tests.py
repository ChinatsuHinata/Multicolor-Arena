from pathlib import Path
p=Path(r'C:\Users\tzx20\Documents\test')
f=p/'tests/test_duel_ui.gd';s=f.read_text(encoding='utf-8-sig')
start=s.index('func run():')
helpers='''func mouse_click(point: Vector2):
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
func pick_card(uid: int):
 await physics_frame; await physics_frame
 for node in view.table.get_children():
  if node is Area3D and node.get_meta("uid",0)==uid:
   var point=view.table.camera.unproject_position(node.position)+Vector2(0,60)
   await mouse_click(point)
   return
 expect(false,"3D card hit target exists")
'''
s=s[:start]+helpers+s[start:]
needle=' expect(FileAccess.get_file_as_string("res://saves/decks.json")==save_before,"player saves unchanged")'
replacement=''' # Drive actual Control and 3D mouse input, not only method calls.
 engine.phase="main"; engine.priority=0; engine.active=0; engine.passes=0
 engine.pending={}; engine.combat={}; engine.stack=[]; engine.players[0].hand=[]
 for c in engine.players[0].palette: c.tapped=false
 var shrine=put(0,"170","hand")
 view.auto_pay=false; view.render()
 await process_frame; await process_frame
 var hand_row
 for node in view.ui.get_children():
  if node is ScrollContainer: hand_row=node.get_child(0)
 await mouse_click(hand_row.get_child(0).get_global_rect().get_center())
 expect(view.local.get("uid",-1)==shrine.uid,"mouse hand click enters payment selection")
 var multicolor=engine.players[0].palette[5]
 await pick_card(multicolor.uid)
 expect(view.modal,"mouse click on multicolor palette opens color choice")
 await press("黄")
 expect(view.local.plan.size()==1 and view.local.plan[0].color=="黄","mouse color choice reserves chosen color")
 await press("取消使用")
 expect(view.local.is_empty() and not multicolor.tapped,"mouse cancel returns reserved color")
 var unit=engine.units(0)[0]; unit.entered=1; unit.tapped=false
 await pick_card(unit.uid)
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
 expect(FileAccess.get_file_as_string("res://saves/decks.json")==save_before,"player saves unchanged")'''
s=s.replace(needle,replacement)
f.write_text(s,encoding='utf-8')
# Retain past regression purpose but update assertions to the real duel entry point.
f=p/'tests/test_v02.gd';s=f.read_text(encoding='utf-8-sig').replace('scripts/battle_table.gd','scripts/duel_table.gd')
a=s.index(' expect(app.table_3d is Node3D')
b=s.index(' app.setup()\n expect(app.page=="setup","return from battle")',a)
s=s[:a]+''' app.duel_view.set_process(false)
 var table=app.duel_view.table
 expect(table is Node3D,"battle uses Node3D")
 expect(table.board.material_override.albedo_texture!=null,"playmat has texture")
 expect(is_equal_approx(Table.pile_height(50)/Table.pile_height(30),5.0/3.0),"50 card pile is 5/3 height of 30")
 expect(table.get_node("pdeck_layers_46").multimesh.instance_count==46,"one geometry layer per remaining card")
 expect(app.duel_view.engine.players[0].hand.size()==4,"rule engine starts with four cards")
 table.inspect_cards(["164","165","167"])
 expect(is_instance_valid(table.inspect_root) and table.inspect_root.get_child_count()==3,"grave cards remain inside 3D scene")
'''+s[b:]
f.write_text(s,encoding='utf-8')
f=p/'tests/test_decks.gd';s=f.read_text(encoding='utf-8-sig').replace('check(Store.validate(d,true).is_empty(),"50 cards legal")','check(not Store.validate(d,true).is_empty(),"50 cards with over four copies rejected")\n check(Store.validate(d,false).is_empty(),"explicit test mode permits repeated demo cards")')
f.write_text(s,encoding='utf-8')
