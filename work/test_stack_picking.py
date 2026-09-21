from pathlib import Path
p=Path(r'C:\Users\tzx20\Documents\test')
f=p/'tests/test_duel_ui.gd';s=f.read_text(encoding='utf-8-sig')
s=s.replace(' var fire=put(0,"99","hand"); put(0,"100","hand"); put(0,"165","hand")',' var fire=put(0,"99","hand"); var own_counter=put(0,"100","hand"); put(0,"165","hand")')
s=s.replace(' expect(engine.stack.size()==2,"response creates second stack card")',''' expect(engine.stack.size()==2,"response creates second stack card")
 view.request_cast(own_counter.uid)
 await physics_frame; await physics_frame
 for area in view.table.get_children():
  if area is Area3D and area.get_meta("stack_id",-1)==engine.stack.back().id:
   await mouse_click(view.table.camera.unproject_position(area.position)+Vector2(0,60))
   break
 expect(view.local.get("target",{}).get("stack_id",-1)==engine.stack.back().id,"mouse picks opposing stack card as counter target")
 view.cancel_cast()''')
f.write_text(s,encoding='utf-8')
