extends RefCounted
const PATH="res://data/card_search_aliases.json"

static func load_rules() -> Dictionary:
 if not FileAccess.file_exists(PATH):return {}
 var value=JSON.parse_string(FileAccess.get_file_as_string(PATH))
 return value if value is Dictionary else {}

static func find_rule(rules: Dictionary,alias: String) -> Variant:
 for key in rules:
  if str(key).begins_with("_"):continue
  if str(key).to_lower()==alias.to_lower():return rules[key]
 return null

static func card_matches(info: Dictionary,rule: Variant) -> bool:
 if rule is Array:
  for part in rule:
   if part is String and not part.is_empty() and part.to_lower() in info.name.to_lower():return true
  return false
 if not rule is Dictionary:return false
 if rule.has("card_name_or_alias"):
  var name=str(rule.card_name_or_alias)
  return info.name==name or name in info.get("aliases",[])
 if rule.get("group","")=="mono_two_cost_tap_mana_item":
  if info.kind!="道具" or info.colors.size()!=1:return false
  var cost=info.get("cost",{})
  if cost.size()!=1 or not cost.has(info.colors[0]) or int(cost[info.colors[0]])!=2:return false
  return info.get("abilities",[]).any(func(ability):return ability.get("实现","")=="mana")
 return false
