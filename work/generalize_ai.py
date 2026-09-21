from pathlib import Path
r=Path(r'C:\Users\tzx20\Documents\test');p=r/'scripts/rules/duel_engine.gd';s=p.read_text(encoding='utf-8-sig')
s=s.replace(' pending={}; pump_choices()',' pending={}; revision+=1; pump_choices()')
a=s.index('func ai_step():');b=s.index('func ai_card_score',a);x=s[a:b]
x=x.replace('func ai_step():','func ai_step(who: int=1):\n var opponent=1-who').replace('mulligan(1,[])','mulligan(who,[])').replace('pending.owner!=1','pending.owner!=who').replace('ai_possession()','ai_possession(who)').replace('players[1]','players[who]').replace('units(0)','units(opponent)').replace('priority!=1','priority!=who').replace('legal_casts(1)','legal_casts(who)').replace('stack.back().owner==0','stack.back().owner==opponent').replace('commit_cast(1,','commit_cast(who,').replace('payment(1,','payment(who,').replace('pass_priority(1)','pass_priority(who)').replace('active==1','active==who').replace('{"player":0}','{"player":opponent}').replace('players[0]','players[opponent]').replace('units(1)','units(who)').replace('can_attack(1,','can_attack(who,').replace('attack(1,','attack(who,')
s=s[:a]+x+s[b:]
a=s.index('func ai_possession():');x=s[a:].replace('func ai_possession():','func ai_possession(who: int=1):').replace('players[1]','players[who]');s=s[:a]+x
p.write_text(s,encoding='utf-8')
