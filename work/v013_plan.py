from pathlib import Path
import json,re,hashlib
R=Path(__file__).resolve().parents[1];O=R/'work/v013'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
write=lambda p,x:p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
norm=lambda s:re.sub(r'[\s「」【】『』·・/（）()\[\]"“”\-—－_：:。，,;；.]','',str(s or '')).lower()
rows=read(O/'excel-rows.json');rows=[r for r in rows if r['sheet'].startswith(('CHARACTER','SPELL','ITEM','FIELD','TOKEN')) and len(r['values'])>6 and r['values'][2]]
manifest=read(R/'recourse/新增卡片/download_manifest.json')['cards'];byfile={v['file']:v['id'] for v in manifest.values()}
catalog={v['id']:v for v in read(R/'recourse/新增卡片/cards_index.json')}
cards={p.stem:read(p) for p in (R/'cards').glob('*.json')}
groups={};plan=[];new=[];unmatched=[]
def fullname(r):
 v=r['values'];return str(v[5] or '').replace('/','')+'「'+str(v[6] or '')+'」' if r['sheet'].startswith('CHARACTER') else str(v[4] if r['sheet'].startswith('TOKEN') else v[5] or '')
def body(r):
 v=r['values'];s=r['sheet']
 if s.startswith('CHARACTER'):
  a=str(v[17] or '').strip();b=str(v[18] or '').strip();return a+('\n自机能力：'+b if b else '')
 return str((v[10] if s.startswith('TOKEN') else v[16] if s.startswith('SPELL') else v[12]) or '').strip()
for i in read(O/'matches.json'):
 code=i['catalog_id'] or byfile.get(i['file'],'');prefix=code.split('-')[0];num=code.removeprefix(prefix+'-')
 kind={'character':'CHARACTER','spell':'SPELL','item':'ITEM','field':'FIELD','token':'TOKEN'}.get(prefix,'')
 exact=[r for r in rows if norm(r['values'][2])==norm(num) and r['sheet'].startswith(kind)]
 matched=exact or i['matches']
 if not matched:unmatched.append(i['file']);continue
 source=matched[0];name=fullname(source);text=body(source)
 old=[c for c in cards.values() if norm(c['名称'])==norm(name)]
 # A spelling-only reprint can share an ID when character/title and text agree.
 if not old and prefix=='character':
  v=source['values'];old=[c for c in cards.values() if norm(c.get('角色名',''))==norm(v[6]) and norm(c.get('称号',''))==norm(v[5])]
 cid=old[0]['卡牌ID'] if old else code
 cid=groups.setdefault(norm(name),cid)
 if not cid:raise ValueError(i['file'])
 existing=cid in cards;primary=not existing and not any(p['id']==cid for p in plan)
 reuse=[]
 if primary:
  reuse=[k for k,c in cards.items() if text and norm(c['能力文字'])==norm(text)]
  new.append({'id':cid,'name':name,'source':source,'text':text,'reuse':reuse,'catalog':catalog.get(code,{})})
 destination='recourse/数据库/'+cid+'.jpg' if primary else 'recourse/数据库/异画与重复/v0.13/'+i['file']
 plan.append({**i,'id':cid,'catalog_id':code,'name':name,'source':source,'text':text,'existing':existing,'primary':primary,'destination':destination,'reuse':reuse,'catalog':catalog.get(code,{})})
write(O/'import-plan.json',plan);write(O/'new-definitions.json',new)
write(O/'unmatched.json',unmatched)
out=[]
for n in new:
 v=n['source']['values'];s=n['source']['sheet'];out.append(f"{n['id']} | {n['name']} | {'REUSE '+','.join(n['reuse']) if n['reuse'] else 'NEW'}\n{n['text']}\n")
(O/'new-effects.txt').write_text('\n'.join(out),encoding='utf-8')
print('Images',len(plan),'new IDs',len(new),'reuse exact text',sum(bool(x['reuse']) for x in new),'unmatched',unmatched)
print('Kinds', {k:sum(x['source']['sheet'].startswith(k) for x in new) for k in ['CHARACTER','SPELL','ITEM','FIELD','TOKEN']})
print('Empty text',[n['id'] for n in new if not n['text']])
print('Nonnumeric units',[(n['id'],n['source']['values'][14:17]) for n in new if n['source']['sheet'].startswith('CHARACTER') and any(not isinstance(v,(int,float)) for v in n['source']['values'][14:17])])
