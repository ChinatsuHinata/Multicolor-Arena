extends Node

signal completed(result: Dictionary)
signal download_started(total_bytes: int, patch_count: int)
signal download_progress(downloaded_bytes: int, total_bytes: int, stage: String)

const BASE_VERSION="1.2.7.1"
const ORIGIN="http://8.137.122.187:47862"
const Manifest=preload("res://scripts/pck_update_manifest.gd")
const MAX_MANIFEST_BYTES=Manifest.MAX_MANIFEST_BYTES

var origin=ORIGIN
var manifest_url=""
var manager
var active_version=""
var busy=false
var download_path=""
var expected: Dictionary={}
var request_node: HTTPRequest
var queue: Array=[]
var downloaded_paths: Array=[]
var download_index=0
var tried_legacy=false
var total_download_bytes=0
var finished_download_bytes=0

func _process(_delta: float) -> void:
 if not busy or download_path.is_empty() or not is_instance_valid(request_node):return
 download_progress.emit(mini(total_download_bytes,finished_download_bytes+request_node.get_downloaded_bytes()),total_download_bytes,"正在下载补丁 %d/%d" % [download_index+1,queue.size()])

func check_for_update(patch_manager) -> void:
 if busy:return
 manager=patch_manager
 active_version=manager.installed_version()
 if manager.base_version!=BASE_VERSION and not manager._newer(manager.base_version,BASE_VERSION):return
 if not manager.startup_error.is_empty():return
 busy=true
 tried_legacy=false
 _request(_manifest_url(),"",_manifest_received)

func _manifest_url() -> String:
 return manifest_url if not manifest_url.is_empty() else origin+"/updates/pck/chain.json"

func _request(url: String,file_path: String,callback: Callable) -> void:
 request_node=HTTPRequest.new()
 request_node.max_redirects=0
 request_node.timeout=20.0 if file_path.is_empty() else 600.0
 if file_path.is_empty():request_node.body_size_limit=MAX_MANIFEST_BYTES
 else:
  request_node.download_file=file_path
  request_node.body_size_limit=int(expected.size)
 add_child(request_node)
 request_node.request_completed.connect(func(result,code,_headers,body):
  var old=request_node
  request_node=null
  old.queue_free()
  callback.call(result,code,body))
 var err=request_node.request(url)
 if err!=OK:
  request_node.queue_free()
  request_node=null
  _finish({"error":"无法连接补丁服务器。"})

func _manifest_received(result: int,code: int,body: PackedByteArray) -> void:
 if result==HTTPRequest.RESULT_SUCCESS and code==404:
  if not tried_legacy and manifest_url.is_empty():
   tried_legacy=true
   _request(origin+"/updates/pck/latest.json","",_manifest_received)
   return
  _finish({"up_to_date":true})
  return
 if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
  _finish({"error":"无法获取云端补丁清单。"})
  return
 var payload=_verify_manifest(body)
 if payload.has("error"):
  _finish(payload)
  return
 if payload.get("base")!=BASE_VERSION or not payload.get("version") is String or not manager._newer(payload.version,BASE_VERSION):
  _finish({"error":"云端补丁版本信息无效。"})
  return
 if not manager._newer(payload.version,active_version):
  _finish({"up_to_date":true})
  return
 var plan=_plan(payload)
 if plan.has("error"):
  _finish(plan)
  return
 queue=plan.patches
 download_index=0
 total_download_bytes=0
 finished_download_bytes=0
 for patch in queue:total_download_bytes+=int(patch.size)
 var folder=manager.patch_dir
 if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))!=OK:
  _finish({"error":"无法创建补丁下载目录。"})
  return
 download_started.emit(total_download_bytes,queue.size())
 _download_next()

func _verify_manifest(bytes: PackedByteArray) -> Dictionary:
 return Manifest.verify(bytes,manager._public_key())

func _plan(payload: Dictionary) -> Dictionary:
 var edges=payload.get("patches",[{"from":BASE_VERSION,"to":payload.version,manager.platform():payload.get(manager.platform())}])
 if not edges is Array or edges.is_empty() or edges.size()>Manifest.MAX_PATCHES:
  return {"error":"云端补丁版本链无效。"}
 var available=[]
 var seen={}
 for edge in edges:
  if not edge is Dictionary or not edge.get("from") is String or not edge.get("to") is String:
   return {"error":"云端补丁版本链无效。"}
  if not manager._newer(edge.to,edge.from) or manager._newer(BASE_VERSION,edge.from) or manager._newer(edge.to,payload.version):
   return {"error":"云端补丁版本链包含无效版本。"}
  var id=edge.from+"->"+edge.to
  if seen.has(id):return {"error":"云端补丁版本链包含重复路径。"}
  seen[id]=true
  var asset=edge.get(manager.platform())
  if not asset is Dictionary or not asset.get("url") is String or not asset.get("sha256") is String or (not asset.get("size") is float and not asset.get("size") is int):
   return {"error":"云端补丁文件信息无效。"}
  if asset.sha256.length()!=64 or not asset.sha256.is_valid_hex_number(false) or asset.size!=int(asset.size) or int(asset.size)<=4096:
   return {"error":"云端补丁文件大小或哈希无效。"}
  var prefix=origin+"/updates/pck/"+edge.to+"/MulticolorArena-%s-to-%s-%s" % [edge.from,edge.to,manager.platform()]
  if asset.url!=prefix+".pck" and asset.url!=prefix+"-"+asset.sha256.to_lower()+".pck":
   return {"error":"云端补丁下载地址无效。"}
  available.append({"from":edge.from,"to":edge.to,"url":asset.url,"size":int(asset.size),"sha256":asset.sha256.to_lower()})
 # Dijkstra over strictly increasing versions; choose the least download bytes.
 # A cumulative patch may start from the installed application's base.
 var costs={active_version:0,manager.base_version:0}
 var previous={}
 var visited={}
 for _step in range(available.size()+2):
  var current=""
  for version in costs:
   if not visited.has(version) and (current.is_empty() or costs[version]<costs[current]):current=version
  if current.is_empty():break
  if current==payload.version:
   var path=[]
   while previous.has(current):
    var edge=previous[current]
    path.push_front(edge)
    current=edge.from
   return {"patches":path}
  visited[current]=true
  for edge in available:
   if edge.from!=current or not manager._newer(edge.to,active_version):continue
   var cost=costs[current]+edge.size
   if not costs.has(edge.to) or cost<costs[edge.to]:
    costs[edge.to]=cost
    previous[edge.to]=edge
 return {"error":"找不到从当前版本到最新版的完整补丁链，请更新完整安装包。"}

func _download_next() -> void:
 if download_index==queue.size():
  download_progress.emit(total_download_bytes,total_download_bytes,"正在安装补丁…")
  var installed=manager.install_chain(downloaded_paths)
  if installed.has("error"):_finish(installed)
  else:_finish({"installed":true,"version":installed.to,"patch_count":queue.size()})
  return
 expected=queue[download_index]
 download_path=manager.patch_dir+"/cloud-download-%d.tmp" % download_index
 downloaded_paths.append(download_path)
 _request(expected.url,download_path,_download_received)

func _download_received(result: int,code: int,_body: PackedByteArray) -> void:
 if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
  _finish({"error":"PCK 补丁下载失败。"})
  return
 var downloaded=FileAccess.open(download_path,FileAccess.READ)
 var size=downloaded.get_length() if downloaded!=null else -1
 if downloaded!=null:downloaded.close()
 if size!=expected.size or FileAccess.get_sha256(download_path).to_lower()!=expected.sha256:
  _finish({"error":"下载的 PCK 补丁大小或哈希不匹配。"})
  return
 var details=manager.inspect(download_path,expected.from)
 if details.has("error"):
  _finish(details)
  return
 if details.to!=expected.to:
  _finish({"error":"PCK 补丁目标版本与清单不一致。"})
  return
 finished_download_bytes+=int(expected.size)
 download_index+=1
 _download_next()

func _finish(result: Dictionary) -> void:
 for path in downloaded_paths:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 download_path=""
 downloaded_paths.clear()
 queue.clear()
 expected={}
 total_download_bytes=0
 finished_download_bytes=0
 busy=false
 completed.emit(result)
