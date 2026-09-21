from pathlib import Path
import re,json
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'work/v011'
read=lambda path: json.loads(path.read_text(encoding='utf-8-sig'))
rows=read(OUT/'excel-rows.json'); drawings=read(OUT/'drawings.json')
catalog={c['id']:c for c in read(ROOT/'recourse/爬虫/cards_index.json')}
manifest=read(ROOT/'recourse/爬虫/download_manifest.json')['cards']
by_file={v['file']:k for k,v in manifest.items()}
cards=[read(p) for p in (ROOT/'cards').glob('*.json')]
def norm(s): return re.sub(r'[\s「」【】『』·・/（）()\[\]"“”\-—－_]', '',s or '').replace('之城','ノ城').replace('封兽鵺','封兽ぬえ')
def name(r):
 v=r['values']; s=r['sheet']
 return str(v[5] or '')+'「'+str(v[6] or '')+'」' if s.startswith('CHARACTER') else str(v[5] or '')
source=[r for r in rows if r['book']!='极彩新牌表.xlsx' and r['row']>1 and r['sheet'].startswith(('CHARACTER','SPELL','ITEM','FIELD')) and len(r['values'])>6 and r['values'][2]]
entries=[]
for f in read(OUT/'queue.json'):
 refs=[d for d in drawings if d['file']==f['file'] and d['book']=='极彩新牌表.xlsx']
 titled=[r['values'] for r in rows if r['book']=='极彩新牌表.xlsx' and any(r['row']==d['row'] for d in refs)]
 sid=by_file.get(f['file']); c=catalog.get(sid,{})
 full=(str(titled[0][2] or '')+'「'+str(titled[0][3] or '')+'」') if titled else ((c.get('title','')+'「'+c['name']+'」') if c.get('card_type')=='character' else c.get('name',''))
 matches=[r for r in source if norm(name(r))==norm(full)]
 existing=[d for d in cards if norm(d['名称'])==norm(full)]
 entry={**f,'name':full,'catalog_id':sid,'existing':[d['卡牌ID'] for d in existing],'matches':matches}
 entries.append(entry)
 print(f['file'],full,'EXISTING',entry['existing'],'MATCH',[(r['sheet'],r['row'],r['values'][2]) for r in matches])
 if matches:
  r=matches[0]; v=r['values']; print('  ',(str(v[17] or '')+' 自：'+str(v[18] or '')) if r['sheet'].startswith('CHARACTER') else str(v[16] or '') if r['sheet'].startswith('SPELL') else str(v[12] or ''))
(OUT/'matches.json').write_text(json.dumps(entries,ensure_ascii=False,indent=2),encoding='utf-8')
print('unmatched',sum(not x['matches'] for x in entries),'ambiguous',sum(len(x['matches'])>1 for x in entries),'existing',sum(bool(x['existing']) for x in entries))
