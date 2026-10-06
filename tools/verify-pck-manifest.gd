extends SceneTree
const Manifest=preload("res://scripts/pck_update_manifest.gd")

func _initialize():
 var args=OS.get_cmdline_user_args()
 if args.size()!=2:push_error("Expected signed manifest and verified payload paths");quit(2);return
 var key=CryptoKey.new()
 if key.load("res://data/update_public.pem",true)!=OK:push_error("Cannot load release public key");quit(2);return
 var payload=Manifest.verify(FileAccess.get_file_as_bytes(args[0]),key)
 if payload.has("error"):push_error(payload.error);quit(2);return
 var output=FileAccess.open(args[1],FileAccess.WRITE)
 if output==null:push_error("Cannot save verified cloud payload");quit(2);return
 output.store_string(JSON.stringify(payload))
 output.close()
 quit(0)
