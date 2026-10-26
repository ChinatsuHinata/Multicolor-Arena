@tool
extends EditorExportPlugin
const Policy=preload("res://addons/share_export/release_policy.gd")
func _get_name() -> String:
 return "MulticolourBundledDecks"
static func release_decks() -> Dictionary:
 var store=load("res://scripts/deck_store.gd")
 var presets=store.load_decks(store.PRESET_DECKS_PATH)
 if presets.has("error"):return presets
 if presets.decks.is_empty():return {"error":"发行包缺少公共预设卡组。"}
 return Policy.select_decks(presets.decks,[])

func _export_begin(_features: PackedStringArray,_is_debug: bool,_path: String,_flags: int):
 var store=load("res://scripts/deck_store.gd")
 # Tool execution initializes the database before validating public presets.
 store.Paths.root_override=""
 # Local enabled packs are external content, outside the released core database.
 store.Database.ModRegistry._shared=store.Database.ModRegistry.new()
 store.CARDS=store.Database.load_cards()
 var release=release_decks()
 if release.has("error") or store.CARDS.is_empty():
  push_error("无法导出初始卡组："+release.get("error",store.Database.last_error))
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
