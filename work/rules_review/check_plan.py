from pathlib import Path
import json,re
p=Path(r'C:\Users\tzx20\Documents\test\docs\游戏整体开发计划.md')
s=p.read_text(encoding='utf-8-sig')
for block in re.findall(r'```json\n(.*?)\n```',s,re.S):
 d=json.loads(block)
 assert d['卡牌ID']=='soi_spell_102'
 assert d['能力'][0]['效果'][0]['目标引用']==d['能力'][0]['目标'][0]['键']
assert s.count('```')%2==0
assert all(f'D{i:02d}' in s for i in range(1,16))
print('Plan verified:',len(s),'characters; JSON example parses; 15 decision entries; balanced code fences.')
