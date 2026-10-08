extends SceneTree

const BASE="1.2.7.1"
const NEXT="1.2.7.2"
const LATEST="1.2.7.3"
const PatchManager=preload("res://scripts/patch_manager.gd")
const AccountClient=preload("res://scripts/account_client.gd")
var failures=[]
var folder=""
var key: CryptoKey
var manager
var server: TCPServer
var peers=[]
var manifest=PackedByteArray()
var patch=PackedByteArray()
var patch_requests=0
var manifest_status=200
var chain_manifest=PackedByteArray()
var assets={}
var asset_status={}
var requested_paths=[]

func _initialize():call_deferred("run")

func check(value: bool,label: String):
 if value:print("PASS: ",label)
 else:failures.append(label);push_error(label)

func signed(value: Dictionary) -> PackedByteArray:
 var bytes=JSON.stringify(value).to_utf8_buffer()
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
 var signature=Crypto.new().sign(HashingContext.HASH_SHA256,hash.finish(),key)
 return JSON.stringify({"payload":Marshalls.raw_to_base64(bytes),"signature":Marshalls.raw_to_base64(signature)}).to_utf8_buffer()

func sha256(bytes: PackedByteArray) -> String:
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
 return hash.finish().hex_encode()

func make_patch(from_version: String=BASE,to_version: String=NEXT,content: String="simulated patch") -> PackedByteArray:
 var marker=folder.path_join("marker.txt")
 var raw=folder.path_join("raw.pck")
 var output=FileAccess.open(marker,FileAccess.WRITE);output.store_string(content);output.close()
 var pack=PCKPacker.new()
 check(pack.pck_start(raw)==OK and pack.add_file("res://data/pck_auto_probe.txt",marker)==OK and pack.flush()==OK,"create signed test PCK")
 var raw_bytes=FileAccess.get_file_as_bytes(raw)
 var payload={"format":"multicolor:arena/pck-patch-1","game":"multicolor:arena","platform":manager.platform(),"from":from_version,"to":to_version,"sha256":sha256(raw_bytes),"size":raw_bytes.size()}
 var envelope=signed(payload)
 var result="MCA-PCK1".to_ascii_buffer()
 result.resize(12)
 result.encode_u32(8,envelope.size())
 result.append_array(envelope)
 result.resize(4096)
 result.append_array(raw_bytes)
 DirAccess.remove_absolute(raw)
 DirAccess.remove_absolute(marker)
 return result

func chain_edge(origin: String,from_version: String,to_version: String,bytes: PackedByteArray) -> Dictionary:
 var hash=sha256(bytes)
 var path="/updates/pck/%s/MulticolorArena-%s-to-%s-%s-%s.pck" % [to_version,from_version,to_version,manager.platform(),hash]
 assets[path]=bytes
 return {"from":from_version,"to":to_version,manager.platform():{"url":origin+path,"size":bytes.size(),"sha256":hash}}

func reset_installation() -> void:
 var dir=DirAccess.open(manager.patch_dir)
 if dir!=null:
  for name in dir.get_files():DirAccess.remove_absolute(manager.patch_dir.path_join(name))
 manager.active_version=BASE
 manager.pending_version=""
 requested_paths.clear()
 asset_status.clear()

func make_manifest(origin: String):
 var name="MulticolorArena-%s-to-%s-%s.pck" % [BASE,NEXT,manager.platform()]
 var payload={"format":"multicolor:arena/pck-latest-1","game":"multicolor:arena","base":BASE,"version":NEXT}
 payload[manager.platform()]={"url":origin+"/updates/pck/"+NEXT+"/"+name,"size":patch.size(),"sha256":sha256(patch)}
 manifest=signed(payload)

func serve():
 while server.is_connection_available():peers.append({"peer":server.take_connection(),"bytes":PackedByteArray()})
 for i in range(peers.size()-1,-1,-1):
  var item=peers[i]
  var peer: StreamPeerTCP=item.peer
  peer.poll()
  if peer.get_available_bytes()>0:
   var received=peer.get_data(peer.get_available_bytes())
   if received[0]==OK:item.bytes.append_array(received[1])
  var request=str(item.bytes.get_string_from_ascii())
  if not request.contains("\r\n\r\n"):continue
  var path=request.split(" ")[1]
  requested_paths.append(path)
  var status=int(asset_status.get(path,200))
  var body=PackedByteArray()
  if path=="/updates/pck/chain.json":
   body=chain_manifest
   if chain_manifest.is_empty():status=404
  elif path=="/updates/pck/latest.json":
   body=manifest
   status=manifest_status
  else:body=assets.get(path,patch)
  if status!=200:body=PackedByteArray()
  if path.ends_with(".pck"):patch_requests+=1
  var header="HTTP/1.1 %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % ["200 OK" if status==200 else "404 Not Found",body.size()]
  peer.put_data(header.to_ascii_buffer()+body)
  peer.disconnect_from_host()
  peers.remove_at(i)

func wait_for_updater(app) -> void:
 var deadline=Time.get_ticks_msec()+30000
 while Time.get_ticks_msec()<deadline:
  serve()
  await create_timer(0.01).timeout
  if is_instance_valid(app.auto_pck_updater) and not app.auto_pck_updater.busy:return
 check(false,"automatic PCK request completes")

func run():
 folder=ProjectSettings.globalize_path("res://work/pck-auto-update-test")
 DirAccess.make_dir_recursive_absolute(folder)
 manager=root.get_node("PatchManager")
 manager.patch_dir=folder.path_join("installed")
 manager.base_version=BASE
 manager.active_version=BASE
 key=Crypto.new().generate_rsa(2048)
 manager.trusted_key=key
 patch=make_patch()
 server=TCPServer.new()
 check(server.listen(0,"127.0.0.1")==OK,"start local cloud simulator")
 var origin="http://127.0.0.1:%d" % server.get_local_port()
 make_manifest(origin)
 var app=load("res://main.tscn").instantiate()
 app.auto_patch_update_in_editor=true
 app.auto_pck_origin=origin
 app.account_session_path=folder.path_join("session.json")
 root.add_child(app)
 await process_frame
 app.account_client=AccountClient.new();app.add_child(app.account_client)
 app.account_client.session_token="a".repeat(64)
 app.account_client.remember_token="b".repeat(64)
 app.account_action="login"
 app.account_request_finished(true,"登录成功","patch_tester")
 await wait_for_updater(app)
 var index_path=manager.patch_dir.path_join("index.json")
 var index=JSON.parse_string(FileAccess.get_file_as_string(index_path))
 check(patch_requests==1,"login downloads the latest platform PCK")
 check(requested_paths[0]=="/updates/pck/chain.json" and requested_paths[1]=="/updates/pck/latest.json","missing chain manifest falls back to legacy manifest")
 check(index is Array and index.size()==1,"login installs the signed PCK")
 if index is Array and index.size()==1:
  var installed=manager.inspect(manager.patch_dir.path_join(index[0]),BASE)
  check(installed.get("to")==NEXT,"installed PCK targets simulated 1.2.7.2")
 manager.active_version=NEXT
 app.check_cloud_pck_patch()
 await wait_for_updater(app)
 check(patch_requests==1,"already current client does not download again")
 manifest_status=404
 var outcomes=[]
 app.auto_pck_updater.completed.connect(func(result):outcomes.append(result))
 app.check_cloud_pck_patch()
 await wait_for_updater(app)
 check(not outcomes.is_empty() and outcomes.back().get("up_to_date",false),"unpublished cloud manifest is treated as no update")
 var invalid=JSON.parse_string(manifest.get_string_from_utf8())
 invalid.signature="AAAA"
 check(app.auto_pck_updater._verify_manifest(JSON.stringify(invalid).to_utf8_buffer()).has("error"),"tampered cloud manifest is rejected")
 app.auto_pck_updater.completed.disconnect(app.cloud_pck_patch_completed)
 var download_starts=[]
 var download_updates=[]
 app.auto_pck_updater.download_started.connect(func(total,count):download_starts.append({"total":total,"count":count}))
 app.auto_pck_updater.download_progress.connect(func(done,total,stage):download_updates.append({"done":done,"total":total,"stage":stage}))
 # Unsorted graph with two small adjacent patches and a larger cumulative route.
 reset_installation()
 var first=chain_edge(origin,BASE,NEXT,make_patch(BASE,NEXT,"intermediate resources"))
 var second=chain_edge(origin,NEXT,LATEST,make_patch(NEXT,LATEST,"final resources"))
 var direct=chain_edge(origin,BASE,LATEST,make_patch(BASE,LATEST,"cumulative".repeat(4000)))
 var payload={"format":"multicolor:arena/pck-latest-1","game":"multicolor:arena","base":BASE,"version":LATEST,"patches":[second,direct,first]}
 var first_path=first[manager.platform()].url.trim_prefix(origin)
 var second_path=second[manager.platform()].url.trim_prefix(origin)
 chain_manifest=signed(payload)
 asset_status[second_path]=404
 outcomes.clear()
 app.check_cloud_pck_patch()
 await wait_for_updater(app)
 check(requested_paths==["/updates/pck/chain.json",first_path,second_path],"version traversal chooses the smallest complete route in order")
 check(outcomes.size()==1 and outcomes[0].has("error") and not FileAccess.file_exists(index_path),"second download failure commits no partial installation")
 check(DirAccess.open(manager.patch_dir).get_files().is_empty(),"failed batch removes all temporary downloads")
 asset_status.clear()
 var good_second=assets[second_path].duplicate()
 var damaged=good_second.duplicate();damaged[damaged.size()-1]^=1
 assets[second_path]=damaged
 outcomes.clear()
 app.check_cloud_pck_patch()
 await wait_for_updater(app)
 check(outcomes.size()==1 and outcomes[0].has("error") and not FileAccess.file_exists(index_path),"corrupt later patch leaves installed state unchanged")
 assets[second_path]=good_second
 outcomes.clear()
 requested_paths.clear()
 app.check_cloud_pck_patch()
 await wait_for_updater(app)
 index=JSON.parse_string(FileAccess.get_file_as_string(index_path))
 check(index is Array and index.size()==2,"one batch commits both adjacent patches")
 check(outcomes.size()==1 and outcomes[0].get("version")==LATEST and outcomes[0].get("patch_count")==2,"whole chain emits one final completion")
 check(not download_starts.is_empty() and download_starts.back().total==assets[first_path].size()+assets[second_path].size() and download_starts.back().count==2,"progress totals every patch in the selected chain")
 check(not download_updates.is_empty() and download_updates.back().done==download_updates.back().total and download_updates.back().stage=="正在安装补丁…","progress reaches full download before installation")
 check(manager.active_version==BASE and manager.installed_version()==LATEST,"pending version advances without changing running resources")
 var request_count=requested_paths.size()
 app.check_cloud_pck_patch()
 await wait_for_updater(app)
 check(requested_paths.size()==request_count+1,"pending installation is not downloaded again before restart")
 var restarted=PatchManager.new()
 restarted.base_version=BASE;restarted.active_version=BASE;restarted.patch_dir=manager.patch_dir;restarted.trusted_key=key
 restarted._load_installed()
 check(restarted.startup_error.is_empty() and restarted.active_version==LATEST and FileAccess.get_file_as_string("res://data/pck_auto_probe.txt")=="final resources","restart mounts the complete chain and final resources")
 restarted.free()
 # Already intermediate clients only need the final edge.
 manager.active_version=NEXT;manager.pending_version=""
 var updater=app.auto_pck_updater
 updater.active_version=NEXT
 var plan=updater._plan(payload)
 check(plan.get("patches",[]).size()==1 and plan.patches[0].from==NEXT,"intermediate client plans only the missing patch")
 manager.base_version=NEXT
 check(updater._plan(payload).get("patches",[]).size()==1,"full intermediate installation can use an adjacent patch")
 manager.base_version=BASE
 var broken=payload.duplicate(true);broken.patches=[second]
 updater.active_version=BASE
 check(updater._plan(broken).has("error"),"missing chain link is rejected")
 broken=payload.duplicate(true);broken.patches.append(first)
 check(updater._plan(broken).has("error"),"duplicate chain routes are rejected")
 broken=payload.duplicate(true);broken.patches[0][manager.platform()].url="http://untrusted.invalid/patch.pck"
 check(updater._plan(broken).has("error"),"external patch address is rejected")
 # Failure during an upgrade must preserve a previously committed chain too.
 manager.active_version=NEXT;manager.pending_version=""
 # Restore the intermediate installation being upgraded in this fixture.
 var intermediate_index=manager._read_index()
 var intermediate_record=FileAccess.open(index_path,FileAccess.WRITE)
 intermediate_record.store_string(JSON.stringify([intermediate_index[0]]));intermediate_record.close()
 var original_index=FileAccess.get_file_as_string(index_path)
 outcomes.clear()
 # HTTP failures were exercised above. Inject the completed failed response
 # here to isolate rollback of an existing installation from a new request.
 var failed_download=manager.patch_dir.path_join("cloud-download-existing.tmp")
 var partial=FileAccess.open(failed_download,FileAccess.WRITE)
 partial.store_string("partial failed download");partial.close()
 updater.manager=manager;updater.busy=true;updater.download_path=failed_download
 updater.downloaded_paths=[failed_download]
 updater._download_received(HTTPRequest.RESULT_SUCCESS,404,PackedByteArray())
 check(outcomes.size()==1 and outcomes[0].get("error")=="PCK 补丁下载失败。" and FileAccess.get_file_as_string(index_path)==original_index,"failed upgrade preserves an existing installed chain")
 check(not FileAccess.file_exists(failed_download),"failed upgrade removes only its temporary download")
 var real_name=manager.name
 manager.name="TestPatchManager"
 var legacy=load("res://tests/support/legacy_patch_manager.gd").new()
 legacy.name="PatchManager";legacy.patch_dir=manager.patch_dir;legacy.trusted_key=key
 root.add_child(legacy)
 var compatible=app.patch_manager()
 check(compatible.has_method("install_chain") and compatible.base_version==BASE and compatible.active_version==NEXT and compatible.patch_dir==manager.patch_dir and compatible.trusted_key==key,"patched client upgrades a pre-mounted legacy manager without remounting")
 legacy.free()
 manager.name=real_name
 var session_path=app.account_session_path
 app.queue_free()
 await process_frame
 if index is Array:
  for name in index:DirAccess.remove_absolute(manager.patch_dir.path_join(name))
 DirAccess.remove_absolute(index_path)
 DirAccess.remove_absolute(manager.patch_dir.path_join("cloud-download.tmp"))
 DirAccess.remove_absolute(manager.patch_dir)
 DirAccess.remove_absolute(session_path)
 DirAccess.remove_absolute(folder)
 server.stop()
 print("PCK_AUTO_UPDATE: ","PASS" if failures.is_empty() else "FAIL")
 quit(0 if failures.is_empty() else 1)
