extends RefCounted
## Turns legal engine options into inline selection steps; never changes duel state.
var entries: Array=[]
var path: Array=[]
var key=""
func reset():
 entries=[]; path=[]; key=""
func configure(options: Array,signature: String,unordered_parts: bool=false):
 if key==signature: return
 key=signature; path=[]; entries=[]
 for option in options:
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
 for i in range(20):
  var next=at(path)
  if next.size()!=1 or next[0].kind=="target" or ready(): return
  path.append(next[0])
func ready() -> bool:
 return entries.any(func(entry): return entry.steps==path)
func option() -> Dictionary:
 for entry in entries:
  if entry.steps==path: return entry.option.duplicate(true)
 return {}
func base_path() -> Array:
 if ready() and at(path).is_empty() and not path.is_empty(): return path.slice(0,path.size()-1)
 return path.duplicate()
func available() -> Array: return at(base_path())
func select(atom: Dictionary) -> bool:
 if atom not in available(): return false
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
