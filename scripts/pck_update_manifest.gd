extends RefCounted
## Shared by the client and the publisher's local signature verifier.
const MAX_MANIFEST_BYTES=131072
const MAX_PAYLOAD_BYTES=60000
const MAX_PATCHES=128

static func verify(bytes: PackedByteArray,key: CryptoKey) -> Dictionary:
 if bytes.is_empty() or bytes.size()>MAX_MANIFEST_BYTES:return {"error":"云端补丁清单大小无效。"}
 var envelope=JSON.parse_string(bytes.get_string_from_utf8())
 if not envelope is Dictionary or not envelope.get("payload") is String or not envelope.get("signature") is String:
  return {"error":"云端补丁清单格式无效。"}
 var payload_bytes=Marshalls.base64_to_raw(envelope.payload)
 var signature=Marshalls.base64_to_raw(envelope.signature)
 if payload_bytes.is_empty() or payload_bytes.size()>MAX_PAYLOAD_BYTES or signature.is_empty():
  return {"error":"云端补丁清单签名缺失。"}
 if key==null:return {"error":"补丁公钥不可用。"}
 var hash=HashingContext.new()
 hash.start(HashingContext.HASH_SHA256)
 hash.update(payload_bytes)
 if not Crypto.new().verify(HashingContext.HASH_SHA256,hash.finish(),signature,key):
  return {"error":"云端补丁清单签名校验失败。"}
 var payload=JSON.parse_string(payload_bytes.get_string_from_utf8())
 if not payload is Dictionary or payload.get("format")!="multicolor:arena/pck-latest-1" or payload.get("game")!="multicolor:arena":
  return {"error":"云端补丁清单内容无效。"}
 return payload
