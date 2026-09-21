from pathlib import Path
import json
p=Path(r'C:\Users\tzx20\Documents\test')
f=p/'cards/68.json';d=json.loads(f.read_text(encoding='utf-8-sig'))
for b in d['能力绑定']: b['参数']={'数值':3 if b['实现']=='marisa_enter' else 1}
f.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
f=p/'scripts/rules/demo_abilities.gd';s=f.read_text(encoding='utf-8-sig')
s=s.replace('entry.card,3,"进战场能力"','entry.card,int(DB.ability(card,"marisa_enter")["数值"]),"进战场能力"')
s=s.replace('owner,unit,1,"使用符卡能力"','owner,unit,int(DB.ability(engine.cards[unit.card_id],"marisa_spell")["数值"]),"使用符卡能力"')
f.write_text(s,encoding='utf-8')
