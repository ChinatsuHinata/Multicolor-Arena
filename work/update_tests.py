from pathlib import Path
r=Path(r'C:\Users\tzx20\Documents\test')
p=r/'tests/test_v02.gd';t=p.read_text(encoding='utf-8-sig');a=t.index(' var outside=false');b=t.index(' app.setup()',a)
t=t[:a]+''' var outside=false
 var rendered=0
 for node in app.main_content.get_children():
  if node.get_script()==preload("res://scripts/deck_card.gd") and node.source_zone=="main":
   rendered+=1
   if node.position.y+node.size.y>app.main_content.custom_minimum_size.y: outside=true
 expect(rendered==70 and not outside,"70 cards fit scrollable main region")
'''+t[b:];p.write_text(t,encoding='utf-8')
