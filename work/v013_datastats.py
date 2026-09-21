import json,re,hashlib
from pathlib import Path
plan=json.loads(Path('work/v013/import-plan.json').read_text(encoding='utf-8'))
print('plan keys',plan[0].keys())
for p in Path('cards').glob('*.json'):
 d=json.loads(p.read_text(encoding='utf-8-sig'))
 if '封兽' in d['名称']:print(p.stem,d['名称'],d['费用'],d.get('混合费用'))
cards=[json.loads(p.read_text(encoding='utf-8-sig')) for p in Path('cards').glob('*.json')]
print('constructible',sum(d['构筑资格']['允许常规构筑'] for d in cards),'tokens',sum(d.get('衍生物',False) for d in cards))
print('unique imports',len(set(i['id'] for i in plan)))
for i in plan[:2]:print(i['id'],i['destination'],i['sha256'])
