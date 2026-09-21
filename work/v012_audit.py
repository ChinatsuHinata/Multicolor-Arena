from pathlib import Path
import json,re,hashlib,shutil,openpyxl
R=Path(__file__).resolve().parents[1]; O=R/'work/v012';O.mkdir(exist_ok=True)
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
write=lambda p,x:p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
norm=lambda x:re.sub(r'[\s「」【】『』·・/（）()\[\]"“”\-—－_]', '',str(x or '')).lower()
queue=R/'recourse/新增卡片';B=R/'work/v012-backup'
if not B.exists():
 B.mkdir()
 for folder in ['scripts','cards','data','docs','saves','tests']:shutil.copytree(R/folder,B/folder)
 shutil.copytree(queue,B/'新增卡片')
 shutil.copy2(R/'recourse/数据库/token-ucs-099.jpg',B/'old-halfghost.jpg')
 shutil.copy2(R/'开发者日志.md',B/'开发者日志.md')
rows=[]
for path in sorted((R/'recourse').glob('*.xlsx')):
 if path.name.startswith('~$'):continue
 b=openpyxl.load_workbook(path,read_only=True,data_only=True)
 for s in b:
  for i,v in enumerate(s.values,1):
   if any(x is not None for x in v):rows.append({'book':path.name,'sheet':s.title,'row':i,'values':list(v)})
 b.close()
write(O/'excel-rows.json',rows)
regular=[r for r in rows if r['sheet'].startswith(('CHARACTER','SPELL','ITEM','FIELD','TOKEN')) and len(r['values'])>6 and r['values'][2]]
def name(r):
 v=r['values'];return str(v[5] or '').replace('/','')+'「'+str(v[6] or '')+'」' if r['sheet'].startswith('CHARACTER') else str(v[4] if r['sheet'].startswith('TOKEN') else v[5] or '')
cards=[read(p) for p in (R/'cards').glob('*.json')];plan=[]
for p in sorted(queue.glob('*.jpg')):
 code=p.stem.split('__')[-1] if '__' in p.stem else ''
 label=p.stem.split('__')[0];number=re.sub(r'^(character|spell|field|item|token)-','',code)
 exact=[r for r in regular if code and norm(r['values'][2])==norm(number)]
 prefix={'character':'CHARACTER','spell':'SPELL','item':'ITEM','field':'FIELD','token':'TOKEN'}.get(code.split('-')[0],'')
 exact=[r for r in exact if r['sheet'].startswith(prefix)]
 matches=exact or [r for r in regular if norm(name(r))==norm(label)]
 if label=='半灵衍生物':matches=[r for r in regular if r['sheet'].startswith('TOKEN') and norm(r['values'][2])=='ucs099']
 existing=[c for c in cards if norm(c['名称'])==norm(label)]
 entry={'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'catalog_id':code,'matches':matches,'existing':[c['卡牌ID'] for c in existing]};plan.append(entry)
 print(p.name,'MATCH',[(r['sheet'],r['row'],r['values'][2]) for r in matches],'EXIST',entry['existing'])
 if matches:
  r=matches[0];v=r['values'];print(' TEXT',v[17:19] if r['sheet'].startswith('CHARACTER') else v[16] if r['sheet'].startswith('SPELL') else v[10] if r['sheet'].startswith('TOKEN') else v[12])
 else:
  print(' FUZZY',[(r['sheet'],r['row'],r['values']) for r in rows if label in str(r['values'])])
write(O/'matches.json',plan)
print('COUNT',len(plan),'UNMATCHED',sum(not i['matches'] for i in plan))
