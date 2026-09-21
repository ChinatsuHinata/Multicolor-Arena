from pathlib import Path
import json,re,hashlib,shutil
R=Path(__file__).resolve().parents[1];O=R/'work/v011'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
norm=lambda s:re.sub(r'[\s「」【】『』·・/（）()\[\]"“”\-—－_]','',str(s or ''))
rows=[r for r in read(O/'excel-rows.json') if r['book']!='极彩新牌表.xlsx' and r['sheet'].startswith(('CHARACTER','SPELL','ITEM','FIELD','TOKEN')) and len(r['values'])>6 and r['values'][2]]
def name(r):
 v=r['values'];return str(v[5] or '')+'「'+str(v[6] or '')+'」' if r['sheet'].startswith(('CHARACTER','TOKEN')) else str(v[5] or '')
cards=[read(p) for p in (R/'cards').glob('*.json')]
plan=[]
for path in sorted((R/'recourse/新增卡片').glob('*.jpg')):
 code=path.stem.split('__')[-1];number=re.sub(r'^(character|spell|field|item|token)-','',code)
 exact=[r for r in rows if norm(r['values'][2]).lower()==norm(number).lower()]
 label=path.stem.split('__')[0];matches=exact or [r for r in rows if norm(name(r))==norm(label)]
 if code.startswith('token-'):matches=[r for r in matches if r['sheet'].startswith('TOKEN')] or matches
 existing=[c for c in cards if norm(c['名称'])==norm(label)]
 entry={'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'catalog_id':code,'matches':matches,'existing':[c['卡牌ID'] for c in existing]}
 plan.append(entry)
 print(path.name,'MATCH',[(r['sheet'],r['row'],r['values'][2]) for r in matches],'EXISTING',entry['existing'])
 if matches:
  r=matches[0];v=r['values'];print(' TEXT',str(v[17:19] if r['sheet'].startswith('CHARACTER') else v[16] if r['sheet'].startswith('SPELL') else v[12]))
assert not (O/'supplement-matches.json').exists(),'Already snapshotted'
(O/'supplement-matches.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2),encoding='utf-8')
dest=R/'work/v011-backup/supplement-input';dest.mkdir()
for item in plan:shutil.copy2(R/'recourse/新增卡片'/item['file'],dest/item['file'])
print('Supplement',len(plan),'unmatched',sum(not i['matches'] for i in plan))
