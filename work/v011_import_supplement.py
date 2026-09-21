from pathlib import Path
import json,hashlib,shutil,importlib.util,re
R=Path(__file__).resolve().parents[1];O=R/'work/v011/supplement';O.mkdir(exist_ok=True)
spec=importlib.util.spec_from_file_location('importer',R/'tools/import_excel_v011.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.WORK=O
items=m.read(R/'work/v011/supplement-matches.json');regular=[i for i in items if not i['catalog_id'].startswith('token-')]
keys={'spell-ucs-011':['coin_anthem'],'spell-ucs-008':['all_counters'],'item-ucs-012':['backpack'],'spell-ucs-029':['kill_small'],'spell-ucs-026':['palette_wipe'],'character-ucs-032':['sakuya_timer'],'character-ucs-072':['kanako_cast','kanako_ten'],'spell-ucs-019':['free_anthem'],'character-ucs-071':['kogasa_scare','kogasa_boost'],'character-ucs-038':['orin_discard'],'character-ucs-069':['miko_divide','miko_discount'],'character-ucs-048':['france_doll'],'character-ucs-042':['parsee_catchup'],'spell-ucs-014':['reset_four'],'spell-ucs-027':['color_damage']}
m.KEYS.update(keys);m.WORDS.update({'spell-ucs-008':['奇迹'],'spell-ucs-026':['终言'],'spell-ucs-019':['终言'],'character-ucs-032':['追击'],'character-ucs-072':['威吓'],'character-ucs-071':['追击']})
m.write(O/'matches.json',regular);m.prepare()
plan=m.read(O/'import-plan.json');tokens=[i for i in items if i['catalog_id'].startswith('token-')]
for i in tokens:plan.append({**i,'id':i['catalog_id'],'destination':'recourse/数据库/'+i['catalog_id']+'.jpg','source':i['matches'][0],'primary':True,'existing':False,'name':'半灵衍生物'})
m.write(O/'import-plan.json',plan)
backup=R/'work/v011-backup/supplement-definitions';backup.mkdir(exist_ok=True)
for i in plan:
 src=(R/'recourse/新增卡片'/i['file']).resolve();dst=(R/i['destination']).resolve()
 assert src.is_relative_to(R) and dst.is_relative_to(R) and src.is_file() and not dst.exists()
 assert hashlib.sha256(src.read_bytes()).hexdigest()==i['sha256'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.move(src,dst)
 prior=R/'cards'/f'{i["id"]}.json'
 if prior.exists() and not (backup/prior.name).exists():shutil.copy2(prior,backup/prior.name)
 meta=Path(str(src)+'.import')
 if meta.exists():shutil.move(meta,backup/meta.name)
# Reuse scalar Excel transcription for all normal cards; token sheet has its own layout.
m.write(O/'import-plan.json',[i for i in plan if not i['id'].startswith('token-')]);m.define();m.write(O/'import-plan.json',plan)
new=m.read(O/'new-ids.json')
for i in tokens:
 cid=i['catalog_id'];row=i['matches'][0];v=row['values']
 d={'格式版本':1,'卡牌ID':cid,'名称':'半灵','类别':'单位','角色名':'半灵','称号':'','种族':['半灵'],'攻击力':int(v[7]),'血量':int(v[8]),'灵力':int(v[9]),'颜色':['黑','绿'],'费用':{},'图片':'res://recourse/数据库/'+cid+'.jpg','完整说明':v[10],'能力文字':v[10],'关键词':['先制','疾行'],'能力绑定':[],'构筑资格':{'允许常规构筑':False},'衍生物':True,'来源':row['book']+' · '+row['sheet']+'!行'+str(row['row'])+'；颜色来自魂魄妖梦创造半灵的规则','Excel来源':{'文件':row['book'],'工作表':row['sheet'],'行':row['row'],'编号':v[2]}}
 m.write(R/'cards'/f'{cid}.json',d);new.append(cid)
m.write(O/'new-ids.json',new)
# Explicit annotation split for ordinary/self rules in this supplemental edition.
for cid,ks in keys.items():
 d=m.read(R/'cards'/f'{cid}.json');row=next(i['source'] for i in plan if i['id']==cid);v=row['values']
 for a in d['能力绑定']:
  if a.get('参数',{}).get('效果') in ['kanako_ten','kogasa_boost','miko_discount']:a['名称']=str(v[18] or '').strip()
 m.write(R/'cards'/f'{cid}.json',d)
p=R/'scripts/card_database.gd';s=p.read_text(encoding='utf-8');ids=json.loads(re.search(r'const IDS=(\[.*\])',s)[1]);ids+=new
effects=sorted({a['参数']['效果'] for f in (R/'cards').glob('*.json') for a in m.read(f)['能力绑定'] if a['实现']=='roster'})
s=re.sub(r'const IDS=\[.*\]','const IDS='+json.dumps(ids,ensure_ascii=False),s);s=re.sub(r'const ROSTER_EFFECTS=\[.*\]','const ROSTER_EFFECTS='+json.dumps(effects,ensure_ascii=False),s);p.write_text(s,encoding='utf-8')
print('Supplement archived:',len(plan),'images; new definitions:',len(new),'total:',len(ids))
