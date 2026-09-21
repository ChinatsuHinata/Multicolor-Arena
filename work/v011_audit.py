from pathlib import Path
import json,hashlib,re,collections
R=Path(__file__).resolve().parents[1];O=R/'work/v011'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
plans=read(O/'import-plan.json')+read(O/'supplement/import-plan.json')
for i in plans:
 path=(R/i['destination']).resolve()
 assert path.is_relative_to(R) and path.is_file() and sha(path)==i['sha256'],i['file']
 assert not (R/'recourse/新增卡片'/i['file']).exists(),i['file']
ids=json.loads(re.search(r'const IDS=(\[.*\])',(R/'scripts/card_database.gd').read_text(encoding='utf-8'))[1])
assert len(ids)==len(set(ids))==251
latest={i['id']:i for i in plans}
for cid in latest:
 d=read(R/'cards'/f'{cid}.json')
 i=next(i for i in plans if i['id']==cid and i['source']['row']==d['Excel来源']['行'] and i['source']['sheet']==d['Excel来源']['工作表'])
 v=i['source']['values'];sheet=i['source']['sheet']
 if sheet.startswith('TOKEN'):ability=v[10]
 elif sheet.startswith('CHARACTER'):
  ability=str(v[17] or '').strip();leader=str(v[18] or '').strip()
  if leader:ability+='\n自机能力：'+leader
 else:ability=str((v[16] if sheet.startswith('SPELL') else v[12]) or '').strip()
 assert d['能力文字']==ability,(cid,d['能力文字'],ability)
 assert d['Excel来源']['行']==i['source']['row'],cid
 assert (R/d['图片'].removeprefix('res://')).exists(),cid
for f in (R/'work/v011-backup/saves').glob('*'):
 assert sha(f)==sha(R/'saves'/f.name),f.name
assert sha(R/'data/test_precons.json')==sha(R/'work/v011-backup/data/test_precons.json')
cards=[read(R/'cards'/f'{cid}.json') for cid in ids]
new=read(O/'new-ids.json')+read(O/'supplement/new-ids.json')
unprocessed=[p.name for p in (R/'recourse/新增卡片').iterdir() if p.suffix.lower() in ['.jpg','.png','.jpeg','.webp']]
report={'已归档卡图':len(plans),'新增定义':len(new),'当前定义':len(ids),'可构筑':sum(c['构筑资格']['允许常规构筑'] for c in cards),'衍生物':sum(c.get('衍生物',False) for c in cards),'核对Excel文本':len(latest),'未处理新卡图':unprocessed,'原卡组与预组逐字节未变':True,'SHA256逐图核对':True}
(O/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
