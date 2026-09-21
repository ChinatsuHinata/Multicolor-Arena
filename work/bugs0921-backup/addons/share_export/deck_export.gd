@tool
extends EditorExportPlugin
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
 # FileAccess JSON records are not imported Godot resources; always package them.
 for id in store.Database.IDS:
  var source="res://cards/"+id+".json"
  add_file(source,FileAccess.get_file_as_bytes(source),false)
 add_file("res://net/rules_manifest.json",FileAccess.get_file_as_bytes("res://net/rules_manifest.json"),false)
 var payload=JSON.stringify({"version":1,"decks":decks.decks},"  ").to_utf8_buffer()
 add_file(store.BUNDLED_DECKS_PATH,payload,false)
 print("BUNDLED_DECKS: ",decks.decks.size(),"; REGISTERED_CARDS: ",store.CARDS.size())

func _export_file(path: String,_type: String,_features: PackedStringArray):
 # Recovery tokens, private match journals and developer test fixtures never ship.
 for directory in ["res://saves/","res://deck/","res://replay/","res://work/","res://tests/","res://tools/","res://docs/","res://builds/","res://addons/"]:
  if path.begins_with(directory):skip();return
