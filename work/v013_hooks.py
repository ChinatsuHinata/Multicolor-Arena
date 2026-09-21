from pathlib import Path
import json,re
R=Path.cwd(); ids=json.loads((R/'work/v013/new-ids.json').read_text());spells=[i for i in ids if i.startswith('spell-')]
p=R/'scripts/rules/catalogue_abilities.gd';s=p.read_text(encoding='utf-8-sig').replace('const SPELLS=[] # generated from reviewed import manifest','const SPELLS='+json.dumps(spells));p.write_text(s,encoding='utf-8')
p=R/'scripts/rules/excel_abilities.gd';s=p.read_text(encoding='utf-8');s=s.replace('const Batch=', 'const Cat=preload("res://scripts/rules/catalogue_abilities.gd")\nconst Batch=',1)
s=re.sub(r'(const ACTIVATIONS=\[.*\])',r'\1+Cat.ACTIVATIONS',s);s=re.sub(r'(const SPELLS=\[.*\])',r'\1+Cat.SPELLS',s)
for fn,line in {'spell_options':' var cat=Cat.spell_options(e,id,who)\n if cat!=null:return cat','spell_resolve':' if Cat.spell_resolve(e,entry):return true','trigger_options':' var cat=Cat.trigger_options(e,t)\n if cat!=null:return cat','resolve_trigger':' if Cat.resolve_trigger(e,t):return','on_enter':' Cat.on_enter(e,c)','on_leave':' Cat.on_leave(e,before,c)','on_death':' Cat.on_death(e,c,before)','on_phase':' Cat.on_phase(e,phase)','on_cast':' Cat.on_cast(e,c,who,old_zone)','on_attack':' Cat.on_attack(e,c)','activation_cost':' if k in Cat.ACTIVATIONS:return Cat.activation_cost(k)','activation_error':' if k in Cat.ACTIVATIONS:return Cat.activation_error(e,c,k)','activation_options':' if k in Cat.ACTIVATIONS:return Cat.activation_options(e,c,k)','pay_activation':' if k in Cat.ACTIVATIONS:Cat.pay_activation(e,c,k,t);return','resolve_activation':' if entry.effect in Cat.ACTIVATIONS:Cat.resolve_activation(e,entry);return'}.items():s=re.sub(r'(static func '+fn+r'\([^\n]+\n)',r'\1'+line+'\n',s,count=1)
p.write_text(s,encoding='utf-8')
p=R/'scripts/rules/duel_engine.gd';s=p.read_text(encoding='utf-8').replace('const Pack=','const Cat=Roster.Cat\nconst Pack=',1)
s=s.replace('  delayed.erase(d)\n','  if d.get("catalogue",false):\n   if Cat.resolve_delay(self,d):delayed.erase(d)\n   continue\n  delayed.erase(d)\n')
s+='\nfunc sacrifice(c: Dictionary):\n move_to(c,"grave")\n';p.write_text(s,encoding='utf-8')
