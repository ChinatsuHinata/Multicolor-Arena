from pathlib import Path
p=Path(r'C:\Users\tzx20\Documents\test')
f=p/'scripts/duel_table.gd';s=f.read_text(encoding='utf-8-sig').replace('Vector3(4.7+i*0.9,1.0+i*0.32,0.8-i*0.35)','Vector3(4.5+i*0.9,1.0+i*0.38,0.3+i*0.18)').replace('mesh.rotation.y=deg_to_rad(-12+i*6)','mesh.rotation.y=deg_to_rad(-8)');f.write_text(s,encoding='utf-8')
f=p/'scripts/duel_view.gd';s=f.read_text(encoding='utf-8-sig').replace('Rect2(910,605,650,42),19','Rect2(975,88,600,30),17');f.write_text(s,encoding='utf-8')
