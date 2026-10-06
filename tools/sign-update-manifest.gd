extends SceneTree
## Sign a release payload with a local-only key. Never copy the private key to the server.

func _initialize():
 var args=OS.get_cmdline_user_args()
 if args.size()!=2 and args.size()!=3:push_error("Usage: sign-update-manifest.gd -- <payload.json> <signed.json> [test-key]");quit(2);return
 var payload=FileAccess.get_file_as_bytes(args[0])
 if payload.is_empty() or payload.size()>60000:push_error("Invalid release payload");quit(2);return
 var decoded=JSON.parse_string(payload.get_string_from_utf8())
 var test_only=decoded is Dictionary and decoded.get("test_only",false)==true
 if args.size()==3:
  if not test_only:push_error("Custom signing keys require a TEST_ONLY payload");quit(2);return
  var test_key=CryptoKey.new()
  if test_key.load(args[2])!=OK:push_error("Cannot load isolated test signing key");quit(2);return
  if test_key.save_to_string(true)==FileAccess.get_file_as_string("res://data/update_public.pem"):
   push_error("Test artifacts require a key different from the release key");quit(2);return
  _sign(payload,test_key,args[1])
  return
 if test_only:push_error("Refusing to sign test artifacts with the release key");quit(2);return
 var private_path="res://.godot-toolchain/release-signing.key"
 var public_path="res://data/update_public.pem"
 var key: CryptoKey
 if FileAccess.file_exists(private_path):
  key=CryptoKey.new()
  if key.load(private_path)!=OK:push_error("Could not load release signing key");quit(2);return
 else:
  key=Crypto.new().generate_rsa(3072)
  if key==null or key.save(private_path)!=OK:push_error("Could not create release signing key");quit(2);return
 var public_pem=key.save_to_string(true)
 if FileAccess.file_exists(public_path) and FileAccess.get_file_as_string(public_path)!=public_pem:
  push_error("Release public key differs from the local signing key; refusing key rotation")
  quit(2);return
 if not FileAccess.file_exists(public_path):
  var public_file=FileAccess.open(public_path,FileAccess.WRITE)
  if public_file==null:push_error("Could not write release public key");quit(2);return
  public_file.store_string(public_pem)
  public_file.close()
 _sign(payload,key,args[1])

func _sign(payload: PackedByteArray,key: CryptoKey,output_path: String):
 var hashing=HashingContext.new()
 hashing.start(HashingContext.HASH_SHA256)
 hashing.update(payload)
 var signature=Crypto.new().sign(HashingContext.HASH_SHA256,hashing.finish(),key)
 if signature.is_empty():push_error("Could not sign release payload");quit(2);return
 var output=FileAccess.open(output_path,FileAccess.WRITE)
 if output==null:push_error("Could not write signed manifest");quit(2);return
 output.store_string(JSON.stringify({"payload":Marshalls.raw_to_base64(payload),"signature":Marshalls.raw_to_base64(signature)}))
 output.close()
 print("Signed manifest: ",output_path)
 quit(0)
