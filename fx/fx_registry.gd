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
## an equipped product names it through `fx`. `card_id` narrows the list to
## definitions whose `cards` names that card (no `cards` means every card);
## an empty card_id, or allow_all previews, skip the card filter.
func enabled(category: String,products: Dictionary={},card_id: String="") -> Array:
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
  if not matches_card(def,card_id):continue
  if def.get("free",false) or claimed.has(str(def.id)) or claimed.has(str(def.get("shop_product",""))):result.append(def)
 return result

static func matches_card(def: Dictionary,card_id: String) -> bool:
 if card_id.is_empty() or not def.get("cards") is Array:return true
 return def.cards.has(card_id)

## 入场时间点，缺省 after。
static func timing(def: Dictionary) -> String:
 return str(def.get("timing","after"))

static func flight(def: Dictionary) -> String:
 return str(def.get("flight","none"))

static func flight_ms(def: Dictionary) -> float:
 return float(def.flight_ms) if def.has("flight_ms") else 0.0

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
