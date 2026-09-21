extends RefCounted
const SAVE_PATH = "res://saves/decks.json"
const Database = preload("res://scripts/card_database.gd")
static var CARDS: Dictionary = Database.load_cards()

static func blank(title: String = "未命名卡组") -> Dictionary:
 return {"id":str(Time.get_unix_time_from_system()) + "_" + str(randi()), "name":title, "main":[], "side":[], "leader":""}
static func validate(d: Variant, strict: bool = false) -> String:
 if not d is Dictionary: return "卡组数据必须是有效对象。"
 if not d.get("name") is String or d.get("name", "").strip_edges().is_empty(): return "请输入卡组名称。"
 if d.name.length() > 40: return "卡组名称不能超过 40 个字符。"
 if not d.get("main") is Array or not d.get("side") is Array: return "主卡组或副卡组格式错误。"
 if d.main.size() > 70: return "主卡组最多 70 张。"
 if d.side.size() > 10: return "副卡组最多 10 张。"
 if not d.get("leader") is String or not CARDS.has(d.leader) or CARDS[d.leader].kind != "自机": return "自机位必须放置一张自机，才可以保存或对战。"
 for id in d.main + d.side:
  if not id is String or not CARDS.has(id): return "卡组包含未知卡牌。"
 for id in d.main+d.side+[d.leader]:
  if not CARDS[id].constructible: return "不能加入常规卡组："+CARDS[id].name
 if strict and d.main.size() != 50: return "主卡组需要 50 张，当前 %d 张。" % d.main.size()
 if strict:
  var names={}
  for id in d.main:
   var name=CARDS[id].name
   names[name]=names.get(name,0)+1
   if "终言" in CARDS[id].get("keywords",[]) and names[name]>1: return "终言同名牌最多 1 张："+name
   if names[name]>4: return "同名牌最多 4 张："+name
  for id in d.main+d.side:
   if CARDS[id].name==CARDS[d.leader].name: return "主副卡组不能包含所选自机的同名牌。"
 return ""
static func add_card(d: Dictionary, id: String, zone: String) -> String:
 if not CARDS.has(id): return "未知卡牌。"
 if not CARDS[id].constructible: return "不能加入常规卡组："+CARDS[id].name
 if zone == "leader":
  if CARDS[id].kind != "自机": return "自机位只能放置自机卡。"
  d.leader = id
  return ""
 if not zone in ["main", "side"]: return "无效的卡组区域。"
 var limit = 70 if zone == "main" else 10
 if d[zone].size() >= limit: return "该区域已达到 %d 张的上限。" % limit
 d[zone].append(id)
 return ""
static func decode(code: String) -> Dictionary:
 if code.length() > 100000: return {"error":"卡组代码过长。"}
 var parser = JSON.new()
 if parser.parse(code) != OK: return {"error":"卡组代码不是有效 JSON。"}
 var d = parser.data
 var error = validate(d)
 if not error.is_empty(): return {"error":error}
 var clean = blank(d.name + "（副本）" if d.name.length() < 35 else d.name)
 clean.main = d.main.duplicate()
 clean.side = d.side.duplicate()
 clean.leader = d.leader
 return {"deck":clean}
static func load_decks(path: String = SAVE_PATH) -> Dictionary:
 if not FileAccess.file_exists(path): return {"decks":[]}
 var f = FileAccess.open(path, FileAccess.READ)
 if f == null: return {"error":"无法读取卡组文件。", "decks":[]}
 var data = JSON.parse_string(f.get_as_text())
 if not data is Dictionary or data.get("version") != 1 or not data.get("decks") is Array:
  return {"error":"卡组文件损坏，原文件已保留。", "decks":[]}
 var ids = {}
 for d in data.decks:
  var error = validate(d)
  if not error.is_empty() or not d.get("id") is String or ids.has(d.id):
   return {"error":"卡组文件包含无效数据，原文件已保留。", "decks":[]}
  ids[d.id] = true
 return {"decks":data.decks}
static func persist(decks: Array, path: String = SAVE_PATH) -> String:
 for d in decks:
  var error = validate(d)
  if not error.is_empty(): return error
 var temp = path + ".tmp"
 var f = FileAccess.open(temp, FileAccess.WRITE)
 if f == null: return "保存失败：无法写入卡组文件。"
 f.store_string(JSON.stringify({"version":1,"decks":decks}, "  "))
 f.flush()
 var write_error = f.get_error()
 f.close()
 if write_error != OK: return "保存失败：写入未完成。"
 if FileAccess.file_exists(path):
  var copy_error = DirAccess.copy_absolute(path, path + ".bak")
  if copy_error != OK: return "保存失败：无法备份原卡组。"
 if DirAccess.rename_absolute(temp, path) != OK: return "保存失败：无法替换卡组文件。"
 return ""




static func sort_deck(d: Dictionary):
 var categories=["自机","单位","符卡","道具","结界"]
 for zone in ["main","side"]:
  d[zone].sort_custom(func(a,b):
   var x=CARDS[a]; var y=CARDS[b]
   if x.kind!=y.kind: return categories.find(x.kind)<categories.find(y.kind)
   var cx=0; var cy=0
   for n in x.cost.values(): cx+=int(n)
   for n in y.cost.values(): cy+=int(n)
   if cx!=cy: return cx<cy
   if x.name!=y.name: return x.name.naturalnocasecmp_to(y.name)<0
   return a.naturalnocasecmp_to(b)<0)
