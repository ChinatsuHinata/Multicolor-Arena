@tool
extends EditorExportPlugin
const Policy=preload("res://addons/share_export/release_policy.gd")
func _get_name() -> String:
 return "MulticolourBundledDecks"
func _export_begin(_features: PackedStringArray,_is_debug: bool,_path: String,_flags: int):
 var store=load("res://scripts/deck_store.gd")
 # Tool execution initializes the database explicitly before validating saves.
 store.CARDS=store.Database.load_cards()
 var decks=store.load_decks(store.SAVE_PATH)
 if decks.has("error") or store.CARDS.is_empty():
  push_error("无法导出初始卡组："+decks.get("error",store.Database.last_error))
  return
 # The old collection remains the preset source; the current AI list lives in .mdeck.
 var portable=[]
 for source in store.scan_files("res://deck"):
  var parsed=store.read_file(source)
  if parsed.has("deck"):portable.append(parsed.deck)
 var release=Policy.select_decks(decks.decks,portable)
 if release.has("error"):
  push_error(release.error)
  return
 # FileAccess JSON records are not imported Godot resources; always package them.
 for id in store.Database.IDS:
  var source="res://cards/"+id+".json"
  add_file(source,FileAccess.get_file_as_bytes(source),false)
 add_file("res://net/rules_manifest.json",FileAccess.get_file_as_bytes("res://net/rules_manifest.json"),false)
 var payload=JSON.stringify({"version":1,"release_policy":Policy.VERSION,"upgrade_deck_ids":[Policy.REMILIA_ID],"decks":release.decks},"  ").to_utf8_buffer()
 add_file(store.BUNDLED_DECKS_PATH,payload,false)
 print("BUNDLED_DECKS: ",release.decks.size(),"; REGISTERED_CARDS: ",store.CARDS.size())

func _export_file(path: String,_type: String,_features: PackedStringArray):
 # Recovery tokens, private match journals and developer test fixtures never ship.
 if Policy.excluded_path(path):skip()
 # These files are supplied once by _export_begin; exporting the originals too
 # creates duplicate APK ZIP entries and prevents Android signing.
 if path.begins_with("res://cards/") and path.ends_with(".json"):skip()
 if path=="res://net/rules_manifest.json":skip()
