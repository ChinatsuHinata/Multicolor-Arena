extends RefCounted
# Registered, implemented card pool. Adding an ID here exposes its JSON to both editor and duel.
const IDS=["68","70","99","100","164","165","167","170"]
const COLORS=["红","蓝","绿","黄","黑"]
static var last_error=""
const HANDLERS=["marisa_enter","marisa_spell","brave","exterminate","damage","counter_card","mana","grant_leader_abilities","activated_damage"]
static func integer_value(value: Variant) -> bool:
 return (value is int or value is float) and value>=0 and value==int(value)
static func validate_definition(d: Variant,id: String) -> String:
 if not d is Dictionary: return "最外层必须是对象"
 if d.get("格式版本")!=1 or d.get("卡牌ID")!=id: return "格式版本或卡牌ID错误"
 for key in ["名称","类别","图片","完整说明","能力文字","来源"]:
  if not d.get(key) is String or d[key].is_empty(): return "缺少文字字段："+key
 if d["类别"] not in ["自机","单位","符卡","道具","结界"]: return "尚未支持的类别"
 if not d.get("颜色") is Array or d["颜色"].is_empty(): return "颜色必须是非空数组"
 var seen=[]
 for color in d["颜色"]:
  if color not in COLORS or color in seen: return "颜色无效或重复"
  seen.append(color)
 if not d.get("费用") is Dictionary: return "费用必须是对象"
 for color in d["费用"]:
  if color not in COLORS or not integer_value(d["费用"][color]): return "费用必须是非负整数"
 if not d.get("构筑资格") is Dictionary or not d["构筑资格"].get("允许常规构筑") is bool: return "构筑资格必须明确为true或false"
 if not d.get("能力绑定") is Array: return "能力绑定必须是数组"
 for binding in d["能力绑定"]:
  if not binding is Dictionary or binding.get("实现","") not in HANDLERS: return "未登记的能力实现"
  var handler=binding["实现"]
  if handler in ["marisa_enter","marisa_spell","brave","exterminate"] and d["类别"] not in ["单位","自机"]: return "单位能力不能绑定到该类别"
  if handler in ["damage","counter_card"] and d["类别"]!="符卡": return "该结算效果目前仅支持符卡"
  if handler=="mana" and d["类别"]!="道具": return "该产色实现目前仅支持道具"
  if handler=="grant_leader_abilities" and d["类别"]!="结界": return "该持续能力目前仅支持结界"
  var params=binding.get("参数",{})
  if handler=="activated_damage":
   if d["类别"] not in ["单位","自机","道具","结界"]: return "启动异能需要永久物"
   if not params is Dictionary or not integer_value(params.get("数值")): return "启动伤害异能需要整数数值"
   if not params.get("费用",{}) is Dictionary or not params.get("横置",false) is bool: return "启动异能费用格式错误"
   for color in params.get("费用",{}):
    if color not in COLORS or not integer_value(params["费用"][color]): return "启动异能费用无效"
   if not params.get("横置",false) and params.get("费用",{}).values().all(func(v): return v==0): return "此实现需要横置或颜色费用"

  if not params is Dictionary: return "能力参数必须是对象"
  if binding["实现"] in ["damage","marisa_enter","marisa_spell"] and not integer_value(params.get("数值")): return "伤害能力需要数值参数"
  if binding["实现"]=="mana" and params.get("颜色") not in COLORS: return "产色能力需要合法颜色"
 if d["类别"] in ["单位","自机"]:
  for key in ["攻击力","血量","灵力"]:
   if not integer_value(d.get(key)): return "单位属性无效："+key
  for key in ["角色名","称号"]:
   if not d.get(key) is String: return "单位文字缺失："+key
  if not d.get("种族") is Array: return "单位种族必须是数组"
 if d.has("高速") and not d["高速"] is bool: return "高速必须为true或false"
 if d.has("角色约束") and not d["角色约束"] is String: return "角色约束必须是文字"
 if not ResourceLoader.exists(d["图片"]): return "图片不存在"
 return ""
static func load_cards() -> Dictionary:
 last_error=""
 var cards={}
 for id in IDS:
  var parser=JSON.new()
  var path="res://cards/"+id+".json"
  if parser.parse(FileAccess.get_file_as_string(path))!=OK:
   last_error="卡牌数据库错误：%s，第%d行" % [path,parser.get_error_line()]
   push_error(last_error); return {}
  var d=parser.data
  var error=validate_definition(d,id)
  if not error.is_empty():
   last_error="卡牌数据库错误：%s · %s" % [path,error]
   push_error(last_error); return {}
  cards[id]={"name":d["名称"],"kind":d["类别"],"color":" / ".join(d["颜色"]),"colors":d["颜色"],"cost":d["费用"],"file":d["图片"].get_file(),"image":d["图片"],"description":d["完整说明"],"rules_text":d["能力文字"],"source":d["来源"],"character":d.get("角色名",""),"title":d.get("称号",""),"race":d.get("种族",[]),"power":int(d.get("攻击力",0)),"health":int(d.get("血量",0)),"spirit":int(d.get("灵力",0)),"fast":d.get("高速",false),"requires_character":d.get("角色约束",""),"abilities":d["能力绑定"],"constructible":d["构筑资格"]["允许常规构筑"]}
 return cards
static func ability(card: Dictionary, handler: String) -> Dictionary:
 for binding in card.abilities:
  if binding["实现"]==handler: return binding.get("参数",{})
 return {}
static func has_ability(card: Dictionary, handler: String) -> bool:
 for binding in card.abilities:
  if binding["实现"]==handler: return true
 return false
