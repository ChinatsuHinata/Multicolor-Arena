from pathlib import Path
import openpyxl,json,shutil
root=Path(r'C:\Users\tzx20\Documents\test')
for n in ['main.gd','deck_store.gd']: shutil.copyfile(root/'scripts'/n,root/'work'/(n+'.v02.bak'))
w=openpyxl.load_workbook(root/'recourse'/'极彩全牌表 - （圣版可检索）25-12-17.xlsx',read_only=True,data_only=True)
spec={'68':('CHARACTER','SOI-070','自机'),'70':('CHARACTER','SOI-071','自机'),'99':('SPELL','SOI-102','符卡'),'100':('SPELL','SOI-103','符卡'),'164':('ITEM','SOI-097','道具'),'165':('ITEM','SOI-098','道具'),'167':('ITEM','SOI-100','道具'),'170':('FIELD','SOI-103','结界')}
cards={}
for id,(prefix,code,kind) in spec.items():
 s=next(s for s in w if s.title.startswith(prefix))
 idx,row=next((i,r) for i,r in enumerate(s.values,1) if r[2]==code)
 unit=prefix=='CHARACTER'; start=8 if unit else 6
 colors=[c for c,v in zip('红蓝绿黄黑',row[start:start+5]) if v]
 cost='  '.join(f'{c}{v}' for c,v in zip('红蓝绿黄黑',row[start:start+5]) if v)
 details=[f'费用：{cost}  /  颜色值 {row[start+5]}']
 if unit: details += [f'种族：{row[7]}',f'攻击 {row[14]}  /  生命 {row[15]}  /  灵力 {row[16]}','主动能力：'+str(row[17] or '无'),'自机能力：'+str(row[18] or '无')]+(['小传：'+str(row[21])] if row[21] else [])
 elif prefix=='SPELL': details += [str(row[12]),'角色：'+str(row[13] or '无'),'能力：'+str(row[16] or '无')]
 else: details += ['能力：'+str(row[12] or '无')]
 details += [f'{row[1]}  {code}  {row[3]}',f'画师：{row[4]}']
 cards[id]={'name':row[5]+'「'+row[6]+'」' if unit else row[5],'kind':kind,'color':' / '.join(colors),'colors':colors,'file':f'image{id}.png','description':'\n\n'.join(details),'source':f'{s.title}!行{idx}'}
p=root/'scripts/deck_store.gd';txt=p.read_text(encoding='utf-8-sig');a=txt.index('const CARDS =');b=txt.index('static func blank',a);txt=txt[:a]+'# Card text transcribed from the supplied workbook; source rows retained per card.\nconst CARDS = '+json.dumps(cards,ensure_ascii=False,indent=1)+'\n'+txt[b:];p.write_text(txt,encoding='utf-8')
p=root/'scripts/main.gd';t=p.read_text(encoding='utf-8-sig').replace('var filter_color = "全部"','var selected_colors: Array = []\nvar color_buttons = {}\nvar main_scroll: ScrollContainer\nvar main_content: Control')
a=t.index(' var colors=["全部"');b=t.index(' var kind=OptionButton.new()',a)
t=t[:a]+''' color_buttons.clear()
 var colors=["全部","红","蓝","绿","黄","黑"]
 var swatches=[Color("#344553"),Color("#a83035"),Color("#337aa7"),Color("#39794d"),Color("#ac963b"),Color("#383a42")]
 for i in range(colors.size()):
  var color=colors[i]
  var b=button(screen,color,Rect2(1252+i*53,142,47,36),func(): toggle_color(color))
  b.add_theme_font_size_override("font_size",16)
  b.add_theme_stylebox_override("normal",style(swatches[i]))
  b.add_theme_stylebox_override("pressed",style(swatches[i],GOLD))
  b.toggle_mode=true
  color_buttons[color]=b
 refresh_color_buttons()
'''+t[b:]
a=t.index('func update_preview():');b=t.index('func add_selected()',a)
t=t[:a]+'''func toggle_color(color: String):
 if color=="全部": selected_colors.clear()
 elif color in selected_colors: selected_colors.erase(color)
 else: selected_colors.append(color)
 refresh_color_buttons()
 update_library()

func refresh_color_buttons():
 for color in color_buttons:
  var active=selected_colors.is_empty() if color=="全部" else color in selected_colors
  color_buttons[color].set_pressed_no_signal(active)
  color_buttons[color].text=("✓" if active and color!="全部" else "")+color

func matches_colors(info: Dictionary) -> bool:
 if selected_colors.is_empty(): return true
 for color in info.colors:
  if color in selected_colors: return true
 return false

func update_preview():
 free_children(preview)
 card(preview,selected,Rect2(0,0,260,350))
 var info=Store.CARDS[selected]
 var scroll=ScrollContainer.new()
 scroll.name="CardTextScroll"
 scroll.position=Vector2(0,362)
 scroll.size=Vector2(260,341)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 preview.add_child(scroll)
 var column=VBoxContainer.new()
 column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 column.add_theme_constant_override("separation",12)
 scroll.add_child(column)
 for value in [info.name,info.kind+"  /  "+info.color,card_description(selected)]:
  var text=Label.new()
  text.text=value
  text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  text.add_theme_font_size_override("font_size",20 if value==info.name else 17)
  text.add_theme_color_override("font_color",GOLD if value==info.name else WHITE)
  column.add_child(text)
 button(preview,"设为自机",Rect2(0,715,260,43),func(): add_to("leader"),true)

func update_library():
 free_children(library)
 for id in Store.CARDS:
  var info=Store.CARDS[id]
  if not query.is_empty() and not query.to_lower() in info.name.to_lower(): continue
  if filter_kind!="全部" and info.kind!=filter_kind: continue
  if not matches_colors(info): continue
  var row=Control.new()
  row.set_meta("card_id",id)
  row.custom_minimum_size=Vector2(296,64)
  library.add_child(row)
  var b=button(row,"",Rect2(0,0,296,62),func():
   selected=id
   update_preview()
   add_to("side" if zone=="side" else "main"))
  var full_name=label(b,info.name,Rect2(10,4,276,54),17,WHITE)
  full_name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  full_name.clip_text=false
  full_name.mouse_filter=Control.MOUSE_FILTER_IGNORE
  b.tooltip_text=info.name
  b.mouse_entered.connect(func(): selected=id; update_preview())

func main_card_rect(index: int) -> Rect2:
 var column=2+index%8 if index<16 else (index-16)%10
 var row=index/8 if index<16 else 2+(index-16)/10
 return Rect2(4+column*85,4+row*120,79,111)

func update_deck_rows():
 name_label.text=draft.name+(" *" if dirty else "")
 counts.text="主卡组 %d / 70     副卡组 %d / 10     自机 %d / 1" % [draft.main.size(),draft.side.size(),0 if draft.leader.is_empty() else 1]
 var old_scroll=main_scroll.scroll_vertical if is_instance_valid(main_scroll) else 0
 free_children(deck_canvas)
 main_scroll=ScrollContainer.new()
 main_scroll.name="MainDeckScroll"
 main_scroll.size=Vector2(874,509)
 main_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 deck_canvas.add_child(main_scroll)
 main_content=Control.new()
 main_content.name="MainDeckCards"
 var height=maxf(509,main_card_rect(maxi(0,draft.main.size()-1)).end.y+5)
 main_content.custom_minimum_size=Vector2(854,height)
 main_scroll.add_child(main_content)
 make_drop_zone("main",Rect2(0,0,854,height),main_content)
 make_drop_zone("leader",Rect2(0,0,170,240),main_content)
 if not draft.leader.is_empty(): editor_card(draft.leader,"leader",0,Rect2(4,4,162,231),main_content)
 for i in range(draft.main.size()):
  editor_card(draft.main[i],"main",i,main_card_rect(i),main_content)
 main_scroll.set_deferred("scroll_vertical",old_scroll)
 make_drop_zone("side",Rect2(0,553,872,124))
 for i in range(draft.side.size()):
  editor_card(draft.side[i],"side",i,Rect2(9+i*86,559,78,109))
 label(deck_canvas,"副卡组",Rect2(5,519,130,32),18,GOLD)
 var color_counts={"红":0,"蓝":0,"绿":0,"黄":0,"黑":0}
 for id in draft.main:
  for color in Store.CARDS[id].colors: color_counts[color]+=1
 var index=0
 for c in color_counts:
  label(deck_canvas,"%s %d" % [c,color_counts[c]],Rect2(146+index*116,519,108,30),18,MUTED)
  index+=1

'''+t[b:]
a=t.index('func card_description');b=t.index('func make_drop_zone',a)
t=t[:a]+'''func card_description(id: String) -> String:
 return Store.CARDS[id].description

'''+t[b:]
t=t.replace('func make_drop_zone(target: String, rect: Rect2):\n var panel=box(deck_canvas,','func make_drop_zone(target: String, rect: Rect2, parent: Node = null):\n var panel=box(parent if parent else deck_canvas,')
t=t.replace('func editor_card(id: String, source: String, index: int, rect: Rect2):','func editor_card(id: String, source: String, index: int, rect: Rect2, parent: Node = null):').replace(' deck_canvas.add_child(tile)',' (parent if parent else deck_canvas).add_child(tile)')
p.write_text(t,encoding='utf-8')
print('Updated 8 cards from workbook and editor UI')
