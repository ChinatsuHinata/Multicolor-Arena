from pathlib import Path
import re,json
r=Path(r'C:\Users\tzx20\Documents\test');p=r/'docs'/'游戏整体开发计划.md';s=p.read_text(encoding='utf-8')
s=s.replace('符卡258行（以导入核对为准）','符卡258行')
p.write_text(s,encoding='utf-8')
blocks=re.findall(r'```json\n(.*?)\n```',s,re.S)
for b in blocks: json.loads(b)
assert s.count('```')%2==0
print('Validated',len(blocks),'JSON examples and document code fences.')
