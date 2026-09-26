extends RefCounted
const PATH="res://data/card_search_aliases.json"
const COLORS=["红","蓝","绿","黄","黑"]
const KINDS=["自机单位","普通单位","普通符卡","单位","自机","符卡","道具","结界"]

static func load_rules() -> Dictionary:
 if not FileAccess.file_exists(PATH):return {}
 var value=JSON.parse_string(FileAccess.get_file_as_string(PATH))
 return value if value is Dictionary else {}

static func find_rule(rules: Dictionary,alias: String) -> Variant:
 var text=alias.strip_edges().to_lower()
 for key in rules:
  if str(key).begins_with("_"):continue
  if str(key).to_lower()==text:return rules[key]
 if text.ends_with("饼"):
  var prefix=text.substr(0,text.length()-1)
  var color=prefix.trim_suffix("色")
  var base=rules.get("饼")
  if color in COLORS and base is Dictionary:
   var rule=base.duplicate(true)
   rule.colors=[color]
   return rule
 return null

static func card_matches(info: Dictionary,rule: Variant,card_id: String="") -> bool:
 if rule is Array:
  for part in rule:
   if part is String and not part.is_empty() and part.to_lower() in info.name.to_lower():return true
  return false
 if not rule is Dictionary:return false
 if not rule.get("colors",[]).all(func(color):return color in info.get("colors",[])):return false
 if rule.has("card_ids"):return card_id in rule.card_ids
 if rule.has("card_name_or_alias"):
  var name=str(rule.card_name_or_alias)
  return info.name==name or name in info.get("aliases",[])
 if rule.get("group","")=="mono_two_cost_tap_mana_item":
  if info.kind!="道具" or info.colors.size()!=1:return false
  var cost=info.get("cost",{})
  if cost.size()!=1 or not cost.has(info.colors[0]) or int(cost[info.colors[0]])!=2:return false
  return info.get("abilities",[]).any(func(ability):return ability.get("实现","")=="mana")
 return false

static func kind_matches(info: Dictionary,wanted: String) -> bool:
 var kind=str(info.kind)
 if wanted in ["","全部"]:return true
 if wanted=="单位":return kind in ["单位","自机"]
 if wanted=="普通单位":return kind=="单位"
 if wanted in ["自机单位","自机"]:return kind=="自机"
 if wanted=="普通符卡":return kind=="符卡" and str(info.get("requires_character","")).is_empty() and "角色" not in str(info.get("spell_type",""))
 return kind==wanted

static func alias_ids(cards: Dictionary,term: String,rules: Dictionary) -> Dictionary:
 var text=term.strip_edges().to_lower()
 var rule=find_rule(rules,text)
 var kind=""
 if rule==null:
  for suffix in KINDS:
   if not text.ends_with(suffix):continue
   rule=find_rule(rules,text.substr(0,text.length()-suffix.length()).strip_edges())
   if rule==null:continue
   kind=suffix
   break
 var matches={}
 if rule!=null:
  for id in cards:
   if kind_matches(cards[id],kind) and card_matches(cards[id],rule,id):matches[id]=true
 return {"exclusive":rule is Dictionary and rule.get("only",false)==true,"ids":matches}

static func role_spell_characters(cards: Dictionary,term: String,rules: Dictionary) -> Array:
 var text=term.strip_edges().to_lower()
 if not text.ends_with("符卡"):return []
 var leader_name=text.substr(0,text.length()-"符卡".length()).strip_edges()
 if leader_name.is_empty():return []
 var alias_rule=find_rule(rules,leader_name)
 var characters=[]
 for id in cards:
  var leader=cards[id]
  var name_match=leader.kind=="自机" and leader_name in leader.name.to_lower()
  var alias_match=alias_rule!=null and leader.kind in ["单位","自机"] and card_matches(leader,alias_rule,id)
  if not name_match and not alias_match:continue
  var character=leader.get("character","")
  if not character.is_empty() and character not in characters:characters.append(character)
 return characters

# Prepare once per search edit; each picker still filters only its legal candidates.
static func prepare_query(cards: Dictionary,term: String,rules: Dictionary) -> Dictionary:
 var query=alias_ids(cards,term,rules)
 query.term=term.strip_edges().to_lower()
 query.role_characters=role_spell_characters(cards,term,rules)
 return query

static func matches_query(info: Dictionary,id: String,query: Dictionary) -> bool:
 var term=str(query.term)
 if term.is_empty():return true
 var required_character=str(info.get("requires_character",""))
 var role_spell=info.kind=="符卡" and not required_character.is_empty() and query.role_characters.any(func(character):return character==required_character or str(character).begins_with(required_character+"·") or str(character).begins_with(required_character+"・"))
 if query.ids.has(id) or role_spell:return true
 if query.exclusive:return false
 var searchable=[info.name,id,info.get("title",""),info.get("character","")]
 searchable.append_array(info.get("keywords",[]))
 searchable.append_array(info.get("aliases",[]))
 if info.get("token",false):searchable.append("衍生物")
 if not info.get("constructible",false):searchable.append("不可构筑")
 return searchable.any(func(value):return term in str(value).to_lower())

static func matching_names(cards: Dictionary,query: Dictionary) -> Dictionary:
 var names={}
 for id in cards:
  if matches_query(cards[id],id,query):names[cards[id].name]=true
 return names
