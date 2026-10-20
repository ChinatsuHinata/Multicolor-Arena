extends RefCounted
## Keep release snapshots and delivery receipts outside the installed game.
const CATALOGUE_PATH="res://data/announcements.json"
var path="user://announcements.json"
var active_version=""
var history: Array=[]
var pushed_versions: Array=[]
var read_versions: Array=[]
var latest_ids: Array=[]
var last_error=""

func initialize(version: String,storage_path: String,catalogue_path: String=CATALOGUE_PATH):
 path=storage_path;active_version=version
 history=[];pushed_versions=[];read_versions=[];latest_ids=[];last_error=""
 if FileAccess.file_exists(path):
  var saved=JSON.parse_string(FileAccess.get_file_as_string(path))
  if saved is Dictionary and saved.get("schema")==1:
   for entry in saved.get("history",[]) if saved.get("history") is Array else []:
    if valid_entry(entry) and find_id(entry_id(entry)).is_empty():history.append(entry.duplicate(true))
   pushed_versions=string_array(saved.get("pushed_versions"))
   read_versions=string_array(saved.get("read_versions"))
  else:last_error="公告记录无法读取，将从随游戏提供的公告恢复。"
 if not FileAccess.file_exists(catalogue_path):return
 var catalogue=JSON.parse_string(FileAccess.get_file_as_string(catalogue_path))
 if not catalogue is Dictionary or catalogue.get("schema")!=1 or not catalogue.get("announcements") is Array:
  last_error="公告目录格式无效。";return
 var removed=string_array(catalogue.get("removed_ids"))
 var migrated=false
 for i in range(history.size()-1,-1,-1):
  if entry_id(history[i]) in removed:history.remove_at(i);migrated=true
 for id in removed:
  if id in pushed_versions or id in read_versions:migrated=true
  pushed_versions.erase(id);read_versions.erase(id)
 var latest_version=""
 var declared_ids: Array=[]
 for entry in catalogue.announcements:
  if not valid_entry(entry):continue
  declared_ids.append(entry_id(entry))
  if entry_id(entry) in removed or compare_versions(entry.version,active_version)>0:continue
  var archived=find_id(entry_id(entry))
  if archived.is_empty():history.append(entry.duplicate(true))
  elif not archived.has("image") and entry.get("image") is String:
   # Supplement old local snapshots without changing their delivery receipts.
   archived.image=entry.image
   if entry.get("image_region") is Array:archived.image_region=entry.image_region.duplicate()
  if latest_version.is_empty() or compare_versions(entry.version,latest_version)>0:
   latest_version=entry.version;latest_ids=[]
  if entry.version==latest_version:latest_ids.append(entry_id(entry))
 # Delivery belongs to the announcement, so a content-free patch adds no new ID.
 if migrate_reused_entries(declared_ids,removed):migrated=true
 history.sort_custom(func(a,b):
  var compared=compare_versions(a.version,b.version)
  return compared>0 if compared!=0 else int(a.get("order",0))<int(b.get("order",0)))
 if migrated:save()

func migrate_reused_entries(declared_ids: Array,removed: Array) -> bool:
 var migrated=false
 var originals=history.duplicate()
 originals.sort_custom(func(a,b):return compare_versions(a.version,b.version)<0)
 for entry in originals:
  var id=entry_id(entry)
  if id in declared_ids:continue
  # Previous clients prefixed explicit IDs with the effective patch version.
  var source_id=id.trim_prefix(entry.version+":")
  if source_id==id:
   if id!=entry.version:continue
   # Older catalogues used the version as ID; their copies kept the same text.
   for original in originals:
    if original.has("id") or compare_versions(original.version,entry.version)>=0:continue
    if original.title==entry.title and original.body==entry.body and original.get("date","")==entry.get("date",""):
     source_id=entry_id(original);break
  if source_id==id:continue
  var source=find_id(source_id)
  if source.is_empty() and source_id not in removed:continue
  if not source.is_empty() and compare_versions(source.version,entry.version)>=0:continue
  for receipts in [pushed_versions,read_versions]:
   if id not in receipts:continue
   receipts.erase(id)
   if source_id not in removed and source_id not in receipts:receipts.append(source_id)
  history.erase(entry);migrated=true
 return migrated

static func entry_id(entry: Dictionary) -> String:
 return str(entry.get("id",entry.version))

func find_id(id: String) -> Dictionary:
 for entry in history:
  if entry_id(entry)==id:return entry
 return {}

static func valid_entry(entry) -> bool:
 return entry is Dictionary and entry.get("version") is String and not entry.version.is_empty() and entry.get("id",entry.version) is String and not entry.get("id",entry.version).is_empty() and entry.get("title") is String and not entry.title.is_empty() and entry.get("body") is String and not entry.body.is_empty() and entry.get("date","") is String

static func string_array(value) -> Array:
 var result=[]
 if value is Array:
  for entry in value:
   if entry is String and not entry.is_empty() and entry not in result:result.append(entry)
 return result

static func compare_versions(a: String,b: String) -> int:
 var left=a.get_slice("-",0).split(".");var right=b.get_slice("-",0).split(".")
 for i in range(maxi(left.size(),right.size())):
  var x=int(left[i]) if i<left.size() else 0
  var y=int(right[i]) if i<right.size() else 0
  if x!=y:return 1 if x>y else -1
 var left_suffix=a.get_slice("-",1);var right_suffix=b.get_slice("-",1)
 if left_suffix==right_suffix:return 0
 if left_suffix.is_empty():return 1
 if right_suffix.is_empty():return -1
 return 1 if left_suffix>right_suffix else -1

func find_version(version: String) -> Dictionary:
 for entry in history:
  if entry.version==version:return entry
 return {}

func pending() -> Dictionary:
 for entry in history:
  var id=entry_id(entry)
  if id in latest_ids and id not in pushed_versions and id not in read_versions:return entry
 return {}

func unread_count() -> int:
 return history.filter(func(entry):return entry_id(entry) not in read_versions).size()

func record_opened(id: String,pushed: bool=false) -> bool:
 if find_id(id).is_empty():return false
 if id not in read_versions:read_versions.append(id)
 if pushed and id not in pushed_versions:pushed_versions.append(id)
 return save()

func save() -> bool:
 last_error=""
 var destination=ProjectSettings.globalize_path(path)
 if DirAccess.make_dir_recursive_absolute(destination.get_base_dir())!=OK:
  last_error="无法创建公告保存目录。";return false
 var file=FileAccess.open(destination+".tmp",FileAccess.WRITE)
 if file==null:last_error="无法保存公告记录。";return false
 file.store_string(JSON.stringify({"schema":1,"history":history,"pushed_versions":pushed_versions,"read_versions":read_versions}," "))
 file.flush();var error=file.get_error();file.close()
 if error!=OK or DirAccess.rename_absolute(destination+".tmp",destination)!=OK:
  last_error="无法写入公告记录。";return false
 return true
