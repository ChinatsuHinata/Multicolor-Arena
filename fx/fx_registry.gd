extends RefCounted
## Loads every manifest once, resolves its module script, and decides which
## effects a match may run. Adding an effect never edits this file.
##
## State is per instance on purpose: a stage owns one registry, a test owns
## another, and neither can be surprised by a shared cache.

const Manifest=preload("res://fx/fx_manifest.gd")

var definitions: Dictionary={}
var errors: Array=[]
var loaded=false
## Off in battles: only free effects and equipped products run.
## A showcase or per-effect test may turn it on.
var allow_all=false

func reload(force: bool=false) -> void:
 if loaded and not force:return
 var result=Manifest.load_all()
 definitions=result.effects
 errors=result.errors
 loaded=true

func get_effect(id: String) -> Dictionary:
 reload()
 return definitions.get(id,{})

func by_category(category: String) -> Array:
 reload()
 var list: Array=[]
 for id in definitions:
  if str(definitions[id].category)==category:list.append(definitions[id])
 list.sort_custom(func(a,b):
  var pa=float(a.get("priority",100.0));var pb=float(b.get("priority",100.0))
  return pa<pb if pa!=pb else str(a.id)<str(b.id))
 return list

## `products` is the frozen battle loadout: product id → product dictionary.
## A definition runs when it is free, when its own product is equipped, or when
## an equipped product names it through `fx`.
func enabled(category: String,products: Dictionary={}) -> Array:
 reload()
 if allow_all:return by_category(category)
 var claimed={}
 for key in products:
  var product=products[key]
  if not product is Dictionary:continue
  var bound=str(product.get("fx",""))
  if bound.is_empty():bound=str(key)
  claimed[bound]=true
 var result: Array=[]
 for def in by_category(category):
  if def.get("free",false) or claimed.has(str(def.id)) or claimed.has(str(def.get("shop_product",""))):result.append(def)
 return result

## Returns a configured module, or null (with the reason in errors) if the
## manifest or its script is broken. Never throws.
func spawn(def: Dictionary,ctx: Dictionary) -> Node:
 var script_path=str(def.get("script",""))
 if not ResourceLoader.exists(script_path):
  errors.append({"file":str(def.get("source","")),"reason":"script not loadable: "+script_path})
  return null
 var script=load(script_path)
 if not script is GDScript:
  errors.append({"file":str(def.get("source","")),"reason":"script is not a GDScript"})
  return null
 var module=script.new()
 if not module is Node or not module.has_method("configure"):
  errors.append({"file":str(def.get("source","")),"reason":"script does not extend fx_module.gd"})
  return null
 module.configure(def,ctx)
 return module
