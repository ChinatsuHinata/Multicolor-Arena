import openpyxl,json
from pathlib import Path
r=Path(r'C:\Users\tzx20\Documents\test');w=openpyxl.load_workbook(r/'recourse'/'极彩全牌表 - （圣版可检索）25-12-17.xlsx',read_only=True,data_only=True)
out=[]; seen=set();counts={}
for s in w:
 if not s.title.startswith(('CHARACTER','SPELL','ITEM','FIELD','TOKEN')): continue
 count=0
 for i,row in enumerate(s.values,1):
  if i==1:continue
  token=s.title.startswith('TOKEN');unit=s.title.startswith('CHARACTER');spell=s.title.startswith('SPELL')
  name=row[4] if token else (str(row[5] or '')+'「'+str(row[6] or '')+'」' if unit else row[5])
  if not name or (unit and not row[6]):continue
  effect=' / 自机：'.join(str(v or '') for v in row[17:19]) if unit else str(row[10] if token else row[16] if spell else row[12] or '')
  count+=1
  key=(name,effect)
  if key in seen:continue
  seen.add(key)
  out.append({'sheet':s.title,'row':i,'code':row[2],'name':name,'effect':effect})
 counts[s.title]=count
p=r/'work'/'rules_review'/'card_effects.json';p.write_text(json.dumps(out,ensure_ascii=False,indent=1),encoding='utf-8')
print(counts,'unique name/effect records',len(out))
for j,x in enumerate(out):
 if '梦违' in str(x) or any(k in x['effect'] for k in ['开始游戏','游戏开始','构筑','套牌','额外回合','结束当前','额外的回合']): print(j,json.dumps(x,ensure_ascii=False))
