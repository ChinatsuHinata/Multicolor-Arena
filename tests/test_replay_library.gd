extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Archive=preload("res://scripts/replay_archive.gd")
const Library=preload("res://scripts/replay_library.gd")
const Observer=preload("res://net/observer_projection.gd")
var checks=0
var failures=[]
func _initialize():call_deferred("run")
func check(ok: bool,title: String):
 checks+=1
 if ok:print("PASS: "+title)
 else:failures.append(title);push_error(title)
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/replay-library/"+str(Time.get_ticks_usec()))
 var decks=Store.load_decks().decks
 var engine=preload("res://scripts/rules/duel_engine.gd").new();engine.start(decks[0],decks[1],0,42)
 var room={"names":["玩家一","玩家二"],"scores":[0,1],"format":1,"round":1,"status":"complete","winner":1}
 var packet={"game_id":"test","sequence":1,"room":room,"projection":Observer.build(engine,[],0,true)}
 var original=Archive.new();original.record(packet);original.finish(room)
 var old_file=original.save(Library.folder().path_join("以前保存的录像.mreply"))
 check(old_file.has("path"),"existing saved recordings remain in replay root")
 var first="";var retained=""
 for i in range(25):
  var archive=Archive.new();archive.record(packet);archive.finish(room)
  archive.metadata.history_file="%020d_test.mreply" % (i+1)
  var saved=Library.record_finished(archive)
  check(saved.has("path"),"completed match automatically stored "+str(i))
  check(Library.entries(true).size()==mini(i+1,20),"rolling history never exceeds twenty "+str(i))
  if i==0:
   first=saved.path
   var keep=Library.keep(first);retained=keep.get("path","")
   check(keep.has("path") and Library.keep(first).path==retained,"keeping is idempotent and creates an independent file")
  check(Library.record_finished(archive).path==saved.path,"repeated completion does not create a duplicate "+str(i))
 check(not FileAccess.file_exists(first),"earliest history recording is removed")
 check(FileAccess.file_exists(retained) and FileAccess.file_exists(old_file.path),"retained and preexisting recordings survive rollover")
 var history=Library.entries(true)
 check(history.front().filename.begins_with("00000000000000000025") and history.back().filename.begins_with("00000000000000000006"),"history contains exactly the newest twenty in newest-first order")
 check(Library.entries().size()==2,"saved list excludes history and temporary files")
 var export_path=Store.Paths.root().path_join("导出录像")
 var exported=Library.export_file(history[0].path,export_path)
 check(exported.has("path") and exported.path.ends_with(".mreply") and FileAccess.get_file_as_bytes(exported.path)==FileAccess.get_file_as_bytes(history[0].path),"history exports verbatim with replay extension")
 check(Library.export_file(retained,exported.path).has("path") and FileAccess.get_file_as_bytes(exported.path)==FileAccess.get_file_as_bytes(retained),"retained replay exports and replaces a chosen destination")
 check(Library.export_file(retained,retained).has("path") and FileAccess.file_exists(retained),"export to same file does not truncate the source")
 var document_path=Store.Paths.root().path_join("system-document.mreply")
 check(Library.write_document(retained,document_path).has("path") and FileAccess.get_file_as_bytes(document_path)==FileAccess.get_file_as_bytes(retained),"document export streams the original replay without renaming the selected destination")
 check(Library.export_file(retained,Store.Paths.root().path_join("missing/export.mreply")).has("error") and FileAccess.file_exists(retained),"failed export preserves the recording")
 var unfinished=Archive.new();unfinished.record(packet)
 check(Library.record_finished(unfinished).has("error") and Library.entries(true).size()==20,"unfinished games do not enter completed history")
 original.metadata.rules="a-different-recorded-rules-fingerprint"
 var id=original.definitions.keys()[0];original.definitions[id].name="录制时的卡名"
 original.frames[0].erase("turn")
 var compatible=original.save(Store.Paths.root().path_join("旧规则录像.mreply"))
 var loaded=Archive.read(compatible.path)
 check(loaded.has("archive"),"different game rules do not block compatible snapshots")
 if loaded.has("archive"):
  check(loaded.archive.definitions[id].name=="录制时的卡名","recorded card definitions remain authoritative")
  check(loaded.archive.frames[0].turn==packet.projection.state.turn,"missing display turn is recovered from the snapshot")
  var remote=preload("res://net/remote_duel.gd").new();remote.apply_snapshot(loaded.archive.frame(0).projection)
  check(remote.cards[id].name=="录制时的卡名" and remote.players==packet.projection.state.players,"old-rule snapshot plays using recorded definitions and state")
 var bytes=FileAccess.get_file_as_bytes(compatible.path);bytes[bytes.size()-1]^=1
 var broken_path=Store.Paths.root().path_join("损坏录像.mreply")
 var file=FileAccess.open(broken_path,FileAccess.WRITE);file.store_buffer(bytes);file.close()
 check(Archive.read(broken_path).has("error"),"checksum corruption is still rejected")
 var invalid=packet.duplicate(true);invalid.projection.state.players=[]
 var raw=var_to_bytes(invalid);original.frames[0].bytes=raw.compress(FileAccess.COMPRESSION_ZSTD);original.frames[0].size=raw.size()
 var invalid_path=original.save(Store.Paths.root().path_join("无效状态.mreply"))
 var bad=Archive.read(invalid_path.path)
 check(bad.has("error") and bad.error.contains("第 1 步"),"genuinely unreadable state reports its failing step")
 print("REPLAY LIBRARY: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
