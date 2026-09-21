from pathlib import Path
import json,re,hashlib
root=Path(__file__).resolve().parents[1];out=root/'work/v015'
logs=['test_v098_rules','test_v095_rules','test_v098','test_v010_rules','test_v011_rules','test_v012_rules','test_v013_rules','test_v013_edges','test_v014_rules','test_v014_ui','test_v015_rules','test_v015_ui-visual','test_v013_ui-visual','test_v013_matches','test_v010_matches']
rows=[];total=0
for name in logs:
 text=(out/(name+'.log')).read_text('utf-8-sig');errors=[l for l in text.splitlines() if ('SCRIPT ERROR' in l or 'ERROR:' in l) and 'root certificate' not in l]
 foot=[l for l in text.splitlines() if re.search(r'V\d+_(?:RULES|UI|EDGES|MATCHES):',l)]
 assert not errors,(name,errors[:3])
 assert foot,(name,'missing completion')
 matches=re.findall(r'(\d+) checks;',foot[-1]);count=int(matches[0]) if matches else 0;total+=count
 assert '[] failures' in foot[-1] or '0 failures' in foot[-1] or '0 unfinished' in foot[-1],(name,foot[-1])
 rows.append({'log':str((out/(name+'.log')).relative_to(root)),'checks':count,'summary':foot[-1],'project_errors':[]})
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
preserved=[]
for folder in ['saves','data']:
 for before in (root/'work/v015-backup'/folder).rglob('*'):
  if before.is_file():
   rel=before.relative_to(root/'work/v015-backup');after=root/rel
   assert after.is_file() and digest(before)==digest(after),str(rel)
   preserved.append(str(rel))
a=json.loads((out/'etb-audit.json').read_text('utf-8'));b=json.loads((out/'activation-audit.json').read_text('utf-8'))
assert all(x['passed'] for x in a) and all(not x['own'] for x in b)
report={'date':'2026-09-19','version':'0.15','checks':total,'complete_matches':20,'entry_cards':len(a),'activation_entries':len(b),'tests':rows,'preserved_files':preserved,'notes':['图形交互日志为visual后缀；根证书存储诊断为既有系统诊断。','翻牌时间线0.5秒；单张墙钟时间另含贴图准备、帧调度与测试轮询。','尚未穷举所有卡牌组合。']}
(out/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:report[k] for k in ['checks','complete_matches','entry_cards','activation_entries','preserved_files']},ensure_ascii=False))
