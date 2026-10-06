extends SceneTree

func _initialize():
 if not FileAccess.file_exists("res://data/update_public.pem"):
  push_error("PCK is missing the update signing public key")
  quit(2)
  return
 var key=CryptoKey.new()
 if key.load("res://data/update_public.pem",true)!=OK:
  push_error("PCK update signing public key is invalid")
  quit(2)
  return
 if load("res://scripts/patch_manager.gd")==null or load("res://scripts/pck_auto_updater.gd")==null:
  push_error("PCK is missing the update client scripts")
  quit(2)
  return
 print("PCK_BASE_CONTENT: PASS")
 quit(0)
