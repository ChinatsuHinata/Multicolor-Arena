extends RefCounted
## Trusted, stateless scripts only. This registry is not a GDScript sandbox.
const API_VERSION=5
const KINDS=["spell","activated","triggered","static","replacement"]
const EVENTS=["self_enter","self_leave","self_exiled_from_deck","cast","targeted","phase"]
static var _shared
var abilities: Dictionary={}
var kinds: Dictionary={}
var packs: Dictionary={}
var card_files: Array=[]
var error=""

static func shared():
 if _shared==null:
  _shared=load("res://scripts/rules/mod_registry.gd").new()
  _shared.discover("res://mods")
  for item in configuration():
   if item.get("enabled",false):
    _shared.error=_shared.register_pack(str(item.path))
    if not _shared.error.is_empty():break
 return _shared

static func config_path() -> String:return preload("res://scripts/portable_paths.gd").root().path_join("mods.json")
static func install_root() -> String:return preload("res://scripts/portable_paths.gd").root().path_join("mod")
static func save_configuration(config: Array) -> String:
 var path=config_path();var pending=path+".tmp"
 var file=FileAccess.open(pending,FileAccess.WRITE)
 if file==null:return "无法保存模组选择"
 file.store_string(JSON.stringify(config,"  "));file.flush()
 var error=file.get_error();file.close()
 if error==OK:error=DirAccess.rename_absolute(pending,path)
 if error!=OK:
  DirAccess.remove_absolute(pending)
  return "无法保存模组选择："+error_string(error)
 return ""
static func configuration() -> Array:
 if not FileAccess.file_exists(config_path()):return []
 var data=JSON.parse_string(FileAccess.get_file_as_string(config_path()))
 return data if data is Array else []

static func serializable(value: Variant,depth: int=0) -> bool:
 if depth>24:return false
 if value==null or value is bool or value is int or value is String or value is StringName:return true
 if value is float:return is_finite(value)
 if value is Array:
  if value.size()>1000:return false
  for child in value:
   if not serializable(child,depth+1):return false
  return true
 if value is Dictionary:
  if value.size()>1000:return false
  for key in value:
   if not (key is String or key is StringName) or not serializable(value[key],depth+1):return false
  return true
 return false

func discover(root: String):
 if not DirAccess.dir_exists_absolute(root):return
 var dirs=DirAccess.get_directories_at(root);dirs.sort()
 for dir in dirs:
  var path=root.path_join(dir).path_join("manifest.json")
  if not FileAccess.file_exists(path):continue
  var manifest=JSON.parse_string(FileAccess.get_file_as_string(path))
  if not manifest is Dictionary:error="模组清单格式错误："+path;return
  if not manifest.get("enabled",false):continue
  error=register_pack(path.get_base_dir())
  if not error.is_empty():return

func register_pack(root: String) -> String:
 var manifest_path=root.path_join("manifest.json")
 if not FileAccess.file_exists(manifest_path):return "找不到模组清单："+manifest_path
 var parser=JSON.new()
 if parser.parse(FileAccess.get_file_as_string(manifest_path))!=OK:return "模组清单 JSON 无效："+parser.get_error_message()
 var m=parser.data
 if not m is Dictionary or not serializable(m):return "模组清单格式错误"
 var pack_id=m.get("id","")
 if not pack_id is String or pack_id.is_empty() or pack_id.length()>64 or "/" in pack_id or "\\" in pack_id or ":" in pack_id:return "模组命名空间无效"
 if packs.has(pack_id):return "模组命名空间重复："+pack_id
 if not (m.get("api") is int or m.get("api") is float) or m.api!=int(m.api) or int(m.api) not in range(1,API_VERSION+1):return "模组接口版本不兼容："+pack_id
 if m.has("name") and (not m.name is String or m.name.strip_edges().is_empty()):return "模组名称无效"
 if m.has("enabled") and not m.enabled is bool:return "模组启用标记必须为 true 或 false"
 if not m.get("version") is String or m.version.is_empty():return "模组需要版本号"
 if not m.get("abilities") is Dictionary or not m.get("cards",[]) is Array:return "模组能力或卡牌清单无效"
 var staged={};var paths=[]
 for local_id in m.abilities:
  var d=m.abilities[local_id]
  if not local_id is String or local_id.is_empty() or local_id.length()>64 or "/" in local_id or "\\" in local_id or ":" in local_id:return "能力 ID 无效"
  if not d is Dictionary or d.get("kind","") not in KINDS:return "未支持的模组能力类型"
  if m.api==1 and d.kind in ["static","replacement"]:return "常驻和替代需要接口 v2"
  if not d.get("parameters",{}) is Dictionary:return "能力参数格式声明必须是对象"
  for key in d.get("parameters",{}):
   var field=d.parameters[key]
   if not field is Dictionary or field.get("type","") not in ["integer","number","string","boolean"] or not field.get("required",false) is bool:return "未支持的参数格式声明"
  if d.get("role","") not in ["main","leader"] or not d.get("text") is String:return "能力需要 role 和 text"
  if not d.get("zones") is Array or d.zones.is_empty():return "能力需要生效区域"
  for zone in d.zones:
   if zone not in ["field","grave","hand","leader","stack","deck","exile","palette"]:return "未支持的能力区域"
  if d.kind=="spell" and (d.zones!=["stack"] or d.role!="main"):return "符卡效果必须在 stack 生效"
  if d.kind=="activated" and "stack" in d.zones:return "v1 启动能力不支持堆叠区域"
  if d.kind=="triggered":
   if not d.get("optional") is bool or d.get("forced","") not in ["empty_event","skip"]:return "触发能力需要 optional 和 forced 策略"
   if not d.get("events") is Array:return "触发能力需要 events"
   for event in d.events:
    if event not in EVENTS:return "未支持的模组事件："+str(event)
  if d.kind=="replacement":
   if not d.get("changes") is Array or d.changes.is_empty():return "替代能力需要 changes"
   for change in d.changes:
    if change not in ["draw","cast_x"]:return "v2 替代支持 draw / cast_x"
  var path=local_path(root,d.get("script",""))
  if path.is_empty() or not path.ends_with(".gd"):return "能力脚本必须在模组目录内"
  var script=load(path) if path.begins_with("res://") else GDScript.new()
  if not path.begins_with("res://"):
   script.source_code=FileAccess.get_file_as_string(path)
   if script.reload()!=OK:return "外部能力脚本编译失败："+path
  if not script is GDScript or not script.can_instantiate():return "无法加载能力脚本："+path
  if script.get_instance_base_type()!="RefCounted":return "模组能力脚本必须继承 RefCounted"
  for method in script.get_script_method_list():
   if method.name=="_init" and method.args.size()>method.default_args.size():return "模组脚本构造函数不能要求参数"
  var instance=script.new()
  var methods=["validate"]+(["get_modifiers"] if d.kind=="static" else ["get_replacements"] if d.kind=="replacement" else ["describe_action","resolve"]+(["collect_triggers"] if d.kind=="triggered" else []))
  for method in methods:
   if not instance.has_method(method):return "能力缺少入口："+method
   var arguments=1 if method=="validate" else 2 if method=="describe_action" else 3
   for declaration in instance.get_method_list():
    if declaration.name==method and (arguments<declaration.args.size()-declaration.default_args.size() or arguments>declaration.args.size()):return "能力入口参数数量错误："+method
  staged[pack_id+"/"+local_id]={"descriptor":d.duplicate(true),"script":script,"pack_id":pack_id}
 for relative in m.get("cards",[]):
  var path=local_path(root,relative)
  if path.is_empty() or not path.ends_with(".json"):return "卡牌文件必须在模组目录内"
  paths.append({"path":path,"pack_id":pack_id,"root":root,"content":FileAccess.get_file_as_string(path)})
 if not m.get("state",{}) is Dictionary:return "模组状态声明无效"
 for key in m.get("state",{}):
  if not key is String or key.is_empty() or ":" in key:return "模组状态键无效"
  var schema=m.state[key]
  if not schema is Dictionary or schema.get("scope","") not in ["match","turn","source"] or schema.get("visibility","") not in ["public","owner","authority"]:return "模组状态必须声明 scope / visibility"
 abilities.merge(staged);card_files.append_array(paths)
 for value in staged.values():kinds[value.descriptor.kind]=true
 packs[pack_id]={"id":pack_id,"version":m.version,"api":int(m.api),"hash":content_hash(root),"state":m.get("state",{}).duplicate(true)}
 return ""

static func local_path(root: String,relative: Variant) -> String:
 if not relative is String or relative.is_empty() or relative.is_absolute_path() or "\\" in relative or ":" in relative or ".." in relative.split("/"):return ""
 var path=root.path_join(relative)
 return path if FileAccess.file_exists(path) or ResourceLoader.exists(path) else ""

static func content_hash(root: String) -> String:
 var lines=[]
 var files=DirAccess.get_files_at(root);files.sort()
 for file in files:
  if file.ends_with(".uid") or file.ends_with(".import"):continue
  lines.append(file+":"+FileAccess.get_sha256(root.path_join(file)))
 var dirs=DirAccess.get_directories_at(root);dirs.sort()
 for dir in dirs:
  if not dir.begins_with("."):lines.append(dir+"/"+content_hash(root.path_join(dir)))
 return "\n".join(lines).sha256_text()

func manifest() -> Array:
 var result=[];var ids=packs.keys();ids.sort()
 for id in ids:
  var item=packs[id].duplicate(true);item.erase("state");result.append(item)
 return result

func descriptor(id: String) -> Dictionary:
 return abilities[id].descriptor.duplicate(true) if abilities.has(id) else {}

func invoke(id: String,method: String,args: Array) -> Variant:
 # Each invocation gets a fresh object; persistent state belongs to the engine.
 return abilities[id].script.new().callv(method,args)

func validate_binding(binding: Dictionary,kind: String) -> String:
 if not binding.get("实例键") is String or binding["实例键"].is_empty() or binding["实例键"].length()>64 or ":" in binding["实例键"]:return "模组能力需要唯一实例键（至多64字且不能含冒号）"
 var params=binding.get("参数",{})
 if not params is Dictionary or not serializable(params):return "模组能力参数必须可序列化"
 var id=params.get("能力","")
 if not id is String or not abilities.has(id):return "未登记的模组能力："+str(id)
 var d=descriptor(id)
 if d.kind=="spell" and kind!="符卡":return "模组能力类型与卡牌类别不符"
 for key in d.get("parameters",{}):
  var field=d.parameters[key]
  if not params.has(key):
   if field.get("required",false):return "缺少能力参数："+key
   continue
  var value=params[key];var type=field.type
  if type=="integer" and (not (value is int or value is float) or value!=int(value)) or type=="number" and not (value is int or value is float) or type=="string" and not value is String or type=="boolean" and not value is bool:return "能力参数类型错误："+key
 var result=invoke(id,"validate",[params.duplicate(true)])
 return result if result is String else "validate 必须返回错误文字或空串"
