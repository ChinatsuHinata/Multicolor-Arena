extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Table=preload("res://scripts/duel_table.gd")
var app
var failures=[]
var checks=0
func expect(ok: bool, title: String):
 checks+=1
 if not ok: failures.append(title); push_error(title)
 else: print("PASS: "+title)
func _initialize():
 call_deferred("run")
func run():
 app=load("res://main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 var d=Store.blank("版本验证")
 d.leader="70"
 d.rule_set="test"
 for i in range(50): d.main.append("68")
 app.decks=[d]
 app.draft=d.duplicate(true)
 app.editor()
 app.drop_editor_card({"card_id":"68","source_zone":"main","source_index":0},"side")
 expect(app.draft.main.size()==49 and app.draft.side.size()==1,"drag main to side conserves count")
 app.drop_editor_card({"card_id":"68","source_zone":"side","source_index":0},"leader")
 expect(app.draft.side.is_empty() and app.draft.leader=="68","drag into leader slot")
 app.draft=d.duplicate(true)
 app.draft.main.resize(49)
 app.selected="167"
 app.add_to("main")
 expect(app.draft.main.size()==50,"list adds card")
 var maximum=Store.blank("70张")
 maximum.leader="70"
 maximum.rule_set="test"
 for i in range(70): maximum.main.append("68")
 app.draft=maximum
 app.editor()
 var outside=false
 var rendered=0
 for node in app.main_content.get_children():
  if node.get_script()==preload("res://scripts/deck_card.gd") and node.source_zone=="main":
   rendered+=1
   if node.position.y+node.size.y>app.main_content.custom_minimum_size.y: outside=true
 expect(rendered==70 and not outside,"70 cards fit scrollable main region")
 app.setup()
 expect(app.page=="setup","setup has no forced redirect")
 app.begin_battle(true)
 app.duel_view.set_process(false)
 var table=app.duel_view.table
 expect(table is Node3D,"battle uses Node3D")
 var board_material=table.board.material_override
 var board_texture=board_material.get_shader_parameter("playmat") if board_material is ShaderMaterial else board_material.albedo_texture
 expect(board_texture is Texture2D,"playmat has texture")
 expect(is_equal_approx(Table.pile_height(50)/Table.pile_height(30),5.0/3.0),"50 card pile is 5/3 height of 30")
 expect(table.piles.pdeck.get_node("Layers").multimesh.instance_count==46,"one geometry layer per remaining card")
 expect(app.duel_view.engine.players[0].hand.size()==4,"rule engine starts with four cards")
 table.inspect_cards(["164","165","167"])
 expect(is_instance_valid(table.inspect_root) and table.inspect_root.get_children().filter(func(n): return n is MeshInstance3D).size()==3,"grave cards remain inside 3D scene")
 app.duel_view.reveal_player.reset()
 app.setup()
 expect(app.page=="setup","return from battle")
 print("REVISION_TEST: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
