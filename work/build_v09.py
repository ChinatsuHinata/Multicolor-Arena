from pathlib import Path
import json, shutil, re
root=Path(__file__).resolve().parent.parent
backup=root/'work/v09-backup'
backup.mkdir(exist_ok=True)
for folder in ['scripts','cards']:
 if not (backup/folder).exists(): shutil.copytree(root/folder,backup/folder)
for f in ['saves/decks.json','开发者日志.md','使用说明.md']:
 if not (backup/Path(f).name).exists(): shutil.copy2(root/f,backup/Path(f).name)
rows=json.loads((root/'work/v09-all-source-rows.json').read_text('utf-8'))
mapping={'CHARACTER':{1:2,5:8,6:9,11:14,14:17,15:18,18:21,21:24,23:26,28:31,29:32,30:33,33:36,35:38,38:41,39:42,41:44,48:51,49:52,61:64,64:67,71:73,75:78,78:81,79:82,87:92,'soi_unit_004':5},'SPELL':{94:2,106:14,110:18,118:26,120:28,130:40,131:41,139:49,141:51,143:53,147:57,162:71,163:72,176:73,177:74},'ITEM':{166:4,168:6},'FIELD':{169:2,174:7}}
colors=['红','蓝','绿','黄','黑']
keywords={1:['结晶'],6:['歼灭'],28:['不占战场格'],29:['不占战场格'],30:['不占战场格'],75:['疾行'],78:['疾行'],79:['闪现'],87:['疾行','先制','英勇'],'soi_unit_004':['疾行'],106:['奇迹'],118:['终言'],120:['终言'],162:['终言']}
abilities={1:['enter_haste'],5:['death_draw_life'],11:['hand_autumn'],14:['enter_drain'],15:['no_possession','death_palette'],18:['enter_grave_damage'],21:['grave_return'],23:['death_drain'],28:['enter_sweep'],29:['enter_color_evasion'],30:['enter_blink'],33:['death_damage'],35:['exile_grave'],38:['death_poverty'],39:['enter_fight'],41:['death_devour'],48:['death_undying'],49:['enter_palette_replace'],61:['grave_reanimate'],64:['leave_ufo'],71:['sacrifice_buff','leader_death_damage'],75:['enter_unblockable','timer_replace'],78:['death_six','spell_rebirth'],79:['leader_bounce'],87:['enter_halfghost','combat_exile'],94:['sacrifice_damage'],106:['draw_two'],110:['choose_keyword'],118:['youmu_counter'],120:['timed_life'],130:['destroy_spirit'],131:['divine_modes'],139:['draw_hand_damage'],141:['exile_all'],143:['aurora_modes'],147:['spirit_buff'],162:['deck_damage'],163:['sacrifice_reanimate'],169:['spirit_aura'],174:['unit_discount'],176:['double_modes'],177:['protect_buff']}
manifest=[]
for sheet,items in mapping.items():
 for id,row in items.items():
  source=next(x for x in rows if x['sheet'].startswith(sheet) and x['row']==row)
  v=source['values']; kind={'CHARACTER':'自机' if id in [71,75,78,79,87] else '单位','SPELL':'符卡','ITEM':'道具','FIELD':'结界'}[sheet]
  offset=8 if sheet=='CHARACTER' else 6
  cost={c:int(v[offset+i]) for i,c in enumerate(colors) if v[offset+i] is not None and int(v[offset+i])>0}
  card_colors=[c for i,c in enumerate(colors) if v[offset+i] is not None]
  title=(v[5] or '').replace('/','')
  text=(v[17] or '')+('\n自机能力：'+v[18].strip() if v[18] else '') if sheet=='CHARACTER' else v[16] if sheet=='SPELL' else v[12]
  # Missing numeric cells in spreadsheet; verified directly against image29.png.
  if id==29: cost={'红':2,'黄':1};card_colors=['红','黄'];v[14:17]=[3,3,2]
  visible=re.sub(r'[（(][^）)]*[）)]','',text).strip()
  name=title+'「'+v[6]+'」' if sheet=='CHARACTER' else v[5]
  handlers=[]
  for effect in abilities.get(id,[]): handlers.append({'实现':'extension','名称':effect,'参数':{'效果':effect}})
  if id in [166,168]: handlers=[{'实现':'mana','参数':{'颜色':'绿' if id==166 else '黑'}}]
  if id==6: handlers.append({'实现':'annihilate','参数':{}})
  if id==87: handlers.append({'实现':'brave','参数':{}})
  image='狼女__character-soi-004.jpg' if isinstance(id,str) else f'image{id}.png'
  d={'格式版本':1,'卡牌ID':str(id),'名称':name,'类别':kind,'颜色':card_colors,'费用':cost,'图片':'res://recourse/新增卡片/'+image,'完整说明':text,'能力文字':visible,'来源':f"{source['sheet']}!行{row} · {v[2]}"+('；费用与属性按卡图补全' if id==29 else ''),'构筑资格':{'允许常规构筑':True},'关键词':keywords.get(id,[]),'能力绑定':handlers}
  if sheet=='CHARACTER':
   d.update({'角色名':v[6],'称号':title,'种族':re.split('[·・]',v[7] or ''),'攻击力':int(v[14]),'血量':int(v[15]),'灵力':int(v[16]),'高速':id==79})
  if sheet=='SPELL':d.update({'高速':'高速' in (v[12] or ''),'角色约束':v[13] or '', '符卡类型':v[14] or '', '计时':int(v[15]) if isinstance(v[15],(float,int)) else 0})
  (root/f'cards/{id}.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n','utf-8')
  manifest.append({'id':str(id),'name':name,'source':d['来源'],'image':image})
(root/'work/v09-import-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),'utf-8')
p=root/'scripts/card_database.gd';s=p.read_text('utf-8');s=s.replace('"170"]','"170",'+','.join(json.dumps(x['id']) for x in manifest)+']',1).replace('"turn_buff"]','"turn_buff","extension"]',1)
s=s.replace('"constructible":d["构筑资格"]["允许常规构筑"]','"constructible":d["构筑资格"]["允许常规构筑"],"keywords":d.get("关键词",[]),"spell_type":d.get("符卡类型",""),"time":int(d.get("计时",0))')
p.write_text(s,'utf-8')
p=root/'scripts/main.gd';s=p.read_text('utf-8').replace('var status = ""','var status = ""\nvar debug_mode=false\nvar about_code=""')
s=s.replace('img.rotate_90(CLOCKWISE)','img.rotate_90(COUNTERCLOCKWISE)').replace('if img.get_width() > 1200: img.resize(1200,int(float(img.get_height())*1200/img.get_width()),Image.INTERPOLATE_LANCZOS)','img.resize(1200,1676,Image.INTERPOLATE_LANCZOS)')
s=s.replace('button(screen,"设置",Rect2(96,676,440,64),settings)','button(screen,"设置",Rect2(96,676,440,64),settings)\n button(screen,"关于",Rect2(96,758,440,64),about)')
s=s.replace('button(screen,"返回",Rect2(1480,14,100,40),func(): guard(menu))','button(screen,"返回",Rect2(1480,14,100,40),func(): guard(menu))\n button(screen,"排序卡组",Rect2(1300,14,156,40),sort_current_deck)')
s+='''
func about():
 clear_page("about")
 about_code=""
 var title=label(screen,"关于",Rect2(100,210,1400,70),44,GOLD)
 title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var body=label(screen,"这是测试文字",Rect2(100,365,1400,90),32)
 body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 if debug_mode:
  var state=label(screen,"调试模式已开启",Rect2(100,495,1400,44),22,GOLD)
  state.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  button(screen,"退出调试模式",Rect2(670,571,260,50),func(): debug_mode=false; about())
 button(screen,"返回",Rect2(670,660,260,54),menu)

func _unhandled_key_input(event: InputEvent):
 if page!="about" or not event is InputEventKey or not event.pressed or event.echo: return
 if event.unicode<=0: return
 about_code=(about_code+String.chr(event.unicode).to_lower()).right(10)
 if about_code=="multicolor": debug_mode=true; about()

func sort_current_deck():
 var before=JSON.stringify([draft.main,draft.side])
 Store.sort_deck(draft)
 if JSON.stringify([draft.main,draft.side])!=before: dirty=true
 update_deck_rows()
'''
p.write_text(s,'utf-8')
p=root/'scripts/deck_store.gd';s=p.read_text('utf-8');s=s.replace('if names[name]>4:','if "终言" in CARDS[id].get("keywords",[]) and names[name]>1: return "终言同名牌最多 1 张："+name\n   if names[name]>4:')
s+='''
static func sort_deck(d: Dictionary):
 var categories=["自机","单位","符卡","道具","结界"]
 for zone in ["main","side"]:
  d[zone].sort_custom(func(a,b):
   var x=CARDS[a]; var y=CARDS[b]
   if x.kind!=y.kind: return categories.find(x.kind)<categories.find(y.kind)
   var cx=0; var cy=0
   for n in x.cost.values(): cx+=int(n)
   for n in y.cost.values(): cy+=int(n)
   if cx!=cy: return cx<cy
   if x.name!=y.name: return x.name.naturalnocasecmp_to(y.name)<0
   return a.naturalnocasecmp_to(b)<0)
'''
p.write_text(s,'utf-8')
print('Imported',len(manifest),'cards')
