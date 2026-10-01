extends SceneTree
## Server search metadata contains no textures, file paths or card assets.
const Store=preload("res://scripts/deck_store.gd")
const Aliases=preload("res://scripts/card_search_aliases.gd")
const Art=preload("res://scripts/card_art.gd")
func _initialize():
 var cards={}
 var rules=Aliases.load_rules()
 for id in Store.CARDS:
  var info=Store.CARDS[id]
  var canonical=Art.canonical(id,Store.CARDS)
  var search=[id,info.name,info.get("character",""),info.get("title","")]
  search.append_array(info.get("aliases",[]))
  for alias in rules:
   if not str(alias).begins_with("_") and Aliases.card_matches(info,rules[alias],id):search.append(alias)
  var art_ids=[]
  for variant in Art.options(id,Store.CARDS):art_ids.append(variant.id)
  var canonical_info=Store.CARDS.get(canonical,info)
  var exclude=canonical in ["128","character-soi-006"] or "极彩" in info.get("keywords",[]) or "极彩" in canonical_info.get("keywords",[])
  cards[id]={"name":info.name,"leader":info.kind=="自机","constructible":info.get("constructible",false) and not info.get("token",false),"canonical":canonical,"colors":info.colors,"search":search,"arts":art_ids,"exclude_colors":exclude}
 var file=FileAccess.open("res://relay/deck_plaza_catalogue.json",FileAccess.WRITE)
 if file==null:push_error("Could not write deck plaza catalogue");quit(1);return
 file.store_string(JSON.stringify({"version":1,"cards":cards}," "))
 file.close();print("DECK_PLAZA_CATALOGUE: ",cards.size()," card records; no assets")
 quit()
