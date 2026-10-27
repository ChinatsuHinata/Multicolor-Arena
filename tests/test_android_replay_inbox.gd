extends SceneTree
const Inbox=preload("res://scripts/android_replay_inbox.gd")
var folder="res://work/replay-inbox-test/"+str(Time.get_ticks_usec())
var delivered=[]
var errors=[]
var checks=0
var failures=0
func expect(value: bool,message: String):
 checks+=1
 if not value:failures+=1;push_error(message)
func write(path: String,contents: String):
 var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(contents);f.close()
func fixture(id: String,name: String="sample.mreply",contents: String="MREPLY1\nfixture") -> String:
 write(folder.path_join(id+".mreply"),contents)
 write(folder.path_join(id+".json"),JSON.stringify({"file":id+".mreply","name":name}))
 return folder.path_join(id+".mreply")
func make_inbox():
 var inbox=Inbox.new();root.add_child(inbox)
 inbox.replay_received.connect(func(path,label):delivered.append([path,label]))
 inbox.import_failed.connect(func(message):errors.append(message))
 expect(inbox.start(folder),"test inbox starts with an explicit cache directory")
 return inbox
func _initialize():call_deferred("run")
func run():
 DirAccess.make_dir_recursive_absolute(folder)
 var id="0123456789abcdef0123456789abcdef"
 var valid=fixture(id,"../../sample.mreply")
 var inbox=make_inbox();inbox.poll();inbox.poll()
 expect(delivered.size()==1,"same pending request is delivered once during a session")
 expect(delivered[0][1]=="sample.mreply","display names cannot carry directory components")
 expect(FileAccess.file_exists(valid),"unacknowledged data survives until the UI accepts it")
 inbox.free();inbox=make_inbox();inbox.poll()
 expect(delivered.size()==2,"an unfinished request is retried after restarting the inbox")
 var outside=folder.path_join("keep.mreply");write(outside,"keep")
 inbox.acknowledge(outside)
 expect(FileAccess.file_exists(outside),"acknowledgement refuses non-generated names")
 inbox.acknowledge(valid)
 expect(not FileAccess.file_exists(valid) and not FileAccess.file_exists(folder.path_join(id+".json")),"acknowledgement removes only its own cache and request")
 write(folder.path_join(id+".json"),JSON.stringify({"file":"../keep.mreply"}))
 inbox.poll()
 expect(errors.size()==1 and FileAccess.file_exists(outside),"path traversal descriptor is rejected without deleting another file")
 id="1123456789abcdef0123456789abcdef"
 valid=fixture(id,"bad.mreply","invalid")
 inbox.poll()
 expect(errors.size()==2 and not FileAccess.file_exists(valid),"bad replay header is rejected and acknowledged")
 id="2123456789abcdef0123456789abcdef"
 write(folder.path_join(id+".json"),JSON.stringify({"error":"读取失败"}));inbox.poll()
 expect(errors.size()==3 and errors[-1]=="读取失败","native import errors reach the UI")
 write(folder.path_join("not-a-generated-request.json"),"{}");inbox.poll()
 expect(errors.size()==3,"unrelated cache files are not interpreted")
 inbox.free()
 for filename in DirAccess.get_files_at(folder):DirAccess.remove_absolute(folder.path_join(filename))
 DirAccess.remove_absolute(folder)
 print("Replay inbox: "+str(checks)+" checks passed")
 quit(1 if failures else 0)
