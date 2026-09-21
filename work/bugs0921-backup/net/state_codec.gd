extends RefCounted
## Save a graph, not a tree: the leader and its battlefield object may share identity.
static func encode(value: Variant) -> Dictionary:
 var seen=[];var nodes=[]
 return {"root":pack_value(value,seen,nodes),"nodes":nodes}
static func pack_value(v: Variant,seen: Array,nodes: Array) -> Variant:
 if v is Dictionary or v is Array:
  for i in range(seen.size()):
   if is_same(v,seen[i]):return {"$ref":i}
  var id=seen.size();seen.append(v);nodes.append({})
  var data=[]
  if v is Dictionary:
   for k in v:data.append([pack_value(k,seen,nodes),pack_value(v[k],seen,nodes)])
  else:
   for item in v:data.append(pack_value(item,seen,nodes))
  nodes[id]={"dict":v is Dictionary,"data":data}
  return {"$ref":id}
 return v
static func decode(graph: Dictionary) -> Variant:
 var nodes=[]
 for item in graph.nodes:nodes.append({} if item.dict else [])
 for i in range(nodes.size()):
  var item=graph.nodes[i]
  for v in item.data:
   if item.dict:nodes[i][unpack_value(v[0],nodes)]=unpack_value(v[1],nodes)
   else:nodes[i].append(unpack_value(v,nodes))
 return unpack_value(graph.root,nodes)
static func unpack_value(v: Variant,nodes: Array) -> Variant:
 return nodes[int(v["$ref"])] if v is Dictionary and v.has("$ref") else v
static func capture(engine) -> Dictionary:
 var state={}
 for p in engine.get_property_list():
  if int(p.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE and p.name not in ["rng","payment_memo","payment_groups","cards","history","log","presentation_events"]:
   var value=engine.get(p.name)
   if not value is Object and not value is Callable:state[p.name]=value
 state["_rng_seed"]=engine.rng.seed;state["_rng_state"]=engine.rng.state
 var graph=encode(state);graph.definitions=engine.cards.duplicate(true)
 graph.plain={"history":engine.history.duplicate(true),"log":engine.log.duplicate(true),"presentation_events":engine.presentation_events.duplicate(true)}
 return graph
static func restore(engine,graph: Dictionary):
 var state=decode(graph)
 engine.cards=graph.definitions.duplicate(true)
 for key in graph.get("plain",{}):engine.set(key,graph.plain[key].duplicate(true))
 for k in state:
  if not str(k).begins_with("_rng_"):engine.set(k,state[k])
 engine.rng.seed=state._rng_seed;engine.rng.state=state._rng_state
 engine.payment_memo={};engine.payment_groups=[]
