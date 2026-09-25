extends SceneTree

var checks=0
var failures=[]

func _initialize():
 call_deferred("run")

func expect(ok: bool,title: String):
 checks+=1
 if ok: print("PASS: "+title)
 else:
  failures.append(title)
  push_error(title)

func find_button(node: Node,title: String):
 if node is Button and node.text==title:return node
 for child in node.get_children():
  var found=find_button(child,title)
  if found:return found
 return null

func run():
 var settings_path="res://saves/settings.json"
 var saved_settings=FileAccess.get_file_as_string(settings_path)
 var app=load("res://main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.settings()
 expect(find_button(app,"游戏内卡牌使用 2D 上方俯视")!=null,"main settings expose the saved card view preference")
 app.load_legacy_test_decks()
 app.begin_battle(true)
 var view=app.duel_view
 view.set_process(false)
 expect(view.STAGE==Rect2(0,0,1600,900) and view.stage.get_rect()==view.STAGE,"battlefield fills the full game window")
 expect(view.STAGE.encloses(view.HAND),"battlefield extends beneath the full hand area")
 for edge in [Vector2(800,145),Vector2(245,450),Vector2(1357,450),Vector2(800,898)]:
  expect(view.stage.get_global_rect().has_point(edge),"battlefield reaches the former opaque margin "+str(edge))
 expect(find_button(view.ui,"视角复原")!=null,"camera reset is available outside settings")
 view.reveal_player.reset()
 view.engine.presentation_events.clear()
 var hand_card=view.engine.make_card("53",view.local_seat,"hand")
 view.engine.players[view.local_seat].hand.append(hand_card)
 view.render()
 await process_frame
 var settings_button=find_button(view.ui,"设置")
 expect(settings_button!=null and not find_button(view.ui,"视角复原").get_global_rect().intersects(settings_button.get_global_rect()),"reset and settings buttons do not overlap")
 expect(not view.hand_nodes.is_empty() and view.over_hand_card(view.hand_nodes.values()[0].get_global_rect().get_center(),view.local_seat) and not view.over_hand_card(Vector2(1200,850),view.local_seat),"only hand cards retain the hand interaction area")
 view.inspect_card(hand_card.card_id,hand_card.uid)
 expect(not view.inspection.get_child(0) is Panel,"card inspection no longer paints an opaque sidebar")
 view.browse_zone(view.local_seat,"grave")
 expect(is_zero_approx((view.browser_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a),"pile browser has no opaque sidebar background")
 view.close_debug()
 var original=app.top_down_view
 expect(view.table.top_down_view==original,"new duel applies the saved card view")
 view.settings_menu()
 var toggle=find_button(view.ui,"2D 上方俯视")
 expect(toggle!=null and find_button(view.ui,"3D 斜视")!=null,"battle settings expose both card views")
 if toggle:toggle.pressed.emit()
 await process_frame
 expect(view.table.top_down_view,"battle settings switch to the 2D card view immediately")
 var stored=JSON.parse_string(FileAccess.get_file_as_string(settings_path))
 expect(stored is Dictionary and stored.get("top_down_view") == view.table.top_down_view,"selected card view is saved for later duels")
 expect(view.table.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"2D card view uses orthographic projection")
 expect(is_equal_approx(view.table.camera.rotation.x,-PI/2) and is_zero_approx(view.table.camera.position.x) and is_zero_approx(view.table.camera.position.z),"2D card view looks straight down from above")
 expect(is_equal_approx(view.table.camera.size,view.table.WIDE_TOP_DOWN_CAMERA_SIZE) and view.table.camera.size<view.table.WIDE_BOARD_SIZE.y,"2D view zooms in on the playable battlefield")
 expect(view.table.board.mesh.size==view.table.TOP_DOWN_BOARD_SIZE and view.table.board.mesh.size.x>view.table.board.mesh.size.y,"2D battlefield uses the wide playmat")
 expect(view.table.wide_playmat and view.table.board.material_override is ShaderMaterial,"printed zones use selective extension")
 var old_slot_width=0.08*view.table.PRINTED_MAT_SIZE.x
 expect(is_equal_approx(view.table.playmat_x(0.9)-view.table.playmat_x(0.82),old_slot_width),"grave and deck slot widths remain unchanged")
 expect(view.table.zone_position("leader",0).x<-9.0 and view.table.zone_position("deck",0).x>9.0 and view.table.piles.pdeck.get_node("Top").mesh.size==view.table.CARD_SIZE*view.table.SLOT_SCALE,"fixed-size leader and deck cards follow the outer slots")
 expect(view.table.playmat_x(0.84)-view.table.playmat_x(0.16)>0.68*view.table.PRINTED_MAT_SIZE.x+6.9,"battlefield and palette gain horizontal space")
 expect(view.table.board.mesh.size.y-view.table.PRINTED_MAT_SIZE.y>2.0,"battlefield gains vertical space")
 var printed_slot_gap=(1027.0-809.0)/1200.0*view.table.PRINTED_MAT_SIZE.y
 expect(is_equal_approx(view.table.zone_position("grave",0).z-view.table.zone_position("deck",0).z,printed_slot_gap),"printed side card slots keep their vertical proportions")
 view.close_overlay()
 var wheel=InputEventMouseButton.new()
 wheel.pressed=true
 wheel.position=Vector2(1200,850)
 wheel.global_position=wheel.position
 wheel.button_index=MOUSE_BUTTON_WHEEL_UP
 var original_size=view.table.camera.size
 for edge in [Vector2(600,145),Vector2(245,450),Vector2(1357,450),Vector2(800,898)]:
  wheel.position=edge
  wheel.global_position=edge
  root.push_input(wheel,true)
  await process_frame
  expect(view.table.camera.size<original_size,"wheel zoom works in the former opaque margin "+str(edge))
  wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
  root.push_input(wheel,true)
  await process_frame
  expect(is_equal_approx(view.table.camera.size,original_size),"reverse wheel restores zoom from margin "+str(edge))
  wheel.button_index=MOUSE_BUTTON_WHEEL_UP
 wheel.position=Vector2(1200,850)
 wheel.global_position=wheel.position
 root.push_input(wheel,true)
 await process_frame
 expect(view.table.camera.size<original_size,"wheel up zooms in through the battlefield input")
 wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
 root.push_input(wheel,true)
 await process_frame
 expect(is_equal_approx(view.table.camera.size,original_size),"wheel down restores the 2D zoom level")
 wheel.button_index=MOUSE_BUTTON_WHEEL_UP
 root.push_input(wheel,true)
 await process_frame
 var drag=InputEventMouseButton.new()
 drag.button_index=MOUSE_BUTTON_MIDDLE
 drag.pressed=true
 drag.position=Vector2(1200,850)
 root.push_input(drag,true)
 await process_frame
 var motion=InputEventMouseMotion.new()
 motion.position=drag.position+Vector2(60,25)
 motion.button_mask=MOUSE_BUTTON_MASK_MIDDLE
 root.push_input(motion,true)
 await process_frame
 expect(view.table.camera_offset.length()>0.1,"middle drag pans across empty hand-area battlefield")
 drag.pressed=false
 drag.position=motion.position
 root.push_input(drag,true)
 await process_frame
 find_button(view.ui,"视角复原").pressed.emit()
 expect(view.table.camera_offset==Vector3.ZERO and is_equal_approx(view.table.camera.size,view.table.WIDE_TOP_DOWN_CAMERA_SIZE),"visible reset button restores center and zoom")
 var hand_point=view.hand_nodes[hand_card.uid].get_global_rect().get_center()
 drag.pressed=true
 drag.position=hand_point
 root.push_input(drag,true)
 await process_frame
 motion.position=hand_point+Vector2(45,10)
 root.push_input(motion,true)
 await process_frame
 expect(view.table.camera_offset.length()>0.1 and view.selection.is_empty(),"middle drag also pans over a hand card without playing it")
 drag.pressed=false
 drag.position=motion.position
 root.push_input(drag,true)
 await process_frame
 find_button(view.ui,"视角复原").pressed.emit()
 view.settings_menu()
 toggle=find_button(view.ui,"3D 斜视")
 if toggle:toggle.pressed.emit()
 await process_frame
 expect(not view.table.top_down_view and view.table.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"card view switches back to 3D without leaving the duel")
 view.close_overlay()
 var original_distance=view.table.camera_distance
 wheel.button_index=MOUSE_BUTTON_WHEEL_UP
 root.push_input(wheel,true)
 await process_frame
 expect(view.table.camera_distance<original_distance,"wheel up zooms in in 3D view")
 wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
 root.push_input(wheel,true)
 await process_frame
 expect(is_equal_approx(view.table.camera_distance,original_distance),"wheel down restores the 3D zoom level")
 drag.pressed=true
 drag.position=Vector2(1200,850)
 root.push_input(drag,true)
 await process_frame
 motion.position=drag.position+Vector2(-50,-20)
 root.push_input(motion,true)
 await process_frame
 expect(view.table.camera_offset.length()>0.1,"middle drag pans in 3D view")
 drag.pressed=false
 drag.position=motion.position
 root.push_input(drag,true)
 await process_frame
 find_button(view.ui,"视角复原").pressed.emit()
 expect(view.table.camera_offset==Vector3.ZERO and is_equal_approx(view.table.camera_distance,view.table.NEAREST_CAMERA),"reset restores the default 3D view")
 view.set_card_view(original)
 await process_frame
 var file=FileAccess.open(settings_path,FileAccess.WRITE)
 if file:
  file.store_string(saved_settings)
  file.close()
 print("CARD_VIEW: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
