from pathlib import Path
p=Path(r'C:\Users\tzx20\Documents\test')
f=p/'scripts/duel_view.gd';s=f.read_text(encoding='utf-8-sig')
s=s.replace('var modal=false','var modal=false\nvar modal_root: Control\nvar view_zoom=0.82',1)
s=s.replace('func render():\n if is_instance_valid(ui):','func render():\n if is_instance_valid(table): view_zoom=table.camera_distance\n if is_instance_valid(ui):',1)
s=s.replace(' var reservations=local.get("plan",[])',' table.camera_distance=view_zoom\n var reservations=local.get("plan",[])',1)
s=s.replace(' modal=true\n var shade=ColorRect.new();',' modal=true\n if is_instance_valid(modal_root):\n  modal_root.get_parent().remove_child(modal_root); modal_root.queue_free()\n var shade=ColorRect.new();',1)
s=s.replace('ui.add_child(shade)\n var panel=host.box','ui.add_child(shade)\n modal_root=shade\n var panel=host.box',1)
f.write_text(s,encoding='utf-8')
