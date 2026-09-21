from pathlib import Path
import json
for p in Path('cards').glob('*.json'):
 d=json.loads(p.read_text(encoding='utf-8-sig'))
 if '人偶' in str(d.get('种族',[])):print(p.stem,d['名称'])
p=Path('tests/test_v013_rules.gd');s=p.read_text(encoding='utf-8-sig').replace('e.role_present(0,e.cards[b.card_id].requires_character,b)','e.Cat.State.role_present(e,b,0)');p.write_text(s,encoding='utf-8')
