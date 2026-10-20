extends RefCounted
## Local gallery preferences are separate from shared deck contents.
const Store=preload("res://scripts/deck_store.gd")
const SORT_MODES=["usage","name","leader"]
var sort_mode="usage"
var records={}
var load_error=""

func path() -> String:return Store.folder().path_join(".library.json")

func load_data() -> String:
 sort_mode="usage";records={};load_error=""
 if not FileAccess.file_exists(path()):return ""
 var data=JSON.parse_string(FileAccess.get_file_as_string(path()))
 if not data is Dictionary or not data.get("decks",{}) is Dictionary:
  load_error="套牌收藏与使用记录读取失败。"
  return load_error
 if data.get("sort_mode","") in SORT_MODES:sort_mode=data.sort_mode
 for id in data.get("decks",{}):
  var record=data.decks[id]
  if not record is Dictionary:continue
  var count=record.get("usage_count",0)
  records[str(id)]={"favorite":record.get("favorite",false)==true,"usage_count":maxi(0,int(count)) if typeof(count) in [TYPE_INT,TYPE_FLOAT] else 0,"last_game_id":str(record.get("last_game_id",""))}
 return ""

func save_data() -> String:
 if not load_error.is_empty():return load_error
 var error=Store.Paths.initialize()
 if not error.is_empty():return error
 var destination=path()
 var temporary=destination+".tmp"
 var file=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:return "无法保存套牌收藏与使用记录。"
 file.store_string(JSON.stringify({"version":1,"sort_mode":sort_mode,"decks":records},"  "))
 file.flush();var status=file.get_error();file.close()
 if status!=OK:return "套牌收藏与使用记录写入未完成。"
 if FileAccess.file_exists(destination) and DirAccess.copy_absolute(destination,destination+".bak")!=OK:return "无法备份套牌收藏与使用记录。"
 if DirAccess.rename_absolute(temporary,destination)!=OK:return "无法替换套牌收藏与使用记录。"
 return ""

func favorite(id: String) -> bool:return records.get(id,{}).get("favorite",false)
func usage_count(id: String) -> int:return records.get(id,{}).get("usage_count",0)

func set_sort(mode: String) -> String:
 if mode not in SORT_MODES:return "无效的套牌排序方式。"
 var previous=sort_mode;sort_mode=mode
 var error=save_data()
 if not error.is_empty():sort_mode=previous
 return error

func set_favorite(id: String,value: bool) -> String:
 var previous=records.duplicate(true)
 var record=records.get(id,{}).duplicate(true);record.favorite=value;records[id]=record
 var error=save_data()
 if not error.is_empty():records=previous
 return error

func record_usage(ids: Array,game_id: String) -> String:
 if game_id.is_empty():return ""
 var previous=records.duplicate(true)
 var changed=false
 for id in ids:
  if str(id).is_empty():continue
  var record=records.get(str(id),{}).duplicate(true)
  # Repeated snapshots, reconnects and both local seats cannot count a game twice.
  if record.get("last_game_id","")==game_id:continue
  record.usage_count=usage_count(str(id))+1;record.last_game_id=game_id;records[str(id)]=record
  changed=true
 if not changed:return ""
 var error=save_data()
 if not error.is_empty():records=previous
 return error

func comes_before(a: Dictionary,b: Dictionary) -> bool:
 var a_id=str(a.id);var b_id=str(b.id)
 if favorite(a_id)!=favorite(b_id):return favorite(a_id)
 if sort_mode=="usage" and usage_count(a_id)!=usage_count(b_id):return usage_count(a_id)>usage_count(b_id)
 if sort_mode=="leader":
  var a_leader=str(Store.CARDS.get(a.leader,{}).get("name",""))
  var b_leader=str(Store.CARDS.get(b.leader,{}).get("name",""))
  var leader_order=a_leader.naturalnocasecmp_to(b_leader)
  if leader_order!=0:return leader_order<0
 var name_order=str(a.name).naturalnocasecmp_to(str(b.name))
 if name_order!=0:return name_order<0
 return a_id.naturalnocasecmp_to(b_id)<0
