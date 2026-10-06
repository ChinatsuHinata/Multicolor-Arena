extends RefCounted
## Disposable fixtures: independent signing key, loopback URLs, and TEST_ONLY markers.
const RESOURCE="res://data/pck_test_only_probe.txt"
var folder: String
var origin: String
var key: CryptoKey
var run_id: String

func sign_payload(payload: Dictionary) -> PackedByteArray:
 var bytes=JSON.stringify(payload).to_utf8_buffer()
 var hash=HashingContext.new()
 hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
 return JSON.stringify({"payload":Marshalls.raw_to_base64(bytes),"signature":Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256,hash.finish(),key))}).to_utf8_buffer()

func hash_bytes(bytes: PackedByteArray) -> String:
 var hash=HashingContext.new()
 hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
 return hash.finish().hex_encode()

func write_bytes(path: String,bytes: PackedByteArray) -> void:
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 var file=FileAccess.open(path,FileAccess.WRITE)
 assert(file!=null,"Cannot write isolated fixture")
 file.store_buffer(bytes);file.close()

func patch(from_version: String,to_version: String,platform: String,large: bool=false) -> Dictionary:
 var marker=folder.path_join("marker.txt")
 var raw=folder.path_join("raw.pck")
 write_bytes(marker,("TEST_ONLY|%s|%s" % [run_id,to_version]).to_utf8_buffer())
 var pack=PCKPacker.new()
 assert(pack.pck_start(raw)==OK)
 assert(pack.add_file(RESOURCE,marker)==OK)
 assert(pack.add_file("res://data/pck_test_only_steps/"+to_version+".txt",marker)==OK)
 if large:
  var padding=folder.path_join("padding.txt")
  write_bytes(padding,"TEST_ONLY_CUMULATIVE_PADDING".repeat(4000).to_utf8_buffer())
  assert(pack.add_file("res://data/pck_test_only_padding.txt",padding)==OK)
 assert(pack.flush()==OK)
 var bytes=FileAccess.get_file_as_bytes(raw)
 var payload={"format":"multicolor:arena/pck-patch-1","game":"multicolor:arena","platform":platform,"from":from_version,"to":to_version,"size":bytes.size(),"sha256":hash_bytes(bytes),"test_only":true,"test_run":run_id,"notice":"TEST_ONLY: not a game release"}
 var envelope=sign_payload(payload)
 assert(envelope.size()<=4084)
 var signed="MCA-PCK1".to_ascii_buffer()
 signed.resize(12);signed.encode_u32(8,envelope.size());signed.append_array(envelope)
 signed.resize(4096);signed.append_array(bytes)
 var hash=hash_bytes(signed)
 var path="/updates/pck/%s/MulticolorArena-%s-to-%s-%s-%s.pck" % [to_version,from_version,to_version,platform,hash]
 write_bytes(folder.path_join("releases/pck/"+to_version).path_join(path.get_file()),signed)
 return {"url":origin+path,"size":signed.size(),"sha256":hash}

func prepare(versions: PackedStringArray) -> void:
 key=Crypto.new().generate_rsa(2048)
 run_id=Crypto.new().generate_random_bytes(16).hex_encode()
 assert(key.save(folder.path_join("test_public.pem"),true)==OK)
 var edges=[]
 for i in range(versions.size()-1):
  var edge={"from":versions[i],"to":versions[i+1]}
  for platform in ["windows","android"]:edge[platform]=patch(versions[i],versions[i+1],platform)
  edges.append(edge)
 var direct={"from":versions[0],"to":versions[-1]}
 for platform in ["windows","android"]:direct[platform]=patch(versions[0],versions[-1],platform,true)
 var payload={"format":"multicolor:arena/pck-latest-1","game":"multicolor:arena","base":"1.2.7.1","version":versions[-1],"test_only":true,"test_run":run_id,"notice":"TEST_ONLY: not a game release","patches":[edges[2],direct,edges[0],edges[1]]}
 write_bytes(folder.path_join("releases/pck/chain.json"),sign_payload(payload))
 var broken=payload.duplicate(true)
 broken.patches=[edges[0],edges[2]]
 write_bytes(folder.path_join("broken-chain.json"),sign_payload(broken))
 write_bytes(folder.path_join("TEST_ONLY.json"),JSON.stringify({"test_only":true,"test_run":run_id,"versions":versions,"origin":origin,"edges":edges,"notice":"Private loopback test. Never publish these files or reuse a release signing key."}).to_utf8_buffer())
 for name in ["marker.txt","raw.pck","padding.txt"]:DirAccess.remove_absolute(folder.path_join(name))
