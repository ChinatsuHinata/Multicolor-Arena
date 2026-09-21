from pathlib import Path
R=Path.cwd()
def edit(p,f):
 p=R/p;s=p.read_text(encoding='utf-8');p.write_text(f(s),encoding='utf-8')
def cat(s):
 start=s.index(' var choices=e.targets_for(c.card_id,t.owner);e.catalogue_x_override=0',s.index('static func copy_spell'))
 end=s.index('static func name_options',start)
 s=s[:start]+''' var choices=retarget_options(e,t,x);e.catalogue_x_override=0
 for property in ["paid_dolls","exiled_hand","ichirin_paid"]:
  if source.has(property):c[property]=source[property]
 var wrapper=t.duplicate(true);wrapper.source=source
 choose(e,wrapper,"cat:spell_copy",choices,{"card":c})
'''+s[end:]
 s+='''
static func retarget_options(e,entry,x=-1):
 var old=entry.target;var options=[]
 e.catalogue_retargeting=true
 if entry.kind=="card":options=e.targets_for(entry.card.card_id,entry.owner)
 elif entry.get("activation",false):options=e.Extra.activation_options(e,entry.source,entry.effect)
 else:options=e.trigger_options(entry)
 e.catalogue_retargeting=false
 var result=[]
 for option in options:
  if x>=0 and int(option.get("x",0))!=x:continue
  var matches=true
  for k in ["mode","x","ignore_color","pitch","counter_payment"]:
   if x>=0 and k in ["mode","x"]:continue
   if old.has(k) and option.get(k)!=old[k]:matches=false
  if not matches:continue
  var candidate=option.duplicate(true)
  if candidate.has("selection"):
   if not old.has("picks") or candidate.selection.size()!=old.picks.size():continue
   if x<0 and candidate.get("selection_id","")!=old.get("selection_id",""):continue
   var groups=[];var indexes=[]
   for i in range(candidate.selection.size()):
    if candidate.selection[i].get("cost",false):continue
    var g=candidate.selection[i];g.min=old.picks[i].size();g.max=old.picks[i].size()
    groups.append(g);indexes.append(i)
   candidate.selection=groups;candidate.retarget_indices=indexes;candidate.retarget_base=old.duplicate(true)
   if x>=0:candidate.retarget_base.x=x
  result.append(candidate)
 return result if not result.is_empty() else [old.duplicate(true)]
static func retarget_result(a):
 if not a.has("retarget_indices"):return a
 var result=a.retarget_base.duplicate(true)
 for i in range(a.retarget_indices.size()):result.picks[a.retarget_indices[i]]=a.picks[i]
 return result
'''
 return s
edit('scripts/rules/catalogue_abilities.gd',cat)
def spell(s):
 s=s.replace('var choices=e.targets_for(s.card.card_id,s.owner) if s.kind=="card" else e.Extra.activation_options(e,s.source,s.effect) if s.get("activation",false) else e.trigger_options(s)','var choices=C.retarget_options(e,s)')
 s=s.replace('if s.id==d.id:s.target=a.duplicate(true)','if s.id==d.id:s.target=C.retarget_result(a)')
 s=s.replace('"card":c,"owner":who,"target":a,"name":e.cards[c.card_id].name,"copy":true','"card":c,"owner":who,"target":C.retarget_result(a),"name":e.cards[c.card_id].name,"copy":true')
 return s
edit('scripts/rules/catalogue_spells.gd',spell)
# Retarget reconstruction is pure data; unavailable paid cost references are omitted from the UI.
# A separate builder temporarily allows empty costs while regenerating target choices.
edit('scripts/rules/duel_engine.gd',lambda s:s.replace('var catalogue_x_override=0','var catalogue_x_override=0\nvar catalogue_retargeting=false'))
# Pack.selection has no engine parameter; in retargeting the spell options provide a cost pool from its paid schema.
# Implement fallback within catalogue group: unavailable costs are zero-pick for retargeting only.
edit('scripts/rules/catalogue_abilities.gd',lambda s:s.replace('var g=e.Pack.group(pool,low,high,title);g.cost=cost;return g','var g=e.Pack.group(pool,0 if cost and e.catalogue_retargeting else low,high,title);g.cost=cost;return g'))
