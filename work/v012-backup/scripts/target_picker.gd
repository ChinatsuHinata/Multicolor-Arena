extends RefCounted
## Turns legal engine options into inline selection steps; never changes duel state.
var entries: Array=[]
var path: Array=[]
var key=""
var specs: Array=[]
func reset():
 entries=[]; path=[]; key=""; specs=[]
func configure(options: Array,signature: String,unordered_parts: bool=false):
 if key==signature: return
 key=signature; path=[]; entries=[]; specs=[]
 for option in options:
  if option.has("selection"): specs.append(option.duplicate(true)); continue
  entries.append({"option":option.duplicate(true),"steps":steps(option)})
  if unordered_parts and option.get("parts",[]).size()==2:
   var reversed=option.duplicate(true); reversed.parts.reverse()
   entries.append({"option":option.duplicate(true),"steps":steps(reversed)})
 normalize()
func steps(option: Dictionary) -> Array:
 var result=[]
 if option.has("parts"):
  for part in option.parts: result.append_array(steps(part))
  return result
 if option.has("mode"): result.append({"kind":"mode","value":option.mode})
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
 if not specs.is_empty(): return
 for i in range(20):
  var next=at(path)
  if next.size()!=1 or next[0].kind=="target" or ready(): return
  path.append(next[0])
func ready() -> bool:
 if not specs.is_empty():
  var state=dynamic_state()
  return state.index>=0 and state.group>=specs[state.index].selection.size()
 return entries.any(func(entry): return entry.steps==path)
func option() -> Dictionary:
 if not specs.is_empty():
  if not ready(): return {}
  var state=dynamic_state()
  return {"selection_id":specs[state.index].get("selection_id",""),"picks":state.picks}
 for entry in entries:
  if entry.steps==path: return entry.option.duplicate(true)
 return {}
func base_path() -> Array:
 if ready() and at(path).is_empty() and not path.is_empty(): return path.slice(0,path.size()-1)
 return path.duplicate()
func available() -> Array:
 if not specs.is_empty(): return dynamic_available()
 return at(base_path())
func select(atom: Dictionary) -> bool:
 if atom not in available(): return false
 if not specs.is_empty(): path.append(atom); return true
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
func dynamic_state() -> Dictionary:
 var state={"index":0 if specs.size()==1 else -1,"group":0,"picks":[],"current":[],"previous":[]}
 for atom in path:
  if atom.kind=="spec": state.index=int(atom.index)
  elif atom.kind=="target": state.current.append(atom.value)
  elif atom.kind=="finish_group":
   state.picks.append(state.current.duplicate(true)); state.previous.append_array(state.current)
   state.current=[]; state.group+=1
 return state
func dynamic_available() -> Array:
 var state=dynamic_state(); var result=[]
 if state.index<0:
  for i in range(specs.size()): result.append({"kind":"spec","index":i,"value":specs[i].selection[0].get("title","选择")})
  return result
 if ready(): return result
 var g=specs[state.index].selection[state.group]
 if state.current.size()<g.max:
  for r in g.pool:
   if r in state.current or r in state.previous and g.get("exclude_previous",false): continue
   if g.get("distinct_names",false) and state.current.any(func(p): return p.get("choice_name")==r.get("choice_name")): continue
   result.append({"kind":"target","role":"target","value":r})
 if state.current.size()>=g.min:
  var caption="完成选择" if state.group==specs[state.index].selection.size()-1 else "下一项"
  result.append({"kind":"finish_group","value":caption+"（%d）" % state.current.size()})
 return result
func prompt() -> String:
 if specs.is_empty() or ready(): return ""
 var state=dynamic_state()
 if state.index<0: return "选择一项"
 return specs[state.index].selection[state.group].get("title","")
