from pathlib import Path
import json,re,hashlib,openpyxl
R=Path.cwd();O=R/'work/v013';B=R/'work/v013-backup'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
plan=read(O/'import-plan.json');new=read(O/'new-ids.json');cards={p.stem:read(p) for p in (R/'cards').glob('*.json')};errors=[]
assert len(plan)==395 and len(new)==217 and len(cards)==486
for i in plan:
 if not (R/i['destination']).is_file() or sha(R/i['destination'])!=i['sha256']:errors.append('image mismatch '+i['file'])
assert not list((R/'recourse/新增卡片').glob('*.jpg'))
for path in ['saves/decks.json','data/test_precons.json']:
 assert sha(R/path)==sha(B/path),path
assert sha(R/'recourse/数据库/token-ucs-099.jpg')==sha(B/'old-halfghost.jpg')
books={name:openpyxl.load_workbook(R/'recourse'/name,read_only=True,data_only=True) for name in set(i['source']['book'] for i in plan)}
rows={}
for name,b in books.items():
 for s in b:
  if s.title.startswith(('CHARACTER','SPELL','ITEM','FIELD','TOKEN')):
   for n,v in enumerate(s.values,1):rows[(name,s.title,n)]=v
for cid,i in {i['id']:i for i in plan}.items():
 src=i['source'];v=rows[(src['book'],src['sheet'],src['row'])];c=cards[cid];unit=src['sheet'].startswith('CHARACTER');spell=src['sheet'].startswith('SPELL');token=src['sheet'].startswith('TOKEN')
 ability=str(v[10 if token else 17 if unit else 16 if spell else 12] or '').strip();leader=str(v[18] or '').strip() if unit else '';expected=ability+('\n自机能力：'+leader if leader else '')
 if c['能力文字']!=expected:errors.append('Excel text '+cid)
 if unit:
  for k,col in [('攻击力',14),('血量',15),('灵力',16)]:
   if c[k]!=int(v[col]):errors.append('Excel stat '+cid+' '+k)
 if not token:
  cost={};colors=[]
  for color,value in zip(['红','蓝','绿','黄','黑'],v[8:13] if unit else v[6:11]):
   if value is None or str(value).strip() in ['/','']:continue
   colors.append(color)
   if 'X' not in str(value).upper() and int(value)>0:cost[color]=int(value)
  if c['费用']!=cost:errors.append('Excel cost '+cid)
  if c['颜色']!=colors:errors.append('Excel colors '+cid)
 if spell and c['角色约束']!=str(v[13] or ''):errors.append('Excel role '+cid)
for b in books.values():b.close()
result={'images':len(plan),'new_definitions':len(new),'total_definitions':len(cards),'constructible':sum(c['构筑资格']['允许常规构筑'] for c in cards.values()),'tokens':sum(c.get('衍生物',False) for c in cards.values()),'dream_units':2,'excel_records_checked':len(set(i['id'] for i in plan)),'archived_reprints':sum(not i['primary'] for i in plan),'image_hashes_verified':len(plan),'saved_decks_unchanged':True,'precons_unchanged':True,'halfghost_unchanged':True,'errors':errors}
(O/'final-data-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps(result,ensure_ascii=False,indent=2));assert not errors
