extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
func _initialize():
 print("CARDS ",Store.CARDS.size()," ",Store.Database.last_error)
 var data=JSON.parse_string(FileAccess.get_file_as_string(Store.SAVE_PATH))
 for d in data.decks:print(d.name," => ",Store.validate(d)," id_type ",typeof(d.id))
 print(Store.load_decks().get("error","OK"))
 quit()
