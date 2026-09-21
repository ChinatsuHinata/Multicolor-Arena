from pathlib import Path
import shutil
r=Path(r'C:\Users\tzx20\Documents\test')
for n in ['main.gd','deck_card.gd']: shutil.copyfile(r/'scripts'/n,r/'work'/(n+'.v03.bak'))
p=r/'scripts/main.gd';s=p.read_text(encoding='utf-8-sig')
s=s.replace(' for value in [info.name,info.kind+"  /  "+info.color,card_description(selected)]:',' for value in [info.name,card_description(selected)]:')
s=s.replace(' library.columns=1',' scroll.set_drag_forwarding(Callable(),can_return_card,return_card_to_library)\n library.columns=1').replace(' scroll.add_child(library)',' scroll.add_child(library)\n library.set_drag_forwarding(Callable(),can_return_card,return_card_to_library)')
a=s.index('  var row=Control.new()',s.index('func update_library():'));b=s.index('\nfunc main_card_rect',a)
s=s[:a]+'''  var row=preload("res://scripts/deck_card.gd").new()
  row.card_id=id
  row.source_zone="library"
  row.face_texture=texture(id)
  row.set_meta("card_id",id)
  row.custom_minimum_size=Vector2(296,64)
  row.add_theme_stylebox_override("panel",style(Color("#142737")))
  library.add_child(row)
  var full_name=label(row,info.name,Rect2(10,4,276,54),17,WHITE)
  full_name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  full_name.clip_text=false
  full_name.mouse_filter=Control.MOUSE_FILTER_IGNORE
  row.tooltip_text=info.name
  row.preview_requested.connect(func(card_id): selected=card_id; update_preview())
  row.clicked.connect(func(card_id,_from,_index,right):
   selected=card_id
   update_preview()
   if not right: add_to("side" if zone=="side" else "main"))
  row.set_drag_forwarding(row._get_drag_data,can_return_card,return_card_to_library)

func can_return_card(_at: Vector2, data: Variant) -> bool:
 return valid_drag_source(data) and data.source_zone in ["main","side","leader"]

func valid_drag_source(data: Variant) -> bool:
 if not data is Dictionary or not Store.CARDS.has(data.get("card_id","")): return false
 var source=data.get("source_zone","")
 if source=="library": return true
 if source=="leader": return draft.leader==data.card_id
 if source in ["main","side"]:
  var index=int(data.get("source_index",-1))
  return index>=0 and index<draft[source].size() and draft[source][index]==data.card_id
 return false

func return_card_to_library(at: Vector2, data: Variant):
 if not can_return_card(at,data): return
 if data.source_zone=="leader": draft.leader=""
 else: draft[data.source_zone].remove_at(int(data.source_index))
 dirty=true
 update_deck_rows()
'''+s[b:]
s=s.replace(' return Store.CARDS[id].description',' var paragraphs=PackedStringArray()\n for paragraph in Store.CARDS[id].description.split("\\n\\n"):\n  if paragraph.begins_with("主动能力：") or paragraph.begins_with("自机能力：") or paragraph.begins_with("能力："):\n   paragraphs.append(paragraph)\n return "\\n\\n".join(paragraphs)')
s=s.replace('return data is Dictionary and data.has("card_id")','return valid_drag_source(data)')
s=s.replace(' tile.card_id=id',' tile.card_id=id\n tile.face_texture=texture(id)')
s=s.replace('func drop_editor_card(data: Dictionary, target: String):\n var source=', 'func drop_editor_card(data: Dictionary, target: String):\n if not valid_drag_source(data) or target not in ["main","side","leader"]: return\n var source=')
p.write_text(s,encoding='utf-8')
p=r/'scripts/deck_card.gd';s=p.read_text(encoding='utf-8-sig').replace('var dragged=false','var dragged=false\nvar face_texture: Texture2D')
a=s.index(' var ghost=Panel.new()');b=s.index(' set_drag_preview(ghost)',a)
s=s[:a]+''' var ghost=TextureRect.new()
 ghost.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 ghost.texture=face_texture
 ghost.custom_minimum_size=Vector2(100,140)
 ghost.size=Vector2(100,140)
 ghost.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 ghost.modulate.a=0.85
'''+s[b:];p.write_text(s,encoding='utf-8')
