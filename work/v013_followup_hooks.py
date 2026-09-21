from pathlib import Path
R=Path.cwd()
def edit(p,f):
 p=R/p;s=p.read_text(encoding='utf-8');p.write_text(f(s),encoding='utf-8')
edit('scripts/rules/duel_engine.gd',lambda s:s.replace('Cat.has(self,c,"character-fdn-027") and not legal_blockers(1-combat.owner).is_empty()','Cat.has(self,c,"character-fdf-090") and not legal_blockers().is_empty()'))
def extra(s):
 s=s.replace('"sacrifice_choice":\n   if valid(e,target): e.move_to(e.find_card(target.uid),"grave")','"sacrifice_choice":\n   if valid(e,target): e.sacrifice(e.find_card(target.uid))')
 s=s.replace('if original: e.move_to(c,"grave")','if original: e.sacrifice(c)')
 return s
edit('scripts/rules/expanded_abilities.gd',extra)
def pre(s):
 s=s.replace('if e.Extra.valid(e,r): e.move_to(e.find_card(r.uid),"grave"); ramp(e,who,1,false)','if e.Extra.valid(e,r): e.sacrifice(e.find_card(r.uid)); ramp(e,who,1,false)')
 s=s.replace('if k in ["standing_blast","watch_counter","letty_shield","wine_discount","medicine_return"]: e.move_to(c,"grave")','if k in ["standing_blast","watch_counter","letty_shield","wine_discount","medicine_return"]: e.sacrifice(c)')
 return s
edit('scripts/rules/precon_abilities.gd',pre)
edit('scripts/rules/excel_abilities.gd',lambda s:s.replace('"seiga_sacrifice":\n   for r in e.Pack.picked(aim):\n    if unit(e,r):e.move_to(e.find_card(r.uid),"grave")','"seiga_sacrifice":\n   for r in e.Pack.picked(aim):\n    if unit(e,r):e.sacrifice(e.find_card(r.uid))').replace('if not keep.any(func(r):return r.get("uid")==c.uid and r.get("epoch")==c.epoch):e.move_to(c,"grave")','if not keep.any(func(r):return r.get("uid")==c.uid and r.get("epoch")==c.epoch):e.sacrifice(c)'))
# Deferred actions use a human caption independent of an internal continuation key.
edit('scripts/rules/catalogue_abilities.gd',lambda s:s.replace('static func choose(e,t,k,options,data={},owner=-1):e.Roster.continue_choice(e,t,k,options,data,false,owner)','static func choose(e,t,k,options,data={},owner=-1):\n e.Roster.continue_choice(e,t,k,options,data,false,owner)\n if not e.pending.is_empty() and e.pending.has("trigger") and not e.pending.trigger.has("ability_text"):\n  e.pending.trigger.ability_text=t.get("ability_text",t.get("name",e.cards[t.source.card_id].name))'))
