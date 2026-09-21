"""Reviewed 119-image batch; Excel is authoritative. Archive before defining."""
from pathlib import Path
import json,re,shutil,hashlib,argparse
ROOT=Path(__file__).resolve().parents[1]; WORK=ROOT/'work/v011'; ART=ROOT/'recourse/数据库'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,d): p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def norm(s): return re.sub(r'[\s「」【】『』·・/（）()\[\]"“”\-—－_]', '',s or '')
KEYS={
2:['luna_life'],3:['star_destroy'],7:['hourai_ping'],8:['shanghai_draw'],9:[],12:['letty_freeze'],13:['dai_search'],17:['medicine_kill'],19:['wriggle_evasion'],22:['mystia_life'],24:['ran_discount'],25:['hatate_return','hatate_replace'],26:['komachi_exile'],27:['nitori_ward'],31:['kasen_ramp_stats'],32:['hina_redirect'],34:['clown_sweep'],42:['seiga_death'],43:['momoyo_wither'],44:['akyuu_counter'],45:['keiki_copy'],46:['chen_counter'],47:['meiling_spell'],51:[],52:[],55:[],58:[],59:['kogasa_flash'],60:['murasa_aura'],62:['seiga_imp'],63:['nazrin_draw'],66:['kyouko_shuffle'],67:[],73:['koishi_coin','koishi_evasion'],74:['remilia_lifelink','remilia_aura'],76:['satori_scry','satori_discard'],77:['alice_search','alice_recycle'],80:['cirno_aura','cirno_return'],82:['kanako_pillar','kanako_blast'],85:['kaguya_end'],86:['yuuka_ramp'],90:['suika_attack','suika_counter'],93:['suwako_top','suwako_haste'],
97:['fairy_revive'],98:['tengu_pair'],101:['leader_mark'],102:['kaleidoscope'],103:['grave_top'],104:['destroy_any'],105:['tap_all'],107:['discard_draw'],109:['gungnir'],111:['draw_x'],113:['activity'],114:['blink_two'],116:['sweep_three'],119:['history_exile'],121:['extra_turn'],122:['hand_army'],123:['counter_ability'],124:['counters_x'],125:['unblock_reset'],126:['lake_mill'],127:['waterfall'],128:['philosopher'],129:['two_bats'],132:['ghost_imp'],134:['destroy_item_field'],135:['exile_permanent'],136:['counter_targeting'],137:['gather_counters'],138:['bounce_small'],140:['steal_turn'],142:['search_leader'],144:['crimson_modes'],145:['quiet_modes'],146:['grave_palette'],148:['flower_damage'],149:['door_reveal'],150:['grace_reset'],151:['frogs_x'],152:['fire_scry'],153:['doll_army'],154:['tap_destroy'],155:['fairy_festival'],156:['perfect_freeze'],157:['memory_cast'],158:['palette_army'],159:['end_turn'],160:['untargetable'],161:['wheel_modes'],171:['annihilate_aura'],172:['mist_lake'],173:['heart_grave'],175:['nether_ghost'],178:['cloud_attack'],
'spell-smm-006':['rest_life'],'spell-kmo-005':['snow_time'],'spell-kmo-004':['survivors'],'character-smm01':['shinmy_cast','shinmy_counter'],'character-kmo-001':['komachi_minus','komachi_coins'],'spell-kmo-002':['death_return'],'character-smm07':['sanae_search']}
WORDS={9:['奇迹'],17:[],19:[],34:['疾行'],52:['吸血3'],55:['先制'],58:['歼灭'],67:['先制','奇迹'],80:[],82:['威吓'],85:['不会被消灭'],86:['威吓'],90:['英勇'],101:['极彩'],102:['极彩'],105:['终言','奇迹'],119:['终言'],121:['终言'],122:['终言'],128:['终言'],134:['极彩'],150:['终言','奇迹'],151:['终言'],153:['终言'],154:['终言'],158:['终言'],178:['终言'],'character-kmo-001':['先制','吸血2'],'character-smm01':['英勇']}
def source_for(item):
 rs=item['matches']; code=item.get('catalog_id','') or ''
 # KMO original omits the lifesteal number; explicit Excel REC-013 states 2.
 if code=='character-kmo-001': return next(r for r in rs if r['values'][2]=='REC-013')
 if code:
  suffix=re.sub(r'^(character|spell|item|field)-','',code)
  exact=[r for r in rs if norm(str(r['values'][2])).lower()==norm(suffix).lower()]
  if exact:return exact[0]
 return rs[0]
def prepare():
 items=read(WORK/'matches.json'); groups={}; rows=[]
 for item in items:
  source=source_for(item); v=source['values']; unit=source['sheet'].startswith('CHARACTER')
  name=(str(v[5] or '').replace('/','')+'「'+v[6]+'」') if unit else v[5]
  key=int(re.search(r'image(\d+)',item['file'])[1]) if item['file'].startswith('image') else item['catalog_id']
  cid=item['existing'][0] if item['existing'] else str(key)
  # SMM-07 has a self ability absent on REI-026: preserve both printed editions.
  if key=='character-smm07': cid=key
  if norm(name) in groups and key!='character-smm07': cid=groups[norm(name)]
  groups[norm(name)]=cid
  existing=(ROOT/'cards'/f'{cid}.json').exists()
  primary=not existing and not any(x['id']==cid for x in rows)
  dest=f'recourse/数据库/{cid}{Path(item["file"]).suffix}' if primary else 'recourse/数据库/异画与重复/v0.11/'+item['file']
  rows.append({'id':cid,'key':key,'name':name,'file':item['file'],'sha256':item['sha256'],'destination':dest,'primary':primary,'existing':existing,'source':source})
 write(WORK/'import-plan.json',rows)
 print('images',len(rows),'new IDs',len(set(x['id'] for x in rows if not x['existing'])),'existing IDs',len(set(x['id'] for x in rows if x['existing'])))
def archive():
 for item in read(WORK/'import-plan.json'):
  src=(ROOT/'recourse/新增卡片'/item['file']).resolve(); dest=(ROOT/item['destination']).resolve()
  assert src.is_relative_to(ROOT) and dest.is_relative_to(ROOT)
  assert src.is_file() and hashlib.sha256(src.read_bytes()).hexdigest()==item['sha256'] and not dest.exists()
  dest.parent.mkdir(parents=True,exist_ok=True); shutil.move(str(src),str(dest))
  imp=Path(str(src)+'.import')
  if imp.exists():
   to=ROOT/'work/v011-backup/import-metadata'/imp.name; to.parent.mkdir(exist_ok=True); shutil.move(str(imp),str(to))
  assert hashlib.sha256(dest.read_bytes()).hexdigest()==item['sha256']
 print('Archived all 119 images unchanged.')
def define():
 rows=read(WORK/'import-plan.json'); done=set(); changes=[]; new=[]
 for item in rows:
  cid=item['id']
  if cid in done:continue
  done.add(cid); v=item['source']['values']; sheet=item['source']['sheet']; unit=sheet.startswith('CHARACTER'); spell=sheet.startswith('SPELL')
  old=read(ROOT/'cards'/f'{cid}.json') if item['existing'] else {}
  cost={}; colors=[]; variable=''; factor=1
  offset=8 if unit else 6
  for color,value in zip(['红','蓝','绿','黄','黑'],v[offset:offset+5]):
   if value is None or value=='/':continue
   colors.append(color)
   if 'X' in str(value).upper():variable=color;factor=int(str(value).upper().replace('X','') or '1')
   elif int(value)>0: cost[color]=int(value)
  ability=str((v[17] if unit else v[16] if spell else v[12]) or '').strip()
  leader=str(v[18] or '').strip() if unit else ''
  full=ability+('\n自机能力：'+leader if leader else '')
  kind='自机' if unit and leader else '单位' if unit else '符卡' if spell else '道具' if sheet.startswith('ITEM') else '结界'
  keys=KEYS.get(item['key'],[]); bindings=old.get('能力绑定',[]).copy()
  if not old:
   for k in keys: bindings.append({'实现':'roster','名称':leader if k in ['koishi_evasion','remilia_aura','satori_discard','alice_recycle','cirno_return','kanako_blast','kaguya_end','yuuka_ramp','suika_counter','suwako_haste','komachi_coins','shinmy_counter','sanae_search'] else ability,'参数':{'效果':k}})
  # Preserve old precon behavior while adding this edition's complete leader text.
  if item['key']=='character-smm07':
   bindings.insert(0,{'实现':'precon','名称':ability,'参数':{'效果':'sanae_end'}})
  keywords=old.get('关键词',[]) if old else WORDS.get(item['key'],[]).copy()
  if not old and ability.startswith('结晶'):keywords.append('结晶')
  if item['key']==43:keywords.append('吸血2')
  d={'格式版本':1,'卡牌ID':cid,'名称':item['name'],'类别':kind,'颜色':colors,'费用':cost,'图片':old.get('图片','res://'+item['destination']),'完整说明':full or '无能力。','能力文字':full,'来源':f"{item['source']['book']} · {sheet}!行{item['source']['row']} · {v[2]}（本批以Excel为准）",'Excel来源':{'文件':item['source']['book'],'工作表':sheet,'行':item['source']['row'],'编号':v[2]},'构筑资格':{'允许常规构筑':True},'关键词':keywords,'能力绑定':bindings,'高速':bool(spell and '高速' in str(v[12])),'角色约束':str(v[13] or '') if spell else '', '符卡类型':str(v[12] or '') if spell else '', '计时':int(v[15]) if spell and isinstance(v[15],(int,float)) else 0}
  if unit:d.update({'角色名':v[6],'称号':str(v[5] or '').replace('/',''),'种族':re.split('[·・]',v[7] or ''),'攻击力':int(v[14]),'血量':int(v[15]),'灵力':int(v[16])})
  if unit and re.search(r'(^|。)你可以在任意时机使用该牌',ability):d['高速']=True
  if variable:d['可变费用']=variable;d['X费用倍率']=factor
  if old:
   for key in ['别名','衍生物']:
    if key in old:d[key]=old[key]
   diffs={key:{'原':old.get(key),'Excel':d.get(key)} for key in ['类别','颜色','费用','攻击力','血量','灵力','完整说明'] if old.get(key)!=d.get(key)}
   if diffs:changes.append({'id':cid,'name':d['名称'],'差异':diffs})
  else:new.append(cid)
  write(ROOT/'cards'/f'{cid}.json',d)
 write(WORK/'excel-differences.json',changes);write(WORK/'new-ids.json',new)
 print('Written',len(done),'definitions;',len(new),'new;',len(changes),'existing records updated from Excel')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','archive','define']);args=p.parse_args();globals()[args.action]()
