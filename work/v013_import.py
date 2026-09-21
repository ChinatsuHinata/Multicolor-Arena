from pathlib import Path
import json,re,shutil,hashlib
R=Path.cwd(); O=R/'work/v013'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
plan=read(O/'import-plan.json'); done=set(); new=[]; diff=[]
# Resolve both ends before moving. Backup contains every unmodified source.
for i in plan:
 src=(R/'recourse/新增卡片'/i['file']).resolve(); dst=(R/i['destination']).resolve()
 assert src.is_relative_to(R) and dst.is_relative_to(R)
 if not src.exists():
  assert dst.is_file() and hashlib.sha256(dst.read_bytes()).hexdigest()==i['sha256'];continue
 assert hashlib.sha256(src.read_bytes()).hexdigest()==i['sha256'] and not dst.exists()
 backup=R/'work/v013-backup/新增卡片'/i['file']
 assert backup.exists() and hashlib.sha256(backup.read_bytes()).hexdigest()==i['sha256']
 dst.parent.mkdir(parents=True,exist_ok=True);shutil.move(src,dst)
 meta=Path(str(src)+'.import')
 if meta.exists():
  to=R/'work/v013-backup/import-metadata'/meta.name;to.parent.mkdir(exist_ok=True);shutil.move(meta,to)
for i in plan:
 cid=i['id']
 if cid in done:continue
 done.add(cid);p=R/'cards'/f'{cid}.json';old=read(p) if p.exists() else {};v=i['source']['values'];sheet=i['source']['sheet'];unit=sheet.startswith('CHARACTER');spell=sheet.startswith('SPELL');token=sheet.startswith('TOKEN')
 ability=str(v[10 if token else 17 if unit else 16 if spell else 12] or '').strip();leader=str(v[18] or '').strip() if unit else ''
 full=ability+('\n自机能力：'+leader if leader else '')
 cost={};colors=[];variable='';factor=1
 if not token:
  for color,val in zip(['红','蓝','绿','黄','黑'],v[8:13] if unit else v[6:11]):
   if val is None or str(val).strip() in ['/','']:continue
   colors.append(color)
   if 'X' in str(val).upper():variable=color;factor=int(str(val).upper().replace('X','') or '1')
   elif int(val)>0:cost[color]=int(val)
 else:colors={'token-fdf-127':['黄'],'token-fdf-129':['红','蓝','绿'],'token-fdn-082':['黑']}.get(cid,old.get('颜色',[]))
 kind=('自机' if leader else '单位') if unit else '符卡' if spell else str(v[5]).replace('普通','') if token else '道具' if sheet.startswith('ITEM') else '结界'
 name=str(i['name']).strip().replace('「「','「').replace('」」','」');keywords=old.get('关键词',[]).copy()
 if not old:
  head=re.split('[。\n]',ability)[0]
  # Only printed keywords in the opening clause, never keywords granted to others.
  keywords=re.findall(r'(?:^|[，,、\s])((?:吸血|防避)\d+|疾行|先制|歼灭|英勇|结晶|威吓|高速移动|退治|追击|奇迹|极彩|终言|支援)(?=[，,。\.\s]|$)',head)
  if '不计入战场格' in ability and ability.startswith('该单位不计入战场格'):keywords.append('不占战场格')
  if spell:
   keywords+= [k for k in ['支援','终言','限制级符卡','极彩','奇迹'] if ability.startswith(k) or re.match(r'^(?:限制级符卡[，,]\s*|计时\w+[，,]\s*)'+k,ability)]
  keywords=list(dict.fromkeys(keywords))
 bindings=old.get('能力绑定',[])
 if not old:
  bindings=[]
  if ability:bindings.append({'实现':'roster','名称':ability,'参数':{'效果':cid}})
  if leader:bindings.append({'实现':'roster','名称':leader,'参数':{'效果':cid+':self'}})
  if cid=='character-ucs-065':bindings=[{'实现':'roster','名称':'弃一张牌：本回合中交换攻击力与'+s,'参数':{'效果':cid+':'+k}} for k,s in [('health','血量'),('spirit','灵力')]]
  new.append(cid)
 d={**old,'格式版本':1,'卡牌ID':cid,'名称':name,'类别':kind,'颜色':colors,'费用':cost,'图片':old.get('图片','res://'+i['destination']),'完整说明':full or '无能力。','能力文字':full,'来源':f"{i['source']['book']} · {sheet}!行{i['source']['row']} · {v[2]}（以Excel为准）",'Excel来源':{'文件':i['source']['book'],'工作表':sheet,'行':i['source']['row'],'编号':v[2]},'构筑资格':{'允许常规构筑':not token and not ability.startswith('梦违')},'关键词':keywords,'能力绑定':bindings,'高速':bool(spell and '高速' in str(v[12])) or '高速移动' in keywords,'角色约束':str(v[13] or '') if spell else '', '符卡类型':str(v[12] or '') if spell else '', '计时':int(v[15]) if spell and isinstance(v[15],(int,float)) else 0}
 if unit:d.update({'角色名':str(v[6]).strip('「」'),'称号':str(v[5] or '').replace('/','').strip(),'种族':re.split('[·・]',v[7] or ''),'攻击力':int(v[14]),'血量':int(v[15]),'灵力':int(v[16])})
 if token:
  d['衍生物']=True
  if kind=='单位':d.update({'角色名':v[4],'称号':'','种族':re.split('[·・]',v[6] or ''),'攻击力':int(v[7]),'血量':int(v[8]),'灵力':int(v[9])})
 if variable:d['可变费用']=variable;d['X费用倍率']=factor
 if old:
  changes={k:{'原':old.get(k),'Excel':d.get(k)} for k in ['名称','类别','颜色','费用','攻击力','血量','灵力','完整说明'] if old.get(k)!=d.get(k)}
  if changes:diff.append({'id':cid,'差异':changes})
 write(p,d)
write(O/'new-ids.json',new);write(O/'excel-differences.json',diff)
p=R/'scripts/card_database.gd';s=p.read_text(encoding='utf-8');ids=json.loads(re.search(r'const IDS=(\[.*\])',s)[1]);ids+= [x for x in new if x not in ids]
effects=sorted({a['参数']['效果'] for p in (R/'cards').glob('*.json') for a in read(p)['能力绑定'] if a['实现']=='roster'})
s=re.sub(r'const IDS=\[.*\]','const IDS='+json.dumps(ids,ensure_ascii=False),s);s=re.sub(r'const ROSTER_EFFECTS=\[.*\]','const ROSTER_EFFECTS='+json.dumps(effects,ensure_ascii=False),s);p.write_text(s,encoding='utf-8')
print('Archived',len(plan),'New definitions',len(new),'Total',len(ids),'Excel changes',len(diff))
