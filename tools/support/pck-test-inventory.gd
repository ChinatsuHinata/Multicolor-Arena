extends SceneTree

func collect(folder: String,inventory: Dictionary):
 var directory=DirAccess.open(folder)
 if directory==null:push_error("Cannot inspect "+folder);quit(2);return
 directory.include_hidden=true
 for name in directory.get_files():
  var path=folder.path_join(name)
  inventory[path]=FileAccess.get_md5(path)
 for name in directory.get_directories():collect(folder.path_join(name),inventory)

func _initialize():
 var args=OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 var inventory={}
 collect("res://",inventory)
 var output=FileAccess.open(args[0],FileAccess.WRITE)
 if output==null:quit(2);return
 output.store_string(JSON.stringify(inventory));output.close()
 print("TEST_ONLY_TARGET_INVENTORY: ",inventory.size())
 quit(0)
