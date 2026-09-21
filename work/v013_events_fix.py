from pathlib import Path
R=Path.cwd()
def edit(p,f):
 p=R/p;s=p.read_text(encoding='utf-8');p.write_text(f(s),encoding='utf-8')
def cat(s):
 start=s.index(' if amount>0:\n  for c in field(e):',s.index('static func mill'))
 end=s.index('static func random_discard',start)
 s=s[:start]+s[end:]
 s=s.replace('"cat:god_damage","character-ucs-044"]','"cat:god_damage","spell-fdf-123","character-ucs-044"]')
 s=s.replace('if t.effect=="cat:god_damage":queued.data.amount+=t.data.amount','if t.effect in ["cat:god_damage","spell-fdf-123"]:queued.data.amount+=t.data.amount')
 s+='''
static func milled(e,c):
 for u in field(e):
  if has(e,u,"spell-fdf-123"):events(e,u,"spell-fdf-123",true,{"amount":1,"milled_owner":c.owner})
'''
 return s
edit('scripts/rules/catalogue_abilities.gd',cat)
def units(s):
 s=s.replace('  C.delay(e,c,"return",-1,"prepare")','  C.events(e,before,"cat:utsuho_return",false,{"ref":C.ref(e,c)})')
 s=s.replace('"cat:nuclear_return","cat:rank_death",','"cat:nuclear_return","cat:utsuho_return","cat:rank_death",')
 s=s.replace('  "cat:rank_death":','  "cat:utsuho_return":\n   if C.valid(e,d.ref):C.delay(e,e.find_card(d.ref.uid),"return",-1,"prepare")\n  "cat:rank_death":')
 s=s.replace('for u in e.units(c.owner):\n  if e.Cat.has(e,u,"character-htk-005")','for u in e.units(c.owner)+([c] if not e.units(c.owner).any(func(u):return u.uid==c.uid) else []):\n  if e.Cat.has(e,u,"character-htk-005")')
 return s
edit('scripts/rules/catalogue_units.gd',units)
def engine(s):
 s=s.replace(' var before=c.duplicate(true)\n detach(c)',' var before=c.duplicate(true)\n var from_top=c.zone=="deck" and not players[c.owner].deck.is_empty() and players[c.owner].deck[0].uid==c.uid\n detach(c)')
 s=s.replace('  if zone=="grave": Extra.on_death(self,c,before)\n  shift(c,"void"); return','  if zone=="grave": Extra.on_death(self,c,before)\n  c.zone=zone;Roster.on_leave(self,before,c)\n  shift(c,"void"); return')
 s=s.replace(' if zone=="palette":Cat.State.on_palette(self,c)',' if zone=="palette":Cat.State.on_palette(self,c)\n if from_top and zone=="grave":Cat.milled(self,c)')
 return s
edit('scripts/rules/duel_engine.gd',engine)
def old(s):
 s=s.replace('if e.Roster.unit(e,r):e.move_to(e.find_card(r.uid),"grave");n+=1','if e.Roster.unit(e,r):e.sacrifice(e.find_card(r.uid));n+=1')
 s=s.replace('if k in ["mask_joy","mask_anger","mask_sorrow"]:e.move_to(c,"grave")','if k in ["mask_joy","mask_anger","mask_sorrow"]:e.sacrifice(c)')
 return s
edit('scripts/rules/mask_abilities.gd',old)
edit('scripts/rules/excel_abilities.gd',lambda s:s.replace('if k in ["alice_recycle","kanako_blast","sanae_search"]:\n  for r in e.Pack.picked(t):e.move_to(e.find_card(r.uid),"grave")','if k in ["alice_recycle","kanako_blast"]:\n  for r in e.Pack.picked(t):e.sacrifice(e.find_card(r.uid))\n if k=="sanae_search":\n  for r in e.Pack.picked(t):e.move_to(e.find_card(r.uid),"grave")'))
edit('scripts/rules/precon_abilities.gd',lambda s:s.replace('if k=="keine_devour":\n  for r in picked(t): e.move_to(e.find_card(r.uid),"grave")','if k=="keine_devour":\n  for r in picked(t): e.sacrifice(e.find_card(r.uid))'))
edit('tests/test_v013_rules.gd',lambda s:s.replace('e.move_to(a,"grave",false);expect(e.delayed.size()==1','e.move_to(a,"grave",false);settle();expect(e.delayed.size()==1'))
