extends RefCounted
## Turns legal engine options into inline selection steps; never changes duel state.
var entries: Array=[]
var path: Array=[]
var key=""
var specs: Array=[]
var x_values: Array=[]
var automatic_opponent: int=-1
var automatic_target_indexes: Array=[]
func reset():
 entries=[]; path=[]; key=""; specs=[];x_values=[];automatic_opponent=-1;automatic_target_indexes=[]
func requires_stack() -> bool:
 # Inspect the whole choice, including later groups and already selected refs.
 return contains_stack_ref(entries) or contains_stack_ref(specs) or contains_stack_ref(path)
func contains_stack_ref(value: Variant) -> bool:
 if value is Dictionary:
  if value.has("stack_id") or value.get("zone","")=="stack":return true
  for child in value.values():
   if contains_stack_ref(child):return true
 elif value is Array:
  for child in value:
   if contains_stack_ref(child):return true
 return false
func configure(options: Array,signature: String,unordered_parts: bool=false,opponent: int=-1):
 if key==signature and automatic_opponent==opponent: return
 key=signature; path=[]; entries=[]; specs=[];x_values=[]
 automatic_opponent=opponent
 automatic_target_indexes=[]
 if not options.is_empty() and options.all(func(option):return option.has("x") or option.get("x_input",false)):
  for option in options:
   var value=x_for_option(option)
   if value not in x_values:x_values.append(value)
  x_values.sort()
 var has_selection=options.any(func(option):return option.has("selection"))
 var fixed_groups={}
 for option in options:
  if option.has("selection"): specs.append(option.duplicate(true)); continue
  entries.append({"option":option.duplicate(true),"steps":steps(option)})
  if unordered_parts and option.get("parts",[]).size()==2:
   var reversed=option.duplicate(true); reversed.parts.reverse()
   entries.append({"option":option.duplicate(true),"steps":steps(reversed)})
  if has_selection:
   var group_key=str(option.get("mode","")) if not str(option.get("mode","")).is_empty() else "fixed_"+str(fixed_groups.size())
   if not x_values.is_empty():group_key=str(option.x)+":"+group_key
   if not fixed_groups.has(group_key):
    fixed_groups[group_key]=specs.size()
    specs.append({"selection":[],"selection_id":"fixed_"+str(specs.size()),"fixed_options":[],"title":option.get("mode","选择目标")})
    if not x_values.is_empty():specs.back().x=int(option.x)
   specs[fixed_groups[group_key]].fixed_options.append(option.duplicate(true))
 normalize()
func steps(option: Dictionary) -> Array:
 var result=[]
 if option.has("parts"):
  for part in option.parts: result.append_array(steps(part))
  return result
 if not x_values.is_empty() and option.has("x"):result.append({"kind":"x","value":int(option.x)})
 if option.has("mode") and (x_values.is_empty() or str(option.mode)!="X = %d" % int(option.get("x",0))): result.append({"kind":"mode","value":option.mode})
 if int(option.get("redirect_total",1))>1: result.append({"kind":"mode","value":"第 %d 个目标" % (int(option.get("redirect_index",0))+1)})
 if option.has("sacrifice"): result.append({"kind":"target","role":"sacrifice","value":option.sacrifice})
 var target={}
 for field in ["uid","epoch","zone","player","stack_id"]:
  if option.has(field): target[field]=option[field]
 if not target.is_empty(): result.append({"kind":"target","role":"target","value":target})
 if option.has("redirect"): result.append({"kind":"target","role":"redirect","value":option.redirect})
 if option.has("color"): result.append({"kind":"color","value":option.color})
 return result
func has_prefix(sequence: Array,prefix: Array) -> bool:
 return sequence.size()>=prefix.size() and sequence.slice(0,prefix.size())==prefix
func at(prefix: Array) -> Array:
 var result=[]
 for entry in entries:
  if has_prefix(entry.steps,prefix) and entry.steps.size()>prefix.size():
   var atom=entry.steps[prefix.size()]
   if atom not in result: result.append(atom)
 return result
func normalize():
 automatic_target_indexes=automatic_target_indexes.filter(func(index):return index<path.size())
 while not ready():
  if not specs.is_empty():
   var state=dynamic_state()
   if state.index<0:return
   if not specs[state.index].has("fixed_options"):
    var group=selection_group(state)
    # Optional player targets and cost choices still require a decision.
    var next=dynamic_available()
    if automatic_group(group):
     if state.current.is_empty() and next.size()==1 and automatic_target(next[0]):
      automatic_target_indexes.append(path.size());path.append(next[0])
     elif state.current.size()==1 and next.size()==1 and next[0].kind=="finish_group":path.append(next[0])
     else:return
    else:
     var groups=specs[state.index].selection
     if state.group+1>=groups.size() or not automatic_group(groups[state.group+1]) or group.max<=0 or state.current.size()!=group.max:return
     if next.size()!=1 or next[0].kind!="finish_group":return
     path.append(next[0])
   else:
    var next=dynamic_available()
    if next.size()!=1 or not automatic_target(next[0]):return
    automatic_target_indexes.append(path.size());path.append(next[0])
  else:
   var next=at(path)
   if next.size()!=1 or next[0].kind=="x" or next[0].kind=="target" and not automatic_target(next[0]):return
   if next[0].kind=="target":automatic_target_indexes.append(path.size())
   path.append(next[0])
func opponent_ref(ref: Dictionary) -> bool:
 return automatic_opponent>=0 and ref.get("player",-1)==automatic_opponent and not ref.has("uid") and not ref.has("stack_id")
func automatic_target(atom: Dictionary) -> bool:
 return atom.kind=="target" and atom.get("role","")=="target" and opponent_ref(atom.value)
func automatic_group(group: Dictionary) -> bool:
 return not group.get("cost",false) and group.min==1 and group.max==1 and group.pool.size()==1 and opponent_ref(group.pool[0])
func has_manual_targets() -> bool:
 for index in range(path.size()):
  if path[index].kind=="target" and index not in automatic_target_indexes:return true
 return false
func can_reselect() -> bool:
 var initial=get_script().new()
 initial.entries=entries;initial.specs=specs;initial.x_values=x_values;initial.automatic_opponent=automatic_opponent
 initial.normalize()
 return path!=initial.path
func final_group_full(state: Dictionary) -> bool:
 if state.index<0 or specs[state.index].has("fixed_options"): return false
 var groups: Array=specs[state.index].selection
 if state.group!=groups.size()-1: return false
 var group: Dictionary=selection_group(state)
 return int(group.max)>0 and state.current.size()==int(group.max)
func ready() -> bool:
 if not specs.is_empty():
  var state=dynamic_state()
  if state.index>=0 and specs[state.index].has("fixed_options"):
   var chosen=path.filter(func(a):return a.kind not in ["spec","x"])
   return specs[state.index].fixed_options.any(func(option):return steps(option).filter(func(a):return a.kind not in ["mode","x"])==chosen)
  return state.index>=0 and (state.group>=specs[state.index].selection.size() or final_group_full(state))
 return entries.any(func(entry): return entry.steps==path)
func option() -> Dictionary:
 if not specs.is_empty():
  if not ready(): return {}
  var state=dynamic_state()
  var spec=specs[state.index]
  if spec.has("fixed_options"):
   var chosen=path.filter(func(a):return a.kind not in ["spec","x"])
   for candidate in spec.fixed_options:
    if steps(candidate).filter(func(a):return a.kind not in ["mode","x"])==chosen:return candidate.duplicate(true)
   return {}
  var result=spec.duplicate(true);result.erase("selection");result.picks=state.picks.duplicate(true)
  if final_group_full(state):result.picks.append(state.current.duplicate(true))
  return result
 for entry in entries:
  if entry.steps==path: return entry.option.duplicate(true)
 return {}
func base_path() -> Array:
 if ready() and at(path).is_empty() and not path.is_empty() and path.size()-1 not in automatic_target_indexes: return path.slice(0,path.size()-1)
 return path.duplicate()
func available() -> Array:
 if not specs.is_empty(): return dynamic_available()
 return at(base_path())
func select(atom: Dictionary) -> bool:
 if atom not in available(): return false
 if not specs.is_empty(): path.append(atom); normalize(); return true
 path=base_path(); path.append(atom); normalize(); return true
func select_target(target: Dictionary) -> bool:
 for atom in available():
  if atom.kind!="target": continue
  var ref=atom.value
  var same=target.has("uid") and ref.get("uid",-1)==target.uid and ref.get("epoch",-1)==target.get("epoch",-2)
  same=same or (target.has("player") and ref.get("player",-1)==target.player)
  same=same or (target.has("stack_id") and ref.get("stack_id",-1)==target.stack_id)
  if same: return select(atom)
 return false
func selected_refs() -> Array:
 return path.filter(func(a): return a.kind=="target").map(func(a): return a.value)
func available_refs() -> Array:
 return available().filter(func(a): return a.kind=="target").map(func(a): return a.value)
func preview_available(atoms: Array) -> Array:
 # Reuse all selection constraints without advancing the live picker.
 var preview=get_script().new()
 preview.entries=entries;preview.specs=specs;preview.x_values=x_values;preview.path=path.duplicate(true);preview.automatic_opponent=automatic_opponent;preview.automatic_target_indexes=automatic_target_indexes.duplicate()
 for atom in atoms:
  if not preview.select(atom):return []
 return preview.available()
func dynamic_state() -> Dictionary:
 var candidates=spec_indexes()
 var state={"index":candidates[0] if candidates.size()==1 else -1,"group":0,"picks":[],"current":[],"previous":[],"mode":"","counts":{}}
 for atom in path:
  if atom.kind=="spec": state.index=int(atom.index)
  elif atom.kind=="x_count":state.counts[int(atom.group)]=int(atom.value)
  elif atom.kind=="mode":state.mode=atom.value
  elif atom.kind=="target": state.current.append(atom.value)
  elif atom.kind=="finish_group":
   state.picks.append(state.current.duplicate(true)); state.previous.append_array(state.current)
   state.current=[]; state.group+=1;state.mode=""
 return state
func dynamic_available() -> Array:
 var state=dynamic_state(); var result=[]
 if not x_values.is_empty() and selected_x()<0:return x_values.map(func(value):return {"kind":"x","value":value})
 if state.index<0:
  for i in spec_indexes():
   var title=specs[i].get("title",specs[i].selection[0].get("title","选择") if not specs[i].selection.is_empty() else "选择")
   if specs[i].has("counter_payment"):title+=" · 移除 %d 个指示物支付" % int(specs[i].counter_payment)
   result.append({"kind":"spec","index":i,"value":title})
  return result
 if specs[state.index].has("fixed_options"):
  var chosen=path.filter(func(a):return a.kind not in ["spec","x"])
  for option in specs[state.index].fixed_options:
   var sequence=steps(option).filter(func(a):return a.kind not in ["mode","x"])
   if has_prefix(sequence,chosen) and chosen.size()<sequence.size() and sequence[chosen.size()] not in result:result.append(sequence[chosen.size()])
  return result
 if final_group_full(state):
  var group=selection_group(state)
  if automatic_group(group):return result
  result.append({"kind":"finish_group","value":"完成选择（%d）" % state.current.size()})
  return result
 if ready(): return result
 var g=selection_group(state)
 if g.get("x_input",false) and not state.counts.has(state.group):
  return range(int(g.min),mini(int(g.max),g.pool.size())+1).map(func(value):return {"kind":"x_count","group":state.group,"value":value})
 if state.mode.is_empty() and state.current.is_empty() and g.pool.any(func(r):return r.has("mode")) and not g.pool.all(func(r):return r.has("outside_id")):
  for r in g.pool:
   var atom={"kind":"mode","value":r.get("mode","")}
   if atom not in result:result.append(atom)
  if g.min==0:result.append({"kind":"finish_group","value":"跳过此项"})
  return result
 if state.current.size()<g.max:
  for r in g.pool:
   if not state.mode.is_empty() and r.get("mode","")!=state.mode:continue
   if r in state.current or r in state.previous and g.get("exclude_previous",false): continue
   if g.has("sum_max") and state.current.reduce(func(n,p):return n+int(p.get("choice_weight",0)),0)+int(r.get("choice_weight",0))>g.sum_max:continue
   if g.get("distinct_names",false) and state.current.any(func(p): return p.get("choice_name")==r.get("choice_name")): continue
   result.append({"kind":"target","role":"target","value":r})
 if state.current.size()>=g.min:
  var caption="完成选择" if state.group==specs[state.index].selection.size()-1 else "下一项"
  result.append({"kind":"finish_group","value":caption+"（%d）" % state.current.size()})
 return result
func prompt() -> String:
 if not x_values.is_empty() and selected_x()<0:return "输入 X 值"
 if specs.is_empty() or ready(): return ""
 var state=dynamic_state()
 if state.index<0: return "选择一项"
 if specs[state.index].has("fixed_options"):return specs[state.index].get("title","")
 var group=selection_group(state)
 return "输入 X 值 · "+group.get("title","") if group.get("x_input",false) and not state.counts.has(state.group) else group.get("title","")
func selected_x() -> int:
 for atom in path:
  if atom.kind in ["x","x_count"]:return int(atom.value)
 return -1
func spec_indexes() -> Array:
 var result=[]
 for i in range(specs.size()):
  if x_values.is_empty() or selected_x()>=0 and x_for_option(specs[i])==selected_x():result.append(i)
 return result
func x_for_option(option: Dictionary) -> int:
 return int(option.x) if option.has("x") else int(option.selection[0].min)
func selection_group(state: Dictionary) -> Dictionary:
 var group=specs[state.index].selection[state.group].duplicate()
 if group.get("x_input",false) and state.counts.has(state.group):group.min=state.counts[state.group];group.max=group.min
 return group
