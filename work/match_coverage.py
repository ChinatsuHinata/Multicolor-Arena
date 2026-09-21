from pathlib import Path
p=Path(r'C:\Users\tzx20\Documents\test')
f=p/'tests/test_duel.gd';s=f.read_text(encoding='utf-8-sig')
s=s.replace(' var finished=0',' var finished=0\n var complete_coverage=0\n var summaries=[]')
s=s.replace('  e=Duel.new(); e.start(sample("70"),sample("68"),seed_value%2,seed_value)','  var game_coverage={"attack":false,"block":false,"spell":false,"counter":false}\n  e=Duel.new(); e.start(sample("70"),sample("68"),seed_value%2,seed_value)')
s=s.replace('covered.attack=true','covered.attack=true; game_coverage.attack=true').replace('covered.block=true','covered.block=true; game_coverage.block=true').replace('covered.spell=true','covered.spell=true; game_coverage.spell=true').replace('covered.counter=true','covered.counter=true; game_coverage.counter=true')
s=s.replace('  if e.winner!=-2: finished+=1','  if e.winner!=-2:\n   finished+=1\n   if game_coverage.values().all(func(value): return value): complete_coverage+=1\n   summaries.append({"seed":seed_value,"turns":e.turn,"winner":e.winner,"result":e.log.back(),"coverage":game_coverage})')
s=s.replace(' var f=FileAccess.open("res://work/duel-test.txt",FileAccess.WRITE)',' expect(complete_coverage>0,"a single complete match includes all four requested interactions")\n var replay_report=FileAccess.open("res://work/full-match-results.json",FileAccess.WRITE)\n replay_report.store_string(JSON.stringify(summaries,"  "))\n var f=FileAccess.open("res://work/duel-test.txt",FileAccess.WRITE)')
f.write_text(s,encoding='utf-8')
