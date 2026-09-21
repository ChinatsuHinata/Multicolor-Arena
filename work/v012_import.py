from pathlib import Path
import json,re,shutil,hashlib,importlib.util
R=Path(__file__).resolve().parents[1];O=R/'work/v012'
spec=importlib.util.spec_from_file_location('base',R/'tools/import_excel_v011.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.WORK=O
keys={'spell-lof-025':['peach_modes'],'spell-fdn-066':['fairy_rewrite'],'spell-htk-018':['night_sakura'],'spell-fdn-069':['blue_flower'],'character-lof-003':['sanae_counters','sanae_miracle'],'character-lof-017':['larva_sacrifice'],'spell-lof-007':['icicle_tide'],'spell-htk-003':['emotions'],'spell-fdf-083':['angry_mask'],'character-fdn-068':['lily_color'],'character-lof-001':['courage_ping','courage_die'],'character-htk-001':['kokoro_mood','kokoro_self'],'character-fdn-067':['toyohime_lock'],'character-htk-002':['tokiko_copy','tokiko_discount'],'character-ucs-007':['sannyo_prevent']}
m.KEYS.update(keys);m.WORDS.update({'character-lof-017':['结晶'],'spell-fdf-083':['支援'],'character-fdn-068':['威吓'],'character-lof-001':['英勇'],'character-fdn-067':['追击','退治','高速移动'],'character-ucs-007':['追击']})
items=m.read(O/'matches.json');groups={};plan=[]
for i in items:
 r=i['matches'][0];v=r['values'];token=r['sheet'].startswith('TOKEN');label=i['file'].split('__')[0].removesuffix('.jpg')
 code=i['catalog_id'] or ('token-' if token else 'character-' if r['sheet'].startswith('CHARACTER') else 'spell-')+v[2].lower()
 cid=i['existing'][0] if i['existing'] else code
 if label=='半灵衍生物':cid='token-ucs-099'
 cid=groups.setdefault(m.norm(label),cid)
 existing=(R/'cards'/f'{cid}.json').exists();primary=not existing and not any(p['id']==cid for p in plan)
 replace=cid=='token-ucs-099'
 dest='recourse/数据库/'+cid+'.jpg' if primary or replace else 'recourse/数据库/异画与重复/v0.12/'+i['file']
 name=(str(v[5] or '').replace('/','')+'「'+v[6]+'」') if r['sheet'].startswith('CHARACTER') else v[4] if token else v[5]
 plan.append({**i,'id':cid,'key':cid,'name':name,'source':r,'existing':existing,'primary':primary,'replace':replace,'token':token,'destination':dest})
m.write(O/'import-plan.json',plan)
for i in plan:
 src=(R/'recourse/新增卡片'/i['file']).resolve();dst=(R/i['destination']).resolve()
 assert src.is_relative_to(R) and dst.is_relative_to(R) and src.is_file()
 assert hashlib.sha256(src.read_bytes()).hexdigest()==i['sha256']
 assert not dst.exists() or i['replace']
 dst.parent.mkdir(parents=True,exist_ok=True)
 if i['replace']:dst.unlink() # old art is preserved in v012-backup/old-halfghost.jpg
 shutil.move(src,dst)
 meta=Path(str(src)+'.import')
 if meta.exists():shutil.move(meta,R/'work/v012-backup/新增卡片'/meta.name)
m.write(O/'import-plan.json',[i for i in plan if not i['token']]);m.define();m.write(O/'import-plan.json',plan)
new=m.read(O/'new-ids.json')
for i in plan:
 if not i['token']:
  d=m.read(R/'cards'/f'{i["id"]}.json')
  if '高速移动' in d['关键词']:d['高速']=True
  if i['id'] in keys:
   for a in d['能力绑定']:
    if a['参数']['效果'] in ['sanae_miracle','courage_die','kokoro_self','tokiko_discount']:a['名称']=str(i['source']['values'][18] or '').strip()
  m.write(R/'cards'/f'{i["id"]}.json',d)
 elif i['id']!='token-ucs-099':
  v=i['source']['values'];k={'HTK-031':'mask_joy','HTK-032':'mask_anger','HTK-033':'mask_sorrow'}[v[2]]
  d={'格式版本':1,'卡牌ID':i['id'],'名称':v[4],'类别':'道具','颜色':['黑'],'费用':{},'图片':'res://'+i['destination'],'完整说明':v[10],'能力文字':v[10],'来源':i['source']['book']+' · '+i['source']['sheet']+'!行'+str(i['source']['row']),'Excel来源':{'文件':i['source']['book'],'工作表':i['source']['sheet'],'行':i['source']['row'],'编号':v[2]},'构筑资格':{'允许常规构筑':False},'衍生物':True,'关键词':[],'能力绑定':[{'实现':'roster','名称':v[10],'参数':{'效果':k}}]}
  d['颜色']=[{'HTK-031':'黄','HTK-032':'黑','HTK-033':'蓝'}[v[2]]]
  d['来源']+='；Excel衍生物页未列颜色，颜色据提供卡图括注'
  m.write(R/'cards'/f'{i["id"]}.json',d);new.append(i['id'])
m.write(O/'new-ids.json',new)
p=R/'scripts/card_database.gd';s=p.read_text(encoding='utf-8');ids=json.loads(re.search(r'const IDS=(\[.*\])',s)[1]);ids+=new
effects=sorted({a['参数']['效果'] for p in (R/'cards').glob('*.json') for a in m.read(p)['能力绑定'] if a['实现']=='roster'})
s=re.sub(r'const IDS=\[.*\]','const IDS='+json.dumps(ids,ensure_ascii=False),s);s=re.sub(r'const ROSTER_EFFECTS=\[.*\]','const ROSTER_EFFECTS='+json.dumps(effects,ensure_ascii=False),s);p.write_text(s,encoding='utf-8')
print('Archived',len(plan),'new',len(new),'total',len(ids));print(new)
print(json.dumps(m.read(O/'excel-differences.json'),ensure_ascii=False,indent=2))
