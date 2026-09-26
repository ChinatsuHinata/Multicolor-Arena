extends RefCounted
## Cosmetic IDs are scoped to a deck; card IDs and gameplay definitions never change.
const MANIFEST="res://data/alternate_art.json"
static var catalogue: Dictionary={}
static func groups() -> Dictionary:
 if catalogue.is_empty():
  var data=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
  if data is Dictionary and data.get("version",0)==1:catalogue=data.get("groups",{})
 return catalogue
static func canonical(id: String,cards: Dictionary) -> String:
 return cards.get(id,{}).get("canonical_id",id)
static func options(id: String,cards: Dictionary) -> Array:
 return groups().get(canonical(id,cards),[])
static func valid(id: String,art_id: String,cards: Dictionary) -> bool:
 return options(id,cards).any(func(v):return v.id==art_id)
static func selected(deck: Dictionary,id: String,cards: Dictionary) -> String:
 return str(deck.get("art_overrides",{}).get(canonical(id,cards),""))
static func image_path(id: String,art_id: String,cards: Dictionary) -> String:
 for variant in options(id,cards):
  if variant.id==art_id:return variant.image
 return cards.get(id,{}).get("image","")
static func validate(overrides: Variant,cards: Dictionary) -> String:
 if not overrides is Dictionary:return "异画设置格式错误。"
 if overrides.size()>groups().size():return "异画设置过多。"
 for id in overrides:
  if not id is String or not cards.has(id) or canonical(id,cards)!=id:return "异画设置包含未知卡牌。"
  if not overrides[id] is String or not valid(id,overrides[id],cards):return "卡牌的异画版本无效："+id
 return ""
