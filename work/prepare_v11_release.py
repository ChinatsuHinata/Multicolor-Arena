from pathlib import Path
import json,hashlib
root=Path('.')
paths=list((root/'net').glob('*.gd'))+list((root/'scripts/rules').glob('*.gd'))+[root/'scripts/card_database.gd',root/'scripts/deck_store.gd',root/'scripts/replay_archive.gd']
manifest={'version':'1.1','files':{p.as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}}
(root/'net/rules_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Rules manifest:',len(paths))
p=root/'scripts/export_verification/main.gd';s=p.read_text(encoding='utf-8').replace('=="1.0","1.0 product identity"','=="1.1","1.1 product identity"').replace('Store.CARDS.size()==486','Store.CARDS.size()==511')
pos=' for id in Store.CARDS:\n'
insert=''' check(int(Store.CARDS["spell-fdf-009"].cost["蓝"])==2 and int(Store.CARDS["spell-fdf-009"].cost["红"])==2,"1.1 modern history cost")
 check(int(Store.CARDS["spell-fdn-012"].cost["绿"])==2 and int(Store.CARDS["spell-fdn-012"].cost["黑"])==2 and int(Store.CARDS["spell-fdn-012"].cost["黄"])==1,"1.1 halfghost spell cost")
 check(Store.CARDS["character-fdn-071"].canonical_id=="character-ucs-068","1.1 alternate Okina identity")
 check(int(Store.CARDS["new-spx-003"].cost["蓝"])==4 and int(Store.CARDS["new-spx-003"].cost["绿"])==4,"Suwako artwork ruling included")
'''
assert pos in s;s=s.replace(pos,insert+pos);p.write_text(s,encoding='utf-8')
for old,new in [('export_bugs0921.py','export_v11.py'),('verify_export_bugs0921.py','verify_export_v11.py')]:
 s=(root/'work'/old).read_text(encoding='utf-8').replace('work/bugfix0921/export','work/v11/export').replace('Windows-1.0-bugfix0921','Windows-1.1').replace('Verify-bugfix0921-r2','Verify-1.1')
 (root/'work'/new).write_text(s,encoding='utf-8')
(root/'work/v11/export').mkdir(parents=True,exist_ok=True)
(root/'builds/Windows-1.1').mkdir(parents=True,exist_ok=True)
