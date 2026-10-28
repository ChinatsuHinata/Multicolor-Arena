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
  if not str(info.get("mod_namespace","")).is_empty():continue
  var canonical=Art.canonical(id,Store.CARDS)
  var search=[id,info.name,info.get("character",""),info.get("title","")]
  search.append_array(info.get("aliases",[]))
  for alias in rules:
   if not str(alias).begins_with("_") and Aliases.card_matches(info,rules[alias],id):search.append(alias)
  var art_ids=[]
  for variant in Art.options(id,Store.CARDS):art_ids.append(variant.id)
  var exclude=Store.excludes_deck_colors(id)
  cards[id]={"name":info.name,"leader":info.kind=="自机","constructible":info.get("constructible",false) and not info.get("token",false),"canonical":canonical,"colors":info.colors,"search":search,"arts":art_ids,"exclude_colors":exclude}
  cards[id].name_key=Store.RuleSet.name_key(id,Store.CARDS)
  cards[id].match_allowed=Store.RuleSet.allowed(id,info,Store.RuleSet.UNRESTRICTED)
  cards[id].match_limit=Store.RuleSet.limit(id,info,Store.RuleSet.UNRESTRICTED)
  if info.has("rule_sets"):cards[id].rule_sets=info.rule_sets
 var file=FileAccess.open("res://relay/deck_plaza_catalogue.json",FileAccess.WRITE)
 if file==null:push_error("Could not write deck plaza catalogue");quit(1);return
 var exploration=preload("res://scripts/rules/gensokyo_exploration.gd")
 file.store_string(JSON.stringify({"version":2,"cards":cards,"fixed_decks":{"4":exploration.deck(),"5":exploration.deck(true)}}," "))
 file.close();print("DECK_PLAZA_CATALOGUE: ",cards.size()," card records; no assets")
 quit()
