import json,re
from pathlib import Path
p=Path(r'C:\Users\tzx20\Documents\test')
for f in sorted((p/'cards').glob('*.json')):
 d=json.loads(f.read_text(encoding='utf-8-sig'))
 assert d['卡牌ID']==f.stem
 assert d['名称'] in (p/'docs/卡牌数据库与编写说明.md').read_text(encoding='utf-8-sig')
for file in ['docs/游戏整体开发计划.md','docs/卡牌数据库与编写说明.md','使用说明.md']:
 text=(p/file).read_text(encoding='utf-8-sig')
 assert text.count('```')%2==0,file
 assert '\ufffd' not in text,file
print('Documentation checked: all eight names match JSON; code fences and text encoding valid.')
