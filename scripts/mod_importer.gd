extends RefCounted
## ZIP packages are staged and validated before any installed pack is changed.
const Registry=preload("res://scripts/rules/mod_registry.gd")
const Database=preload("res://scripts/card_database.gd")
const Store=preload("res://scripts/deck_store.gd")
const MAX_ARCHIVE_BYTES=256*1024*1024
const MAX_FILE_BYTES=64*1024*1024
const MAX_TOTAL_BYTES=512*1024*1024
const MAX_FILES=2048

static func valid_component(value: String) -> bool:
 if value.is_empty() or value.begins_with(".") or value.ends_with(".") or value.ends_with(" "):return false
 for character in value:
  if character.unicode_at(0)<32 or character in '<>:"/\\|?*':return false
 var stem=value.get_slice(".",0).to_upper()
 return stem not in ["CON","PRN","AUX","NUL","COM1","COM2","COM3","COM4","COM5","COM6","COM7","COM8","COM9","LPT1","LPT2","LPT3","LPT4","LPT5","LPT6","LPT7","LPT8","LPT9"]

static func valid_relative(path: String) -> bool:
 if path.length()>240 or path.is_absolute_path():return false
 for part in path.split("/"):
  if not valid_component(part):return false
 return true

static func normalized_path(path: String) -> String:
 var result=ProjectSettings.globalize_path(path).replace("\\","/").simplify_path().trim_suffix("/")
 return result.to_lower() if OS.get_name()=="Windows" else result

static func is_link(path: String) -> bool:
 var parent=DirAccess.open(path.get_base_dir())
 return parent!=null and parent.is_link(path.get_file())

static func managed_path(path: String) -> bool:
 return normalized_path(path.get_base_dir())==normalized_path(Registry.install_root()) and valid_component(path.get_file()) and not is_link(path) and not is_link(Registry.install_root())

static func installed_match(id: String,config: Array) -> Dictionary:
 var roots=["res://mods",Registry.install_root()]
 var paths=[]
 for root in roots:
  if not DirAccess.dir_exists_absolute(root):continue
  for directory in DirAccess.get_directories_at(root):
   if not directory.begins_with("."):paths.append(root.path_join(directory))
 for item in config:
  if item is Dictionary and item.get("path") is String:paths.append(item.path)
 var matches={}
 for path in paths:
  var data=JSON.parse_string(FileAccess.get_file_as_string(path.path_join("manifest.json"))) if FileAccess.file_exists(path.path_join("manifest.json")) else null
  if data is Dictionary and str(data.get("id","")).to_lower()==id.to_lower():matches[normalized_path(path)]={"path":path,"manifest":data}
 if matches.size()>1:return {"error":"相同模组存在多个副本，请先删除多余登记："+id}
 if matches.is_empty():return {}
 var result=matches.values()[0]
 if normalized_path(result.path).begins_with(normalized_path("res://mods")+"/"):return {"error":"相同模组为内置模组，无法替换："+id}
 if result.manifest.id!=id:return {"error":"相同模组 ID 大小写不一致："+id}
 return result

static func version_parts(value: String) -> Dictionary:
 var expression=RegEx.new()
 expression.compile("^[vV]?([0-9]+(?:\\.[0-9]+)*)(?:-([0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*))?(?:\\+[0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*)?$")
 var found=expression.search(value)
 return {"numbers":found.get_string(1).split("."),"pre":found.get_string(2)} if found!=null else {}

static func compare_number(a: String,b: String) -> int:
 a=a.lstrip("0");b=b.lstrip("0")
 if a.length()!=b.length():return 1 if a.length()>b.length() else -1
 return 0 if a==b else 1 if a>b else -1

static func compare_versions(incoming: String,installed: String) -> Dictionary:
 var a=version_parts(incoming);var b=version_parts(installed)
 if a.is_empty() or b.is_empty():return {"error":"无法比较模组版本，请使用数字点分版本号（例如 1.2.3 或 1.2.3-beta.1）"}
 for index in range(maxi(a.numbers.size(),b.numbers.size())):
  var order=compare_number(a.numbers[index] if index<a.numbers.size() else "0",b.numbers[index] if index<b.numbers.size() else "0")
  if order!=0:return {"order":order}
 if a.pre==b.pre:return {"order":0}
 if a.pre.is_empty() or b.pre.is_empty():return {"order":1 if a.pre.is_empty() else -1}
 var left=a.pre.split(".");var right=b.pre.split(".")
 for index in range(mini(left.size(),right.size())):
  var x=left[index];var y=right[index]
  if x==y:continue
  var numeric_x=x.is_valid_int() and not x.begins_with("-");var numeric_y=y.is_valid_int() and not y.begins_with("-")
  var order=compare_number(x,y) if numeric_x and numeric_y else (-1 if numeric_x else 1) if numeric_x!=numeric_y else (1 if x>y else -1)
  if order!=0:return {"order":order}
 return {"order":0 if left.size()==right.size() else 1 if left.size()>right.size() else -1}

static func apply_configuration(config: Array) -> String:
 var registry=Registry.new();registry.discover("res://mods")
 if not registry.error.is_empty():return registry.error
 for item in config:
  if not item is Dictionary or not item.get("path") is String or not item.get("enabled") is bool:return "模组配置格式错误"
  if item.enabled:
   var error=registry.register_pack(item.path)
   if not error.is_empty():return error
 var old=Registry._shared;var old_error=Database.last_error;Registry._shared=registry
 var cards=Database.load_cards(true,config);var error=Database.last_error
 Registry._shared=old;Database.last_error=old_error
 if cards.is_empty():return error
 error=Registry.save_configuration(config)
 if not error.is_empty():return error
 Registry._shared=registry;Store.CARDS=cards;Database.last_error=""
 return ""

static func delete_mod(path: String,config: Array) -> Dictionary:
 var updated=[];var found=false
 for item in config:
  if item is Dictionary and item.get("path") is String and normalized_path(item.path)==normalized_path(path):found=true
  else:updated.append(item)
 if not found:return {"error":"模组登记已改变，请刷新后重试"}
 var staging="";var removed_files=false
 if managed_path(path) and DirAccess.dir_exists_absolute(path):
  staging=Registry.install_root().path_join(".import-delete-"+str(Time.get_ticks_usec()))
  if DirAccess.make_dir_absolute(staging)!=OK:return {"error":"无法创建模组删除临时目录"}
  if DirAccess.rename_absolute(path,staging.path_join("previous"))!=OK:
   remove_staging(staging)
   return {"error":"无法删除模组文件，请关闭占用文件后重试"}
  removed_files=true
 var error=apply_configuration(updated)
 if not error.is_empty():
  if removed_files and DirAccess.rename_absolute(staging.path_join("previous"),path)!=OK:return {"error":error+"；旧模组保留在："+staging.path_join("previous")}
  if not staging.is_empty():remove_staging(staging)
  return {"error":error}
 if not staging.is_empty():remove_staging(staging)
 return {"removed_files":removed_files}

static func import_file(source: String,config: Array) -> Dictionary:
 var input=FileAccess.open(source,FileAccess.READ)
 if input==null:return {"error":"无法读取模组文件"}
 if input.get_length()==0 or input.get_length()>MAX_ARCHIVE_BYTES:return {"error":"模组 ZIP 文件为空或超过 256 MiB"}
 var root=Registry.install_root()
 if DirAccess.make_dir_recursive_absolute(root)!=OK:return {"error":"无法创建本地 mod 文件夹"}
 var staging=root.path_join(".import-"+str(Time.get_ticks_usec()))
 if DirAccess.make_dir_absolute(staging)!=OK:return {"error":"无法创建模组临时目录"}
 # Copy through FileAccess so Android document-provider URIs work with ZIPReader.
 var archive=staging.path_join("package.zip")
 var output=FileAccess.open(archive,FileAccess.WRITE)
 if output==null:
  remove_staging(staging)
  return {"error":"无法写入模组临时文件"}
 while input.get_position()<input.get_length():
  var chunk=input.get_buffer(mini(1024*1024,input.get_length()-input.get_position()))
  if chunk.is_empty():
   input.close();output.close();remove_staging(staging)
   return {"error":"模组文件读取中断"}
  output.store_buffer(chunk)
 output.flush()
 var write_error=output.get_error();output.close();input.close()
 var result={"error":"无法复制模组文件"} if write_error!=OK else install_archive(archive,staging,config)
 if not result.get("preserve_staging",false):remove_staging(staging)
 return result

static func archive_index(path: String) -> Dictionary:
 # Inspect the central directory before decompressing, including declared sizes.
 var file=FileAccess.open(path,FileAccess.READ)
 var length=file.get_length();var tail_size=mini(length,65557)
 file.seek(length-tail_size)
 var tail=file.get_buffer(tail_size);var end=-1
 for offset in range(tail.size()-22,-1,-1):
  if tail.decode_u32(offset)==0x06054b50 and offset+22+tail.decode_u16(offset+20)==tail.size():
   end=offset;break
 if end<0:return {"error":"不是完整有效的 ZIP 模组文件"}
 var count=tail.decode_u16(end+10);var size=tail.decode_u32(end+12);var start=tail.decode_u32(end+16)
 if tail.decode_u16(end+4)!=0 or tail.decode_u16(end+6)!=0 or tail.decode_u16(end+8)!=count or count==0 or count>MAX_FILES or start+size!=length-tail_size+end:return {"error":"ZIP 目录无效、文件过多或使用了不支持的分卷格式"}
 var entries={};var seen={};var total=0
 file.seek(start)
 for index in range(count):
  var header=file.get_buffer(46)
  if header.size()!=46 or header.decode_u32(0)!=0x02014b50:return {"error":"ZIP 文件目录损坏"}
  var flags=header.decode_u16(8);var method=header.decode_u16(10)
  var compressed=header.decode_u32(20);var expanded=header.decode_u32(24)
  var name_length=header.decode_u16(28);var extra=header.decode_u16(30);var comment=header.decode_u16(32)
  var attributes=header.decode_u32(38);var local=header.decode_u32(42)
  if flags&1 or method not in [0,8] or header.decode_u16(34)!=0 or ((attributes>>16)&0xf000)==0xa000 or local+30+compressed>start:return {"error":"ZIP 含加密、链接或不支持的文件格式"}
  var name_bytes=file.get_buffer(name_length);var name=name_bytes.get_string_from_utf8()
  var directory=name.ends_with("/");var relative=name.trim_suffix("/")
  if name_bytes.size()!=name_length or not valid_relative(relative):return {"error":"ZIP 内含不规范或越界路径："+name}
  var key=relative.to_lower()
  if seen.has(key):return {"error":"ZIP 内含重复文件或大小写冲突："+name}
  seen[key]=directory
  if expanded>MAX_FILE_BYTES or directory and expanded!=0:return {"error":"ZIP 单个文件超过 64 MiB 或目录无效"}
  total+=expanded
  if total>MAX_TOTAL_BYTES:return {"error":"ZIP 解压后超过 512 MiB"}
  entries[name]={"size":expanded,"crc":header.decode_u32(16),"directory":directory}
  file.seek(file.get_position()+extra+comment)
  if file.get_position()>start+size:return {"error":"ZIP 文件目录越界"}
 if file.get_position()!=start+size:return {"error":"ZIP 文件目录长度错误"}
 for key in seen:
  var parent=key.get_base_dir()
  while not parent.is_empty():
   if seen.has(parent) and not seen[parent]:return {"error":"ZIP 中文件与目录冲突："+key}
   parent=parent.get_base_dir()
 return {"entries":entries}

static func install_archive(archive: String,staging: String,config: Array) -> Dictionary:
 var inspected=archive_index(archive)
 if inspected.has("error"):return inspected
 var entries=inspected.entries;var zip=ZIPReader.new()
 if zip.open(archive)!=OK:return {"error":"无法打开 ZIP 模组文件"}
 var result=extract_pack(zip,entries,staging,config)
 zip.close()
 return result

static func extract_pack(zip: ZIPReader,entries: Dictionary,staging: String,config: Array) -> Dictionary:
 var names=zip.get_files();var manifests=[]
 if names.size()!=entries.size():return {"error":"ZIP 文件目录不一致"}
 for name in names:
  if not entries.has(name):return {"error":"ZIP 文件目录不一致"}
  if name.get_file()=="manifest.json":manifests.append(name)
 if manifests.size()!=1:return {"error":"模组 ZIP 必须包含且只包含一个 manifest.json"}
 var manifest_path=manifests[0];var prefix=manifest_path.trim_suffix("manifest.json")
 if prefix.trim_suffix("/").contains("/"):return {"error":"manifest.json 必须位于 ZIP 根目录或第一层模组文件夹"}
 var bytes=zip.read_file(manifest_path,true)
 if bytes.size()!=entries[manifest_path].size:return {"error":"模组清单损坏"}
 var parser=JSON.new()
 if parser.parse(bytes.get_string_from_utf8())!=OK:return {"error":"模组清单 JSON 无效："+parser.get_error_message()}
 var manifest=parser.data
 if not manifest is Dictionary or not manifest.get("id") is String or manifest.id.length()>64 or not valid_component(manifest.id):return {"error":"模组清单格式错误或 ID 不规范"}
 var id=manifest.id
 var installed=installed_match(id,config)
 if installed.has("error"):return installed
 if not manifest.get("version") is String:return {"error":"模组需要版本号"}
 if not installed.is_empty():
  var compared=compare_versions(manifest.version,str(installed.manifest.get("version","")))
  if compared.has("error"):return compared
  if compared.order<=0:return {"error":"相同模组已安装此版本："+manifest.version if compared.order==0 else "模组版本较旧，已保留当前版本：%s（导入 %s）" % [installed.manifest.version,manifest.version]}
 var destination=installed.path if not installed.is_empty() and managed_path(installed.path) else Registry.install_root().path_join(id)
 var replacing=not installed.is_empty() and managed_path(installed.path)
 if (FileAccess.file_exists(destination) or DirAccess.dir_exists_absolute(destination)) and not replacing:return {"error":"相同模组目录已存在，无法安全替换："+id}
 var pack=staging.path_join("pack")
 DirAccess.make_dir_absolute(pack)
 var hashes=HashingContext.new()
 for name in names:
  if entries[name].directory:
   if not prefix.is_empty() and name!=prefix and not name.begins_with(prefix):return {"error":"ZIP 包含模组文件夹之外的目录"}
   continue
  if not name.begins_with(prefix):return {"error":"ZIP 包含模组文件夹之外的文件"}
  var relative=name.trim_prefix(prefix)
  if not valid_relative(relative):return {"error":"模组文件路径不规范："+relative}
  var data=zip.read_file(name,true)
  if data.size()!=entries[name].size:return {"error":"ZIP 文件损坏或解压失败："+name}
  if crc32(data)!=entries[name].crc:return {"error":"ZIP 文件校验失败："+name}
  var target=pack.path_join(relative)
  if DirAccess.make_dir_recursive_absolute(target.get_base_dir())!=OK:return {"error":"无法创建模组子目录"}
  var file=FileAccess.open(target,FileAccess.WRITE)
  if file==null:return {"error":"无法写入模组文件："+relative}
  file.store_buffer(data);file.flush();var error=file.get_error();file.close()
  if error!=OK:return {"error":"模组文件写入失败："+relative}
  hashes.start(HashingContext.HASH_SHA256);hashes.update(data)
  if FileAccess.get_sha256(target)!=hashes.finish().hex_encode():return {"error":"模组文件写入校验失败："+relative}
 var registry=Registry.new();var error=registry.register_pack(pack)
 if not error.is_empty():return {"error":"模组不规范："+error}
 var previous=Registry._shared;var previous_error=Database.last_error
 Registry._shared=registry
 var cards=Database.load_cards();error=Database.last_error
 Registry._shared=previous;Database.last_error=previous_error
 if cards.is_empty():return {"error":"模组卡牌不规范："+error}
 # Keep the previous directory until configuration and the active library commit.
 var backup=staging.path_join("previous")
 if replacing and DirAccess.rename_absolute(destination,backup)!=OK:return {"error":"无法替换旧模组，请关闭占用文件后重试"}
 if DirAccess.rename_absolute(pack,destination)!=OK:
  if replacing and DirAccess.rename_absolute(backup,destination)!=OK:return {"error":"安装失败，旧模组保留在："+backup,"preserve_staging":true}
  return {"error":"无法安装模组到本地 mod 文件夹"}
 var updated=config.duplicate(true);var configured=false;var enabled=false
 for item in updated:
  if not installed.is_empty() and item is Dictionary and item.get("path") is String and normalized_path(item.path)==normalized_path(installed.path):
   item.path=destination;enabled=enabled or item.get("enabled",false);configured=true
 if not configured:updated.append({"path":destination,"enabled":false})
 error=apply_configuration(updated)
 if not error.is_empty():
  if DirAccess.rename_absolute(destination,pack)!=OK:return {"error":error+"；新旧模组文件保留在："+staging,"preserve_staging":true}
  if replacing and DirAccess.rename_absolute(backup,destination)!=OK:return {"error":error+"；旧模组保留在："+backup,"preserve_staging":true}
  return {"error":error}
 return {"id":id,"name":str(manifest.get("name",id)),"path":destination,"updated":not installed.is_empty(),"previous_path":installed.get("path",""),"previous_version":str(installed.get("manifest",{}).get("version","")),"version":manifest.version,"enabled":enabled}

static func remove_staging(path: String):
 # Only our unique temporary import directory may be recursively removed.
 if path.get_base_dir()!=Registry.install_root() or not path.get_file().begins_with(".import-"):return
 remove_tree(path)

static var crc_table: Array=make_crc_table()
static func make_crc_table() -> Array:
 var table=[]
 for index in range(256):
  var value=index
  for bit in range(8):value=(value>>1)^0xedb88320 if value&1 else value>>1
  table.append(value)
 return table

static func crc32(data: PackedByteArray) -> int:
 var value=0xffffffff
 for byte in data:value=crc_table[(value^byte)&255]^(value>>8)
 return value^0xffffffff

static func remove_tree(path: String):
 if is_link(path):DirAccess.remove_absolute(path);return
 for directory in DirAccess.get_directories_at(path):remove_tree(path.path_join(directory))
 for file in DirAccess.get_files_at(path):DirAccess.remove_absolute(path.path_join(file))
 DirAccess.remove_absolute(path)
