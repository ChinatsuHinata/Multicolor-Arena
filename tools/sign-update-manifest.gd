extends SceneTree
## Sign a release payload with a local-only key. Never copy the private key to the server.

func _initialize():
 var args=OS.get_cmdline_user_args()
 if args.size()!=2:push_error("Usage: sign-update-manifest.gd -- <payload.json> <signed.json>");quit(2);return
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
 var payload=FileAccess.get_file_as_bytes(args[0])
 if payload.is_empty() or payload.size()>60000:push_error("Invalid release payload");quit(2);return
 var hashing=HashingContext.new()
 hashing.start(HashingContext.HASH_SHA256)
 hashing.update(payload)
 var signature=Crypto.new().sign(HashingContext.HASH_SHA256,hashing.finish(),key)
 if signature.is_empty():push_error("Could not sign release payload");quit(2);return
 var output=FileAccess.open(args[1],FileAccess.WRITE)
 if output==null:push_error("Could not write signed manifest");quit(2);return
 output.store_string(JSON.stringify({"payload":Marshalls.raw_to_base64(payload),"signature":Marshalls.raw_to_base64(signature)}))
 output.close()
 print("Signed release manifest: ",args[1])
 quit(0)
