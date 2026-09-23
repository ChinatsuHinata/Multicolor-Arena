extends RefCounted
const SAVE_PATH = "res://saves/decks.json"
const USER_SAVE_PATH = "user://decks.json"
const BUNDLED_DECKS_PATH = "res://data/bundled_decks.json"
const Paths=preload("res://scripts/portable_paths.gd")
const EXTENSION="mdeck"
static var file_paths={}

static func active_save_path() -> String:
 return folder()

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
   var name=CARDS[CARDS[id].get("canonical_id",id)].name
   names[name]=names.get(name,0)+1
   if "终言" in CARDS[id].get("keywords",[]) and names[name]>1: return "终言同名牌最多 1 张："+name
   if "限制级" in CARDS[id].get("keywords",[]) and names[name]>2: return "限制级同名牌最多 2 张："+name
   if names[name]>4 and not CARDS[id].get("unlimited",false): return "同名牌最多 4 张："+name
  for id in d.main+d.side:
   if CARDS[CARDS[id].get("canonical_id",id)].name==CARDS[CARDS[d.leader].get("canonical_id",d.leader)].name: return "主副卡组不能包含所选自机的同名牌。"
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
static func load_decks(path: String = "") -> Dictionary:
 if path.is_empty():return load_portable()
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
static func persist(decks: Array, path: String = "") -> String:
 if path.is_empty():
  for deck in decks:
   var result=save_file(deck)
   if not result.is_empty():return result
  return ""
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

static func clean_deck(d: Dictionary) -> Dictionary:
 return {"id":d.id,"name":d.name,"leader":d.leader,"main":d.main.duplicate(),"side":d.side.duplicate()}
static func folder() -> String:return Paths.root().path_join("deck")
static func scan_files(directory: String,depth: int=0) -> Array:
 var result=[]
 var dir=DirAccess.open(directory)
 if dir==null or depth>4:return result
 dir.list_dir_begin()
 var name=dir.get_next()
 while not name.is_empty():
  if not name.begins_with(".") and not dir.is_link(name):
   if dir.current_is_dir():result.append_array(scan_files(directory.path_join(name),depth+1))
   elif name.get_extension().to_lower()==EXTENSION:result.append(directory.path_join(name))
  name=dir.get_next()
 dir.list_dir_end();result.sort()
 return result
static func initialize_portable() -> String:
 var error=Paths.initialize()
 if not error.is_empty():return error
 var marker=folder().path_join(".initialized")
 if FileAccess.file_exists(marker):return ""
 var seed=load_decks(SAVE_PATH if OS.has_feature("editor") else BUNDLED_DECKS_PATH)
 if seed.has("error"):return seed.error
 if seed.decks.is_empty():return "发行包缺少预设卡组。"
 var defaults=folder().path_join("预设卡组")
 if DirAccess.make_dir_recursive_absolute(defaults)!=OK:return "无法创建预设卡组文件夹。"
 var existing={}
 for path in scan_files(folder()):
  var parsed=read_file(path)
  if parsed.has("deck"):existing[parsed.deck.id]=true
 file_paths.clear()
 var seeds=seed.decks.duplicate(true)
 if not OS.has_feature("editor") and FileAccess.file_exists(USER_SAVE_PATH):
  var legacy=load_decks(USER_SAVE_PATH)
  if legacy.has("error"):return legacy.error
  for d in legacy.decks:
   var replaced=false
   for i in range(seeds.size()):
    if seeds[i].id==d.id:seeds[i]=d;replaced=true;break
   if not replaced:seeds.append(d)
 for deck in seeds:
  if existing.has(deck.id):continue
  error=save_file(deck,defaults.path_join(filename(deck)))
  if not error.is_empty():return error
 var f=FileAccess.open(marker,FileAccess.WRITE)
 if f==null:return "无法写入卡组初始化标记。"
 f.store_string("1");f.close()
 return ""
static func filename(d: Dictionary) -> String:
 var title=d.name.validate_filename().strip_edges().trim_suffix(".")
 if title.is_empty():title="卡组"
 return title.left(40)+"_"+str(d.id).sha256_text().left(12)+"."+EXTENSION
static func read_file(path: String) -> Dictionary:
 var f=FileAccess.open(path,FileAccess.READ)
 if f==null:return {"error":"无法读取"}
 if f.get_length()>100000:return {"error":"文件过大"}
 var parser=JSON.new()
 if parser.parse(f.get_as_text())!=OK:return {"error":"不是有效的 JSON 文件"}
 var data=parser.data
 if not data is Dictionary or data.get("format")!="multicolor:arena/deck" or data.get("version")!=1:return {"error":"不是受支持的 .mdeck 文件"}
 var d=data.get("deck")
 var error=validate(d)
 if not error.is_empty():return {"error":error}
 if not d.get("id") is String or d.id.is_empty() or d.id.length()>200:return {"error":"卡组标识无效"}
 return {"deck":clean_deck(d)}
static func load_portable() -> Dictionary:
 var error=initialize_portable()
 if not error.is_empty():return {"decks":[],"error":error}
 file_paths.clear()
 var decks=[];var warnings=[];var seen={}
 for path in scan_files(folder()):
  var parsed=read_file(path)
  if parsed.has("error"):warnings.append(path.get_file()+"："+parsed.error);continue
  var d=parsed.deck
  if seen.has(d.id):
   if seen[d.id]==d:continue
   # Two differently edited copies of one shared deck must both remain accessible.
   d.id="import_"+path.sha256_text()
  seen[d.id]=d;file_paths[d.id]=path;decks.append(d)
 return {"decks":decks,"warnings":warnings}
static func save_file(d: Dictionary,path: String="") -> String:
 if not d.get("id") is String or d.id.is_empty():return "卡组标识无效"
 var error=validate(d)
 if not error.is_empty():return error
 error=Paths.initialize()
 if not error.is_empty():return error
 if path.is_empty():path=file_paths.get(d.id,folder().path_join(filename(d)))
 var temp=path+".tmp"
 var f=FileAccess.open(temp,FileAccess.WRITE)
 if f==null:return "无法写入卡组文件："+path.get_file()
 f.store_string(JSON.stringify({"format":"multicolor:arena/deck","version":1,"deck":clean_deck(d)},"  "))
 f.flush();var status=f.get_error();f.close()
 if status!=OK:return "卡组写入未完成，原文件已保留。"
 if FileAccess.file_exists(path) and DirAccess.copy_absolute(path,path+".bak")!=OK:return "无法备份原卡组。"
 if DirAccess.rename_absolute(temp,path)!=OK:return "无法替换卡组文件。"
 file_paths[d.id]=path
 return ""
static func delete_file(id: String) -> String:
 if not file_paths.has(id):return "卡组文件不存在，请重新进入组卡器。"
 var path=file_paths[id]
 if FileAccess.file_exists(path) and DirAccess.rename_absolute(path,path+".deleted")!=OK:return "无法删除卡组文件。"
 file_paths.erase(id)
 return ""




static func sort_deck(d: Dictionary, mode: String="类别"):
 var categories=["自机","单位","符卡","道具","结界"]
 for zone in ["main","side"]:
  d[zone].sort_custom(func(a,b):
   var x=CARDS[a]; var y=CARDS[b]
   var xn=CARDS[x.get("canonical_id",a)].name;var yn=CARDS[y.get("canonical_id",b)].name
   var cx=0; var cy=0
   for n in x.cost.values(): cx+=int(n)
   for n in y.cost.values(): cy+=int(n)
   if mode=="名字":
    if xn!=yn:return xn.naturalnocasecmp_to(yn)<0
    return a.naturalnocasecmp_to(b)<0
   if mode=="类别" and x.kind!=y.kind: return categories.find(x.kind)<categories.find(y.kind)
   if cx!=cy: return cx<cy
   if xn!=yn: return xn.naturalnocasecmp_to(yn)<0
   return a.naturalnocasecmp_to(b)<0)
