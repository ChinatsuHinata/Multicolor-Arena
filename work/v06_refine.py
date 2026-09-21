from pathlib import Path
p=Path(r'C:\Users\tzx20\Documents\test')
f=p/'scripts/duel_table.gd';s=f.read_text(encoding='utf-8-sig').replace('(1.65+(unit_index/3)*2.2)*side','(2.0+(unit_index/3)*2.2)*side').replace('Vector3(-5.7+group*2.3+n*0.24,0.12+n*0.045,4.15*side)','Vector3(0.3+group*1.9+n*0.22,0.12+n*0.045,3.6*side)');f.write_text(s,encoding='utf-8')
f=p/'scripts/duel_view.gd';s=f.read_text(encoding='utf-8-sig').replace('else Vector2(62,86)','else Vector2(54,75)').replace('*stride/2+i*stride,83)','*stride/2+i*stride,70)').replace('table.stack_heights[key]+0.1,1.65','table.stack_heights[key]+0.1,0.0')
s=s.replace('var parts={"root":root,"zone":d.zone}','var parts={"root":root,"zone":d.zone,"owner":d.owner}')
# Keep unrelated right-click previews available; only right-click outside action tiles dismisses the menu.
s=s.replace('  close_overlay(); get_viewport().set_input_as_handled(); return','''  var at=make_input_local(event).position
  var panel=modal_root.get_child(0)
  var inspected=false
  for child in panel.get_children():
   if child is Panel and child.get_global_rect().has_point(at):
    var uid=panel.get_meta("action_card_uid",0)
    var c=engine.find_card(uid)
    if not c.is_empty(): inspect_card(c.card_id,uid); inspected=true
  if not inspected: close_overlay()
  get_viewport().set_input_as_handled(); return''',1)
f.write_text(s,encoding='utf-8')
# Update previous UI regression for drag-to-cast, persistent projection and action cards.
f=p/'tests/test_duel_ui.gd';s=f.read_text(encoding='utf-8-sig')
s=s.replace(' await process_frame; await process_frame\n if DisplayServer',' await create_timer(0.5).timeout; view.update_badge_positions()\n if DisplayServer',1)
a=s.index('func pick_card(');b=s.index('func run():',a)
s=s[:a]+'''func drag(from: Vector2,to: Vector2):
 var move=InputEventMouseMotion.new(); move.position=from; move.global_position=from
 root.push_input(move,true)
 var down=InputEventMouseButton.new(); down.position=from; down.global_position=from; down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true
 root.push_input(down,true); await process_frame
 move=InputEventMouseMotion.new(); move.position=to; move.global_position=to; move.relative=to-from; move.button_mask=MOUSE_BUTTON_MASK_LEFT
 root.push_input(move,true); await process_frame
 var up=InputEventMouseButton.new(); up.position=to; up.global_position=to; up.button_index=MOUSE_BUTTON_LEFT; up.pressed=false
 root.push_input(up,true); await process_frame
func pick_card(uid: int):
 await create_timer(0.5).timeout; await physics_frame
 await mouse_click(view.project(view.table.visuals["card_"+str(uid)].global_position))
'''+s[b:]
a=s.index(' for area in view.table.get_children():');b=s.index(' expect(view.local.get("target"',a)
s=s[:a]+' await create_timer(0.5).timeout\n await mouse_click(view.project(view.table.visuals["card_"+str(enemy_counter.uid)].global_position))\n'+s[b:]
s=s.replace(' view.full_response=true; view.clock_time=2',' view.fast_mode=true; view.full_response=true; view.clock_time=2')
a=s.index(' var hand_row');b=s.index(' var multicolor=',a)
s=s[:a]+''' await create_timer(0.5).timeout
 await drag(view.hand_nodes[shrine.uid].get_global_rect().get_center(),Vector2(800,410))
 expect(view.local.get("uid",-1)==shrine.uid,"mouse hand drag enters payment selection")
'''+s[b:]
s=s.replace(' await pick_card(unit.uid)\n expect(not engine.combat',' await pick_card(unit.uid)\n expect(view.action_menu_open and engine.combat.is_empty(),"permanent presents action choice before attacking")\n var panel=view.modal_root.get_child(0)\n await mouse_click(panel.global_position+Vector2(100,180))\n expect(not engine.combat')
f.write_text(s,encoding='utf-8')
f=p/'tests/test_v02.gd';s=f.read_text(encoding='utf-8-sig').replace('table.get_node("pdeck_layers_46").multimesh.instance_count','table.piles.pdeck.get_node("Layers").multimesh.instance_count');f.write_text(s,encoding='utf-8')
# Verify action-card click in the new regression, plus a visible summoning-sickness frame.
f=p/'tests/test_v06.gd';s=f.read_text(encoding='utf-8-sig').replace(' view.execute_action(e.available_actions(0,unit.uid)[0])',' var action_panel=view.modal_root.get_child(0)\n await click(action_panel.global_position+Vector2(100,180))')
s=s.replace(' expect(e.summoning_sick(newcomer) and not e.can_attack(0,newcomer.uid),"new unit is summoning sick")',' expect(e.summoning_sick(newcomer) and not e.can_attack(0,newcomer.uid),"new unit is summoning sick")\n view.render(); await settle(); view.inspect_card("68",newcomer.uid); await capture("summoning")')
f.write_text(s,encoding='utf-8')
