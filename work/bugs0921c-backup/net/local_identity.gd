extends RefCounted
const Journal=preload("res://net/journal_store.gd")
static func token() -> String:return Crypto.new().generate_random_bytes(24).hex_encode()
static func load_identity(path: String="user://lan/identity.bin") -> Dictionary:
 var data=Journal.load_from(path)
 if data.is_empty():data={"installation":token(),"nickname":"玩家","resume":{}}
 return data
static func nickname(value: String) -> String:
 var clean=""
 for ch in value.strip_edges():
  if ch.unicode_at(0)>=32 and ch.unicode_at(0)!=127:clean+=ch
 return clean.left(20) if not clean.is_empty() else "玩家"
