from pathlib import Path
R=Path.cwd()
def edit(path,fn):
 p=R/path;s=p.read_text(encoding='utf-8-sig');p.write_text(fn(s),encoding='utf-8')
def picker(s):
 s=s.replace(' normalize()\nfunc steps',' if not specs.is_empty() and not entries.is_empty():\n  var included=[]\n  for entry in entries:\n   var o=entry.option\n   if o in included:continue\n   included.append(o)\n   specs.append({"selection":[],"selection_id":"fixed_"+str(specs.size()),"fixed_option":o,"title":o.get("mode","选择目标")})\n normalize()\nfunc steps')
 s=s.replace('  return {"selection_id":specs[state.index].get("selection_id",""),"picks":state.picks}','  var spec=specs[state.index]\n  if spec.has("fixed_option"):return spec.fixed_option.duplicate(true)\n  var result=spec.duplicate(true);result.erase("selection");result.picks=state.picks;return result')
 s=s.replace('  return state.index>=0 and state.group>=specs[state.index].selection.size()','  if state.index>=0 and specs[state.index].has("fixed_option"):\n   return path.size()>1 or steps(specs[state.index].fixed_option).is_empty()\n  return state.index>=0 and state.group>=specs[state.index].selection.size()')
 # Fixed alternative keeps the original sequence of target/mode atoms.
 s=s.replace(' if ready(): return result\n var g=', ' if specs[state.index].has("fixed_option"):\n  var sequence=steps(specs[state.index].fixed_option).filter(func(a):return a.kind!="mode")\n  var chosen=path.filter(func(a):return a.kind!="spec")\n  if chosen.size()<sequence.size():result.append(sequence[chosen.size()])\n  return result\n if ready(): return result\n var g=')
 s=s.replace('"value":specs[i].selection[0].get("title","选择")','"value":specs[i].get("title",specs[i].selection[0].get("title","选择") if not specs[i].selection.is_empty() else "选择")')
 s=s.replace('   if g.get("distinct_names",false)', '   if g.has("sum_max") and state.current.reduce(func(n,p):return n+int(p.get("choice_weight",0)),0)+int(r.get("choice_weight",0))>g.sum_max:continue\n   if g.get("distinct_names",false)')
 return s
edit('scripts/target_picker.gd',picker)
def pack(s):
 s=s.replace(' if t in options: return true',' if not e.Cat.extra_choice_valid(e,t):return false\n if t in options: return true',1)
 s=s.replace('  var good=true; var all_seen=[]','  var metadata_ok=true\n  for field in ["x","ignore_color","pitch","counter_payment"]:\n   if spec.has(field) and spec[field]!=t.get(field):metadata_ok=false\n  if not metadata_ok:continue\n  var good=true; var all_seen=[]',1)
 s=s.replace('   all_seen.append_array(seen)','   if g.has("sum_max"):\n    var total=0\n    for p in list:total+=e.stat(e.find_card(p.uid),g.sum_stat)\n    if total>g.sum_max:good=false\n   all_seen.append_array(seen)',1)
 s=s.replace('  var spec=specs[0]; var result={"selection_id":spec.get("selection_id",""),"picks":[]}; var seen=[]','  var spec=specs[0]; var result=spec.duplicate(true);result.erase("selection");result.picks=[];var seen=[]')
 s=s.replace('    if g.get("distinct_names",false):\n     var name=', '    if g.has("sum_max") and list.reduce(func(n,p):return n+int(p.get("choice_weight",0)),0)+int(r.get("choice_weight",0))>g.sum_max:continue\n    if g.get("distinct_names",false):\n     var name=')
 return s
edit('scripts/rules/precon_abilities.gd',pack)
edit('scripts/rules/catalogue_abilities.gd',lambda s:s.replace('var g=e.Pack.group(refs(e,list),low,high,title);g.cost=cost;return g','var pool=refs(e,list)\n for r in pool:r.choice_name=e.cards[e.find_card(r.uid).card_id].name\n var g=e.Pack.group(pool,low,high,title);g.cost=cost;return g'))
# Do not add choice_name to references that do not need it (target equality is structural).
edit('scripts/rules/catalogue_abilities.gd',lambda s:s.replace(' for r in pool:r.choice_name=e.cards[e.find_card(r.uid).card_id].name\n',''))
edit('scripts/rules/catalogue_spells.gd',lambda s:s.replace('g.sum_stat="spirit";g.sum_max=3','g.sum_stat="spirit";g.sum_max=3\n   for r in g.pool:r.choice_weight=e.stat(e.find_card(r.uid),"spirit")').replace('g.distinct_names=id=="spell-fdn-046"','g.distinct_names=id=="spell-fdn-046"\n   if g.distinct_names:\n    for r in g.pool:r.choice_name=e.cards[e.find_card(r.uid).card_id].name').replace('var max_x=e.source_resources(who).size()+C.counter_total(e,own) if id=="spell-fdf-053" else e.source_resources(who).size()','var max_x=maxi(e.catalogue_x_override,e.source_resources(who).size()+C.counter_total(e,own) if id=="spell-fdf-053" else e.source_resources(who).size())').replace('for j in range(n):groups.append(e.Pack.group(C.counter_refs(e,own),1,1,"移除一个指示物",false))','for j in range(n):\n       var cg=e.Pack.group(C.counter_refs(e,own),1,1,"移除一个指示物");cg.exclude_previous=true;cg.cost=true;groups.append(cg)'))
edit('scripts/rules/catalogue_units.gd',lambda s:s.replace('"character-lof-004","character-fdf-119","character-fdf-114"','"character-lof-004","character-fdf-114"').replace('"cat:element_reveal","cat:sacrifice_recover"','"cat:element_reveal","cat:flower_cast","cat:unconscious_return","cat:sacrifice_recover"').replace('  "cat:element_reveal":\n','  "cat:flower_cast":\n   if same and c.zone=="palette":C.grant_cast(e,c,who,true)\n  "cat:unconscious_return":\n   if same and c.zone=="grave":e.move_to(c,"hand")\n  "cat:element_reveal":\n'))
edit('scripts/rules/duel_engine.gd',lambda s:s.replace('var catalogue_target_fast=false','var catalogue_target_fast=false\nvar catalogue_x_override=0').replace('func trigger_options(t: Dictionary) -> Array:\n','func trigger_options(t: Dictionary) -> Array:\n catalogue_target_fast=false\n').replace('  e.target=Roster.invalidate(self,e.target,e.owner,e.kind=="card")','  catalogue_target_fast=cards[e.card.card_id].fast if e.kind=="card" else false\n  e.target=Roster.invalidate(self,e.target,e.owner,e.kind=="card")'))
edit('scripts/rules/excel_abilities.gd',lambda s:s.replace('elif protected(e,out,who,spell): out.uid=-1','elif protected(e,out,who,spell): return {"invalid":true}'))
edit('scripts/rules/catalogue_abilities.gd',lambda s:s.replace(' var choices=e.targets_for(c.card_id,t.owner)\n if x>=0:', ' e.catalogue_x_override=maxi(0,x)\n var choices=e.targets_for(c.card_id,t.owner);e.catalogue_x_override=0\n if x>=0:').replace('c.stack_copy=true;c.cast_x','c.stack_copy=true;c.token=true;c.cast_x'))
# Baseline card-count assertions change only because the catalogue grew.
for p in (R/'tests').glob('*.gd'):
 s=p.read_text(encoding='utf-8-sig')
 if '269' in s:s=s.replace('269','486');p.write_text(s,encoding='utf-8')
