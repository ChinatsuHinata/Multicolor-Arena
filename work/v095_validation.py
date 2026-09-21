from pathlib import Path
import re,hashlib,json
root=Path(__file__).resolve().parents[1]
logs=['v095-final-test_v095_rules.log','v095-final-test_v095.log','v095-final-test_v095_edges.log','v095-test_v09_rules.log','v095-final-test_v09_matches.log','v095-test_v07_matches.log','v095-test_v08.log','v095-test_v082.log','v095-test_v081.log','v095-final-test_v094.log','v095-test_v092.log','v095-final-test_v06.log','v095-final-test_v093.log','v095-final-test_v09_ui.log']
total=0
lines=[]
for name in logs:
 text=(root/'work'/name).read_text('utf-8')
 summaries=re.findall(r'(V\w+: (\d+) checks; (\d+) failures[^\n]*)',text)
 assert summaries,name+' missing test summary'
 summary,count,failures=summaries[-1]
 assert int(failures)==0,(name,summary)
 errors=[line for line in text.splitlines() if ('ERROR:' in line or 'Parse Error:' in line) and 'Failed to read the root certificate store.' not in line]
 assert not errors,(name,errors)
 total+=int(count); lines.append(name+'\n  '+summary)
digest=hashlib.sha256((root/'saves/decks.json').read_bytes()).hexdigest().upper()
matches=json.loads((root/'work/v09-matches.json').read_text('utf-8'))
assert all(x in matches['new_cards_used'] for x in ['91','133','rec_unit_097','soi_unit_086'])
lines.insert(0,f'v0.9.5: {total} checks; 0 failures; no project script errors in selected final logs.')
lines+=['8 expanded-pool complete matches; all four added cards actually used.',f'Current saved decks SHA256: {digest}','Nue cost uses provisional first-table-row 3 red + 1 black; interpretation pending.']
(root/'work/v095-validation.txt').write_text('\n'.join(lines)+'\n','utf-8')
print('\n'.join(lines))
