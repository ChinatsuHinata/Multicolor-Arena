from pathlib import Path
p=Path('scripts/rules/catalogue_abilities.gd');s=p.read_text(encoding='utf-8').replace('static func paid_cast(e,c,t):\n var meta={};var id=c.card_id;var who=c.owner','static func paid_cast(e,c,t,controller=-1):\n var meta={};var id=c.card_id;var who=c.owner if controller<0 else controller');p.write_text(s,encoding='utf-8')
p=Path('scripts/rules/duel_engine.gd');s=p.read_text(encoding='utf-8').replace('Cat.paid_cast(self,c,target)','Cat.paid_cast(self,c,target,who)');p.write_text(s,encoding='utf-8')
