from pathlib import Path
p=Path(r'C:\Users\tzx20\Documents\test')
f=p/'tests/test_v02.gd';s=f.read_text(encoding='utf-8-sig').replace('table.inspect_root.get_child_count()==3','table.inspect_root.get_children().filter(func(n): return n is MeshInstance3D).size()==3');f.write_text(s,encoding='utf-8')
f=p/'scripts/duel_view.gd';s=f.read_text(encoding='utf-8-sig').replace('var inspect_caption=""','var inspect_caption=""\nvar inspection_signature=""')
s=s.replace('func update_inspection():\n clear_children(inspection)','''func update_inspection():
 var current=engine.find_card(inspect_uid)
 var signature=inspect_id+str(inspect_uid)+inspect_caption+str(engine.summoning_sick(current))
 if signature==inspection_signature: return
 inspection_signature=signature
 clear_children(inspection)''')
f.write_text(s,encoding='utf-8')
